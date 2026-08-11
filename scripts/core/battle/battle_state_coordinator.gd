## BattleStateCoordinator - Coordina el estado general de la batalla
## Responsabilidad única: Gestión de fases, turnos y condiciones de victoria
## Extraído de battle_scene.gd como parte del refactoring SOLID
class_name BattleStateCoordinator
extends RefCounted

# ==============================================================================
# SIGNALS
# ==============================================================================
signal state_changed(new_state: int)  # GameEnums.GameState
signal phase_changed(phase: String)
signal turn_changed(team: String, turn_number: int)
signal unit_activated(unit: Mech)
@warning_ignore("unused_signal")
signal battle_started()
signal battle_ended(winner: String, loser: String, reason: String)
signal combat_message(text: String, color: Color)

# ==============================================================================
# STATE
# ==============================================================================
var current_state: int = GameEnums.GameState.MOVING  # Estado inicial
var selected_unit: Mech = null
var is_my_turn: bool = false
var current_turn: int = 0
var current_phase: String = ""

# ==============================================================================
# REFERENCES
# ==============================================================================
var turn_manager = null  # TurnManager
var player_mechs: Array = []
var enemy_mechs: Array = []
var is_multiplayer_mode: bool = false
var my_team: String = ""


func setup(p_turn_manager, p_is_multiplayer: bool = false, p_my_team: String = "") -> void:
	"""Configura el state coordinator"""
	turn_manager = p_turn_manager
	is_multiplayer_mode = p_is_multiplayer
	my_team = p_my_team
	
	# Conectar señales del turn_manager
	if turn_manager:
		if turn_manager.has_signal("phase_changed"):
			turn_manager.phase_changed.connect(_on_turn_manager_phase_changed)
		if turn_manager.has_signal("turn_changed"):
			turn_manager.turn_changed.connect(_on_turn_manager_turn_changed)
		if turn_manager.has_signal("unit_activated"):
			turn_manager.unit_activated.connect(_on_turn_manager_unit_activated)


func set_mechs(p_player_mechs: Array, p_enemy_mechs: Array) -> void:
	"""Actualiza las referencias a mechs"""
	player_mechs = p_player_mechs
	enemy_mechs = p_enemy_mechs


func set_state(new_state: int) -> void:
	"""Cambia el estado del juego"""
	if current_state != new_state:
		current_state = new_state
		state_changed.emit(new_state)
		Log.debug("Combat", "Game state changed to: %s" % GameEnums.GameState.keys()[new_state])


func set_selected_unit(unit: Mech) -> void:
	"""Establece la unidad seleccionada"""
	selected_unit = unit


func set_my_turn(value: bool) -> void:
	"""Establece si es el turno del jugador"""
	is_my_turn = value


func _on_turn_manager_phase_changed(phase: String) -> void:
	"""Callback cuando el turn manager cambia de fase"""
	current_phase = phase
	
	# Mapear fase a estado
	match phase:
		"Movement":
			set_state(GameEnums.GameState.MOVING)
		"Weapon Attack":
			set_state(GameEnums.GameState.WEAPON_ATTACK)
		"Physical Attack":
			set_state(GameEnums.GameState.PHYSICAL_TARGETING)
		"Heat":
			# No cambiar estado, solo notificar
			pass
		"Initiative":
			# No cambiar estado durante iniciativa
			pass
	
	phase_changed.emit(phase)


func _on_turn_manager_turn_changed(team: String, turn_number: int) -> void:
	"""Callback cuando el turn manager cambia de turno"""
	current_turn = turn_number
	turn_changed.emit(team, turn_number)


func _on_turn_manager_unit_activated(unit: Mech) -> void:
	"""Callback cuando se activa una unidad"""
	selected_unit = unit
	unit_activated.emit(unit)


func check_battle_end() -> Dictionary:
	"""Verifica si la batalla terminó y retorna el resultado"""
	var players_alive = 0
	var enemies_alive = 0
	
	for mech in player_mechs:
		if not mech.is_destroyed:
			players_alive += 1
	
	for mech in enemy_mechs:
		if not mech.is_destroyed:
			enemies_alive += 1
	
	if players_alive == 0 or enemies_alive == 0:
		var result = _build_battle_result(players_alive, enemies_alive)
		battle_ended.emit(result.winner, result.loser, result.reason)
		return result
	
	return {"ended": false}


func _build_battle_result(players_alive: int, enemies_alive: int) -> Dictionary:
	"""Construye el resultado de la batalla"""
	var winner_name = ""
	var loser_name = ""
	var death_reason = ""
	
	if players_alive == 0:
		# Enemigos ganaron
		winner_name = enemy_mechs[0].mech_name if enemy_mechs.size() > 0 else "Enemy"
		for mech in player_mechs:
			if mech.is_destroyed:
				loser_name = mech.mech_name
				death_reason = _build_death_reason(mech)
				break
	else:
		# Jugador ganó
		winner_name = player_mechs[0].mech_name if player_mechs.size() > 0 else "Player"
		for mech in enemy_mechs:
			if mech.is_destroyed:
				loser_name = mech.mech_name
				death_reason = _build_death_reason(mech)
				break
	
	return {
		"ended": true,
		"winner": winner_name,
		"loser": loser_name,
		"reason": death_reason,
		"player_won": enemies_alive == 0
	}


func _build_death_reason(mech: Mech) -> String:
	"""Construye el mensaje de razón de muerte"""
	var reason = ""
	
	if mech.destroyed_by != "":
		reason = "%s destroyed by %s" % [mech.mech_name, mech.destroyed_by]
	else:
		reason = mech.mech_name
	
	if mech.death_reason != "":
		reason += "\n" + mech.death_reason.capitalize()
	
	return reason


func emit_initiative_messages(data: Dictionary) -> void:
	"""Emite mensajes de iniciativa"""
	combat_message.emit("", Color.WHITE)
	combat_message.emit("╔═══════════════════════════════╗", Color.GOLD)
	combat_message.emit("║     INITIATIVE PHASE          ║", Color.GOLD)
	combat_message.emit("╚═══════════════════════════════╝", Color.GOLD)
	
	combat_message.emit("Player rolls: [%d] + [%d] = %d" % [
		data["player_dice"][0],
		data["player_dice"][1],
		data["player_total"]
	], Color.CYAN)
	
	combat_message.emit("Enemy rolls: [%d] + [%d] = %d" % [
		data["enemy_dice"][0],
		data["enemy_dice"][1],
		data["enemy_total"]
	], Color.RED)
	
	combat_message.emit("", Color.WHITE)
	
	if data.has("winner"):
		if data["winner"] == "player":
			combat_message.emit("★ PLAYER WINS INITIATIVE! ★", Color.GREEN)
			combat_message.emit("Player team moves first", Color.CYAN)
		else:
			combat_message.emit("★ ENEMY WINS INITIATIVE! ★", Color.ORANGE_RED)
			combat_message.emit("Enemy team moves first", Color.RED)
	
	combat_message.emit("", Color.WHITE)


func is_player_unit(unit: Mech) -> bool:
	"""Verifica si una unidad pertenece al jugador"""
	if is_multiplayer_mode:
		return unit.is_player_controlled
	else:
		return unit in player_mechs


func is_enemy_unit(unit: Mech) -> bool:
	"""Verifica si una unidad es enemiga"""
	if is_multiplayer_mode:
		return not unit.is_player_controlled
	else:
		return unit in enemy_mechs


func can_player_act() -> bool:
	"""Verifica si el jugador puede actuar"""
	if is_multiplayer_mode:
		return is_my_turn
	else:
		return selected_unit != null and is_player_unit(selected_unit)


func end_current_activation() -> void:
	"""Termina la activación de la unidad actual"""
	if turn_manager:
		turn_manager.complete_unit_activation()


func advance_phase() -> void:
	"""Avanza a la siguiente fase"""
	if turn_manager:
		turn_manager.advance_phase()


func get_current_state() -> int:
	"""Retorna el estado actual"""
	return current_state


func get_current_phase() -> String:
	"""Retorna la fase actual"""
	return current_phase


func get_current_turn() -> int:
	"""Retorna el turno actual"""
	return current_turn


func get_selected_unit() -> Mech:
	"""Retorna la unidad seleccionada"""
	return selected_unit


func is_in_state(state: int) -> bool:
	"""Verifica si estamos en un estado específico"""
	return current_state == state


func is_in_phase(phase: String) -> bool:
	"""Verifica si estamos en una fase específica"""
	return current_phase == phase


func get_alive_count() -> Dictionary:
	"""Retorna el conteo de mechs vivos"""
	var players_alive = 0
	var enemies_alive = 0
	
	for mech in player_mechs:
		if not mech.is_destroyed:
			players_alive += 1
	
	for mech in enemy_mechs:
		if not mech.is_destroyed:
			enemies_alive += 1
	
	return {
		"player": players_alive,
		"enemy": enemies_alive
	}
