extends RefCounted
class_name BattleMechInspector
## Componente para mostrar paneles de inspección de mechs

var scale_factor: float = 1.0
var margin: float = 10.0
var _parent: CanvasLayer
var _theme: Theme
var _styles: SteelTitansStyles

# Paneles activos
var _inspector_panel: Panel = null
var _inspector_armor: Control = null
var _inspector_visible: bool = false
var _paper_doll_overlay: ColorRect = null

func _init(parent: CanvasLayer, theme: Theme, p_scale_factor: float, p_margin: float) -> void:
	_parent = parent
	_theme = theme
	scale_factor = p_scale_factor
	margin = p_margin
	_styles = SteelTitansStyles.new(scale_factor)

# ============================================
# MECH INSPECTOR (Panel pequeño)
# ============================================

func show_inspector(mech) -> void:
	if _inspector_visible:
		hide_inspector()
		return
	
	_inspector_visible = true
	
	var viewport_size = _parent.get_viewport().get_visible_rect().size
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y
	
	# Panel (50% ancho, 35% altura, centrado)
	var panel_width = screen_width * 0.5
	var panel_height = screen_height * 0.35
	
	_inspector_panel = Panel.new()
	_inspector_panel.position = Vector2((screen_width - panel_width) / 2, (screen_height - panel_height) / 2)
	_inspector_panel.size = Vector2(panel_width, panel_height)
	
	# Estilo
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color.CYAN
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	_inspector_panel.add_theme_stylebox_override("panel", style)
	_parent.add_child(_inspector_panel)
	
	# Layout vertical
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(margin, margin)
	vbox.size = Vector2(panel_width - margin * 2, panel_height - margin * 2)
	vbox.add_theme_constant_override("separation", int(5 * scale_factor))
	_inspector_panel.add_child(vbox)
	
	# Título
	var title = Label.new()
	title.text = mech.mech_name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(20 * scale_factor))
	title.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(title)
	
	# Info básica
	var info_label = Label.new()
	var status = "DESTROYED" if mech.is_destroyed else "OPERATIONAL"
	var status_color = Color.RED if mech.is_destroyed else Color.GREEN
	info_label.text = "%s | %d tons | Heat: %d/%d | Pilot: %d" % [status, mech.tonnage, mech.heat, mech.heat_capacity, mech.pilot_skill]
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", int(14 * scale_factor))
	info_label.add_theme_color_override("font_color", status_color)
	vbox.add_child(info_label)
	
	# Espaciador
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, panel_height * 0.2)
	vbox.add_child(spacer)
	
	# Panel de armadura gráfico
	var CustomArmorPanel = load("res://scripts/ui/custom_armor_panel.gd")
	_inspector_armor = CustomArmorPanel.new()
	_inspector_armor.custom_minimum_size = Vector2(panel_width * 0.5, panel_height * 0.5)
	_inspector_armor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_armor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Preparar datos de armadura
	var armor_data = {}
	for location in mech.armor.keys():
		armor_data[location] = mech.armor[location].duplicate()
		if mech.structure.has(location):
			armor_data[location + "_structure"] = mech.structure[location]["current"]
			armor_data[location + "_structure_max"] = mech.structure[location]["max"]
		else:
			armor_data[location + "_structure"] = 0
			armor_data[location + "_structure_max"] = 1
	
	_inspector_armor.set_armor(armor_data)
	vbox.add_child(_inspector_armor)
	
	# Botón cerrar
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_container)
	
	var close_button = Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(panel_width * 0.3, 40 * scale_factor)
	close_button.add_theme_font_size_override("font_size", int(16 * scale_factor))
	close_button.pressed.connect(hide_inspector)
	button_container.add_child(close_button)

func hide_inspector() -> void:
	if _inspector_panel:
		_inspector_panel.queue_free()
		_inspector_panel = null
	_inspector_armor = null
	_inspector_visible = false

func is_inspector_visible() -> bool:
	return _inspector_visible

# ============================================
# PAPER DOLL DIALOG (Modal completo)
# ============================================

func show_paper_doll_dialog(mech) -> void:
	Log.debug("UI", "show_paper_doll_dialog called", {"mech": str(mech)})
	if not mech:
		Log.warning("UI", "show_paper_doll_dialog called with null mech")
		return
	
	if not ResourceLoader.exists("res://scenes/mech_paper_doll.tscn"):
		Log.error("UI", "Paper doll scene not found")
		return
	
	var paper_scene = load("res://scenes/mech_paper_doll.tscn")
	if not paper_scene:
		Log.error("UI", "Failed to load mech_paper_doll.tscn")
		return
	
	# Overlay
	_paper_doll_overlay = ColorRect.new()
	_paper_doll_overlay.color = Color(0, 0, 0, 0.6)
	_paper_doll_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_paper_doll_overlay.anchor_left = 0
	_paper_doll_overlay.anchor_top = 0
	_paper_doll_overlay.anchor_right = 1
	_paper_doll_overlay.anchor_bottom = 1
	
	var panel = Panel.new()
	panel.name = "PaperDollModal"
	panel.add_theme_font_size_override("font_size", 16)
	
	# CenterContainer para centrar
	var center = CenterContainer.new()
	center.anchor_left = 0
	center.anchor_top = 0
	center.anchor_right = 1
	center.anchor_bottom = 1
	
	var viewport_size = _parent.get_viewport().get_visible_rect().size
	
	# Instanciar paper doll
	var paper = paper_scene.instantiate()
	var paper_min_size = Vector2(120, 170)
	if paper and paper.has_method("get_minimum_size"):
		if paper.custom_minimum_size and paper.custom_minimum_size != Vector2.ZERO:
			paper_min_size = paper.custom_minimum_size
		else:
			paper_min_size = paper.get_minimum_size()
	
	var target_width = paper_min_size.x + 48
	var target_height = paper_min_size.y + 72
	
	var panel_width = clamp(target_width, 220, min(viewport_size.x - 40, 600))
	var panel_height = clamp(target_height, 180, min(viewport_size.y - 40, 420))
	var panel_size = Vector2(panel_width, panel_height)
	panel.custom_minimum_size = panel_size
	
	# Header
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(panel_size.x, 30)
	
	var title = Label.new()
	title.text = mech.mech_name if "mech_name" in mech else "Mech"
	title.add_theme_font_size_override("font_size", int(14 * scale_factor))
	title.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.18, 1))
	title.add_theme_constant_override("outline_size", 2)
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.add_theme_font_size_override("font_size", int(14 * scale_factor))
	close_btn.theme = _theme
	close_btn.pressed.connect(_close_paper_doll_dialog)
	header.add_child(close_btn)
	
	panel.add_child(header)
	
	# Posicionar paper
	var inner_size = Vector2(max(panel_size.x - 16, paper_min_size.x), max(panel_size.y - header.custom_minimum_size.y - 12, paper_min_size.y))
	var inner_pos_x = max(8, (panel_size.x - inner_size.x) / 2)
	var inner_pos = Vector2(inner_pos_x, header.custom_minimum_size.y + 6)
	paper.position = inner_pos
	paper.size = inner_size
	panel.add_child(paper)
	
	# Estilo Steel Titans
	var paper_style = _create_paper_doll_style()
	paper.add_theme_stylebox_override("panel", paper_style)
	panel.add_theme_stylebox_override("panel", paper_style)
	panel.theme = _theme
	
	# Actualizar paper doll
	if paper and paper.has_method("update_from_mech"):
		paper.update_from_mech(mech)
	
	# Añadir al árbol
	_parent.add_child(_paper_doll_overlay)
	_paper_doll_overlay.add_child(center)
	center.add_child(panel)
	
	Log.debug("UI", "Paper doll modal shown", {"mech_name": mech.mech_name})

func _close_paper_doll_dialog() -> void:
	if _paper_doll_overlay:
		_paper_doll_overlay.queue_free()
		_paper_doll_overlay = null

func _create_paper_doll_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.13, 0.95)
	style.border_width_left = 3
	style.border_width_top = 2
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.2, 0.55, 0.85, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = Color(0.15, 0.35, 0.55, 0.5)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style
