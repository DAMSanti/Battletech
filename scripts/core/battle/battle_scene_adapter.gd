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
@warning_ignore("unused_signal")
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
	
	# NOTA: NO sincronizar facing aquí - el mech visual es la fuente de verdad
	# El facing del estado interno puede estar desactualizado (default 0)
	# El facing se sincroniza solo cuando el servidor lo confirma via battle_scene
	
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
	Log.info("Match", "Turn changed", {"turn": turn})

func _on_active_team_changed(team: String) -> void:
	Log.debug("Match", "Active team changed", {"team": team})

func _on_active_unit_changed(mech_id: String) -> void:
	var mech_node = get_mech_node(mech_id)
	if mech_node:
		Log.debug("Combat", "Active unit changed", {"name": mech_node.get("mech_name")})

func _on_deployment_started(team: String) -> void:
	Log.info("Match", "Deployment started", {"team": team})
	deployment_phase_started.emit()

func _on_deployment_zone_ready(valid_hexes: Array) -> void:
	# El battle_scene puede usar esto para mostrar overlay
	if battle_scene.has_method("_show_deployment_overlay"):
		battle_scene._show_deployment_overlay(valid_hexes)

func _on_mech_deployed(mech_id: String, position: Vector2i) -> void:
	var mech_node = get_mech_node(mech_id)
	if mech_node:
		Log.info("Mech", "Mech deployed", {"name": mech_node.get("mech_name"), "position": [position.x, position.y]})

func _on_deployment_complete(team: String) -> void:
	Log.info("Match", "Deployment complete", {"team": team})
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
	Log.debug("Combat", "Attack resolved", result)
	
	# Obtener los nodos de mech
	var attacker_id = str(result.get("attacker_id", ""))
	var target_id = str(result.get("target_id", ""))
	var attacker_node = get_mech_node(attacker_id)
	var target_node = get_mech_node(target_id)
	
	var attacker_name = attacker_node.mech_name if attacker_node and attacker_node.get("mech_name") else "Unknown"
	var target_name = target_node.mech_name if target_node and target_node.get("mech_name") else "Unknown"
	
	# Procesar resultados de armas (weapon attack)
	var weapon_results = result.get("results", [])
	for weapon_result in weapon_results:
		_display_weapon_result(attacker_name, target_name, weapon_result, target_node)
	
	# Procesar resultado de ataque físico
	if result.has("attack_type"):
		_display_physical_result(attacker_name, target_name, result, target_node)
	
	# Actualizar el calor del atacante si lo tenemos
	if attacker_node and result.has("attacker_heat"):
		attacker_node.heat = result.get("attacker_heat", 0)
		attacker_node.queue_redraw()
	
	# Verificar si el objetivo fue destruido
	if result.get("target_destroyed", false) and target_node:
		target_node.is_destroyed = true
		if battle_scene.ui and battle_scene.ui.has_method("add_combat_message"):
			battle_scene.ui.add_combat_message(">>> %s DESTROYED! <<<" % target_name, Color.RED)

func _display_weapon_result(attacker_name: String, target_name: String, weapon_result: Dictionary, target_node) -> void:
	"""Muestra el resultado de un disparo de arma en la UI"""
	if not battle_scene.ui or not battle_scene.ui.has_method("add_combat_message"):
		return
	
	var weapon_name = weapon_result.get("weapon_name", "Unknown Weapon")
	var roll = weapon_result.get("roll", 0)
	var target_number = weapon_result.get("target_number", 0)
	var dice = weapon_result.get("dice", [0, 0])
	var hit = weapon_result.get("hit", false)
	
	# Mostrar tirada
	battle_scene.ui.add_combat_message("", Color.WHITE)
	battle_scene.ui.add_combat_message("=== %s fires %s at %s ===" % [attacker_name, weapon_name, target_name], Color.CYAN)
	battle_scene.ui.add_combat_message("Roll: %d + %d = %d (need %d+)" % [dice[0], dice[1], roll, target_number], Color.WHITE)
	
	if weapon_result.get("reason", "") == "out_of_range":
		battle_scene.ui.add_combat_message("OUT OF RANGE!", Color.ORANGE)
		return
	
	if weapon_result.get("critical_miss", false):
		battle_scene.ui.add_combat_message("CRITICAL MISS!", Color.RED)
		return
	
	if hit:
		var location = weapon_result.get("location", "unknown")
		var damage = weapon_result.get("damage", 0)
		var damage_result = weapon_result.get("damage_result", {})
		
		battle_scene.ui.add_combat_message("HIT! Location: %s" % location.replace("_", " ").capitalize(), Color.GREEN)
		battle_scene.ui.add_combat_message("Damage: %d" % damage, Color.YELLOW)
		
		# Aplicar daño al mech visual
		if target_node and target_node.has_method("take_damage"):
			target_node.take_damage(location, damage)
			target_node.queue_redraw()
		
		# Mostrar información adicional del daño
		if damage_result.get("critical_hit", false):
			battle_scene.ui.add_combat_message("CRITICAL HIT! Structure damaged!", Color.ORANGE)
		
		if damage_result.get("location_destroyed", false):
			battle_scene.ui.add_combat_message("%s DESTROYED!" % location.replace("_", " ").capitalize(), Color.RED)
		
		if damage_result.get("mech_destroyed", false):
			battle_scene.ui.add_combat_message(">>> MECH DESTROYED! <<<", Color.RED)
	else:
		battle_scene.ui.add_combat_message("MISS!", Color.GRAY)

func _display_physical_result(attacker_name: String, target_name: String, result: Dictionary, target_node) -> void:
	"""Muestra el resultado de un ataque físico en la UI"""
	if not battle_scene.ui or not battle_scene.ui.has_method("add_combat_message"):
		return
	
	var attack_type = result.get("attack_type", "physical")
	var attack_result = result.get("result", {})
	var roll = attack_result.get("roll", 0)
	var target_number = attack_result.get("target_number", 0)
	var dice = attack_result.get("dice", [0, 0])
	var hit = attack_result.get("hit", false)
	
	# Formatear nombre del ataque
	var attack_name = attack_type.replace("_", " ").capitalize()
	
	battle_scene.ui.add_combat_message("", Color.WHITE)
	battle_scene.ui.add_combat_message("=== %s uses %s on %s ===" % [attacker_name, attack_name, target_name], Color.MAGENTA)
	battle_scene.ui.add_combat_message("Roll: %d + %d = %d (need %d+)" % [dice[0], dice[1], roll, target_number], Color.WHITE)
	
	if hit:
		var location = attack_result.get("location", "unknown")
		var damage = attack_result.get("damage", 0)
		
		battle_scene.ui.add_combat_message("HIT! Location: %s" % location.replace("_", " ").capitalize(), Color.GREEN)
		battle_scene.ui.add_combat_message("Damage: %d" % damage, Color.YELLOW)
		
		# Aplicar daño al mech visual
		if target_node and target_node.has_method("take_damage"):
			target_node.take_damage(location, damage)
			target_node.queue_redraw()
	else:
		battle_scene.ui.add_combat_message("MISS!", Color.GRAY)

func _on_initiative_rolled(results: Dictionary) -> void:
	var player_roll = results.get("player", 0)
	var enemy_roll = results.get("enemy", 0)
	var winner = "player" if player_roll >= enemy_roll else "enemy"
	initiative_rolled.emit(player_roll, enemy_roll, winner)

func _on_game_over(winner: String, reason: String) -> void:
	Log.info("Match", "Game over", {"winner": winner, "reason": reason})
	if battle_scene.has_method("_on_battle_ended"):
		battle_scene._on_battle_ended(winner, reason)

func _on_error_occurred(error_code: int, message: String) -> void:
	push_error("[ADAPTER] Error %d: %s" % [error_code, message])
	if battle_scene.ui and battle_scene.ui.has_method("add_combat_message"):
		battle_scene.ui.add_combat_message("Error: " + message, Color.RED)

#endregion
