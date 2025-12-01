extends Node2D

## Script de prueba para el generador procedural de mapas
## 
## Uso:
## 1. Crea un nodo Node2D en tu escena
## 2. Asígnale este script
## 3. Ejecuta la escena
## 4. Presiona F5 para regenerar el mapa con un nuevo seed

const ProceduralMapGenerator = preload("res://scripts/core/terrain/procedural_map_generator.gd")

var hex_size: float = 32.0  # Tamaño más pequeño para testing
var map_data: Dictionary = {}
var current_seed: int = 0

func _ready():
	# Generar primer mapa
	generate_new_map()

func _process(_delta):
	# Regenerar al presionar F5
	if Input.is_action_just_pressed("ui_cancel"):  # ESC
		queue_free()
	
	if Input.is_action_just_pressed("ui_accept"):  # Enter o Espacio
		generate_new_map()

func generate_new_map():
	current_seed = randi()
	var generator = ProceduralMapGenerator.new(12, 16, current_seed)
	map_data = generator.generate_map()
	
	Log.info("System", "========================================")
	Log.info("System", "Mapa generado con seed: %d" % current_seed)
	Log.info("System", "========================================")
	
	# Analizar y mostrar estadísticas
	_print_statistics()
	
	queue_redraw()

func _print_statistics():
	var terrain_counts = {}
	var elevation_counts = {}
	var min_elev = 999
	var max_elev = -999
	
	for pos in map_data.keys():
		var terrain = map_data[pos]["terrain"]
		var elevation = map_data[pos]["elevation"]
		
		# Contar terrenos
		terrain_counts[terrain] = terrain_counts.get(terrain, 0) + 1
		
		# Contar elevaciones
		elevation_counts[elevation] = elevation_counts.get(elevation, 0) + 1
		
		# Min/max elevación
		if elevation < min_elev:
			min_elev = elevation
		if elevation > max_elev:
			max_elev = elevation
	
	Log.info("System", "📊 Distribución de terrenos:")
	var terrain_names = {
		TerrainType.Type.CLEAR: "Clear (Despejado)",
		TerrainType.Type.LIGHT_WOODS: "Light Woods (Bosque Ligero)",
		TerrainType.Type.HEAVY_WOODS: "Heavy Woods (Bosque Denso)",
		TerrainType.Type.WATER: "Water (Agua)",
		TerrainType.Type.SAND: "Sand (Arena)",
		TerrainType.Type.ROUGH: "Rough (Difícil)",
		TerrainType.Type.HILL: "Hill (Colina)",
		TerrainType.Type.PAVEMENT: "Pavement (Pavimento)",
		TerrainType.Type.BUILDING: "Building (Edificio)",
		TerrainType.Type.ROAD: "Road (Carretera)"
	}
	
	for terrain in terrain_counts.keys():
		var count = terrain_counts[terrain]
		var percentage = float(count) / float(map_data.size()) * 100.0
		var terrain_name = terrain_names.get(terrain, "Unknown")
		Log.info("System", "  %s: %d hexes (%.1f%%)" % [terrain_name, count, percentage])
	
	Log.info("System", "🏔️ Distribución de elevaciones:")
	Log.info("System", "  Rango: %d a %d niveles" % [min_elev, max_elev])
	var sorted_elevations = elevation_counts.keys()
	sorted_elevations.sort()
	for elev in sorted_elevations:
		var count = elevation_counts[elev]
		var percentage = float(count) / float(map_data.size()) * 100.0
		Log.info("System", "  Nivel %+d: %d hexes (%.1f%%)" % [elev, count, percentage])
	
	# Validar transiciones
	var violations = _check_elevation_transitions()
	if violations.size() > 0:
		Log.warning("System", "⚠️ Advertencia: %d transiciones bruscas (≥4 niveles)" % violations.size())
	else:
		Log.info("System", "✅ Todas las transiciones de elevación son válidas (≤3 niveles)")

func _check_elevation_transitions() -> Array:
	var violations = []
	const HEX_DIRECTIONS = [
		Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, 0)
	]
	
	for pos in map_data.keys():
		var elev = map_data[pos]["elevation"]
		
		for direction in HEX_DIRECTIONS:
			var neighbor = pos + direction
			if not map_data.has(neighbor):
				continue
			
			var neigh_elev = map_data[neighbor]["elevation"]
			var diff = abs(elev - neigh_elev)
			
			if diff >= 4:
				violations.append([pos, neighbor, diff])
	
	return violations

func _draw():
	if map_data.is_empty():
		return
	
	# Dibujar cada hex
	for pos in map_data.keys():
		var terrain = map_data[pos]["terrain"]
		var elevation = map_data[pos]["elevation"]
		
		# Calcular posición en pantalla
		var pixel_pos = _hex_to_pixel(pos)
		
		# Offset por elevación (isométrico)
		pixel_pos.y -= elevation * 5.0
		
		# Color según terreno
		var color = TerrainType.get_color(terrain)
		
		# Ajustar brillo según elevación
		var brightness = 1.0 + (elevation * 0.1)
		color = color * brightness
		
		# Dibujar hexágono
		_draw_hex(pixel_pos, hex_size, color)
		
		# Dibujar elevación si != 0
		if elevation != 0:
			var elev_text = "%+d" % elevation
			var text_color = Color.YELLOW if elevation > 0 else Color.CYAN
			draw_string(ThemeDB.fallback_font, pixel_pos + Vector2(-5, 3), elev_text, 
						HORIZONTAL_ALIGNMENT_CENTER, -1, 10, text_color)
	
	# Instrucciones
	var instructions = "Presiona ENTER/ESPACIO para regenerar | ESC para salir | Seed: %d" % current_seed
	draw_string(ThemeDB.fallback_font, Vector2(10, 20), instructions, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _hex_to_pixel(hex: Vector2i) -> Vector2:
	var x = hex_size * (3.0/2.0 * hex.x)
	var y = hex_size * sqrt(3.0) * (hex.y + 0.5 * hex.x)
	return Vector2(x, y) + Vector2(50, 50)  # Offset para centrar

func _draw_hex(center: Vector2, size: float, color: Color):
	var points = PackedVector2Array()
	for i in range(6):
		var angle_deg = 60 * i
		var angle_rad = deg_to_rad(angle_deg)
		var x = center.x + size * cos(angle_rad)
		var y = center.y + size * sin(angle_rad)
		points.append(Vector2(x, y))
	
	draw_colored_polygon(points, color)
	
	# Borde
	for i in range(6):
		var p1 = points[i]
		var p2 = points[(i + 1) % 6]
		draw_line(p1, p2, Color.BLACK, 1.0)
