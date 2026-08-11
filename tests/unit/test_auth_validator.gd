## Tests para AuthValidator
## Verifica la lógica de validación de credenciales de autenticación
## Estos tests son puramente lógicos, sin dependencias de UI
extends GutTest

const AuthValidatorClass = preload("res://scripts/core/auth_validator.gd")

var _validator: AuthValidatorClass


func before_each() -> void:
	_validator = AuthValidatorClass.new()


func after_each() -> void:
	_validator = null


# =============================================================================
# LOGIN VALIDATION TESTS
# =============================================================================

func test_validate_login_valid_credentials_returns_success() -> void:
	var result = _validator.validate_login("validuser", "password123")
	
	assert_true(result.is_valid, "Should validate valid login credentials")
	assert_eq(result.error_message, "", "Should have no error message")


func test_validate_login_empty_username_returns_error() -> void:
	var result = _validator.validate_login("", "password123")
	
	assert_false(result.is_valid, "Should reject empty username")
	assert_eq(result.field, "username", "Should indicate username field")
	assert_string_contains(result.error_message, "username", "Error should mention username")


func test_validate_login_whitespace_username_returns_error() -> void:
	var result = _validator.validate_login("   ", "password123")
	
	assert_false(result.is_valid, "Should reject whitespace-only username")
	assert_eq(result.field, "username", "Should indicate username field")


func test_validate_login_short_username_returns_error() -> void:
	var result = _validator.validate_login("ab", "password123")
	
	assert_false(result.is_valid, "Should reject username shorter than minimum")
	assert_eq(result.field, "username", "Should indicate username field")
	assert_string_contains(result.error_message, "3", "Error should mention minimum length")


func test_validate_login_empty_password_returns_error() -> void:
	var result = _validator.validate_login("validuser", "")
	
	assert_false(result.is_valid, "Should reject empty password")
	assert_eq(result.field, "password", "Should indicate password field")
	assert_string_contains(result.error_message, "password", "Error should mention password")


func test_validate_login_username_with_leading_spaces_is_trimmed() -> void:
	var result = _validator.validate_login("  validuser  ", "password123")
	
	assert_true(result.is_valid, "Should validate after trimming spaces")


# =============================================================================
# REGISTRATION VALIDATION TESTS
# =============================================================================

func test_validate_registration_valid_data_returns_success() -> void:
	var result = _validator.validate_registration(
		"newuser",
		"password123",
		"password123",
		"user@example.com"
	)
	
	assert_true(result.is_valid, "Should validate valid registration data")


func test_validate_registration_valid_data_without_email_returns_success() -> void:
	var result = _validator.validate_registration(
		"newuser",
		"password123",
		"password123",
		""
	)
	
	assert_true(result.is_valid, "Should allow registration without email")


func test_validate_registration_empty_username_returns_error() -> void:
	var result = _validator.validate_registration("", "password123", "password123", "")
	
	assert_false(result.is_valid, "Should reject empty username")
	assert_eq(result.field, "username", "Should indicate username field")


func test_validate_registration_short_username_returns_error() -> void:
	var result = _validator.validate_registration("ab", "password123", "password123", "")
	
	assert_false(result.is_valid, "Should reject short username")
	assert_eq(result.field, "username", "Should indicate username field")
	assert_string_contains(result.error_message, "3", "Error should mention minimum length")


func test_validate_registration_long_username_returns_error() -> void:
	var result = _validator.validate_registration(
		"thisisaverylongusername123",  # 26 chars, max is 20
		"password123",
		"password123",
		""
	)
	
	assert_false(result.is_valid, "Should reject long username")
	assert_eq(result.field, "username", "Should indicate username field")
	assert_string_contains(result.error_message, "20", "Error should mention maximum length")


func test_validate_registration_username_with_special_chars_returns_error() -> void:
	var result = _validator.validate_registration(
		"user@name!",
		"password123",
		"password123",
		""
	)
	
	assert_false(result.is_valid, "Should reject username with special characters")
	assert_eq(result.field, "username", "Should indicate username field")
	assert_string_contains(result.error_message.to_lower(), "letters", "Error should mention allowed characters")


func test_validate_registration_username_with_spaces_returns_error() -> void:
	var result = _validator.validate_registration(
		"user name",
		"password123",
		"password123",
		""
	)
	
	assert_false(result.is_valid, "Should reject username with spaces")
	assert_eq(result.field, "username", "Should indicate username field")


func test_validate_registration_valid_username_with_underscore_returns_success() -> void:
	var result = _validator.validate_registration(
		"user_name_123",
		"password123",
		"password123",
		""
	)
	
	assert_true(result.is_valid, "Should allow underscore in username")


func test_validate_registration_empty_password_returns_error() -> void:
	var result = _validator.validate_registration("validuser", "", "", "")
	
	assert_false(result.is_valid, "Should reject empty password")
	assert_eq(result.field, "password", "Should indicate password field")


func test_validate_registration_short_password_returns_error() -> void:
	var result = _validator.validate_registration("validuser", "12345", "12345", "")
	
	assert_false(result.is_valid, "Should reject short password")
	assert_eq(result.field, "password", "Should indicate password field")
	assert_string_contains(result.error_message, "6", "Error should mention minimum length")


func test_validate_registration_password_mismatch_returns_error() -> void:
	var result = _validator.validate_registration(
		"validuser",
		"password123",
		"different456",
		""
	)
	
	assert_false(result.is_valid, "Should reject mismatched passwords")
	assert_eq(result.field, "confirm_password", "Should indicate confirm_password field")
	assert_string_contains(result.error_message.to_lower(), "match", "Error should mention mismatch")


func test_validate_registration_invalid_email_returns_error() -> void:
	var result = _validator.validate_registration(
		"validuser",
		"password123",
		"password123",
		"notanemail"
	)
	
	assert_false(result.is_valid, "Should reject invalid email")
	assert_eq(result.field, "email", "Should indicate email field")
	assert_string_contains(result.error_message.to_lower(), "email", "Error should mention email")


func test_validate_registration_valid_emails() -> void:
	var valid_emails := [
		"user@example.com",
		"user.name@domain.org",
		"user+tag@example.co.uk",
		"a@b.c"
	]
	
	for email in valid_emails:
		var result = _validator.validate_registration(
			"validuser",
			"password123",
			"password123",
			email
		)
		assert_true(result.is_valid, "Should accept valid email: %s" % email)


func test_validate_registration_invalid_emails() -> void:
	var invalid_emails := [
		"notanemail",
		"@nodomain.com",
		"nodomain@",
		"no@domain",  # Missing TLD with dot
		"spaces in@email.com"
	]
	
	for email in invalid_emails:
		var result = _validator.validate_registration(
			"validuser",
			"password123",
			"password123",
			email
		)
		assert_false(result.is_valid, "Should reject invalid email: %s" % email)


# =============================================================================
# INDIVIDUAL VALIDATION TESTS
# =============================================================================

func test_validate_email_empty_returns_success() -> void:
	var result = _validator.validate_email("")
	
	assert_true(result.is_valid, "Empty email should be valid (optional field)")


func test_validate_email_valid_returns_success() -> void:
	var result = _validator.validate_email("user@example.com")
	
	assert_true(result.is_valid, "Valid email should pass")


func test_validate_email_invalid_returns_error() -> void:
	var result = _validator.validate_email("invalid")
	
	assert_false(result.is_valid, "Invalid email should fail")
	assert_eq(result.field, "email", "Should indicate email field")


func test_validate_password_confirmation_match_returns_success() -> void:
	var result = _validator.validate_password_confirmation("password", "password")
	
	assert_true(result.is_valid, "Matching passwords should pass")


func test_validate_password_confirmation_mismatch_returns_error() -> void:
	var result = _validator.validate_password_confirmation("password1", "password2")
	
	assert_false(result.is_valid, "Mismatched passwords should fail")
	assert_eq(result.field, "confirm_password", "Should indicate confirm_password field")


# =============================================================================
# SANITIZATION TESTS
# =============================================================================

func test_sanitize_username_trims_whitespace() -> void:
	var result = _validator.sanitize_username("  username  ")
	
	assert_eq(result, "username", "Should trim whitespace")


func test_sanitize_email_trims_and_lowercases() -> void:
	var result = _validator.sanitize_email("  User@Example.COM  ")
	
	assert_eq(result, "user@example.com", "Should trim and lowercase email")


# =============================================================================
# CONFIGURATION TESTS
# =============================================================================

func test_validator_uses_configurable_min_username_length() -> void:
	_validator.min_username_length = 5
	
	var result = _validator.validate_login("abc", "password")
	
	assert_false(result.is_valid, "Should respect configured min_username_length")


func test_validator_uses_configurable_min_password_length() -> void:
	_validator.min_password_length = 8
	
	var result = _validator.validate_password_for_registration("short1")
	
	assert_false(result.is_valid, "Should respect configured min_password_length")


# =============================================================================
# VALIDATION RESULT TESTS
# =============================================================================

func test_validation_result_success_has_correct_properties() -> void:
	var result = AuthValidatorClass.ValidationResult.success()
	
	assert_true(result.is_valid, "Success result should be valid")
	assert_eq(result.error_message, "", "Success should have empty error message")
	assert_eq(result.field, "", "Success should have empty field")


func test_validation_result_failure_has_correct_properties() -> void:
	var result = AuthValidatorClass.ValidationResult.failure("Error message", "field_name")
	
	assert_false(result.is_valid, "Failure result should be invalid")
	assert_eq(result.error_message, "Error message", "Should have error message")
	assert_eq(result.field, "field_name", "Should have field name")


# =============================================================================
# ADDITIONAL TESTS - Login Validation Methods
# =============================================================================

func test_validate_username_for_login_valid() -> void:
	"""Test: validate_username_for_login con username válido"""
	var result = _validator.validate_username_for_login("testuser")
	assert_true(result.is_valid, "Username válido debe pasar")


func test_validate_username_for_login_empty() -> void:
	"""Test: validate_username_for_login con username vacío"""
	var result = _validator.validate_username_for_login("")
	assert_false(result.is_valid, "Username vacío debe fallar")
	assert_eq(result.field, "username")


func test_validate_username_for_login_too_short() -> void:
	"""Test: validate_username_for_login con username muy corto"""
	var result = _validator.validate_username_for_login("ab")
	assert_false(result.is_valid, "Username muy corto debe fallar")


func test_validate_password_for_login_valid() -> void:
	"""Test: validate_password_for_login con password válido"""
	var result = _validator.validate_password_for_login("anypassword")
	assert_true(result.is_valid, "Password válido debe pasar")


func test_validate_password_for_login_empty() -> void:
	"""Test: validate_password_for_login con password vacío"""
	var result = _validator.validate_password_for_login("")
	assert_false(result.is_valid, "Password vacío debe fallar")
	assert_eq(result.field, "password")


# =============================================================================
# ADDITIONAL TESTS - Registration Username Validation
# =============================================================================

func test_validate_username_for_registration_valid() -> void:
	"""Test: validate_username_for_registration con username válido"""
	var result = _validator.validate_username_for_registration("validuser123")
	assert_true(result.is_valid, "Username válido debe pasar registro")


func test_validate_username_for_registration_empty() -> void:
	"""Test: validate_username_for_registration con username vacío"""
	var result = _validator.validate_username_for_registration("")
	assert_false(result.is_valid, "Username vacío debe fallar")


func test_validate_username_for_registration_too_short() -> void:
	"""Test: validate_username_for_registration con username muy corto"""
	var result = _validator.validate_username_for_registration("ab")
	assert_false(result.is_valid, "Username muy corto debe fallar")


func test_validate_username_for_registration_too_long() -> void:
	"""Test: validate_username_for_registration con username muy largo"""
	var result = _validator.validate_username_for_registration("a".repeat(25))
	assert_false(result.is_valid, "Username muy largo debe fallar")


func test_validate_username_for_registration_invalid_chars() -> void:
	"""Test: validate_username_for_registration con caracteres inválidos"""
	var result = _validator.validate_username_for_registration("user@name!")
	assert_false(result.is_valid, "Username con caracteres especiales debe fallar")
