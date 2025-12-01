extends Control
class_name MatchmakingUI

## MatchmakingUI - UI para matchmaking via API REST
## Muestra estado de cola, tiempo de espera y oponente encontrado

# =============================================================================
# SIGNALS
# =============================================================================

signal match_accepted()
signal match_declined()
signal back_pressed()


# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var status_panel: PanelContainer = $StatusPanel
@onready var status_label: Label = $StatusPanel/VBox/StatusLabel
@onready var queue_time_label: Label = $StatusPanel/VBox/QueueTimeLabel
@onready var position_label: Label = $StatusPanel/VBox/PositionLabel
@onready var mode_selector: OptionButton = $ControlsPanel/VBox/ModeSelector
@onready var join_button: Button = $ControlsPanel/VBox/JoinButton
@onready var leave_button: Button = $ControlsPanel/VBox/LeaveButton
@onready var advanced_lobby_button: Button = $ControlsPanel/VBox/AdvancedLobbyButton
@onready var back_button: Button = $ControlsPanel/VBox/BackButton

@onready var match_found_panel: PanelContainer = $MatchFoundPanel
@onready var opponent_name_label: Label = $MatchFoundPanel/VBox/OpponentNameLabel
@onready var opponent_elo_label: Label = $MatchFoundPanel/VBox/OpponentEloLabel
@onready var accept_button: Button = $MatchFoundPanel/VBox/HBox/AcceptButton
@onready var decline_button: Button = $MatchFoundPanel/VBox/HBox/DeclineButton

@onready var elo_display: Label = $EloPanel/VBox/EloLabel
@onready var rank_display: Label = $EloPanel/VBox/RankLabel


# =============================================================================
# VARIABLES
# =============================================================================

var network_manager: Node = null
var _update_timer: float = 0.0
var _is_in_queue: bool = false
var _match_data: Dictionary = {}


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	network_manager = get_node_or_null("/root/NetworkManager")
	
	if not network_manager:
		push_error("NetworkManager not found!")
		return
	
	_connect_signals()
	_setup_mode_selector()
	_update_ui_state()
	
	# Ocultar panel de match encontrado inicialmente
	if match_found_panel:
		match_found_panel.visible = false


func _process(delta: float) -> void:
	if _is_in_queue:
		_update_timer += delta
		if _update_timer >= 1.0:
			_update_timer = 0.0
			_update_queue_time()


# =============================================================================
# SETUP
# =============================================================================

func _connect_signals() -> void:
	# Señales del NetworkManager
	if network_manager.has_signal("matchmaking_queue_joined"):
		network_manager.matchmaking_queue_joined.connect(_on_queue_joined)
	if network_manager.has_signal("matchmaking_queue_left"):
		network_manager.matchmaking_queue_left.connect(_on_queue_left)
	if network_manager.has_signal("api_match_found"):
		network_manager.api_match_found.connect(_on_match_found)
	if network_manager.has_signal("matchmaking_error"):
		network_manager.matchmaking_error.connect(_on_matchmaking_error)
	# Señal del servidor ENet cuando la partida está lista
	if network_manager.has_signal("match_ready"):
		network_manager.match_ready.connect(_on_match_ready)
	
	# Botones
	if join_button:
		join_button.pressed.connect(_on_join_pressed)
	if leave_button:
		leave_button.pressed.connect(_on_leave_pressed)
	if advanced_lobby_button:
		advanced_lobby_button.pressed.connect(_on_advanced_lobby_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if accept_button:
		accept_button.pressed.connect(_on_accept_pressed)
	if decline_button:
		decline_button.pressed.connect(_on_decline_pressed)


func _setup_mode_selector() -> void:
	if not mode_selector:
		return
	
	mode_selector.clear()
	mode_selector.add_item("1v1 Match", 0)
	mode_selector.add_item("2v2 Match", 1)
	mode_selector.add_item("4v4 Match", 2)
	mode_selector.add_item("Practice", 3)
	mode_selector.selected = 0


# =============================================================================
# UI STATE
# =============================================================================

func _update_ui_state() -> void:
	var in_queue = network_manager.is_in_matchmaking_queue() if network_manager else false
	_is_in_queue = in_queue
	
	# Actualizar botones
	if join_button:
		join_button.disabled = in_queue
		join_button.text = "Searching..." if in_queue else "Find Match"
	
	if leave_button:
		leave_button.disabled = not in_queue
	
	if mode_selector:
		mode_selector.disabled = in_queue
	
	# Actualizar status
	if status_label:
		if in_queue:
			status_label.text = "Searching for opponent..."
			status_label.modulate = Color.YELLOW
		else:
			status_label.text = "Ready to play"
			status_label.modulate = Color.GREEN
	
	# Ocultar tiempo si no está en cola
	if queue_time_label:
		queue_time_label.visible = in_queue
	if position_label:
		position_label.visible = in_queue


func _update_queue_time() -> void:
	if not queue_time_label or not network_manager:
		return
	
	var time_sec = network_manager.get_matchmaking_time()
	var minutes = int(time_sec) / 60
	var seconds = int(time_sec) % 60
	queue_time_label.text = "Time: %02d:%02d" % [minutes, seconds]


func _show_match_found(match_data: Dictionary) -> void:
	_match_data = match_data
	
	if match_found_panel:
		match_found_panel.visible = true
	
	if opponent_name_label:
		opponent_name_label.text = "Opponent: %s" % match_data.get("opponent_name", "Unknown")
	
	if opponent_elo_label:
		var elo = match_data.get("opponent_elo", 1000)
		var rank = _get_rank_name(elo)
		opponent_elo_label.text = "ELO: %d (%s)" % [elo, rank]
	
	# Deshabilitar controles mientras se muestra el match
	if join_button:
		join_button.disabled = true
	if leave_button:
		leave_button.disabled = true
	
	# Auto-aceptar después de 10 segundos si no se responde
	# (opcional, comentado por ahora)
	# await get_tree().create_timer(10.0).timeout
	# if match_found_panel.visible:
	#     _on_accept_pressed()


func _hide_match_found() -> void:
	if match_found_panel:
		match_found_panel.visible = false
	_match_data = {}
	_update_ui_state()


# =============================================================================
# ELO / RANK DISPLAY
# =============================================================================

func set_player_elo(elo: int) -> void:
	if elo_display:
		elo_display.text = "ELO: %d" % elo
	
	if rank_display:
		rank_display.text = _get_rank_name(elo)


func _get_rank_name(elo: int) -> String:
	# Sincronizado con EloCalculator
	if elo >= 2800:
		return "Kerensky Prime"
	elif elo >= 2500:
		return "Kerensky"
	elif elo >= 2200:
		return "ilKhan"
	elif elo >= 2000:
		return "Khan"
	elif elo >= 1800:
		return "Galaxy Commander"
	elif elo >= 1600:
		return "Star Colonel"
	elif elo >= 1400:
		return "Star Captain"
	elif elo >= 1200:
		return "Elite"
	elif elo >= 1000:
		return "Veteran"
	elif elo >= 800:
		return "MechWarrior"
	elif elo >= 500:
		return "Cadet"
	else:
		return "Recruit"


# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_join_pressed() -> void:
	_play_click()
	
	if not network_manager:
		return
	
	var mode = mode_selector.selected if mode_selector else 0
	network_manager.join_matchmaking_queue(mode)


func _on_leave_pressed() -> void:
	_play_click()
	
	if network_manager:
		network_manager.leave_matchmaking_queue()


func _on_advanced_lobby_pressed() -> void:
	"""Abre el lobby avanzado con opciones de partida personalizada"""
	_play_click()
	
	# Salir de la cola si está en ella
	if _is_in_queue and network_manager:
		network_manager.leave_matchmaking_queue()
	
	# Ir al lobby mejorado
	get_tree().change_scene_to_file("res://scenes/improved_lobby.tscn")


func _on_back_pressed() -> void:
	_play_click()
	
	# Salir de la cola si está en ella
	if _is_in_queue and network_manager:
		network_manager.leave_matchmaking_queue()
	
	back_pressed.emit()
	
	# Volver al menú principal
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_accept_pressed() -> void:
	_play_click()
	
	if network_manager and not _match_data.is_empty():
		# Conectar al servidor de juego
		var error = network_manager.connect_to_matched_game()
		if error != OK:
			Log.error("MatchmakingUI", "Failed to connect to game server", {"error": error})
			_on_matchmaking_error("Failed to connect to game server")
			return
	
	_hide_match_found()
	match_accepted.emit()


func _on_decline_pressed() -> void:
	_play_click()
	
	# Volver a la cola
	_hide_match_found()
	match_declined.emit()


func _play_click() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(audio.SFX_UI_CLICK)


# =============================================================================
# NETWORK CALLBACKS
# =============================================================================

func _on_queue_joined(position: int, estimated_wait: float) -> void:
	_is_in_queue = true
	_update_ui_state()
	
	if position_label:
		position_label.text = "Position: #%d" % position
		position_label.visible = true
	
	if status_label:
		status_label.text = "Searching... (est. %ds)" % int(estimated_wait)


func _on_queue_left() -> void:
	_is_in_queue = false
	_update_ui_state()


func _on_match_found(match_data: Dictionary) -> void:
	_is_in_queue = false
	Log.info("MatchmakingUI", "Match found!", match_data)
	_show_match_found(match_data)


func _on_matchmaking_error(error: String) -> void:
	_is_in_queue = false
	_update_ui_state()
	
	if status_label:
		status_label.text = "Error: %s" % error
		status_label.modulate = Color.RED
	
	Log.error("MatchmakingUI", "Matchmaking error", {"error": error})


func _on_match_ready(match_id: int, team: String) -> void:
	"""Servidor ENet confirma que la partida está lista - transicionar a batalla"""
	Log.info("MatchmakingUI", "Match ready! Transitioning to battle", {
		"match_id": match_id,
		"team": team
	})
	
	# Transicionar a la escena de batalla
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")
