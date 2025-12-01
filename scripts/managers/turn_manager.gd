extends Node
class_name TurnManager

## Gestor de turnos y fases del juego
## Controla el flujo de la batalla según las reglas de Battletech

signal turn_changed(team: String, turn_number: int)
signal phase_changed(phase_name: String)
signal unit_activated(unit)
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
		# Fallback: avanzar directamente si no hay pantalla (no debería pasar)
		await get_tree().create_timer(0.5).timeout
		advance_phase()

## Usar datos de iniciativa precalculados (desde pantalla de dados)
func use_precalculated_initiative(_data: Dictionary):
	current_phase = GameEnums.TurnPhase.INITIATIVE
	
	# Las iniciativas ya fueron asignadas a cada mech en battle_scene
	# Solo necesitamos emitir señales y continuar
	
	_log("Using individual mech initiatives")
	
	# Emitir señales
	turn_changed.emit(current_team, current_turn)
	phase_changed.emit(GameEnums.phase_to_string(current_phase))
	
	# Ir directamente a la fase de movimiento
	await get_tree().create_timer(0.5).timeout
	advance_phase()

## Avanza a la siguiente fase del turno
func advance_phase():
	if is_phase_transitioning:
		return
	
	is_phase_transitioning = true
	
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
	_build_activation_order()
	current_unit_index = 0
	
	# Pequeño delay para que phase_changed se procese
	await get_tree().create_timer(GameConstants.PHASE_TRANSITION_DELAY).timeout
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

## Construye el orden de activación basado en iniciativa individual
## NUEVO: Ordena los 8 mechs por iniciativa (mayor primero)
func _build_activation_order():
	units_to_activate.clear()
	
	# Filtrar solo unidades activas (no destruidas)
	var player_active = player_units.filter(func(u): return not u.is_destroyed)
	var enemy_active = enemy_units.filter(func(u): return not u.is_destroyed)
	
	# Combinar todos los mechs activos
	var all_units = []
	all_units.append_array(player_active)
	all_units.append_array(enemy_active)
	
	# FASE DE MOVIMIENTO: Menor iniciativa mueve PRIMERO (orden inverso)
	if current_phase == GameEnums.TurnPhase.MOVEMENT:
		all_units.sort_custom(func(a, b): return a.initiative < b.initiative)
	
	# FASES DE ATAQUE: Mayor iniciativa ataca PRIMERO (orden normal)
	elif current_phase == GameEnums.TurnPhase.WEAPON_ATTACK or current_phase == GameEnums.TurnPhase.PHYSICAL_ATTACK:
		all_units.sort_custom(func(a, b): return a.initiative > b.initiative)
	else:
		# Por defecto, ordenar por iniciativa descendente
		all_units.sort_custom(func(a, b): return a.initiative > b.initiative)
	
	units_to_activate = all_units
	
	# Debug log (opcional)
	_log("Built activation order for %s: %d units" % [GameEnums.phase_to_string(current_phase), units_to_activate.size()])
	for i in range(units_to_activate.size()):
		var unit = units_to_activate[i]
		var team_str = "Player" if unit in player_units else "Enemy"
		_log("  [%d] %s (%s) - Initiative: %d" % [i + 1, unit.mech_name, team_str, unit.initiative])

## Activa la siguiente unidad en el orden
func activate_next_unit():
	# Si no hay unidades para activar y es el inicio de la fase, hay un problema
	if units_to_activate.size() == 0:
		advance_phase()
		return
	
	if current_unit_index >= units_to_activate.size():
		advance_phase()
		return
	
	var unit = units_to_activate[current_unit_index]
	
	# Resetear movimiento SOLO en fase de movimiento
	if current_phase == GameEnums.TurnPhase.MOVEMENT and unit.has_method("reset_movement"):
		unit.reset_movement()
	
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

func _log(_message: String):
	pass  # Debug logs disabled
