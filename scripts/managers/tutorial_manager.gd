extends Node

## TutorialManager - Gestiona el sistema de tutorial
## Singleton que controla cuándo mostrar el tutorial y su estado de completado
##
## El tutorial usa TutorialBattleController para una experiencia completamente guiada:
## - Mapa fijo y plano para visibilidad clara
## - Posiciones predeterminadas de mechs
## - Pasos controlados que esperan acción del jugador
## - Eventos forzados (shutdown, explosión de munición, etc.)

const TutorialBattleControllerClass = preload("res://scripts/managers/tutorial_battle_controller.gd")
const TUTORIAL_SAVE_PATH = "user://tutorial_completed.save"

# Señales
signal tutorial_started
signal tutorial_completed
signal hint_requested(hint_data: Dictionary)

# Estado
var is_tutorial_active: bool = false
var battle_controller: TutorialBattleControllerClass = null
var _battle_scene: Node = null
var movement_selector_blocked: bool = false  # Bloquea la aparición del selector de movimiento
var heat_phase_blocked: bool = false  # Bloquea la fase de calor hasta cerrar el hint

func _ready():
	Log.info("Tutorial", "TutorialManager initialized")

# ============================================================
# VERIFICACIÓN DE ESTADO
# ============================================================

func should_show_tutorial() -> bool:
	"""Verifica si es la primera partida y debería ofrecer el tutorial"""
	if FileAccess.file_exists(TUTORIAL_SAVE_PATH):
		var file = FileAccess.open(TUTORIAL_SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()
			if data is Dictionary and data.get("completed", false):
				return false
	return true

func is_tutorial_completed_state() -> bool:
	"""Verifica si el tutorial ya fue completado"""
	return not should_show_tutorial()

func is_heat_phase_blocked() -> bool:
	"""Verifica si la fase de calor está bloqueada por el tutorial"""
	return heat_phase_blocked

func reset_tutorial():
	"""Resetea el estado del tutorial para poder repetirlo"""
	if FileAccess.file_exists(TUTORIAL_SAVE_PATH):
		DirAccess.remove_absolute(TUTORIAL_SAVE_PATH)
	is_tutorial_active = false
	battle_controller = null
	_battle_scene = null
	Log.info("Tutorial", "Tutorial reset - will show again")

# ============================================================
# CONTROL DEL TUTORIAL
# ============================================================

func start_tutorial(battle_scene: Node):
	"""Inicia el tutorial en la escena de batalla"""
	is_tutorial_active = true
	_battle_scene = battle_scene
	
	# Crear el controlador de batalla tutorial
	battle_controller = TutorialBattleControllerClass.new()
	
	# Conectar señales del controlador
	battle_controller.hint_requested.connect(_on_hint_requested)
	battle_controller.input_blocked.connect(_on_input_blocked)
	battle_controller.input_unblocked.connect(_on_input_unblocked)
	battle_controller.force_action.connect(_on_force_action)
	battle_controller.tutorial_completed.connect(_on_tutorial_completed)
	
	tutorial_started.emit()
	Log.info("Tutorial", "Tutorial started with TutorialBattleController")
	
	# Iniciar el controlador
	battle_controller.start(battle_scene)

func skip_tutorial():
	"""Permite saltar el tutorial y marcarlo como completado"""
	_mark_completed()
	is_tutorial_active = false

func get_battle_controller() -> TutorialBattleControllerClass:
	"""Retorna el controlador de batalla del tutorial (para validaciones)"""
	return battle_controller

# ============================================================
# CALLBACKS DEL CONTROLADOR
# ============================================================

func _on_hint_requested(hint_data: Dictionary):
	"""Muestra un hint del tutorial"""
	hint_requested.emit(hint_data)
	
	if _battle_scene and _battle_scene.tutorial_hint_popup:
		_battle_scene.tutorial_hint_popup.show_hint(hint_data)
		Log.debug("Tutorial", "Showing hint: %s" % hint_data.get("id", "unknown"))

func _on_input_blocked():
	"""Bloquea el input del jugador"""
	Log.debug("Tutorial", "Input blocked")
	movement_selector_blocked = true
	
	# Ocultar el selector de movimiento si está visible
	if _battle_scene and _battle_scene.ui:
		if _battle_scene.ui.has_method("hide_movement_type_selector"):
			_battle_scene.ui.hide_movement_type_selector()
		# También ocultar otros paneles de interacción
		if _battle_scene.ui.has_method("hide_weapon_selector"):
			_battle_scene.ui.hide_weapon_selector()

func _on_input_unblocked():
	"""Desbloquea el input del jugador"""
	Log.debug("Tutorial", "Input unblocked")
	movement_selector_blocked = false

func _on_force_action(action_type: String, action_data: Dictionary):
	"""Fuerza una acción específica en la batalla"""
	if not _battle_scene:
		return
		
	Log.debug("Tutorial", "Force action: %s with data: %s" % [action_type, action_data])
	
	match action_type:
		"set_initiative":
			_force_initiative(action_data)
		"highlight_hexes":
			_highlight_tutorial_hexes(action_data)
		"force_facing":
			_force_player_facing(action_data)
		"enemy_deploy":
			_force_enemy_deploy(action_data)
		"enemy_move":
			_force_enemy_move(action_data)
		"enemy_attack":
			_force_enemy_attack(action_data)
		"enemy_overheat":
			_force_enemy_overheat(action_data)
		"ammo_explosion":
			_force_ammo_explosion(action_data)
		"block_initiative":
			_block_initiative_screen(action_data)
		"unblock_initiative":
			_unblock_initiative_screen()

func _on_tutorial_completed():
	"""El tutorial ha sido completado"""
	is_tutorial_active = false
	battle_controller = null
	_mark_completed()
	tutorial_completed.emit()
	Log.info("Tutorial", "Tutorial completed and saved!")

func _mark_completed():
	"""Marca el tutorial como completado"""
	var file = FileAccess.open(TUTORIAL_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var({
			"completed": true,
			"timestamp": Time.get_unix_time_from_system()
		})
		file.close()

# ============================================================
# ACCIONES FORZADAS
# ============================================================

func _force_initiative(_data: Dictionary):
	"""Fuerza el resultado de la iniciativa"""
	# TODO: Implementar cuando se integre con el sistema de iniciativa
	pass

func _highlight_tutorial_hexes(data: Dictionary):
	"""Resalta hexes específicos para el tutorial"""
	var hexes = data.get("hexes", [])
	Log.info("Tutorial", "_highlight_tutorial_hexes called with data: %s" % [data])
	
	if hexes.is_empty():
		Log.warning("Tutorial", "No hexes to highlight!")
		return
	
	# Usar el overlay_manager para resaltar (igual que otros overlays)
	if _battle_scene and _battle_scene.battle_components:
		var overlay_mgr = _battle_scene.battle_components.overlay_manager
		if overlay_mgr:
			overlay_mgr.set_tutorial_hexes(hexes)
			overlay_mgr.update_and_render()
			Log.info("Tutorial", "Highlighting %d hexes via overlay_manager" % hexes.size())
		else:
			Log.error("Tutorial", "No overlay_manager found!")
	else:
		Log.error("Tutorial", "Cannot highlight - no battle_components!")


func _force_player_facing(data: Dictionary):
	"""Fuerza el facing del mech del jugador después del deployment"""
	if not _battle_scene:
		return
	
	var facing = data.get("facing", 0)
	
	# Obtener el mech del jugador que acaba de desplegarse
	if _battle_scene.player_mechs.size() > 0:
		var player_mech = _battle_scene.player_mechs[0]
		player_mech.facing = facing
		if player_mech.has_method("update_facing_visual"):
			player_mech.update_facing_visual()
		Log.info("Tutorial", "Forced player facing to %d (North)" % facing)


var _initiative_blocked: bool = false

func _block_initiative_screen(_data: Dictionary):
	"""Bloquea la pantalla de iniciativa para que no aparezca"""
	_initiative_blocked = true
	Log.debug("Tutorial", "Initiative screen BLOCKED")


func _unblock_initiative_screen():
	"""Desbloquea la pantalla de iniciativa"""
	_initiative_blocked = false
	Log.debug("Tutorial", "Initiative screen UNBLOCKED")


func is_initiative_blocked() -> bool:
	"""Retorna si la pantalla de iniciativa está bloqueada"""
	return _initiative_blocked


func _force_enemy_deploy(data: Dictionary):
	"""Fuerza el deployment del enemigo"""
	if not _battle_scene:
		Log.error("Tutorial", "_force_enemy_deploy: No battle scene!")
		return
	
	# IMPORTANTE: Marcar que el tutorial ya desplegó al enemigo para evitar que _deploy_ai_mech lo haga
	_battle_scene.tutorial_enemy_already_deployed = true
		
	var target_hex = data.get("hex", Vector2i.ZERO)
	var facing = data.get("facing", 0)
	
	Log.info("Tutorial", "Forcing enemy deploy: hex=%s, facing=%d" % [target_hex, facing])
	Log.info("Tutorial", "  player_mechs=%d, enemy_mechs=%d, mechs_to_deploy=%d" % [
		_battle_scene.player_mechs.size(),
		_battle_scene.enemy_mechs.size(),
		_battle_scene.mechs_to_deploy.size()
	])
	
	# Buscar el mech enemigo - debe tener team="enemy"
	var enemy = null
	
	# Buscar en mechs_to_deploy (pendientes de desplegar) - prioridad
	for mech in _battle_scene.mechs_to_deploy:
		var team = mech.get_meta("team", "")
		Log.debug("Tutorial", "  mechs_to_deploy: %s (team=%s)" % [mech.mech_name, team])
		if team == "enemy":
			enemy = mech
			Log.info("Tutorial", "Found enemy in mechs_to_deploy: %s" % enemy.mech_name)
			break
	
	# Si no está en mechs_to_deploy, buscar en enemy_mechs
	if not enemy:
		for mech in _battle_scene.enemy_mechs:
			Log.debug("Tutorial", "  enemy_mechs: %s" % mech.mech_name)
			enemy = mech
			Log.info("Tutorial", "Found enemy in enemy_mechs: %s" % enemy.mech_name)
			break
	
	if not enemy:
		Log.error("Tutorial", "No enemy mech found! Creating one...")
		# Crear el mech enemigo si no existe
		var tutorial_enemy_data = TutorialBattleController.get_tutorial_enemy_mech()
		enemy = _battle_scene.mech_factory.create_for_deployment(tutorial_enemy_data, "enemy")
		if not enemy:
			Log.error("Tutorial", "Failed to create enemy mech!")
			return
	
	# IMPORTANTE: Terminar la fase de deployment ANTES de colocar el enemigo
	_battle_scene.deployment_phase = false
	if _battle_scene.battle_components:
		_battle_scene.battle_components.set_input_deployment_phase(false)
		if _battle_scene.battle_components.deployment_manager:
			_battle_scene.battle_components.deployment_manager.deployment_phase = false
	_battle_scene.mechs_to_deploy.clear()
	
	# Desplegar el enemigo en la posición correcta
	enemy.hex_position = target_hex
	enemy.facing = facing
	
	if _battle_scene.hex_grid:
		enemy.position = _battle_scene.hex_grid.hex_to_pixel(target_hex)
		_battle_scene.hex_grid.set_unit(target_hex, enemy)
	
	# Si el mech no está en la escena todavía, añadirlo
	if not enemy.is_inside_tree():
		_battle_scene.add_child(enemy)
	enemy.visible = true
	
	# Añadir a enemy_mechs si no está ya
	if enemy not in _battle_scene.enemy_mechs:
		_battle_scene.enemy_mechs.append(enemy)
	
	Log.info("Tutorial", "Enemy %s deployed at %s facing %d, position=%s" % [
		enemy.mech_name, target_hex, facing, enemy.position
	])
	
	# Actualizar visual del enemigo
	if enemy.has_method("update_visual_position"):
		enemy.update_visual_position(_battle_scene.hex_grid)
	if enemy.has_method("update_facing_visual"):
		enemy.update_facing_visual()
	
	# Actualizar referencias de mechs en componentes
	if _battle_scene.has_method("_update_components_mech_references"):
		_battle_scene._update_components_mech_references()
	
	# Centrar cámara en el enemigo con delay
	_center_camera_on_enemy_delayed(enemy, target_hex)


func _center_camera_on_enemy_delayed(_enemy, target_hex: Vector2i):
	"""Centra la cámara en el enemigo después de un pequeño delay"""
	Log.info("Tutorial", "_center_camera_on_enemy_delayed called for hex %s" % target_hex)
	
	if not _battle_scene:
		Log.error("Tutorial", "No battle scene in _center_camera_on_enemy_delayed!")
		return
	
	if not _battle_scene.hex_grid:
		Log.error("Tutorial", "No hex_grid in battle scene!")
		return
	
	if not _battle_scene.camera:
		Log.error("Tutorial", "No camera in battle scene!")
		return
	
	# Calcular la posición del hex directamente
	var target_pos = _battle_scene.hex_grid.hex_to_pixel(target_hex)
	Log.info("Tutorial", "Target position for camera: %s (current camera pos: %s)" % [target_pos, _battle_scene.camera.position])
	
	# Pequeño delay para que el mech sea visible primero
	await _battle_scene.get_tree().create_timer(0.2).timeout
	
	# Verificar que todo sigue válido después del await
	if not is_instance_valid(_battle_scene) or not is_instance_valid(_battle_scene.camera):
		Log.error("Tutorial", "Battle scene or camera invalidated after await!")
		return
	
	Log.info("Tutorial", "Starting camera tween to %s" % target_pos)
	
	# Mover la cámara con animación
	var tween = _battle_scene.create_tween()
	tween.tween_property(_battle_scene.camera, "position", target_pos, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Esperar a que termine el tween
	await tween.finished
	Log.info("Tutorial", "Camera centered on enemy at %s" % target_pos)

func _force_enemy_move(data: Dictionary):
	"""Fuerza el movimiento del enemigo"""
	if not _battle_scene:
		return
		
	var target_hex = data.get("hex", Vector2i.ZERO)
	var facing = data.get("facing", 0)
	
	if _battle_scene.enemy_mechs.size() > 0:
		var enemy = _battle_scene.enemy_mechs[0]
		# Mover el enemigo directamente
		enemy.hex_position = target_hex
		enemy.facing = facing
		# Bug reportado: esto asignaba enemy.position = hex_to_pixel(hex)
		# directamente, sin sumar hex_grid.position (offset de
		# Vector2(100, 200) en battle_scene.tscn) ni actualizar z_index.
		# El enemigo terminaba en un punto incorrecto del mapa - y si el
		# offset lo sacaba del viewport de la camara, parecia desaparecer
		# por completo. update_visual_position() es el mismo metodo que usa
		# el despliegue normal para hex_position -> pixeles.
		if _battle_scene.hex_grid and enemy.has_method("update_visual_position"):
			enemy.update_visual_position(_battle_scene.hex_grid)
		if enemy.has_method("update_facing_visual"):
			enemy.update_facing_visual()
		Log.debug("Tutorial", "Forced enemy move to %s facing %d" % [target_hex, facing])

func _force_enemy_attack(data: Dictionary):
	"""Fuerza un ataque del enemigo con daño controlado"""
	if not _battle_scene:
		return
		
	var damage = data.get("damage", 10)
	var location = data.get("location", "center_torso")
	
	if _battle_scene.player_mechs.size() > 0:
		var player_mech = _battle_scene.player_mechs[0]
		# Aplicar daño controlado
		if player_mech.armor.has(location):
			player_mech.armor[location]["current"] = max(0, player_mech.armor[location]["current"] - damage)
		Log.debug("Tutorial", "Forced enemy attack: %d damage to %s" % [damage, location])
		
		# Actualizar visual si existe paper doll
		if player_mech.has_method("update_visuals"):
			player_mech.update_visuals()

func _force_enemy_overheat(data: Dictionary):
	"""Fuerza al enemigo a sobrecalentarse y apagarse"""
	if not _battle_scene:
		return
		
	var heat = data.get("heat", 30)
	
	if _battle_scene.enemy_mechs.size() > 0:
		var enemy = _battle_scene.enemy_mechs[0]
		enemy.heat = heat
		enemy.is_shutdown = true
		Log.debug("Tutorial", "Forced enemy overheat: heat=%d, shutdown=true" % heat)
		
		# Actualizar visual
		if enemy.has_method("update_visuals"):
			enemy.update_visuals()

func _force_ammo_explosion(data: Dictionary):
	"""Fuerza una explosión de munición en el enemigo"""
	if not _battle_scene:
		return
		
	var location = data.get("location", "right_torso")
	var damage = data.get("damage", 20)
	
	if _battle_scene.enemy_mechs.size() > 0:
		var enemy = _battle_scene.enemy_mechs[0]
		# Destruir la ubicación
		if enemy.structure.has(location):
			enemy.structure[location]["current"] = 0
		if enemy.armor.has(location):
			enemy.armor[location]["current"] = 0
		# Marcar como destruido si es mucho daño
		if location == "center_torso" or damage >= 40:
			enemy.is_destroyed = true
		Log.debug("Tutorial", "Forced ammo explosion in %s for %d damage" % [location, damage])
		
		# Actualizar visual
		if enemy.has_method("update_visuals"):
			enemy.update_visuals()

# ============================================================
# DATOS DE MECHS DEL TUTORIAL (delegados al controlador)
# ============================================================

func get_tutorial_player_mech() -> Dictionary:
	"""Retorna los datos del mech del jugador para el tutorial"""
	return TutorialBattleController.get_tutorial_player_mech()

func get_tutorial_enemy_mech() -> Dictionary:
	"""Retorna los datos del mech enemigo para el tutorial"""
	return TutorialBattleController.get_tutorial_enemy_mech()

# ============================================================
# VALIDACIONES DESDE BATTLE_SCENE
# ============================================================

func is_hex_allowed(hex: Vector2i) -> bool:
	"""Verifica si un hex está permitido en el paso actual"""
	if battle_controller:
		return battle_controller.is_hex_allowed(hex)
	return true

func is_facing_allowed(facing: int) -> bool:
	"""Verifica si un facing está permitido"""
	if battle_controller:
		return battle_controller.is_facing_allowed(facing)
	return true

func can_select_movement_type(type: String) -> bool:
	"""Verifica si se puede seleccionar un tipo de movimiento"""
	if battle_controller:
		return battle_controller.can_select_movement_type(type)
	return true

func can_skip_movement() -> bool:
	"""Verifica si se puede saltar el movimiento"""
	if battle_controller:
		return battle_controller.can_skip_movement()
	return true

func can_skip_attack() -> bool:
	"""Verifica si se puede saltar el ataque"""
	if battle_controller:
		return battle_controller.can_skip_attack()
	return true

# ============================================================
# NOTIFICACIONES DESDE BATTLE_SCENE
# ============================================================

func _hide_action_hint():
	"""Oculta el hint actual sin emitir señales (para acciones completadas)"""
	if _battle_scene and _battle_scene.tutorial_hint_popup:
		var popup = _battle_scene.tutorial_hint_popup
		if popup.action_required_mode:
			popup.hide_hint_silent()

func notify_deployment_completed(hex: Vector2i):
	"""Notifica que se completó el deployment"""
	_hide_action_hint()
	# Limpiar highlight usando overlay_manager
	_clear_tutorial_highlights()
	if battle_controller:
		battle_controller.on_deployment_completed(hex)

func _clear_tutorial_highlights():
	"""Limpia los highlights del tutorial"""
	if _battle_scene and _battle_scene.battle_components:
		var overlay_mgr = _battle_scene.battle_components.overlay_manager
		if overlay_mgr:
			overlay_mgr.clear_tutorial_hexes()
			overlay_mgr.update_and_render()

func notify_deployment_facing_selected(facing: int):
	"""Notifica que se eligió el facing de deployment"""
	_hide_action_hint()
	if battle_controller:
		battle_controller.on_deployment_facing_selected(facing)

func notify_movement_type_selected(type: String):
	"""Notifica que se seleccionó un tipo de movimiento"""
	if battle_controller:
		battle_controller.on_movement_type_selected(type)

func notify_movement_completed(hex: Vector2i):
	"""Notifica que se completó el movimiento"""
	if battle_controller:
		battle_controller.on_movement_completed(hex)

func notify_facing_selected(facing: int):
	"""Notifica que se seleccionó el facing"""
	if battle_controller:
		battle_controller.on_facing_selected(facing)

func notify_target_selected():
	"""Notifica que se seleccionó un objetivo"""
	if battle_controller:
		battle_controller.on_target_selected()

func notify_weapons_selected():
	"""Notifica que se seleccionaron armas"""
	if battle_controller:
		battle_controller.on_weapons_selected()

func notify_weapon_fired():
	"""Notifica que se dispararon armas"""
	if battle_controller:
		battle_controller.on_weapon_fired()

func notify_physical_attack_completed():
	"""Notifica que se completó un ataque físico"""
	if battle_controller:
		battle_controller.on_physical_attack_completed()

func notify_initiative_completed(data: Dictionary):
	"""Notifica que se completó la tirada de iniciativa"""
	if battle_controller:
		battle_controller.on_initiative_completed(data)

func notify_hint_dismissed():
	"""Notifica que se cerró un hint"""
	if battle_controller:
		battle_controller.on_hint_dismissed()

# ============================================================
# COMPATIBILIDAD CON CÓDIGO ANTERIOR
# ============================================================

# Estos métodos mantienen compatibilidad con el código anterior pero ya no hacen nada
# El nuevo sistema usa notify_* en su lugar

func on_battle_started():
	pass

func on_initiative_phase():
	pass

func on_movement_phase_start(_unit_is_player: bool):
	pass

func on_movement_type_selected():
	pass

func on_movement_completed():
	pass

func on_weapon_attack_phase(_unit_is_player: bool):
	pass

func notify_weapon_attack_phase():
	"""Notifica que empieza la fase de ataque con armas"""
	if battle_controller:
		battle_controller.on_weapon_attack_phase()

func on_target_selected():
	pass

func on_heat_increased(_current_heat: int):
	pass

func on_physical_attack_available():
	pass

func on_damage_received_first_time():
	pass

func on_enemy_destroyed():
	pass
