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

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 32  # Múltiples partidas simultáneas

# ============================================================
# CONFIGURACIÓN DEL SERVIDOR DE PRODUCCIÓN
# ============================================================
# Cambia esta IP por la de tu Droplet en DigitalOcean
const PRODUCTION_SERVER_IP: String = "159.65.94.179"
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

func _ready():
	# Conectar señales del multiplayer API
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ============================================================
# SERVIDOR DEDICADO
# ============================================================

func start_dedicated_server(port: int = DEFAULT_PORT) -> Error:
	"""Inicia el servidor dedicado ENet"""
	if multiplayer_peer != null:
		push_warning("Server already running")
		return ERR_ALREADY_IN_USE
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_server(port, MAX_CLIENTS)
	
	if error != OK:
		push_error("Failed to start server: %s" % error_string(error))
		multiplayer_peer = null
		return error
	
	multiplayer.multiplayer_peer = multiplayer_peer
	is_server = true
	connection_state = ConnectionState.CONNECTED
	
	print("[SERVER] Dedicated server started on port %d" % port)
	print("[SERVER] Waiting for players...")
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
	
	print("[SERVER] Server stopped")

# ============================================================
# CLIENTE
# ============================================================

func connect_to_server(address: String = "", port: int = DEFAULT_PORT, player_name: String = "Player") -> Error:
	"""Conecta un cliente al servidor dedicado"""
	if connection_state != ConnectionState.DISCONNECTED:
		push_warning("Already connected or connecting")
		return ERR_ALREADY_IN_USE
	
	# Usar servidor de producción si está configurado y no se especifica dirección
	if address.is_empty() or USE_PRODUCTION_SERVER:
		address = PRODUCTION_SERVER_IP
	
	local_player_name = player_name
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_client(address, port)
	
	if error != OK:
		push_error("Failed to connect: %s" % error_string(error))
		multiplayer_peer = null
		return error
	
	multiplayer.multiplayer_peer = multiplayer_peer
	is_server = false
	connection_state = ConnectionState.CONNECTING
	
	print("[CLIENT] Connecting to %s:%d as '%s'..." % [address, port, player_name])
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
	
	print("[CLIENT] Disconnected from server")

# ============================================================
# MATCHMAKING (Server-side)
# ============================================================

func _add_to_lobby(peer_id: int):
	"""Añade un jugador a la cola de matchmaking"""
	if peer_id in lobby_queue:
		return
	
	lobby_queue.append(peer_id)
	connected_players[peer_id]["state"] = "lobby"
	
	print("[SERVER] Player %d added to lobby. Queue size: %d" % [peer_id, lobby_queue.size()])
	
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
		
		print("[SERVER] Match %d created: Player %d vs Player %d (seed: %d)" % [match_id, player1_id, player2_id, map_seed])
		
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
	
	print("[SERVER] Player registered: %d -> '%s'" % [sender_id, player_name])
	player_registered.emit(sender_id, player_name)
	
	# Confirmar registro al cliente
	rpc_id(sender_id, "client_registration_confirmed", sender_id)

@rpc("any_peer", "reliable")
func server_join_lobby():
	"""Cliente solicita unirse al lobby de matchmaking"""
	var sender_id = multiplayer.get_remote_sender_id()
	
	if sender_id not in connected_players:
		push_warning("Unregistered player trying to join lobby: %d" % sender_id)
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
		print("[SERVER] Player %d left lobby" % sender_id)

# ============================================================
# RPCs - Servidor -> Cliente
# ============================================================

@rpc("authority", "reliable")
func client_registration_confirmed(my_peer_id: int):
	"""Servidor confirma el registro del cliente"""
	connection_state = ConnectionState.CONNECTED
	print("[CLIENT] Registration confirmed. My peer ID: %d" % my_peer_id)

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
	print("[CLIENT] Match found! ID: %d, Team: %s, Opponent: %s, MapSeed: %d" % [p_match_id, p_team, p_opponent_name, p_map_seed])
	match_ready.emit(p_match_id, p_team)

# ============================================================
# CALLBACKS DE CONEXIÓN
# ============================================================

func _on_peer_connected(peer_id: int):
	print("[NET] Peer connected: %d" % peer_id)
	
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
	print("[NET] Peer disconnected: %d" % peer_id)
	
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
				active_matches.erase(match_id)
			
			connected_players.erase(peer_id)
	
	peer_disconnected.emit(peer_id)

func _on_connected_to_server():
	print("[CLIENT] Connected to server!")
	connection_state = ConnectionState.CONNECTED
	
	# Registrarse automáticamente
	rpc_id(server_peer_id, "server_register_player", local_player_name)
	
	connected_to_server.emit()
	
	# Auto-unirse al lobby después de conectar
	await get_tree().create_timer(0.5).timeout
	if connection_state == ConnectionState.CONNECTED:
		rpc_id(server_peer_id, "server_join_lobby")

func _on_connection_failed():
	print("[CLIENT] Connection failed!")
	connection_state = ConnectionState.DISCONNECTED
	multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected():
	print("[CLIENT] Server disconnected!")
	connection_state = ConnectionState.DISCONNECTED
	multiplayer_peer = null
	server_disconnected.emit()

@rpc("authority", "reliable")
func client_opponent_disconnected():
	"""Servidor notifica que el oponente se desconectó"""
	print("[CLIENT] Opponent disconnected!")
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

# Variable para guardar la semilla del mapa (usada por hex_grid)
var current_map_seed: int = 0

@rpc("authority", "reliable")
func client_start_deployment(match_id: int, team: String, map_seed: int):
	"""Servidor indica inicio de fase de despliegue con semilla del mapa"""
	print("[CLIENT] Deployment started - Match: %d, Team: %s, MapSeed: %d" % [match_id, team, map_seed])
	current_map_seed = map_seed
	battle_deployment_started.emit(match_id, team)

@rpc("authority", "reliable")
func client_mech_deployed(mech_id: int, mech_data: Dictionary, hex_pos: Array, facing: int, team: String):
	"""Servidor confirma despliegue de mech"""
	print("[CLIENT] Mech deployed: %s at %s" % [mech_data.get("name", "Unknown"), hex_pos])
	battle_mech_deployed.emit(mech_id, mech_data, hex_pos, facing, team)

@rpc("authority", "reliable")
func client_initiative_result(result: Dictionary):
	"""Servidor envía resultado de iniciativa"""
	print("[CLIENT] Initiative result received")
	battle_initiative_result.emit(result)

@rpc("authority", "reliable")
func client_phase_changed(phase: String, turn: int):
	"""Servidor indica cambio de fase"""
	print("[CLIENT] Phase changed to: %s (Turn %d)" % [phase, turn])
	battle_phase_changed.emit(phase, turn)

@rpc("authority", "reliable")
func client_unit_activated(mech_id: int, is_mine: bool):
	"""Servidor indica qué unidad se activa"""
	print("[CLIENT] Unit activated: %d (mine: %s)" % [mech_id, is_mine])
	battle_unit_activated.emit(mech_id, is_mine)

@rpc("authority", "reliable")
func client_mech_moved(result: Dictionary):
	"""Servidor confirma movimiento"""
	print("[CLIENT] Mech moved")
	battle_mech_moved.emit(result)

@rpc("authority", "reliable")
func client_mech_rotated(result: Dictionary):
	"""Servidor confirma rotación"""
	print("[CLIENT] Mech rotated")
	battle_mech_rotated.emit(result)

@rpc("authority", "reliable")
func client_weapons_fired(result: Dictionary):
	"""Servidor envía resultados de disparo"""
	print("[CLIENT] Weapons fired")
	battle_weapons_fired.emit(result)

@rpc("authority", "reliable")
func client_physical_attack_result(result: Dictionary):
	"""Servidor envía resultado de ataque físico"""
	print("[CLIENT] Physical attack result")
	battle_physical_result.emit(result)

@rpc("authority", "reliable")
func client_heat_phase_result(results: Array):
	"""Servidor envía resultados de fase de calor"""
	print("[CLIENT] Heat phase result")
	battle_heat_result.emit(results)

@rpc("authority", "reliable")
func client_battle_ended(winner_team: String, reason: String):
	"""Servidor indica fin de batalla"""
	print("[CLIENT] Battle ended: %s wins - %s" % [winner_team, reason])
	battle_ended.emit(winner_team, reason)

@rpc("authority", "reliable")
func client_action_rejected(reason: String):
	"""Servidor rechaza una acción"""
	print("[CLIENT] Action rejected: %s" % reason)
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

# Señal para notificar que ambos jugadores desplegaron
signal battle_all_deployed()

@rpc("authority", "reliable")
func client_all_deployed():
	"""Servidor notifica que ambos jugadores terminaron de desplegar"""
	print("[CLIENT] Both players deployed!")
	battle_all_deployed.emit()

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
