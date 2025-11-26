extends Control

## MultiplayerLobbyUI - Interfaz de lobby multiplayer
## Permite conectar al servidor, unirse a la cola y ver el estado

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var player_name_input: LineEdit = $VBoxContainer/NameContainer/PlayerNameInput
@onready var server_address_input: LineEdit = $VBoxContainer/ServerContainer/ServerAddressInput
@onready var connect_button: Button = $VBoxContainer/ConnectButton
@onready var join_lobby_button: Button = $VBoxContainer/JoinLobbyButton
@onready var leave_lobby_button: Button = $VBoxContainer/LeaveLobbyButton
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var lobby_list: VBoxContainer = $VBoxContainer/LobbyPanel/LobbyList

var network_manager: Node = null

func _ready():
	network_manager = get_node_or_null("/root/NetworkManager")
	
	if not network_manager:
		push_error("NetworkManager not found!")
		return
	
	# Conectar señales del NetworkManager
	network_manager.connected_to_server.connect(_on_connected_to_server)
	network_manager.connection_failed.connect(_on_connection_failed)
	network_manager.server_disconnected.connect(_on_server_disconnected)
	network_manager.lobby_updated.connect(_on_lobby_updated)
	network_manager.match_ready.connect(_on_match_ready)
	
	# Conectar botones
	connect_button.pressed.connect(_on_connect_pressed)
	join_lobby_button.pressed.connect(_on_join_lobby_pressed)
	leave_lobby_button.pressed.connect(_on_leave_lobby_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Estado inicial
	_update_ui_state()
	
	# AUTO-CONECTAR al servidor al entrar a la pantalla
	_auto_connect()

func _update_ui_state():
	var state = network_manager.connection_state if network_manager else 0
	
	match state:
		NetworkManager.ConnectionState.DISCONNECTED:
			status_label.text = "Status: Disconnected"
			status_label.modulate = Color.RED
			connect_button.text = "Connect"
			connect_button.disabled = false
			join_lobby_button.disabled = true
			leave_lobby_button.disabled = true
			player_name_input.editable = true
			server_address_input.editable = true
		
		NetworkManager.ConnectionState.CONNECTING:
			status_label.text = "Status: Connecting..."
			status_label.modulate = Color.YELLOW
			connect_button.text = "Connecting..."
			connect_button.disabled = true
			join_lobby_button.disabled = true
			leave_lobby_button.disabled = true
		
		NetworkManager.ConnectionState.CONNECTED:
			status_label.text = "Status: Connected"
			status_label.modulate = Color.GREEN
			connect_button.text = "Disconnect"
			connect_button.disabled = false
			join_lobby_button.disabled = false
			leave_lobby_button.disabled = true
			player_name_input.editable = false
			server_address_input.editable = false
		
		NetworkManager.ConnectionState.IN_LOBBY:
			status_label.text = "Status: In Lobby (waiting for opponent)"
			status_label.modulate = Color.CYAN
			connect_button.text = "Disconnect"
			connect_button.disabled = false
			join_lobby_button.disabled = true
			leave_lobby_button.disabled = false
		
		NetworkManager.ConnectionState.IN_MATCH:
			status_label.text = "Status: Match found!"
			status_label.modulate = Color.GOLD

func _on_connect_pressed():
	if network_manager.connection_state == NetworkManager.ConnectionState.DISCONNECTED:
		# Conectar
		var player_name = player_name_input.text.strip_edges()
		if player_name.is_empty():
			player_name = "Player_%d" % randi()
			player_name_input.text = player_name
		
		var server_address = server_address_input.text.strip_edges()
		if server_address.is_empty():
			server_address = "127.0.0.1"  # Localhost por defecto
			server_address_input.text = server_address
		
		var error = network_manager.connect_to_server(server_address, 7777, player_name)
		if error != OK:
			status_label.text = "Connection failed: " + error_string(error)
			status_label.modulate = Color.RED
	else:
		# Desconectar
		network_manager.disconnect_from_server()
	
	_update_ui_state()

func _on_join_lobby_pressed():
	if network_manager:
		network_manager.rpc_id(1, "server_join_lobby")
		network_manager.connection_state = NetworkManager.ConnectionState.IN_LOBBY
		_update_ui_state()

func _on_leave_lobby_pressed():
	if network_manager:
		network_manager.rpc_id(1, "server_leave_lobby")
		network_manager.connection_state = NetworkManager.ConnectionState.CONNECTED
		_update_ui_state()
		_clear_lobby_list()

func _on_back_pressed():
	# Desconectar si está conectado
	if network_manager and network_manager.connection_state != NetworkManager.ConnectionState.DISCONNECTED:
		network_manager.disconnect_from_server()
	
	# Volver al menú principal
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_connected_to_server():
	print("[LOBBY_UI] Connected to server!")
	_update_ui_state()

func _on_connection_failed():
	print("[LOBBY_UI] Connection failed!")
	status_label.text = "Status: Connection failed!"
	status_label.modulate = Color.RED
	_update_ui_state()

func _on_server_disconnected():
	print("[LOBBY_UI] Server disconnected!")
	status_label.text = "Status: Server disconnected!"
	status_label.modulate = Color.RED
	_update_ui_state()
	_clear_lobby_list()

func _on_lobby_updated(players: Array):
	print("[LOBBY_UI] Lobby updated: %d players" % players.size())
	_update_lobby_list(players)

func _on_match_ready(_match_id, _team):
	print("[LOBBY_UI] Match ready! Starting battle...")
	# Cambiar a la escena de batalla
	# El NetworkBattleClient manejará la sincronización
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")

func _update_lobby_list(players: Array):
	_clear_lobby_list()
	
	for player_info in players:
		var label = Label.new()
		label.text = "• %s" % player_info.get("name", "Unknown")
		label.add_theme_color_override("font_color", Color.WHITE)
		lobby_list.add_child(label)

func _clear_lobby_list():
	for child in lobby_list.get_children():
		child.queue_free()

func _auto_connect():
	"""Conecta automáticamente al servidor al entrar a la pantalla"""
	if network_manager.connection_state != network_manager.ConnectionState.DISCONNECTED:
		return  # Ya conectado
	
	# Generar nombre aleatorio si no hay uno
	var player_name = player_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player_%d" % (randi() % 9999)
		player_name_input.text = player_name
	
	# Obtener IP del servidor (usa la de producción por defecto)
	var server_ip = network_manager.PRODUCTION_SERVER_IP
	server_address_input.text = server_ip
	
	status_label.text = "Connecting to server..."
	status_label.modulate = Color.YELLOW
	
	var error = network_manager.connect_to_server(server_ip, 7777, player_name)
	if error != OK:
		status_label.text = "Connection failed: " + error_string(error)
		status_label.modulate = Color.RED
	
	_update_ui_state()
