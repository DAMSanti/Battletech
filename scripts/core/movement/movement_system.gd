class_name MovementSystem
extends RefCounted

## Sistema de movimiento BattleTech - Calcula movimiento, costos de terreno y alcance
## Implementa reglas oficiales de BattleTech con tipos de movimiento (Walk/Run/Jump)

## Constantes de BattleTech
const MAX_ELEVATION_CHANGE = 2  # Máximo cambio de elevación sin transición
const ELEVATION_COST_PER_LEVEL = 1  # Coste adicional por nivel al subir

## Calcular distancia de caminata considerando daño y calor
static func calculate_walk_distance(mech) -> int:
	var base_walk = mech.walk_mp
	
	# Penalización por daño en piernas (solo si el mech tiene sistema de armadura por locación)
	var leg_damage_penalty = 0
	if mech.has_method("get_location_armor"):
		if mech.get_location_armor("right_leg") <= 0 or mech.get_location_armor("left_leg") <= 0:
			leg_damage_penalty = base_walk / 2
	
	# Penalización por calor
	var heat_penalty = 0
	if mech.heat >= 5:
		heat_penalty = 1
	if mech.heat >= 10:
		heat_penalty = 2
	if mech.heat >= 15:
		heat_penalty = 3
	if mech.heat >= 20:
		heat_penalty = 4
	if mech.heat >= 25:
		heat_penalty = 5
	
	var final_walk = base_walk - leg_damage_penalty - heat_penalty
	return max(1, final_walk)  # Mínimo 1

## Calcular distancia corriendo (1.5x walk en BattleTech)
static func calculate_run_distance(mech) -> int:
	var walk = calculate_walk_distance(mech)
	return int(walk * 1.5)

## Calcular distancia de salto
static func calculate_jump_distance(mech) -> int:
	# Verificar si el mech tiene la propiedad jump_mp
	if not "jump_mp" in mech:
		return 0
	
	var base_jump = mech.jump_mp
	
	# Penalización por daño en piernas (solo si el mech tiene sistema de armadura por localización)
	var leg_damage_penalty = 0
	if mech.has_method("get_location_armor"):
		if mech.get_location_armor("right_leg") <= 0 or mech.get_location_armor("left_leg") <= 0:
			leg_damage_penalty = base_jump / 2
	
	var final_jump = base_jump - leg_damage_penalty
	return max(0, final_jump)

## Calcular coste de movimiento BattleTech entre dos hexes
## movement_type: 1=WALK, 2=RUN, 3=JUMP
static func calculate_movement_cost(from_hex: Vector2i, to_hex: Vector2i, movement_type: int, hex_grid) -> int:
	if not hex_grid.is_valid_hex(to_hex):
		return 999
	
	# SALTAR: ignora terreno, solo cuenta hexes
	if movement_type == GameEnums.MovementType.JUMP:
		return 1  # Saltar siempre cuesta 1 MP por hex
	
	# Obtener terreno del hex destino
	var terrain = hex_grid.get_terrain(to_hex)
	
	# Coste base según tipo de movimiento y terreno
	var base_cost = 0
	match movement_type:
		GameEnums.MovementType.WALK:
			base_cost = TerrainType.get_movement_cost_by_type(terrain, 1)
		GameEnums.MovementType.RUN:
			base_cost = TerrainType.get_movement_cost_by_type(terrain, 2)
		_:
			base_cost = 1
	
	# Aplicar modificador de terreno (carreteras = -1)
	var terrain_modifier = TerrainType.get_cost_modifier(terrain)
	base_cost = max(1, base_cost + terrain_modifier)  # Mínimo 1
	
	# Calcular coste por elevación (SOLO AL SUBIR)
	var from_elevation = hex_grid.get_elevation(from_hex)
	var to_elevation = hex_grid.get_elevation(to_hex)
	var elevation_change = to_elevation - from_elevation
	
	var elevation_cost = 0
	if elevation_change > 0:  # Solo si subimos
		elevation_cost = elevation_change * ELEVATION_COST_PER_LEVEL
	# Bajar NO cuesta MPs adicionales
	
	return base_cost + elevation_cost

## Verificar si se puede entrar a un hex
static func can_enter_hex(hex: Vector2i, movement_type: int, mech, hex_grid) -> bool:
	if not hex_grid.is_valid_hex(hex):
		return false
	
	# Verificar si hay unidad bloqueando
	var unit = hex_grid.get_unit(hex)
	if unit != null and unit != mech:
		return false
	
	# Obtener terreno y elevación
	var terrain = hex_grid.get_terrain(hex)
	
	# Verificar terreno prohibido
	# Agua profunda (depth 2+) no es accesible caminando
	if movement_type != GameEnums.MovementType.JUMP:
		var water_depth = TerrainType.get_water_depth(terrain)
		if water_depth >= 2:
			return false  # Solo accesible saltando (según altura del mech)
	
	# Verificar prohibición de correr
	if movement_type == GameEnums.MovementType.RUN:
		if TerrainType.prohibits_running(terrain):
			return false
	
	return true

## Mapear índice de vecino de HEX_DIRECTIONS a facing
## HEX_DIRECTIONS order: N(0), NE(1), NW(2), S(3), SW(4), SE(5)
## Facing enum: N(0), NE(1), SE(2), S(3), SW(4), NW(5)
static func neighbor_index_to_facing(neighbor_index: int) -> int:
	# Mapeo directo del índice de HEX_DIRECTIONS al facing correspondiente
	match neighbor_index:
		0: return 0  # N -> N
		1: return 1  # NE -> NE
		2: return 5  # NW -> NW
		3: return 3  # S -> S
		4: return 4  # SW -> SW
		5: return 2  # SE -> SE
		_: return 0

## Obtener hexes alcanzables con movimiento Walk/Run
## Considera el costo de rotación - girar cuesta MPs
static func get_reachable_hexes(start_hex: Vector2i, max_distance: int, movement_type: int, hex_grid, mech = null) -> Array:
	var reachable = []
	# Guardar facing inicial del mech si está disponible
	var initial_facing = -1
	if mech != null and "facing" in mech:
		initial_facing = mech.facing
	
	# Cada estado incluye: hex, distancia acumulada, facing actual, y path
	var queue = [{hex = start_hex, distance = 0, facing = initial_facing, path = [start_hex]}]
	# Visited ahora guarda el MEJOR coste para cada combinación de (hex, facing)
	var visited = {}
	if initial_facing >= 0:
		visited[str(start_hex) + "_" + str(initial_facing)] = 0
	else:
		visited[str(start_hex)] = 0
	
	var iterations = 0
	var MAX_ITERATIONS = 10000  # Límite de seguridad para evitar loops infinitos
	
	while not queue.is_empty() and iterations < MAX_ITERATIONS:
		iterations += 1
		var current = queue.pop_front()
		var current_hex = current.hex
		var current_distance = current.distance
		var current_facing = current.facing
		
		if current_distance > max_distance:
			continue
		
		if current_hex != start_hex:
			# Solo agregar si este hex no está ya en reachable o si encontramos un camino mejor
			if not reachable.has(current_hex):
				reachable.append(current_hex)
		
		var neighbors = hex_grid.get_neighbors(current_hex)
		for i in range(neighbors.size()):
			var neighbor = neighbors[i]
			if not hex_grid.is_valid_hex(neighbor):
				continue
			
			# Verificar si se puede entrar al hex
			if mech != null and not can_enter_hex(neighbor, movement_type, mech, hex_grid):
				continue
			
			# Calcular el facing necesario para moverse a este vecino
			# El mech cambia su facing al moverse (mira hacia donde se mueve)
			var required_facing = neighbor_index_to_facing(i)
			
			# Calcular coste de rotación desde facing actual al requerido
			var rotation_cost = get_rotation_cost(current_facing, required_facing)
			
			# Calcular coste de movimiento al hex vecino
			var move_cost = calculate_movement_cost(current_hex, neighbor, movement_type, hex_grid)
			
			# Coste total = rotación + movimiento
			var total_cost = rotation_cost + move_cost
			var new_distance = current_distance + total_cost
			
			if new_distance > max_distance:
				continue
			
			# Crear clave para visited que incluye facing si es relevante
			var visited_key = str(neighbor)
			if required_facing >= 0:
				visited_key = str(neighbor) + "_" + str(required_facing)
			
			# Solo agregar a la cola si encontramos un camino mejor
			if not visited.has(visited_key) or new_distance < visited[visited_key]:
				visited[visited_key] = new_distance
				var new_path = current.path.duplicate()
				new_path.append(neighbor)
				queue.append({
					hex = neighbor, 
					distance = new_distance, 
					facing = required_facing,  # Actualizar facing al llegar
					path = new_path
				})
	
	if iterations >= MAX_ITERATIONS:
		push_warning("MovementSystem: get_reachable_hexes alcanzó el límite de iteraciones")
	
	return reachable

## Obtener hexes alcanzables saltando (ignora terreno)
static func get_jump_hexes(start_hex: Vector2i, max_jump: int, hex_grid, mech = null) -> Array:
	var reachable = []
	
	# Saltar es directo: cualquier hex a distancia <= max_jump
	var all_hexes = hex_grid.get_hexes_in_range(start_hex, max_jump)
	
	for hex in all_hexes:
		if hex == start_hex:
			continue
		
		# Verificar restricciones de salto
		if not can_land_on_hex(hex, mech, hex_grid):
			continue
		
		var distance = hex_grid.hex_distance(start_hex, hex)
		if distance <= max_jump:
			reachable.append(hex)
	
	return reachable

## Verificar si se puede aterrizar en un hex al saltar
static func can_land_on_hex(hex: Vector2i, mech, hex_grid) -> bool:
	if not hex_grid.is_valid_hex(hex):
		return false
	
	# Verificar si hay unidad bloqueando
	var unit = hex_grid.get_unit(hex)
	if unit != null and unit != mech:
		return false  # No se puede aterrizar en hex ocupado (excepto DFA)
	
	var terrain = hex_grid.get_terrain(hex)
	var _elevation = hex_grid.get_elevation(hex)
	
	# Agua profunda: depende de la altura del mech
	var water_depth = TerrainType.get_water_depth(terrain)
	if water_depth >= 2:
		# TODO: Verificar altura del mech vs profundidad
		return false
	
	# Edificios: verificar si la altura lo permite
	if terrain == TerrainType.Type.BUILDING:
		# TODO: Verificar nivel del edificio
		pass
	
	return true

## Calcular penalizador de disparo según movimiento
## Retorna modificador al to-hit del atacante
static func get_attacker_movement_modifier(movement_type: int) -> int:
	match movement_type:
		GameEnums.MovementType.WALK:
			return 1  # +1 to-hit al disparar (más difícil)
		GameEnums.MovementType.RUN:
			return 2  # +2 to-hit al disparar
		GameEnums.MovementType.JUMP:
			return 3  # +3 to-hit al disparar (mayor penalización)
		_:
			return 0

## Calcular bonificador de defensa según movimiento
## Retorna modificador al to-hit del enemigo (más difícil impactarte)
static func get_target_movement_modifier(movement_type: int, hexes_moved: int) -> int:
	if hexes_moved == 0:
		return 0  # Sin movimiento, sin bonificación
	
	match movement_type:
		GameEnums.MovementType.WALK:
			return 0  # Caminar no da bonificación de defensa
		GameEnums.MovementType.RUN:
			return 2  # +2 to-hit para enemigos (más difícil impactarte)
		GameEnums.MovementType.JUMP:
			return 2  # +2 to-hit para enemigos
		_:
			return 0

## Calcular coste de MP por girar
## BattleTech: girar cuesta MPs según cuántas facetas giras
## Cada cambio de faceta (60 grados) cuesta 1 MP
static func get_rotation_cost(from_facing: int, to_facing: int) -> int:
	if from_facing < 0 or to_facing < 0:
		return 0  # Sin facing válido, sin coste
	
	# Calcular diferencia de facetas (0-5)
	# Normalizar facings al rango 0-5
	var normalized_from = from_facing % 6
	var normalized_to = to_facing % 6
	
	var diff = abs(normalized_to - normalized_from)
	if diff > 3:
		diff = 6 - diff  # Camino más corto (girar en la otra dirección)
	
	# Cada faceta de rotación cuesta 1 MP
	return diff

## Calcular calor generado por movimiento
static func calculate_heat_from_movement(_mech, hexes_moved: int, movement_type: int) -> int:
	var heat = 0
	
	if hexes_moved > 0:
		match movement_type:
			GameEnums.MovementType.WALK:
				heat = 1  # Caminar genera 1 calor
			GameEnums.MovementType.RUN:
				heat = 2  # Correr genera 2 calor
			GameEnums.MovementType.JUMP:
				heat = hexes_moved  # Saltar genera 1 calor por hex saltado
			_:
				heat = 0
	
	return heat

## Verificar si se requiere chequeo de pilotaje
static func requires_piloting_check(hex: Vector2i, movement_type: int, hex_grid) -> bool:
	if not hex_grid.is_valid_hex(hex):
		return false
	
	var terrain = hex_grid.get_terrain(hex)
	
	# Ciertos terrenos siempre requieren chequeo
	if TerrainType.requires_piloting_check(terrain):
		return true
	
	# Saltar siempre requiere chequeo al aterrizar
	if movement_type == GameEnums.MovementType.JUMP:
		return true
	
	# Bajar más de 1 nivel requiere chequeo
	# TODO: Implementar cuando tengamos el from_hex
	
	return false

## Verificar zona de control de enemigos (ZOC)
## BattleTech: salir de hex adyacente a enemigo requiere piloting check
static func check_enemy_adjacency(from_hex: Vector2i, to_hex: Vector2i, hex_grid) -> bool:
	# Verificar si from_hex tiene enemigos adyacentes
	var has_adjacent_enemy = false
	var neighbors = hex_grid.get_neighbors(from_hex)
	
	for neighbor in neighbors:
		var unit = hex_grid.get_unit(neighbor)
		if unit != null:
			# TODO: Verificar si es enemigo
			has_adjacent_enemy = true
			break
	
	# Si salimos de hex con enemigo adyacente, requiere piloting check
	if has_adjacent_enemy and to_hex not in neighbors:
		return true
	
	return false
