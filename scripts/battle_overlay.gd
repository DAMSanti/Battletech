extends Node2D

# Referencia al battle_scene
var battle_scene = null

func _draw():
	if not battle_scene or not battle_scene.hex_grid:
		return
	
	var hex_grid = battle_scene.hex_grid
	var reachable_hexes = battle_scene.reachable_hexes
	var target_hexes = battle_scene.target_hexes
	var physical_target_hexes = battle_scene.physical_target_hexes
	
	
	# Dibujar hexágonos alcanzables (azul brillante)
	for hex in reachable_hexes:
		# hex_to_pixel ya da la posición local del hexágono dentro del grid
		# Necesitamos la posición global sumando la posición del grid
		var pixel = hex_grid.hex_to_pixel(hex) + hex_grid.position
		_draw_hexagon(pixel, hex_grid.hex_size, Color(0.2, 0.5, 1.0, 0.4), Color.CYAN, 3.0)
	
	# Dibujar hexágonos con objetivos (rojo brillante)
	for hex in target_hexes:
		var pixel = hex_grid.hex_to_pixel(hex) + hex_grid.position
		_draw_hexagon(pixel, hex_grid.hex_size, Color(1.0, 0.2, 0.2, 0.4), Color.ORANGE_RED, 3.0)
	
	# Dibujar hexágonos con objetivos físicos (magenta brillante)
	for hex in physical_target_hexes:
		var pixel = hex_grid.hex_to_pixel(hex) + hex_grid.position
		_draw_hexagon(pixel, hex_grid.hex_size, Color(1.0, 0.0, 1.0, 0.4), Color.MAGENTA, 3.0)

func _draw_hexagon(center: Vector2, size: float, fill_color: Color, border_color: Color, border_width: float):
	# Dibujar hexágono relleno
	var points = PackedVector2Array()
	for i in range(6):
		var angle_deg = 60 * i
		var angle_rad = deg_to_rad(angle_deg)
		var point = center + Vector2(cos(angle_rad), sin(angle_rad)) * size
		points.append(point)
	
	# Relleno
	if fill_color.a > 0:
		draw_colored_polygon(points, fill_color)
	
	# Borde
	for i in range(6):
		var p1 = points[i]
		var p2 = points[(i + 1) % 6]
		draw_line(p1, p2, border_color, border_width)
