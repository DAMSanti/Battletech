extends Node2D

# Referencia al battle_scene
var battle_scene = null

func _draw():
	if not battle_scene or not battle_scene.hex_grid:
		return
	
	var hex_grid = battle_scene.hex_grid
	
	# Dibujar zonas de despliegue si estamos en fase de despliegue
	if battle_scene.deployment_phase and battle_scene.valid_deployment_hexes.size() > 0:
		for hex in battle_scene.valid_deployment_hexes:
			var pixel = hex_grid.hex_to_pixel(hex, true) + hex_grid.position
			
			if hex_grid.get_unit(hex):
				_draw_hexagon(pixel, hex_grid.hex_size, Color(0.5, 0.5, 0.5, 0.2), Color.GRAY, 2.0)
			else:
				_draw_hexagon(pixel, hex_grid.hex_size, Color(0.2, 1.0, 0.2, 0.3), Color.GREEN, 3.0)
		return
	
	var reachable_hexes = battle_scene.reachable_hexes
	var target_hexes = battle_scene.target_hexes
	var physical_target_hexes = battle_scene.physical_target_hexes
	
	for hex in reachable_hexes:
		var pixel = hex_grid.hex_to_pixel(hex, true) + hex_grid.position
		_draw_hexagon(pixel, hex_grid.hex_size, Color(0.2, 0.5, 1.0, 0.4), Color.CYAN, 3.0)
	
	for hex in target_hexes:
		var pixel = hex_grid.hex_to_pixel(hex, true) + hex_grid.position
		_draw_hexagon(pixel, hex_grid.hex_size, Color(1.0, 0.2, 0.2, 0.4), Color.ORANGE_RED, 3.0)
	
	for hex in physical_target_hexes:
		var pixel = hex_grid.hex_to_pixel(hex, true) + hex_grid.position
		_draw_hexagon(pixel, hex_grid.hex_size, Color(1.0, 0.0, 1.0, 0.4), Color.MAGENTA, 3.0)

func _draw_hexagon(center: Vector2, size: float, fill_color: Color, border_color: Color, border_width: float):
	var points = PackedVector2Array()
	for i in range(6):
		var angle_deg = 60 * i
		var angle_rad = deg_to_rad(angle_deg)
		var point = center + Vector2(cos(angle_rad), sin(angle_rad)) * size
		points.append(point)
	
	if fill_color.a > 0:
		draw_colored_polygon(points, fill_color)
	
	for i in range(6):
		var p1 = points[i]
		var p2 = points[(i + 1) % 6]
		draw_line(p1, p2, border_color, border_width)
