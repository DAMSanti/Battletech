extends Node
class_name ServerBattleManager

## ServerBattleManager - Gestiona las batallas en el servidor dedicado
## El servidor es AUTORITATIVO: valida todas las acciones y ejecuta la lógica

const WeaponAttackSystem = preload("res://scripts/core/combat/weapon_attack_system.gd")
const PhysicalAttackSystem = preload("res://scripts/core/combat/physical_attack_system.gd")
const HeatSystem = preload("res://scripts/core/combat/heat_system.gd")

# Estructura de una partida activa
# match_data = {
#   "match_id": int,
#   "player1_peer": int,
#   "player2_peer": int,
#   "current_turn": int,
#   "current_phase": String,
#   "initiative_winner": String,
#   "mechs": { mech_id: MechData },
#   "units_to_activate": Array,
#   "current_unit_index": int
# }

var active_battles: Dictionary = {}  # match_id -> match_data
var network_manager: Node = null

func _ready():
	# Obtener referencia al NetworkManager (será el padre o un sibling)
	await get_tree().process_frame
	network_manager = get_node_or_null("/root/NetworkManager")
	if not network_manager:
		network_manager = get_parent().get_node_or_null("NetworkManager")

# ============================================================
# INICIALIZACIÓN DE PARTIDA
# ============================================================

func start_match(player1_peer: int, player2_peer: int):
	"""Inicia una nueva partida entre dos jugadores"""
	var match_id = _generate_match_id(player1_peer, player2_peer)
	
	var match_data = {
		"match_id": match_id,
		"player1_peer": player1_peer,
		"player2_peer": player2_peer,
		"current_turn": 0,
		"current_phase": "deployment",
		"initiative_winner": "",
		"mechs": {},
		"player1_deployed": false,
		"player2_deployed": false,
		"units_to_activate": [],
		"current_unit_index": 0,
		"rng_seed": randi()  # Semilla para reproducibilidad
	}
	
	active_battles[match_id] = match_data
	
	print("[SERVER_BATTLE] Match %d started: Peer %d vs Peer %d" % [match_id, player1_peer, player2_peer])
	
	# Notificar a ambos jugadores que inicien la fase de despliegue
	rpc_id(player1_peer, "client_start_deployment", match_id, "player")
	rpc_id(player2_peer, "client_start_deployment", match_id, "enemy")

func _generate_match_id(peer1: int, peer2: int) -> int:
	return hash(str(peer1) + "_" + str(peer2) + "_" + str(Time.get_ticks_msec()))

# ============================================================
# RPCs - SOLICITUDES DE CLIENTES (Client -> Server)
# ============================================================

@rpc("any_peer", "reliable")
func server_request_deploy_mech(match_id: int, mech_data: Dictionary, hex_pos: Array, facing: int):
	"""Cliente solicita desplegar un mech"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	var team = _get_team_for_peer(match_data, sender_id)
	var hex = Vector2i(hex_pos[0], hex_pos[1])
	
	# Validar zona de despliegue
	if not _is_valid_deployment_hex(hex, team):
		rpc_id(sender_id, "client_action_rejected", "Invalid deployment zone")
		return
	
	# Crear mech en el servidor
	var mech_id = _generate_mech_id(match_id, team)
	var server_mech = {
		"id": mech_id,
		"owner_peer": sender_id,
		"team": team,
		"name": mech_data.get("name", "Unknown"),
		"tonnage": mech_data.get("tonnage", 50),
		"hex_position": hex,
		"facing": facing,
		"walk_mp": mech_data.get("walk_mp", 4),
		"run_mp": mech_data.get("run_mp", 6),
		"jump_mp": mech_data.get("jump_mp", 0),
		"current_movement": mech_data.get("walk_mp", 4),
		"heat": 0,
		"heat_capacity": mech_data.get("heat_capacity", 30),
		"heat_dissipation": mech_data.get("heat_dissipation", 10),
		"armor": mech_data.get("armor", {}).duplicate(true),
		"weapons": mech_data.get("weapons", []).duplicate(true),
		"is_destroyed": false,
		"is_prone": false,
		"is_shutdown": false,
		"moved_this_turn": false,
		"fired_this_turn": false,
		"movement_type_used": 0,
		"hexes_moved": 0
	}
	
	match_data["mechs"][mech_id] = server_mech
	
	# Marcar como desplegado
	if team == "player":
		match_data["player1_deployed"] = true
	else:
		match_data["player2_deployed"] = true
	
	print("[SERVER_BATTLE] Mech deployed: %s at [%d,%d] facing %d" % [server_mech["name"], hex.x, hex.y, facing])
	
	# Notificar a ambos jugadores
	var opponent_peer = _get_opponent_peer(match_data, sender_id)
	rpc_id(sender_id, "client_mech_deployed", mech_id, mech_data, [hex.x, hex.y], facing, team)
	rpc_id(opponent_peer, "client_mech_deployed", mech_id, mech_data, [hex.x, hex.y], facing, team)
	
	# Verificar si ambos desplegaron
	if match_data["player1_deployed"] and match_data["player2_deployed"]:
		_start_initiative_phase(match_id)

@rpc("any_peer", "reliable")
func server_request_move(match_id: int, mech_id: int, target_hex: Array, movement_type: int):
	"""Cliente solicita mover un mech"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	# Validar que el mech pertenece al jugador
	if not _validate_mech_ownership(match_data, mech_id, sender_id):
		rpc_id(sender_id, "client_action_rejected", "Not your mech")
		return
	
	# Validar fase
	if match_data["current_phase"] != "movement":
		rpc_id(sender_id, "client_action_rejected", "Not movement phase")
		return
	
	var mech = match_data["mechs"][mech_id]
	var hex = Vector2i(target_hex[0], target_hex[1])
	
	# Validar movimiento (MPs, camino válido, etc.)
	var max_mp = _get_max_movement(mech, movement_type)
	var current_pos = mech["hex_position"]
	var distance = _hex_distance(current_pos, hex)
	
	if distance > max_mp:
		rpc_id(sender_id, "client_action_rejected", "Insufficient movement points")
		return
	
	# Ejecutar movimiento en el servidor
	var old_pos = mech["hex_position"]
	mech["hex_position"] = hex
	mech["moved_this_turn"] = true
	mech["movement_type_used"] = movement_type
	mech["hexes_moved"] = distance
	mech["current_movement"] = max_mp - distance
	
	print("[SERVER_BATTLE] Mech %s moved from [%d,%d] to [%d,%d]" % [
		mech["name"], old_pos.x, old_pos.y, hex.x, hex.y
	])
	
	# Calcular calor por movimiento
	var movement_heat = 0
	if movement_type == 2:  # Run
		movement_heat = 2
	elif movement_type == 3:  # Jump
		movement_heat = distance
	
	mech["heat"] += movement_heat
	
	# Broadcast a ambos jugadores
	var opponent_peer = _get_opponent_peer(match_data, sender_id)
	var move_result = {
		"mech_id": mech_id,
		"from_hex": [old_pos.x, old_pos.y],
		"to_hex": [hex.x, hex.y],
		"movement_type": movement_type,
		"movement_heat": movement_heat,
		"remaining_mp": mech["current_movement"]
	}
	
	rpc_id(sender_id, "client_mech_moved", move_result)
	rpc_id(opponent_peer, "client_mech_moved", move_result)

@rpc("any_peer", "reliable")
func server_request_rotate(match_id: int, mech_id: int, new_facing: int):
	"""Cliente solicita rotar un mech"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	if not _validate_mech_ownership(match_data, mech_id, sender_id):
		rpc_id(sender_id, "client_action_rejected", "Not your mech")
		return
	
	var mech = match_data["mechs"][mech_id]
	var rotations = _calculate_rotations(mech["facing"], new_facing)
	
	if rotations > mech["current_movement"]:
		rpc_id(sender_id, "client_action_rejected", "Insufficient MPs for rotation")
		return
	
	var old_facing = mech["facing"]
	mech["facing"] = new_facing
	mech["current_movement"] -= rotations
	
	# Broadcast
	var opponent_peer = _get_opponent_peer(match_data, sender_id)
	var rotate_result = {
		"mech_id": mech_id,
		"old_facing": old_facing,
		"new_facing": new_facing,
		"mp_cost": rotations,
		"remaining_mp": mech["current_movement"]
	}
	
	rpc_id(sender_id, "client_mech_rotated", rotate_result)
	rpc_id(opponent_peer, "client_mech_rotated", rotate_result)

@rpc("any_peer", "reliable")
func server_request_fire(match_id: int, attacker_id: int, target_id: int, weapon_indices: Array):
	"""Cliente solicita disparar armas"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	if not _validate_mech_ownership(match_data, attacker_id, sender_id):
		rpc_id(sender_id, "client_action_rejected", "Not your mech")
		return
	
	if match_data["current_phase"] != "weapon_attack":
		rpc_id(sender_id, "client_action_rejected", "Not weapon attack phase")
		return
	
	var attacker = match_data["mechs"][attacker_id]
	var target = match_data["mechs"].get(target_id)
	
	if not target:
		rpc_id(sender_id, "client_action_rejected", "Invalid target")
		return
	
	# Verificar que el objetivo es enemigo
	if attacker["team"] == target["team"]:
		rpc_id(sender_id, "client_action_rejected", "Cannot attack ally")
		return
	
	var range_hexes = _hex_distance(attacker["hex_position"], target["hex_position"])
	
	# Ejecutar ataque para cada arma
	var attack_results = []
	var total_heat = 0
	
	for weapon_idx in weapon_indices:
		if weapon_idx >= attacker["weapons"].size():
			continue
		
		var weapon = attacker["weapons"][weapon_idx]
		var result = _execute_weapon_attack(attacker, target, weapon, range_hexes, match_data["rng_seed"])
		attack_results.append(result)
		total_heat += weapon.get("heat", 0)
		
		# Actualizar semilla RNG
		match_data["rng_seed"] = (match_data["rng_seed"] * 1103515245 + 12345) % 2147483648
	
	attacker["heat"] += total_heat
	attacker["fired_this_turn"] = true
	
	# Broadcast resultados
	var opponent_peer = _get_opponent_peer(match_data, sender_id)
	var fire_result = {
		"attacker_id": attacker_id,
		"target_id": target_id,
		"weapon_indices": weapon_indices,
		"results": attack_results,
		"total_heat": total_heat,
		"attacker_heat": attacker["heat"],
		"target_destroyed": target["is_destroyed"]
	}
	
	rpc_id(sender_id, "client_weapons_fired", fire_result)
	rpc_id(opponent_peer, "client_weapons_fired", fire_result)
	
	# Verificar fin de batalla
	if target["is_destroyed"]:
		_check_battle_end(match_id)

@rpc("any_peer", "reliable")
func server_request_physical_attack(match_id: int, attacker_id: int, target_id: int, attack_type: String):
	"""Cliente solicita ataque físico"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	if not _validate_mech_ownership(match_data, attacker_id, sender_id):
		rpc_id(sender_id, "client_action_rejected", "Not your mech")
		return
	
	if match_data["current_phase"] != "physical_attack":
		rpc_id(sender_id, "client_action_rejected", "Not physical attack phase")
		return
	
	var attacker = match_data["mechs"][attacker_id]
	var target = match_data["mechs"].get(target_id)
	
	if not target:
		rpc_id(sender_id, "client_action_rejected", "Invalid target")
		return
	
	var distance = _hex_distance(attacker["hex_position"], target["hex_position"])
	if distance > 1:
		rpc_id(sender_id, "client_action_rejected", "Target too far for physical attack")
		return
	
	# Ejecutar ataque físico
	var result = _execute_physical_attack(attacker, target, attack_type, match_data["rng_seed"])
	match_data["rng_seed"] = (match_data["rng_seed"] * 1103515245 + 12345) % 2147483648
	
	# Broadcast
	var opponent_peer = _get_opponent_peer(match_data, sender_id)
	var attack_result = {
		"attacker_id": attacker_id,
		"target_id": target_id,
		"attack_type": attack_type,
		"result": result,
		"target_destroyed": target["is_destroyed"]
	}
	
	rpc_id(sender_id, "client_physical_attack_result", attack_result)
	rpc_id(opponent_peer, "client_physical_attack_result", attack_result)
	
	if target["is_destroyed"]:
		_check_battle_end(match_id)

@rpc("any_peer", "reliable")
func server_request_end_activation(match_id: int, mech_id: int):
	"""Cliente indica que terminó su activación"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	if not _validate_mech_ownership(match_data, mech_id, sender_id):
		return
	
	_advance_to_next_unit(match_id)

# ============================================================
# RPCs - SERVIDOR -> CLIENTE
# ============================================================

@rpc("authority", "reliable")
func client_start_deployment(_match_id: int, _team: String):
	pass  # Implementado en el cliente

@rpc("authority", "reliable")
func client_mech_deployed(_mech_id: int, _mech_data: Dictionary, _hex_pos: Array, _facing: int, _team: String):
	pass

@rpc("authority", "reliable")
func client_initiative_result(_result: Dictionary):
	pass

@rpc("authority", "reliable")
func client_phase_changed(_phase: String, _turn: int):
	pass

@rpc("authority", "reliable")
func client_unit_activated(_mech_id: int, _is_yours: bool):
	pass

@rpc("authority", "reliable")
func client_mech_moved(_result: Dictionary):
	pass

@rpc("authority", "reliable")
func client_mech_rotated(_result: Dictionary):
	pass

@rpc("authority", "reliable")
func client_weapons_fired(_result: Dictionary):
	pass

@rpc("authority", "reliable")
func client_physical_attack_result(_result: Dictionary):
	pass

@rpc("authority", "reliable")
func client_heat_phase_result(_results: Array):
	pass

@rpc("authority", "reliable")
func client_battle_ended(_winner_team: String, _reason: String):
	pass

@rpc("authority", "reliable")
func client_action_rejected(_reason: String):
	pass

# ============================================================
# LÓGICA DE FASES
# ============================================================

func _start_initiative_phase(match_id: int):
	"""Inicia la fase de iniciativa"""
	var match_data = active_battles[match_id]
	match_data["current_turn"] += 1
	match_data["current_phase"] = "initiative"
	
	# Tirar dados en el servidor
	seed(match_data["rng_seed"])
	var player_dice = [randi() % 6 + 1, randi() % 6 + 1]
	var enemy_dice = [randi() % 6 + 1, randi() % 6 + 1]
	var player_total = player_dice[0] + player_dice[1]
	var enemy_total = enemy_dice[0] + enemy_dice[1]
	
	match_data["rng_seed"] = randi()
	
	var winner = "player" if player_total >= enemy_total else "enemy"
	match_data["initiative_winner"] = winner
	
	var init_result = {
		"turn": match_data["current_turn"],
		"player_dice": player_dice,
		"player_total": player_total,
		"enemy_dice": enemy_dice,
		"enemy_total": enemy_total,
		"winner": winner
	}
	
	print("[SERVER_BATTLE] Initiative: Player %d vs Enemy %d -> %s wins" % [player_total, enemy_total, winner])
	
	# Notificar a ambos jugadores
	rpc_id(match_data["player1_peer"], "client_initiative_result", init_result)
	rpc_id(match_data["player2_peer"], "client_initiative_result", init_result)
	
	# Iniciar fase de movimiento después de un delay
	await get_tree().create_timer(2.0).timeout
	_start_movement_phase(match_id)

func _start_movement_phase(match_id: int):
	"""Inicia la fase de movimiento"""
	var match_data = active_battles[match_id]
	match_data["current_phase"] = "movement"
	
	# Resetear movimiento de todos los mechs
	for mech_id in match_data["mechs"]:
		var mech = match_data["mechs"][mech_id]
		mech["moved_this_turn"] = false
		mech["current_movement"] = mech["walk_mp"]
		mech["movement_type_used"] = 0
		mech["hexes_moved"] = 0
	
	# Construir orden de activación
	_build_activation_order(match_id, "movement")
	
	# Notificar cambio de fase
	rpc_id(match_data["player1_peer"], "client_phase_changed", "movement", match_data["current_turn"])
	rpc_id(match_data["player2_peer"], "client_phase_changed", "movement", match_data["current_turn"])
	
	# Activar primera unidad
	await get_tree().create_timer(0.5).timeout
	_activate_next_unit(match_id)

func _start_weapon_phase(match_id: int):
	"""Inicia la fase de ataque con armas"""
	var match_data = active_battles[match_id]
	match_data["current_phase"] = "weapon_attack"
	
	# Resetear flags de disparo
	for mech_id in match_data["mechs"]:
		match_data["mechs"][mech_id]["fired_this_turn"] = false
	
	_build_activation_order(match_id, "attack")
	
	rpc_id(match_data["player1_peer"], "client_phase_changed", "weapon_attack", match_data["current_turn"])
	rpc_id(match_data["player2_peer"], "client_phase_changed", "weapon_attack", match_data["current_turn"])
	
	await get_tree().create_timer(0.5).timeout
	_activate_next_unit(match_id)

func _start_physical_phase(match_id: int):
	"""Inicia la fase de ataque físico"""
	var match_data = active_battles[match_id]
	match_data["current_phase"] = "physical_attack"
	
	_build_activation_order(match_id, "attack")
	
	rpc_id(match_data["player1_peer"], "client_phase_changed", "physical_attack", match_data["current_turn"])
	rpc_id(match_data["player2_peer"], "client_phase_changed", "physical_attack", match_data["current_turn"])
	
	await get_tree().create_timer(0.5).timeout
	_activate_next_unit(match_id)

func _start_heat_phase(match_id: int):
	"""Procesa la fase de calor"""
	var match_data = active_battles[match_id]
	match_data["current_phase"] = "heat"
	
	var heat_results = []
	
	for mech_id in match_data["mechs"]:
		var mech = match_data["mechs"][mech_id]
		if mech["is_destroyed"]:
			continue
		
		var result = _process_mech_heat(mech, match_data["rng_seed"])
		match_data["rng_seed"] = (match_data["rng_seed"] * 1103515245 + 12345) % 2147483648
		
		result["mech_id"] = mech_id
		heat_results.append(result)
	
	# Notificar resultados
	rpc_id(match_data["player1_peer"], "client_heat_phase_result", heat_results)
	rpc_id(match_data["player2_peer"], "client_heat_phase_result", heat_results)
	
	# Verificar si algún mech explotó
	_check_battle_end(match_id)
	
	# Siguiente turno
	await get_tree().create_timer(2.0).timeout
	_start_initiative_phase(match_id)

func _build_activation_order(match_id: int, phase_type: String):
	"""Construye el orden de activación según reglas de BattleTech"""
	var match_data = active_battles[match_id]
	match_data["units_to_activate"] = []
	match_data["current_unit_index"] = 0
	
	var player_mechs = []
	var enemy_mechs = []
	
	for mech_id in match_data["mechs"]:
		var mech = match_data["mechs"][mech_id]
		if mech["is_destroyed"]:
			continue
		
		if mech["team"] == "player":
			player_mechs.append(mech_id)
		else:
			enemy_mechs.append(mech_id)
	
	# En movimiento: el ganador de iniciativa mueve ÚLTIMO
	# En ataque: el ganador de iniciativa ataca PRIMERO
	var first_team: Array
	var last_team: Array
	
	if phase_type == "movement":
		first_team = enemy_mechs if match_data["initiative_winner"] == "player" else player_mechs
		last_team = player_mechs if match_data["initiative_winner"] == "player" else enemy_mechs
	else:
		first_team = player_mechs if match_data["initiative_winner"] == "player" else enemy_mechs
		last_team = enemy_mechs if match_data["initiative_winner"] == "player" else player_mechs
	
	# Alternar
	var max_units = max(first_team.size(), last_team.size())
	for i in range(max_units):
		if i < first_team.size():
			match_data["units_to_activate"].append(first_team[i])
		if i < last_team.size():
			match_data["units_to_activate"].append(last_team[i])

func _activate_next_unit(match_id: int):
	"""Activa la siguiente unidad"""
	var match_data = active_battles[match_id]
	
	if match_data["units_to_activate"].is_empty():
		_advance_phase(match_id)
		return
	
	if match_data["current_unit_index"] >= match_data["units_to_activate"].size():
		_advance_phase(match_id)
		return
	
	var mech_id = match_data["units_to_activate"][match_data["current_unit_index"]]
	var mech = match_data["mechs"][mech_id]
	
	# Determinar quién controla este mech
	var owner_peer = mech["owner_peer"]
	var opponent_peer = _get_opponent_peer(match_data, owner_peer)
	
	# Notificar activación
	rpc_id(owner_peer, "client_unit_activated", mech_id, true)
	rpc_id(opponent_peer, "client_unit_activated", mech_id, false)
	
	print("[SERVER_BATTLE] Unit activated: %s (peer %d)" % [mech["name"], owner_peer])

func _advance_to_next_unit(match_id: int):
	"""Avanza al siguiente mech en la lista de activación"""
	var match_data = active_battles[match_id]
	match_data["current_unit_index"] += 1
	_activate_next_unit(match_id)

func _advance_phase(match_id: int):
	"""Avanza a la siguiente fase"""
	var match_data = active_battles[match_id]
	
	match match_data["current_phase"]:
		"movement":
			_start_weapon_phase(match_id)
		"weapon_attack":
			_start_physical_phase(match_id)
		"physical_attack":
			_start_heat_phase(match_id)
		"heat":
			_start_initiative_phase(match_id)

# ============================================================
# LÓGICA DE COMBATE
# ============================================================

func _execute_weapon_attack(attacker: Dictionary, target: Dictionary, weapon: Dictionary, range_hexes: int, rng_seed: int) -> Dictionary:
	"""Ejecuta un ataque con arma"""
	seed(rng_seed)
	
	# Calcular to-hit
	var gunnery = attacker.get("gunnery_skill", 4)
	var attacker_mod = _get_attacker_movement_modifier(attacker)
	var target_mod = _get_target_movement_modifier(target)
	var range_mod = _get_range_modifier(weapon, range_hexes)
	
	if range_mod >= 999:
		return {"hit": false, "reason": "out_of_range", "roll": 0, "target": 0}
	
	var target_number = gunnery + attacker_mod + target_mod + range_mod
	
	# Tirar 2D6
	var die1 = randi() % 6 + 1
	var die2 = randi() % 6 + 1
	var roll = die1 + die2
	
	var result = {
		"weapon_name": weapon.get("name", "Unknown"),
		"roll": roll,
		"dice": [die1, die2],
		"target_number": target_number,
		"modifiers": {
			"gunnery": gunnery,
			"attacker_movement": attacker_mod,
			"target_movement": target_mod,
			"range": range_mod
		}
	}
	
	# Verificar impacto
	if roll == 2:
		result["hit"] = false
		result["critical_miss"] = true
	elif roll == 12 or roll >= target_number:
		result["hit"] = true
		
		# Determinar localización
		var loc_roll = (randi() % 6 + 1) + (randi() % 6 + 1)
		var location = _get_hit_location(loc_roll)
		result["location"] = location
		result["location_roll"] = loc_roll
		
		# Aplicar daño
		var damage = weapon.get("damage", 0)
		var damage_result = _apply_damage(target, location, damage)
		result["damage"] = damage
		result["damage_result"] = damage_result
	else:
		result["hit"] = false
	
	return result

func _execute_physical_attack(attacker: Dictionary, target: Dictionary, attack_type: String, rng_seed: int) -> Dictionary:
	"""Ejecuta un ataque físico"""
	seed(rng_seed)
	
	var piloting = attacker.get("piloting_skill", 5)
	var target_mod = _get_target_movement_modifier(target)
	
	var target_number = piloting + target_mod
	
	var die1 = randi() % 6 + 1
	var die2 = randi() % 6 + 1
	var roll = die1 + die2
	
	var result = {
		"attack_type": attack_type,
		"roll": roll,
		"dice": [die1, die2],
		"target_number": target_number
	}
	
	if roll >= target_number:
		result["hit"] = true
		
		# Calcular daño según tipo
		var damage = 0
		var location = ""
		
		match attack_type:
			"punch_left", "punch_right":
				damage = int(attacker["tonnage"] / 10.0)
				var loc_roll = randi() % 6 + 1
				location = ["left_arm", "left_torso", "center_torso", "right_torso", "right_arm", "head"][loc_roll - 1]
			"kick":
				damage = int(attacker["tonnage"] / 5.0)
				location = "left_leg" if randi() % 2 == 0 else "right_leg"
		
		result["damage"] = damage
		result["location"] = location
		
		var damage_result = _apply_damage(target, location, damage)
		result["damage_result"] = damage_result
	else:
		result["hit"] = false
	
	return result

func _apply_damage(target: Dictionary, location: String, damage: int) -> Dictionary:
	"""Aplica daño a un mech"""
	var result = {
		"location": location,
		"damage_dealt": damage,
		"armor_remaining": 0,
		"structure_remaining": 0,
		"critical_hit": false,
		"location_destroyed": false,
		"mech_destroyed": false
	}
	
	if not target["armor"].has(location):
		return result
	
	var armor_data = target["armor"][location]
	var current_armor = armor_data.get("current", 0)
	
	# Aplicar a armadura
	var armor_damage = min(damage, current_armor)
	armor_data["current"] = current_armor - armor_damage
	damage -= armor_damage
	
	result["armor_remaining"] = armor_data["current"]
	
	# Si queda daño, va a estructura
	if damage > 0:
		result["critical_hit"] = true
		# Simplificado: si el daño penetra armadura en torso central o cabeza, mech destruido
		if location in ["center_torso", "head"]:
			target["is_destroyed"] = true
			result["mech_destroyed"] = true
	
	return result

func _process_mech_heat(mech: Dictionary, rng_seed: int) -> Dictionary:
	"""Procesa el calor de un mech"""
	seed(rng_seed)
	
	var initial_heat = mech["heat"]
	var result = {
		"initial_heat": initial_heat,
		"dissipated": 0,
		"final_heat": 0,
		"shutdown": false,
		"ammo_explosion": false
	}
	
	# Disipar calor
	var dissipation = mech["heat_dissipation"]
	mech["heat"] = max(0, mech["heat"] - dissipation)
	result["dissipated"] = min(dissipation, initial_heat)
	result["final_heat"] = mech["heat"]
	
	# Verificar shutdown (simplificado)
	if initial_heat >= 14:
		var shutdown_target = 4 if initial_heat >= 22 else (6 if initial_heat >= 18 else 8)
		var roll = (randi() % 6 + 1) + (randi() % 6 + 1)
		if roll < shutdown_target:
			mech["is_shutdown"] = true
			result["shutdown"] = true
	
	return result

func _check_battle_end(match_id: int):
	"""Verifica si la batalla terminó"""
	var match_data = active_battles[match_id]
	
	var player_alive = false
	var enemy_alive = false
	
	for mech_id in match_data["mechs"]:
		var mech = match_data["mechs"][mech_id]
		if mech["is_destroyed"]:
			continue
		
		if mech["team"] == "player":
			player_alive = true
		else:
			enemy_alive = true
	
	if not player_alive or not enemy_alive:
		var winner = "player" if player_alive else "enemy"
		var reason = "All enemy mechs destroyed" if player_alive else "All player mechs destroyed"
		
		print("[SERVER_BATTLE] Battle ended: %s wins! (%s)" % [winner, reason])
		
		rpc_id(match_data["player1_peer"], "client_battle_ended", winner, reason)
		rpc_id(match_data["player2_peer"], "client_battle_ended", winner, reason)
		
		# Limpiar partida
		active_battles.erase(match_id)

# ============================================================
# UTILIDADES
# ============================================================

func _validate_match_participant(match_id: int, peer_id: int) -> bool:
	if match_id not in active_battles:
		return false
	
	var match_data = active_battles[match_id]
	return peer_id == match_data["player1_peer"] or peer_id == match_data["player2_peer"]

func _validate_mech_ownership(match_data: Dictionary, mech_id: int, peer_id: int) -> bool:
	if mech_id not in match_data["mechs"]:
		return false
	return match_data["mechs"][mech_id]["owner_peer"] == peer_id

func _get_team_for_peer(match_data: Dictionary, peer_id: int) -> String:
	if peer_id == match_data["player1_peer"]:
		return "player"
	return "enemy"

func _get_opponent_peer(match_data: Dictionary, peer_id: int) -> int:
	if peer_id == match_data["player1_peer"]:
		return match_data["player2_peer"]
	return match_data["player1_peer"]

func _generate_mech_id(match_id: int, team: String) -> int:
	return hash(str(match_id) + "_" + team + "_" + str(Time.get_ticks_msec()))

func _is_valid_deployment_hex(hex: Vector2i, team: String) -> bool:
	# Simplificado: jugador en sur (y >= 14), enemigo en norte (y < 4)
	if team == "player":
		return hex.y >= 14
	return hex.y < 4

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dx = abs(a.x - b.x)
	var dy = abs(a.y - b.y)
	return max(dx, dy)

func _get_max_movement(mech: Dictionary, movement_type: int) -> int:
	match movement_type:
		1:  # Walk
			return mech["walk_mp"]
		2:  # Run
			return mech["run_mp"]
		3:  # Jump
			return mech["jump_mp"]
	return mech["walk_mp"]

func _calculate_rotations(from_facing: int, to_facing: int) -> int:
	var diff = (to_facing - from_facing + 6) % 6
	return min(diff, 6 - diff)

func _get_attacker_movement_modifier(attacker: Dictionary) -> int:
	match attacker["movement_type_used"]:
		1:  # Walk
			return 1
		2:  # Run
			return 2
		3:  # Jump
			return 3
	return 0

func _get_target_movement_modifier(target: Dictionary) -> int:
	var hexes = target["hexes_moved"]
	if hexes >= 10:
		return 4
	elif hexes >= 7:
		return 3
	elif hexes >= 5:
		return 2
	elif hexes >= 3:
		return 1
	return 0

func _get_range_modifier(weapon: Dictionary, range_hexes: int) -> int:
	var short_range = weapon.get("range_short", 3)
	var medium_range = weapon.get("range_medium", 6)
	var long_range = weapon.get("range_long", 9)
	
	if range_hexes <= short_range:
		return 0
	elif range_hexes <= medium_range:
		return 2
	elif range_hexes <= long_range:
		return 4
	return 999

func _get_hit_location(roll: int) -> String:
	match roll:
		2: return "center_torso"
		3, 4: return "right_arm"
		5: return "right_leg"
		6: return "right_torso"
		7: return "center_torso"
		8: return "left_torso"
		9: return "left_leg"
		10, 11: return "left_arm"
		12: return "head"
	return "center_torso"
