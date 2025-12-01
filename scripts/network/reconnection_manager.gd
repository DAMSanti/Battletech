extends Node
class_name ReconnectionManager

## Sistema de reconexión automática para clientes
## Maneja intentos de reconexión cuando se pierde la conexión con el servidor

signal reconnection_started()
signal reconnection_attempt(attempt: int, max_attempts: int)
signal reconnection_success()
signal reconnection_failed()
signal reconnection_cancelled()

# Configuración de reconexión
const DEFAULT_MAX_ATTEMPTS: int = 5
const DEFAULT_INITIAL_DELAY: float = 1.0  # Segundos
const DEFAULT_MAX_DELAY: float = 30.0  # Segundos
const DEFAULT_BACKOFF_MULTIPLIER: float = 2.0
const CONNECTION_TIMEOUT: float = 10.0  # Tiempo máximo para cada intento

# Estado actual
enum ReconnectionState {
	IDLE,
	RECONNECTING,
	WAITING_DELAY,
	CONNECTED,
	FAILED,
	CANCELLED
}

var state: ReconnectionState = ReconnectionState.IDLE
var current_attempt: int = 0
var max_attempts: int = DEFAULT_MAX_ATTEMPTS
var current_delay: float = DEFAULT_INITIAL_DELAY
var initial_delay: float = DEFAULT_INITIAL_DELAY
var max_delay: float = DEFAULT_MAX_DELAY
var backoff_multiplier: float = DEFAULT_BACKOFF_MULTIPLIER

# Datos de conexión para reconectar
var _last_server_address: String = ""
var _last_server_port: int = 7777
var _last_player_name: String = "Player"
var _was_in_match: bool = false
var _last_match_id: int = -1
var _last_team: String = ""

# Referencias
var _network_manager: Node = null
var _reconnect_timer: Timer = null
var _connection_timer: Timer = null


func _ready() -> void:
	# Crear timers
	_reconnect_timer = Timer.new()
	_reconnect_timer.one_shot = true
	_reconnect_timer.timeout.connect(_on_reconnect_timer_timeout)
	add_child(_reconnect_timer)
	
	_connection_timer = Timer.new()
	_connection_timer.one_shot = true
	_connection_timer.timeout.connect(_on_connection_timeout)
	add_child(_connection_timer)


func initialize(network_manager: Node) -> void:
	"""Inicializa el manager con referencia al NetworkManager"""
	_network_manager = network_manager
	
	# Conectar señales del NetworkManager
	if _network_manager:
		if _network_manager.has_signal("connected_to_server"):
			_network_manager.connected_to_server.connect(_on_connected_to_server)
		if _network_manager.has_signal("connection_failed"):
			_network_manager.connection_failed.connect(_on_connection_failed)
		if _network_manager.has_signal("server_disconnected"):
			_network_manager.server_disconnected.connect(_on_server_disconnected)
	
	Log.info("Reconnection", "ReconnectionManager initialized")


func configure(
	p_max_attempts: int = DEFAULT_MAX_ATTEMPTS,
	p_initial_delay: float = DEFAULT_INITIAL_DELAY,
	p_max_delay: float = DEFAULT_MAX_DELAY,
	p_backoff_multiplier: float = DEFAULT_BACKOFF_MULTIPLIER
) -> void:
	"""Configura los parámetros de reconexión"""
	max_attempts = p_max_attempts
	initial_delay = p_initial_delay
	max_delay = p_max_delay
	backoff_multiplier = p_backoff_multiplier


func save_connection_data(address: String, port: int, player_name: String) -> void:
	"""Guarda los datos de conexión para posible reconexión"""
	_last_server_address = address
	_last_server_port = port
	_last_player_name = player_name
	Log.debug("Reconnection", "Connection data saved", {
		"address": address,
		"port": port,
		"player": player_name
	})


func save_match_data(match_id: int, team: String) -> void:
	"""Guarda datos de la partida actual para reconexión"""
	_was_in_match = match_id > 0
	_last_match_id = match_id
	_last_team = team
	Log.debug("Reconnection", "Match data saved", {
		"match_id": match_id,
		"team": team
	})


func start_reconnection() -> void:
	"""Inicia el proceso de reconexión"""
	if state == ReconnectionState.RECONNECTING or state == ReconnectionState.WAITING_DELAY:
		Log.warning("Reconnection", "Already attempting to reconnect")
		return
	
	if _last_server_address.is_empty():
		Log.error("Reconnection", "No connection data saved, cannot reconnect")
		state = ReconnectionState.FAILED
		reconnection_failed.emit()
		return
	
	Log.info("Reconnection", "Starting reconnection process", {
		"server": _last_server_address,
		"port": _last_server_port,
		"max_attempts": max_attempts
	})
	
	state = ReconnectionState.RECONNECTING
	current_attempt = 0
	current_delay = initial_delay
	
	reconnection_started.emit()
	_attempt_reconnect()


func cancel_reconnection() -> void:
	"""Cancela el proceso de reconexión"""
	if state != ReconnectionState.RECONNECTING and state != ReconnectionState.WAITING_DELAY:
		return
	
	Log.info("Reconnection", "Reconnection cancelled by user")
	
	_reconnect_timer.stop()
	_connection_timer.stop()
	
	state = ReconnectionState.CANCELLED
	reconnection_cancelled.emit()
	_reset()


func is_reconnecting() -> bool:
	"""Retorna si está en proceso de reconexión"""
	return state == ReconnectionState.RECONNECTING or state == ReconnectionState.WAITING_DELAY


func get_current_attempt() -> int:
	"""Retorna el intento actual"""
	return current_attempt


func get_max_attempts() -> int:
	"""Retorna el máximo de intentos"""
	return max_attempts


func get_time_until_next_attempt() -> float:
	"""Retorna el tiempo restante hasta el próximo intento"""
	if _reconnect_timer.is_stopped():
		return 0.0
	return _reconnect_timer.time_left


func was_in_match() -> bool:
	"""Retorna si estaba en una partida al desconectarse"""
	return _was_in_match


func get_match_data() -> Dictionary:
	"""Retorna datos de la partida para reconexión"""
	return {
		"match_id": _last_match_id,
		"team": _last_team,
		"was_in_match": _was_in_match
	}


# ============================================================
# INTERNAL METHODS
# ============================================================

func _attempt_reconnect() -> void:
	"""Intenta una reconexión"""
	current_attempt += 1
	
	if current_attempt > max_attempts:
		Log.error("Reconnection", "Max reconnection attempts reached", {
			"attempts": current_attempt - 1
		})
		state = ReconnectionState.FAILED
		reconnection_failed.emit()
		_reset()
		return
	
	Log.info("Reconnection", "Attempting reconnection", {
		"attempt": current_attempt,
		"max": max_attempts,
		"server": _last_server_address
	})
	
	reconnection_attempt.emit(current_attempt, max_attempts)
	
	# Intentar conectar
	if _network_manager:
		# Asegurarse de estar desconectado primero
		if _network_manager.has_method("disconnect_from_server"):
			_network_manager.disconnect_from_server()
		
		# Esperar un frame para limpiar
		await get_tree().process_frame
		
		# Intentar conexión
		var result = _network_manager.connect_to_server(
			_last_server_address,
			_last_server_port,
			_last_player_name
		)
		
		if result != OK:
			Log.warning("Reconnection", "Connection attempt failed immediately", {
				"error": error_string(result)
			})
			_schedule_next_attempt()
		else:
			# Iniciar timer de timeout
			_connection_timer.start(CONNECTION_TIMEOUT)


func _schedule_next_attempt() -> void:
	"""Programa el siguiente intento con backoff exponencial"""
	state = ReconnectionState.WAITING_DELAY
	
	Log.info("Reconnection", "Scheduling next attempt", {
		"delay": current_delay,
		"attempt": current_attempt + 1
	})
	
	_reconnect_timer.start(current_delay)
	
	# Aplicar backoff exponencial
	current_delay = min(current_delay * backoff_multiplier, max_delay)


func _reset() -> void:
	"""Resetea el estado del manager"""
	current_attempt = 0
	current_delay = initial_delay


func _handle_successful_reconnection() -> void:
	"""Maneja una reconexión exitosa"""
	_connection_timer.stop()
	state = ReconnectionState.CONNECTED
	
	Log.info("Reconnection", "Reconnection successful!", {
		"attempts_needed": current_attempt
	})
	
	reconnection_success.emit()
	
	# Si estaba en una partida, intentar reconectarse a ella
	if _was_in_match and _last_match_id > 0:
		Log.info("Reconnection", "Attempting to rejoin match", {
			"match_id": _last_match_id
		})
		# El servidor manejará la lógica de reconexión a partida
		if _network_manager and _network_manager.has_method("request_match_rejoin"):
			_network_manager.request_match_rejoin(_last_match_id)
	
	_reset()


# ============================================================
# CALLBACKS
# ============================================================

func _on_reconnect_timer_timeout() -> void:
	"""Callback cuando el timer de reconexión expira"""
	if state == ReconnectionState.WAITING_DELAY:
		state = ReconnectionState.RECONNECTING
		_attempt_reconnect()


func _on_connection_timeout() -> void:
	"""Callback cuando la conexión tarda demasiado"""
	Log.warning("Reconnection", "Connection attempt timed out", {
		"attempt": current_attempt
	})
	
	# Desconectar y programar siguiente intento
	if _network_manager and _network_manager.has_method("disconnect_from_server"):
		_network_manager.disconnect_from_server()
	
	_schedule_next_attempt()


func _on_connected_to_server() -> void:
	"""Callback cuando se conecta al servidor"""
	if state == ReconnectionState.RECONNECTING:
		_handle_successful_reconnection()


func _on_connection_failed() -> void:
	"""Callback cuando falla la conexión"""
	if state == ReconnectionState.RECONNECTING:
		_connection_timer.stop()
		_schedule_next_attempt()


func _on_server_disconnected() -> void:
	"""Callback cuando el servidor se desconecta"""
	if state == ReconnectionState.IDLE or state == ReconnectionState.CONNECTED:
		# Guardar estado de partida actual si existe
		if _network_manager:
			var match_id = _network_manager.get("current_match_id")
			var team = _network_manager.get("current_team")
			if match_id and match_id > 0:
				save_match_data(match_id, team if team else "")
		
		# Auto-iniciar reconexión
		Log.info("Reconnection", "Server disconnected, starting auto-reconnection")
		start_reconnection()
