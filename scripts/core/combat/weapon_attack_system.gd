class_name WeaponAttackSystem
extends RefCounted

## Sistema completo de ataque con armas según BattleTech Total Warfare
## Responsabilidad: LoS, to-hit, tirada de ataque, aplicar daño, generar calor, críticos

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

# Tablas de cluster hits para misiles (según BattleTech Total Warfare)
# Clave: número de misiles en salva, valor: array indexado por tirada 2D6
const CLUSTER_TABLE = {
	2: {2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 2, 8: 2, 9: 2, 10: 2, 11: 2, 12: 2},
	4: {2: 1, 3: 1, 4: 2, 5: 2, 6: 2, 7: 3, 8: 3, 9: 3, 10: 4, 11: 4, 12: 4},
	5: {2: 1, 3: 1, 4: 2, 5: 2, 6: 3, 7: 3, 8: 4, 9: 4, 10: 5, 11: 5, 12: 5},
	6: {2: 2, 3: 2, 4: 2, 5: 3, 6: 3, 7: 4, 8: 4, 9: 5, 10: 6, 11: 6, 12: 6},
	10: {2: 3, 3: 3, 4: 4, 5: 6, 6: 6, 7: 7, 8: 8, 9: 9, 10: 10, 11: 10, 12: 10},
	15: {2: 5, 3: 6, 4: 7, 5: 9, 6: 10, 7: 11, 8: 12, 9: 13, 10: 15, 11: 15, 12: 15},
	20: {2: 6, 3: 8, 4: 10, 5: 12, 6: 14, 7: 16, 8: 18, 9: 18, 10: 20, 11: 20, 12: 20}
}

# Tabla de críticos (2D6 + número de críticos previos en esa localización)
const CRITICAL_HIT_TABLE = {
	# 2-7: Sin efecto adicional (solo daño estructural)
	# 8-9: Crítico en 1 componente
	# 10-11: Crítico en 2 componentes
	# 12+: Crítico en 3 componentes o cabeza destruida
}

## ========== FUNCIONES PRINCIPALES DE RESOLUCIÓN DE ATAQUE ==========

## Resolver un ataque completo de arma (función principal)
static func resolve_weapon_attack(attacker, target, weapon, hex_grid) -> Dictionary:
	var result = {
		"success": false,
		"can_shoot": false,
		"hit": false,
		"damage_applied": 0,
		"locations_hit": [],
		"critical_hits": [],
		"heat_generated": 0,
		"ammo_consumed": 0,
		"message": "",
		"breakdown": ""
	}
	
	# Paso 1: Verificar Line of Sight
	var los_check = verify_line_of_sight(attacker, target, hex_grid)
	if not los_check.can_shoot:
		result["message"] = los_check.message
		result["breakdown"] = los_check.breakdown
		return result
	
	# Paso 2: Verificar que el arma pueda disparar
	var weapon_check = can_fire_weapon(attacker, weapon, target, hex_grid)
	if not weapon_check.can_fire:
		result["message"] = weapon_check.reason
		return result
	
	# Paso 3: Calcular número objetivo (To-Hit)
	var range_hexes = hex_grid.hex_distance(attacker.hex_position, target.hex_position)
	var to_hit_data = calculate_to_hit(attacker, target, weapon, range_hexes, 0, hex_grid)
	
	if not to_hit_data.can_shoot:
		result["message"] = to_hit_data.get("los_message", "Cannot shoot")
		result["breakdown"] = to_hit_data.breakdown
		return result
	
	result["can_shoot"] = true
	result["breakdown"] = to_hit_data.breakdown
	
	# Paso 4: Tirada de ataque (2D6)
	var roll = roll_to_hit()
	var hit = check_hit(roll, to_hit_data.target_number)
	
	result["roll"] = roll
	result["target_number"] = to_hit_data.target_number
	result["hit"] = hit
	result["breakdown"] += "\n\nRoll: %d on 2D6" % roll
	
	if not hit:
		result["message"] = "MISS! Rolled %d, needed %d+" % [roll, to_hit_data.target_number]
		result["success"] = true  # Ataque completado, solo que falló
		return result
	
	# Paso 5: HIT! Resolver daño
	result["message"] = "HIT! Rolled %d vs %d" % [roll, to_hit_data.target_number]
	
	# Consumir munición y generar calor
	if weapon.get("requires_ammo", false) and weapon.has("ammo"):
		weapon["ammo"] -= 1
		result["ammo_consumed"] = 1
	
	var heat = weapon.get("heat", 0)
	if attacker.has_method("add_heat"):
		attacker.add_heat(heat)
	result["heat_generated"] = heat
	
	# Paso 6: Resolver daño según tipo de arma
	var damage_result = resolve_damage(attacker, target, weapon, to_hit_data.modifiers)
	
	result["damage_applied"] = damage_result.total_damage
	result["locations_hit"] = damage_result.locations_hit
	result["critical_hits"] = damage_result.critical_hits
	result["message"] += "\n" + damage_result.message
	result["success"] = true
	
	return result

## Verificar Line of Sight
static func verify_line_of_sight(attacker, target, hex_grid) -> Dictionary:
	var result = {"can_shoot": true, "message": "", "breakdown": ""}
	
	if hex_grid == null or not "hex_position" in attacker or not "hex_position" in target:
		result["can_shoot"] = false
		result["message"] = "Cannot determine line of sight"
		return result
	
	var los_data = LineOfSight.calculate_los(hex_grid, attacker.hex_position, target.hex_position)
	
	if los_data.result == LineOfSight.Result.BLOCKED:
		result["can_shoot"] = false
		result["message"] = "LINE OF SIGHT BLOCKED: " + los_data.message
		result["breakdown"] = los_data.message
		return result
	
	if los_data.result == LineOfSight.Result.PARTIAL:
		result["message"] = "Partial cover: " + los_data.message
		result["breakdown"] = los_data.message
	else:
		result["message"] = "Clear line of sight"
	
	return result

## Verificar si el arma puede disparar
static func can_fire_weapon(attacker, weapon, target, hex_grid) -> Dictionary:
	var result = {"can_fire": false, "reason": ""}
	
	# Verificar si el arma está destruida
	if weapon.get("destroyed", false):
		result["reason"] = "Weapon destroyed"
		return result
	
	# Verificar munición
	if weapon.get("requires_ammo", false):
		var ammo = weapon.get("ammo", 0)
		if ammo <= 0:
			result["reason"] = "Out of ammo"
			return result
	
	# Verificar si el mech está shutdown
	if attacker.get("is_shutdown", false):
		result["reason"] = "Mech shutdown"
		return result
	
	# Verificar rango
	var range_hexes = hex_grid.hex_distance(attacker.hex_position, target.hex_position)
	
	# Verificar rango mínimo
	var min_range = weapon.get("range_minimum", 0)
	if min_range > 0 and range_hexes < min_range:
		result["reason"] = "Target too close (min range: %d)" % min_range
		return result
	
	# Verificar rango máximo
	var max_range = weapon.get("range_long", 0)
	if range_hexes > max_range:
		result["reason"] = "Target out of range (max: %d, distance: %d)" % [max_range, range_hexes]
		return result
	
	result["can_fire"] = true
	return result

## Resolver daño según tipo de arma
static func resolve_damage(attacker, target, weapon, modifiers: Dictionary) -> Dictionary:
	var weapon_category = weapon.get("category", ComponentDatabase.WeaponCategory.ENERGY)
	
	# Verificar si es arma de misiles
	if weapon_category == ComponentDatabase.WeaponCategory.MISSILE:
		return _resolve_missile_damage(attacker, target, weapon, modifiers)
	else:
		return _resolve_direct_damage(attacker, target, weapon, modifiers)

## Resolver daño de armas directas (energía/balística)
static func _resolve_direct_damage(_attacker, target, weapon, modifiers: Dictionary) -> Dictionary:
	var result = {
		"total_damage": 0,
		"locations_hit": [],
		"critical_hits": [],
		"message": ""
	}
	
	var damage = weapon.get("damage", 0)
	
	# Hull-down: solo puede golpear localizaciones superiores
	var location = ""
	if modifiers.get("hull_down", false):
		location = _roll_hit_location_upper_only()
		result["message"] = "Hit %s (hull-down)" % location
	else:
		location = roll_hit_location()
		result["message"] = "Hit %s" % location
	
	# Aplicar daño a la localización
	var damage_result = apply_damage_to_location(target, location, damage)
	
	result["total_damage"] = damage
	result["locations_hit"].append({
		"location": location,
		"damage": damage,
		"armor_damage": damage_result.get("armor_damage", 0),
		"structure_damage": damage_result.get("structure_damage", 0),
		"critical_hit": damage_result.get("critical_hit", false)
	})
	
	# Verificar críticos si hubo daño a estructura
	if damage_result.get("structure_damage", 0) > 0:
		var critical_result = roll_critical_hits(target, location, damage_result.structure_damage)
		result["critical_hits"] = critical_result.criticals
		result["message"] += "\n" + critical_result.message
	
	return result

## Resolver daño de misiles (cluster table)
static func _resolve_missile_damage(_attacker, target, weapon, modifiers: Dictionary) -> Dictionary:
	var result = {
		"total_damage": 0,
		"locations_hit": [],
		"critical_hits": [],
		"message": ""
	}
	
	var missiles_fired = weapon.get("missiles_per_salvo", 0)
	var damage_per_missile = weapon.get("damage", 1)
	
	# Tirar cluster table para ver cuántos misiles impactan
	var cluster_roll = roll_to_hit()
	var missiles_hit = get_cluster_hits(missiles_fired, cluster_roll)
	
	result["message"] = "%d/%d missiles hit (rolled %d)" % [missiles_hit, missiles_fired, cluster_roll]
	
	# Agrupar misiles (grupos de 5 para distribución)
	var groups = _group_missiles(missiles_hit)
	
	# Para cada grupo, tirar localización
	for group in groups:
		var location = ""
		if modifiers.get("hull_down", false):
			location = _roll_hit_location_upper_only()
		else:
			location = roll_hit_location()
		
		var group_damage = group * damage_per_missile
		
		# Aplicar daño
		var damage_result = apply_damage_to_location(target, location, group_damage)
		
		result["total_damage"] += group_damage
		result["locations_hit"].append({
			"location": location,
			"damage": group_damage,
			"missiles": group,
			"armor_damage": damage_result.get("armor_damage", 0),
			"structure_damage": damage_result.get("structure_damage", 0),
			"critical_hit": damage_result.get("critical_hit", false)
		})
		
		# Verificar críticos si hubo daño a estructura
		if damage_result.get("structure_damage", 0) > 0:
			var critical_result = roll_critical_hits(target, location, damage_result.structure_damage)
			result["critical_hits"].append_array(critical_result.criticals)
			result["message"] += "\n" + critical_result.message

	return result

## Agrupar misiles para distribución de daño
static func _group_missiles(total_missiles: int) -> Array:
	var groups = []
	
	# LRM: grupos de 5
	# SRM: individual (grupos de 1)
	var group_size = 5
	
	while total_missiles >= group_size:
		groups.append(group_size)
		total_missiles -= group_size
	
	# Misiles restantes
	if total_missiles > 0:
		groups.append(total_missiles)
	
	return groups

## Obtener número de misiles que impactan según cluster table
static func get_cluster_hits(missiles_fired: int, roll: int) -> int:
	# Buscar en la tabla de cluster
	if CLUSTER_TABLE.has(missiles_fired):
		var table = CLUSTER_TABLE[missiles_fired]
		return table.get(roll, missiles_fired)
	
	# Si no está en la tabla, todos impactan (armas directas)
	return missiles_fired

## Tirar localización solo para partes superiores (hull-down)
static func _roll_hit_location_upper_only() -> String:
	var roll = roll_to_hit()
	
	# Redistribuir para solo partes superiores
	match roll:
		2, 7: return "center_torso"
		3, 4: return "right_arm"
		5: return "right_torso"
		6: return "right_torso"
		8: return "left_torso"
		9: return "left_torso"
		10, 11: return "left_arm"
		12: return "head"
		_: return "center_torso"

## ========== FUNCIONES DE CÁLCULO DE TO-HIT ==========

static func calculate_to_hit(attacker, target, weapon, range_hexes: int, terrain_modifier: int = 0, hex_grid = null) -> Dictionary:
	# Calcula el número objetivo y modificadores para impactar según BattleTech Total Warfare
	# Retorna: { "target_number": int, "modifiers": Dictionary, "breakdown": String }
	
	var modifiers = {}
	var breakdown_lines = []
	
	# 0. NUEVO: Verificar Line of Sight
	if hex_grid != null and "hex_position" in attacker and "hex_position" in target:
		var attacker_hex = attacker.hex_position
		var target_hex = target.hex_position
		var los_data = LineOfSight.calculate_los(hex_grid, attacker_hex, target_hex)
		
		# Si está bloqueado, imposible disparar
		if los_data.result == LineOfSight.Result.BLOCKED:
			modifiers["los_blocked"] = true
			breakdown_lines.append("LINE OF SIGHT BLOCKED")
			breakdown_lines.append(los_data.message)
			return {
				"target_number": 999,
				"modifiers": modifiers,
				"breakdown": "\n".join(breakdown_lines),
				"can_shoot": false,
				"los_message": los_data.message
			}
		
		# Aplicar modificadores de LoS (cobertura)
		if los_data.to_hit_modifier > 0:
			modifiers["los_cover"] = los_data.to_hit_modifier
			breakdown_lines.append("Cover/Woods: +%d" % los_data.to_hit_modifier)
		
		# Aplicar modificador de altura
		var height_mod = LineOfSight.calculate_height_modifier(hex_grid, attacker_hex, target_hex)
		if height_mod != 0:
			modifiers["height"] = height_mod
			if height_mod < 0:
				breakdown_lines.append("Height Advantage: %d" % height_mod)
			else:
				breakdown_lines.append("Height Disadvantage: +%d" % height_mod)
		
		# Advertencia si solo puede golpear partes superiores
		if not los_data.can_hit_all_locations:
			modifiers["hull_down"] = true
			breakdown_lines.append("(Target hull-down: upper locations only)")
	
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
	
	# NUEVO: Aplicar modificadores de LoS
	if modifiers.has("los_cover"):
		target_number += modifiers["los_cover"]
	if modifiers.has("height"):
		target_number += modifiers["height"]
	
	# Crear línea de resumen
	var breakdown = "\n".join(breakdown_lines)
	breakdown += "\n─────────────────"
	breakdown += "\nTarget Number: %d" % target_number
	breakdown += "\nNeed %d+ on 2D6 to hit" % target_number
	
	return {
		"target_number": target_number,
		"modifiers": modifiers,
		"breakdown": breakdown,
		"can_shoot": true
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

## ========== FUNCIONES DE DAÑO Y CRÍTICOS ==========

## Aplicar daño a una localización específica
static func apply_damage_to_location(target, location: String, damage: int) -> Dictionary:
	var result = {
		"armor_damage": 0,
		"structure_damage": 0,
		"location_destroyed": false,
		"critical_hit": false
	}
	
	if not target.has("armor") or not target.armor.has(location):
		push_error("Invalid location: " + location)
		return result
	
	# Paso 1: Daño a armadura
	var armor_current = target.armor[location]["current"]
	var armor_damage = min(damage, armor_current)
	target.armor[location]["current"] -= armor_damage
	result["armor_damage"] = armor_damage
	
	# Paso 2: Daño overflow a estructura interna
	var overflow = damage - armor_damage
	if overflow > 0:
		if target.has("structure") and target.structure.has(location):
			var structure_current = target.structure[location]["current"]
			var structure_damage = min(overflow, structure_current)
			target.structure[location]["current"] -= structure_damage
			result["structure_damage"] = structure_damage
			result["critical_hit"] = true
			
			# Verificar si la localización fue destruida
			if target.structure[location]["current"] <= 0:
				result["location_destroyed"] = true
				_handle_location_destroyed(target, location)
	
	return result

## Manejar destrucción de localización
static func _handle_location_destroyed(target, location: String):
	# Marcar como destruida
	if target.has("destroyed_locations"):
		if not target.destroyed_locations is Array:
			target["destroyed_locations"] = []
		target.destroyed_locations.append(location)
	
	# Casos especiales
	if location == "head" or location == "center_torso":
		target["is_destroyed"] = true
		target["death_reason"] = "%s destroyed" % location
	
	# Ambas piernas destruidas
	if target.has("structure"):
		if target.structure.get("left_leg", {}).get("current", 1) <= 0 and \
		   target.structure.get("right_leg", {}).get("current", 1) <= 0:
			target["is_destroyed"] = true
			target["death_reason"] = "Both legs destroyed"

## Tirar críticos cuando hay daño a estructura
static func roll_critical_hits(target, location: String, structure_damage: int) -> Dictionary:
	var result = {
		"criticals": [],
		"message": ""
	}
	
	# Por cada punto de daño a estructura, posibilidad de crítico
	for i in range(structure_damage):
		var roll = roll_to_hit()
		
		# 8+: crítico
		if roll >= 8:
			var critical = _apply_critical_hit(target, location, roll)
			result["criticals"].append(critical)
			result["message"] += "\nCritical Hit in %s! (rolled %d): %s" % [location, roll, critical.description]
	
	return result

## Aplicar un crítico específico
static func _apply_critical_hit(target, location: String, roll: int) -> Dictionary:
	var critical = {
		"location": location,
		"roll": roll,
		"component_hit": "",
		"description": "",
		"effect": ""
	}
	
	# Determinar severidad del crítico
	var slots_hit = 1
	if roll >= 12:
		slots_hit = 3
		critical["description"] = "Triple Critical"
	elif roll >= 10:
		slots_hit = 2
		critical["description"] = "Double Critical"
	else:
		slots_hit = 1
		critical["description"] = "Single Critical"
	
	# Buscar componentes en esa localización
	var components_in_location = _get_components_in_location(target, location)
	
	if components_in_location.is_empty():
		critical["component_hit"] = "none"
		critical["effect"] = "No components to damage"
		return critical
	
	# Seleccionar componente(s) al azar
	for i in range(slots_hit):
		if components_in_location.is_empty():
			break
		
		var component_idx = randi() % components_in_location.size()
		var component = components_in_location[component_idx]
		
		# Aplicar daño al componente
		if not component.get("destroyed", false):
			component["destroyed"] = true
			critical["component_hit"] = component.get("name", "Unknown")
			critical["effect"] = "Component destroyed"
			
			# Casos especiales: munición explosiva
			if component.get("explosive", false) and component.get("type") == ComponentDatabase.ComponentType.EQUIPMENT_AMMO:
				_handle_ammo_explosion(target, location, component)
				critical["effect"] += " - AMMO EXPLOSION!"
			
			# Gyro destruido
			if component.get("name", "").contains("Gyro"):
				critical["effect"] += " - Mech falls, +3 PSR to stand"
			
			# Engine hit
			if component.get("name", "").contains("Engine"):
				var engine_hits = _count_engine_hits(target)
				if engine_hits >= 3:
					target["is_destroyed"] = true
					critical["effect"] += " - ENGINE DESTROYED!"
				else:
					critical["effect"] += " - Engine damaged (%d/3)" % engine_hits
		
		# Remover del array para evitar duplicados
		components_in_location.remove_at(component_idx)
	
	return critical

## Manejar explosión de munición
static func _handle_ammo_explosion(target, location: String, ammo_component: Dictionary):
	# Verificar si hay CASE en la localización
	var has_case = ComponentDatabase.has_case_in_location(target, location) if ComponentDatabase else false
	
	if has_case:
		# CASE contiene la explosión: solo destruye la localización
		if target.has("structure") and target.structure.has(location):
			target.structure[location]["current"] = 0
		_handle_location_destroyed(target, location)
	else:
		# Sin CASE: explosión interna devastadora
		var explosion_damage = ammo_component.get("shots_per_ton", 10) * 2
		
		# Daño al torso central
		apply_damage_to_location(target, "center_torso", explosion_damage)
		
		# Daño a localizaciones adyacentes
		var adjacent = _get_adjacent_locations(location)
		for adj_loc in adjacent:
			apply_damage_to_location(target, adj_loc, explosion_damage / 2)

## Obtener componentes en una localización
static func _get_components_in_location(target, location: String) -> Array:
	var components = []
	
	if target.has("weapons"):
		for weapon in target.weapons:
			if weapon.get("location", "") == location and not weapon.get("destroyed", false):
				components.append(weapon)
	
	if target.has("equipment"):
		for equip in target.equipment:
			if equip.get("location", "") == location and not equip.get("destroyed", false):
				components.append(equip)
	
	return components

## Contar hits al motor
static func _count_engine_hits(target) -> int:
	var count = 0
	
	if target.has("weapons"):
		for weapon in target.weapons:
			if weapon.get("name", "").contains("Engine") and weapon.get("destroyed", false):
				count += 1
	
	if target.has("equipment"):
		for equip in target.equipment:
			if equip.get("name", "").contains("Engine") and equip.get("destroyed", false):
				count += 1
	
	return count

## Obtener localizaciones adyacentes para explosión
static func _get_adjacent_locations(location: String) -> Array:
	match location:
		"left_torso":
			return ["center_torso", "left_arm"]
		"right_torso":
			return ["center_torso", "right_arm"]
		"center_torso":
			return ["left_torso", "right_torso"]
		"left_arm":
			return ["left_torso"]
		"right_arm":
			return ["right_torso"]
		_:
			return []
