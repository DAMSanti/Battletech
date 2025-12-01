# server_combat_resolver.gd
# Combat resolution logic for authoritative server
# Part of Phase 5 SOLID refactoring - extracted from server_battle_manager.gd
class_name ServerCombatResolver
extends RefCounted

## Executes a weapon attack and returns the result
static func execute_weapon_attack(attacker: Dictionary, target: Dictionary, weapon: Dictionary, range_hexes: int, rng_seed: int) -> Dictionary:
	seed(rng_seed)
	
	# Calculate to-hit
	var gunnery = attacker.get("gunnery_skill", 4)
	var attacker_mod = _get_attacker_movement_modifier(attacker)
	var target_mod = _get_target_movement_modifier(target)
	var range_mod = _get_range_modifier(weapon, range_hexes)
	
	if range_mod >= 999:
		return {"hit": false, "reason": "out_of_range", "roll": 0, "target": 0}
	
	var target_number = gunnery + attacker_mod + target_mod + range_mod
	
	# Roll 2D6
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
	
	# Check hit
	if roll == 2:
		result["hit"] = false
		result["critical_miss"] = true
	elif roll == 12 or roll >= target_number:
		result["hit"] = true
		
		# Determine hit location
		var loc_roll = (randi() % 6 + 1) + (randi() % 6 + 1)
		var location = _get_hit_location(loc_roll)
		result["location"] = location
		result["location_roll"] = loc_roll
		
		# Apply damage
		var damage = weapon.get("damage", 0)
		var damage_result = apply_damage(target, location, damage)
		result["damage"] = damage
		result["damage_result"] = damage_result
	else:
		result["hit"] = false
	
	return result

## Executes a physical attack and returns the result
static func execute_physical_attack(attacker: Dictionary, target: Dictionary, attack_type: String, rng_seed: int) -> Dictionary:
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
		
		# Calculate damage based on type
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
		
		var damage_result = apply_damage(target, location, damage)
		result["damage_result"] = damage_result
	else:
		result["hit"] = false
	
	return result

## Applies damage to a mech and returns the result
static func apply_damage(target: Dictionary, location: String, damage: int) -> Dictionary:
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
	
	# Apply to armor
	var armor_damage = min(damage, current_armor)
	armor_data["current"] = current_armor - armor_damage
	damage -= armor_damage
	
	result["armor_remaining"] = armor_data["current"]
	
	# If damage remains, goes to structure
	if damage > 0:
		result["critical_hit"] = true
		# Simplified: if damage penetrates armor in center torso or head, mech destroyed
		if location in ["center_torso", "head"]:
			target["is_destroyed"] = true
			result["mech_destroyed"] = true
	
	return result

## Processes heat for a mech
static func process_mech_heat(mech: Dictionary, rng_seed: int) -> Dictionary:
	seed(rng_seed)
	
	var initial_heat = mech["heat"]
	var result = {
		"initial_heat": initial_heat,
		"dissipated": 0,
		"final_heat": 0,
		"shutdown": false,
		"ammo_explosion": false
	}
	
	# Dissipate heat
	var dissipation = mech["heat_dissipation"]
	mech["heat"] = max(0, mech["heat"] - dissipation)
	result["dissipated"] = min(dissipation, initial_heat)
	result["final_heat"] = mech["heat"]
	
	# Check shutdown (simplified)
	if initial_heat >= 14:
		var shutdown_target = 4 if initial_heat >= 22 else (6 if initial_heat >= 18 else 8)
		var roll = (randi() % 6 + 1) + (randi() % 6 + 1)
		if roll < shutdown_target:
			mech["is_shutdown"] = true
			result["shutdown"] = true
	
	return result

# ============================================================
# MODIFIER CALCULATIONS
# ============================================================

static func _get_attacker_movement_modifier(attacker: Dictionary) -> int:
	match attacker["movement_type_used"]:
		1:  # Walk
			return 1
		2:  # Run
			return 2
		3:  # Jump
			return 3
	return 0

static func _get_target_movement_modifier(target: Dictionary) -> int:
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

static func _get_range_modifier(weapon: Dictionary, range_hexes: int) -> int:
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

static func _get_hit_location(roll: int) -> String:
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
