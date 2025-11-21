extends Control

## Selector de orientación (facing) hexagonal
## Permite al jugador elegir una de las 6 direcciones

signal facing_selected(facing: int)

var hex_buttons: Array = []
var center_pos: Vector2
const RADIUS = 80.0  # Radio del círculo de botones
var current_facing: int = -1
var available_mp: int = 99
var background_panel: Panel

func _ready():
	# Ocultar por defecto
	visible = false
	
	# Hacer que el control sea "modal" - bloquea inputs a otros elementos
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Crear panel de fondo para bloquear clics y dar contexto visual
	background_panel = Panel.new()
	background_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Crear un StyleBox semi-transparente
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)  # Negro semi-transparente
	style.border_color = Color(1, 1, 1, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	background_panel.add_theme_stylebox_override("panel", style)
	
	add_child(background_panel)
	
	# Calcular centro del control
	center_pos = size / 2
	
	# Crear 6 botones en forma de hexágono
	for i in range(6):
		var button = Button.new()
		button.text = _get_direction_name(i)
		button.custom_minimum_size = Vector2(80, 50)  # Más grande para evitar misclicks
		
		# Calcular posición del botón
		var angle_deg = 60 * i - 90  # -90 para que 0 esté arriba (norte)
		var angle_rad = deg_to_rad(angle_deg)
		var pos = center_pos + Vector2(cos(angle_rad), sin(angle_rad)) * RADIUS
		
		# Centrar el botón en su posición
		button.position = pos - button.custom_minimum_size / 2
		
		# Conectar señal
		var facing_index = i
		button.pressed.connect(func(): _on_facing_button_pressed(facing_index))
		
		add_child(button)
		hex_buttons.append(button)
	
	# Añadir botón de confirmar en el centro (para mantener facing actual)
	var confirm_button = Button.new()
	confirm_button.text = "OK"
	confirm_button.custom_minimum_size = Vector2(70, 40)
	confirm_button.position = center_pos - confirm_button.custom_minimum_size / 2
	confirm_button.pressed.connect(_on_confirm_pressed)
	add_child(confirm_button)

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
	"""Muestra el selector en una posición específica"""
	position = pos - size / 2
	current_facing = facing
	available_mp = mp
	_update_buttons()
	visible = true

func _update_buttons():
	"""Actualiza el estado de los botones según MPs disponibles y facing actual"""
	for i in range(hex_buttons.size()):
		var button = hex_buttons[i]
		
		# Calcular coste de rotación a este facing
		var cost = _calculate_rotation_cost(current_facing, i)
		
		# Deshabilitar si no hay suficientes MPs
		button.disabled = (cost > available_mp)
		
		# Actualizar texto con coste
		var dir_name = _get_direction_name(i)
		if i == current_facing:
			button.text = "%s\n(Current)" % dir_name
			button.modulate = Color(0.5, 1.0, 0.5)  # Verde para actual
		elif cost > available_mp:
			button.text = "%s\n(%d MP)" % [dir_name, cost]
			button.modulate = Color(0.5, 0.5, 0.5)  # Gris para deshabilitado
		elif cost == 0:
			button.text = "%s\n(Free)" % dir_name
			button.modulate = Color.WHITE
		else:
			button.text = "%s\n(%d MP)" % [dir_name, cost]
			button.modulate = Color.WHITE

func _calculate_rotation_cost(from_facing: int, to_facing: int) -> int:
	"""Calcula el coste en MPs de rotar de una dirección a otra"""
	if from_facing < 0:
		return 0  # En despliegue, no hay coste
	
	var diff = (to_facing - from_facing + 6) % 6
	var clockwise = diff
	var counter_clockwise = 6 - diff
	
	return min(clockwise, counter_clockwise)

func _on_facing_button_pressed(facing: int):
	print("[FACING_SELECTOR] Selected facing: %d" % facing)
	facing_selected.emit(facing)
	visible = false

func _on_confirm_pressed():
	"""Confirma el facing actual (no cambiar)"""
	print("[FACING_SELECTOR] Confirmed current facing")
	if current_facing >= 0:
		facing_selected.emit(current_facing)
	visible = false
