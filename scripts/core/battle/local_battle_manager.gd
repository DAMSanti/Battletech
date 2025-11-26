## LocalBattleManager - Maneja batallas en modo singleplayer
## Toda la lógica se ejecuta localmente sin necesidad de servidor
class_name LocalBattleManager
extends BattleController

# Referencias a sistemas existentes
var _hex_grid: Node = null
var _movement_system = null
var _combat_system = null
var _los_system = null

# Zonas de despliegue calculadas
var _deployment_zones: Dictionary = {}  # team -> Array[Vector2i]

# RNG para resultados deterministas
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Orden de turnos
var _turn_order: Array = []
var _current_turn_index: int = 0

func _init():
	pass

#region Inicialización

func initialize(config: Dictionary) -> bool:
	_state = _create_initial_state(config)
	
	# Inicializar RNG
	_rng.seed = _state.rng_seed
	
	# Configurar referencias
	if config.has("hex_grid"):
		_hex_grid = config.hex_grid
	
	if config.has("movement_system"):
		_movement_system = config.movement_system
	
	if config.has("combat_system"):
		_combat_system = config.combat_system
	
	if config.has("los_system"):
		_los_system = config.los_system
	
	# Crear mechs desde la configuración
	if config.has("player_mechs"):
		for mech_data in config.player_mechs:
			_add_mech_to_state(mech_data, "player")
	
	if config.has("enemy_mechs"):
		for mech_data in config.enemy_mechs:
			_add_mech_to_state(mech_data, "enemy")
	
	# Calcular zonas de despliegue
	if config.has("map_size"):
		_calculate_deployment_zones(config.map_size)
	
	_is_initialized = true
	state_changed.emit(_state)
	
	return true

func _add_mech_to_state(mech_data: Dictionary, team: String) -> void:
	var mech_state = BattleStateClass.MechState.new()
	
	mech_state.id = mech_data.get("id", "mech_" + str(_state.mechs.size()))
	mech_state.name = mech_data.get("name", "Unknown Mech")
	mech_state.team = team
	mech_state.chassis = mech_data.get("chassis", "Atlas")
	mech_state.variant = mech_data.get("variant", "AS7-D")
	
	# Estadísticas
	mech_state.max_armor = mech_data.get("max_armor", {})
	mech_state.current_armor = mech_state.max_armor.duplicate(true)
	mech_state.max_structure = mech_data.get("max_structure", {})
	mech_state.current_structure = mech_state.max_structure.duplicate(true)
	
	mech_state.walk_mp = mech_data.get("walk_mp", 4)
	mech_state.run_mp = mech_data.get("run_mp", 6)
	mech_state.jump_mp = mech_data.get("jump_mp", 0)
	mech_state.current_mp = mech_state.walk_mp
	
	mech_state.weapons = mech_data.get("weapons", []).duplicate(true)
	mech_state.heat_sinks = mech_data.get("heat_sinks", 10)
	
	# Estado inicial
	mech_state.is_deployed = false
	mech_state.is_active = true
	mech_state.position = Vector2i(-1, -1)
	mech_state.facing = 0
	
	_state.add_mech(mech_state)

func _calculate_deployment_zones(map_size: Vector2i) -> void:
	_deployment_zones.clear()
	
	# Zona del jugador: 2 filas inferiores
	var player_zone: Array[Vector2i] = []
	for x in range(map_size.x):
		for y in range(map_size.y - 2, map_size.y):
			player_zone.append(Vector2i(x, y))
	_deployment_zones["player"] = player_zone
	
	# Zona del enemigo: 2 filas superiores
	var enemy_zone: Array[Vector2i] = []
	for x in range(map_size.x):
		for y in range(2):
			enemy_zone.append(Vector2i(x, y))
	_deployment_zones["enemy"] = enemy_zone

#endregion

#region Fase de Despliegue

func request_start_deployment() -> void:
	if not _state:
		error_occurred.emit(1, "Battle not initialized")
		return
	
	_state.current_phase = GameEnums.TurnPhase.DEPLOYMENT
	phase_changed.emit(_state.current_phase)
	
	# Determinar qué equipo despliega primero
	var first_team = _state.teams[0] if _state.teams.size() > 0 else "player"
	_state.active_team = first_team
	active_team_changed.emit(first_team)
	
	deployment_started.emit(first_team)
	deployment_zone_ready.emit(_deployment_zones.get(first_team, []))

func get_deployment_zone(team: String) -> Array[Vector2i]:
	return _deployment_zones.get(team, [])

func request_deploy_mech(mech_id: String, position: Vector2i, facing: int) -> void:
	var validation = _validate_action("deploy", {
		"mech_id": mech_id,
		"position": position,
		"facing": facing
	})
	
	if not validation.valid:
		error_occurred.emit(2, validation.error)
		return
	
	# Ejecutar el despliegue
	var mech = _state.get_mech(mech_id)
	mech.position = position
	mech.facing = facing
	mech.is_deployed = true
	
	mech_deployed.emit(mech_id, position)
	state_changed.emit(_state)
	
	# Verificar si el equipo actual ha terminado de desplegar
	var team_mechs = _state.get_mechs_for_team(mech.team)
	var all_deployed = true
	for tm in team_mechs:
		if not tm.is_deployed:
			all_deployed = false
			break
	
	if all_deployed:
		deployment_complete.emit(mech.team)
		
		# Verificar si todos los equipos han terminado
		if _state.all_mechs_deployed():
			_start_initiative_phase()
		else:
			# Pasar al siguiente equipo
			var current_index = _state.teams.find(mech.team)
			var next_index = (current_index + 1) % _state.teams.size()
			var next_team = _state.teams[next_index]
			
			_state.active_team = next_team
			active_team_changed.emit(next_team)
			deployment_started.emit(next_team)
			deployment_zone_ready.emit(_deployment_zones.get(next_team, []))

#endregion

#region Fase de Iniciativa

func _start_initiative_phase() -> void:
	_state.current_phase = GameEnums.TurnPhase.INITIATIVE
	_state.turn_number += 1
	
	phase_changed.emit(_state.current_phase)
	turn_changed.emit(_state.turn_number)

func request_roll_initiative() -> void:
	if _state.current_phase != GameEnums.TurnPhase.INITIATIVE:
		error_occurred.emit(3, "Not in initiative phase")
		return
	
	# Tirar iniciativa para cada equipo (2d6)
	var results: Dictionary = {}
	for team in _state.teams:
		var roll = _rng.randi_range(1, 6) + _rng.randi_range(1, 6)
		results[team] = roll
	
	_state.initiative_rolls = results
	initiative_rolled.emit(results)
	
	# Determinar orden de turnos
	var sorted_teams = _state.teams.duplicate()
	sorted_teams.sort_custom(func(a, b): return results[a] > results[b])
	
	# Crear orden de mechs (alternando equipos, perdedor mueve primero)
	_turn_order.clear()
	
	# En Battletech, el que pierde iniciativa mueve primero
	sorted_teams.reverse()
	
	# Obtener mechs de cada equipo
	var team_mechs: Dictionary = {}
	for team in sorted_teams:
		team_mechs[team] = []
		for mech in _state.get_mechs_for_team(team):
			if mech.is_active:
				team_mechs[team].append(mech.id)
	
	# Alternar mechs de cada equipo
	var max_mechs = 0
	for team in sorted_teams:
		max_mechs = max(max_mechs, team_mechs[team].size())
	
	for i in range(max_mechs):
		for team in sorted_teams:
			if i < team_mechs[team].size():
				_turn_order.append(team_mechs[team][i])
	
	_state.turn_order = _turn_order.duplicate()
	turn_order_determined.emit(_turn_order)
	
	# Iniciar fase de movimiento
	_start_movement_phase()

func _start_movement_phase() -> void:
	_state.current_phase = GameEnums.TurnPhase.MOVEMENT
	phase_changed.emit(_state.current_phase)
	
	# Resetear MPs y flags de movimiento
	for mech in _state.mechs.values():
		mech.has_moved = false
		mech.current_mp = mech.walk_mp
		mech.movement_type_used = GameEnums.MovementType.NONE
	
	_current_turn_index = 0
	
	if _turn_order.size() > 0:
		var first_mech = _turn_order[0]
		_state.active_unit_id = first_mech
		var mech = _state.get_mech(first_mech)
		if mech:
			_state.active_team = mech.team
			active_team_changed.emit(_state.active_team)
		active_unit_changed.emit(first_mech)
		movement_started.emit(first_mech)

#endregion

#region Fase de Movimiento

func request_start_movement(mech_id: String) -> void:
	var validation = _validate_action("move", {"mech_id": mech_id})
	
	if not validation.valid:
		error_occurred.emit(4, validation.error)
		return
	
	_state.active_unit_id = mech_id
	active_unit_changed.emit(mech_id)
	movement_started.emit(mech_id)

func get_movement_options(mech_id: String) -> Dictionary:
	var mech = _state.get_mech(mech_id)
	if not mech:
		return {}
	
	# Si tenemos sistema de movimiento, usarlo
	if _movement_system and _movement_system.has_method("get_movement_options"):
		return _movement_system.get_movement_options(mech.position, mech.walk_mp, mech.run_mp, mech.jump_mp)
	
	# Fallback: calcular hexes alcanzables básicos
	var options = {
		"walk": _calculate_reachable_hexes(mech.position, mech.walk_mp),
		"run": _calculate_reachable_hexes(mech.position, mech.run_mp),
		"jump": _calculate_reachable_hexes(mech.position, mech.jump_mp) if mech.jump_mp > 0 else []
	}
	
	return options

func _calculate_reachable_hexes(from: Vector2i, max_mp: int) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	
	if not _hex_grid:
		return reachable
	
	# BFS simple para encontrar hexes alcanzables
	var visited: Dictionary = {}
	var queue: Array = [[from, 0]]
	visited[from] = true
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var pos = current[0]
		var cost = current[1]
		
		if cost > 0:
			reachable.append(pos)
		
		if cost < max_mp:
			var neighbors = _get_hex_neighbors(pos)
			for neighbor in neighbors:
				if not visited.has(neighbor) and _is_hex_passable(neighbor):
					visited[neighbor] = true
					queue.append([neighbor, cost + 1])
	
	return reachable

func _get_hex_neighbors(pos: Vector2i) -> Array[Vector2i]:
	# Asumiendo coordenadas offset (odd-q)
	var neighbors: Array[Vector2i] = []
	var directions_even = [
		Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	var directions_odd = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)
	]
	
	var directions = directions_odd if pos.x % 2 == 1 else directions_even
	
	for dir in directions:
		neighbors.append(pos + dir)
	
	return neighbors

func _is_hex_passable(pos: Vector2i) -> bool:
	if not _hex_grid:
		return true
	
	if _hex_grid.has_method("is_hex_passable"):
		return _hex_grid.is_hex_passable(pos)
	
	# Verificar límites
	if pos.x < 0 or pos.y < 0:
		return false
	if pos.x >= _state.map_size.x or pos.y >= _state.map_size.y:
		return false
	
	# Verificar si hay otro mech
	for mech in _state.mechs.values():
		if mech.is_deployed and mech.position == pos:
			return false
	
	return true

func request_execute_movement(mech_id: String, path: Array, movement_type: GameEnums.MovementType) -> void:
	var validation = _validate_action("move", {"mech_id": mech_id})
	
	if not validation.valid:
		error_occurred.emit(5, validation.error)
		return
	
	var mech = _state.get_mech(mech_id)
	if path.size() == 0:
		error_occurred.emit(5, "Empty path")
		return
	
	var final_pos = path[path.size() - 1]
	if final_pos is Array:
		final_pos = Vector2i(final_pos[0], final_pos[1])
	
	# Calcular MP usado
	var mp_used = path.size()
	
	# Actualizar estado del mech
	mech.position = final_pos
	mech.has_moved = true
	mech.movement_type_used = movement_type
	mech.current_mp = max(0, mech.current_mp - mp_used)
	
	movement_executed.emit(mech_id, path, final_pos)
	state_changed.emit(_state)
	
	# Iniciar selección de facing
	facing_change_started.emit(mech_id)

func request_change_facing(mech_id: String, new_facing: int) -> void:
	var validation = _validate_action("facing", {
		"mech_id": mech_id,
		"facing": new_facing
	})
	
	if not validation.valid:
		error_occurred.emit(6, validation.error)
		return
	
	var mech = _state.get_mech(mech_id)
	var old_facing = mech.facing
	
	# Calcular costo de MP del giro
	var facing_diff = abs(new_facing - old_facing)
	if facing_diff > 3:
		facing_diff = 6 - facing_diff
	var mp_cost = facing_diff  # 1 MP por cada 60 grados
	
	mech.facing = new_facing
	mech.current_mp = max(0, mech.current_mp - mp_cost)
	
	facing_changed.emit(mech_id, new_facing, mp_cost)
	state_changed.emit(_state)
	
	# Avanzar al siguiente mech
	_advance_to_next_unit()

func request_end_movement(mech_id: String) -> void:
	var mech = _state.get_mech(mech_id)
	if mech:
		mech.has_moved = true
	
	_advance_to_next_unit()

func _advance_to_next_unit() -> void:
	_current_turn_index += 1
	
	if _current_turn_index >= _turn_order.size():
		# Todos los mechs han actuado, pasar a siguiente fase
		_advance_to_next_phase()
		return
	
	var next_mech = _turn_order[_current_turn_index]
	_state.active_unit_id = next_mech
	
	var mech = _state.get_mech(next_mech)
	if mech:
		_state.active_team = mech.team
		active_team_changed.emit(_state.active_team)
	
	active_unit_changed.emit(next_mech)
	
	if _state.current_phase == GameEnums.TurnPhase.MOVEMENT:
		movement_started.emit(next_mech)

#endregion

#region Fase de Combate

func _advance_to_next_phase() -> void:
	match _state.current_phase:
		GameEnums.TurnPhase.MOVEMENT:
			_start_weapon_attack_phase()
		GameEnums.TurnPhase.WEAPON_ATTACK:
			_start_physical_attack_phase()
		GameEnums.TurnPhase.PHYSICAL_ATTACK:
			_start_heat_phase()
		GameEnums.TurnPhase.HEAT:
			_start_end_phase()
		GameEnums.TurnPhase.END:
			_start_new_turn()
		_:
			pass

func _start_weapon_attack_phase() -> void:
	_state.current_phase = GameEnums.TurnPhase.WEAPON_ATTACK
	phase_changed.emit(_state.current_phase)
	
	# Reset ataques
	for mech in _state.mechs.values():
		mech.has_attacked = false
	
	_current_turn_index = 0
	if _turn_order.size() > 0:
		var first_mech = _turn_order[0]
		_state.active_unit_id = first_mech
		active_unit_changed.emit(first_mech)

func _start_physical_attack_phase() -> void:
	_state.current_phase = GameEnums.TurnPhase.PHYSICAL_ATTACK
	phase_changed.emit(_state.current_phase)
	
	_current_turn_index = 0
	if _turn_order.size() > 0:
		var first_mech = _turn_order[0]
		_state.active_unit_id = first_mech
		active_unit_changed.emit(first_mech)

func _start_heat_phase() -> void:
	_state.current_phase = GameEnums.TurnPhase.HEAT
	phase_changed.emit(_state.current_phase)
	
	# Procesar calor de todos los mechs
	for mech in _state.mechs.values():
		if mech.is_active:
			_process_heat(mech)
	
	state_changed.emit(_state)
	
	# Avanzar a fase final
	_advance_to_next_phase()

func _process_heat(mech) -> void:
	# Disipar calor basado en heat sinks
	var dissipation = mech.heat_sinks
	mech.current_heat = max(0, mech.current_heat - dissipation)
	
	# TODO: Efectos de calor excesivo

func _start_end_phase() -> void:
	_state.current_phase = GameEnums.TurnPhase.END
	phase_changed.emit(_state.current_phase)
	
	# Verificar condiciones de victoria
	var winner = _state.get_winning_team()
	if winner != "":
		game_over.emit(winner, "All enemy mechs destroyed")
		return
	
	# Iniciar nuevo turno
	_start_new_turn()

func _start_new_turn() -> void:
	# Volver a iniciativa
	_start_initiative_phase()

func request_declare_attack(attacker_id: String, defender_id: String, weapon_index: int) -> void:
	var validation = _validate_action("attack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	})
	
	if not validation.valid:
		error_occurred.emit(7, validation.error)
		return
	
	var attacker = _state.get_mech(attacker_id)
	var defender = _state.get_mech(defender_id)
	
	attack_started.emit(attacker_id, defender_id)
	
	# Resolver el ataque
	var result = _resolve_attack(attacker, defender, weapon_index)
	
	attacker.has_attacked = true
	
	attack_resolved.emit(result)
	state_changed.emit(_state)
	
	# Avanzar al siguiente mech
	_advance_to_next_unit()

func _resolve_attack(attacker, defender, weapon_index: int) -> Dictionary:
	var result = {
		"attacker_id": attacker.id,
		"defender_id": defender.id,
		"weapon_index": weapon_index,
		"hit": false,
		"damage": 0,
		"location": "",
		"critical": false
	}
	
	# Obtener arma
	if weapon_index < 0 or weapon_index >= attacker.weapons.size():
		result["error"] = "Invalid weapon index"
		return result
	
	var weapon = attacker.weapons[weapon_index]
	
	# Calcular modificador de ataque
	var base_to_hit = 4  # Gunnery skill
	var modifier = get_attack_modifier(attacker.id, defender.id, weapon_index)
	var target_number = base_to_hit + modifier
	
	# Tirar 2d6
	var roll = _rng.randi_range(1, 6) + _rng.randi_range(1, 6)
	
	result["roll"] = roll
	result["target_number"] = target_number
	result["hit"] = roll >= target_number
	
	if result.hit:
		result.damage = weapon.get("damage", 5)
		
		# Determinar ubicación (2d6)
		var location_roll = _rng.randi_range(1, 6) + _rng.randi_range(1, 6)
		result.location = _get_hit_location(location_roll)
		
		# Aplicar daño
		_apply_damage(defender, result.damage, result.location)
		
		# Generar calor
		attacker.current_heat += weapon.get("heat", 1)
	
	return result

func _get_hit_location(roll: int) -> String:
	# Tabla de ubicación frontal estándar de Battletech
	match roll:
		2: return "center_torso_critical"
		3: return "right_arm"
		4: return "right_arm"
		5: return "right_leg"
		6: return "right_torso"
		7: return "center_torso"
		8: return "left_torso"
		9: return "left_leg"
		10: return "left_arm"
		11: return "left_arm"
		12: return "head"
		_: return "center_torso"

func _apply_damage(mech, damage: int, location: String) -> void:
	var clean_location = location.replace("_critical", "")
	
	# Primero reducir armadura
	var armor_key = clean_location
	if mech.current_armor.has(armor_key):
		var armor = mech.current_armor[armor_key]
		if armor >= damage:
			mech.current_armor[armor_key] -= damage
			return
		else:
			damage -= armor
			mech.current_armor[armor_key] = 0
	
	# Luego reducir estructura
	if mech.current_structure.has(armor_key):
		mech.current_structure[armor_key] = max(0, mech.current_structure[armor_key] - damage)
		
		# Verificar destrucción
		if mech.current_structure[armor_key] <= 0:
			if armor_key == "center_torso" or armor_key == "head":
				mech.is_active = false
			# TODO: Transferir daño a ubicación adyacente

func get_valid_targets(mech_id: String) -> Array:
	var targets: Array = []
	var attacker = _state.get_mech(mech_id)
	
	if not attacker or not attacker.is_active:
		return targets
	
	for mech in _state.mechs.values():
		if mech.team != attacker.team and mech.is_active:
			# TODO: Verificar línea de visión
			targets.append(mech.id)
	
	return targets

func get_attack_modifier(attacker_id: String, defender_id: String, weapon_index: int) -> int:
	var modifier = 0
	
	var attacker = _state.get_mech(attacker_id)
	var defender = _state.get_mech(defender_id)
	
	if not attacker or not defender:
		return 99  # Imposible
	
	# Modificador por movimiento del atacante
	match attacker.movement_type_used:
		GameEnums.MovementType.WALK:
			modifier += 1
		GameEnums.MovementType.RUN:
			modifier += 2
		GameEnums.MovementType.JUMP:
			modifier += 3
	
	# Modificador por movimiento del defensor
	match defender.movement_type_used:
		GameEnums.MovementType.WALK:
			modifier += 1
		GameEnums.MovementType.RUN:
			modifier += 2
		GameEnums.MovementType.JUMP:
			modifier += 3
	
	# Modificador por rango (simplificado)
	var distance = _calculate_hex_distance(attacker.position, defender.position)
	if distance <= 3:
		modifier += 0  # Corto
	elif distance <= 12:
		modifier += 2  # Medio
	elif distance <= 21:
		modifier += 4  # Largo
	else:
		modifier += 99  # Fuera de rango
	
	# TODO: Terreno, cobertura, calor, etc.
	
	return modifier

func _calculate_hex_distance(from: Vector2i, to: Vector2i) -> int:
	if _hex_grid and _hex_grid.has_method("hex_distance"):
		return _hex_grid.hex_distance(from, to)
	
	# Fallback: distancia Manhattan aproximada
	return abs(to.x - from.x) + abs(to.y - from.y)

func request_physical_attack(attacker_id: String, defender_id: String, attack_type: GameEnums.PhysicalAttackType) -> void:
	var validation = _validate_action("attack", {
		"attacker_id": attacker_id,
		"defender_id": defender_id
	})
	
	if not validation.valid:
		error_occurred.emit(8, validation.error)
		return
	
	# TODO: Implementar ataques físicos (puñetazo, patada, carga, DFA)
	var result = {
		"attacker_id": attacker_id,
		"defender_id": defender_id,
		"attack_type": attack_type,
		"hit": false,
		"damage": 0
	}
	
	attack_resolved.emit(result)
	_advance_to_next_unit()

#endregion

#region Control de Turno

func request_next_unit() -> void:
	_advance_to_next_unit()

func request_end_phase() -> void:
	_advance_to_next_phase()

func request_end_turn() -> void:
	_start_end_phase()

#endregion
