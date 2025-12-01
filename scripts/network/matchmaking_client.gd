## MatchmakingClient - Cliente para la API de matchmaking
##
## Conecta con el backend FastAPI para matchmaking basado en ELO.
## Complementa el sistema ENet existente para emparejamiento inteligente.
class_name MatchmakingClient
extends Node


# =============================================================================
# SIGNALS
# =============================================================================

## Emitido cuando se une exitosamente a la cola
signal queue_joined(position: int, estimated_wait: float)
## Emitido cuando se abandona la cola
signal queue_left()
## Emitido cuando se encuentra una partida
signal match_found(match_data: Dictionary)
## Emitido cuando el tiempo en cola expira
signal queue_timeout()
## Emitido cuando hay un error de matchmaking
signal matchmaking_error(error: String)
## Emitido cuando se actualiza el estado de la cola
signal queue_status_updated(status: Dictionary)


# =============================================================================
# CONSTANTES
# =============================================================================

## URL base de la API
const API_BASE_URL: String = "https://steeltitans.damsanti.app/api/v1"

## Intervalo de polling para check-match (segundos)
const CHECK_INTERVAL: float = 2.0

## Tiempo máximo en cola antes de timeout (segundos)
const MAX_QUEUE_TIME: float = 180.0

## Modos de juego disponibles
enum GameMode {
	MODE_1V1,
	MODE_2V2,
	MODE_4V4,
	PRACTICE
}

const GAME_MODE_NAMES: Dictionary = {
	GameMode.MODE_1V1: "1v1",
	GameMode.MODE_2V2: "2v2",
	GameMode.MODE_4V4: "4v4",
	GameMode.PRACTICE: "practice"
}


# =============================================================================
# VARIABLES
# =============================================================================

## Estado actual del matchmaking
var is_in_queue: bool = false
var current_game_mode: GameMode = GameMode.MODE_1V1
var queue_start_time: float = 0.0
var queue_position: int = -1

## HTTP client para requests
var _http_request: HTTPRequest
var _check_timer: Timer
var _auth_token: String = ""

## Estado de la última partida encontrada
var last_match_data: Dictionary = {}


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Crear HTTPRequest
	_http_request = HTTPRequest.new()
	_http_request.timeout = 10.0
	add_child(_http_request)
	
	# Crear timer para polling
	_check_timer = Timer.new()
	_check_timer.wait_time = CHECK_INTERVAL
	_check_timer.timeout.connect(_on_check_timer_timeout)
	add_child(_check_timer)


func _process(_delta: float) -> void:
	if is_in_queue:
		var time_in_queue = Time.get_ticks_msec() / 1000.0 - queue_start_time
		if time_in_queue > MAX_QUEUE_TIME:
			_handle_queue_timeout()


# =============================================================================
# PUBLIC API
# =============================================================================

## Establece el token de autenticación
func set_auth_token(token: String) -> void:
	_auth_token = token


## Une al jugador a la cola de matchmaking
func join_queue(game_mode: GameMode = GameMode.MODE_1V1) -> void:
	if is_in_queue:
		Log.warning("Matchmaking", "Already in queue")
		return
	
	if _auth_token.is_empty():
		matchmaking_error.emit("No auth token set")
		return
	
	current_game_mode = game_mode
	var mode_name = GAME_MODE_NAMES[game_mode]
	
	var url = "%s/matchmaking/queue/join" % API_BASE_URL
	var headers = _get_auth_headers()
	var body = JSON.stringify({"game_mode": mode_name})
	
	_http_request.request_completed.connect(_on_join_queue_completed, CONNECT_ONE_SHOT)
	var error = _http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		Log.error("Matchmaking", "Failed to send join request", {"error": error})
		matchmaking_error.emit("Network error")


## Abandona la cola de matchmaking
func leave_queue() -> void:
	if not is_in_queue:
		return
	
	var mode_name = GAME_MODE_NAMES[current_game_mode]
	var url = "%s/matchmaking/queue/leave?game_mode=%s" % [API_BASE_URL, mode_name]
	var headers = _get_auth_headers()
	
	_http_request.request_completed.connect(_on_leave_queue_completed, CONNECT_ONE_SHOT)
	_http_request.request(url, headers, HTTPClient.METHOD_DELETE)
	
	# Detener polling inmediatamente
	_stop_polling()
	is_in_queue = false


## Obtiene el estado actual de la cola
func get_queue_status() -> void:
	if not is_in_queue:
		return
	
	var mode_name = GAME_MODE_NAMES[current_game_mode]
	var url = "%s/matchmaking/queue/status?game_mode=%s" % [API_BASE_URL, mode_name]
	var headers = _get_auth_headers()
	
	_http_request.request_completed.connect(_on_status_completed, CONNECT_ONE_SHOT)
	_http_request.request(url, headers, HTTPClient.METHOD_GET)


## Obtiene estadísticas de matchmaking
func get_matchmaking_stats() -> void:
	var url = "%s/matchmaking/queue/stats" % API_BASE_URL
	var headers = _get_auth_headers()
	
	_http_request.request_completed.connect(_on_stats_completed, CONNECT_ONE_SHOT)
	_http_request.request(url, headers, HTTPClient.METHOD_GET)


## Devuelve el tiempo en cola en segundos
func get_time_in_queue() -> float:
	if not is_in_queue:
		return 0.0
	return Time.get_ticks_msec() / 1000.0 - queue_start_time


## Devuelve si estamos actualmente en cola
func is_queued() -> bool:
	return is_in_queue


# =============================================================================
# POLLING
# =============================================================================

func _start_polling() -> void:
	_check_timer.start()


func _stop_polling() -> void:
	_check_timer.stop()


func _on_check_timer_timeout() -> void:
	if not is_in_queue:
		_stop_polling()
		return
	
	_check_for_match()


func _check_for_match() -> void:
	var mode_name = GAME_MODE_NAMES[current_game_mode]
	var url = "%s/matchmaking/queue/check-match?game_mode=%s" % [API_BASE_URL, mode_name]
	var headers = _get_auth_headers()
	
	# Crear un nuevo HTTPRequest para check separado
	var check_request = HTTPRequest.new()
	check_request.timeout = 5.0
	add_child(check_request)
	check_request.request_completed.connect(
		func(result, code, hdrs, body): _on_check_match_completed(result, code, hdrs, body, check_request),
		CONNECT_ONE_SHOT
	)
	check_request.request(url, headers, HTTPClient.METHOD_GET)


# =============================================================================
# CALLBACKS HTTP
# =============================================================================

func _on_join_queue_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		Log.error("Matchmaking", "Join queue request failed", {"result": result})
		matchmaking_error.emit("Connection error")
		return
	
	var response = _parse_response(body)
	
	if response_code == 200:
		is_in_queue = true
		queue_start_time = Time.get_ticks_msec() / 1000.0
		queue_position = response.get("position", 0)
		
		Log.info("Matchmaking", "Joined queue", {
			"mode": GAME_MODE_NAMES[current_game_mode],
			"position": queue_position
		})
		
		queue_joined.emit(queue_position, response.get("estimated_wait", 30.0))
		_start_polling()
		
	elif response_code == 409:
		# Ya en cola
		is_in_queue = true
		queue_start_time = Time.get_ticks_msec() / 1000.0
		_start_polling()
		matchmaking_error.emit("Already in queue")
		
	else:
		var error_msg = response.get("error", "Unknown error")
		Log.error("Matchmaking", "Failed to join queue", {"code": response_code, "error": error_msg})
		matchmaking_error.emit(error_msg)


func _on_leave_queue_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		Log.warning("Matchmaking", "Leave queue request may have failed", {"result": result})
	
	is_in_queue = false
	queue_position = -1
	
	Log.info("Matchmaking", "Left queue")
	queue_left.emit()


func _on_check_match_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request_node: HTTPRequest) -> void:
	# Limpiar el request temporal
	request_node.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		return  # Ignorar errores de polling
	
	if response_code != 200:
		return
	
	var response = _parse_response(body)
	
	if response.get("match_found", false):
		_handle_match_found(response)


func _on_status_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	
	var response = _parse_response(body)
	queue_status_updated.emit(response)


func _on_stats_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	
	var response = _parse_response(body)
	# Emitir stats si hay listeners
	Log.debug("Matchmaking", "Queue stats received", response)


# =============================================================================
# MATCH HANDLING
# =============================================================================

func _handle_match_found(response: Dictionary) -> void:
	_stop_polling()
	is_in_queue = false
	
	last_match_data = {
		"match_id": response.get("match_id", ""),
		"opponent_id": response.get("opponent", {}).get("user_id", ""),
		"opponent_name": response.get("opponent", {}).get("username", "Unknown"),
		"opponent_elo": response.get("opponent", {}).get("elo", 1000),
		"server_ip": response.get("game_server", {}).get("ip", ""),
		"server_port": response.get("game_server", {}).get("port", 7777),
		"team": response.get("team", "player"),
		"map_seed": response.get("map_seed", randi())
	}
	
	Log.info("Matchmaking", "Match found!", {
		"opponent": last_match_data.opponent_name,
		"opponent_elo": last_match_data.opponent_elo
	})
	
	match_found.emit(last_match_data)


func _handle_queue_timeout() -> void:
	Log.warning("Matchmaking", "Queue timeout", {"time_waited": MAX_QUEUE_TIME})
	
	# Intentar salir de la cola
	leave_queue()
	
	queue_timeout.emit()


# =============================================================================
# HELPERS
# =============================================================================

func _get_auth_headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _auth_token
	])


func _parse_response(body: PackedByteArray) -> Dictionary:
	var json_string = body.get_string_from_utf8()
	if json_string.is_empty():
		return {}
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		Log.error("Matchmaking", "Failed to parse response", {"error": error})
		return {}
	
	return json.data if json.data is Dictionary else {}


# =============================================================================
# INTEGRATION WITH ENET
# =============================================================================

## Conecta al servidor de juego después de encontrar partida
## Usa los datos del match_found para conectar via ENet
func connect_to_game_server() -> Error:
	if last_match_data.is_empty():
		Log.error("Matchmaking", "No match data available")
		return ERR_INVALID_DATA
	
	var network_manager = get_node_or_null("/root/NetworkManager")
	if not network_manager:
		Log.error("Matchmaking", "NetworkManager not found")
		return ERR_UNCONFIGURED
	
	# Extraer datos de conexión
	var server_ip = last_match_data.get("server_ip", "")
	var server_port = last_match_data.get("server_port", 7777)
	var player_name = "Player"  # Obtener del AuthManager si está disponible
	
	# Si no hay IP específica, usar el servidor por defecto
	if server_ip.is_empty():
		server_ip = network_manager.PRODUCTION_SERVER_IP
	
	Log.info("Matchmaking", "Connecting to game server", {
		"ip": server_ip,
		"port": server_port
	})
	
	return network_manager.connect_to_server(server_ip, server_port, player_name)


## Obtiene los datos de la partida actual
func get_match_data() -> Dictionary:
	return last_match_data.duplicate()
