extends Panel
class_name BattleOverlayMenu
## Menú de opciones de overlays del mapa (Elevation, Coords, Terrain, Movement, LOS)

signal overlay_changed(overlay_key: String, is_active: bool)
signal los_overlay_requested(visible_hexes: Array)
signal los_overlay_cleared()

var scale_factor: float = 1.0
var battle_scene: Node = null

# Botones de toggle
var elevation_toggle: Button
var coords_toggle: Button
var terrain_toggle: Button
var movement_toggle: Button
var los_toggle: Button

# Estado de overlays
var overlay_settings: Dictionary = {
	"elevation": false,
	"coords": false,
	"terrain": false,
	"movement": false,
	"los": false
}

# Cache para overlay de LOS
var los_overlay_visible: bool = false
var los_overlay_hexes: Array = []

var _styles: SteelTitansStyles

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func setup(p_scale_factor: float, p_battle_scene: Node) -> void:
	scale_factor = p_scale_factor
	battle_scene = p_battle_scene
	_styles = SteelTitansStyles.new(scale_factor)
	_setup_panel()

func _setup_panel() -> void:
	var menu_width = 180 * scale_factor
	var toggle_start_y = 35 * scale_factor
	var toggle_height = 38 * scale_factor
	var toggle_width = menu_width - 20 * scale_factor
	
	# Estilo del menú
	var menu_style = StyleBoxFlat.new()
	menu_style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	menu_style.border_color = Color(0.3, 0.6, 0.9, 0.9)
	menu_style.border_width_left = 2
	menu_style.border_width_top = 2
	menu_style.border_width_right = 2
	menu_style.border_width_bottom = 2
	menu_style.corner_radius_top_left = 8
	menu_style.corner_radius_top_right = 8
	menu_style.corner_radius_bottom_right = 8
	menu_style.corner_radius_bottom_left = 8
	add_theme_stylebox_override("panel", menu_style)
	
	# Título
	var title = Label.new()
	title.text = "MAP OVERLAYS"
	title.position = Vector2(10 * scale_factor, 8 * scale_factor)
	title.add_theme_font_size_override("font_size", int(14 * scale_factor))
	title.add_theme_color_override("font_color", SteelTitansStyles.get_cyan_text_color())
	add_child(title)
	
	# Toggles
	elevation_toggle = _create_toggle("📊 Elevation", Vector2(10 * scale_factor, toggle_start_y), Vector2(toggle_width, toggle_height), "elevation")
	add_child(elevation_toggle)
	
	coords_toggle = _create_toggle("📍 Coordinates", Vector2(10 * scale_factor, toggle_start_y + toggle_height), Vector2(toggle_width, toggle_height), "coords")
	add_child(coords_toggle)
	
	terrain_toggle = _create_toggle("🌲 Terrain Type", Vector2(10 * scale_factor, toggle_start_y + toggle_height * 2), Vector2(toggle_width, toggle_height), "terrain")
	add_child(terrain_toggle)
	
	movement_toggle = _create_toggle("🚶 Move Cost", Vector2(10 * scale_factor, toggle_start_y + toggle_height * 3), Vector2(toggle_width, toggle_height), "movement")
	add_child(movement_toggle)
	
	los_toggle = _create_toggle("👁 Line of Sight", Vector2(10 * scale_factor, toggle_start_y + toggle_height * 4), Vector2(toggle_width, toggle_height), "los")
	add_child(los_toggle)
	
	# Ajustar tamaño del panel
	size = Vector2(menu_width, toggle_start_y + toggle_height * 5 + 10 * scale_factor)

func _create_toggle(text: String, pos: Vector2, btn_size: Vector2, overlay_key: String) -> Button:
	var initial_state = overlay_settings.get(overlay_key, false)
	
	var btn = Button.new()
	btn.text = ("✓ " if initial_state else "○ ") + text
	btn.position = pos
	btn.size = btn_size
	btn.add_theme_font_size_override("font_size", int(13 * scale_factor))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.set_meta("base_text", text)
	btn.set_meta("overlay_key", overlay_key)
	
	_apply_toggle_style(btn, initial_state)
	btn.pressed.connect(_on_toggle_pressed.bind(overlay_key, btn))
	
	return btn

func _apply_toggle_style(btn: Button, is_active: bool) -> void:
	var toggle_style = StyleBoxFlat.new()
	toggle_style.bg_color = Color(0.12, 0.18, 0.25, 0.8) if is_active else Color(0.08, 0.1, 0.14, 0.6)
	toggle_style.border_color = Color(0.3, 0.7, 0.5, 0.8) if is_active else Color(0.2, 0.3, 0.4, 0.5)
	toggle_style.border_width_left = 2
	toggle_style.border_width_top = 1
	toggle_style.border_width_right = 2
	toggle_style.border_width_bottom = 1
	toggle_style.corner_radius_top_left = 4
	toggle_style.corner_radius_top_right = 4
	toggle_style.corner_radius_bottom_right = 4
	toggle_style.corner_radius_bottom_left = 4
	btn.add_theme_stylebox_override("normal", toggle_style)
	btn.add_theme_stylebox_override("hover", toggle_style)
	btn.add_theme_stylebox_override("pressed", toggle_style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1, 1))

func _on_toggle_pressed(overlay_key: String, btn: Button) -> void:
	overlay_settings[overlay_key] = not overlay_settings[overlay_key]
	var is_active = overlay_settings[overlay_key]
	
	# Actualizar UI
	var base_text = btn.get_meta("base_text", "")
	btn.text = ("✓ " if is_active else "○ ") + base_text
	_apply_toggle_style(btn, is_active)
	
	# Aplicar cambio al mapa
	_apply_overlay_setting(overlay_key, is_active)
	
	# Emitir señal
	overlay_changed.emit(overlay_key, is_active)

func _apply_overlay_setting(overlay_key: String, is_active: bool) -> void:
	if not battle_scene:
		return
	
	var hex_grid = battle_scene.get_node_or_null("HexGrid")
	if not hex_grid:
		return
	
	var surface_renderer = hex_grid.get_node_or_null("__hex_surface_renderer")
	if not surface_renderer and "_surface_renderer" in hex_grid:
		surface_renderer = hex_grid._surface_renderer
	
	if not surface_renderer:
		Log.warning("UI", "surface_renderer not found")
		return
	
	match overlay_key:
		"elevation":
			surface_renderer.show_elevation_labels = is_active
		"coords":
			surface_renderer.show_coordinates = is_active
		"terrain":
			surface_renderer.show_terrain_type = is_active
		"movement":
			surface_renderer.show_movement_cost = is_active
		"los":
			_toggle_los_overlay(is_active, hex_grid)
	
	Log.debug("UI", "Overlay set", {"overlay": overlay_key, "active": is_active})

# ============================================
# LINE OF SIGHT OVERLAY
# ============================================

func _toggle_los_overlay(is_active: bool, hex_grid) -> void:
	los_overlay_visible = is_active
	
	if not is_active:
		_clear_los_overlay()
		return
	
	_update_los_overlay(hex_grid)

func _update_los_overlay(hex_grid) -> void:
	if not los_overlay_visible or not hex_grid or not battle_scene:
		return
	
	# Obtener los mechs del jugador
	var player_units: Array = []
	
	if battle_scene.is_multiplayer_mode:
		var all_mechs = battle_scene.player_mechs + battle_scene.enemy_mechs
		for mech in all_mechs:
			if mech.is_player_controlled:
				player_units.append(mech)
	else:
		player_units = battle_scene.player_mechs
	
	if player_units.size() == 0:
		Log.debug("UI", "No player units found for LOS overlay")
		return
	
	# Recolectar hexes visibles
	var visible_hexes: Dictionary = {}
	
	for q in range(hex_grid.grid_width):
		for r in range(hex_grid.grid_height):
			var target_hex = Vector2i(q, r)
			
			for unit in player_units:
				if unit.is_destroyed:
					continue
				
				if unit.hex_position == target_hex:
					var hex_key = "%d,%d" % [q, r]
					visible_hexes[hex_key] = target_hex
					break
				
				var los_data = LineOfSight.calculate_los(hex_grid, unit.hex_position, target_hex)
				
				if los_data.result != LineOfSight.Result.BLOCKED:
					var hex_key = "%d,%d" % [q, r]
					visible_hexes[hex_key] = target_hex
					break
	
	# Antes esto marcaba las casillas VISIBLES con un tinte verde encima. El
	# pedido original era el contrario: las casillas FUERA de LoS deben
	# quedar visualmente apagadas/desaturadas para que sea obvio a simple
	# vista qué zonas no son visibles, no resaltar las que sí lo son.
	var overlays: Array = []
	var out_of_los_color = Color(0.05, 0.05, 0.08, 0.55)  # Oscurece/desatura en vez de resaltar

	for q in range(hex_grid.grid_width):
		for r in range(hex_grid.grid_height):
			var hex_key = "%d,%d" % [q, r]
			if visible_hexes.has(hex_key):
				continue
			var hex = Vector2i(q, r)
			var elevation = hex_grid.get_elevation(hex)
			overlays.append({
				"hex": hex,
				"color": out_of_los_color,
				"elevation": elevation
			})

	los_overlay_hexes = overlays
	los_overlay_requested.emit(overlays)

	Log.debug("UI", "LOS overlay showing out-of-LoS hexes", {"count": overlays.size()})

func _clear_los_overlay() -> void:
	los_overlay_hexes.clear()
	los_overlay_cleared.emit()

func refresh_los_overlay() -> void:
	"""Refresca el overlay de LOS (llamar cuando los mechs se muevan)"""
	if not los_overlay_visible:
		return
	
	var hex_grid = null
	if battle_scene:
		hex_grid = battle_scene.get_node_or_null("HexGrid")
	
	if hex_grid:
		_update_los_overlay(hex_grid)

# ============================================
# API PÚBLICA
# ============================================

func toggle_visibility() -> void:
	visible = not visible

func is_overlay_active(key: String) -> bool:
	return overlay_settings.get(key, false)

func get_los_overlay_hexes() -> Array:
	return los_overlay_hexes

func is_los_overlay_visible() -> bool:
	return los_overlay_visible

func is_mouse_over() -> bool:
	if not visible:
		return false
	var mouse_pos = get_viewport().get_mouse_position()
	var panel_rect = Rect2(global_position, size)
	return panel_rect.has_point(mouse_pos)
