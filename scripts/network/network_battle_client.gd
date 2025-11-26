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
	
	# El battle_scene será el padre
	battle_scene = get_parent()

func setup(match_id: int, team: String):
	"""Configura el cliente para una partida específica"""
	current_match_id = match_id
	my_team = team
	print("[BATTLE_CLIENT] Setup for match %d as %s" % [match_id, team])

# ============================================================
# SOLICITUDES AL SERVIDOR (Cliente -> Servidor)
# ============================================================

func request_deploy_mech(mech_data: Dictionary, hex_pos: Vector2i, facing: int):
	"""Solicita desplegar un mech"""
	if current_match_id == -1:
		push_error("Not in a match!")
		return
	
	var server_battle_manager = _get_server_battle_manager()
	if server_battle_manager:
		server_battle_manager.rpc_id(1, "server_request_deploy_mech", 
			current_match_id, mech_data, [hex_pos.x, hex_pos.y], facing)

func request_move(mech_id: int, target_hex: Vector2i, movement_type: int):
	"""Solicita mover un mech"""
	var server_battle_manager = _get_server_battle_manager()
	if server_battle_manager:
		server_battle_manager.rpc_id(1, "server_request_move",
			current_match_id, mech_id, [target_hex.x, target_hex.y], movement_type)

func request_rotate(mech_id: int, new_facing: int):
	"""Solicita rotar un mech"""
	var server_battle_manager = _get_server_battle_manager()
	if server_battle_manager:
		server_battle_manager.rpc_id(1, "server_request_rotate",
			current_match_id, mech_id, new_facing)

func request_fire(attacker_id: int, target_id: int, weapon_indices: Array):
	"""Solicita disparar armas"""
	var server_battle_manager = _get_server_battle_manager()
	if server_battle_manager:
		server_battle_manager.rpc_id(1, "server_request_fire",
			current_match_id, attacker_id, target_id, weapon_indices)

func request_physical_attack(attacker_id: int, target_id: int, attack_type: String):
	"""Solicita ataque físico"""
	var server_battle_manager = _get_server_battle_manager()
	if server_battle_manager:
		server_battle_manager.rpc_id(1, "server_request_physical_attack",
			current_match_id, attacker_id, target_id, attack_type)

func request_end_activation(mech_id: int):
	"""Indica que terminó la activación de un mech"""
	var server_battle_manager = _get_server_battle_manager()
	if server_battle_manager:
		server_battle_manager.rpc_id(1, "server_request_end_activation",
			current_match_id, mech_id)

# ============================================================
# RPCs DEL SERVIDOR (Servidor -> Cliente)
# Estos métodos son llamados por el servidor
# ============================================================

@rpc("authority", "reliable")
func client_start_deployment(match_id: int, team: String):
	"""Servidor indica inicio de fase de despliegue"""
	current_match_id = match_id
	my_team = team
	print("[BATTLE_CLIENT] Deployment started - Match: %d, Team: %s" % [match_id, team])
	deployment_started.emit(match_id, team)

@rpc("authority", "reliable")
func client_mech_deployed(mech_id: int, mech_data: Dictionary, hex_pos: Array, facing: int, team: String):
	"""Servidor confirma despliegue de mech"""
	var hex = Vector2i(hex_pos[0], hex_pos[1])
	
	# Guardar localmente
	if team == my_team:
		my_mechs[mech_id] = mech_data.duplicate(true)
		my_mechs[mech_id]["hex_position"] = hex
		my_mechs[mech_id]["facing"] = facing
	else:
		enemy_mechs[mech_id] = mech_data.duplicate(true)
		enemy_mechs[mech_id]["hex_position"] = hex
		enemy_mechs[mech_id]["facing"] = facing
	
	print("[BATTLE_CLIENT] Mech deployed: %s at [%d,%d]" % [mech_data.get("name", "Unknown"), hex.x, hex.y])
	mech_deployed.emit(mech_id, mech_data, hex, facing, team)

@rpc("authority", "reliable")
func client_initiative_result(result: Dictionary):
	"""Servidor envía resultado de iniciativa"""
	print("[BATTLE_CLIENT] Initiative: Player %d vs Enemy %d -> %s wins" % [
		result["player_total"], result["enemy_total"], result["winner"]
	])
	initiative_result.emit(result)

@rpc("authority", "reliable")
func client_phase_changed(phase: String, turn: int):
	"""Servidor indica cambio de fase"""
	print("[BATTLE_CLIENT] Phase changed to: %s (Turn %d)" % [phase, turn])
	phase_changed.emit(phase, turn)

@rpc("authority", "reliable")
func client_unit_activated(mech_id: int, is_mine: bool):
	"""Servidor indica qué unidad se activa"""
	print("[BATTLE_CLIENT] Unit activated: %d (mine: %s)" % [mech_id, is_mine])
	unit_activated.emit(mech_id, is_mine)

@rpc("authority", "reliable")
func client_mech_moved(result: Dictionary):
	"""Servidor confirma movimiento"""
	var mech_id = result["mech_id"]
	var to_hex = Vector2i(result["to_hex"][0], result["to_hex"][1])
	
	# Actualizar posición local
	if mech_id in my_mechs:
		my_mechs[mech_id]["hex_position"] = to_hex
	elif mech_id in enemy_mechs:
		enemy_mechs[mech_id]["hex_position"] = to_hex
	
	print("[BATTLE_CLIENT] Mech %d moved to [%d,%d]" % [mech_id, to_hex.x, to_hex.y])
	mech_moved.emit(result)

@rpc("authority", "reliable")
func client_mech_rotated(result: Dictionary):
	"""Servidor confirma rotación"""
	var mech_id = result["mech_id"]
	var new_facing = result["new_facing"]
	
	if mech_id in my_mechs:
		my_mechs[mech_id]["facing"] = new_facing
	elif mech_id in enemy_mechs:
		enemy_mechs[mech_id]["facing"] = new_facing
	
	print("[BATTLE_CLIENT] Mech %d rotated to facing %d" % [mech_id, new_facing])
	mech_rotated.emit(result)

@rpc("authority", "reliable")
func client_weapons_fired(result: Dictionary):
	"""Servidor envía resultados de disparo"""
	print("[BATTLE_CLIENT] Weapons fired: %d results" % result["results"].size())
	
	# Actualizar estado del objetivo si fue destruido
	if result["target_destroyed"]:
		var target_id = result["target_id"]
		if target_id in my_mechs:
			my_mechs[target_id]["is_destroyed"] = true
		elif target_id in enemy_mechs:
			enemy_mechs[target_id]["is_destroyed"] = true
	
	weapons_fired.emit(result)

@rpc("authority", "reliable")
func client_physical_attack_result(result: Dictionary):
	"""Servidor envía resultado de ataque físico"""
	print("[BATTLE_CLIENT] Physical attack result: %s" % ("HIT" if result["result"]["hit"] else "MISS"))
	
	if result["target_destroyed"]:
		var target_id = result["target_id"]
		if target_id in my_mechs:
			my_mechs[target_id]["is_destroyed"] = true
		elif target_id in enemy_mechs:
			enemy_mechs[target_id]["is_destroyed"] = true
	
	physical_attack_result.emit(result)

@rpc("authority", "reliable")
func client_heat_phase_result(results: Array):
	"""Servidor envía resultados de fase de calor"""
	print("[BATTLE_CLIENT] Heat phase processed for %d mechs" % results.size())
	
	for result in results:
		var mech_id = result["mech_id"]
		if mech_id in my_mechs:
			my_mechs[mech_id]["heat"] = result["final_heat"]
			my_mechs[mech_id]["is_shutdown"] = result["shutdown"]
		elif mech_id in enemy_mechs:
			enemy_mechs[mech_id]["heat"] = result["final_heat"]
			enemy_mechs[mech_id]["is_shutdown"] = result["shutdown"]
	
	heat_phase_result.emit(results)

@rpc("authority", "reliable")
func client_battle_ended(winner_team: String, reason: String):
	"""Servidor indica fin de batalla"""
	var i_won = winner_team == my_team
	print("[BATTLE_CLIENT] Battle ended! Winner: %s (I %s)" % [winner_team, "WON" if i_won else "LOST"])
	battle_ended.emit(winner_team, reason)

@rpc("authority", "reliable")
func client_action_rejected(reason: String):
	"""Servidor rechaza una acción"""
	print("[BATTLE_CLIENT] Action rejected: %s" % reason)
	action_rejected.emit(reason)

@rpc("authority", "reliable")
func client_opponent_disconnected():
	"""Servidor notifica desconexión del oponente"""
	print("[BATTLE_CLIENT] Opponent disconnected!")
	opponent_disconnected.emit()

# ============================================================
# UTILIDADES
# ============================================================

func _get_server_battle_manager() -> Node:
	"""Obtiene referencia al ServerBattleManager para enviar RPCs"""
	# En el cliente, los RPCs se envían directamente a través del multiplayer
	# El servidor tiene el ServerBattleManager escuchando
	return self  # Los RPCs se envían desde este nodo

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
