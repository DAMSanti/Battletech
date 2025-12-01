## DatabaseManager - HTTP Client for REST API
## Provides async communication with the Steel Titans backend API
## Handles authentication tokens, request queuing, and error handling
## Note: class_name removed to avoid conflict with autoload singleton
extends Node

## Signals for async operations
signal request_completed(endpoint: String, result: Dictionary)
signal request_failed(endpoint: String, error: Dictionary)
signal connection_status_changed(is_connected: bool)
signal token_refreshed(new_token: String)
signal token_expired()

## API Configuration
const DEFAULT_API_URL := "https://steeltitans.damsanti.app"
const PRODUCTION_API_URL := "https://steeltitans.damsanti.app"
const LOCAL_API_URL := "http://localhost:8080"
const INSECURE_API_URL := "http://steeltitans.damsanti.app:8080"  # Fallback sin TLS
const API_VERSION := "/api/v1"
const DEFAULT_TIMEOUT := 30.0
const MAX_RETRIES := 3
const RETRY_DELAY := 1.0

## Token refresh threshold (refresh when less than 5 minutes remaining)
const TOKEN_REFRESH_THRESHOLD := 300

## Log category for this manager
const LOG_CATEGORY := "Network"

## HTTP Methods
enum Method {
	GET,
	POST,
	PUT,
	DELETE,
	PATCH
}

## Request priority
enum Priority {
	LOW = 0,
	NORMAL = 1,
	HIGH = 2,
	CRITICAL = 3
}

## Internal state
var _api_url: String = DEFAULT_API_URL
var _access_token: String = ""
var _refresh_token_value: String = ""
var _token_expiry: int = 0
var _is_connected: bool = false
var _pending_requests: Array[Dictionary] = []
var _active_requests: Dictionary = {}  # request_id -> HTTPRequest node
var _request_counter: int = 0
var _retry_counts: Dictionary = {}  # request_id -> retry count


func _ready() -> void:
	_load_configuration()
	_start_token_refresh_timer()
	Log.info(LOG_CATEGORY, "DatabaseManager initialized", {"api_url": _api_url})


func _load_configuration() -> void:
	"""Load API configuration from settings or environment"""
	# Try to get from ProjectSettings first
	if ProjectSettings.has_setting("steel_titans/api_url"):
		_api_url = ProjectSettings.get_setting("steel_titans/api_url")
	
	# Override with environment variable if present
	var env_url := OS.get_environment("STEEL_TITANS_API_URL")
	if not env_url.is_empty():
		_api_url = env_url
	
	Log.debug(LOG_CATEGORY, "Configuration loaded", {"api_url": _api_url})


func _start_token_refresh_timer() -> void:
	"""Start a timer to check token expiry periodically"""
	var timer := Timer.new()
	timer.wait_time = 60.0  # Check every minute
	timer.autostart = true
	timer.timeout.connect(_check_token_expiry)
	add_child(timer)


func _check_token_expiry() -> void:
	"""Check if token needs refresh"""
	if _access_token.is_empty():
		return
	
	var current_time := int(Time.get_unix_time_from_system())
	var time_remaining := _token_expiry - current_time
	
	if time_remaining <= 0:
		Log.warning(LOG_CATEGORY, "Access token expired")
		token_expired.emit()
	elif time_remaining <= TOKEN_REFRESH_THRESHOLD and not _refresh_token_value.is_empty():
		Log.info(LOG_CATEGORY, "Token expiring soon, refreshing", {"seconds_remaining": time_remaining})
		do_refresh_token()


# =============================================================================
# PUBLIC API - Authentication
# =============================================================================

## Set authentication tokens
func set_tokens(p_access_token: String, p_refresh_token: String, expiry: int) -> void:
	_access_token = p_access_token
	_refresh_token_value = p_refresh_token
	_token_expiry = expiry
	_is_connected = not p_access_token.is_empty()
	connection_status_changed.emit(_is_connected)
	Log.info(LOG_CATEGORY, "Tokens updated", {"has_access": not p_access_token.is_empty(), "expiry": expiry})


## Clear all tokens (logout)
func clear_tokens() -> void:
	_access_token = ""
	_refresh_token_value = ""
	_token_expiry = 0
	_is_connected = false
	connection_status_changed.emit(false)
	Log.info(LOG_CATEGORY, "Tokens cleared")


## Get current access token
func get_access_token() -> String:
	return _access_token


## Get current refresh token
func get_refresh_token() -> String:
	return _refresh_token_value


## Check if authenticated
func is_authenticated() -> bool:
	if _access_token.is_empty():
		return false
	var current_time := int(Time.get_unix_time_from_system())
	return _token_expiry > current_time


## Refresh the access token using refresh token
func do_refresh_token() -> void:
	if _refresh_token_value.is_empty():
		Log.error(LOG_CATEGORY, "No refresh token available")
		token_expired.emit()
		return
	
	var result := await post_async("/auth/refresh", {"refresh_token": _refresh_token_value}, false)
	
	if result.success:
		var data: Dictionary = result.data
		_access_token = data.get("access_token", "")
		if data.has("refresh_token"):
			_refresh_token_value = data.refresh_token
		_token_expiry = int(Time.get_unix_time_from_system()) + data.get("expires_in", 1800)
		token_refreshed.emit(_access_token)
		Log.info(LOG_CATEGORY, "Token refreshed successfully")
	else:
		Log.error(LOG_CATEGORY, "Token refresh failed", {"error": result.error})
		clear_tokens()
		token_expired.emit()


# =============================================================================
# PUBLIC API - HTTP Methods
# =============================================================================

## GET request (async with await)
func get_async(endpoint: String, query_params: Dictionary = {}, auth_required: bool = true) -> Dictionary:
	return await _make_request_async(Method.GET, endpoint, {}, query_params, auth_required)


## POST request (async with await)
func post_async(endpoint: String, body: Dictionary = {}, auth_required: bool = true) -> Dictionary:
	return await _make_request_async(Method.POST, endpoint, body, {}, auth_required)


## PUT request (async with await)
func put_async(endpoint: String, body: Dictionary = {}, auth_required: bool = true) -> Dictionary:
	return await _make_request_async(Method.PUT, endpoint, body, {}, auth_required)


## DELETE request (async with await)
func delete_async(endpoint: String, auth_required: bool = true) -> Dictionary:
	return await _make_request_async(Method.DELETE, endpoint, {}, {}, auth_required)


## PATCH request (async with await)
func patch_async(endpoint: String, body: Dictionary = {}, auth_required: bool = true) -> Dictionary:
	return await _make_request_async(Method.PATCH, endpoint, body, {}, auth_required)


## Signal-based GET request (non-blocking)
func get_request(endpoint: String, query_params: Dictionary = {}, auth_required: bool = true) -> int:
	return _queue_request(Method.GET, endpoint, {}, query_params, auth_required, Priority.NORMAL)


## Signal-based POST request (non-blocking)
func post_request(endpoint: String, body: Dictionary = {}, auth_required: bool = true) -> int:
	return _queue_request(Method.POST, endpoint, body, {}, auth_required, Priority.NORMAL)


## Signal-based PUT request (non-blocking)
func put_request(endpoint: String, body: Dictionary = {}, auth_required: bool = true) -> int:
	return _queue_request(Method.PUT, endpoint, body, {}, auth_required, Priority.NORMAL)


## Signal-based DELETE request (non-blocking)
func delete_request(endpoint: String, auth_required: bool = true) -> int:
	return _queue_request(Method.DELETE, endpoint, {}, {}, auth_required, Priority.NORMAL)


# =============================================================================
# PUBLIC API - Convenience Methods
# =============================================================================

## Check API health
func check_health() -> Dictionary:
	return await get_async("/health", {}, false)


## Register new user
func register_user(username: String, email: String, password: String) -> Dictionary:
	return await post_async("/auth/register", {
		"username": username,
		"email": email,
		"password": password
	}, false)


## Login with username/password
func login(username: String, password: String) -> Dictionary:
	var result := await post_async("/auth/login", {
		"username": username,
		"password": password
	}, false)
	
	if result.success:
		_handle_auth_response(result.data)
	
	return result


## Login as guest
func login_guest(device_id: String) -> Dictionary:
	var result := await post_async("/auth/guest", {
		"device_id": device_id
	}, false)
	
	if result.success:
		_handle_auth_response(result.data)
	
	return result


## Logout
func logout() -> Dictionary:
	var result := await post_async("/auth/logout", {
		"refresh_token": _refresh_token_value
	}, true)
	
	clear_tokens()
	return result


## Get current user profile
func get_current_user() -> Dictionary:
	return await get_async("/users/me")


## Update current user profile
func update_user(data: Dictionary) -> Dictionary:
	return await put_async("/users/me", data)


## Get user mechs
func get_mechs() -> Dictionary:
	return await get_async("/mechs/")


## Get specific mech
func get_mech(mech_id: String) -> Dictionary:
	return await get_async("/mechs/%s" % mech_id)


## Create new mech
func create_mech(mech_data: Dictionary) -> Dictionary:
	return await post_async("/mechs/", mech_data)


## Update mech
func update_mech(mech_id: String, mech_data: Dictionary) -> Dictionary:
	return await put_async("/mechs/%s" % mech_id, mech_data)


## Delete mech
func delete_mech(mech_id: String) -> Dictionary:
	return await delete_async("/mechs/%s" % mech_id)


## Get user pilots
func get_pilots() -> Dictionary:
	return await get_async("/pilots/")


## Get specific pilot
func get_pilot(pilot_id: String) -> Dictionary:
	return await get_async("/pilots/%s" % pilot_id)


## Create new pilot
func create_pilot(pilot_data: Dictionary) -> Dictionary:
	return await post_async("/pilots/", pilot_data)


## Update pilot
func update_pilot(pilot_id: String, pilot_data: Dictionary) -> Dictionary:
	return await put_async("/pilots/%s" % pilot_id, pilot_data)


## Delete pilot
func delete_pilot(pilot_id: String) -> Dictionary:
	return await delete_async("/pilots/%s" % pilot_id)


# =============================================================================
# INTERNAL - Request Handling
# =============================================================================

func _handle_auth_response(data: Dictionary) -> void:
	"""Process authentication response and store tokens"""
	var new_access_token := data.get("access_token", "") as String
	var new_refresh_token := data.get("refresh_token", "") as String
	var expires_in := data.get("expires_in", 1800) as int
	var expiry := int(Time.get_unix_time_from_system()) + expires_in
	
	set_tokens(new_access_token, new_refresh_token, expiry)


func _make_request_async(method: Method, endpoint: String, body: Dictionary, 
						  query_params: Dictionary, auth_required: bool) -> Dictionary:
	"""Make an HTTP request and wait for the response"""
	
	# Check authentication if required
	if auth_required and not is_authenticated():
		return _create_error_response("AUTH_REQUIRED", "Authentication required", 401)
	
	# Build URL
	var url := _build_url(endpoint, query_params)
	
	# Build headers
	var headers := _build_headers(auth_required)
	
	# Create HTTP request node
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = DEFAULT_TIMEOUT
	
	# Convert body to JSON
	var body_string := ""
	if not body.is_empty():
		body_string = JSON.stringify(body)
	
	# Log request
	Log.debug(LOG_CATEGORY, "Making request", {
		"method": _method_to_string(method),
		"endpoint": endpoint,
		"auth": auth_required
	})
	
	# Make request
	var error := http.request(url, headers, _method_to_http(method), body_string)
	if error != OK:
		http.queue_free()
		return _create_error_response("REQUEST_FAILED", "Failed to initiate request", 0)
	
	# Wait for response
	var response: Array = await http.request_completed
	http.queue_free()
	
	# Parse response
	return _parse_response(endpoint, response)


func _queue_request(method: Method, endpoint: String, body: Dictionary,
					query_params: Dictionary, auth_required: bool, priority: Priority) -> int:
	"""Queue a request for processing (signal-based)"""
	_request_counter += 1
	var request_id := _request_counter
	
	_pending_requests.append({
		"id": request_id,
		"method": method,
		"endpoint": endpoint,
		"body": body,
		"query_params": query_params,
		"auth_required": auth_required,
		"priority": priority
	})
	
	# Sort by priority (higher first)
	_pending_requests.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Process queue
	_process_queue()
	
	return request_id


func _process_queue() -> void:
	"""Process pending requests"""
	if _pending_requests.is_empty():
		return
	
	# Limit concurrent requests
	if _active_requests.size() >= 4:
		return
	
	var request: Dictionary = _pending_requests.pop_front()
	_execute_queued_request(request)


func _execute_queued_request(request: Dictionary) -> void:
	"""Execute a queued request"""
	var result := await _make_request_async(
		request.method,
		request.endpoint,
		request.body,
		request.query_params,
		request.auth_required
	)
	
	if result.success:
		request_completed.emit(request.endpoint, result)
	else:
		# Handle retry
		var retry_count := _retry_counts.get(request.id, 0) as int
		if retry_count < MAX_RETRIES and _should_retry(result):
			_retry_counts[request.id] = retry_count + 1
			Log.warning(LOG_CATEGORY, "Retrying request", {
				"endpoint": request.endpoint,
				"attempt": retry_count + 1
			})
			await get_tree().create_timer(RETRY_DELAY).timeout
			_pending_requests.push_front(request)
			_process_queue()
		else:
			_retry_counts.erase(request.id)
			request_failed.emit(request.endpoint, result)
	
	# Process next in queue
	_process_queue()


func _should_retry(result: Dictionary) -> bool:
	"""Determine if request should be retried"""
	var status_code := result.get("status_code", 0) as int
	# Retry on server errors or timeout
	return status_code >= 500 or status_code == 0 or status_code == 408


func _build_url(endpoint: String, query_params: Dictionary) -> String:
	"""Build full URL with query parameters"""
	# Algunos endpoints están en la raíz, no bajo /api/v1
	var root_endpoints := ["/health", "/docs", "/openapi.json"]
	var use_version_prefix := true
	for root_ep in root_endpoints:
		if endpoint.begins_with(root_ep):
			use_version_prefix = false
			break
	
	var url := _api_url
	if use_version_prefix:
		url += API_VERSION
	url += endpoint
	
	if not query_params.is_empty():
		var params: Array[String] = []
		for key in query_params:
			var value := str(query_params[key]).uri_encode()
			params.append("%s=%s" % [key, value])
		url += "?" + "&".join(params)
	
	return url


func _build_headers(auth_required: bool) -> PackedStringArray:
	"""Build HTTP headers"""
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"X-Client-Version: 1.0.0"
	])
	
	if auth_required and not _access_token.is_empty():
		headers.append("Authorization: Bearer " + _access_token)
	
	return headers


func _parse_response(endpoint: String, response: Array) -> Dictionary:
	"""Parse HTTP response"""
	var result := response[0] as int  # HTTPRequest.Result
	var response_code := response[1] as int
	var _headers := response[2] as PackedStringArray
	var body := response[3] as PackedByteArray
	
	# Check for network errors
	if result != HTTPRequest.RESULT_SUCCESS:
		Log.error(LOG_CATEGORY, "Network error", {
			"endpoint": endpoint,
			"result": result
		})
		return _create_error_response("NETWORK_ERROR", _result_to_error(result), 0)
	
	# Parse JSON body
	var body_string := body.get_string_from_utf8()
	var data := {}
	
	if not body_string.is_empty():
		var json := JSON.new()
		var parse_error := json.parse(body_string)
		if parse_error == OK:
			data = json.data
		else:
			Log.warning(LOG_CATEGORY, "Failed to parse response JSON", {
				"endpoint": endpoint,
				"error": json.get_error_message()
			})
	
	# Check for HTTP errors
	if response_code >= 400:
		var error_code := data.get("code", "HTTP_ERROR") as String
		var error_message := data.get("message", "HTTP Error %d" % response_code) as String
		
		Log.warning(LOG_CATEGORY, "HTTP error", {
			"endpoint": endpoint,
			"status": response_code,
			"code": error_code
		})
		
		return _create_error_response(error_code, error_message, response_code)
	
	# Success
	Log.debug(LOG_CATEGORY, "Request successful", {
		"endpoint": endpoint,
		"status": response_code
	})
	
	return {
		"success": true,
		"data": data,
		"status_code": response_code
	}


func _create_error_response(code: String, message: String, status_code: int) -> Dictionary:
	"""Create standardized error response"""
	return {
		"success": false,
		"error": {
			"code": code,
			"message": message
		},
		"status_code": status_code
	}


func _method_to_string(method: Method) -> String:
	"""Convert Method enum to string"""
	match method:
		Method.GET: return "GET"
		Method.POST: return "POST"
		Method.PUT: return "PUT"
		Method.DELETE: return "DELETE"
		Method.PATCH: return "PATCH"
		_: return "UNKNOWN"


func _method_to_http(method: Method) -> HTTPClient.Method:
	"""Convert Method enum to HTTPClient.Method"""
	match method:
		Method.GET: return HTTPClient.METHOD_GET
		Method.POST: return HTTPClient.METHOD_POST
		Method.PUT: return HTTPClient.METHOD_PUT
		Method.DELETE: return HTTPClient.METHOD_DELETE
		Method.PATCH: return HTTPClient.METHOD_PATCH
		_: return HTTPClient.METHOD_GET


func _result_to_error(result: int) -> String:
	"""Convert HTTPRequest.Result to error message"""
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to server"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve hostname"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake failed"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "No response from server"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "Response body too large"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "Failed to decompress response"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "Request failed"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "Cannot open download file"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "Download file write error"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "Too many redirects"
		HTTPRequest.RESULT_TIMEOUT:
			return "Request timed out"
		_:
			return "Unknown error"


# =============================================================================
# CONFIGURATION
# =============================================================================

## Set API URL
func set_api_url(url: String) -> void:
	_api_url = url
	Log.info(LOG_CATEGORY, "API URL changed", {"url": url})


## Get API URL
func get_api_url() -> String:
	return _api_url


## Get connection status
func get_connection_status() -> bool:
	return _is_connected
