@tool
extends Node2D
class_name HexGrid

# Configuración del grid hexagonal (flat-top hexagons)
var hex_size: float = 64.0  # Tamaño del hexágono
var grid_width: int = 12
var grid_height: int = 16

# Seed para generación procedural (cambia cada partida)
var terrain_seed: int = 0

# Cache de iconos de terreno
var terrain_icons: Dictionary = {}
# Enable this in the Inspector to draw debug overlays (surfaces, depths, elevations)
@export var debug_draw_surfaces: bool = false
@export var base_elevation: int = -2  # All tiles start at this base elevation (levels)
var _prev_debug_draw_surfaces: bool = false
@export var use_depth_renderer: bool = true

var _surface_renderer = null  # HexSurfaceRenderer instance created dynamically

# Direcciones hexagonales (flat-top)
const HEX_DIRECTIONS = [
	Vector2i(0, -1),   # N
	Vector2i(1, -1),  # NE
	Vector2i(-1, 0),  # NW
	Vector2i(0, 1),  # S
	Vector2i(-1, 1),  # SW
	Vector2i(1, 0)    # SE
]

# Almacenamiento del estado del grid
var hex_data: Dictionary = {}  # Posición -> datos (terreno, elevación, unidad)

func _ready():
	z_index = 0  # Grid en el fondo
	# Generar seed aleatorio para esta partida
	terrain_seed = randi()
	_preload_terrain_icons()
	_initialize_grid()
	queue_redraw()  # Forzar redibujado con los nuevos terrenos
	# Ensure we watch for inspector changes in editor / runtime
	_prev_debug_draw_surfaces = debug_draw_surfaces
	set_process(true)
	# Create the surface renderer node (manages depth-pass + per-surface draw)
	if use_depth_renderer:
		# Instantiate the renderer by directly loading the script (avoids parser cache issues)
		var _hs_script = load("res://scripts/hex_surface_renderer.gd")
		_surface_renderer = _hs_script.new()
		_surface_renderer.name = "__hex_surface_renderer"
		add_child(_surface_renderer)
		# Set a reasonable depth resolution to start
		_surface_renderer.set_depth_viewport_scale(0.75)
		# Enable elevation labels by default
		_surface_renderer.show_elevation_labels = true

func _preload_terrain_icons():
	# Precargar todos los iconos SVG
	for terrain_type in TerrainType.Type.values():
		var icon_path = TerrainType.get_icon(terrain_type)
		if icon_path != "":
			var texture = load(icon_path)
			if texture:
				terrain_icons[terrain_type] = texture

func _initialize_grid():
	# Decidir tipo de mapa (50% urbano, 50% natural)
	var is_urban_map = randf() < 0.5
	
	# FASE 1: Generar terreno base con ruido
	_generate_base_terrain()
	
	if is_urban_map:
		# FASE 2: Generar zona urbana (solo en mapas urbanos)
		_generate_urban_zone()
		
		# FASE 3: Aplanar terreno urbano ANTES de generar elevaciones
		_flatten_urban_area()
		
		# FASE 4: Generar carreteras que conectan edificios
		_generate_roads()
	else:
		# En mapas naturales, generar bosques más abundantes
		_generate_forest_patches(true)  # Modo abundante
	
	# FASE 5: Generar bosques coherentes (si no es urbano o poco si es urbano)
	if not is_urban_map:
		_generate_forest_patches(false)
	
	# FASE 6: Generar elevación coherente
	_generate_all_elevations()
	
	# FASE 7: Marcar hexágonos transitables
	_mark_walkable_hexes()

# FASE 1: Terreno base con ruido (solo terrenos naturales)
func _generate_base_terrain():
	for q in range(grid_width):
		for r in range(grid_height):
			var pos = Vector2i(q, r)
			var noise_value = _simple_noise(q, r)
			
			var terrain_type: TerrainType.Type
			
			# Solo terrenos naturales en esta fase
			if noise_value < 0.05:
				terrain_type = TerrainType.Type.WATER
			elif noise_value < 0.15:
				terrain_type = TerrainType.Type.SAND
			elif noise_value < 0.40:
				terrain_type = TerrainType.Type.CLEAR
			elif noise_value < 0.60:
				terrain_type = TerrainType.Type.ROUGH
			elif noise_value < 0.80:
				terrain_type = TerrainType.Type.HILL
			else:
				terrain_type = TerrainType.Type.CLEAR  # Placeholder para bosques
			
			hex_data[pos] = {
				"terrain": terrain_type,
				"elevation": 0,  # Se calculará después
				"unit": null,
				"walkable": true
			}

# FASE 2: Generar zona urbana coherente (máximo 50% del mapa, centrada)
func _generate_urban_zone():
	# Calcular centro del mapa
	var center_q = int(grid_width / 2.0)
	var center_r = int(grid_height / 2.0)
	var center = Vector2i(center_q, center_r)
	
	# Calcular área máxima urbana (50% del mapa)
	var total_tiles = grid_width * grid_height
	var max_urban_tiles = total_tiles * 0.5
	
	# Número de edificios (15-25% del área urbana)
	var num_buildings = int(max_urban_tiles * randf_range(0.15, 0.25))
	
	# Radio máximo desde el centro
	var max_radius = min(grid_width, grid_height) / 2
	
	# Colocar edificios en el área central
	var buildings_placed = 0
	var attempts = 0
	var max_attempts = num_buildings * 10
	
	while buildings_placed < num_buildings and attempts < max_attempts:
		attempts += 1
		
		# Generar posición cerca del centro (distribución gaussiana)
		var angle = randf() * TAU
		var distance = randf() * randf() * max_radius  # randf() * randf() sesga hacia el centro
		
		var offset_q = int(cos(angle) * distance)
		var offset_r = int(sin(angle) * distance)
		var pos = Vector2i(center.x + offset_q, center.y + offset_r)
		
		if not is_valid_hex(pos):
			continue
		
		# No colocar edificios en agua
		if hex_data[pos]["terrain"] == TerrainType.Type.WATER:
			continue
		
		# Verificar que no haya edificio muy cerca (mínimo 2 tiles de distancia)
		var too_close = false
		for neighbor in get_neighbors(pos):
			if hex_data[neighbor]["terrain"] == TerrainType.Type.BUILDING:
				too_close = true
				break
			# Verificar también vecinos de segundo nivel
			for second_neighbor in get_neighbors(neighbor):
				if hex_data[second_neighbor]["terrain"] == TerrainType.Type.BUILDING:
					too_close = true
					break
			if too_close:
				break
		
		if too_close:
			continue
		
		# Colocar edificio
		hex_data[pos]["terrain"] = TerrainType.Type.BUILDING
		buildings_placed += 1

# FASE 3: Aplanar área urbana (edificios y alrededores)
func _flatten_urban_area():
	# Encontrar todos los edificios y marcar área urbana
	var urban_tiles = []
	
	for pos in hex_data.keys():
		if hex_data[pos]["terrain"] == TerrainType.Type.BUILDING:
			# El edificio mismo
			urban_tiles.append(pos)
			
			# Aplanar vecinos inmediatos (para carreteras)
			for neighbor in get_neighbors(pos):
				if hex_data[neighbor]["terrain"] != TerrainType.Type.WATER:
					if not urban_tiles.has(neighbor):
						urban_tiles.append(neighbor)
	
	# Calcular elevación base urbana (nivel 0-1)
	var base_urban_elevation = randi_range(0, 1)
	
	# Aplanar todos los tiles urbanos al mismo nivel
	for tile in urban_tiles:
		if hex_data[tile]["terrain"] == TerrainType.Type.BUILDING:
			# Los edificios se elevarán después, por ahora marcarlos
			hex_data[tile]["elevation"] = base_urban_elevation
		else:
			# El resto del área urbana (futuras carreteras) nivel plano
			hex_data[tile]["elevation"] = base_urban_elevation

# FASE 4: Generar carreteras conectando edificios (sin ensanchar cruces)
func _generate_roads():
	# Encontrar todos los edificios
	var buildings = []
	for pos in hex_data.keys():
		if hex_data[pos]["terrain"] == TerrainType.Type.BUILDING:
			buildings.append(pos)
	
	if buildings.size() < 2:
		return
	
	# Crear árbol de expansión mínimo (conectar todos los edificios con caminos mínimos)
	var connected = [buildings[0]]
	var unconnected = buildings.slice(1)
	
	while unconnected.size() > 0:
		var best_pair = null
		var best_distance = INF
		
		# Encontrar el par más cercano entre conectados y no conectados
		for conn in connected:
			for unconn in unconnected:
				var dist = hex_distance(conn, unconn)
				if dist < best_distance and dist <= 8:  # Máximo 8 tiles
					best_distance = dist
					best_pair = [conn, unconn]
		
		if best_pair == null:
			# No se puede conectar más edificios, tomar el siguiente sin conectar
			if unconnected.size() > 0:
				connected.append(unconnected[0])
				unconnected.remove_at(0)
			break
		
		# Crear carretera entre el par
		_create_road_between(best_pair[0], best_pair[1])
		
		connected.append(best_pair[1])
		unconnected.erase(best_pair[1])

# Crear carretera entre dos puntos (1 tile de ancho, sin ensanchar cruces)
func _create_road_between(start: Vector2i, end: Vector2i):
	# Pathfinding simple para crear camino
	var current = start
	var visited = {}
	
	while current != end:
		visited[current] = true
		
		# Encontrar vecino más cercano al objetivo
		var best_neighbor = null
		var best_distance = INF
		
		for neighbor in get_neighbors(current):
			if visited.has(neighbor):
				continue
			
			var dist = hex_distance(neighbor, end)
			if dist < best_distance:
				best_distance = dist
				best_neighbor = neighbor
		
		if best_neighbor == null:
			break
		
		# Colocar pavimento si no es edificio o agua
		if best_neighbor != end and best_neighbor != start:
			if hex_data[best_neighbor]["terrain"] != TerrainType.Type.BUILDING and \
			   hex_data[best_neighbor]["terrain"] != TerrainType.Type.WATER:
				hex_data[best_neighbor]["terrain"] = TerrainType.Type.PAVEMENT
		
		current = best_neighbor
		
		# Evitar bucles infinitos
		if visited.size() > 20:
			break

# FASE 4: Generar parches coherentes de bosque
func _generate_forest_patches(abundant: bool = false):
	var num_patches = randi_range(6, 10) if abundant else randi_range(2, 4)
	
	for i in range(num_patches):
		# Centro del parche
		var center_q = randi_range(1, grid_width - 2)
		var center_r = randi_range(1, grid_height - 2)
		var center = Vector2i(center_q, center_r)
		
		# No colocar bosque sobre urbano o agua
		if hex_data[center]["terrain"] == TerrainType.Type.BUILDING or \
		   hex_data[center]["terrain"] == TerrainType.Type.PAVEMENT or \
		   hex_data[center]["terrain"] == TerrainType.Type.WATER:
			continue
		
		# Tamaño del parche
		var patch_size = randi_range(4, 10) if abundant else randi_range(3, 6)
		
		# Expansión desde el centro
		var forest_tiles = [center]
		hex_data[center]["terrain"] = TerrainType.Type.FOREST
		
		for j in range(patch_size):
			if forest_tiles.is_empty():
				break
			
			var random_tile = forest_tiles[randi() % forest_tiles.size()]
			
			for neighbor in get_neighbors(random_tile):
				# 60% probabilidad de expandir a vecino
				if randf() > 0.6:
					continue
				
				# No expandir sobre urbano o agua
				if hex_data[neighbor]["terrain"] == TerrainType.Type.BUILDING or \
				   hex_data[neighbor]["terrain"] == TerrainType.Type.PAVEMENT or \
				   hex_data[neighbor]["terrain"] == TerrainType.Type.WATER:
					continue
				
				hex_data[neighbor]["terrain"] = TerrainType.Type.FOREST
				forest_tiles.append(neighbor)

# FASE 5: Generar elevaciones coherentes
func _generate_all_elevations():
	# PASO 1: Asignar elevación inicial basada en terreno
	for pos in hex_data.keys():
		var terrain = hex_data[pos]["terrain"]
		
		# Los edificios y pavimento ya tienen su elevación base de _flatten_urban_area
		if terrain != TerrainType.Type.BUILDING and terrain != TerrainType.Type.PAVEMENT:
			var elevation = _generate_elevation(pos.x, pos.y, terrain)
			hex_data[pos]["elevation"] = elevation
	
	# PASO 2: Suavizar elevaciones para evitar cambios bruscos
	_smooth_elevations(3)  # 3 pasadas de suavizado
	
	# PASO 3: Elevar edificios (DESPUÉS del suavizado para que sobresalgan)
	_elevate_buildings()

# Suavizar elevaciones para coherencia entre vecinos
func _smooth_elevations(passes: int):
	for _pass in range(passes):
		var new_elevations = {}
		
		for pos in hex_data.keys():
			var _terrain = hex_data[pos]["terrain"]
			var current_elevation = hex_data[pos]["elevation"]
			
			# Obtener elevaciones de vecinos
			var neighbor_elevations = []
			for neighbor in get_neighbors(pos):
				neighbor_elevations.append(hex_data[neighbor]["elevation"])
			
			if neighbor_elevations.is_empty():
				new_elevations[pos] = current_elevation
				continue
			
			# Calcular promedio de vecinos
			var _avg_elevation = 0.0
			for elev in neighbor_elevations:
				_avg_elevation += elev
			_avg_elevation /= neighbor_elevations.size()
			
			# Determinar cambio máximo permitido según tipo de terreno
			var max_change = 3  # Por defecto
			match _terrain:
				TerrainType.Type.HILL:
					max_change = 2  # Colinas cambian máximo 2 niveles
				TerrainType.Type.ROUGH:
					max_change = 3  # Montañas cambian máximo 3 niveles
				TerrainType.Type.WATER:
					max_change = 1  # Agua muy plana
				TerrainType.Type.PAVEMENT, TerrainType.Type.BUILDING:
					max_change = 1  # Urbano es plano
				_:
					max_change = 2  # Resto moderado
			
			# Ajustar elevación para que no exceda el cambio máximo con vecinos
			var max_neighbor = -999
			var min_neighbor = 999
			for elev in neighbor_elevations:
				if elev > max_neighbor:
					max_neighbor = elev
				if elev < min_neighbor:
					min_neighbor = elev
			
			# Limitar la elevación actual
			var adjusted_elevation = current_elevation
			if current_elevation > max_neighbor + max_change:
				adjusted_elevation = max_neighbor + max_change
			elif current_elevation < min_neighbor - max_change:
				adjusted_elevation = min_neighbor - max_change
			
			new_elevations[pos] = adjusted_elevation
		
		# Aplicar nuevas elevaciones
		for pos in new_elevations.keys():
			hex_data[pos]["elevation"] = new_elevations[pos]

# Elevar edificios sobre el terreno base (mínimo 3 niveles)
func _elevate_buildings():
	for pos in hex_data.keys():
		if hex_data[pos]["terrain"] == TerrainType.Type.BUILDING:
			# El edificio se eleva entre 3-5 niveles sobre su base
			var building_base_elevation = hex_data[pos]["elevation"]
			var building_height = randi_range(3, 5)
			hex_data[pos]["elevation"] = building_base_elevation + building_height

# FASE 6: Marcar hexágonos transitables
func _mark_walkable_hexes():
	for pos in hex_data.keys():
		var terrain = hex_data[pos]["terrain"]
		var is_walkable = (terrain != TerrainType.Type.WATER)
		hex_data[pos]["walkable"] = is_walkable

# Convertir coordenadas hexagonales a píxeles (CENTRO del hexágono)
func hex_to_pixel(hex: Vector2i, include_elevation: bool = false) -> Vector2:
	# Fórmula para flat-top hexagons (orientación con lados planos arriba/abajo)
	var x = hex_size * (3.0/2.0 * hex.x)
	var y = hex_size * sqrt(3.0) * (hex.y + 0.5 * hex.x)
	
	# Aplicar offset de elevación si se solicita
	if include_elevation and is_valid_hex(hex):
		var elevation = get_elevation(hex)
		y -= elevation * 10.0  # Cada nivel = 10 píxeles hacia arriba
	
	return Vector2(x, y)

# Convertir píxeles a coordenadas hexagonales
func pixel_to_hex(pixel: Vector2) -> Vector2i:
	# Fórmula inversa para flat-top hexagons
	var q = (2.0/3.0 * pixel.x) / hex_size
	var r = (-1.0/3.0 * pixel.x + sqrt(3.0)/3.0 * pixel.y) / hex_size
	return axial_round(Vector2(q, r))

func axial_round(hex: Vector2) -> Vector2i:
	var q = round(hex.x)
	var r = round(hex.y)
	var s = round(-hex.x - hex.y)
	
	var q_diff = abs(q - hex.x)
	var r_diff = abs(r - hex.y)
	var s_diff = abs(s - (-hex.x - hex.y))
	
	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
	
	return Vector2i(int(q), int(r))

# Calcular distancia entre dos hexágonos
func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac = axial_to_cube(a)
	var bc = axial_to_cube(b)
	return (abs(ac.x - bc.x) + abs(ac.y - bc.y) + abs(ac.z - bc.z)) / 2

func axial_to_cube(hex: Vector2i) -> Vector3i:
	var x = hex.x
	var z = hex.y
	var y = -x - z
	return Vector3i(x, y, z)

func cube_to_axial(cube: Vector3i) -> Vector2i:
	return Vector2i(cube.x, cube.z)

# Obtener vecinos de un hexágono
func get_neighbors(hex: Vector2i) -> Array:
	var neighbors = []
	for direction in HEX_DIRECTIONS:
		var neighbor = hex + direction
		if is_valid_hex(neighbor):
			neighbors.append(neighbor)
	return neighbors

func is_valid_hex(hex: Vector2i) -> bool:
	return hex.x >= 0 and hex.x < grid_width and hex.y >= 0 and hex.y < grid_height

# Pathfinding: encontrar camino entre dos hexágonos
func find_path(start: Vector2i, goal: Vector2i, max_distance: int = -1) -> Array:
	if not is_valid_hex(start) or not is_valid_hex(goal):
		return []
	
	if not hex_data[goal]["walkable"]:
		return []
	
	var frontier = [start]
	var came_from = {start: null}
	var cost_so_far = {start: 0}
	
	while frontier.size() > 0:
		var current_hex = _get_lowest_cost(frontier, cost_so_far)
		frontier.erase(current_hex)
		
		if current_hex == goal:
			break
		
		for next_hex in get_neighbors(current_hex):
			if not hex_data[next_hex]["walkable"]:
				continue
			
			var new_cost = cost_so_far[current_hex] + _get_movement_cost(current_hex, next_hex)
			
			if max_distance > 0 and new_cost > max_distance:
				continue
			
			if not cost_so_far.has(next_hex) or new_cost < cost_so_far[next_hex]:
				cost_so_far[next_hex] = new_cost
				came_from[next_hex] = current_hex
				if not frontier.has(next_hex):
					frontier.append(next_hex)
	
	# Reconstruir camino
	if not came_from.has(goal):
		return []
	
	var path = []
	var current = goal
	while current != null:
		path.push_front(current)
		current = came_from[current]
	
	return path

func _get_lowest_cost(frontier: Array, costs: Dictionary) -> Vector2i:
	var lowest = frontier[0]
	var lowest_cost = costs.get(lowest, INF)
	
	for hex in frontier:
		var cost = costs.get(hex, INF)
		if cost < lowest_cost:
			lowest = hex
			lowest_cost = cost
	
	return lowest

# Obtener todos los hexágonos dentro de un rango
func get_hexes_in_range(center: Vector2i, range_val: int) -> Array:
	var results = []
	
	for q in range(-range_val, range_val + 1):
		for r in range(max(-range_val, -q - range_val), min(range_val, -q + range_val) + 1):
			var hex = center + Vector2i(q, r)
			if is_valid_hex(hex):
				results.append(hex)
	
	return results

# Obtener hexágonos alcanzables con movimiento limitado
func get_reachable_hexes(start: Vector2i, movement_points: int) -> Array:
	var reachable = []
	var visited = {start: 0}
	var frontier = [start]
	
	while frontier.size() > 0:
		var current = frontier.pop_front()
		var current_cost = visited[current]
		
		for next_hex in get_neighbors(current):
			# Permitir el hexágono de inicio, pero no otros hexágonos ocupados
			if next_hex != start and not hex_data[next_hex]["walkable"]:
				continue
			
			var terrain_cost = _get_movement_cost(current, next_hex)
			var new_cost = current_cost + terrain_cost
			
			if new_cost <= movement_points:
				if not visited.has(next_hex) or new_cost < visited[next_hex]:
					visited[next_hex] = new_cost
					# Solo agregar a frontier si no está ocupado (excepto el inicio)
					if next_hex == start or hex_data[next_hex]["unit"] == null:
						frontier.append(next_hex)
					# Agregar a reachable solo si no es el inicio y no está ocupado
					if next_hex != start and hex_data[next_hex]["unit"] == null:
						if not reachable.has(next_hex):
							reachable.append(next_hex)
	
	return reachable

# Colocar/remover unidad en el grid
func set_unit(hex: Vector2i, unit):
	if is_valid_hex(hex):
		hex_data[hex]["unit"] = unit
		hex_data[hex]["walkable"] = (unit == null)

func get_unit(hex: Vector2i):
	if is_valid_hex(hex):
		return hex_data[hex]["unit"]
	return null

# Línea de visión
# Generar terreno proceduralmente
# Ruido simple basado en funciones matemáticas
func _simple_noise(x: int, y: int) -> float:
	var n = x + y * 57 + terrain_seed * 131  # Usar el seed de la partida
	n = (n << 13) ^ n
	var nn = (n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff
	# Normalizar correctamente entre 0.0 y 1.0
	return float(nn) / 2147483647.0

# Generar elevación procedural coherente
func _generate_elevation(q: int, r: int, terrain: TerrainType.Type) -> int:
	# Usar ruido con escala más grande para elevación (más suave)
	var elevation_noise = _layered_noise(q, r, 3)
	
	# Diferentes terrenos tienen diferentes rangos de elevación
	match terrain:
		TerrainType.Type.WATER:
			return -1  # Agua está por debajo del nivel del mar
		TerrainType.Type.SAND:
			return 0   # Playa al nivel del mar
		TerrainType.Type.CLEAR:
			# Terreno claro: 0-1 niveles
			return 1 if elevation_noise > 0.6 else 0
		TerrainType.Type.ROUGH:
			# Terreno accidentado: 0-2 niveles
			if elevation_noise > 0.7:
				return 2
			elif elevation_noise > 0.4:
				return 1
			else:
				return 0
		TerrainType.Type.FOREST:
			# Bosque: 0-2 niveles (árboles dan cobertura pero no elevan tanto)
			if elevation_noise > 0.65:
				return 2
			elif elevation_noise > 0.35:
				return 1
			else:
				return 0
		TerrainType.Type.HILL:
			# Colinas: 2-4 niveles (más altas)
			if elevation_noise > 0.8:
				return 4
			elif elevation_noise > 0.6:
				return 3
			else:
				return 2
		TerrainType.Type.BUILDING:
			# Los edificios ya tienen su elevación base establecida en _flatten_urban_area
			# Aquí NO se modifica, se eleva en post-procesamiento
			return 0  # Placeholder, se ajustará después
		TerrainType.Type.PAVEMENT:
			# Pavimento: mantiene la elevación del área urbana
			return 0  # Placeholder, se ajustará después
		_:
			return 0

# Ruido en capas para mayor coherencia
func _layered_noise(x: int, y: int, octaves: int = 3) -> float:
	var value = 0.0
	var amplitude = 1.0
	var frequency = 1.0
	var max_value = 0.0
	
	for i in range(octaves):
		var sample_x = x * frequency
		var sample_y = y * frequency
		value += _simple_noise(int(sample_x), int(sample_y)) * amplitude
		max_value += amplitude
		amplitude *= 0.5
		frequency *= 2.0
	
	return value / max_value

# Obtener costo de movimiento considerando terreno
func get_terrain_cost(hex: Vector2i) -> int:
	if not is_valid_hex(hex):
		return 999
	
	var terrain = hex_data[hex]["terrain"]
	return TerrainType.get_movement_cost(terrain)

# Método auxiliar para calcular costo de movimiento considerando terreno Y elevación
func _get_movement_cost(from: Vector2i, to: Vector2i) -> int:
	var base_cost = get_terrain_cost(to)
	
	# Añadir costo por cambio de elevación
	var elevation_diff = abs(get_elevation(to) - get_elevation(from))
	
	# Cada nivel de subida cuesta +1 MP adicional (BattleTech rules)
	var elevation_cost = elevation_diff if get_elevation(to) > get_elevation(from) else 0
	
	return base_cost + elevation_cost

# Dibujar el grid con colores de terreno y elevación
func _draw():
	# Generate surfaces and pass to renderer
	_update_surface_renderer()

func _update_surface_renderer():
	# Dibujar en orden de elevación (primero los bajos, luego los altos)
	var sorted_hexes = hex_data.keys()
	# Use a proper comparator function for sort_custom — Godot expects a method that
	# returns -1/0/1. The previous inline lambda returned a boolean which can cause
	# unpredictable behavior or runtime errors.
	# Godot 4 expects a single Callable argument for sort_custom.
	# Create a Callable pointing at our comparator method.
	sorted_hexes.sort_custom(Callable(self, "_compare_hex_elevation"))
	
	# Build surface list (each drawable face becomes a surface), compute approximate depth
	var surfaces: Array = []

	for hex_pos in sorted_hexes:
		var pixel_pos = hex_to_pixel(hex_pos, false)
		var terrain = hex_data[hex_pos]["terrain"]
		var elevation = hex_data[hex_pos]["elevation"]

		# Top center for this tile
		var elevation_offset = Vector2(0, -elevation * 10.0)
		var top_center = pixel_pos + elevation_offset
		var colors = _get_terrain_colors(terrain, elevation)

		# Top face polygon (use vertices to compute a depth metric)
		var top_vertices = PackedVector2Array()
		var sum_y = 0.0
		for i in range(6):
			var angle = deg_to_rad(60 * i)
			var v = Vector2(top_center.x + hex_size * cos(angle), top_center.y + hex_size * sin(angle))
			top_vertices.append(v)
			sum_y += v.y
		var avg_y_top = sum_y / float(top_vertices.size()) if top_vertices.size() > 0 else top_center.y

		# Get texture paths for this terrain type
		var texture_path = _get_terrain_texture_path(terrain)
		var normal_map_path = _get_terrain_normal_map_path(terrain)
		
		surfaces.append({"depth": avg_y_top, "type": "top", "center": top_center, "colors": colors, "terrain": terrain, "elevation": elevation, "top_vertices": top_vertices, "hex": hex_pos, "albedo_texture": texture_path, "normal_map": normal_map_path})

		# Add vertical side faces for each tile to give volume from base_elevation up to tile elevation
		if elevation > base_elevation:
			# Use a consistent brown color for all vertical faces (lighting will be applied by shader)
			var face_base_color = Color(0.4, 0.25, 0.15)  # Brown/earth tone

			# Flat-top hexagons: render visible sides in isometric view
			# Vertices are generated at angles: 0°, 60°, 120°, 180°, 240°, 300°
			# For flat-top hexagons:
			# - Vertex 0 (0°): East
			# - Vertex 1 (60°): Southeast 
			# - Vertex 2 (120°): Southwest
			# - Vertex 3 (180°): West
			# - Vertex 4 (240°): Northwest
			# - Vertex 5 (300°): Northeast
			#
			# Edges perpendicular to neighbor directions:
			# - Edge 0→1: neighbor is SE (HEX_DIRECTIONS[5])
			# - Edge 1→2: neighbor is S (HEX_DIRECTIONS[3])
			# - Edge 2→3: neighbor is SW (HEX_DIRECTIONS[4])
			
			var edge_to_neighbor = {
				0: 5,  # Edge 0→1 faces SE
				1: 3,  # Edge 1→2 faces S
				2: 4   # Edge 2→3 faces SW
			}

			for vertex_idx in edge_to_neighbor.keys():
				# Get the correct neighbor direction for this edge
				var neighbor_dir_idx = edge_to_neighbor[vertex_idx]
				var neighbor = hex_pos + HEX_DIRECTIONS[neighbor_dir_idx]
				var neigh_elev = base_elevation
				if is_valid_hex(neighbor) and hex_data.has(neighbor):
					neigh_elev = hex_data[neighbor]["elevation"]

				# If neighbor's elevation is >= our top elevation, the side is hidden (shared or higher)
				if neigh_elev >= elevation:
					continue

				# Get the two vertices of this edge (in top face of THIS tile)
				var v1t = top_vertices[vertex_idx]
				var v2t = top_vertices[(vertex_idx + 1) % 6]

				# ✅ Calculate bottom vertices at the neighbor's elevation
				var elevation_diff = (elevation - neigh_elev) * 10.0
				var v1b = Vector2(v1t.x, v1t.y + elevation_diff)
				var v2b = Vector2(v2t.x, v2t.y + elevation_diff)

				# Create quad face: v1b, v2b, v2t, v1t (counter-clockwise from bottom)
				var face_points = PackedVector2Array([v1b, v2b, v2t, v1t])
				var avg_y_face = (v1b.y + v2b.y + v2t.y + v1t.y) / 4.0
				surfaces.append({"depth": avg_y_face, "type": "side", "points": face_points, "color": face_base_color, "outline_color": face_base_color.darkened(0.3), "elevation": elevation, "hex": hex_pos, "neighbor_elev": neigh_elev, "face_direction": neighbor_dir_idx})

	# Group surfaces by elevation so we can DRAW STRICTLY by height only

	# --- MECH SHADOWS: find MechEntity nodes and add projected blob shadows ---
	# We'll add simple blob shadows centered on the mech's hex (pixel-perfect occluded
	# by the depth map created earlier). This keeps mechs as 2D sprites and projects
	# shadows into the world with pixel-accurate occlusion.
	for mech_node in get_tree().get_nodes_in_group("mechs"):
		if not mech_node or not mech_node.is_inside_tree():
			continue
		# Find mech world position and map to the grid
		var mech_pos = mech_node.global_position
		var mech_hex = pixel_to_hex(mech_pos)
		if not is_valid_hex(mech_hex):
			continue
		# Ground center and elevation
		var ground_center = hex_to_pixel(mech_hex, true)
		var ground_elev = get_elevation(mech_hex)
		# Simple radius based on mech tonnage or default
		var radius = hex_size * 0.6
		if mech_node.has_method("get_mech_class"):
			# If mech provides size via sprite_manager, approximate scale
			radius *= 1.0
		# Build an ellipse/circle polygon approximated by 12 points
		var shadow_points = PackedVector2Array()
		var segments = 12
		for i in range(segments):
			var a = deg_to_rad(360.0 * float(i) / float(segments))
			shadow_points.append(Vector2(ground_center.x + cos(a) * radius, ground_center.y + sin(a) * radius - max(0, (ground_elev - base_elevation) * 10.0)))
		# Add shadow surface (top_vertices style so elevation is uniform)
		surfaces.append({"depth": ground_center.y, "type": "shadow", "top_vertices": shadow_points, "color": Color(0, 0, 0, 0.55), "elevation": ground_elev, "hex": mech_hex})

	# If we're using the depth renderer, hand all surfaces off to it and skip
	# the canvas immediate-mode drawing path (Polygon2D nodes will render instead).
	if use_depth_renderer and _surface_renderer:
		_surface_renderer.update_surfaces(surfaces, base_elevation)
		# Keep debug overlays & validations below, but skip the immediate-mode draw
		# so we don't double-draw polygons that are now handled by the renderer.
		# NOTE: This ends the draw pass early; we still proceed to some debug logic
		# below that does string overlays and ordering checks.
		# return early to avoid the draw loop
		return
	var groups := {}
	for surf in surfaces:
		var elev = 0
		if typeof(surf) == TYPE_DICTIONARY and surf.has("elevation"):
			elev = int(surf.get("elevation", 0))
		if not groups.has(elev):
			groups[elev] = []
		groups[elev].append(surf)

	# Get sorted list of elevations (low first)
	var elev_keys = groups.keys()
	elev_keys.sort()

	# Debug validation: detect any ordering violation (earlier surface with higher elevation)
	if debug_draw_surfaces:
		for k in range(surfaces.size() - 1):
			var ea = 0
			var eb = 0
			if typeof(surfaces[k]) == TYPE_DICTIONARY and surfaces[k].has("elevation"):
				ea = int(surfaces[k].get("elevation", 0))
			if typeof(surfaces[k + 1]) == TYPE_DICTIONARY and surfaces[k + 1].has("elevation"):
				eb = int(surfaces[k + 1].get("elevation", 0))
			if ea > eb:
				# mark the earlier surface as problematic
				var bad = surfaces[k]
				var pos = bad["center"] if bad.has("center") else (bad["points"][0] if bad.has("points") else Vector2())
				draw_string(ThemeDB.fallback_font, pos + Vector2(0, 6), "ORDER VIOLATION %d>%d idx=%d" % [ea, eb, k], HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1,0.2,0.2))
				print_debug("ORDER VIOLATION: index %d elevation %d before index %d elevation %d" % [k, ea, k+1, eb])

	# Draw every surface grouped by elevation (strict height-first ordering)
	var draw_index = 0
	for elev in elev_keys:
		var group = groups[elev]
		# Optionally we can sort each group by screen depth for deterministic rendering inside same elevation
		group.sort_custom(Callable(self, "_compare_surfaces_by_screen_depth"))
		for surf in group:
			if surf["type"] == "side":
				draw_colored_polygon(surf["points"], surf["color"])
				var pl = PackedVector2Array()
				for p in surf["points"]:
					pl.append(p)
				pl.append(surf["points"][0])
				draw_polyline(pl, surf["outline_color"], 1.0)
				if debug_draw_surfaces:
					# Overlay diagnostic info for sides
					var mid = Vector2()
					for pt in surf["points"]:
						mid += pt
					mid /= float(surf["points"].size())
					draw_string(ThemeDB.fallback_font, mid + Vector2(0, -6), "side e=%d d=%.1f" % [surf.get("elevation", -999), surf.get("depth", 0.0)], HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1,1,1))
			elif surf["type"] == "top":
				_draw_hex_with_gradient(surf["center"], hex_size, surf["colors"]["light"], surf["colors"]["dark"])
				# Draw beveled border only on edges where neighbor elevation is lower
				if surf.has("hex"):
					_draw_hex_beveled_border_segmented(surf["center"], hex_size, surf["colors"]["highlight"], surf["colors"]["shadow"], surf["hex"], surf["elevation"])
				else:
					_draw_hex_beveled_border(surf["center"], hex_size, surf["colors"]["highlight"], surf["colors"]["shadow"])

				if surf["terrain"] and terrain_icons.has(surf["terrain"]):
					var icon = terrain_icons[surf["terrain"]]
					var icon_size = Vector2(32, 32)
					var icon_pos = surf["center"] - icon_size / 2
					draw_texture_rect(icon, Rect2(icon_pos, icon_size), false, Color(1, 1, 1, 0.85))

				if surf["elevation"] != 0:
					var elev_text = "%+d" % surf["elevation"]
					var elev_color = Color.YELLOW if surf["elevation"] > 0 else Color.CYAN
					draw_string(ThemeDB.fallback_font, surf["center"] + Vector2(-7, 21), elev_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0, 0, 0, 0.6))
					draw_string(ThemeDB.fallback_font, surf["center"] + Vector2(-8, 20), elev_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, elev_color)
				if debug_draw_surfaces:
					# Draw debug label of center depth/elevation
					draw_string(ThemeDB.fallback_font, surf["center"] + Vector2(0, -30), "top e=%d d=%.1f" % [surf.get("elevation", -999), surf.get("depth", 0.0)], HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1,1,0))
				if debug_draw_surfaces:
					# draw-order index (0 drawn first)
					draw_string(ThemeDB.fallback_font, surf["center"] + Vector2(0, -14), "#%d" % draw_index, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1,0.8,0))
				draw_index += 1

# Vertical side rendering added — tiles have volume from base_elevation up to their elevation.

## FUNCIONES DE RENDERIZADO HELPER ##

func _draw_hex_filled(center: Vector2, size: float, color: Color):
	var points = PackedVector2Array()
	for i in range(6):
		var angle_deg = 60 * i
		var angle_rad = deg_to_rad(angle_deg)
		var x = center.x + size * cos(angle_rad)
		var y = center.y + size * sin(angle_rad)
		points.append(Vector2(x, y))
	
	draw_colored_polygon(points, color)

func _draw_hex_outline(center: Vector2, size: float, color: Color):
	for i in range(6):
		var angle_deg = 60 * i
		var angle_rad = deg_to_rad(angle_deg)
		var x = center.x + size * cos(angle_rad)
		var y = center.y + size * sin(angle_rad)
		var next_angle_rad = deg_to_rad((i + 1) * 60)
		var next_x = center.x + size * cos(next_angle_rad)
		var next_y = center.y + size * sin(next_angle_rad)
		draw_line(Vector2(x, y), Vector2(next_x, next_y), color, 2.0)



func _compare_hex_elevation(a, b) -> bool:
	# Comparator for draw order that sorts tiles primarily by elevation
	# (low elevation first -> higher tiles drawn last and appear above lower tiles),
	# then by screen Y and screen X for deterministic ordering.
	var ea = 0
	var eb = 0
	if hex_data.has(a) and typeof(hex_data[a]) == TYPE_DICTIONARY:
		ea = hex_data[a].get("elevation", 0)
	if hex_data.has(b) and typeof(hex_data[b]) == TYPE_DICTIONARY:
		eb = hex_data[b].get("elevation", 0)

	# We want higher elevation to be drawn later (appear on top)
	# So return true if a should come before b (a has lower elevation)
	if ea != eb:
		return ea < eb

	# Elevation tie: compare screen Y then X for deterministic order
	var pa = hex_to_pixel(a, false)
	var pb = hex_to_pixel(b, false)

	if pa.y != pb.y:
		return pa.y < pb.y

	return pa.x < pb.x


func _compare_surfaces_by_depth(a, b) -> bool:
	# Compare surfaces by their 'depth' (average screen Y), ascending
	# ONLY use elevation for ordering. Lower elevation => draw first.
	var ea = 0
	var eb = 0
	if typeof(a) == TYPE_DICTIONARY and a.has("elevation"):
		ea = int(a.get("elevation", 0))
	if typeof(b) == TYPE_DICTIONARY and b.has("elevation"):
		eb = int(b.get("elevation", 0))

	return ea < eb


func _compare_surfaces_by_screen_depth(a, b) -> int:
	var da = 0.0
	var db = 0.0
	if typeof(a) == TYPE_DICTIONARY and a.has("depth"):
		da = float(a.get("depth", 0.0))
	if typeof(b) == TYPE_DICTIONARY and b.has("depth"):
		db = float(b.get("depth", 0.0))
	# Prefer side faces before top faces when depth is similar — that keeps sides behind tops
	var a_type = a.get("type", "") if (typeof(a) == TYPE_DICTIONARY and a.has("type")) else ""
	var b_type = b.get("type", "") if (typeof(b) == TYPE_DICTIONARY and b.has("type")) else ""
	if a_type != b_type:
		if a_type == "side":
			return -1
		elif b_type == "side":
			return 1

	if da < db:
		return -1
	elif da > db:
		return 1
	return 0

func _process(_delta: float) -> void:
	# Watch the exported toggle so the overlay updates immediately in-editor
	if debug_draw_surfaces != _prev_debug_draw_surfaces:
		_prev_debug_draw_surfaces = debug_draw_surfaces
		# Force redraw
		if Engine.is_editor_hint():
			queue_redraw()
		else:
			queue_redraw()

func get_occlusion_edge(hex: Vector2i, observer_hex: Vector2i) -> Array:
	"""
	Retorna la geometría exacta del borde de oclusión para pixel-perfect clipping.
	Retorna un array de puntos que forman el borde superior de las caras laterales visibles.
	"""
	var hex_elevation = get_elevation(hex)
	var observer_elevation = get_elevation(observer_hex)
	
	# Solo hay oclusión si el hex está 2+ niveles más alto
	if hex_elevation < observer_elevation + 2:
		return []
	
	# Calcular la posición del hex oclusor (sin elevación aplicada)
	var hex_pos = hex_to_pixel(hex, false) + position
	var height = hex_elevation * 10.0
	
	# Obtener vértices del hexágono en la BASE (nivel 0)
	var base_vertices = []
	for i in range(6):
		var angle_deg = 60 * i
		var angle_rad = deg_to_rad(angle_deg)
		var x = hex_pos.x + hex_size * cos(angle_rad)
		var y = hex_pos.y + hex_size * sin(angle_rad)
		base_vertices.append(Vector2(x, y))
	
	# Determinar cuáles caras laterales son visibles (las que miran hacia el sur)
	# Las caras 2, 3, 4 son las visibles (SE, S, SW)
	# El borde superior de estas caras forma la línea de oclusión
	var visible_faces = [2, 3, 4]
	
	# Obtener los vértices superiores de las caras visibles
	var edge_points = []
	for face_idx in visible_faces:
		var v_base = base_vertices[face_idx]
		var v_top = v_base + Vector2(0, -height)
		edge_points.append(v_top)
	
	# Agregar también el siguiente vértice para cerrar el polígono
	var last_v_base = base_vertices[(visible_faces[-1] + 1) % 6]
	var last_v_top = last_v_base + Vector2(0, -height)
	edge_points.append(last_v_top)
	
	return edge_points

## FUNCIONES DE RENDERIZADO MEJORADO ##

# Obtener colores de terreno con gradiente según elevación
func _get_terrain_colors(terrain: TerrainType.Type, elevation: int) -> Dictionary:
	var base_color = TerrainType.get_color(terrain)
	
	# Modificar según elevación (más alto = más claro)
	var elevation_brightness = 1.0 + (elevation * 0.12)
	
	# Color más claro (parte superior del gradiente)
	var light_color = base_color * elevation_brightness * 1.3
	light_color.a = base_color.a
	
	# Color más oscuro (parte inferior del gradiente)
	var dark_color = base_color * elevation_brightness * 0.7
	dark_color.a = base_color.a
	
	# Color para highlight (borde superior)
	var highlight_color = light_color.lightened(0.3)
	highlight_color.a = 0.8
	
	# Color para sombra (borde inferior)
	var shadow_color = dark_color.darkened(0.4)
	shadow_color.a = 0.6
	
	return {
		"light": light_color,
		"dark": dark_color,
		"highlight": highlight_color,
		"shadow": shadow_color
	}

# Map terrain types to texture paths
func _get_terrain_texture_path(terrain: TerrainType.Type) -> String:
	match terrain:
		TerrainType.Type.CLEAR:
			return "res://assets/textures/terrain/clear_albedo.jpeg"
		TerrainType.Type.FOREST:
			return "res://assets/textures/terrain/forest_albedo.png"
		TerrainType.Type.WATER:
			return "res://assets/textures/terrain/water_albedo.jpeg"
		TerrainType.Type.ROUGH:
			return "res://assets/textures/terrain/rough_albedo.png"
		TerrainType.Type.PAVEMENT:
			return "res://assets/textures/terrain/pavement_albedo.png"
		TerrainType.Type.SAND:
			return "res://assets/textures/terrain/sand_albedo.png"  # Placeholder
		TerrainType.Type.ICE:
			return "res://assets/textures/terrain/ice_albedo.png"  # Placeholder
		TerrainType.Type.BUILDING:
			return "res://assets/textures/terrain/clear_albedo.png"  # Placeholder
		TerrainType.Type.HILL:
			return "res://assets/textures/terrain/clear_albedo.jpeg"  # Similar to rough
		_:
			return ""  # No texture

func _get_terrain_normal_map_path(terrain: TerrainType.Type) -> String:
	match terrain:
		TerrainType.Type.CLEAR:
			return "res://assets/textures/terrain/clear_normal.png"
		TerrainType.Type.FOREST:
			return "res://assets/textures/terrain/forest_normal.png"
		TerrainType.Type.WATER:
			return "res://assets/textures/terrain/water_normal.png"
		TerrainType.Type.ROUGH:
			return "res://assets/textures/terrain/rough_normal.png"
		TerrainType.Type.PAVEMENT:
			return "res://assets/textures/terrain/pavement_normal.png"
		TerrainType.Type.SAND:
			return "res://assets/textures/terrain/sand_normal.png"
		TerrainType.Type.ICE:
			return "res://assets/textures/terrain/ice_normal.png"
		TerrainType.Type.BUILDING:
			return ""  # No normal map for buildings
		TerrainType.Type.HILL:
			return "res://assets/textures/terrain/clear_normal.png"
		_:
			return ""  # No normal map

# Dibujar hexágono con gradiente radial
func _draw_hex_with_gradient(center: Vector2, size: float, color_center: Color, color_edge: Color):
	var points = PackedVector2Array()
	var colors = PackedColorArray()
	
	# Centro del hexágono
	points.append(center)
	colors.append(color_center)
	
	# Vértices del hexágono
	for i in range(7):  # 7 para cerrar el círculo
		var angle_deg = 60 * i
		var angle_rad = deg_to_rad(angle_deg)
		var x = center.x + size * cos(angle_rad)
		var y = center.y + size * sin(angle_rad)
		points.append(Vector2(x, y))
		colors.append(color_edge)
	
	# Dibujar triángulos desde el centro
	for i in range(6):
		var triangle_points = PackedVector2Array([
			points[0],      # Centro
			points[i + 1],  # Vértice actual
			points[i + 2]   # Siguiente vértice
		])
		var triangle_colors = PackedColorArray([
			colors[0],
			colors[i + 1],
			colors[i + 2]
		])
		draw_polygon(triangle_points, triangle_colors)

# Dibujar borde biselado del hexágono
func _draw_hex_beveled_border(center: Vector2, size: float, highlight_color: Color, shadow_color: Color):
	# Dibujar bordes con efecto de bisel
	for i in range(6):
		var angle_deg = 60 * i
		var angle_rad = deg_to_rad(angle_deg)
		var x1 = center.x + size * cos(angle_rad)
		var y1 = center.y + size * sin(angle_rad)
		
		var next_angle_deg = 60 * ((i + 1) % 6)
		var next_angle_rad = deg_to_rad(next_angle_deg)
		var x2 = center.x + size * cos(next_angle_rad)
		var y2 = center.y + size * sin(next_angle_rad)
		
		var p1 = Vector2(x1, y1)
		var p2 = Vector2(x2, y2)
		
		# Determinar si es borde superior (highlight) o inferior (sombra)
		# Los bordes 0, 1, 5 son superiores, 2, 3, 4 son inferiores
		var color = highlight_color if i in [0, 1, 5] else shadow_color
		
		# Borde externo
		draw_line(p1, p2, color, 2.5)
		
		# Borde interno más oscuro
		var inner_size = size * 0.95
		var x1_inner = center.x + inner_size * cos(angle_rad)
		var y1_inner = center.y + inner_size * sin(angle_rad)
		var x2_inner = center.x + inner_size * cos(next_angle_rad)
		var y2_inner = center.y + inner_size * sin(next_angle_rad)
		
		var inner_color = Color(0.1, 0.1, 0.1, 0.3)
		draw_line(Vector2(x1_inner, y1_inner), Vector2(x2_inner, y2_inner), inner_color, 1.5)


func _draw_hex_beveled_border_segmented(center: Vector2, size: float, highlight_color: Color, shadow_color: Color, hex_coord: Vector2i, elevation: int):
		# Draw beveled border per-edge, skipping edges where the neighbor has >= elevation
	for i in range(6):
		var angle_deg = 60 * i
		var angle_rad = deg_to_rad(angle_deg)
		var x1 = center.x + size * cos(angle_rad)
		var y1 = center.y + size * sin(angle_rad)

		var next_angle_deg = 60 * ((i + 1) % 6)
		var next_angle_rad = deg_to_rad(next_angle_deg)
		var x2 = center.x + size * cos(next_angle_rad)
		var y2 = center.y + size * sin(next_angle_rad)

		var neighbor = hex_coord + HEX_DIRECTIONS[i]
		var neigh_elev = base_elevation
		if is_valid_hex(neighbor) and hex_data.has(neighbor):
			neigh_elev = int(hex_data[neighbor]["elevation"])

		# Skip border if neighbor elevation is >= this tile's elevation (shared or taller)
		if neigh_elev >= elevation:
			continue

		var p1 = Vector2(x1, y1)
		var p2 = Vector2(x2, y2)

		var color = highlight_color if i in [0, 1, 5] else shadow_color
		draw_line(p1, p2, color, 2.5)

		# Inner border
		var inner_size = size * 0.95
		var x1_inner = center.x + inner_size * cos(angle_rad)
		var y1_inner = center.y + inner_size * sin(angle_rad)
		var x2_inner = center.x + inner_size * cos(next_angle_rad)
		var y2_inner = center.y + inner_size * sin(next_angle_rad)
		var inner_color = Color(0.1, 0.1, 0.1, 0.3)
		draw_line(Vector2(x1_inner, y1_inner), Vector2(x2_inner, y2_inner), inner_color, 1.5)

## SISTEMA DE ELEVACIÓN Y LÍNEA DE VISIÓN ##

# Obtener elevación de un hexágono
func get_elevation(hex: Vector2i) -> int:
	if not is_valid_hex(hex):
		return 0
	return hex_data[hex]["elevation"]

# Get the top vertices of a hex tile (for overlay alignment)
func get_hex_top_vertices(hex: Vector2i) -> PackedVector2Array:
	var vertices = PackedVector2Array()
	var pixel_pos = hex_to_pixel(hex, false)
	var elevation = get_elevation(hex)
	var elevation_offset = Vector2(0, -elevation * 10.0)
	var top_center = pixel_pos + elevation_offset
	
	for i in range(6):
		var angle = deg_to_rad(60 * i)
		var v = Vector2(top_center.x + hex_size * cos(angle), top_center.y + hex_size * sin(angle))
		vertices.append(v)
	
	return vertices

func get_terrain(hex: Vector2i) -> TerrainType.Type:
	if not is_valid_hex(hex):
		return TerrainType.Type.CLEAR
	return hex_data[hex]["terrain"]

# Calcular línea de visión entre dos hexágonos considerando elevación
func has_line_of_sight(from_hex: Vector2i, to_hex: Vector2i) -> bool:
	if not is_valid_hex(from_hex) or not is_valid_hex(to_hex):
		return false
	
	# Obtener elevación del atacante y objetivo
	var from_elevation = get_elevation(from_hex)
	var to_elevation = get_elevation(to_hex)
	
	# Obtener todos los hexágonos entre from y to
	var line_hexes = _get_line_between(from_hex, to_hex)
	
	# Verificar si algún hex intermedio bloquea la visión
	for i in range(1, line_hexes.size() - 1):  # Excluir inicio y fin
		var blocking_hex = line_hexes[i]
		var blocking_elevation = get_elevation(blocking_hex)
		var blocking_terrain = hex_data[blocking_hex]["terrain"]
		
		# Calcular la altura efectiva del hex bloqueador
		var blocking_height = blocking_elevation
		
		# Bosques y edificios añaden altura adicional
		if blocking_terrain == TerrainType.Type.FOREST:
			blocking_height += 2  # Árboles añaden 2 niveles
		elif blocking_terrain == TerrainType.Type.BUILDING:
			blocking_height += 3  # Edificios añaden 3 niveles
		
		# Calcular interpolación de la línea de visión
		var progress = float(i) / float(line_hexes.size() - 1)
		var los_height = lerp(float(from_elevation), float(to_elevation), progress)
		
		# Si el hex bloqueador es más alto que la línea de visión, bloquea
		if blocking_height >= los_height + 1:  # +1 para dar margen
			return false
	
	return true

# Obtener hexágonos en línea entre dos puntos (Bresenham adaptado para hexágonos)
func _get_line_between(from_hex: Vector2i, to_hex: Vector2i) -> Array:
	var distance = hex_distance(from_hex, to_hex)
	var results = []
	
	if distance == 0:
		return [from_hex]
	
	for i in range(distance + 1):
		var t = float(i) / float(distance)
		var lerped = _hex_lerp(from_hex, to_hex, t)
		results.append(lerped)
	
	return results

# Interpolación lineal entre hexágonos
func _hex_lerp(a: Vector2i, b: Vector2i, t: float) -> Vector2i:
	var ax = float(a.x)
	var ay = float(a.y)
	var bx = float(b.x)
	var by = float(b.y)
	
	var x = lerp(ax, bx, t)
	var y = lerp(ay, by, t)
	
	return axial_round(Vector2(x, y))

# Calcular modificador de ataque basado en diferencia de altura
# Reglas BattleTech: atacar desde arriba da bonificación, desde abajo penalización
func get_height_modifier(attacker_hex: Vector2i, target_hex: Vector2i) -> int:
	if not is_valid_hex(attacker_hex) or not is_valid_hex(target_hex):
		return 0
	
	var attacker_elev = get_elevation(attacker_hex)
	var target_elev = get_elevation(target_hex)
	var diff = attacker_elev - target_elev
	
	# En BattleTech, cada nivel de diferencia da +/-1 al to-hit
	# Positivo = más fácil golpear (atacando desde arriba)
	# Negativo = más difícil golpear (atacando desde abajo)
	return -diff  # Invertido porque menor número to-hit = mejor

# Verificar si un hex proporciona cobertura parcial por elevación
func provides_partial_cover(attacker_hex: Vector2i, target_hex: Vector2i) -> bool:
	if not has_line_of_sight(attacker_hex, target_hex):
		return false  # Sin LOS no hay disparo
	
	var line_hexes = _get_line_between(attacker_hex, target_hex)
	var target_elev = get_elevation(target_hex)
	
	# Verificar hexágonos adyacentes al objetivo
	for i in range(max(0, line_hexes.size() - 2), line_hexes.size() - 1):
		var hex = line_hexes[i]
		var hex_elev = get_elevation(hex)
		
		# Si hay un hex cercano más alto, da cobertura parcial
		if hex_elev > target_elev:
			return true
	
	return false
