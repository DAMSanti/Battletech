# server_match_validator.gd
# Match validation and utility functions for authoritative server
# Part of Phase 5 SOLID refactoring - extracted from server_battle_manager.gd
class_name ServerMatchValidator
extends RefCounted

# ============================================================
# VALIDATION FUNCTIONS
# ============================================================

## Validates that a peer is a participant in the match
static func validate_match_participant(active_battles: Dictionary, match_id: int, peer_id: int) -> bool:
	if match_id not in active_battles:
		Log.warning("Match", "Match not found", {
			"match_id": match_id,
			"active_battles": active_battles.keys()
		})
		return false
	
	var match_data = active_battles[match_id]
	return peer_id == match_data["player1_peer"] or peer_id == match_data["player2_peer"]

## Validates that a peer owns a specific mech
static func validate_mech_ownership(match_data: Dictionary, mech_id: int, peer_id: int) -> bool:
	if mech_id not in match_data["mechs"]:
		return false
	return match_data["mechs"][mech_id]["owner_peer"] == peer_id

## Validates deployment hex based on team
static func is_valid_deployment_hex(hex: Vector2i, team: String) -> bool:
	# Flexible deployment zone for different map sizes
	# Player: south (last 5 rows: y >= 13 for compatibility)
	# Enemy: north (first 5 rows: y < 5)
	if team == "player":
		return hex.y >= 13
	else:  # team == "enemy"
		return hex.y < 5

# ============================================================
# TEAM / PEER HELPERS
# ============================================================

## Gets the team string for a peer
static func get_team_for_peer(match_data: Dictionary, peer_id: int) -> String:
	if peer_id == match_data["player1_peer"]:
		return "player"
	return "enemy"

## Gets the opponent's peer ID
static func get_opponent_peer(match_data: Dictionary, peer_id: int) -> int:
	if peer_id == match_data["player1_peer"]:
		return match_data["player2_peer"]
	return match_data["player1_peer"]

## Generates a unique mech ID
static func generate_mech_id(match_id: int, team: String) -> int:
	return hash(str(match_id) + "_" + team + "_" + str(Time.get_ticks_msec()))

## Generates a unique match ID
static func generate_match_id(peer1: int, peer2: int) -> int:
	return hash(str(peer1) + "_" + str(peer2) + "_" + str(Time.get_ticks_msec()))

# ============================================================
# HEX / MOVEMENT UTILITIES
# ============================================================

## Calculates hex distance between two positions
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dx = abs(a.x - b.x)
	var dy = abs(a.y - b.y)
	return max(dx, dy)

## Gets the facing direction from one hex to another
static func get_facing_to_hex(from: Vector2i, to: Vector2i) -> int:
	var dx = to.x - from.x
	var dy = to.y - from.y
	
	# Hexagonal offset coordinates directions:
	# 0 = North (dy < 0)
	# 1 = Northeast (dx > 0, dy <= 0)
	# 2 = Southeast (dx > 0, dy >= 0)
	# 3 = South (dy > 0)
	# 4 = Southwest (dx < 0, dy >= 0)
	# 5 = Northwest (dx < 0, dy <= 0)
	
	if dx == 0:
		if dy < 0:
			return 0  # North
		else:
			return 3  # South
	elif dx > 0:
		if dy <= 0:
			return 1  # Northeast
		else:
			return 2  # Southeast
	else:  # dx < 0
		if dy <= 0:
			return 5  # Northwest
		else:
			return 4  # Southwest

## Gets maximum movement points based on movement type
static func get_max_movement(mech: Dictionary, movement_type: int) -> int:
	match movement_type:
		1:  # Walk
			return mech["walk_mp"]
		2:  # Run
			return mech["run_mp"]
		3:  # Jump
			return mech["jump_mp"]
	return mech["walk_mp"]

## Calculates rotation cost between two facings
static func calculate_rotations(from_facing: int, to_facing: int) -> int:
	var diff = (to_facing - from_facing + 6) % 6
	return min(diff, 6 - diff)

# ============================================================
# BATTLE END CHECK
# ============================================================

## Checks if the battle has ended and returns winner info
static func check_battle_end(match_data: Dictionary) -> Dictionary:
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
	
	var result = {
		"ended": false,
		"winner": "",
		"reason": ""
	}
	
	if not player_alive or not enemy_alive:
		result["ended"] = true
		result["winner"] = "player" if player_alive else "enemy"
		result["reason"] = "All enemy mechs destroyed" if player_alive else "All player mechs destroyed"
	
	return result
