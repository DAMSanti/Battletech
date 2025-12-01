# server_battle_manager.gd
# Main server battle manager - Authoritative game server
# Refactored in Phase 5 SOLID - delegates to ServerCombatResolver, ServerPhaseManager, ServerMatchValidator
extends Node
class_name ServerBattleManager

## ServerBattleManager - Manages battles on dedicated server
## Server is AUTHORITATIVE: validates all actions and executes game logic

# Preload helper classes
const ServerCombatResolver = preload("res://scripts/network/server_combat_resolver.gd")
const ServerPhaseManager = preload("res://scripts/network/server_phase_manager.gd")
const ServerMatchValidator = preload("res://scripts/network/server_match_validator.gd")
const ServerActionValidator = preload("res://scripts/network/server_action_validator.gd")

# Match structure
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
	await get_tree().process_frame
	network_manager = get_node_or_null("/root/NetworkManager")
	if not network_manager:
		network_manager = get_parent().get_node_or_null("NetworkManager")

# ============================================================
# MATCH INITIALIZATION
# ============================================================

func start_match(player1_peer: int, player2_peer: int, match_id: int = -1, map_seed: int = -1):
	"""Starts a new match between two players"""
	if match_id == -1:
		match_id = ServerMatchValidator.generate_match_id(player1_peer, player2_peer)
	if map_seed == -1:
		map_seed = randi()
	
	var match_data = {
		"match_id": match_id,
		"player1_peer": player1_peer,
		"player2_peer": player2_peer,
		"current_turn": 0,
		"current_phase": "waiting_for_clients",
		"initiative_winner": "",
		"mechs": {},
		"player1_deployed": false,
		"player2_deployed": false,
		"player1_ready": false,
		"player2_ready": false,
		"player1_roll_ready": false,
		"player2_roll_ready": false,
		"player1_start_ready": false,
		"player2_start_ready": false,
		"units_to_activate": [],
		"current_unit_index": 0,
		"rng_seed": map_seed
	}
	
	active_battles[match_id] = match_data
	
	Log.match_event("Match created", str(match_id), str(player1_peer), str(player2_peer))
	Log.debug("Match", "Match config", {"seed": map_seed})
	Log.info("Match", "Waiting for both clients to be ready in battle scene...")

func _send_rpc_to_client(peer_id: int, method: String, args: Array) -> void:
	"""Sends an RPC to client through NetworkManager autoload"""
	if not network_manager:
		push_error("[SERVER_BATTLE] NetworkManager not available!")
		return
	
	match method:
		"client_start_deployment":
			network_manager.rpc_id(peer_id, method, args[0], args[1], args[2])
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

# ============================================================
# HANDLERS - Called from NetworkManager when RPCs are received
# ============================================================

func _handle_deploy_request(sender_id: int, match_id: int, mech_data: Dictionary, hex_pos: Array, facing: int) -> void:
	"""Processes deployment request with comprehensive validation"""
	Log.debug("Mech", "Deploy request received", {
		"peer": sender_id,
		"mech": mech_data.get("name", "Unknown"),
		"hex": str(hex_pos),
		"facing": facing
	})
	
	if not ServerMatchValidator.validate_match_participant(active_battles, match_id, sender_id):
		return
	
	var match_data: Dictionary = active_battles[match_id]
	var team: String = ServerMatchValidator.get_team_for_peer(match_data, sender_id)
	var hex: Vector2i = Vector2i(hex_pos[0], hex_pos[1])
	
	Log.debug("Mech", "Processing deploy", {"peer": sender_id, "team": team, "hex": "[%d,%d]" % [hex.x, hex.y]})
	
	# Usar el nuevo validador comprehensivo
	var validation: ServerActionValidator.ValidationResult = ServerActionValidator.validate_deployment(
		match_data,
		sender_id,
		hex,
		team,
		mech_data
	)
	
	if not validation.valid:
		Log.warning("Mech", "Deploy REJECTED", {
			"peer": sender_id,
			"team": team,
			"hex": [hex.x, hex.y],
			"reason": validation.reason,
			"context": validation.context
		})
		_send_rpc_to_client(sender_id, "client_action_rejected", [validation.reason])
		return
	
	# Validación pasada - ejecutar deployment
	var mech_id: int = ServerMatchValidator.generate_mech_id(match_id, team)
	var server_mech: Dictionary = _create_server_mech(mech_id, sender_id, team, mech_data, hex, facing)
	
	match_data["mechs"][mech_id] = server_mech
	_update_mech_counts(match_data, team)
	
	Log.info("Mech", "Mech deployed", {
		"name": server_mech["name"],
		"hex": "[%d,%d]" % [hex.x, hex.y],
		"facing": facing,
		"p1_mechs": match_data.get("player1_mech_count", 0),
		"p2_mechs": match_data.get("player2_mech_count", 0)
	})
	
	var opponent_peer: int = ServerMatchValidator.get_opponent_peer(match_data, sender_id)
	network_manager.rpc_id(sender_id, "client_mech_deployed", mech_id, mech_data, [hex.x, hex.y], facing, team)
	network_manager.rpc_id(opponent_peer, "client_mech_deployed", mech_id, mech_data, [hex.x, hex.y], facing, team)

func _create_server_mech(mech_id: int, owner_peer: int, team: String, mech_data: Dictionary, hex: Vector2i, facing: int) -> Dictionary:
	return {
		"id": mech_id,
		"owner_peer": owner_peer,
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

func _update_mech_counts(match_data: Dictionary, team: String) -> void:
	if not match_data.has("player1_mech_count"):
		match_data["player1_mech_count"] = 0
	if not match_data.has("player2_mech_count"):
		match_data["player2_mech_count"] = 0
	
	if team == "player":
		match_data["player1_mech_count"] += 1
	else:
		match_data["player2_mech_count"] += 1

func _handle_client_ready(sender_id: int, match_id: int) -> void:
	"""Processes client ready notification"""
	if not ServerMatchValidator.validate_match_participant(active_battles, match_id, sender_id):
		Log.warning("Match", "Invalid match participant", {"peer": sender_id, "match_id": match_id})
		return
	
	var match_data = active_battles[match_id]
	
	if sender_id == match_data["player1_peer"]:
		match_data["player1_ready"] = true
		Log.info("Match", "Player 1 ready in battle scene", {"peer": sender_id})
	elif sender_id == match_data["player2_peer"]:
		match_data["player2_ready"] = true
		Log.info("Match", "Player 2 ready in battle scene", {"peer": sender_id})
	
	if match_data["player1_ready"] and match_data["player2_ready"]:
		Log.info("Match", "Both clients ready! Starting deployment phase...")
		match_data["current_phase"] = "deployment"
		var map_seed = match_data["rng_seed"]
		_send_rpc_to_client(match_data["player1_peer"], "client_start_deployment", [match_id, "player", map_seed])
		_send_rpc_to_client(match_data["player2_peer"], "client_start_deployment", [match_id, "enemy", map_seed])

func _handle_deployment_complete(sender_id: int, match_id: int) -> void:
	"""Processes deployment complete notification"""
	if not ServerMatchValidator.validate_match_participant(active_battles, match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	if sender_id == match_data["player1_peer"]:
		match_data["player1_deployed"] = true
		Log.info("Match", "Player 1 finished deployment", {"peer": sender_id})
	elif sender_id == match_data["player2_peer"]:
		match_data["player2_deployed"] = true
		Log.info("Match", "Player 2 finished deployment", {"peer": sender_id})
	
	if match_data["player1_deployed"] and match_data["player2_deployed"]:
		Log.info("Match", "Both players deployed! Waiting for initiative rolls...")
		network_manager.rpc_id(match_data["player1_peer"], "client_all_deployed")
		network_manager.rpc_id(match_data["player2_peer"], "client_all_deployed")
		match_data["current_phase"] = "waiting_for_rolls"

func _handle_initiative_roll_ready(sender_id: int, match_id: int) -> void:
	"""Processes when a player presses Roll Dice"""
	if not ServerMatchValidator.validate_match_participant(active_battles, match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	if sender_id == match_data["player1_peer"]:
		match_data["player1_roll_ready"] = true
	elif sender_id == match_data["player2_peer"]:
		match_data["player2_roll_ready"] = true
	
	var ready_count = int(match_data["player1_roll_ready"]) + int(match_data["player2_roll_ready"])
	
	network_manager.rpc_id(match_data["player1_peer"], "client_waiting_for_rolls", ready_count, 2)
	network_manager.rpc_id(match_data["player2_peer"], "client_waiting_for_rolls", ready_count, 2)
	
	if match_data["player1_roll_ready"] and match_data["player2_roll_ready"]:
		Log.info("Combat", "Both players ready! Rolling initiative...")
		_execute_initiative_roll(match_id)

func _handle_start_battle_ready(sender_id: int, match_id: int) -> void:
	"""Processes when a player presses Start Battle"""
	if not ServerMatchValidator.validate_match_participant(active_battles, match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	if sender_id == match_data["player1_peer"]:
		match_data["player1_start_ready"] = true
	elif sender_id == match_data["player2_peer"]:
		match_data["player2_start_ready"] = true
	
	var ready_count = int(match_data["player1_start_ready"]) + int(match_data["player2_start_ready"])
	
	network_manager.rpc_id(match_data["player1_peer"], "client_waiting_for_start", ready_count, 2)
	network_manager.rpc_id(match_data["player2_peer"], "client_waiting_for_start", ready_count, 2)
	
	if match_data["player1_start_ready"] and match_data["player2_start_ready"]:
		Log.info("Match", "Both players ready! Starting movement phase...")
		_start_movement_phase(match_id)

func _handle_move_request(sender_id: int, match_id: int, mech_id: int, target_hex: Array, movement_type: int) -> void:
	"""Processes movement request with comprehensive validation"""
	if not ServerMatchValidator.validate_match_participant(active_battles, match_id, sender_id):
		return
	
	var match_data: Dictionary = active_battles[match_id]
	var hex: Vector2i = Vector2i(target_hex[0], target_hex[1])
	
	# Usar el nuevo validador comprehensivo
	var validation: ServerActionValidator.ValidationResult = ServerActionValidator.validate_movement(
		match_data,
		mech_id,
		sender_id,
		hex,
		movement_type
	)
	
	if not validation.valid:
		Log.warning("Movement", "Move request rejected", {
			"peer": sender_id,
			"mech_id": mech_id,
			"reason": validation.reason,
			"context": validation.context
		})
		network_manager.rpc_id(sender_id, "client_action_rejected", validation.reason)
		return
	
	# Validación pasada - ejecutar movimiento
	var mech: Dictionary = match_data["mechs"][mech_id]
	var old_pos: Vector2i = mech["hex_position"]
	var max_mp: int = ServerMatchValidator.get_max_movement(mech, movement_type)
	var distance: int = ServerMatchValidator.hex_distance(old_pos, hex)
	
	mech["hex_position"] = hex
	mech["moved_this_turn"] = true
	mech["movement_type_used"] = movement_type
	mech["hexes_moved"] = distance
	mech["current_movement"] = max_mp - distance
	
	var new_facing: int = ServerMatchValidator.get_facing_to_hex(old_pos, hex)
	mech["facing"] = new_facing
	
	Log.info("Movement", "Mech moved", {
		"name": mech["name"],
		"from": [old_pos.x, old_pos.y],
		"to": [hex.x, hex.y],
		"facing": new_facing
	})
	
	var movement_heat = 0
	if movement_type == 2:
		movement_heat = 2
	elif movement_type == 3:
		movement_heat = distance
	
	mech["heat"] += movement_heat
	
	var opponent_peer = ServerMatchValidator.get_opponent_peer(match_data, sender_id)
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
	"""Processes rotation request with comprehensive validation"""
	if not ServerMatchValidator.validate_match_participant(active_battles, match_id, sender_id):
		return
	
	var match_data: Dictionary = active_battles[match_id]
	
	# Usar el nuevo validador comprehensivo
	var validation: ServerActionValidator.ValidationResult = ServerActionValidator.validate_rotation(
		match_data,
		mech_id,
		sender_id,
		new_facing
	)
	
	if not validation.valid:
		Log.warning("Movement", "Rotation request rejected", {
			"peer": sender_id,
			"mech_id": mech_id,
			"reason": validation.reason,
			"context": validation.context
		})
		network_manager.rpc_id(sender_id, "client_action_rejected", validation.reason)
		return
	
	# Validación pasada - ejecutar rotación
	var mech: Dictionary = match_data["mechs"][mech_id]
	var old_facing: int = mech["facing"]
	var rotations: int = ServerMatchValidator.calculate_rotations(old_facing, new_facing)
	
	mech["facing"] = new_facing
	mech["current_movement"] -= rotations
	
	var opponent_peer: int = ServerMatchValidator.get_opponent_peer(match_data, sender_id)
	var rotate_result: Dictionary = {
		"mech_id": mech_id,
		"old_facing": old_facing,
		"new_facing": new_facing,
		"mp_cost": rotations,
		"remaining_mp": mech["current_movement"]
	}
	
	network_manager.rpc_id(sender_id, "client_mech_rotated", rotate_result)
	network_manager.rpc_id(opponent_peer, "client_mech_rotated", rotate_result)

func _handle_fire_request(sender_id: int, match_id: int, attacker_id: int, target_id: int, weapon_indices: Array) -> void:
	"""Processes fire request with comprehensive validation"""
	Log.debug("Combat", "Fire request received", {
		"peer": sender_id,
		"attacker": attacker_id,
		"target": target_id,
		"weapons": weapon_indices
	})
	
	if not ServerMatchValidator.validate_match_participant(active_battles, match_id, sender_id):
		return
	
	var match_data: Dictionary = active_battles[match_id]
	
	# Usar el nuevo validador comprehensivo
	var validation: ServerActionValidator.ValidationResult = ServerActionValidator.validate_weapon_attack(
		match_data,
		attacker_id,
		target_id,
		weapon_indices,
		sender_id
	)
	
	if not validation.valid:
		Log.warning("Combat", "Fire request rejected", {
			"peer": sender_id,
			"attacker_id": attacker_id,
			"target_id": target_id,
			"reason": validation.reason,
			"context": validation.context
		})
		network_manager.rpc_id(sender_id, "client_action_rejected", validation.reason)
		return
	
	# Validación pasada - ejecutar ataque
	var attacker: Dictionary = match_data["mechs"][attacker_id]
	var target: Dictionary = match_data["mechs"][target_id]
	var range_hexes: int = ServerMatchValidator.hex_distance(attacker["hex_position"], target["hex_position"])
	
	var attack_results: Array = []
	var total_heat: int = 0
	
	for weapon_idx in weapon_indices:
		if weapon_idx >= attacker["weapons"].size():
			continue
		
		var weapon: Dictionary = attacker["weapons"][weapon_idx]
		var result: Dictionary = ServerCombatResolver.execute_weapon_attack(attacker, target, weapon, range_hexes, match_data["rng_seed"])
		attack_results.append(result)
		total_heat += weapon.get("heat", 0)
		
		match_data["rng_seed"] = (match_data["rng_seed"] * 1103515245 + 12345) % 2147483648
	
	attacker["heat"] += total_heat
	attacker["fired_this_turn"] = true
	
	var opponent_peer: int = ServerMatchValidator.get_opponent_peer(match_data, sender_id)
	var fire_result: Dictionary = {
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
	"""Processes physical attack request with comprehensive validation"""
	if not ServerMatchValidator.validate_match_participant(active_battles, match_id, sender_id):
		return
	
	var match_data: Dictionary = active_battles[match_id]
	
	# Usar el nuevo validador comprehensivo
	var validation: ServerActionValidator.ValidationResult = ServerActionValidator.validate_physical_attack(
		match_data,
		attacker_id,
		target_id,
		attack_type,
		sender_id
	)
	
	if not validation.valid:
		Log.warning("Combat", "Physical attack rejected", {
			"peer": sender_id,
			"attacker_id": attacker_id,
			"target_id": target_id,
			"attack_type": attack_type,
			"reason": validation.reason,
			"context": validation.context
		})
		network_manager.rpc_id(sender_id, "client_action_rejected", validation.reason)
		return
	
	# Validación pasada - ejecutar ataque físico
	var attacker: Dictionary = match_data["mechs"][attacker_id]
	var target: Dictionary = match_data["mechs"][target_id]
	
	var result: Dictionary = ServerCombatResolver.execute_physical_attack(attacker, target, attack_type, match_data["rng_seed"])
	match_data["rng_seed"] = (match_data["rng_seed"] * 1103515245 + 12345) % 2147483648
	
	var opponent_peer: int = ServerMatchValidator.get_opponent_peer(match_data, sender_id)
	var attack_result: Dictionary = {
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
	"""Processes end of activation"""
	Log.debug("Combat", "End activation request", {"peer": sender_id, "mech_id": mech_id})
	if not ServerMatchValidator.validate_match_participant(active_battles, match_id, sender_id):
		return
	
	var match_data = active_battles[match_id]
	
	if not ServerMatchValidator.validate_mech_ownership(match_data, mech_id, sender_id):
		return
	
	Log.info("Combat", "End activation accepted, advancing to next unit")
	_advance_to_next_unit(match_id)

# ============================================================
# LEGACY RPCs - Maintain for compatibility but redirect to handlers
# ============================================================

@rpc("any_peer", "reliable")
func server_request_deploy_mech(match_id: int, mech_data: Dictionary, hex_pos: Array, facing: int):
	var sender_id = multiplayer.get_remote_sender_id()
	_handle_deploy_request(sender_id, match_id, mech_data, hex_pos, facing)

@rpc("any_peer", "reliable")
func server_request_move(match_id: int, mech_id: int, target_hex: Array, movement_type: int):
	var sender_id = multiplayer.get_remote_sender_id()
	_handle_move_request(sender_id, match_id, mech_id, target_hex, movement_type)

@rpc("any_peer", "reliable")
func server_request_rotate(match_id: int, mech_id: int, new_facing: int):
	var sender_id = multiplayer.get_remote_sender_id()
	_handle_rotate_request(sender_id, match_id, mech_id, new_facing)

@rpc("any_peer", "reliable")
func server_request_fire(match_id: int, attacker_id: int, target_id: int, weapon_indices: Array):
	var sender_id = multiplayer.get_remote_sender_id()
	_handle_fire_request(sender_id, match_id, attacker_id, target_id, weapon_indices)

@rpc("any_peer", "reliable")
func server_request_physical_attack(match_id: int, attacker_id: int, target_id: int, attack_type: String):
	var sender_id = multiplayer.get_remote_sender_id()
	_handle_physical_request(sender_id, match_id, attacker_id, target_id, attack_type)

@rpc("any_peer", "reliable")
func server_request_end_activation(match_id: int, mech_id: int):
	var sender_id = multiplayer.get_remote_sender_id()
	_handle_end_activation(sender_id, match_id, mech_id)

# ============================================================
# CLIENT RPC STUBS
# ============================================================

@rpc("authority", "reliable")
func client_start_deployment(_match_id: int, _team: String):
	pass

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
# PHASE LOGIC
# ============================================================

func _execute_initiative_roll(match_id: int):
	"""Executes initiative roll when both players are ready"""
	if match_id not in active_battles:
		return
	var match_data = active_battles[match_id]
	match_data["current_turn"] += 1
	match_data["current_phase"] = "initiative"
	
	var init_result = ServerPhaseManager.execute_initiative_roll(match_data)
	match_data["initiative_winner"] = init_result["winner"]
	match_data["rng_seed"] = init_result["new_rng_seed"]
	
	network_manager.rpc_id(match_data["player1_peer"], "client_initiative_result", init_result)
	network_manager.rpc_id(match_data["player2_peer"], "client_initiative_result", init_result)
	
	match_data["current_phase"] = "waiting_for_start"

func _start_initiative_phase(match_id: int):
	"""Starts initiative phase for a new turn"""
	if match_id not in active_battles:
		return
	
	var match_data = active_battles[match_id]
	match_data["current_turn"] += 1
	
	ServerPhaseManager.reset_ready_flags(match_data)
	match_data["current_phase"] = "waiting_for_rolls"
	
	Log.info("Match", "Starting initiative phase", {"turn": match_data["current_turn"]})
	
	network_manager.rpc_id(match_data["player1_peer"], "client_phase_changed", "initiative", match_data["current_turn"])
	network_manager.rpc_id(match_data["player2_peer"], "client_phase_changed", "initiative", match_data["current_turn"])

func _start_movement_phase(match_id: int):
	"""Starts movement phase"""
	if match_id not in active_battles:
		return
	var match_data = active_battles[match_id]
	match_data["current_phase"] = "movement"
	
	Log.info("Match", "Starting movement phase", {"match_id": match_id})
	
	ServerPhaseManager.reset_movement_for_all_mechs(match_data)
	
	match_data["units_to_activate"] = ServerPhaseManager.build_activation_order(match_data, "movement")
	match_data["current_unit_index"] = 0
	
	var peer1 = match_data["player1_peer"]
	var peer2 = match_data["player2_peer"]
	var connected_peers = multiplayer.get_peers()
	
	if peer1 in connected_peers:
		network_manager.rpc_id(peer1, "client_phase_changed", "movement", match_data["current_turn"])
	if peer2 in connected_peers:
		network_manager.rpc_id(peer2, "client_phase_changed", "movement", match_data["current_turn"])
	
	await get_tree().create_timer(0.5).timeout
	if match_id not in active_battles:
		return
	_activate_next_unit(match_id)

func _start_weapon_phase(match_id: int):
	"""Starts weapon attack phase"""
	Log.info("Combat", "*** STARTING WEAPON ATTACK PHASE ***", {"match_id": match_id})
	if match_id not in active_battles:
		return
	var match_data = active_battles[match_id]
	match_data["current_phase"] = "weapon_attack"
	
	ServerPhaseManager.reset_firing_for_all_mechs(match_data)
	
	match_data["units_to_activate"] = ServerPhaseManager.build_activation_order(match_data, "attack")
	match_data["current_unit_index"] = 0
	
	network_manager.rpc_id(match_data["player1_peer"], "client_phase_changed", "weapon_attack", match_data["current_turn"])
	network_manager.rpc_id(match_data["player2_peer"], "client_phase_changed", "weapon_attack", match_data["current_turn"])
	
	await get_tree().create_timer(0.5).timeout
	if match_id not in active_battles:
		return
	_activate_next_unit(match_id)

func _start_physical_phase(match_id: int):
	"""Starts physical attack phase"""
	if match_id not in active_battles:
		return
	var match_data = active_battles[match_id]
	match_data["current_phase"] = "physical_attack"
	
	match_data["units_to_activate"] = ServerPhaseManager.build_activation_order(match_data, "attack")
	match_data["current_unit_index"] = 0
	
	network_manager.rpc_id(match_data["player1_peer"], "client_phase_changed", "physical_attack", match_data["current_turn"])
	network_manager.rpc_id(match_data["player2_peer"], "client_phase_changed", "physical_attack", match_data["current_turn"])
	
	await get_tree().create_timer(0.5).timeout
	if match_id not in active_battles:
		return
	_activate_next_unit(match_id)

func _start_heat_phase(match_id: int):
	"""Processes heat phase"""
	if match_id not in active_battles:
		return
	var match_data = active_battles[match_id]
	match_data["current_phase"] = "heat"
	
	Log.info("Heat", "Starting heat phase", {"match_id": match_id})
	
	network_manager.rpc_id(match_data["player1_peer"], "client_phase_changed", "heat", match_data["current_turn"])
	network_manager.rpc_id(match_data["player2_peer"], "client_phase_changed", "heat", match_data["current_turn"])
	
	await get_tree().create_timer(0.5).timeout
	
	if match_id not in active_battles:
		return
	
	var heat_results = ServerPhaseManager.process_all_mechs_heat(match_data)
	
	network_manager.rpc_id(match_data["player1_peer"], "client_heat_phase_result", heat_results)
	network_manager.rpc_id(match_data["player2_peer"], "client_heat_phase_result", heat_results)
	
	_check_battle_end(match_id)
	
	if match_id not in active_battles:
		return
	
	await get_tree().create_timer(2.0).timeout
	
	if match_id not in active_battles:
		return
	
	_start_initiative_phase(match_id)

func _activate_next_unit(match_id: int):
	"""Activates the next unit"""
	var match_data = active_battles[match_id]
	
	if match_data["units_to_activate"].is_empty():
		_advance_phase(match_id)
		return
	
	if match_data["current_unit_index"] >= match_data["units_to_activate"].size():
		_advance_phase(match_id)
		return
	
	var mech_id = match_data["units_to_activate"][match_data["current_unit_index"]]
	var mech = match_data["mechs"][mech_id]
	
	var owner_peer = mech["owner_peer"]
	var opponent_peer = ServerMatchValidator.get_opponent_peer(match_data, owner_peer)
	
	var connected_peers = multiplayer.get_peers()
	
	if owner_peer in connected_peers:
		network_manager.rpc_id(owner_peer, "client_unit_activated", mech_id, true)
	if opponent_peer in connected_peers:
		network_manager.rpc_id(opponent_peer, "client_unit_activated", mech_id, false)
	
	Log.info("Combat", "Unit activated", {"name": mech["name"], "peer": owner_peer})

func _advance_to_next_unit(match_id: int):
	"""Advances to next mech in activation list"""
	var match_data = active_battles[match_id]
	match_data["current_unit_index"] += 1
	_activate_next_unit(match_id)

func _advance_phase(match_id: int):
	"""Advances to next phase"""
	var match_data = active_battles[match_id]
	Log.info("Match", "_advance_phase called", {"current_phase": match_data["current_phase"]})
	
	match match_data["current_phase"]:
		"movement":
			_start_weapon_phase(match_id)
		"weapon_attack":
			_start_physical_phase(match_id)
		"physical_attack":
			_start_heat_phase(match_id)
		"heat":
			_start_initiative_phase(match_id)

func _check_battle_end(match_id: int):
	"""Checks if the battle ended"""
	var match_data = active_battles[match_id]
	var result = ServerMatchValidator.check_battle_end(match_data)
	
	if result["ended"]:
		Log.match_event("Battle ended - Winner: %s, Reason: %s" % [result["winner"], result["reason"]], str(match_id))
		
		network_manager.rpc_id(match_data["player1_peer"], "client_battle_ended", result["winner"], result["reason"])
		network_manager.rpc_id(match_data["player2_peer"], "client_battle_ended", result["winner"], result["reason"])
		
		active_battles.erase(match_id)
