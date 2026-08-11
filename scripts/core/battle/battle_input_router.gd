## BattleInputRouter - Enruta input según el estado del juego
## Responsabilidades:
## - Procesar eventos de input (touch/mouse)
## - Determinar el destino del input según el estado actual
## - Manejar gestos de cámara (pan, zoom, pinch)
## - Gestionar long press y click detection
## - Verificar si el input está sobre UI
##
## NOTA: Este componente replica exactamente el comportamiento del código
## legacy en battle_scene.gd para garantizar compatibilidad
class_name BattleInputRouter
extends RefCounted

# ==============================================================================
# SIGNALS
# ==============================================================================
signal hex_clicked(hex: Vector2i)
signal hex_long_pressed(hex: Vector2i)
@warning_ignore("unused_signal")
signal camera_pan_started
@warning_ignore("unused_signal")
signal camera_pan_ended
signal movement_flag_reset_requested
@warning_ignore("unused_signal")
signal movement_gesture_detected  # Para compatibilidad con BattleComponentsIntegrator

# ==============================================================================
# CONSTANTS
# ==============================================================================
const LONG_PRESS_DURATION: float = 0.5
const LONG_PRESS_VISUAL_DELAY: float = 0.15  # Delay antes de mostrar animación visual
const TOUCH_MOVE_THRESHOLD: float = 15.0  # Igual que legacy
const MIN_ZOOM: float = 0.3
const MAX_ZOOM: float = 2.0

# ==============================================================================
# REFERENCIAS EXTERNAS
# ==============================================================================
var hex_grid: HexGrid = null
var camera: Camera2D = null
var ui: Node = null  # CanvasLayer, no Control

# ==============================================================================
# ESTADO DE TOUCH/MOUSE
# ==============================================================================
var touch_points: Dictionary = {}  # index -> position
var touch_start_positions: Dictionary = {}  # index -> posición inicial (para detectar drags)
var is_dragging: bool = false  # Para mouse middle button
var is_touch_dragging: bool = false  # Para touch drag (separado)
var drag_start_pos: Vector2 = Vector2.ZERO
var camera_start_pos: Vector2 = Vector2.ZERO

# Pinch zoom
var initial_pinch_distance: float = 0.0
var initial_zoom: Vector2 = Vector2.ONE

# ==============================================================================
# ESTADO DE LONG PRESS
# ==============================================================================
var long_press_active: bool = false
var long_press_timer: float = 0.0
var long_press_start_pos: Vector2 = Vector2.ZERO
var long_press_start_hex: Vector2i = Vector2i(-1, -1)

# ==============================================================================
# FLAGS DE CONTROL
# ==============================================================================
var has_moved_significantly: bool = false
var deployment_phase: bool = false
var battle_started: bool = false

# Debounce de clicks
var _last_click_frame: int = -1

# Input blocking
var ignore_next_click: bool = false
var ui_interaction_cooldown: float = 0.0

# Referencia al FacingSelector local (para excluirlo de detección de botones)
var _local_facing_selector: Node = null


# ==============================================================================
# SETUP
# ==============================================================================

func setup(p_hex_grid: HexGrid, p_camera: Camera2D = null, p_ui: Node = null) -> void:
	"""Configura el router con las referencias necesarias"""
	hex_grid = p_hex_grid
	camera = p_camera
	ui = p_ui
	Log.info("Input", "BattleInputRouter initialized")


func set_camera(p_camera: Camera2D) -> void:
	"""Establece la referencia a la cámara"""
	camera = p_camera


func set_ui(p_ui: Node) -> void:
	"""Establece la referencia a la UI"""
	ui = p_ui


func set_local_facing_selector(selector: Node) -> void:
	"""Establece referencia al facing selector local para excluirlo de detección"""
	_local_facing_selector = selector


func set_deployment_phase(active: bool) -> void:
	"""Establece si estamos en fase de despliegue"""
	deployment_phase = active


func set_battle_started(started: bool) -> void:
	"""Establece si la batalla ha comenzado"""
	battle_started = started


# ==============================================================================
# PROCESS (llamar desde _process del battle_scene)
# ==============================================================================

func process_delta(delta: float) -> void:
	"""Procesar cada frame (para cooldowns y long press timer)"""
	if ui_interaction_cooldown > 0:
		ui_interaction_cooldown -= delta
	
	# Actualizar el timer de long press
	if long_press_active:
		long_press_timer += delta
		
		# Si se completó el long press, emitir señal
		if long_press_timer >= LONG_PRESS_DURATION:
			long_press_active = false
			hex_long_pressed.emit(long_press_start_hex)


# ==============================================================================
# INPUT PRINCIPAL
# ==============================================================================

func process_input(event: InputEvent) -> bool:
	"""
	Procesa un evento de input.
	Retorna true si el evento fue manejado y no debe propagarse.
	
	IMPORTANTE: Esta función replica exactamente el flujo de _input() en battle_scene.gd
	"""
	# Verificar referencias básicas
	if hex_grid == null or camera == null:
		return false
	
	# PRIMERO: Ignorar TODOS los eventos si están sobre el panel de log de la UI
	# Esto incluye gestos de cámara (pan/zoom)
	if ui and ui.has_method("is_mouse_over_log_panel"):
		if ui.is_mouse_over_log_panel():
			if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseMotion:
				return false  # No consumir, pero tampoco procesar
	
	# Gestos de cámara (zoom, pan) - solo si NO estamos sobre el log
	if _handle_camera_input(event):
		long_press_active = false
		return true
	
	# Bloquear OTRO input solo si no estamos en despliegue y la batalla no ha comenzado
	if not deployment_phase and not battle_started:
		return false
	
	# Detectar inicio de tap largo (táctil o mouse)
	if _is_press_start(event):
		_handle_press_start(event)
	
	# Cancelar tap largo si se mueve mucho
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		_handle_drag_or_motion(event)
	
	# Detectar fin de press (para cancelar long press antes de tiempo)
	if _is_press_end(event):
		if long_press_active and long_press_timer < LONG_PRESS_DURATION:
			long_press_active = false
	
	# Click derecho para inspección en PC
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var world_pos: Vector2 = camera.get_global_mouse_position()
		var hex: Vector2i = hex_grid.pixel_to_hex(world_pos - hex_grid.global_position)
		hex_long_pressed.emit(hex)
		return true
	
	# Click/toque en hexágono - Prevenir doble procesamiento
	var current_frame: int = Engine.get_process_frames()
	
	# Touch release
	if event is InputEventScreenTouch and not event.pressed:
		return _handle_touch_release(event, current_frame)
	
	# Mouse press (guardar posición inicial)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		touch_start_positions[0] = event.position
		has_moved_significantly = false
		return false  # No consumir, dejar que llegue al release
	
	# Mouse release
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return _handle_mouse_release(event, current_frame)
	
	return false


# ==============================================================================
# CAMERA INPUT (réplica exacta de _handle_camera_input en battle_scene.gd)
# ==============================================================================

func _handle_camera_input(event: InputEvent) -> bool:
	"""
	Procesa gestos de cámara.
	Retorna true si el evento fue procesado como gesto de cámara.
	NOTA: Actualizado para permitir long press con emulación táctil desde mouse.
	"""
	if camera == null:
		return false
	
	# Gestos táctiles - SOLO para multi-touch (2+ dedos) o drag con 1 dedo
	# NO consumir el primer toque (InputEventScreenTouch pressed) para permitir long press
	if event is InputEventScreenTouch:
		if event.pressed:
			# Nuevo toque
			touch_points[event.index] = event.position
			
			if touch_points.size() == 1:
				# Un dedo: iniciar arrastre pero NO consumir el evento
				# para permitir que long press funcione
				is_dragging = true
				drag_start_pos = event.position
				camera_start_pos = camera.position
				return false  # ← NO consumir el primer toque
			elif touch_points.size() == 2:
				# Dos dedos: iniciar zoom con pellizco
				is_dragging = false
				var points: Array = touch_points.values()
				initial_pinch_distance = points[0].distance_to(points[1])
				initial_zoom = camera.zoom
				return true  # Consumir para pinch zoom
		else:
			# Soltar toque
			touch_points.erase(event.index)
			
			if touch_points.size() == 0:
				is_dragging = false
			elif touch_points.size() == 1:
				# Volver a modo arrastre con el dedo restante
				is_dragging = true
				var remaining_point: Vector2 = touch_points.values()[0]
				drag_start_pos = remaining_point
				camera_start_pos = camera.position
		
		# Solo consumir release si hay más dedos activos
		return touch_points.size() > 0
	
	# Movimiento táctil - solo procesar como drag de cámara si el movimiento es significativo
	if event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		
		# Calcular distancia desde el inicio del drag
		var drag_distance: float = event.position.distance_to(drag_start_pos)
		
		if touch_points.size() == 1 and is_dragging:
			# Solo mover cámara si el movimiento excede el threshold de long press
			# Esto permite que long press funcione con pequeños movimientos
			if drag_distance > TOUCH_MOVE_THRESHOLD:
				var drag_delta: Vector2 = (drag_start_pos - event.position) / camera.zoom.x
				camera.position = camera_start_pos + drag_delta
				has_moved_significantly = true
				return true
			else:
				# Movimiento pequeño - no consumir para permitir long press
				return false
		elif touch_points.size() == 2:
			# Zoom con pellizco (pinch)
			has_moved_significantly = true
			var points: Array = touch_points.values()
			var current_distance: float = points[0].distance_to(points[1])
			var zoom_factor: float = current_distance / initial_pinch_distance
			
			var new_zoom: Vector2 = initial_zoom * zoom_factor
			new_zoom.x = clamp(new_zoom.x, MIN_ZOOM, MAX_ZOOM)
			new_zoom.y = clamp(new_zoom.y, MIN_ZOOM, MAX_ZOOM)
			camera.zoom = new_zoom
			return true
	
	# Soporte de mouse para testing en PC
	if event is InputEventMouseButton:
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
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom *= 0.9
			camera.zoom.x = clamp(camera.zoom.x, MIN_ZOOM, MAX_ZOOM)
			camera.zoom.y = clamp(camera.zoom.y, MIN_ZOOM, MAX_ZOOM)
			has_moved_significantly = true
			return true
	
	if event is InputEventMouseMotion and is_dragging:
		var drag_delta: Vector2 = (drag_start_pos - event.position) / camera.zoom.x
		camera.position = camera_start_pos + drag_delta
		has_moved_significantly = true
		return true
	
	return false


# ==============================================================================
# PRESS DETECTION
# ==============================================================================

func _is_press_start(event: InputEvent) -> bool:
	"""Detecta inicio de press (touch o mouse left)"""
	if event is InputEventScreenTouch and event.pressed:
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return false


func _is_press_end(event: InputEvent) -> bool:
	"""Detecta fin de press"""
	if event is InputEventScreenTouch and not event.pressed:
		return true
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return false


func _handle_press_start(event: InputEvent) -> void:
	"""Maneja el inicio de un press para long press detection"""
	# Solo iniciar tap largo si hay máximo 1 toque (el actual) - evitar durante pinch zoom
	# NOTA: touch_points ya tiene el toque actual agregado por _handle_camera_input
	if touch_points.size() <= 1:
		long_press_active = true
		long_press_timer = 0.0
		long_press_start_pos = event.position
		has_moved_significantly = false
		
		# Guardar posición inicial del toque para detectar drags
		if event is InputEventScreenTouch:
			touch_start_positions[event.index] = event.position
		
		# Calcular el hexágono donde empezó el long press
		if camera and hex_grid:
			var lp_world_pos: Vector2 = camera.get_global_mouse_position()
			long_press_start_hex = hex_grid.pixel_to_hex(lp_world_pos - hex_grid.global_position)


func _handle_drag_or_motion(event: InputEvent) -> void:
	"""Maneja eventos de drag/motion para cancelar long press y detectar movimiento"""
	# Cancelar long press si se mueve mucho
	if long_press_active and event.position.distance_to(long_press_start_pos) > TOUCH_MOVE_THRESHOLD:
		long_press_active = false
		has_moved_significantly = true
	
	# Detectar movimiento significativo para cualquier toque
	if event is InputEventScreenDrag and touch_start_positions.has(event.index):
		if event.position.distance_to(touch_start_positions[event.index]) > TOUCH_MOVE_THRESHOLD:
			has_moved_significantly = true
	
	# Detectar movimiento significativo para mouse
	if event is InputEventMouseMotion and touch_start_positions.has(0):
		if event.position.distance_to(touch_start_positions[0]) > TOUCH_MOVE_THRESHOLD:
			has_moved_significantly = true


# ==============================================================================
# CLICK HANDLING
# ==============================================================================

func _handle_touch_release(event: InputEventScreenTouch, current_frame: int) -> bool:
	"""Maneja el release de un touch"""
	# Limpiar la posición inicial del toque
	if touch_start_positions.has(event.index):
		touch_start_positions.erase(event.index)
	
	# Solo procesar como click si no hubo movimiento significativo
	if touch_points.size() == 0 and not long_press_active and not has_moved_significantly:
		if not _should_block_click(event.position):
			_emit_hex_click()
			_last_click_frame = current_frame
	
	# Resetear el flag de movimiento cuando se sueltan todos los toques
	if touch_points.size() == 0:
		movement_flag_reset_requested.emit()
	
	return true  # Siempre consumir touch release para evitar doble procesamiento


func _handle_mouse_release(event: InputEventMouseButton, current_frame: int) -> bool:
	"""Maneja el release del botón izquierdo del mouse"""
	# Ignorar si ya se procesó como touch en este frame
	if _last_click_frame == current_frame:
		return false
	
	# Solo procesar como click si no hubo movimiento significativo
	if not long_press_active and not has_moved_significantly:
		if not _should_block_click(event.position):
			_emit_hex_click()
	
	# Limpiar posición inicial
	touch_start_positions.erase(0)
	movement_flag_reset_requested.emit()
	
	return false  # No consumir para permitir otros handlers


func _emit_hex_click() -> void:
	"""Emite la señal de click en hex"""
	var world_pos: Vector2 = camera.get_global_mouse_position()
	var hex: Vector2i = hex_grid.pixel_to_hex(world_pos - hex_grid.global_position)
	
	if hex_grid.is_valid_hex(hex):
		hex_clicked.emit(hex)


func _should_block_click(screen_pos: Vector2) -> bool:
	"""Determina si el click debe ser bloqueado"""
	# Verificar cooldown de interacción con UI
	if ui_interaction_cooldown > 0:
		return true
	
	# Verificar si el clic está sobre un control de UI
	if _is_click_over_ui(screen_pos):
		return true
	
	# Bloquear clics si el facing selector está visible
	if ui and ui.has_method("is_facing_selector_visible") and ui.is_facing_selector_visible():
		return true
	
	# Verificar si debemos ignorar este click
	if ignore_next_click:
		return true
	
	return false


# ==============================================================================
# UI DETECTION (réplica de _is_click_over_ui en battle_scene.gd)
# ==============================================================================

func _is_click_over_ui(screen_pos: Vector2) -> bool:
	"""Verifica si la posición de pantalla está sobre un control de UI interactivo"""
	if not ui:
		return false
	
	# Verificar primero si está sobre el panel de log (tiene prioridad)
	if ui.has_method("is_mouse_over_log_panel") and ui.is_mouse_over_log_panel():
		Log.debug("Input", "Click blocked - over log panel")
		return true
	
	# Verificar si está sobre los paneles de selección de ataque
	if ui.has_method("is_point_over_attack_panels") and ui.is_point_over_attack_panels(screen_pos):
		Log.debug("Input", "Click blocked - over attack panel")
		return true
	
	# Buscar botones visibles en la UI que realmente estén en pantalla
	var buttons: Array = _get_visible_buttons(ui)
	for button in buttons:
		var rect: Rect2 = button.get_global_rect()
		if rect.has_point(screen_pos):
			var button_name: String = button.text if button.text else button.name
			Log.debug("Input", "Click blocked - over button: %s at %s" % [button_name, rect])
			return true
	
	return false


func _get_visible_buttons(node: Node) -> Array:
	"""Obtiene recursivamente todos los botones realmente visibles"""
	var buttons: Array = []
	
	# IMPORTANTE: No buscar botones dentro del facing_selector
	if node.name == "FacingSelector" or node.get_class() == "FacingSelector":
		return buttons
	if _local_facing_selector and node == _local_facing_selector:
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


# ==============================================================================
# UTILIDADES PÚBLICAS
# ==============================================================================

func reset_movement_flag() -> void:
	"""Reset manual del flag de movimiento (llamar desde battle_scene)"""
	has_moved_significantly = false


func start_ignore_click_timer(_duration_ms: int = 200) -> void:
	"""Inicia el timer para ignorar clicks (usado después de cerrar UI)"""
	ignore_next_click = true


func stop_ignore_click() -> void:
	"""Detiene el ignorar clicks"""
	ignore_next_click = false


func clear_ignore_click() -> void:
	"""Alias de stop_ignore_click para compatibilidad"""
	ignore_next_click = false


func notify_ui_interaction() -> void:
	"""Notifica que hubo interacción con UI (para cooldown)"""
	ui_interaction_cooldown = 0.1  # 100ms de cooldown


func get_long_press_progress() -> float:
	"""Retorna el progreso del long press (0.0 a 1.0)"""
	if not long_press_active:
		return 0.0
	return clamp(long_press_timer / LONG_PRESS_DURATION, 0.0, 1.0)


func is_long_press_active() -> bool:
	"""Retorna si hay un long press activo"""
	return long_press_active


func get_long_press_start_pos() -> Vector2:
	"""Retorna la posición donde empezó el long press"""
	return long_press_start_pos


func get_long_press_start_hex() -> Vector2i:
	"""Retorna el hex donde empezó el long press"""
	return long_press_start_hex


func update_long_press_timer(delta: float) -> bool:
	"""
	Actualiza el timer de long press.
	Retorna true si el long press se completó este frame.
	"""
	if not long_press_active:
		return false
	
	long_press_timer += delta
	
	if long_press_timer >= LONG_PRESS_DURATION:
		long_press_active = false
		hex_long_pressed.emit(long_press_start_hex)
		return true
	
	return false


func cancel_long_press() -> void:
	"""Cancela el long press activo"""
	long_press_active = false
	long_press_timer = 0.0
