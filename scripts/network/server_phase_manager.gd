# server_phase_manager.gd
# Phase management logic for authoritative server
# Part of Phase 5 SOLID refactoring - extracted from server_battle_manager.gd
class_name ServerPhaseManager
extends RefCounted

# Preload combat resolver
const ServerCombatResolver = preload("res://scripts/network/server_combat_resolver.gd")

# ============================================================
# INITIATIVE ROLL
# ============================================================

## Executes initiative roll and returns the result
static func execute_initiative_roll(match_data: Dictionary) -> Dictionary:
	seed(match_data["rng_seed"])
	
	var player_mech_rolls = []
	var enemy_mech_rolls = []
	var player_total = 0
	var enemy_total = 0
	
	# Collect mechs by team
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
	
	# Roll dice for each player mech
	for mech in player_mechs_list:
		var die1 = randi() % 6 + 1
		var die2 = randi() % 6 + 1
		player_mech_rolls.append([die1, die2])
		player_total += die1 + die2
		Log.debug("Combat", "Player mech initiative roll", {
			"name": mech["name"],
			"die1": die1,
			"die2": die2,
			"total": die1 + die2
		})
	
	# Roll dice for each enemy mech
	for mech in enemy_mechs_list:
		var die1 = randi() % 6 + 1
		var die2 = randi() % 6 + 1
		enemy_mech_rolls.append([die1, die2])
		enemy_total += die1 + die2
		Log.debug("Combat", "Enemy mech initiative roll", {
			"name": mech["name"],
			"die1": die1,
			"die2": die2,
			"total": die1 + die2
		})
	
	# Winner has highest total (tie goes to player)
	var winner = "player" if player_total >= enemy_total else "enemy"
	
	var init_result = {
		"turn": match_data["current_turn"],
		"player_mech_rolls": player_mech_rolls,
		"enemy_mech_rolls": enemy_mech_rolls,
		"player_total": player_total,
		"enemy_total": enemy_total,
		"winner": winner,
		"new_rng_seed": randi()
	}
	
	Log.info("Combat", "Initiative result", {
		"player_total": player_total,
		"enemy_total": enemy_total,
		"winner": winner
	})
	
	return init_result

# ============================================================
# ACTIVATION ORDER
# ============================================================

## Builds the activation order based on BattleTech rules
static func build_activation_order(match_data: Dictionary, phase_type: String) -> Array:
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
	
	# Movement: initiative winner moves LAST
	# Attack: initiative winner attacks FIRST
	var first_team: Array
	var last_team: Array
	
	if phase_type == "movement":
		first_team = enemy_mechs if match_data["initiative_winner"] == "player" else player_mechs
		last_team = player_mechs if match_data["initiative_winner"] == "player" else enemy_mechs
	else:
		first_team = player_mechs if match_data["initiative_winner"] == "player" else enemy_mechs
		last_team = enemy_mechs if match_data["initiative_winner"] == "player" else player_mechs
	
	# Alternate between teams
	var units_to_activate = []
	var max_units = max(first_team.size(), last_team.size())
	for i in range(max_units):
		if i < first_team.size():
			units_to_activate.append(first_team[i])
		if i < last_team.size():
			units_to_activate.append(last_team[i])
	
	Log.debug("Combat", "Built activation order", {
		"units_to_activate": units_to_activate.size(),
		"player_mechs": player_mechs.size(),
		"enemy_mechs": enemy_mechs.size()
	})
	
	return units_to_activate

# ============================================================
# PHASE RESET FUNCTIONS
# ============================================================

## Resets movement data for all mechs at start of movement phase
static func reset_movement_for_all_mechs(match_data: Dictionary) -> void:
	for mech_id in match_data["mechs"]:
		var mech = match_data["mechs"][mech_id]
		mech["moved_this_turn"] = false
		mech["current_movement"] = mech["walk_mp"]
		mech["movement_type_used"] = 0
		mech["hexes_moved"] = 0

## Resets firing flags for all mechs at start of weapon phase
static func reset_firing_for_all_mechs(match_data: Dictionary) -> void:
	for mech_id in match_data["mechs"]:
		match_data["mechs"][mech_id]["fired_this_turn"] = false

## Resets ready flags for a new turn
static func reset_ready_flags(match_data: Dictionary) -> void:
	match_data["player1_roll_ready"] = false
	match_data["player2_roll_ready"] = false
	match_data["player1_start_ready"] = false
	match_data["player2_start_ready"] = false

# ============================================================
# PHASE TRANSITION HELPERS
# ============================================================

## Gets the next phase after current phase
static func get_next_phase(current_phase: String) -> String:
	match current_phase:
		"movement":
			return "weapon_attack"
		"weapon_attack":
			return "physical_attack"
		"physical_attack":
			return "heat"
		"heat":
			return "initiative"
	return "initiative"

## Processes heat for all mechs and returns results
static func process_all_mechs_heat(match_data: Dictionary) -> Array:
	var heat_results = []
	
	for mech_id in match_data["mechs"]:
		var mech = match_data["mechs"][mech_id]
		if mech["is_destroyed"]:
			continue
		
		var result = ServerCombatResolver.process_mech_heat(mech, match_data["rng_seed"])
		match_data["rng_seed"] = (match_data["rng_seed"] * 1103515245 + 12345) % 2147483648
		
		result["mech_id"] = mech_id
		heat_results.append(result)
	
	return heat_results
