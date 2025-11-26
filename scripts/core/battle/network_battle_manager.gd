## NetworkBattleManager - Maneja batallas en modo multiplayer
## Este manager actúa como adaptador entre la UI local y el servidor autoritativo
class_name NetworkBattleManager
extends BattleController

# Referencia al cliente de batalla (RPCs)
var _battle_client: NetworkBattleClient = null

# ID del match actual
var _match_id: int = -1

# ID del peer local
var _local_peer_id: int = -1

# Equipo local
var _local_team: String = ""

# Zonas de despliegue (igual que local)
var _deployment_zones: Dictionary = {}

# Pendiente: esperando confirmación del servidor
var _pending_action: String = ""

func _init():
	pass

#region Overrides de BattleController

func is_multiplayer() -> bool:
	return true

func has_authority() -> bool:
	return false  # El servidor tiene la autoridad

func get_local_player_id() -> int:
	return _local_peer_id

func get_local_team() -> String:
	return _local_team

#endregion

#region Inicialización

func initialize(config: Dictionary) -> bool:
	_state = _create_initial_state(config)
	
	# Configuración de red
	if config.has("battle_client"):
		_battle_client = config.battle_client
		_connect_client_signals()
	else:
		push_error("NetworkBattleManager requires a battle_client")
		return false
	
	if config.has("match_id"):
		_match_id = config.match_id
	
	if config.has("local_peer_id"):
		_local_peer_id = config.local_peer_id
	
	if config.has("local_team"):
		_local_team = config.local_team
	
	# Calcular zonas de despliegue (mismo cálculo que servidor)
	if config.has("map_size"):
		_calculate_deployment_zones(config.map_size)
	
	_is_initialized = true
	state_changed.emit(_state)
	
	return true

func _connect_client_signals() -> void:
	if not _battle_client:
		return
	
	# Conectar señales del cliente a métodos locales
	_battle_client.deployment_started.connect(_on_deployment_started)
	_battle_client.mech_deployed.connect(_on_mech_deployed)
	_battle_client.initiative_result.connect(_on_initiative_result)
	_battle_client.phase_changed.connect(_on_phase_changed)
	_battle_client.unit_activated.connect(_on_unit_activated)
	_battle_client.mech_moved.connect(_on_mech_moved)
	_battle_client.mech_rotated.connect(_on_mech_rotated)
	_battle_client.weapons_fired.connect(_on_weapons_fired)
	_battle_client.physical_attack_result.connect(_on_physical_attack_result)
	_battle_client.heat_phase_result.connect(_on_heat_phase_result)
	_battle_client.battle_ended.connect(_on_battle_ended)
	_battle_client.action_rejected.connect(_on_action_rejected)
	_battle_client.opponent_disconnected.connect(_on_opponent_disconnected)

func _calculate_deployment_zones(map_size: Vector2i) -> void:
	_deployment_zones.clear()
	
	# Zona del jugador (player): sur del mapa (y >= map_size.y - 3)
	var player_zone: Array[Vector2i] = []
	for x in range(map_size.x):
		for y in range(map_size.y - 3, map_size.y):
			player_zone.append(Vector2i(x, y))
	_deployment_zones["player"] = player_zone
	
	# Zona del enemigo: norte del mapa (y < 3)
	var enemy_zone: Array[Vector2i] = []
	for x in range(map_size.x):
		for y in range(3):
			enemy_zone.append(Vector2i(x, y))
	_deployment_zones["enemy"] = enemy_zone

#endregion

#region Fase de Despliegue

func request_start_deployment() -> void:
	# En multiplayer, el servidor decide cuándo empieza el despliegue
	# No hacemos nada aquí, esperamos la señal del servidor
	pass

func get_deployment_zone(team: String) -> Array[Vector2i]:
	return _deployment_zones.get(team, [])

func request_deploy_mech(mech_id: String, position: Vector2i, facing: int) -> void:
	if not _battle_client:
		error_occurred.emit(1, "No battle client")
		return
	
	# Obtener datos del mech del estado local
	var mech = _state.get_mech(mech_id)
	if not mech:
		error_occurred.emit(2, "Mech not found: " + mech_id)
		return
	
	# Construir datos para enviar al servidor
	var mech_data = {
		"name": mech.name,
		"chassis": mech.chassis,
		"variant": mech.variant,
		"tonnage": 75,  # TODO: obtener de mech_data
		"walk_mp": mech.walk_mp,
		"run_mp": mech.run_mp,
		"jump_mp": mech.jump_mp,
		"armor": mech.max_armor.duplicate(true),
		"weapons": mech.weapons.duplicate(true),
		"heat_capacity": 30,
		"heat_dissipation": mech.heat_sinks
	}
	
	_pending_action = "deploy"
	_battle_client.request_deploy_mech(mech_data, position, facing)

#endregion

#region Fase de Iniciativa

func request_roll_initiative() -> void:
	# En multiplayer, el servidor tira la iniciativa automáticamente
	# No hacemos nada, esperamos el resultado
	pass

#endregion

#region Fase de Movimiento

func request_start_movement(mech_id: String) -> void:
	# El servidor controla qué mech se activa
	pass

func get_movement_options(mech_id: String) -> Dictionary:
	var mech = _state.get_mech(mech_id)
	if not mech:
		return {}
	
	# Calcular opciones de movimiento localmente
	# (el servidor validará el movimiento final)
	var options = {
		"walk": _calculate_reachable_hexes(mech.position, mech.walk_mp),
		"run": _calculate_reachable_hexes(mech.position, mech.run_mp),
		"jump": _calculate_reachable_hexes(mech.position, mech.jump_mp) if mech.jump_mp > 0 else []
	}
	
	return options

func _calculate_reachable_hexes(from: Vector2i, max_mp: int) -> Array[Vector2i]:
	# Cálculo simplificado - idealmente usar hex_grid
	var reachable: Array[Vector2i] = []
	
	for dx in range(-max_mp, max_mp + 1):
		for dy in range(-max_mp, max_mp + 1):
			var pos = from + Vector2i(dx, dy)
			if _hex_distance(from, pos) <= max_mp:
				if _is_valid_position(pos):
					reachable.append(pos)
	
	return reachable

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dx = abs(a.x - b.x)
	var dy = abs(a.y - b.y)
	return max(dx, dy)

func _is_valid_position(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0:
		return false
	if pos.x >= _state.map_size.x or pos.y >= _state.map_size.y:
		return false
	
	# Verificar ocupación
	for mech in _state.mechs.values():
		if mech.is_deployed and mech.position == pos:
			return false
	
	return true

func request_execute_movement(mech_id: String, path: Array, movement_type: GameEnums.MovementType) -> void:
	if not _battle_client:
		error_occurred.emit(1, "No battle client")
		return
	
	if path.size() == 0:
		error_occurred.emit(3, "Empty path")
		return
	
	var target_hex = path[path.size() - 1]
	if target_hex is Array:
		target_hex = Vector2i(target_hex[0], target_hex[1])
	
	# El mech_id en multiplayer es un int, necesitamos convertir
	var mech = _state.get_mech(mech_id)
	if not mech:
		error_occurred.emit(2, "Mech not found")
		return
	
	# Convertir movement_type a int
	var mt_int = 1  # Walk default
	match movement_type:
		GameEnums.MovementType.WALK:
			mt_int = 1
		GameEnums.MovementType.RUN:
			mt_int = 2
		GameEnums.MovementType.JUMP:
			mt_int = 3
	
	_pending_action = "move"
	_battle_client.request_move(mech.id.to_int() if mech.id.is_valid_int() else mech.id.hash(), target_hex, mt_int)

func request_change_facing(mech_id: String, new_facing: int) -> void:
	if not _battle_client:
		error_occurred.emit(1, "No battle client")
		return
	
	var mech = _state.get_mech(mech_id)
	if not mech:
		error_occurred.emit(2, "Mech not found")
		return
	
	_pending_action = "rotate"
	_battle_client.request_rotate(mech.id.to_int() if mech.id.is_valid_int() else mech.id.hash(), new_facing)

func request_end_movement(mech_id: String) -> void:
	if not _battle_client:
		return
	
	var mech = _state.get_mech(mech_id)
	if not mech:
		return
	
	_battle_client.request_end_activation(mech.id.to_int() if mech.id.is_valid_int() else mech.id.hash())

#endregion

#region Fase de Combate

func request_declare_attack(attacker_id: String, defender_id: String, weapon_index: int) -> void:
	if not _battle_client:
		error_occurred.emit(1, "No battle client")
		return
	
	var attacker = _state.get_mech(attacker_id)
	var defender = _state.get_mech(defender_id)
	
	if not attacker or not defender:
		error_occurred.emit(2, "Invalid attacker or defender")
		return
	
	_pending_action = "fire"
	_battle_client.request_fire(
		attacker.id.to_int() if attacker.id.is_valid_int() else attacker.id.hash(),
		defender.id.to_int() if defender.id.is_valid_int() else defender.id.hash(),
		[weapon_index]
	)

func get_valid_targets(mech_id: String) -> Array:
	var targets: Array = []
	var attacker = _state.get_mech(mech_id)
	
	if not attacker or not attacker.is_active:
		return targets
	
	for mech in _state.mechs.values():
		if mech.team != attacker.team and mech.is_active:
			targets.append(mech.id)
	
	return targets

func get_attack_modifier(attacker_id: String, defender_id: String, weapon_index: int) -> int:
	# Cálculo local para mostrar en UI
	var modifier = 0
	
	var attacker = _state.get_mech(attacker_id)
	var defender = _state.get_mech(defender_id)
	
	if not attacker or not defender:
		return 99
	
	# Modificadores de movimiento
	match attacker.movement_type_used:
		GameEnums.MovementType.WALK:
			modifier += 1
		GameEnums.MovementType.RUN:
			modifier += 2
		GameEnums.MovementType.JUMP:
			modifier += 3
	
	match defender.movement_type_used:
		GameEnums.MovementType.WALK:
			modifier += 1
		GameEnums.MovementType.RUN:
			modifier += 2
		GameEnums.MovementType.JUMP:
			modifier += 3
	
	# Modificador de rango
	var distance = _hex_distance(attacker.position, defender.position)
	if distance <= 3:
		modifier += 0
	elif distance <= 12:
		modifier += 2
	elif distance <= 21:
		modifier += 4
	else:
		modifier += 99
	
	return modifier

func request_physical_attack(attacker_id: String, defender_id: String, attack_type: GameEnums.PhysicalAttackType) -> void:
	if not _battle_client:
		error_occurred.emit(1, "No battle client")
		return
	
	var attacker = _state.get_mech(attacker_id)
	var defender = _state.get_mech(defender_id)
	
	if not attacker or not defender:
		error_occurred.emit(2, "Invalid attacker or defender")
		return
	
	var attack_type_str = "punch"
	match attack_type:
		GameEnums.PhysicalAttackType.PUNCH:
			attack_type_str = "punch_right"
		GameEnums.PhysicalAttackType.KICK:
			attack_type_str = "kick"
	
	_pending_action = "physical"
	_battle_client.request_physical_attack(
		attacker.id.to_int() if attacker.id.is_valid_int() else attacker.id.hash(),
		defender.id.to_int() if defender.id.is_valid_int() else defender.id.hash(),
		attack_type_str
	)

#endregion

#region Control de Turno

func request_next_unit() -> void:
	if not _battle_client:
		return
	
	var mech = _state.get_mech(_state.active_unit_id)
	if mech:
		_battle_client.request_end_activation(mech.id.to_int() if mech.id.is_valid_int() else mech.id.hash())

func request_end_phase() -> void:
	# El servidor maneja las transiciones de fase
	request_next_unit()

func request_end_turn() -> void:
	# El servidor maneja el fin de turno
	request_next_unit()

#endregion

#region Callbacks del Cliente (Servidor -> Este Manager)

func _on_deployment_started(match_id: int, my_team: String) -> void:
	_match_id = match_id
	_local_team = my_team
	
	_state.current_phase = GameEnums.TurnPhase.DEPLOYMENT
	_state.active_team = my_team
	
	phase_changed.emit(_state.current_phase)
	active_team_changed.emit(my_team)
	deployment_started.emit(my_team)
	deployment_zone_ready.emit(_deployment_zones.get(my_team, []))

func _on_mech_deployed(mech_id: int, mech_data: Dictionary, hex_pos: Vector2i, facing: int, team: String) -> void:
	# Actualizar o crear el mech en el estado local
	var state_mech_id = str(mech_id)
	var mech = _state.get_mech(state_mech_id)
	
	if not mech:
		# Crear nuevo mech
		mech = BattleStateClass.MechState.new()
		mech.id = state_mech_id
		mech.name = mech_data.get("name", "Unknown")
		mech.team = team
		mech.chassis = mech_data.get("chassis", "Unknown")
		mech.variant = mech_data.get("variant", "")
		mech.walk_mp = mech_data.get("walk_mp", 4)
		mech.run_mp = mech_data.get("run_mp", 6)
		mech.jump_mp = mech_data.get("jump_mp", 0)
		mech.max_armor = mech_data.get("armor", {})
		mech.current_armor = mech.max_armor.duplicate(true)
		mech.weapons = mech_data.get("weapons", [])
		mech.heat_sinks = mech_data.get("heat_dissipation", 10)
		_state.add_mech(mech)
	
	mech.position = hex_pos
	mech.facing = facing
	mech.is_deployed = true
	
	_pending_action = ""
	mech_deployed.emit(state_mech_id, hex_pos)
	state_changed.emit(_state)

func _on_initiative_result(result: Dictionary) -> void:
	_state.current_phase = GameEnums.TurnPhase.INITIATIVE
	_state.turn_number = result.get("turn", _state.turn_number + 1)
	
	var results = {
		"player": result.get("player_total", 0),
		"enemy": result.get("enemy_total", 0)
	}
	
	_state.initiative_rolls = results
	
	phase_changed.emit(_state.current_phase)
	turn_changed.emit(_state.turn_number)
	initiative_rolled.emit(results)

func _on_phase_changed(phase: String, turn: int) -> void:
	_state.turn_number = turn
	
	match phase:
		"deployment":
			_state.current_phase = GameEnums.TurnPhase.DEPLOYMENT
		"initiative":
			_state.current_phase = GameEnums.TurnPhase.INITIATIVE
		"movement":
			_state.current_phase = GameEnums.TurnPhase.MOVEMENT
			# Reset MPs
			for mech in _state.mechs.values():
				mech.has_moved = false
				mech.current_mp = mech.walk_mp
		"weapon_attack":
			_state.current_phase = GameEnums.TurnPhase.WEAPON_ATTACK
			for mech in _state.mechs.values():
				mech.has_attacked = false
		"physical_attack":
			_state.current_phase = GameEnums.TurnPhase.PHYSICAL_ATTACK
		"heat":
			_state.current_phase = GameEnums.TurnPhase.HEAT
		"end":
			_state.current_phase = GameEnums.TurnPhase.END
	
	phase_changed.emit(_state.current_phase)
	state_changed.emit(_state)

func _on_unit_activated(mech_id: int, is_mine: bool) -> void:
	var state_mech_id = str(mech_id)
	_state.active_unit_id = state_mech_id
	
	var mech = _state.get_mech(state_mech_id)
	if mech:
		_state.active_team = mech.team
		active_team_changed.emit(_state.active_team)
	
	active_unit_changed.emit(state_mech_id)
	
	if _state.current_phase == GameEnums.TurnPhase.MOVEMENT:
		movement_started.emit(state_mech_id)

func _on_mech_moved(result: Dictionary) -> void:
	var mech_id = str(result.get("mech_id", 0))
	var to_hex = Vector2i(result["to_hex"][0], result["to_hex"][1])
	
	var mech = _state.get_mech(mech_id)
	if mech:
		mech.position = to_hex
		mech.has_moved = true
		mech.current_mp = result.get("remaining_mp", 0)
		
		var mt = result.get("movement_type", 1)
		match mt:
			1: mech.movement_type_used = GameEnums.MovementType.WALK
			2: mech.movement_type_used = GameEnums.MovementType.RUN
			3: mech.movement_type_used = GameEnums.MovementType.JUMP
	
	_pending_action = ""
	movement_executed.emit(mech_id, [], to_hex)
	state_changed.emit(_state)
	
	# Esperar por facing
	facing_change_started.emit(mech_id)

func _on_mech_rotated(result: Dictionary) -> void:
	var mech_id = str(result.get("mech_id", 0))
	var new_facing = result.get("new_facing", 0)
	var mp_cost = result.get("mp_cost", 0)
	
	var mech = _state.get_mech(mech_id)
	if mech:
		mech.facing = new_facing
		mech.current_mp = result.get("remaining_mp", mech.current_mp - mp_cost)
	
	_pending_action = ""
	facing_changed.emit(mech_id, new_facing, mp_cost)
	state_changed.emit(_state)

func _on_weapons_fired(result: Dictionary) -> void:
	var attacker_id = str(result.get("attacker_id", 0))
	var defender_id = str(result.get("target_id", 0))
	
	var attacker = _state.get_mech(attacker_id)
	if attacker:
		attacker.has_attacked = true
		attacker.current_heat = result.get("attacker_heat", attacker.current_heat)
	
	# Procesar resultados de cada arma
	var results = result.get("results", [])
	for weapon_result in results:
		if weapon_result.get("hit", false):
			var defender = _state.get_mech(defender_id)
			if defender:
				var damage_result = weapon_result.get("damage_result", {})
				if damage_result.get("mech_destroyed", false):
					defender.is_active = false
	
	_pending_action = ""
	attack_resolved.emit(result)
	state_changed.emit(_state)

func _on_physical_attack_result(result: Dictionary) -> void:
	var defender_id = str(result.get("target_id", 0))
	
	if result.get("target_destroyed", false):
		var defender = _state.get_mech(defender_id)
		if defender:
			defender.is_active = false
	
	_pending_action = ""
	attack_resolved.emit(result)
	state_changed.emit(_state)

func _on_heat_phase_result(results: Array) -> void:
	for heat_result in results:
		var mech_id = str(heat_result.get("mech_id", 0))
		var mech = _state.get_mech(mech_id)
		if mech:
			mech.current_heat = heat_result.get("final_heat", 0)
			if heat_result.get("shutdown", false):
				mech.is_shutdown = true
	
	state_changed.emit(_state)

func _on_battle_ended(winner_team: String, reason: String) -> void:
	_state.current_phase = GameEnums.TurnPhase.END
	game_over.emit(winner_team, reason)

func _on_action_rejected(reason: String) -> void:
	_pending_action = ""
	error_occurred.emit(100, reason)

func _on_opponent_disconnected() -> void:
	error_occurred.emit(999, "Opponent disconnected")
	game_over.emit(_local_team, "Opponent disconnected")

#endregion

#region Utilidades adicionales

## Añade un mech al estado local (usado antes de desplegar)
func add_local_mech(mech_data: Dictionary, team: String) -> String:
	var mech = BattleStateClass.MechState.new()
	
	mech.id = "local_" + str(_state.mechs.size())
	mech.name = mech_data.get("name", "Unknown")
	mech.team = team
	mech.chassis = mech_data.get("chassis", "Unknown")
	mech.variant = mech_data.get("variant", "")
	
	mech.walk_mp = mech_data.get("walk_mp", 4)
	mech.run_mp = mech_data.get("run_mp", 6)
	mech.jump_mp = mech_data.get("jump_mp", 0)
	mech.current_mp = mech.walk_mp
	
	mech.max_armor = mech_data.get("armor", {})
	mech.current_armor = mech.max_armor.duplicate(true)
	mech.max_structure = mech_data.get("structure", {})
	mech.current_structure = mech.max_structure.duplicate(true)
	
	mech.weapons = mech_data.get("weapons", [])
	mech.heat_sinks = mech_data.get("heat_dissipation", 10)
	
	mech.is_deployed = false
	mech.is_active = true
	mech.position = Vector2i(-1, -1)
	mech.facing = 0
	
	_state.add_mech(mech)
	
	return mech.id

#endregion
