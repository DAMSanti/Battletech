class_name PhysicalAttackSystem
extends RefCounted

## Sistema de ataques físicos - Maneja puñetazos, patadas, empujes y cargas
## Responsabilidad única: Combate cuerpo a cuerpo

const PUNCH_BASE_DAMAGE = 1  # Por cada 10 tons
const KICK_BASE_DAMAGE = 2   # Por cada 10 tons

static func can_punch(attacker) -> bool:
	return not attacker.is_prone and attacker.arms_functional > 0

static func can_kick(attacker) -> bool:
	return not attacker.is_prone

static func can_push(attacker) -> bool:
	return not attacker.is_prone

static func can_charge(attacker) -> bool:
	return not attacker.is_prone and attacker.ran_this_turn

static func calculate_punch_to_hit(attacker, target) -> int:
	var base_piloting = attacker.pilot_piloting
	
	var height_mod = 0
	if target.is_prone:
		height_mod = -2
	
	var attacker_damage_mod = 0
	if attacker.arms_functional == 1:
		attacker_damage_mod = 1
	
	return base_piloting + height_mod + attacker_damage_mod

static func calculate_kick_to_hit(attacker, target) -> int:
	var base_piloting = attacker.pilot_piloting
	
	var height_mod = 0
	if target.is_prone:
		height_mod = -2
	
	return base_piloting + 2 + height_mod  # +2 porque patear es más difícil

static func calculate_push_to_hit(attacker, target) -> int:
	return attacker.pilot_piloting

static func calculate_charge_to_hit(attacker, target) -> int:
	return attacker.pilot_piloting + 1

static func calculate_punch_damage(attacker) -> int:
	var tonnage = attacker.tonnage
	var base_damage = (tonnage / 10) * PUNCH_BASE_DAMAGE
	return int(base_damage)

static func calculate_kick_damage(attacker) -> int:
	var tonnage = attacker.tonnage
	var base_damage = (tonnage / 10) * KICK_BASE_DAMAGE
	return int(base_damage)

static func calculate_push_damage(attacker) -> int:
	return 0  # Push no hace daño, solo mueve

static func calculate_charge_damage(attacker, hexes_moved: int) -> int:
	var tonnage = attacker.tonnage
	var damage = int((tonnage / 10.0) * hexes_moved)
	return damage

static func calculate_charge_self_damage(attacker, hexes_moved: int) -> int:
	var tonnage = attacker.tonnage
	var self_damage = int((tonnage / 10.0) * (hexes_moved / 2.0))
	return self_damage

static func roll_to_hit(target_number: int) -> bool:
	if target_number < 2:
		target_number = 2
	if target_number > 12:
		return false
	
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1)
	return roll >= target_number

static func determine_punch_location() -> String:
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1)
	
	if roll <= 5:
		return "head"
	elif roll <= 9:
		return "center_torso"
	else:
		return "left_arm" if randf() > 0.5 else "right_arm"

static func determine_kick_location() -> String:
	return "right_leg" if randf() > 0.5 else "left_leg"
