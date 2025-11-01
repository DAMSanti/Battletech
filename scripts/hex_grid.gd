extends Node2D
class_name HexGrid

# Configuración del grid hexagonal (flat-top hexagons)
var hex_size: float = 64.0  # Tamaño del hexágono
var grid_width: int = 12
var grid_height: int = 16

# Seed para generación procedural (cambia cada partida)
var terrain_seed: int = 0

# Direcciones hexagonales (flat-top)
const HEX_DIRECTIONS = [
	Vector2i(1, 0),   # E
	Vector2i(1, -1),  # NE
	Vector2i(0, -1),  # NW
	Vector2i(-1, 0),  # W
	Vector2i(-1, 1),  # SW
	Vector2i(0, 1)    # SE
]

# Almacenamiento del estado del grid
var hex_data: Dictionary = {}  # Posición -> datos (terreno, elevación, unidad)

func _ready():
	z_index = 0  # Grid en el fondo
	# Generar seed aleatorio para esta partida
	terrain_seed = randi()
	_initialize_grid()
	queue_redraw()  # Forzar redibujado con los nuevos terrenos

func _initialize_grid():
	# Generar terrenos proceduralmente con variedad
	for q in range(grid_width):
		for r in range(grid_height):
			var pos = Vector2i(q, r)
			var terrain_type = _generate_terrain(q, r)
			
			# El agua no es transitable para mechs estándar
			var is_walkable = (terrain_type != TerrainType.Type.WATER)
			
			hex_data[pos] = {
				"terrain": terrain_type,
				"elevation": 0,
				"unit": null,
				"walkable": is_walkable
			}

# Convertir coordenadas hexagonales a píxeles (CENTRO del hexágono)
func hex_to_pixel(hex: Vector2i) -> Vector2:
	# Fórmula para flat-top hexagons (orientación con lados planos arriba/abajo)
	var x = hex_size * (3.0/2.0 * hex.x)
	var y = hex_size * sqrt(3.0) * (hex.y + 0.5 * hex.x)
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
		var current = _get_lowest_cost(frontier, cost_so_far)
		frontier.erase(current)
		
		if current == goal:
			break
		
		for next_hex in get_neighbors(current):
			if not hex_data[next_hex]["walkable"]:
				continue
			
			var new_cost = cost_so_far[current] + _get_movement_cost(current, next_hex)
			
			if max_distance > 0 and new_cost > max_distance:
				continue
			
			if not cost_so_far.has(next_hex) or new_cost < cost_so_far[next_hex]:
				cost_so_far[next_hex] = new_cost
				came_from[next_hex] = current
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
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var distance = hex_distance(from, to)
	if distance <= 1:
		return true
	
	# Trazar línea entre hexágonos
	var from_pixel = hex_to_pixel(from)
	var to_pixel = hex_to_pixel(to)
	
	var steps = distance * 2
	for i in range(1, steps):
		var t = float(i) / float(steps)
		var pixel = from_pixel.lerp(to_pixel, t)
		var hex = pixel_to_hex(pixel)
		
		if hex != from and hex != to:
			# Chequear obstáculos
			if hex_data.has(hex):
				var terrain = hex_data[hex]["terrain"]
				if TerrainType.blocks_line_of_sight(terrain):
					return false
				if hex_data[hex]["unit"] != null:
					return false
	
	return true

# Generar terreno proceduralmente
func _generate_terrain(q: int, r: int) -> TerrainType.Type:
	# Usar ruido Perlin simulado con funciones matemáticas
	var noise_value = _simple_noise(q, r)
	
	# Distribuir terrenos basado en el valor de ruido
	# AGUA MUY REDUCIDA - solo 3% del mapa
	if noise_value < 0.03:
		return TerrainType.Type.WATER
	elif noise_value < 0.10:
		return TerrainType.Type.SAND
	elif noise_value < 0.40:
		return TerrainType.Type.CLEAR
	elif noise_value < 0.55:
		return TerrainType.Type.ROUGH
	elif noise_value < 0.72:
		return TerrainType.Type.FOREST
	elif noise_value < 0.85:
		return TerrainType.Type.HILL
	elif noise_value < 0.92:
		return TerrainType.Type.PAVEMENT
	else:
		return TerrainType.Type.BUILDING

# Ruido simple basado en funciones matemáticas
func _simple_noise(x: int, y: int) -> float:
	var n = x + y * 57 + terrain_seed * 131  # Usar el seed de la partida
	n = (n << 13) ^ n
	var nn = (n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff
	# Normalizar correctamente entre 0.0 y 1.0
	return float(nn) / 2147483647.0

# Obtener costo de movimiento considerando terreno
func get_terrain_cost(hex: Vector2i) -> int:
	if not is_valid_hex(hex):
		return 999
	
	var terrain = hex_data[hex]["terrain"]
	return TerrainType.get_movement_cost(terrain)

# Método auxiliar para compatibilidad
func _get_movement_cost(from: Vector2i, to: Vector2i) -> int:
	return get_terrain_cost(to)

# Dibujar el grid con colores de terreno
func _draw():
	for hex_pos in hex_data.keys():
		var pixel_pos = hex_to_pixel(hex_pos)
		var terrain = hex_data[hex_pos]["terrain"]
		var color = TerrainType.get_color(terrain)
		
		# Dibujar hexágono relleno
		_draw_hex_filled(pixel_pos, hex_size, color)
		
		# Dibujar borde del hexágono
		_draw_hex_outline(pixel_pos, hex_size, Color(0.2, 0.2, 0.2, 0.5))
		
		# Dibujar símbolo de terreno
		var symbol = TerrainType.get_symbol(terrain)
		if symbol != "·":  # No dibujar símbolo para terreno clear
			draw_string(ThemeDB.fallback_font, pixel_pos + Vector2(-10, 5), symbol, 
				HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1, 1, 1, 0.7))

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
		var x1 = center.x + size * cos(angle_rad)
		var y1 = center.y + size * sin(angle_rad)
		
		var next_angle_deg = 60 * ((i + 1) % 6)
		var next_angle_rad = deg_to_rad(next_angle_deg)
		var x2 = center.x + size * cos(next_angle_rad)
		var y2 = center.y + size * sin(next_angle_rad)
		
		draw_line(Vector2(x1, y1), Vector2(x2, y2), color, 2.0)
