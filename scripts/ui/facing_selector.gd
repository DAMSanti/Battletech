extends Control

## Selector de orientación (facing) hexagonal
## Permite al jugador elegir una de las 6 direcciones

signal facing_selected(facing: int)

var hex_buttons: Array = []
var center_pos: Vector2
const RADIUS = 70.0  # Radio del círculo de botones (reducido para juntar más)
var current_facing: int = -1
var available_mp: int = 99
var background_panel: Panel
var title_label: Label
var info_label: Label
var target_hex: Vector2i = Vector2i(-1, -1)  # Hex al que está anclado el diálogo
var battle_scene = null  # Referencia a la escena de batalla para obtener posición del hex

func _ready():
	# Ocultar por defecto
	visible = false
	
	# NO hacer que el control sea modal - queremos que la cámara siga funcionando
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Posicionar en top-left para usar coordenadas absolutas
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	
	# Crear panel de fondo (solo detrás del diálogo, no fullscreen)
	background_panel = Panel.new()
	background_panel.custom_minimum_size = Vector2(300, 300)
	background_panel.size = Vector2(300, 300)
	background_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Estilo del panel principal - diseño terminal militar
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.7)  # Azul oscuro más transparente
	style.border_color = Color(0.3, 0.6, 1.0, 1.0)  # Cyan brillante
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_size = 10
	style.shadow_color = Color(0, 0, 0, 0.5)
	background_panel.add_theme_stylebox_override("panel", style)
	
	add_child(background_panel)
	
	# Título
	title_label = Label.new()
	title_label.text = "⚙ SELECT FACING ⚙"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 10)
	title_label.size = Vector2(300, 25)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))  # Cyan
	background_panel.add_child(title_label)
	
	# Info label (MPs disponibles)
	info_label = Label.new()
	info_label.text = "Available MPs: --"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.position = Vector2(0, 35)
	info_label.size = Vector2(300, 20)
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))  # Naranja
	background_panel.add_child(info_label)
	
	# Calcular centro del panel
	center_pos = Vector2(150, 160)  # Centro del panel de 300x300, offset por título
	
	# Crear 6 botones en forma de hexágono con estilo BattleTech
	for i in range(6):
		# Crear contenedor para el botón de dirección
		var button_container = Control.new()
		button_container.custom_minimum_size = Vector2(90, 55)
		
		# Calcular posición del botón
		var angle_deg = 60 * i - 90  # -90 para que 0 esté arriba (norte)
		var angle_rad = deg_to_rad(angle_deg)
		var pos = center_pos + Vector2(cos(angle_rad), sin(angle_rad)) * RADIUS
		button_container.position = pos - button_container.custom_minimum_size / 2
		
		# Crear botón invisible para detectar clics
		var button = Button.new()
		button.custom_minimum_size = Vector2(90, 55)
		button.flat = true
		button.modulate = Color(1, 1, 1, 0.01)  # Casi invisible pero clickeable
		
		# Crear flecha visual usando Polygon2D
		# La flecha debe apuntar en la dirección del facing (hacia donde mirará el mech)
		# Facing 0 = N (arriba), 1 = NE, 2 = SE, 3 = S (abajo), 4 = SW, 5 = NW
		var arrow = Polygon2D.new()
		var arrow_angle = 60 * i  # 0° = Norte (arriba), 60° = NE, etc.
		var arrow_points = _create_arrow_shape(arrow_angle)
		arrow.polygon = arrow_points
		arrow.color = Color(0.3, 0.6, 1.0, 0.9)  # Cyan
		arrow.position = Vector2(45, 27.5)  # Centro del botón
		
		# Añadir borde a la flecha
		var arrow_border = Line2D.new()
		var border_points = arrow_points.duplicate()
		border_points.append(arrow_points[0])  # Cerrar el polígono
		arrow_border.points = border_points
		arrow_border.default_color = Color(0.5, 0.8, 1.0, 1.0)
		arrow_border.width = 2
		arrow_border.position = Vector2(45, 27.5)
		
		# Label para mostrar info (MPs, etc)
		var info_label_btn = Label.new()
		info_label_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label_btn.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		info_label_btn.position = Vector2(0, 35)
		info_label_btn.size = Vector2(90, 20)
		info_label_btn.add_theme_font_size_override("font_size", 12)
		info_label_btn.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		
		button_container.add_child(arrow)
		button_container.add_child(arrow_border)
		button_container.add_child(info_label_btn)
		button_container.add_child(button)
		
		# Conectar señal
		var facing_index = i
		button.pressed.connect(func(): _on_facing_button_pressed(facing_index))
		button.mouse_entered.connect(func(): _on_arrow_hover(arrow, arrow_border, true))
		button.mouse_exited.connect(func(): _on_arrow_hover(arrow, arrow_border, false))
		
		background_panel.add_child(button_container)
		hex_buttons.append({"button": button, "arrow": arrow, "border": arrow_border, "label": info_label_btn, "container": button_container})
	
	# Botón de cancelar en el centro con forma de X
	var cancel_container = Control.new()
	cancel_container.custom_minimum_size = Vector2(60, 60)
	cancel_container.position = center_pos - Vector2(30, 30)
	
	var cancel_button = Button.new()
	cancel_button.custom_minimum_size = Vector2(60, 60)
	cancel_button.flat = true
	cancel_button.modulate = Color(1, 1, 1, 0.01)
	
	# Crear X usando dos Line2D
	var x_line1 = Line2D.new()
	x_line1.points = PackedVector2Array([Vector2(15, 15), Vector2(45, 45)])
	x_line1.default_color = Color(1.0, 0.3, 0.3, 0.9)  # Rojo
	x_line1.width = 4
	
	var x_line2 = Line2D.new()
	x_line2.points = PackedVector2Array([Vector2(45, 15), Vector2(15, 45)])
	x_line2.default_color = Color(1.0, 0.3, 0.3, 0.9)  # Rojo
	x_line2.width = 4
	
	# Círculo de fondo para la X
	var x_circle = Polygon2D.new()
	var circle_points = PackedVector2Array()
	for angle_i in range(32):
		var circle_angle = deg_to_rad(angle_i * 360.0 / 32)
		circle_points.append(Vector2(30, 30) + Vector2(cos(circle_angle), sin(circle_angle)) * 25)
	x_circle.polygon = circle_points
	x_circle.color = Color(0.2, 0.05, 0.05, 0.9)  # Rojo oscuro
	
	# Borde del círculo
	var circle_border = Line2D.new()
	var border_circle_points = circle_points.duplicate()
	border_circle_points.append(circle_points[0])
	circle_border.points = border_circle_points
	circle_border.default_color = Color(1.0, 0.4, 0.4, 1.0)
	circle_border.width = 2
	
	cancel_container.add_child(x_circle)
	cancel_container.add_child(circle_border)
	cancel_container.add_child(x_line1)
	cancel_container.add_child(x_line2)
	cancel_container.add_child(cancel_button)
	
	cancel_button.pressed.connect(_on_cancel_pressed)
	cancel_button.mouse_entered.connect(func(): _on_x_hover(x_line1, x_line2, circle_border, true))
	cancel_button.mouse_exited.connect(func(): _on_x_hover(x_line1, x_line2, circle_border, false))
	
	background_panel.add_child(cancel_container)

func _create_arrow_shape(rotation_deg: float) -> PackedVector2Array:
	"""Crea una forma de flecha apuntando hacia arriba, rotada según rotation_deg"""
	# Flecha básica apuntando arriba
	var points = PackedVector2Array([
		Vector2(0, -20),      # Punta
		Vector2(12, -8),      # Derecha punta
		Vector2(6, -8),       # Derecha cuello
		Vector2(6, 10),       # Derecha base
		Vector2(-6, 10),      # Izquierda base
		Vector2(-6, -8),      # Izquierda cuello
		Vector2(-12, -8)      # Izquierda punta
	])
	
	# Rotar puntos
	var rad = deg_to_rad(rotation_deg)
	var rotated = PackedVector2Array()
	for p in points:
		var x = p.x * cos(rad) - p.y * sin(rad)
		var y = p.x * sin(rad) + p.y * cos(rad)
		rotated.append(Vector2(x, y))
	
	return rotated

func _on_arrow_hover(arrow: Polygon2D, border: Line2D, is_hovering: bool):
	"""Feedback visual al pasar el mouse sobre una flecha"""
	if is_hovering:
		arrow.color = Color(0.4, 0.7, 1.0, 1.0)  # Más brillante
		border.default_color = Color(0.6, 0.9, 1.0, 1.0)
		border.width = 3
	else:
		arrow.color = Color(0.3, 0.6, 1.0, 0.9)
		border.default_color = Color(0.5, 0.8, 1.0, 1.0)
		border.width = 2

func _on_x_hover(line1: Line2D, line2: Line2D, border: Line2D, is_hovering: bool):
	"""Feedback visual al pasar el mouse sobre la X"""
	if is_hovering:
		line1.default_color = Color(1.0, 0.5, 0.5, 1.0)
		line2.default_color = Color(1.0, 0.5, 0.5, 1.0)
		border.default_color = Color(1.0, 0.6, 0.6, 1.0)
		border.width = 3
	else:
		line1.default_color = Color(1.0, 0.3, 0.3, 0.9)
		line2.default_color = Color(1.0, 0.3, 0.3, 0.9)
		border.default_color = Color(1.0, 0.4, 0.4, 1.0)
		border.width = 2

func _get_direction_name(facing: int) -> String:
	match facing:
		0: return "N"
		1: return "NE"
		2: return "SE"
		3: return "S"
		4: return "SW"
		5: return "NW"
	return "?"

func show_at_position(pos: Vector2, facing: int = -1, mp: int = 99):
	"""Muestra el selector anclado a la posición del click, siguiendo la cámara"""
	current_facing = facing
	available_mp = mp
	
	# Actualizar info label
	if mp >= 99:
		info_label.text = "Deployment - No MP cost"
		info_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # Verde
	else:
		info_label.text = "Available MPs: %d" % mp
		info_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))  # Naranja
	
	# Posicionar inicialmente
	_update_panel_position(pos)
	
	_update_buttons()
	visible = true

func _process(_delta):
	"""Actualizar posición cada frame para seguir el hex cuando la cámara se mueve"""
	if visible and battle_scene and target_hex != Vector2i(-1, -1):
		# Obtener posición actual del hex en pantalla
		if battle_scene.has_method("get_screen_position_for_hex"):
			var screen_pos = battle_scene.get_screen_position_for_hex(target_hex)
			_update_panel_position(screen_pos)

func _update_panel_position(pos: Vector2):
	"""Actualiza la posición del panel centrado en pos"""
	var viewport_size = get_viewport_rect().size
	var target_pos = pos - Vector2(150, 150)  # Centrar el panel de 300x300
	
	# Ajustar para que esté completamente visible
	var margin = 10.0
	
	if target_pos.x < margin:
		target_pos.x = margin
	elif target_pos.x + 300 > viewport_size.x - margin:
		target_pos.x = viewport_size.x - 300 - margin
	
	if target_pos.y < margin:
		target_pos.y = margin
	elif target_pos.y + 300 > viewport_size.y - margin:
		target_pos.y = viewport_size.y - 300 - margin
	
	background_panel.position = target_pos

func set_target_hex(hex: Vector2i, scene):
	"""Establece el hex objetivo y la referencia a la escena"""
	target_hex = hex
	battle_scene = scene

func _update_buttons():
	"""Actualiza el estado de los botones según MPs disponibles y facing actual"""
	for i in range(hex_buttons.size()):
		var btn_data = hex_buttons[i]
		var button = btn_data["button"]
		var arrow = btn_data["arrow"]
		var border = btn_data["border"]
		var label = btn_data["label"]
		var container = btn_data["container"]
		
		# Calcular coste de rotación a este facing
		var cost = _calculate_rotation_cost(current_facing, i)
		
		# Deshabilitar si no hay suficientes MPs
		button.disabled = (cost > available_mp)
		
		# Actualizar visual según estado
		if i == current_facing:
			label.text = "CURRENT"
			label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			arrow.color = Color(0.3, 1.0, 0.3, 1.0)  # Verde brillante
			border.default_color = Color(0.5, 1.0, 0.5, 1.0)
			border.width = 3
		elif cost > available_mp:
			label.text = "✗ %d MP" % cost
			label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			arrow.color = Color(0.2, 0.2, 0.2, 0.5)  # Gris oscuro
			border.default_color = Color(0.3, 0.3, 0.3, 0.5)
			border.width = 2
			container.modulate = Color(0.6, 0.6, 0.6)
		elif cost == 0:
			label.text = "FREE"
			label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			arrow.color = Color(0.3, 0.6, 1.0, 0.9)
			border.default_color = Color(0.5, 0.8, 1.0, 1.0)
			border.width = 2
			container.modulate = Color(1.0, 1.0, 1.0)
		else:
			label.text = "%d MP" % cost
			label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			arrow.color = Color(0.3, 0.6, 1.0, 0.9)
			border.default_color = Color(0.5, 0.8, 1.0, 1.0)
			border.width = 2
			container.modulate = Color(1.0, 1.0, 1.0)

func _calculate_rotation_cost(from_facing: int, to_facing: int) -> int:
	"""Calcula el coste en MPs de rotar de una dirección a otra"""
	if from_facing < 0:
		return 0  # En despliegue, no hay coste
	
	var diff = (to_facing - from_facing + 6) % 6
	var clockwise = diff
	var counter_clockwise = 6 - diff
	
	return min(clockwise, counter_clockwise)

func _on_facing_button_pressed(facing: int):
	# print("[FACING_SELECTOR] Selected facing: %d" % facing)
	facing_selected.emit(facing)
	visible = false

func _on_cancel_pressed():
	"""Cancela la selección de facing"""
	visible = false

func _on_confirm_pressed():
	"""Confirma el facing actual (no cambiar)"""
	print("[FACING_SELECTOR] Confirmed current facing")
	if current_facing >= 0:
		facing_selected.emit(current_facing)
	visible = false
