## AuthScreen - Pantalla de Login/Register (Solo UI)
## La lógica de validación está en AuthValidator (SRP - Single Responsibility Principle)
## La lógica de autenticación está en AuthManager
class_name AuthScreen
extends Control

const AuthValidatorClass = preload("res://scripts/core/auth_validator.gd")

## Señales
signal login_successful(user_data: Dictionary)
signal login_cancelled()

## Modo de la pantalla
enum Mode { LOGIN, REGISTER }

## Referencias a nodos
@onready var _login_panel: Panel = $CenterContainer/LoginPanel
@onready var _register_panel: Panel = $CenterContainer/RegisterPanel

# Login fields
@onready var _login_username: LineEdit = $CenterContainer/LoginPanel/VBox/UsernameField
@onready var _login_password: LineEdit = $CenterContainer/LoginPanel/VBox/PasswordField
@onready var _login_remember_me: CheckBox = $CenterContainer/LoginPanel/VBox/RememberMeCheck
@onready var _login_button: Button = $CenterContainer/LoginPanel/VBox/ButtonsHBox/LoginButton
@onready var _login_guest_button: Button = $CenterContainer/LoginPanel/VBox/ButtonsHBox/GuestButton
@onready var _login_register_link: Button = $CenterContainer/LoginPanel/VBox/RegisterLink
@onready var _login_error_label: Label = $CenterContainer/LoginPanel/VBox/ErrorLabel
@onready var _login_loading: Control = $CenterContainer/LoginPanel/VBox/LoadingIndicator

# Register fields
@onready var _register_username: LineEdit = $CenterContainer/RegisterPanel/VBox/UsernameField
@onready var _register_email: LineEdit = $CenterContainer/RegisterPanel/VBox/EmailField
@onready var _register_password: LineEdit = $CenterContainer/RegisterPanel/VBox/PasswordField
@onready var _register_confirm: LineEdit = $CenterContainer/RegisterPanel/VBox/ConfirmPasswordField
@onready var _register_button: Button = $CenterContainer/RegisterPanel/VBox/RegisterButton
@onready var _register_back_link: Button = $CenterContainer/RegisterPanel/VBox/BackLink
@onready var _register_error_label: Label = $CenterContainer/RegisterPanel/VBox/ErrorLabel
@onready var _register_loading: Control = $CenterContainer/RegisterPanel/VBox/LoadingIndicator

## Estado interno
var _current_mode: Mode = Mode.LOGIN
var _auth_manager: Node = null
var _validator = null  # AuthValidatorClass instance
var _is_processing: bool = false

const LOG_CATEGORY := "Auth"


func _ready() -> void:
	# Inicializar el validador
	_validator = AuthValidatorClass.new()
	
	# Obtener AuthManager
	_auth_manager = get_node_or_null("/root/AuthManager")
	if not _auth_manager:
		Log.error(LOG_CATEGORY, "AuthManager not found!")
		return
	
	# Conectar señales del AuthManager
	_auth_manager.login_completed.connect(_on_login_completed)
	_auth_manager.login_failed.connect(_on_login_failed)
	_auth_manager.registration_completed.connect(_on_registration_completed)
	_auth_manager.registration_failed.connect(_on_registration_failed)
	
	# Configurar campos de contraseña
	_login_password.secret = true
	_register_password.secret = true
	_register_confirm.secret = true
	
	# Conectar señales de UI
	_login_button.pressed.connect(_on_login_pressed)
	_login_guest_button.pressed.connect(_on_guest_pressed)
	_login_register_link.pressed.connect(_switch_to_register)
	
	_register_button.pressed.connect(_on_register_pressed)
	_register_back_link.pressed.connect(_switch_to_login)
	
	# Permitir Enter para enviar formularios
	_login_password.text_submitted.connect(func(_t): _on_login_pressed())
	_register_confirm.text_submitted.connect(func(_t): _on_register_pressed())
	
	# Estado inicial
	_switch_to_login()
	_clear_errors()
	_set_loading(false)
	
	# Focus en el primer campo
	_login_username.grab_focus()
	
	Log.info(LOG_CATEGORY, "AuthScreen initialized")


func _switch_to_login() -> void:
	"""Cambia al modo login"""
	_current_mode = Mode.LOGIN
	_login_panel.visible = true
	_register_panel.visible = false
	_clear_errors()
	_login_username.grab_focus()


func _switch_to_register() -> void:
	"""Cambia al modo registro"""
	_current_mode = Mode.REGISTER
	_login_panel.visible = false
	_register_panel.visible = true
	_clear_errors()
	_register_username.grab_focus()


func _clear_errors() -> void:
	"""Limpia los mensajes de error"""
	_login_error_label.text = ""
	_login_error_label.visible = false
	_register_error_label.text = ""
	_register_error_label.visible = false


func _show_login_error(message: String) -> void:
	"""Muestra error en el panel de login"""
	_login_error_label.text = message
	_login_error_label.visible = true
	_login_error_label.add_theme_color_override("font_color", Color.RED)


func _show_register_error(message: String) -> void:
	"""Muestra error en el panel de registro"""
	_register_error_label.text = message
	_register_error_label.visible = true
	_register_error_label.add_theme_color_override("font_color", Color.RED)


func _set_loading(is_loading: bool) -> void:
	"""Activa/desactiva el estado de carga"""
	_is_processing = is_loading
	
	# Login panel
	_login_button.disabled = is_loading
	_login_guest_button.disabled = is_loading
	_login_username.editable = not is_loading
	_login_password.editable = not is_loading
	if _login_loading:
		_login_loading.visible = is_loading
	
	# Register panel
	_register_button.disabled = is_loading
	_register_username.editable = not is_loading
	_register_email.editable = not is_loading
	_register_password.editable = not is_loading
	_register_confirm.editable = not is_loading
	if _register_loading:
		_register_loading.visible = is_loading


# =============================================================================
# HANDLERS DE BOTONES
# =============================================================================

func _on_login_pressed() -> void:
	"""Maneja el click en Login"""
	if _is_processing:
		return
	
	var username := _login_username.text.strip_edges()
	var password := _login_password.text
	var remember_me := _login_remember_me.button_pressed
	
	# Validación usando AuthValidator
	var result = _validator.validate_login(username, password)
	if not result.is_valid:
		_show_login_error(result.error_message)
		_focus_login_field(result.field)
		return
	
	_clear_errors()
	_set_loading(true)
	
	Log.info(LOG_CATEGORY, "Attempting login", {"username": username, "remember_me": remember_me})
	_auth_manager.login_with_credentials(username, password, remember_me)


func _focus_login_field(field_name: String) -> void:
	"""Enfoca el campo correspondiente en login"""
	match field_name:
		"username":
			_login_username.grab_focus()
		"password":
			_login_password.grab_focus()


func _on_guest_pressed() -> void:
	"""Maneja el click en Guest Login"""
	if _is_processing:
		return
	
	_clear_errors()
	_set_loading(true)
	
	Log.info(LOG_CATEGORY, "Attempting guest login")
	_auth_manager.login_as_guest()


func _on_register_pressed() -> void:
	"""Maneja el click en Register"""
	if _is_processing:
		return
	
	var username := _register_username.text.strip_edges()
	var email := _register_email.text.strip_edges()
	var password := _register_password.text
	var confirm := _register_confirm.text
	
	# Validación usando AuthValidator
	var result = _validator.validate_registration(username, password, confirm, email)
	if not result.is_valid:
		_show_register_error(result.error_message)
		_focus_register_field(result.field)
		return
	
	_clear_errors()
	_set_loading(true)
	
	Log.info(LOG_CATEGORY, "Attempting registration", {"username": username})
	_auth_manager.register_user(username, password, email if not email.is_empty() else "")


func _focus_register_field(field_name: String) -> void:
	"""Enfoca el campo correspondiente en registro"""
	match field_name:
		"username":
			_register_username.grab_focus()
		"email":
			_register_email.grab_focus()
		"password":
			_register_password.grab_focus()
		"confirm_password":
			_register_confirm.grab_focus()


# =============================================================================
# CALLBACKS DEL AUTH MANAGER
# =============================================================================

func _on_login_completed(user_data: Dictionary) -> void:
	"""Login exitoso"""
	_set_loading(false)
	Log.info(LOG_CATEGORY, "Login successful", {"user_id": user_data.get("user_id", "unknown")})
	
	# Reproducir sonido de éxito
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_UI_CONFIRM)
	
	login_successful.emit(user_data)


func _on_login_failed(error: Dictionary) -> void:
	"""Login fallido"""
	_set_loading(false)
	var message: String = str(error.get("message", "Login failed. Please try again."))
	Log.warning(LOG_CATEGORY, "Login failed", error)
	_show_login_error(message)
	
	# Reproducir sonido de error
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_UI_ERROR)


func _on_registration_completed(user_data: Dictionary) -> void:
	"""Registro exitoso - hace login automático"""
	_set_loading(false)
	Log.info(LOG_CATEGORY, "Registration successful", {"user_id": user_data.get("user_id", "unknown")})
	
	# Reproducir sonido de éxito
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_UI_CONFIRM)
	
	# El registro ya hace login automático en AuthManager
	login_successful.emit(user_data)


func _on_registration_failed(error: Dictionary) -> void:
	"""Registro fallido"""
	_set_loading(false)
	var message: String = str(error.get("message", "Registration failed. Please try again."))
	Log.warning(LOG_CATEGORY, "Registration failed", error)
	_show_register_error(message)
	
	# Reproducir sonido de error
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_UI_ERROR)


# =============================================================================
# INPUT
# =============================================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		login_cancelled.emit()
		get_viewport().set_input_as_handled()
