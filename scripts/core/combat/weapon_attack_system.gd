class_name WeaponAttackSystem
extends RefCounted

## Sistema de ataque con armas
## Responsabilidad: Calcular to-hit, aplicar daño, generar calor

# Referencia a ComponentDatabase para verificar ECM/BAP
const component_db = preload("res://scripts/core/component_database.gd")

# Modificadores base para to-hit
const BASE_TO_HIT = 4  # Target number base en Battletech

# Tabla de localización de impactos (2D6)
# Para disparos frontales/laterales
const HIT_LOCATION_TABLE = {
	2: "center_torso",   # Centro del torso
	3: "right_arm",      # Brazo derecho
	4: "right_arm",      # Brazo derecho
	5: "right_leg",      # Pierna derecha
	6: "right_torso",    # Torso derecho
	7: "center_torso",   # Centro del torso
	8: "left_torso",     # Torso izquierdo
	9: "left_leg",       # Pierna izquierda
	10: "left_arm",      # Brazo izquierdo
	11: "left_arm",      # Brazo izquierdo
	12: "head"           # Cabeza
}

static func calculate_to_hit(attacker, target, weapon, range_hexes: int, terrain_modifier: int = 0) -> Dictionary:
	# Calcula el número objetivo y modificadores para impactar según BattleTech Total Warfare
	# Retorna: { "target_number": int, "modifiers": Dictionary, "breakdown": String }
	
	var modifiers = {}
	var breakdown_lines = []
	
	# 1. Gunnery Skill del piloto (base)
	var gunnery_skill = attacker.pilot_skill if "pilot_skill" in attacker else 4
	modifiers["gunnery_skill"] = gunnery_skill
	breakdown_lines.append("Gunnery Skill: +%d" % gunnery_skill)
	
	# 2. Modificador por movimiento del atacante
	var attacker_movement_mod = attacker.get_attacker_movement_modifier()
	if attacker_movement_mod > 0:
		modifiers["attacker_moved"] = attacker_movement_mod
		var movement_type = ""
		if attacker_movement_mod == 1:
			movement_type = "Walked"
		elif attacker_movement_mod == 2:
			movement_type = "Ran"
		elif attacker_movement_mod == 3:
			movement_type = "Jumped"
		breakdown_lines.append("Attacker %s: +%d" % [movement_type, attacker_movement_mod])
	
	# 3. Modificador por movimiento del objetivo (TMM)
	var target_tmm = _calculate_target_movement_modifier(target)
	if target_tmm > 0:
		modifiers["target_tmm"] = target_tmm
		breakdown_lines.append("Target Movement: +%d" % target_tmm)
	
	# 4. Modificador por rango del arma
	var range_mod = _get_range_modifier(weapon, range_hexes)
	var range_type = ""
	if range_mod == 0:
		range_type = "Short"
	elif range_mod == 2:
		range_type = "Medium"
	elif range_mod == 4:
		range_type = "Long"
	else:
		range_type = "Out of Range"
	
	if range_mod != 0 and range_mod < 999:
		modifiers["range"] = range_mod
		breakdown_lines.append("%s Range: +%d" % [range_type, range_mod])
	elif range_mod >= 999:
		modifiers["range"] = range_mod
		breakdown_lines.append("%s: CANNOT FIRE" % range_type)
	
	# 5. Modificador por terreno/cobertura
	if terrain_modifier > 0:
		modifiers["terrain"] = terrain_modifier
		breakdown_lines.append("Terrain/Cover: +%d" % terrain_modifier)
	
	# 6. Modificador por calor (cada 5 puntos de calor = +1 to-hit)
	if "heat" in attacker and attacker.heat >= 5:
		var heat_mod = int(attacker.heat / 5)
		modifiers["heat"] = heat_mod
		breakdown_lines.append("Heat Penalty: +%d" % heat_mod)
	
	# 7. Modificadores de equipamiento electrónico (ECM/BAP)
	var ecm_bap_mods = _calculate_ecm_bap_modifiers(attacker, target, weapon, range_hexes)
	if ecm_bap_mods.has("ecm_penalty"):
		modifiers["ecm"] = ecm_bap_mods["ecm_penalty"]
		breakdown_lines.append("ECM Interference: +%d" % ecm_bap_mods["ecm_penalty"])
	if ecm_bap_mods.has("bap_bonus"):
		modifiers["bap"] = ecm_bap_mods["bap_bonus"]
		breakdown_lines.append("BAP Targeting: %d" % ecm_bap_mods["bap_bonus"])
	
	# Calcular número objetivo total
	var target_number = gunnery_skill + attacker_movement_mod + target_tmm + range_mod + terrain_modifier
	if "heat" in attacker and attacker.heat >= 5:
		target_number += int(attacker.heat / 5)
	
	# Aplicar modificadores de ECM/BAP
	if ecm_bap_mods.has("ecm_penalty"):
		target_number += ecm_bap_mods["ecm_penalty"]
	if ecm_bap_mods.has("bap_bonus"):
		target_number += ecm_bap_mods["bap_bonus"]  # Será negativo para mejorar
	
	# Crear línea de resumen
	var breakdown = "\n".join(breakdown_lines)
	breakdown += "\n─────────────────"
	breakdown += "\nTarget Number: %d" % target_number
	breakdown += "\nNeed %d+ on 2D6 to hit" % target_number
	
	return {
		"target_number": target_number,
		"modifiers": modifiers,
		"breakdown": breakdown
	}

static func _calculate_target_movement_modifier(target) -> int:
	# Calcula el TMM según las reglas de BattleTech Total Warfare
	# Basado en hexes movidos este turno
	
	var hexes_moved = 0
	
	# Obtener hexes movidos de diferentes formas posibles
	if "hexes_moved_this_turn" in target:
		hexes_moved = target.hexes_moved_this_turn
	elif "movement_this_turn" in target:
		hexes_moved = target.movement_this_turn
	
	# Si saltó, añade +1 adicional
	var jumped = false
	if "last_movement_type" in target:
		jumped = (target.last_movement_type == 3)  # JUMP = 3
	
	# Tabla de TMM según BattleTech Total Warfare
	var tmm = 0
	if hexes_moved >= 10:
		tmm = 4
	elif hexes_moved >= 7:
		tmm = 3
	elif hexes_moved >= 5:
		tmm = 2
	elif hexes_moved >= 3:
		tmm = 1
	else:
		tmm = 0
	
	# Bonus adicional por salto
	if jumped:
		tmm += 1
	
	return tmm

static func _get_range_modifier(weapon, range_hexes: int) -> int:
	# Retorna el modificador por rango según el tipo de arma
	var short_range = weapon.get("range_short", 3)
	var medium_range = weapon.get("range_medium", 6)
	var long_range = weapon.get("range_long", 9)
	
	if range_hexes <= short_range:
		return 0  # Rango corto, sin modificador
	elif range_hexes <= medium_range:
		return 2  # Rango medio, +2
	elif range_hexes <= long_range:
		return 4  # Rango largo, +4
	else:
		return 999  # Fuera de rango, imposible

static func roll_to_hit() -> int:
	# Tira 2D6
	var die1 = randi() % 6 + 1
	var die2 = randi() % 6 + 1
	return die1 + die2

static func check_hit(roll: int, target_number: int) -> bool:
	# Verifica si el disparo impacta
	# En Battletech: 2 siempre falla, 12 siempre impacta
	if roll == 2:
		return false  # Fallo crítico
	if roll == 12:
		return true   # Impacto crítico
	
	return roll >= target_number

static func roll_hit_location() -> String:
	# Tira 2D6 para determinar dónde impactó
	var roll = roll_to_hit()  # Reusar la misma función de 2D6
	return HIT_LOCATION_TABLE.get(roll, "CT")

static func apply_damage(target, location: String, damage: int) -> Dictionary:
	# Aplica daño a la localización específica usando el sistema del mech
	# Retorna información sobre el daño aplicado
	
	if target.has_method("take_damage"):
		return target.take_damage(location, damage)
	
	# Fallback si no tiene el método
	return {
		"success": false,
		"message": "Target cannot take damage"
	}

static func calculate_heat_generated(weapons_fired: Array) -> int:
	# Calcula el calor total generado por las armas disparadas
	var total_heat = 0
	for weapon in weapons_fired:
		total_heat += weapon.get("heat", 0)
	return total_heat

static func _calculate_ecm_bap_modifiers(attacker, target, weapon, range_hexes: int) -> Dictionary:
	# Calcula modificadores de ECM (Electronic Counter-Measures) y BAP (Beagle Active Probe)
	# según las reglas de BattleTech Total Warfare
	
	var modifiers = {}
	
	# Verificar si el objetivo tiene ECM activo
	var target_has_ecm = ComponentDatabase.has_ecm_suite(target) if ComponentDatabase else false
	var attacker_has_bap = ComponentDatabase.has_beagle_probe(attacker) if ComponentDatabase else false
	
	# ECM afecta a armas de misiles si el atacante está dentro del rango de ECM
	if target_has_ecm and _is_missile_weapon(weapon):
		# Verificar si el atacante está dentro del rango de ECM (6 hexes)
		if "hex_position" in attacker and "hex_position" in target:
			var distance = ComponentDatabase.hex_distance(attacker.hex_position, target.hex_position) if ComponentDatabase else range_hexes
			if distance <= 6:
				# ECM da +1 to-hit a armas de misiles
				# Pero si el atacante tiene BAP, lo niega
				if not attacker_has_bap:
					modifiers["ecm_penalty"] = 1
	
	# BAP proporciona bonus a corto alcance (opcional, para hacerlo útil)
	if attacker_has_bap:
		var short_range = weapon.get("range_short", 3)
		if range_hexes <= short_range:
			# BAP da -1 to-hit a corto alcance (mejor targeting)
			modifiers["bap_bonus"] = -1
	
	return modifiers

static func _is_missile_weapon(weapon: Dictionary) -> bool:
	# Verifica si el arma es de tipo misil
	var weapon_type = weapon.get("type", -1)
	return weapon_type == ComponentDatabase.ComponentType.WEAPON_MISSILE if ComponentDatabase else false
