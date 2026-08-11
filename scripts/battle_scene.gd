extends Node2D
## Escena principal de batalla táctica BattleTech.
##
## Orquesta todos los sistemas de combate:
## - Grid hexagonal y movimiento
## - Sistema de turnos e iniciativa
## - Ataques de armas y físicos
## - Gestión de calor
## - Modo multiplayer/singleplayer
##
## Arquitectura: Usa BattleComponentsIntegrator (SOLID) para delegar
## responsabilidades a componentes especializados.
##
## @tutorial: Ver doc/UNIFIED_BATTLE_SYSTEM.md para arquitectura completa.

# Precargar componentes de UI
const ActiveMechIndicatorClass = preload("res://scripts/ui/active_mech_indicator.gd")
const CombatResultPresenterClass = preload("res://scripts/ui/combat_result_presenter.gd")
const BattleStatsTrackerClass = preload("res://scripts/managers/battle_stats_tracker.gd")
const BattleEndScreenClass = preload("res://scripts/ui/battle_end_screen.gd")
const TutorialHintPopupClass = preload("res://scripts/ui/tutorial_hint_popup.gd")

# Nuevo sistema de batalla unificado
const BattleSceneAdapterClass = preload("res://scripts/core/battle/battle_scene_adapter.gd")
const LocalBattleManagerClass = preload("res://scripts/core/battle/local_battle_manager.gd")
const NetworkBattleManagerClass = preload("res://scripts/core/battle/network_battle_manager.gd")

# ==============================================================================
# COMPONENTES REFACTORIZADOS (SOLID)
# ==============================================================================
var battle_components: BattleComponentsIntegrator = null
var mech_factory: MechFactory = null  # Factory para creación de mechs
var initiative_presenter: BattleInitiativePresenter = null  # Presenter para iniciativa
var combat_result_presenter = null  # CombatResultPresenter para resultados de combate
var use_component_input: bool = true  # Usar BattleInputRouter refactorizado

# Dificultad de la IA (0=EASY, 1=NORMAL, 2=HARD)
@export_range(0, 2) var ai_difficulty: int = 1

# Flag para evitar que la IA despliegue cuando el tutorial ya forzó el deploy
var tutorial_enemy_already_deployed: bool = false

# Sistema de estadísticas de batalla
var battle_stats_tracker = null

# Sistema de tutorial
var tutorial_hint_popup = null
var is_tutorial_mode: bool = false
var first_damage_received: bool = false

# Referencias (sin @onready porque necesitamos esperar)
var hex_grid
var turn_manager
var ui
var overlay_layer  # Capa para dibujar hexágonos alcanzables ENCIMA del terreno
var effects_layer: Node2D = null  # Capa para efectos de combate (proyectiles, impactos)
var battle_ai: BattleAI  # Sistema de IA mejorado

# ============================================================
# SISTEMA UNIFICADO DE BATALLA
# ============================================================
var battle_adapter: Node = null  # BattleSceneAdapter para el nuevo sistema
var use_unified_system: bool = false  # Flag para activar gradualmente el nuevo sistema

# ============================================================
# SISTEMA MULTIPLAYER
# ============================================================
var is_multiplayer_mode: bool = false
var network_battle_client: Node = null
var network_handler: BattleNetworkHandler = null  # Handler de red SOLID
var my_team: String = ""  # "player" o "enemy"
var match_id: int = -1
var is_my_turn: bool = false
var waiting_for_server: bool = false  # Esperando respuesta del servidor

var player_mechs: Array = []
var enemy_mechs: Array = []

var selected_unit = null
var selected_hex: Vector2i = Vector2i(-1, -1)

var reachable_hexes: Array = []
var target_hexes: Array = []
var physical_target_hexes: Array = []  # Enemigos adyacentes para ataque físico

# Sistema de movimiento
var pending_movement_selection: bool = false  # Esperando que el jugador elija Walk/Run/Jump
var pending_turn_only: bool = false  # Esperando selección de facing para girar sin moverse
var ignore_next_click: bool = false  # Ignorar el próximo click (usado después de cerrar UI)
var ignore_until_time: int = 0  # Timestamp (ms) hasta el cual ignorar clicks
const IGNORE_CLICK_DEBOUNCE_MS: int = 200  # Tiempo para ignorar clicks tras cerrar UI (ms)
var ui_interaction_cooldown: float = 0.0  # Tiempo de cooldown después de interacción con UI
var _last_hex_click_time: int = 0  # Tiempo del último click en hex (ms) - debounce para Android
const HEX_CLICK_DEBOUNCE_MS: int = 150  # Tiempo mínimo entre clicks en hex (ms)

# Sistema de confirmación de movimiento
var pending_move_confirmation: bool = false  # Esperando confirmación de movimiento
var preview_path: Array = []  # Camino a previsualizar
var preview_destination: Vector2i = Vector2i(-1, -1)  # Destino del movimiento pendiente
var reachable_hexes_details: Dictionary = {}  # Detalles de hexes alcanzables (incluye paths)

# USAR GameEnums en lugar de enum local
var current_state: int = GameEnums.GameState.MOVING
var current_attack_target = null  # Objetivo actual para ataque con armas

var initiative_screen_scene = preload("res://scenes/initiative_screen.tscn")
var initiative_data_stored: Dictionary = {}
var battle_started = false

# Sistema de despliegue
var deployment_phase: bool = false
var deployment_zones: Dictionary = {}  # Zonas de despliegue por equipo
var mechs_to_deploy: Array = []  # Mechs pendientes de desplegar
var current_deploying_mech = null  # Mech que se está desplegando
var valid_deployment_hexes: Array = []  # Hexágonos válidos para despliegue

# Sistema de cámara
var camera: Camera2D
const CAMERA_SMOOTH_SPEED = 10.0

# Sistema de long press (indicador visual - el estado lo maneja BattleInputRouter)
var long_press_indicator: LongPressIndicator = null

# Sistema de indicador de mech activo
var active_mech_indicator: Control = null  # ActiveMechIndicator

func update_mech_visibility():
	"""Actualiza la visibilidad de mechs enemigos según LoS desde mechs aliados"""
	if not hex_grid:
		return
	
	# Bug reportado: el tutorial fuerza al enemigo a posiciones concretas
	# (ver tutorial_manager._force_enemy_move) sin garantizar que el mech
	# del jugador tenga linea de vision real hasta ahi. El sistema de
	# fog-of-war por LoS entonces lo ocultaba (correctamente, segun las
	# reglas normales de combate) y se quedaba oculto el resto de la
	# partida, porque el tutorial nunca vuelve a forzar su visibilidad.
	# El tutorial es una demo 1v1 completamente scripteada: el enemigo
	# siempre debe verse mientras no este destruido.
	if is_tutorial_mode:
		for enemy in enemy_mechs:
			enemy.set_visibility(not enemy.is_destroyed)
		return
	
	# Actualizar visibilidad de cada mech enemigo
	for enemy in enemy_mechs:
		if enemy.is_destroyed:
			enemy.set_visibility(false)
			continue
		
		# Verificar si algún mech aliado tiene LoS a este enemigo
		var mech_is_visible = false
		for player_mech in player_mechs:
			if player_mech.is_destroyed:
				continue
			
			# Verificar LoS desde este mech aliado al enemigo
			var has_los = LineOfSight.can_shoot(hex_grid, player_mech.hex_position, enemy.hex_position)
			if has_los:
				mech_is_visible = true
				break
		
		enemy.set_visibility(mech_is_visible)

# NOTA: has_enemies_in_los() y has_adjacent_enemies() movidos a BattleCombatExecutor
# Se acceden via battle_components.has_enemies_in_los(unit) / battle_components.has_adjacent_enemies(unit)

func update_overlays():
	# Delegar al componente de overlay - usa sync_and_update para leer de componentes
	if battle_components and battle_components.use_overlay_component:
		# sync_and_update lee todos los datos de los componentes:
		# - reachable_hexes/preview_path del movement_handler
		# - target_hexes/physical_target_hexes del combat_executor
		# - deployment_hexes del deployment_manager
		battle_components.sync_and_update_overlays()

func _ready():
	Log.info("Combat", "_ready() called")
	
	# Iniciar música de batalla
	if AudioManager:
		AudioManager.play_music(AudioManager.MUSIC_BATTLE, 1.5)
	
	# Crear indicador de long press
	_create_long_press_indicator()
	
	# Obtener referencias a los nodos
	hex_grid = $HexGrid
	turn_manager = $TurnManager
	# La UI puede llamarse "UI" o "BattleUI" dependiendo de cómo se cargue
	ui = get_node_or_null("UI")
	if not ui:
		ui = get_node_or_null("BattleUI")
	
	Log.debug("Combat", "Got references - hex_grid: %s, turn_manager: %s, ui: %s" % [hex_grid != null, turn_manager != null, ui != null])
	if ui:
		Log.debug("UI", "UI node name: %s, class: %s" % [ui.name, ui.get_class()])
		Log.debug("UI", "UI has add_combat_message: %s" % ui.has_method("add_combat_message"))
		Log.debug("UI", "UI has show_facing_selector: %s" % ui.has_method("show_facing_selector"))
	
	# ============================================================
	# DETECTAR MODO MULTIPLAYER Y CONFIGURAR SISTEMA UNIFICADO
	# ============================================================
	var network_manager = get_node_or_null("/root/NetworkManager")
	Log.debug("Network", "NetworkManager exists: %s" % (network_manager != null))
	if network_manager:
		Log.debug("Network", "is_in_match(): %s, get_current_team(): %s, get_current_match_id(): %d" % [
			network_manager.is_in_match(),
			network_manager.get_current_team(),
			network_manager.get_current_match_id()
		])
	
	if network_manager and network_manager.is_in_match():
		is_multiplayer_mode = true
		use_unified_system = true  # Usar sistema unificado para multiplayer
		my_team = network_manager.get_current_team()
		match_id = network_manager.get_current_match_id()
		Log.info("Match", "*** MULTIPLAYER MODE ACTIVATED ***")
		Log.info("Match", "Team: %s, Match: %d, Opponent: %s" % [my_team, match_id, network_manager.get_opponent_name()])
		
		# Crear NetworkBattleClient
		network_battle_client = preload("res://scripts/network/network_battle_client.gd").new()
		network_battle_client.name = "NetworkBattleClient"
		add_child(network_battle_client)
		network_battle_client.setup(match_id, my_team)
		
		# NOTA: network_handler se configura en _setup_battle_components() via integrator
		
		# Crear adaptador de batalla unificado
		_setup_unified_battle_system()
		
		# Conectar señal de NetworkManager para cuando ambos jugadores desplieguen
		network_manager.battle_all_deployed.connect(_on_both_players_deployed)
	else:
		Log.info("Match", "*** SINGLEPLAYER MODE ***")
		is_multiplayer_mode = false
		# Para singleplayer, opcionalmente usar el sistema unificado
		# use_unified_system = true
		# _setup_unified_battle_system()
	
	# ==============================================================================
	# INICIALIZAR COMPONENTES REFACTORIZADOS (SOLID)
	# ==============================================================================
	_setup_battle_components()
	
	# Conectar señales del network_handler del integrator (multiplayer)
	if is_multiplayer_mode and battle_components and battle_components.network_handler:
		network_handler = battle_components.network_handler
		_connect_network_handler_signals()
	
	# Inicializar MechFactory
	mech_factory = MechFactory.new()
	mech_factory.configure(hex_grid, is_multiplayer_mode, my_team)
	
	# Inicializar Initiative Presenter
	initiative_presenter = BattleInitiativePresenter.new()
	initiative_presenter.setup(self, ui, initiative_screen_scene)
	initiative_presenter.initiative_complete.connect(_on_initiative_presenter_complete)
	
	# Inicializar Combat Result Presenter
	combat_result_presenter = CombatResultPresenterClass.new(ui, get_tree())
	
	# Crear y configurar cámara
	camera = Camera2D.new()
	camera.enabled = true
	camera.zoom = Vector2(0.8, 0.8)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTH_SPEED
	camera.add_to_group("cameras")
	add_child(camera)
	camera.make_current()
	
	# Actualizar la cámara en los componentes (se configura después de crear)
	if battle_components:
		battle_components.set_input_camera(camera)
	
	# Centrar cámara en el mapa
	if hex_grid:
		var map_center = hex_grid.hex_to_pixel(Vector2i(hex_grid.grid_width / 2, hex_grid.grid_height / 2))
		camera.position = map_center
	
	# Crear CanvasLayer para overlays que se dibuja ENCIMA de todo
	var overlay_canvas = CanvasLayer.new()
	overlay_canvas.layer = 100
	overlay_canvas.follow_viewport_enabled = true
	add_child(overlay_canvas)
	
	# Crear overlay layer que dibuja con _draw()
	overlay_layer = Node2D.new()
	overlay_layer.set_script(preload("res://scripts/battle_overlay.gd"))
	overlay_canvas.add_child(overlay_layer)
	overlay_layer.battle_scene = self
	
	# Crear capa de efectos de combate (proyectiles, impactos, etc.)
	# Debe estar por ENCIMA de mechs pero seguir coordenadas del mundo
	effects_layer = Node2D.new()
	effects_layer.name = "EffectsLayer"
	effects_layer.z_index = 500  # Por encima de mechs (que tienen z_index ~10-100)
	add_child(effects_layer)
	Log.info("Combat", "Effects layer created with z_index=%d" % effects_layer.z_index)
	
	# Conectar señales
	turn_manager.turn_changed.connect(_on_turn_changed)
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.unit_activated.connect(_on_unit_activated)
	
	# Inicializar sistema de IA (solo en singleplayer)
	if not is_multiplayer_mode:
		battle_ai = BattleAI.new()
		add_child(battle_ai)
	
	# Crear FacingSelector si la UI no lo tiene (ej: UI inline de battle_scene.tscn)
	if ui and not ui.has_method("show_facing_selector"):
		Log.debug("UI", "UI doesn't have facing_selector, creating one...")
		_create_facing_selector_for_ui()
	
	# ============================================================
	# INICIALIZAR SISTEMA DE TUTORIAL
	# ============================================================
	_setup_tutorial_system()
	
	# Iniciar la batalla con fase de despliegue
	_setup_battle()

# Variable para facing_selector creado por battle_scene (cuando UI no lo tiene)
var _local_facing_selector = null

# ==============================================================================
# SETUP DE COMPONENTES REFACTORIZADOS
# ==============================================================================

func _setup_battle_components():
	"""Inicializa y configura los componentes SOLID de batalla"""
	Log.info("Combat", "Setting up refactored battle components...")
	
	battle_components = BattleComponentsIntegrator.new()
	battle_components.setup(self, hex_grid, ui, turn_manager, {
		"is_multiplayer": is_multiplayer_mode,
		"my_team": my_team,
		"camera": camera,
		"network_client": network_battle_client,
		"match_id": match_id
	})
	
	# Configurar adaptador de batalla si existe
	if battle_adapter:
		battle_components.set_battle_adapter(battle_adapter)
	
	Log.info("Combat", "Battle components initialized successfully")


func _update_components_mech_references():
	"""Actualiza las referencias de mechs en los componentes"""
	if battle_components:
		battle_components.update_mech_references(player_mechs, enemy_mechs)


func _on_hex_clicked_from_component(_hex: Vector2i):
	"""Callback cuando el componente de cámara detecta un click en hex"""
	# Por ahora, delegar al sistema existente
	# Este será el punto de integración gradual
	pass


func _on_deployment_ended_from_component():
	"""Callback cuando el componente de deployment termina"""
	_end_deployment_phase()


func _sync_deployment_state_from_component():
	"""Sincroniza el estado de deployment desde el componente"""
	if battle_components and battle_components.deployment_manager:
		current_deploying_mech = battle_components.deployment_manager.get_current_deploying_mech()
		# valid_deployment_hexes ya no necesita sincronización - usamos battle_components.get_valid_deployment_hexes() directamente
		Log.debug("Combat", "Synced deployment state: mech=%s" % [
			current_deploying_mech.mech_name if current_deploying_mech else "null"
		])


func _continue_deployment_from_component():
	"""Callback para continuar el deployment después de colocar un mech"""
	# Pequeño delay para asegurar que el UI se actualizó
	await get_tree().create_timer(0.1).timeout
	
	# Sincronizar estado del componente
	_sync_deployment_state_from_component()
	
	if battle_components:
		# Si el componente ya no tiene más mechs, finalizará automáticamente
		# La señal deployment_phase_ended se emitirá
		battle_components.continue_deployment_after_placement()


func _create_facing_selector_for_ui():
	"""Crea un FacingSelector y añade los métodos necesarios a la UI"""
	var FacingSelectorScript = preload("res://scripts/ui/facing_selector.gd")
	_local_facing_selector = Control.new()
	_local_facing_selector.set_script(FacingSelectorScript)
	_local_facing_selector.name = "FacingSelector"
	ui.add_child(_local_facing_selector)
	
	# Conectar la señal del facing selector
	_local_facing_selector.facing_selected.connect(_on_local_facing_selected)
	
	# Añadir métodos wrapper a la UI usando un script extension
	ui.set_meta("facing_selector", _local_facing_selector)
	ui.set_meta("battle_scene_ref", self)
	
	Log.debug("UI", "FacingSelector created and added to UI")

func _on_local_facing_selected(facing: int):
	"""Maneja selección de facing desde el selector local"""
	on_facing_selected(facing)

func _ui_show_facing_selector(screen_pos: Vector2, hex: Vector2i = Vector2i(-1, -1)):
	"""Muestra el facing selector (wrapper)"""
	# Primero intentar usar el método de UI si existe
	if ui and ui.has_method("show_facing_selector"):
		ui.show_facing_selector(screen_pos, hex)
		return
	
	# Fallback al selector local
	if _local_facing_selector:
		if hex != Vector2i(-1, -1):
			_local_facing_selector.set_target_hex(hex, self)
		_local_facing_selector.show_at_position(screen_pos, -1, 99)

func _ui_show_facing_selector_with_current(screen_pos: Vector2, current_facing: int, available_mp: int, hex: Vector2i = Vector2i(-1, -1)):
	"""Muestra el facing selector con facing actual (wrapper)"""
	if _local_facing_selector:
		if hex != Vector2i(-1, -1):
			_local_facing_selector.set_target_hex(hex, self)
		_local_facing_selector.show_at_position(screen_pos, current_facing, available_mp)

func _ui_hide_facing_selector():
	"""Oculta el facing selector (wrapper)"""
	if _local_facing_selector:
		_local_facing_selector.visible = false

func _ui_show_facing_selector_tutorial(screen_pos: Vector2, allowed_facing: int, hex: Vector2i = Vector2i(-1, -1)):
	"""Muestra el facing selector en modo tutorial con solo una dirección habilitada"""
	# Primero intentar usar el método de UI si existe
	if ui and ui.has_method("show_facing_selector_tutorial"):
		ui.show_facing_selector_tutorial(screen_pos, allowed_facing, hex)
		return
	
	# Fallback al selector local
	if _local_facing_selector and _local_facing_selector.has_method("show_tutorial_facing"):
		_local_facing_selector.show_tutorial_facing(screen_pos, allowed_facing, hex)
	elif _local_facing_selector:
		# Si no tiene el método de tutorial, usar el normal
		if hex != Vector2i(-1, -1):
			_local_facing_selector.set_target_hex(hex, self)
		_local_facing_selector.show_at_position(screen_pos, -1, 99)

func _ui_is_facing_selector_visible() -> bool:
	"""Verifica si el facing selector está visible (wrapper)"""
	return _local_facing_selector and _local_facing_selector.visible

# ============================================================
# SISTEMA UNIFICADO DE BATALLA
# ============================================================

func _setup_unified_battle_system():
	"""Configura el sistema de batalla unificado"""
	Log.info("Combat", "Setting up unified battle system...")
	
	battle_adapter = BattleSceneAdapterClass.new()
	battle_adapter.name = "BattleAdapter"
	add_child(battle_adapter)
	
	var config = {
		"map_size": Vector2i(hex_grid.grid_width, hex_grid.grid_height)
	}
	
	if is_multiplayer_mode:
		config["battle_client"] = network_battle_client
		config["match_id"] = match_id
		config["local_peer_id"] = multiplayer.get_unique_id()
		config["local_team"] = my_team
	
	var success = battle_adapter.setup(self, is_multiplayer_mode, config)
	if success:
		Log.info("Combat", "Unified battle system initialized successfully")
		_connect_unified_signals()
	else:
		push_error("[BATTLE] Failed to initialize unified battle system")
		use_unified_system = false

func _connect_unified_signals():
	"""Conecta las señales del sistema unificado"""
	if not battle_adapter:
		return
	
	battle_adapter.deployment_phase_started.connect(_on_unified_deployment_started)
	battle_adapter.deployment_complete.connect(_on_unified_deployment_complete)
	battle_adapter.initiative_rolled.connect(_on_unified_initiative_rolled)
	battle_adapter.movement_phase_started.connect(_on_unified_movement_started)
	battle_adapter.turn_ended.connect(_on_unified_turn_ended)

func _on_unified_deployment_started():
	"""Despliegue iniciado desde sistema unificado"""
	Log.info("Combat", "Deployment phase started")
	deployment_phase = true
	if battle_components:
		battle_components.set_input_deployment_phase(true)
	if is_multiplayer_mode:
		valid_deployment_hexes = battle_adapter.get_deployment_zone(my_team)
	update_overlays()

func _on_unified_deployment_complete():
	"""Despliegue completado desde sistema unificado"""
	Log.info("Combat", "Deployment complete")
	deployment_phase = false
	if battle_components:
		battle_components.set_input_deployment_phase(false)
	valid_deployment_hexes.clear()
	update_overlays()

func _on_unified_initiative_rolled(player_roll: int, enemy_roll: int, winner: String):
	"""Iniciativa tirada desde sistema unificado"""
	Log.info("Combat", "Initiative: Player %d vs Enemy %d - %s wins" % [player_roll, enemy_roll, winner])
	initiative_data_stored = {
		"player_total": player_roll,
		"enemy_total": enemy_roll,
		"winner": winner
	}

func _on_unified_movement_started(mech_node):
	"""Movimiento iniciado para un mech desde sistema unificado"""
	Log.info("Movement", "Movement started for: %s" % mech_node.mech_name)
	selected_unit = mech_node
	is_my_turn = (mech_node in player_mechs) if not is_multiplayer_mode else (battle_adapter.get_local_team() == mech_node.get_meta("team", ""))
	
	if is_my_turn:
		_show_active_mech_indicator(mech_node)
		# Calcular hexes alcanzables
		var move_type = GameEnums.MovementType.WALK
		reachable_hexes = MovementSystem.get_reachable_hexes(mech_node.hex_position, mech_node.walk_mp, move_type, hex_grid, mech_node)
		if ui and ui.has_method("show_unit_info"):
			ui.show_unit_info(mech_node)
		update_overlays()

func _on_unified_turn_ended():
	"""Turno terminado desde sistema unificado"""
	Log.info("Combat", "Turn ended")

## Registra un mech con el sistema unificado (llamar después de crear el mech)
func _register_mech_with_unified_system(mech: Mech, team: String):
	"""Registra un mech node con el sistema de batalla unificado"""
	if use_unified_system and battle_adapter:
		var state_id = battle_adapter.register_mech(mech, team)
		mech.set_meta("battle_state_id", state_id)
		Log.debug("Mech", "Registered mech %s with state ID: %s" % [mech.mech_name, state_id])

func _process(delta):
	# Procesar delta en componentes si están activos
	if battle_components:
		battle_components.process_input_delta(delta)
	
	# Actualizar overlays pulsantes del tutorial
	if is_tutorial_mode and battle_components and battle_components.overlay_manager:
		if battle_components.overlay_manager.needs_continuous_update():
			battle_components.overlay_manager.update_and_render()
	
	# Decrementar cooldown de interacción con UI
	if ui_interaction_cooldown > 0:
		ui_interaction_cooldown -= delta
	
	# El indicador de long press gestiona su propio estado en _process/_draw
	# (ver scripts/ui/long_press_indicator.gd)


# ==============================================================================
# INITIATIVE SYSTEM - Delegado a BattleInitiativePresenter
# ==============================================================================

func _create_initiative_screen(my_mechs: Array = [], opponent_mechs: Array = []) -> Node:
	"""Helper: Crea y configura la pantalla de iniciativa - delega al presenter"""
	_update_initiative_presenter_mechs()
	return initiative_presenter.create_initiative_screen(my_mechs, opponent_mechs)


func _update_initiative_presenter_mechs() -> void:
	"""Actualiza las referencias de mechs en el presenter de iniciativa"""
	if initiative_presenter:
		initiative_presenter.set_mechs(player_mechs, enemy_mechs)


func show_initiative_screen():
	"""Muestra pantalla de iniciativa (singleplayer)"""
	# En tutorial, verificar si está bloqueada
	if is_tutorial_mode:
		var tutorial_mgr = get_node_or_null("/root/TutorialManager")
		if tutorial_mgr and tutorial_mgr.is_initiative_blocked():
			Log.debug("Tutorial", "Initiative screen blocked by tutorial")
			return
	
	_update_initiative_presenter_mechs()
	initiative_presenter.show_initiative_screen()


func show_initiative_screen_multiplayer(server_result: Dictionary):
	"""Muestra la pantalla de iniciativa con los resultados del servidor"""
	_update_initiative_presenter_mechs()
	initiative_presenter.show_initiative_screen_with_server_result(server_result)


func _show_initiative_screen_multiplayer():
	"""Muestra la pantalla de iniciativa para un nuevo turno en multiplayer"""
	_update_initiative_presenter_mechs()
	initiative_presenter.show_initiative_screen_multiplayer_new_turn()


func _on_initiative_presenter_complete(data: Dictionary, is_first_battle: bool) -> void:
	"""Callback cuando el presenter de iniciativa completa"""
	initiative_data_stored = data
	
	# Notificar al tutorial que la iniciativa se completó
	if is_tutorial_mode:
		_notify_tutorial("initiative_completed", data)
	
	if is_first_battle and not battle_started:
		# Iniciar el sistema de turnos
		turn_manager.start_battle(player_mechs, enemy_mechs)
		
		# Inicializar el tracker de estadísticas
		battle_stats_tracker = BattleStatsTrackerClass.new()
		add_child(battle_stats_tracker)
		# Registrar todos los mechs
		for mech in player_mechs:
			battle_stats_tracker.register_mech(mech.mech_name, true)
		for mech in enemy_mechs:
			battle_stats_tracker.register_mech(mech.mech_name, false)
		
		# Configurar el sistema de IA mejorado
		if battle_ai:
			battle_ai.setup(hex_grid, player_mechs, self)
			# Aplicar dificultad desde el MechBayManager
			var mech_bay_manager = get_node_or_null("/root/MechBayManager")
			if mech_bay_manager and mech_bay_manager.has_meta("ai_difficulty"):
				var diff = mech_bay_manager.get_meta("ai_difficulty")
				battle_ai.set_difficulty(diff)
				Log.info("AI", "Applied difficulty from team setup: %d" % diff)
			else:
				battle_ai.set_difficulty(ai_difficulty)
		
		# Actualizar visibilidad inicial
		update_mech_visibility()
		
		battle_started = true
		if battle_components:
			battle_components.set_input_battle_started(true)
		
		# Mostrar mensaje de ayuda para inspección de mechs
		if ui and ui.has_method("add_combat_message"):
			ui.add_combat_message("💡 TIP: Long press on a mech to inspect its armor and status", Color(0.7, 0.9, 1.0))
	else:
		# Turno posterior: usar los datos de iniciativa con el turn_manager
		if turn_manager:
			turn_manager.use_precalculated_initiative(data)


func get_stored_initiative() -> Dictionary:
	if initiative_presenter:
		return initiative_presenter.get_stored_initiative()
	return initiative_data_stored


func clear_initiative_data():
	if initiative_presenter:
		initiative_presenter.clear_initiative_data()
	initiative_data_stored = {}


# ==============================================================================
# SISTEMA DE TUTORIAL
# ==============================================================================

func _setup_tutorial_system():
	"""Configura el sistema de tutorial si está activo"""
	# Solo en singleplayer
	if is_multiplayer_mode:
		return
	
	# Verificar si TutorialManager existe
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if not tutorial_mgr:
		Log.debug("Tutorial", "TutorialManager not found - tutorial disabled")
		return
	
	# Verificar si estamos en modo tutorial (desde main_menu)
	var mech_bay_manager = get_node_or_null("/root/MechBayManager")
	if mech_bay_manager and mech_bay_manager.has_meta("is_tutorial"):
		is_tutorial_mode = mech_bay_manager.get_meta("is_tutorial")
	
	if not is_tutorial_mode:
		Log.debug("Tutorial", "Not in tutorial mode")
		return
	
	Log.info("Tutorial", "Tutorial mode activated - using controlled battle flow!")
	
	# Crear el popup de hints
	tutorial_hint_popup = TutorialHintPopupClass.new()
	tutorial_hint_popup.name = "TutorialHintPopup"
	tutorial_hint_popup.process_mode = Node.PROCESS_MODE_ALWAYS  # Funciona aunque el juego esté pausado
	add_child(tutorial_hint_popup)
	
	# Forzar AI a EASY durante el tutorial (aunque realmente estará controlada)
	if battle_ai:
		battle_ai.set_difficulty(BattleAI.Difficulty.EASY)
		Log.info("Tutorial", "AI forced to EASY difficulty for tutorial")
	
	# Iniciar el tutorial con el nuevo sistema controlado
	# El TutorialManager creará el TutorialBattleController que maneja todo
	tutorial_mgr.start_tutorial(self)


func _on_tutorial_hint_requested(hint_data: Dictionary):
	"""Muestra un hint del tutorial"""
	if tutorial_hint_popup:
		tutorial_hint_popup.show_hint(hint_data)
		Log.debug("Tutorial", "Showing hint: %s" % hint_data.get("id", "unknown"))


func _on_tutorial_completed():
	"""Callback cuando el tutorial se completa"""
	Log.info("Tutorial", "Tutorial completed!")
	is_tutorial_mode = false
	
	# Limpiar metadata
	var mech_bay_manager = get_node_or_null("/root/MechBayManager")
	if mech_bay_manager and mech_bay_manager.has_meta("is_tutorial"):
		mech_bay_manager.remove_meta("is_tutorial")


func _notify_tutorial(event_name: String, data: Variant = null):
	"""Notifica un evento al sistema de tutorial"""
	if not is_tutorial_mode:
		return
	
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if not tutorial_mgr:
		return
	
	match event_name:
		"movement_type_selected":
			tutorial_mgr.notify_movement_type_selected(data as String)
		"movement_completed":
			tutorial_mgr.notify_movement_completed(data as Vector2i)
		"facing_selected":
			tutorial_mgr.notify_facing_selected(data as int)
		"weapon_attack_phase":
			tutorial_mgr.notify_weapon_attack_phase()
		"target_selected":
			tutorial_mgr.notify_target_selected()
		"weapons_selected":
			tutorial_mgr.notify_weapons_selected()
		"weapon_fired":
			tutorial_mgr.notify_weapon_fired()
		"physical_attack_completed":
			tutorial_mgr.notify_physical_attack_completed()
		"initiative_completed":
			tutorial_mgr.notify_initiative_completed(data as Dictionary)


func _is_tutorial_hex_allowed(hex: Vector2i) -> bool:
	"""Verifica si un hex está permitido en el tutorial"""
	if not is_tutorial_mode:
		return true
	
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		return tutorial_mgr.is_hex_allowed(hex)
	return true


func _is_tutorial_facing_allowed(facing: int) -> bool:
	"""Verifica si un facing está permitido en el tutorial"""
	if not is_tutorial_mode:
		return true
	
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		return tutorial_mgr.is_facing_allowed(facing)
	return true


func _can_tutorial_skip_movement() -> bool:
	"""Verifica si se puede saltar el movimiento en el tutorial"""
	if not is_tutorial_mode:
		return true
	
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		return tutorial_mgr.can_skip_movement()
	return true


func _can_tutorial_skip_attack() -> bool:
	"""Verifica si se puede saltar el ataque en el tutorial"""
	if not is_tutorial_mode:
		return true
	
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		return tutorial_mgr.can_skip_attack()
	return true


# DEPRECATED: Old trigger system - keeping for backward compatibility but does nothing
func _trigger_tutorial_event(_event_name: String, _data: Dictionary = {}):
	"""DEPRECATED: Use _notify_tutorial instead"""
	pass


func _setup_battle():
	# Definir zonas de despliegue
	_setup_deployment_zones()
	
	# En multiplayer, determinar qué lance crea este cliente
	var should_create_player_mechs = true
	var should_create_enemy_mechs = true
	
	Log.debug("Match", "is_multiplayer_mode: %s, my_team: '%s'" % [is_multiplayer_mode, my_team])
	
	if is_multiplayer_mode:
		Log.info("Match", "Multiplayer mode detected!")
		if my_team == "player":
			should_create_enemy_mechs = false
			Log.debug("Match", "I am 'player' - will create player mechs, NOT enemy mechs")
		elif my_team == "enemy":
			should_create_player_mechs = false
			Log.debug("Match", "I am 'enemy' - will create enemy mechs, NOT player mechs")
	else:
		Log.debug("Match", "Singleplayer mode - creating both player and enemy mechs")
	
	# Cargar y crear mechs usando LanceData helper
	var loadout_manager = get_node_or_null("/root/SelectedLoadoutManager")
	var mech_bay_manager = get_node_or_null("/root/MechBayManager")
	
	# En modo tutorial, usar los mechs del tutorial
	if is_tutorial_mode:
		var tutorial_mgr = get_node_or_null("/root/TutorialManager")
		if tutorial_mgr:
			Log.info("Tutorial", "Loading tutorial mechs (Atlas vs Hunchback)")
			var player_mech_data = tutorial_mgr.get_tutorial_player_mech()
			var enemy_mech_data = tutorial_mgr.get_tutorial_enemy_mech()
			
			mechs_to_deploy.append(_create_mech_for_deployment(player_mech_data, "player"))
			mechs_to_deploy.append(_create_mech_for_deployment(enemy_mech_data, "enemy"))
	else:
		# Carga normal de mechs
		if should_create_player_mechs:
			var player_mechs_data = LanceData.load_player_lance_data(loadout_manager, mech_bay_manager, mech_factory)
			for mech_data in player_mechs_data:
				mechs_to_deploy.append(_create_mech_for_deployment(mech_data, "player"))
		
		if should_create_enemy_mechs:
			var enemy_mechs_data = LanceData.load_enemy_lance_data(mech_bay_manager)
			for mech_data in enemy_mechs_data:
				mechs_to_deploy.append(_create_mech_for_deployment(mech_data, "enemy"))
	
	# Iniciar fase de despliegue
	if is_multiplayer_mode:
		Log.info("Network", "Multiplayer mode - notifying server we are ready...")
		if ui:
			ui.add_combat_message("", Color.WHITE)
			ui.add_combat_message("🌐 MULTIPLAYER BATTLE", Color.CYAN)
			ui.add_combat_message("Waiting for opponent...", Color.YELLOW)
			ui.add_combat_message("", Color.WHITE)
		_notify_server_ready()
	else:
		_start_deployment_phase()


func _setup_deployment_zones():
	"""Genera las zonas de despliegue para cada equipo"""
	deployment_zones["player"] = []
	deployment_zones["enemy"] = []
	
	for x in range(hex_grid.grid_width):
		for y in range(hex_grid.grid_height):
			var hex_pos = Vector2i(x, y)
			var terrain = hex_grid.get_terrain(hex_pos)
			
			# No permitir despliegue en agua
			if terrain == TerrainType.Type.WATER:
				continue
			
			# Zona del jugador (sur del mapa) - últimas 4 filas
			if y >= hex_grid.grid_height - 4:
				deployment_zones["player"].append(hex_pos)
			# Zona enemiga (norte del mapa) - primeras 4 filas
			elif y < 4:
				deployment_zones["enemy"].append(hex_pos)


func _notify_server_ready():
	"""Notifica al servidor que este cliente está listo en la escena de batalla"""
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager and match_id != -1:
		Log.info("Network", "Sending server_client_ready for match %d" % match_id)
		network_manager.rpc_id(1, "server_client_ready", match_id)

func _create_mech_for_deployment(mech_data: Dictionary, team: String) -> Mech:
	"""Crea un mech pero no lo coloca en el mapa todavía"""
	# Delegar al factory para centralizar la lógica de creación
	if mech_factory:
		return mech_factory.create_for_deployment(mech_data, team)
	
	# Fallback si factory no está disponible (no debería pasar)
	Log.warning("Mech", "MechFactory not available, using legacy creation")
	var mech = Mech.new()
	mech.mech_name = mech_data.get("name", "Unknown")
	mech.pilot_name = "Player" if team == "player" else "Enemy"
	mech.tonnage = mech_data.get("tonnage", 50)
	mech.walk_mp = mech_data.get("walk_mp", 4)
	mech.run_mp = mech_data.get("run_mp", 6)
	mech.jump_mp = mech_data.get("jump_mp", 0)
	mech.current_movement = mech.walk_mp
	mech.is_player_controlled = (team == "player")
	if mech_data.has("armor"):
		mech.armor = mech_data["armor"].duplicate(true)
	if mech_data.has("weapons"):
		mech.weapons = mech_data["weapons"].duplicate(true)
	mech.z_index = 10
	mech.set_meta("team", team)
	return mech

func _start_deployment_phase():
	"""Inicia la fase de despliegue"""
	deployment_phase = true
	if battle_components:
		battle_components.set_input_deployment_phase(true)
	
	# Delegación al componente
	if battle_components:
		# Pasar los mechs al componente antes de iniciar
		battle_components.queue_mechs_for_deployment(mechs_to_deploy)
		# Configurar zonas de deployment
		battle_components.set_deployment_zones(deployment_zones)
		# Configurar battle_adapter si existe
		if battle_adapter:
			battle_components.set_battle_adapter(battle_adapter)
		# Iniciar la fase - esto llamará internamente a deploy_next_mech
		battle_components.start_deployment_phase()
		# Sincronizar estado DESPUÉS de que el componente haya procesado
		# El componente emitirá overlays_update_requested que sincronizará el estado
		_sync_deployment_state_from_component()

func _deploy_next_mech():
	"""Selecciona el siguiente mech para desplegar"""
	# Delegación al componente
	if battle_components:
		# El componente maneja internamente toda la lógica
		# Sincronizamos estado desde el componente
		if battle_components.is_in_deployment_phase():
			current_deploying_mech = battle_components.deployment_manager.get_current_deploying_mech()
			valid_deployment_hexes = battle_components.get_valid_deployment_hexes()


func _deploy_ai_mech():
	"""Despliega un mech de la IA automáticamente - delega al componente"""
	# En tutorial, si ya forzamos el deploy del enemigo, ignorar
	if tutorial_enemy_already_deployed:
		Log.debug("Tutorial", "_deploy_ai_mech: Skipping - enemy already deployed by tutorial")
		return
	
	if not battle_components:
		push_error("No battle_components for AI deployment")
		return
	
	var result = battle_components.deploy_ai_mech()
	if result.is_empty():
		return
	
	var deploy_hex = result.hex
	var facing = result.facing
	var mech = result.mech
	var enemy_remaining = result.remaining
	
	# Mostrar mensaje UI
	if ui:
		var total_enemy_mechs = enemy_mechs.size() + enemy_remaining + 1
		var deployed_count = total_enemy_mechs - enemy_remaining - 1
		ui.add_combat_message("🔴 ENEMY DEPLOYMENT [%d/%d]: %s" % [deployed_count + 1, total_enemy_mechs, mech.mech_name], Color.RED)
		ui.add_combat_message("  Position: [%d, %d], Facing: %s" % [deploy_hex.x, deploy_hex.y, FacingSystem.get_facing_name(facing)], Color.ORANGE)
	
	_place_mech(mech, deploy_hex, facing)
	
	# Continuar con el siguiente mech después de un delay
	await get_tree().create_timer(0.5).timeout
	battle_components.deployment_manager.deploy_next_mech()


func _place_mech(mech: Mech, hex: Vector2i, facing: int):
	"""Coloca un mech en el mapa"""
	Log.debug("Mech", "Placing %s at %s with facing %d" % [mech.mech_name, hex, facing])
	mech.hex_position = hex
	mech.facing = facing
	Log.debug("Mech", "After assignment, mech.facing = %d" % mech.facing)
	
	var team = mech.get_meta("team")
	
	# En modo multijugador, enviar al servidor ANTES de colocar localmente
	if is_multiplayer_mode and network_battle_client and team == my_team:
		# Construir datos COMPLETOS del mech para enviar al servidor
		var mech_data = {
			"name": mech.mech_name,
			"tonnage": mech.tonnage,
			"walk_mp": mech.walk_mp,
			"run_mp": mech.run_mp,
			"jump_mp": mech.jump_mp,
			"armor": mech.armor.duplicate(true) if mech.armor else {},
			"internal_structure": mech.structure.duplicate(true) if mech.structure else {},
			"weapons": mech.weapons.duplicate(true) if mech.weapons else [],
			"equipment": mech.equipment.duplicate(true) if mech.equipment else [],
			"critical_slots": mech.critical_slots.duplicate(true) if mech.critical_slots else {},
			"heat_capacity": mech.heat_capacity,
			"heat_dissipation": mech.heat_dissipation,
			"gunnery_skill": mech.pilot_skill,
			"piloting_skill": mech.piloting_skill
		}
		Log.debug("Network", "Sending mech %s to server at [%d,%d]" % [mech.mech_name, hex.x, hex.y])
		Log.debug("Network", "  Weapons: %d, Equipment: %d" % [mech_data["weapons"].size(), mech_data["equipment"].size()])
		if mech_data["weapons"].size() > 0:
			Log.debug("Network", "  Weapon list: %s" % str(mech_data["weapons"].map(func(w): return w.get("name", "?"))))
		else:
			Log.warning("Network", "No weapons in mech data!")
			Log.debug("Network", "mech.weapons = %s" % str(mech.weapons))
		network_battle_client.request_deploy_mech(mech_data, hex, facing)
		# En multijugador, el mech se añadirá cuando el servidor confirme via _on_net_mech_deployed
		# Pero también lo añadimos localmente para feedback inmediato
	
	add_child(mech)
	mech.visible = true  # Asegurar que sea visible
	hex_grid.set_unit(hex, mech)
	mech.update_visual_position(hex_grid)
	mech.update_facing_visual()  # Actualizar sprite según facing
	
	# Registrar con sistema unificado
	_register_mech_with_unified_system(mech, team)
	
	# Añadir a la lista correcta y mostrar confirmación
	# IMPORTANTE: Verificar que no esté ya en la lista para evitar duplicados
	if team == "player" or team == my_team:
		if mech not in player_mechs:
			player_mechs.append(mech)
		if ui:
			ui.add_combat_message("✓ %s deployed at [%d, %d], facing %s" % [
				mech.mech_name, 
				hex.x, 
				hex.y, 
				FacingSystem.get_facing_name(facing)
			], Color.GREEN)
			ui.add_combat_message("", Color.WHITE)
	else:
		if mech not in enemy_mechs:
			enemy_mechs.append(mech)
	
	# Actualizar referencias en componentes refactorizados
	_update_components_mech_references()
	
	# Actualizar overlays inmediatamente para mostrar el mech recién colocado
	update_overlays()

func _on_my_deployment_complete():
	"""Llamado en multiplayer cuando este cliente termina de desplegar todos sus mechs"""
	deployment_phase = false
	if battle_components:
		battle_components.set_input_deployment_phase(false)
	valid_deployment_hexes.clear()
	current_deploying_mech = null
	
	if ui:
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("╔══════════════════════════════════════════╗", Color.CYAN)
		ui.add_combat_message("║   ✓ YOUR DEPLOYMENT COMPLETE!           ║", Color.CYAN)
		ui.add_combat_message("║   Waiting for opponent...               ║", Color.YELLOW)
		ui.add_combat_message("╚══════════════════════════════════════════╝", Color.CYAN)
		ui.add_combat_message("", Color.WHITE)
	
	# Notificar al servidor que terminamos
	# El servidor esperará a que AMBOS jugadores terminen antes de iniciar iniciativa
	if network_battle_client and network_battle_client.has_method("notify_deployment_complete"):
		network_battle_client.notify_deployment_complete()
	
	# NO llamar update_overlays() aquí - los overlays ya se limpiaron al cambiar deployment_phase
	# y queremos mantener el último estado visible

func _on_both_players_deployed():
	"""Llamado por el servidor cuando AMBOS jugadores terminaron de desplegar"""
	Log.info("Match", "Both players deployed - showing initiative screen!")
	
	if ui:
		ui.add_combat_message("╔══════════════════════════════════════════╗", Color.GREEN)
		ui.add_combat_message("║    ✓ ALL FORCES DEPLOYED!               ║", Color.GREEN)
		ui.add_combat_message("╚══════════════════════════════════════════╝", Color.GREEN)
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("⚔️  Preparing for combat...", Color.YELLOW)
		ui.add_combat_message("🎲 Roll for initiative!", Color.GOLD)
	
	# Mostrar pantalla de iniciativa interactiva
	# Los jugadores deben presionar Roll y el servidor sincronizará los resultados
	show_initiative_screen()

func _end_deployment_phase():
	"""Finaliza la fase de despliegue e inicia la batalla"""
	deployment_phase = false
	if battle_components:
		battle_components.set_input_deployment_phase(false)
	valid_deployment_hexes.clear()
	current_deploying_mech = null
	
	if ui:
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("╔══════════════════════════════════════════╗", Color.GREEN)
		ui.add_combat_message("║     ✓ DEPLOYMENT COMPLETE!              ║", Color.GREEN)
		ui.add_combat_message("╚══════════════════════════════════════════╝", Color.GREEN)
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("📊 BATTLE ROSTER:", Color.CYAN)
		ui.add_combat_message("  ► YOUR LANCE: %d mechs deployed" % player_mechs.size(), Color.LIGHT_BLUE)
		for mech in player_mechs:
			ui.add_combat_message("    • %s (%d tons)" % [mech.mech_name, mech.tonnage], Color.WHITE)
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("  ► ENEMY FORCE: %d mechs detected" % enemy_mechs.size(), Color.ORANGE_RED)
		for mech in enemy_mechs:
			ui.add_combat_message("    • %s (%d tons)" % [mech.mech_name, mech.tonnage], Color.RED)
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("⚔️  Preparing for combat...", Color.YELLOW)
		ui.add_combat_message("🎲 Rolling for initiative...", Color.GOLD)
		ui.add_combat_message("", Color.WHITE)
	
	# Asegurar que selected_unit apunte al primer mech del jugador
	if player_mechs.size() > 0:
		selected_unit = player_mechs[0]
	
	update_overlays()
	
	# Mostrar pantalla de iniciativa DESPUÉS del despliegue
	show_initiative_screen()

## Crea un mech desde datos del MechBayManager
func _create_player_mech_from_data(mech_data: Dictionary, hex_position: Vector2i) -> Mech:
	"""Crea un mech del jugador y lo registra en el grid"""
	var mech = mech_factory.create_player_mech(mech_data, hex_position)
	add_child(mech)
	player_mechs.append(mech)
	hex_grid.set_unit(mech.hex_position, mech)
	mech.update_visual_position(hex_grid)
	return mech

## Crea un mech enemigo desde datos del MechBayManager
func _create_enemy_mech_from_data(mech_data: Dictionary, hex_position: Vector2i) -> Mech:
	"""Crea un mech enemigo y lo registra en el grid"""
	var mech = mech_factory.create_enemy_mech(mech_data, hex_position)
	add_child(mech)
	enemy_mechs.append(mech)
	hex_grid.set_unit(mech.hex_position, mech)
	mech.update_visual_position(hex_grid)
	return mech

func _input(event):
	# === DELEGACIÓN A COMPONENTES ===
	# El componente BattleInputRouter maneja todo el input de forma modular
	if use_component_input and battle_components:
		battle_components.process_input(event)

# ==============================================================================
# FUNCIONES DE INPUT MOVIDAS A BattleInputRouter
# ==============================================================================
# _is_click_over_ui, _get_visible_buttons, _is_truly_visible, _handle_camera_input
# fueron movidas al componente BattleInputRouter para seguir principio SOLID


func start_ignore_click_timer(duration_ms: int = 200) -> void:
	"""Ignora clicks durante duration_ms milisegundos usando un temporizador asincrónico"""
	ignore_next_click = true
	# No bloqueamos la ejecución; el await solo limpia el flag después del timeout
	await get_tree().create_timer(duration_ms / 1000.0).timeout
	ignore_next_click = false

func _handle_hex_clicked(hex: Vector2i):
	# Debounce basado en tiempo para evitar doble procesamiento en Android
	var current_time = Time.get_ticks_msec()
	if current_time - _last_hex_click_time < HEX_CLICK_DEBOUNCE_MS:
		Log.debug("Input", "Debounce - ignoring click (delta=%dms)" % (current_time - _last_hex_click_time))
		return
	_last_hex_click_time = current_time
	
	if not hex_grid.is_valid_hex(hex):
		return
	
	# Manejar fase de despliegue
	if deployment_phase:
		_handle_deployment_click(hex)
		return
	
	# En modo multijugador, solo permitir input si es mi turno
	if is_multiplayer_mode and not is_my_turn:
		Log.debug("Network", "Not my turn, ignoring click")
		if ui and ui.has_method("add_combat_message"):
			ui.add_combat_message("Wait for your turn!", Color.YELLOW)
		return

# (helper debouncer implemented once above with await)
	
	match current_state:
		GameEnums.GameState.MOVING:
			_handle_movement_click(hex)
		GameEnums.GameState.TARGETING:
			_handle_targeting_click(hex)
		GameEnums.GameState.WEAPON_ATTACK:
			_handle_weapon_attack_click(hex)
		GameEnums.GameState.PHYSICAL_TARGETING:
			_handle_physical_targeting_click(hex)

func _handle_deployment_click(hex: Vector2i):
	"""Maneja clics durante la fase de despliegue"""
	
	# Delegación al componente
	if battle_components:
		# Asegurarse de que el estado esté sincronizado
		_sync_deployment_state_from_component()
		
		var _hex_pixel = hex_grid.hex_to_pixel(hex, true) + hex_grid.global_position
		var _screen_pos = _hex_pixel
		if camera:
			_screen_pos = _hex_pixel - camera.position + get_viewport().get_visible_rect().size / 2
		
		# Debug
		var component_valid_hexes = battle_components.get_valid_deployment_hexes()
		Log.debug("Input", "[COMPONENT] hex=%s, deployment_phase=%s, current_mech=%s, valid_hexes=%d" % [
			hex,
			battle_components.is_in_deployment_phase(),
			current_deploying_mech.mech_name if current_deploying_mech else "null",
			component_valid_hexes.size()
		])
		
		if battle_components.handle_deployment_click(hex, _screen_pos):
			# El componente procesó el click (mostró facing selector)
			return
		else:
			# Click en hex inválido - verificar por qué
			if hex not in component_valid_hexes:
				if ui:
					ui.add_combat_message("Invalid deployment location", Color.RED)
			elif hex_grid.get_unit(hex):
				if ui:
					ui.add_combat_message("Hex already occupied", Color.RED)
			return

var _cached_hex_screen_pos: Dictionary = {}
var _camera_last_pos: Vector2 = Vector2.ZERO

func get_screen_position_for_hex(hex: Vector2i) -> Vector2:
	"""Convierte una posición hex a coordenadas de pantalla"""
	# Optimización: Cachear si la cámara no se movió
	var current_cam_pos = camera.position if camera else Vector2.ZERO
	if current_cam_pos != _camera_last_pos:
		_cached_hex_screen_pos.clear()
		_camera_last_pos = current_cam_pos
	
	var cache_key = str(hex)
	if _cached_hex_screen_pos.has(cache_key):
		return _cached_hex_screen_pos[cache_key]
	
	var hex_pixel = hex_grid.hex_to_pixel(hex, true) + hex_grid.global_position
	var screen_pos = hex_pixel
	if camera:
		screen_pos = hex_pixel - camera.position + get_viewport().get_visible_rect().size / 2
	
	_cached_hex_screen_pos[cache_key] = screen_pos
	return screen_pos

func on_facing_selected(facing: int):
	"""Llamado cuando el jugador selecciona una orientación"""
	
	# Manejar cancelación (facing = -1)
	if facing == -1:
		Log.debug("UI", "Facing selection cancelled")
		selected_hex = Vector2i(-1, -1)
		if ui and ui.has_method("hide_facing_selector"):
			ui.hide_facing_selector()
		elif _local_facing_selector:
			_ui_hide_facing_selector()
		
		# Si estamos en modo Turn Only, volver al selector de movimientos
		if pending_turn_only and selected_unit:
			Log.debug("Movement", "Turn only cancelled - reopening movement selector")
			pending_turn_only = false
			pending_movement_selection = true
			if ui and ui.has_method("show_movement_type_selector"):
				ui.show_movement_type_selector(selected_unit)
			return
		
		# En deployment, no hacer nada más - permitir que el jugador elija otro hex
		return
	
	if deployment_phase and current_deploying_mech and selected_hex != Vector2i(-1, -1):
		# Estamos en fase de despliegue - delegar al componente
		if battle_components:
			if battle_components.on_deployment_facing_selected(facing, selected_hex):
				# El componente procesó, limpiar selector
				if ui and ui.has_method("hide_facing_selector"):
					ui.hide_facing_selector()
				elif _local_facing_selector:
					_ui_hide_facing_selector()
				selected_hex = Vector2i(-1, -1)
				
				# Notificar al tutorial
				_notify_tutorial("facing_selected", facing)
				return
	elif pending_turn_only and selected_unit:
		# En multiplayer usar is_player_controlled, en singleplayer usar player_mechs
		var can_control_turn_only = selected_unit.is_player_controlled if is_multiplayer_mode else (selected_unit in player_mechs)
		if not can_control_turn_only:
			return
		# Estamos en modo Turn Only - girar sin moverse
		Log.debug("Movement", "Turn only: %d -> %d" % [selected_unit.facing, facing])
		
		var rotation_cost = MovementSystem.get_rotation_cost(selected_unit.facing, facing)
		
		# En multiplayer, enviar rotación al servidor
		if is_multiplayer_mode and network_battle_client:
			var mech_id = selected_unit.get_meta("network_id", -1)
			network_battle_client.request_rotate(mech_id, facing)
			# La confirmación llegará via _on_net_mech_rotated
		else:
			# Singleplayer - aplicar localmente
			selected_unit.facing = facing
			selected_unit.update_visual_position(hex_grid)
			if selected_unit.has_method("update_facing_visual"):
				selected_unit.update_facing_visual()
		
		if ui:
			ui.add_combat_message("  → New facing: %s (Cost: %d MP)" % [FacingSystem.get_facing_name(facing), rotation_cost], Color.CYAN)
			ui.update_unit_info(selected_unit)
		
		pending_turn_only = false
		
		# Finalizar activación
		await get_tree().create_timer(0.2).timeout
		if is_multiplayer_mode:
			end_current_activation()
		else:
			turn_manager.complete_unit_activation()
	elif selected_unit and selected_hex != Vector2i(-1, -1):
		# En multiplayer usar is_player_controlled, en singleplayer usar player_mechs
		var can_control_post_move = selected_unit.is_player_controlled if is_multiplayer_mode else (selected_unit in player_mechs)
		if not can_control_post_move:
			return
		# Estamos después del movimiento - ajuste final de facing (gratis)
		Log.debug("Movement", "Post-movement facing adjustment: %d -> %d" % [selected_unit.facing, facing])
		
		# Trigger tutorial para movimiento completado
		_trigger_tutorial_event("movement_completed")
		
		# En multiplayer, enviar rotación al servidor
		if is_multiplayer_mode and network_battle_client:
			var mech_id = selected_unit.get_meta("network_id", -1)
			network_battle_client.request_rotate(mech_id, facing)
			# La confirmación llegará via _on_net_mech_rotated
		else:
			# Singleplayer - aplicar localmente
			selected_unit.facing = facing
			selected_unit.update_visual_position(hex_grid)
			if selected_unit.has_method("update_facing_visual"):
				selected_unit.update_facing_visual()
		
		if ui:
			ui.add_combat_message("  → Final facing: %s" % FacingSystem.get_facing_name(facing), Color.CYAN)
			ui.update_unit_info(selected_unit)
		
		selected_hex = Vector2i(-1, -1)  # Reset
		
		# Finalizar activación
		await get_tree().create_timer(0.2).timeout
		if is_multiplayer_mode:
			end_current_activation()
		else:
			turn_manager.complete_unit_activation()

func _calculate_rotations(from_facing: int, to_facing: int) -> int:
	"""Calcula el número mínimo de rotaciones (cada una cuesta 1 MP)"""
	# Calcular diferencia
	var diff = (to_facing - from_facing + 6) % 6
	
	# El camino más corto es el mínimo entre ir en sentido horario o antihorario
	var clockwise = diff
	var counter_clockwise = 6 - diff
	
	return min(clockwise, counter_clockwise)


# ==============================================================================
# MOVEMENT COMPONENT BRIDGE METHODS
# ==============================================================================

func _show_movement_confirmation_menu(destination: Vector2i, cost: int) -> void:
	"""Muestra el menú de confirmación de movimiento (llamado por componente)"""
	if not selected_unit:
		return
	
	pending_move_confirmation = true
	preview_destination = destination
	
	if ui:
		var movement_names = {
			GameEnums.MovementType.WALK: "Walking",
			GameEnums.MovementType.RUN: "Running",
			GameEnums.MovementType.JUMP: "Jumping"
		}
		var move_type = movement_names.get(selected_unit.movement_type_used, "Moving")
		var message = "%s: %s to destination (Cost: %d MP)" % [selected_unit.mech_name, move_type, cost]
		
		if ui.has_method("show_confirmation_dialog"):
			ui.show_confirmation_dialog(
				"Confirm Movement",
				message,
				_on_movement_confirmed,
				_on_movement_cancelled
			)
		else:
			ui.add_combat_message("▶ " + message, Color.YELLOW)
			ui.add_combat_message("Tap destination again to confirm", Color.CYAN)


func _execute_confirmed_movement(mech, destination: Vector2i, path: Array) -> void:
	"""Ejecuta el movimiento ya confirmado (llamado por componente)"""
	if not mech:
		return
	
	# Limpiar estado via componente (esto limpia su estado interno)
	_clear_movement_state()
	
	# Actualizar overlays para limpiar preview
	update_overlays()
	
	# Ejecutar el movimiento
	_execute_movement(mech, destination, path)


func _on_movement_execution_complete(_mech) -> void:
	"""Callback cuando el componente termina de ejecutar movimiento"""
	# Limpiar estado de movimiento via componente
	_clear_movement_state()
	
	update_overlays()
	
	# NOTA: El facing selector se muestra via facing_adjustment_requested del componente
	# No duplicar la llamada aquí


func _on_component_movement_blocked(_mech, _reason: String) -> void:
	"""Callback cuando el movimiento está bloqueado (llamado por componente)"""
	# Auto-completar activación
	await get_tree().create_timer(1.0).timeout
	if is_multiplayer_mode:
		end_current_activation()
	else:
		turn_manager.complete_unit_activation()


func _show_turn_only_facing_selector(mech) -> void:
	"""Muestra el selector de facing para turn-only (llamado por componente)"""
	if not mech:
		return
	
	# Mostrar selector de facing CENTRADO EN PANTALLA
	var viewport_size = get_viewport().get_visible_rect().size
	var center_screen_pos = viewport_size / 2
	if ui and ui.has_method("show_facing_selector_with_current"):
		ui.show_facing_selector_with_current(center_screen_pos, mech.facing, mech.current_movement)
	elif _local_facing_selector:
		_ui_show_facing_selector_with_current(center_screen_pos, mech.facing, mech.current_movement)


func select_movement_type(movement_type: int):  # Mech.MovementType
	"""Llamado cuando el jugador selecciona Walk/Run/Jump"""
	if battle_components:
		battle_components.movement_select_type(movement_type)
	
	# Trigger tutorial para tipo de movimiento seleccionado
	_trigger_tutorial_event("movement_type_selected")

func select_turn_only():
	"""Llamado cuando el jugador selecciona solo girar sin moverse"""
	if battle_components:
		battle_components.movement_select_turn_only()

func cancel_movement_selection():
	"""Cancela la selección de movimiento actual y vuelve al selector de tipo"""
	Log.debug("Movement", "Cancelling movement selection")
	if battle_components:
		battle_components.movement_cancel_selection()

func _handle_movement_click(hex: Vector2i):
	"""Maneja click en hex durante fase de movimiento"""
	if battle_components:
		battle_components.movement_handle_click(hex)


func _on_movement_confirmed():
	"""Ejecutar el movimiento confirmado"""
	if battle_components:
		battle_components.movement_confirm()


func _on_movement_cancelled():
	"""Cancelar el movimiento"""
	if battle_components:
		battle_components.movement_cancel()


func _execute_movement(unit, hex: Vector2i, path: Array):
	"""Ejecuta el movimiento del mech - delega al componente"""
	if battle_components:
		battle_components.movement_execute(unit, hex, path)
		update_mech_visibility()


func _move_unit_to_hex(unit, hex: Vector2i):
	"""Mueve un mech a un hex (usado por IA) - delega al componente"""
	var path = hex_grid.find_path(unit.hex_position, hex, unit.current_movement)
	
	if path.size() > 0:
		# Delegar al componente de movimiento
		if battle_components:
			battle_components.movement_execute(unit, hex, path)
			update_mech_visibility()
			
			# Para IA: completar activación después de moverse
			var can_control = unit.is_player_controlled if is_multiplayer_mode else (unit in player_mechs)
			if not can_control:
				_clear_movement_state()
				await get_tree().create_timer(0.3).timeout
				turn_manager.complete_unit_activation()
			
			queue_redraw()


func _handle_targeting_click(hex: Vector2i):
	# Solo permitir atacar si es el turno del jugador
	# En multiplayer usar is_player_controlled, en singleplayer usar player_mechs
	var can_control = selected_unit.is_player_controlled if is_multiplayer_mode and selected_unit else (selected_unit in player_mechs if selected_unit else false)
	if selected_unit == null or not can_control:
		return
	
	var target = hex_grid.get_unit(hex)
	
	# En multiplayer verificar que el target NO es nuestro mech (es enemigo)
	var is_enemy_target = false
	if is_multiplayer_mode:
		is_enemy_target = target != null and not target.is_player_controlled
	else:
		is_enemy_target = target != null and target in enemy_mechs
	
	if is_enemy_target:
		# NOTA: Sistema viejo deshabilitado - usar selector de armas
		# _attack_target(selected_unit, target)
		Log.debug("Combat", "Use weapon selector for attacks")

func _handle_physical_targeting_click(hex: Vector2i):
	# Solo permitir ataque físico si es el turno del jugador Y estamos en la fase correcta
	# En multiplayer usar is_player_controlled, en singleplayer usar player_mechs
	var can_control = selected_unit.is_player_controlled if is_multiplayer_mode and selected_unit else (selected_unit in player_mechs if selected_unit else false)
	if selected_unit == null or not can_control:
		return
	
	# Verificar que estamos en la fase de ataque físico
	if current_state != GameEnums.GameState.PHYSICAL_TARGETING:
		return
	
	var target = hex_grid.get_unit(hex)
	
	# En multiplayer verificar que el target NO es nuestro mech (es enemigo)
	var is_enemy_target = false
	if is_multiplayer_mode:
		is_enemy_target = target != null and not target.is_player_controlled
	else:
		is_enemy_target = target != null and target in enemy_mechs
	
	if is_enemy_target and hex in physical_target_hexes:
		_show_physical_attack_menu(target)

func _handle_weapon_attack_click(hex: Vector2i):
	"""Maneja click en hex durante fase de ataque con armas"""
	if battle_components:
		battle_components.handle_weapon_attack_click(hex, selected_unit)


func execute_weapon_attack(attacker, target, weapon_indices: Array, range_hexes: int):
	"""Ejecuta ataque con armas"""
	# En modo multiplayer, enviar solicitud al servidor
	if is_multiplayer_mode and network_battle_client:
		Log.info("Network", "Sending fire request to server")
		var attacker_id = attacker.get_meta("network_id", -1)
		var target_id = target.get_meta("network_id", -1)
		
		if attacker_id == -1 or target_id == -1:
			push_error("[BATTLE_NET] Invalid mech IDs for weapon attack")
			return
		
		waiting_for_server = true
		network_battle_client.request_fire(attacker_id, target_id, weapon_indices)
		
		if ui:
			ui.add_combat_message("Firing... (waiting for server)", Color.YELLOW)
		return
	
	# Singleplayer: delegar al componente
	if battle_components:
		battle_components.execute_weapon_attack(attacker, target, weapon_indices, range_hexes)
		return


func _end_weapon_attack_phase():
	# Terminar fase de ataque y continuar
	current_attack_target = null
	
	# Limpiar overlays via componente
	# NOTA: battle_components.end_weapon_attack_phase() ya emite activation_complete_requested
	# que llama turn_manager.complete_unit_activation() via _on_activation_complete
	if battle_components:
		battle_components.end_weapon_attack_phase()
	update_overlays()
	
	# NO llamar complete_unit_activation() aquí - ya lo hace el componente


func _on_physical_attack_complete():
	# Terminar fase de ataque físico y continuar
	current_attack_target = null
	
	# Limpiar overlays y finalizar fase
	# NOTA: battle_components.end_physical_attack_phase() ya emite activation_complete_requested
	# que llama turn_manager.complete_unit_activation() via _on_activation_complete
	if battle_components:
		battle_components.end_physical_attack_phase()
	update_overlays()
	
	# NO llamar complete_unit_activation() aquí - ya lo hace el componente


func _on_turn_changed(team: String, turn_number: int):
	
	# Actualizar UI con el turno
	if ui:
		ui.update_turn_info(turn_number, team)

func _on_initiative_rolled(data: Dictionary):
	# No mostrar animación de dados 3D porque ya se vio en la pantalla de iniciativa
	
	# Solo mostrar en el chat como referencia
	if ui:
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("╔═══════════════════════════════╗", Color.GOLD)
		ui.add_combat_message("║     INITIATIVE PHASE          ║", Color.GOLD)
		ui.add_combat_message("╚═══════════════════════════════╝", Color.GOLD)
		
		ui.add_combat_message("Player rolls: [%d] + [%d] = %d" % [
			data["player_dice"][0],
			data["player_dice"][1],
			data["player_total"]
		], Color.CYAN)
		
		ui.add_combat_message("Enemy rolls: [%d] + [%d] = %d" % [
			data["enemy_dice"][0],
			data["enemy_dice"][1],
			data["enemy_total"]
		], Color.RED)
		
		ui.add_combat_message("", Color.WHITE)
		
		# Verificar que exista la clave "winner"
		if data.has("winner"):
			if data["winner"] == "player":
				ui.add_combat_message("★ PLAYER WINS INITIATIVE! ★", Color.GREEN)
				ui.add_combat_message("Player team moves first", Color.CYAN)
			else:
				ui.add_combat_message("★ ENEMY WINS INITIATIVE! ★", Color.ORANGE_RED)
				ui.add_combat_message("Enemy team moves first", Color.RED)
		else:
			push_warning("Initiative data missing 'winner' key")
		
		ui.add_combat_message("", Color.WHITE)

func _on_initiative_result(data: Dictionary):
	# Esta función es llamada directamente por el turn_manager
	_on_initiative_rolled(data)

func _on_phase_changed(phase: String):
	# Limpiar estado al cambiar de fase
	_clear_phase_state()
	update_overlays()
	
	# IMPORTANTE: phase_to_string() retorna "Movement", "Weapon Attack", "Physical Attack"
	match phase:
		"Movement":
			current_state = GameEnums.GameState.MOVING
		"Weapon Attack":
			current_state = GameEnums.GameState.WEAPON_ATTACK
			# Trigger tutorial para ataque con armas
			_notify_tutorial("weapon_attack_phase")
		"Physical Attack":
			current_state = GameEnums.GameState.PHYSICAL_TARGETING
		"Heat":
			_process_heat_phase()
		"Initiative":
			# Trigger tutorial para iniciativa
			_trigger_tutorial_event("initiative_phase")
		_:
			pass
	
	# Actualizar UI con la fase
	if ui and ui.has_method("update_phase_info"):
		ui.update_phase_info(phase)

# ==============================================================================
# ACTIVACIÓN DE UNIDADES - Métodos auxiliares refactorizados
# ==============================================================================

func _on_unit_activated(unit):
	"""Callback principal cuando se activa una unidad - Delegación a métodos auxiliares"""
	Log.debug("Combat", "_on_unit_activated: %s, is_player=%s" % [unit.mech_name, _is_player_unit(unit)])
	selected_unit = unit
	
	# Sincronizar con movement_handler si está activo
	if battle_components:
		battle_components.set_movement_selected_unit(unit)
	
	# Setup inicial común a todas las activaciones
	_setup_unit_activation(unit)
	
	# Procesar según si es unidad del jugador o enemigo
	if _is_player_unit(unit):
		_handle_player_unit_activation(unit)
	else:
		_handle_enemy_unit_activation(unit)
	
	# Actualizar visibilidad y overlays
	update_mech_visibility()
	update_overlays()


func _setup_unit_activation(unit) -> void:
	"""Configura el estado inicial cuando se activa una unidad"""
	# Centrar cámara en el mech activo - delegar al componente
	if battle_components and unit:
		battle_components.center_camera_on_unit(unit, 0.5)
	elif camera and unit:
		# Fallback si no hay componente
		var target_pos = unit.global_position
		var tween = create_tween()
		tween.tween_property(camera, "position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Mostrar overlay de mech activo si es del jugador
	if _is_player_unit(unit):
		_show_active_mech_indicator(unit)
	
	# Resetear flag de ataque físico al inicio de cada activación
	unit.has_performed_physical_attack = false
	
	# Ocultar menú de movimiento y limpiar estado anterior
	if ui and ui.has_method("hide_movement_type_selector"):
		ui.hide_movement_type_selector()
	_clear_movement_state()
	
	# Actualizar UI
	if ui:
		ui.update_unit_info(unit)


func _is_player_unit(unit) -> bool:
	"""Verifica si una unidad pertenece al jugador"""
	if is_multiplayer_mode:
		var unit_team = unit.get_meta("team", "")
		return unit_team == my_team
	else:
		return unit in player_mechs


func _handle_player_unit_activation(unit) -> void:
	"""Maneja la activación de una unidad del jugador según la fase actual"""
	Log.debug("Combat", "_handle_player_unit_activation for %s, current_state=%s" % [unit.mech_name, GameEnums.GameState.keys()[current_state]])
	
	# Si el mech está en shutdown, saltar automáticamente su turno
	if unit.is_shutdown:
		Log.info("Combat", "%s is shutdown - automatically skipping activation" % unit.mech_name)
		if ui:
			ui.add_combat_message("%s is shutdown and cannot act" % unit.mech_name, Color.GRAY)
		# Pequeña pausa para que el jugador vea el mensaje
		await get_tree().create_timer(0.5).timeout
		turn_manager.complete_unit_activation()
		return
	
	match current_state:
		GameEnums.GameState.MOVING:
			_activate_for_movement(unit)
		GameEnums.GameState.PHYSICAL_TARGETING:
			_activate_for_physical_attack(unit)
		GameEnums.GameState.TARGETING, GameEnums.GameState.WEAPON_ATTACK:
			_activate_for_weapon_attack(unit)
		_:
			Log.warn("Combat", "  -> Unhandled state %s for player unit %s!" % [current_state, unit.mech_name])


func _activate_for_movement(unit) -> void:
	"""Activa la unidad para la fase de movimiento"""
	pending_movement_selection = true
	
	# Sincronizar unidad con componente de movimiento
	if battle_components:
		battle_components.set_movement_selected_unit(unit)
	
	# Trigger tutorial para movimiento
	_trigger_tutorial_event("movement_phase", {"is_player": true})
	
	if ui:
		if ui.has_method("show_movement_type_selector"):
			ui.show_movement_type_selector(unit)
		ui.add_combat_message("Your turn: Select movement type for %s" % unit.mech_name, Color.CYAN)


func _activate_for_physical_attack(unit) -> void:
	"""Activa la unidad para la fase de ataque físico"""
	Log.debug("Combat", "_activate_for_physical_attack called for %s, has_performed=%s" % [unit.mech_name, unit.has_performed_physical_attack])
	
	# Verificar si ya realizó un ataque físico
	if unit.has_performed_physical_attack:
		Log.debug("Combat", "  -> Skipping: already performed physical attack")
		if ui:
			ui.add_combat_message("%s has already performed a physical attack this turn" % unit.mech_name, Color.GRAY)
		turn_manager.complete_unit_activation()
		return
	
	# Verificar si hay enemigos adyacentes
	var has_adjacent = battle_components and battle_components.has_adjacent_enemies(unit)
	Log.debug("Combat", "  -> has_adjacent_enemies = %s" % has_adjacent)
	
	if not has_adjacent:
		Log.debug("Combat", "  -> Skipping: no adjacent enemies")
		if ui:
			ui.add_combat_message("%s: No adjacent enemies - skipping physical attack" % unit.mech_name, Color.GRAY)
		turn_manager.complete_unit_activation()
		return
	
	# Calcular enemigos adyacentes - delegar al componente
	if battle_components:
		physical_target_hexes = battle_components.calculate_physical_targets(unit)
	Log.debug("Combat", "  -> physical_target_hexes = %s" % [physical_target_hexes])
	
	# Trigger tutorial para ataque físico disponible
	_trigger_tutorial_event("physical_attack_available")
	
	if ui:
		ui.add_combat_message("Your turn: Physical attack with %s" % unit.mech_name, Color.MAGENTA)
		if turn_manager and turn_manager.current_phase == GameEnums.TurnPhase.PHYSICAL_ATTACK:
			ui.set_help_text("Click on an adjacent enemy to attack")
	
	Log.debug("Combat", "  -> Waiting for player input for physical attack")


func _activate_for_weapon_attack(unit) -> void:
	"""Activa la unidad para la fase de ataque con armas"""
	Log.debug("Combat", "_activate_for_weapon_attack called for %s" % unit.mech_name)
	current_state = GameEnums.GameState.WEAPON_ATTACK
	
	# Trigger tutorial para ataque con armas
	_notify_tutorial("weapon_attack_phase")
	
	# Verificar si hay enemigos en LoS
	var has_los = battle_components and battle_components.has_enemies_in_los(unit)
	Log.debug("Combat", "  -> has_enemies_in_los = %s" % has_los)
	
	if not has_los:
		Log.debug("Combat", "  -> Skipping: no enemies in LoS")
		if ui:
			ui.add_combat_message("%s: No enemies in line of sight - skipping weapon attack" % unit.mech_name, Color.GRAY)
		turn_manager.complete_unit_activation()
		return
	
	# Calcular objetivos con LoS - delegar al componente
	if battle_components:
		target_hexes = battle_components.calculate_weapon_targets(unit)
	Log.debug("Combat", "  -> target_hexes = %s" % [target_hexes])
	
	if ui:
		var los_count = target_hexes.size()
		var enemies = _get_enemy_mechs_for_unit(unit)
		var total_enemies = enemies.filter(func(e): return not e.is_destroyed).size()
		var message = "Your turn: Select target for %s to fire weapons" % unit.mech_name
		if los_count < total_enemies:
			message += " (%d/%d in LoS)" % [los_count, total_enemies]
		ui.add_combat_message(message, Color.ORANGE)
		if turn_manager and (turn_manager.current_phase == GameEnums.TurnPhase.WEAPON_ATTACK or turn_manager.current_phase == GameEnums.TurnPhase.PHYSICAL_ATTACK):
			ui.set_help_text("Click on an enemy to select weapons")
	
	Log.debug("Combat", "  -> Waiting for player input for weapon attack")


func _get_enemy_mechs_for_unit(unit) -> Array:
	"""Retorna los mechs enemigos para una unidad dada"""
	if is_multiplayer_mode:
		return enemy_mechs if unit.is_player_controlled else player_mechs
	else:
		return enemy_mechs if unit in player_mechs else player_mechs


func _handle_enemy_unit_activation(unit) -> void:
	"""Maneja la activación de una unidad enemiga (IA)"""
	
	# Si el mech está en shutdown, saltar automáticamente su turno
	if unit.is_shutdown:
		Log.info("Combat", "Enemy %s is shutdown - automatically skipping activation" % unit.mech_name)
		if ui:
			ui.add_combat_message("Enemy %s is shutdown and cannot act" % unit.mech_name, Color.GRAY)
		await get_tree().create_timer(0.5).timeout
		turn_manager.complete_unit_activation()
		return
	
	if ui:
		ui.add_combat_message("Enemy turn: %s" % unit.mech_name, Color.RED)
	# Esperar un poco antes de que la IA actúe para que se vea
	await get_tree().create_timer(0.5).timeout
	_ai_turn(unit)

func _ai_turn(unit):
	# Usar el sistema de IA mejorado
	if battle_ai and turn_manager:
		await battle_ai.execute_ai_turn(unit, turn_manager.current_phase)
	else:
		# Fallback si no hay IA configurada
		turn_manager.complete_unit_activation()

func _show_physical_attack_menu(target):
	# Por ahora, mostrar todas las opciones disponibles en la UI
	if ui:
		ui.show_physical_attack_options(selected_unit, target)

func execute_physical_attack(attacker, target, attack_type: String):
	"""Ejecuta ataque físico"""
	# En modo multiplayer, enviar solicitud al servidor
	if is_multiplayer_mode and network_battle_client:
		Log.info("Network", "Sending physical attack request to server")
		var attacker_id = attacker.get_meta("network_id", -1)
		var target_id = target.get_meta("network_id", -1)
		
		if attacker_id == -1 or target_id == -1:
			push_error("[BATTLE_NET] Invalid mech IDs for physical attack")
			return
		
		waiting_for_server = true
		network_battle_client.request_physical_attack(attacker_id, target_id, attack_type)
		
		if ui:
			ui.add_combat_message("Physical attack... (waiting for server)", Color.MAGENTA)
		return
	
	# Singleplayer: delegar al componente
	if battle_components:
		battle_components.execute_physical_attack(attacker, target, attack_type)
		return


## FASE DE CALOR ##

func _process_heat_phase():
	"""Procesa la fase de calor para todos los mechs"""
	if battle_components:
		# El heat_manager ahora procesa iterativamente con pausas
		# y emite heat_phase_completed cuando termina, lo cual
		# avanza la fase automáticamente a través del integrator
		battle_components.process_heat_phase()
	return


# Métodos públicos para la UI
func get_turn_manager():
	return turn_manager

func end_current_activation():
	"""Termina la activación de la unidad actual"""
	if is_multiplayer_mode and network_battle_client and selected_unit:
		# En multiplayer, notificar al servidor
		Log.info("Network", "Multiplayer - requesting end activation from server")
		mp_request_end_activation(selected_unit)
		is_my_turn = false  # Ya no es mi turno
		_clear_movement_state()
		update_overlays()
		_hide_active_mech_indicator()
	elif turn_manager:
		# En singleplayer, usar el turn_manager local
		turn_manager.complete_unit_activation()

func notify_ui_interaction():
	"""Llamar esta función desde la UI cuando se hace click en un botón para evitar clics fantasma en el mapa"""
	ui_interaction_cooldown = 0.2  # 200ms de cooldown

func _check_battle_end():
	"""Verifica si la batalla terminó - delega al state_coordinator via integrator"""
	if battle_components:
		var result = battle_components.check_battle_end()
		if result.get("ended", false):
			# Determinar si el jugador ganó
			var player_won = false
			for mech in player_mechs:
				if not mech.is_destroyed:
					player_won = true
					break
			
			# Mostrar pantalla de fin mejorada con estadísticas
			_show_battle_end_screen(player_won, result.winner, result.loser, result.reason)


func _show_battle_end_screen(player_won: bool, winner: String, loser: String, reason: String):
	"""Muestra la pantalla de fin de batalla con estadísticas"""
	# Obtener estadísticas
	var stats = {}
	if battle_stats_tracker:
		stats = battle_stats_tracker.get_full_summary()
	
	# Crear la pantalla de fin
	var end_screen = BattleEndScreenClass.new()
	
	# Añadir a un CanvasLayer para que esté encima de todo
	var end_layer = CanvasLayer.new()
	end_layer.layer = 200
	add_child(end_layer)
	end_layer.add_child(end_screen)
	
	# Configurar con los datos
	end_screen.setup(stats, player_won, winner, loser, reason)
	
	Log.info("Match", "Battle ended - showing end screen", {
		"winner": winner,
		"player_won": player_won,
		"turns": stats.get("turns", 0)
	})


func _handle_mech_inspect(hex: Vector2i):
	# Verificar si hay un mech en este hexágono
	if not hex_grid.is_valid_hex(hex):
		return
	
	var unit = hex_grid.get_unit(hex)
	if unit and ui and ui.has_method("show_mech_inspector"):
		ui.show_mech_inspector(unit)


func _create_long_press_indicator():
	# Delegado a LongPressIndicator (scripts/ui/long_press_indicator.gd)
	var indicator_layer = CanvasLayer.new()
	indicator_layer.name = "LongPressIndicatorLayer"
	indicator_layer.layer = 100  # Encima del UI normal
	add_child(indicator_layer)
	
	long_press_indicator = LongPressIndicator.new()
	long_press_indicator.name = "LongPressIndicator"
	long_press_indicator.scene = self
	long_press_indicator.visible = false
	indicator_layer.add_child(long_press_indicator)

func _show_active_mech_indicator(unit):
	"""Muestra un indicador visual sobre el mech activo - usa componente dedicado"""
	_hide_active_mech_indicator()
	
	# Crear instancia del componente de indicador
	active_mech_indicator = ActiveMechIndicatorClass.new()
	add_child(active_mech_indicator)
	active_mech_indicator.show_for_unit(unit.mech_name)


func _hide_active_mech_indicator():
	"""Oculta el indicador de mech activo"""
	if active_mech_indicator and is_instance_valid(active_mech_indicator):
		if active_mech_indicator.has_method("hide_indicator"):
			active_mech_indicator.hide_indicator()
			# Esperar un poco y luego liberar
			await get_tree().create_timer(0.5).timeout
		if active_mech_indicator and is_instance_valid(active_mech_indicator):
			active_mech_indicator.queue_free()
		active_mech_indicator = null


# ============================================================
# SISTEMA MULTIPLAYER - CONEXIÓN DE SEÑALES DEL NETWORK HANDLER
# ============================================================

func _connect_network_handler_signals() -> void:
	"""Conecta las señales del BattleNetworkHandler SOLID"""
	if not network_handler:
		Log.warning("Network", "Cannot connect signals - network_handler is null")
		return
	
	# Deployment
	network_handler.deployment_phase_requested.connect(_on_handler_deployment_requested)
	network_handler.enemy_mech_created.connect(_on_handler_enemy_mech_created)
	network_handler.my_mech_confirmed.connect(_on_handler_my_mech_confirmed)
	
	# Phases & Turns
	network_handler.initiative_received.connect(_on_handler_initiative_received)
	network_handler.phase_changed_processed.connect(_on_handler_phase_changed)
	network_handler.unit_activated_processed.connect(_on_handler_unit_activated)
	
	# Action Results
	network_handler.movement_result.connect(_on_handler_movement_result)
	network_handler.rotation_result.connect(_on_handler_rotation_result)
	network_handler.weapon_fire_result.connect(_on_handler_weapon_fire_result)
	network_handler.physical_attack_result.connect(_on_handler_physical_attack_result)
	network_handler.heat_phase_result.connect(_on_handler_heat_phase_result)
	
	# Battle End
	network_handler.battle_ended_processed.connect(_on_handler_battle_ended)
	network_handler.action_rejected_message.connect(_on_handler_action_rejected)
	network_handler.opponent_disconnected_event.connect(_on_handler_opponent_disconnected)
	
	# UI Messages
	network_handler.combat_message.connect(_on_handler_combat_message)
	
	Log.info("Network", "BattleNetworkHandler signals connected")


# ============================================================
# HANDLERS PARA SEÑALES DEL NETWORK HANDLER (SOLID)
# ============================================================

func _on_handler_deployment_requested(team: String) -> void:
	"""Handler: Servidor solicita inicio de despliegue"""
	my_team = team
	if network_handler:
		network_handler.set_my_team(team)
	Log.info("Network", "Server authorized deployment - starting deployment phase")
	_start_deployment_phase()


func _on_handler_enemy_mech_created(mech_data: Dictionary, hex_pos: Vector2i, facing: int, team: String, mech_id: int) -> void:
	"""Handler: Crear mech enemigo desde datos de red"""
	Log.info("Network", "Creating ENEMY mech: %s with facing=%d" % [mech_data.get("name", "Unknown"), facing])
	var mech = _create_mech_from_network_data(mech_id, mech_data, hex_pos, facing, team)
	Log.debug("Mech", "After creation, mech.facing = %d" % mech.facing)
	enemy_mechs.append(mech)
	Log.debug("Network", "Enemy mechs count: %d" % enemy_mechs.size())


func _on_handler_my_mech_confirmed(mech_id: int, hex_pos: Vector2i, facing: int, mech_name: String) -> void:
	"""Handler: Confirmar network_id de mi mech"""
	for mech in player_mechs:
		if mech.hex_position == hex_pos and (mech_name.is_empty() or mech.mech_name == mech_name):
			mech.set_meta("network_id", mech_id)
			if mech.facing != facing:
				Log.warning("Network", "Facing mismatch! Updating from %d to %d" % [mech.facing, facing])
				mech.facing = facing
				mech.update_facing_visual()
			Log.debug("Network", "Updated my mech %s with network_id %d, facing=%d" % [mech.mech_name, mech_id, mech.facing])
			return
	Log.warning("Network", "Could not find my mech at %s to update network_id" % hex_pos)


func _on_handler_initiative_received(result: Dictionary) -> void:
	"""Handler: Resultado de iniciativa"""
	initiative_data_stored = result


func _on_handler_phase_changed(phase: String, turn: int, _phase_enum: int) -> void:
	"""Handler: Cambio de fase desde servidor"""
	# Asegurar que la batalla ha empezado
	battle_started = true
	if battle_components:
		battle_components.set_input_battle_started(true)
	
	# Cerrar pantalla de iniciativa si está abierta
	var init_screen = get_node_or_null("InitiativeScreen")
	if init_screen:
		Log.debug("UI", "Closing initiative screen due to phase change")
		init_screen.queue_free()
	
	# Mostrar UI principal
	if ui and ui.has_method("show_main_ui"):
		ui.show_main_ui()
	
	# Limpiar estado anterior
	_clear_phase_state()
	
	# Ocultar selectores de UI
	_hide_all_ui_selectors()
	
	# Actualizar fase según el tipo
	match phase:
		"initiative":
			Log.info("Match", "Initiative phase - showing initiative screen")
			_show_initiative_screen_multiplayer()
			return
		"movement":
			turn_manager.current_phase = GameEnums.TurnPhase.MOVEMENT
			current_state = GameEnums.GameState.MOVING
			deployment_phase = false
			if battle_components:
				battle_components.set_input_deployment_phase(false)
		"weapon_attack":
			turn_manager.current_phase = GameEnums.TurnPhase.WEAPON_ATTACK
			current_state = GameEnums.GameState.WEAPON_ATTACK
			# Trigger tutorial para ataque con armas
			_notify_tutorial("weapon_attack_phase")
		"physical_attack":
			turn_manager.current_phase = GameEnums.TurnPhase.PHYSICAL_ATTACK
			current_state = GameEnums.GameState.PHYSICAL_TARGETING
		"heat":
			turn_manager.current_phase = GameEnums.TurnPhase.HEAT
	
	# Actualizar display de fase
	_update_phase_display(phase, turn)
	update_overlays()


func _on_handler_unit_activated(mech_id: int, is_mine: bool) -> void:
	"""Handler: Unidad activada por el servidor"""
	is_my_turn = is_mine
	if network_handler:
		network_handler.set_is_my_turn(is_mine)
	
	var mech = _find_mech_by_network_id(mech_id)
	if not mech:
		push_error("[BATTLE_NET] Could not find mech with network_id %d" % mech_id)
		return
	
	selected_unit = mech
	
	# Resetear estado de movimiento si es fase de movimiento
	if current_state == GameEnums.GameState.MOVING and mech.has_method("reset_movement"):
		mech.reset_movement()
	
	if is_mine:
		_handle_my_unit_activated(mech)
	else:
		_handle_opponent_unit_activated(mech)
	
	update_overlays()


func _handle_my_unit_activated(mech) -> void:
	"""Maneja la activación de mi unidad"""
	Log.info("Network", "It's MY turn with %s!" % mech.mech_name)
	_show_active_mech_indicator(mech)
	
	if ui:
		if ui.has_method("update_unit_info"):
			ui.update_unit_info(mech)
		if ui.has_method("update_end_turn_button"):
			ui.update_end_turn_button(true, "END ▶")
	
	match current_state:
		GameEnums.GameState.MOVING:
			pending_movement_selection = true
			if ui and ui.has_method("show_movement_type_selector"):
				ui.show_movement_type_selector(mech)
				ui.add_combat_message("▶ Your turn: Select movement for %s" % mech.mech_name, Color.GREEN)
		GameEnums.GameState.WEAPON_ATTACK:
			_show_weapon_attack_targets_mp(mech)
		GameEnums.GameState.PHYSICAL_TARGETING:
			_show_physical_attack_targets_mp(mech)


func _handle_opponent_unit_activated(mech) -> void:
	"""Maneja la activación de una unidad del oponente"""
	_clear_phase_state()
	
	if ui:
		if ui.has_method("hide_movement_type_selector"):
			ui.hide_movement_type_selector()
		if ui.has_method("update_end_turn_button"):
			ui.update_end_turn_button(false, "WAIT...")
		if ui.has_method("add_combat_message"):
			ui.add_combat_message("⏳ Opponent's turn: %s" % mech.mech_name, Color.YELLOW)


func _on_handler_movement_result(result: Dictionary) -> void:
	"""Handler: Resultado de movimiento"""
	waiting_for_server = false
	
	var mech_id = result.get("mech_id", -1)
	var from_hex = Vector2i(result["from_hex"][0], result["from_hex"][1])
	var to_hex = Vector2i(result["to_hex"][0], result["to_hex"][1])
	
	var mech = _find_mech_by_network_id(mech_id)
	if not mech:
		push_error("[BATTLE_NET] Could not find mech with id %d for movement update" % mech_id)
		return
	
	# Actualizar posición en el grid
	hex_grid.set_unit(from_hex, null)
	hex_grid.set_unit(to_hex, mech)
	
	# Actualizar mech
	var old_pos = mech.hex_position
	mech.hex_position = to_hex
	mech.hexes_moved_this_turn = result.get("hexes_moved", 0)
	mech.current_movement = result.get("remaining_mp", 0)
	
	# Convertir tipo de movimiento
	var move_type_int = result.get("movement_type", 1)
	match move_type_int:
		1: mech.movement_type_used = GameEnums.MovementType.WALK
		2: mech.movement_type_used = GameEnums.MovementType.RUN
		3: mech.movement_type_used = GameEnums.MovementType.JUMP
	
	# Usar facing del servidor o calcularlo
	mech.facing = result.get("facing", FacingSystem.get_facing_to_hex(old_pos, to_hex))
	
	# Actualizar visual
	mech.update_visual_position(hex_grid)
	if mech.has_method("update_facing_visual"):
		mech.update_facing_visual()
	
	# Limpiar overlays
	_clear_movement_state()
	
	# Log en UI
	if ui:
		var move_names = {1: "walked", 2: "ran", 3: "jumped"}
		ui.add_combat_message("%s %s to [%d,%d] (Remaining: %d MP)" % [
			mech.mech_name, move_names.get(move_type_int, "moved"), to_hex.x, to_hex.y, mech.current_movement
		], Color.WHITE)
	
	# Si es mi mech, mostrar selector de facing
	if mech.is_player_controlled and is_my_turn:
		_show_post_movement_facing_selector(mech, to_hex)
	
	update_overlays()


func _on_handler_rotation_result(result: Dictionary) -> void:
	"""Handler: Resultado de rotación"""
	waiting_for_server = false
	
	var mech = _find_mech_by_network_id(result.get("mech_id", -1))
	if mech:
		mech.facing = result.get("new_facing", mech.facing)
		mech.update_visual_position(hex_grid)
		if mech.has_method("update_facing_visual"):
			mech.update_facing_visual()


func _on_handler_weapon_fire_result(result: Dictionary) -> void:
	"""Handler: Resultado de disparo de armas"""
	waiting_for_server = false
	_process_weapon_fire_result(result)


func _on_handler_physical_attack_result(result: Dictionary) -> void:
	"""Handler: Resultado de ataque físico"""
	waiting_for_server = false
	_process_physical_attack_result(result)


func _on_handler_heat_phase_result(results: Array) -> void:
	"""Handler: Resultados de fase de calor - delega presentación al presenter"""
	for result in results:
		var mech = _find_mech_by_network_id(result.get("mech_id", -1))
		if not mech:
			continue
		
		var initial_heat = result.get("initial_heat", 0)
		var final_heat = result.get("final_heat", 0)
		var shutdown = result.get("shutdown", false)
		
		mech.heat = final_heat
		if shutdown:
			mech.is_shutdown = true
		
		# Delegar presentación al presenter
		if combat_result_presenter:
			combat_result_presenter.present_heat_phase_result(
				mech.mech_name, initial_heat, final_heat, 
				result.get("dissipated", 0), shutdown
			)
		
		if ui and selected_unit == mech and ui.has_method("update_unit_info"):
			ui.update_unit_info(mech)
	
	if combat_result_presenter:
		combat_result_presenter.present_heat_phase_separator()


func _on_handler_battle_ended(_winner_team: String, reason: String, i_won: bool) -> void:
	"""Handler: Batalla terminada - delega presentación al presenter"""
	if ui and ui.has_method("show_battle_end"):
		ui.show_battle_end(i_won, reason)
	elif combat_result_presenter:
		combat_result_presenter.present_battle_end(i_won, reason)
	
	# Registrar resultado de la partida en PlayerDataManager
	var player_data = get_node_or_null("/root/PlayerData")
	if player_data:
		if i_won:
			player_data.record_match_result(true)  # Victoria
			player_data.add_xp(100)  # XP por victoria
			Log.info("Combat", "Match result recorded: WIN +100 XP")
		else:
			player_data.record_match_result(false)  # Derrota
			player_data.add_xp(25)  # XP de consolación
			Log.info("Combat", "Match result recorded: LOSS +25 XP")
	
	# Volver al menú después de un delay
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_handler_action_rejected(reason: String) -> void:
	"""Handler: Acción rechazada"""
	waiting_for_server = false
	if ui:
		if ui.has_method("show_message"):
			ui.show_message("Action rejected: " + reason)


func _on_handler_opponent_disconnected() -> void:
	"""Handler: Oponente desconectado"""
	if ui and ui.has_method("show_message"):
		ui.show_message("Opponent disconnected! You win!")
	
	# Registrar victoria por desconexión
	var player_data = get_node_or_null("/root/PlayerData")
	if player_data:
		player_data.record_match_result(true)  # Victoria por forfeit
		player_data.add_xp(50)  # XP reducido por forfeit
		Log.info("Combat", "Match result recorded: WIN by forfeit +50 XP")
	
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_handler_combat_message(text: String, color: Color) -> void:
	"""Handler: Mensaje de combate desde network handler"""
	if ui and ui.has_method("add_combat_message"):
		ui.add_combat_message(text, color)


# ============================================================
# FUNCIONES AUXILIARES PARA HANDLERS DE RED
# ============================================================

func _clear_phase_state() -> void:
	"""Limpia el estado al cambiar de fase - delega al componente"""
	if battle_components:
		battle_components.clear_all_phase_state()


func _clear_movement_state() -> void:
	"""Limpia el estado de movimiento - delega al componente"""
	if battle_components:
		battle_components.movement_clear_state()


func _hide_all_ui_selectors() -> void:
	"""Oculta todos los selectores de UI"""
	if ui:
		if ui.has_method("hide_movement_type_selector"):
			ui.hide_movement_type_selector()
		if ui.has_method("hide_weapon_selector"):
			ui.hide_weapon_selector()
		if ui.has_method("hide_physical_attack_panel"):
			ui.hide_physical_attack_panel()


func _update_phase_display(phase: String, _turn: int) -> void:
	"""Actualiza el display de fase en la UI"""
	if ui:
		if ui.has_method("update_phase_display"):
			ui.update_phase_display(turn_manager.current_phase)
		if ui.has_method("update_phase_info"):
			ui.update_phase_info(phase.capitalize())


func _show_weapon_attack_targets_mp(mech) -> void:
	"""Muestra los objetivos válidos para ataque con armas en multiplayer"""
	# Delegar cálculo al componente
	if battle_components:
		target_hexes = battle_components.calculate_weapon_targets(mech)
	
	var valid_targets = target_hexes.size()
	
	if valid_targets > 0:
		if ui and ui.has_method("add_combat_message"):
			ui.add_combat_message("▶ Select target for %s (%d enemies in range)" % [mech.mech_name, valid_targets], Color.ORANGE)
	else:
		if ui and ui.has_method("add_combat_message"):
			ui.add_combat_message("%s: No enemies in line of sight - skipping" % mech.mech_name, Color.GRAY)
		await get_tree().create_timer(1.0).timeout
		if is_my_turn:
			end_current_activation()


func _show_physical_attack_targets_mp(mech) -> void:
	"""Muestra los objetivos válidos para ataque físico en multiplayer"""
	# Delegar cálculo al componente
	if battle_components:
		physical_target_hexes = battle_components.calculate_physical_targets(mech)
	
	var valid_targets = physical_target_hexes.size()
	
	if valid_targets > 0:
		if ui and ui.has_method("add_combat_message"):
			ui.add_combat_message("▶ Select adjacent enemy for physical attack", Color.MAGENTA)
	else:
		if ui and ui.has_method("add_combat_message"):
			ui.add_combat_message("%s: No adjacent enemies - skipping physical attack" % mech.mech_name, Color.GRAY)
		await get_tree().create_timer(1.0).timeout
		if is_my_turn:
			end_current_activation()


func _show_post_movement_facing_selector(mech, to_hex: Vector2i) -> void:
	"""Muestra el selector de facing después del movimiento"""
	Log.debug("Network", "My mech moved - showing facing selector")
	selected_unit = mech
	selected_hex = to_hex
	
	if ui:
		ui.add_combat_message("▶ Adjust facing then tap 'END' to finish", Color.YELLOW)
	
	var hex_pixel = hex_grid.hex_to_pixel(to_hex, true) + hex_grid.global_position
	var screen_pos = hex_pixel
	if camera:
		screen_pos = hex_pixel - camera.position + get_viewport().get_visible_rect().size / 2
	
	if ui and ui.has_method("show_facing_selector_with_current"):
		ui.show_facing_selector_with_current(screen_pos, mech.facing, mech.current_movement, to_hex)
	elif _local_facing_selector:
		_ui_show_facing_selector_with_current(screen_pos, mech.facing, mech.current_movement, to_hex)


func _process_weapon_fire_result(result: Dictionary) -> void:
	"""Procesa y muestra el resultado de disparo de armas - delega al presenter"""
	var attacker = _find_mech_by_network_id(result.get("attacker_id", 0))
	var target = _find_mech_by_network_id(result.get("target_id", 0))
	
	if not attacker or not target:
		push_error("[BATTLE_NET] Could not find attacker or target for weapon fire result")
		return
	
	# Actualizar calor del atacante
	var total_heat = result.get("total_heat", 0)
	attacker.heat = result.get("attacker_heat", attacker.heat)
	if ui and ui.has_method("update_unit_info"):
		ui.update_unit_info(attacker)
	
	# Verificar destrucción
	var target_destroyed = result.get("target_destroyed", false)
	if target_destroyed:
		target.is_destroyed = true
	
	# Delegar presentación visual al presenter
	if combat_result_presenter:
		combat_result_presenter.present_weapon_fire_result(
			attacker.mech_name, target.mech_name,
			result.get("results", []), total_heat, attacker.heat,
			target_destroyed, target
		)
	
	# Limpiar targets via componente
	if battle_components:
		battle_components.end_weapon_attack_phase()
	update_overlays()
	
	# Auto-terminar
	if is_my_turn:
		await get_tree().create_timer(0.5).timeout
		end_current_activation()


func _process_physical_attack_result(result: Dictionary) -> void:
	"""Procesa y muestra el resultado de ataque físico - delega al presenter"""
	var attacker = _find_mech_by_network_id(result.get("attacker_id", 0))
	var target = _find_mech_by_network_id(result.get("target_id", 0))
	var attack_type = result.get("attack_type", "unknown")
	var attack_result = result.get("result", {})
	
	# Verificar destrucción
	var target_destroyed = result.get("target_destroyed", false)
	if target_destroyed and target:
		target.is_destroyed = true
	
	# Delegar presentación visual al presenter
	if combat_result_presenter:
		var attacker_name = attacker.mech_name if attacker else "Unknown"
		var target_name = target.mech_name if target else "Unknown"
		combat_result_presenter.present_physical_attack_result(
			attacker_name, target_name,
			attack_type, attack_result,
			target_destroyed, target
		)
	
	# Limpiar targets via componente (clear_target_hexes limpia ambos)
	if battle_components:
		battle_components.end_weapon_attack_phase()
	update_overlays()
	
	if is_my_turn:
		await get_tree().create_timer(0.5).timeout
		end_current_activation()


func _find_mech_by_network_id(mech_id: int):
	"""Busca un mech por su ID de red"""
	for mech in player_mechs:
		if mech.get_meta("network_id", -1) == mech_id:
			return mech
	for mech in enemy_mechs:
		if mech.get_meta("network_id", -1) == mech_id:
			return mech
	return null


func _create_mech_from_network_data(mech_id: int, mech_data: Dictionary, hex_pos: Vector2i, facing: int, team: String):
	"""Crea un mech visual desde datos de red - delega al factory"""
	if not mech_factory:
		push_error("MechFactory not available for network mech creation")
		return null
	
	var mech = mech_factory.create_from_network(mech_id, mech_data, hex_pos, facing, team)
	if not mech:
		return null
	
	# Posición visual y registro en grid
	mech.position = hex_grid.hex_to_pixel(hex_pos)
	mech.visible = true
	hex_grid.set_unit(hex_pos, mech)
	
	# Color según equipo
	mech.modulate = Color.GREEN if team == my_team else Color.RED
	
	add_child(mech)
	
	# Actualizar visual
	if mech.has_method("update_visual_position"):
		mech.update_visual_position(hex_grid)
	if mech.has_method("update_facing_visual"):
		mech.update_facing_visual()
	
	Log.info("Mech", "Created network mech %s at hex %s" % [mech.mech_name, hex_pos])
	return mech


# ============================================================
# ENVÍO DE ACCIONES EN MULTIPLAYER
# ============================================================

func mp_request_move(mech, target_hex: Vector2i, movement_type: int):
	"""Solicita movimiento al servidor en modo multiplayer"""
	if not is_multiplayer_mode or not network_battle_client:
		return
	
	var mech_id = mech.get_meta("network_id", -1)
	if mech_id == -1:
		push_error("Mech has no network_id!")
		return
	
	waiting_for_server = true
	network_battle_client.request_move(mech_id, target_hex, movement_type)

func mp_request_fire(attacker, target, weapon_indices: Array):
	"""Solicita disparo al servidor"""
	if not is_multiplayer_mode or not network_battle_client:
		return
	
	var attacker_id = attacker.get_meta("network_id", -1)
	var target_id = target.get_meta("network_id", -1)
	
	waiting_for_server = true
	network_battle_client.request_fire(attacker_id, target_id, weapon_indices)

func mp_request_end_activation(mech):
	"""Indica al servidor que terminó la activación"""
	if not is_multiplayer_mode or not network_battle_client:
		return
	
	var mech_id = mech.get_meta("network_id", -1)
	network_battle_client.request_end_activation(mech_id)


# ============================================================
# TRACKING DE ESTADÍSTICAS DE BATALLA
# ============================================================

func _on_weapon_fired_stats(attacker, weapon: Dictionary, hit: bool, damage: int, _location: String):
	"""Trackea estadísticas cuando se dispara un arma"""
	if not battle_stats_tracker:
		return
	
	var is_player = attacker in player_mechs
	var weapon_name = weapon.get("name", "").to_lower()
	
	# Detectar si es un misil
	var is_missile = "lrm" in weapon_name or "srm" in weapon_name
	var missile_count = 1
	
	if is_missile:
		# Extraer número de misiles
		var regex = RegEx.new()
		regex.compile("[ls]rm[- ]?(\\d+)")
		var result = regex.search(weapon_name)
		if result:
			missile_count = int(result.get_string(1))
	
	# Registrar el disparo
	battle_stats_tracker.record_weapon_attack(attacker.mech_name, is_player, hit, is_missile, missile_count)
	
	# Registrar daño si hubo impacto
	if hit and damage > 0:
		# Necesitamos saber el target - por ahora usamos current_attack_target
		var target_name = "Unknown"
		var target_is_player = false
		if current_attack_target:
			target_name = current_attack_target.mech_name
			target_is_player = current_attack_target in player_mechs
		
		battle_stats_tracker.record_damage(attacker.mech_name, is_player, target_name, target_is_player, damage)
	
	# Registrar calor
	var heat = weapon.get("heat", 0)
	if heat > 0:
		battle_stats_tracker.record_heat_generated(attacker.mech_name, is_player, heat)


func _on_physical_attack_stats(attacker, target, _attack_type: String, hit: bool):
	"""Trackea estadísticas de ataques físicos"""
	if not battle_stats_tracker:
		return
	
	var attacker_is_player = attacker in player_mechs
	battle_stats_tracker.record_physical_attack(attacker.mech_name, attacker_is_player, hit)
	
	# Registrar daño si hubo impacto (daño físico aproximado)
	if hit:
		var damage = int(attacker.tonnage / 10)  # Daño aproximado de puño/patada
		var target_is_player = target in player_mechs
		battle_stats_tracker.record_damage(attacker.mech_name, attacker_is_player, target.mech_name, target_is_player, damage)


func _on_mech_destroyed_stats(_target, destroyed_by):
	"""Trackea cuando un mech es destruido"""
	if not battle_stats_tracker:
		return
	
	var killer_is_player = destroyed_by in player_mechs
	battle_stats_tracker.record_kill(destroyed_by.mech_name, killer_is_player)
