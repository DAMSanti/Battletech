# ============================================================================
# test_auth_manager_singleton.gd - Tests para el singleton de autenticación
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const AuthManagerSingleton = preload("res://scripts/core/auth_manager_singleton.gd")

var _singleton: Node = null


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

func before_each():
	# Crear instancia del singleton para testing
	_singleton = AuthManagerSingleton.new()
	add_child_autofree(_singleton)


func after_each():
	_singleton = null


# ============================================================================
# TESTS DE ESTADO DE AUTENTICACIÓN
# ============================================================================

func test_is_authenticated_default():
	"""Test: is_authenticated por defecto es false"""
	var result = _singleton.is_authenticated()
	assert_false(result, "Por defecto no está autenticado")


func test_is_authenticated_returns_bool():
	"""Test: is_authenticated retorna booleano"""
	var result = _singleton.is_authenticated()
	assert_true(result is bool, "Debe retornar booleano")


func test_get_current_user_default():
	"""Test: get_current_user por defecto es vacío"""
	var user = _singleton.get_current_user()
	assert_eq(user, {}, "Por defecto usuario está vacío")


func test_get_auth_token_default():
	"""Test: get_auth_token por defecto es vacío"""
	var token = _singleton.get_auth_token()
	assert_eq(token, "", "Por defecto token está vacío")


func test_is_online_returns_bool():
	"""Test: is_online retorna booleano"""
	var result = _singleton.is_online()
	assert_true(result is bool, "Debe retornar booleano")


# ============================================================================
# TESTS DE MÉTODOS PÚBLICOS
# ============================================================================

func test_logout_clears_state():
	"""Test: logout limpia el estado"""
	# Simular estado autenticado
	_singleton._is_authenticated = true
	_singleton._current_user = {"username": "test"}
	_singleton._auth_token = "test_token"
	
	# Logout
	_singleton.logout()
	
	# Verificar estado limpio
	assert_false(_singleton.is_authenticated(), "Debe limpiar autenticación")
	assert_eq(_singleton.get_current_user(), {}, "Debe limpiar usuario")
	assert_eq(_singleton.get_auth_token(), "", "Debe limpiar token")


func test_internal_auth_manager_exists():
	"""Test: auth_manager interno existe"""
	assert_not_null(_singleton._auth_manager, "Auth manager interno debe existir")
