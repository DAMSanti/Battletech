extends RefCounted
class_name BattleState

## BattleState - Estado compartido de la batalla
## Este objeto contiene todo el estado de la batalla y puede ser serializado
## para sincronización en multiplayer

# ============================================================
# ESTADO DE MECHS
# ============================================================

## Diccionario de mechs: mech_id -> MechState
var mechs: Dictionary = {}

## Listas de IDs por equipo para acceso rápido
var team_mechs: Dictionary = {
	"player": [],
	"enemy": []
}

# ============================================================
# ESTADO DE LA PARTIDA
# ============================================================

var current_turn: int = 1
var turn_number: int = 0  # Alias para compatibilidad con BattleController
var current_phase: int = GameEnums.TurnPhase.DEPLOYMENT
var initiative_winner: String = ""  # "player" o "enemy"
var activation_order: Array = []  # Array de mech_ids en orden de activación
var current_activation_index: int = 0
var deployment_complete: Dictionary = {"player": false, "enemy": false}

# Semilla RNG para reproducibilidad
var rng_seed: int = 0

# Tamaño del mapa
var map_size: Vector2i = Vector2i(18, 18)

# Equipos activos
var teams: Array = ["player", "enemy"]

# Equipo activo actualmente
var active_team: String = ""

# ID de la unidad activa
var active_unit_id: String = ""

# Orden de turnos
var turn_order: Array = []

# Resultados de iniciativa
var initiative_rolls: Dictionary = {}

# ============================================================
# ZONAS DE DESPLIEGUE
# ============================================================

var deployment_zones: Dictionary = {
	"player": [],  # Array de Vector2i
	"enemy": []
}

# ============================================================
# CLASE INTERNA: Estado de un Mech
# ============================================================

class MechState:
	var id: String = ""  # ID único del mech (String para compatibilidad)
	var name: String = ""
	var team: String = ""  # "player" o "enemy"
	var pilot_name: String = ""
	var tonnage: int = 50
	
	# Posición y orientación
	var hex_position: Vector2i = Vector2i(-1, -1)
	var position: Vector2i = Vector2i(-1, -1)  # Alias para hex_position
	var facing: int = 0  # 0-5
	var is_deployed: bool = false
	
	# Info adicional
	var chassis: String = ""
	var variant: String = ""
	
	# Movimiento
	var walk_mp: int = 4
	var run_mp: int = 6
	var jump_mp: int = 0
	var current_mp: int = 4
	var movement_type_used: int = GameEnums.MovementType.NONE
	var hexes_moved: int = 0
	var has_moved: bool = false
	
	# Combate
	var pilot_gunnery: int = 4
	var pilot_piloting: int = 5
	var initiative: int = 0
	var has_attacked: bool = false
	
	# Armadura y Estructura
	var max_armor: Dictionary = {}
	var current_armor: Dictionary = {}
	var max_structure: Dictionary = {}
	var current_structure: Dictionary = {}
	var armor: Dictionary = {}  # Legacy alias
	var internal_structure: Dictionary = {}  # Legacy alias
	var weapons: Array = []
	
	# Calor
	var heat: int = 0
	var current_heat: int = 0
	var heat_capacity: int = 30
	var heat_dissipation: int = 10
	var heat_sinks: int = 10
	
	# Estado
	var is_active: bool = true
	var is_destroyed: bool = false
	var is_shutdown: bool = false
	var is_prone: bool = false
	var has_fired: bool = false
	var has_physical_attacked: bool = false
	
	func _init():
		# Inicializar armadura por defecto
		armor = {
			"head": 9,
			"center_torso": 30,
			"center_torso_rear": 10,
			"left_torso": 20,
			"left_torso_rear": 8,
			"right_torso": 20,
			"right_torso_rear": 8,
			"left_arm": 16,
			"right_arm": 16,
			"left_leg": 20,
			"right_leg": 20
		}
		internal_structure = {
			"head": 3,
			"center_torso": 20,
			"left_torso": 14,
			"right_torso": 14,
			"left_arm": 10,
			"right_arm": 10,
			"left_leg": 14,
			"right_leg": 14
		}
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"team": team,
			"pilot_name": pilot_name,
			"tonnage": tonnage,
			"hex_position": [hex_position.x, hex_position.y],
			"facing": facing,
			"is_deployed": is_deployed,
			"walk_mp": walk_mp,
			"run_mp": run_mp,
			"jump_mp": jump_mp,
			"current_mp": current_mp,
			"movement_type_used": movement_type_used,
			"hexes_moved": hexes_moved,
			"pilot_gunnery": pilot_gunnery,
			"pilot_piloting": pilot_piloting,
			"initiative": initiative,
			"armor": armor.duplicate(true),
			"internal_structure": internal_structure.duplicate(true),
			"weapons": weapons.duplicate(true),
			"heat": heat,
			"heat_capacity": heat_capacity,
			"heat_dissipation": heat_dissipation,
			"is_destroyed": is_destroyed,
			"is_shutdown": is_shutdown,
			"is_prone": is_prone,
			"has_fired": has_fired,
			"has_physical_attacked": has_physical_attacked,
			"has_moved": has_moved
		}
	
	static func from_dict(data: Dictionary) -> MechState:
		var state = MechState.new()
		state.id = data.get("id", -1)
		state.name = data.get("name", "Unknown")
		state.team = data.get("team", "player")
		state.pilot_name = data.get("pilot_name", "Pilot")
		state.tonnage = data.get("tonnage", 50)
		
		var pos = data.get("hex_position", [-1, -1])
		if pos is Array:
			state.hex_position = Vector2i(pos[0], pos[1])
		elif pos is Vector2i:
			state.hex_position = pos
		
		state.facing = data.get("facing", 0)
		state.is_deployed = data.get("is_deployed", false)
		state.walk_mp = data.get("walk_mp", 4)
		state.run_mp = data.get("run_mp", 6)
		state.jump_mp = data.get("jump_mp", 0)
		state.current_mp = data.get("current_mp", state.walk_mp)
		state.movement_type_used = data.get("movement_type_used", GameEnums.MovementType.NONE)
		state.hexes_moved = data.get("hexes_moved", 0)
		state.pilot_gunnery = data.get("pilot_gunnery", 4)
		state.pilot_piloting = data.get("pilot_piloting", 5)
		state.initiative = data.get("initiative", 0)
		
		if data.has("armor"):
			state.armor = data["armor"].duplicate(true)
		if data.has("internal_structure"):
			state.internal_structure = data["internal_structure"].duplicate(true)
		if data.has("weapons"):
			state.weapons = data["weapons"].duplicate(true)
		
		state.heat = data.get("heat", 0)
		state.heat_capacity = data.get("heat_capacity", 30)
		state.heat_dissipation = data.get("heat_dissipation", 10)
		state.is_destroyed = data.get("is_destroyed", false)
		state.is_shutdown = data.get("is_shutdown", false)
		state.is_prone = data.get("is_prone", false)
		state.has_fired = data.get("has_fired", false)
		state.has_physical_attacked = data.get("has_physical_attacked", false)
		state.has_moved = data.get("has_moved", false)
		
		return state
	
	func reset_for_new_turn():
		"""Resetea el estado para un nuevo turno"""
		current_mp = walk_mp
		movement_type_used = GameEnums.MovementType.NONE
		hexes_moved = 0
		has_fired = false
		has_physical_attacked = false
		has_moved = false

# ============================================================
# MÉTODOS DE GESTIÓN DE MECHS
# ============================================================

func add_mech(mech_state: MechState) -> void:
	mechs[mech_state.id] = mech_state
	if not team_mechs.has(mech_state.team):
		team_mechs[mech_state.team] = []
	team_mechs[mech_state.team].append(mech_state.id)

func get_mech(mech_id: String) -> MechState:
	return mechs.get(mech_id, null)

func get_mechs_for_team(team: String) -> Array:
	var result = []
	for mech_id in team_mechs.get(team, []):
		if mechs.has(mech_id):
			result.append(mechs[mech_id])
	return result

func get_team_mechs(team: String) -> Array:
	return get_mechs_for_team(team)

func get_active_mechs(team: String = "") -> Array:
	"""Retorna mechs que no están destruidos"""
	var result = []
	for mech_id in mechs:
		var mech = mechs[mech_id]
		if not mech.is_destroyed and mech.is_active:
			if team == "" or mech.team == team:
				result.append(mech)
	return result

func all_mechs_deployed() -> bool:
	"""Verifica si todos los mechs están desplegados"""
	for mech in mechs.values():
		if not mech.is_deployed:
			return false
	return mechs.size() > 0

func get_winning_team() -> String:
	"""Retorna el equipo ganador o cadena vacía si no hay ganador"""
	var player_alive = false
	var enemy_alive = false
	
	for mech in mechs.values():
		if mech.is_active and not mech.is_destroyed:
			if mech.team == "player":
				player_alive = true
			else:
				enemy_alive = true
	
	if not player_alive and enemy_alive:
		return "enemy"
	elif player_alive and not enemy_alive:
		return "player"
	return ""

func get_mech_at_hex(hex: Vector2i) -> MechState:
	"""Busca un mech en una posición específica"""
	for mech_id in mechs:
		var mech = mechs[mech_id]
		if mech.hex_position == hex and mech.is_deployed and not mech.is_destroyed:
			return mech
	return null

# ============================================================
# MÉTODOS DE FASE
# ============================================================

func is_deployment_complete() -> bool:
	return deployment_complete["player"] and deployment_complete["enemy"]

func mark_deployment_complete(team: String):
	deployment_complete[team] = true

func get_undeployed_mechs(team: String) -> Array:
	var result = []
	for mech_id in team_mechs.get(team, []):
		var mech = mechs.get(mech_id)
		if mech and not mech.is_deployed:
			result.append(mech)
	return result

func get_current_mech() -> MechState:
	"""Retorna el mech que está siendo activado actualmente"""
	if current_activation_index >= 0 and current_activation_index < activation_order.size():
		var mech_id = activation_order[current_activation_index]
		return mechs.get(mech_id, null)
	return null

func advance_activation() -> MechState:
	"""Avanza al siguiente mech en el orden de activación"""
	current_activation_index += 1
	return get_current_mech()

func reset_activation_order():
	"""Resetea el orden de activación para una nueva fase"""
	current_activation_index = 0

# ============================================================
# SERIALIZACIÓN
# ============================================================

func to_dict() -> Dictionary:
	var mechs_data = {}
	for mech_id in mechs:
		mechs_data[mech_id] = mechs[mech_id].to_dict()
	
	return {
		"mechs": mechs_data,
		"team_mechs": team_mechs.duplicate(true),
		"current_turn": current_turn,
		"current_phase": current_phase,
		"initiative_winner": initiative_winner,
		"activation_order": activation_order.duplicate(),
		"current_activation_index": current_activation_index,
		"deployment_complete": deployment_complete.duplicate(),
		"deployment_zones": {
			"player": _serialize_vector2i_array(deployment_zones["player"]),
			"enemy": _serialize_vector2i_array(deployment_zones["enemy"])
		}
	}

static func from_dict(data: Dictionary) -> BattleState:
	var state = BattleState.new()
	
	# Cargar mechs
	var mechs_data = data.get("mechs", {})
	for mech_id in mechs_data:
		var mech_state = MechState.from_dict(mechs_data[mech_id])
		state.mechs[int(mech_id)] = mech_state
	
	state.team_mechs = data.get("team_mechs", {"player": [], "enemy": []})
	state.current_turn = data.get("current_turn", 1)
	state.current_phase = data.get("current_phase", GameEnums.TurnPhase.DEPLOYMENT)
	state.initiative_winner = data.get("initiative_winner", "")
	state.activation_order = data.get("activation_order", [])
	state.current_activation_index = data.get("current_activation_index", 0)
	state.deployment_complete = data.get("deployment_complete", {"player": false, "enemy": false})
	
	# Cargar zonas de despliegue
	var zones = data.get("deployment_zones", {})
	state.deployment_zones["player"] = _deserialize_vector2i_array(zones.get("player", []))
	state.deployment_zones["enemy"] = _deserialize_vector2i_array(zones.get("enemy", []))
	
	return state

static func _serialize_vector2i_array(arr: Array) -> Array:
	var result = []
	for v in arr:
		result.append([v.x, v.y])
	return result

static func _deserialize_vector2i_array(arr: Array) -> Array:
	var result = []
	for v in arr:
		if v is Array and v.size() >= 2:
			result.append(Vector2i(v[0], v[1]))
	return result
