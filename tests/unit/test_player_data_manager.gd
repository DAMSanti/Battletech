## Tests para PlayerDataManager - Sistema de Auto-Guardado
## Autor: DAMSanti
## Cobertura objetivo: ≥95% (sistema crítico)
extends GutTest

# Referencia al script para acceso a clases internas y constantes
# NOTA: Usamos PDM para evitar conflicto con el autoload PDM
const PDM = preload("res://scripts/core/player_data_manager.gd")

# Usar PDM para el tipo ya que PlayerDataManagerCore puede no estar en scope
var manager = null


## ═══════════════════════════════════════════════════════════════════════════
## SETUP / TEARDOWN
## ═══════════════════════════════════════════════════════════════════════════

func before_each() -> void:
	# Limpiar datos de tests anteriores
	PDM.clear_all_local_data()
	manager = PDM.new(null)


func after_each() -> void:
	if manager:
		manager = null
	# Limpiar datos de test
	PDM.clear_all_local_data()


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE CONSTANTES
## ═══════════════════════════════════════════════════════════════════════════

func test_sync_interval_is_5_minutes() -> void:
	assert_eq(PDM.SYNC_INTERVAL, 300.0, "Sync cada 5 minutos")


func test_reconnect_timeout_is_3_minutes() -> void:
	assert_eq(PDM.RECONNECT_TIMEOUT, 180.0, "Reconexión 3 minutos")


func test_save_version_defined() -> void:
	assert_eq(PDM.SAVE_VERSION, 2, "Versión de guardado actual es 2")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE ProgressData
## ═══════════════════════════════════════════════════════════════════════════

func test_progress_data_creation() -> void:
	var progress: PDM.ProgressData = PDM.ProgressData.new("test_user")
	
	assert_eq(progress.user_id, "test_user")
	assert_eq(progress.xp, 0)
	assert_eq(progress.level, 1)
	assert_eq(progress.wins, 0)
	assert_eq(progress.losses, 0)
	assert_eq(progress.credits, 1000, "Créditos iniciales")
	assert_eq(progress.elo_rating, 1000, "ELO inicial")
	assert_true(progress.created_at > 0)


func test_progress_calculate_level_from_xp() -> void:
	# Nivel 1: 0-99 XP
	assert_eq(PDM.ProgressData.calculate_level(0), 1)
	assert_eq(PDM.ProgressData.calculate_level(50), 1)
	assert_eq(PDM.ProgressData.calculate_level(99), 1)
	
	# Nivel 2: 100-299 XP (necesita 100 para nivel 2)
	assert_eq(PDM.ProgressData.calculate_level(100), 2)
	assert_eq(PDM.ProgressData.calculate_level(200), 2)
	assert_eq(PDM.ProgressData.calculate_level(299), 2)
	
	# Nivel 3: 300-599 XP (100 + 200 = 300)
	assert_eq(PDM.ProgressData.calculate_level(300), 3)
	
	# Nivel 4: 600+ XP (100 + 200 + 300 = 600)
	assert_eq(PDM.ProgressData.calculate_level(600), 4)


func test_progress_xp_for_next_level() -> void:
	var progress: PDM.ProgressData = PDM.ProgressData.new()
	
	progress.level = 1
	assert_eq(progress.xp_for_next_level(), 100)
	
	progress.level = 2
	assert_eq(progress.xp_for_next_level(), 200)
	
	progress.level = 5
	assert_eq(progress.xp_for_next_level(), 500)


func test_progress_xp_in_current_level() -> void:
	var progress: PDM.ProgressData = PDM.ProgressData.new()
	
	# Nivel 1, 50 XP
	progress.level = 1
	progress.xp = 50
	assert_eq(progress.xp_in_current_level(), 50)
	
	# Nivel 2, 150 XP total (50 XP en nivel 2)
	progress.level = 2
	progress.xp = 150
	assert_eq(progress.xp_in_current_level(), 50)
	
	# Nivel 3, 400 XP total (100 XP en nivel 3)
	progress.level = 3
	progress.xp = 400
	assert_eq(progress.xp_in_current_level(), 100)


func test_progress_level_progress_percent() -> void:
	var progress: PDM.ProgressData = PDM.ProgressData.new()
	
	progress.level = 1
	progress.xp = 50
	# 50/100 = 50%
	assert_almost_eq(progress.level_progress_percent(), 50.0, 0.1)
	
	progress.level = 2
	progress.xp = 200
	# 100/200 = 50%
	assert_almost_eq(progress.level_progress_percent(), 50.0, 0.1)


func test_progress_win_rate() -> void:
	var progress: PDM.ProgressData = PDM.ProgressData.new()
	
	# Sin partidas
	assert_eq(progress.win_rate(), 0.0)
	
	# 5 wins, 5 losses = 50%
	progress.wins = 5
	progress.losses = 5
	progress.total_matches = 10
	assert_almost_eq(progress.win_rate(), 50.0, 0.1)
	
	# 7 wins, 3 losses = 70%
	progress.wins = 7
	progress.losses = 3
	progress.total_matches = 10
	assert_almost_eq(progress.win_rate(), 70.0, 0.1)


func test_progress_serialization() -> void:
	var original: PDM.ProgressData = PDM.ProgressData.new("user123")
	original.xp = 500
	original.level = 3
	original.wins = 10
	original.losses = 5
	original.credits = 5000
	original.elo_rating = 1200
	
	var dict := original.to_dict()
	var restored: PDM.ProgressData = PDM.ProgressData.from_dict(dict)
	
	assert_eq(restored.user_id, "user123")
	assert_eq(restored.xp, 500)
	assert_eq(restored.level, 3)
	assert_eq(restored.wins, 10)
	assert_eq(restored.losses, 5)
	assert_eq(restored.credits, 5000)
	assert_eq(restored.elo_rating, 1200)


func test_progress_duplicate() -> void:
	var original: PDM.ProgressData = PDM.ProgressData.new("user1")
	original.xp = 100
	original.wins = 5
	
	var copy := original.duplicate()
	
	assert_eq(copy.xp, 100)
	assert_eq(copy.wins, 5)
	
	# Modificar copia no afecta original
	copy.xp = 200
	assert_eq(original.xp, 100)


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE SettingsData
## ═══════════════════════════════════════════════════════════════════════════

func test_settings_data_defaults() -> void:
	var settings: PDM.SettingsData = PDM.SettingsData.new()
	
	# Audio
	assert_eq(settings.master_volume, 1.0)
	assert_eq(settings.music_volume, 0.8)
	assert_eq(settings.sfx_volume, 1.0)
	assert_false(settings.mute_all)
	
	# Gráficos
	assert_eq(settings.quality_preset, 1, "Medium por defecto")
	assert_true(settings.vsync_enabled)
	assert_true(settings.particle_effects)
	
	# Controles
	assert_eq(settings.touch_sensitivity, 1.0)
	assert_true(settings.confirm_end_turn)
	
	# Idioma
	assert_eq(settings.language, "es")


func test_settings_serialization() -> void:
	var original: PDM.SettingsData = PDM.SettingsData.new()
	original.master_volume = 0.5
	original.music_volume = 0.3
	original.language = "en"
	original.colorblind_mode = 2
	
	var dict := original.to_dict()
	var restored: PDM.SettingsData = PDM.SettingsData.from_dict(dict)
	
	assert_eq(restored.master_volume, 0.5)
	assert_eq(restored.music_volume, 0.3)
	assert_eq(restored.language, "en")
	assert_eq(restored.colorblind_mode, 2)


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE InventoryData
## ═══════════════════════════════════════════════════════════════════════════

func test_inventory_data_defaults() -> void:
	var inv: PDM.InventoryData = PDM.InventoryData.new("test_user")
	
	assert_eq(inv.user_id, "test_user")
	# Mechs iniciales gratis
	assert_true("locust" in inv.owned_mechs)
	assert_true("commando" in inv.owned_mechs)
	assert_true("jenner" in inv.owned_mechs)
	assert_eq(inv.owned_mechs.size(), 3)


func test_inventory_serialization() -> void:
	var original: PDM.InventoryData = PDM.InventoryData.new("user1")
	original.owned_mechs.append("atlas")
	original.owned_skins.append("skin_red")
	original.saved_loadouts["atlas"] = [{"weapons": ["ppc"]}]
	
	var dict := original.to_dict()
	var restored: PDM.InventoryData = PDM.InventoryData.from_dict(dict)
	
	assert_true("atlas" in restored.owned_mechs)
	assert_true("skin_red" in restored.owned_skins)
	assert_true("atlas" in restored.saved_loadouts)


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE DataError
## ═══════════════════════════════════════════════════════════════════════════

func test_data_error_messages() -> void:
	var error: PDM.DataError
	
	error = PDM.DataError.new(PDM.DataErrorType.LOAD_FAILED)
	assert_eq(error.get_user_message(), "No se pudieron cargar los datos")
	
	error = PDM.DataError.new(PDM.DataErrorType.SAVE_FAILED)
	assert_eq(error.get_user_message(), "No se pudieron guardar los datos")
	
	error = PDM.DataError.new(PDM.DataErrorType.NETWORK_ERROR)
	assert_eq(error.get_user_message(), "Error de conexión")
	
	error = PDM.DataError.new(PDM.DataErrorType.VERSION_MISMATCH)
	assert_eq(error.get_user_message(), "Versión incompatible, actualiza el juego")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE PlayerDataManager - CARGA
## ═══════════════════════════════════════════════════════════════════════════

func test_manager_initial_state() -> void:
	assert_null(manager.progress)
	assert_not_null(manager.settings, "Settings siempre existe")
	assert_null(manager.inventory)
	assert_false(manager.is_dirty)


func test_manager_load_offline_data() -> void:
	manager.load_offline_data()
	
	assert_not_null(manager.progress)
	assert_eq(manager.progress.user_id, "offline_player")
	assert_eq(manager.mode, PDM.DataMode.OFFLINE)


func test_manager_load_player_data_online() -> void:
	manager.load_player_data("test_user", true)
	
	assert_not_null(manager.progress)
	assert_eq(manager.progress.user_id, "test_user")
	assert_eq(manager.mode, PDM.DataMode.ONLINE)


func test_manager_load_player_data_offline() -> void:
	manager.load_player_data("test_user", false)
	
	assert_not_null(manager.progress)
	assert_eq(manager.mode, PDM.DataMode.OFFLINE)


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE PlayerDataManager - PROGRESO
## ═══════════════════════════════════════════════════════════════════════════

func test_manager_add_xp() -> void:
	manager.load_offline_data()
	var initial_xp: int = manager.progress.xp
	
	manager.add_xp(100)
	
	assert_eq(manager.progress.xp, initial_xp + 100)
	assert_true(manager.is_dirty)


func test_manager_add_xp_levels_up() -> void:
	manager.load_offline_data()
	
	# Añadir suficiente XP para subir de nivel
	manager.add_xp(100)  # Nivel 2
	
	assert_eq(manager.progress.level, 2)


func test_manager_add_xp_without_data_does_nothing() -> void:
	# Sin cargar datos
	manager.add_xp(100)
	# No debe crashear
	assert_null(manager.progress)


func test_manager_record_match_win() -> void:
	manager.load_offline_data()
	
	manager.record_match_result(true, 50, 25)
	
	assert_eq(manager.progress.wins, 1)
	assert_eq(manager.progress.total_matches, 1)
	assert_eq(manager.progress.xp, 50)
	assert_eq(manager.progress.elo_rating, 1025)
	assert_true(manager.progress.last_match_at > 0)


func test_manager_record_match_loss() -> void:
	manager.load_offline_data()
	
	manager.record_match_result(false, 25, -20)
	
	assert_eq(manager.progress.losses, 1)
	assert_eq(manager.progress.wins, 0)
	assert_eq(manager.progress.total_matches, 1)
	assert_eq(manager.progress.elo_rating, 980)


func test_manager_record_draw() -> void:
	manager.load_offline_data()
	
	manager.record_draw()
	
	assert_eq(manager.progress.draws, 1)
	assert_eq(manager.progress.total_matches, 1)


func test_manager_elo_cannot_go_negative() -> void:
	manager.load_offline_data()
	manager.progress.elo_rating = 10
	
	manager.record_match_result(false, 0, -100)
	
	assert_eq(manager.progress.elo_rating, 0, "ELO no puede ser negativo")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE PlayerDataManager - CRÉDITOS
## ═══════════════════════════════════════════════════════════════════════════

func test_manager_modify_credits_add() -> void:
	manager.load_offline_data()
	var initial: int = manager.progress.credits
	
	var result: bool = manager.modify_credits(500)
	
	assert_true(result)
	assert_eq(manager.progress.credits, initial + 500)


func test_manager_modify_credits_subtract() -> void:
	manager.load_offline_data()
	manager.progress.credits = 1000
	
	var result: bool = manager.modify_credits(-300)
	
	assert_true(result)
	assert_eq(manager.progress.credits, 700)


func test_manager_modify_credits_insufficient_fails() -> void:
	manager.load_offline_data()
	manager.progress.credits = 100
	
	var result: bool = manager.modify_credits(-500)
	
	assert_false(result, "No debería permitir saldo negativo")
	assert_eq(manager.progress.credits, 100, "Créditos sin cambio")


func test_manager_modify_premium_credits() -> void:
	manager.load_offline_data()
	
	var result: bool = manager.modify_premium_credits(100)
	
	assert_true(result)
	assert_eq(manager.progress.premium_credits, 100)


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE PlayerDataManager - INVENTARIO
## ═══════════════════════════════════════════════════════════════════════════

func test_manager_add_mech() -> void:
	manager.load_offline_data()
	var initial_count: int = manager.inventory.owned_mechs.size()
	
	manager.add_mech("atlas")
	
	assert_eq(manager.inventory.owned_mechs.size(), initial_count + 1)
	assert_true("atlas" in manager.inventory.owned_mechs)


func test_manager_add_mech_duplicate_ignored() -> void:
	manager.load_offline_data()
	manager.add_mech("atlas")
	var count: int = manager.inventory.owned_mechs.size()
	
	manager.add_mech("atlas")
	
	assert_eq(manager.inventory.owned_mechs.size(), count, "No duplicados")


func test_manager_save_and_get_loadout() -> void:
	manager.load_offline_data()
	
	var loadout := {"weapons": ["medium_laser", "srm6"], "armor": 100}
	manager.save_loadout("locust", loadout, 0)
	
	var retrieved: Dictionary = manager.get_loadout("locust", 0)
	
	assert_eq(retrieved["weapons"], ["medium_laser", "srm6"])
	assert_eq(retrieved["armor"], 100)


func test_manager_get_loadout_nonexistent_returns_empty() -> void:
	manager.load_offline_data()
	
	var result: Dictionary = manager.get_loadout("nonexistent_mech", 0)
	
	assert_true(result.is_empty())


func test_manager_save_loadout_multiple_slots() -> void:
	manager.load_offline_data()
	
	manager.save_loadout("atlas", {"name": "Brawler"}, 0)
	manager.save_loadout("atlas", {"name": "Sniper"}, 1)
	manager.save_loadout("atlas", {"name": "Support"}, 2)
	
	assert_eq(manager.get_loadout("atlas", 0)["name"], "Brawler")
	assert_eq(manager.get_loadout("atlas", 1)["name"], "Sniper")
	assert_eq(manager.get_loadout("atlas", 2)["name"], "Support")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE PlayerDataManager - SETTINGS
## ═══════════════════════════════════════════════════════════════════════════

func test_manager_settings_always_available() -> void:
	# Incluso sin cargar datos de jugador
	assert_not_null(manager.settings)


func test_manager_update_setting() -> void:
	manager.update_setting("master_volume", 0.5)
	
	assert_eq(manager.settings.master_volume, 0.5)


func test_manager_save_settings() -> void:
	manager.settings.music_volume = 0.3
	manager.save_settings()
	
	# Crear nuevo manager y verificar que cargó
	var new_manager := PDM.new(null)
	assert_eq(new_manager.settings.music_volume, 0.3)


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE PlayerDataManager - DIRTY FLAG Y SYNC
## ═══════════════════════════════════════════════════════════════════════════

func test_manager_dirty_flag_on_xp() -> void:
	manager.load_offline_data()
	assert_false(manager.is_dirty)
	
	manager.add_xp(10)
	
	assert_true(manager.is_dirty)


func test_manager_dirty_flag_on_credits() -> void:
	manager.load_offline_data()
	
	# NOTA: modify_credits usa PURCHASE por defecto, que fuerza sync inmediato
	# Esto limpia el dirty flag, así que verificamos que el sync ocurrió correctamente
	# verificando que los datos persisten (se guardó)
	manager.modify_credits(100)
	
	# En modo offline, force_sync guarda localmente y limpia dirty
	# El comportamiento esperado es que dirty sea false después de una compra
	# porque se sincroniza inmediatamente
	assert_false(manager.is_dirty, "Compras se sincronizan inmediatamente")


func test_manager_force_sync_clears_dirty() -> void:
	manager.load_offline_data()
	manager.add_xp(100)
	assert_true(manager.is_dirty)
	
	manager.force_sync()
	
	assert_false(manager.is_dirty)


func test_manager_on_logout_clears_data() -> void:
	manager.load_offline_data()
	manager.add_xp(100)
	
	manager.on_logout()
	
	assert_null(manager.progress)
	assert_false(manager.is_dirty)


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE PlayerDataManager - PERSISTENCIA
## ═══════════════════════════════════════════════════════════════════════════

func test_manager_save_and_load_persists_data() -> void:
	# Guardar datos
	manager.load_offline_data()
	manager.add_xp(250)
	manager.record_match_result(true, 0, 0)
	manager.add_mech("atlas")
	manager.force_sync()
	
	# Nuevo manager carga los datos
	var new_manager := PDM.new(null)
	new_manager.load_offline_data()
	
	assert_eq(new_manager.progress.xp, 250)
	assert_eq(new_manager.progress.wins, 1)
	assert_true("atlas" in new_manager.inventory.owned_mechs)


func test_static_has_local_save() -> void:
	assert_false(PDM.has_local_save())
	
	manager.load_player_data("test", true)
	manager.force_sync()
	
	assert_true(PDM.has_local_save())


func test_static_has_offline_save() -> void:
	assert_false(PDM.has_offline_save())
	
	manager.load_offline_data()
	manager.force_sync()
	
	assert_true(PDM.has_offline_save())


func test_static_clear_all_local_data() -> void:
	manager.load_offline_data()
	manager.force_sync()
	manager.load_player_data("online", true)
	manager.force_sync()
	
	PDM.clear_all_local_data()
	
	assert_false(PDM.has_local_save())
	assert_false(PDM.has_offline_save())


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE SEÑALES
## ═══════════════════════════════════════════════════════════════════════════

func test_signal_data_loaded_emitted() -> void:
	watch_signals(manager)
	
	manager.load_offline_data()
	
	assert_signal_emitted(manager, "data_loaded")


func test_signal_data_saved_emitted() -> void:
	manager.load_offline_data()
	watch_signals(manager)
	
	manager.force_sync()
	
	assert_signal_emitted(manager, "data_saved")


func test_signal_dirty_state_changed_emitted() -> void:
	manager.load_offline_data()
	watch_signals(manager)
	
	manager.add_xp(10)
	
	assert_signal_emitted(manager, "dirty_state_changed")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE CHECKSUM (INTEGRIDAD DE DATOS)
## ═══════════════════════════════════════════════════════════════════════════

func test_checksum_calculation_is_deterministic() -> void:
	var data := {"version": 1, "test": "value", "number": 42}
	
	var checksum1 := PDM._calculate_checksum(data)
	var checksum2 := PDM._calculate_checksum(data)
	
	assert_eq(checksum1, checksum2, "Checksum debe ser determinístico")
	assert_eq(checksum1.length(), 64, "SHA256 debe tener 64 caracteres hex")


func test_checksum_changes_with_different_data() -> void:
	var data1 := {"version": 1, "test": "value"}
	var data2 := {"version": 1, "test": "different"}
	
	var checksum1 := PDM._calculate_checksum(data1)
	var checksum2 := PDM._calculate_checksum(data2)
	
	assert_ne(checksum1, checksum2, "Datos diferentes deben tener checksums diferentes")


func test_verify_checksum_with_valid_data() -> void:
	var data := {"version": 1, "progress": {"xp": 100}}
	var checksum := PDM._calculate_checksum(data)
	
	assert_true(PDM._verify_checksum(data, checksum), "Checksum válido debe verificar")


func test_verify_checksum_with_invalid_data() -> void:
	var data := {"version": 1, "progress": {"xp": 100}}
	var checksum := PDM._calculate_checksum(data)
	
	# Modificar datos después de calcular checksum
	data["progress"]["xp"] = 999
	
	assert_false(PDM._verify_checksum(data, checksum), "Datos modificados no deben verificar")


func test_verify_checksum_with_empty_checksum_accepts_legacy() -> void:
	var data := {"version": 1, "progress": {"xp": 100}}
	
	assert_true(PDM._verify_checksum(data, ""), "Sin checksum = datos legacy, aceptar")


func test_save_includes_checksum() -> void:
	manager.load_offline_data()
	manager.add_xp(50)
	manager.force_sync()
	
	# Leer archivo guardado directamente
	var file := FileAccess.open(PDM.OFFLINE_SAVE_PATH, FileAccess.READ)
	assert_not_null(file, "Archivo debe existir")
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	assert_eq(json.parse(json_string), OK)
	
	var data: Dictionary = json.data
	assert_true(data.has("checksum"), "Guardado debe incluir checksum")
	assert_eq(data["checksum"].length(), 64, "Checksum debe ser SHA256 (64 chars)")


func test_load_with_valid_checksum_succeeds() -> void:
	# Guardar datos válidos
	manager.load_offline_data()
	manager.add_xp(100)
	manager.force_sync()
	
	# Crear nuevo manager y cargar
	var manager2 = PDM.new(null)
	manager2.load_offline_data()
	
	assert_false(manager2.had_checksum_error, "No debe haber error de checksum")
	assert_eq(manager2.progress.xp, 100, "Datos deben cargarse correctamente")
	manager2 = null


func test_load_with_corrupted_data_fails_checksum() -> void:
	# Guardar datos válidos
	manager.load_offline_data()
	manager.add_xp(100)
	manager.force_sync()
	
	# Corromper el archivo manualmente
	var file := FileAccess.open(PDM.OFFLINE_SAVE_PATH, FileAccess.READ)
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	json.parse(json_string)
	var data: Dictionary = json.data
	
	# Modificar datos sin actualizar checksum (simulando corrupción)
	data["progress"]["xp"] = 9999
	
	var corrupted_json := JSON.stringify(data, "\t")
	file = FileAccess.open(PDM.OFFLINE_SAVE_PATH, FileAccess.WRITE)
	file.store_string(corrupted_json)
	file.close()
	
	# Crear nuevo manager y cargar
	var manager2 = PDM.new(null)
	watch_signals(manager2)
	manager2.load_offline_data()
	
	assert_true(manager2.had_checksum_error, "Debe detectar error de checksum")
	assert_signal_emitted(manager2, "data_error")
	# Datos deben ser valores por defecto (no los corruptos)
	assert_eq(manager2.progress.xp, 0, "Con corrupción, usar datos por defecto")
	manager2 = null


func test_checksum_error_type_has_user_message() -> void:
	var error := PDM.DataError.new(PDM.DataErrorType.CHECKSUM_FAILED, "test")
	
	assert_eq(
		error.get_user_message(),
		"Los datos están corruptos y no pueden cargarse",
		"Mensaje de error de checksum para usuario"
	)


func test_load_legacy_data_without_checksum_succeeds() -> void:
	# Crear archivo sin checksum (datos legacy)
	var legacy_data := {
		"version": 1,
		"progress": {
			"user_id": "legacy_user",
			"xp": 500,
			"level": 3,
			"wins": 5,
			"losses": 2,
			"draws": 0,
			"total_matches": 7,
			"credits": 2000,
			"premium_credits": 0,
			"elo_rating": 1100,
			"rank_tier": 0,
			"season_wins": 5,
			"created_at": 0,
			"last_updated": 0,
			"last_match_at": 0
		},
		"inventory": {}
	}
	# Sin campo "checksum"
	
	var json_string := JSON.stringify(legacy_data, "\t")
	var file := FileAccess.open(PDM.OFFLINE_SAVE_PATH, FileAccess.WRITE)
	file.store_string(json_string)
	file.close()
	
	# Cargar datos legacy
	var manager2 = PDM.new(null)
	manager2.load_offline_data()
	
	assert_false(manager2.had_checksum_error, "Datos legacy sin checksum deben aceptarse")
	assert_eq(manager2.progress.xp, 500, "Datos legacy deben cargarse")
	assert_eq(manager2.progress.level, 3)
	manager2 = null


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE MIGRACIONES DE VERSIÓN
## ═══════════════════════════════════════════════════════════════════════════

func test_migrate_data_same_version_returns_unchanged() -> void:
	# Datos ya en versión actual
	var data := {
		"version": PDM.SAVE_VERSION,
		"progress": {"xp": 100, "level": 2},
		"inventory": {"owned_mechs": ["atlas"]}
	}
	
	var result: PDM.MigrationResult = PDM.migrate_data(data)
	
	assert_true(result.success, "Migración de misma versión debe ser exitosa")
	assert_eq(result.migrations_applied.size(), 0, "No debe aplicar migraciones")
	assert_eq(result.from_version, PDM.SAVE_VERSION)
	assert_eq(result.to_version, PDM.SAVE_VERSION)


func test_migrate_data_future_version_fails() -> void:
	# Datos de versión futura (más nueva que el juego)
	var data := {
		"version": PDM.SAVE_VERSION + 10,
		"progress": {"xp": 100}
	}
	
	var result: PDM.MigrationResult = PDM.migrate_data(data)
	
	assert_false(result.success, "Versión futura no debe migrar")
	assert_true(result.error_message.contains("más nueva"), "Debe indicar versión más nueva")


func test_migrate_v1_to_v2_adds_achievements() -> void:
	# Datos v1 sin achievements
	var v1_data := {
		"version": 1,
		"progress": {
			"xp": 500,
			"level": 3,
			"wins": 5,
			"losses": 2
		}
	}
	
	var result: PDM.MigrationResult = PDM.migrate_data(v1_data)
	
	assert_true(result.success, "Migración v1→v2 debe ser exitosa")
	assert_eq(result.from_version, 1)
	assert_eq(result.to_version, PDM.SAVE_VERSION)
	assert_true(result.data["progress"].has("achievements"), "Debe añadir achievements")
	assert_eq(result.data["progress"]["achievements"], [], "achievements debe ser array vacío")


func test_migrate_v1_to_v2_adds_tutorial_completed() -> void:
	# Datos v1 sin tutorial_completed
	var v1_data := {
		"version": 1,
		"progress": {
			"xp": 100
		}
	}
	
	var result: PDM.MigrationResult = PDM.migrate_data(v1_data)
	
	assert_true(result.success)
	assert_true(result.data["progress"].has("tutorial_completed"), "Debe añadir tutorial_completed")
	assert_false(result.data["progress"]["tutorial_completed"], "tutorial_completed debe ser false")


func test_migrate_v1_to_v2_adds_favorite_mechs() -> void:
	# Datos v1 sin favorite_mechs en inventory
	var v1_data := {
		"version": 1,
		"progress": {},
		"inventory": {
			"owned_mechs": ["atlas", "locust"]
		}
	}
	
	var result: PDM.MigrationResult = PDM.migrate_data(v1_data)
	
	assert_true(result.success)
	assert_true(result.data["inventory"].has("favorite_mechs"), "Debe añadir favorite_mechs")
	assert_eq(result.data["inventory"]["favorite_mechs"], [], "favorite_mechs debe ser array vacío")


func test_migrate_v1_to_v2_preserves_existing_data() -> void:
	# Verificar que la migración no pierde datos existentes
	var v1_data := {
		"version": 1,
		"progress": {
			"xp": 1500,
			"level": 5,
			"wins": 20,
			"losses": 10,
			"credits": 5000,
			"elo_rating": 1200
		},
		"inventory": {
			"owned_mechs": ["atlas", "madcat", "locust"],
			"saved_loadouts": {"atlas": [{"name": "Standard"}]}
		}
	}
	
	var result: PDM.MigrationResult = PDM.migrate_data(v1_data)
	
	assert_true(result.success)
	# Verificar que datos originales están intactos
	assert_eq(result.data["progress"]["xp"], 1500, "XP debe preservarse")
	assert_eq(result.data["progress"]["wins"], 20, "Wins debe preservarse")
	assert_eq(result.data["progress"]["elo_rating"], 1200, "ELO debe preservarse")
	assert_eq(result.data["inventory"]["owned_mechs"].size(), 3, "Mechs deben preservarse")
	assert_true(result.data["inventory"]["saved_loadouts"].has("atlas"), "Loadouts deben preservarse")


func test_migrate_records_applied_migrations() -> void:
	var v1_data := {
		"version": 1,
		"progress": {}
	}
	
	var result: PDM.MigrationResult = PDM.migrate_data(v1_data)
	
	assert_true(result.success)
	assert_true(result.migrations_applied.has(2), "Debe registrar migración a v2")


func test_migration_result_ok_factory() -> void:
	var data := {"test": "data"}
	var applied: Array[int] = [2, 3]
	
	var result := PDM.MigrationResult.ok(data, 1, 3, applied)
	
	assert_true(result.success)
	assert_eq(result.data, data)
	assert_eq(result.from_version, 1)
	assert_eq(result.to_version, 3)
	assert_eq(result.migrations_applied, applied)


func test_migration_result_fail_factory() -> void:
	var result := PDM.MigrationResult.fail("Test error", 1)
	
	assert_false(result.success)
	assert_eq(result.error_message, "Test error")
	assert_eq(result.from_version, 1)


func test_load_v1_data_auto_migrates() -> void:
	# Crear archivo v1 directamente (sin checksum que sería de v2)
	var v1_data := {
		"version": 1,
		"progress": {
			"version": 1,
			"user_id": "offline_user",
			"xp": 300,
			"level": 2,
			"wins": 3
		},
		"inventory": {
			"version": 1,
			"user_id": "offline_user",
			"owned_mechs": ["locust"]
		}
	}
	
	var file := FileAccess.open("user://offline_player_data.save", FileAccess.WRITE)
	file.store_string(JSON.stringify(v1_data))
	file.close()
	
	# Cargar - debe migrar automáticamente
	var migration_manager = PDM.new(null)
	migration_manager.load_offline_data()
	
	# Verificar que los datos se cargaron con campos nuevos
	assert_not_null(migration_manager.progress, "Progress debe existir")
	assert_eq(migration_manager.progress.xp, 300, "XP debe cargarse")
	
	# Los nuevos campos deben existir con valores default
	assert_eq(migration_manager.progress.achievements.size(), 0, "achievements debe ser array vacío")
	assert_false(migration_manager.progress.tutorial_completed, "tutorial_completed debe ser false")
	assert_eq(migration_manager.inventory.favorite_mechs.size(), 0, "favorite_mechs debe ser array vacío")
	
	migration_manager = null


func test_progress_data_new_fields_serialize() -> void:
	# Verificar que los nuevos campos se serializan correctamente
	var progress := PDM.ProgressData.new("test_user")
	progress.achievements = ["first_win", "10_kills"]
	progress.tutorial_completed = true
	
	var dict := progress.to_dict()
	
	assert_true(dict.has("achievements"), "to_dict debe incluir achievements")
	assert_eq(dict["achievements"].size(), 2)
	assert_true(dict.has("tutorial_completed"), "to_dict debe incluir tutorial_completed")
	assert_true(dict["tutorial_completed"])


func test_progress_data_new_fields_deserialize() -> void:
	var dict := {
		"user_id": "test",
		"achievements": ["badge_1", "badge_2"],
		"tutorial_completed": true,
		"xp": 100
	}
	
	var progress := PDM.ProgressData.from_dict(dict)
	
	assert_eq(progress.achievements.size(), 2)
	assert_eq(progress.achievements[0], "badge_1")
	assert_true(progress.tutorial_completed)


func test_inventory_data_new_fields_serialize() -> void:
	var inv := PDM.InventoryData.new("test_user")
	inv.favorite_mechs = ["atlas", "madcat"]
	
	var dict := inv.to_dict()
	
	assert_true(dict.has("favorite_mechs"), "to_dict debe incluir favorite_mechs")
	assert_eq(dict["favorite_mechs"].size(), 2)


func test_inventory_data_new_fields_deserialize() -> void:
	var dict := {
		"user_id": "test",
		"owned_mechs": ["atlas"],
		"favorite_mechs": ["atlas"]
	}
	
	var inv := PDM.InventoryData.from_dict(dict)
	
	assert_eq(inv.favorite_mechs.size(), 1)
	assert_eq(inv.favorite_mechs[0], "atlas")
