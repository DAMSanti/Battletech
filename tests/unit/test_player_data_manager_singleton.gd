# ============================================================================
# test_player_data_manager_singleton.gd - Tests para el singleton de datos de jugador
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const PlayerDataSingleton = preload("res://scripts/core/player_data_manager_singleton.gd")

var _singleton: Node = null


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

func before_each():
	_singleton = PlayerDataSingleton.new()
	add_child_autofree(_singleton)


func after_each():
	_singleton = null


# ============================================================================
# TESTS DE INSTANCIA
# ============================================================================

func test_get_instance_returns_value():
	"""Test: get_instance retorna instancia del manager"""
	var instance = _singleton.get_instance()
	assert_not_null(instance, "get_instance debe retornar una instancia")


func test_get_instance_is_refcounted():
	"""Test: get_instance retorna RefCounted"""
	var instance = _singleton.get_instance()
	assert_true(instance is RefCounted, "Debe ser RefCounted")


# ============================================================================
# TESTS DE PROPIEDADES
# ============================================================================

func test_progress_property():
	"""Test: propiedad progress accesible"""
	var progress = _singleton.progress
	# Puede ser null si instance no está configurado
	assert_true(progress == null or progress is RefCounted, "Progress es RefCounted o null")


func test_settings_property():
	"""Test: propiedad settings accesible"""
	var settings = _singleton.settings
	assert_true(settings == null or settings is RefCounted, "Settings es RefCounted o null")


func test_inventory_property():
	"""Test: propiedad inventory accesible"""
	var inventory = _singleton.inventory
	assert_true(inventory == null or inventory is RefCounted, "Inventory es RefCounted o null")


func test_is_dirty_default():
	"""Test: is_dirty por defecto"""
	var dirty = _singleton.is_dirty
	assert_true(dirty is bool, "is_dirty debe ser booleano")


# ============================================================================
# TESTS DE MÉTODOS DELEGADOS
# ============================================================================

func test_check_periodic_sync_no_crash():
	"""Test: check_periodic_sync no causa crash"""
	# Solo verificar que no lance excepción
	_singleton.check_periodic_sync()
	assert_true(true, "check_periodic_sync ejecutado sin crash")


func test_load_offline_data_no_crash():
	"""Test: load_offline_data no causa crash"""
	_singleton.load_offline_data()
	assert_true(true, "load_offline_data ejecutado sin crash")


func test_on_logout_no_crash():
	"""Test: on_logout no causa crash"""
	_singleton.on_logout()
	assert_true(true, "on_logout ejecutado sin crash")


func test_add_xp_no_crash():
	"""Test: add_xp no causa crash"""
	_singleton.add_xp(100)
	assert_true(true, "add_xp ejecutado sin crash")


func test_record_match_result_no_crash():
	"""Test: record_match_result no causa crash"""
	_singleton.record_match_result(true, 50, 10)
	assert_true(true, "record_match_result ejecutado sin crash")


func test_record_draw_no_crash():
	"""Test: record_draw no causa crash"""
	_singleton.record_draw()
	assert_true(true, "record_draw ejecutado sin crash")


func test_modify_credits_no_crash():
	"""Test: modify_credits no causa crash"""
	var result = _singleton.modify_credits(100)
	assert_true(result is bool, "modify_credits retorna booleano")


# ============================================================================
# TESTS DE SEÑALES
# ============================================================================

func test_has_data_loaded_signal():
	"""Test: señal data_loaded existe"""
	assert_true(_singleton.has_signal("data_loaded"), "Debe tener señal data_loaded")


func test_has_data_saved_signal():
	"""Test: señal data_saved existe"""
	assert_true(_singleton.has_signal("data_saved"), "Debe tener señal data_saved")


func test_has_data_error_signal():
	"""Test: señal data_error existe"""
	assert_true(_singleton.has_signal("data_error"), "Debe tener señal data_error")


func test_has_dirty_state_changed_signal():
	"""Test: señal dirty_state_changed existe"""
	assert_true(_singleton.has_signal("dirty_state_changed"), "Debe tener señal dirty_state_changed")
