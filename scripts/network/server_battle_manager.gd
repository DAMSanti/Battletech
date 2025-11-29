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

func start_match(player1_peer: int, player2_peer: int, match_id: int = -1, map_seed: int = -1):
	"""Inicia una nueva partida entre dos jugadores"""
	# Usar el match_id proporcionado o generar uno nuevo
	if match_id == -1:
		match_id = _generate_match_id(player1_peer, player2_peer)
	if map_seed == -1:
		map_seed = randi()  # Semilla para el mapa - COMPARTIDA entre clientes
	
	var match_data = {
		"match_id": match_id,
		"player1_peer": player1_peer,
		"player2_peer": player2_peer,
		"current_turn": 0,
		"current_phase": "waiting_for_clients",  # Esperar a que los clientes estén listos
		"initiative_winner": "",
		"mechs": {},
		"player1_deployed": false,
		"player2_deployed": false,
		"player1_ready": false,  # Cliente 1 listo en escena de batalla
		"player2_ready": false,  # Cliente 2 listo en escena de batalla
		"player1_roll_ready": false,  # Cliente 1 presionó Roll Dice
		"player2_roll_ready": false,  # Cliente 2 presionó Roll Dice
		"player1_start_ready": false,  # Cliente 1 presionó Start Battle
		"player2_start_ready": false,  # Cliente 2 presionó Start Battle
		"units_to_activate": [],
		"current_unit_index": 0,
		"rng_seed": map_seed  # Semilla para reproducibilidad
	}
	
	active_battles[match_id] = match_data
	
	print("[SERVER_BATTLE] Match %d created: Peer %d vs Peer %d (seed: %d)" % [match_id, player1_peer, player2_peer, map_seed])
	print("[SERVER_BATTLE] Waiting for both clients to be ready in battle scene...")

func _send_rpc_to_client(peer_id: int, method: String, args: Array) -> void:
	"""Envía un RPC al cliente a través del NetworkManager autoload"""
	if not network_manager:
		push_error("[SERVER_BATTLE] NetworkManager not available!")
		return
	
	# Llamamos los RPCs específicos según el método
	match method:
		"client_start_deployment":
			network_manager.rpc_id(peer_id, method, args[0], args[1], args[2])  # match_id, team, map_seed
		"client_mech_deployed":
			network_manager.rpc_id(peer_id, method, args[0], args[1], args[2], args[3], args[4])
		"client_initiative_result":
			network_manager.rpc_id(peer_id, method, args[0])
		"client_phase_changed":
			network_manager.rpc_id(peer_id, method, args[0], args[1])
		"client_unit_activated":
			network_manager.rpc_id(peer_id, method, args[0], args[1])
		"client_mech_moved":
			network_manager.rpc_id(peer_id, method, args[0])
		"client_mech_rotated":
			network_manager.rpc_id(peer_id, method, args[0])
		"client_weapons_fired":
			network_manager.rpc_id(peer_id, method, args[0])
		"client_physical_attack_result":
			network_manager.rpc_id(peer_id, method, args[0])
		"client_heat_phase_result":
			network_manager.rpc_id(peer_id, method, args[0])
		"client_battle_ended":
			network_manager.rpc_id(peer_id, method, args[0], args[1])
		"client_action_rejected":
			network_manager.rpc_id(peer_id, method, args[0])
		"client_opponent_disconnected":
			network_manager.rpc_id(peer_id, method)
		_:
			push_error("[SERVER_BATTLE] Unknown RPC method: %s" % method)

func _generate_match_id(peer1: int, peer2: int) -> int:
	return hash(str(peer1) + "_" + str(peer2) + "_" + str(Time.get_ticks_msec()))

# ============================================================
# HANDLERS - Llamados desde NetworkManager cuando recibe RPCs
# ============================================================

func _handle_deploy_request(sender_id: int, match_id: int, mech_data: Dictionary, hex_pos: Array, facing: int) -> void:
	"""Procesa solicitud de despliegue recibida via NetworkManager"""
	print("[SERVER_BATTLE] *** DEPLOY REQUEST ***")
	print("[SERVER_BATTLE]   sender_id: %d" % sender_id)
	print("[SERVER_BATTLE]   mech: %s" % mech_data.get("name", "Unknown"))
	print("[SERVER_BATTLE]   hex_pos: %s" % str(hex_pos))
	print("[SERVER_BATTLE]   facing: %d" % facing)
	
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	var team = _get_team_for_peer(match_data, sender_id)
	var hex = Vector2i(hex_pos[0], hex_pos[1])
	
	print("[SERVER_BATTLE] Deploy request from peer %d (team=%s) at [%d,%d]" % [sender_id, team, hex.x, hex.y])
	
	# Validar zona de despliegue
	if not _is_valid_deployment_hex(hex, team):
		print("[SERVER_BATTLE] REJECTED - Invalid deployment zone for team %s at y=%d" % [team, hex.y])
		_send_rpc_to_client(sender_id, "client_action_rejected", ["Invalid deployment zone"])
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
		"internal_structure": mech_data.get("internal_structure", {}).duplicate(true),
		"weapons": mech_data.get("weapons", []).duplicate(true),
		"equipment": mech_data.get("equipment", []).duplicate(true),
		"critical_slots": mech_data.get("critical_slots", {}).duplicate(true),
		"gunnery_skill": mech_data.get("gunnery_skill", 4),
		"piloting_skill": mech_data.get("piloting_skill", 5),
		"is_destroyed": false,
		"is_prone": false,
		"is_shutdown": false,
		"moved_this_turn": false,
		"fired_this_turn": false,
		"movement_type_used": 0,
		"hexes_moved": 0
	}
	
	match_data["mechs"][mech_id] = server_mech
	
	# Contar mechs desplegados por equipo
	if not match_data.has("player1_mech_count"):
		match_data["player1_mech_count"] = 0
	if not match_data.has("player2_mech_count"):
		match_data["player2_mech_count"] = 0
	
	if team == "player":
		match_data["player1_mech_count"] += 1
	else:
		match_data["player2_mech_count"] += 1
	
	print("[SERVER_BATTLE] Mech deployed: %s at [%d,%d] facing %d (P1: %d mechs, P2: %d mechs)" % [
		server_mech["name"], hex.x, hex.y, facing,
		match_data["player1_mech_count"], match_data["player2_mech_count"]
	])
	print("[SERVER_BATTLE] Mech has: %d weapons, %d equipment" % [server_mech["weapons"].size(), server_mech["equipment"].size()])
	for i in range(server_mech["weapons"].size()):
		print("[SERVER_BATTLE]   Weapon %d: %s (dmg=%s)" % [i, server_mech["weapons"][i].get("name", "?"), server_mech["weapons"][i].get("damage", "?")])
	for equip in server_mech["equipment"]:
		print("[SERVER_BATTLE]   Equipment: %s in %s" % [equip.get("name", "?"), equip.get("location", "?")])
	
	# Notificar a ambos jugadores via NetworkManager
	var opponent_peer = _get_opponent_peer(match_data, sender_id)
	network_manager.rpc_id(sender_id, "client_mech_deployed", mech_id, mech_data, [hex.x, hex.y], facing, team)
	network_manager.rpc_id(opponent_peer, "client_mech_deployed", mech_id, mech_data, [hex.x, hex.y], facing, team)

func _handle_client_ready(sender_id: int, match_id: int) -> void:
	"""Procesa notificación de que un cliente está listo en la escena de batalla"""
	if not _validate_match_participant(match_id, sender_id):
		print("[SERVER_BATTLE] Invalid match participant: %d for match %d" % [sender_id, match_id])
		return
	
	var match_data = active_battles[match_id]
	
	# Marcar qué cliente está listo
	if sender_id == match_data["player1_peer"]:
		match_data["player1_ready"] = true
		print("[SERVER_BATTLE] Player 1 (peer %d) ready in battle scene" % sender_id)
	elif sender_id == match_data["player2_peer"]:
		match_data["player2_ready"] = true
		print("[SERVER_BATTLE] Player 2 (peer %d) ready in battle scene" % sender_id)
	
	# Verificar si AMBOS están listos para iniciar deployment
	if match_data["player1_ready"] and match_data["player2_ready"]:
		print("[SERVER_BATTLE] Both clients ready! Starting deployment phase...")
		match_data["current_phase"] = "deployment"
		var map_seed = match_data["rng_seed"]
		_send_rpc_to_client(match_data["player1_peer"], "client_start_deployment", [match_id, "player", map_seed])
		_send_rpc_to_client(match_data["player2_peer"], "client_start_deployment", [match_id, "enemy", map_seed])

func _handle_deployment_complete(sender_id: int, match_id: int) -> void:
	"""Procesa notificación de que un jugador terminó de desplegar"""
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	# Marcar qué jugador terminó
	if sender_id == match_data["player1_peer"]:
		match_data["player1_deployed"] = true
		print("[SERVER_BATTLE] Player 1 (peer %d) finished deployment" % sender_id)
	elif sender_id == match_data["player2_peer"]:
		match_data["player2_deployed"] = true
		print("[SERVER_BATTLE] Player 2 (peer %d) finished deployment" % sender_id)
	
	# Verificar si AMBOS terminaron
	if match_data["player1_deployed"] and match_data["player2_deployed"]:
		print("[SERVER_BATTLE] Both players deployed! Waiting for initiative rolls...")
		# Notificar a ambos que pueden empezar
		network_manager.rpc_id(match_data["player1_peer"], "client_all_deployed")
		network_manager.rpc_id(match_data["player2_peer"], "client_all_deployed")
		# Cambiar fase a esperar rolls
		match_data["current_phase"] = "waiting_for_rolls"
		# NO iniciar automáticamente - esperar a que ambos presionen Roll

func _handle_initiative_roll_ready(sender_id: int, match_id: int) -> void:
	"""Procesa cuando un jugador presiona Roll Dice"""
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	# Marcar qué jugador presionó Roll
	if sender_id == match_data["player1_peer"]:
		match_data["player1_roll_ready"] = true
		print("[SERVER_BATTLE] Player 1 (peer %d) ready to roll" % sender_id)
	elif sender_id == match_data["player2_peer"]:
		match_data["player2_roll_ready"] = true
		print("[SERVER_BATTLE] Player 2 (peer %d) ready to roll" % sender_id)
	
	# Contar cuántos están listos
	var ready_count = 0
	if match_data["player1_roll_ready"]:
		ready_count += 1
	if match_data["player2_roll_ready"]:
		ready_count += 1
	
	# Notificar a ambos del estado de espera
	network_manager.rpc_id(match_data["player1_peer"], "client_waiting_for_rolls", ready_count, 2)
	network_manager.rpc_id(match_data["player2_peer"], "client_waiting_for_rolls", ready_count, 2)
	
	# Si ambos están listos, tirar dados
	if match_data["player1_roll_ready"] and match_data["player2_roll_ready"]:
		print("[SERVER_BATTLE] Both players ready! Rolling initiative...")
		_execute_initiative_roll(match_id)

func _handle_start_battle_ready(sender_id: int, match_id: int) -> void:
	"""Procesa cuando un jugador presiona Start Battle"""
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	# Marcar qué jugador presionó Start
	if sender_id == match_data["player1_peer"]:
		match_data["player1_start_ready"] = true
		print("[SERVER_BATTLE] Player 1 (peer %d) ready to start" % sender_id)
	elif sender_id == match_data["player2_peer"]:
		match_data["player2_start_ready"] = true
		print("[SERVER_BATTLE] Player 2 (peer %d) ready to start" % sender_id)
	
	# Contar cuántos están listos
	var ready_count = 0
	if match_data["player1_start_ready"]:
		ready_count += 1
	if match_data["player2_start_ready"]:
		ready_count += 1
	
	# Notificar a ambos del estado de espera
	network_manager.rpc_id(match_data["player1_peer"], "client_waiting_for_start", ready_count, 2)
	network_manager.rpc_id(match_data["player2_peer"], "client_waiting_for_start", ready_count, 2)
	
	# Si ambos están listos, iniciar batalla
	if match_data["player1_start_ready"] and match_data["player2_start_ready"]:
		print("[SERVER_BATTLE] Both players ready! Starting movement phase...")
		_start_movement_phase(match_id)

func _handle_move_request(sender_id: int, match_id: int, mech_id: int, target_hex: Array, movement_type: int) -> void:
	"""Procesa solicitud de movimiento"""
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	if not _validate_mech_ownership(match_data, mech_id, sender_id):
		network_manager.rpc_id(sender_id, "client_action_rejected", "Not your mech")
		return
	
	if match_data["current_phase"] != "movement":
		network_manager.rpc_id(sender_id, "client_action_rejected", "Not movement phase")
		return
	
	var mech = match_data["mechs"][mech_id]
	var hex = Vector2i(target_hex[0], target_hex[1])
	
	var max_mp = _get_max_movement(mech, movement_type)
	var current_pos = mech["hex_position"]
	var distance = _hex_distance(current_pos, hex)
	
	if distance > max_mp:
		network_manager.rpc_id(sender_id, "client_action_rejected", "Insufficient movement points")
		return
	
	var old_pos = mech["hex_position"]
	mech["hex_position"] = hex
	mech["moved_this_turn"] = true
	mech["movement_type_used"] = movement_type
	mech["hexes_moved"] = distance
	mech["current_movement"] = max_mp - distance
	
	# Actualizar facing según dirección del movimiento
	var new_facing = _get_facing_to_hex(old_pos, hex)
	mech["facing"] = new_facing
	
	print("[SERVER_BATTLE] Mech %s moved from [%d,%d] to [%d,%d], facing now %d" % [
		mech["name"], old_pos.x, old_pos.y, hex.x, hex.y, new_facing
	])
	
	var movement_heat = 0
	if movement_type == 2:
		movement_heat = 2
	elif movement_type == 3:
		movement_heat = distance
	
	mech["heat"] += movement_heat
	
	var opponent_peer = _get_opponent_peer(match_data, sender_id)
	var move_result = {
		"mech_id": mech_id,
		"from_hex": [old_pos.x, old_pos.y],
		"to_hex": [hex.x, hex.y],
		"movement_type": movement_type,
		"movement_heat": movement_heat,
		"remaining_mp": mech["current_movement"],
		"facing": new_facing
	}
	
	network_manager.rpc_id(sender_id, "client_mech_moved", move_result)
	network_manager.rpc_id(opponent_peer, "client_mech_moved", move_result)

func _handle_rotate_request(sender_id: int, match_id: int, mech_id: int, new_facing: int) -> void:
	"""Procesa solicitud de rotación"""
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	if not _validate_mech_ownership(match_data, mech_id, sender_id):
		network_manager.rpc_id(sender_id, "client_action_rejected", "Not your mech")
		return
	
	var mech = match_data["mechs"][mech_id]
	var rotations = _calculate_rotations(mech["facing"], new_facing)
	
	if rotations > mech["current_movement"]:
		network_manager.rpc_id(sender_id, "client_action_rejected", "Insufficient MPs for rotation")
		return
	
	var old_facing = mech["facing"]
	mech["facing"] = new_facing
	mech["current_movement"] -= rotations
	
	var opponent_peer = _get_opponent_peer(match_data, sender_id)
	var rotate_result = {
		"mech_id": mech_id,
		"old_facing": old_facing,
		"new_facing": new_facing,
		"mp_cost": rotations,
		"remaining_mp": mech["current_movement"]
	}
	
	network_manager.rpc_id(sender_id, "client_mech_rotated", rotate_result)
	network_manager.rpc_id(opponent_peer, "client_mech_rotated", rotate_result)

func _handle_fire_request(sender_id: int, match_id: int, attacker_id: int, target_id: int, weapon_indices: Array) -> void:
	"""Procesa solicitud de disparo"""
	print("[SERVER_BATTLE] Fire request from peer %d: attacker=%d, target=%d, weapons=%s" % [sender_id, attacker_id, target_id, weapon_indices])
	
	if not _validate_match_participant(match_id, sender_id):
		print("[SERVER_BATTLE] Fire request rejected: invalid match participant")
		return
	
	var match_data = active_battles[match_id]
	
	if not _validate_mech_ownership(match_data, attacker_id, sender_id):
		print("[SERVER_BATTLE] Fire request rejected: not mech owner")
		network_manager.rpc_id(sender_id, "client_action_rejected", "Not your mech")
		return
	
	print("[SERVER_BATTLE] Current phase: %s" % match_data["current_phase"])
	if match_data["current_phase"] != "weapon_attack":
		print("[SERVER_BATTLE] Fire request rejected: not weapon attack phase (current: %s)" % match_data["current_phase"])
		network_manager.rpc_id(sender_id, "client_action_rejected", "Not weapon attack phase")
		return
	
	var attacker = match_data["mechs"][attacker_id]
	var target = match_data["mechs"].get(target_id)
	
	print("[SERVER_BATTLE] Attacker: %s, weapons count: %d" % [attacker.get("name", "?"), attacker.get("weapons", []).size()])
	print("[SERVER_BATTLE] Attacker weapons: %s" % str(attacker.get("weapons", [])))
	
	if not target:
		network_manager.rpc_id(sender_id, "client_action_rejected", "Invalid target")
		return
	
	if attacker["team"] == target["team"]:
		network_manager.rpc_id(sender_id, "client_action_rejected", "Cannot attack ally")
		return
	
	var range_hexes = _hex_distance(attacker["hex_position"], target["hex_position"])
	print("[SERVER_BATTLE] Range: %d hexes" % range_hexes)
	
	var attack_results = []
	var total_heat = 0
	
	for weapon_idx in weapon_indices:
		print("[SERVER_BATTLE] Processing weapon index %d (attacker has %d weapons)" % [weapon_idx, attacker["weapons"].size()])
		if weapon_idx >= attacker["weapons"].size():
			print("[SERVER_BATTLE] SKIPPING weapon index %d - out of bounds!" % weapon_idx)
			continue
		
		var weapon = attacker["weapons"][weapon_idx]
		print("[SERVER_BATTLE] Firing weapon: %s" % weapon.get("name", "Unknown"))
		var result = _execute_weapon_attack(attacker, target, weapon, range_hexes, match_data["rng_seed"])
		print("[SERVER_BATTLE] Weapon result: %s" % str(result))
		attack_results.append(result)
		total_heat += weapon.get("heat", 0)
		
		match_data["rng_seed"] = (match_data["rng_seed"] * 1103515245 + 12345) % 2147483648
	
	attacker["heat"] += total_heat
	attacker["fired_this_turn"] = true
	
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
	
	network_manager.rpc_id(sender_id, "client_weapons_fired", fire_result)
	network_manager.rpc_id(opponent_peer, "client_weapons_fired", fire_result)
	
	if target["is_destroyed"]:
		_check_battle_end(match_id)

func _handle_physical_request(sender_id: int, match_id: int, attacker_id: int, target_id: int, attack_type: String) -> void:
	"""Procesa solicitud de ataque físico"""
	if not _validate_match_participant(match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	if not _validate_mech_ownership(match_data, attacker_id, sender_id):
		network_manager.rpc_id(sender_id, "client_action_rejected", "Not your mech")
		return
	
	if match_data["current_phase"] != "physical_attack":
		network_manager.rpc_id(sender_id, "client_action_rejected", "Not physical attack phase")
		return
	
	var attacker = match_data["mechs"][attacker_id]
	var target = match_data["mechs"].get(target_id)
	
	if not target:
		network_manager.rpc_id(sender_id, "client_action_rejected", "Invalid target")
		return
	
	var distance = _hex_distance(attacker["hex_position"], target["hex_position"])
	if distance > 1:
		network_manager.rpc_id(sender_id, "client_action_rejected", "Target too far for physical attack")
		return
	
	var result = _execute_physical_attack(attacker, target, attack_type, match_data["rng_seed"])
	match_data["rng_seed"] = (match_data["rng_seed"] * 1103515245 + 12345) % 2147483648
	
	var opponent_peer = _get_opponent_peer(match_data, sender_id)
	var attack_result = {
		"attacker_id": attacker_id,
		"target_id": target_id,
		"attack_type": attack_type,
		"result": result,
		"target_destroyed": target["is_destroyed"]
	}
	
	network_manager.rpc_id(sender_id, "client_physical_attack_result", attack_result)
	network_manager.rpc_id(opponent_peer, "client_physical_attack_result", attack_result)
	
	if target["is_destroyed"]:
		_check_battle_end(match_id)

func _handle_end_activation(sender_id: int, match_id: int, mech_id: int) -> void:
	"""Procesa fin de activación"""
	print("[SERVER_BATTLE] End activation request from peer %d for mech %d" % [sender_id, mech_id])
	if not _validate_match_participant(match_id, sender_id):
		print("[SERVER_BATTLE] End activation rejected: not a match participant")
		return
	
	var match_data = active_battles[match_id]
	
	if not _validate_mech_ownership(match_data, mech_id, sender_id):
		print("[SERVER_BATTLE] End activation rejected: not mech owner")
		return
	
	print("[SERVER_BATTLE] End activation accepted, advancing to next unit")
	_advance_to_next_unit(match_id)

# ============================================================
# RPCs LEGACY - Mantener por compatibilidad pero redirigir a handlers
# ============================================================

@rpc("any_peer", "reliable")
func server_request_deploy_mech(match_id: int, mech_data: Dictionary, hex_pos: Array, facing: int):
	"""Cliente solicita desplegar un mech - LEGACY, usar _handle_deploy_request"""
	var sender_id = multiplayer.get_remote_sender_id()
	_handle_deploy_request(sender_id, match_id, mech_data, hex_pos, facing)

@rpc("any_peer", "reliable")
func server_request_move(match_id: int, mech_id: int, target_hex: Array, movement_type: int):
	"""Cliente solicita mover un mech - LEGACY, redirige a handler"""
	var sender_id = multiplayer.get_remote_sender_id()
	_handle_move_request(sender_id, match_id, mech_id, target_hex, movement_type)

@rpc("any_peer", "reliable")
func server_request_rotate(match_id: int, mech_id: int, new_facing: int):
	"""Cliente solicita rotar un mech - LEGACY, redirige a handler"""
	var sender_id = multiplayer.get_remote_sender_id()
	_handle_rotate_request(sender_id, match_id, mech_id, new_facing)

@rpc("any_peer", "reliable")
func server_request_fire(match_id: int, attacker_id: int, target_id: int, weapon_indices: Array):
	"""Cliente solicita disparar armas - LEGACY, redirige a handler"""
	var sender_id = multiplayer.get_remote_sender_id()
	_handle_fire_request(sender_id, match_id, attacker_id, target_id, weapon_indices)

@rpc("any_peer", "reliable")
func server_request_physical_attack(match_id: int, attacker_id: int, target_id: int, attack_type: String):
	"""Cliente solicita ataque físico - LEGACY, redirige a handler"""
	var sender_id = multiplayer.get_remote_sender_id()
	_handle_physical_request(sender_id, match_id, attacker_id, target_id, attack_type)

@rpc("any_peer", "reliable")
func server_request_end_activation(match_id: int, mech_id: int):
	"""Cliente indica que terminó su activación - LEGACY, redirige a handler"""
	var sender_id = multiplayer.get_remote_sender_id()
	_handle_end_activation(sender_id, match_id, mech_id)

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

func _execute_initiative_roll(match_id: int):
	"""Ejecuta la tirada de iniciativa cuando ambos jugadores están listos"""
	if match_id not in active_battles:
		print("[SERVER_BATTLE] Match %d no longer exists, skipping initiative" % match_id)
		return
	var match_data = active_battles[match_id]
	match_data["current_turn"] += 1
	match_data["current_phase"] = "initiative"
	
	# Tirar 2D6 por CADA mech (no por equipo)
	seed(match_data["rng_seed"])
	
	var player_mech_rolls = []  # Array de [die1, die2] por cada mech del player
	var enemy_mech_rolls = []   # Array de [die1, die2] por cada mech del enemy
	var player_total = 0
	var enemy_total = 0
	
	# Recopilar mechs por equipo
	var player_mechs_list = []
	var enemy_mechs_list = []
	for mech_id in match_data["mechs"]:
		var mech = match_data["mechs"][mech_id]
		if mech["is_destroyed"]:
			continue
		if mech["team"] == "player":
			player_mechs_list.append(mech)
		else:
			enemy_mechs_list.append(mech)
	
	# Tirar dados para cada mech del player
	for mech in player_mechs_list:
		var die1 = randi() % 6 + 1
		var die2 = randi() % 6 + 1
		player_mech_rolls.append([die1, die2])
		player_total += die1 + die2
		print("[SERVER_BATTLE] Player mech %s rolled %d + %d = %d" % [mech["name"], die1, die2, die1 + die2])
	
	# Tirar dados para cada mech del enemy
	for mech in enemy_mechs_list:
		var die1 = randi() % 6 + 1
		var die2 = randi() % 6 + 1
		enemy_mech_rolls.append([die1, die2])
		enemy_total += die1 + die2
		print("[SERVER_BATTLE] Enemy mech %s rolled %d + %d = %d" % [mech["name"], die1, die2, die1 + die2])
	
	match_data["rng_seed"] = randi()
	
	# El ganador tiene el total más alto (empate va al player)
	var winner = "player" if player_total >= enemy_total else "enemy"
	match_data["initiative_winner"] = winner
	
	var init_result = {
		"turn": match_data["current_turn"],
		"player_mech_rolls": player_mech_rolls,  # Array de [die1, die2] por mech
		"enemy_mech_rolls": enemy_mech_rolls,    # Array de [die1, die2] por mech
		"player_total": player_total,
		"enemy_total": enemy_total,
		"winner": winner
	}
	
	print("[SERVER_BATTLE] Initiative: Player total %d vs Enemy total %d -> %s wins" % [player_total, enemy_total, winner])
	
	# Notificar a ambos jugadores via NetworkManager
	network_manager.rpc_id(match_data["player1_peer"], "client_initiative_result", init_result)
	network_manager.rpc_id(match_data["player2_peer"], "client_initiative_result", init_result)
	
	# Cambiar fase a esperar Start Battle
	match_data["current_phase"] = "waiting_for_start"
	# NO iniciar movimiento automáticamente - esperar a que ambos presionen Start Battle

func _start_initiative_phase(match_id: int):
	"""Inicia la fase de iniciativa para un nuevo turno"""
	if match_id not in active_battles:
		return
	
	var match_data = active_battles[match_id]
	
	# Incrementar turno
	match_data["current_turn"] += 1
	
	# Resetear estados de ready para nuevo turno
	match_data["player1_roll_ready"] = false
	match_data["player2_roll_ready"] = false
	match_data["player1_start_ready"] = false
	match_data["player2_start_ready"] = false
	match_data["current_phase"] = "waiting_for_rolls"
	
	print("[SERVER_BATTLE] Starting initiative phase for turn %d" % match_data["current_turn"])
	
	# Notificar a los clientes que deben mostrar la pantalla de iniciativa
	network_manager.rpc_id(match_data["player1_peer"], "client_phase_changed", "initiative", match_data["current_turn"])
	network_manager.rpc_id(match_data["player2_peer"], "client_phase_changed", "initiative", match_data["current_turn"])

func _start_movement_phase(match_id: int):
	"""Inicia la fase de movimiento"""
	if match_id not in active_battles:
		print("[SERVER_BATTLE] _start_movement_phase: Match %d not in active_battles!" % match_id)
		return
	var match_data = active_battles[match_id]
	match_data["current_phase"] = "movement"
	
	print("[SERVER_BATTLE] Starting movement phase for match %d" % match_id)
	print("[SERVER_BATTLE] Mechs in match: %d" % match_data["mechs"].size())
	for mech_id in match_data["mechs"]:
		var mech = match_data["mechs"][mech_id]
		print("[SERVER_BATTLE]   Mech %d: %s (team=%s, destroyed=%s)" % [mech_id, mech["name"], mech["team"], mech["is_destroyed"]])
	
	# Resetear movimiento de todos los mechs
	for mech_id in match_data["mechs"]:
		var mech = match_data["mechs"][mech_id]
		mech["moved_this_turn"] = false
		mech["current_movement"] = mech["walk_mp"]
		mech["movement_type_used"] = 0
		mech["hexes_moved"] = 0
	
	# Construir orden de activación
	_build_activation_order(match_id, "movement")
	
	# Notificar cambio de fase via NetworkManager
	var peer1 = match_data["player1_peer"]
	var peer2 = match_data["player2_peer"]
	var connected_peers = multiplayer.get_peers()
	print("[SERVER_BATTLE] Sending phase_changed RPC to peers %d and %d" % [peer1, peer2])
	print("[SERVER_BATTLE] Connected peers: %s" % str(connected_peers))
	print("[SERVER_BATTLE] NetworkManager path: %s" % network_manager.get_path())
	
	if peer1 in connected_peers:
		network_manager.rpc_id(peer1, "client_phase_changed", "movement", match_data["current_turn"])
		print("[SERVER_BATTLE] RPC sent to peer %d" % peer1)
	else:
		print("[SERVER_BATTLE] ERROR: Peer %d not connected!" % peer1)
		
	if peer2 in connected_peers:
		network_manager.rpc_id(peer2, "client_phase_changed", "movement", match_data["current_turn"])
		print("[SERVER_BATTLE] RPC sent to peer %d" % peer2)
	else:
		print("[SERVER_BATTLE] ERROR: Peer %d not connected!" % peer2)
	
	# Activar primera unidad
	await get_tree().create_timer(0.5).timeout
	if match_id not in active_battles:
		return
	_activate_next_unit(match_id)

func _start_weapon_phase(match_id: int):
	"""Inicia la fase de ataque con armas"""
	print("[SERVER_BATTLE] *** STARTING WEAPON ATTACK PHASE for match %d ***" % match_id)
	if match_id not in active_battles:
		return
	var match_data = active_battles[match_id]
	match_data["current_phase"] = "weapon_attack"
	print("[SERVER_BATTLE] current_phase set to: weapon_attack")
	
	# Resetear flags de disparo
	for mech_id in match_data["mechs"]:
		match_data["mechs"][mech_id]["fired_this_turn"] = false
	
	_build_activation_order(match_id, "attack")
	
	network_manager.rpc_id(match_data["player1_peer"], "client_phase_changed", "weapon_attack", match_data["current_turn"])
	network_manager.rpc_id(match_data["player2_peer"], "client_phase_changed", "weapon_attack", match_data["current_turn"])
	
	await get_tree().create_timer(0.5).timeout
	if match_id not in active_battles:
		return
	_activate_next_unit(match_id)

func _start_physical_phase(match_id: int):
	"""Inicia la fase de ataque físico"""
	if match_id not in active_battles:
		return
	var match_data = active_battles[match_id]
	match_data["current_phase"] = "physical_attack"
	
	_build_activation_order(match_id, "attack")
	
	network_manager.rpc_id(match_data["player1_peer"], "client_phase_changed", "physical_attack", match_data["current_turn"])
	network_manager.rpc_id(match_data["player2_peer"], "client_phase_changed", "physical_attack", match_data["current_turn"])
	
	await get_tree().create_timer(0.5).timeout
	if match_id not in active_battles:
		return
	_activate_next_unit(match_id)

func _start_heat_phase(match_id: int):
	"""Procesa la fase de calor"""
	if match_id not in active_battles:
		return
	var match_data = active_battles[match_id]
	match_data["current_phase"] = "heat"
	
	print("[SERVER_BATTLE] Starting heat phase for match %d" % match_id)
	
	# Notificar cambio de fase a los clientes ANTES de procesar
	network_manager.rpc_id(match_data["player1_peer"], "client_phase_changed", "heat", match_data["current_turn"])
	network_manager.rpc_id(match_data["player2_peer"], "client_phase_changed", "heat", match_data["current_turn"])
	
	# Pequeña pausa para que los clientes muestren la fase
	await get_tree().create_timer(0.5).timeout
	
	if match_id not in active_battles:
		return
	
	var heat_results = []
	
	for mech_id in match_data["mechs"]:
		var mech = match_data["mechs"][mech_id]
		if mech["is_destroyed"]:
			continue
		
		var result = _process_mech_heat(mech, match_data["rng_seed"])
		match_data["rng_seed"] = (match_data["rng_seed"] * 1103515245 + 12345) % 2147483648
		
		result["mech_id"] = mech_id
		heat_results.append(result)
	
	# Notificar resultados via NetworkManager
	network_manager.rpc_id(match_data["player1_peer"], "client_heat_phase_result", heat_results)
	network_manager.rpc_id(match_data["player2_peer"], "client_heat_phase_result", heat_results)
	
	# Verificar si algún mech explotó
	_check_battle_end(match_id)
	
	# Verificar si la batalla sigue activa antes de continuar
	if match_id not in active_battles:
		print("[SERVER_BATTLE] Battle %d ended, not starting next turn" % match_id)
		return
	
	# Siguiente turno
	await get_tree().create_timer(2.0).timeout
	
	# Verificar de nuevo después del await
	if match_id not in active_battles:
		print("[SERVER_BATTLE] Battle %d ended during wait, not starting next turn" % match_id)
		return
	
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
	
	print("[SERVER_BATTLE] Built activation order: %d units to activate" % match_data["units_to_activate"].size())
	print("[SERVER_BATTLE]   Player mechs: %d, Enemy mechs: %d" % [player_mechs.size(), enemy_mechs.size()])

func _activate_next_unit(match_id: int):
	"""Activa la siguiente unidad"""
	var match_data = active_battles[match_id]
	
	print("[SERVER_BATTLE] _activate_next_unit: index=%d, total=%d, phase=%s" % [match_data["current_unit_index"], match_data["units_to_activate"].size(), match_data["current_phase"]])
	
	if match_data["units_to_activate"].is_empty():
		print("[SERVER_BATTLE] No units to activate, advancing phase")
		_advance_phase(match_id)
		return
	
	if match_data["current_unit_index"] >= match_data["units_to_activate"].size():
		print("[SERVER_BATTLE] All units activated (%d/%d), advancing phase" % [match_data["current_unit_index"], match_data["units_to_activate"].size()])
		_advance_phase(match_id)
		return
	
	var mech_id = match_data["units_to_activate"][match_data["current_unit_index"]]
	var mech = match_data["mechs"][mech_id]
	
	# Determinar quién controla este mech
	var owner_peer = mech["owner_peer"]
	var opponent_peer = _get_opponent_peer(match_data, owner_peer)
	
	# Verificar peers conectados
	var connected_peers = multiplayer.get_peers()
	print("[SERVER_BATTLE] Activating unit %d (%s) for peer %d" % [mech_id, mech["name"], owner_peer])
	print("[SERVER_BATTLE] Connected peers for activation: %s" % str(connected_peers))
	
	# Notificar activación via NetworkManager
	if owner_peer in connected_peers:
		network_manager.rpc_id(owner_peer, "client_unit_activated", mech_id, true)
		print("[SERVER_BATTLE] Unit activation sent to owner %d (is_mine=true)" % owner_peer)
	else:
		print("[SERVER_BATTLE] ERROR: Owner peer %d not connected!" % owner_peer)
		
	if opponent_peer in connected_peers:
		network_manager.rpc_id(opponent_peer, "client_unit_activated", mech_id, false)
		print("[SERVER_BATTLE] Unit activation sent to opponent %d (is_mine=false)" % opponent_peer)
	else:
		print("[SERVER_BATTLE] ERROR: Opponent peer %d not connected!" % opponent_peer)
	
	print("[SERVER_BATTLE] Unit activated: %s (peer %d)" % [mech["name"], owner_peer])

func _advance_to_next_unit(match_id: int):
	"""Avanza al siguiente mech en la lista de activación"""
	var match_data = active_battles[match_id]
	match_data["current_unit_index"] += 1
	print("[SERVER_BATTLE] _advance_to_next_unit: index now %d of %d, phase=%s" % [match_data["current_unit_index"], match_data["units_to_activate"].size(), match_data["current_phase"]])
	_activate_next_unit(match_id)

func _advance_phase(match_id: int):
	"""Avanza a la siguiente fase"""
	var match_data = active_battles[match_id]
	print("[SERVER_BATTLE] _advance_phase called, current phase: %s" % match_data["current_phase"])
	
	match match_data["current_phase"]:
		"movement":
			print("[SERVER_BATTLE] Advancing from movement -> weapon_attack")
			_start_weapon_phase(match_id)
		"weapon_attack":
			print("[SERVER_BATTLE] Advancing from weapon_attack -> physical_attack")
			_start_physical_phase(match_id)
		"physical_attack":
			print("[SERVER_BATTLE] Advancing from physical_attack -> heat")
			_start_heat_phase(match_id)
		"heat":
			print("[SERVER_BATTLE] Advancing from heat -> initiative")
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
	
	print("[SERVER_BATTLE] Checking battle end for match %d..." % match_id)
	print("[SERVER_BATTLE] Total mechs in battle: %d" % match_data["mechs"].size())
	
	for mech_id in match_data["mechs"]:
		var mech = match_data["mechs"][mech_id]
		print("[SERVER_BATTLE]   Mech %d (%s): team=%s, destroyed=%s" % [mech_id, mech["name"], mech["team"], mech["is_destroyed"]])
		if mech["is_destroyed"]:
			continue
		
		if mech["team"] == "player":
			player_alive = true
		else:
			enemy_alive = true
	
	print("[SERVER_BATTLE] Player alive: %s, Enemy alive: %s" % [player_alive, enemy_alive])
	
	if not player_alive or not enemy_alive:
		var winner = "player" if player_alive else "enemy"
		var reason = "All enemy mechs destroyed" if player_alive else "All player mechs destroyed"
		
		print("[SERVER_BATTLE] Battle ended: %s wins! (%s)" % [winner, reason])
		
		network_manager.rpc_id(match_data["player1_peer"], "client_battle_ended", winner, reason)
		network_manager.rpc_id(match_data["player2_peer"], "client_battle_ended", winner, reason)
		
		# Limpiar partida
		active_battles.erase(match_id)

# ============================================================
# UTILIDADES
# ============================================================

func _validate_match_participant(match_id: int, peer_id: int) -> bool:
	if match_id not in active_battles:
		print("[SERVER_BATTLE] Match %d not found. Active battles: %s" % [match_id, active_battles.keys()])
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
	# Zona de despliegue flexible para diferentes tamaños de mapa
	# Jugador: sur (últimas 5 filas: y >= 13 para compatibilidad)
	# Enemigo: norte (primeras 5 filas: y < 5)
	# Esto permite mapas de diferentes tamaños
	
	if team == "player":
		return hex.y >= 13  # Aceptar y >= 13 para mayor flexibilidad
	else:  # team == "enemy"
		return hex.y < 5  # Aceptar y < 5 para mayor flexibilidad

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dx = abs(a.x - b.x)
	var dy = abs(a.y - b.y)
	return max(dx, dy)

func _get_facing_to_hex(from: Vector2i, to: Vector2i) -> int:
	"""Calcula el facing desde una posición hacia otra (hexagonal offset coordinates)"""
	var dx = to.x - from.x
	var dy = to.y - from.y
	
	# Hexagonal offset coordinates directions:
	# 0 = Norte (dy < 0)
	# 1 = Noreste (dx > 0, dy <= 0 o dy < 0 para columnas pares/impares)
	# 2 = Sureste (dx > 0, dy >= 0)
	# 3 = Sur (dy > 0)
	# 4 = Suroeste (dx < 0, dy >= 0)
	# 5 = Noroeste (dx < 0, dy <= 0)
	
	if dx == 0:
		if dy < 0:
			return 0  # Norte
		else:
			return 3  # Sur
	elif dx > 0:
		if dy <= 0:
			return 1  # Noreste
		else:
			return 2  # Sureste
	else:  # dx < 0
		if dy <= 0:
			return 5  # Noroeste
		else:
			return 4  # Suroeste

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
