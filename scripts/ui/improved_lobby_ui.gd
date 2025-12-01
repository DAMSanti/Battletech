extends Control
class_name ImprovedLobbyUI

## ImprovedLobbyUI - Sistema de lobby mejorado
## Incluye: selección de modo, configuración de partida, chat, lista de jugadores

signal match_started(match_config: Dictionary)
signal back_pressed()

# Modos de juego disponibles
enum GameMode {
	MODE_1V1,
	MODE_2V2,
	PRACTICE,
	CUSTOM_MATCH
}

# Configuración de partida personalizada
var match_config: Dictionary = {
	"game_mode": GameMode.MODE_1V1,
	"turn_time_limit": 120,  # segundos
	"map_type": "random",
	"lance_size": 4,  # mechs por jugador
	"battle_value_limit": 0,  # 0 = sin límite
	"allow_spectators": false
}

# Referencias UI
@onready var mode_selector: OptionButton = $MainPanel/VBox/ModeContainer/ModeSelector
@onready var status_label: Label = $MainPanel/VBox/StatusLabel
@onready var queue_time_label: Label = $MainPanel/VBox/QueueTimeLabel
@onready var player_count_label: Label = $MainPanel/VBox/PlayerCountLabel
@onready var player_list: VBoxContainer = $MainPanel/VBox/PlayersPanel/ScrollContainer/PlayerList
@onready var chat_display: RichTextLabel = $MainPanel/VBox/ChatPanel/ChatDisplay
@onready var chat_input: LineEdit = $MainPanel/VBox/ChatPanel/InputContainer/ChatInput
@onready var send_button: Button = $MainPanel/VBox/ChatPanel/InputContainer/SendButton
@onready var config_panel: PanelContainer = $MainPanel/VBox/ConfigPanel
@onready var turn_time_spinbox: SpinBox = $MainPanel/VBox/ConfigPanel/ConfigGrid/TurnTimeSpinBox
@onready var lance_size_spinbox: SpinBox = $MainPanel/VBox/ConfigPanel/ConfigGrid/LanceSizeSpinBox
@onready var bv_limit_spinbox: SpinBox = $MainPanel/VBox/ConfigPanel/ConfigGrid/BVLimitSpinBox
@onready var map_type_selector: OptionButton = $MainPanel/VBox/ConfigPanel/ConfigGrid/MapTypeSelector
@onready var find_match_button: Button = $MainPanel/VBox/ButtonContainer/FindMatchButton
@onready var cancel_button: Button = $MainPanel/VBox/ButtonContainer/CancelButton
@onready var back_button: Button = $MainPanel/VBox/ButtonContainer/BackButton

var _network_manager: Node = null
var _in_queue: bool = false
var _queue_start_time: float = 0.0
var _players_in_lobby: Array = []


func _ready() -> void:
	# Obtener NetworkManager
	_network_manager = get_node_or_null("/root/NetworkManager")
	
	if _network_manager:
		_network_manager.lobby_updated.connect(_on_lobby_updated)
		_network_manager.match_ready.connect(_on_match_ready)
		_network_manager.connected_to_server.connect(_on_connected)
		_network_manager.server_disconnected.connect(_on_disconnected)
		_network_manager.matchmaking_queue_joined.connect(_on_queue_joined)
		_network_manager.matchmaking_queue_left.connect(_on_queue_left)
		_network_manager.matchmaking_error.connect(_on_matchmaking_error)
		# Conectar señal de chat
		if _network_manager.has_signal("chat_message_received"):
			_network_manager.chat_message_received.connect(_on_chat_received)
	
	# Setup UI
	_setup_mode_selector()
	_setup_map_selector()
	_setup_config_panel()
	_connect_signals()
	_update_ui_state()


func _process(delta: float) -> void:
	if _in_queue:
		_update_queue_time()


func _setup_mode_selector() -> void:
	"""Configura el selector de modo de juego"""
	if not mode_selector:
		return
	
	mode_selector.clear()
	mode_selector.add_item("⚔️ 1v1 Match", GameMode.MODE_1V1)
	mode_selector.add_item("👥 2v2 Match", GameMode.MODE_2V2)
	mode_selector.add_item("🎯 Practice", GameMode.PRACTICE)
	mode_selector.add_item("⚙️ Custom Match", GameMode.CUSTOM_MATCH)
	mode_selector.selected = 0


func _setup_map_selector() -> void:
	"""Configura el selector de tipo de mapa"""
	if not map_type_selector:
		return
	
	map_type_selector.clear()
	map_type_selector.add_item("Random", 0)
	map_type_selector.add_item("Plains", 1)
	map_type_selector.add_item("Forest", 2)
	map_type_selector.add_item("Urban", 3)
	map_type_selector.add_item("Desert", 4)
	map_type_selector.add_item("Mountain", 5)


func _setup_config_panel() -> void:
	"""Configura los valores por defecto del panel de configuración"""
	if turn_time_spinbox:
		turn_time_spinbox.min_value = 30
		turn_time_spinbox.max_value = 300
		turn_time_spinbox.step = 30
		turn_time_spinbox.value = match_config.turn_time_limit
	
	if lance_size_spinbox:
		lance_size_spinbox.min_value = 1
		lance_size_spinbox.max_value = 8
		lance_size_spinbox.value = match_config.lance_size
	
	if bv_limit_spinbox:
		bv_limit_spinbox.min_value = 0
		bv_limit_spinbox.max_value = 50000
		bv_limit_spinbox.step = 1000
		bv_limit_spinbox.value = match_config.battle_value_limit


func _connect_signals() -> void:
	"""Conecta las señales de los botones"""
	if mode_selector:
		mode_selector.item_selected.connect(_on_mode_selected)
	
	if find_match_button:
		find_match_button.pressed.connect(_on_find_match_pressed)
	
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	if send_button:
		send_button.pressed.connect(_on_send_chat)
	
	if chat_input:
		chat_input.text_submitted.connect(_on_chat_submitted)
	
	# Configuración
	if turn_time_spinbox:
		turn_time_spinbox.value_changed.connect(_on_turn_time_changed)
	
	if lance_size_spinbox:
		lance_size_spinbox.value_changed.connect(_on_lance_size_changed)
	
	if bv_limit_spinbox:
		bv_limit_spinbox.value_changed.connect(_on_bv_limit_changed)
	
	if map_type_selector:
		map_type_selector.item_selected.connect(_on_map_type_selected)


func _update_ui_state() -> void:
	"""Actualiza el estado de la UI basado en el estado actual"""
	var connected = _network_manager and _network_manager.connection_state >= NetworkManager.ConnectionState.CONNECTED
	var current_mode = mode_selector.get_selected_id() if mode_selector else 0
	var is_custom_match = (current_mode == GameMode.CUSTOM_MATCH)
	
	# Custom Match permite jugar offline (partida local)
	if is_custom_match:
		if not connected:
			status_label.text = "🎮 Modo Local - Sin conexión"
			status_label.modulate = Color.ORANGE
		else:
			status_label.text = "✅ Conectado - Partida personalizada"
			status_label.modulate = Color.GREEN
		
		find_match_button.disabled = false
		find_match_button.visible = true
		find_match_button.text = "🎮 Iniciar Partida Local" if not connected else "🔍 Buscar Oponente"
		cancel_button.disabled = true
		cancel_button.visible = false
		mode_selector.disabled = false
		config_panel.visible = true
		queue_time_label.visible = false
		return
	
	# Ranked/Casual requieren conexión
	if not connected:
		status_label.text = "⚠️ Desconectado del servidor"
		status_label.modulate = Color.RED
		find_match_button.disabled = true
		find_match_button.text = "🔍 Buscar Partida"
		cancel_button.disabled = true
		config_panel.visible = false
		return
	
	if _in_queue:
		status_label.text = "🔍 Buscando oponente..."
		status_label.modulate = Color.YELLOW
		find_match_button.disabled = true
		find_match_button.visible = false
		cancel_button.disabled = false
		cancel_button.visible = true
		mode_selector.disabled = true
		config_panel.visible = false
	else:
		status_label.text = "✅ Conectado - Listo para buscar"
		status_label.modulate = Color.GREEN
		find_match_button.disabled = false
		find_match_button.visible = true
		find_match_button.text = "🔍 Buscar Partida"
		cancel_button.disabled = true
		cancel_button.visible = false
		mode_selector.disabled = false
		config_panel.visible = false
	
	queue_time_label.visible = _in_queue


func _update_queue_time() -> void:
	"""Actualiza el tiempo en cola"""
	if not _in_queue:
		return
	
	var elapsed = Time.get_ticks_msec() / 1000.0 - _queue_start_time
	var minutes = int(elapsed) / 60
	var seconds = int(elapsed) % 60
	queue_time_label.text = "⏱️ Tiempo en cola: %02d:%02d" % [minutes, seconds]


func _update_player_list() -> void:
	"""Actualiza la lista de jugadores en el lobby"""
	if not player_list:
		return
	
	# Limpiar lista actual
	for child in player_list.get_children():
		child.queue_free()
	
	# Agregar jugadores
	for player_data in _players_in_lobby:
		var player_entry = _create_player_entry(player_data)
		player_list.add_child(player_entry)
	
	# Actualizar contador
	if player_count_label:
		player_count_label.text = "👥 Jugadores en cola: %d" % _players_in_lobby.size()


func _create_player_entry(player_data: Dictionary) -> HBoxContainer:
	"""Crea una entrada de jugador para la lista"""
	var container = HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Icono de estado
	var status_icon = Label.new()
	status_icon.text = "🟢 "
	container.add_child(status_icon)
	
	# Nombre
	var name_label = Label.new()
	name_label.text = player_data.get("name", "Unknown")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(name_label)
	
	# ELO (si disponible)
	var elo = player_data.get("elo", 0)
	if elo > 0:
		var elo_label = Label.new()
		elo_label.text = "[%d]" % elo
		elo_label.modulate = Color(0.7, 0.7, 0.7)
		container.add_child(elo_label)
	
	return container


func _add_chat_message(sender: String, message: String, is_system: bool = false) -> void:
	"""Agrega un mensaje al chat"""
	if not chat_display:
		return
	
	var timestamp = Time.get_time_string_from_system().substr(0, 5)
	var formatted: String
	
	if is_system:
		formatted = "[color=yellow][%s] %s[/color]\n" % [timestamp, message]
	else:
		formatted = "[color=cyan][%s][/color] [b]%s:[/b] %s\n" % [timestamp, sender, message]
	
	chat_display.append_text(formatted)
	
	# Auto-scroll al final
	chat_display.scroll_to_line(chat_display.get_line_count())


func _read_match_config() -> Dictionary:
	"""Lee la configuración actual de partida"""
	return {
		"game_mode": mode_selector.get_selected_id() if mode_selector else GameMode.MODE_1V1,
		"turn_time_limit": int(turn_time_spinbox.value) if turn_time_spinbox else 120,
		"map_type": map_type_selector.get_item_text(map_type_selector.selected) if map_type_selector else "random",
		"lance_size": int(lance_size_spinbox.value) if lance_size_spinbox else 4,
		"battle_value_limit": int(bv_limit_spinbox.value) if bv_limit_spinbox else 0
	}


# ============================================================
# CALLBACKS
# ============================================================

func _on_mode_selected(index: int) -> void:
	"""Callback cuando se selecciona un modo"""
	var mode = mode_selector.get_item_id(index)
	match_config.game_mode = mode
	
	# Actualizar UI (esto controla visibilidad del panel de config)
	_update_ui_state()
	
	_add_chat_message("Sistema", "Modo seleccionado: %s" % mode_selector.get_item_text(index), true)


func _on_find_match_pressed() -> void:
	"""Callback cuando se presiona buscar partida"""
	var config = _read_match_config()
	var connected = _network_manager and _network_manager.connection_state >= NetworkManager.ConnectionState.CONNECTED
	
	# Custom Match sin conexión = partida local
	if config.game_mode == GameMode.CUSTOM_MATCH and not connected:
		_add_chat_message("Sistema", "Iniciando partida local...", true)
		_start_local_match(config)
		return
	
	if not _network_manager:
		_add_chat_message("Sistema", "Error: NetworkManager no disponible", true)
		return
	
	_queue_start_time = Time.get_ticks_msec() / 1000.0
	_in_queue = true
	
	# Usar el modo de juego para la API de matchmaking
	var api_mode = config.game_mode
	if api_mode == GameMode.CUSTOM_MATCH:
		api_mode = GameMode.MODE_1V1  # Custom usa 1v1 por ahora
	
	_network_manager.join_matchmaking_queue(api_mode)
	_add_chat_message("Sistema", "Buscando oponente...", true)
	_update_ui_state()


func _start_local_match(config: Dictionary) -> void:
	"""Inicia una partida local (sin servidor)"""
	# Guardar configuración para la batalla
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		game_state.is_multiplayer = false
		game_state.match_config = config
	
	match_started.emit(config)
	
	# Ir a la pantalla de configuración de equipos
	get_tree().change_scene_to_file("res://scenes/team_setup.tscn")


func _on_cancel_pressed() -> void:
	"""Callback cuando se cancela la búsqueda"""
	if not _network_manager:
		return
	
	_network_manager.leave_matchmaking_queue()
	_in_queue = false
	_add_chat_message("Sistema", "Búsqueda cancelada", true)
	_update_ui_state()


func _on_back_pressed() -> void:
	"""Callback para volver al menú"""
	# Si está en cola, salir primero
	if _in_queue and _network_manager:
		_network_manager.leave_matchmaking_queue()
	
	back_pressed.emit()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_send_chat() -> void:
	"""Callback para enviar mensaje de chat"""
	if not chat_input or chat_input.text.strip_edges().is_empty():
		return
	
	var message = chat_input.text.strip_edges()
	var player_name = "Yo"
	
	# Obtener nombre real del jugador si está disponible
	if _network_manager and _network_manager.has_method("get_local_player_name"):
		var name = _network_manager.get_local_player_name()
		if name and not name.is_empty():
			player_name = name
	
	# Mostrar mensaje local
	_add_chat_message(player_name, message)
	
	# Enviar por RPC a otros jugadores si estamos en partida
	if _network_manager and _network_manager.has_method("send_chat_message"):
		if _network_manager.has_method("is_in_match") and _network_manager.is_in_match():
			_network_manager.send_chat_message(message)
	
	chat_input.clear()


func _on_chat_received(sender_name: String, message: String) -> void:
	"""Callback cuando se recibe un mensaje de chat de la red"""
	_add_chat_message(sender_name, message)


func _on_chat_submitted(text: String) -> void:
	"""Callback cuando se presiona Enter en el chat"""
	_on_send_chat()


func _on_turn_time_changed(value: float) -> void:
	match_config.turn_time_limit = int(value)


func _on_lance_size_changed(value: float) -> void:
	match_config.lance_size = int(value)


func _on_bv_limit_changed(value: float) -> void:
	match_config.battle_value_limit = int(value)


func _on_map_type_selected(index: int) -> void:
	match_config.map_type = map_type_selector.get_item_text(index).to_lower()


# Network callbacks
func _on_connected() -> void:
	_add_chat_message("Sistema", "Conectado al servidor", true)
	_update_ui_state()


func _on_disconnected() -> void:
	_in_queue = false
	_add_chat_message("Sistema", "Desconectado del servidor", true)
	_update_ui_state()


func _on_lobby_updated(players: Array) -> void:
	_players_in_lobby = players
	_update_player_list()


func _on_queue_joined(position: int, estimated_wait: float) -> void:
	_in_queue = true
	_add_chat_message("Sistema", "En cola - Posición: %d, Espera estimada: %.0fs" % [position, estimated_wait], true)
	_update_ui_state()


func _on_queue_left() -> void:
	_in_queue = false
	_update_ui_state()


func _on_matchmaking_error(error: String) -> void:
	_in_queue = false
	_add_chat_message("Sistema", "Error: %s" % error, true)
	_update_ui_state()


func _on_match_ready(match_id: int, team: String) -> void:
	"""Callback cuando se encuentra partida"""
	_in_queue = false
	_add_chat_message("Sistema", "¡Partida encontrada! Match ID: %d, Equipo: %s" % [match_id, team], true)
	
	var config = _read_match_config()
	config["match_id"] = match_id
	config["team"] = team
	match_started.emit(config)
	
	# Cambiar a la escena de batalla
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")
