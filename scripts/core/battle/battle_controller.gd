## BattleController - Controlador de batalla abstracto
## Esta clase define la interfaz común para el manejo de batallas.
## Se hereda para implementar LocalBattleManager y NetworkBattleManager.
class_name BattleController
extends Node

const BattleStateClass = preload("res://scripts/core/battle/battle_state.gd")

# Señales que la UI debe escuchar
signal state_changed(new_state)  # BattleState
signal phase_changed(phase: GameEnums.TurnPhase)
signal turn_changed(turn_number: int)
signal active_team_changed(team: String)
signal active_unit_changed(mech_id: String)

signal deployment_started(team: String)
signal deployment_zone_ready(valid_hexes: Array)
signal mech_deployed(mech_id: String, position: Vector2i)
signal deployment_complete(team: String)

signal movement_started(mech_id: String)
signal movement_options_ready(mech_id: String, options: Dictionary)
signal movement_executed(mech_id: String, path: Array, new_position: Vector2i)
signal facing_change_started(mech_id: String)
signal facing_changed(mech_id: String, new_facing: int, mp_cost: int)

signal attack_started(attacker_id: String, defender_id: String)
signal attack_resolved(result: Dictionary)

signal initiative_rolled(results: Dictionary)
signal turn_order_determined(order: Array)

signal game_over(winner: String, reason: String)
signal error_occurred(error_code: int, message: String)

# Estado de la batalla (BattleState)
var _state = null
var _is_initialized: bool = false

## Obtiene el estado actual de la batalla (solo lectura)
func get_state():  # -> BattleState
	return _state

## Obtiene si es modo multiplayer
func is_multiplayer() -> bool:
	return false  # Override en NetworkBattleManager

## Obtiene si este cliente tiene autoridad para ejecutar acciones
func has_authority() -> bool:
	return true  # Override en NetworkBattleManager

## Obtiene el ID del jugador local
func get_local_player_id() -> int:
	return 1  # Override en NetworkBattleManager

## Obtiene el equipo del jugador local
func get_local_team() -> String:
	return "player"  # Override en NetworkBattleManager

#region Inicialización

## Inicializa la batalla con la configuración dada
func initialize(config: Dictionary) -> bool:
	push_error("BattleController.initialize() must be overridden")
	return false

## Establece la semilla RNG para reproducibilidad
func set_rng_seed(seed_value: int) -> void:
	if _state:
		_state.rng_seed = seed_value

#endregion

#region Fase de Despliegue

## Solicita iniciar la fase de despliegue
func request_start_deployment() -> void:
	push_error("BattleController.request_start_deployment() must be overridden")

## Obtiene las posiciones válidas de despliegue para un equipo
func get_deployment_zone(team: String) -> Array[Vector2i]:
	push_error("BattleController.get_deployment_zone() must be overridden")
	return []

## Solicita desplegar un mech en una posición
func request_deploy_mech(mech_id: String, position: Vector2i, facing: int) -> void:
	push_error("BattleController.request_deploy_mech() must be overridden")

## Verifica si todos los mechs han sido desplegados
func is_deployment_complete() -> bool:
	if not _state:
		return false
	return _state.all_mechs_deployed()

#endregion

#region Fase de Iniciativa

## Solicita tirar iniciativa
func request_roll_initiative() -> void:
	push_error("BattleController.request_roll_initiative() must be overridden")

#endregion

#region Fase de Movimiento

## Solicita iniciar el movimiento de un mech
func request_start_movement(mech_id: String) -> void:
	push_error("BattleController.request_start_movement() must be overridden")

## Obtiene las opciones de movimiento para un mech
func get_movement_options(mech_id: String) -> Dictionary:
	push_error("BattleController.get_movement_options() must be overridden")
	return {}

## Solicita ejecutar un movimiento
func request_execute_movement(mech_id: String, path: Array, movement_type: GameEnums.MovementType) -> void:
	push_error("BattleController.request_execute_movement() must be overridden")

## Solicita cambiar la orientación después del movimiento
func request_change_facing(mech_id: String, new_facing: int) -> void:
	push_error("BattleController.request_change_facing() must be overridden")

## Solicita terminar el movimiento sin cambiar facing
func request_end_movement(mech_id: String) -> void:
	push_error("BattleController.request_end_movement() must be overridden")

#endregion

#region Fase de Combate

## Solicita declarar un ataque
func request_declare_attack(attacker_id: String, defender_id: String, weapon_index: int) -> void:
	push_error("BattleController.request_declare_attack() must be overridden")

## Obtiene los posibles objetivos para un mech
func get_valid_targets(mech_id: String) -> Array:
	push_error("BattleController.get_valid_targets() must be overridden")
	return []

## Obtiene el modificador de ataque base
func get_attack_modifier(attacker_id: String, defender_id: String, weapon_index: int) -> int:
	push_error("BattleController.get_attack_modifier() must be overridden")
	return 0

## Solicita resolver un ataque físico
func request_physical_attack(attacker_id: String, defender_id: String, attack_type: GameEnums.PhysicalAttackType) -> void:
	push_error("BattleController.request_physical_attack() must be overridden")

#endregion

#region Control de Turno

## Solicita pasar al siguiente mech en el turno
func request_next_unit() -> void:
	push_error("BattleController.request_next_unit() must be overridden")

## Solicita terminar la fase actual
func request_end_phase() -> void:
	push_error("BattleController.request_end_phase() must be overridden")

## Solicita terminar el turno
func request_end_turn() -> void:
	push_error("BattleController.request_end_turn() must be overridden")

#endregion

#region Utilidades

## Verifica si es el turno del jugador local
func is_local_player_turn() -> bool:
	if not _state:
		return false
	return _state.active_team == get_local_team()

## Verifica si un mech pertenece al jugador local
func is_local_mech(mech_id: String) -> bool:
	if not _state:
		return false
	var mech = _state.get_mech(mech_id)
	if not mech:
		return false
	return mech.team == get_local_team()

## Obtiene todos los mechs de un equipo
func get_team_mechs(team: String) -> Array:
	if not _state:
		return []
	return _state.get_mechs_for_team(team)

## Obtiene todos los mechs vivos
func get_active_mechs() -> Array:
	if not _state:
		return []
	return _state.get_active_mechs()

## Verifica si la batalla ha terminado
func is_battle_over() -> bool:
	if not _state:
		return false
	return _state.get_winning_team() != ""

#endregion

#region Métodos Protegidos (para subclases)

## Establece el nuevo estado y emite señales
func _set_state(new_state) -> void:  # new_state: BattleState
	var old_phase = _state.current_phase if _state else null
	var old_turn = _state.turn_number if _state else -1
	var old_team = _state.active_team if _state else ""
	var old_unit = _state.active_unit_id if _state else ""
	
	_state = new_state
	state_changed.emit(_state)
	
	if old_phase != _state.current_phase:
		phase_changed.emit(_state.current_phase)
	
	if old_turn != _state.turn_number:
		turn_changed.emit(_state.turn_number)
	
	if old_team != _state.active_team:
		active_team_changed.emit(_state.active_team)
	
	if old_unit != _state.active_unit_id:
		active_unit_changed.emit(_state.active_unit_id)

## Crea el estado inicial
func _create_initial_state(config: Dictionary):  # -> BattleState
	var state = BattleStateClass.new()
	
	if config.has("rng_seed"):
		state.rng_seed = config.rng_seed
	else:
		state.rng_seed = randi()
	
	if config.has("map_size"):
		state.map_size = config.map_size
	
	if config.has("teams"):
		state.teams = config.teams.duplicate()
	else:
		state.teams = ["player", "enemy"]
	
	state.current_phase = GameEnums.TurnPhase.DEPLOYMENT
	state.turn_number = 0
	
	return state

## Valida que una acción sea legal
func _validate_action(action_type: String, params: Dictionary) -> Dictionary:
	var result = {"valid": false, "error": ""}
	
	if not _state:
		result.error = "Battle not initialized"
		return result
	
	match action_type:
		"deploy":
			result = _validate_deploy(params)
		"move":
			result = _validate_move(params)
		"attack":
			result = _validate_attack(params)
		"facing":
			result = _validate_facing(params)
		_:
			result.error = "Unknown action type: " + action_type
	
	return result

func _validate_deploy(params: Dictionary) -> Dictionary:
	var result = {"valid": false, "error": ""}
	
	if _state.current_phase != GameEnums.TurnPhase.DEPLOYMENT:
		result.error = "Not in deployment phase"
		return result
	
	var mech_id = params.get("mech_id", "")
	var position = params.get("position", Vector2i(-1, -1))
	
	if mech_id.is_empty():
		result.error = "No mech specified"
		return result
	
	var mech = _state.get_mech(mech_id)
	if not mech:
		result.error = "Mech not found: " + mech_id
		return result
	
	if mech.is_deployed:
		result.error = "Mech already deployed"
		return result
	
	# Verificar que la posición está en la zona de despliegue
	var zone = get_deployment_zone(mech.team)
	if position not in zone:
		result.error = "Position not in deployment zone"
		return result
	
	# Verificar que no hay otro mech en esa posición
	for other_mech in _state.mechs.values():
		if other_mech.is_deployed and other_mech.position == position:
			result.error = "Position already occupied"
			return result
	
	result.valid = true
	return result

func _validate_move(params: Dictionary) -> Dictionary:
	var result = {"valid": false, "error": ""}
	
	if _state.current_phase != GameEnums.TurnPhase.MOVEMENT:
		result.error = "Not in movement phase"
		return result
	
	var mech_id = params.get("mech_id", "")
	
	if mech_id.is_empty():
		result.error = "No mech specified"
		return result
	
	var mech = _state.get_mech(mech_id)
	if not mech:
		result.error = "Mech not found: " + mech_id
		return result
	
	if mech.has_moved:
		result.error = "Mech has already moved"
		return result
	
	if not mech.is_active:
		result.error = "Mech is not active"
		return result
	
	result.valid = true
	return result

func _validate_attack(params: Dictionary) -> Dictionary:
	var result = {"valid": false, "error": ""}
	
	if _state.current_phase != GameEnums.TurnPhase.WEAPON_ATTACK and \
	   _state.current_phase != GameEnums.TurnPhase.PHYSICAL_ATTACK:
		result.error = "Not in attack phase"
		return result
	
	var attacker_id = params.get("attacker_id", "")
	var defender_id = params.get("defender_id", "")
	
	if attacker_id.is_empty() or defender_id.is_empty():
		result.error = "Attacker and defender required"
		return result
	
	var attacker = _state.get_mech(attacker_id)
	var defender = _state.get_mech(defender_id)
	
	if not attacker or not defender:
		result.error = "Invalid attacker or defender"
		return result
	
	if attacker.team == defender.team:
		result.error = "Cannot attack friendly units"
		return result
	
	if not attacker.is_active or not defender.is_active:
		result.error = "Both units must be active"
		return result
	
	result.valid = true
	return result

func _validate_facing(params: Dictionary) -> Dictionary:
	var result = {"valid": false, "error": ""}
	
	var mech_id = params.get("mech_id", "")
	var new_facing = params.get("facing", -1)
	
	if mech_id.is_empty():
		result.error = "No mech specified"
		return result
	
	var mech = _state.get_mech(mech_id)
	if not mech:
		result.error = "Mech not found"
		return result
	
	if new_facing < 0 or new_facing > 5:
		result.error = "Invalid facing (must be 0-5)"
		return result
	
	result.valid = true
	return result

#endregion
