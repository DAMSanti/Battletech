## Logger - Sistema de Logging Profesional para Steel Titans
## Autor: DAMSanti
## Versión: 1.2.0
##
## Uso:
##   Log.debug("Combat", "Calculando daño...")
##   Log.info("Network", "Jugador conectado: %s" % player_name)
##   Log.warning("Heat", "Mech cerca de sobrecalentamiento")
##   Log.error("Save", "No se pudo guardar la partida")
##   Log.critical("Network", "Conexión perdida con el servidor")
##
## Categorías predefinidas (strings):
##   "System", "Combat", "Network", "UI", "Heat", "Movement", "Save", 
##   "Audio", "AI", "Match", "Mech", "Input", "Test"
##
## Integración con Sentry:
##   - Errores y críticos se envían automáticamente a Sentry
##   - Configura el DSN en Project Settings -> Sentry -> Options
extends Node

## Niveles de log (uso interno)
enum Level {
	DEBUG = 0,    ## Información detallada para desarrollo
	INFO = 1,     ## Información general del flujo
	WARNING = 2,  ## Situaciones anómalas pero manejables
	ERROR = 3,    ## Errores que afectan funcionalidad
	CRITICAL = 4  ## Errores graves que pueden crashear
}

## Categorías válidas (strings para fácil acceso desde cualquier script)
const VALID_CATEGORIES = [
	"System", "Combat", "Network", "UI", "Heat", "Movement", 
	"Save", "Audio", "AI", "Match", "Mech", "Input", "Test"
]

## Configuración
var min_level: Level = Level.DEBUG  ## Nivel mínimo para mostrar
var min_file_level: Level = Level.INFO  ## Nivel mínimo para escribir a archivo
var enabled_categories: Dictionary = {}  ## Categorías habilitadas (vacío = todas)
var disabled_categories: Dictionary = {}  ## Categorías explícitamente deshabilitadas
var sentry_enabled: bool = true  ## Enviar errores a Sentry
var sentry_min_level: Level = Level.ERROR  ## Nivel mínimo para Sentry

## Estado
var _log_file: FileAccess = null
var _log_path: String = ""
var _session_id: String = ""
var _log_buffer: Array[String] = []
var _buffer_flush_size: int = 10  ## Escribir cada N logs
var _is_server: bool = false
var _start_time: int = 0
var _sentry_available: bool = false  ## Si el SDK de Sentry está disponible

## Formato de colores para consola (ANSI - solo funciona en terminales reales)
const COLORS = {
	Level.DEBUG: "",        ## Sin color
	Level.INFO: "",         ## Sin color
	Level.WARNING: "",      ## Amarillo (no soportado en Godot)
	Level.ERROR: "",        ## Rojo (no soportado en Godot)
	Level.CRITICAL: ""      ## Rojo brillante
}

## Prefijos visuales para cada nivel
const LEVEL_PREFIXES = {
	Level.DEBUG: "🔍 DEBUG",
	Level.INFO: "ℹ️ INFO ",
	Level.WARNING: "⚠️ WARN ",
	Level.ERROR: "❌ ERROR",
	Level.CRITICAL: "🔥 CRIT "
}

## Nombres de nivel para archivo
const LEVEL_NAMES = {
	Level.DEBUG: "DEBUG",
	Level.INFO: "INFO",
	Level.WARNING: "WARNING",
	Level.ERROR: "ERROR",
	Level.CRITICAL: "CRITICAL"
}


func _ready() -> void:
	_start_time = Time.get_ticks_msec()
	_session_id = _generate_session_id()
	_is_server = OS.has_feature("dedicated_server") or DisplayServer.get_name() == "headless"
	
	# Detectar si estamos en modo test (headless + debug = tests)
	var _is_test_mode: bool = _is_server and OS.is_debug_build()
	
	# Configurar nivel según build
	if OS.is_debug_build():
		min_level = Level.DEBUG
		min_file_level = Level.DEBUG
	else:
		min_level = Level.INFO
		min_file_level = Level.INFO
	
	# Inicializar archivo de log
	_init_log_file()
	
	# Inicializar Sentry (deshabilitado en modo test para evitar crashes)
	if _is_test_mode:
		sentry_enabled = false
		_sentry_available = false
	else:
		_init_sentry()
	
	# Log de inicio
	info("System", "═══════════════════════════════════════════")
	info("System", "Logger inicializado - Steel Titans v%s" % _get_version())
	info("System", "Session ID: %s" % _session_id)
	info("System", "Modo: %s | Build: %s" % [
		"Servidor" if _is_server else "Cliente",
		"Debug" if OS.is_debug_build() else "Release"
	])
	info("System", "OS: %s | Godot: %s" % [OS.get_name(), Engine.get_version_info().string])
	if _is_test_mode:
		info("System", "Sentry: Deshabilitado (modo test)")
	else:
		info("System", "Sentry: %s" % ("Activo" if _sentry_available else "No disponible"))
	info("System", "═══════════════════════════════════════════")


func _exit_tree() -> void:
	info("System", "═══════════════════════════════════════════")
	info("System", "Logger cerrando - Sesión duró %.1f segundos" % (
		(Time.get_ticks_msec() - _start_time) / 1000.0
	))
	info("System", "═══════════════════════════════════════════")
	_flush_buffer()
	if _log_file:
		_log_file.close()


## ═══════════════════════════════════════════════════════════════════════════
## API PÚBLICA - Métodos de logging
## ═══════════════════════════════════════════════════════════════════════════

## Log de nivel DEBUG
func debug(category: String, message: String, context: Dictionary = {}) -> void:
	_log(Level.DEBUG, category, message, context)


## Log de nivel INFO
func info(category: String, message: String, context: Dictionary = {}) -> void:
	_log(Level.INFO, category, message, context)


## Log de nivel WARNING
func warning(category: String, message: String, context: Dictionary = {}) -> void:
	_log(Level.WARNING, category, message, context)


## Log de nivel ERROR
func error(category: String, message: String, context: Dictionary = {}) -> void:
	_log(Level.ERROR, category, message, context)


## Log de nivel CRITICAL
func critical(category: String, message: String, context: Dictionary = {}) -> void:
	_log(Level.CRITICAL, category, message, context)


## Log con nivel dinámico
func log_level(level: Level, category: String, message: String, context: Dictionary = {}) -> void:
	_log(level, category, message, context)


## ═══════════════════════════════════════════════════════════════════════════
## API PÚBLICA - Helpers específicos
## ═══════════════════════════════════════════════════════════════════════════

## Log de red con peer_id
func network(message: String, peer_id: int = 0, is_error: bool = false) -> void:
	var ctx = {"peer_id": peer_id} if peer_id > 0 else {}
	if is_error:
		error("Network", message, ctx)
	else:
		info("Network", message, ctx)


## Log de combate con atacante/defensor
func combat(message: String, attacker: String = "", defender: String = "", damage: int = -1) -> void:
	var ctx: Dictionary = {}
	if attacker != "": ctx["attacker"] = attacker
	if defender != "": ctx["defender"] = defender
	if damage >= 0: ctx["damage"] = damage
	info("Combat", message, ctx)


## Log de movimiento con coordenadas
func movement(message: String, mech_name: String = "", from_hex: Vector2i = Vector2i.MIN, to_hex: Vector2i = Vector2i.MIN) -> void:
	var ctx: Dictionary = {}
	if mech_name != "": ctx["mech"] = mech_name
	if from_hex != Vector2i.MIN: ctx["from"] = "%d,%d" % [from_hex.x, from_hex.y]
	if to_hex != Vector2i.MIN: ctx["to"] = "%d,%d" % [to_hex.x, to_hex.y]
	debug("Movement", message, ctx)


## Log de calor
func heat(message: String, mech_name: String, current_heat: int, max_heat: int = 30) -> void:
	var ctx = {"mech": mech_name, "heat": current_heat, "max": max_heat}
	var level = Level.DEBUG
	var heat_percent = float(current_heat) / float(max_heat)
	if heat_percent >= 0.9:
		level = Level.WARNING
	elif heat_percent >= 0.7:
		level = Level.INFO
	_log(level, "Heat", message, ctx)


## Log de match/partida
func match_event(message: String, match_id: String = "", player1: String = "", player2: String = "") -> void:
	var ctx: Dictionary = {}
	if match_id != "": ctx["match_id"] = match_id
	if player1 != "": ctx["player1"] = player1
	if player2 != "": ctx["player2"] = player2
	info("Match", message, ctx)


## Log de UI
func ui(message: String, element: String = "") -> void:
	var ctx = {"element": element} if element != "" else {}
	debug("UI", message, ctx)


## Log de test (para archivos de test)
func test(message: String, context: Dictionary = {}) -> void:
	info("Test", message, context)


## ═══════════════════════════════════════════════════════════════════════════
## API PÚBLICA - Configuración
## ═══════════════════════════════════════════════════════════════════════════

## Cambiar nivel mínimo de log
func set_min_level(level: Level) -> void:
	min_level = level
	info("System", "Nivel de log cambiado a: %s" % LEVEL_NAMES[level])


## Habilitar solo ciertas categorías
func enable_only_categories(categories: Array) -> void:
	enabled_categories.clear()
	for cat in categories:
		enabled_categories[cat] = true
	info("System", "Categorías habilitadas: %d" % categories.size())


## Deshabilitar categorías específicas
func disable_categories(categories: Array) -> void:
	for cat in categories:
		disabled_categories[cat] = true


## Habilitar todas las categorías
func enable_all_categories() -> void:
	enabled_categories.clear()
	disabled_categories.clear()


## Habilitar/deshabilitar envío a Sentry
func set_sentry_enabled(enabled: bool) -> void:
	sentry_enabled = enabled
	info("System", "Sentry %s" % ("habilitado" if enabled else "deshabilitado"))


## Capturar excepción manualmente a Sentry
func capture_exception(error_message: String, context: Dictionary = {}) -> void:
	critical("System", error_message, context)


## Añadir breadcrumb manual a Sentry (para debugging)
func add_breadcrumb(message: String, category: String = "custom", data: Dictionary = {}) -> void:
	if not _sentry_available:
		return
	
	# Usar acceso dinámico para evitar errores de compilación si Sentry no está
	_add_sentry_breadcrumb(message, category, "default", "info", data)


## Helper interno para añadir breadcrumb de forma segura
func _add_sentry_breadcrumb(msg: String, cat: String, type: String, lvl: String, data: Dictionary) -> void:
	if not ClassDB.class_exists("SentryBreadcrumb"):
		return
	var breadcrumb = ClassDB.instantiate("SentryBreadcrumb")
	if breadcrumb:
		breadcrumb.message = msg
		breadcrumb.category = cat
		breadcrumb.type = type
		breadcrumb.level = lvl
		if not data.is_empty():
			breadcrumb.data = data
		if ClassDB.class_exists("SentrySDK"):
			var sdk = Engine.get_singleton("SentrySDK")
			if sdk:
				sdk.add_breadcrumb(breadcrumb)


## Verificar si Sentry está disponible
func is_sentry_available() -> bool:
	return _sentry_available


## ═══════════════════════════════════════════════════════════════════════════
## MÉTODOS PRIVADOS
## ═══════════════════════════════════════════════════════════════════════════

func _log(level: Level, category: String, message: String, context: Dictionary) -> void:
	# Filtrar por nivel
	if level < min_level:
		return
	
	# Filtrar por categoría
	if not _is_category_enabled(category):
		return
	
	# Construir entrada de log
	var timestamp = _get_timestamp()
	var uptime = "%.3f" % ((Time.get_ticks_msec() - _start_time) / 1000.0)
	var category_upper = category.to_upper()
	var level_prefix = LEVEL_PREFIXES.get(level, "?????")
	
	# Formato para consola (más visual)
	var console_msg = "[%s] %s [%s] %s" % [uptime, level_prefix, category_upper, message]
	if not context.is_empty():
		console_msg += " | " + _format_context(context)
	
	# Imprimir a consola según nivel
	match level:
		Level.DEBUG, Level.INFO:
			print(console_msg)
		Level.WARNING:
			push_warning(console_msg)
		Level.ERROR, Level.CRITICAL:
			push_error(console_msg)
	
	# Enviar a Sentry si es error o crítico
	if level >= sentry_min_level:
		_send_to_sentry(level, category, message, context)
	
	# Formato para archivo (más parseable)
	if level >= min_file_level:
		var file_msg = "%s|%s|%s|%s|%s|%s" % [
			timestamp,
			_session_id,
			LEVEL_NAMES[level],
			category_upper,
			message,
			JSON.stringify(context) if not context.is_empty() else ""
		]
		_write_to_file(file_msg)


func _is_category_enabled(category: String) -> bool:
	# Si hay categorías deshabilitadas explícitamente
	if disabled_categories.has(category):
		return false
	
	# Si hay categorías habilitadas específicamente
	if not enabled_categories.is_empty():
		return enabled_categories.has(category)
	
	# Por defecto, todas habilitadas
	return true


func _init_log_file() -> void:
	# Crear directorio de logs
	var log_dir = "user://logs"
	if not DirAccess.dir_exists_absolute(log_dir):
		DirAccess.make_dir_recursive_absolute(log_dir)
	
	# Nombre de archivo con fecha
	var date = Time.get_datetime_dict_from_system()
	var filename = "steel_titans_%04d%02d%02d_%02d%02d%02d.log" % [
		date.year, date.month, date.day,
		date.hour, date.minute, date.second
	]
	
	_log_path = log_dir + "/" + filename
	_log_file = FileAccess.open(_log_path, FileAccess.WRITE)
	
	if _log_file:
		# Escribir header
		_log_file.store_line("# Steel Titans Log File")
		_log_file.store_line("# Session: %s" % _session_id)
		_log_file.store_line("# Started: %s" % _get_timestamp())
		_log_file.store_line("# Format: timestamp|session|level|category|message|context")
		_log_file.store_line("#")
	else:
		push_error("[Logger] No se pudo crear archivo de log: %s" % _log_path)


func _init_sentry() -> void:
	# Verificar si SentrySDK está disponible como singleton
	if not ClassDB.class_exists("SentrySDK"):
		_sentry_available = false
		return
	
	# Obtener el singleton de Sentry de forma segura
	var sdk = Engine.get_singleton("SentrySDK")
	if sdk == null:
		_sentry_available = false
		return
	
	# Nota: Con auto_init=false, el SDK debe inicializarse manualmente
	# Pero si el GDExtension no está cargado, no podemos hacerlo
	# En ese caso, simplemente marcamos como no disponible
	_sentry_available = true
	
	# Configurar contexto de sesión usando acceso dinámico
	if _sentry_available and sdk:
		# Añadir tags para filtrado en Sentry dashboard
		sdk.set_tag("session_id", _session_id)
		sdk.set_tag("mode", "server" if _is_server else "client")
		sdk.set_tag("build", "debug" if OS.is_debug_build() else "release")
		sdk.set_tag("os", OS.get_name())
		sdk.set_tag("godot_version", Engine.get_version_info().string)
		
		# Añadir contexto extra
		sdk.set_context("game", {
			"name": "Steel Titans",
			"version": _get_version(),
			"session_id": _session_id
		})


func _send_to_sentry(level: Level, category: String, message: String, context: Dictionary) -> void:
	if not _sentry_available or not sentry_enabled:
		return
	
	var sdk = Engine.get_singleton("SentrySDK")
	if sdk == null:
		return
	
	var category_upper = category.to_upper()
	var full_message = "[%s] %s" % [category_upper, message]
	
	# Añadir breadcrumb para contexto usando helper seguro
	_add_sentry_breadcrumb(full_message, category.to_lower(), "default", _level_to_sentry_level(level), context)
	
	# Capturar evento según nivel
	if level == Level.CRITICAL:
		# Los críticos se envían como errores con nivel fatal (LEVEL_FATAL = 4)
		var event_id = sdk.capture_message(full_message, 4)
		if event_id:
			debug("System", "Sentry event enviado: %s" % event_id)
	elif level == Level.ERROR:
		# LEVEL_ERROR = 3
		var event_id = sdk.capture_message(full_message, 3)
		if event_id:
			debug("System", "Sentry event enviado: %s" % event_id)


func _level_to_sentry_level(level: Level) -> String:
	match level:
		Level.DEBUG:
			return "debug"
		Level.INFO:
			return "info"
		Level.WARNING:
			return "warning"
		Level.ERROR:
			return "error"
		Level.CRITICAL:
			return "fatal"
		_:
			return "info"


func _write_to_file(message: String) -> void:
	_log_buffer.append(message)
	
	if _log_buffer.size() >= _buffer_flush_size:
		_flush_buffer()


func _flush_buffer() -> void:
	if _log_file and not _log_buffer.is_empty():
		for msg in _log_buffer:
			_log_file.store_line(msg)
		_log_file.flush()
		_log_buffer.clear()


func _get_timestamp() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		dt.year, dt.month, dt.day,
		dt.hour, dt.minute, dt.second
	]


func _generate_session_id() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var id = ""
	for i in range(8):
		id += chars[randi() % chars.length()]
	return id


func _format_context(context: Dictionary) -> String:
	var parts: Array[String] = []
	for key in context:
		parts.append("%s=%s" % [key, str(context[key])])
	return ", ".join(parts)


func _get_version() -> String:
	# Podría leerse de project.godot o un archivo de versión
	return "0.1.0-alpha"


## ═══════════════════════════════════════════════════════════════════════════
## UTILIDADES ADICIONALES
## ═══════════════════════════════════════════════════════════════════════════

## Obtener ruta del archivo de log actual
func get_log_path() -> String:
	return _log_path


## Obtener ID de sesión actual
func get_session_id() -> String:
	return _session_id


## Limpiar logs antiguos (mantener últimos N días)
func cleanup_old_logs(days_to_keep: int = 7) -> int:
	var log_dir = "user://logs"
	var deleted_count = 0
	
	if not DirAccess.dir_exists_absolute(log_dir):
		return 0
	
	var dir = DirAccess.open(log_dir)
	if not dir:
		return 0
	
	var current_time = Time.get_unix_time_from_system()
	var max_age = days_to_keep * 24 * 60 * 60  # días a segundos
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".log"):
			var file_path = log_dir + "/" + file_name
			var file_time = FileAccess.get_modified_time(file_path)
			if current_time - file_time > max_age:
				dir.remove(file_name)
				deleted_count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if deleted_count > 0:
		info("System", "Logs antiguos eliminados: %d" % deleted_count)
	
	return deleted_count


## Exportar logs a una ubicación específica (para reports de bugs)
func export_logs(destination_path: String) -> bool:
	_flush_buffer()
	
	if not FileAccess.file_exists(_log_path):
		error("System", "No hay archivo de log para exportar")
		return false
	
	var source = FileAccess.open(_log_path, FileAccess.READ)
	if not source:
		error("System", "No se pudo abrir archivo de log")
		return false
	
	var dest = FileAccess.open(destination_path, FileAccess.WRITE)
	if not dest:
		source.close()
		error("System", "No se pudo crear archivo de destino: %s" % destination_path)
		return false
	
	dest.store_string(source.get_as_text())
	source.close()
	dest.close()
	
	info("System", "Logs exportados a: %s" % destination_path)
	return true


## Marcar inicio de una operación (para medir tiempos)\nvar _timers: Dictionary = {}\n\nfunc start_timer(timer_name: String) -> void:\n\t_timers[timer_name] = Time.get_ticks_msec()\n\n\nfunc end_timer(timer_name: String, category: String = "System") -> float:\n\tif not _timers.has(timer_name):\n\t\twarning(category, "Timer no encontrado: %s" % timer_name)\n\t\treturn -1.0\n\t\n\tvar elapsed = (Time.get_ticks_msec() - _timers[timer_name]) / 1000.0\n\t_timers.erase(timer_name)\n\tdebug(category, "Timer '%s' completado" % timer_name, {"elapsed_sec": "%.3f" % elapsed})\n\treturn elapsed
