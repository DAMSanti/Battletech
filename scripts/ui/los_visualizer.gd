extends Node2D
class_name LoSVisualizer

## Visualizador de Line of Sight
## Dibuja líneas y marcadores mostrando la LoS entre dos hexes

var hex_grid = null
var from_hex: Vector2i = Vector2i.ZERO
var to_hex: Vector2i = Vector2i.ZERO
var los_visible: bool = false

func _ready():
	z_index = 100  # Encima de todo

func show_los(grid, from: Vector2i, to: Vector2i):
	hex_grid = grid
	from_hex = from
	to_hex = to
	los_visible = true
	queue_redraw()

func hide_los():
	los_visible = false
	queue_redraw()

func _draw():
	if not los_visible or hex_grid == null:
		return
	
	if from_hex == Vector2i.ZERO or to_hex == Vector2i.ZERO:
		return
	
	# Calcular LoS
	var los_data = LineOfSight.calculate_los(hex_grid, from_hex, to_hex)
	
	# Obtener posiciones en pantalla
	var from_pos = hex_grid.hex_to_pixel(from_hex, true) + hex_grid.position
	var to_pos = hex_grid.hex_to_pixel(to_hex, true) + hex_grid.position
	
	# Dibujar línea principal
	var line_color = Color.GREEN
	var line_width = 3.0
	
	if los_data.result == LineOfSight.Result.BLOCKED:
		line_color = Color.RED
	elif los_data.result == LineOfSight.Result.PARTIAL:
		line_color = Color.YELLOW
	
	draw_line(from_pos, to_pos, line_color, line_width, true)
	
	# Dibujar hexes bloqueantes
	for hex in los_data.blocking_hexes:
		var hex_pos = hex_grid.hex_to_pixel(hex, true) + hex_grid.position
		var radius = hex_grid.hex_size * 0.8
		
		# Dibujar hexágono resaltado
		var points = PackedVector2Array()
		for i in range(6):
			var angle = deg_to_rad(60 * i)
			var point = hex_pos + Vector2(cos(angle), sin(angle)) * radius
			points.append(point)
		
		# Color según tipo
		var fill_color = Color(1, 0, 0, 0.3) if los_data.result == LineOfSight.Result.BLOCKED else Color(1, 1, 0, 0.3)
		draw_colored_polygon(points, fill_color)
		
		# Borde
		for i in range(6):
			var p1 = points[i]
			var p2 = points[(i + 1) % 6]
			draw_line(p1, p2, line_color, 2.0, true)
	
	# Dibujar marcadores en los extremos
	draw_circle(from_pos, 8, Color.CYAN)
	draw_circle(to_pos, 8, line_color)
	
	# Dibujar texto descriptivo
	var text_pos = (from_pos + to_pos) / 2 + Vector2(0, -30)
	var text = ""
	
	match los_data.result:
		LineOfSight.Result.CLEAR:
			text = "CLEAR LoS"
		LineOfSight.Result.PARTIAL:
			text = "PARTIAL (+%d)" % los_data.to_hit_modifier
		LineOfSight.Result.BLOCKED:
			text = "BLOCKED"
	
	# Fondo para texto
	var font = ThemeDB.fallback_font
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	var bg_rect = Rect2(text_pos - Vector2(text_size.x / 2 + 5, text_size.y / 2 + 3), text_size + Vector2(10, 6))
	draw_rect(bg_rect, Color(0, 0, 0, 0.7))
	
	# Texto
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, line_color)
	
	# Info adicional debajo
	if not los_data.can_hit_all_locations:
		var info_pos = text_pos + Vector2(0, 25)
		draw_string(font, info_pos, "(Upper locations only)", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.YELLOW)
