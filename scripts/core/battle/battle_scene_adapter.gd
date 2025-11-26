## BattleSceneAdapter - Adaptador para integrar el nuevo sistema con battle_scene.gd
## Este adaptador permite migrar gradualmente del sistema actual al nuevo
class_name BattleSceneAdapter
extends Node

const LocalBattleManagerClass = preload("res://scripts/core/battle/local_battle_manager.gd")
const NetworkBattleManagerClass = preload("res://scripts/core/battle/network_battle_manager.gd")

# Referencia al battle_scene
var battle_scene: Node2D = null

# El manager de batalla (LocalBattleManager o NetworkBattleManager)
var battle_manager: BattleController = null

# Mapeo de IDs de estado a nodos de mech
var mech_id_to_node: Dictionary = {}  # state_mech_id -> mech_node
var mech_node_to_id: Dictionary = {}  # mech_node -> state_mech_id

# Señales para la UI existente
signal deployment_phase_started
signal deployment_complete
signal initiative_rolled(player_roll: int, enemy_roll: int, winner: String)
signal movement_phase_started(mech_node)
signal attack_phase_started(mech_node)
signal turn_ended

func _init():
	pass

## Inicializa el adaptador
func setup(p_battle_scene: Node2D, is_multiplayer: bool, config: Dictionary = {}) -> bool:
	battle_scene = p_battle_scene
	
	# Crear el manager apropiado
	if is_multiplayer:
		battle_manager = NetworkBattleManagerClass.new()
	else:
		battle_manager = LocalBattleManagerClass.new()
	
	# Añadir como hijo para que reciba _process
	add_child(battle_manager)
	
	# Conectar señales del manager
	_connect_manager_signals()
	
	# Inicializar
	var init_config = config.duplicate()
	if not is_multiplayer:
		init_config["hex_grid"] = battle_scene.hex_grid
		init_config["map_size"] = Vector2i(
			battle_scene.hex_grid.grid_width, 
			battle_scene.hex_grid.grid_height
		)
	
	return battle_manager.initialize(init_config)

func _connect_manager_signals() -> void:
	battle_manager.state_changed.connect(_on_state_changed)
	battle_manager.phase_changed.connect(_on_phase_changed)
	battle_manager.turn_changed.connect(_on_turn_changed)
	battle_manager.active_team_changed.connect(_on_active_team_changed)
	battle_manager.active_unit_changed.connect(_on_active_unit_changed)
	battle_manager.deployment_started.connect(_on_deployment_started)
	battle_manager.deployment_zone_ready.connect(_on_deployment_zone_ready)
	battle_manager.mech_deployed.connect(_on_mech_deployed)
	battle_manager.deployment_complete.connect(_on_deployment_complete)
	battle_manager.movement_started.connect(_on_movement_started)
	battle_manager.movement_executed.connect(_on_movement_executed)
	battle_manager.facing_change_started.connect(_on_facing_change_started)
	battle_manager.facing_changed.connect(_on_facing_changed)
	battle_manager.attack_resolved.connect(_on_attack_resolved)
	battle_manager.initiative_rolled.connect(_on_initiative_rolled)
	battle_manager.game_over.connect(_on_game_over)
	battle_manager.error_occurred.connect(_on_error_occurred)

#region Registro de Mechs

## Registra un mech node con el sistema unificado
func register_mech(mech_node, team: String) -> String:
	var state = battle_manager.get_state()
	if not state:
		push_error("BattleSceneAdapter: No state available")
		return ""
	
	# Crear datos del mech desde el nodo
	var mech_data = {
		"name": mech_node.mech_name if mech_node.has_method("get") else "Unknown",
		"chassis": mech_node.get("chassis_name") if mech_node.get("chassis_name") else "Unknown",
		"variant": mech_node.get("variant_name") if mech_node.get("variant_name") else "",
		"walk_mp": mech_node.get("walk_mp") if mech_node.get("walk_mp") else 4,
		"run_mp": mech_node.get("run_mp") if mech_node.get("run_mp") else 6,
		"jump_mp": mech_node.get("jump_mp") if mech_node.get("jump_mp") else 0,
		"weapons": mech_node.get("weapons") if mech_node.get("weapons") else [],
		"armor": _extract_armor(mech_node),
		"structure": _extract_structure(mech_node),
		"heat_sinks": mech_node.get("heat_sinks") if mech_node.get("heat_sinks") else 10
	}
	
	# Registrar en el manager
	var state_id = ""
	if battle_manager is NetworkBattleManagerClass:
		state_id = battle_manager.add_local_mech(mech_data, team)
	else:
		# Para LocalBattleManager, los mechs se añaden durante initialize()
		# Pero podemos añadir después también
		var BattleStateClass = preload("res://scripts/core/battle/battle_state.gd")
		var mech = BattleStateClass.MechState.new()
		mech.id = "mech_" + str(state.mechs.size())
		mech.name = mech_data.name
		mech.team = team
		mech.walk_mp = mech_data.walk_mp
		mech.run_mp = mech_data.run_mp
		mech.jump_mp = mech_data.jump_mp
		mech.weapons = mech_data.weapons
		mech.heat_sinks = mech_data.heat_sinks
		state.add_mech(mech)
		state_id = mech.id
	
	# Guardar mapeo
	mech_id_to_node[state_id] = mech_node
	mech_node_to_id[mech_node] = state_id
	
	return state_id

func _extract_armor(mech_node) -> Dictionary:
	if mech_node.has_method("get_armor_values"):
		return mech_node.get_armor_values()
	
	# Fallback
	return {
		"head": 9,
		"center_torso": 35,
		"left_torso": 24,
		"right_torso": 24,
		"left_arm": 24,
		"right_arm": 24,
		"left_leg": 33,
		"right_leg": 33
	}

func _extract_structure(mech_node) -> Dictionary:
	if mech_node.has_method("get_structure_values"):
		return mech_node.get_structure_values()
	
	# Fallback basado en tonelaje estimado
	return {
		"head": 3,
		"center_torso": 11,
		"left_torso": 8,
		"right_torso": 8,
		"left_arm": 6,
		"right_arm": 6,
		"left_leg": 8,
		"right_leg": 8
	}

## Obtiene el nodo de mech para un ID de estado
func get_mech_node(state_id: String):
	return mech_id_to_node.get(state_id)

## Obtiene el ID de estado para un nodo de mech
func get_mech_state_id(mech_node) -> String:
	return mech_node_to_id.get(mech_node, "")

#endregion

#region Forwarding de comandos

## Solicita desplegar un mech
func deploy_mech(mech_node, position: Vector2i, facing: int) -> void:
	var state_id = get_mech_state_id(mech_node)
	if state_id.is_empty():
		push_error("BattleSceneAdapter: Mech not registered")
		return
	
	battle_manager.request_deploy_mech(state_id, position, facing)

## Solicita mover un mech
func move_mech(mech_node, path: Array, movement_type: GameEnums.MovementType) -> void:
	var state_id = get_mech_state_id(mech_node)
	if state_id.is_empty():
		push_error("BattleSceneAdapter: Mech not registered")
		return
	
	battle_manager.request_execute_movement(state_id, path, movement_type)

## Solicita cambiar el facing de un mech
func change_facing(mech_node, new_facing: int) -> void:
	var state_id = get_mech_state_id(mech_node)
	if state_id.is_empty():
		push_error("BattleSceneAdapter: Mech not registered")
		return
	
	battle_manager.request_change_facing(state_id, new_facing)

## Termina el movimiento del mech actual
func end_movement(mech_node) -> void:
	var state_id = get_mech_state_id(mech_node)
	if state_id.is_empty():
		return
	
	battle_manager.request_end_movement(state_id)

## Solicita atacar
func attack(attacker_node, target_node, weapon_index: int) -> void:
	var attacker_id = get_mech_state_id(attacker_node)
	var target_id = get_mech_state_id(target_node)
	
	if attacker_id.is_empty() or target_id.is_empty():
		push_error("BattleSceneAdapter: Invalid attacker or target")
		return
	
	battle_manager.request_declare_attack(attacker_id, target_id, weapon_index)

## Pasa al siguiente mech
func next_unit() -> void:
	battle_manager.request_next_unit()

## Obtiene la zona de despliegue
func get_deployment_zone(team: String) -> Array[Vector2i]:
	return battle_manager.get_deployment_zone(team)

## Obtiene si es el turno del jugador local
func is_local_turn() -> bool:
	return battle_manager.is_local_player_turn()

## Obtiene el equipo local
func get_local_team() -> String:
	return battle_manager.get_local_team()

#endregion

#region Callbacks del Manager

func _on_state_changed(state) -> void:
	# Sincronizar estado visual de todos los mechs
	for state_id in mech_id_to_node:
		var mech_node = mech_id_to_node[state_id]
		var mech_state = state.get_mech(state_id)
		if mech_state and mech_node:
			_sync_mech_visual(mech_node, mech_state)

func _sync_mech_visual(mech_node, mech_state) -> void:
	# Sincronizar posición si está desplegado
	if mech_state.is_deployed and mech_state.position != Vector2i(-1, -1):
		if mech_node.has_method("set_hex_position"):
			mech_node.set_hex_position(mech_state.position)
		elif mech_node.get("hex_position") != null:
			mech_node.hex_position = mech_state.position
			mech_node.position = battle_scene.hex_grid.hex_to_pixel(mech_state.position)
	
	# Sincronizar facing
	if mech_node.has_method("set_facing"):
		mech_node.set_facing(mech_state.facing)
	elif mech_node.get("facing") != null:
		mech_node.facing = mech_state.facing
	
	# Sincronizar visibilidad/destrucción
	if not mech_state.is_active:
		if mech_node.has_method("destroy"):
			mech_node.destroy()
		else:
			mech_node.visible = false

func _on_phase_changed(phase: GameEnums.TurnPhase) -> void:
	match phase:
		GameEnums.TurnPhase.DEPLOYMENT:
			deployment_phase_started.emit()
		GameEnums.TurnPhase.INITIATIVE:
			pass  # Esperar initiative_rolled
		GameEnums.TurnPhase.MOVEMENT:
			pass  # movement_started se emite para cada mech
		GameEnums.TurnPhase.WEAPON_ATTACK, GameEnums.TurnPhase.PHYSICAL_ATTACK:
			pass  # attack_phase_started se emite para cada mech
		GameEnums.TurnPhase.END:
			turn_ended.emit()

func _on_turn_changed(turn: int) -> void:
	print("[ADAPTER] Turn %d" % turn)

func _on_active_team_changed(team: String) -> void:
	print("[ADAPTER] Active team: %s" % team)

func _on_active_unit_changed(mech_id: String) -> void:
	var mech_node = get_mech_node(mech_id)
	if mech_node:
		print("[ADAPTER] Active unit: %s" % mech_node.get("mech_name"))

func _on_deployment_started(team: String) -> void:
	print("[ADAPTER] Deployment started for team: %s" % team)
	deployment_phase_started.emit()

func _on_deployment_zone_ready(valid_hexes: Array) -> void:
	# El battle_scene puede usar esto para mostrar overlay
	if battle_scene.has_method("_show_deployment_overlay"):
		battle_scene._show_deployment_overlay(valid_hexes)

func _on_mech_deployed(mech_id: String, position: Vector2i) -> void:
	var mech_node = get_mech_node(mech_id)
	if mech_node:
		print("[ADAPTER] Mech deployed: %s at %s" % [mech_node.get("mech_name"), position])

func _on_deployment_complete(team: String) -> void:
	print("[ADAPTER] Deployment complete for: %s" % team)
	deployment_complete.emit()

func _on_movement_started(mech_id: String) -> void:
	var mech_node = get_mech_node(mech_id)
	if mech_node:
		movement_phase_started.emit(mech_node)

func _on_movement_executed(mech_id: String, _path: Array, new_position: Vector2i) -> void:
	var mech_node = get_mech_node(mech_id)
	if mech_node and battle_scene.hex_grid:
		mech_node.hex_position = new_position
		mech_node.position = battle_scene.hex_grid.hex_to_pixel(new_position)

func _on_facing_change_started(mech_id: String) -> void:
	# La UI debería mostrar el selector de facing
	var mech_node = get_mech_node(mech_id)
	if mech_node and battle_scene.has_method("_show_facing_selector_for_mech"):
		battle_scene._show_facing_selector_for_mech(mech_node)

func _on_facing_changed(mech_id: String, new_facing: int, _mp_cost: int) -> void:
	var mech_node = get_mech_node(mech_id)
	if mech_node:
		if mech_node.has_method("set_facing"):
			mech_node.set_facing(new_facing)
		elif mech_node.get("facing") != null:
			mech_node.facing = new_facing

func _on_attack_resolved(result: Dictionary) -> void:
	print("[ADAPTER] Attack resolved: %s" % result)
	# TODO: Actualizar UI con resultado del ataque

func _on_initiative_rolled(results: Dictionary) -> void:
	var player_roll = results.get("player", 0)
	var enemy_roll = results.get("enemy", 0)
	var winner = "player" if player_roll >= enemy_roll else "enemy"
	initiative_rolled.emit(player_roll, enemy_roll, winner)

func _on_game_over(winner: String, reason: String) -> void:
	print("[ADAPTER] Game over: %s wins - %s" % [winner, reason])
	if battle_scene.has_method("_on_battle_ended"):
		battle_scene._on_battle_ended(winner, reason)

func _on_error_occurred(error_code: int, message: String) -> void:
	push_error("[ADAPTER] Error %d: %s" % [error_code, message])
	if battle_scene.ui and battle_scene.ui.has_method("add_combat_message"):
		battle_scene.ui.add_combat_message("Error: " + message, Color.RED)

#endregion
