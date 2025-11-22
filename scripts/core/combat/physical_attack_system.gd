class_name PhysicalAttackSystem
extends RefCounted

## Sistema de ataques físicos
## Responsabilidad: Calcular to-hit y daño de ataques cuerpo a cuerpo

# Tipos de ataques físicos
enum AttackType {
	PUNCH,      # Puñetazo
	KICK,       # Patada
	CHARGE,     # Embestida
	DFA,        # Death From Above (salto sobre enemigo)
	PUSH        # Empujón
}

# Tabla de localización para puñetazos (2D6)
const PUNCH_LOCATION_TABLE = {
	2: "head",           # Cabeza (crítico)
	3: "left_torso",     # Torso izquierdo
	4: "left_torso",     # Torso izquierdo
	5: "left_arm",       # Brazo izquierdo
	6: "center_torso",   # Torso central
	7: "center_torso",   # Torso central
	8: "center_torso",   # Torso central
	9: "right_arm",      # Brazo derecho
	10: "right_torso",   # Torso derecho
	11: "right_torso",   # Torso derecho
	12: "head"           # Cabeza (crítico)
}

# Tabla de localización para patadas (2D6)
const KICK_LOCATION_TABLE = {
	2: "left_leg",       # Pierna izquierda
	3: "left_leg",       # Pierna izquierda
	4: "left_leg",       # Pierna izquierda
	5: "left_leg",       # Pierna izquierda
	6: "left_leg",       # Pierna izquierda
	7: "right_leg",      # Pierna derecha
	8: "right_leg",      # Pierna derecha
	9: "right_leg",      # Pierna derecha
	10: "right_leg",     # Pierna derecha
	11: "right_leg",     # Pierna derecha
	12: "right_leg"      # Pierna derecha
}

static func calculate_punch_damage(attacker_tonnage: int) -> int:
	# Daño de puñetazo = Tonnage / 10 (redondeado)
	return int(ceil(float(attacker_tonnage) / 10.0))

static func calculate_kick_damage(attacker_tonnage: int) -> int:
	# Daño de patada = Tonnage / 5 (redondeado) - el doble que puñetazo
	return int(ceil(float(attacker_tonnage) / 5.0))

static func calculate_charge_damage(attacker_tonnage: int, hexes_moved: int) -> int:
	# Daño de embestida = (Tonnage / 10) * Hexes moved
	var base_damage = int(ceil(float(attacker_tonnage) / 10.0))
	return base_damage * hexes_moved

static func calculate_to_hit(attacker, target, attack_type: AttackType, _modifiers: Dictionary = {}) -> Dictionary:
	# Calcula el número objetivo para impactar con ataque físico
	var target_number = 4  # Base para ataques físicos
	var mod_list = {}
	
	# Modificador por habilidad del piloto
	var pilot_skill = attacker.pilot_skill if "pilot_skill" in attacker else 4
	mod_list["pilot_skill"] = pilot_skill
	target_number += pilot_skill
	
	# Modificador por tipo de ataque
	match attack_type:
		AttackType.PUNCH:
			# Puñetazo: sin modificador adicional
			pass
		AttackType.KICK:
			# Patada: +2 más difícil
			mod_list["kick"] = 2
			target_number += 2
		AttackType.CHARGE:
			# Embestida: más fácil
			mod_list["charge"] = -2
			target_number -= 2
	
	# Modificador por movimiento del objetivo (TMM)
	var target_tmm = target.target_movement_modifier if "target_movement_modifier" in target else 0
	if target_tmm > 0:
		mod_list["target_tmm"] = target_tmm
		target_number += target_tmm
	
	# Modificador por calor
	if "heat" in attacker and attacker.heat >= 5:
		var heat_mod = int(attacker.heat / 5)
		mod_list["heat"] = heat_mod
		target_number += heat_mod
	
	# Modificador si el objetivo está caído
	if "is_prone" in target and target.is_prone:
		mod_list["target_prone"] = -2
		target_number -= 2
	
	return {
		"target_number": target_number,
		"modifiers": mod_list
	}

static func roll_to_hit() -> int:
	# Tira 2D6
	var die1 = randi() % 6 + 1
	var die2 = randi() % 6 + 1
	return die1 + die2

static func check_hit(roll: int, target_number: int) -> bool:
	# Verifica si el ataque impacta
	if roll == 2:
		return false  # Fallo crítico
	if roll == 12:
		return true   # Impacto crítico
	
	return roll >= target_number

static func roll_punch_location() -> String:
	# Determina dónde impacta el puñetazo
	var roll = roll_to_hit()
	return PUNCH_LOCATION_TABLE.get(roll, "center_torso")

static func roll_kick_location() -> String:
	# Determina dónde impacta la patada
	var roll = roll_to_hit()
	return KICK_LOCATION_TABLE.get(roll, "right_leg")

static func check_fall_after_kick(attacker) -> bool:
	# Verifica si el atacante se cae después de fallar una patada
	# Requiere chequeo de pilotaje con +1
	if attacker.has_method("check_piloting_skill_roll"):
		return not attacker.check_piloting_skill_roll(1)
	return false

static func apply_charge_self_damage(_attacker, damage_to_target: int) -> int:
	# El atacante recibe daño por embestir = 1/10 del daño causado (redondeado)
	return int(ceil(float(damage_to_target) / 10.0))

static func can_punch(attacker, arm: String) -> Dictionary:
	# Verifica si puede usar un brazo para golpear
	var result = {"can_punch": true, "reason": ""}
	
	# Verificar que el brazo no esté destruido
	var arm_location = "left_arm" if arm == "left" else "right_arm"
	
	if "structure" in attacker:
		if attacker.structure.has(arm_location):
			if attacker.structure[arm_location]["current"] <= 0:
				result["can_punch"] = false
				result["reason"] = "Arm destroyed"
				return result
	
	return result

static func can_kick(attacker) -> Dictionary:
	# Verifica si puede patear
	var result = {"can_kick": true, "reason": ""}
	
	# Verificar que al menos una pierna esté funcional
	if "structure" in attacker:
		var left_leg_ok = attacker.structure["left_leg"]["current"] > 0
		var right_leg_ok = attacker.structure["right_leg"]["current"] > 0
		
		if not left_leg_ok and not right_leg_ok:
			result["can_kick"] = false
			result["reason"] = "Both legs destroyed"
			return result
	
	# No se puede patear si está caído
	if "is_prone" in attacker and attacker.is_prone:
		result["can_kick"] = false
		result["reason"] = "Cannot kick while prone"
		return result
	
	return result

static func can_charge(attacker) -> Dictionary:
	# Verifica si puede embestir (requiere haber corrido este turno)
	var result = {"can_charge": true, "reason": ""}
	
	# Debe haber usado movimiento RUN
	if "movement_type_used" in attacker:
		if attacker.movement_type_used != 2:  # 2 = RUN
			result["can_charge"] = false
			result["reason"] = "Must run to charge"
			return result
	
	# Debe haber movido al menos 2 hexes
	if "hexes_moved_this_turn" in attacker:
		if attacker.hexes_moved_this_turn < 2:
			result["can_charge"] = false
			result["reason"] = "Must move at least 2 hexes"
			return result
	
	return result
