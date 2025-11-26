extends Node

## ServerMain - Punto de entrada para el servidor dedicado headless
## Ejecutar con: godot --headless --main-pack BattleTech_Server.pck

const NetworkManager = preload("res://scripts/network/network_manager.gd")

var network_manager: NetworkManager
var server_battle_manager: Node

func _ready():
	print("========================================")
	print("  BATTLETECH DEDICATED SERVER")
	print("  Version: 1.0.0")
	print("========================================")
	
	# Parsear argumentos de línea de comandos
	var args = _parse_arguments()
	var port = args.get("port", 7777)
	
	# Crear e inicializar NetworkManager
	network_manager = NetworkManager.new()
	network_manager.name = "NetworkManager"
	add_child(network_manager)
	
	# Crear ServerBattleManager
	server_battle_manager = preload("res://scripts/network/server_battle_manager.gd").new()
	server_battle_manager.name = "ServerBattleManager"
	add_child(server_battle_manager)
	
	# Conectar señales
	network_manager.player_registered.connect(_on_player_registered)
	network_manager.match_ready.connect(_on_match_ready)
	network_manager.peer_disconnected.connect(_on_peer_disconnected)
	
	# Iniciar servidor
	var error = network_manager.start_dedicated_server(port)
	if error != OK:
		push_error("Failed to start server!")
		get_tree().quit(1)
		return
	
	print("[SERVER] Server ready on port %d" % port)
	print("[SERVER] Waiting for connections...")

func _parse_arguments() -> Dictionary:
	"""Parsea argumentos de línea de comandos"""
	var args = {}
	var cmd_args = OS.get_cmdline_args()
	
	for i in range(cmd_args.size()):
		var arg = cmd_args[i]
		
		if arg == "--port" and i + 1 < cmd_args.size():
			args["port"] = int(cmd_args[i + 1])
		elif arg.begins_with("--port="):
			args["port"] = int(arg.split("=")[1])
	
	return args

func _on_player_registered(peer_id: int, player_name: String):
	print("[SERVER] Player registered: %d (%s)" % [peer_id, player_name])
	print("[SERVER] Total players: %d" % network_manager.get_player_count())

func _on_match_ready(player1_id: int, player2_id: int):
	print("[SERVER] Match starting: %d vs %d" % [player1_id, player2_id])
	print("[SERVER] Active matches: %d" % network_manager.get_active_match_count())
	
	# Iniciar la batalla en el ServerBattleManager
	if server_battle_manager.has_method("start_match"):
		server_battle_manager.start_match(player1_id, player2_id)

func _on_peer_disconnected(peer_id: int):
	print("[SERVER] Player disconnected: %d" % peer_id)
	print("[SERVER] Total players: %d" % network_manager.get_player_count())

func _process(_delta):
	# Mostrar estadísticas cada 60 segundos
	pass

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[SERVER] Shutdown requested...")
		if network_manager:
			network_manager.stop_server()
		get_tree().quit()
