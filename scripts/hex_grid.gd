@tool
extends Node2D
class_name HexGrid
## Sistema de grid hexagonal para mapas tácticos BattleTech.
##
## Implementa un grid hexagonal flat-top con soporte para:
## - Conversión entre coordenadas hexagonales y píxeles
## - Pathfinding A* con costos de terreno
## - Generación procedural de mapas
## - Línea de visión y cobertura
## - Elevaciones y terreno 3D
##
## @tutorial: Ver doc/TERRAIN_GENERATION.md para detalles del sistema de terreno.

# Preload del controlador de tutorial
const TutorialBattleControllerClass = preload("res://scripts/managers/tutorial_battle_controller.gd")

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

# Tutorial highlight (deprecated - now uses BattleOverlayManager)
var tutorial_highlighted_hexes: Array[Vector2i] = []
var tutorial_highlight_color: Color = Color(0.2, 0.8, 1.0, 0.6)

func _ready():
	z_index = 0  # Grid en el fondo
	
	# Verificar si estamos en modo tutorial (usar mapa fijo)
	var mech_bay_manager = get_node_or_null("/root/MechBayManager")
	var is_tutorial = mech_bay_manager and mech_bay_manager.has_meta("is_tutorial") and mech_bay_manager.get_meta("is_tutorial")
	
	if is_tutorial:
		# Mapa tutorial fijo - plano y sin obstáculos
		terrain_seed = TutorialBattleControllerClass.TUTORIAL_MAP_SEED
		Log.info("System", "Using TUTORIAL map (flat terrain)", {"seed": terrain_seed})
	else:
		# En multiplayer, usar la semilla del servidor; en singleplayer, generar aleatoria
		var network_manager = get_node_or_null("/root/NetworkManager")
		if network_manager and network_manager.is_in_match() and network_manager.current_map_seed != 0:
			terrain_seed = network_manager.current_map_seed
			Log.info("System", "Using server map seed", {"seed": terrain_seed})
		else:
			terrain_seed = randi()
			Log.info("System", "Using random map seed", {"seed": terrain_seed})
	
	_preload_terrain_icons()
	
	# Generar mapa (tutorial = fijo, normal = procedural)
	if is_tutorial:
		_generate_tutorial_map()
	else:
		_generate_procedural_map()
	
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
		# Elevation labels desactivados por defecto (se activan desde el boton de overlays)
		_surface_renderer.show_elevation_labels = false
		# Pasar referencia a este hex_grid para que pueda obtener info de terreno
		_surface_renderer.set_hex_grid(self)
	
	# Tutorial overlay ya no se crea aquí - se usa BattleOverlayManager

func _preload_terrain_icons():
	# Precargar todos los iconos SVG
	for terrain_type in TerrainType.Type.values():
		var icon_path = TerrainType.get_icon(terrain_type)
		if icon_path != "":
			var texture = load(icon_path)
			if texture:
				terrain_icons[terrain_type] = texture

## Generar mapa usando el generador procedural (reglas oficiales BattleTech)
func _generate_procedural_map():
	var generator = ProceduralMapGenerator.new(grid_width, grid_height, terrain_seed)
	hex_data = generator.generate_map()
	Log.info("System", "Mapa procedural generado", {"seed": terrain_seed})

## Generar mapa tutorial (plano, sin obstáculos, línea de visión clara)
func _generate_tutorial_map():
	hex_data = TutorialBattleControllerClass.generate_tutorial_map_data(grid_width, grid_height)
	Log.info("System", "Mapa TUTORIAL generado (plano)", {"seed": terrain_seed})

# ============================================================
# TUTORIAL HIGHLIGHT SYSTEM
# ============================================================

## Convierte coordenadas hexagonales a posición en píxeles (centro del hexágono).
## [param hex]: Coordenadas hexagonales (axial q,r)
## [param include_elevation]: Si true, ajusta Y según la elevación del hex
## [return]: Posición en píxeles del centro del hexágono
func hex_to_pixel(hex: Vector2i, include_elevation: bool = false) -> Vector2:
	# Fórmula para flat-top hexagons (orientación con lados planos arriba/abajo)
	var x = hex_size * (3.0/2.0 * hex.x)
	var y = hex_size * sqrt(3.0) * (hex.y + 0.5 * hex.x)
	
	# Aplicar offset de elevación si se solicita
	if include_elevation and is_valid_hex(hex):
		var elevation = get_elevation(hex)
		y -= elevation * 10.0  # Cada nivel = 10 píxeles hacia arriba
	
	return Vector2(x, y)


## Convierte posición en píxeles a coordenadas hexagonales.
## [param pixel]: Posición en píxeles
## [return]: Coordenadas hexagonales redondeadas al hex más cercano
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


## Calcula la distancia en hexágonos entre dos posiciones (Manhattan hexagonal).
## [param a]: Primer hexágono
## [param b]: Segundo hexágono
## [return]: Distancia en número de hexágonos
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


## Obtiene los hexágonos adyacentes válidos a una posición.
## [param hex]: Posición central
## [return]: Array de Vector2i con los vecinos dentro del grid
func get_neighbors(hex: Vector2i) -> Array:
	var neighbors = []
	for direction in HEX_DIRECTIONS:
		var neighbor = hex + direction
		if is_valid_hex(neighbor):
			neighbors.append(neighbor)
	return neighbors

## Verifica si una coordenada hexagonal está dentro de los límites del grid.
## [param hex]: Coordenadas a verificar
## [return]: true si el hex está dentro del grid
func is_valid_hex(hex: Vector2i) -> bool:
	return hex.x >= 0 and hex.x < grid_width and hex.y >= 0 and hex.y < grid_height


## Encuentra el camino más corto entre dos hexágonos usando A*.
## Considera costos de terreno, elevación y unidades bloqueantes.
## [param start]: Hexágono de inicio
## [param goal]: Hexágono destino
## [param max_distance]: Distancia máxima (-1 = sin límite)
## [return]: Array de Vector2i con el camino, vacío si no hay ruta
func find_path(start: Vector2i, goal: Vector2i, max_distance: int = -1) -> Array:
	if not is_valid_hex(start) or not is_valid_hex(goal):
		return []
	
	if not hex_data[goal].get("walkable", true):
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
			if not hex_data[next_hex].get("walkable", true):
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
			if next_hex != start and not hex_data[next_hex].get("walkable", true):
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
	
	# Diferenciar entre light woods y heavy woods
	if terrain == TerrainType.Type.LIGHT_WOODS:
		base_color = base_color.lightened(0.15)  # Light woods más claro
	elif terrain == TerrainType.Type.HEAVY_WOODS:
		base_color = base_color.darkened(0.15)  # Heavy woods más oscuro
	
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
			return "res://assets/textures/terrain/clear_albedo.png"
		TerrainType.Type.LIGHT_WOODS:
			return "res://assets/textures/terrain/forest_albedo.png"
		TerrainType.Type.HEAVY_WOODS:
			return "res://assets/textures/terrain/forest_albedo.png"
		TerrainType.Type.WATER:
			return "res://assets/textures/terrain/water_albedo.png"
		TerrainType.Type.ROUGH:
			return "res://assets/textures/terrain/rough_albedo.png"
		TerrainType.Type.PAVEMENT:
			return "res://assets/textures/terrain/pavement_albedo.png"
		TerrainType.Type.SAND:
			return "res://assets/textures/terrain/sand_albedo.png"
		TerrainType.Type.ICE:
			return "res://assets/textures/terrain/ice_albedo.png"
		TerrainType.Type.BUILDING:
			return "res://assets/textures/terrain/building_albedo.png"
		TerrainType.Type.HILL:
			return "res://assets/textures/terrain/hill_albedo.png"  # Similar to rough
		_:
			return ""  # No texture

func _get_terrain_normal_map_path(terrain: TerrainType.Type) -> String:
	match terrain:
		TerrainType.Type.CLEAR:
			return "res://assets/textures/terrain/clear_normal.png"
		TerrainType.Type.LIGHT_WOODS:
			return "res://assets/textures/terrain/forest_normal.png"
		TerrainType.Type.HEAVY_WOODS:
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
