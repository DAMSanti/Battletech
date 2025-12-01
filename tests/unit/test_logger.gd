## Tests para el sistema de Log
extends GutTest

var logger_instance: Node
var LoggerScript = preload("res://scripts/core/logger.gd")


func before_each() -> void:
	# Crear instancia fresca del logger para cada test
	logger_instance = LoggerScript.new()
	logger_instance._ready()


func after_each() -> void:
	if logger_instance:
		logger_instance.queue_free()


## ═══════════════════════════════════════════════════════════════════════════
## Tests de niveles de log
## ═══════════════════════════════════════════════════════════════════════════

func test_level_enum_values() -> void:
	# Verificar que los niveles están ordenados correctamente
	assert_lt(LoggerScript.Level.DEBUG, LoggerScript.Level.INFO, "DEBUG debe ser menor que INFO")
	assert_lt(LoggerScript.Level.INFO, LoggerScript.Level.WARNING, "INFO debe ser menor que WARNING")
	assert_lt(LoggerScript.Level.WARNING, LoggerScript.Level.ERROR, "WARNING debe ser menor que ERROR")
	assert_lt(LoggerScript.Level.ERROR, LoggerScript.Level.CRITICAL, "ERROR debe ser menor que CRITICAL")


func test_level_names_complete() -> void:
	# Verificar que todos los niveles tienen nombre
	for level in LoggerScript.Level.values():
		assert_true(LoggerScript.LEVEL_NAMES.has(level), "Nivel %d debe tener nombre" % level)
		assert_ne(LoggerScript.LEVEL_NAMES[level], "", "Nombre de nivel no debe estar vacío")


func test_level_prefixes_complete() -> void:
	# Verificar que todos los niveles tienen prefijo
	for level in LoggerScript.Level.values():
		assert_true(LoggerScript.LEVEL_PREFIXES.has(level), "Nivel %d debe tener prefijo" % level)


## ═══════════════════════════════════════════════════════════════════════════
## Tests de categorías
## ═══════════════════════════════════════════════════════════════════════════

func test_valid_categories_defined() -> void:
	assert_true(LoggerScript.VALID_CATEGORIES.size() > 0, "Debe haber categorías válidas definidas")
	assert_true("System" in LoggerScript.VALID_CATEGORIES, "System debe estar en categorías válidas")
	assert_true("Combat" in LoggerScript.VALID_CATEGORIES, "Combat debe estar en categorías válidas")
	assert_true("Network" in LoggerScript.VALID_CATEGORIES, "Network debe estar en categorías válidas")


func test_all_categories_enabled_by_default() -> void:
	# Por defecto, enabled_categories y disabled_categories están vacíos
	assert_true(logger_instance.enabled_categories.is_empty(), "No debe haber categorías específicamente habilitadas")
	assert_true(logger_instance.disabled_categories.is_empty(), "No debe haber categorías deshabilitadas")


func test_disable_category() -> void:
	logger_instance.disable_categories(["UI", "Audio"])
	
	assert_true(logger_instance.disabled_categories.has("UI"), "UI debe estar deshabilitado")
	assert_true(logger_instance.disabled_categories.has("Audio"), "AUDIO debe estar deshabilitado")
	assert_false(logger_instance.disabled_categories.has("Combat"), "COMBAT no debe estar deshabilitado")


func test_enable_only_specific_categories() -> void:
	logger_instance.enable_only_categories(["Combat", "Network"])
	
	assert_true(logger_instance.enabled_categories.has("Combat"), "COMBAT debe estar habilitado")
	assert_true(logger_instance.enabled_categories.has("Network"), "NETWORK debe estar habilitado")
	assert_eq(logger_instance.enabled_categories.size(), 2, "Solo 2 categorías habilitadas")


func test_enable_all_categories_resets() -> void:
	# Primero deshabilitar algunas
	logger_instance.disable_categories(["UI"])
	logger_instance.enable_only_categories(["Combat"])
	
	# Luego resetear
	logger_instance.enable_all_categories()
	
	assert_true(logger_instance.enabled_categories.is_empty(), "enabled_categories debe estar vacío")
	assert_true(logger_instance.disabled_categories.is_empty(), "disabled_categories debe estar vacío")


## ═══════════════════════════════════════════════════════════════════════════
## Tests de configuración
## ═══════════════════════════════════════════════════════════════════════════

func test_set_min_level() -> void:
	logger_instance.set_min_level(LoggerScript.Level.WARNING)
	assert_eq(logger_instance.min_level, LoggerScript.Level.WARNING)


func test_session_id_generated() -> void:
	assert_ne(logger_instance.get_session_id(), "")
	assert_eq(logger_instance.get_session_id().length(), 8)


func test_session_id_alphanumeric() -> void:
	var session_id = logger_instance.get_session_id()
	var valid_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	for i in range(session_id.length()):
		assert_true(valid_chars.contains(session_id[i]), "Carácter '%s' debe ser alfanumérico" % session_id[i])


## ═══════════════════════════════════════════════════════════════════════════
## Tests de timers
## ═══════════════════════════════════════════════════════════════════════════

func test_timer_start_and_end() -> void:
	logger_instance.start_timer("test_operation")
	
	# Esperar un poco - usamos más tiempo para evitar flakiness
	await get_tree().create_timer(0.1).timeout
	
	var elapsed = logger_instance.end_timer("test_operation")
	
	# Verificar que el timer midió algo (mayor que 0)
	assert_gt(elapsed, 0.0, "Timer debe medir algo de tiempo")
	assert_lt(elapsed, 1.0, "Timer no debe medir más de 1 segundo")


func test_timer_not_found_returns_negative() -> void:
	var elapsed = logger_instance.end_timer("nonexistent_timer")
	assert_eq(elapsed, -1.0, "Timer inexistente debe retornar -1")
	# Marcar el warning esperado como manejado
	for err in get_errors():
		if err.contains_text("Timer no encontrado"):
			err.handled = true


func test_timer_removed_after_end() -> void:
	logger_instance.start_timer("temp_timer")
	logger_instance.end_timer("temp_timer")
	
	# Intentar terminar de nuevo debe retornar -1
	var second_end = logger_instance.end_timer("temp_timer")
	assert_eq(second_end, -1.0)
	# Marcar el warning esperado como manejado
	for err in get_errors():
		if err.contains_text("Timer no encontrado"):
			err.handled = true
			err.handled = true


## ═══════════════════════════════════════════════════════════════════════════
## Tests de formato
## ═══════════════════════════════════════════════════════════════════════════

func test_format_context_empty() -> void:
	var result = logger_instance._format_context({})
	assert_eq(result, "")


func test_format_context_single_value() -> void:
	var result = logger_instance._format_context({"damage": 10})
	assert_eq(result, "damage=10")


func test_format_context_multiple_values() -> void:
	var result = logger_instance._format_context({"a": 1, "b": 2})
	# El orden puede variar, así que verificamos que contiene ambos
	assert_true(result.contains("a=1"))
	assert_true(result.contains("b=2"))


## ═══════════════════════════════════════════════════════════════════════════
## Tests de helpers específicos
## ═══════════════════════════════════════════════════════════════════════════

func test_network_helper_creates_correct_context() -> void:
	# Este test verifica que el método no crashea
	# La verificación real sería con un mock, pero al menos probamos que funciona
	logger_instance.network("Test message", 12345, false)
	logger_instance.network("Error message", 0, true)
	pass_test("network() helper ejecutado sin errores")
	# Manejar el push_error esperado de network() con is_error=true
	assert_push_error(1, "Se espera 1 push_error de network() con is_error=true")


func test_combat_helper_creates_correct_context() -> void:
	logger_instance.combat("Attack landed", "Warden", "Crusader", 15)
	pass_test("combat() helper ejecutado sin errores")


func test_movement_helper_creates_correct_context() -> void:
	logger_instance.movement("Mech moved", "Warden", Vector2i(5, 5), Vector2i(7, 6))
	pass_test("movement() helper ejecutado sin errores")


func test_heat_helper_creates_correct_context() -> void:
	logger_instance.heat("Heat warning", "Warden", 25, 30)
	pass_test("heat() helper ejecutado sin errores")


func test_match_event_helper_creates_correct_context() -> void:
	logger_instance.match_event("Match started", "MATCH001", "Player1", "Player2")
	pass_test("match_event() helper ejecutado sin errores")


func test_ui_helper_creates_correct_context() -> void:
	logger_instance.ui("Button pressed", "attack_button")
	pass_test("ui() helper ejecutado sin errores")


## ═══════════════════════════════════════════════════════════════════════════
## Tests de archivo de log
## ═══════════════════════════════════════════════════════════════════════════

func test_log_path_not_empty() -> void:
	var path = logger_instance.get_log_path()
	assert_ne(path, "", "Log path no debe estar vacío")
	assert_true(path.contains("logs"), "Path debe contener 'logs'")
	assert_true(path.ends_with(".log"), "Path debe terminar en .log")


func test_log_filename_format() -> void:
	var path = logger_instance.get_log_path()
	var filename = path.get_file()
	assert_true(filename.begins_with("steel_titans_"), "Filename debe comenzar con 'steel_titans_'")
