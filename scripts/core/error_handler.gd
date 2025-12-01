## ErrorHandler - Sistema de Manejo de Errores Robusto para Steel Titans
## Autor: DAMSanti
## Versión: 1.0.0
##
## Proporciona:
##   - Categorización de errores por severidad y tipo
##   - Estrategias de recuperación automática
##   - Integración con Logger y Sentry
##   - Notificación al usuario cuando es necesario
##   - Historial de errores para debugging
##
## Uso:
##   var result = ErrorHandler.try_operation(func(): return risky_operation())
##   if result.is_error():
##       ErrorHandler.handle(result)
##
##   # O para operaciones simples:
##   ErrorHandler.safe_call(object, "method_name", [args])
##
class_name ErrorHandler
extends RefCounted


## ═══════════════════════════════════════════════════════════════════════════
## TIPOS Y ENUMERACIONES
## ═══════════════════════════════════════════════════════════════════════════

## Categorías de error para filtrado y métricas
enum ErrorCategory {
	NETWORK,      ## Errores de conexión, timeout, sincronización
	FILE_SYSTEM,  ## Errores de lectura/escritura de archivos
	GAME_STATE,   ## Estado de juego inválido o corrupto
	VALIDATION,   ## Datos de entrada inválidos
	RESOURCE,     ## Recursos no encontrados o corruptos
	DATABASE,     ## Errores de base de datos
	AUTHENTICATION, ## Errores de login/permisos
	UNKNOWN       ## Errores no categorizados
}

## Severidad del error
enum ErrorSeverity {
	LOW,      ## No afecta gameplay, solo loguear
	MEDIUM,   ## Afecta funcionalidad menor, notificar si persiste
	HIGH,     ## Afecta funcionalidad importante, notificar usuario
	CRITICAL  ## Puede crashear o corromper datos, acción inmediata
}

## Estrategias de recuperación
enum RecoveryStrategy {
	NONE,         ## No hacer nada, solo loguear
	RETRY,        ## Reintentar la operación
	FALLBACK,     ## Usar valor por defecto
	NOTIFY_USER,  ## Mostrar mensaje al usuario
	RECONNECT,    ## Intentar reconectar (para errores de red)
	RELOAD_STATE, ## Recargar estado del juego
	GRACEFUL_EXIT ## Salir de forma controlada
}

## Nombres de categorías para logging
const CATEGORY_NAMES: Dictionary = {
	ErrorCategory.NETWORK: "NETWORK",
	ErrorCategory.FILE_SYSTEM: "FILE_SYSTEM",
	ErrorCategory.GAME_STATE: "GAME_STATE",
	ErrorCategory.VALIDATION: "VALIDATION",
	ErrorCategory.RESOURCE: "RESOURCE",
	ErrorCategory.DATABASE: "DATABASE",
	ErrorCategory.AUTHENTICATION: "AUTH",
	ErrorCategory.UNKNOWN: "UNKNOWN"
}

## Nombres de severidad para logging
const SEVERITY_NAMES: Dictionary = {
	ErrorSeverity.LOW: "LOW",
	ErrorSeverity.MEDIUM: "MEDIUM",
	ErrorSeverity.HIGH: "HIGH",
	ErrorSeverity.CRITICAL: "CRITICAL"
}


## ═══════════════════════════════════════════════════════════════════════════
## CLASE RESULT - Para operaciones que pueden fallar
## ═══════════════════════════════════════════════════════════════════════════

## Clase Result para encapsular éxito o error de operaciones
class Result extends RefCounted:
	var _value: Variant = null
	var _error: GameError = null
	
	## Crear un Result exitoso
	static func ok(value: Variant = null) -> Result:
		var r := Result.new()
		r._value = value
		return r
	
	## Crear un Result con error
	static func err(game_error: GameError) -> Result:
		var r := Result.new()
		r._error = game_error
		return r
	
	## Crear un Result con error desde parámetros simples
	static func error(
		message: String,
		category: ErrorCategory = ErrorCategory.UNKNOWN,
		severity: ErrorSeverity = ErrorSeverity.MEDIUM,
		context: Dictionary = {}
	) -> Result:
		var game_error := GameError.new(message, category, severity, context)
		return err(game_error)
	
	## ¿Es exitoso?
	func is_ok() -> bool:
		return _error == null
	
	## ¿Es error?
	func is_error() -> bool:
		return _error != null
	
	## Obtener valor (solo si es ok)
	func unwrap() -> Variant:
		if is_error():
			push_error("Intentando unwrap un Result con error: %s" % _error.message)
			return null
		return _value
	
	## Obtener valor o un valor por defecto
	func unwrap_or(default: Variant) -> Variant:
		if is_error():
			return default
		return _value
	
	## Obtener el error (solo si es error)
	func get_error() -> GameError:
		return _error
	
	## Ejecutar callback si es ok
	func on_ok(callback: Callable) -> Result:
		if is_ok():
			callback.call(_value)
		return self
	
	## Ejecutar callback si es error
	func on_error(callback: Callable) -> Result:
		if is_error():
			callback.call(_error)
		return self


## ═══════════════════════════════════════════════════════════════════════════
## CLASE GAMEERROR - Representa un error del juego
## ═══════════════════════════════════════════════════════════════════════════

## Clase que encapsula información completa de un error
class GameError extends RefCounted:
	var message: String = ""
	var category: ErrorCategory = ErrorCategory.UNKNOWN
	var severity: ErrorSeverity = ErrorSeverity.MEDIUM
	var context: Dictionary = {}
	var timestamp: int = 0
	var stack_trace: String = ""
	var error_code: String = ""
	var recovery_strategy: RecoveryStrategy = RecoveryStrategy.NONE
	var retry_count: int = 0
	var max_retries: int = 3
	
	func _init(
		p_message: String,
		p_category: ErrorCategory = ErrorCategory.UNKNOWN,
		p_severity: ErrorSeverity = ErrorSeverity.MEDIUM,
		p_context: Dictionary = {}
	) -> void:
		message = p_message
		category = p_category
		severity = p_severity
		context = p_context
		timestamp = Time.get_ticks_msec()
		error_code = _generate_error_code()
		recovery_strategy = _suggest_recovery_strategy()
		_capture_stack_trace()
	
	## Generar código único de error para referencia
	func _generate_error_code() -> String:
		var cat_prefix: String = CATEGORY_NAMES.get(category, "UNK")
		var hash_part: String = str(hash(message)).substr(0, 4)
		return "%s-%s" % [cat_prefix, hash_part]
	
	## Sugerir estrategia de recuperación basada en categoría
	func _suggest_recovery_strategy() -> RecoveryStrategy:
		match category:
			ErrorCategory.NETWORK:
				return RecoveryStrategy.RECONNECT
			ErrorCategory.FILE_SYSTEM:
				return RecoveryStrategy.RETRY
			ErrorCategory.GAME_STATE:
				return RecoveryStrategy.RELOAD_STATE
			ErrorCategory.VALIDATION:
				return RecoveryStrategy.NOTIFY_USER
			ErrorCategory.RESOURCE:
				return RecoveryStrategy.FALLBACK
			ErrorCategory.DATABASE:
				return RecoveryStrategy.RETRY
			ErrorCategory.AUTHENTICATION:
				return RecoveryStrategy.NOTIFY_USER
			_:
				return RecoveryStrategy.NONE
	
	## Capturar stack trace para debugging
	func _capture_stack_trace() -> void:
		var stack := get_stack()
		if stack.is_empty():
			return
		
		var lines: Array[String] = []
		# Saltar los primeros frames que son del ErrorHandler
		var start_idx := mini(3, stack.size())
		for i in range(start_idx, mini(start_idx + 5, stack.size())):
			var frame: Dictionary = stack[i]
			lines.append("  at %s:%d in %s()" % [
				frame.get("source", "unknown"),
				frame.get("line", 0),
				frame.get("function", "unknown")
			])
		stack_trace = "\n".join(lines)
	
	## Convertir a diccionario para serialización
	func to_dict() -> Dictionary:
		return {
			"message": message,
			"category": CATEGORY_NAMES.get(category, "UNKNOWN"),
			"severity": SEVERITY_NAMES.get(severity, "MEDIUM"),
			"error_code": error_code,
			"timestamp": timestamp,
			"context": context,
			"stack_trace": stack_trace,
			"retry_count": retry_count
		}
	
	## Representación en string
	func _to_string() -> String:
		return "[%s] %s: %s" % [error_code, CATEGORY_NAMES.get(category, "UNK"), message]


## ═══════════════════════════════════════════════════════════════════════════
## ESTADO ESTÁTICO
## ═══════════════════════════════════════════════════════════════════════════

## Historial de errores recientes (para debugging y métricas)
static var _error_history: Array[GameError] = []
static var _max_history_size: int = 100

## Contadores por categoría (para métricas)
static var _error_counts: Dictionary = {}

## Callbacks para notificación de errores
static var _error_callbacks: Array[Callable] = []

## Callback para mostrar mensajes al usuario
static var _user_notification_callback: Callable = Callable()

## Callback para reconexión
static var _reconnect_callback: Callable = Callable()

## Callback para recargar estado
static var _reload_state_callback: Callable = Callable()


## ═══════════════════════════════════════════════════════════════════════════
## API PÚBLICA - Manejo de errores
## ═══════════════════════════════════════════════════════════════════════════

## Manejar un error completo
static func handle(result: Result, auto_recover: bool = true) -> void:
	if result.is_ok():
		return
	
	var error := result.get_error()
	_record_error(error)
	_log_error(error)
	
	if auto_recover:
		_execute_recovery(error)


## Manejar un GameError directamente
static func handle_error(error: GameError, auto_recover: bool = true) -> void:
	_record_error(error)
	_log_error(error)
	
	if auto_recover:
		_execute_recovery(error)


## Crear y manejar un error rápidamente
static func report(
	message: String,
	category: ErrorCategory = ErrorCategory.UNKNOWN,
	severity: ErrorSeverity = ErrorSeverity.MEDIUM,
	context: Dictionary = {},
	auto_recover: bool = true
) -> GameError:
	var error := GameError.new(message, category, severity, context)
	handle_error(error, auto_recover)
	return error


## Ejecutar una operación de forma segura
static func try_operation(operation: Callable) -> Result:
	# En GDScript no hay try/catch real, pero podemos envolver la operación
	var result: Variant = operation.call()
	
	# Si la operación retorna un Result, usarlo directamente
	if result is Result:
		return result
	
	# Si retorna null y era esperado un valor, considerarlo error
	# (esto es una heurística, el caller debería usar Result explícitamente)
	return Result.ok(result)


## Llamar un método de forma segura
static func safe_call(
	obj: Object,
	method: String,
	args: Array = [],
	default_value: Variant = null
) -> Variant:
	if obj == null:
		report(
			"Objeto null al llamar '%s'" % method,
			ErrorCategory.GAME_STATE,
			ErrorSeverity.MEDIUM,
			{"method": method}
		)
		return default_value
	
	if not obj.has_method(method):
		report(
			"Método '%s' no existe en %s" % [method, obj.get_class()],
			ErrorCategory.GAME_STATE,
			ErrorSeverity.MEDIUM,
			{"method": method, "class": obj.get_class()}
		)
		return default_value
	
	return obj.callv(method, args)


## Verificar condición y reportar error si falla (como assert pero sin crash)
static func check(
	condition: bool,
	message: String,
	category: ErrorCategory = ErrorCategory.VALIDATION,
	severity: ErrorSeverity = ErrorSeverity.MEDIUM,
	context: Dictionary = {}
) -> bool:
	if not condition:
		report(message, category, severity, context, false)
	return condition


## Verificar que un valor no sea null
static func check_not_null(
	value: Variant,
	value_name: String,
	category: ErrorCategory = ErrorCategory.VALIDATION
) -> bool:
	if value == null:
		report(
			"Valor '%s' es null" % value_name,
			category,
			ErrorSeverity.MEDIUM,
			{"value_name": value_name}
		)
		return false
	return true


## ═══════════════════════════════════════════════════════════════════════════
## API PÚBLICA - Operaciones de archivo seguras
## ═══════════════════════════════════════════════════════════════════════════

## Leer archivo JSON de forma segura
static func safe_read_json(path: String, _default_value: Variant = null) -> Result:
	if not FileAccess.file_exists(path):
		return Result.error(
			"Archivo no encontrado: %s" % path,
			ErrorCategory.FILE_SYSTEM,
			ErrorSeverity.MEDIUM,
			{"path": path}
		)
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Result.error(
			"No se puede abrir archivo: %s (Error: %s)" % [path, FileAccess.get_open_error()],
			ErrorCategory.FILE_SYSTEM,
			ErrorSeverity.MEDIUM,
			{"path": path, "error_code": FileAccess.get_open_error()}
		)
	
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(content)
	if parse_result != OK:
		return Result.error(
			"JSON inválido en %s: %s (línea %d)" % [path, json.get_error_message(), json.get_error_line()],
			ErrorCategory.FILE_SYSTEM,
			ErrorSeverity.MEDIUM,
			{"path": path, "error_line": json.get_error_line()}
		)
	
	return Result.ok(json.get_data())


## Escribir archivo JSON de forma segura
static func safe_write_json(path: String, data: Variant, indent: String = "\t") -> Result:
	# Asegurar que el directorio existe
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err := DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			return Result.error(
				"No se puede crear directorio: %s" % dir_path,
				ErrorCategory.FILE_SYSTEM,
				ErrorSeverity.HIGH,
				{"path": dir_path, "error_code": err}
			)
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return Result.error(
			"No se puede escribir archivo: %s (Error: %s)" % [path, FileAccess.get_open_error()],
			ErrorCategory.FILE_SYSTEM,
			ErrorSeverity.HIGH,
			{"path": path, "error_code": FileAccess.get_open_error()}
		)
	
	var json_string := JSON.stringify(data, indent)
	file.store_string(json_string)
	file.close()
	
	return Result.ok(true)


## Leer archivo de texto de forma segura
static func safe_read_text(path: String) -> Result:
	if not FileAccess.file_exists(path):
		return Result.error(
			"Archivo no encontrado: %s" % path,
			ErrorCategory.FILE_SYSTEM,
			ErrorSeverity.MEDIUM,
			{"path": path}
		)
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Result.error(
			"No se puede abrir archivo: %s" % path,
			ErrorCategory.FILE_SYSTEM,
			ErrorSeverity.MEDIUM,
			{"path": path, "error_code": FileAccess.get_open_error()}
		)
	
	var content := file.get_as_text()
	file.close()
	return Result.ok(content)


## ═══════════════════════════════════════════════════════════════════════════
## API PÚBLICA - Configuración
## ═══════════════════════════════════════════════════════════════════════════

## Registrar callback para cuando ocurra un error
static func on_error(callback: Callable) -> void:
	_error_callbacks.append(callback)


## Registrar callback para notificar al usuario
static func set_user_notification_callback(callback: Callable) -> void:
	_user_notification_callback = callback


## Registrar callback para reconexión
static func set_reconnect_callback(callback: Callable) -> void:
	_reconnect_callback = callback


## Registrar callback para recargar estado
static func set_reload_state_callback(callback: Callable) -> void:
	_reload_state_callback = callback


## Obtener historial de errores
static func get_error_history() -> Array[GameError]:
	return _error_history.duplicate()


## Obtener conteo de errores por categoría
static func get_error_counts() -> Dictionary:
	return _error_counts.duplicate()


## Limpiar historial de errores
static func clear_history() -> void:
	_error_history.clear()
	_error_counts.clear()


## Obtener último error
static func get_last_error() -> GameError:
	if _error_history.is_empty():
		return null
	return _error_history[-1]


## ═══════════════════════════════════════════════════════════════════════════
## MÉTODOS PRIVADOS
## ═══════════════════════════════════════════════════════════════════════════

## Registrar error en historial
static func _record_error(error: GameError) -> void:
	_error_history.append(error)
	
	# Mantener tamaño máximo del historial
	while _error_history.size() > _max_history_size:
		_error_history.pop_front()
	
	# Incrementar contador
	var cat_name: String = CATEGORY_NAMES.get(error.category, "UNKNOWN")
	_error_counts[cat_name] = _error_counts.get(cat_name, 0) + 1
	
	# Notificar callbacks
	for callback in _error_callbacks:
		if callback.is_valid():
			callback.call(error)


## Loguear error usando el sistema de Logger
static func _log_error(error: GameError) -> void:
	# Usar el autoload Log si está disponible
	var log_category: String = CATEGORY_NAMES.get(error.category, "System")
	var context := error.context.duplicate()
	context["error_code"] = error.error_code
	context["severity"] = SEVERITY_NAMES.get(error.severity, "MEDIUM")
	
	if not error.stack_trace.is_empty():
		context["stack"] = error.stack_trace
	
	# Determinar nivel de log según severidad
	match error.severity:
		ErrorSeverity.LOW:
			if Engine.has_singleton("Log"):
				Engine.get_singleton("Log").warning(log_category, error.message, context)
			else:
				push_warning("[%s] %s | %s" % [error.error_code, error.message, str(context)])
		ErrorSeverity.MEDIUM:
			if Engine.has_singleton("Log"):
				Engine.get_singleton("Log").error(log_category, error.message, context)
			else:
				push_error("[%s] %s | %s" % [error.error_code, error.message, str(context)])
		ErrorSeverity.HIGH, ErrorSeverity.CRITICAL:
			if Engine.has_singleton("Log"):
				Engine.get_singleton("Log").critical(log_category, error.message, context)
			else:
				push_error("[CRITICAL][%s] %s | %s" % [error.error_code, error.message, str(context)])


## Ejecutar estrategia de recuperación
static func _execute_recovery(error: GameError) -> void:
	match error.recovery_strategy:
		RecoveryStrategy.NONE:
			pass  # Solo loguear
		
		RecoveryStrategy.RETRY:
			# El retry debe manejarse externamente con retry_operation()
			pass
		
		RecoveryStrategy.FALLBACK:
			# El fallback se maneja con unwrap_or()
			pass
		
		RecoveryStrategy.NOTIFY_USER:
			_notify_user(error)
		
		RecoveryStrategy.RECONNECT:
			_attempt_reconnect(error)
		
		RecoveryStrategy.RELOAD_STATE:
			_reload_game_state(error)
		
		RecoveryStrategy.GRACEFUL_EXIT:
			_graceful_exit(error)


## Notificar al usuario del error
static func _notify_user(error: GameError) -> void:
	if _user_notification_callback.is_valid():
		_user_notification_callback.call(error.message, error.severity)
	else:
		# Fallback: solo loguear que deberíamos notificar
		push_warning("User notification pending: %s" % error.message)


## Intentar reconectar
static func _attempt_reconnect(_error: GameError) -> void:
	if _reconnect_callback.is_valid():
		_reconnect_callback.call()
	else:
		push_warning("Reconnect callback not set")


## Recargar estado del juego
static func _reload_game_state(_error: GameError) -> void:
	if _reload_state_callback.is_valid():
		_reload_state_callback.call()
	else:
		push_warning("Reload state callback not set")


## Salida controlada
static func _graceful_exit(error: GameError) -> void:
	push_error("CRITICAL ERROR - Exiting: %s" % error.message)
	# Dar tiempo para que se envíen logs a Sentry
	if Engine.has_singleton("Log"):
		Engine.get_singleton("Log").critical("System", "Graceful exit due to: %s" % error.message)
	
	# En producción, podríamos guardar estado antes de salir
	# Por ahora solo cerramos
	if not OS.is_debug_build():
		OS.kill(OS.get_process_id())


## ═══════════════════════════════════════════════════════════════════════════
## UTILIDADES ADICIONALES
## ═══════════════════════════════════════════════════════════════════════════

## Ejecutar operación con reintentos
static func retry_operation(
	operation: Callable,
	max_retries: int = 3,
	_delay_ms: int = 1000,
	_category: ErrorCategory = ErrorCategory.UNKNOWN
) -> Result:
	var last_error: GameError = null
	
	for attempt in range(max_retries):
		var result := try_operation(operation)
		
		if result.is_ok():
			return result
		
		last_error = result.get_error()
		last_error.retry_count = attempt + 1
		
		# Esperar antes del siguiente intento (solo loguear, el delay real
		# necesitaría ser async con await)
		if attempt < max_retries - 1:
			push_warning("Retry %d/%d for: %s" % [attempt + 1, max_retries, last_error.message])
	
	# Todos los reintentos fallaron
	if last_error:
		last_error.severity = ErrorSeverity.HIGH
		handle_error(last_error)
	
	return Result.err(last_error)


## Generar reporte de errores para debugging
static func generate_error_report() -> String:
	var lines: Array[String] = []
	lines.append("═══════════════════════════════════════════")
	lines.append("ERROR REPORT - Steel Titans")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system())
	lines.append("═══════════════════════════════════════════")
	lines.append("")
	
	# Resumen de conteos
	lines.append("ERROR COUNTS BY CATEGORY:")
	for cat_name in _error_counts:
		lines.append("  %s: %d" % [cat_name, _error_counts[cat_name]])
	lines.append("")
	
	# Últimos errores
	lines.append("RECENT ERRORS (last 10):")
	var start_idx := maxi(0, _error_history.size() - 10)
	for i in range(start_idx, _error_history.size()):
		var error := _error_history[i]
		lines.append("  [%s] %s" % [error.error_code, error.message])
		if not error.stack_trace.is_empty():
			for stack_line in error.stack_trace.split("\n"):
				lines.append("    %s" % stack_line)
	
	lines.append("")
	lines.append("═══════════════════════════════════════════")
	
	return "\n".join(lines)
