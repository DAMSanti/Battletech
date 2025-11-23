class_name MovementRestrictions
extends RefCounted

## Sistema de restricciones de movimiento BattleTech
## Determina qué hexes son transitables según reglas de BattleTech

## Constantes
const MAX_ELEVATION_CLIMB = 2  # Máximo cambio de elevación sin escalón

## Verificar si un hex es transitable para una unidad
static func is_hex_accessible(hex: Vector2i, unit, hex_grid, movement_type: int) -> bool:
	if not hex_grid.is_valid_hex(hex):
		return false
	
	# Verificar ocupación
	var occupant = hex_grid.get_unit(hex)
	if occupant != null and occupant != unit:
		return false  # Hex ocupado por otra unidad
	
	var terrain = hex_grid.get_terrain(hex)
	
	# Hexes prohibidos para TODOS
	if _is_prohibited_terrain(terrain):
		return false
	
	# Verificar según tipo de movimiento
	match movement_type:
		GameEnums.MovementType.WALK:
			return _can_walk_on(hex, terrain, hex_grid)
		GameEnums.MovementType.RUN:
			return _can_run_on(hex, terrain, hex_grid)
		GameEnums.MovementType.JUMP:
			return _can_jump_to(hex, terrain, unit, hex_grid)
		_:
			return false

## Terrenos prohibidos para todos (abismos, fuera del mapa)
static func _is_prohibited_terrain(_terrain: TerrainType.Type) -> bool:
	# Por ahora no tenemos terrenos prohibidos explícitos
	# En el futuro: ABYSS, CLIFF, OUT_OF_BOUNDS
	return false

## Verificar si se puede caminar sobre un hex
static func _can_walk_on(_hex: Vector2i, terrain: TerrainType.Type, _hex_grid) -> bool:
	# Agua profunda (depth 2+) no es accesible caminando
	var water_depth = TerrainType.get_water_depth(terrain)
	if water_depth >= 2:
		return false
	
	# Edificios colapsados/destruidos
	# TODO: Verificar estado del edificio
	
	return true

## Verificar si se puede correr sobre un hex
static func _can_run_on(hex: Vector2i, terrain: TerrainType.Type, hex_grid) -> bool:
	# Primero verificar si se puede caminar
	if not _can_walk_on(hex, terrain, hex_grid):
		return false
	
	# Ciertos terrenos prohíben correr
	if TerrainType.prohibits_running(terrain):
		return false
	
	return true

## Verificar si se puede saltar a un hex
static func _can_jump_to(hex: Vector2i, terrain: TerrainType.Type, _unit, hex_grid) -> bool:
	# Saltar permite ignorar muchas restricciones
	
	# Agua muy profunda sigue siendo prohibida
	var water_depth = TerrainType.get_water_depth(terrain)
	if water_depth >= 3:  # Depth 3+ prohibido incluso saltando
		return false
	
	# Edificios: verificar altura
	if terrain == TerrainType.Type.BUILDING:
		var _elevation = hex_grid.get_elevation(hex)
		# TODO: Verificar si el mech puede saltar a esa altura
		pass
	
	return true

## Verificar cambio de elevación permitido
static func is_elevation_change_valid(from_hex: Vector2i, to_hex: Vector2i, hex_grid, movement_type: int) -> bool:
	var from_elev = hex_grid.get_elevation(from_hex)
	var to_elev = hex_grid.get_elevation(to_hex)
	var diff = abs(to_elev - from_elev)
	
	# Saltar ignora restricciones de elevación (hasta cierto punto)
	if movement_type == GameEnums.MovementType.JUMP:
		return true  # TODO: Verificar jump MP suficientes
	
	# Subida mayor a 2 niveles sin escalón no es posible
	if to_elev > from_elev and diff > MAX_ELEVATION_CLIMB:
		return false
	
	# Bajar más de 2 niveles requiere chequeo pero es posible
	# (puede causar daño)
	
	return true

## Verificar si se requiere chequeo de pilotaje
static func requires_piloting_check(from_hex: Vector2i, to_hex: Vector2i, hex_grid, movement_type: int) -> Dictionary:
	var result = {
		"required": false,
		"reason": "",
		"difficulty": 0
	}
	
	var to_terrain = hex_grid.get_terrain(to_hex)
	
	# Terrenos que requieren chequeo
	if TerrainType.requires_piloting_check(to_terrain):
		result.required = true
		result.reason = "Terreno peligroso"
		result.difficulty = 4  # Dificultad base
	
	# Saltar siempre requiere chequeo al aterrizar
	if movement_type == GameEnums.MovementType.JUMP:
		result.required = true
		result.reason = "Aterrizaje de salto"
		result.difficulty = 3
	
	# Bajar más de 1 nivel
	var from_elev = hex_grid.get_elevation(from_hex)
	var to_elev = hex_grid.get_elevation(to_hex)
	var descent = from_elev - to_elev
	
	if descent > 1:
		result.required = true
		result.reason = "Descenso pronunciado"
		result.difficulty = 4 + (descent - 1)  # Más difícil por cada nivel extra
	
	# Salir de hex adyacente a enemigo (ZOC)
	if _has_adjacent_enemy(from_hex, hex_grid):
		var distance = hex_grid.hex_distance(from_hex, to_hex)
		if distance > 0:  # Saliendo del hex
			result.required = true
			result.reason = "Salir de hex adyacente a enemigo"
			result.difficulty = 4
	
	return result

## Verificar si hay enemigos adyacentes
static func _has_adjacent_enemy(hex: Vector2i, hex_grid) -> bool:
	var neighbors = hex_grid.get_neighbors(hex)
	
	for neighbor in neighbors:
		var unit = hex_grid.get_unit(neighbor)
		if unit != null:
			# TODO: Verificar si es enemigo (necesita info de equipo)
			# Por ahora asumimos que cualquier unidad adyacente cuenta
			return true
	
	return false

## Obtener lista de hexes prohibidos en el mapa
static func get_prohibited_hexes(hex_grid) -> Array:
	var prohibited = []
	
	# Recorrer todo el grid buscando hexes no transitables
	for q in range(hex_grid.grid_width):
		for r in range(hex_grid.grid_height):
			var hex = Vector2i(q, r)
			if not hex_grid.is_valid_hex(hex):
				continue
			
			var terrain = hex_grid.get_terrain(hex)
			
			# Agua profunda
			if TerrainType.get_water_depth(terrain) >= 2:
				prohibited.append(hex)
			
			# Edificios destruidos (TODO)
			# Acantilados (TODO)
	
	return prohibited

## Calcular penalizaciones por movimiento peligroso
static func get_movement_penalties(hex: Vector2i, movement_type: int, hex_grid) -> Dictionary:
	var penalties = {
		"to_hit_modifier": 0,  # Modificador al disparar
		"defense_modifier": 0,  # Modificador de defensa
		"heat_penalty": 0,      # Calor adicional
		"piloting_check": false
	}
	
	var terrain = hex_grid.get_terrain(hex)
	
	# Modificadores de terreno
	penalties.to_hit_modifier += TerrainType.get_to_hit_modifier(terrain)
	penalties.defense_modifier += TerrainType.get_defense_bonus(terrain)
	
	# Modificadores de movimiento
	match movement_type:
		GameEnums.MovementType.WALK:
			penalties.to_hit_modifier += 1  # +1 al disparar caminando
		GameEnums.MovementType.RUN:
			penalties.to_hit_modifier += 2  # +2 al disparar corriendo
			penalties.defense_modifier += 2  # +2 defensa corriendo
		GameEnums.MovementType.JUMP:
			penalties.to_hit_modifier += 3  # +3 al disparar saltando
			penalties.defense_modifier += 2  # +2 defensa saltando
			penalties.piloting_check = true  # Requiere chequeo al aterrizar
	
	return penalties
