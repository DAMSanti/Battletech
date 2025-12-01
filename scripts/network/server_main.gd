extends Node

## ServerMain - Punto de entrada para el servidor dedicado headless
## Ejecutar con: godot --headless --main-pack BattleTech_Server.pck

var network_manager: Node  # Referencia al autoload NetworkManager
var server_battle_manager: Node

func _ready():
	Log.info("System", "════════════════════════════════════════")
	Log.info("System", "  STEEL TITANS DEDICATED SERVER")
	Log.info("System", "  Version: 1.0.0")
	Log.info("System", "════════════════════════════════════════")
	
	# Parsear argumentos de línea de comandos
	var args = _parse_arguments()
	var port = args.get("port", 7777)
	
	# Usar el NetworkManager autoload en lugar de crear una instancia nueva
	network_manager = get_node_or_null("/root/NetworkManager")
	if not network_manager:
		Log.critical("Network", "NetworkManager autoload not found!")
		get_tree().quit(1)
		return
	
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
		Log.critical("Network", "Failed to start server!", {"port": port})
		get_tree().quit(1)
		return
	
	Log.info("Network", "Server ready and listening", {"port": port})
	Log.info("Network", "Waiting for connections...")

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
	Log.network("Player registered: %s" % player_name, peer_id)
	Log.info("Network", "Total players connected", {"count": network_manager.get_player_count()})

func _on_match_ready(player1_id: int, player2_id: int):
	Log.match_event("Match starting", "", str(player1_id), str(player2_id))
	Log.info("Match", "Active matches", {"count": network_manager.get_active_match_count()})
	
	# Obtener el match_id y map_seed del NetworkManager
	var match_id = network_manager.connected_players[player1_id]["match_id"]
	var map_seed = network_manager.active_matches[match_id]["map_seed"]
	
	# Iniciar la batalla en el ServerBattleManager con el MISMO match_id
	if server_battle_manager.has_method("start_match"):
		server_battle_manager.start_match(player1_id, player2_id, match_id, map_seed)

func _on_peer_disconnected(peer_id: int):
	Log.network("Player disconnected", peer_id)
	Log.info("Network", "Total players remaining", {"count": network_manager.get_player_count()})

func _process(_delta):
	# Mostrar estadísticas cada 60 segundos
	pass

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Log.info("System", "Shutdown requested by system")
		if network_manager:
			network_manager.stop_server()
		get_tree().quit()
