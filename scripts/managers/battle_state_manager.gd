extends Node
class_name BattleStateManager

## Gestor de estado de la batalla
## Controla el estado actual y las transiciones

signal state_changed(new_state: int)

var current_state: int = GameEnums.GameState.MOVING
var current_phase: int = GameEnums.TurnPhase.INITIATIVE

var selected_unit = null
var selected_hex: Vector2i = Vector2i(-1, -1)
var current_attack_target = null

var pending_movement_selection: bool = false

## Actualiza el estado según la fase actual
func update_state_for_phase(phase_name: String):
	_log("Updating state for phase: %s" % phase_name)
	
	match phase_name:
		"Movement":
			current_state = GameEnums.GameState.MOVING
			current_phase = GameEnums.TurnPhase.MOVEMENT
			
		"Weapon Attack":
			current_state = GameEnums.GameState.WEAPON_ATTACK
			current_phase = GameEnums.TurnPhase.WEAPON_ATTACK
			
		"Physical Attack":
			current_state = GameEnums.GameState.PHYSICAL_TARGETING
			current_phase = GameEnums.TurnPhase.PHYSICAL_ATTACK
			
		"Heat":
			current_phase = GameEnums.TurnPhase.HEAT
			
		"Initiative":
			current_phase = GameEnums.TurnPhase.INITIATIVE
	
	_log("State set to: %s" % GameEnums.GameState.keys()[current_state])
	state_changed.emit(current_state)

## Establece la unidad seleccionada
func set_selected_unit(unit):
	selected_unit = unit
	pending_movement_selection = false

## Limpia la selección
func clear_selection():
	selected_unit = null
	selected_hex = Vector2i(-1, -1)
	current_attack_target = null
	pending_movement_selection = false

## Verifica si el input del jugador está permitido
func is_player_input_allowed() -> bool:
	# Solo permitir input en ciertos estados
	match current_state:
		GameEnums.GameState.MOVING, \
		GameEnums.GameState.WEAPON_ATTACK, \
		GameEnums.GameState.PHYSICAL_TARGETING:
			return not pending_movement_selection
		_:
			return false

## Activa el modo de selección de movimiento
func start_movement_selection():
	pending_movement_selection = true

## Finaliza el modo de selección de movimiento
func end_movement_selection():
	pending_movement_selection = false

## Getters

func get_current_state() -> int:
	return current_state

func get_current_phase() -> int:
	return current_phase

func get_selected_unit():
	return selected_unit

func is_movement_selection_pending() -> bool:
	return pending_movement_selection

func _log(message: String):
	if GameConstants.ENABLE_DEBUG_LOGS:
		print("[BattleState] ", message)
