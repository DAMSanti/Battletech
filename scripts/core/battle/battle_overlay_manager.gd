## BattleOverlayManager - Gestiona los overlays visuales del campo de batalla
## Responsabilidades:
## - Calcular y actualizar overlays de hexágonos
## - Manejar overlays de movimiento, ataque, despliegue
## - Coordinar con el surface renderer para dibujar overlays
## - Gestionar preview paths y highlighting
class_name BattleOverlayManager
extends RefCounted

# ==============================================================================
# SIGNALS
# ==============================================================================
signal overlays_updated

# ==============================================================================
# COLORS
# ==============================================================================
const COLOR_DEPLOYMENT_VALID := Color(0.2, 1.0, 0.2, 0.4)  # Green
const COLOR_DEPLOYMENT_OCCUPIED := Color(0.5, 0.5, 0.5, 0.3)  # Gray
const COLOR_MOVEMENT := Color(0.2, 0.5, 1.0, 0.4)  # Cyan
const COLOR_PREVIEW_PATH := Color(1.0, 0.8, 0.0, 0.4)  # Yellow/Orange
const COLOR_PREVIEW_DESTINATION := Color(1.0, 0.8, 0.0, 0.6)  # Brighter yellow
const COLOR_ATTACK_TARGET := Color(1.0, 0.2, 0.2, 0.4)  # Red
const COLOR_PHYSICAL_TARGET := Color(1.0, 0.0, 1.0, 0.4)  # Magenta
const COLOR_TUTORIAL_HIGHLIGHT := Color(0.0, 1.0, 1.0, 0.6)  # Cyan brillante para tutorial

# ==============================================================================
# STATE
# ==============================================================================
var hex_grid: HexGrid

# Overlay data
var deployment_hexes: Array = []
var reachable_hexes: Array = []
var preview_path: Array = []
var target_hexes: Array = []
var physical_target_hexes: Array = []
var los_overlay_hexes: Array = []
var tutorial_hexes: Array = []  # Hexes resaltados del tutorial

# Flags
var deployment_phase: bool = false
var los_overlay_visible: bool = false


func setup(p_hex_grid: HexGrid) -> void:
	"""Configura el manager con las referencias necesarias"""
	hex_grid = p_hex_grid
	Log.info("Combat", "BattleOverlayManager initialized")


# ==============================================================================
# OVERLAY STATE MANAGEMENT
# ==============================================================================

func set_deployment_phase(active: bool) -> void:
	"""Activa/desactiva la fase de despliegue"""
	deployment_phase = active
	if not active:
		deployment_hexes.clear()


func set_deployment_hexes(hexes: Array) -> void:
	"""Establece los hexágonos de despliegue válidos"""
	deployment_hexes = hexes.duplicate()


func set_reachable_hexes(hexes: Array) -> void:
	"""Establece los hexágonos alcanzables para movimiento"""
	reachable_hexes = hexes.duplicate()


func clear_reachable_hexes() -> void:
	"""Limpia los hexágonos alcanzables"""
	reachable_hexes.clear()


func set_preview_path(path: Array) -> void:
	"""Establece el camino de preview"""
	preview_path = path.duplicate()


func clear_preview_path() -> void:
	"""Limpia el preview path"""
	preview_path.clear()


func set_target_hexes(hexes: Array) -> void:
	"""Establece los hexágonos objetivo para ataque"""
	target_hexes = hexes.duplicate()


func clear_target_hexes() -> void:
	"""Limpia los hexágonos objetivo"""
	target_hexes.clear()


func set_physical_target_hexes(hexes: Array) -> void:
	"""Establece los hexágonos para ataques físicos"""
	physical_target_hexes = hexes.duplicate()


func clear_physical_target_hexes() -> void:
	"""Limpia los hexágonos de ataque físico"""
	physical_target_hexes.clear()


func set_los_overlay(hexes: Array, visible: bool) -> void:
	"""Establece el overlay de línea de visión"""
	los_overlay_hexes = hexes.duplicate()
	los_overlay_visible = visible


func clear_los_overlay() -> void:
	"""Limpia el overlay de LOS"""
	los_overlay_hexes.clear()
	los_overlay_visible = false


func set_tutorial_hexes(hexes: Array) -> void:
	"""Establece los hexágonos resaltados del tutorial"""
	tutorial_hexes = hexes.duplicate()
	overlays_updated.emit()


func clear_tutorial_hexes() -> void:
	"""Limpia los hexágonos del tutorial"""
	tutorial_hexes.clear()
	overlays_updated.emit()


func clear_all() -> void:
	"""Limpia todos los overlays"""
	reachable_hexes.clear()
	preview_path.clear()
	target_hexes.clear()
	physical_target_hexes.clear()
	tutorial_hexes.clear()
	# No limpiamos deployment_hexes ni los_overlay_hexes aquí


# ==============================================================================
# OVERLAY BUILDING
# ==============================================================================

func build_overlays() -> Array:
	"""
	Construye el array de overlays para renderizar
	Retorna un array de diccionarios con formato:
	{
		"hex": Vector2i,
		"color": Color,
		"elevation": float
	}
	"""
	var overlays: Array = []
	
	# 1. LOS overlay primero (se pinta debajo de todo)
	if los_overlay_visible and los_overlay_hexes.size() > 0:
		for los_entry in los_overlay_hexes:
			overlays.append(los_entry)
	
	# 2. Deployment phase overlays
	if deployment_phase and deployment_hexes.size() > 0:
		overlays.append_array(_build_deployment_overlays())
	else:
		# 3. Preview path overlays (highest priority - over movement)
		if preview_path.size() > 0:
			overlays.append_array(_build_preview_path_overlays())
		else:
			# 4. Movement overlays (solo si no hay preview)
			overlays.append_array(_build_movement_overlays())
		
		# 5. Attack target overlays
		overlays.append_array(_build_attack_overlays())
		
		# 6. Physical attack overlays
		overlays.append_array(_build_physical_overlays())
	
	# 7. Tutorial overlays (siempre encima de todo)
	if tutorial_hexes.size() > 0:
		overlays.append_array(_build_tutorial_overlays())
	
	return overlays


func _build_deployment_overlays() -> Array:
	"""Construye overlays para fase de despliegue"""
	var overlays: Array = []
	
	for hex in deployment_hexes:
		var color = COLOR_DEPLOYMENT_VALID
		if hex_grid.get_unit(hex):
			color = COLOR_DEPLOYMENT_OCCUPIED
		
		var terrain_elev = hex_grid.get_elevation(hex)
		var overlay_elev = terrain_elev + 0.5
		
		overlays.append({
			"hex": hex,
			"color": color,
			"elevation": overlay_elev
		})
	
	return overlays


func _build_preview_path_overlays() -> Array:
	"""Construye overlays para el preview path"""
	var overlays: Array = []
	
	for i in range(preview_path.size()):
		var hex = preview_path[i]
		var terrain_elev = hex_grid.get_elevation(hex)
		var is_destination = (i == preview_path.size() - 1)
		var color = COLOR_PREVIEW_DESTINATION if is_destination else COLOR_PREVIEW_PATH
		
		overlays.append({
			"hex": hex,
			"color": color,
			"elevation": terrain_elev + 0.5
		})
	
	return overlays


func _build_movement_overlays() -> Array:
	"""Construye overlays para hexágonos de movimiento"""
	var overlays: Array = []
	
	for hex in reachable_hexes:
		var terrain_elev = hex_grid.get_elevation(hex)
		overlays.append({
			"hex": hex,
			"color": COLOR_MOVEMENT,
			"elevation": terrain_elev + 0.5
		})
	
	return overlays


func _build_attack_overlays() -> Array:
	"""Construye overlays para objetivos de ataque"""
	var overlays: Array = []
	
	for hex in target_hexes:
		var terrain_elev = hex_grid.get_elevation(hex)
		overlays.append({
			"hex": hex,
			"color": COLOR_ATTACK_TARGET,
			"elevation": terrain_elev + 0.5
		})
	
	return overlays


func _build_physical_overlays() -> Array:
	"""Construye overlays para ataques físicos"""
	var overlays: Array = []
	
	for hex in physical_target_hexes:
		var terrain_elev = hex_grid.get_elevation(hex)
		overlays.append({
			"hex": hex,
			"color": COLOR_PHYSICAL_TARGET,
			"elevation": terrain_elev + 0.5
		})
	
	return overlays


func _build_tutorial_overlays() -> Array:
	"""Construye overlays para el tutorial (hexes resaltados)"""
	var overlays: Array = []
	
	# Color pulsante para el tutorial (efecto de respiración)
	var time_ms = Time.get_ticks_msec()
	var pulse = (sin(time_ms * 0.004) + 1.0) * 0.5  # Pulso suave
	
	# Color base cyan brillante con pulso
	var color = Color(0.0, 0.9, 1.0, 0.3 + pulse * 0.5)  # Alpha pulsa entre 0.3 y 0.8
	
	for hex in tutorial_hexes:
		var terrain_elev = hex_grid.get_elevation(hex)
		overlays.append({
			"hex": hex,
			"color": color,
			"elevation": terrain_elev + 0.6  # Un poco más alto que otros overlays
		})
	
	return overlays


# ==============================================================================
# RENDERING
# ==============================================================================

func update_and_render() -> void:
	"""Actualiza y renderiza los overlays"""
	if not hex_grid or not hex_grid._surface_renderer:
		return
	
	var overlays = build_overlays()
	hex_grid._surface_renderer.render_overlays(overlays, hex_grid)
	overlays_updated.emit()


func needs_continuous_update() -> bool:
	"""Retorna true si hay overlays que necesitan actualización continua (pulsantes)"""
	return tutorial_hexes.size() > 0


# ==============================================================================
# HELPER QUERIES
# ==============================================================================

func is_hex_in_movement_range(hex: Vector2i) -> bool:
	"""Verifica si un hex está en rango de movimiento"""
	return hex in reachable_hexes


func is_hex_in_attack_range(hex: Vector2i) -> bool:
	"""Verifica si un hex está en rango de ataque"""
	return hex in target_hexes


func is_hex_in_physical_range(hex: Vector2i) -> bool:
	"""Verifica si un hex está en rango de ataque físico"""
	return hex in physical_target_hexes


func is_valid_deployment_hex(hex: Vector2i) -> bool:
	"""Verifica si un hex es válido para despliegue"""
	return hex in deployment_hexes and not hex_grid.get_unit(hex)


func get_preview_destination() -> Vector2i:
	"""Retorna el destino del preview path, o (-1,-1) si no hay preview"""
	if preview_path.size() > 0:
		return preview_path[-1]
	return Vector2i(-1, -1)


# ==============================================================================
# UI DATA SYNC (for UI that needs overlay info)
# ==============================================================================

func sync_from_ui(ui_node: Node) -> void:
	"""Sincroniza datos de overlay desde la UI (para LOS overlay)"""
	if ui_node and "los_overlay_visible" in ui_node and "los_overlay_hexes" in ui_node:
		los_overlay_visible = ui_node.los_overlay_visible
		los_overlay_hexes = ui_node.los_overlay_hexes
