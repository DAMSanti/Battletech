extends Node2D

# Referencia al battle_scene
var battle_scene = null

# DESACTIVADO: Ahora los overlays se renderizan con Polygon2D y oclusión
# en hex_surface_renderer.render_overlays()
# El código antiguo se mantiene comentado para referencia:

#func _draw():
#	if not battle_scene or not battle_scene.hex_grid:
#		return
#	
#	var hex_grid = battle_scene.hex_grid
#	
#	# Procesar hexes para deployment
#	if battle_scene.deployment_phase and battle_scene.valid_deployment_hexes.size() > 0:
#		for hex in battle_scene.valid_deployment_hexes:
#			var center = hex_grid.hex_to_pixel(hex, true) + hex_grid.position
#			
#			if hex_grid.get_unit(hex):
#				_draw_overlay_hex(center, hex_grid.hex_size, Color(0.5, 0.5, 0.5, 0.3), Color.GRAY, 2.0)
#			else:
#				_draw_overlay_hex(center, hex_grid.hex_size, Color(0.2, 1.0, 0.2, 0.4), Color.GREEN, 3.0)
#	else:
#		# Dibujar movimiento/ataque
#		for hex in battle_scene.reachable_hexes:
#			var center = hex_grid.hex_to_pixel(hex, true) + hex_grid.position
#			_draw_overlay_hex(center, hex_grid.hex_size, Color(0.2, 0.5, 1.0, 0.4), Color.CYAN, 3.0)
#		
#		for hex in battle_scene.target_hexes:
#			var center = hex_grid.hex_to_pixel(hex, true) + hex_grid.position
#			_draw_overlay_hex(center, hex_grid.hex_size, Color(1.0, 0.2, 0.2, 0.4), Color.ORANGE_RED, 3.0)
#		
#		for hex in battle_scene.physical_target_hexes:
#			var center = hex_grid.hex_to_pixel(hex, true) + hex_grid.position
#			_draw_overlay_hex(center, hex_grid.hex_size, Color(1.0, 0.0, 1.0, 0.4), Color.MAGENTA, 3.0)

func _draw_overlay_hex(center: Vector2, size: float, fill_color: Color, border_color: Color, border_width: float):
	# Crear puntos del hexágono
	var points = PackedVector2Array()
	for i in range(6):
		var angle_deg = 60 * i
		var angle_rad = deg_to_rad(angle_deg)
		var point = center + Vector2(cos(angle_rad), sin(angle_rad)) * size
		points.append(point)
	
	# Dibujar relleno semi-transparente
	if fill_color.a > 0:
		draw_colored_polygon(points, fill_color)
	
	# Dibujar borde
	for i in range(6):
		var p1 = points[i]
		var p2 = points[(i + 1) % 6]
		draw_line(p1, p2, border_color, border_width, true)
