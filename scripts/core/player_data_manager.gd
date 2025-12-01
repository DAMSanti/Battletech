## PlayerDataManager - Sistema de Auto-Guardado para Steel Titans
## Autor: DAMSanti  
## Versión: 1.0.0
##
## Sistema de persistencia de datos del jugador con auto-guardado.
## 
## Características:
##   - Auto-save automático (NO hay botón manual de guardar)
##   - Sync periódico cada 5 minutos si hay cambios
##   - Servidor es SIEMPRE fuente de verdad en modo online
##   - Modo offline aislado (no se sincroniza con online)
##   - Reconexión mid-game: 3 minutos de ventana
##
## Datos gestionados:
##   - ProgressData: XP, nivel, wins/losses, currency
##   - SettingsData: Audio, gráficos, controles
##   - InventoryData: Mechs comprados, loadouts
##
## Triggers de auto-save:
##   - Login: Carga datos del servidor
##   - Fin de partida: XP, wins/losses
##   - Mech Bay: Configuración de loadouts
##   - Compra: Transacciones
##   - Settings: Preferencias (solo local)
##   - Timer: Cada 5 minutos si dirty_flag = true
##   - Logout: Flush final
##
## Uso:
##   PlayerDataManager.load_player_data(user_id)
##   PlayerDataManager.add_xp(100)
##   PlayerDataManager.record_match_result(true)  # win
##   PlayerDataManager.save_settings(settings_data)
##
## Note: class_name para evitar conflicto con autoload singleton
class_name PlayerDataManagerCore
extends RefCounted


## ═══════════════════════════════════════════════════════════════════════════
## CONSTANTES
## ═══════════════════════════════════════════════════════════════════════════

## Intervalo de sync periódico (en segundos)
const SYNC_INTERVAL: float = 300.0  # 5 minutos

## Tiempo máximo para reconexión mid-game (en segundos)
const RECONNECT_TIMEOUT: float = 180.0  # 3 minutos

## Ruta de guardado local
const LOCAL_SAVE_PATH: String = "user://player_data.save"
const OFFLINE_SAVE_PATH: String = "user://offline_player_data.save"
const SETTINGS_PATH: String = "user://settings.save"

## Versión del formato de guardado (para migraciones)
## IMPORTANTE: Incrementar cada vez que cambie la estructura de datos
## y añadir la función de migración correspondiente en _MIGRATIONS
const SAVE_VERSION: int = 2

## Categoría de log
const LOG_CATEGORY: String = "SAVE"


## ═══════════════════════════════════════════════════════════════════════════
## SEÑALES
## ═══════════════════════════════════════════════════════════════════════════

## Emitida cuando los datos se cargan exitosamente
signal data_loaded(progress: ProgressData)

## Emitida cuando los datos se guardan exitosamente  
signal data_saved()

## Emitida cuando falla una operación de datos
signal data_error(error: DataError)

## Emitida cuando hay un conflicto de sincronización (reservada para API futura)
@warning_ignore("unused_signal")
signal sync_conflict(local_data: ProgressData, server_data: ProgressData)

## Emitida cuando cambia el dirty flag
signal dirty_state_changed(is_dirty: bool)

## Emitida cuando se detecta progreso offline pendiente (reservada para API futura)
@warning_ignore("unused_signal")
signal offline_progress_detected(offline_data: ProgressData)


## ═══════════════════════════════════════════════════════════════════════════
## ENUMERACIONES
## ═══════════════════════════════════════════════════════════════════════════

## Modo de operación
enum DataMode {
	ONLINE,     ## Conectado al servidor (fuente de verdad: servidor)
	OFFLINE,    ## Sin conexión (progreso aislado)
}

## Tipos de error
enum DataErrorType {
	NONE,
	LOAD_FAILED,
	SAVE_FAILED,
	SYNC_FAILED,
	NETWORK_ERROR,
	INVALID_DATA,
	VERSION_MISMATCH,
	PERMISSION_DENIED,
	CHECKSUM_FAILED,  ## Datos corruptos (checksum no coincide)
}

## Tipos de trigger de auto-save
enum SaveTrigger {
	LOGIN,
	LOGOUT,
	MATCH_END,
	MECH_BAY,
	PURCHASE,
	SETTINGS,
	PERIODIC,
	MANUAL,  # Solo para debug/admin
}


## ═══════════════════════════════════════════════════════════════════════════
## CLASE ProgressData - Progresión del jugador
## ═══════════════════════════════════════════════════════════════════════════

class ProgressData extends RefCounted:
	## Identificación
	var user_id: String = ""
	
	## Progresión
	var xp: int = 0
	var level: int = 1
	
	## Estadísticas de partidas
	var wins: int = 0
	var losses: int = 0
	var draws: int = 0
	var total_matches: int = 0
	
	## Economía
	var credits: int = 1000  # Créditos de Titanio (CT) - moneda principal
	var premium_credits: int = 0  # Moneda premium (compra real)
	
	## Rankings
	var elo_rating: int = 1000
	var rank_tier: int = 0  # Bronze, Silver, Gold, etc.
	var season_wins: int = 0
	
	## Timestamps
	var created_at: int = 0
	var last_updated: int = 0
	var last_match_at: int = 0
	
	## Metadatos
	var version: int = SAVE_VERSION
	
	## Campos añadidos en v2
	var achievements: Array[String] = []  # IDs de logros desbloqueados
	var tutorial_completed: bool = false  # Si completó el tutorial
	
	func _init(p_user_id: String = "") -> void:
		user_id = p_user_id
		created_at = int(Time.get_unix_time_from_system())
		last_updated = created_at
	
	## Calcula el nivel basado en XP
	static func calculate_level(total_xp: int) -> int:
		# Fórmula: XP necesario = nivel * 100
		# Nivel 1: 0 XP, Nivel 2: 100 XP, Nivel 3: 300 XP, etc.
		var current_level: int = 1
		var xp_for_next: int = 100
		var accumulated_xp: int = 0
		
		while accumulated_xp + xp_for_next <= total_xp:
			accumulated_xp += xp_for_next
			current_level += 1
			xp_for_next = current_level * 100
		
		return current_level
	
	## XP necesario para el siguiente nivel
	func xp_for_next_level() -> int:
		return level * 100
	
	## XP actual dentro del nivel
	func xp_in_current_level() -> int:
		var xp_at_level_start: int = 0
		for i in range(1, level):
			xp_at_level_start += i * 100
		return xp - xp_at_level_start
	
	## Porcentaje de progreso al siguiente nivel
	func level_progress_percent() -> float:
		var current: float = float(xp_in_current_level())
		var needed: float = float(xp_for_next_level())
		return (current / needed) * 100.0 if needed > 0 else 0.0
	
	## Win rate
	func win_rate() -> float:
		if total_matches == 0:
			return 0.0
		return (float(wins) / float(total_matches)) * 100.0
	
	## Serializa a diccionario
	func to_dict() -> Dictionary:
		return {
			"version": version,
			"user_id": user_id,
			"xp": xp,
			"level": level,
			"wins": wins,
			"losses": losses,
			"draws": draws,
			"total_matches": total_matches,
			"credits": credits,
			"premium_credits": premium_credits,
			"elo_rating": elo_rating,
			"rank_tier": rank_tier,
			"season_wins": season_wins,
			"created_at": created_at,
			"last_updated": last_updated,
			"last_match_at": last_match_at,
			# Campos v2
			"achievements": achievements,
			"tutorial_completed": tutorial_completed,
		}
	
	## Crea desde diccionario
	static func from_dict(data: Dictionary) -> ProgressData:
		var prog := ProgressData.new()
		prog.version = data.get("version", SAVE_VERSION)
		prog.user_id = data.get("user_id", "")
		prog.xp = data.get("xp", 0)
		prog.level = data.get("level", 1)
		prog.wins = data.get("wins", 0)
		prog.losses = data.get("losses", 0)
		prog.draws = data.get("draws", 0)
		prog.total_matches = data.get("total_matches", 0)
		prog.credits = data.get("credits", 1000)
		prog.premium_credits = data.get("premium_credits", 0)
		prog.elo_rating = data.get("elo_rating", 1000)
		prog.rank_tier = data.get("rank_tier", 0)
		prog.season_wins = data.get("season_wins", 0)
		prog.created_at = data.get("created_at", 0)
		prog.last_updated = data.get("last_updated", 0)
		prog.last_match_at = data.get("last_match_at", 0)
		# Campos v2 (con defaults para datos antiguos)
		var achievements_arr: Array = data.get("achievements", [])
		prog.achievements = []
		for a in achievements_arr:
			prog.achievements.append(str(a))
		prog.tutorial_completed = data.get("tutorial_completed", false)
		return prog
	
	## Crea una copia
	func duplicate() -> ProgressData:
		return ProgressData.from_dict(to_dict())


## ═══════════════════════════════════════════════════════════════════════════
## CLASE SettingsData - Preferencias del jugador (solo local)
## ═══════════════════════════════════════════════════════════════════════════

class SettingsData extends RefCounted:
	## Audio
	var master_volume: float = 1.0
	var music_volume: float = 0.8
	var sfx_volume: float = 1.0
	var voice_volume: float = 1.0
	var mute_all: bool = false
	
	## Gráficos
	var quality_preset: int = 1  # 0=Low, 1=Medium, 2=High
	var vsync_enabled: bool = true
	var show_fps: bool = false
	var screen_shake: bool = true
	var particle_effects: bool = true
	
	## Controles
	var touch_sensitivity: float = 1.0
	var invert_pan: bool = false
	var confirm_end_turn: bool = true
	var show_move_preview: bool = true
	var show_attack_preview: bool = true
	
	## Accesibilidad
	var colorblind_mode: int = 0  # 0=Off, 1=Protanopia, 2=Deuteranopia, 3=Tritanopia
	var large_text: bool = false
	var reduce_motion: bool = false
	
	## Idioma
	var language: String = "es"
	
	## Notificaciones
	var push_notifications: bool = true
	var sound_notifications: bool = true
	
	## Versión
	var version: int = SAVE_VERSION
	
	## Serializa a diccionario
	func to_dict() -> Dictionary:
		return {
			"version": version,
			# Audio
			"master_volume": master_volume,
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
			"voice_volume": voice_volume,
			"mute_all": mute_all,
			# Gráficos
			"quality_preset": quality_preset,
			"vsync_enabled": vsync_enabled,
			"show_fps": show_fps,
			"screen_shake": screen_shake,
			"particle_effects": particle_effects,
			# Controles
			"touch_sensitivity": touch_sensitivity,
			"invert_pan": invert_pan,
			"confirm_end_turn": confirm_end_turn,
			"show_move_preview": show_move_preview,
			"show_attack_preview": show_attack_preview,
			# Accesibilidad
			"colorblind_mode": colorblind_mode,
			"large_text": large_text,
			"reduce_motion": reduce_motion,
			# Idioma
			"language": language,
			# Notificaciones
			"push_notifications": push_notifications,
			"sound_notifications": sound_notifications,
		}
	
	## Crea desde diccionario
	static func from_dict(data: Dictionary) -> SettingsData:
		var settings := SettingsData.new()
		settings.version = data.get("version", SAVE_VERSION)
		# Audio
		settings.master_volume = data.get("master_volume", 1.0)
		settings.music_volume = data.get("music_volume", 0.8)
		settings.sfx_volume = data.get("sfx_volume", 1.0)
		settings.voice_volume = data.get("voice_volume", 1.0)
		settings.mute_all = data.get("mute_all", false)
		# Gráficos
		settings.quality_preset = data.get("quality_preset", 1)
		settings.vsync_enabled = data.get("vsync_enabled", true)
		settings.show_fps = data.get("show_fps", false)
		settings.screen_shake = data.get("screen_shake", true)
		settings.particle_effects = data.get("particle_effects", true)
		# Controles
		settings.touch_sensitivity = data.get("touch_sensitivity", 1.0)
		settings.invert_pan = data.get("invert_pan", false)
		settings.confirm_end_turn = data.get("confirm_end_turn", true)
		settings.show_move_preview = data.get("show_move_preview", true)
		settings.show_attack_preview = data.get("show_attack_preview", true)
		# Accesibilidad
		settings.colorblind_mode = data.get("colorblind_mode", 0)
		settings.large_text = data.get("large_text", false)
		settings.reduce_motion = data.get("reduce_motion", false)
		# Idioma
		settings.language = data.get("language", "es")
		# Notificaciones
		settings.push_notifications = data.get("push_notifications", true)
		settings.sound_notifications = data.get("sound_notifications", true)
		return settings


## ═══════════════════════════════════════════════════════════════════════════
## CLASE InventoryData - Mechs y equipamiento del jugador
## ═══════════════════════════════════════════════════════════════════════════

class InventoryData extends RefCounted:
	var user_id: String = ""
	
	## Mechs desbloqueados (array de mech_ids)
	var owned_mechs: Array[String] = []
	
	## Loadouts guardados (mech_id -> array de loadout dicts)
	var saved_loadouts: Dictionary = {}
	
	## Cosméticos desbloqueados
	var owned_skins: Array[String] = []
	var owned_camos: Array[String] = []
	var owned_emblems: Array[String] = []
	
	## Equipamiento activo
	var active_loadout_per_mech: Dictionary = {}  # mech_id -> loadout_index
	
	## Versión
	var version: int = SAVE_VERSION
	var last_updated: int = 0
	
	## Campos añadidos en v2
	var favorite_mechs: Array[String] = []  # IDs de mechs marcados como favoritos
	
	func _init(p_user_id: String = "") -> void:
		user_id = p_user_id
		last_updated = int(Time.get_unix_time_from_system())
		# Mechs iniciales gratis
		owned_mechs = ["locust", "commando", "jenner"]  # Ligeros básicos
	
	## Serializa a diccionario
	func to_dict() -> Dictionary:
		return {
			"version": version,
			"user_id": user_id,
			"owned_mechs": owned_mechs,
			"saved_loadouts": saved_loadouts,
			"owned_skins": owned_skins,
			"owned_camos": owned_camos,
			"owned_emblems": owned_emblems,
			"active_loadout_per_mech": active_loadout_per_mech,
			"last_updated": last_updated,
			# Campos v2
			"favorite_mechs": favorite_mechs,
		}
	
	## Crea desde diccionario
	static func from_dict(data: Dictionary) -> InventoryData:
		var inv := InventoryData.new()
		inv.version = data.get("version", SAVE_VERSION)
		inv.user_id = data.get("user_id", "")
		
		# Convertir arrays tipados
		var mechs: Array = data.get("owned_mechs", [])
		inv.owned_mechs = []
		for m in mechs:
			inv.owned_mechs.append(str(m))
		
		inv.saved_loadouts = data.get("saved_loadouts", {})
		
		var skins: Array = data.get("owned_skins", [])
		inv.owned_skins = []
		for s in skins:
			inv.owned_skins.append(str(s))
		
		var camos: Array = data.get("owned_camos", [])
		inv.owned_camos = []
		for c in camos:
			inv.owned_camos.append(str(c))
		
		var emblems: Array = data.get("owned_emblems", [])
		inv.owned_emblems = []
		for e in emblems:
			inv.owned_emblems.append(str(e))
		
		inv.active_loadout_per_mech = data.get("active_loadout_per_mech", {})
		inv.last_updated = data.get("last_updated", 0)
		
		# Campos v2 (con defaults para datos antiguos)
		var favorites: Array = data.get("favorite_mechs", [])
		inv.favorite_mechs = []
		for f in favorites:
			inv.favorite_mechs.append(str(f))
		
		return inv


## ═══════════════════════════════════════════════════════════════════════════
## CLASE DataError - Error de operación de datos
## ═══════════════════════════════════════════════════════════════════════════

class DataError extends RefCounted:
	var type: DataErrorType = DataErrorType.NONE
	var message: String = ""
	var details: Dictionary = {}
	
	func _init(
		p_type: DataErrorType = DataErrorType.NONE,
		p_message: String = ""
	) -> void:
		type = p_type
		message = p_message
	
	## Mensaje para el usuario
	func get_user_message() -> String:
		match type:
			DataErrorType.LOAD_FAILED:
				return "No se pudieron cargar los datos"
			DataErrorType.SAVE_FAILED:
				return "No se pudieron guardar los datos"
			DataErrorType.SYNC_FAILED:
				return "Error al sincronizar con el servidor"
			DataErrorType.NETWORK_ERROR:
				return "Error de conexión"
			DataErrorType.INVALID_DATA:
				return "Datos corruptos"
			DataErrorType.VERSION_MISMATCH:
				return "Versión incompatible, actualiza el juego"
			DataErrorType.PERMISSION_DENIED:
				return "Acceso denegado"
			DataErrorType.CHECKSUM_FAILED:
				return "Los datos están corruptos y no pueden cargarse"
			_:
				return "Error desconocido"


## ═══════════════════════════════════════════════════════════════════════════
## SISTEMA DE MIGRACIONES
## ═══════════════════════════════════════════════════════════════════════════
##
## Cada vez que cambie la estructura de datos guardados:
## 1. Incrementar SAVE_VERSION
## 2. Añadir función _migrate_vX_to_vY que transforme los datos
## 3. Añadir entrada en get_migration_for_version()
##
## Las migraciones se ejecutan en orden: v1→v2→v3→...→SAVE_VERSION
##
## IMPORTANTE: Las migraciones deben ser idempotentes y no destructivas

## Resultado de migración
class MigrationResult extends RefCounted:
	var success: bool = false
	var data: Dictionary = {}
	var from_version: int = 0
	var to_version: int = 0
	var error_message: String = ""
	var migrations_applied: Array[int] = []
	
	static func ok(p_data: Dictionary, p_from: int, p_to: int, p_applied: Array[int]) -> MigrationResult:
		var result := MigrationResult.new()
		result.success = true
		result.data = p_data
		result.from_version = p_from
		result.to_version = p_to
		result.migrations_applied = p_applied
		return result
	
	static func fail(p_message: String, p_from: int) -> MigrationResult:
		var result := MigrationResult.new()
		result.success = false
		result.error_message = p_message
		result.from_version = p_from
		return result


## Ejecuta todas las migraciones necesarias desde la versión guardada hasta SAVE_VERSION
static func migrate_data(data: Dictionary) -> MigrationResult:
	var saved_version: int = int(data.get("version", 1))
	
	# Versión futura - no podemos migrar hacia atrás
	if saved_version > SAVE_VERSION:
		return MigrationResult.fail(
			"Los datos son de una versión más nueva (%d) que el juego (%d)" % [saved_version, SAVE_VERSION],
			saved_version
		)
	
	# Si ya está en la versión actual, no hay nada que hacer
	if saved_version == SAVE_VERSION:
		return MigrationResult.ok(data, saved_version, SAVE_VERSION, [])
	
	# Ejecutar migraciones secuencialmente
	var migrated_data: Dictionary = data.duplicate(true)
	var applied: Array[int] = []
	
	for version in range(saved_version, SAVE_VERSION):
		var migration: Callable = _get_migration_for_version(version + 1)
		if migration.is_null():
			return MigrationResult.fail(
				"No existe migración para versión %d" % (version + 1),
				saved_version
			)
		
		# Ejecutar migración
		var result: Dictionary = migration.call(migrated_data)
		if result.is_empty():
			return MigrationResult.fail(
				"Migración a v%d falló" % (version + 1),
				saved_version
			)
		
		migrated_data = result
		migrated_data["version"] = version + 1
		applied.append(version + 1)
	
	return MigrationResult.ok(migrated_data, saved_version, SAVE_VERSION, applied)


## Retorna la función de migración para una versión específica
## Cada migración transforma de vN-1 a vN
static func _get_migration_for_version(target_version: int) -> Callable:
	match target_version:
		2:
			return _migrate_v1_to_v2
		# Añadir futuras migraciones aquí:
		# 3: return _migrate_v2_to_v3
		# 4: return _migrate_v3_to_v4
		_:
			return Callable()


## ═══════════════════════════════════════════════════════════════════════════
## FUNCIONES DE MIGRACIÓN INDIVIDUALES
## ═══════════════════════════════════════════════════════════════════════════

## Migración v1 → v2
## Cambios:
##   - progress: añade campo "achievements" (array vacío)
##   - progress: añade campo "tutorial_completed" (bool false)
##   - inventory: añade campo "favorite_mechs" (array vacío)
static func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	
	# Migrar progress
	if migrated.has("progress"):
		var progress_data: Dictionary = migrated["progress"]
		
		# Nuevos campos en v2
		if not progress_data.has("achievements"):
			progress_data["achievements"] = []
		if not progress_data.has("tutorial_completed"):
			progress_data["tutorial_completed"] = false
		
		migrated["progress"] = progress_data
	
	# Migrar inventory
	if migrated.has("inventory"):
		var inventory_data: Dictionary = migrated["inventory"]
		
		# Nuevo campo en v2
		if not inventory_data.has("favorite_mechs"):
			inventory_data["favorite_mechs"] = []
		
		migrated["inventory"] = inventory_data
	
	return migrated


## ═══════════════════════════════════════════════════════════════════════════
## ESTADO INTERNO
## ═══════════════════════════════════════════════════════════════════════════

## Datos actuales del jugador
var _current_progress: ProgressData = null
var _current_settings: SettingsData = null
var _current_inventory: InventoryData = null

## Estado
var _current_mode: DataMode = DataMode.OFFLINE
var _current_user_id: String = ""
var _is_dirty: bool = false
var _last_sync_time: int = 0
var _last_checksum_error: bool = false  ## True si el último load tuvo error de checksum
var _should_save_after_migration: bool = false  ## True si hay que guardar después de migrar

## Referencias a otros managers (inyectadas)
var _database_manager: RefCounted = null


## ═══════════════════════════════════════════════════════════════════════════
## PROPIEDADES PÚBLICAS
## ═══════════════════════════════════════════════════════════════════════════

## Datos de progresión actual (solo lectura desde fuera)
var progress: ProgressData:
	get:
		return _current_progress

## Datos de settings actual
var settings: SettingsData:
	get:
		return _current_settings

## Datos de inventario actual
var inventory: InventoryData:
	get:
		return _current_inventory

## Modo actual
var mode: DataMode:
	get:
		return _current_mode

## ¿Hay cambios sin guardar?
var is_dirty: bool:
	get:
		return _is_dirty

## ¿El último load tuvo error de checksum?
var had_checksum_error: bool:
	get:
		return _last_checksum_error


## ═══════════════════════════════════════════════════════════════════════════
## INICIALIZACIÓN
## ═══════════════════════════════════════════════════════════════════════════

func _init(database_mgr: RefCounted = null) -> void:
	_database_manager = database_mgr
	_current_settings = SettingsData.new()
	_load_settings_from_local()


## ═══════════════════════════════════════════════════════════════════════════
## API PÚBLICA - CARGA DE DATOS
## ═══════════════════════════════════════════════════════════════════════════

## Carga los datos del jugador (llamar después de login)
func load_player_data(user_id: String, is_online: bool = true) -> void:
	_current_user_id = user_id
	_current_mode = DataMode.ONLINE if is_online else DataMode.OFFLINE
	
	if _current_mode == DataMode.ONLINE:
		_load_from_server(user_id)
	else:
		_load_from_local(user_id, true)  # offline = true


## Carga datos para modo offline
func load_offline_data() -> void:
	_current_mode = DataMode.OFFLINE
	_current_user_id = "offline_player"
	_load_from_local(_current_user_id, true)


## ═══════════════════════════════════════════════════════════════════════════
## API PÚBLICA - MODIFICACIÓN DE PROGRESO
## ═══════════════════════════════════════════════════════════════════════════

## Añade XP y recalcula nivel
func add_xp(amount: int, trigger: SaveTrigger = SaveTrigger.MATCH_END) -> void:
	if _current_progress == null:
		return
	
	var old_level := _current_progress.level
	_current_progress.xp += amount
	_current_progress.level = ProgressData.calculate_level(_current_progress.xp)
	_mark_dirty(trigger)
	
	# Si subió de nivel, podría haber recompensas
	if _current_progress.level > old_level:
		_on_level_up(old_level, _current_progress.level)


## Registra resultado de partida
func record_match_result(won: bool, xp_earned: int = 0, elo_change: int = 0) -> void:
	if _current_progress == null:
		return
	
	_current_progress.total_matches += 1
	_current_progress.last_match_at = int(Time.get_unix_time_from_system())
	
	if won:
		_current_progress.wins += 1
		_current_progress.season_wins += 1
	else:
		_current_progress.losses += 1
	
	if xp_earned > 0:
		add_xp(xp_earned, SaveTrigger.MATCH_END)
	
	_current_progress.elo_rating = maxi(0, _current_progress.elo_rating + elo_change)
	_mark_dirty(SaveTrigger.MATCH_END)


## Registra empate
func record_draw() -> void:
	if _current_progress == null:
		return
	
	_current_progress.total_matches += 1
	_current_progress.draws += 1
	_current_progress.last_match_at = int(Time.get_unix_time_from_system())
	_mark_dirty(SaveTrigger.MATCH_END)


## Modifica créditos (positivo = añadir, negativo = gastar)
func modify_credits(amount: int, trigger: SaveTrigger = SaveTrigger.PURCHASE) -> bool:
	if _current_progress == null:
		return false
	
	var new_credits := _current_progress.credits + amount
	if new_credits < 0:
		return false  # No tiene suficientes créditos
	
	_current_progress.credits = new_credits
	_mark_dirty(trigger)
	return true


## Modifica créditos premium
func modify_premium_credits(amount: int) -> bool:
	if _current_progress == null:
		return false
	
	var new_credits := _current_progress.premium_credits + amount
	if new_credits < 0:
		return false
	
	_current_progress.premium_credits = new_credits
	_mark_dirty(SaveTrigger.PURCHASE)
	return true


## ═══════════════════════════════════════════════════════════════════════════
## API PÚBLICA - INVENTARIO
## ═══════════════════════════════════════════════════════════════════════════

## Añade un mech al inventario
func add_mech(mech_id: String) -> void:
	if _current_inventory == null:
		return
	
	if mech_id not in _current_inventory.owned_mechs:
		_current_inventory.owned_mechs.append(mech_id)
		_current_inventory.last_updated = int(Time.get_unix_time_from_system())
		_mark_dirty(SaveTrigger.PURCHASE)


## Guarda un loadout para un mech
func save_loadout(mech_id: String, loadout_data: Dictionary, slot: int = 0) -> void:
	if _current_inventory == null:
		return
	
	if mech_id not in _current_inventory.saved_loadouts:
		_current_inventory.saved_loadouts[mech_id] = []
	
	var loadouts: Array = _current_inventory.saved_loadouts[mech_id]
	
	# Expandir array si es necesario
	while loadouts.size() <= slot:
		loadouts.append({})
	
	loadouts[slot] = loadout_data
	_current_inventory.last_updated = int(Time.get_unix_time_from_system())
	_mark_dirty(SaveTrigger.MECH_BAY)


## Obtiene un loadout guardado
func get_loadout(mech_id: String, slot: int = 0) -> Dictionary:
	if _current_inventory == null:
		return {}
	
	if mech_id not in _current_inventory.saved_loadouts:
		return {}
	
	var loadouts: Array = _current_inventory.saved_loadouts[mech_id]
	if slot >= loadouts.size():
		return {}
	
	return loadouts[slot]


## ═══════════════════════════════════════════════════════════════════════════
## API PÚBLICA - SETTINGS
## ═══════════════════════════════════════════════════════════════════════════

## Guarda configuración (siempre local)
func save_settings(new_settings: SettingsData = null) -> void:
	if new_settings != null:
		_current_settings = new_settings
	
	_save_settings_to_local()


## Actualiza un setting específico
func update_setting(key: String, value: Variant) -> void:
	if _current_settings == null:
		_current_settings = SettingsData.new()
	
	if key in _current_settings:
		_current_settings.set(key, value)
		_save_settings_to_local()


## ═══════════════════════════════════════════════════════════════════════════
## API PÚBLICA - SYNC Y GUARDADO
## ═══════════════════════════════════════════════════════════════════════════

## Fuerza una sincronización inmediata
func force_sync() -> void:
	if _current_mode == DataMode.ONLINE and _is_dirty:
		_sync_to_server()
	else:
		_save_to_local()


## Llamar al hacer logout
func on_logout() -> void:
	if _is_dirty:
		force_sync()
	
	_current_progress = null
	_current_inventory = null
	_current_user_id = ""
	_is_dirty = false


## Llamar periódicamente (cada frame o timer)
func check_periodic_sync() -> void:
	if not _is_dirty:
		return
	
	var current_time := int(Time.get_unix_time_from_system())
	if current_time - _last_sync_time >= SYNC_INTERVAL:
		force_sync()


## ═══════════════════════════════════════════════════════════════════════════
## MÉTODOS PRIVADOS - CARGA
## ═══════════════════════════════════════════════════════════════════════════

func _load_from_server(user_id: String) -> void:
	# TODO: Implementar cuando tengamos endpoint API
	# Por ahora, fallback a local
	if _database_manager == null:
		_load_from_local(user_id, false)
		return
	
	# Simulación: cargar de local y marcar como cargado
	_load_from_local(user_id, false)
	data_loaded.emit(_current_progress)


func _load_from_local(user_id: String, is_offline: bool) -> void:
	var path := OFFLINE_SAVE_PATH if is_offline else LOCAL_SAVE_PATH
	
	if not FileAccess.file_exists(path):
		# Crear datos nuevos
		_current_progress = ProgressData.new(user_id)
		_current_inventory = InventoryData.new(user_id)
		_last_checksum_error = false
		data_loaded.emit(_current_progress)
		return
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error := DataError.new(DataErrorType.LOAD_FAILED, "No se pudo abrir archivo")
		data_error.emit(error)
		# Crear datos por defecto
		_current_progress = ProgressData.new(user_id)
		_current_inventory = InventoryData.new(user_id)
		_last_checksum_error = false
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	
	if parse_result != OK:
		var error := DataError.new(DataErrorType.INVALID_DATA, "JSON inválido")
		data_error.emit(error)
		_current_progress = ProgressData.new(user_id)
		_current_inventory = InventoryData.new(user_id)
		_last_checksum_error = false
		return
	
	var data: Dictionary = json.data
	
	# Verificar checksum de integridad (antes de migración)
	var stored_checksum: String = data.get("checksum", "")
	if not stored_checksum.is_empty():
		# Crear copia de datos sin checksum para verificación
		var data_to_verify := data.duplicate(true)
		data_to_verify.erase("checksum")
		
		if not _verify_checksum(data_to_verify, stored_checksum):
			_last_checksum_error = true
			var error := DataError.new(
				DataErrorType.CHECKSUM_FAILED,
				"Los datos están corruptos (checksum inválido)"
			)
			data_error.emit(error)
			# Crear datos por defecto en caso de corrupción
			_current_progress = ProgressData.new(user_id)
			_current_inventory = InventoryData.new(user_id)
			return
	
	_last_checksum_error = false
	
	# Ejecutar migraciones si es necesario
	var saved_version: int = int(data.get("version", 1))
	if saved_version < SAVE_VERSION:
		var migration_result: MigrationResult = migrate_data(data)
		
		if not migration_result.success:
			var error := DataError.new(
				DataErrorType.VERSION_MISMATCH, 
				migration_result.error_message
			)
			data_error.emit(error)
			_current_progress = ProgressData.new(user_id)
			_current_inventory = InventoryData.new(user_id)
			return
		
		# Usar datos migrados
		data = migration_result.data
		
		# Guardar automáticamente después de migración exitosa
		_should_save_after_migration = true
		if not migration_result.migrations_applied.is_empty():
			Log.info(LOG_CATEGORY, "Datos migrados", {
				"from_version": migration_result.from_version,
				"to_version": migration_result.to_version,
				"migrations": migration_result.migrations_applied
			})
	elif saved_version > SAVE_VERSION:
		var error := DataError.new(DataErrorType.VERSION_MISMATCH, "Versión más nueva")
		data_error.emit(error)
		# Intentar cargar de todos modos (backwards compatibility)
	
	# Cargar datos (ya migrados si era necesario)
	if data.has("progress"):
		_current_progress = ProgressData.from_dict(data["progress"])
	else:
		_current_progress = ProgressData.new(user_id)
	
	if data.has("inventory"):
		_current_inventory = InventoryData.from_dict(data["inventory"])
	else:
		_current_inventory = InventoryData.new(user_id)
	
	_current_progress.user_id = user_id
	_current_inventory.user_id = user_id
	
	# Guardar si hubo migración
	if _should_save_after_migration:
		_should_save_after_migration = false
		_save_to_local()
	
	data_loaded.emit(_current_progress)


func _load_settings_from_local() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		_current_settings = SettingsData.new()
		return
	
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		_current_settings = SettingsData.new()
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) == OK:
		_current_settings = SettingsData.from_dict(json.data)
	else:
		_current_settings = SettingsData.new()


## ═══════════════════════════════════════════════════════════════════════════
## MÉTODOS PRIVADOS - CHECKSUM (INTEGRIDAD DE DATOS)
## ═══════════════════════════════════════════════════════════════════════════

## Normaliza tipos de datos para consistencia (JSON puede cambiar int → float)
## También ordena recursivamente las claves de diccionarios
static func _normalize_for_checksum(data: Variant) -> Variant:
	if data is Dictionary:
		var normalized := {}
		var keys: Array = data.keys()
		keys.sort()
		for key in keys:
			normalized[key] = _normalize_for_checksum(data[key])
		return normalized
	elif data is Array:
		var normalized := []
		for item in data:
			normalized.append(_normalize_for_checksum(item))
		return normalized
	elif data is float:
		# Si el float es un entero (sin decimales), convertir a int
		if data == floor(data):
			return int(data)
		return data
	else:
		return data


## Calcula el checksum SHA256 de un diccionario de datos
## Normaliza y ordena las claves recursivamente para garantizar consistencia
static func _calculate_checksum(data: Dictionary) -> String:
	var normalized: Variant = _normalize_for_checksum(data)
	var json_string := JSON.stringify(normalized, "", false)  # Sin formato para consistencia
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(json_string.to_utf8_buffer())
	var hash_bytes := ctx.finish()
	return hash_bytes.hex_encode()


## Verifica si el checksum de los datos es válido
static func _verify_checksum(data: Dictionary, stored_checksum: String) -> bool:
	if stored_checksum.is_empty():
		return true  # Sin checksum = datos legacy, aceptar
	var calculated := _calculate_checksum(data)
	return calculated == stored_checksum


## ═══════════════════════════════════════════════════════════════════════════
## MÉTODOS PRIVADOS - GUARDADO
## ═══════════════════════════════════════════════════════════════════════════

func _sync_to_server() -> void:
	# TODO: Implementar cuando tengamos endpoint API
	# Por ahora, guardar localmente
	_save_to_local()
	_last_sync_time = int(Time.get_unix_time_from_system())
	_is_dirty = false
	dirty_state_changed.emit(false)
	data_saved.emit()


func _save_to_local() -> void:
	if _current_progress == null:
		return
	
	var path := OFFLINE_SAVE_PATH if _current_mode == DataMode.OFFLINE else LOCAL_SAVE_PATH
	
	_current_progress.last_updated = int(Time.get_unix_time_from_system())
	
	# Datos a guardar (sin checksum para calcularlo)
	var data := {
		"version": SAVE_VERSION,
		"progress": _current_progress.to_dict(),
		"inventory": _current_inventory.to_dict() if _current_inventory else {},
	}
	
	# Calcular y añadir checksum de integridad
	var checksum := _calculate_checksum(data)
	data["checksum"] = checksum
	
	var json_string := JSON.stringify(data, "\t")
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var error := DataError.new(DataErrorType.SAVE_FAILED, "No se pudo crear archivo")
		data_error.emit(error)
		return
	
	file.store_string(json_string)
	file.close()
	
	_last_sync_time = int(Time.get_unix_time_from_system())
	_is_dirty = false
	dirty_state_changed.emit(false)
	data_saved.emit()


func _save_settings_to_local() -> void:
	if _current_settings == null:
		return
	
	var json_string := JSON.stringify(_current_settings.to_dict(), "\t")
	
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()


## ═══════════════════════════════════════════════════════════════════════════
## MÉTODOS PRIVADOS - UTILIDADES
## ═══════════════════════════════════════════════════════════════════════════

func _mark_dirty(trigger: SaveTrigger) -> void:
	var was_dirty := _is_dirty
	_is_dirty = true
	
	if not was_dirty:
		dirty_state_changed.emit(true)
	
	# Algunos triggers fuerzan guardado inmediato
	if trigger in [SaveTrigger.PURCHASE, SaveTrigger.LOGOUT]:
		force_sync()


func _on_level_up(_old_level: int, _new_level: int) -> void:
	# TODO: Dar recompensas por subir de nivel
	# Por ahora solo log
	pass


## ═══════════════════════════════════════════════════════════════════════════
## MÉTODOS ESTÁTICOS DE UTILIDAD
## ═══════════════════════════════════════════════════════════════════════════

## Borra todos los datos locales (para testing/debug)
static func clear_all_local_data() -> void:
	var paths := [LOCAL_SAVE_PATH, OFFLINE_SAVE_PATH, SETTINGS_PATH]
	for path in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Verifica si existe un guardado local
static func has_local_save() -> bool:
	return FileAccess.file_exists(LOCAL_SAVE_PATH)


## Verifica si existe un guardado offline
static func has_offline_save() -> bool:
	return FileAccess.file_exists(OFFLINE_SAVE_PATH)
