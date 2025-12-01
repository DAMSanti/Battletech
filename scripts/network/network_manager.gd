extends Node

## NetworkManager - Singleton para gestión de red ENet
## Diseñado para servidor dedicado en DigitalOcean
## Los clientes se conectan al servidor; el servidor es autoritativo

signal connected_to_server
signal connection_failed
signal server_disconnected
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal player_registered(peer_id: int, player_name: String)
signal match_ready(player1_id: int, player2_id: int)
signal lobby_updated(players: Array)
signal api_match_found(match_data: Dictionary)
signal matchmaking_queue_joined(position: int, estimated_wait: float)
signal matchmaking_queue_left()
signal matchmaking_error(error: String)

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 32  # Múltiples partidas simultáneas

# ============================================================
# CONFIGURACIÓN DEL SERVIDOR DE PRODUCCIÓN
# ============================================================
# Servidor de producción en DigitalOcean
const PRODUCTION_SERVER_IP: String = "steeltitans.damsanti.app"
const USE_PRODUCTION_SERVER: bool = true  # Cambiar a true para usar servidor remoto

# Estados de conexión
enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	IN_LOBBY,
	IN_MATCH
}

var connection_state: ConnectionState = ConnectionState.DISCONNECTED
var is_server: bool = false
var local_player_name: String = "Player"
var server_peer_id: int = 1  # El servidor siempre es peer 1

# Datos del cliente en partida (solo válidos en cliente)
var current_match_id: int = -1
var current_team: String = ""  # "player" o "enemy"
var opponent_name: String = ""

# Mapeo de peers a datos de jugador
var connected_players: Dictionary = {}  # peer_id -> { "name": String, "team": String, "match_id": int }

# Sistema de matchmaking simple
var lobby_queue: Array = []  # peer_ids esperando partida
var active_matches: Dictionary = {}  # match_id -> { "player1": peer_id, "player2": peer_id, "state": String }
var next_match_id: int = 1

# Referencias
var multiplayer_peer: ENetMultiplayerPeer = null
var _matchmaking_client: Node = null  # MatchmakingClient para API REST
var _reconnection_manager: Node = null  # ReconnectionManager para auto-reconexión

# Señales de reconexión
signal reconnection_started()
signal reconnection_attempt(attempt: int, max_attempts: int)
signal reconnection_success()
signal reconnection_failed()
signal reconnection_cancelled()

func _ready():
	# Conectar señales del multiplayer API
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Inicializar MatchmakingClient para modo cliente
	_setup_matchmaking_client()
	
	# Inicializar ReconnectionManager
	_setup_reconnection_manager()

# ============================================================
# SERVIDOR DEDICADO
# ============================================================

func start_dedicated_server(port: int = DEFAULT_PORT) -> Error:
	"""Inicia el servidor dedicado ENet"""
	if multiplayer_peer != null:
		Log.warning("Network", "Server already running")
		return ERR_ALREADY_IN_USE
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_server(port, MAX_CLIENTS)
	
	if error != OK:
		Log.error("Network", "Failed to start server", {"error": error_string(error)})
		multiplayer_peer = null
		return error
	
	multiplayer.multiplayer_peer = multiplayer_peer
	is_server = true
	connection_state = ConnectionState.CONNECTED
	
	Log.info("Network", "Dedicated server started", {"port": port, "max_clients": MAX_CLIENTS})
	Log.info("Network", "Waiting for players...")
	return OK

func stop_server():
	"""Detiene el servidor"""
	if multiplayer_peer:
		multiplayer_peer.close()
		multiplayer_peer = null
	
	multiplayer.multiplayer_peer = null
	is_server = false
	connection_state = ConnectionState.DISCONNECTED
	connected_players.clear()
	lobby_queue.clear()
	active_matches.clear()
	
	Log.info("Network", "Server stopped")

# ============================================================
# CLIENTE
# ============================================================

func connect_to_server(address: String = "", port: int = DEFAULT_PORT, player_name: String = "Player") -> Error:
	"""Conecta un cliente al servidor dedicado"""
	# Permitir conexión si estamos desconectados o solo conectados al API REST
	# No permitir si estamos CONNECTING, IN_LOBBY, IN_MATCH, o SEARCHING
	if connection_state == ConnectionState.CONNECTING:
		Log.warning("Network", "Already connecting to server")
		return ERR_ALREADY_IN_USE
	
	if connection_state == ConnectionState.IN_LOBBY or connection_state == ConnectionState.IN_MATCH:
		Log.warning("Network", "Already in lobby or match")
		return ERR_ALREADY_IN_USE
	
	# Si hay un peer existente, cerrarlo primero
	if multiplayer_peer:
		multiplayer_peer.close()
		multiplayer_peer = null
		multiplayer.multiplayer_peer = null
	
	# Usar servidor de producción si está configurado y no se especifica dirección
	if address.is_empty() or USE_PRODUCTION_SERVER:
		address = PRODUCTION_SERVER_IP
	
	local_player_name = player_name
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_client(address, port)
	
	if error != OK:
		Log.error("Network", "Failed to connect", {"address": address, "error": error_string(error)})
		multiplayer_peer = null
		return error
	
	multiplayer.multiplayer_peer = multiplayer_peer
	is_server = false
	connection_state = ConnectionState.CONNECTING
	
	# Guardar datos para reconexión automática
	if _reconnection_manager:
		_reconnection_manager.save_connection_data(address, port, player_name)
	
	Log.info("Network", "Connecting to server", {"address": address, "port": port, "player": player_name})
	return OK

func disconnect_from_server():
	"""Desconecta del servidor"""
	if multiplayer_peer:
		multiplayer_peer.close()
		multiplayer_peer = null
	
	multiplayer.multiplayer_peer = null
	is_server = false
	connection_state = ConnectionState.DISCONNECTED
	connected_players.clear()
	
	Log.info("Network", "Disconnected from server")

# ============================================================
# MATCHMAKING (Server-side)
# ============================================================

func _add_to_lobby(peer_id: int):
	"""Añade un jugador a la cola de matchmaking"""
	if peer_id in lobby_queue:
		return
	
	lobby_queue.append(peer_id)
	connected_players[peer_id]["state"] = "lobby"
	
	Log.info("Match", "Player added to lobby", {"peer_id": peer_id, "queue_size": lobby_queue.size()})
	
	# Notificar a todos los clientes del estado del lobby
	_broadcast_lobby_state()
	
	# Intentar emparejar
	_try_matchmake()

func _try_matchmake():
	"""Intenta emparejar jugadores en la cola"""
	while lobby_queue.size() >= 2:
		var player1_id = lobby_queue.pop_front()
		var player2_id = lobby_queue.pop_front()
		
		# Verificar que ambos siguen conectados
		if player1_id not in connected_players or player2_id not in connected_players:
			# Devolver el válido a la cola
			if player1_id in connected_players:
				lobby_queue.push_front(player1_id)
			if player2_id in connected_players:
				lobby_queue.push_front(player2_id)
			continue
		
		# Crear partida
		var match_id = next_match_id
		next_match_id += 1
		
		active_matches[match_id] = {
			"player1": player1_id,
			"player2": player2_id,
			"state": "starting",
			"turn": 0,
			"phase": "deployment"
		}
		
		connected_players[player1_id]["match_id"] = match_id
		connected_players[player1_id]["team"] = "player"
		connected_players[player1_id]["state"] = "in_match"
		
		connected_players[player2_id]["match_id"] = match_id
		connected_players[player2_id]["team"] = "enemy"
		connected_players[player2_id]["state"] = "in_match"
		
		# Generar semilla del mapa compartida
		var map_seed = randi()
		active_matches[match_id]["map_seed"] = map_seed
		
		Log.match_event("Match created", str(match_id), connected_players[player1_id]["name"], connected_players[player2_id]["name"])
		Log.debug("Match", "Match details", {"seed": map_seed, "p1_peer": player1_id, "p2_peer": player2_id})
		
		# Notificar a ambos jugadores con la semilla del mapa
		rpc_id(player1_id, "client_match_found", match_id, "player", connected_players[player2_id]["name"], map_seed)
		rpc_id(player2_id, "client_match_found", match_id, "enemy", connected_players[player1_id]["name"], map_seed)
		
		match_ready.emit(player1_id, player2_id)

func _broadcast_lobby_state():
	"""Envía el estado del lobby a todos los jugadores en cola"""
	var lobby_info = []
	for peer_id in lobby_queue:
		if peer_id in connected_players:
			lobby_info.append({
				"id": peer_id,
				"name": connected_players[peer_id]["name"]
			})
	
	# Enviar a todos los que están en lobby
	for peer_id in lobby_queue:
		rpc_id(peer_id, "client_lobby_update", lobby_info)
	
	lobby_updated.emit(lobby_info)

func get_match_for_peer(peer_id: int) -> Dictionary:
	"""Obtiene los datos de la partida de un peer"""
	if peer_id not in connected_players:
		return {}
	
	var match_id = connected_players[peer_id].get("match_id", -1)
	if match_id == -1 or match_id not in active_matches:
		return {}
	
	return active_matches[match_id]

func get_opponent_peer_id(peer_id: int) -> int:
	"""Obtiene el peer_id del oponente"""
	var match_data = get_match_for_peer(peer_id)
	if match_data.is_empty():
		return -1
	
	if match_data["player1"] == peer_id:
		return match_data["player2"]
	return match_data["player1"]

func get_team_for_peer(peer_id: int) -> String:
	"""Obtiene el equipo asignado a un peer"""
	if peer_id not in connected_players:
		return ""
	return connected_players[peer_id].get("team", "")

# ============================================================
# RPCs - Cliente -> Servidor
# ============================================================

@rpc("any_peer", "reliable")
func server_register_player(player_name: String):
	"""Cliente se registra con su nombre"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	if sender_id in connected_players:
		connected_players[sender_id]["name"] = player_name
	else:
		connected_players[sender_id] = {
			"name": player_name,
			"team": "",
			"match_id": -1,
			"state": "connected"
		}
	
	Log.network("Player registered: %s" % player_name, sender_id)
	player_registered.emit(sender_id, player_name)
	
	# Confirmar registro al cliente
	rpc_id(sender_id, "client_registration_confirmed", sender_id)

@rpc("any_peer", "reliable")
func server_join_lobby():
	"""Cliente solicita unirse al lobby de matchmaking"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	if sender_id not in connected_players:
		Log.warning("Network", "Unregistered player trying to join lobby", {"peer_id": sender_id})
		return
	
	_add_to_lobby(sender_id)

@rpc("any_peer", "reliable")
func server_leave_lobby():
	"""Cliente abandona el lobby"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	if sender_id in lobby_queue:
		lobby_queue.erase(sender_id)
		if sender_id in connected_players:
			connected_players[sender_id]["state"] = "connected"
		_broadcast_lobby_state()
		Log.info("Match", "Player left lobby", {"peer_id": sender_id})

# ============================================================
# RPCs - Servidor -> Cliente
# ============================================================

@rpc("authority", "reliable")
func client_registration_confirmed(my_peer_id: int):
	"""Servidor confirma el registro del cliente"""
	connection_state = ConnectionState.CONNECTED
	Log.info("Network", "Registration confirmed", {"peer_id": my_peer_id})

@rpc("authority", "reliable")
func client_lobby_update(lobby_info: Array):
	"""Servidor envía actualización del lobby"""
	connection_state = ConnectionState.IN_LOBBY
	lobby_updated.emit(lobby_info)

@rpc("authority", "reliable")
func client_match_found(p_match_id: int, p_team: String, p_opponent_name: String, p_map_seed: int):
	"""Servidor notifica que se encontró partida"""
	connection_state = ConnectionState.IN_MATCH
	current_match_id = p_match_id
	current_team = p_team
	opponent_name = p_opponent_name
	current_map_seed = p_map_seed  # Guardar semilla para hex_grid
	
	# Guardar datos para reconexión automática
	if _reconnection_manager:
		_reconnection_manager.save_match_data(p_match_id, p_team)
	
	Log.match_event("Match found!", str(p_match_id), local_player_name, p_opponent_name)
	Log.info("Match", "Match details", {"team": p_team, "map_seed": p_map_seed})
	match_ready.emit(p_match_id, p_team)

# ============================================================
# CALLBACKS DE CONEXIÓN
# ============================================================

func _on_peer_connected(peer_id: int):
	Log.network("Peer connected", peer_id)
	
	if is_server:
		# Servidor: nuevo cliente conectado
		connected_players[peer_id] = {
			"name": "Player_%d" % peer_id,
			"team": "",
			"match_id": -1,
			"state": "connected"
		}
	
	peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int):
	Log.network("Peer disconnected", peer_id)
	
	if is_server:
		# Limpiar datos del jugador
		if peer_id in lobby_queue:
			lobby_queue.erase(peer_id)
			_broadcast_lobby_state()
		
		# Manejar desconexión en partida activa
		if peer_id in connected_players:
			var match_id = connected_players[peer_id].get("match_id", -1)
			if match_id != -1 and match_id in active_matches:
				var match_data = active_matches[match_id]
				var opponent_id = match_data["player1"] if match_data["player2"] == peer_id else match_data["player2"]
				
				# Notificar al oponente
				if opponent_id in connected_players:
					rpc_id(opponent_id, "client_opponent_disconnected")
				
				# Limpiar partida
				Log.info("Match", "Match ended due to disconnect", {"match_id": match_id})
				active_matches.erase(match_id)
			
			connected_players.erase(peer_id)
	
	peer_disconnected.emit(peer_id)

func _on_connected_to_server():
	Log.info("Network", "Connected to server!")
	connection_state = ConnectionState.CONNECTED
	
	# Registrarse automáticamente
	rpc_id(server_peer_id, "server_register_player", local_player_name)
	
	connected_to_server.emit()
	
	# Auto-unirse al lobby después de conectar
	await get_tree().create_timer(0.5).timeout
	if connection_state == ConnectionState.CONNECTED:
		rpc_id(server_peer_id, "server_join_lobby")

func _on_connection_failed():
	Log.error("Network", "Connection failed!")
	connection_state = ConnectionState.DISCONNECTED
	multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected():
	Log.warning("Network", "Server disconnected!")
	connection_state = ConnectionState.DISCONNECTED
	multiplayer_peer = null
	server_disconnected.emit()

@rpc("authority", "reliable")
func client_opponent_disconnected():
	"""Servidor notifica que el oponente se desconectó"""
	Log.warning("Match", "Opponent disconnected!")
	battle_opponent_disconnected.emit()

# ============================================================
# BATTLE RPCS - Servidor -> Cliente
# Estos RPCs son llamados por el ServerBattleManager y recibidos aquí
# Luego se reenvían a través de señales al NetworkBattleClient
# ============================================================

signal battle_deployment_started(match_id: int, team: String)
signal battle_mech_deployed(mech_id: int, mech_data: Dictionary, hex_pos: Array, facing: int, team: String)
signal battle_initiative_result(result: Dictionary)
signal battle_phase_changed(phase: String, turn: int)
signal battle_unit_activated(mech_id: int, is_mine: bool)
signal battle_mech_moved(result: Dictionary)
signal battle_mech_rotated(result: Dictionary)
signal battle_weapons_fired(result: Dictionary)
signal battle_physical_result(result: Dictionary)
signal battle_heat_result(results: Array)
signal battle_ended(winner_team: String, reason: String)
signal battle_action_rejected(reason: String)
signal battle_opponent_disconnected()
signal initiative_waiting_update(players_ready: int, players_total: int, wait_type: String)

# Variable para guardar la semilla del mapa (usada por hex_grid)
var current_map_seed: int = 0

@rpc("authority", "reliable")
func client_start_deployment(match_id: int, team: String, map_seed: int):
	"""Servidor indica inicio de fase de despliegue con semilla del mapa"""
	Log.info("Match", "Deployment started", {"match_id": match_id, "team": team, "map_seed": map_seed})
	current_map_seed = map_seed
	battle_deployment_started.emit(match_id, team)

@rpc("authority", "reliable")
func client_mech_deployed(mech_id: int, mech_data: Dictionary, hex_pos: Array, facing: int, team: String):
	"""Servidor confirma despliegue de mech"""
	Log.debug("Mech", "Mech deployed", {"mech": mech_data.get("name", "Unknown"), "pos": hex_pos, "team": team})
	battle_mech_deployed.emit(mech_id, mech_data, hex_pos, facing, team)

@rpc("authority", "reliable")
func client_initiative_result(result: Dictionary):
	"""Servidor envía resultado de iniciativa"""
	Log.debug("Combat", "Initiative result received")
	battle_initiative_result.emit(result)

@rpc("authority", "reliable")
func client_phase_changed(phase: String, turn: int):
	"""Servidor indica cambio de fase"""
	Log.info("Match", "Phase changed", {"phase": phase, "turn": turn})
	battle_phase_changed.emit(phase, turn)

@rpc("authority", "reliable")
func client_unit_activated(mech_id: int, is_mine: bool):
	"""Servidor indica qué unidad se activa"""
	Log.debug("Combat", "Unit activated", {"mech_id": mech_id, "is_mine": is_mine})
	battle_unit_activated.emit(mech_id, is_mine)

@rpc("authority", "reliable")
func client_mech_moved(result: Dictionary):
	"""Servidor confirma movimiento"""
	Log.debug("Movement", "Mech moved")
	battle_mech_moved.emit(result)

@rpc("authority", "reliable")
func client_mech_rotated(result: Dictionary):
	"""Servidor confirma rotación"""
	Log.debug("Movement", "Mech rotated")
	battle_mech_rotated.emit(result)

@rpc("authority", "reliable")
func client_weapons_fired(result: Dictionary):
	"""Servidor envía resultados de disparo"""
	Log.debug("Combat", "Weapons fired")
	battle_weapons_fired.emit(result)

@rpc("authority", "reliable")
func client_physical_attack_result(result: Dictionary):
	"""Servidor envía resultado de ataque físico"""
	Log.debug("Combat", "Physical attack result")
	battle_physical_result.emit(result)

@rpc("authority", "reliable")
func client_heat_phase_result(results: Array):
	"""Servidor envía resultados de fase de calor"""
	Log.debug("Heat", "Heat phase result")
	battle_heat_result.emit(results)

@rpc("authority", "reliable")
func client_battle_ended(winner_team: String, reason: String):
	"""Servidor indica fin de batalla"""
	Log.info("Match", "Battle ended", {"winner": winner_team, "reason": reason})
	battle_ended.emit(winner_team, reason)

@rpc("authority", "reliable")
func client_action_rejected(reason: String):
	"""Servidor rechaza una acción"""
	Log.warning("Combat", "Action rejected", {"reason": reason})
	battle_action_rejected.emit(reason)

# ============================================================
# BATTLE RPCS - Cliente -> Servidor (para forwarding al ServerBattleManager)
# ============================================================

@rpc("any_peer", "reliable")
func server_request_deploy_mech(match_id: int, mech_data: Dictionary, hex_pos: Array, facing: int):
	"""Cliente solicita desplegar un mech - forwarded al ServerBattleManager"""
	if not is_server:
		return
	var server_battle = get_node_or_null("/root/ServerMain/ServerBattleManager")
	if server_battle and server_battle.has_method("server_request_deploy_mech"):
		# Re-llamar el método como si fuera el sender original
		var sender = multiplayer.get_remote_sender_id()
		server_battle._handle_deploy_request(sender, match_id, mech_data, hex_pos, facing)

@rpc("any_peer", "reliable")
func server_request_move(match_id: int, mech_id: int, target_hex: Array, movement_type: int):
	"""Cliente solicita mover un mech"""
	if not is_server:
		return
	var server_battle = get_node_or_null("/root/ServerMain/ServerBattleManager")
	if server_battle:
		var sender = multiplayer.get_remote_sender_id()
		server_battle._handle_move_request(sender, match_id, mech_id, target_hex, movement_type)

@rpc("any_peer", "reliable")
func server_request_rotate(match_id: int, mech_id: int, new_facing: int):
	"""Cliente solicita rotar un mech"""
	if not is_server:
		return
	var server_battle = get_node_or_null("/root/ServerMain/ServerBattleManager")
	if server_battle:
		var sender = multiplayer.get_remote_sender_id()
		server_battle._handle_rotate_request(sender, match_id, mech_id, new_facing)

@rpc("any_peer", "reliable")
func server_request_fire(match_id: int, attacker_id: int, target_id: int, weapon_indices: Array):
	"""Cliente solicita disparar armas"""
	if not is_server:
		return
	var server_battle = get_node_or_null("/root/ServerMain/ServerBattleManager")
	if server_battle:
		var sender = multiplayer.get_remote_sender_id()
		server_battle._handle_fire_request(sender, match_id, attacker_id, target_id, weapon_indices)

@rpc("any_peer", "reliable")
func server_request_physical_attack(match_id: int, attacker_id: int, target_id: int, attack_type: String):
	"""Cliente solicita ataque físico"""
	if not is_server:
		return
	var server_battle = get_node_or_null("/root/ServerMain/ServerBattleManager")
	if server_battle:
		var sender = multiplayer.get_remote_sender_id()
		server_battle._handle_physical_request(sender, match_id, attacker_id, target_id, attack_type)

@rpc("any_peer", "reliable")
func server_request_end_activation(match_id: int, mech_id: int):
	"""Cliente indica fin de activación"""
	if not is_server:
		return
	var server_battle = get_node_or_null("/root/ServerMain/ServerBattleManager")
	if server_battle:
		var sender = multiplayer.get_remote_sender_id()
		server_battle._handle_end_activation(sender, match_id, mech_id)

@rpc("any_peer", "reliable")
func server_deployment_complete(match_id: int):
	"""Cliente indica que terminó de desplegar todos sus mechs"""
	if not is_server:
		return
	var server_battle = get_node_or_null("/root/ServerMain/ServerBattleManager")
	if server_battle:
		var sender = multiplayer.get_remote_sender_id()
		server_battle._handle_deployment_complete(sender, match_id)

@rpc("any_peer", "reliable")
func server_client_ready(match_id: int):
	"""Cliente notifica que está listo en la escena de batalla"""
	if not is_server:
		return
	var server_battle = get_node_or_null("/root/ServerMain/ServerBattleManager")
	if server_battle:
		var sender = multiplayer.get_remote_sender_id()
		server_battle._handle_client_ready(sender, match_id)

@rpc("any_peer", "reliable")
func server_initiative_roll_ready(match_id: int):
	"""Cliente notifica que presionó Roll Dice"""
	if not is_server:
		return
	var server_battle = get_node_or_null("/root/ServerMain/ServerBattleManager")
	if server_battle:
		var sender = multiplayer.get_remote_sender_id()
		server_battle._handle_initiative_roll_ready(sender, match_id)

@rpc("any_peer", "reliable")
func server_start_battle_ready(match_id: int):
	"""Cliente notifica que presionó Start Battle"""
	if not is_server:
		return
	var server_battle = get_node_or_null("/root/ServerMain/ServerBattleManager")
	if server_battle:
		var sender = multiplayer.get_remote_sender_id()
		server_battle._handle_start_battle_ready(sender, match_id)

@rpc("authority", "reliable")
func client_waiting_for_rolls(players_ready: int, players_total: int):
	"""Servidor notifica cuántos jugadores han dado a Roll"""
	initiative_waiting_update.emit(players_ready, players_total, "roll")

@rpc("authority", "reliable")
func client_waiting_for_start(players_ready: int, players_total: int):
	"""Servidor notifica cuántos jugadores han dado a Start"""
	initiative_waiting_update.emit(players_ready, players_total, "start")

# Señal para notificar que ambos jugadores desplegaron
signal battle_all_deployed()

@rpc("authority", "reliable")
func client_all_deployed():
	"""Servidor notifica que ambos jugadores terminaron de desplegar"""
	Log.info("Match", "Both players deployed!")
	battle_all_deployed.emit()

# ============================================================
# CHAT MULTIPLAYER
# ============================================================

signal chat_message_received(sender_name: String, message: String)

@rpc("any_peer", "reliable")
func server_send_chat(match_id: int, message: String):
	"""Cliente envía mensaje de chat al servidor"""
	if not is_server:
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id not in connected_players:
		return
	
	var sender_name = connected_players[sender_id].get("name", "Unknown")
	var player_match_id = connected_players[sender_id].get("match_id", -1)
	
	# Verificar que el mensaje es para la partida correcta
	if player_match_id != match_id or match_id not in active_matches:
		return
	
	var match_data = active_matches[match_id]
	
	# Reenviar al oponente
	var opponent_id = match_data["player1"] if match_data["player2"] == sender_id else match_data["player2"]
	if opponent_id in connected_players:
		rpc_id(opponent_id, "client_chat_message", sender_name, message)
	
	Log.debug("Network", "Chat message", {"from": sender_name, "length": message.length()})

@rpc("authority", "reliable")
func client_chat_message(sender_name: String, message: String):
	"""Servidor reenvía mensaje de chat al cliente"""
	Log.debug("Network", "Chat received", {"from": sender_name})
	chat_message_received.emit(sender_name, message)

func send_chat_message(message: String):
	"""Envía un mensaje de chat al servidor para reenviar al oponente"""
	if not is_in_match():
		return
	rpc_id(1, "server_send_chat", current_match_id, message)

func get_local_player_name() -> String:
	"""Obtiene el nombre del jugador local"""
	return local_player_name

# ============================================================
# UTILIDADES
# ============================================================

func get_my_peer_id() -> int:
	"""Obtiene el peer ID local"""
	if multiplayer_peer:
		return multiplayer.get_unique_id()
	return 0

func is_connected_to_server() -> bool:
	return connection_state >= ConnectionState.CONNECTED

func is_in_match() -> bool:
	return connection_state == ConnectionState.IN_MATCH

func get_current_match_id() -> int:
	"""Obtiene el ID de la partida actual (solo cliente)"""
	return current_match_id

func get_current_team() -> String:
	"""Obtiene el equipo asignado al cliente"""
	return current_team

func get_opponent_name() -> String:
	"""Obtiene el nombre del oponente"""
	return opponent_name

func get_player_count() -> int:
	return connected_players.size()

func get_active_match_count() -> int:
	return active_matches.size()


# ============================================================
# MATCHMAKING API (Cliente)
# ============================================================

func _setup_matchmaking_client() -> void:
	"""Configura el cliente de matchmaking API"""
	# Solo en cliente, no en servidor headless
	if OS.has_feature("dedicated_server"):
		return
	
	var MatchmakingClientClass = load("res://scripts/network/matchmaking_client.gd")
	if MatchmakingClientClass:
		_matchmaking_client = MatchmakingClientClass.new()
		_matchmaking_client.name = "MatchmakingClient"
		add_child(_matchmaking_client)
		
		# Conectar señales
		_matchmaking_client.queue_joined.connect(_on_api_queue_joined)
		_matchmaking_client.queue_left.connect(_on_api_queue_left)
		_matchmaking_client.match_found.connect(_on_api_match_found)
		_matchmaking_client.queue_timeout.connect(_on_api_queue_timeout)
		_matchmaking_client.matchmaking_error.connect(_on_api_matchmaking_error)
		
		Log.info("Network", "MatchmakingClient initialized")


func set_api_auth_token(token: String) -> void:
	"""Establece el token de autenticación para la API de matchmaking"""
	if _matchmaking_client:
		_matchmaking_client.set_auth_token(token)
		Log.debug("Network", "API auth token set")


func join_matchmaking_queue(game_mode: int = 0) -> void:
	"""Une al jugador a la cola de matchmaking via API
	game_mode: 0=RANKED_1V1, 1=RANKED_2V2, 2=CASUAL_1V1, 3=CASUAL_2V2
	"""
	if _matchmaking_client:
		_matchmaking_client.join_queue(game_mode)
		connection_state = ConnectionState.IN_LOBBY
	else:
		Log.error("Network", "MatchmakingClient not available")
		matchmaking_error.emit("Matchmaking not available")


func leave_matchmaking_queue() -> void:
	"""Abandona la cola de matchmaking API"""
	if _matchmaking_client:
		_matchmaking_client.leave_queue()
		connection_state = ConnectionState.CONNECTED


func is_in_matchmaking_queue() -> bool:
	"""Verifica si está en cola de matchmaking"""
	if _matchmaking_client:
		return _matchmaking_client.is_queued()
	return false


func get_matchmaking_time() -> float:
	"""Devuelve el tiempo en cola de matchmaking"""
	if _matchmaking_client:
		return _matchmaking_client.get_time_in_queue()
	return 0.0


func get_api_match_data() -> Dictionary:
	"""Obtiene los datos de la partida encontrada via API"""
	if _matchmaking_client:
		return _matchmaking_client.get_match_data()
	return {}


func connect_to_matched_game() -> Error:
	"""Conecta al servidor de juego después de encontrar partida via API"""
	if not _matchmaking_client:
		return ERR_UNCONFIGURED
	
	var match_data = _matchmaking_client.get_match_data()
	if match_data.is_empty():
		return ERR_INVALID_DATA
	
	# Guardar datos de la partida
	opponent_name = match_data.get("opponent_name", "Unknown")
	current_team = match_data.get("team", "player")
	
	# Cambiar estado a CONNECTED para permitir conexión ENet
	# (estábamos en IN_LOBBY por la cola de matchmaking)
	connection_state = ConnectionState.CONNECTED
	
	# Conectar via ENet
	return _matchmaking_client.connect_to_game_server()


# Callbacks de MatchmakingClient
func _on_api_queue_joined(position: int, estimated_wait: float) -> void:
	Log.info("Network", "Joined matchmaking queue", {
		"position": position,
		"estimated_wait": estimated_wait
	})
	matchmaking_queue_joined.emit(position, estimated_wait)


func _on_api_queue_left() -> void:
	Log.info("Network", "Left matchmaking queue")
	matchmaking_queue_left.emit()


func _on_api_match_found(match_data: Dictionary) -> void:
	Log.info("Network", "Match found via API!", {
		"opponent": match_data.get("opponent_name", "Unknown"),
		"match_id": match_data.get("match_id", "")
	})
	api_match_found.emit(match_data)


func _on_api_queue_timeout() -> void:
	Log.warning("Network", "Matchmaking queue timeout")
	connection_state = ConnectionState.CONNECTED
	matchmaking_error.emit("Queue timeout - no opponents found")


func _on_api_matchmaking_error(error: String) -> void:
	Log.error("Network", "Matchmaking error", {"error": error})
	matchmaking_error.emit(error)


# ============================================================
# RECONNECTION SYSTEM
# ============================================================

func _setup_reconnection_manager() -> void:
	"""Configura el manager de reconexión automática"""
	# Solo en cliente, no en servidor headless
	if OS.has_feature("dedicated_server"):
		return
	
	var ReconnectionManagerClass = load("res://scripts/network/reconnection_manager.gd")
	if ReconnectionManagerClass:
		_reconnection_manager = ReconnectionManagerClass.new()
		_reconnection_manager.name = "ReconnectionManager"
		add_child(_reconnection_manager)
		
		# Inicializar con referencia a este NetworkManager
		_reconnection_manager.initialize(self)
		
		# Conectar señales
		_reconnection_manager.reconnection_started.connect(_on_reconnection_started)
		_reconnection_manager.reconnection_attempt.connect(_on_reconnection_attempt)
		_reconnection_manager.reconnection_success.connect(_on_reconnection_success)
		_reconnection_manager.reconnection_failed.connect(_on_reconnection_failed)
		_reconnection_manager.reconnection_cancelled.connect(_on_reconnection_cancelled)
		
		Log.info("Network", "ReconnectionManager initialized")


func enable_auto_reconnection(enabled: bool = true) -> void:
	"""Habilita o deshabilita la reconexión automática"""
	if _reconnection_manager:
		if enabled:
			# Las señales ya están conectadas, el manager actuará automáticamente
			Log.info("Network", "Auto-reconnection enabled")
		else:
			# Cancelar si está en proceso
			if _reconnection_manager.is_reconnecting():
				_reconnection_manager.cancel_reconnection()
			Log.info("Network", "Auto-reconnection disabled")


func configure_reconnection(
	max_attempts: int = 5,
	initial_delay: float = 1.0,
	max_delay: float = 30.0,
	backoff_multiplier: float = 2.0
) -> void:
	"""Configura los parámetros de reconexión"""
	if _reconnection_manager:
		_reconnection_manager.configure(max_attempts, initial_delay, max_delay, backoff_multiplier)


func start_reconnection() -> void:
	"""Inicia manualmente el proceso de reconexión"""
	if _reconnection_manager:
		_reconnection_manager.start_reconnection()


func cancel_reconnection() -> void:
	"""Cancela el proceso de reconexión"""
	if _reconnection_manager:
		_reconnection_manager.cancel_reconnection()


func is_reconnecting() -> bool:
	"""Retorna si está en proceso de reconexión"""
	if _reconnection_manager:
		return _reconnection_manager.is_reconnecting()
	return false


func get_reconnection_progress() -> Dictionary:
	"""Obtiene el progreso de la reconexión"""
	if not _reconnection_manager:
		return {"current": 0, "max": 0, "time_until_next": 0.0}
	
	return {
		"current": _reconnection_manager.get_current_attempt(),
		"max": _reconnection_manager.get_max_attempts(),
		"time_until_next": _reconnection_manager.get_time_until_next_attempt(),
		"was_in_match": _reconnection_manager.was_in_match()
	}


func request_match_rejoin(match_id: int) -> void:
	"""Solicita reconectarse a una partida en curso"""
	if not is_server and connection_state == ConnectionState.CONNECTED:
		Log.info("Network", "Requesting match rejoin", {"match_id": match_id})
		rpc_id(server_peer_id, "server_request_rejoin", match_id)


# Callbacks de ReconnectionManager
func _on_reconnection_started() -> void:
	Log.info("Network", "Reconnection process started")
	reconnection_started.emit()


func _on_reconnection_attempt(attempt: int, max_attempts: int) -> void:
	Log.info("Network", "Reconnection attempt", {
		"attempt": attempt,
		"max": max_attempts
	})
	reconnection_attempt.emit(attempt, max_attempts)


func _on_reconnection_success() -> void:
	Log.info("Network", "Reconnection successful!")
	reconnection_success.emit()


func _on_reconnection_failed() -> void:
	Log.error("Network", "Reconnection failed after all attempts")
	reconnection_failed.emit()


func _on_reconnection_cancelled() -> void:
	Log.info("Network", "Reconnection cancelled")
	reconnection_cancelled.emit()


# RPC del servidor para manejar reconexión a partidas
@rpc("any_peer", "reliable")
func server_request_rejoin(match_id: int) -> void:
	"""[Server] Cliente solicita reconectarse a una partida"""
	if not is_server:
		return
	
	var peer_id = multiplayer.get_remote_sender_id()
	Log.info("Network", "Rejoin request received", {
		"peer_id": peer_id,
		"match_id": match_id
	})
	
	# Verificar si la partida existe y está activa
	if match_id not in active_matches:
		rpc_id(peer_id, "client_rejoin_failed", "Match not found or already ended")
		return
	
	var match_data = active_matches[match_id]
	
	# Verificar si el jugador era parte de esta partida
	# Esto requiere que guardemos los datos del jugador incluso después de desconexión
	var player_name = ""
	if peer_id in connected_players:
		player_name = connected_players[peer_id].get("name", "")
	
	# Buscar si este jugador estaba en la partida (por nombre)
	var original_peer_id = -1
	var team = ""
	
	# Por ahora, permitimos reconexión si hay un slot vacío en la partida
	var p1_id = match_data.get("player1", -1)
	var p2_id = match_data.get("player2", -1)
	
	# Verificar si alguno de los jugadores se desconectó
	if p1_id not in connected_players or multiplayer.get_peers().find(p1_id) == -1:
		original_peer_id = p1_id
		team = "player"
	elif p2_id not in connected_players or multiplayer.get_peers().find(p2_id) == -1:
		original_peer_id = p2_id
		team = "enemy"
	
	if original_peer_id == -1:
		rpc_id(peer_id, "client_rejoin_failed", "No available slot in match")
		return
	
	# Reasignar el jugador
	if team == "player":
		match_data["player1"] = peer_id
	else:
		match_data["player2"] = peer_id
	
	# Actualizar datos del jugador
	if peer_id not in connected_players:
		connected_players[peer_id] = {"name": player_name, "state": "connected"}
	
	connected_players[peer_id]["match_id"] = match_id
	connected_players[peer_id]["team"] = team
	connected_players[peer_id]["state"] = "in_match"
	
	# Obtener nombre del oponente
	var opponent_id = match_data["player1"] if team == "enemy" else match_data["player2"]
	var opponent_name_str = "Unknown"
	if opponent_id in connected_players:
		opponent_name_str = connected_players[opponent_id].get("name", "Unknown")
	
	Log.info("Network", "Player rejoined match", {
		"peer_id": peer_id,
		"match_id": match_id,
		"team": team
	})
	
	# Enviar confirmación con datos del estado actual de la partida
	rpc_id(peer_id, "client_rejoin_success", match_id, team, opponent_name_str, match_data.get("map_seed", 0))
	
	# Notificar al oponente
	if opponent_id in connected_players and multiplayer.get_peers().find(opponent_id) != -1:
		rpc_id(opponent_id, "client_opponent_reconnected", player_name)


@rpc("authority", "reliable")
func client_rejoin_success(match_id: int, team: String, opponent: String, map_seed: int) -> void:
	"""[Client] Servidor confirma reconexión exitosa a partida"""
	Log.info("Network", "Rejoin successful!", {
		"match_id": match_id,
		"team": team,
		"opponent": opponent
	})
	
	current_match_id = match_id
	current_team = team
	opponent_name = opponent
	current_map_seed = map_seed
	connection_state = ConnectionState.IN_MATCH
	
	# TODO: Sincronizar estado del juego


@rpc("authority", "reliable")
func client_rejoin_failed(reason: String) -> void:
	"""[Client] Servidor rechaza reconexión a partida"""
	Log.warning("Network", "Rejoin failed", {"reason": reason})
	# Volver al lobby
	connection_state = ConnectionState.CONNECTED


@rpc("authority", "reliable")
func client_opponent_reconnected(opponent_name_str: String) -> void:
	"""[Client] Servidor notifica que el oponente se reconectó"""
	Log.info("Network", "Opponent reconnected!", {"opponent": opponent_name_str})
	# TODO: Emitir señal para actualizar UI
