## BattleInitiativePresenter - Gestiona la presentación de la pantalla de iniciativa
## Responsabilidades:
## - Crear y configurar la pantalla de iniciativa
## - Procesar resultados de iniciativa
## - Mostrar mensajes de UI relacionados con iniciativa
class_name BattleInitiativePresenter
extends RefCounted

# ==============================================================================
# SIGNALS
# ==============================================================================
signal initiative_complete(data: Dictionary, is_first_battle: bool)

# ==============================================================================
# REFERENCES
# ==============================================================================
var initiative_screen_scene: PackedScene
var parent_node: Node  # battle_scene
var ui: Node

# ==============================================================================
# STATE
# ==============================================================================
var initiative_data_stored: Dictionary = {}
var player_mechs: Array = []
var enemy_mechs: Array = []


func setup(p_parent: Node, p_ui: Node, p_initiative_scene: PackedScene) -> void:
	"""Configura el presenter con las referencias necesarias"""
	parent_node = p_parent
	ui = p_ui
	initiative_screen_scene = p_initiative_scene


func set_mechs(p_player_mechs: Array, p_enemy_mechs: Array) -> void:
	"""Actualiza las referencias de mechs"""
	player_mechs = p_player_mechs
	enemy_mechs = p_enemy_mechs


func create_initiative_screen(my_mechs: Array = [], opponent_mechs: Array = []) -> Node:
	"""Crea y configura la pantalla de iniciativa"""
	if ui and ui.has_method("hide_main_ui"):
		ui.hide_main_ui()
	
	var initiative_screen = initiative_screen_scene.instantiate()
	initiative_screen.layer = 100
	parent_node.add_child(initiative_screen)
	
	# Usar mechs pasados o defaults
	var p_mechs = my_mechs if my_mechs.size() > 0 else player_mechs
	var e_mechs = opponent_mechs if opponent_mechs.size() > 0 else enemy_mechs
	
	initiative_screen.player_mech_names = []
	initiative_screen.player_mech_destroyed = []
	initiative_screen.player_mech_bonuses = []
	for mech in p_mechs:
		initiative_screen.player_mech_names.append(mech.mech_name)
		initiative_screen.player_mech_destroyed.append(mech.is_destroyed)
		initiative_screen.player_mech_bonuses.append(_compute_initiative_bonus(mech.tonnage))

	initiative_screen.enemy_mech_names = []
	initiative_screen.enemy_mech_destroyed = []
	initiative_screen.enemy_mech_bonuses = []
	for mech in e_mechs:
		initiative_screen.enemy_mech_names.append(mech.mech_name)
		initiative_screen.enemy_mech_destroyed.append(mech.is_destroyed)
		initiative_screen.enemy_mech_bonuses.append(_compute_initiative_bonus(mech.tonnage))
	
	# Forzar actualización de labels después de asignar nombres
	initiative_screen.call_deferred("refresh_mech_display")
	
	return initiative_screen


func _compute_initiative_bonus(tonnage: float) -> int:
	"""Regla clásica de BattleTech: +1 a iniciativa por cada 5 toneladas por debajo de 100"""
	return max(0, int((100.0 - tonnage) / 5.0))


func show_initiative_screen(_is_multiplayer: bool = false) -> void:
	"""Muestra la pantalla de iniciativa para singleplayer"""
	var screen = create_initiative_screen()
	screen.initiative_complete.connect(_on_screen_complete.bind(false), CONNECT_ONE_SHOT)


func show_initiative_screen_multiplayer_new_turn() -> void:
	"""Muestra la pantalla de iniciativa para un nuevo turno en multiplayer"""
	Log.info("Match", "Showing initiative screen for new turn (multiplayer)")
	
	# Separar mechs según control
	var my_mechs: Array = []
	var opponent_mechs: Array = []
	for mech in (player_mechs + enemy_mechs):
		if mech.is_player_controlled:
			my_mechs.append(mech)
		else:
			opponent_mechs.append(mech)
	
	var screen = create_initiative_screen(my_mechs, opponent_mechs)
	screen.set_meta("is_multiplayer", true)
	screen.initiative_complete.connect(_on_screen_complete.bind(false), CONNECT_ONE_SHOT)


func show_initiative_screen_with_server_result(server_result: Dictionary) -> void:
	"""Muestra la pantalla de iniciativa con resultados del servidor"""
	var screen = create_initiative_screen()
	screen.set_meta("server_mode", true)
	screen.set_meta("server_result", server_result)
	screen.initiative_complete.connect(_on_screen_complete_multiplayer.bind(server_result), CONNECT_ONE_SHOT)


func _on_screen_complete(data: Dictionary, _is_subsequent_turn: bool) -> void:
	"""Callback cuando la pantalla de iniciativa se completa"""
	_show_main_ui()
	
	initiative_data_stored = data
	
	# Asignar iniciativas individuales a cada mech
	if data.has("player_initiatives") and data.has("enemy_initiatives"):
		for i in range(min(player_mechs.size(), data["player_initiatives"].size())):
			player_mechs[i].initiative = data["player_initiatives"][i]
		
		for i in range(min(enemy_mechs.size(), data["enemy_initiatives"].size())):
			enemy_mechs[i].initiative = data["enemy_initiatives"][i]
		
		_show_initiative_results_singleplayer()
	
	# Emitir señal para que battle_scene maneje el inicio/continuación
	initiative_complete.emit(data, not _is_subsequent_turn)


func _on_screen_complete_multiplayer(_data: Dictionary, server_result: Dictionary) -> void:
	"""Callback cuando la pantalla de iniciativa se completa en multiplayer"""
	_show_main_ui()
	
	initiative_data_stored = server_result
	_show_initiative_results_multiplayer(server_result)
	
	# Emitir señal
	initiative_complete.emit(server_result, true)


func _show_main_ui() -> void:
	"""Muestra la UI principal"""
	if ui and ui.has_method("show_main_ui"):
		ui.show_main_ui()


func _show_initiative_results_singleplayer() -> void:
	"""Muestra los resultados de iniciativa en el chat (singleplayer)"""
	if not ui:
		return
	
	ui.add_combat_message("", Color.WHITE)
	ui.add_combat_message("╔═══════════════════════════════╗", Color.GOLD)
	ui.add_combat_message("║     INITIATIVE RESULTS        ║", Color.GOLD)
	ui.add_combat_message("╚═══════════════════════════════╝", Color.GOLD)
	ui.add_combat_message("", Color.WHITE)
	ui.add_combat_message("PLAYER LANCE:", Color.CYAN)
	for i in range(player_mechs.size()):
		ui.add_combat_message("  • %s: %d" % [player_mechs[i].mech_name, player_mechs[i].initiative], Color.WHITE)
	ui.add_combat_message("", Color.WHITE)
	ui.add_combat_message("ENEMY FORCE:", Color.RED)
	for i in range(enemy_mechs.size()):
		ui.add_combat_message("  • %s: %d" % [enemy_mechs[i].mech_name, enemy_mechs[i].initiative], Color.ORANGE_RED)
	ui.add_combat_message("", Color.WHITE)


func _show_initiative_results_multiplayer(server_result: Dictionary) -> void:
	"""Muestra los resultados de iniciativa en el chat (multiplayer)"""
	if not ui:
		return
	
	ui.add_combat_message("", Color.WHITE)
	ui.add_combat_message("╔═══════════════════════════════╗", Color.GOLD)
	ui.add_combat_message("║     INITIATIVE RESULTS        ║", Color.GOLD)
	ui.add_combat_message("╚═══════════════════════════════╝", Color.GOLD)
	ui.add_combat_message("Player: %d (%s wins!)" % [server_result.get("player_total", 0), server_result.get("winner", "?")], Color.CYAN)
	ui.add_combat_message("Enemy: %d" % server_result.get("enemy_total", 0), Color.RED)


func get_stored_initiative() -> Dictionary:
	"""Retorna los datos de iniciativa almacenados"""
	return initiative_data_stored


func clear_initiative_data() -> void:
	"""Limpia los datos de iniciativa"""
	initiative_data_stored = {}
