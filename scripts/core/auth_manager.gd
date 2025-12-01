## AuthManager - Sistema de Autenticación Flexible para Steel Titans
## Autor: DAMSanti
## Versión: 2.0.0
##
## Sistema de autenticación diseñado para ser extensible.
## Soporta dos modos de operación:
##   - ONLINE: Usa DatabaseManager para conectar con el backend API
##   - OFFLINE: Usa almacenamiento local (desarrollo/fallback)
##
## El modo se detecta automáticamente según la disponibilidad del DatabaseManager
## y la conexión al servidor.
##
## Métodos de autenticación soportados:
##   - Login con usuario/contraseña
##   - Modo invitado (para testing y demo)
##   - (Preparado) Google Sign-In
##   - (Preparado) Apple Game Center
##
## Uso:
##   AuthManager.login("user", "pass", callback)
##   AuthManager.guest_login(callback)
##   AuthManager.sign_out()
##
## Note: Renamed to AuthManagerCore to avoid conflict with autoload singleton
class_name AuthManagerCore
extends RefCounted


## ═══════════════════════════════════════════════════════════════════════════
## SEÑALES
## ═══════════════════════════════════════════════════════════════════════════

## Emitida cuando el usuario inicia sesión exitosamente
signal login_success(user_data: UserData)

## Emitida cuando falla el login
signal login_failed(error: AuthError)

## Emitida cuando el usuario cierra sesión
signal logout_completed()

## Emitida cuando cambia el estado de autenticación
signal auth_state_changed(is_authenticated: bool)


## ═══════════════════════════════════════════════════════════════════════════
## TIPOS Y ENUMERACIONES
## ═══════════════════════════════════════════════════════════════════════════

## Proveedor de autenticación
enum AuthProvider {
	NONE,           ## No autenticado
	CREDENTIALS,    ## Usuario y contraseña
	GUEST,          ## Modo invitado
	GOOGLE,         ## Google Sign-In (futuro)
	APPLE,          ## Apple Game Center (futuro)
}

## Modo de operación
enum OperationMode {
	OFFLINE,        ## Almacenamiento local (desarrollo)
	ONLINE,         ## Conectado al backend API
}

## Tipos de error de autenticación
enum AuthErrorType {
	NONE,
	INVALID_CREDENTIALS,    ## Usuario o contraseña incorrectos
	USER_NOT_FOUND,         ## Usuario no existe
	USER_ALREADY_EXISTS,    ## Intentar registrar usuario existente
	WEAK_PASSWORD,          ## Contraseña muy débil
	NETWORK_ERROR,          ## Error de conexión
	SERVER_ERROR,           ## Error del servidor
	TOKEN_EXPIRED,          ## Token de sesión expirado
	PROVIDER_ERROR,         ## Error del proveedor (Google, etc)
	RATE_LIMITED,           ## Demasiados intentos
	UNKNOWN,                ## Error desconocido
}

## Nombres de proveedores para logging
const PROVIDER_NAMES: Dictionary = {
	AuthProvider.NONE: "none",
	AuthProvider.CREDENTIALS: "credentials",
	AuthProvider.GUEST: "guest",
	AuthProvider.GOOGLE: "google",
	AuthProvider.APPLE: "apple",
}

const MODE_NAMES: Dictionary = {
	OperationMode.OFFLINE: "offline",
	OperationMode.ONLINE: "online",
}


## ═══════════════════════════════════════════════════════════════════════════
## CLASE UserData - Datos del usuario autenticado
## ═══════════════════════════════════════════════════════════════════════════

class UserData extends RefCounted:
	var user_id: String = ""
	var username: String = ""
	var display_name: String = ""
	var email: String = ""
	var provider: AuthProvider = AuthProvider.NONE
	var is_guest: bool = false
	var created_at: int = 0
	var last_login: int = 0
	var metadata: Dictionary = {}
	
	func _init(
		p_user_id: String = "",
		p_username: String = "",
		p_provider: AuthProvider = AuthProvider.NONE
	) -> void:
		user_id = p_user_id
		username = p_username
		provider = p_provider
		is_guest = (provider == AuthProvider.GUEST)
		created_at = int(Time.get_unix_time_from_system())
		last_login = created_at
	
	## Crea un usuario invitado con ID único
	static func create_guest() -> UserData:
		var guest_id := "guest_%s_%d" % [
			_generate_random_string(8),
			Time.get_unix_time_from_system()
		]
		var user := UserData.new(guest_id, "Guest", AuthProvider.GUEST)
		user.display_name = "Invitado"
		user.is_guest = true
		return user
	
	## Genera string aleatorio para IDs
	static func _generate_random_string(length: int) -> String:
		const CHARS := "abcdefghijklmnopqrstuvwxyz0123456789"
		var result := ""
		for i in range(length):
			result += CHARS[randi() % CHARS.length()]
		return result
	
	## Serializa a diccionario para guardar
	func to_dict() -> Dictionary:
		return {
			"user_id": user_id,
			"username": username,
			"display_name": display_name,
			"email": email,
			"provider": provider,
			"is_guest": is_guest,
			"created_at": created_at,
			"last_login": last_login,
			"metadata": metadata,
		}
	
	## Crea UserData desde diccionario
	static func from_dict(data: Dictionary) -> UserData:
		var user := UserData.new()
		user.user_id = data.get("user_id", "")
		user.username = data.get("username", "")
		user.display_name = data.get("display_name", "")
		user.email = data.get("email", "")
		user.provider = data.get("provider", AuthProvider.NONE)
		user.is_guest = data.get("is_guest", false)
		user.created_at = data.get("created_at", 0)
		user.last_login = data.get("last_login", 0)
		user.metadata = data.get("metadata", {})
		return user


## ═══════════════════════════════════════════════════════════════════════════
## CLASE AuthError - Error de autenticación
## ═══════════════════════════════════════════════════════════════════════════

class AuthError extends RefCounted:
	var type: AuthErrorType = AuthErrorType.NONE
	var message: String = ""
	var provider: AuthProvider = AuthProvider.NONE
	var details: Dictionary = {}
	
	func _init(
		p_type: AuthErrorType = AuthErrorType.NONE,
		p_message: String = "",
		p_provider: AuthProvider = AuthProvider.NONE
	) -> void:
		type = p_type
		message = p_message
		provider = p_provider
	
	## Mensaje de error localizado para mostrar al usuario
	func get_user_message() -> String:
		match type:
			AuthErrorType.INVALID_CREDENTIALS:
				return "Usuario o contraseña incorrectos"
			AuthErrorType.USER_NOT_FOUND:
				return "Usuario no encontrado"
			AuthErrorType.USER_ALREADY_EXISTS:
				return "El usuario ya existe"
			AuthErrorType.WEAK_PASSWORD:
				return "La contraseña es muy débil. Usa al menos 8 caracteres"
			AuthErrorType.NETWORK_ERROR:
				return "Error de conexión. Comprueba tu internet"
			AuthErrorType.SERVER_ERROR:
				return "Error del servidor. Inténtalo más tarde"
			AuthErrorType.TOKEN_EXPIRED:
				return "Tu sesión ha expirado. Inicia sesión de nuevo"
			AuthErrorType.RATE_LIMITED:
				return "Demasiados intentos. Espera un momento"
			_:
				return "Error desconocido. Inténtalo de nuevo"


## ═══════════════════════════════════════════════════════════════════════════
## CLASE AuthResult - Resultado de operación de autenticación
## ═══════════════════════════════════════════════════════════════════════════

class AuthResult extends RefCounted:
	var success: bool = false
	var user: UserData = null
	var error: AuthError = null
	var token: String = ""
	
	static func ok(user_data: UserData, auth_token: String = "") -> AuthResult:
		var result := AuthResult.new()
		result.success = true
		result.user = user_data
		result.token = auth_token
		return result
	
	static func fail(auth_error: AuthError) -> AuthResult:
		var result := AuthResult.new()
		result.success = false
		result.error = auth_error
		return result


## ═══════════════════════════════════════════════════════════════════════════
## ESTADO DEL MANAGER
## ═══════════════════════════════════════════════════════════════════════════

## Instancia singleton
static var _instance: AuthManagerCore = null

## Usuario actual autenticado
var current_user: UserData = null

## Token de sesión actual
var session_token: String = ""

## Proveedor actual
var current_provider: AuthProvider = AuthProvider.NONE

## Si está autenticado
var is_authenticated: bool = false

## Si debe recordar la sesión
var _remember_session: bool = true

## Path para almacenamiento local de sesión
const SESSION_FILE_PATH := "user://session.json"

## Path para almacenamiento local de usuarios (desarrollo)
const USERS_FILE_PATH := "user://users.json"

## Configuración de validación de contraseña
const MIN_PASSWORD_LENGTH := 8
const MIN_USERNAME_LENGTH := 3
const MAX_USERNAME_LENGTH := 20

## Logger reference
var _logger: Variant = null

## DatabaseManager reference (for online mode)
var _database: Variant = null

## Current operation mode
var operation_mode: OperationMode = OperationMode.OFFLINE


## ═══════════════════════════════════════════════════════════════════════════
## SINGLETON
## ═══════════════════════════════════════════════════════════════════════════

## Instancia singleton (usar get_instance() para acceder)
## La instancia se crea automáticamente cuando se accede por primera vez
## o puede ser inyectada manualmente con set_instance() para testing.

## Obtiene la instancia singleton
static func get_instance() -> AuthManagerCore:
	if _instance == null:
		_instance = AuthManagerCore.new()
	return _instance

## Establece la instancia singleton (útil para testing)
static func set_instance(instance: AuthManagerCore) -> void:
	_instance = instance

## Limpia la instancia singleton (útil para testing)
static func clear_instance() -> void:
	_instance = null


## ═══════════════════════════════════════════════════════════════════════════
## INICIALIZACIÓN
## ═══════════════════════════════════════════════════════════════════════════

func _init() -> void:
	_init_logger()
	_init_database()
	_try_restore_session()


## Inicializa el logger si está disponible
func _init_logger() -> void:
	# El logger está registrado como autoload "Log"
	# Usamos Engine.has_singleton para verificar disponibilidad en runtime
	if Engine.has_singleton("Log"):
		_logger = Engine.get_singleton("Log")
	else:
		# Fallback: Logger no disponible (por ejemplo, en tests unitarios puros)
		_logger = null


## Inicializa la conexión al DatabaseManager si está disponible
func _init_database() -> void:
	# Buscar DatabaseManager como autoload
	if Engine.has_singleton("Database"):
		_database = Engine.get_singleton("Database")
		_log_info("DatabaseManager encontrado, modo online disponible")
	else:
		_database = null
		_log_info("DatabaseManager no encontrado, usando modo offline")


## Intenta conectar con el backend y determina el modo de operación
func check_online_status() -> void:
	if _database == null:
		operation_mode = OperationMode.OFFLINE
		_log_info("Modo offline (sin DatabaseManager)")
		return
	
	# Verificar conexión con el servidor
	_log_info("Verificando conexión con el servidor...")
	var result: Dictionary = await _database.check_health()
	
	if result.success:
		operation_mode = OperationMode.ONLINE
		_log_info("Modo online - Conectado al servidor")
	else:
		operation_mode = OperationMode.OFFLINE
		_log_warning("Modo offline - Servidor no disponible: %s" % result.get("error", {}).get("message", "unknown"))


## Retorna true si está en modo online
func is_online() -> bool:
	return operation_mode == OperationMode.ONLINE and _database != null


## Intenta restaurar sesión guardada
func _try_restore_session() -> void:
	if not FileAccess.file_exists(SESSION_FILE_PATH):
		return
	
	var file := FileAccess.open(SESSION_FILE_PATH, FileAccess.READ)
	if file == null:
		return
	
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		_log_warning("No se pudo parsear sesión guardada")
		return
	
	var data: Dictionary = json.data
	if not data.has("user") or not data.has("token"):
		return
	
	# Verificar que el token no ha expirado
	var expires_at: int = data.get("expires_at", 0)
	if expires_at > 0 and Time.get_unix_time_from_system() > expires_at:
		_log_info("Sesión expirada, requiere nuevo login")
		_clear_session_file()
		return
	
	# Restaurar sesión
	current_user = UserData.from_dict(data["user"])
	session_token = data["token"]
	current_provider = current_user.provider
	is_authenticated = true
	
	_log_info("Sesión restaurada para: %s" % current_user.username)


## ═══════════════════════════════════════════════════════════════════════════
## LOGIN CON CREDENCIALES
## ═══════════════════════════════════════════════════════════════════════════

## Login con usuario y contraseña
## callback: func(result: AuthResult) -> void
## remember_me: si es true, guarda la sesión para auto-login
func login_with_credentials(
	username: String,
	password: String,
	callback: Callable = Callable(),
	remember_me: bool = true
) -> void:
	_log_info("Intentando login con credenciales: %s (modo: %s, remember: %s)" % [username, MODE_NAMES[operation_mode], remember_me])
	
	# Guardar preferencia para usarla en _set_authenticated
	_remember_session = remember_me
	
	# Validar entrada
	var validation_error := _validate_credentials(username, password)
	if validation_error != null:
		_emit_login_result(AuthResult.fail(validation_error), callback)
		return
	
	# Modo online: usar API
	if is_online():
		await _login_online(username, password, callback)
		return
	
	# Modo offline: usar almacenamiento local
	_login_offline(username, password, callback)


## Login usando el backend API
func _login_online(username: String, password: String, callback: Callable) -> void:
	var result: Dictionary = await _database.login(username, password)
	
	if result.success:
		var data: Dictionary = result.data
		var user := _create_user_from_api_response(data)
		var token: String = data.get("access_token", "") as String
		
		_set_authenticated(user, token, AuthProvider.CREDENTIALS)
		_emit_login_result(AuthResult.ok(user, token), callback)
	else:
		var error := _create_error_from_api_response(result, AuthProvider.CREDENTIALS)
		_emit_login_result(AuthResult.fail(error), callback)


## Login usando almacenamiento local (desarrollo/offline)
func _login_offline(username: String, password: String, callback: Callable) -> void:
	# Buscar usuario en almacenamiento local (desarrollo)
	var user_result: Dictionary = _find_user_by_username(username)
	if user_result.is_empty():
		var not_found_error := AuthError.new(
			AuthErrorType.USER_NOT_FOUND,
			"Usuario no encontrado",
			AuthProvider.CREDENTIALS
		)
		_emit_login_result(AuthResult.fail(not_found_error), callback)
		return
	
	# Verificar contraseña
	if not _verify_password(password, user_result["password_hash"]):
		var invalid_error := AuthError.new(
			AuthErrorType.INVALID_CREDENTIALS,
			"Contraseña incorrecta",
			AuthProvider.CREDENTIALS
		)
		_emit_login_result(AuthResult.fail(invalid_error), callback)
		return
	
	# Login exitoso
	var user := UserData.from_dict(user_result["user_data"])
	user.last_login = int(Time.get_unix_time_from_system())
	var token := _generate_session_token()
	
	_set_authenticated(user, token, AuthProvider.CREDENTIALS)
	_emit_login_result(AuthResult.ok(user, token), callback)


## Valida formato de credenciales
func _validate_credentials(username: String, password: String) -> AuthError:
	if username.length() < MIN_USERNAME_LENGTH:
		return AuthError.new(
			AuthErrorType.INVALID_CREDENTIALS,
			"Usuario muy corto",
			AuthProvider.CREDENTIALS
		)
	
	if password.length() < MIN_PASSWORD_LENGTH:
		return AuthError.new(
			AuthErrorType.WEAK_PASSWORD,
			"Contraseña muy corta",
			AuthProvider.CREDENTIALS
		)
	
	return null


## ═══════════════════════════════════════════════════════════════════════════
## REGISTRO DE USUARIO
## ═══════════════════════════════════════════════════════════════════════════

## Registra nuevo usuario con credenciales
func register_user(
	username: String,
	password: String,
	email: String = "",
	callback: Callable = Callable()
) -> void:
	_log_info("Intentando registrar usuario: %s (modo: %s)" % [username, MODE_NAMES[operation_mode]])
	
	# Validar entrada
	var validation_error := _validate_registration(username, password, email)
	if validation_error != null:
		_emit_login_result(AuthResult.fail(validation_error), callback)
		return
	
	# Modo online: usar API
	if is_online():
		await _register_online(username, password, email, callback)
		return
	
	# Modo offline: usar almacenamiento local
	_register_offline(username, password, email, callback)


## Registro usando el backend API
func _register_online(username: String, password: String, email: String, callback: Callable) -> void:
	var result: Dictionary = await _database.register_user(username, email, password)
	
	if result.success:
		var data: Dictionary = result.data
		_log_info("Usuario registrado en servidor: %s" % username)
		
		# Auto-login después de registro
		var login_result: Dictionary = await _database.login(username, password)
		if login_result.success:
			var user := _create_user_from_api_response(login_result.data)
			var token: String = login_result.data.get("access_token", "") as String
			_set_authenticated(user, token, AuthProvider.CREDENTIALS)
			_emit_login_result(AuthResult.ok(user, token), callback)
		else:
			# Registro exitoso pero login falló
			var user := UserData.new(data.get("id", ""), username, AuthProvider.CREDENTIALS)
			user.email = email
			_emit_login_result(AuthResult.ok(user, ""), callback)
	else:
		var error := _create_error_from_api_response(result, AuthProvider.CREDENTIALS)
		_emit_login_result(AuthResult.fail(error), callback)


## Registro usando almacenamiento local (desarrollo/offline)
func _register_offline(username: String, password: String, email: String, callback: Callable) -> void:
	# Verificar que no existe
	var existing: Dictionary = _find_user_by_username(username)
	if not existing.is_empty():
		var exists_error := AuthError.new(
			AuthErrorType.USER_ALREADY_EXISTS,
			"El usuario ya existe",
			AuthProvider.CREDENTIALS
		)
		_emit_login_result(AuthResult.fail(exists_error), callback)
		return
	
	# Crear usuario
	var user_id := "user_%s_%d" % [
		UserData._generate_random_string(12),
		Time.get_unix_time_from_system()
	]
	var user := UserData.new(user_id, username, AuthProvider.CREDENTIALS)
	user.display_name = username
	user.email = email
	
	# Guardar usuario
	var password_hash := _hash_password(password)
	_save_user(user, password_hash)
	
	# Auto-login después de registro
	var token := _generate_session_token()
	_set_authenticated(user, token, AuthProvider.CREDENTIALS)
	
	var result := AuthResult.ok(user, token)
	_emit_login_result(result, callback)
	
	_log_info("Usuario registrado exitosamente (offline): %s" % username)


## Valida datos de registro
func _validate_registration(
	username: String,
	password: String,
	email: String
) -> AuthError:
	# Validar username
	if username.length() < MIN_USERNAME_LENGTH:
		return AuthError.new(
			AuthErrorType.INVALID_CREDENTIALS,
			"Usuario debe tener al menos %d caracteres" % MIN_USERNAME_LENGTH,
			AuthProvider.CREDENTIALS
		)
	
	if username.length() > MAX_USERNAME_LENGTH:
		return AuthError.new(
			AuthErrorType.INVALID_CREDENTIALS,
			"Usuario no puede tener más de %d caracteres" % MAX_USERNAME_LENGTH,
			AuthProvider.CREDENTIALS
		)
	
	# Solo alfanuméricos y guiones bajos
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	if not regex.search(username):
		return AuthError.new(
			AuthErrorType.INVALID_CREDENTIALS,
			"Usuario solo puede contener letras, números y guiones bajos",
			AuthProvider.CREDENTIALS
		)
	
	# Validar password
	if password.length() < MIN_PASSWORD_LENGTH:
		return AuthError.new(
			AuthErrorType.WEAK_PASSWORD,
			"Contraseña debe tener al menos %d caracteres" % MIN_PASSWORD_LENGTH,
			AuthProvider.CREDENTIALS
		)
	
	# Validar email si se proporciona
	if email != "" and not _is_valid_email(email):
		return AuthError.new(
			AuthErrorType.INVALID_CREDENTIALS,
			"Email no válido",
			AuthProvider.CREDENTIALS
		)
	
	return null


## Valida formato de email
func _is_valid_email(email: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	return regex.search(email) != null


## ═══════════════════════════════════════════════════════════════════════════
## LOGIN DE INVITADO
## ═══════════════════════════════════════════════════════════════════════════

## Login como invitado (sin cuenta)
func login_as_guest(callback: Callable = Callable()) -> void:
	_log_info("Iniciando sesión como invitado (modo: %s)" % MODE_NAMES[operation_mode])
	
	# Modo online: usar API
	if is_online():
		await _guest_login_online(callback)
		return
	
	# Modo offline: crear guest local
	_guest_login_offline(callback)


## Guest login usando el backend API
func _guest_login_online(callback: Callable) -> void:
	# Generar device_id único para este dispositivo
	var device_id := _get_or_create_device_id()
	var result: Dictionary = await _database.login_guest(device_id)
	
	if result.success:
		var data: Dictionary = result.data
		var user := _create_user_from_api_response(data)
		user.is_guest = true
		user.provider = AuthProvider.GUEST
		var token: String = data.get("access_token", "") as String
		
		_set_authenticated(user, token, AuthProvider.GUEST)
		_emit_login_result(AuthResult.ok(user, token), callback)
	else:
		var error := _create_error_from_api_response(result, AuthProvider.GUEST)
		_emit_login_result(AuthResult.fail(error), callback)


## Guest login local (offline)
func _guest_login_offline(callback: Callable) -> void:
	var user := UserData.create_guest()
	var token := _generate_session_token()
	
	_set_authenticated(user, token, AuthProvider.GUEST)
	
	var result := AuthResult.ok(user, token)
	_emit_login_result(result, callback)


## Obtiene o crea un device ID único para este dispositivo
func _get_or_create_device_id() -> String:
	const DEVICE_ID_PATH := "user://device_id.txt"
	
	if FileAccess.file_exists(DEVICE_ID_PATH):
		var read_file := FileAccess.open(DEVICE_ID_PATH, FileAccess.READ)
		if read_file:
			var existing_id := read_file.get_as_text().strip_edges()
			read_file.close()
			if not existing_id.is_empty():
				return existing_id
	
	# Crear nuevo device_id
	var device_id := "device_%s_%d" % [
		UserData._generate_random_string(16),
		Time.get_unix_time_from_system()
	]
	
	var write_file := FileAccess.open(DEVICE_ID_PATH, FileAccess.WRITE)
	if write_file:
		write_file.store_string(device_id)
		write_file.close()
	
	return device_id


## ═══════════════════════════════════════════════════════════════════════════
## GOOGLE SIGN-IN (PREPARADO PARA FUTURO)
## ═══════════════════════════════════════════════════════════════════════════

## Login con Google (requiere Google Play Developer Account)
## Este método está preparado pero no implementado
func login_with_google(callback: Callable = Callable()) -> void:
	_log_warning("Google Sign-In no implementado aún")
	
	var error := AuthError.new(
		AuthErrorType.PROVIDER_ERROR,
		"Google Sign-In no está disponible todavía",
		AuthProvider.GOOGLE
	)
	error.details["reason"] = "requires_developer_account"
	error.details["help"] = "Esta función requiere una cuenta de Google Play Developer ($25)"
	
	var result := AuthResult.fail(error)
	_emit_login_result(result, callback)


## Procesa token de Google (para implementar cuando se active)
## Este método se usará cuando se integre el plugin de Google Sign-In
func _process_google_token(
	_id_token: String,
	_callback: Callable
) -> void:
	# TODO: Implementar cuando se tenga Google Play Developer Account
	# 1. Verificar id_token con el servidor
	# 2. Obtener datos del usuario de Google
	# 3. Crear/actualizar UserData
	# 4. Generar session token
	pass


## ═══════════════════════════════════════════════════════════════════════════
## LOGOUT
## ═══════════════════════════════════════════════════════════════════════════

## Cierra la sesión actual
func logout() -> void:
	if not is_authenticated:
		return
	
	var username := current_user.username if current_user else "unknown"
	_log_info("Cerrando sesión: %s (modo: %s)" % [username, MODE_NAMES[operation_mode]])
	
	# Si estamos online, notificar al servidor
	if is_online() and session_token != "":
		var _result: Dictionary = await _database.logout()
		# No importa si falla, cerramos sesión local de todos modos
	
	# Limpiar estado local
	_clear_local_session()


## Limpia la sesión local sin llamar al servidor
func _clear_local_session() -> void:
	current_user = null
	session_token = ""
	current_provider = AuthProvider.NONE
	is_authenticated = false
	
	# Eliminar sesión guardada
	_clear_session_file()
	
	# Limpiar tokens del DatabaseManager si existe
	if _database and _database.has_method("clear_tokens"):
		_database.clear_tokens()
	
	# Emitir señales
	logout_completed.emit()
	auth_state_changed.emit(false)


## ═══════════════════════════════════════════════════════════════════════════
## VERIFICACIÓN DE SESIÓN
## ═══════════════════════════════════════════════════════════════════════════

## Verifica si hay una sesión activa válida
func has_valid_session() -> bool:
	return is_authenticated and current_user != null and session_token != ""


## Verifica si el usuario actual es invitado
func is_guest_user() -> bool:
	return is_authenticated and current_provider == AuthProvider.GUEST


## Obtiene el nombre para mostrar del usuario actual
func get_display_name() -> String:
	if current_user:
		return current_user.display_name if current_user.display_name else current_user.username
	return "No autenticado"


## ═══════════════════════════════════════════════════════════════════════════
## PERSISTENCIA LOCAL (DESARROLLO)
## ═══════════════════════════════════════════════════════════════════════════

## Busca usuario por nombre
## Devuelve Dictionary con datos o Dictionary vacío si no existe
func _find_user_by_username(username: String) -> Dictionary:
	var users := _load_users_db()
	var username_lower := username.to_lower()
	
	for uid in users:
		var user_data: Dictionary = users[uid]
		if user_data.get("user_data", {}).get("username", "").to_lower() == username_lower:
			return user_data
	
	return {}


## Carga base de datos local de usuarios
func _load_users_db() -> Dictionary:
	if not FileAccess.file_exists(USERS_FILE_PATH):
		return {}
	
	var file := FileAccess.open(USERS_FILE_PATH, FileAccess.READ)
	if file == null:
		return {}
	
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		return {}
	
	return json.data if json.data is Dictionary else {}


## Guarda usuario en base de datos local
func _save_user(user: UserData, password_hash: String) -> void:
	var users := _load_users_db()
	
	users[user.user_id] = {
		"user_data": user.to_dict(),
		"password_hash": password_hash,
		"created_at": Time.get_unix_time_from_system()
	}
	
	var file := FileAccess.open(USERS_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(users, "\t"))
		file.close()


## Guarda sesión actual
func _save_session() -> void:
	if not is_authenticated or current_user == null:
		return
	
	var session_data := {
		"user": current_user.to_dict(),
		"token": session_token,
		"provider": current_provider,
		"expires_at": Time.get_unix_time_from_system() + 86400 * 30  # 30 días
	}
	
	var file := FileAccess.open(SESSION_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(session_data, "\t"))
		file.close()


## Elimina archivo de sesión
func _clear_session_file() -> void:
	if FileAccess.file_exists(SESSION_FILE_PATH):
		DirAccess.remove_absolute(SESSION_FILE_PATH)


## ═══════════════════════════════════════════════════════════════════════════
## UTILIDADES DE SEGURIDAD
## ═══════════════════════════════════════════════════════════════════════════

## Hash de contraseña (usar bcrypt en producción)
func _hash_password(password: String) -> String:
	# En producción, usar bcrypt o argon2
	# Por ahora, SHA-256 con salt
	var salt := UserData._generate_random_string(16)
	var to_hash := salt + password
	var hashed := to_hash.sha256_text()
	return salt + ":" + hashed


## Verifica contraseña contra hash
func _verify_password(password: String, stored_hash: String) -> bool:
	var parts := stored_hash.split(":")
	if parts.size() != 2:
		return false
	
	var salt := parts[0]
	var expected_hash := parts[1]
	var to_hash := salt + password
	var actual_hash := to_hash.sha256_text()
	
	return actual_hash == expected_hash


## Genera token de sesión único
func _generate_session_token() -> String:
	var random_part := UserData._generate_random_string(32)
	var time_part := str(Time.get_unix_time_from_system())
	var combined := random_part + time_part
	return combined.sha256_text()


## ═══════════════════════════════════════════════════════════════════════════
## HELPERS INTERNOS
## ═══════════════════════════════════════════════════════════════════════════

## Establece estado autenticado
func _set_authenticated(user: UserData, token: String, provider: AuthProvider) -> void:
	current_user = user
	session_token = token
	current_provider = provider
	is_authenticated = true
	
	# Solo guardar sesión si remember_session está activo
	if _remember_session:
		_save_session()
	
	auth_state_changed.emit(true)


## Emite resultado de login
func _emit_login_result(result: AuthResult, callback: Callable) -> void:
	if result.success:
		login_success.emit(result.user)
	else:
		login_failed.emit(result.error)
	
	if callback.is_valid():
		callback.call(result)


## Crea UserData desde respuesta de API
func _create_user_from_api_response(data: Dictionary) -> UserData:
	var user_data: Dictionary = data.get("user", data)
	var user := UserData.new(
		str(user_data.get("id", "")),
		str(user_data.get("username", "")),
		AuthProvider.CREDENTIALS
	)
	user.display_name = str(user_data.get("display_name", user.username))
	user.email = str(user_data.get("email", ""))
	user.is_guest = user_data.get("is_guest", false) as bool
	user.created_at = user_data.get("created_at", 0) as int
	user.last_login = int(Time.get_unix_time_from_system())
	
	if user.is_guest:
		user.provider = AuthProvider.GUEST
	
	return user


## Crea AuthError desde respuesta de API
func _create_error_from_api_response(result: Dictionary, provider: AuthProvider) -> AuthError:
	var error_data: Dictionary = result.get("error", {})
	var code: String = str(error_data.get("code", "UNKNOWN"))
	var message: String = str(error_data.get("message", "Error desconocido"))
	var status_code: int = result.get("status_code", 0) as int
	
	var error_type := AuthErrorType.UNKNOWN
	
	# Mapear código de error de API a tipo de AuthError
	match code:
		"INVALID_CREDENTIALS", "UNAUTHORIZED":
			error_type = AuthErrorType.INVALID_CREDENTIALS
		"USER_NOT_FOUND":
			error_type = AuthErrorType.USER_NOT_FOUND
		"USER_ALREADY_EXISTS", "USERNAME_TAKEN", "EMAIL_TAKEN":
			error_type = AuthErrorType.USER_ALREADY_EXISTS
		"WEAK_PASSWORD":
			error_type = AuthErrorType.WEAK_PASSWORD
		"NETWORK_ERROR", "CONNECTION_ERROR":
			error_type = AuthErrorType.NETWORK_ERROR
		"SERVER_ERROR", "INTERNAL_ERROR":
			error_type = AuthErrorType.SERVER_ERROR
		"TOKEN_EXPIRED", "TOKEN_INVALID":
			error_type = AuthErrorType.TOKEN_EXPIRED
		"RATE_LIMITED", "TOO_MANY_REQUESTS":
			error_type = AuthErrorType.RATE_LIMITED
		_:
			# Inferir por status code
			if status_code == 401:
				error_type = AuthErrorType.INVALID_CREDENTIALS
			elif status_code == 404:
				error_type = AuthErrorType.USER_NOT_FOUND
			elif status_code == 409:
				error_type = AuthErrorType.USER_ALREADY_EXISTS
			elif status_code == 429:
				error_type = AuthErrorType.RATE_LIMITED
			elif status_code >= 500:
				error_type = AuthErrorType.SERVER_ERROR
			elif status_code == 0:
				error_type = AuthErrorType.NETWORK_ERROR
	
	var auth_error := AuthError.new(error_type, message, provider)
	auth_error.details = {
		"api_code": code,
		"status_code": status_code
	}
	
	return auth_error


## ═══════════════════════════════════════════════════════════════════════════
## LOGGING
## ═══════════════════════════════════════════════════════════════════════════

func _log_info(message: String) -> void:
	if _logger:
		_logger.info("[AuthManager] " + message)
	else:
		print("[AuthManager] INFO: " + message)


func _log_warning(message: String) -> void:
	if _logger:
		_logger.warning("[AuthManager] " + message)
	else:
		push_warning("[AuthManager] " + message)


func _log_error(message: String) -> void:
	if _logger:
		_logger.error("[AuthManager] " + message)
	else:
		push_error("[AuthManager] " + message)


## ═══════════════════════════════════════════════════════════════════════════
## API ESTÁTICA (CONVENIENCIA)
## ═══════════════════════════════════════════════════════════════════════════

## Login con credenciales (estático)
static func login(
	username: String,
	password: String,
	callback: Callable = Callable()
) -> void:
	get_instance().login_with_credentials(username, password, callback)


## Registro de usuario (estático)
static func register(
	username: String,
	password: String,
	email: String = "",
	callback: Callable = Callable()
) -> void:
	get_instance().register_user(username, password, email, callback)


## Login como invitado (estático)
static func guest_login(callback: Callable = Callable()) -> void:
	get_instance().login_as_guest(callback)


## Logout (estático)
static func sign_out() -> void:
	get_instance().logout()


## Verifica sesión (estático)
static func is_logged_in() -> bool:
	return get_instance().has_valid_session()


## Obtiene usuario actual (estático)
static func get_current_user() -> UserData:
	return get_instance().current_user


## Obtiene nombre para mostrar (estático)
static func get_user_display_name() -> String:
	return get_instance().get_display_name()
