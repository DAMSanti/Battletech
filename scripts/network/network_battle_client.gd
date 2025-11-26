extends Node
class_name NetworkBattleClient

## NetworkBattleClient - Maneja la comunicación del cliente con el servidor durante la batalla
## Este script se añade a la escena de batalla y traduce RPCs del servidor a señales locales

signal deployment_started(match_id: int, my_team: String)
signal mech_deployed(mech_id: int, mech_data: Dictionary, hex_pos: Vector2i, facing: int, team: String)
signal initiative_result(result: Dictionary)
signal phase_changed(phase: String, turn: int)
signal unit_activated(mech_id: int, is_mine: bool)
signal mech_moved(result: Dictionary)
signal mech_rotated(result: Dictionary)
signal weapons_fired(result: Dictionary)
signal physical_attack_result(result: Dictionary)
signal heat_phase_result(results: Array)
signal battle_ended(winner_team: String, reason: String)
signal action_rejected(reason: String)
signal opponent_disconnected

var current_match_id: int = -1
var my_team: String = ""
var my_mechs: Dictionary = {}  # mech_id -> mech_data local
var enemy_mechs: Dictionary = {}

# Referencias
var network_manager: Node = null
var battle_scene: Node = null

func _ready():
	# Buscar NetworkManager
	network_manager = get_node_or_null("/root/NetworkManager")
	if not network_manager:
		push_error("NetworkManager not found!")
		return
	
	# Conectar señales del NetworkManager para recibir eventos de batalla
	_connect_network_manager_signals()
	
	# El battle_scene será el padre
	battle_scene = get_parent()

func _connect_network_manager_signals():
	"""Conecta las señales de batalla del NetworkManager"""
	if not network_manager:
		return
	
	network_manager.battle_deployment_started.connect(_on_deployment_started_from_nm)
	network_manager.battle_mech_deployed.connect(_on_mech_deployed_from_nm)
	network_manager.battle_initiative_result.connect(_on_initiative_result_from_nm)
	network_manager.battle_phase_changed.connect(_on_phase_changed_from_nm)
	network_manager.battle_unit_activated.connect(_on_unit_activated_from_nm)
	network_manager.battle_mech_moved.connect(_on_mech_moved_from_nm)
	network_manager.battle_mech_rotated.connect(_on_mech_rotated_from_nm)
	network_manager.battle_weapons_fired.connect(_on_weapons_fired_from_nm)
	network_manager.battle_physical_result.connect(_on_physical_result_from_nm)
	network_manager.battle_heat_result.connect(_on_heat_result_from_nm)
	network_manager.battle_ended.connect(_on_battle_ended_from_nm)
	network_manager.battle_action_rejected.connect(_on_action_rejected_from_nm)
	network_manager.battle_opponent_disconnected.connect(_on_opponent_disconnected_from_nm)
	
	print("[BATTLE_CLIENT] Connected to NetworkManager battle signals")

func _on_deployment_started_from_nm(match_id: int, team: String):
	current_match_id = match_id
	my_team = team
	deployment_started.emit(match_id, team)

func _on_mech_deployed_from_nm(mech_id: int, mech_data: Dictionary, hex_pos: Array, facing: int, team: String):
	var hex = Vector2i(hex_pos[0], hex_pos[1])
	if team == my_team:
		my_mechs[mech_id] = mech_data.duplicate(true)
		my_mechs[mech_id]["hex_position"] = hex
		my_mechs[mech_id]["facing"] = facing
	else:
		enemy_mechs[mech_id] = mech_data.duplicate(true)
		enemy_mechs[mech_id]["hex_position"] = hex
		enemy_mechs[mech_id]["facing"] = facing
	mech_deployed.emit(mech_id, mech_data, hex, facing, team)

func _on_initiative_result_from_nm(result: Dictionary):
	initiative_result.emit(result)

func _on_phase_changed_from_nm(phase: String, turn: int):
	phase_changed.emit(phase, turn)

func _on_unit_activated_from_nm(mech_id: int, is_mine: bool):
	unit_activated.emit(mech_id, is_mine)

func _on_mech_moved_from_nm(result: Dictionary):
	var mech_id = result["mech_id"]
	var to_hex = Vector2i(result["to_hex"][0], result["to_hex"][1])
	if mech_id in my_mechs:
		my_mechs[mech_id]["hex_position"] = to_hex
	elif mech_id in enemy_mechs:
		enemy_mechs[mech_id]["hex_position"] = to_hex
	mech_moved.emit(result)

func _on_mech_rotated_from_nm(result: Dictionary):
	var mech_id = result["mech_id"]
	var new_facing = result["new_facing"]
	if mech_id in my_mechs:
		my_mechs[mech_id]["facing"] = new_facing
	elif mech_id in enemy_mechs:
		enemy_mechs[mech_id]["facing"] = new_facing
	mech_rotated.emit(result)

func _on_weapons_fired_from_nm(result: Dictionary):
	if result.get("target_destroyed", false):
		var target_id = result["target_id"]
		if target_id in my_mechs:
			my_mechs[target_id]["is_destroyed"] = true
		elif target_id in enemy_mechs:
			enemy_mechs[target_id]["is_destroyed"] = true
	weapons_fired.emit(result)

func _on_physical_result_from_nm(result: Dictionary):
	if result.get("target_destroyed", false):
		var target_id = result["target_id"]
		if target_id in my_mechs:
			my_mechs[target_id]["is_destroyed"] = true
		elif target_id in enemy_mechs:
			enemy_mechs[target_id]["is_destroyed"] = true
	physical_attack_result.emit(result)

func _on_heat_result_from_nm(results: Array):
	for result in results:
		var mech_id = result["mech_id"]
		if mech_id in my_mechs:
			my_mechs[mech_id]["heat"] = result["final_heat"]
			my_mechs[mech_id]["is_shutdown"] = result["shutdown"]
		elif mech_id in enemy_mechs:
			enemy_mechs[mech_id]["heat"] = result["final_heat"]
			enemy_mechs[mech_id]["is_shutdown"] = result["shutdown"]
	heat_phase_result.emit(results)

func _on_battle_ended_from_nm(winner_team: String, reason: String):
	battle_ended.emit(winner_team, reason)

func _on_action_rejected_from_nm(reason: String):
	action_rejected.emit(reason)

func _on_opponent_disconnected_from_nm():
	opponent_disconnected.emit()

func setup(match_id: int, team: String):
	"""Configura el cliente para una partida específica"""
	current_match_id = match_id
	my_team = team
	print("[BATTLE_CLIENT] Setup for match %d as %s" % [match_id, team])

# ============================================================
# SOLICITUDES AL SERVIDOR (Cliente -> Servidor)
# Usamos NetworkManager para enviar los RPCs ya que es un autoload compartido
# ============================================================

func request_deploy_mech(mech_data: Dictionary, hex_pos: Vector2i, facing: int):
	"""Solicita desplegar un mech"""
	if current_match_id == -1:
		push_error("Not in a match!")
		return
	
	# Enviar RPC al servidor via NetworkManager (autoload compartido)
	if network_manager:
		network_manager.rpc_id(1, "server_request_deploy_mech", 
			current_match_id, mech_data, [hex_pos.x, hex_pos.y], facing)
	else:
		push_error("[BATTLE_CLIENT] NetworkManager not available!")

func request_move(mech_id: int, target_hex: Vector2i, movement_type: int):
	"""Solicita mover un mech"""
	if network_manager:
		network_manager.rpc_id(1, "server_request_move",
			current_match_id, mech_id, [target_hex.x, target_hex.y], movement_type)

func request_rotate(mech_id: int, new_facing: int):
	"""Solicita rotar un mech"""
	if network_manager:
		network_manager.rpc_id(1, "server_request_rotate",
			current_match_id, mech_id, new_facing)

func request_fire(attacker_id: int, target_id: int, weapon_indices: Array):
	"""Solicita disparar armas"""
	if network_manager:
		network_manager.rpc_id(1, "server_request_fire",
			current_match_id, attacker_id, target_id, weapon_indices)

func request_physical_attack(attacker_id: int, target_id: int, attack_type: String):
	"""Solicita ataque físico"""
	if network_manager:
		network_manager.rpc_id(1, "server_request_physical_attack",
			current_match_id, attacker_id, target_id, attack_type)

func request_end_activation(mech_id: int):
	"""Indica que terminó la activación de un mech"""
	if network_manager:
		network_manager.rpc_id(1, "server_request_end_activation",
			current_match_id, mech_id)

func notify_deployment_complete():
	"""Notifica al servidor que terminamos de desplegar todos nuestros mechs"""
	print("[BATTLE_CLIENT] Notifying server: deployment complete")
	if network_manager:
		network_manager.rpc_id(1, "server_deployment_complete", current_match_id)

# ============================================================
# RPCs DEL SERVIDOR (LEGACY - ahora se reciben via señales de NetworkManager)
# Mantenemos los stubs por si algún código antiguo aún los usa directamente
# ============================================================

@rpc("authority", "reliable")
func client_start_deployment(match_id: int, team: String):
	"""LEGACY - Servidor indica inicio de fase de despliegue"""
	_on_deployment_started_from_nm(match_id, team)

@rpc("authority", "reliable")
func client_mech_deployed(mech_id: int, mech_data: Dictionary, hex_pos: Array, facing: int, team: String):
	"""LEGACY - Servidor confirma despliegue de mech"""
	_on_mech_deployed_from_nm(mech_id, mech_data, hex_pos, facing, team)

@rpc("authority", "reliable")
func client_initiative_result(result: Dictionary):
	"""LEGACY - Servidor envía resultado de iniciativa"""
	_on_initiative_result_from_nm(result)

@rpc("authority", "reliable")
func client_phase_changed(phase: String, turn: int):
	"""LEGACY - Servidor indica cambio de fase"""
	_on_phase_changed_from_nm(phase, turn)

@rpc("authority", "reliable")
func client_unit_activated(mech_id: int, is_mine: bool):
	"""LEGACY - Servidor indica qué unidad se activa"""
	_on_unit_activated_from_nm(mech_id, is_mine)

@rpc("authority", "reliable")
func client_mech_moved(result: Dictionary):
	"""LEGACY - Servidor confirma movimiento"""
	_on_mech_moved_from_nm(result)

@rpc("authority", "reliable")
func client_mech_rotated(result: Dictionary):
	"""LEGACY - Servidor confirma rotación"""
	_on_mech_rotated_from_nm(result)

@rpc("authority", "reliable")
func client_weapons_fired(result: Dictionary):
	"""LEGACY - Servidor envía resultados de disparo"""
	_on_weapons_fired_from_nm(result)

@rpc("authority", "reliable")
func client_physical_attack_result(result: Dictionary):
	"""LEGACY - Servidor envía resultado de ataque físico"""
	_on_physical_result_from_nm(result)

@rpc("authority", "reliable")
func client_heat_phase_result(results: Array):
	"""LEGACY - Servidor envía resultados de fase de calor"""
	_on_heat_result_from_nm(results)

@rpc("authority", "reliable")
func client_battle_ended(winner_team: String, reason: String):
	"""LEGACY - Servidor indica fin de batalla"""
	_on_battle_ended_from_nm(winner_team, reason)

@rpc("authority", "reliable")
func client_action_rejected(reason: String):
	"""LEGACY - Servidor rechaza una acción"""
	_on_action_rejected_from_nm(reason)

@rpc("authority", "reliable")
func client_opponent_disconnected():
	"""LEGACY - Servidor notifica desconexión del oponente"""
	_on_opponent_disconnected_from_nm()

# ============================================================
# UTILIDADES
# ============================================================

func get_mech_by_id(mech_id: int) -> Dictionary:
	"""Obtiene datos de un mech por ID"""
	if mech_id in my_mechs:
		return my_mechs[mech_id]
	if mech_id in enemy_mechs:
		return enemy_mechs[mech_id]
	return {}

func is_my_mech(mech_id: int) -> bool:
	"""Verifica si un mech es mío"""
	return mech_id in my_mechs

func get_all_mechs() -> Dictionary:
	"""Obtiene todos los mechs"""
	var all_mechs = my_mechs.duplicate()
	all_mechs.merge(enemy_mechs)
	return all_mechs
# RPCs - STUBS para recibir desde ServerBattleManager del servidor
# Estos métodos permiten que el servidor llame RPCs a este nodo
# ============================================================

@rpc("any_peer", "reliable")
func server_request_deploy_mech(_match_id: int, _mech_data: Dictionary, _hex_pos: Array, _facing: int):
	"""Stub - este RPC es manejado por el ServerBattleManager del servidor"""
	pass

@rpc("any_peer", "reliable")
func server_request_move(_match_id: int, _mech_id: int, _target_hex: Array, _movement_type: int):
	"""Stub"""
	pass

@rpc("any_peer", "reliable")
func server_request_rotate(_match_id: int, _mech_id: int, _new_facing: int):
	"""Stub"""
	pass

@rpc("any_peer", "reliable")
func server_request_fire(_match_id: int, _attacker_id: int, _target_id: int, _weapon_indices: Array):
	"""Stub"""
	pass

@rpc("any_peer", "reliable")
func server_request_physical_attack(_match_id: int, _attacker_id: int, _target_id: int, _attack_type: String):
	"""Stub"""
	pass

@rpc("any_peer", "reliable")
func server_request_end_activation(_match_id: int, _mech_id: int):
	"""Stub"""
	pass