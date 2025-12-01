## BattleMovementHandler - Gestiona la lógica de movimiento de mechs
## Responsabilidad única: Cálculo de paths, costos y ejecución de movimiento
## Extraído de battle_scene.gd como parte del refactoring SOLID
class_name BattleMovementHandler
extends RefCounted

# ==============================================================================
# SIGNALS
# ==============================================================================
signal movement_type_selected(mech: Mech, movement_type: int)
signal movement_preview_shown(path: Array, destination: Vector2i, cost: int)
signal movement_confirmed(mech: Mech, destination: Vector2i, path: Array)
signal movement_cancelled()
signal movement_executed(mech: Mech, from: Vector2i, to: Vector2i, cost: int)
signal movement_blocked(mech: Mech, reason: String)
signal turn_only_selected(mech: Mech)
signal facing_adjustment_requested(mech: Mech, screen_pos: Vector2, current_facing: int, available_mp: int)
signal combat_message(text: String, color: Color)
signal overlays_update_requested()

# ==============================================================================
# STATE
# ==============================================================================
var reachable_hexes: Array = []
var reachable_hexes_details: Dictionary = {}  # hex -> {path, cost, rotation}
var preview_path: Array = []
var preview_destination: Vector2i = Vector2i(-1, -1)
var pending_move_confirmation: bool = false
var pending_movement_selection: bool = false
var pending_turn_only: bool = false

# ==============================================================================
# REFERENCES
# ==============================================================================
var hex_grid: HexGrid = null
var selected_unit: Mech = null
var is_multiplayer_mode: bool = false
var player_mechs: Array = []  # Referencia a mechs del jugador


func setup(p_hex_grid: HexGrid, p_is_multiplayer: bool = false) -> void:
	"""Configura el movement handler"""
	hex_grid = p_hex_grid
	is_multiplayer_mode = p_is_multiplayer


func set_player_mechs(mechs: Array) -> void:
	"""Actualiza la lista de mechs del jugador"""
	player_mechs = mechs


func set_selected_unit(unit: Mech) -> void:
	"""Establece la unidad seleccionada para movimiento"""
	selected_unit = unit
	# Limpiar estado previo
	clear_movement_state()


func select_movement_type(movement_type: int) -> void:
	"""Llamado cuando el jugador selecciona Walk/Run/Jump"""
	if not selected_unit or not _can_control_unit(selected_unit):
		return
	
	pending_movement_selection = false
	
	selected_unit.start_movement(movement_type)
	
	var movement_names = ["None", "Walk", "Run", "Jump"]
	
	# Verificar si hay MPs disponibles
	if selected_unit.current_movement <= 0:
		combat_message.emit("%s: Cannot move (%s) - 0 MP available" % [selected_unit.mech_name, movement_names[movement_type]], Color.RED)
		_emit_movement_penalties()
		combat_message.emit("  Skipping movement phase...", Color.GRAY)
		movement_blocked.emit(selected_unit, "No MP available")
		return
	
	# Actualizar hexagonos alcanzables
	_calculate_reachable_hexes(movement_type)
	
	# Verificar si se encontraron hexágonos alcanzables
	if reachable_hexes.size() == 0 and selected_unit.current_movement > 0:
		combat_message.emit("%s: No reachable hexes (%s, %d MP)" % [selected_unit.mech_name, movement_names[movement_type], selected_unit.current_movement], Color.ORANGE)
		combat_message.emit("  Surrounded or blocked. Skipping movement...", Color.GRAY)
		movement_blocked.emit(selected_unit, "Surrounded or blocked")
		return
	
	combat_message.emit("%s selected: %s (%d MP, %d hexes)" % [selected_unit.mech_name, movement_names[movement_type], selected_unit.current_movement, reachable_hexes.size()], Color.CYAN)
	
	movement_type_selected.emit(selected_unit, movement_type)
	overlays_update_requested.emit()


func _calculate_reachable_hexes(movement_type: int) -> void:
	"""Calcula los hexes alcanzables según el tipo de movimiento"""
	if movement_type == GameEnums.MovementType.JUMP:
		reachable_hexes = MovementSystem.get_jump_hexes(selected_unit.hex_position, selected_unit.current_movement, hex_grid, selected_unit)
		reachable_hexes_details = {}
	else:
		reachable_hexes_details = MovementSystem.get_reachable_hexes_with_details(selected_unit.hex_position, selected_unit.current_movement, movement_type, hex_grid, selected_unit)
		reachable_hexes = reachable_hexes_details.keys()


func _emit_movement_penalties() -> void:
	"""Emite mensajes sobre penalizaciones de movimiento"""
	if not selected_unit:
		return
	
	var penalties = []
	if selected_unit.heat > 0:
		var heat_penalty = selected_unit.get_heat_movement_penalty()
		if heat_penalty > 0:
			penalties.append("Heat: -%d MP" % heat_penalty)
	if selected_unit.armor["left_leg"]["current"] <= 0 or selected_unit.armor["right_leg"]["current"] <= 0:
		penalties.append("Leg damage")
	if penalties.size() > 0:
		combat_message.emit("  Penalties: %s" % ", ".join(penalties), Color.YELLOW)


func select_turn_only() -> void:
	"""Llamado cuando el jugador selecciona solo girar sin moverse"""
	if not selected_unit or not _can_control_unit(selected_unit):
		return
	
	pending_movement_selection = false
	pending_turn_only = true
	
	combat_message.emit("%s: Select new facing (Turn only - %d MP available)" % [selected_unit.mech_name, selected_unit.current_movement], Color.CYAN)
	
	turn_only_selected.emit(selected_unit)


func cancel_movement_selection() -> void:
	"""Cancela la selección de movimiento actual"""
	Log.debug("Movement", "Cancelling movement selection")
	
	clear_movement_state()
	
	combat_message.emit("Movement cancelled - select new movement type", Color.GRAY)
	movement_cancelled.emit()


func clear_movement_state() -> void:
	"""Limpia todo el estado de movimiento"""
	reachable_hexes = []
	reachable_hexes_details = {}
	preview_path = []
	preview_destination = Vector2i(-1, -1)
	pending_move_confirmation = false
	pending_turn_only = false
	overlays_update_requested.emit()


func handle_movement_click(hex: Vector2i) -> bool:
	"""Maneja click en hex durante movimiento. Retorna true si fue procesado."""
	Log.debug("Movement", "hex=%s, selected_unit=%s" % [hex, selected_unit.mech_name if selected_unit else "null"])
	Log.debug("Movement", "pending_move_confirmation=%s, preview_destination=%s" % [pending_move_confirmation, preview_destination])
	
	if selected_unit == null:
		Log.debug("Movement", "No unit selected - abort")
		return false
	
	# Si estamos esperando selección de tipo de movimiento, ignorar clics
	if pending_movement_selection:
		Log.debug("Movement", "Waiting for movement type selection - abort")
		return false
	
	# Solo permitir movimiento si es controlable
	if not _can_control_unit(selected_unit):
		Log.debug("Movement", "Not my mech - abort")
		return false
	
	# Si ya hay un movimiento pendiente de confirmar
	if pending_move_confirmation and preview_destination != Vector2i(-1, -1):
		Log.debug("Movement", "Have pending confirmation - checking if same hex")
		if hex == preview_destination:
			Log.debug("Movement", "SAME HEX - ignoring (use confirmation menu)")
			return true
		else:
			Log.debug("Movement", "Different hex - cancelling preview")
			_cancel_preview()
	
	# Verificar que el hexágono sea alcanzable
	if hex in reachable_hexes:
		Log.debug("Movement", "Hex is reachable - showing preview")
		preview_movement_path(hex)
		return true
	else:
		Log.debug("Movement", "Hex NOT reachable (reachable_hexes.size=%d)" % reachable_hexes.size())
		return false


func preview_movement_path(hex: Vector2i) -> void:
	"""Muestra el camino de movimiento y pide confirmación"""
	if not selected_unit:
		return
	
	Log.debug("Movement", "Starting preview to hex=%s for unit=%s" % [hex, selected_unit.mech_name])
	
	var is_jumping = selected_unit.movement_type_used == GameEnums.MovementType.JUMP
	
	# Obtener o calcular path
	var path: Array = _get_path_to_hex(hex, is_jumping)
	
	if path.size() == 0:
		Log.debug("Movement", "No path found - abort")
		return
	
	# Guardar información del movimiento pendiente
	preview_path = path
	preview_destination = hex
	pending_move_confirmation = true
	
	# Calcular costos
	var costs = _calculate_movement_costs(path, is_jumping)
	
	Log.debug("Movement", "Set pending_move_confirmation=true, preview_destination=%s" % preview_destination)
	
	# Emitir evento con datos del preview
	movement_preview_shown.emit(path, hex, costs.total)
	overlays_update_requested.emit()


func _get_path_to_hex(hex: Vector2i, is_jumping: bool) -> Array:
	"""Obtiene el path hacia un hex"""
	var path: Array = []
	
	if is_jumping:
		path = [selected_unit.hex_position, hex]
		Log.debug("Movement", "Using direct jump path (no terrain pathfinding)")
	elif reachable_hexes_details.has(hex):
		path = reachable_hexes_details[hex]["path"]
		Log.debug("Movement", "Using pre-calculated path from reachable_hexes_details")
	else:
		path = hex_grid.find_path(selected_unit.hex_position, hex, selected_unit.current_movement)
		Log.debug("Movement", "Using hex_grid.find_path (fallback)")
	
	return path


func _calculate_movement_costs(path: Array, is_jumping: bool) -> Dictionary:
	"""Calcula costos de movimiento y rotación"""
	var movement_cost = 0
	var rotation_cost = 0
	var current_facing = selected_unit.facing
	
	if is_jumping:
		movement_cost = hex_grid.hex_distance(selected_unit.hex_position, path[path.size() - 1])
		rotation_cost = 0
	else:
		for i in range(1, path.size()):
			var from_hex = path[i - 1]
			var to_hex = path[i]
			
			var step_facing = FacingSystem.get_facing_to_hex(from_hex, to_hex)
			var step_rotation = MovementSystem.get_rotation_cost(current_facing, step_facing)
			rotation_cost += step_rotation
			
			var step_cost = MovementSystem.calculate_movement_cost(from_hex, to_hex, selected_unit.movement_type_used, hex_grid)
			movement_cost += step_cost
			
			current_facing = step_facing
	
	return {
		"movement": movement_cost,
		"rotation": rotation_cost,
		"total": movement_cost + rotation_cost,
		"final_facing": current_facing
	}


func confirm_movement() -> void:
	"""Ejecutar el movimiento confirmado"""
	Log.info("Movement", "Movement confirmed - pending: %s, dest: %s" % [pending_move_confirmation, preview_destination])
	
	if not pending_move_confirmation or preview_destination == Vector2i(-1, -1):
		Log.warning("Movement", "Movement confirmation failed - invalid state")
		return
	
	if not selected_unit:
		Log.warning("Movement", "Movement confirmation failed - no unit selected")
		return
	
	pending_move_confirmation = false
	
	# Emitir señal para que battle_scene maneje la ejecución
	movement_confirmed.emit(selected_unit, preview_destination, preview_path.duplicate())


func cancel_movement() -> void:
	"""Cancelar el movimiento pendiente"""
	_cancel_preview()
	combat_message.emit("Movement cancelled", Color.GRAY)
	movement_cancelled.emit()


func _cancel_preview() -> void:
	"""Cancela solo el preview sin limpiar todo el estado"""
	pending_move_confirmation = false
	preview_path = []
	preview_destination = Vector2i(-1, -1)
	overlays_update_requested.emit()


func execute_movement(unit: Mech, hex: Vector2i, path: Array) -> void:
	"""Ejecuta el movimiento del mech localmente"""
	var is_jumping = unit.movement_type_used == GameEnums.MovementType.JUMP
	
	# Calcular camino si no se proporciona
	if path.size() == 0:
		path = _get_path_to_hex(hex, is_jumping)
	
	if path.size() == 0:
		return
	
	# Calcular costos
	var costs = _calculate_movement_costs(path, is_jumping)
	var old_pos = unit.hex_position
	
	# Actualizar posición en el grid
	hex_grid.set_unit(unit.hex_position, null)
	unit.move_to_hex(hex, costs.total)
	hex_grid.set_unit(hex, unit)
	
	# Actualizar facing al final del movimiento
	unit.facing = costs.final_facing
	Log.debug("Movement", "_execute_movement: Updated facing to %d for %s" % [costs.final_facing, unit.mech_name])
	
	# Actualizar visual
	unit.update_visual_position(hex_grid)
	unit._update_sprite()
	
	# Emitir mensajes de UI
	_emit_movement_log(unit, old_pos, hex, path, costs, is_jumping)
	
	# Limpiar estado
	preview_path = []
	preview_destination = Vector2i(-1, -1)
	reachable_hexes = []
	reachable_hexes_details = {}
	
	Log.info("Movement", "Movement execution completed")
	
	# Emitir señal
	movement_executed.emit(unit, old_pos, hex, costs.total)
	
	# Solicitar ajuste de facing post-movimiento si es controlable
	if _can_control_unit(unit):
		var mech_screen_pos = hex_grid.hex_to_pixel(unit.hex_position, true) + hex_grid.global_position
		facing_adjustment_requested.emit(unit, mech_screen_pos, unit.facing, unit.current_movement)


func _emit_movement_log(unit: Mech, old_pos: Vector2i, new_pos: Vector2i, path: Array, costs: Dictionary, is_jumping: bool) -> void:
	"""Emite mensajes de log del movimiento"""
	var movement_names = {
		GameEnums.MovementType.WALK: "Walking",
		GameEnums.MovementType.RUN: "Running",
		GameEnums.MovementType.JUMP: "Jumping"
	}
	var move_type_str = movement_names.get(unit.movement_type_used, "Moving")
	var hex_distance = path.size() - 1
	
	# Cambio de elevación
	var old_elevation = hex_grid.get_elevation(old_pos)
	var new_elevation = hex_grid.get_elevation(new_pos)
	var elevation_change = new_elevation - old_elevation
	
	# Mensaje principal
	combat_message.emit("%s %s from [%d,%d] to [%d,%d]" % [
		unit.mech_name, move_type_str, old_pos.x, old_pos.y, new_pos.x, new_pos.y
	], Color.WHITE)
	
	# Detalles
	var details = "  → Moved %d hex%s, Cost: %d MP" % [
		hex_distance, 
		"es" if hex_distance != 1 else "",
		costs.total
	]
	
	if costs.rotation > 0:
		details += " (Terrain: %d MP, Rotation: %d MP)" % [costs.movement, costs.rotation]
	
	if elevation_change != 0:
		var elev_str = "+%d" % elevation_change if elevation_change > 0 else str(elevation_change)
		details += ", Elevation: %s" % elev_str
	
	combat_message.emit(details, Color.CYAN)


func _can_control_unit(unit: Mech) -> bool:
	"""Verifica si el jugador puede controlar esta unidad"""
	if is_multiplayer_mode:
		return unit.is_player_controlled
	else:
		return unit in player_mechs


func get_reachable_hexes() -> Array:
	"""Retorna los hexes alcanzables actualmente"""
	return reachable_hexes


func get_preview_path() -> Array:
	"""Retorna el path de preview actual"""
	return preview_path


func get_preview_destination() -> Vector2i:
	"""Retorna el destino de preview actual"""
	return preview_destination


func is_pending_confirmation() -> bool:
	"""Retorna si hay un movimiento pendiente de confirmar"""
	return pending_move_confirmation


func is_pending_selection() -> bool:
	"""Retorna si estamos esperando selección de tipo"""
	return pending_movement_selection


func set_pending_selection(value: bool) -> void:
	"""Establece si estamos esperando selección de tipo"""
	pending_movement_selection = value


func is_turn_only_pending() -> bool:
	"""Retorna si estamos en modo turn only"""
	return pending_turn_only


func clear_turn_only() -> void:
	"""Limpia el estado de turn only"""
	pending_turn_only = false
