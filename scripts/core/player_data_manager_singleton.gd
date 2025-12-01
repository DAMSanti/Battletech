## PlayerDataManager Singleton Wrapper
## Este archivo existe porque RefCounted no puede ser autoload directamente.
## Proporciona acceso global al PlayerDataManagerCore.
extends Node

const PlayerDataScript = preload("res://scripts/core/player_data_manager.gd")

## La instancia del manager - usamos RefCounted porque class_name causa ciclos
var _instance: RefCounted = null

func _ready() -> void:
	var db_manager: RefCounted = null
	
	# Intentar obtener DatabaseManager si existe
	if Engine.has_singleton("DatabaseManager"):
		db_manager = Engine.get_singleton("DatabaseManager")
	elif has_node("/root/DatabaseManager"):
		var node = get_node("/root/DatabaseManager")
		if node.has_method("get_instance"):
			db_manager = node.get_instance()
	
	_instance = PlayerDataScript.new(db_manager)
	_connect_signals()


## Acceso a la instancia del manager
func get_instance() -> RefCounted:
	return _instance


## ═══════════════════════════════════════════════════════════════════════════
## SHORTCUTS - Métodos delegados para acceso directo
## ═══════════════════════════════════════════════════════════════════════════

# Propiedades - Usamos RefCounted porque las clases internas no se resuelven entre archivos
var progress: RefCounted:
	get:
		return _instance.progress if _instance else null

var settings: RefCounted:
	get:
		return _instance.settings if _instance else null

var inventory: RefCounted:
	get:
		return _instance.inventory if _instance else null

var is_dirty: bool:
	get:
		return _instance.is_dirty if _instance else false


# Carga de datos
func load_player_data(user_id: String, is_online: bool = true) -> void:
	if _instance:
		_instance.load_player_data(user_id, is_online)


func load_offline_data() -> void:
	if _instance:
		_instance.load_offline_data()


# Progreso
func add_xp(amount: int) -> void:
	if _instance:
		_instance.add_xp(amount)


func record_match_result(won: bool, xp_earned: int = 0, elo_change: int = 0) -> void:
	if _instance:
		_instance.record_match_result(won, xp_earned, elo_change)


func record_draw() -> void:
	if _instance:
		_instance.record_draw()


func modify_credits(amount: int) -> bool:
	if _instance:
		return _instance.modify_credits(amount)
	return false


func modify_premium_credits(amount: int) -> bool:
	if _instance:
		return _instance.modify_premium_credits(amount)
	return false


# Inventario
func add_mech(mech_id: String) -> void:
	if _instance:
		_instance.add_mech(mech_id)


func save_loadout(mech_id: String, loadout_data: Dictionary, slot: int = 0) -> void:
	if _instance:
		_instance.save_loadout(mech_id, loadout_data, slot)


func get_loadout(mech_id: String, slot: int = 0) -> Dictionary:
	if _instance:
		return _instance.get_loadout(mech_id, slot)
	return {}


# Settings
func save_settings(new_settings: RefCounted = null) -> void:
	if _instance:
		_instance.save_settings(new_settings)


func update_setting(key: String, value: Variant) -> void:
	if _instance:
		_instance.update_setting(key, value)


# Sync
func force_sync() -> void:
	if _instance:
		_instance.force_sync()


func on_logout() -> void:
	if _instance:
		_instance.on_logout()


func check_periodic_sync() -> void:
	if _instance:
		_instance.check_periodic_sync()


## Señales expuestas
signal data_loaded(progress)
signal data_saved()
signal data_error(error)
signal dirty_state_changed(is_dirty)


func _connect_signals() -> void:
	if _instance:
		_instance.data_loaded.connect(func(p): data_loaded.emit(p))
		_instance.data_saved.connect(func(): data_saved.emit())
		_instance.data_error.connect(func(e): data_error.emit(e))
		_instance.dirty_state_changed.connect(func(d): dirty_state_changed.emit(d))
