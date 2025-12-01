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
signal login_failed(error_message: String)
signal registration_completed(user_data: Dictionary)
signal registration_failed(error_message: String)
signal logout_completed()
signal auth_state_changed(is_authenticated: bool)

## Instancia interna del AuthManagerCore
var _auth_manager = null  # Type: AuthManagerCore
var _current_user: Dictionary = {}
var _is_authenticated: bool = false

const LOG_CATEGORY := "AuthSingleton"


func _ready() -> void:
	_auth_manager = AuthManagerCoreScript.new()
	
	# Conectar señales del AuthManagerCore interno
	_auth_manager.login_success.connect(_on_login_success)
	_auth_manager.login_failed.connect(_on_login_failed)
	_auth_manager.logout_completed.connect(_on_logout_completed)
	_auth_manager.auth_state_changed.connect(_on_auth_state_changed)
	
	Log.info(LOG_CATEGORY, "AuthManagerSingleton initialized")


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


func is_authenticated() -> bool:
	"""Retorna si hay un usuario autenticado"""
	return _is_authenticated


func get_current_user() -> Dictionary:
	"""Retorna los datos del usuario actual"""
	return _current_user


func is_online() -> bool:
	"""Retorna si está en modo online"""
	return _auth_manager.is_online() if _auth_manager else false


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
		login_completed.emit(_current_user)
	else:
		var error = result.error
		login_failed.emit(error.message if error else "Unknown error")


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
		registration_completed.emit(_current_user)
	else:
		var error = result.error
		registration_failed.emit(error.message if error else "Registration failed")


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
