# server_action_validator.gd
# Comprehensive server-side action validation for authoritative server
# Prevents cheating by validating ALL client actions before execution
# Part of Phase 1 security implementation
class_name ServerActionValidator
extends RefCounted

## ServerActionValidator - Validates all game actions server-side
## NEVER trust the client - validate everything here

# ============================================================
# CONSTANTS
# ============================================================

## Maximum allowed values to prevent exploits
const MAX_MOVEMENT_POINTS: int = 20
const MAX_JUMP_POINTS: int = 10
const MAX_HEAT: int = 50
const MAX_WEAPONS_PER_SALVO: int = 10
const MAX_FACING: int = 5  # 0-5 hex facings
const MIN_FACING: int = 0

## Movement types (mirror GameEnums)
const MOVEMENT_WALK: int = 1
const MOVEMENT_RUN: int = 2
const MOVEMENT_JUMP: int = 3

# ============================================================
# VALIDATION RESULT STRUCTURE
# ============================================================

## Resultado estándar de validación
## Contiene si es válido, razón del rechazo, y contexto para logs
class ValidationResult:
	var valid: bool = false
	var reason: String = ""
	var context: Dictionary = {}
	
	func _init(is_valid: bool = false, rejection_reason: String = "", ctx: Dictionary = {}) -> void:
		valid = is_valid
		reason = rejection_reason
		context = ctx
	
	static func success() -> ValidationResult:
		return ValidationResult.new(true)
	
	static func failure(rejection_reason: String, ctx: Dictionary = {}) -> ValidationResult:
		return ValidationResult.new(false, rejection_reason, ctx)

# ============================================================
# ACTIVATION ORDER VALIDATION
# ============================================================

## Verifica que mech_id es la unidad que le toca activar en match_data["units_to_activate"].
## Si units_to_activate no esta poblado (partidas/tests que no lo usan) no restringe nada,
## para mantener compatibilidad con flujos que aun no rellenan la cola de activacion.
static func _validate_activation_order(match_data: Dictionary, mech_id: int) -> ValidationResult:
	var queue: Array = match_data.get("units_to_activate", [])
	if queue.is_empty():
		return ValidationResult.success()

	var index: int = match_data.get("current_unit_index", 0)
	if index < 0 or index >= queue.size():
		return ValidationResult.failure("Invalid activation index", {
			"current_unit_index": index,
			"queue_size": queue.size()
		})

	var expected_mech_id = queue[index]
	if expected_mech_id != mech_id:
		return ValidationResult.failure("Not this mech's turn to activate", {
			"mech_id": mech_id,
			"expected_mech_id": expected_mech_id,
			"current_unit_index": index
		})

	return ValidationResult.success()


# ============================================================
# MOVEMENT VALIDATION
# ============================================================

## Validates a complete movement action
## Checks: ownership, phase, distance, terrain, occupied hexes, ZoC, MPs
static func validate_movement(
	match_data: Dictionary, 
	mech_id: int, 
	peer_id: int,
	target_hex: Vector2i, 
	movement_type: int,
	terrain_data: Dictionary = {}
) -> ValidationResult:
	
	# 1. Verificar que el mech existe
	if not match_data["mechs"].has(mech_id):
		return ValidationResult.failure("Mech not found", {"mech_id": mech_id})
	
	var mech: Dictionary = match_data["mechs"][mech_id]
	
	# 2. Verificar propiedad del mech
	if mech["owner_peer"] != peer_id:
		return ValidationResult.failure("Not your mech", {
			"mech_id": mech_id,
			"owner": mech["owner_peer"],
			"requester": peer_id
		})
	
	# 3. Verificar fase correcta
	if match_data["current_phase"] != "movement":
		return ValidationResult.failure("Not movement phase", {
			"current_phase": match_data["current_phase"]
		})
	
	# 3b. Verificar orden de activacion (le toca a esta unidad, no a otra)
	var activation_check: ValidationResult = _validate_activation_order(match_data, mech_id)
	if not activation_check.valid:
		return activation_check
	
	# 4. Verificar que el mech no ha sido destruido
	if mech.get("is_destroyed", false):
		return ValidationResult.failure("Mech is destroyed", {"mech_id": mech_id})
	
	# 5. Verificar que el mech no está en shutdown
	if mech.get("is_shutdown", false):
		return ValidationResult.failure("Mech is shutdown", {"mech_id": mech_id})
	
	# 6. Verificar que el mech no se ha movido este turno
	if mech.get("moved_this_turn", false):
		return ValidationResult.failure("Mech already moved this turn", {"mech_id": mech_id})
	
	# 7. Validar tipo de movimiento
	if movement_type < MOVEMENT_WALK or movement_type > MOVEMENT_JUMP:
		return ValidationResult.failure("Invalid movement type", {"type": movement_type})
	
	# 8. Verificar si puede saltar (tiene jump_mp)
	if movement_type == MOVEMENT_JUMP and mech.get("jump_mp", 0) <= 0:
		return ValidationResult.failure("Mech cannot jump", {
			"mech_id": mech_id,
			"jump_mp": mech.get("jump_mp", 0)
		})
	
	# 9. Calcular MPs disponibles y distancia
	var current_pos: Vector2i = mech["hex_position"]
	var max_mp: int = _get_max_movement_points(mech, movement_type)
	var distance: int = _hex_distance(current_pos, target_hex)
	
	# 10. Verificar distancia básica
	if distance > max_mp:
		return ValidationResult.failure("Insufficient movement points", {
			"distance": distance,
			"max_mp": max_mp,
			"movement_type": movement_type
		})
	
	# 11. Verificar que el hex destino es válido (dentro del mapa)
	var validation_hex = _validate_hex_bounds(target_hex, terrain_data)
	if not validation_hex.valid:
		return validation_hex
	
	# 12. Verificar que el hex no está ocupado por otra unidad
	var occupation_check = _validate_hex_not_occupied(target_hex, mech_id, match_data)
	if not occupation_check.valid:
		return occupation_check
	
	# 13. Verificar terreno transitable (si tenemos datos de terreno)
	if not terrain_data.is_empty():
		var terrain_check = _validate_terrain_passable(target_hex, movement_type, terrain_data)
		if not terrain_check.valid:
			return terrain_check
	
	# 14. Verificar ZoC (Zone of Control) - no se puede salir de ZoC corriendo
	if movement_type == MOVEMENT_RUN:
		var zoc_check = _validate_zone_of_control(current_pos, target_hex, mech, match_data)
		if not zoc_check.valid:
			return zoc_check
	
	# Todo válido
	return ValidationResult.success()


## Validates rotation action
static func validate_rotation(
	match_data: Dictionary,
	mech_id: int,
	peer_id: int,
	new_facing: int
) -> ValidationResult:
	
	# 1. Verificar que el mech existe
	if not match_data["mechs"].has(mech_id):
		return ValidationResult.failure("Mech not found", {"mech_id": mech_id})
	
	var mech: Dictionary = match_data["mechs"][mech_id]
	
	# 2. Verificar propiedad
	if mech["owner_peer"] != peer_id:
		return ValidationResult.failure("Not your mech", {"mech_id": mech_id})
	
	# 3. Verificar que no está destruido
	if mech.get("is_destroyed", false):
		return ValidationResult.failure("Mech is destroyed")
	
	# 4. Verificar facing válido (0-5)
	if new_facing < MIN_FACING or new_facing > MAX_FACING:
		return ValidationResult.failure("Invalid facing", {
			"facing": new_facing,
			"valid_range": "0-5"
		})
	
	# 5. Calcular coste de rotación
	var current_facing: int = mech.get("facing", 0)
	var rotation_cost: int = _calculate_rotation_cost(current_facing, new_facing)
	var remaining_mp: int = mech.get("current_movement", 0)
	
	# 6. Verificar MPs suficientes
	if rotation_cost > remaining_mp:
		return ValidationResult.failure("Insufficient MPs for rotation", {
			"rotation_cost": rotation_cost,
			"remaining_mp": remaining_mp
		})
	
	return ValidationResult.success()


# ============================================================
# WEAPON ATTACK VALIDATION
# ============================================================

## Validates a weapon attack action
static func validate_weapon_attack(
	match_data: Dictionary,
	attacker_id: int,
	target_id: int,
	weapon_indices: Array,
	peer_id: int,
	terrain_data: Dictionary = {}
) -> ValidationResult:
	
	# 1. Verificar fase correcta
	if match_data["current_phase"] != "weapon_attack":
		return ValidationResult.failure("Not weapon attack phase", {
			"current_phase": match_data["current_phase"]
		})
	
	# 2. Verificar que el atacante existe
	if not match_data["mechs"].has(attacker_id):
		return ValidationResult.failure("Attacker not found", {"attacker_id": attacker_id})
	
	var attacker: Dictionary = match_data["mechs"][attacker_id]
	
	# 3. Verificar propiedad del atacante
	if attacker["owner_peer"] != peer_id:
		return ValidationResult.failure("Not your mech", {"attacker_id": attacker_id})
	
	# 3b. Verificar orden de activacion
	var activation_check: ValidationResult = _validate_activation_order(match_data, attacker_id)
	if not activation_check.valid:
		return activation_check
	
	# 4. Verificar que el atacante no está destruido
	if attacker.get("is_destroyed", false):
		return ValidationResult.failure("Attacker is destroyed")
	
	# 5. Verificar que el atacante no está en shutdown
	if attacker.get("is_shutdown", false):
		return ValidationResult.failure("Attacker is shutdown")
	
	# 6. Verificar que no ha disparado este turno
	if attacker.get("fired_this_turn", false):
		return ValidationResult.failure("Already fired this turn")
	
	# 7. Verificar que el objetivo existe
	if not match_data["mechs"].has(target_id):
		return ValidationResult.failure("Target not found", {"target_id": target_id})
	
	var target: Dictionary = match_data["mechs"][target_id]
	
	# 8. Verificar que el objetivo no está destruido
	if target.get("is_destroyed", false):
		return ValidationResult.failure("Target is already destroyed")
	
	# 9. Verificar que no es fuego amigo
	if attacker["team"] == target["team"]:
		return ValidationResult.failure("Cannot attack ally", {
			"attacker_team": attacker["team"],
			"target_team": target["team"]
		})
	
	# 10. Validar índices de armas
	var weapons_check = _validate_weapon_indices(attacker, weapon_indices)
	if not weapons_check.valid:
		return weapons_check
	
	# 11. Calcular y verificar rango
	var attacker_pos: Vector2i = attacker["hex_position"]
	var target_pos: Vector2i = target["hex_position"]
	var range_hexes: int = _hex_distance(attacker_pos, target_pos)
	
	# 12. Verificar que al menos un arma está en rango
	var range_check = _validate_weapons_in_range(attacker, weapon_indices, range_hexes)
	if not range_check.valid:
		return range_check
	
	# 13. Verificar LOS (Line of Sight) si tenemos datos de terreno
	if not terrain_data.is_empty():
		var los_check = _validate_line_of_sight(attacker_pos, target_pos, terrain_data)
		if not los_check.valid:
			return los_check
	
	# 14. Verificar munición para armas que la requieren
	var ammo_check = _validate_ammunition(attacker, weapon_indices)
	if not ammo_check.valid:
		return ammo_check
	
	return ValidationResult.success()


## Validates a physical attack action
static func validate_physical_attack(
	match_data: Dictionary,
	attacker_id: int,
	target_id: int,
	attack_type: String,
	peer_id: int
) -> ValidationResult:
	
	# 1. Verificar fase correcta
	if match_data["current_phase"] != "physical_attack":
		return ValidationResult.failure("Not physical attack phase", {
			"current_phase": match_data["current_phase"]
		})
	
	# 2. Verificar que el atacante existe
	if not match_data["mechs"].has(attacker_id):
		return ValidationResult.failure("Attacker not found")
	
	var attacker: Dictionary = match_data["mechs"][attacker_id]
	
	# 3. Verificar propiedad
	if attacker["owner_peer"] != peer_id:
		return ValidationResult.failure("Not your mech")
	
	# 3b. Verificar orden de activacion
	var activation_check: ValidationResult = _validate_activation_order(match_data, attacker_id)
	if not activation_check.valid:
		return activation_check
	
	# 4. Verificar estado del atacante
	if attacker.get("is_destroyed", false):
		return ValidationResult.failure("Attacker is destroyed")
	
	if attacker.get("is_shutdown", false):
		return ValidationResult.failure("Attacker is shutdown")
	
	if attacker.get("is_prone", false):
		return ValidationResult.failure("Cannot attack while prone")
	
	# 5. Verificar tipo de ataque válido
	var valid_attack_types: Array = ["punch_left", "punch_right", "kick", "charge", "dfa"]
	if attack_type not in valid_attack_types:
		return ValidationResult.failure("Invalid attack type", {
			"type": attack_type,
			"valid_types": valid_attack_types
		})
	
	# 6. Verificar que el objetivo existe
	if not match_data["mechs"].has(target_id):
		return ValidationResult.failure("Target not found")
	
	var target: Dictionary = match_data["mechs"][target_id]
	
	# 7. Verificar estado del objetivo
	if target.get("is_destroyed", false):
		return ValidationResult.failure("Target is already destroyed")
	
	# 8. Verificar que no es fuego amigo
	if attacker["team"] == target["team"]:
		return ValidationResult.failure("Cannot attack ally")
	
	# 9. Verificar distancia (adyacente para punch/kick, rango para charge/DFA)
	var attacker_pos: Vector2i = attacker["hex_position"]
	var target_pos: Vector2i = target["hex_position"]
	var distance: int = _hex_distance(attacker_pos, target_pos)
	
	match attack_type:
		"punch_left", "punch_right", "kick":
			if distance > 1:
				return ValidationResult.failure("Target too far for physical attack", {
					"distance": distance,
					"max_range": 1
				})
		"charge":
			# Charge requiere haber corrido hacia el objetivo
			if distance > 1:
				return ValidationResult.failure("Must end movement adjacent for charge")
		"dfa":
			# Death From Above requiere salto y aterrizar en el objetivo
			if distance > 1:
				return ValidationResult.failure("Must jump onto target for DFA")
	
	# 10. Verificar que los brazos/piernas no están destruidos
	var limb_check = _validate_attack_limbs(attacker, attack_type)
	if not limb_check.valid:
		return limb_check
	
	return ValidationResult.success()


# ============================================================
# END ACTIVATION VALIDATION
# ============================================================

## Validates a "end activation" request: the mech must exist, belong to
## the requesting peer, and - crucially - be the unit actually at the
## front of the activation queue. Without this last check any client
## could end any of its own mechs' "activation" at any time and force
## advance match_data["current_unit_index"], effectively skipping the
## opponent's turn to activate their own unit.
static func validate_end_activation(match_data: Dictionary, mech_id: int, peer_id: int) -> ValidationResult:
	if not match_data["mechs"].has(mech_id):
		return ValidationResult.failure("Mech not found", {"mech_id": mech_id})

	var mech: Dictionary = match_data["mechs"][mech_id]
	if mech["owner_peer"] != peer_id:
		return ValidationResult.failure("Not your mech", {"mech_id": mech_id})

	return _validate_activation_order(match_data, mech_id)


# ============================================================
# DEPLOYMENT VALIDATION
# ============================================================

## Validates mech deployment
static func validate_deployment(
	match_data: Dictionary,
	peer_id: int,
	hex_pos: Vector2i,
	team: String,
	mech_data: Dictionary
) -> ValidationResult:
	
	# 1. Verificar fase de deployment
	if match_data["current_phase"] != "deployment":
		return ValidationResult.failure("Not deployment phase", {
			"current_phase": match_data["current_phase"]
		})
	
	# 2. Verificar que el peer es participante
	var is_player1: bool = peer_id == match_data["player1_peer"]
	var is_player2: bool = peer_id == match_data["player2_peer"]
	
	if not is_player1 and not is_player2:
		return ValidationResult.failure("Not a match participant")
	
	# 3. Verificar zona de deployment válida
	if not _is_valid_deployment_zone(hex_pos, team):
		return ValidationResult.failure("Invalid deployment zone", {
			"hex": [hex_pos.x, hex_pos.y],
			"team": team,
			"expected_zone": "y >= 13" if team == "player" else "y < 5"
		})
	
	# 4. Verificar que el hex no está ocupado
	var occupation_check = _validate_hex_not_occupied_for_deploy(hex_pos, match_data)
	if not occupation_check.valid:
		return occupation_check
	
	# 5. Validar datos del mech (prevenir valores exploits)
	var mech_check = _validate_mech_data(mech_data)
	if not mech_check.valid:
		return mech_check
	
	return ValidationResult.success()


# ============================================================
# HELPER FUNCTIONS - PRIVATE
# ============================================================

## Calcula distancia hexagonal entre dos posiciones
static func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	# Offset coordinates hex distance
	var ac = _offset_to_cube(a)
	var bc = _offset_to_cube(b)
	return (abs(ac.x - bc.x) + abs(ac.y - bc.y) + abs(ac.z - bc.z)) / 2


## Convierte offset coordinates a cube coordinates
static func _offset_to_cube(hex: Vector2i) -> Vector3i:
	@warning_ignore("integer_division")
	var x: int = hex.x - (hex.y - (hex.y & 1)) / 2
	var z: int = hex.y
	var y: int = -x - z
	return Vector3i(x, y, z)


## Obtiene MPs máximos según tipo de movimiento
static func _get_max_movement_points(mech: Dictionary, movement_type: int) -> int:
	match movement_type:
		MOVEMENT_WALK:
			return mech.get("walk_mp", 4)
		MOVEMENT_RUN:
			return mech.get("run_mp", 6)
		MOVEMENT_JUMP:
			return mech.get("jump_mp", 0)
	return 0


## Calcula coste de rotación entre dos facings
static func _calculate_rotation_cost(from_facing: int, to_facing: int) -> int:
	var diff: int = (to_facing - from_facing + 6) % 6
	return mini(diff, 6 - diff)


## Valida que el hex está dentro del mapa
static func _validate_hex_bounds(hex: Vector2i, terrain_data: Dictionary) -> ValidationResult:
	# Si no tenemos datos de terreno, asumir válido pero con límites razonables
	if terrain_data.is_empty():
		if hex.x < 0 or hex.y < 0 or hex.x > 50 or hex.y > 50:
			return ValidationResult.failure("Hex out of bounds", {
				"hex": [hex.x, hex.y]
			})
		return ValidationResult.success()
	
	# Con datos de terreno, verificar si existe el hex
	if terrain_data.has("map_width") and terrain_data.has("map_height"):
		if hex.x < 0 or hex.y < 0:
			return ValidationResult.failure("Hex out of bounds (negative)")
		if hex.x >= terrain_data["map_width"] or hex.y >= terrain_data["map_height"]:
			return ValidationResult.failure("Hex out of bounds", {
				"hex": [hex.x, hex.y],
				"map_size": [terrain_data["map_width"], terrain_data["map_height"]]
			})
	
	return ValidationResult.success()


## Valida que el hex no está ocupado por otra unidad
static func _validate_hex_not_occupied(hex: Vector2i, mech_id: int, match_data: Dictionary) -> ValidationResult:
	for other_id in match_data["mechs"]:
		if other_id == mech_id:
			continue
		
		var other_mech: Dictionary = match_data["mechs"][other_id]
		if other_mech.get("is_destroyed", false):
			continue
		
		if other_mech["hex_position"] == hex:
			return ValidationResult.failure("Hex occupied", {
				"hex": [hex.x, hex.y],
				"occupant": other_mech.get("name", "Unknown")
			})
	
	return ValidationResult.success()


## Valida hex no ocupado para deployment
static func _validate_hex_not_occupied_for_deploy(hex: Vector2i, match_data: Dictionary) -> ValidationResult:
	for mech_id in match_data["mechs"]:
		var mech: Dictionary = match_data["mechs"][mech_id]
		if mech["hex_position"] == hex:
			return ValidationResult.failure("Hex already occupied", {
				"hex": [hex.x, hex.y]
			})
	
	return ValidationResult.success()


## Valida terreno transitable
static func _validate_terrain_passable(hex: Vector2i, movement_type: int, terrain_data: Dictionary) -> ValidationResult:
	if not terrain_data.has("hexes"):
		return ValidationResult.success()  # Sin datos, asumir válido
	
	var hex_key: String = str(hex.x) + "," + str(hex.y)
	if not terrain_data["hexes"].has(hex_key):
		return ValidationResult.success()
	
	var hex_info: Dictionary = terrain_data["hexes"][hex_key]
	
	# Verificar si es transitable
	if hex_info.has("walkable") and not hex_info["walkable"]:
		return ValidationResult.failure("Terrain impassable", {
			"hex": [hex.x, hex.y],
			"terrain": hex_info.get("terrain", "unknown")
		})
	
	# Agua profunda no es transitable caminando/corriendo
	if hex_info.has("water_depth") and hex_info["water_depth"] >= 2:
		if movement_type != MOVEMENT_JUMP:
			return ValidationResult.failure("Deep water - must jump", {
				"hex": [hex.x, hex.y],
				"water_depth": hex_info["water_depth"]
			})
	
	return ValidationResult.success()


## Valida Zone of Control (no se puede correr saliendo de ZoC)
static func _validate_zone_of_control(from_hex: Vector2i, _to_hex: Vector2i, mech: Dictionary, match_data: Dictionary) -> ValidationResult:
	# Verificar si hay enemigos adyacentes al hex origen
	var enemy_team: String = "enemy" if mech["team"] == "player" else "player"
	
	for other_id in match_data["mechs"]:
		var other_mech: Dictionary = match_data["mechs"][other_id]
		
		if other_mech["team"] != enemy_team:
			continue
		
		if other_mech.get("is_destroyed", false):
			continue
		
		# Verificar adyacencia al hex de origen
		var distance_from_origin: int = _hex_distance(from_hex, other_mech["hex_position"])
		if distance_from_origin == 1:
			# Hay un enemigo en ZoC - no se puede correr
			return ValidationResult.failure("Cannot run while in Zone of Control", {
				"enemy_mech": other_mech.get("name", "Unknown"),
				"enemy_pos": [other_mech["hex_position"].x, other_mech["hex_position"].y]
			})
	
	return ValidationResult.success()


## Valida índices de armas
static func _validate_weapon_indices(attacker: Dictionary, weapon_indices: Array) -> ValidationResult:
	if weapon_indices.is_empty():
		return ValidationResult.failure("No weapons selected")
	
	if weapon_indices.size() > MAX_WEAPONS_PER_SALVO:
		return ValidationResult.failure("Too many weapons selected", {
			"selected": weapon_indices.size(),
			"max": MAX_WEAPONS_PER_SALVO
		})
	
	var weapons: Array = attacker.get("weapons", [])
	
	for idx in weapon_indices:
		if typeof(idx) != TYPE_INT:
			return ValidationResult.failure("Invalid weapon index type")
		
		if idx < 0 or idx >= weapons.size():
			return ValidationResult.failure("Weapon index out of range", {
				"index": idx,
				"weapon_count": weapons.size()
			})
	
	return ValidationResult.success()


## Valida que las armas están en rango
static func _validate_weapons_in_range(attacker: Dictionary, weapon_indices: Array, range_hexes: int) -> ValidationResult:
	var weapons: Array = attacker.get("weapons", [])
	var any_in_range: bool = false
	
	for idx in weapon_indices:
		var weapon: Dictionary = weapons[idx]
		var max_range: int = weapon.get("range_long", weapon.get("range", 9))
		
		if range_hexes <= max_range:
			any_in_range = true
			break
	
	if not any_in_range:
		return ValidationResult.failure("All weapons out of range", {
			"target_range": range_hexes
		})
	
	return ValidationResult.success()


## Valida línea de visión (simplificada para servidor)
static func _validate_line_of_sight(from_hex: Vector2i, to_hex: Vector2i, terrain_data: Dictionary) -> ValidationResult:
	# Implementación simplificada - el servidor verifica bloqueos básicos
	# El sistema completo de LOS está en scripts/core/combat/line_of_sight.gd
	
	if not terrain_data.has("hexes"):
		return ValidationResult.success()
	
	# Obtener hexes en la línea (simplificado)
	var line_hexes: Array = _get_line_hexes(from_hex, to_hex)
	
	for hex in line_hexes:
		var hex_key: String = str(hex.x) + "," + str(hex.y)
		if not terrain_data["hexes"].has(hex_key):
			continue
		
		var hex_info: Dictionary = terrain_data["hexes"][hex_key]
		
		# Verificar bloqueos mayores (edificios altos, montañas)
		if hex_info.has("blocks_los") and hex_info["blocks_los"]:
			return ValidationResult.failure("Line of sight blocked", {
				"blocking_hex": [hex.x, hex.y],
				"terrain": hex_info.get("terrain", "unknown")
			})
	
	return ValidationResult.success()


## Obtiene hexes en línea recta (Bresenham para hex)
static func _get_line_hexes(from: Vector2i, to: Vector2i) -> Array:
	var hexes: Array = []
	var n: int = _hex_distance(from, to)
	
	if n == 0:
		return hexes
	
	for i in range(1, n):
		var t: float = float(i) / float(n)
		var lerp_x: int = roundi(lerp(float(from.x), float(to.x), t))
		var lerp_y: int = roundi(lerp(float(from.y), float(to.y), t))
		var hex: Vector2i = Vector2i(lerp_x, lerp_y)
		
		if hex != from and hex != to and not hexes.has(hex):
			hexes.append(hex)
	
	return hexes


## Valida munición disponible
static func _validate_ammunition(attacker: Dictionary, weapon_indices: Array) -> ValidationResult:
	var weapons: Array = attacker.get("weapons", [])
	
	for idx in weapon_indices:
		var weapon: Dictionary = weapons[idx]
		
		# Solo verificar armas que usan munición
		if weapon.get("uses_ammo", false):
			var current_ammo: int = weapon.get("current_ammo", 0)
			if current_ammo <= 0:
				return ValidationResult.failure("No ammunition", {
					"weapon": weapon.get("name", "Unknown"),
					"ammo": current_ammo
				})
	
	return ValidationResult.success()


## Valida zona de deployment
static func _is_valid_deployment_zone(hex: Vector2i, team: String) -> bool:
	# Player: sur (últimas 5 filas, y >= 13)
	# Enemy: norte (primeras 5 filas, y < 5)
	if team == "player":
		return hex.y >= 13
	else:
		return hex.y < 5


## Valida datos del mech (anti-exploit)
static func _validate_mech_data(mech_data: Dictionary) -> ValidationResult:
	# Verificar valores razonables para prevenir exploits
	
	var walk_mp: int = mech_data.get("walk_mp", 0)
	if walk_mp < 0 or walk_mp > MAX_MOVEMENT_POINTS:
		return ValidationResult.failure("Invalid walk_mp", {"value": walk_mp})
	
	var run_mp: int = mech_data.get("run_mp", 0)
	if run_mp < 0 or run_mp > MAX_MOVEMENT_POINTS:
		return ValidationResult.failure("Invalid run_mp", {"value": run_mp})
	
	var jump_mp: int = mech_data.get("jump_mp", 0)
	if jump_mp < 0 or jump_mp > MAX_JUMP_POINTS:
		return ValidationResult.failure("Invalid jump_mp", {"value": jump_mp})
	
	var tonnage: int = mech_data.get("tonnage", 0)
	if tonnage < 20 or tonnage > 100:
		return ValidationResult.failure("Invalid tonnage", {"value": tonnage})
	
	return ValidationResult.success()


## Valida que el mech tiene las extremidades para el ataque físico
static func _validate_attack_limbs(attacker: Dictionary, attack_type: String) -> ValidationResult:
	var armor: Dictionary = attacker.get("armor", {})
	
	match attack_type:
		"punch_left":
			if armor.has("left_arm"):
				var arm_armor: Dictionary = armor["left_arm"]
				if arm_armor.get("current", 0) <= 0 and arm_armor.get("structure", 1) <= 0:
					return ValidationResult.failure("Left arm destroyed")
		
		"punch_right":
			if armor.has("right_arm"):
				var arm_armor: Dictionary = armor["right_arm"]
				if arm_armor.get("current", 0) <= 0 and arm_armor.get("structure", 1) <= 0:
					return ValidationResult.failure("Right arm destroyed")
		
		"kick":
			# Verificar al menos una pierna funcional
			var left_ok: bool = true
			var right_ok: bool = true
			
			if armor.has("left_leg"):
				var leg: Dictionary = armor["left_leg"]
				if leg.get("current", 0) <= 0 and leg.get("structure", 1) <= 0:
					left_ok = false
			
			if armor.has("right_leg"):
				var leg: Dictionary = armor["right_leg"]
				if leg.get("current", 0) <= 0 and leg.get("structure", 1) <= 0:
					right_ok = false
			
			if not left_ok and not right_ok:
				return ValidationResult.failure("Both legs destroyed")
	
	return ValidationResult.success()
