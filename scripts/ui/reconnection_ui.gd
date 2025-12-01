extends Control
class_name ReconnectionUI

## UI para mostrar estado de reconexión al usuario
## Se muestra automáticamente cuando se pierde conexión

signal reconnection_cancelled()

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var attempt_label: Label = $Panel/VBox/AttemptLabel
@onready var timer_label: Label = $Panel/VBox/TimerLabel
@onready var progress_bar: ProgressBar = $Panel/VBox/ProgressBar
@onready var cancel_button: Button = $Panel/VBox/CancelButton

var _network_manager: Node = null
var _is_active: bool = false


func _ready() -> void:
	# Ocultar inicialmente
	visible = false
	
	# Obtener NetworkManager
	_network_manager = get_node_or_null("/root/NetworkManager")
	
	if _network_manager:
		_network_manager.reconnection_started.connect(_on_reconnection_started)
		_network_manager.reconnection_attempt.connect(_on_reconnection_attempt)
		_network_manager.reconnection_success.connect(_on_reconnection_success)
		_network_manager.reconnection_failed.connect(_on_reconnection_failed)
		_network_manager.reconnection_cancelled.connect(_on_reconnection_cancelled_signal)
	
	# Conectar botón
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)


func _process(delta: float) -> void:
	if not _is_active or not _network_manager:
		return
	
	# Actualizar tiempo restante
	var progress = _network_manager.get_reconnection_progress()
	var time_left = progress.get("time_until_next", 0.0)
	
	if time_left > 0:
		timer_label.text = "Próximo intento en: %.1f s" % time_left
		timer_label.visible = true
	else:
		timer_label.text = "Conectando..."
		timer_label.visible = true


func show_reconnecting() -> void:
	"""Muestra la UI de reconexión"""
	_is_active = true
	visible = true
	
	title_label.text = "CONEXIÓN PERDIDA"
	status_label.text = "Intentando reconectar..."
	progress_bar.value = 0
	cancel_button.disabled = false


func hide_ui() -> void:
	"""Oculta la UI de reconexión"""
	_is_active = false
	visible = false


func update_attempt(current: int, max_attempts: int) -> void:
	"""Actualiza el progreso de reconexión"""
	attempt_label.text = "Intento %d de %d" % [current, max_attempts]
	progress_bar.max_value = max_attempts
	progress_bar.value = current


func show_success() -> void:
	"""Muestra mensaje de éxito"""
	title_label.text = "¡RECONECTADO!"
	status_label.text = "Conexión restaurada"
	timer_label.visible = false
	cancel_button.disabled = true
	
	# Auto-ocultar después de 2 segundos
	await get_tree().create_timer(2.0).timeout
	hide_ui()


func show_failed() -> void:
	"""Muestra mensaje de fallo"""
	title_label.text = "RECONEXIÓN FALLIDA"
	status_label.text = "No se pudo conectar al servidor"
	timer_label.visible = false
	cancel_button.text = "Aceptar"
	cancel_button.disabled = false


# ============================================================
# CALLBACKS
# ============================================================

func _on_reconnection_started() -> void:
	show_reconnecting()


func _on_reconnection_attempt(attempt: int, max_attempts: int) -> void:
	update_attempt(attempt, max_attempts)


func _on_reconnection_success() -> void:
	show_success()


func _on_reconnection_failed() -> void:
	show_failed()


func _on_reconnection_cancelled_signal() -> void:
	hide_ui()


func _on_cancel_pressed() -> void:
	if _network_manager and _network_manager.is_reconnecting():
		_network_manager.cancel_reconnection()
		reconnection_cancelled.emit()
	else:
		# Si ya falló, simplemente ocultar
		hide_ui()
		reconnection_cancelled.emit()
