# ============================================================
# BATTLE CAMERA CONTROLLER
# Maneja input de cámara, touch, zoom y detección de clicks
# ============================================================
class_name BattleCameraController
extends Node

## Señales
signal hex_clicked(hex: Vector2i)
signal long_press_started(hex: Vector2i)
signal long_press_completed(hex: Vector2i)
signal camera_moved()

## Referencias
var camera: Camera2D = null
var hex_grid = null  # Referencia al HexGrid para convertir posiciones
var ui_root: Control = null  # Referencia a la UI para detectar clicks sobre ella

## Configuración de cámara
const MIN_ZOOM: float = 0.3
const MAX_ZOOM: float = 2.0
const CAMERA_SMOOTH_SPEED: float = 10.0

## Configuración de touch
const TOUCH_MOVE_THRESHOLD: float = 15.0  # Píxeles para considerar movimiento
const LONG_PRESS_DURATION: float = 0.5  # Segundos para tap largo
const HEX_CLICK_DEBOUNCE_MS: int = 150  # Tiempo mínimo entre clicks
const IGNORE_CLICK_DEBOUNCE_MS: int = 200  # Tiempo para ignorar clicks tras UI

## Estado de cámara
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var camera_start_pos: Vector2 = Vector2.ZERO
var touch_points: Dictionary = {}  # ID del toque -> posición
var initial_pinch_distance: float = 0.0
var initial_zoom: Vector2 = Vector2.ONE

## Estado de detección de tap vs drag
var touch_start_positions: Dictionary = {}  # ID del toque -> posición inicial
var has_moved_significantly: bool = false  # True si se movió más del umbral

## Estado de long press
var long_press_timer: float = 0.0
var long_press_start_pos: Vector2 = Vector2.ZERO
var long_press_start_hex: Vector2i = Vector2i(-1, -1)
var long_press_active: bool = false

## Estado de debounce
var ignore_next_click: bool = false
var ignore_until_time: int = 0
var _last_hex_click_time: int = 0
var _last_click_frame: int = -1

## Referencia al FacingSelector para excluirlo de detección UI
var _facing_selector = null


func _ready() -> void:
	set_process(true)


func initialize(p_camera: Camera2D, p_hex_grid, p_ui_root: Control = null) -> void:
	"""Inicializa el controlador con las referencias necesarias"""
	camera = p_camera
	hex_grid = p_hex_grid
	ui_root = p_ui_root
	
	Log.debug("System", "BattleCameraController initialized")


func set_facing_selector(facing_selector) -> void:
	"""Establece referencia al FacingSelector para excluirlo de detección UI"""
	_facing_selector = facing_selector


func _process(delta: float) -> void:
	_update_long_press(delta)


# ============================================================
# PROCESAMIENTO DE INPUT
# ============================================================

func handle_input(event: InputEvent) -> bool:
	"""Procesa un evento de input. Retorna true si fue consumido."""
	
	# Primero intentar procesar como gesto de cámara
	if _handle_camera_gesture(event):
		return true
	
	# Si no es gesto de cámara, verificar si es click/tap
	if _is_tap_event(event):
		return _handle_tap(event)
	
	return false


func _handle_camera_gesture(event: InputEvent) -> bool:
	"""Procesa gestos de cámara (drag, pinch, zoom). Retorna true si fue procesado."""
	
	if camera == null:
		return false
	
	# Gestos táctiles
	if event is InputEventScreenTouch:
		return _handle_screen_touch(event)
	
	# Movimiento táctil
	if event is InputEventScreenDrag:
		return _handle_screen_drag(event)
	
	# Soporte de mouse para testing en PC
	if event is InputEventMouseButton:
		return _handle_mouse_button(event)
	
	if event is InputEventMouseMotion and is_dragging:
		return _handle_mouse_drag(event)
	
	return false


func _handle_screen_touch(event: InputEventScreenTouch) -> bool:
	"""Maneja eventos de toque en pantalla"""
	if event.pressed:
		# Nuevo toque
		touch_points[event.index] = event.position
		touch_start_positions[event.index] = event.position
		
		if touch_points.size() == 1:
			# Un dedo: iniciar arrastre
			is_dragging = true
			drag_start_pos = event.position
			camera_start_pos = camera.position
			
			# Iniciar detección de long press
			_start_long_press_detection(event.position)
			
		elif touch_points.size() == 2:
			# Dos dedos: iniciar zoom con pellizco
			is_dragging = false
			_cancel_long_press()
			var points = touch_points.values()
			initial_pinch_distance = points[0].distance_to(points[1])
			initial_zoom = camera.zoom
	else:
		# Soltar toque
		touch_points.erase(event.index)
		touch_start_positions.erase(event.index)
		
		if touch_points.size() == 0:
			is_dragging = false
			_cancel_long_press()
		elif touch_points.size() == 1:
			# Volver a modo arrastre con el dedo restante
			is_dragging = true
			var remaining_point = touch_points.values()[0]
			drag_start_pos = remaining_point
			camera_start_pos = camera.position
	
	return touch_points.size() > 0


func _handle_screen_drag(event: InputEventScreenDrag) -> bool:
	"""Maneja el arrastre de pantalla táctil"""
	touch_points[event.index] = event.position
	
	if touch_points.size() == 1 and is_dragging:
		# Arrastrar cámara con un dedo
		var drag_delta = (drag_start_pos - event.position) / camera.zoom.x
		camera.position = camera_start_pos + drag_delta
		has_moved_significantly = true
		_cancel_long_press()
		camera_moved.emit()
		return true
		
	elif touch_points.size() == 2:
		# Zoom con pellizco (pinch)
		has_moved_significantly = true
		_cancel_long_press()
		var points = touch_points.values()
		var current_distance = points[0].distance_to(points[1])
		var zoom_factor = current_distance / initial_pinch_distance
		
		# Calcular nuevo zoom
		var new_zoom = initial_zoom * zoom_factor
		new_zoom.x = clamp(new_zoom.x, MIN_ZOOM, MAX_ZOOM)
		new_zoom.y = clamp(new_zoom.y, MIN_ZOOM, MAX_ZOOM)
		camera.zoom = new_zoom
		camera_moved.emit()
		return true
	
	return false


func _handle_mouse_button(event: InputEventMouseButton) -> bool:
	"""Maneja eventos de botón de mouse"""
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			is_dragging = true
			drag_start_pos = event.position
			camera_start_pos = camera.position
		else:
			is_dragging = false
		return true
		
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.zoom *= 1.1
		camera.zoom.x = clamp(camera.zoom.x, MIN_ZOOM, MAX_ZOOM)
		camera.zoom.y = clamp(camera.zoom.y, MIN_ZOOM, MAX_ZOOM)
		has_moved_significantly = true
		camera_moved.emit()
		return true
		
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.zoom *= 0.9
		camera.zoom.x = clamp(camera.zoom.x, MIN_ZOOM, MAX_ZOOM)
		camera.zoom.y = clamp(camera.zoom.y, MIN_ZOOM, MAX_ZOOM)
		has_moved_significantly = true
		camera_moved.emit()
		return true
	
	return false


func _handle_mouse_drag(event: InputEventMouseMotion) -> bool:
	"""Maneja el arrastre con mouse"""
	var drag_delta = (drag_start_pos - event.position) / camera.zoom.x
	camera.position = camera_start_pos + drag_delta
	has_moved_significantly = true
	camera_moved.emit()
	return true


# ============================================================
# DETECCIÓN DE TAP/CLICK
# ============================================================

func _is_tap_event(event: InputEvent) -> bool:
	"""Verifica si el evento es un tap/click (no un gesto de cámara)"""
	if event is InputEventScreenTouch:
		return not event.pressed and not has_moved_significantly
	
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not has_moved_significantly
	
	return false


func _handle_tap(event: InputEvent) -> bool:
	"""Procesa un tap/click y emite señal si es válido"""
	var screen_pos = event.position
	
	# Verificar debounce
	if not _check_debounce():
		return true  # Consumir evento pero no procesar
	
	# Verificar si está sobre UI
	if is_click_over_ui(screen_pos):
		return true  # Consumir para evitar que pase al mapa
	
	# Convertir a coordenadas de hex
	var hex = _screen_to_hex(screen_pos)
	if hex != Vector2i(-1, -1):
		_last_hex_click_time = Time.get_ticks_msec()
		hex_clicked.emit(hex)
		return true
	
	return false


func _check_debounce() -> bool:
	"""Verifica si el click debe ser ignorado por debounce"""
	var current_time = Time.get_ticks_msec()
	var current_frame = Engine.get_process_frames()
	
	# Evitar doble procesamiento en el mismo frame
	if current_frame == _last_click_frame:
		return false
	_last_click_frame = current_frame
	
	# Verificar debounce de tiempo
	if current_time - _last_hex_click_time < HEX_CLICK_DEBOUNCE_MS:
		return false
	
	# Verificar ignore temporal
	if ignore_next_click:
		return false
	
	if current_time < ignore_until_time:
		return false
	
	return true


func _screen_to_hex(screen_pos: Vector2) -> Vector2i:
	"""Convierte posición de pantalla a coordenadas hex"""
	if hex_grid == null or camera == null:
		return Vector2i(-1, -1)
	
	var world_pos = camera.get_canvas_transform().affine_inverse() * screen_pos
	return hex_grid.world_to_hex(world_pos)


# ============================================================
# DETECCIÓN DE UI
# ============================================================

func is_click_over_ui(screen_pos: Vector2) -> bool:
	"""Verifica si la posición de pantalla está sobre un control de UI interactivo"""
	if ui_root == null:
		return false
	
	# Verificar primero si está sobre el panel de log (tiene prioridad)
	if ui_root.has_method("is_mouse_over_log_panel") and ui_root.is_mouse_over_log_panel():
		Log.debug("Input", "Click blocked - over log panel")
		return true
	
	# Verificar si está sobre los paneles de selección de ataque
	if ui_root.has_method("is_point_over_attack_panels") and ui_root.is_point_over_attack_panels(screen_pos):
		Log.debug("Input", "Click blocked - over attack panel")
		return true
	
	# Buscar botones visibles en la UI
	var buttons = _get_visible_buttons(ui_root)
	for button in buttons:
		var rect = button.get_global_rect()
		if rect.has_point(screen_pos):
			Log.debug("Input", "Click blocked - over button: %s at %s" % [button.text if button.text else button.name, rect])
			return true
	
	return false


func _get_visible_buttons(node: Node) -> Array:
	"""Obtiene recursivamente todos los botones realmente visibles"""
	var buttons = []
	
	# No buscar botones dentro del facing_selector
	if node.name == "FacingSelector" or node.get_class() == "FacingSelector":
		return buttons
	if _facing_selector and node == _facing_selector:
		return buttons
	if node.get_script() and node.get_script().resource_path.ends_with("facing_selector.gd"):
		return buttons
	
	if node is Button:
		if _is_truly_visible(node):
			buttons.append(node)
	
	for child in node.get_children():
		buttons.append_array(_get_visible_buttons(child))
	
	return buttons


func _is_truly_visible(node: Node) -> bool:
	"""Verifica si un nodo y todos sus ancestros están visibles"""
	if node is CanvasItem:
		if not node.visible:
			return false
	if node.get_parent():
		return _is_truly_visible(node.get_parent())
	return true


# ============================================================
# SISTEMA DE LONG PRESS
# ============================================================

func _start_long_press_detection(screen_pos: Vector2) -> void:
	"""Inicia la detección de long press"""
	long_press_start_pos = screen_pos
	long_press_timer = 0.0
	long_press_active = true
	
	# Calcular hex inicial
	long_press_start_hex = _screen_to_hex(screen_pos)
	
	if long_press_start_hex != Vector2i(-1, -1):
		long_press_started.emit(long_press_start_hex)


func _cancel_long_press() -> void:
	"""Cancela la detección de long press"""
	long_press_active = false
	long_press_timer = 0.0


func _update_long_press(delta: float) -> void:
	"""Actualiza el temporizador de long press"""
	if not long_press_active:
		return
	
	long_press_timer += delta
	
	if long_press_timer >= LONG_PRESS_DURATION:
		# Long press completado
		if long_press_start_hex != Vector2i(-1, -1):
			long_press_completed.emit(long_press_start_hex)
		_cancel_long_press()


func get_long_press_progress() -> float:
	"""Retorna el progreso del long press (0.0 a 1.0)"""
	if not long_press_active:
		return 0.0
	return clamp(long_press_timer / LONG_PRESS_DURATION, 0.0, 1.0)


func is_long_press_active() -> bool:
	"""Retorna si hay un long press en progreso"""
	return long_press_active


# ============================================================
# CONTROL DE DEBOUNCE
# ============================================================

func start_ignore_click_timer(duration_ms: int = IGNORE_CLICK_DEBOUNCE_MS) -> void:
	"""Ignora clicks durante duration_ms milisegundos"""
	ignore_next_click = true
	ignore_until_time = Time.get_ticks_msec() + duration_ms
	
	# Timer asíncrono para limpiar el flag
	await get_tree().create_timer(duration_ms / 1000.0).timeout
	ignore_next_click = false


func reset_movement_flag() -> void:
	"""Resetea el flag de movimiento significativo"""
	has_moved_significantly = false


func did_move_significantly() -> bool:
	"""Retorna si hubo movimiento significativo desde el último reset"""
	return has_moved_significantly


# ============================================================
# CONTROL DE CÁMARA
# ============================================================

func center_on_hex(hex: Vector2i, smooth: bool = true) -> void:
	"""Centra la cámara en un hex específico"""
	if camera == null or hex_grid == null:
		return
	
	var world_pos = hex_grid.hex_to_world(hex)
	
	if smooth:
		# TODO: Implementar movimiento suave con tween
		camera.position = world_pos
	else:
		camera.position = world_pos


func pan_to_position(world_pos: Vector2, smooth: bool = true) -> void:
	"""Mueve la cámara suavemente a una posición del mundo"""
	if camera == null:
		return
	
	if smooth:
		# Crear tween para movimiento suave
		var tween = camera.create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(camera, "position", world_pos, 0.4)
	else:
		camera.position = world_pos
	
	camera_moved.emit()


func set_zoom(zoom_level: float, smooth: bool = false) -> void:
	"""Establece el nivel de zoom"""
	if camera == null:
		return
	
	zoom_level = clamp(zoom_level, MIN_ZOOM, MAX_ZOOM)
	
	if smooth:
		# TODO: Implementar zoom suave con tween
		camera.zoom = Vector2(zoom_level, zoom_level)
	else:
		camera.zoom = Vector2(zoom_level, zoom_level)


func get_zoom() -> float:
	"""Retorna el nivel de zoom actual"""
	if camera == null:
		return 1.0
	return camera.zoom.x
