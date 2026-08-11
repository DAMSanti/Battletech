## BattleHeatManager - Gestiona el sistema de calor en batalla
## Responsabilidad única: Procesamiento de fase de calor, disipación, y efectos
## Extraído de battle_scene.gd como parte del refactoring SOLID
class_name BattleHeatManager
extends RefCounted

# ==============================================================================
# SIGNALS
# ==============================================================================
signal heat_phase_started()
signal heat_phase_completed()
signal mech_heat_processing_started(mech: Mech)
signal mech_heat_processed(mech: Mech, initial: int, final: int, dissipated: int)
signal mech_shutdown(mech: Mech, automatic: bool)
signal mech_restarted(mech: Mech)
signal ammo_explosion(mech: Mech, location: String, has_case: bool)
signal mech_destroyed_by_heat(mech: Mech, reason: String)
signal combat_message(text: String, color: Color)
signal unit_info_update_requested(mech: Mech)
signal battle_end_check_requested()

# ==============================================================================
# CONSTANTS
# ==============================================================================
const HEAT_PROCESS_DELAY: float = 1.2  # Pausa entre mechs para visualización
const TUTORIAL_HEAT_PROCESS_DELAY: float = 2.8  # Pausa más larga en el tutorial: da tiempo a ver la barra de calor bajar

# ==============================================================================
# STATE
# ==============================================================================
var processing_heat: bool = false
var _scene_tree: SceneTree = null
var _current_mech_index: int = 0
var _mechs_to_process: Array = []
var _is_tutorial: bool = false

# ==============================================================================
# REFERENCES
# ==============================================================================
var player_mechs: Array = []
var enemy_mechs: Array = []


func set_mechs(p_player_mechs: Array, p_enemy_mechs: Array) -> void:
	"""Actualiza las referencias a mechs"""
	player_mechs = p_player_mechs
	enemy_mechs = p_enemy_mechs


func set_scene_tree(tree: SceneTree) -> void:
	"""Establece la referencia al SceneTree para poder usar timers"""
	_scene_tree = tree


func process_heat_phase() -> void:
	"""Inicia la fase de calor - procesa los mechs de forma iterativa"""
	
	# En modo tutorial, esperar a que el hint de heat esté cerrado
	var tutorial_mgr = Engine.get_singleton("TutorialManager") if Engine.has_singleton("TutorialManager") else null
	if not tutorial_mgr:
		# Intentar obtener del árbol si existe
		if _scene_tree:
			tutorial_mgr = _scene_tree.root.get_node_or_null("/root/TutorialManager")
	
	_is_tutorial = tutorial_mgr != null and tutorial_mgr.is_tutorial_active

	if _is_tutorial:
		# Esperar a que el hint de heat se cierre antes de procesar
		while tutorial_mgr.is_heat_phase_blocked():
			if _scene_tree:
				await _scene_tree.create_timer(0.1).timeout
			else:
				break

	processing_heat = true
	heat_phase_started.emit()
	
	combat_message.emit("", Color.WHITE)
	combat_message.emit("═══════════════════════════════", Color.ORANGE)
	combat_message.emit("        HEAT PHASE", Color.ORANGE)
	combat_message.emit("═══════════════════════════════", Color.ORANGE)
	
	# Construir lista de mechs a procesar
	_mechs_to_process.clear()
	var all_mechs = player_mechs + enemy_mechs
	for mech in all_mechs:
		if not mech.is_destroyed:
			_mechs_to_process.append(mech)
	
	_current_mech_index = 0
	
	# Si no hay mechs a procesar, terminar inmediatamente
	if _mechs_to_process.is_empty():
		_finish_heat_phase()
		return
	
	# Iniciar procesamiento del primer mech después de un pequeño delay
	_schedule_next_mech_processing()


func _schedule_next_mech_processing() -> void:
	"""Programa el procesamiento del siguiente mech usando timer"""
	if not _scene_tree:
		# Sin SceneTree, procesar todo síncronamente
		_process_all_mechs_sync()
		return
	
	# Crear timer para procesar el siguiente mech (más lento en tutorial para
	# dar tiempo real a observar cómo baja la barra de calor tras disipar)
	var delay = TUTORIAL_HEAT_PROCESS_DELAY if _is_tutorial else HEAT_PROCESS_DELAY
	var timer = _scene_tree.create_timer(delay)
	timer.timeout.connect(_process_next_mech, CONNECT_ONE_SHOT)


func _process_all_mechs_sync() -> void:
	"""Fallback: procesa todos los mechs síncronamente"""
	for mech in _mechs_to_process:
		mech_heat_processing_started.emit(mech)
		_process_mech_heat(mech)
	_finish_heat_phase()


func _process_next_mech() -> void:
	"""Procesa el siguiente mech en la cola"""
	if _current_mech_index >= _mechs_to_process.size():
		_finish_heat_phase()
		return
	
	var mech = _mechs_to_process[_current_mech_index]
	
	# Emitir señal de que empezamos a procesar este mech
	mech_heat_processing_started.emit(mech)
	
	# Procesar calor de este mech
	_process_mech_heat(mech)
	
	_current_mech_index += 1
	
	# Programar siguiente mech con delay
	if _current_mech_index < _mechs_to_process.size():
		_schedule_next_mech_processing()
	else:
		# Era el último mech
		_finish_heat_phase()


func _finish_heat_phase() -> void:
	"""Finaliza la fase de calor"""
	processing_heat = false
	heat_phase_completed.emit()


func _process_mech_heat(mech: Mech) -> void:
	"""Procesa el calor de un mech individual"""
	var initial_heat = mech.heat
	
	combat_message.emit("", Color.WHITE)
	combat_message.emit("%s (Heat: %d)" % [mech.mech_name, initial_heat], Color.CYAN)
	
	# 1. Verificar shutdown ANTES de disipar
	_check_shutdown(mech, initial_heat)
	
	# 2. Verificar explosión de munición
	_check_ammo_explosion(mech, initial_heat)
	
	# 3. Disipar calor
	var dissipation_result = mech.dissipate_heat()
	var heat_removed = dissipation_result["heat_removed"]
	var current_heat = dissipation_result["current_heat"]
	
	combat_message.emit("  → Dissipated %d heat (%d -> %d)" % [heat_removed, initial_heat, current_heat], Color.LIGHT_BLUE)
	
	# Actualizar UI
	unit_info_update_requested.emit(mech)
	
	if dissipation_result.get("restarted", false):
		combat_message.emit("  ✓ MECH RESTARTED!", Color.GREEN)
		mech_restarted.emit(mech)
	
	# Mostrar efectos del calor restante
	if current_heat > 0:
		var heat_desc = HeatSystem.get_heat_description(current_heat)
		combat_message.emit("  Status: %s" % heat_desc, HeatSystem.get_heat_status_color(current_heat, mech.heat_capacity))
	
	# Actualizar visualización
	mech.queue_redraw()
	
	mech_heat_processed.emit(mech, initial_heat, current_heat, heat_removed)


func _check_shutdown(mech: Mech, initial_heat: int) -> void:
	"""Verifica si el mech debe hacer shutdown por calor"""
	if initial_heat >= 19:
		var shutdown_check = HeatSystem.check_shutdown(initial_heat)
		if shutdown_check["must_shutdown"]:
			mech.is_shutdown = true
			var automatic = shutdown_check.get("automatic", false)
			if automatic:
				combat_message.emit("  ☠ AUTOMATIC SHUTDOWN (Heat >= 30)!", Color.RED)
			else:
				combat_message.emit("  ☠ SHUTDOWN! (Rolled %d vs %d)" % [shutdown_check["roll"], shutdown_check["target"]], Color.RED)
			mech_shutdown.emit(mech, automatic)
		elif shutdown_check["target"] > 0:
			combat_message.emit("  ✓ Avoided shutdown (Rolled %d vs %d)" % [shutdown_check["roll"], shutdown_check["target"]], Color.GREEN)


func _check_ammo_explosion(mech: Mech, initial_heat: int) -> void:
	"""Verifica y procesa explosión de munición por calor"""
	if initial_heat >= 19:
		var ammo_check = HeatSystem.check_ammo_explosion(initial_heat)
		if ammo_check["explodes"]:
			combat_message.emit("  ☠☠☠ AMMO EXPLOSION! (Rolled %d vs %d)" % [ammo_check["roll"], ammo_check["target"]], Color.RED)
			
			# Determinar localización de la explosión
			var explosion_location = _find_ammo_explosion_location(mech)
			var has_case = ComponentDatabase.has_case_in_location(mech, explosion_location)
			
			ammo_explosion.emit(mech, explosion_location, has_case)
			
			if has_case:
				_process_case_explosion(mech, explosion_location)
			else:
				_process_catastrophic_explosion(mech)
				
		elif ammo_check["target"] > 0:
			combat_message.emit("  ✓ Avoided ammo explosion (Rolled %d vs %d)" % [ammo_check["roll"], ammo_check["target"]], Color.YELLOW)


func _process_case_explosion(mech: Mech, location: String) -> void:
	"""Procesa explosión contenida por CASE"""
	combat_message.emit("    ✓ CASE activated! Explosion vented safely.", Color.YELLOW)
	var _damage_result = mech.take_damage(location, 10)  # Daño reducido
	_destroy_ammo_in_location(mech, location)


func _process_catastrophic_explosion(mech: Mech) -> void:
	"""Procesa explosión catastrófica sin CASE"""
	combat_message.emit("    ⚠ NO CASE! Catastrophic explosion!", Color.ORANGE)
	var damage_result = mech.take_damage("center_torso", 20)  # Daño completo
	
	if damage_result.get("mech_destroyed", false):
		mech.death_reason = "Ammo explosion"
		combat_message.emit("    %s DESTROYED BY AMMO EXPLOSION!" % mech.mech_name.to_upper(), Color.DARK_RED)
		mech_destroyed_by_heat.emit(mech, "Ammo explosion")
		battle_end_check_requested.emit()


func _find_ammo_explosion_location(mech: Mech) -> String:
	"""Encuentra la localización donde hay munición para la explosión"""
	# Buscar en torsos primero (donde suele haber munición)
	var locations_to_check = ["left_torso", "right_torso", "center_torso"]
	
	for location in locations_to_check:
		if mech.has_ammo_in_location(location):
			return location
	
	# Si no hay munición en torsos, usar center_torso por defecto
	return "center_torso"


func _destroy_ammo_in_location(mech: Mech, location: String) -> void:
	"""Destruye la munición en una localización específica"""
	if mech.has_method("destroy_ammo_in_location"):
		mech.destroy_ammo_in_location(location)
	else:
		# Fallback: marcar munición como usada
		Log.warning("Heat", "Mech %s doesn't have destroy_ammo_in_location method" % mech.mech_name)


func get_heat_movement_penalty(mech: Mech) -> int:
	"""Calcula la penalización de movimiento por calor"""
	var effects = HeatSystem.get_heat_effects(mech.heat)
	return effects.get("movement_penalty", 0)


func get_heat_attack_penalty(mech: Mech) -> int:
	"""Calcula la penalización de ataque por calor"""
	var effects = HeatSystem.get_heat_effects(mech.heat)
	return effects.get("to_hit_penalty", 0)


func get_heat_status_description(mech: Mech) -> String:
	"""Obtiene descripción del estado de calor"""
	return HeatSystem.get_heat_description(mech.heat)


func get_heat_status_color(mech: Mech) -> Color:
	"""Obtiene color para mostrar el estado de calor"""
	return HeatSystem.get_heat_status_color(mech.heat, mech.heat_capacity)


func is_processing() -> bool:
	"""Retorna si está procesando la fase de calor"""
	return processing_heat
