## Tests for DatabaseManager HTTP Client
## Verifies token handling and basic state management
## NOTE: Async HTTP tests are skipped to avoid IDE crashes
extends GutTest

const DatabaseManagerScript := preload("res://scripts/core/database_manager.gd")

## ═══════════════════════════════════════════════════════════════════════════
## TEST SETUP
## ═══════════════════════════════════════════════════════════════════════════

var _db: Node = null


func before_each() -> void:
	_db = DatabaseManagerScript.new()
	add_child_autoqfree(_db)
	await get_tree().process_frame


func after_each() -> void:
	_db = null


## ═══════════════════════════════════════════════════════════════════════════
## UNIT TESTS - Token Management
## ═══════════════════════════════════════════════════════════════════════════

func test_initial_state_is_not_authenticated() -> void:
	assert_false(_db.is_authenticated(), "Fresh manager should not be authenticated")
	assert_eq(_db.get_access_token(), "", "Access token should be empty")
	assert_eq(_db.get_refresh_token(), "", "Refresh token should be empty")
	assert_false(_db.get_connection_status(), "Connection status should be false")


func test_set_tokens_updates_state() -> void:
	var access_token := "test_access_token_12345"
	var refresh_token := "test_refresh_token_67890"
	var expiry := int(Time.get_unix_time_from_system()) + 3600
	
	_db.set_tokens(access_token, refresh_token, expiry)
	
	assert_eq(_db.get_access_token(), access_token, "Access token should be stored")
	assert_eq(_db.get_refresh_token(), refresh_token, "Refresh token should be stored")
	assert_true(_db.is_authenticated(), "Should be authenticated with valid tokens")
	assert_true(_db.get_connection_status(), "Connection status should be true")


func test_set_tokens_emits_signal() -> void:
	watch_signals(_db)
	
	var expiry := int(Time.get_unix_time_from_system()) + 3600
	_db.set_tokens("token", "refresh", expiry)
	
	assert_signal_emitted(_db, "connection_status_changed")


func test_clear_tokens_resets_state() -> void:
	var expiry := int(Time.get_unix_time_from_system()) + 3600
	_db.set_tokens("access", "refresh", expiry)
	assert_true(_db.is_authenticated())
	
	_db.clear_tokens()
	
	assert_eq(_db.get_access_token(), "", "Access token should be cleared")
	assert_eq(_db.get_refresh_token(), "", "Refresh token should be cleared")
	assert_false(_db.is_authenticated(), "Should not be authenticated after clear")
	assert_false(_db.get_connection_status(), "Connection should be false after clear")


func test_expired_token_returns_not_authenticated() -> void:
	var expired_time := int(Time.get_unix_time_from_system()) - 100
	_db.set_tokens("access", "refresh", expired_time)
	
	assert_false(_db.is_authenticated(), "Expired token should not authenticate")


func test_valid_token_returns_authenticated() -> void:
	var future_time := int(Time.get_unix_time_from_system()) + 3600
	_db.set_tokens("access", "refresh", future_time)
	
	assert_true(_db.is_authenticated(), "Valid token should authenticate")


## ═══════════════════════════════════════════════════════════════════════════
## UNIT TESTS - URL Management
## ═══════════════════════════════════════════════════════════════════════════

func test_get_api_url_returns_default() -> void:
	assert_eq(_db.get_api_url(), "http://localhost:8080", "Should have default API URL")


func test_set_api_url_updates_url() -> void:
	var new_url := "https://api.steeltitans.com"
	
	_db.set_api_url(new_url)
	
	assert_eq(_db.get_api_url(), new_url, "API URL should be updated")


func test_set_api_url_empty_string() -> void:
	_db.set_api_url("")
	assert_eq(_db.get_api_url(), "")


## ═══════════════════════════════════════════════════════════════════════════
## UNIT TESTS - HTTP Methods Enum
## ═══════════════════════════════════════════════════════════════════════════

func test_http_methods_defined() -> void:
	assert_eq(DatabaseManagerScript.Method.GET, 0)
	assert_eq(DatabaseManagerScript.Method.POST, 1)
	assert_eq(DatabaseManagerScript.Method.PUT, 2)
	assert_eq(DatabaseManagerScript.Method.DELETE, 3)
	assert_eq(DatabaseManagerScript.Method.PATCH, 4)


func test_priority_levels_defined() -> void:
	assert_lt(DatabaseManagerScript.Priority.LOW, DatabaseManagerScript.Priority.NORMAL)
	assert_lt(DatabaseManagerScript.Priority.NORMAL, DatabaseManagerScript.Priority.HIGH)
	assert_lt(DatabaseManagerScript.Priority.HIGH, DatabaseManagerScript.Priority.CRITICAL)


## ═══════════════════════════════════════════════════════════════════════════
## UNIT TESTS - Constants
## ═══════════════════════════════════════════════════════════════════════════

func test_constants_have_sensible_values() -> void:
	assert_eq(DatabaseManagerScript.DEFAULT_API_URL, "http://localhost:8080")
	assert_eq(DatabaseManagerScript.DEFAULT_TIMEOUT, 30.0)
	assert_eq(DatabaseManagerScript.MAX_RETRIES, 3)
	assert_gt(DatabaseManagerScript.RETRY_DELAY, 0.0)
	assert_gt(DatabaseManagerScript.TOKEN_REFRESH_THRESHOLD, 0)


## ═══════════════════════════════════════════════════════════════════════════
## SIGNAL TESTS
## ═══════════════════════════════════════════════════════════════════════════

func test_token_signals_defined() -> void:
	assert_true(_db.has_signal("request_completed"))
	assert_true(_db.has_signal("request_failed"))
	assert_true(_db.has_signal("connection_status_changed"))
	assert_true(_db.has_signal("token_refreshed"))
	assert_true(_db.has_signal("token_expired"))


func test_clear_tokens_emits_disconnected() -> void:
	var expiry := int(Time.get_unix_time_from_system()) + 3600
	_db.set_tokens("access", "refresh", expiry)
	watch_signals(_db)
	
	_db.clear_tokens()
	
	assert_signal_emitted(_db, "connection_status_changed")


## ═══════════════════════════════════════════════════════════════════════════
## EDGE CASES
## ═══════════════════════════════════════════════════════════════════════════

func test_empty_tokens_not_authenticated() -> void:
	_db.set_tokens("", "", 0)
	assert_false(_db.is_authenticated())


func test_multiple_set_tokens_overwrite() -> void:
	var expiry := int(Time.get_unix_time_from_system()) + 3600
	_db.set_tokens("first_access", "first_refresh", expiry)
	
	_db.set_tokens("second_access", "second_refresh", expiry)
	
	assert_eq(_db.get_access_token(), "second_access")
	assert_eq(_db.get_refresh_token(), "second_refresh")


## ═══════════════════════════════════════════════════════════════════════════
## ASYNC HTTP TESTS - Skipped (require server + can cause issues)
## ═══════════════════════════════════════════════════════════════════════════

func test_health_check_integration() -> void:
	pending("Integration test - requires running API server")


func test_register_and_login_flow() -> void:
	pending("Integration test - requires running API server")


func test_auth_required_request_fails_without_token() -> void:
	pending("Async test - run manually with server")


func test_non_auth_request_proceeds_without_token() -> void:
	pending("Async test - run manually with server")
