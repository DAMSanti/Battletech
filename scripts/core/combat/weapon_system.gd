class_name WeaponSystem
extends RefCounted

## Sistema de armas - Maneja disparo, cálculo de golpe y daño
## Responsabilidad única: Gestión de armas y combate a distancia

static func calculate_to_hit(attacker, target, weapon: Dictionary, range_in_hexes: int, target_terrain = null, hex_grid = null, attacker_hex: Vector2i = Vector2i.ZERO, target_hex: Vector2i = Vector2i.ZERO) -> int:
	var base_gunnery = attacker.pilot_gunnery
	
	# NUEVO: Verificar Line of Sight
	if hex_grid != null and attacker_hex != Vector2i.ZERO and target_hex != Vector2i.ZERO:
		var los_data = LineOfSight.calculate_los(hex_grid, attacker_hex, target_hex)
		
		# Si la LoS está bloqueada, imposible disparar
		if los_data.result == LineOfSight.Result.BLOCKED:
			return -1  # No se puede disparar
	
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
	
	# NUEVO: Modificador por terreno del objetivo
	var terrain_mod = 0
	if target_terrain != null:
		terrain_mod = TerrainType.get_to_hit_modifier(target_terrain)
	
	# NUEVO: Modificador por Line of Sight (cobertura)
	var los_mod = 0
	if hex_grid != null and attacker_hex != Vector2i.ZERO and target_hex != Vector2i.ZERO:
		var los_data = LineOfSight.calculate_los(hex_grid, attacker_hex, target_hex)
		los_mod = los_data.to_hit_modifier
		
		# Modificador de altura
		var height_mod = LineOfSight.calculate_height_modifier(hex_grid, attacker_hex, target_hex)
		los_mod += height_mod
	
	var target_number = base_gunnery + range_mod + attacker_movement_mod + target_movement_mod + heat_mod + prone_mod + terrain_mod + los_mod
	
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
