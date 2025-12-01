## AuthManagerSingleton - Wrapper Node para AuthManager
## Este singleton permite usar AuthManager como autoload en Godot
##
## El AuthManagerCore original extiende RefCounted para mayor flexibilidad,
## pero los autoloads de Godot requieren que sean Node.
## Este wrapper resuelve esa limitación.
extends Node

## Preload the AuthManagerCore script
const AuthManagerCoreScript = preload("res://scripts/core/auth_manager.gd")

## Señales - forwarded desde AuthManagerCore + adicionales para UI
signal login_completed(user_data: Dictionary)
signal login_failed(error: Dictionary)
signal registration_completed(user_data: Dictionary)
signal registration_failed(error: Dictionary)
signal logout_completed()
signal auth_state_changed(is_authenticated: bool)

## Instancia interna del AuthManagerCore
var _auth_manager = null  # Type: AuthManagerCore
var _current_user: Dictionary = {}
var _is_authenticated: bool = false
var _auth_token: String = ""

const LOG_CATEGORY := "AuthSingleton"


func _ready() -> void:
	_auth_manager = AuthManagerCoreScript.new()
	
	# Re-inicializar la conexión a la base de datos ahora que estamos en el árbol de escenas
	# Esto es necesario porque Engine.has_singleton puede fallar en RefCounted._init()
	_auth_manager._init_database()
	
	# Verificar estado online de forma asíncrona
	_check_online_status()
	
	# Conectar señales del AuthManagerCore interno
	_auth_manager.login_success.connect(_on_login_success)
	_auth_manager.login_failed.connect(_on_login_failed)
	_auth_manager.logout_completed.connect(_on_logout_completed)
	_auth_manager.auth_state_changed.connect(_on_auth_state_changed)
	
	Log.info(LOG_CATEGORY, "AuthManagerSingleton initialized")


func _check_online_status() -> void:
	"""Verifica el estado online de forma asíncrona"""
	if _auth_manager:
		await _auth_manager.check_online_status()
		var mode = "online" if _auth_manager.is_online() else "offline"
		Log.info(LOG_CATEGORY, "Operation mode determined", {"mode": mode})


## ═══════════════════════════════════════════════════════════════════════════
## MÉTODOS PÚBLICOS - API para UI
## ═══════════════════════════════════════════════════════════════════════════

func login_with_credentials(username: String, password: String, remember_me: bool = true) -> void:
	"""Inicia sesión con credenciales"""
	_auth_manager.login_with_credentials(username, password, _on_login_callback, remember_me)


func register_user(username: String, password: String, email: String = "") -> void:
	"""Registra un nuevo usuario"""
	_auth_manager.register_user(username, password, email, _on_register_callback)


func login_as_guest() -> void:
	"""Inicia sesión como invitado"""
	_auth_manager.login_as_guest(_on_login_callback)


func logout() -> void:
	"""Cierra la sesión actual"""
	_auth_manager.logout()
	_current_user = {}
	_is_authenticated = false
	_auth_token = ""
	
	# Limpiar token en NetworkManager
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager and network_manager.has_method("set_api_auth_token"):
		network_manager.set_api_auth_token("")


func is_authenticated() -> bool:
	"""Retorna si hay un usuario autenticado"""
	return _is_authenticated


func get_current_user() -> Dictionary:
	"""Retorna los datos del usuario actual"""
	return _current_user


func is_online() -> bool:
	"""Retorna si está en modo online"""
	return _auth_manager.is_online() if _auth_manager else false


func get_auth_token() -> String:
	"""Retorna el token de autenticación actual"""
	return _auth_token


func _propagate_auth_token() -> void:
	"""Propaga el token de autenticación al NetworkManager"""
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager and network_manager.has_method("set_api_auth_token"):
		network_manager.set_api_auth_token(_auth_token)
		Log.debug(LOG_CATEGORY, "Auth token propagated to NetworkManager")


## ═══════════════════════════════════════════════════════════════════════════
## CALLBACKS INTERNOS
## ═══════════════════════════════════════════════════════════════════════════

func _on_login_callback(result) -> void:
	"""Callback para login (credentials o guest)"""
	if result.success:
		var user_data = result.user
		_current_user = {
			"id": user_data.user_id,
			"username": user_data.username,
			"display_name": user_data.display_name,
			"email": user_data.email,
			"is_guest": user_data.is_guest,
			"provider": user_data.provider,
			"elo_rating": user_data.metadata.get("elo_rating", 1000),
			"c_bills": user_data.metadata.get("c_bills", 0)
		}
		_is_authenticated = true
		
		# Guardar y propagar el token de autenticación
		if result.token and not result.token.is_empty():
			_auth_token = result.token
			_propagate_auth_token()
			Log.info(LOG_CATEGORY, "Auth token received and propagated")
		
		login_completed.emit(_current_user)
	else:
		var error = result.error
		var error_dict := {
			"message": error.message if error else "Unknown error",
			"code": error.type if error else 0
		}
		login_failed.emit(error_dict)


func _on_register_callback(result) -> void:
	"""Callback para registro"""
	if result.success:
		var user_data = result.user
		_current_user = {
			"id": user_data.user_id,
			"username": user_data.username,
			"display_name": user_data.display_name,
			"email": user_data.email,
			"is_guest": false,
			"provider": user_data.provider,
			"elo_rating": user_data.metadata.get("elo_rating", 1000),
			"c_bills": user_data.metadata.get("c_bills", 0)
		}
		_is_authenticated = true
		
		# Guardar y propagar el token de autenticación (igual que en login)
		if result.token and not result.token.is_empty():
			_auth_token = result.token
			_propagate_auth_token()
			Log.info(LOG_CATEGORY, "Auth token received after registration and propagated")
		
		registration_completed.emit(_current_user)
	else:
		var error = result.error
		var error_dict := {
			"message": error.message if error else "Registration failed",
			"code": error.type if error else 0
		}
		registration_failed.emit(error_dict)


func _on_login_success(user_data) -> void:
	"""Forwarded desde AuthManagerCore"""
	_current_user = {
		"id": user_data.user_id,
		"username": user_data.username,
		"display_name": user_data.display_name,
		"email": user_data.email,
		"is_guest": user_data.is_guest,
		"provider": user_data.provider,
		"elo_rating": user_data.metadata.get("elo_rating", 1000),
		"c_bills": user_data.metadata.get("c_bills", 0)
	}
	_is_authenticated = true


func _on_login_failed(_error) -> void:
	"""Forwarded desde AuthManagerCore"""
	_is_authenticated = false


func _on_logout_completed() -> void:
	"""Forwarded desde AuthManagerCore"""
	_current_user = {}
	_is_authenticated = false
	logout_completed.emit()


func _on_auth_state_changed(authenticated: bool) -> void:
	"""Forwarded desde AuthManagerCore"""
	_is_authenticated = authenticated
	auth_state_changed.emit(authenticated)
