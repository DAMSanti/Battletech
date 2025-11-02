extends Node
class_name TurnManager

## Gestor de turnos y fases del juego
## Controla el flujo de la batalla según las reglas de Battletech

signal turn_changed(team: String, turn_number: int)
signal phase_changed(phase_name: String)
signal unit_activated(unit)
signal initiative_rolled(data: Dictionary)
signal battle_ended(winner: String)

var current_turn: int = 1
var current_phase: int = GameEnums.TurnPhase.INITIATIVE
var current_team: String = "player"  # "player" o "enemy"

var player_units: Array = []
var enemy_units: Array = []

var units_to_activate: Array = []
var current_unit_index: int = 0
var is_phase_transitioning: bool = false  # Prevenir transiciones múltiples

## Inicia la batalla con las unidades especificadas
func start_battle(player_mechs: Array, enemy_mechs: Array):
	player_units = player_mechs
	enemy_units = enemy_mechs
	current_turn = 1
	
	_log("Starting battle with %d player units and %d enemy units" % [player_units.size(), enemy_units.size()])
	
	# Verificar si ya tenemos datos de iniciativa guardados
	if owner and owner.has_method("get_stored_initiative"):
		var stored_data = owner.get_stored_initiative()
		if stored_data and stored_data.size() > 0:
			_log("Using pre-calculated initiative")
			use_precalculated_initiative(stored_data)
			return
	
	start_turn()

## Inicia un nuevo turno
func start_turn():
	current_phase = GameEnums.TurnPhase.INITIATIVE
	turn_changed.emit(current_team, current_turn)
	phase_changed.emit(GameEnums.phase_to_string(current_phase))
	
	_log("=== TURN %d START ===" % current_turn)
	
	# Solicitar pantalla de iniciativa visual
	if owner and owner.has_method("show_initiative_screen"):
		owner.show_initiative_screen()
	else:
		# Fallback: tirar iniciativa internamente si no hay pantalla
		await get_tree().create_timer(0.5).timeout
		roll_initiative()

## Tirar iniciativa usando 2d6 para cada equipo
func roll_initiative():
	# En Battletech, la iniciativa se tira con 2d6
	var die1_player = (randi() % 6) + 1
	var die2_player = (randi() % 6) + 1
	var player_initiative = die1_player + die2_player
	
	var die1_enemy = (randi() % 6) + 1
	var die2_enemy = (randi() % 6) + 1
	var enemy_initiative = die1_enemy + die2_enemy
	
	# Preparar datos de iniciativa
	var initiative_data = {
		"player_dice": [die1_player, die2_player],
		"player_total": player_initiative,
		"enemy_dice": [die1_enemy, die2_enemy],
		"enemy_total": enemy_initiative,
		"winner": "player" if player_initiative >= enemy_initiative else "enemy"
	}
	
	current_team = initiative_data["winner"]
	
	_log("Initiative: Player %d vs Enemy %d - Winner: %s" % [
		player_initiative, enemy_initiative, current_team.to_upper()
	])
	
	# Emitir señal de iniciativa
	initiative_rolled.emit(initiative_data)
	
	# Notificar al battle_scene
	if owner and owner.has_method("_on_initiative_result"):
		owner._on_initiative_result(initiative_data)
	
	# Esperar para que se lean los mensajes
	await get_tree().create_timer(1.5).timeout
	advance_phase()

## Usar datos de iniciativa precalculados (desde pantalla de dados)
func use_precalculated_initiative(data: Dictionary):
	current_phase = GameEnums.TurnPhase.INITIATIVE
	
	if not data.has("winner"):
		push_error("Initiative data missing 'winner' key!")
		start_turn()
		return
	
	current_team = data["winner"]
	
	_log("Using precalculated initiative: %s wins" % current_team.to_upper())
	
	# Emitir señales
	turn_changed.emit(current_team, current_turn)
	phase_changed.emit(GameEnums.phase_to_string(current_phase))
	initiative_rolled.emit(data)
	
	if owner and owner.has_method("_on_initiative_result"):
		owner._on_initiative_result(data)
	
	# Ir directamente a la fase de movimiento
	await get_tree().create_timer(0.5).timeout
	advance_phase()

## Avanza a la siguiente fase del turno
func advance_phase():
	if is_phase_transitioning:
		print("[TURN_MGR] advance_phase() blocked - already transitioning")
		return
	
	is_phase_transitioning = true
	print("[TURN_MGR] Advancing from phase: %s" % GameEnums.phase_to_string(current_phase))
	
	match current_phase:
		GameEnums.TurnPhase.INITIATIVE:
			current_phase = GameEnums.TurnPhase.MOVEMENT
			phase_changed.emit(GameEnums.phase_to_string(current_phase))
			await start_movement_phase()
			is_phase_transitioning = false
			
		GameEnums.TurnPhase.MOVEMENT:
			current_phase = GameEnums.TurnPhase.WEAPON_ATTACK
			phase_changed.emit(GameEnums.phase_to_string(current_phase))
			await start_weapon_phase()
			is_phase_transitioning = false
			
		GameEnums.TurnPhase.WEAPON_ATTACK:
			current_phase = GameEnums.TurnPhase.PHYSICAL_ATTACK
			phase_changed.emit(GameEnums.phase_to_string(current_phase))
			await start_physical_phase()
			is_phase_transitioning = false
			
		GameEnums.TurnPhase.PHYSICAL_ATTACK:
			current_phase = GameEnums.TurnPhase.HEAT
			phase_changed.emit(GameEnums.phase_to_string(current_phase))
			await start_heat_phase()
			is_phase_transitioning = false
			
		GameEnums.TurnPhase.HEAT:
			current_phase = GameEnums.TurnPhase.END
			phase_changed.emit(GameEnums.phase_to_string(current_phase))
			end_turn()
			is_phase_transitioning = false
			
		GameEnums.TurnPhase.END:
			current_turn += 1
			start_turn()
			is_phase_transitioning = false

## Inicia la fase de movimiento
func start_movement_phase():
	print("[TURN_MGR] === MOVEMENT PHASE START ===")
	_build_activation_order()
	current_unit_index = 0
	
	print("[TURN_MGR] Waiting for phase transition delay...")
	# Pequeño delay para que phase_changed se procese
	await get_tree().create_timer(GameConstants.PHASE_TRANSITION_DELAY).timeout
	print("[TURN_MGR] Delay finished, calling activate_next_unit(), units_to_activate.size()=%d" % units_to_activate.size())
	activate_next_unit()

## Inicia la fase de ataque con armas
func start_weapon_phase():
	_log("=== WEAPON ATTACK PHASE START ===")
	_build_activation_order()
	current_unit_index = 0
	
	await get_tree().create_timer(GameConstants.PHASE_TRANSITION_DELAY).timeout
	activate_next_unit()

## Inicia la fase de ataque físico
func start_physical_phase():
	_log("=== PHYSICAL ATTACK PHASE START ===")
	_build_activation_order()
	current_unit_index = 0
	
	await get_tree().create_timer(GameConstants.PHASE_TRANSITION_DELAY).timeout
	activate_next_unit()

## Inicia la fase de disipación de calor
func start_heat_phase():
	_log("=== HEAT PHASE START ===")
	# La fase de calor se procesa automáticamente en battle_scene
	advance_phase()

## Construye el orden de activación alternando entre equipos
## ESCALABLE: Funciona con cualquier número de unidades por equipo (1-4+)
## Alterna la activación: Unit1_TeamA, Unit1_TeamB, Unit2_TeamA, Unit2_TeamB, etc.
func _build_activation_order():
	units_to_activate.clear()
	print("[TURN_MGR] Building activation order for phase: %s" % GameEnums.phase_to_string(current_phase))
	print("[TURN_MGR]   Player units: %d, Enemy units: %d" % [player_units.size(), enemy_units.size()])
	
	# Filtrar solo unidades activas (no destruidas)
	var player_active = player_units.filter(func(u): return not u.is_destroyed)
	var enemy_active = enemy_units.filter(func(u): return not u.is_destroyed)
	print("[TURN_MGR]   Active - Player: %d, Enemy: %d" % [player_active.size(), enemy_active.size()])
	
	# Determinar el número máximo de unidades para alternar correctamente
	var max_units = max(player_active.size(), enemy_active.size())

	# FASE DE MOVIMIENTO: El ganador de iniciativa mueve ÚLTIMO (reglas BattleTech)
	# Ejemplo con 2v2: Si Player gana iniciativa -> Enemy1, Player1, Enemy2, Player2
	if current_phase == GameEnums.TurnPhase.MOVEMENT:
		var first_team = enemy_active if current_team == "player" else player_active
		var last_team = player_active if current_team == "player" else enemy_active
		for i in range(max_units):
			if i < first_team.size():
				units_to_activate.append(first_team[i])
			if i < last_team.size():
				units_to_activate.append(last_team[i])
	
	# FASES DE ATAQUE: El ganador de iniciativa ataca PRIMERO
	# Ejemplo con 2v2: Si Player gana iniciativa -> Player1, Enemy1, Player2, Enemy2
	elif current_phase == GameEnums.TurnPhase.WEAPON_ATTACK or current_phase == GameEnums.TurnPhase.PHYSICAL_ATTACK:
		var first_team = player_active if current_team == "player" else enemy_active
		var last_team = enemy_active if current_team == "player" else player_active
		for i in range(max_units):
			if i < first_team.size():
				units_to_activate.append(first_team[i])
			if i < last_team.size():
				units_to_activate.append(last_team[i])
	else:
		# Por defecto, alternar según current_team
		for i in range(max_units):
			if current_team == "player":
				if i < player_active.size():
					units_to_activate.append(player_active[i])
				if i < enemy_active.size():
					units_to_activate.append(enemy_active[i])
			else:
				if i < enemy_active.size():
					units_to_activate.append(enemy_active[i])
				if i < player_active.size():
					units_to_activate.append(player_active[i])
	print("[TURN_MGR] Built activation order: %d units" % units_to_activate.size())
	for i in range(units_to_activate.size()):
		var unit = units_to_activate[i]
		var team_str = "player" if unit in player_units else "enemy"
		print("[TURN_MGR]   [%d] %s (%s)" % [i, unit.mech_name, team_str])
		# Debug: imprimir armas
		if typeof(unit.weapons) == TYPE_ARRAY:
			print("[TURN_MGR]     Weapons: %d" % unit.weapons.size())
			for w_idx in range(min(3, unit.weapons.size())):
				print("[TURN_MGR]       - %s" % unit.weapons[w_idx].get("name", "Unknown"))

## Activa la siguiente unidad en el orden
func activate_next_unit():
	print("[TURN_MGR] activate_next_unit(): current_unit_index=%d, units_to_activate.size()=%d" % [current_unit_index, units_to_activate.size()])
	# Si no hay unidades para activar y es el inicio de la fase, hay un problema
	if units_to_activate.size() == 0:
		print("[TURN_MGR] WARNING: No units to activate in phase %s!" % GameEnums.phase_to_string(current_phase))
		advance_phase()
		return
	
	if current_unit_index >= units_to_activate.size():
		print("[TURN_MGR] All units activated, advancing phase")
		advance_phase()
		return
	
	var unit = units_to_activate[current_unit_index]
	
	# Resetear movimiento SOLO en fase de movimiento
	if current_phase == GameEnums.TurnPhase.MOVEMENT and unit.has_method("reset_movement"):
		unit.reset_movement()
	
	print("[TURN_MGR] Activating unit: %s [%d/%d]" % [unit.mech_name, current_unit_index + 1, units_to_activate.size()])
	unit_activated.emit(unit)

## Completa la activación de la unidad actual
func complete_unit_activation():
	current_unit_index += 1
	activate_next_unit()

## Termina el turno actual
func end_turn():
	_log("=== TURN %d END ===" % current_turn)
	
	# Chequear condiciones de victoria (ESCALABLE: funciona con cualquier número de unidades)
	# Victoria: Al menos 1 unidad propia viva Y todas las enemigas destruidas
	var player_alive = player_units.any(func(u): return not u.is_destroyed)
	var enemy_alive = enemy_units.any(func(u): return not u.is_destroyed)
	
	if not player_alive:
		end_battle("defeat")
	elif not enemy_alive:
		end_battle("victory")
	else:
		# Limpiar los datos de iniciativa para el próximo turno
		if owner and owner.has_method("clear_initiative_data"):
			owner.clear_initiative_data()
		
		advance_phase()  # Siguiente turno

## Termina la batalla
func end_battle(result: String):
	_log("=== BATTLE ENDED: %s ===" % result.to_upper())
	battle_ended.emit(result)
	# Aquí se podría mostrar pantalla de resultados

## Utilidades

func get_current_phase_name() -> String:
	return GameEnums.phase_to_string(current_phase)

func is_player_turn() -> bool:
	if units_to_activate.size() == 0:
		return current_team == "player"
	
	if current_unit_index >= units_to_activate.size():
		return false
	
	var current_unit = units_to_activate[current_unit_index]
	return current_unit in player_units

func _log(message: String):
	pass  # Debug logs disabled
