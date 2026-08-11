extends RefCounted
class_name BattleUIFactory
## Factory para crear elementos UI comunes de batalla con estilo Steel Titans

var scale_factor: float = 1.0
var margin: float = 10.0
var _styles: SteelTitansStyles
var _theme: Theme

func _init(p_scale_factor: float, p_margin: float, p_theme: Theme = null) -> void:
	scale_factor = p_scale_factor
	margin = p_margin
	_theme = p_theme
	_styles = SteelTitansStyles.new(scale_factor)

# ============================================
# LABELS
# ============================================

func create_title_label(text: String, font_size: int = 22) -> Label:
	"""Crea un label de título con estilo Steel Titans"""
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(font_size * scale_factor))
	label.add_theme_color_override("font_color", SteelTitansStyles.get_cyan_text_color())
	label.add_theme_color_override("font_outline_color", SteelTitansStyles.get_outline_color())
	label.add_theme_constant_override("outline_size", 2)
	return label

func create_info_label(text: String, font_size: int = 14, color: Color = Color.WHITE) -> Label:
	"""Crea un label informativo"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(font_size * scale_factor))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	label.add_theme_constant_override("outline_size", 2)
	return label

func create_turn_label(text: String = "T1") -> Label:
	"""Crea el label de turno"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(22 * scale_factor))
	label.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	label.add_theme_constant_override("outline_size", 3)
	return label

func create_phase_label(text: String = "MOVEMENT") -> Label:
	"""Crea el label de fase"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(14 * scale_factor))
	label.add_theme_color_override("font_color", Color.CYAN)
	label.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	label.add_theme_constant_override("outline_size", 2)
	return label

func create_mech_name_label(font_size: int = 12) -> Label:
	"""Crea el label para nombre del mech"""
	var label = Label.new()
	label.text = ""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	label.add_theme_constant_override("outline_size", 1)
	return label

# ============================================
# BUTTONS
# ============================================

func create_end_turn_button(callback: Callable) -> Button:
	"""Crea el botón de fin de turno"""
	var btn = Button.new()
	btn.text = "END ▶"
	btn.size = Vector2(100 * scale_factor, 38 * scale_factor)
	btn.add_theme_font_size_override("font_size", int(16 * scale_factor))
	btn.add_theme_stylebox_override("normal", _styles.create_end_turn_button_style())
	btn.add_theme_stylebox_override("hover", _styles.create_end_turn_button_hover_style())
	btn.add_theme_stylebox_override("pressed", _styles.create_end_turn_button_hover_style())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.8, 1, 0.8, 1))
	btn.pressed.connect(callback)
	return btn

func create_cancel_button(callback: Callable, text: String = "✗ CANCEL") -> Button:
	"""Crea un botón de cancelar estilo Steel Titans"""
	var btn = Button.new()
	btn.text = text
	btn.size = Vector2(120 * scale_factor, 35 * scale_factor)
	btn.add_theme_font_size_override("font_size", int(14 * scale_factor))
	btn.visible = false
	btn.add_theme_stylebox_override("normal", _styles.create_cancel_movement_button_style())
	btn.add_theme_stylebox_override("hover", _styles.create_cancel_movement_button_hover_style())
	btn.add_theme_stylebox_override("pressed", _styles.create_cancel_movement_button_hover_style())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(1, 0.7, 0.7, 1))
	btn.pressed.connect(callback)
	return btn

func create_movement_button(text: String, callback: Callable) -> Button:
	"""Crea un botón de selección de movimiento"""
	var btn = Button.new()
	btn.text = text
	if _theme:
		btn.theme = _theme
	btn.add_theme_font_size_override("font_size", int(26 * scale_factor))
	btn.pressed.connect(callback)
	return btn

func create_physical_attack_button(text: String, callback: Callable) -> Button:
	"""Crea un botón de ataque físico"""
	var btn = Button.new()
	btn.text = text
	# Bug de estilo: a diferencia de create_movement_button, este botón nunca
	# aplicaba el theme compartido, así que salía con el Button gris por
	# defecto de Godot en vez del estilo Steel Titans del resto de menús.
	if _theme:
		btn.theme = _theme
	btn.add_theme_font_size_override("font_size", int(22 * scale_factor))
	btn.pressed.connect(callback)
	return btn

func create_icon_button(icon_text: String, btn_size: float, color: Color, style: StyleBoxFlat, callback: Callable) -> Button:
	"""Crea un botón con icono (para confirmación)"""
	var btn = Button.new()
	btn.text = icon_text
	btn.size = Vector2(btn_size, btn_size)
	btn.add_theme_font_size_override("font_size", int(28 * scale_factor))
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_stylebox_override("normal", style)
	var hover_style = style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.pressed.connect(callback)
	return btn

# ============================================
# PANELS
# ============================================

func create_info_panel(box_width: float, box_height: float) -> Panel:
	"""Crea el panel de información del mech"""
	var panel = Panel.new()
	panel.size = Vector2(box_width, box_height)
	panel.add_theme_stylebox_override("panel", _styles.create_info_panel_style())
	panel.visible = false
	return panel

func create_movement_selector_panel(width: float, height: float) -> Panel:
	"""Crea el panel de selección de movimiento"""
	var panel = Panel.new()
	panel.size = Vector2(width, height)
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _styles.create_main_panel_style())
	return panel

func create_physical_attack_panel(width: float, height: float) -> Panel:
	"""Crea el panel de ataques físicos"""
	var panel = Panel.new()
	panel.size = Vector2(width, height)
	panel.visible = false
	return panel

func create_confirmation_panel(width: float, height: float) -> Panel:
	"""Crea el panel de confirmación"""
	var panel = Panel.new()
	panel.size = Vector2(width, height)
	panel.visible = false
	panel.z_index = 200
	panel.add_theme_stylebox_override("panel", _styles.create_confirmation_panel_style())
	return panel

func create_confirm_icon_button(btn_size: float, callback: Callable) -> Button:
	"""Crea el botón de confirmar con tick verde"""
	var btn = Button.new()
	btn.text = "✓"
	btn.size = Vector2(btn_size, btn_size)
	btn.add_theme_font_size_override("font_size", int(28 * scale_factor))
	btn.add_theme_color_override("font_color", SteelTitansStyles.get_positive_color())
	btn.add_theme_color_override("font_hover_color", Color(0.2, 1.0, 0.2))
	btn.add_theme_color_override("font_pressed_color", Color(0.0, 0.7, 0.0))
	btn.add_theme_stylebox_override("normal", _styles.create_confirm_tick_button_style())
	var hover_style = _styles.create_confirm_tick_button_style()
	hover_style.bg_color = Color(0.1, 0.4, 0.1, 0.9)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.pressed.connect(callback)
	return btn

func create_cancel_icon_button(btn_size: float, callback: Callable) -> Button:
	"""Crea el botón de cancelar con cruz roja"""
	var btn = Button.new()
	btn.text = "✗"
	btn.size = Vector2(btn_size, btn_size)
	btn.add_theme_font_size_override("font_size", int(28 * scale_factor))
	btn.add_theme_color_override("font_color", SteelTitansStyles.get_negative_color())
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.25, 0.25))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.0, 0.0))
	btn.add_theme_stylebox_override("normal", _styles.create_cancel_cross_button_style())
	var hover_style = _styles.create_cancel_cross_button_style()
	hover_style.bg_color = Color(0.4, 0.1, 0.1, 0.9)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.pressed.connect(callback)
	return btn

func create_game_over_panel(width: float, height: float) -> Panel:
	"""Crea el panel de game over"""
	var panel = Panel.new()
	panel.size = Vector2(width, height)
	panel.add_theme_stylebox_override("panel", _styles.create_game_over_panel_style())
	return panel

# ============================================
# EYE BUTTON
# ============================================

func create_eye_button(btn_size: float, callback: Callable) -> Button:
	"""Crea el botón de ojo para overlays"""
	var btn = Button.new()
	btn.text = ""
	btn.size = Vector2(btn_size, btn_size)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Cargar icono SVG del ojo
	if ResourceLoader.exists("res://assets/ui/eye_icon.svg"):
		var eye_icon_texture = load("res://assets/ui/eye_icon.svg")
		var eye_icon_rect = TextureRect.new()
		eye_icon_rect.texture = eye_icon_texture
		eye_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		eye_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		eye_icon_rect.position = Vector2(btn_size * 0.15, btn_size * 0.15)
		eye_icon_rect.size = Vector2(btn_size * 0.7, btn_size * 0.7)
		eye_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(eye_icon_rect)
	
	btn.add_theme_stylebox_override("normal", _styles.create_eye_button_style())
	btn.add_theme_stylebox_override("hover", _styles.create_eye_button_hover_style())
	btn.add_theme_stylebox_override("pressed", _styles.create_eye_button_hover_style())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(callback)
	return btn

# ============================================
# HEAT & MP COMPONENTS
# ============================================

func create_heat_bar() -> ProgressBar:
	"""Crea la barra de calor"""
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 30
	bar.value = 0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _styles.create_heat_bar_background_style())
	bar.add_theme_stylebox_override("fill", _styles.create_heat_bar_fill_style())
	return bar

func create_heat_label(font_size: int = 12) -> Label:
	"""Crea el label de heat"""
	var label = Label.new()
	label.text = "0"
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8, 1))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label

func create_mp_container() -> VBoxContainer:
	"""Crea el contenedor de MP dots"""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 0)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	return container

func create_mp_dot(dot_size: float, texture: Texture2D) -> TextureRect:
	"""Crea un dot de MP"""
	var dot = TextureRect.new()
	dot.custom_minimum_size = Vector2(dot_size, dot_size)
	dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dot.texture = texture
	dot.visible = false
	return dot

# ============================================
# HELP LABEL
# ============================================

func create_help_label() -> Label:
	"""Crea el label de ayuda"""
	var label = Label.new()
	label.text = ""
	label.add_theme_font_size_override("font_size", int(11 * scale_factor))
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size = Vector2(200 * scale_factor, 40 * scale_factor)
	return label

# ============================================
# RICH TEXT LABELS
# ============================================

func create_death_label(panel_width: float) -> RichTextLabel:
	"""Crea el label de muerte para game over"""
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(panel_width - margin * 8, 100 * scale_factor)
	label.add_theme_font_size_override("normal_font_size", int(24 * scale_factor))
	return label

# ============================================
# CONFIRMATION MESSAGE
# ============================================

func create_confirmation_message() -> Label:
	"""Crea el label de mensaje de confirmación"""
	var label = Label.new()
	label.text = "Confirm action?"
	label.add_theme_font_size_override("font_size", int(13 * scale_factor))
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

# ============================================
# ACCESSORS
# ============================================

func get_styles() -> SteelTitansStyles:
	return _styles
