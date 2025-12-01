extends GutTest
## Tests para AuthScreen - Pantalla de autenticación

const AuthScreenScene = preload("res://scenes/auth_screen.tscn")

var auth_screen: AuthScreen
var _mock_auth_manager: MockAuthManager


class MockAuthManager extends Node:
	"""Mock del AuthManager para testing"""
	# Señales que AuthScreen espera (son conectadas en _ready de AuthScreen)
	signal login_completed(user_data: Dictionary)
	signal login_failed(error: Dictionary)
	signal registration_completed(user_data: Dictionary)
	signal registration_failed(error: Dictionary)
	
	var login_calls: Array = []
	var guest_login_calls: int = 0
	var register_calls: Array = []
	
	func login_with_credentials(username: String, password: String, remember_me: bool = true) -> void:
		login_calls.append({"username": username, "password": password, "remember_me": remember_me})
	
	func login_as_guest() -> void:
		guest_login_calls += 1
	
	func register_user(username: String, password: String, email: String = "") -> void:
		register_calls.append({"username": username, "password": password, "email": email})


func before_each() -> void:
	# Crear mock del AuthManager
	_mock_auth_manager = MockAuthManager.new()
	add_child(_mock_auth_manager)
	
	# Instanciar la escena
	auth_screen = AuthScreenScene.instantiate()
	
	# Inyectar el mock antes de agregar al árbol
	# (sobrescribimos la referencia después de _ready)
	add_child_autofree(auth_screen)
	await get_tree().process_frame
	
	# Sobrescribir la referencia al auth manager
	auth_screen._auth_manager = _mock_auth_manager
	
	# Reconectar señales del mock
	if _mock_auth_manager.login_completed.is_connected(auth_screen._on_login_completed):
		pass  # Ya conectado
	else:
		_mock_auth_manager.login_completed.connect(auth_screen._on_login_completed)
		_mock_auth_manager.login_failed.connect(auth_screen._on_login_failed)
		_mock_auth_manager.registration_completed.connect(auth_screen._on_registration_completed)
		_mock_auth_manager.registration_failed.connect(auth_screen._on_registration_failed)


func after_each() -> void:
	if _mock_auth_manager and is_instance_valid(_mock_auth_manager):
		_mock_auth_manager.queue_free()


# =============================================================================
# TESTS DE INICIALIZACIÓN
# =============================================================================

func test_initial_state_shows_login_panel() -> void:
	"""Verifica que el panel de login se muestra por defecto"""
	assert_true(auth_screen._login_panel.visible, "Login panel should be visible initially")
	assert_false(auth_screen._register_panel.visible, "Register panel should be hidden initially")
	assert_eq(auth_screen._current_mode, AuthScreen.Mode.LOGIN, "Initial mode should be LOGIN")


func test_initial_state_no_errors_shown() -> void:
	"""Verifica que no hay errores visibles al inicio"""
	assert_false(auth_screen._login_error_label.visible, "Login error should be hidden initially")
	assert_false(auth_screen._register_error_label.visible, "Register error should be hidden initially")


func test_initial_fields_are_empty() -> void:
	"""Verifica que los campos están vacíos al inicio"""
	assert_eq(auth_screen._login_username.text, "", "Login username should be empty")
	assert_eq(auth_screen._login_password.text, "", "Login password should be empty")
	assert_eq(auth_screen._register_username.text, "", "Register username should be empty")
	assert_eq(auth_screen._register_email.text, "", "Register email should be empty")
	assert_eq(auth_screen._register_password.text, "", "Register password should be empty")
	assert_eq(auth_screen._register_confirm.text, "", "Register confirm should be empty")


# =============================================================================
# TESTS DE CAMBIO DE MODO
# =============================================================================

func test_switch_to_register_mode() -> void:
	"""Verifica cambio a modo registro"""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	assert_false(auth_screen._login_panel.visible, "Login panel should be hidden")
	assert_true(auth_screen._register_panel.visible, "Register panel should be visible")
	assert_eq(auth_screen._current_mode, AuthScreen.Mode.REGISTER, "Mode should be REGISTER")


func test_switch_back_to_login_mode() -> void:
	"""Verifica cambio de vuelta a modo login"""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	auth_screen._switch_to_login()
	await get_tree().process_frame
	
	assert_true(auth_screen._login_panel.visible, "Login panel should be visible")
	assert_false(auth_screen._register_panel.visible, "Register panel should be hidden")
	assert_eq(auth_screen._current_mode, AuthScreen.Mode.LOGIN, "Mode should be LOGIN")


func test_switch_clears_errors() -> void:
	"""Verifica que cambiar de modo limpia los errores"""
	# Mostrar un error
	auth_screen._show_login_error("Test error")
	assert_true(auth_screen._login_error_label.visible, "Error should be visible")
	
	# Cambiar a registro
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	assert_false(auth_screen._login_error_label.visible, "Login error should be cleared")
	assert_false(auth_screen._register_error_label.visible, "Register error should be cleared")


# =============================================================================
# TESTS DE VALIDACIÓN - LOGIN
# =============================================================================

func test_login_empty_username_shows_error() -> void:
	"""Verifica error cuando username está vacío"""
	auth_screen._login_username.text = ""
	auth_screen._login_password.text = "password123"
	
	auth_screen._on_login_pressed()
	await get_tree().process_frame
	
	assert_true(auth_screen._login_error_label.visible, "Error should be visible")
	assert_string_contains(auth_screen._login_error_label.text, "username")
	assert_eq(_mock_auth_manager.login_calls.size(), 0, "Should not call AuthManager")


func test_login_empty_password_shows_error() -> void:
	"""Verifica error cuando password está vacío"""
	auth_screen._login_username.text = "testuser"
	auth_screen._login_password.text = ""
	
	auth_screen._on_login_pressed()
	await get_tree().process_frame
	
	assert_true(auth_screen._login_error_label.visible, "Error should be visible")
	assert_string_contains(auth_screen._login_error_label.text, "password")
	assert_eq(_mock_auth_manager.login_calls.size(), 0, "Should not call AuthManager")


func test_login_short_username_shows_error() -> void:
	"""Verifica error cuando username es muy corto"""
	auth_screen._login_username.text = "ab"
	auth_screen._login_password.text = "password123"
	
	auth_screen._on_login_pressed()
	await get_tree().process_frame
	
	assert_true(auth_screen._login_error_label.visible, "Error should be visible")
	assert_string_contains(auth_screen._login_error_label.text, "3 characters")
	assert_eq(_mock_auth_manager.login_calls.size(), 0, "Should not call AuthManager")


func test_login_valid_credentials_calls_auth_manager() -> void:
	"""Verifica que credenciales válidas llaman al AuthManager"""
	auth_screen._login_username.text = "testuser"
	auth_screen._login_password.text = "password123"
	
	auth_screen._on_login_pressed()
	await get_tree().process_frame
	
	assert_false(auth_screen._login_error_label.visible, "No error should be shown")
	assert_eq(_mock_auth_manager.login_calls.size(), 1, "Should call AuthManager once")
	assert_eq(_mock_auth_manager.login_calls[0].username, "testuser")
	assert_eq(_mock_auth_manager.login_calls[0].password, "password123")


func test_login_trims_username() -> void:
	"""Verifica que el username se trimea"""
	auth_screen._login_username.text = "  testuser  "
	auth_screen._login_password.text = "password123"
	
	auth_screen._on_login_pressed()
	await get_tree().process_frame
	
	assert_eq(_mock_auth_manager.login_calls[0].username, "testuser", "Username should be trimmed")


# =============================================================================
# TESTS DE VALIDACIÓN - REGISTRO
# =============================================================================

func test_register_empty_username_shows_error() -> void:
	"""Verifica error cuando username de registro está vacío"""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	auth_screen._register_username.text = ""
	auth_screen._register_password.text = "password123"
	auth_screen._register_confirm.text = "password123"
	
	auth_screen._on_register_pressed()
	await get_tree().process_frame
	
	assert_true(auth_screen._register_error_label.visible, "Error should be visible")
	assert_eq(_mock_auth_manager.register_calls.size(), 0, "Should not call AuthManager")


func test_register_short_username_shows_error() -> void:
	"""Verifica error cuando username es muy corto"""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	auth_screen._register_username.text = "ab"
	auth_screen._register_password.text = "password123"
	auth_screen._register_confirm.text = "password123"
	
	auth_screen._on_register_pressed()
	await get_tree().process_frame
	
	assert_true(auth_screen._register_error_label.visible, "Error should be visible")
	assert_string_contains(auth_screen._register_error_label.text, "3 characters")


func test_register_long_username_shows_error() -> void:
	"""Verifica error cuando username es muy largo.
	Nota: El campo LineEdit tiene max_length=20, así que para probar la validación
	del backend, removemos temporalmente esa restricción de UI."""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	# Remover la restricción de max_length para poder probar la validación backend
	auth_screen._register_username.max_length = 0  # 0 = sin límite
	
	auth_screen._register_username.text = "a".repeat(21)  # 21 caracteres
	auth_screen._register_password.text = "password123"
	auth_screen._register_confirm.text = "password123"
	
	auth_screen._on_register_pressed()
	await get_tree().process_frame
	
	assert_true(auth_screen._register_error_label.visible, "Error should be visible")
	assert_string_contains(auth_screen._register_error_label.text, "20 characters")


func test_register_invalid_username_characters_shows_error() -> void:
	"""Verifica error cuando username tiene caracteres inválidos"""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	auth_screen._register_username.text = "test@user"  # @ es inválido
	auth_screen._register_password.text = "password123"
	auth_screen._register_confirm.text = "password123"
	
	auth_screen._on_register_pressed()
	await get_tree().process_frame
	
	assert_true(auth_screen._register_error_label.visible, "Error should be visible")
	assert_string_contains(auth_screen._register_error_label.text, "letters, numbers")


func test_register_invalid_email_shows_error() -> void:
	"""Verifica error cuando email es inválido"""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	auth_screen._register_username.text = "testuser"
	auth_screen._register_email.text = "invalid-email"
	auth_screen._register_password.text = "password123"
	auth_screen._register_confirm.text = "password123"
	
	auth_screen._on_register_pressed()
	await get_tree().process_frame
	
	assert_true(auth_screen._register_error_label.visible, "Error should be visible")
	assert_string_contains(auth_screen._register_error_label.text, "email")


func test_register_empty_email_is_valid() -> void:
	"""Verifica que email vacío es válido (es opcional)"""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	auth_screen._register_username.text = "testuser"
	auth_screen._register_email.text = ""  # Email vacío
	auth_screen._register_password.text = "password123"
	auth_screen._register_confirm.text = "password123"
	
	auth_screen._on_register_pressed()
	await get_tree().process_frame
	
	assert_eq(_mock_auth_manager.register_calls.size(), 1, "Should call AuthManager")


func test_register_short_password_shows_error() -> void:
	"""Verifica error cuando password es muy corto"""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	auth_screen._register_username.text = "testuser"
	auth_screen._register_password.text = "12345"  # Solo 5 caracteres
	auth_screen._register_confirm.text = "12345"
	
	auth_screen._on_register_pressed()
	await get_tree().process_frame
	
	assert_true(auth_screen._register_error_label.visible, "Error should be visible")
	assert_string_contains(auth_screen._register_error_label.text, "6 characters")


func test_register_password_mismatch_shows_error() -> void:
	"""Verifica error cuando passwords no coinciden"""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	auth_screen._register_username.text = "testuser"
	auth_screen._register_password.text = "password123"
	auth_screen._register_confirm.text = "password456"  # Diferente
	
	auth_screen._on_register_pressed()
	await get_tree().process_frame
	
	assert_true(auth_screen._register_error_label.visible, "Error should be visible")
	assert_string_contains(auth_screen._register_error_label.text, "match")


func test_register_valid_data_calls_auth_manager() -> void:
	"""Verifica que datos válidos llaman al AuthManager"""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	auth_screen._register_username.text = "testuser"
	auth_screen._register_email.text = "test@example.com"
	auth_screen._register_password.text = "password123"
	auth_screen._register_confirm.text = "password123"
	
	auth_screen._on_register_pressed()
	await get_tree().process_frame
	
	assert_false(auth_screen._register_error_label.visible, "No error should be shown")
	assert_eq(_mock_auth_manager.register_calls.size(), 1, "Should call AuthManager once")
	assert_eq(_mock_auth_manager.register_calls[0].username, "testuser")
	assert_eq(_mock_auth_manager.register_calls[0].password, "password123")
	assert_eq(_mock_auth_manager.register_calls[0].email, "test@example.com")


# =============================================================================
# TESTS DE GUEST LOGIN
# =============================================================================

func test_guest_login_calls_auth_manager() -> void:
	"""Verifica que guest login llama al AuthManager"""
	auth_screen._on_guest_pressed()
	await get_tree().process_frame
	
	assert_eq(_mock_auth_manager.guest_login_calls, 1, "Should call guest login once")


# =============================================================================
# TESTS DE ESTADO DE CARGA
# =============================================================================

func test_loading_state_disables_login_buttons() -> void:
	"""Verifica que el estado de carga deshabilita botones de login"""
	auth_screen._set_loading(true)
	await get_tree().process_frame
	
	assert_true(auth_screen._login_button.disabled, "Login button should be disabled")
	assert_true(auth_screen._login_guest_button.disabled, "Guest button should be disabled")
	assert_false(auth_screen._login_username.editable, "Username field should not be editable")
	assert_false(auth_screen._login_password.editable, "Password field should not be editable")


func test_loading_state_disables_register_buttons() -> void:
	"""Verifica que el estado de carga deshabilita botones de registro"""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	auth_screen._set_loading(true)
	await get_tree().process_frame
	
	assert_true(auth_screen._register_button.disabled, "Register button should be disabled")
	assert_false(auth_screen._register_username.editable, "Username field should not be editable")
	assert_false(auth_screen._register_password.editable, "Password field should not be editable")


func test_loading_state_can_be_cleared() -> void:
	"""Verifica que el estado de carga se puede limpiar"""
	auth_screen._set_loading(true)
	await get_tree().process_frame
	
	auth_screen._set_loading(false)
	await get_tree().process_frame
	
	assert_false(auth_screen._login_button.disabled, "Login button should be enabled")
	assert_false(auth_screen._login_guest_button.disabled, "Guest button should be enabled")
	assert_true(auth_screen._login_username.editable, "Username field should be editable")


func test_cannot_login_while_loading() -> void:
	"""Verifica que no se puede hacer login mientras está cargando"""
	auth_screen._login_username.text = "testuser"
	auth_screen._login_password.text = "password123"
	
	# Simular estado de carga
	auth_screen._is_processing = true
	
	auth_screen._on_login_pressed()
	await get_tree().process_frame
	
	assert_eq(_mock_auth_manager.login_calls.size(), 0, "Should not call AuthManager while loading")


# =============================================================================
# TESTS DE CALLBACKS
# =============================================================================

func test_login_success_emits_signal() -> void:
	"""Verifica que login exitoso emite señal"""
	watch_signals(auth_screen)
	
	var user_data = {"user_id": "123", "username": "testuser", "is_guest": false}
	auth_screen._on_login_completed(user_data)
	await get_tree().process_frame
	
	assert_signal_emitted(auth_screen, "login_successful", "login_successful signal should be emitted")


func test_login_success_clears_loading_state() -> void:
	"""Verifica que login exitoso limpia estado de carga"""
	auth_screen._set_loading(true)
	
	var user_data = {"user_id": "123", "username": "testuser"}
	auth_screen._on_login_completed(user_data)
	await get_tree().process_frame
	
	assert_false(auth_screen._is_processing, "Processing should be false")


func test_login_failure_shows_error() -> void:
	"""Verifica que login fallido muestra error"""
	auth_screen._set_loading(true)
	
	var error = {"message": "Invalid credentials"}
	auth_screen._on_login_failed(error)
	await get_tree().process_frame
	
	assert_true(auth_screen._login_error_label.visible, "Error should be visible")
	assert_string_contains(auth_screen._login_error_label.text, "Invalid credentials")
	assert_false(auth_screen._is_processing, "Processing should be false")
	
	# El Log.warning es comportamiento esperado - marcamos TODOS los errores como handled
	for e in get_errors():
		e.handled = true


func test_registration_success_emits_login_signal() -> void:
	"""Verifica que registro exitoso emite señal de login"""
	watch_signals(auth_screen)
	
	var user_data = {"user_id": "123", "username": "newuser"}
	auth_screen._on_registration_completed(user_data)
	await get_tree().process_frame
	
	assert_signal_emitted(auth_screen, "login_successful", "login_successful should be emitted after registration")


func test_registration_failure_shows_error() -> void:
	"""Verifica que registro fallido muestra error"""
	auth_screen._switch_to_register()
	await get_tree().process_frame
	
	auth_screen._set_loading(true)
	
	var error = {"message": "Username already taken"}
	auth_screen._on_registration_failed(error)
	await get_tree().process_frame
	
	assert_true(auth_screen._register_error_label.visible, "Error should be visible")
	assert_string_contains(auth_screen._register_error_label.text, "Username already taken")
	
	# El Log.warning es comportamiento esperado - marcamos TODOS los errores como handled
	for e in get_errors():
		e.handled = true


# =============================================================================
# TESTS DE EMAIL VALIDATION
# Nota: _is_valid_email se movió a AuthValidator, testeamos a través del validador
# =============================================================================

func test_is_valid_email_accepts_valid_emails() -> void:
	"""Verifica que emails válidos son aceptados por el validador"""
	var validator = auth_screen._validator
	assert_true(validator.validate_email("test@example.com").is_valid)
	assert_true(validator.validate_email("user.name@domain.org").is_valid)
	assert_true(validator.validate_email("user+tag@example.co.uk").is_valid)


func test_is_valid_email_rejects_invalid_emails() -> void:
	"""Verifica que emails inválidos son rechazados por el validador"""
	var validator = auth_screen._validator
	assert_false(validator.validate_email("invalid").is_valid)
	assert_false(validator.validate_email("@example.com").is_valid)
	assert_false(validator.validate_email("test@").is_valid)
	assert_false(validator.validate_email("test@.com").is_valid)


# =============================================================================
# TESTS DE SEÑAL CANCEL
# =============================================================================

func test_cancel_emits_signal() -> void:
	"""Verifica que cancelar emite señal"""
	watch_signals(auth_screen)
	
	# Simular input de cancelar
	var event = InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	auth_screen._input(event)
	await get_tree().process_frame
	
	assert_signal_emitted(auth_screen, "login_cancelled", "login_cancelled signal should be emitted")
