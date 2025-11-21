extends RefCounted

## Sistema de calor - Maneja acumulación, disipación y efectos del calor
## Responsabilidad única: Gestión de calor

const HEAT_THRESHOLDS = {
	5: "Movement -1",
	8: "+1 to-hit",
	10: "Movement -2",
	13: "+2 to-hit", 
	15: "Movement -3",
	17: "+3 to-hit",
	19: "Shutdown check",
	20: "Movement -4",
	23: "Shutdown",
	24: "+4 to-hit",
	25: "Movement -5",
	28: "Ammo explosion check",
	30: "Mech destroyed"
}

static func add_heat(mech, amount: int) -> void:
	mech.heat = min(mech.heat + amount, mech.max_heat)

static func dissipate_heat(mech) -> int:
	var dissipated = min(mech.heat, mech.heat_sinks)
	mech.heat -= dissipated
	return dissipated

static func check_shutdown(mech) -> bool:
	if mech.heat < 19:
		return false
	
	var target = 0
	if mech.heat >= 19 and mech.heat < 23:
		target = 10 - (mech.heat - 19)
	elif mech.heat >= 23:
		return true  # Shutdown automático
	
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1)
	return roll < target

static func check_ammo_explosion(mech) -> bool:
	if mech.heat < 28:
		return false
	
	var target = 8
	if mech.heat >= 28:
		target = 8
	
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1)
	return roll >= target

static func get_heat_effects(heat_level: int) -> Array:
	var effects = []
	for threshold in HEAT_THRESHOLDS.keys():
		if heat_level >= threshold:
			effects.append(HEAT_THRESHOLDS[threshold])
	return effects

static func get_movement_penalty(heat_level: int) -> int:
	var penalty = 0
	if heat_level >= 5: penalty = 1
	if heat_level >= 10: penalty = 2
	if heat_level >= 15: penalty = 3
	if heat_level >= 20: penalty = 4
	if heat_level >= 25: penalty = 5
	return penalty

static func get_to_hit_penalty(heat_level: int) -> int:
	var penalty = 0
	if heat_level >= 8: penalty = 1
	if heat_level >= 13: penalty = 2
	if heat_level >= 17: penalty = 3
	if heat_level >= 24: penalty = 4
	return penalty
