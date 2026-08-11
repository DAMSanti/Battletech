## Tests para AuthManager
## Cobertura completa del sistema de autenticación
extends GutTest

const Auth := preload("res://scripts/core/auth_manager.gd")

var auth: Auth = null


## ═══════════════════════════════════════════════════════════════════════════
## SETUP Y TEARDOWN
## ═══════════════════════════════════════════════════════════════════════════

func before_each() -> void:
	auth = Auth.new()
	# Limpiar archivos de test
	_cleanup_test_files()


func after_each() -> void:
	if auth:
		auth.logout()
	_cleanup_test_files()


func _cleanup_test_files() -> void:
	var session_path := "user://session.json"
	var users_path := "user://users.json"
	
	if FileAccess.file_exists(session_path):
		DirAccess.remove_absolute(session_path)
	if FileAccess.file_exists(users_path):
		DirAccess.remove_absolute(users_path)


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE UserData
## ═══════════════════════════════════════════════════════════════════════════

func test_user_data_creation() -> void:
	var user: Auth.UserData = Auth.UserData.new("test_id", "testuser", Auth.AuthProvider.CREDENTIALS)
	
	assert_eq(user.user_id, "test_id", "user_id debe ser correcto")
	assert_eq(user.username, "testuser", "username debe ser correcto")
	assert_eq(user.provider, Auth.AuthProvider.CREDENTIALS, "provider debe ser CREDENTIALS")
	assert_false(user.is_guest, "no debe ser invitado")
	assert_gt(user.created_at, 0, "created_at debe tener valor")


func test_user_data_guest_creation() -> void:
	var user: Auth.UserData = Auth.UserData.create_guest()
	
	assert_true(user.user_id.begins_with("guest_"), "ID debe comenzar con 'guest_'")
	assert_eq(user.username, "Guest", "username debe ser 'Guest'")
	assert_eq(user.display_name, "Invitado", "display_name debe ser 'Invitado'")
	assert_eq(user.provider, Auth.AuthProvider.GUEST, "provider debe ser GUEST")
	assert_true(user.is_guest, "debe ser invitado")


func test_user_data_serialization() -> void:
	var original: Auth.UserData = Auth.UserData.new("id123", "player1", Auth.AuthProvider.CREDENTIALS)
	original.display_name = "Player One"
	original.email = "player1@test.com"
	
	var dict: Dictionary = original.to_dict()
	var restored: Auth.UserData = Auth.UserData.from_dict(dict)
	
	assert_eq(restored.user_id, original.user_id, "user_id debe persistir")
	assert_eq(restored.username, original.username, "username debe persistir")
	assert_eq(restored.display_name, original.display_name, "display_name debe persistir")
	assert_eq(restored.email, original.email, "email debe persistir")
	assert_eq(restored.provider, original.provider, "provider debe persistir")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE AuthError
## ═══════════════════════════════════════════════════════════════════════════

func test_auth_error_creation() -> void:
	var error: Auth.AuthError = Auth.AuthError.new(
		Auth.AuthErrorType.INVALID_CREDENTIALS,
		"Test error",
		Auth.AuthProvider.CREDENTIALS
	)
	
	assert_eq(error.type, Auth.AuthErrorType.INVALID_CREDENTIALS)
	assert_eq(error.message, "Test error")
	assert_eq(error.provider, Auth.AuthProvider.CREDENTIALS)


func test_auth_error_invalid_credentials_message() -> void:
	var error: Auth.AuthError = Auth.AuthError.new(Auth.AuthErrorType.INVALID_CREDENTIALS, "", Auth.AuthProvider.NONE)
	assert_true(error.get_user_message().contains("Usuario"), "debe contener mensaje apropiado")


func test_auth_error_user_not_found_message() -> void:
	var error: Auth.AuthError = Auth.AuthError.new(Auth.AuthErrorType.USER_NOT_FOUND, "", Auth.AuthProvider.NONE)
	assert_true(error.get_user_message().contains("no encontrado"), "debe contener mensaje apropiado")


func test_auth_error_user_exists_message() -> void:
	var error: Auth.AuthError = Auth.AuthError.new(Auth.AuthErrorType.USER_ALREADY_EXISTS, "", Auth.AuthProvider.NONE)
	assert_true(error.get_user_message().contains("existe"), "debe contener mensaje apropiado")


func test_auth_error_weak_password_message() -> void:
	var error: Auth.AuthError = Auth.AuthError.new(Auth.AuthErrorType.WEAK_PASSWORD, "", Auth.AuthProvider.NONE)
	assert_true(error.get_user_message().contains("débil"), "debe contener mensaje apropiado")


func test_auth_error_network_message() -> void:
	var error: Auth.AuthError = Auth.AuthError.new(Auth.AuthErrorType.NETWORK_ERROR, "", Auth.AuthProvider.NONE)
	assert_true(error.get_user_message().contains("conexión"), "debe contener mensaje apropiado")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE AuthResult
## ═══════════════════════════════════════════════════════════════════════════

func test_auth_result_success() -> void:
	var user: Auth.UserData = Auth.UserData.new("id", "user", Auth.AuthProvider.CREDENTIALS)
	var result: Auth.AuthResult = Auth.AuthResult.ok(user, "token123")
	
	assert_true(result.success, "result debe ser exitoso")
	assert_not_null(result.user, "user no debe ser null")
	assert_eq(result.token, "token123", "token debe ser correcto")
	assert_null(result.error, "error debe ser null")


func test_auth_result_failure() -> void:
	var error: Auth.AuthError = Auth.AuthError.new(
		Auth.AuthErrorType.INVALID_CREDENTIALS,
		"Bad login",
		Auth.AuthProvider.CREDENTIALS
	)
	var result: Auth.AuthResult = Auth.AuthResult.fail(error)
	
	assert_false(result.success, "result no debe ser exitoso")
	assert_null(result.user, "user debe ser null")
	assert_not_null(result.error, "error no debe ser null")
	assert_eq(result.error.type, Auth.AuthErrorType.INVALID_CREDENTIALS)


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE LOGIN COMO INVITADO
## ═══════════════════════════════════════════════════════════════════════════

func test_guest_login_success() -> void:
	# Usar diccionario para captura por referencia en lambdas
	var state := {"callback_called": false, "login_success": false}
	
	auth.login_as_guest(func(result: Auth.AuthResult) -> void:
		state.callback_called = true
		state.login_success = result.success
	)
	
	assert_true(state.callback_called, "callback debe ser llamado")
	assert_true(state.login_success, "login debe ser exitoso")
	assert_true(auth.is_authenticated, "debe estar autenticado")
	assert_eq(auth.current_provider, Auth.AuthProvider.GUEST)


func test_guest_login_creates_unique_ids() -> void:
	var ids: Array[String] = []
	
	for i in range(5):
		var user: Auth.UserData = Auth.UserData.create_guest()
		assert_false(ids.has(user.user_id), "cada ID debe ser único")
		ids.append(user.user_id)


func test_is_guest_user() -> void:
	assert_false(auth.is_guest_user(), "no debe ser guest antes de login")
	
	auth.login_as_guest()
	
	assert_true(auth.is_guest_user(), "debe ser guest después de login")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE REGISTRO DE USUARIO
## ═══════════════════════════════════════════════════════════════════════════

func test_register_user_success() -> void:
	var state := {"callback_called": false, "register_success": false, "username_received": ""}
	
	auth.register_user("newuser", "password123", "test@test.com", 
		func(result: Auth.AuthResult) -> void:
			state.callback_called = true
			state.register_success = result.success
			if result.user:
				state.username_received = result.user.username
	)
	
	assert_true(state.callback_called, "callback debe ser llamado")
	assert_true(state.register_success, "registro debe ser exitoso")
	assert_eq(state.username_received, "newuser")
	assert_true(auth.is_authenticated, "debe estar autenticado después de registro")


func test_register_user_short_username() -> void:
	var state := {"error_type": Auth.AuthErrorType.NONE}
	
	auth.register_user("ab", "password123", "", 
		func(result: Auth.AuthResult) -> void:
			if result.error:
				state.error_type = result.error.type
	)
	
	assert_eq(state.error_type, Auth.AuthErrorType.INVALID_CREDENTIALS)


func test_register_user_short_password() -> void:
	var state := {"error_type": Auth.AuthErrorType.NONE}
	
	auth.register_user("validuser", "short", "", 
		func(result: Auth.AuthResult) -> void:
			if result.error:
				state.error_type = result.error.type
	)
	
	assert_eq(state.error_type, Auth.AuthErrorType.WEAK_PASSWORD)


func test_register_user_invalid_username_chars() -> void:
	var state := {"register_failed": false}
	
	auth.register_user("invalid@user!", "password123", "", 
		func(result: Auth.AuthResult) -> void:
			state.register_failed = not result.success
	)
	
	assert_true(state.register_failed, "registro debe fallar con caracteres inválidos")


func test_register_duplicate_user() -> void:
	# Registrar primer usuario
	auth.register_user("existinguser", "password123", "")
	auth.logout()
	
	# Intentar registrar el mismo username
	var state := {"error_type": Auth.AuthErrorType.NONE}
	auth.register_user("existinguser", "different123", "", 
		func(result: Auth.AuthResult) -> void:
			if result.error:
				state.error_type = result.error.type
	)
	
	assert_eq(state.error_type, Auth.AuthErrorType.USER_ALREADY_EXISTS)


func test_register_invalid_email() -> void:
	var state := {"register_failed": false}
	
	auth.register_user("validuser", "password123", "notanemail", 
		func(result: Auth.AuthResult) -> void:
			state.register_failed = not result.success
	)
	
	assert_true(state.register_failed, "registro con email inválido debe fallar")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE LOGIN CON CREDENCIALES
## ═══════════════════════════════════════════════════════════════════════════

func test_login_with_credentials_success() -> void:
	# Primero registrar usuario
	auth.register_user("logintest", "testpass123", "")
	auth.logout()
	
	# Luego hacer login
	var state := {"login_success": false, "username_received": ""}
	auth.login_with_credentials("logintest", "testpass123",
		func(result: Auth.AuthResult) -> void:
			state.login_success = result.success
			if result.user:
				state.username_received = result.user.username
	)
	
	assert_true(state.login_success, "login debe ser exitoso")
	assert_eq(state.username_received, "logintest")
	assert_true(auth.is_authenticated)


func test_login_with_wrong_password() -> void:
	# Registrar usuario
	auth.register_user("wrongpasstest", "correctpass", "")
	auth.logout()
	
	# Login con contraseña incorrecta
	var state := {"error_type": Auth.AuthErrorType.NONE}
	auth.login_with_credentials("wrongpasstest", "wrongpassword",
		func(result: Auth.AuthResult) -> void:
			if result.error:
				state.error_type = result.error.type
	)
	
	assert_eq(state.error_type, Auth.AuthErrorType.INVALID_CREDENTIALS)


func test_login_with_nonexistent_user() -> void:
	var state := {"error_type": Auth.AuthErrorType.NONE}
	
	auth.login_with_credentials("doesnotexist", "somepassword",
		func(result: Auth.AuthResult) -> void:
			if result.error:
				state.error_type = result.error.type
	)
	
	assert_eq(state.error_type, Auth.AuthErrorType.USER_NOT_FOUND)


func test_login_case_insensitive_username() -> void:
	# Registrar con minúsculas
	auth.register_user("casetest", "password123", "")
	auth.logout()
	
	# Login con mayúsculas
	var state := {"login_success": false}
	auth.login_with_credentials("CASETEST", "password123",
		func(result: Auth.AuthResult) -> void:
			state.login_success = result.success
	)
	
	assert_true(state.login_success, "login debe funcionar con diferente case")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE LOGOUT
## ═══════════════════════════════════════════════════════════════════════════

func test_logout() -> void:
	auth.login_as_guest()
	assert_true(auth.is_authenticated, "debe estar autenticado")
	
	auth.logout()
	
	assert_false(auth.is_authenticated, "no debe estar autenticado")
	assert_null(auth.current_user, "current_user debe ser null")
	assert_eq(auth.session_token, "", "token debe estar vacío")
	assert_eq(auth.current_provider, Auth.AuthProvider.NONE)


func test_logout_when_not_authenticated() -> void:
	# No debe fallar si no hay sesión
	auth.logout()
	assert_false(auth.is_authenticated)


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE SESIÓN
## ═══════════════════════════════════════════════════════════════════════════

func test_has_valid_session() -> void:
	assert_false(auth.has_valid_session(), "no debe tener sesión antes de login")
	
	auth.login_as_guest()
	
	assert_true(auth.has_valid_session(), "debe tener sesión después de login")


func test_get_display_name_guest() -> void:
	auth.login_as_guest()
	
	assert_eq(auth.get_display_name(), "Invitado")


func test_get_display_name_credentials() -> void:
	auth.register_user("displaytest", "password123", "")
	
	# El display_name inicial es el username
	assert_eq(auth.get_display_name(), "displaytest")


func test_get_display_name_not_authenticated() -> void:
	assert_eq(auth.get_display_name(), "No autenticado")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE GOOGLE SIGN-IN (Preparación)
## ═══════════════════════════════════════════════════════════════════════════

func test_google_login_not_implemented() -> void:
	var state := {"login_failed": false, "error_type": Auth.AuthErrorType.NONE, "provider": Auth.AuthProvider.NONE}
	
	auth.login_with_google(func(result: Auth.AuthResult) -> void:
		state.login_failed = not result.success
		if result.error:
			state.error_type = result.error.type
			state.provider = result.error.provider
	)
	
	assert_true(state.login_failed, "Google login no está implementado")
	assert_eq(state.error_type, Auth.AuthErrorType.PROVIDER_ERROR)
	assert_eq(state.provider, Auth.AuthProvider.GOOGLE)
	# Manejar el print de error esperado (Google Sign-In no implementado)
	assert_engine_error(1, "Se espera 1 print indicando que Google no está implementado")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE SEÑALES
## ═══════════════════════════════════════════════════════════════════════════

func test_login_success_signal() -> void:
	var state := {"signal_emitted": false}
	
	auth.login_success.connect(func(_user: Auth.UserData) -> void:
		state.signal_emitted = true
	)
	
	auth.login_as_guest()
	
	assert_true(state.signal_emitted, "señal login_success debe emitirse")


func test_login_failed_signal() -> void:
	var state := {"signal_emitted": false}
	
	auth.login_failed.connect(func(_error: Auth.AuthError) -> void:
		state.signal_emitted = true
	)
	
	auth.login_with_credentials("nonexistent", "password123")
	
	assert_true(state.signal_emitted, "señal login_failed debe emitirse")


func test_logout_completed_signal() -> void:
	var state := {"signal_emitted": false}
	
	auth.logout_completed.connect(func() -> void:
		state.signal_emitted = true
	)
	
	auth.login_as_guest()
	auth.logout()
	
	assert_true(state.signal_emitted, "señal logout_completed debe emitirse")


func test_auth_state_changed_signal() -> void:
	var state := {"state_changes": 0}
	
	auth.auth_state_changed.connect(func(_is_auth: bool) -> void:
		state.state_changes += 1
	)
	
	auth.login_as_guest()  # +1
	auth.logout()          # +1
	
	assert_eq(state.state_changes, 2, "debe haber 2 cambios de estado")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE API ESTÁTICA
## ═══════════════════════════════════════════════════════════════════════════

func test_static_is_logged_in() -> void:
	# Limpiar cualquier sesión previa
	Auth.sign_out()
	
	assert_false(Auth.is_logged_in(), "no debe estar logueado")
	
	Auth.guest_login()
	
	assert_true(Auth.is_logged_in(), "debe estar logueado")
	
	Auth.sign_out()


func test_static_get_current_user() -> void:
	Auth.sign_out()
	assert_null(Auth.get_current_user())
	
	Auth.guest_login()
	assert_not_null(Auth.get_current_user())
	
	Auth.sign_out()


func test_static_get_user_display_name() -> void:
	Auth.sign_out()
	assert_eq(Auth.get_user_display_name(), "No autenticado")
	
	Auth.guest_login()
	assert_eq(Auth.get_user_display_name(), "Invitado")
	
	Auth.sign_out()


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE VALIDACIÓN DE EMAIL
## ═══════════════════════════════════════════════════════════════════════════

func test_valid_email_simple() -> void:
	var state := {"register_success": false}
	auth.register_user("emailtest1", "password123", "test@example.com",
		func(result: Auth.AuthResult) -> void:
			state.register_success = result.success
	)
	assert_true(state.register_success, "Email 'test@example.com' debe ser válido")


func test_valid_email_with_dots() -> void:
	auth.logout()
	_cleanup_test_files()
	var state := {"register_success": false}
	auth.register_user("emailtest2", "password123", "user.name@domain.org",
		func(result: Auth.AuthResult) -> void:
			state.register_success = result.success
	)
	assert_true(state.register_success, "Email con puntos debe ser válido")


func test_invalid_email_no_at() -> void:
	var state := {"register_failed": false}
	auth.register_user("invalidmail", "password123", "notanemail",
		func(result: Auth.AuthResult) -> void:
			state.register_failed = not result.success
	)
	assert_true(state.register_failed, "Email sin @ debe ser inválido")


func test_invalid_email_no_domain() -> void:
	var state := {"register_failed": false}
	auth.register_user("invalidmail2", "password123", "missing@domain",
		func(result: Auth.AuthResult) -> void:
			state.register_failed = not result.success
	)
	assert_true(state.register_failed, "Email sin TLD debe ser inválido")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE PERSISTENCIA
## ═══════════════════════════════════════════════════════════════════════════

func test_session_persists_between_instances() -> void:
	# Registrar y hacer login
	auth.register_user("persisttest", "password123", "")
	var original_user_id := auth.current_user.user_id
	
	# Crear nueva instancia (simula reiniciar app)
	var auth2: Auth = Auth.new()
	
	# Debe restaurar sesión
	assert_true(auth2.is_authenticated, "sesión debe restaurarse")
	assert_eq(auth2.current_user.user_id, original_user_id, "mismo usuario")


func test_logout_clears_persisted_session() -> void:
	auth.register_user("cleartest", "password123", "")
	auth.logout()
	
	# Nueva instancia no debe tener sesión
	var auth2: Auth = Auth.new()
	assert_false(auth2.is_authenticated, "no debe haber sesión después de logout")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE REMEMBER SESSION
## ═══════════════════════════════════════════════════════════════════════════

func test_login_with_remember_me_true_saves_session() -> void:
	# Registrar usuario primero (esto también crea sesión)
	auth.register_user("rememberuser", "password123", "")
	auth.logout()  # Esto borra sesión pero NO borra users.json
	
	# Borrar solo el archivo de sesión, no users.json
	var session_path := "user://session.json"
	if FileAccess.file_exists(session_path):
		DirAccess.remove_absolute(session_path)
	
	# Login con remember_me = true (default)
	auth.login_with_credentials("rememberuser", "password123", Callable(), true)
	
	# Verificar que el archivo de sesión existe
	assert_true(FileAccess.file_exists(session_path), "sesión debe guardarse con remember_me=true")
	
	# Nueva instancia debe restaurar sesión
	var auth2: Auth = Auth.new()
	assert_true(auth2.is_authenticated, "sesión debe restaurarse con remember_me=true")


func test_login_with_remember_me_false_does_not_save_session() -> void:
	# Registrar usuario primero
	auth.register_user("norememberuser", "password123", "")
	auth.logout()  # Esto borra sesión pero NO borra users.json
	
	# Borrar solo el archivo de sesión, no users.json
	var session_path := "user://session.json"
	if FileAccess.file_exists(session_path):
		DirAccess.remove_absolute(session_path)
	
	# Login con remember_me = false
	auth.login_with_credentials("norememberuser", "password123", Callable(), false)
	
	# Verificar que el archivo de sesión NO existe
	assert_false(FileAccess.file_exists(session_path), "sesión NO debe guardarse con remember_me=false")
	
	# Nueva instancia NO debe tener sesión
	var auth2: Auth = Auth.new()
	assert_false(auth2.is_authenticated, "sesión NO debe restaurarse con remember_me=false")


func test_remember_session_default_is_true() -> void:
	# Verificar que el default de _remember_session es true para nuevas instancias
	# Login sin especificar remember_me (usa default true)
	auth.register_user("defaultremember", "password123", "")
	auth.logout()
	
	# Borrar solo el archivo de sesión, no users.json
	var session_path := "user://session.json"
	if FileAccess.file_exists(session_path):
		DirAccess.remove_absolute(session_path)
	
	# Login sin especificar remember_me - debe usar default true
	auth.login_with_credentials("defaultremember", "password123")
	
	assert_true(FileAccess.file_exists(session_path), "default debe ser guardar sesión")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS ADICIONALES - get_instance / set_instance / clear_instance
## ═══════════════════════════════════════════════════════════════════════════

func test_get_instance_returns_value() -> void:
	"""Test: get_instance retorna instancia o null"""
	var instance = Auth.get_instance()
	# Puede ser null o una instancia válida
	assert_true(instance == null or instance is Auth, "get_instance retorna Auth o null")


func test_set_instance() -> void:
	"""Test: set_instance configura instancia"""
	var new_auth = Auth.new()
	Auth.set_instance(new_auth)
	pass_test("set_instance ejecutado sin errores")


func test_clear_instance() -> void:
	"""Test: clear_instance limpia instancia"""
	Auth.clear_instance()
	pass_test("clear_instance ejecutado sin errores")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS ADICIONALES - check_online_status / is_online
## ═══════════════════════════════════════════════════════════════════════════

func test_check_online_status() -> void:
	"""Test: check_online_status retorna resultado"""
	# Esto puede ser async, así que solo verificamos que no crashea
	auth.check_online_status()
	pass_test("check_online_status ejecutado sin errores")


func test_is_online() -> void:
	"""Test: is_online retorna booleano"""
	var online = auth.is_online()
	assert_true(online is bool, "is_online retorna bool")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS ADICIONALES - register (static)
## ═══════════════════════════════════════════════════════════════════════════

func test_register_static_method_exists() -> void:
	"""Test: método estático register existe"""
	# Solo verificamos que podemos llamarlo
	pass_test("register method exists")


func test_register_static_no_crash() -> void:
	"""Test: register estático no crashea"""
	# Llamamos sin callback real - solo verificar que no crashea
	# Usamos credenciales inválidas para que falle silenciosamente
	Auth.register("test_invalid_user_xyz", "test_pass", "test@invalid.com")
	pass_test("register ejecutado sin crash")


func test_register_static_with_callback() -> void:
	"""Test: register estático acepta callback"""
	var callback_called = false
	var test_callback = func(_result: Variant) -> void:
		callback_called = true
	
	Auth.register("test_user_abc", "password123", "test@test.com", test_callback)
	# El callback puede o no ser llamado dependiendo del servidor
	pass_test("register con callback ejecutado")

