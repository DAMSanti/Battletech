extends Node2D
class_name HexGrid

# Configuración del grid hexagonal (flat-top hexagons)
var hex_size: float = 64.0  # Tamaño del hexágono
var grid_width: int = 12
var grid_height: int = 16

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
	_initialize_grid()

func _initialize_grid():
	for q in range(grid_width):
		for r in range(grid_height):
			var pos = Vector2i(q, r)
			hex_data[pos] = {
				"terrain": "clear",
				"elevation": 0,
				"unit": null,
				"walkable": true
			}

# Convertir coordenadas hexagonales a píxeles
func hex_to_pixel(hex: Vector2i) -> Vector2:
	var x = hex_size * (3.0/2.0 * hex.x)
	var y = hex_size * (sqrt(3.0)/2.0 * hex.x + sqrt(3.0) * hex.y)
	return Vector2(x, y)

# Convertir píxeles a coordenadas hexagonales
func pixel_to_hex(pixel: Vector2) -> Vector2i:
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

func _get_movement_cost(from: Vector2i, to: Vector2i) -> int:
	var base_cost = 1
	
	# Modificadores por terreno
	match hex_data[to]["terrain"]:
		"clear":
			base_cost = 1
		"rough":
			base_cost = 2
		"water":
			base_cost = 2
		"woods":
			base_cost = 2
		"heavy_woods":
			base_cost = 3
	
	# Modificadores por elevación
	var elevation_diff = abs(hex_data[to]["elevation"] - hex_data[from]["elevation"])
	base_cost += elevation_diff
	
	return base_cost

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
			if not hex_data[next_hex]["walkable"]:
				continue
			
			var new_cost = current_cost + _get_movement_cost(current, next_hex)
			
			if new_cost <= movement_points:
				if not visited.has(next_hex) or new_cost < visited[next_hex]:
					visited[next_hex] = new_cost
					frontier.append(next_hex)
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
				if hex_data[hex]["terrain"] in ["heavy_woods", "building"]:
					return false
				if hex_data[hex]["unit"] != null:
					return false
	
	return true
