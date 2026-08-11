## BattleDeploymentManager - Gestiona la fase de despliegue de mechs
## Responsabilidad única: Lógica de despliegue inicial de unidades
## Extraído de battle_scene.gd como parte del refactoring SOLID
class_name BattleDeploymentManager
extends RefCounted

# ==============================================================================
# SIGNALS
# ==============================================================================
signal deployment_phase_started()
signal deployment_phase_ended()
signal mech_deploy_requested(mech: Mech, hex: Vector2i, facing: int)
signal ai_deployment_started(mech: Mech)
signal show_facing_selector_requested(screen_pos: Vector2, hex: Vector2i)
signal deployment_message(text: String, color: Color)
signal my_deployment_complete()  # Para multiplayer
signal overlays_update_requested()

# ==============================================================================
# STATE
# ==============================================================================
var deployment_phase: bool = false
var mechs_to_deploy: Array[Mech] = []
var current_deploying_mech: Mech = null
var valid_deployment_hexes: Array = []
var deployment_zones: Dictionary = {}

# ==============================================================================
# REFERENCES
# ==============================================================================
var hex_grid: HexGrid = null
var is_multiplayer_mode: bool = false
var my_team: String = ""
var battle_adapter = null  # BattleSceneAdapter


func setup(p_hex_grid: HexGrid, p_is_multiplayer: bool = false, p_my_team: String = "") -> void:
	"""Configura el deployment manager con referencias necesarias"""
	hex_grid = p_hex_grid
	is_multiplayer_mode = p_is_multiplayer
	my_team = p_my_team


func set_battle_adapter(adapter) -> void:
	"""Establece el adaptador de batalla unificado"""
	battle_adapter = adapter


func set_deployment_zones(zones: Dictionary) -> void:
	"""Establece las zonas de despliegue"""
	deployment_zones = zones


func queue_mechs_for_deployment(mechs: Array) -> void:
	"""Añade mechs a la cola de despliegue"""
	for mech in mechs:
		if mech is Mech:
			mechs_to_deploy.append(mech)


func start_deployment_phase() -> void:
	"""Inicia la fase de despliegue"""
	deployment_phase = true
	Log.info("Combat", "========== DEPLOYMENT PHASE STARTED ==========")
	Log.debug("Combat", "deployment_phase = %s" % deployment_phase)
	Log.debug("Combat", "mechs_to_deploy count = %d" % mechs_to_deploy.size())
	
	# Contar total de mechs por equipo
	var total_player = 0
	var total_enemy = 0
	for mech in mechs_to_deploy:
		if mech.get_meta("team") == "player":
			total_player += 1
		else:
			total_enemy += 1
	
	# Emitir mensajes de UI
	deployment_message.emit("", Color.WHITE)
	deployment_message.emit("╔════════════════════════════════════════════╗", Color.GOLD)
	deployment_message.emit("║       DEPLOYMENT PHASE - PLACE MECHS      ║", Color.GOLD)
	deployment_message.emit("╚════════════════════════════════════════════╝", Color.GOLD)
	deployment_message.emit("", Color.WHITE)
	deployment_message.emit("📋 MISSION BRIEF:", Color.CYAN)
	deployment_message.emit("  • Your Lance: %d mechs to deploy" % total_player, Color.WHITE)
	deployment_message.emit("  • Enemy Force: %d mechs detected" % total_enemy, Color.RED)
	deployment_message.emit("", Color.WHITE)
	deployment_message.emit("🎯 DEPLOYMENT INSTRUCTIONS:", Color.YELLOW)
	deployment_message.emit("  1. Click on a GREEN hex in the southern zone", Color.WHITE)
	deployment_message.emit("  2. Select facing direction for each mech", Color.WHITE)
	deployment_message.emit("  3. Deploy all %d mechs to begin battle" % total_player, Color.WHITE)
	deployment_message.emit("", Color.WHITE)
	
	deployment_phase_started.emit()
	
	# Comenzar con el primer mech
	deploy_next_mech()


func deploy_next_mech() -> void:
	"""Selecciona el siguiente mech para desplegar"""
	
	if mechs_to_deploy.is_empty():
		# En multiplayer, notificar que terminamos de desplegar
		if is_multiplayer_mode:
			Log.info("Network", "All my mechs deployed, notifying server...")
			_on_my_deployment_complete()
		else:
			end_deployment_phase()
		return
	
	current_deploying_mech = mechs_to_deploy.pop_front()
	var mech_team = current_deploying_mech.get_meta("team")
	
	# Contar cuántos mechs quedan por desplegar de MI equipo
	var my_remaining = _count_my_remaining_mechs()
	
	# Determinar si este mech es MÍO (debo desplegarlo manualmente)
	var is_my_mech = _is_my_mech(mech_team)
	
	if is_my_mech:
		_setup_player_deployment(my_remaining)
	else:
		# En singleplayer: IA despliega automáticamente
		# En multiplayer: NO debería llegar aquí
		if is_multiplayer_mode:
			push_error("[DEPLOY] Trying to deploy opponent's mech locally - this shouldn't happen!")
			deploy_next_mech()
		else:
			ai_deployment_started.emit(current_deploying_mech)


func _count_my_remaining_mechs() -> int:
	"""Cuenta cuántos mechs de mi equipo quedan por desplegar"""
	var my_remaining = 0
	for mech in mechs_to_deploy:
		var t = mech.get_meta("team")
		if is_multiplayer_mode:
			if t == my_team:
				my_remaining += 1
		else:
			if t == "player":
				my_remaining += 1
	return my_remaining


func _is_my_mech(mech_team: String) -> bool:
	"""Determina si el mech es controlado por este cliente"""
	if is_multiplayer_mode:
		return mech_team == my_team
	else:
		return mech_team == "player"


func _setup_player_deployment(my_remaining: int) -> void:
	"""Configura el despliegue manual del jugador"""
	# Determinar zona de despliegue
	var my_zone = my_team if is_multiplayer_mode and my_team != "" else "player"
	
	# Usar sistema unificado si está disponible
	if battle_adapter and battle_adapter.has_method("get_deployment_zone"):
		valid_deployment_hexes = Array(battle_adapter.get_deployment_zone(my_zone))
		Log.debug("Combat", "Using unified system for zone '%s' - valid hexes: %d" % [my_zone, valid_deployment_hexes.size()])
	elif deployment_zones.has(my_zone):
		valid_deployment_hexes = deployment_zones[my_zone].duplicate()
		Log.debug("Combat", "My zone: %s, valid hexes: %d" % [my_zone, valid_deployment_hexes.size()])
	else:
		push_error("[DEPLOY] Zone not found for team: %s, available zones: %s" % [my_zone, deployment_zones.keys()])
		valid_deployment_hexes = deployment_zones.get("player", []).duplicate()
	
	# Emitir mensajes de UI
	var total_my_mechs = 1 + my_remaining
	var deployed_count = (4 - total_my_mechs)
	if deployed_count < 0:
		deployed_count = 0
	var current_num = deployed_count + 1
	
	deployment_message.emit("─────────────────────────────────────────", Color.GRAY)
	deployment_message.emit("⚔️  DEPLOYING MECH [%d/%d]" % [current_num, deployed_count + total_my_mechs], Color.GOLD)
	deployment_message.emit("─────────────────────────────────────────", Color.GRAY)
	deployment_message.emit("🤖 Mech: %s" % current_deploying_mech.mech_name, Color.CYAN)
	deployment_message.emit("⚖️  Tonnage: %d tons" % current_deploying_mech.tonnage, Color.WHITE)
	deployment_message.emit("🏃 Movement: Walk %d / Run %d" % [current_deploying_mech.walk_mp, current_deploying_mech.run_mp], Color.WHITE)
	if current_deploying_mech.jump_mp > 0:
		deployment_message.emit("🚀 Jump: %d MP" % current_deploying_mech.jump_mp, Color.LIGHT_BLUE)
	deployment_message.emit("", Color.WHITE)
	if my_remaining > 0:
		deployment_message.emit("📊 Progress: %d deployed, %d remaining" % [deployed_count, my_remaining], Color.YELLOW)
	else:
		deployment_message.emit("📊 Progress: This is your LAST mech!", Color.ORANGE)
	deployment_message.emit("👉 Click on a GREEN hex to deploy", Color.GREEN)
	deployment_message.emit("", Color.WHITE)
	
	overlays_update_requested.emit()


func handle_hex_click(hex: Vector2i, screen_pos: Vector2) -> bool:
	"""Maneja click en hex durante fase de despliegue. Retorna true si fue procesado."""
	if not deployment_phase or not current_deploying_mech:
		return false
	
	# Verificar si el tutorial permite este hex
	var tutorial_mgr = Engine.get_singleton("TutorialManager") if Engine.has_singleton("TutorialManager") else null
	if not tutorial_mgr:
		# Intentar obtenerlo del árbol de nodos
		var main = Engine.get_main_loop()
		if main and main.root:
			tutorial_mgr = main.root.get_node_or_null("/root/TutorialManager")
	
	if tutorial_mgr and tutorial_mgr.is_tutorial_active:
		if not tutorial_mgr.is_hex_allowed(hex):
			# Hex no permitido por el tutorial
			deployment_message.emit("⚠️ Deploy on the highlighted hex", Color.YELLOW)
			return true  # Consumimos el click pero no procesamos
	
	if hex in valid_deployment_hexes and not hex_grid.get_unit(hex):
		# Mostrar selector de facing
		show_facing_selector_requested.emit(screen_pos, hex)
		return true
	
	return false


func is_valid_deployment_hex(hex: Vector2i) -> bool:
	"""Verifica si un hex es válido para despliegue"""
	return hex in valid_deployment_hexes and not hex_grid.get_unit(hex)


func get_valid_deployment_hexes() -> Array:
	"""Retorna los hexes válidos para despliegue actual"""
	return valid_deployment_hexes


func on_facing_selected(facing: int, selected_hex: Vector2i) -> bool:
	"""Procesa la selección de facing durante despliegue. Retorna true si fue procesado."""
	if not deployment_phase or not current_deploying_mech or selected_hex == Vector2i(-1, -1):
		return false
	
	# Notificar al tutorial
	var tutorial_mgr = Engine.get_singleton("TutorialManager") if Engine.has_singleton("TutorialManager") else null
	if not tutorial_mgr:
		var main = Engine.get_main_loop()
		if main and main.root:
			tutorial_mgr = main.root.get_node_or_null("/root/TutorialManager")
	
	if tutorial_mgr and tutorial_mgr.is_tutorial_active:
		# Primero notificar el deployment del hex
		tutorial_mgr.notify_deployment_completed(selected_hex)
		# Luego notificar el facing
		tutorial_mgr.notify_deployment_facing_selected(facing)
	
	# Emitir evento para que battle_scene coloque el mech
	mech_deploy_requested.emit(current_deploying_mech, selected_hex, facing)
	return true


func continue_after_placement() -> void:
	"""Continúa con el siguiente mech después de colocar uno"""
	deploy_next_mech()


func _on_my_deployment_complete() -> void:
	"""Llamado en multiplayer cuando este cliente termina de desplegar todos sus mechs"""
	deployment_phase = false
	valid_deployment_hexes.clear()
	current_deploying_mech = null
	
	deployment_message.emit("", Color.WHITE)
	deployment_message.emit("╔══════════════════════════════════════════╗", Color.CYAN)
	deployment_message.emit("║   ✓ YOUR DEPLOYMENT COMPLETE!           ║", Color.CYAN)
	deployment_message.emit("║   Waiting for opponent...               ║", Color.YELLOW)
	deployment_message.emit("╚══════════════════════════════════════════╝", Color.CYAN)
	deployment_message.emit("", Color.WHITE)
	
	my_deployment_complete.emit()


func end_deployment_phase() -> void:
	"""Finaliza la fase de despliegue"""
	deployment_phase = false
	valid_deployment_hexes.clear()
	current_deploying_mech = null
	
	deployment_phase_ended.emit()


func deploy_ai_mech() -> Dictionary:
	"""Despliega un mech de IA automáticamente. Retorna {hex, facing} o {} si falla."""
	if not current_deploying_mech:
		return {}
	
	var team = current_deploying_mech.get_meta("team")
	if not deployment_zones.has(team):
		push_error("[DEPLOY] No zone for AI team: %s" % team)
		return {}
	
	var zone = deployment_zones[team]
	
	# Elegir una posición aleatoria válida
	var valid_hexes = []
	for hex in zone:
		if not hex_grid.get_unit(hex):
			valid_hexes.append(hex)
	
	if valid_hexes.is_empty():
		push_error("No valid deployment hexes for AI")
		return {}
	
	var deploy_hex = valid_hexes[randi() % valid_hexes.size()]
	var facing = randi() % 6  # Orientación aleatoria
	
	# Calcular info para mensaje
	var enemy_remaining = 0
	for mech in mechs_to_deploy:
		if mech.get_meta("team") == team:
			enemy_remaining += 1
	
	return {
		"hex": deploy_hex,
		"facing": facing,
		"mech": current_deploying_mech,
		"remaining": enemy_remaining
	}


func is_in_deployment_phase() -> bool:
	"""Retorna si estamos en fase de despliegue"""
	return deployment_phase


func get_current_deploying_mech() -> Mech:
	"""Retorna el mech que se está desplegando actualmente"""
	return current_deploying_mech


func get_remaining_count() -> int:
	"""Retorna cuántos mechs quedan por desplegar"""
	return mechs_to_deploy.size()
