class_name WeaponSystem
extends RefCounted

## Sistema de armas - Maneja disparo, cálculo de golpe y daño
## Responsabilidad única: Gestión de armas y combate a distancia

static func calculate_to_hit(attacker, target, weapon: Dictionary, range_in_hexes: int) -> int:
	var base_gunnery = attacker.pilot_gunnery
	
	# Modificador por rango
	var range_mod = 0
	if range_in_hexes <= weapon.get("short_range", 3):
		range_mod = 0
	elif range_in_hexes <= weapon.get("medium_range", 6):
		range_mod = 2
	elif range_in_hexes <= weapon.get("long_range", 9):
		range_mod = 4
	else:
		return -1  # Fuera de rango
	
	# Modificador por movimiento del atacante
	var attacker_movement_mod = 0
	if attacker.moved_this_turn:
		attacker_movement_mod = 1
		if attacker.ran_this_turn:
			attacker_movement_mod = 2
	
	# Modificador por movimiento del objetivo
	var target_movement_mod = 0
	if target.moved_this_turn:
		target_movement_mod = 1
		if target.ran_this_turn:
			target_movement_mod = 2
	
	# Modificador por calor
	var heat_mod = 0
	if attacker.heat >= 8:
		heat_mod = 1
	if attacker.heat >= 13:
		heat_mod = 2
	if attacker.heat >= 17:
		heat_mod = 3
	if attacker.heat >= 24:
		heat_mod = 4
	
	# Modificador por estar tumbado
	var prone_mod = 0
	if attacker.is_prone:
		prone_mod = 2
	
	var target_number = base_gunnery + range_mod + attacker_movement_mod + target_movement_mod + heat_mod + prone_mod
	
	return target_number

static func roll_to_hit(target_number: int) -> bool:
	if target_number < 2:
		target_number = 2
	if target_number > 12:
		return false  # Imposible acertar
	
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1)
	return roll >= target_number

static func calculate_damage(weapon: Dictionary) -> int:
	return weapon.get("damage", 5)

static func determine_hit_location() -> String:
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1)
	
	match roll:
		2: return "center_torso"
		3: return "right_arm"
		4: return "right_arm"
		5: return "right_leg"
		6: return "right_torso"
		7: return "center_torso"
		8: return "left_torso"
		9: return "left_leg"
		10: return "left_arm"
		11: return "left_arm"
		12: return "head"
		_: return "center_torso"
