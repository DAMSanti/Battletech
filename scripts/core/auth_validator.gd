## AuthValidator - Validación de credenciales de autenticación
## Separa la lógica de validación de la UI (SRP - Single Responsibility Principle)
## Esta clase es pura lógica sin dependencias de UI, fácilmente testeable
class_name AuthValidator
extends RefCounted

## Resultado de validación
class ValidationResult:
	extends RefCounted
	
	var is_valid: bool = true
	var error_message: String = ""
	var field: String = ""  # Campo que falló la validación
	
	static func success() -> ValidationResult:
		var result := ValidationResult.new()
		result.is_valid = true
		return result
	
	static func failure(message: String, field_name: String = "") -> ValidationResult:
		var result := ValidationResult.new()
		result.is_valid = false
		result.error_message = message
		result.field = field_name
		return result


## Configuración de validación (puede ser inyectada para testing)
var min_username_length: int = 3
var max_username_length: int = 20
var min_password_length: int = 6
var username_pattern: String = "^[a-zA-Z0-9_]+$"
var email_pattern: String = "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"  # No permite espacios

## RegEx compilados (lazy initialization)
var _username_regex: RegEx = null
var _email_regex: RegEx = null


func _get_username_regex() -> RegEx:
	if _username_regex == null:
		_username_regex = RegEx.new()
		_username_regex.compile(username_pattern)
	return _username_regex


func _get_email_regex() -> RegEx:
	if _email_regex == null:
		_email_regex = RegEx.new()
		_email_regex.compile(email_pattern)
	return _email_regex


# =============================================================================
# VALIDACIÓN DE LOGIN
# =============================================================================

## Valida las credenciales de login
func validate_login(username: String, password: String) -> ValidationResult:
	var username_result := validate_username_for_login(username)
	if not username_result.is_valid:
		return username_result
	
	var password_result := validate_password_for_login(password)
	if not password_result.is_valid:
		return password_result
	
	return ValidationResult.success()


## Valida solo el username para login (menos restrictivo que registro)
func validate_username_for_login(username: String) -> ValidationResult:
	var clean_username := username.strip_edges()
	
	if clean_username.is_empty():
		return ValidationResult.failure("Please enter your username", "username")
	
	if clean_username.length() < min_username_length:
		return ValidationResult.failure(
			"Username must be at least %d characters" % min_username_length,
			"username"
		)
	
	return ValidationResult.success()


## Valida solo el password para login (menos restrictivo)
func validate_password_for_login(password: String) -> ValidationResult:
	if password.is_empty():
		return ValidationResult.failure("Please enter your password", "password")
	
	return ValidationResult.success()


# =============================================================================
# VALIDACIÓN DE REGISTRO
# =============================================================================

## Valida todos los campos de registro
func validate_registration(
	username: String,
	password: String,
	confirm_password: String,
	email: String = ""
) -> ValidationResult:
	# Validar username
	var username_result := validate_username_for_registration(username)
	if not username_result.is_valid:
		return username_result
	
	# Validar email (si se proporciona)
	if not email.strip_edges().is_empty():
		var email_result := validate_email(email)
		if not email_result.is_valid:
			return email_result
	
	# Validar password
	var password_result := validate_password_for_registration(password)
	if not password_result.is_valid:
		return password_result
	
	# Validar confirmación
	var confirm_result := validate_password_confirmation(password, confirm_password)
	if not confirm_result.is_valid:
		return confirm_result
	
	return ValidationResult.success()


## Valida username para registro (más restrictivo)
func validate_username_for_registration(username: String) -> ValidationResult:
	var clean_username := username.strip_edges()
	
	if clean_username.is_empty():
		return ValidationResult.failure("Please enter a username", "username")
	
	if clean_username.length() < min_username_length:
		return ValidationResult.failure(
			"Username must be at least %d characters" % min_username_length,
			"username"
		)
	
	if clean_username.length() > max_username_length:
		return ValidationResult.failure(
			"Username must be %d characters or less" % max_username_length,
			"username"
		)
	
	# Validar caracteres permitidos
	if not _get_username_regex().search(clean_username):
		return ValidationResult.failure(
			"Username can only contain letters, numbers and underscore",
			"username"
		)
	
	return ValidationResult.success()


## Valida password para registro
func validate_password_for_registration(password: String) -> ValidationResult:
	if password.is_empty():
		return ValidationResult.failure("Please enter a password", "password")
	
	if password.length() < min_password_length:
		return ValidationResult.failure(
			"Password must be at least %d characters" % min_password_length,
			"password"
		)
	
	return ValidationResult.success()


## Valida que las contraseñas coincidan
func validate_password_confirmation(password: String, confirm: String) -> ValidationResult:
	if password != confirm:
		return ValidationResult.failure("Passwords do not match", "confirm_password")
	
	return ValidationResult.success()


## Valida formato de email
func validate_email(email: String) -> ValidationResult:
	var clean_email := email.strip_edges()
	
	if clean_email.is_empty():
		return ValidationResult.success()  # Email es opcional
	
	if not _get_email_regex().search(clean_email):
		return ValidationResult.failure(
			"Please enter a valid email address",
			"email"
		)
	
	return ValidationResult.success()


# =============================================================================
# UTILIDADES
# =============================================================================

## Sanitiza un username (quita espacios)
func sanitize_username(username: String) -> String:
	return username.strip_edges()


## Sanitiza un email
func sanitize_email(email: String) -> String:
	return email.strip_edges().to_lower()
