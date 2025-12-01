## BattleNetworkHandler - Gestiona todas las comunicaciones de red en batalla
## Responsabilidad única: Handlers de red, requests al servidor, sincronización
## Extraído de battle_scene.gd como parte del refactoring SOLID
class_name BattleNetworkHandler
extends RefCounted

# ==============================================================================
# SIGNALS - Eventos procesados que battle_scene debe manejar
# ==============================================================================

# Deployment
signal deployment_phase_requested(team: String)
signal enemy_mech_created(mech_data: Dictionary, hex_pos: Vector2i, facing: int, team: String, mech_id: int)
signal my_mech_confirmed(mech_id: int, hex_pos: Vector2i, facing: int, mech_name: String)

# Phases & Turns
signal initiative_received(result: Dictionary)
signal phase_changed_processed(phase: String, turn: int, phase_enum: int)
signal unit_activated_processed(mech_id: int, is_mine: bool)

# Actions Results
signal movement_result(result: Dictionary)
signal rotation_result(result: Dictionary)
signal weapon_fire_result(result: Dictionary)
signal physical_attack_result(result: Dictionary)
signal heat_phase_result(results: Array)

# Battle End
signal battle_ended_processed(winner_team: String, reason: String, i_won: bool)
signal action_rejected_message(reason: String)
signal opponent_disconnected_event()

# UI Messages
signal combat_message(text: String, color: Color)

# ==============================================================================
# STATE
# ==============================================================================
var waiting_for_server: bool = false
var is_my_turn: bool = false
var my_team: String = ""
var match_id: int = -1

# ==============================================================================
# REFERENCES
# ==============================================================================
var network_battle_client: Node = null
var hex_grid: HexGrid = null


func setup(p_client: Node, p_hex_grid: HexGrid, p_match_id: int, p_my_team: String) -> void:
	"""Configura el handler de red"""
	network_battle_client = p_client
	hex_grid = p_hex_grid
	match_id = p_match_id
	my_team = p_my_team
	
	if network_battle_client:
		_connect_signals()
	
	Log.info("Network", "BattleNetworkHandler setup complete - Team: %s, Match: %d" % [my_team, match_id])


func _connect_signals() -> void:
	"""Conecta las señales del cliente de red"""
	if not network_battle_client:
		return
	
	network_battle_client.deployment_started.connect(_on_net_deployment_started)
	network_battle_client.mech_deployed.connect(_on_net_mech_deployed)
	network_battle_client.initiative_result.connect(_on_net_initiative_result)
	network_battle_client.phase_changed.connect(_on_net_phase_changed)
	network_battle_client.unit_activated.connect(_on_net_unit_activated)
	network_battle_client.mech_moved.connect(_on_net_mech_moved)
	network_battle_client.mech_rotated.connect(_on_net_mech_rotated)
	network_battle_client.weapons_fired.connect(_on_net_weapons_fired)
	network_battle_client.physical_attack_result.connect(_on_net_physical_attack)
	network_battle_client.heat_phase_result.connect(_on_net_heat_phase)
	network_battle_client.battle_ended.connect(_on_net_battle_ended)
	network_battle_client.action_rejected.connect(_on_net_action_rejected)
	network_battle_client.opponent_disconnected.connect(_on_net_opponent_disconnected)
	
	Log.debug("Network", "Network signals connected")


# ==============================================================================
# NETWORK EVENT HANDLERS
# ==============================================================================

func _on_net_deployment_started(_match_id: int, team: String) -> void:
	"""Servidor indica inicio de despliegue"""
	Log.info("Network", "Deployment started - Team: %s" % team)
	my_team = team
	deployment_phase_requested.emit(team)


func _on_net_mech_deployed(mech_id: int, mech_data: Dictionary, hex_pos: Vector2i, facing: int, team: String) -> void:
	"""Un mech fue desplegado (mío o enemigo)"""
	Log.info("Network", "*** MECH DEPLOYED ***")
	Log.debug("Network", "  mech_id: %d, name: %s, hex: %s, facing: %d, team: %s" % [
		mech_id, mech_data.get("name", "Unknown"), hex_pos, facing, team
	])
	waiting_for_server = false
	
	if team == my_team:
		# Mi mech - emitir para confirmar network_id
		my_mech_confirmed.emit(mech_id, hex_pos, facing, mech_data.get("name", ""))
	else:
		# Mech enemigo - emitir para crear visualmente
		enemy_mech_created.emit(mech_data, hex_pos, facing, team, mech_id)


func _on_net_initiative_result(result: Dictionary) -> void:
	"""Resultado de iniciativa del servidor"""
	Log.info("Match", "Initiative result: %s wins" % result.get("winner", "unknown"))
	initiative_received.emit(result)


func _on_net_phase_changed(phase: String, turn: int) -> void:
	"""Cambio de fase desde servidor"""
	Log.info("Match", "*** PHASE CHANGED: %s (Turn %d) ***" % [phase, turn])
	
	# Convertir fase string a enum
	var phase_enum: int = GameEnums.TurnPhase.INITIATIVE
	
	match phase:
		"initiative":
			phase_enum = GameEnums.TurnPhase.INITIATIVE
		"movement":
			phase_enum = GameEnums.TurnPhase.MOVEMENT
		"weapon_attack":
			phase_enum = GameEnums.TurnPhase.WEAPON_ATTACK
		"physical_attack":
			phase_enum = GameEnums.TurnPhase.PHYSICAL_ATTACK
		"heat":
			phase_enum = GameEnums.TurnPhase.HEAT
	
	# Emitir mensaje de combate
	combat_message.emit("", Color.WHITE)
	combat_message.emit("═══ Phase: %s (Turn %d) ═══" % [phase.to_upper(), turn], Color.GOLD)
	
	phase_changed_processed.emit(phase, turn, phase_enum)


func _on_net_unit_activated(mech_id: int, is_mine: bool) -> void:
	"""Unidad activada por el servidor"""
	Log.info("Match", "*** UNIT ACTIVATED: %d (mine: %s) ***" % [mech_id, is_mine])
	is_my_turn = is_mine
	unit_activated_processed.emit(mech_id, is_mine)


func _on_net_mech_moved(result: Dictionary) -> void:
	"""Resultado de movimiento desde el servidor"""
	waiting_for_server = false
	
	if result.get("success", false):
		Log.info("Network", "Move confirmed: mech %d to %s" % [
			result.get("mech_id", -1),
			result.get("to_hex", Vector2i.ZERO)
		])
	else:
		Log.warning("Network", "Move rejected: %s" % result.get("error", "Unknown"))
	
	movement_result.emit(result)


func _on_net_mech_rotated(result: Dictionary) -> void:
	"""Resultado de rotación desde el servidor"""
	waiting_for_server = false
	
	if result.get("success", false):
		Log.debug("Network", "Rotation confirmed: mech %d facing %d" % [
			result.get("mech_id", -1),
			result.get("new_facing", 0)
		])
	
	rotation_result.emit(result)


func _on_net_weapons_fired(result: Dictionary) -> void:
	"""Resultado de disparo de armas desde el servidor"""
	waiting_for_server = false
	Log.info("Network", "Weapon fire result received")
	weapon_fire_result.emit(result)


func _on_net_physical_attack(result: Dictionary) -> void:
	"""Resultado de ataque físico desde el servidor"""
	waiting_for_server = false
	Log.info("Network", "Physical attack result received")
	physical_attack_result.emit(result)


func _on_net_heat_phase(results: Array) -> void:
	"""Resultados de fase de calor desde el servidor"""
	Log.info("Network", "Heat phase results received: %d mechs" % results.size())
	
	# Emitir mensaje de cabecera
	combat_message.emit("", Color.WHITE)
	combat_message.emit("═══════════════════════════════", Color.ORANGE)
	combat_message.emit("        HEAT PHASE", Color.ORANGE)
	combat_message.emit("═══════════════════════════════", Color.ORANGE)
	
	heat_phase_result.emit(results)


func _on_net_battle_ended(winner_team: String, reason: String) -> void:
	"""La batalla ha terminado"""
	var i_won = winner_team == my_team
	Log.info("Match", "*** BATTLE ENDED - Winner: %s (%s), I %s ***" % [winner_team, reason, "WON" if i_won else "LOST"])
	battle_ended_processed.emit(winner_team, reason, i_won)


func _on_net_action_rejected(reason: String) -> void:
	"""El servidor rechazó una acción"""
	waiting_for_server = false
	Log.warning("Network", "Action rejected: %s" % reason)
	combat_message.emit("❌ Action rejected: %s" % reason, Color.RED)
	action_rejected_message.emit(reason)


func _on_net_opponent_disconnected() -> void:
	"""El oponente se desconectó"""
	Log.warning("Match", "Opponent disconnected!")
	combat_message.emit("⚠️ Opponent disconnected!", Color.ORANGE)
	opponent_disconnected_event.emit()


# ==============================================================================
# REQUEST METHODS - Enviar solicitudes al servidor
# ==============================================================================

func request_move(mech_id: int, target_hex: Vector2i, movement_type: int) -> void:
	"""Solicita movimiento al servidor"""
	if not network_battle_client:
		return
	
	Log.info("Network", "Requesting move: mech %d to %s (type: %d)" % [mech_id, target_hex, movement_type])
	waiting_for_server = true
	network_battle_client.request_move(mech_id, target_hex, movement_type)


func request_rotate(mech_id: int, new_facing: int) -> void:
	"""Solicita rotación al servidor"""
	if not network_battle_client:
		return
	
	Log.debug("Network", "Requesting rotation: mech %d to facing %d" % [mech_id, new_facing])
	waiting_for_server = true
	network_battle_client.request_rotate(mech_id, new_facing)


func request_fire(attacker_id: int, target_id: int, weapon_indices: Array) -> void:
	"""Solicita disparo de armas al servidor"""
	if not network_battle_client:
		return
	
	Log.info("Network", "Requesting fire: attacker %d -> target %d, weapons: %s" % [
		attacker_id, target_id, weapon_indices
	])
	waiting_for_server = true
	network_battle_client.request_fire(attacker_id, target_id, weapon_indices)


func request_physical_attack(attacker_id: int, target_id: int, attack_type: String) -> void:
	"""Solicita ataque físico al servidor"""
	if not network_battle_client:
		return
	
	Log.info("Network", "Requesting physical attack: %d -> %d (type: %s)" % [
		attacker_id, target_id, attack_type
	])
	waiting_for_server = true
	network_battle_client.request_physical_attack(attacker_id, target_id, attack_type)


func request_end_activation(mech_id: int) -> void:
	"""Solicita fin de activación al servidor"""
	if not network_battle_client:
		return
	
	Log.info("Network", "Requesting end activation for mech %d" % mech_id)
	waiting_for_server = true
	if network_battle_client.has_method("request_end_activation"):
		network_battle_client.request_end_activation(mech_id)


func request_deploy_mech(mech_data: Dictionary, hex: Vector2i, facing: int) -> void:
	"""Solicita despliegue de mech al servidor"""
	if not network_battle_client:
		return
	
	Log.debug("Network", "Requesting deploy: %s at %s facing %d" % [
		mech_data.get("name", "Unknown"), hex, facing
	])
	waiting_for_server = true
	network_battle_client.request_deploy_mech(mech_data, hex, facing)


func notify_deployment_complete() -> void:
	"""Notifica al servidor que terminamos de desplegar"""
	if not network_battle_client:
		return
	
	Log.info("Network", "Notifying deployment complete")
	if network_battle_client.has_method("notify_deployment_complete"):
		network_battle_client.notify_deployment_complete()


# ==============================================================================
# UTILITY METHODS
# ==============================================================================

func is_waiting() -> bool:
	"""Retorna si estamos esperando respuesta del servidor"""
	return waiting_for_server


func get_is_my_turn() -> bool:
	"""Retorna si es nuestro turno"""
	return is_my_turn


func set_is_my_turn(value: bool) -> void:
	"""Establece si es nuestro turno"""
	is_my_turn = value


func get_my_team() -> String:
	"""Retorna nuestro equipo"""
	return my_team


func set_my_team(value: String) -> void:
	"""Establece nuestro equipo"""
	my_team = value


func get_match_id() -> int:
	"""Retorna el ID del match"""
	return match_id


func clear_waiting() -> void:
	"""Limpia el flag de espera"""
	waiting_for_server = false
