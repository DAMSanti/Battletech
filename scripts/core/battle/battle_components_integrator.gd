## BattleComponentsIntegrator - Integra todos los componentes de batalla
## Este archivo sirve como fachada para facilitar la migración gradual
## de battle_scene.gd hacia componentes modulares SOLID
class_name BattleComponentsIntegrator
extends RefCounted

# ==============================================================================
# COMPONENTS
# ==============================================================================
var camera_controller: BattleCameraController
var deployment_manager: BattleDeploymentManager
var combat_executor: BattleCombatExecutor
var heat_manager: BattleHeatManager
var state_coordinator: BattleStateCoordinator
var network_handler: BattleNetworkHandler
var input_router: BattleInputRouter
var overlay_manager: BattleOverlayManager
var movement_handler: BattleMovementHandler

# ==============================================================================
# REFERENCES
# ==============================================================================
var battle_scene: Node2D  # Referencia a battle_scene.gd
var hex_grid: HexGrid
var ui: Node  # Puede ser Control o CanvasLayer (battle_ui.gd)
var turn_manager = null

# ==============================================================================
# STATE FLAGS
# ==============================================================================
var is_initialized: bool = false
var use_camera_component: bool = true
var use_deployment_component: bool = true
var use_combat_component: bool = true
var use_heat_component: bool = true
var use_state_component: bool = true
var use_network_component: bool = true
var use_input_component: bool = true
var use_overlay_component: bool = true
var use_movement_component: bool = true  # Desactivado hasta migración completa


func _init() -> void:
	"""Crea instancias de todos los componentes"""
	camera_controller = BattleCameraController.new()
	deployment_manager = BattleDeploymentManager.new()
	combat_executor = BattleCombatExecutor.new()
	heat_manager = BattleHeatManager.new()
	state_coordinator = BattleStateCoordinator.new()
	network_handler = BattleNetworkHandler.new()
	input_router = BattleInputRouter.new()
	overlay_manager = BattleOverlayManager.new()
	movement_handler = BattleMovementHandler.new()


func setup(p_battle_scene: Node2D, p_hex_grid: HexGrid, p_ui: Node, p_turn_manager, config: Dictionary = {}) -> void:
	"""Configura todos los componentes con las referencias necesarias"""
	battle_scene = p_battle_scene
	hex_grid = p_hex_grid
	ui = p_ui
	turn_manager = p_turn_manager
	
	var is_multiplayer = config.get("is_multiplayer", false)
	var my_team = config.get("my_team", "")
	
	# Configurar cada componente
	if use_camera_component:
		var camera = config.get("camera", null)
		camera_controller.initialize(camera, hex_grid, null)
		_connect_camera_signals()
	
	if use_deployment_component:
		deployment_manager.setup(hex_grid, is_multiplayer, my_team)
		_connect_deployment_signals()
	
	if use_combat_component:
		combat_executor.setup(hex_grid, is_multiplayer)
		# Pasar SceneTree y parent node para animaciones
		if battle_scene:
			var tree = battle_scene.get_tree()
			# Usar effects_layer si existe, sino battle_scene
			var effects_parent = battle_scene.effects_layer if battle_scene.get("effects_layer") else battle_scene
			Log.info("Combat", "Setting up combat animations: tree=%s, effects_parent=%s" % [tree != null, effects_parent.name if effects_parent else "null"])
			if tree:
				combat_executor.set_scene_tree(tree)
			combat_executor.set_parent_node(effects_parent)
		_connect_combat_signals()
	
	if use_heat_component:
		# Pasar SceneTree al heat_manager para que pueda usar timers
		if battle_scene and battle_scene.get_tree():
			heat_manager.set_scene_tree(battle_scene.get_tree())
		_connect_heat_signals()
	
	if use_state_component:
		state_coordinator.setup(turn_manager, is_multiplayer, my_team)
		_connect_state_signals()
	
	if use_network_component and is_multiplayer:
		var network_client = config.get("network_client", null)
		var match_id = config.get("match_id", 0)
		network_handler.setup(network_client, hex_grid, match_id, my_team)
		_connect_network_signals()
	
	if use_input_component:
		var camera = config.get("camera", null)
		input_router.setup(hex_grid, camera, ui)
		_connect_input_signals()
	
	if use_overlay_component:
		overlay_manager.setup(hex_grid)
	
	if use_movement_component:
		movement_handler.setup(hex_grid, is_multiplayer)
		_connect_movement_signals()
	
	is_initialized = true
	Log.info("Combat", "BattleComponentsIntegrator initialized")


func update_mech_references(player_mechs: Array, enemy_mechs: Array) -> void:
	"""Actualiza las referencias a mechs en todos los componentes"""
	if use_combat_component:
		combat_executor.set_mechs(player_mechs, enemy_mechs)
	
	if use_heat_component:
		heat_manager.set_mechs(player_mechs, enemy_mechs)
	
	if use_state_component:
		state_coordinator.set_mechs(player_mechs, enemy_mechs)
	
	if use_movement_component:
		movement_handler.set_player_mechs(player_mechs)


func set_deployment_zones(zones: Dictionary) -> void:
	"""Establece las zonas de despliegue"""
	if use_deployment_component:
		deployment_manager.set_deployment_zones(zones)


func set_battle_adapter(adapter) -> void:
	"""Establece el adaptador de batalla unificado"""
	if use_deployment_component:
		deployment_manager.set_battle_adapter(adapter)


# ==============================================================================
# CAMERA COMPONENT FACADE
# ==============================================================================

func center_camera_on_hex(hex: Vector2i, smooth: bool = true) -> void:
	"""Centra la cámara en un hex específico"""
	if use_camera_component and camera_controller:
		camera_controller.center_on_hex(hex, smooth)


func center_camera_on_unit(unit: Mech, duration: float = 0.5) -> void:
	"""Centra la cámara en una unidad con animación suave"""
	if not unit:
		return
	
	# Si tenemos el camera_controller, usarlo
	if use_camera_component and camera_controller and camera_controller.camera:
		var target_pos = unit.global_position
		var tween = battle_scene.create_tween()
		tween.tween_property(camera_controller.camera, "position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func handle_camera_input(event: InputEvent, _camera: Camera2D) -> Dictionary:
	"""Procesa input de cámara y retorna resultado"""
	if use_camera_component:
		var handled = camera_controller.handle_input(event)
		return {"handled": handled}
	return {"handled": false}


func is_click_over_ui(pos: Vector2) -> bool:
	"""Verifica si un click está sobre la UI"""
	if use_camera_component:
		return camera_controller.is_click_over_ui(pos)
	return false


# ==============================================================================
# DEPLOYMENT COMPONENT FACADE
# ==============================================================================

func start_deployment_phase() -> void:
	"""Inicia la fase de despliegue"""
	if use_deployment_component:
		deployment_manager.start_deployment_phase()


func handle_deployment_click(hex: Vector2i, screen_pos: Vector2) -> bool:
	"""Maneja click durante despliegue"""
	if use_deployment_component:
		return deployment_manager.handle_hex_click(hex, screen_pos)
	return false


func is_in_deployment_phase() -> bool:
	"""Verifica si estamos en fase de despliegue"""
	if use_deployment_component:
		return deployment_manager.is_in_deployment_phase()
	return false


func get_valid_deployment_hexes() -> Array:
	"""Retorna hexes válidos para despliegue"""
	if use_deployment_component:
		return deployment_manager.get_valid_deployment_hexes()
	return []


func queue_mechs_for_deployment(mechs: Array) -> void:
	"""Añade mechs a la cola de despliegue"""
	if use_deployment_component:
		deployment_manager.queue_mechs_for_deployment(mechs)


func on_deployment_facing_selected(facing: int, selected_hex: Vector2i) -> bool:
	"""Procesa selección de facing durante despliegue"""
	if use_deployment_component:
		return deployment_manager.on_facing_selected(facing, selected_hex)
	return false


func continue_deployment_after_placement() -> void:
	"""Continúa con el siguiente mech después de colocar uno"""
	if use_deployment_component:
		deployment_manager.continue_after_placement()


func deploy_ai_mech() -> Dictionary:
	"""Despliega un mech de IA automáticamente"""
	if use_deployment_component:
		return deployment_manager.deploy_ai_mech()
	return {}


# ==============================================================================
# COMBAT COMPONENT FACADE
# ==============================================================================

func handle_weapon_attack_click(hex: Vector2i, selected_unit) -> bool:
	"""Maneja click para ataque con armas"""
	if use_combat_component:
		return combat_executor.handle_weapon_attack_click(hex, selected_unit)
	return false


func execute_weapon_attack(attacker, target, weapon_indices: Array, range_hexes: int) -> void:
	"""Ejecuta ataque con armas"""
	if use_combat_component:
		combat_executor.execute_weapon_attack(attacker, target, weapon_indices, range_hexes)


func execute_physical_attack(attacker, target, attack_type: String) -> void:
	"""Ejecuta ataque físico"""
	if use_combat_component:
		combat_executor.execute_physical_attack(attacker, target, attack_type)


func has_adjacent_enemies(unit) -> bool:
	"""Verifica si hay enemigos adyacentes"""
	if use_combat_component:
		return combat_executor.has_adjacent_enemies(unit)
	return false


func has_enemies_in_los(unit) -> bool:
	"""Verifica si la unidad tiene enemigos en línea de vista"""
	if use_combat_component:
		return combat_executor.has_enemies_in_los(unit)
	return false


func calculate_weapon_targets(unit) -> Array:
	"""Calcula y establece los hexes de objetivos con LoS"""
	if use_combat_component:
		return combat_executor.calculate_weapon_targets(unit)
	return []


func calculate_physical_targets(unit) -> Array:
	"""Calcula y establece los hexes de objetivos físicos (adyacentes)"""
	if use_combat_component:
		return combat_executor.calculate_physical_targets(unit)
	return []


func end_weapon_attack_phase() -> void:
	"""Finaliza la fase de ataque"""
	if use_combat_component:
		combat_executor.end_weapon_attack_phase()


func end_physical_attack_phase() -> void:
	"""Finaliza la fase de ataque físico"""
	if use_combat_component:
		combat_executor.end_physical_attack_phase()


# ==============================================================================
# HEAT COMPONENT FACADE
# ==============================================================================

func process_heat_phase() -> void:
	"""Procesa la fase de calor"""
	if use_heat_component:
		heat_manager.process_heat_phase()


# ==============================================================================
# STATE COMPONENT FACADE
# ==============================================================================

func check_battle_end() -> Dictionary:
	"""Verifica si la batalla terminó"""
	if use_state_component:
		return state_coordinator.check_battle_end()
	return {"ended": false}


func set_game_state(state: int) -> void:
	"""Cambia el estado del juego"""
	if use_state_component:
		state_coordinator.set_state(state)


func get_current_state() -> int:
	"""Retorna el estado actual"""
	if use_state_component:
		return state_coordinator.get_current_state()
	return GameEnums.GameState.MOVING  # Estado por defecto


func emit_initiative_messages(data: Dictionary) -> void:
	"""Emite mensajes de iniciativa"""
	if use_state_component:
		state_coordinator.emit_initiative_messages(data)


# ==============================================================================
# SIGNAL CONNECTIONS
# ==============================================================================

func _connect_camera_signals() -> void:
	"""Conecta señales del controlador de cámara"""
	camera_controller.hex_clicked.connect(_on_camera_hex_clicked)
	camera_controller.long_press_completed.connect(_on_camera_hex_long_pressed)
	camera_controller.camera_moved.connect(_on_camera_movement_detected)


func _connect_deployment_signals() -> void:
	"""Conecta señales del manager de despliegue"""
	deployment_manager.deployment_phase_started.connect(_on_deployment_started)
	deployment_manager.deployment_phase_ended.connect(_on_deployment_ended)
	deployment_manager.mech_deploy_requested.connect(_on_mech_deploy_requested)
	deployment_manager.show_facing_selector_requested.connect(_on_show_facing_selector)
	deployment_manager.deployment_message.connect(_on_combat_message)
	deployment_manager.my_deployment_complete.connect(_on_my_deployment_complete)
	deployment_manager.overlays_update_requested.connect(_on_overlays_update)
	deployment_manager.ai_deployment_started.connect(_on_ai_deployment_started)


func _connect_combat_signals() -> void:
	"""Conecta señales del executor de combate"""
	combat_executor.weapon_attack_started.connect(_on_weapon_attack_started)
	combat_executor.weapon_fired.connect(_on_weapon_fired)
	combat_executor.weapon_attack_completed.connect(_on_weapon_attack_completed)
	combat_executor.physical_attack_completed.connect(_on_physical_attack_completed)
	combat_executor.target_destroyed.connect(_on_target_destroyed)
	combat_executor.combat_message.connect(_on_combat_message)
	combat_executor.unit_info_update_requested.connect(_on_unit_info_update)
	combat_executor.battle_end_check_requested.connect(_on_battle_end_check)
	combat_executor.activation_complete_requested.connect(_on_activation_complete)


func _connect_heat_signals() -> void:
	"""Conecta señales del manager de calor"""
	heat_manager.heat_phase_started.connect(_on_heat_phase_started)
	heat_manager.heat_phase_completed.connect(_on_heat_phase_completed)
	heat_manager.mech_heat_processing_started.connect(_on_mech_heat_processing_started)
	heat_manager.mech_heat_processed.connect(_on_mech_heat_processed)
	heat_manager.mech_shutdown.connect(_on_mech_shutdown)
	heat_manager.mech_restarted.connect(_on_mech_restarted)
	heat_manager.mech_destroyed_by_heat.connect(_on_mech_destroyed_by_heat)
	heat_manager.ammo_explosion.connect(_on_ammo_explosion)
	heat_manager.combat_message.connect(_on_combat_message)
	heat_manager.unit_info_update_requested.connect(_on_unit_info_update)
	heat_manager.battle_end_check_requested.connect(_on_battle_end_check)


func _connect_state_signals() -> void:
	"""Conecta señales del coordinador de estado"""
	state_coordinator.state_changed.connect(_on_state_changed)
	state_coordinator.phase_changed.connect(_on_phase_changed)
	state_coordinator.turn_changed.connect(_on_turn_changed)
	state_coordinator.unit_activated.connect(_on_unit_activated)
	state_coordinator.battle_ended.connect(_on_battle_ended)
	state_coordinator.combat_message.connect(_on_combat_message)


func _connect_network_signals() -> void:
	"""Conecta señales del handler de red"""
	if not network_handler:
		return
	# Las señales del BattleNetworkHandler ahora se conectan directamente en battle_scene.gd
	# Este método se mantiene por compatibilidad pero no conecta nada
	Log.debug("Network", "BattleComponentsIntegrator: Network signals managed by battle_scene directly")


func _connect_input_signals() -> void:
	"""Conecta señales del router de input"""
	input_router.hex_clicked.connect(_on_input_hex_clicked)
	input_router.hex_long_pressed.connect(_on_input_hex_long_pressed)
	input_router.movement_gesture_detected.connect(_on_input_movement_gesture)


func _connect_movement_signals() -> void:
	"""Conecta señales del handler de movimiento"""
	movement_handler.movement_type_selected.connect(_on_movement_type_selected)
	movement_handler.movement_preview_shown.connect(_on_movement_preview_shown)
	movement_handler.movement_confirmed.connect(_on_movement_confirmed)
	movement_handler.movement_cancelled.connect(_on_movement_cancelled)
	movement_handler.movement_executed.connect(_on_movement_executed)
	movement_handler.movement_blocked.connect(_on_movement_blocked)
	movement_handler.turn_only_selected.connect(_on_turn_only_selected)
	movement_handler.facing_adjustment_requested.connect(_on_facing_adjustment_requested)
	movement_handler.combat_message.connect(_on_combat_message)
	movement_handler.overlays_update_requested.connect(_on_overlays_update)


# ==============================================================================
# SIGNAL HANDLERS - Forward to battle_scene
# ==============================================================================

func _on_camera_hex_clicked(hex: Vector2i) -> void:
	if battle_scene.has_method("_on_hex_clicked_from_component"):
		battle_scene._on_hex_clicked_from_component(hex)


func _on_camera_hex_long_pressed(hex: Vector2i) -> void:
	if battle_scene.has_method("_handle_mech_inspect"):
		battle_scene._handle_mech_inspect(hex)


func _on_camera_movement_detected() -> void:
	# Notificar que hubo movimiento de cámara
	pass


func _on_deployment_started() -> void:
	Log.info("Combat", "Deployment phase started via component")


func _on_deployment_ended() -> void:
	if battle_scene.has_method("_on_deployment_ended_from_component"):
		battle_scene._on_deployment_ended_from_component()


func _on_mech_deploy_requested(mech, hex: Vector2i, facing: int) -> void:
	if battle_scene.has_method("_place_mech"):
		battle_scene._place_mech(mech, hex, facing)
	
	# Actualizar overlays y continuar con el siguiente mech
	if battle_scene.has_method("update_overlays"):
		battle_scene.update_overlays()
	
	# Continuar despliegue después de un pequeño delay
	if battle_scene.has_method("_continue_deployment_from_component"):
		battle_scene._continue_deployment_from_component()


func _on_show_facing_selector(screen_pos: Vector2, hex: Vector2i) -> void:
	battle_scene.selected_hex = hex
	
	# En modo tutorial, usar el selector de tutorial con direcciones restringidas
	if battle_scene.is_tutorial_mode:
		var tutorial_mgr = battle_scene.get_node_or_null("/root/TutorialManager")
		Log.debug("Tutorial", "_on_show_facing_selector: tutorial_mode=true, tutorial_mgr=%s" % (tutorial_mgr != null))
		if tutorial_mgr and tutorial_mgr.battle_controller:
			var allowed = tutorial_mgr.battle_controller.allowed_facings
			Log.debug("Tutorial", "_on_show_facing_selector: allowed_facings=%s" % str(allowed))
			if allowed.size() > 0:
				# Hay facings restringidos - usar selector de tutorial
				Log.info("Tutorial", "Showing tutorial facing selector with allowed: %s" % str(allowed))
				if battle_scene.has_method("_ui_show_facing_selector_tutorial"):
					battle_scene._ui_show_facing_selector_tutorial(screen_pos, allowed[0], hex)
					return
	
	# Modo normal - mostrar todos los facings
	Log.debug("UI", "_on_show_facing_selector: Normal mode, is_tutorial=%s" % battle_scene.is_tutorial_mode)
	if battle_scene.has_method("_ui_show_facing_selector"):
		battle_scene._ui_show_facing_selector(screen_pos, hex)


func _on_my_deployment_complete() -> void:
	if battle_scene.has_method("_on_my_deployment_complete"):
		battle_scene._on_my_deployment_complete()


func _on_ai_deployment_started(mech) -> void:
	"""Maneja cuando la IA necesita desplegar un mech"""
	if battle_scene.has_method("_deploy_ai_mech"):
		# Sincronizar el mech actual al battle_scene
		battle_scene.current_deploying_mech = mech
		battle_scene._deploy_ai_mech()


func _on_overlays_update() -> void:
	# Sincronizar estado del deployment antes de actualizar overlays
	if use_deployment_component and deployment_manager.is_in_deployment_phase():
		battle_scene.valid_deployment_hexes = deployment_manager.get_valid_deployment_hexes()
		battle_scene.current_deploying_mech = deployment_manager.get_current_deploying_mech()
	
	if battle_scene.has_method("update_overlays"):
		battle_scene.update_overlays()


func _on_weapon_attack_started(attacker, target) -> void:
	if ui and ui.has_method("show_weapon_selector"):
		var range_hexes = hex_grid.hex_distance(attacker.hex_position, target.hex_position)
		ui.show_weapon_selector(attacker, target, range_hexes)
	
	# Trigger tutorial cuando se selecciona objetivo
	if battle_scene and battle_scene.has_method("_notify_tutorial"):
		battle_scene._notify_tutorial("target_selected")


func _on_weapon_fired(attacker, weapon: Dictionary, hit: bool, damage: int, location: String) -> void:
	"""Handler para cuando un arma dispara - tracking de estadísticas"""
	if battle_scene and battle_scene.has_method("_on_weapon_fired_stats"):
		battle_scene._on_weapon_fired_stats(attacker, weapon, hit, damage, location)
	
	# Trigger tutorial cuando el jugador recibe daño
	if hit and damage > 0:
		# Si el atacante es enemigo, el jugador recibió daño
		if attacker in combat_executor.enemy_mechs and battle_scene and battle_scene.has_method("_trigger_tutorial_event"):
			battle_scene._trigger_tutorial_event("damage_received")


func _on_weapon_attack_completed(attacker, _total_heat: int) -> void:
	if battle_scene.has_method("_end_weapon_attack_phase"):
		battle_scene._end_weapon_attack_phase()
	
	# Trigger tutorial cuando el jugador completa su ataque de armas
	if attacker in combat_executor.player_mechs and battle_scene and battle_scene.has_method("_notify_tutorial"):
		battle_scene._notify_tutorial("weapon_fired")


func _on_physical_attack_completed(attacker, target, attack_type: String, hit: bool) -> void:
	# Tracking de estadísticas
	if battle_scene and battle_scene.has_method("_on_physical_attack_stats"):
		battle_scene._on_physical_attack_stats(attacker, target, attack_type, hit)
	
	if battle_scene.has_method("_on_physical_attack_complete"):
		battle_scene._on_physical_attack_complete()


func _on_target_destroyed(target, destroyed_by) -> void:
	Log.info("Combat", "%s destroyed by %s" % [target.mech_name, destroyed_by.mech_name])
	# Tracking de estadísticas
	if battle_scene and battle_scene.has_method("_on_mech_destroyed_stats"):
		battle_scene._on_mech_destroyed_stats(target, destroyed_by)
	
	# Trigger tutorial cuando se destruye un enemigo
	if target in combat_executor.enemy_mechs and battle_scene and battle_scene.has_method("_trigger_tutorial_event"):
		battle_scene._trigger_tutorial_event("enemy_destroyed")


func _on_combat_message(text: String, color: Color) -> void:
	if ui and ui.has_method("add_combat_message"):
		ui.add_combat_message(text, color)


func _on_unit_info_update(unit) -> void:
	if ui and ui.has_method("update_unit_info"):
		ui.update_unit_info(unit)


func _on_battle_end_check() -> void:
	if battle_scene.has_method("_check_battle_end"):
		battle_scene._check_battle_end()


func _on_activation_complete() -> void:
	if turn_manager and turn_manager.has_method("complete_unit_activation"):
		turn_manager.complete_unit_activation()


func _on_heat_phase_started() -> void:
	Log.info("Combat", "Heat phase started via component")


func _on_heat_phase_completed() -> void:
	if turn_manager and turn_manager.has_method("advance_phase"):
		turn_manager.advance_phase()


func _on_mech_heat_processed(mech, initial: int, final: int, dissipated: int) -> void:
	Log.debug("Heat", "%s: %d -> %d (-%d)" % [mech.mech_name, initial, final, dissipated])


func _on_mech_heat_processing_started(mech) -> void:
	"""Cuando empieza a procesarse el calor de un mech, centrar la cámara en él"""
	Log.debug("Heat", "Processing heat for %s" % mech.mech_name)
	# Centrar cámara en el mech que está siendo procesado
	if camera_controller and camera_controller.has_method("pan_to_position"):
		camera_controller.pan_to_position(mech.position)


func _on_mech_shutdown(mech, automatic: bool) -> void:
	Log.warning("Heat", "%s shutdown! (automatic: %s)" % [mech.mech_name, automatic])
	# Mostrar efecto visual de shutdown
	if mech.has_method("show_shutdown_effect"):
		mech.show_shutdown_effect()
	# Mostrar anuncio dramático
	if ui and ui.has_method("show_shutdown_announcement"):
		ui.show_shutdown_announcement(mech.mech_name)


func _on_mech_restarted(mech) -> void:
	Log.info("Heat", "%s restarted!" % mech.mech_name)
	# Centrar cámara en el mech
	if camera_controller and camera_controller.has_method("pan_to_position"):
		camera_controller.pan_to_position(mech.position)
	# Ocultar efecto visual de shutdown
	if mech.has_method("hide_shutdown_effect"):
		mech.hide_shutdown_effect()
	# Mostrar anuncio de reinicio
	if ui and ui.has_method("show_restart_announcement"):
		ui.show_restart_announcement(mech.mech_name)


func _on_mech_destroyed_by_heat(mech, reason: String) -> void:
	Log.error("Heat", "%s destroyed: %s" % [mech.mech_name, reason])
	# Centrar cámara en el mech destruido
	if camera_controller and camera_controller.has_method("pan_to_position"):
		camera_controller.pan_to_position(mech.position)
	# Mostrar anuncio de destrucción
	if ui and ui.has_method("show_mech_destroyed_announcement"):
		ui.show_mech_destroyed_announcement(mech.mech_name)


func _on_ammo_explosion(mech, location: String, has_case: bool) -> void:
	"""Handler para explosiones de munición"""
	Log.error("Heat", "%s ammo explosion at %s (CASE: %s)" % [mech.mech_name, location, has_case])
	# Centrar cámara en el mech
	if camera_controller and camera_controller.has_method("pan_to_position"):
		camera_controller.pan_to_position(mech.position)
	# Mostrar efecto visual de explosión
	if mech.has_method("show_explosion_effect"):
		mech.show_explosion_effect()
	# Mostrar anuncio dramático
	if ui and ui.has_method("show_ammo_explosion_announcement"):
		ui.show_ammo_explosion_announcement(mech.mech_name)


func _on_state_changed(new_state: int) -> void:
	if battle_scene:
		battle_scene.current_state = new_state


func _on_phase_changed(phase: String) -> void:
	if ui and ui.has_method("update_phase_info"):
		ui.update_phase_info(phase)


func _on_turn_changed(team: String, turn_number: int) -> void:
	if ui and ui.has_method("update_turn_info"):
		ui.update_turn_info(turn_number, team)


func _on_unit_activated(unit) -> void:
	if battle_scene:
		battle_scene.selected_unit = unit


func _on_battle_ended(winner: String, loser: String, reason: String) -> void:
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over(winner, loser, reason)


# ==============================================================================
# NETWORK SIGNAL HANDLERS
# ==============================================================================

func _on_net_deployment_started(data: Dictionary) -> void:
	if battle_scene.has_method("_on_net_deployment_started"):
		battle_scene._on_net_deployment_started(data)


func _on_net_mech_deployed(data: Dictionary) -> void:
	if battle_scene.has_method("_on_net_mech_deployed"):
		battle_scene._on_net_mech_deployed(data)


func _on_net_initiative_result(data: Dictionary) -> void:
	if battle_scene.has_method("_on_net_initiative_result"):
		battle_scene._on_net_initiative_result(data)


func _on_net_phase_changed(data: Dictionary) -> void:
	if battle_scene.has_method("_on_net_phase_changed"):
		battle_scene._on_net_phase_changed(data)


func _on_net_unit_activated(data: Dictionary) -> void:
	if battle_scene.has_method("_on_net_unit_activated"):
		battle_scene._on_net_unit_activated(data)


func _on_net_mech_moved(data: Dictionary) -> void:
	if battle_scene.has_method("_on_net_mech_moved"):
		battle_scene._on_net_mech_moved(data)


func _on_net_mech_rotated(data: Dictionary) -> void:
	if battle_scene.has_method("_on_net_mech_rotated"):
		battle_scene._on_net_mech_rotated(data)


func _on_net_weapons_fired(data: Dictionary) -> void:
	if battle_scene.has_method("_on_net_weapons_fired"):
		battle_scene._on_net_weapons_fired(data)


func _on_net_physical_attack(data: Dictionary) -> void:
	if battle_scene.has_method("_on_net_physical_attack"):
		battle_scene._on_net_physical_attack(data)


func _on_net_heat_phase(data: Dictionary) -> void:
	if battle_scene.has_method("_on_net_heat_phase"):
		battle_scene._on_net_heat_phase(data)


func _on_net_battle_ended(data: Dictionary) -> void:
	if battle_scene.has_method("_on_net_battle_ended"):
		battle_scene._on_net_battle_ended(data)


func _on_net_action_rejected(data: Dictionary) -> void:
	if battle_scene.has_method("_on_net_action_rejected"):
		battle_scene._on_net_action_rejected(data)


func _on_net_opponent_disconnected(peer_id: int) -> void:
	if battle_scene.has_method("_on_net_opponent_disconnected"):
		battle_scene._on_net_opponent_disconnected(peer_id)


# ==============================================================================
# NETWORK COMPONENT FACADE
# ==============================================================================

func connect_network_signals() -> void:
	"""Conecta las señales de red del NetworkManager"""
	if use_network_component:
		network_handler.connect_signals()


func mp_request_move(unit, path: Array, type: int, facing: int) -> void:
	"""Solicita movimiento en multiplayer"""
	if use_network_component:
		network_handler.mp_request_move(unit, path, type, facing)


func mp_request_weapon_fire(attacker, target, weapon_indices: Array) -> void:
	"""Solicita disparo de armas en multiplayer"""
	if use_network_component:
		network_handler.mp_request_weapon_fire(attacker, target, weapon_indices)


func mp_request_physical_attack(attacker, target, attack_type: String) -> void:
	"""Solicita ataque físico en multiplayer"""
	if use_network_component:
		network_handler.mp_request_physical_attack(attacker, target, attack_type)


func mp_request_end_activation() -> void:
	"""Solicita fin de activación en multiplayer"""
	if use_network_component:
		network_handler.mp_request_end_activation()


func mp_request_deploy_mech(mech, hex: Vector2i, facing: int) -> void:
	"""Solicita despliegue de mech en multiplayer"""
	if use_network_component:
		network_handler.mp_request_deploy_mech(mech, hex, facing)


# ==============================================================================
# INPUT COMPONENT FACADE
# ==============================================================================

func process_input(event: InputEvent) -> bool:
	"""Procesa un evento de input via el router"""
	if use_input_component:
		return input_router.process_input(event)
	return false


func process_input_delta(delta: float) -> void:
	"""Procesa el delta frame para el router (long press, etc.)"""
	if use_input_component:
		input_router.process_delta(delta)


func set_input_deployment_phase(active: bool) -> void:
	"""Notifica al router que estamos en fase de despliegue"""
	if use_input_component:
		input_router.set_deployment_phase(active)


func set_input_battle_started(started: bool) -> void:
	"""Notifica al router que la batalla comenzó"""
	if use_input_component:
		input_router.set_battle_started(started)


func set_input_camera(camera: Camera2D) -> void:
	"""Establece la cámara para el router y camera_controller"""
	if use_input_component:
		input_router.set_camera(camera)
	if use_camera_component and camera_controller:
		camera_controller.camera = camera


func start_ignore_click_timer(duration_ms: int = 200) -> void:
	"""Ignora clicks durante duration_ms"""
	if use_input_component:
		input_router.start_ignore_click_timer(duration_ms)


func clear_ignore_click() -> void:
	"""Limpia el flag de ignorar click"""
	if use_input_component:
		input_router.clear_ignore_click()


func set_ui_interaction_cooldown(duration: float) -> void:
	"""Establece cooldown de UI"""
	if use_input_component:
		input_router.set_ui_cooldown(duration)


func reset_input_movement_flag() -> void:
	"""Reset del flag de movimiento significativo"""
	if use_input_component:
		input_router.reset_movement_flag()


# ==============================================================================
# INPUT SIGNAL HANDLERS
# ==============================================================================

func _on_input_hex_clicked(hex: Vector2i) -> void:
	"""Handler para click en hex"""
	if battle_scene.has_method("_handle_hex_clicked"):
		battle_scene._handle_hex_clicked(hex)


func _on_input_hex_long_pressed(hex: Vector2i) -> void:
	"""Handler para long press en hex"""
	if battle_scene.has_method("_handle_mech_inspect"):
		battle_scene._handle_mech_inspect(hex)


func _on_input_movement_gesture() -> void:
	"""Handler para cuando se detecta un gesto de movimiento"""
	# El battle_scene debe llamar a reset_movement_flag después de un frame
	pass


# ==============================================================================
# MOVEMENT COMPONENT FACADE
# ==============================================================================

func set_movement_selected_unit(unit) -> void:
	"""Establece la unidad seleccionada para movimiento"""
	if use_movement_component:
		movement_handler.set_selected_unit(unit)


func set_movement_player_mechs(mechs: Array) -> void:
	"""Actualiza referencias de mechs del jugador"""
	if use_movement_component:
		movement_handler.set_player_mechs(mechs)


func movement_select_type(movement_type: int) -> void:
	"""Selecciona tipo de movimiento (Walk/Run/Jump)"""
	if use_movement_component:
		movement_handler.select_movement_type(movement_type)


func movement_select_turn_only() -> void:
	"""Selecciona solo girar sin moverse"""
	if use_movement_component:
		movement_handler.select_turn_only()


func movement_cancel_selection() -> void:
	"""Cancela la selección de movimiento"""
	if use_movement_component:
		movement_handler.cancel_movement_selection()
	# Sincronizar estado con battle_scene
	if battle_scene:
		battle_scene.reachable_hexes = []
		battle_scene.reachable_hexes_details = {}
		battle_scene.preview_path = []
		battle_scene.preview_destination = Vector2i(-1, -1)
		battle_scene.pending_move_confirmation = false
		battle_scene.pending_movement_selection = true
		battle_scene.update_overlays()
		# Mostrar selector de tipo de movimiento
		if ui and battle_scene.selected_unit:
			if ui.has_method("hide_cancel_movement_button"):
				ui.hide_cancel_movement_button()
			if ui.has_method("show_movement_type_selector"):
				ui.show_movement_type_selector(battle_scene.selected_unit)
			if ui.has_method("add_combat_message"):
				ui.add_combat_message("Movement cancelled - select new movement type", Color.GRAY)


func movement_handle_click(hex: Vector2i) -> bool:
	"""Maneja click durante movimiento"""
	if use_movement_component:
		return movement_handler.handle_movement_click(hex)
	return false


func movement_confirm() -> void:
	"""Confirma el movimiento pendiente"""
	if use_movement_component:
		movement_handler.confirm_movement()


func movement_cancel() -> void:
	"""Cancela el movimiento pendiente"""
	if use_movement_component:
		movement_handler.cancel_movement()


func movement_get_reachable_hexes() -> Array:
	"""Retorna hexes alcanzables"""
	if use_movement_component:
		return movement_handler.reachable_hexes
	return []


func movement_get_preview_path() -> Array:
	"""Retorna el path de preview actual"""
	if use_movement_component:
		return movement_handler.preview_path
	return []


func movement_get_preview_destination() -> Vector2i:
	"""Retorna el destino del preview"""
	if use_movement_component:
		return movement_handler.preview_destination
	return Vector2i(-1, -1)


func movement_is_pending_confirmation() -> bool:
	"""Verifica si hay movimiento pendiente de confirmar"""
	if use_movement_component:
		return movement_handler.pending_move_confirmation
	return false


func movement_clear_state() -> void:
	"""Limpia todo el estado de movimiento"""
	if use_movement_component:
		movement_handler.clear_movement_state()


func movement_execute(mech: Mech, destination: Vector2i, path: Array) -> void:
	"""Ejecuta el movimiento de un mech - delega al movement_handler"""
	if use_movement_component and movement_handler:
		movement_handler.execute_movement(mech, destination, path)


# ==============================================================================
# MOVEMENT SIGNAL HANDLERS
# ==============================================================================

func _on_movement_type_selected(_mech, _movement_type: int) -> void:
	"""Handler cuando se selecciona tipo de movimiento"""
	# Sincronizar reachable_hexes con battle_scene para overlays
	if battle_scene:
		battle_scene.reachable_hexes = movement_handler.reachable_hexes
		battle_scene.reachable_hexes_details = movement_handler.reachable_hexes_details
		battle_scene.update_overlays()
	# Actualizar overlays con hexes alcanzables (si usa componente overlay)
	if use_overlay_component:
		overlay_manager.set_reachable_hexes(movement_handler.reachable_hexes)
		overlay_manager.update_and_render()
	# Notificar UI
	if ui and ui.has_method("show_cancel_movement_button"):
		ui.show_cancel_movement_button()


func _on_movement_preview_shown(path: Array, destination: Vector2i, cost: int) -> void:
	"""Handler cuando se muestra preview de movimiento"""
	# Sincronizar preview con battle_scene para overlays
	if battle_scene:
		battle_scene.preview_path = path
		battle_scene.preview_destination = destination
		battle_scene.pending_move_confirmation = true
		battle_scene.update_overlays()
	# Actualizar overlays (si usa componente overlay)
	if use_overlay_component:
		overlay_manager.set_preview_path(path)
		overlay_manager.update_and_render()
	# Mostrar menú de confirmación
	if battle_scene.has_method("_show_movement_confirmation_menu"):
		battle_scene._show_movement_confirmation_menu(destination, cost)


func _on_movement_confirmed(mech, destination: Vector2i, path: Array) -> void:
	"""Handler cuando se confirma movimiento"""
	if battle_scene.has_method("_execute_confirmed_movement"):
		battle_scene._execute_confirmed_movement(mech, destination, path)


func _on_movement_cancelled() -> void:
	"""Handler cuando se cancela movimiento"""
	# Sincronizar con battle_scene
	if battle_scene:
		battle_scene.preview_path = []
		battle_scene.preview_destination = Vector2i(-1, -1)
		battle_scene.pending_move_confirmation = false
		battle_scene.update_overlays()
	# Actualizar overlays (si usa componente overlay)
	if use_overlay_component:
		overlay_manager.clear_preview_path()
		overlay_manager.update_and_render()


func _on_movement_executed(mech, _from: Vector2i, _to: Vector2i, _cost: int) -> void:
	"""Handler cuando se ejecuta movimiento"""
	_on_overlays_update()
	# Ocultar botón de cancelar movimiento
	if ui and ui.has_method("hide_cancel_movement_button"):
		ui.hide_cancel_movement_button()
	if battle_scene.has_method("_on_movement_execution_complete"):
		battle_scene._on_movement_execution_complete(mech)


func _on_movement_blocked(mech, reason: String) -> void:
	"""Handler cuando movimiento está bloqueado"""
	if battle_scene.has_method("_on_component_movement_blocked"):
		battle_scene._on_component_movement_blocked(mech, reason)


func _on_turn_only_selected(mech) -> void:
	"""Handler cuando se selecciona solo girar"""
	# Sincronizar estado con battle_scene
	if battle_scene:
		battle_scene.pending_turn_only = true
		battle_scene.pending_movement_selection = false
	if battle_scene.has_method("_show_turn_only_facing_selector"):
		battle_scene._show_turn_only_facing_selector(mech)


func _on_facing_adjustment_requested(mech, _screen_pos: Vector2, _current_facing: int, _available_mp: int) -> void:
	"""Handler cuando se solicita ajuste de facing post-movimiento"""
	if battle_scene.has_method("_show_post_movement_facing_selector"):
		battle_scene._show_post_movement_facing_selector(mech, mech.hex_position)


# ==============================================================================
# OVERLAY COMPONENT FACADE
# ==============================================================================

func set_overlay_deployment_phase(active: bool) -> void:
	"""Activa/desactiva fase de despliegue en overlays"""
	if use_overlay_component:
		overlay_manager.set_deployment_phase(active)


func set_overlay_deployment_hexes(hexes: Array) -> void:
	"""Establece hexes de despliegue"""
	if use_overlay_component:
		overlay_manager.set_deployment_hexes(hexes)


func set_overlay_reachable_hexes(hexes: Array) -> void:
	"""Establece hexes alcanzables"""
	if use_overlay_component:
		overlay_manager.set_reachable_hexes(hexes)


func clear_overlay_reachable_hexes() -> void:
	"""Limpia hexes alcanzables"""
	if use_overlay_component:
		overlay_manager.clear_reachable_hexes()


func set_overlay_preview_path(path: Array) -> void:
	"""Establece preview path"""
	if use_overlay_component:
		overlay_manager.set_preview_path(path)


func clear_overlay_preview_path() -> void:
	"""Limpia preview path"""
	if use_overlay_component:
		overlay_manager.clear_preview_path()


func set_overlay_target_hexes(hexes: Array) -> void:
	"""Establece hexes objetivo"""
	if use_overlay_component:
		overlay_manager.set_target_hexes(hexes)


func clear_overlay_target_hexes() -> void:
	"""Limpia hexes objetivo"""
	if use_overlay_component:
		overlay_manager.clear_target_hexes()


func set_overlay_physical_target_hexes(hexes: Array) -> void:
	"""Establece hexes de ataque físico"""
	if use_overlay_component:
		overlay_manager.set_physical_target_hexes(hexes)


func clear_overlay_physical_target_hexes() -> void:
	"""Limpia hexes de ataque físico"""
	if use_overlay_component:
		overlay_manager.clear_physical_target_hexes()


func update_overlays() -> void:
	"""Actualiza y renderiza todos los overlays"""
	if use_overlay_component:
		# Sync LOS data from UI first
		if ui:
			overlay_manager.sync_from_ui(ui)
		overlay_manager.update_and_render()


func sync_and_update_overlays() -> void:
	"""Sincroniza datos de los componentes y actualiza overlays"""
	if not use_overlay_component:
		return
	
	# Sincronizar desde movement_handler
	if use_movement_component and movement_handler:
		overlay_manager.set_reachable_hexes(movement_handler.reachable_hexes)
		overlay_manager.set_preview_path(movement_handler.preview_path)
	
	# Sincronizar desde combat_executor
	if use_combat_component and combat_executor:
		overlay_manager.set_target_hexes(combat_executor.target_hexes)
		overlay_manager.set_physical_target_hexes(combat_executor.physical_target_hexes)
	
	# Sincronizar desde deployment_manager
	if use_deployment_component and deployment_manager:
		overlay_manager.set_deployment_phase(deployment_manager.is_in_deployment_phase())
		overlay_manager.set_deployment_hexes(deployment_manager.get_valid_deployment_hexes())
	
	# Sync LOS data from UI
	if ui:
		overlay_manager.sync_from_ui(ui)
	
	overlay_manager.update_and_render()


func clear_all_overlays() -> void:
	"""Limpia todos los overlays"""
	if use_overlay_component:
		overlay_manager.clear_all()
		overlay_manager.update_and_render()


func clear_all_phase_state() -> void:
	"""Limpia todo el estado de fase (movimiento, combate, overlays)"""
	# Limpiar estado de movimiento
	if use_movement_component and movement_handler:
		movement_handler.clear_movement_state()
	
	# Limpiar estado de combate
	if use_combat_component and combat_executor:
		combat_executor.clear_target_hexes()
	
	# Limpiar overlays
	clear_all_overlays()


func is_hex_in_movement_range(hex: Vector2i) -> bool:
	"""Verifica si un hex está en rango de movimiento"""
	if use_overlay_component:
		return overlay_manager.is_hex_in_movement_range(hex)
	return false


func is_hex_in_attack_range(hex: Vector2i) -> bool:
	"""Verifica si un hex está en rango de ataque"""
	if use_overlay_component:
		return overlay_manager.is_hex_in_attack_range(hex)
	return false


func get_overlay_preview_destination() -> Vector2i:
	"""Retorna el destino del preview path"""
	if use_overlay_component:
		return overlay_manager.get_preview_destination()
	return Vector2i(-1, -1)
