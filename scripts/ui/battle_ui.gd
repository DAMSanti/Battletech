
extends CanvasLayer
var scale_factor := 1.0
var margin := 10.0

@onready var battle_scene = get_parent()
@onready var battletech_theme = load("res://assets/themes/battletech_theme.tres")

# Paneles principales para ocultar/mostrar
var info_panel: Panel
var log_panel: Panel

var turn_label: Label
var phase_label: Label
var unit_info_label: Label
var mech_paper_doll: Control = null  # Paper doll del mech
var end_turn_button: Button
var help_label: Label
var cancel_movement_button: Button  # Botón para cancelar selección de movimiento
var combat_log: RichTextLabel
var combat_log_scrollbar: VScrollBar  # Scrollbar personalizada para el log
var combat_log_mode: String = "full"  # "full", "short" o "chat"
var full_button: Button
var short_button: Button
var chat_button: Button  # Nueva pestaña de chat para multiplayer
var collapse_log_button: Button  # Botón para colapsar/expandir el log
var combat_log_collapsed: bool = false  # Estado del log
var log_expanded_height: float = 0.0  # Altura cuando está expandido
var log_collapsed_height: float = 40.0  # Altura cuando está colapsado
var message_history: Array = []  # Almacenar todos los mensajes [{text: String, color: Color}]
var chat_history: Array = []  # Mensajes de chat multiplayer [{text: String, sender: String, color: Color}]
var chat_input_container: HBoxContainer = null  # Contenedor para entrada de chat
var chat_input: LineEdit = null  # Campo de entrada de chat

# Panel superior mejorado - Heat y MP visual
var heat_bar: ProgressBar = null
var heat_label: Label = null
var mp_container: VBoxContainer = null
var mp_dots: Array = []  # Array de TextureRect para los puntos de MP
var mp_dot_filled_texture: Texture2D = null
var mp_dot_empty_texture: Texture2D = null
var mech_name_label: Label = null

# Botón Eye y menú de overlays
var eye_button: Button = null
var eye_menu_panel: Panel = null
var overlay_elevation_toggle: Button = null
var overlay_coords_toggle: Button = null
var overlay_terrain_toggle: Button = null
var overlay_movement_toggle: Button = null
var overlay_los_toggle: Button = null
var overlay_settings: Dictionary = {
	"elevation": false,  # Por defecto desactivado
	"coords": false,
	"terrain": false,
	"movement": false,
	"los": false  # Line of Sight overlay
}

# Cache para overlay de LOS
var los_overlay_visible: bool = false
var los_overlay_hexes: Array = []

# Selector de tipo de movimiento
var movement_selector_panel: Panel
var movement_selector_title: Label
var walk_button: Button
var run_button: Button
var jump_button: Button
var turn_button: Button

# Selector de orientación (facing)
var facing_selector: Control

# Selector de armas para disparo
var weapon_selector_panel: Panel
var weapon_selector_title: Label
var weapon_buttons: Array = []
var selected_weapons: Array = []
var fire_button: Button
var cancel_weapon_button: Button

# Panel de información de arma
var weapon_info_panel: Panel
var weapon_info_label: RichTextLabel

# Selector de ataque físico
var physical_attack_panel: Panel
var punch_left_button: Button
var punch_right_button: Button
var kick_button: Button
var charge_button: Button
var cancel_physical_button: Button

# Pantalla de fin de juego
var game_over_panel: Panel
var game_over_visible: bool = false

# Panel de inspección de mech
var mech_inspector_panel: Panel
var mech_inspector_armor: Control
var mech_inspector_visible: bool = false

# Panel de confirmación genérico
var confirmation_panel: Panel
var confirmation_title: Label
var confirmation_message: Label
var confirm_button: Button
var cancel_button: Button
var confirmation_visible: bool = false
var on_confirm_callback: Callable
var on_cancel_callback: Callable

func _ready():
	_setup_ui()
	# Esperar un frame para que battle_scene esté listo
	await get_tree().process_frame
	if battle_scene and battle_scene.has_method("get_turn_manager"):
		var turn_manager = battle_scene.get_turn_manager()
		if turn_manager:
			turn_manager.turn_changed.connect(_on_turn_changed)
			turn_manager.phase_changed.connect(_on_phase_changed)
			turn_manager.unit_activated.connect(_on_unit_activated)

func _setup_ui():
	# Obtener tamaño de la pantalla
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y
	
	# Escalar todo basado en el ancho de pantalla
	scale_factor = screen_width / 720.0  # Resolución base 720px de ancho
	margin = 10 * scale_factor
	
	# Cargar texturas de MP dots
	if ResourceLoader.exists("res://assets/ui/mp_dot_filled.svg"):
		mp_dot_filled_texture = load("res://assets/ui/mp_dot_filled.svg")
	if ResourceLoader.exists("res://assets/ui/mp_dot_empty.svg"):
		mp_dot_empty_texture = load("res://assets/ui/mp_dot_empty.svg")
	
	# ============================================
	# SECCIÓN IZQUIERDA (SIN BOX): T1 + MOVEMENT + END
	# ============================================
	
	# Turn label (arriba izquierda, sin panel)
	turn_label = Label.new()
	turn_label.text = "T1"
	turn_label.position = Vector2(margin + 8 * scale_factor, margin + 4 * scale_factor)
	turn_label.add_theme_font_size_override("font_size", int(22 * scale_factor))
	turn_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	turn_label.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	turn_label.add_theme_constant_override("outline_size", 3)
	add_child(turn_label)
	
	# Phase label (debajo de T1)
	phase_label = Label.new()
	phase_label.text = "MOVEMENT"
	phase_label.position = Vector2(margin + 8 * scale_factor, margin + 30 * scale_factor)
	phase_label.add_theme_font_size_override("font_size", int(14 * scale_factor))
	phase_label.add_theme_color_override("font_color", Color.CYAN)
	phase_label.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	phase_label.add_theme_constant_override("outline_size", 2)
	add_child(phase_label)
	
	# Botón End (debajo de phase)
	end_turn_button = Button.new()
	end_turn_button.text = "END ▶"
	var end_btn_width = 100 * scale_factor
	var end_btn_height = 38 * scale_factor
	end_turn_button.position = Vector2(margin + 8 * scale_factor, margin + 52 * scale_factor)
	end_turn_button.size = Vector2(end_btn_width, end_btn_height)
	end_turn_button.add_theme_font_size_override("font_size", int(16 * scale_factor))
	var end_btn_style = StyleBoxFlat.new()
	end_btn_style.bg_color = Color(0.15, 0.35, 0.2, 0.9)
	end_btn_style.border_color = Color(0.3, 0.7, 0.4, 1)
	end_btn_style.border_width_left = 2
	end_btn_style.border_width_right = 2
	end_btn_style.border_width_top = 1
	end_btn_style.border_width_bottom = 2
	end_btn_style.corner_radius_top_left = 4
	end_btn_style.corner_radius_top_right = 4
	end_btn_style.corner_radius_bottom_left = 4
	end_btn_style.corner_radius_bottom_right = 4
	end_turn_button.add_theme_stylebox_override("normal", end_btn_style)
	var end_btn_hover = end_btn_style.duplicate()
	end_btn_hover.bg_color = Color(0.2, 0.45, 0.25, 1)
	end_turn_button.add_theme_stylebox_override("hover", end_btn_hover)
	end_turn_button.add_theme_stylebox_override("pressed", end_btn_hover)
	end_turn_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	end_turn_button.add_theme_color_override("font_color", Color(0.8, 1, 0.8, 1))
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	add_child(end_turn_button)
	
	# ============================================
	# BOX DERECHA: Robot + MPs + Heat + Nombre + Eye
	# ============================================
	
	# Calcular dimensiones de la box basadas en porcentajes de pantalla
	var box_height = screen_height * 0.18
	var box_width = screen_width * 0.28  # Ancho relativo a la pantalla
	box_width = clampf(box_width, 120, 300)  # Limitar tamaño mínimo y máximo
	
	# Crear el panel (box) arriba a la derecha
	info_panel = Panel.new()
	info_panel.position = Vector2(screen_width - margin - box_width, margin)
	info_panel.size = Vector2(box_width, box_height)
	
	# Estilo BattleTech azul
	var info_style = StyleBoxFlat.new()
	info_style.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	info_style.border_width_left = 2
	info_style.border_width_top = 2
	info_style.border_width_right = 2
	info_style.border_width_bottom = 2
	info_style.border_color = Color(0.2, 0.5, 0.7, 0.9)
	info_style.corner_radius_top_left = 8
	info_style.corner_radius_top_right = 8
	info_style.corner_radius_bottom_right = 8
	info_style.corner_radius_bottom_left = 8
	info_style.anti_aliasing = true
	info_style.shadow_color = Color(0.2, 0.5, 0.7, 0.3)
	info_style.shadow_size = 3
	info_style.shadow_offset = Vector2(0, 2)
	info_panel.add_theme_stylebox_override("panel", info_style)
	info_panel.visible = false  # Oculto hasta que se seleccione un mech
	add_child(info_panel)
	
	# --- POSICIONES RELATIVAS AL TAMAÑO DEL PANEL ---
	var panel_padding = box_width * 0.05  # 5% del ancho como padding
	var content_width = box_width - panel_padding * 2
	var content_height = box_height - panel_padding * 2
	
	# Eye button: 15% del ancho del panel, cuadrado
	var eye_btn_size = box_width * 0.15
	eye_btn_size = clampf(eye_btn_size, 24, 40)
	
	# MP column: 12% del ancho del contenido
	var mp_column_width = content_width * 0.12
	mp_column_width = clampf(mp_column_width, 14, 24)
	
	# Doll: ocupa el resto del espacio menos padding
	var doll_width = content_width - mp_column_width - panel_padding
	var doll_height = content_height * 0.85  # 85% de la altura para el robot
	
	# Heat section height
	var heat_section_height = content_height * 0.15
	
	# Posiciones X relativas
	var mp_x = panel_padding
	var doll_x = mp_x + mp_column_width + panel_padding * 0.5
	var doll_center_x = doll_x + doll_width * 0.5
	
	# Posiciones Y relativas
	var doll_y = panel_padding + content_height * 0.15
	var heat_y = box_height - panel_padding - heat_section_height
	
	# 1. EYE BUTTON (arriba a la derecha de la box)
	eye_button = Button.new()
	eye_button.text = ""  # Sin texto, usamos icono
	eye_button.position = Vector2(box_width - panel_padding - eye_btn_size, panel_padding)
	eye_button.size = Vector2(eye_btn_size, eye_btn_size)
	eye_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Cargar icono SVG del ojo
	if ResourceLoader.exists("res://assets/ui/eye_icon.svg"):
		var eye_icon_texture = load("res://assets/ui/eye_icon.svg")
		var eye_icon_rect = TextureRect.new()
		eye_icon_rect.texture = eye_icon_texture
		eye_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		eye_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		eye_icon_rect.position = Vector2(eye_btn_size * 0.15, eye_btn_size * 0.15)
		eye_icon_rect.size = Vector2(eye_btn_size * 0.7, eye_btn_size * 0.7)
		eye_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		eye_button.add_child(eye_icon_rect)
	
	var eye_style = StyleBoxFlat.new()
	eye_style.bg_color = Color(0.1, 0.15, 0.22, 0.9)
	eye_style.border_color = Color(0.3, 0.6, 0.9, 0.9)
	eye_style.set_border_width_all(2)
	eye_style.set_corner_radius_all(6)
	eye_button.add_theme_stylebox_override("normal", eye_style)
	var eye_hover = eye_style.duplicate()
	eye_hover.bg_color = Color(0.15, 0.22, 0.32, 0.95)
	eye_button.add_theme_stylebox_override("hover", eye_hover)
	eye_button.add_theme_stylebox_override("pressed", eye_hover)
	eye_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	eye_button.pressed.connect(_on_eye_button_pressed)
	info_panel.add_child(eye_button)
	
	# 2. PAPER DOLL DEL MECH (empieza desde arriba)
	if ResourceLoader.exists("res://scenes/mech_paper_doll.tscn"):
		var paper_doll_scene = load("res://scenes/mech_paper_doll.tscn")
		if paper_doll_scene:
			mech_paper_doll = paper_doll_scene.instantiate()
			mech_paper_doll.position = Vector2(doll_x, doll_y)
			mech_paper_doll.size = Vector2(doll_width, doll_height)
			mech_paper_doll.visible = false
			info_panel.add_child(mech_paper_doll)
	
	# 3. NOMBRE DEL MECH (alineado con la cabeza del robot)
	var name_font_size = int(box_height * 0.08)
	name_font_size = clampi(name_font_size, 8, 14)
	mech_name_label = Label.new()
	mech_name_label.text = ""
	mech_name_label.position = Vector2(doll_x - doll_width * 0.1, doll_y - content_height * 0.15)
	mech_name_label.size = Vector2(doll_width * 1.2, box_height * 0.12)
	mech_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mech_name_label.add_theme_font_size_override("font_size", name_font_size)
	mech_name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 1))
	mech_name_label.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	mech_name_label.add_theme_constant_override("outline_size", 1)
	info_panel.add_child(mech_name_label)
	
	# 4. MP DOTS (columna vertical a la izquierda del robot)
	var mp_dot_size = mp_column_width * 0.9
	mp_dot_size = clampf(mp_dot_size, 10, 20)
	
	mp_container = VBoxContainer.new()
	mp_container.position = Vector2(mp_x, doll_y - content_height * 0.15)
	mp_container.size = Vector2(mp_column_width, doll_height)
	mp_container.add_theme_constant_override("separation", 0)
	mp_container.alignment = BoxContainer.ALIGNMENT_CENTER
	info_panel.add_child(mp_container)
	
	for i in range(12):
		var dot = TextureRect.new()
		dot.custom_minimum_size = Vector2(mp_dot_size, mp_dot_size)
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.texture = mp_dot_empty_texture
		dot.visible = false
		mp_container.add_child(dot)
		mp_dots.append(dot)
	
	# 5. HEAT SECTION (debajo del robot, centrado y alineado)
	var heat_row_height = heat_section_height * 0.8
	var heat_font_size = int(heat_section_height * 0.6)
	heat_font_size = clampi(heat_font_size, 8, 14)
	var heat_icon_width = heat_section_height
	var heat_label_width = heat_section_height * 1.5
	var heat_bar_width = content_width - heat_icon_width - heat_label_width - panel_padding
	var heat_start_x = mp_x
	
	# Heat icon usando SVG
	var heat_icon = TextureRect.new()
	if ResourceLoader.exists("res://assets/ui/heat_icon.svg"):
		heat_icon.texture = load("res://assets/ui/heat_icon.svg")
	heat_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heat_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heat_icon.position = Vector2(heat_start_x, heat_y)
	heat_icon.size = Vector2(heat_icon_width, heat_section_height)
	info_panel.add_child(heat_icon)
	
	heat_bar = ProgressBar.new()
	heat_bar.position = Vector2(heat_start_x + heat_icon_width, heat_y + heat_section_height * 0.15)
	heat_bar.size = Vector2(heat_bar_width, heat_row_height)
	heat_bar.min_value = 0
	heat_bar.max_value = 30
	heat_bar.value = 0
	heat_bar.show_percentage = false
	var heat_bg_style = StyleBoxFlat.new()
	heat_bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	heat_bg_style.border_color = Color(0.3, 0.3, 0.3, 1)
	heat_bg_style.set_border_width_all(1)
	heat_bg_style.set_corner_radius_all(2)
	heat_bar.add_theme_stylebox_override("background", heat_bg_style)
	var heat_fill_style = StyleBoxFlat.new()
	heat_fill_style.bg_color = Color(0.2, 0.7, 0.3, 1)
	heat_fill_style.set_corner_radius_all(1)
	heat_bar.add_theme_stylebox_override("fill", heat_fill_style)
	info_panel.add_child(heat_bar)
	
	heat_label = Label.new()
	heat_label.text = "0"
	heat_label.position = Vector2(heat_start_x + heat_icon_width + heat_bar_width + panel_padding * 0.5, heat_y)
	heat_label.size = Vector2(heat_label_width, heat_section_height)
	heat_label.add_theme_font_size_override("font_size", heat_font_size)
	heat_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8, 1))
	heat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_panel.add_child(heat_label)
	
	# ============================================
	# Help label y Cancel button (debajo de END, sin box)
	# ============================================
	help_label = Label.new()
	help_label.text = ""
	help_label.position = Vector2(margin + 8 * scale_factor, margin + 85 * scale_factor)
	help_label.add_theme_font_size_override("font_size", int(11 * scale_factor))
	help_label.add_theme_color_override("font_color", Color.YELLOW)
	help_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	help_label.add_theme_constant_override("outline_size", 2)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	help_label.size = Vector2(200 * scale_factor, 40 * scale_factor)
	add_child(help_label)
	
	# Botón de cancelar movimiento - CENTRADO EN PARTE SUPERIOR DE PANTALLA
	cancel_movement_button = Button.new()
	cancel_movement_button.text = "✗ CANCEL"
	var cancel_btn_width = 120 * scale_factor
	var cancel_btn_height = 35 * scale_factor
	cancel_movement_button.position = Vector2((screen_width - cancel_btn_width) / 2, margin)
	cancel_movement_button.size = Vector2(cancel_btn_width, cancel_btn_height)
	cancel_movement_button.add_theme_font_size_override("font_size", int(14 * scale_factor))
	cancel_movement_button.visible = false
	var cancel_btn_style = StyleBoxFlat.new()
	cancel_btn_style.bg_color = Color(0.35, 0.1, 0.1, 0.9)
	cancel_btn_style.border_color = Color(0.8, 0.2, 0.2, 1)
	cancel_btn_style.border_width_left = 2
	cancel_btn_style.border_width_right = 2
	cancel_btn_style.border_width_top = 1
	cancel_btn_style.border_width_bottom = 2
	cancel_btn_style.corner_radius_top_left = 4
	cancel_btn_style.corner_radius_top_right = 4
	cancel_btn_style.corner_radius_bottom_left = 4
	cancel_btn_style.corner_radius_bottom_right = 4
	cancel_movement_button.add_theme_stylebox_override("normal", cancel_btn_style)
	var cancel_btn_hover = cancel_btn_style.duplicate()
	cancel_btn_hover.bg_color = Color(0.5, 0.15, 0.15, 1)
	cancel_movement_button.add_theme_stylebox_override("hover", cancel_btn_hover)
	cancel_movement_button.add_theme_stylebox_override("pressed", cancel_btn_hover)
	cancel_movement_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	cancel_movement_button.add_theme_color_override("font_color", Color(1, 0.7, 0.7, 1))
	cancel_movement_button.pressed.connect(_on_cancel_movement_pressed)
	add_child(cancel_movement_button)
	
	# unit_info_label oculto (para compatibilidad)
	unit_info_label = Label.new()
	unit_info_label.visible = false
	add_child(unit_info_label)
	
	# ============================================
	# Crear menú de overlays del Eye (va fuera de la box)
	# ============================================
	_create_eye_menu()
	
	# ============================================
	# COMBAT LOG MEJORADO - Colapsable con pestañas
	# ============================================
	# Reutilizar viewport_size del inicio de _setup_ui
	log_expanded_height = screen_height * 0.26  # Aumentado para que quepa el textbox
	log_collapsed_height = 40 * scale_factor  # Aumentado para que quepa el botón
	var log_height = log_expanded_height
	
	log_panel = Panel.new()
	log_panel.position = Vector2(margin, screen_height - log_height - margin)
	log_panel.size = Vector2(screen_width * 0.95, log_height)
	log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Aplicar estilo BattleTech al panel de combat log
	var log_style = StyleBoxFlat.new()
	log_style.bg_color = Color(0.08, 0.12, 0.18, 0.85)
	log_style.border_width_left = 3
	log_style.border_width_top = 2
	log_style.border_width_right = 3
	log_style.border_width_bottom = 3
	log_style.border_color = Color(0.2, 0.5, 0.7, 0.9)
	log_style.corner_radius_top_left = 8
	log_style.corner_radius_top_right = 8
	log_style.corner_radius_bottom_right = 8
	log_style.corner_radius_bottom_left = 8
	log_style.border_blend = true
	log_style.anti_aliasing = true
	log_style.shadow_color = Color(0.2, 0.5, 0.7, 0.4)
	log_style.shadow_size = 4
	log_style.shadow_offset = Vector2(0, 2)
	log_style.skew = Vector2(0.03, 0)  # Skew reducido para mejor legibilidad
	log_panel.add_theme_stylebox_override("panel", log_style)
	
	# Conectar gui_input al panel para bloquear clicks que van al mapa
	log_panel.gui_input.connect(_on_log_panel_gui_input)
	add_child(log_panel)
	
	# Header del log con título y controles
	var header_height = 30 * scale_factor
	
	# Botón colapsar/expandir (izquierda)
	collapse_log_button = Button.new()
	collapse_log_button.text = "▼"
	collapse_log_button.position = Vector2(margin + 5 * scale_factor, 4 * scale_factor)
	collapse_log_button.size = Vector2(28 * scale_factor, 24 * scale_factor)
	collapse_log_button.add_theme_font_size_override("font_size", int(14 * scale_factor))
	collapse_log_button.mouse_filter = Control.MOUSE_FILTER_STOP
	# Estilo plano sin glow para el botón de colapsar
	var collapse_btn_style = StyleBoxFlat.new()
	collapse_btn_style.bg_color = Color(0.1, 0.15, 0.2, 0.8)
	collapse_btn_style.border_color = Color(0.3, 0.5, 0.7, 0.8)
	collapse_btn_style.border_width_left = 1
	collapse_btn_style.border_width_top = 1
	collapse_btn_style.border_width_right = 1
	collapse_btn_style.border_width_bottom = 1
	collapse_btn_style.corner_radius_top_left = 4
	collapse_btn_style.corner_radius_top_right = 4
	collapse_btn_style.corner_radius_bottom_right = 4
	collapse_btn_style.corner_radius_bottom_left = 4
	collapse_log_button.add_theme_stylebox_override("normal", collapse_btn_style)
	var collapse_btn_hover = collapse_btn_style.duplicate()
	collapse_btn_hover.bg_color = Color(0.15, 0.2, 0.28, 0.9)
	collapse_log_button.add_theme_stylebox_override("hover", collapse_btn_hover)
	collapse_log_button.add_theme_stylebox_override("pressed", collapse_btn_hover)
	collapse_log_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	collapse_log_button.add_theme_color_override("font_color", Color(0.7, 0.85, 1, 1))
	collapse_log_button.pressed.connect(_on_toggle_log_collapse)
	log_panel.add_child(collapse_log_button)
	
	# Título "Log"
	var log_title = Label.new()
	log_title.text = "Log"
	log_title.position = Vector2(margin + 38 * scale_factor, 6 * scale_factor)
	log_title.add_theme_font_size_override("font_size", int(16 * scale_factor))
	log_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	log_title.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	log_title.add_theme_constant_override("outline_size", 1)
	log_panel.add_child(log_title)
	
	# Pestañas FULL | SHORT | CHAT (centro-derecha)
	var tab_button_width = 55 * scale_factor
	var tab_button_height = 22 * scale_factor
	var tab_spacing = 3 * scale_factor
	var tabs_total_width = tab_button_width * 3 + tab_spacing * 2
	var tabs_x_start = log_panel.size.x - margin - tabs_total_width - 35 * scale_factor
	var tab_y = 5 * scale_factor
	
	full_button = Button.new()
	full_button.text = "FULL"
	full_button.position = Vector2(tabs_x_start, tab_y)
	full_button.size = Vector2(tab_button_width, tab_button_height)
	full_button.theme = battletech_theme
	full_button.add_theme_font_size_override("font_size", int(10 * scale_factor))
	full_button.pressed.connect(_on_log_mode_changed.bind("full"))
	log_panel.add_child(full_button)
	
	short_button = Button.new()
	short_button.text = "SHORT"
	short_button.position = Vector2(tabs_x_start + tab_button_width + tab_spacing, tab_y)
	short_button.size = Vector2(tab_button_width, tab_button_height)
	short_button.theme = battletech_theme
	short_button.add_theme_font_size_override("font_size", int(10 * scale_factor))
	short_button.pressed.connect(_on_log_mode_changed.bind("short"))
	log_panel.add_child(short_button)
	
	chat_button = Button.new()
	chat_button.text = "CHAT"
	chat_button.position = Vector2(tabs_x_start + (tab_button_width + tab_spacing) * 2, tab_y)
	chat_button.size = Vector2(tab_button_width, tab_button_height)
	chat_button.theme = battletech_theme
	chat_button.add_theme_font_size_override("font_size", int(10 * scale_factor))
	chat_button.pressed.connect(_on_log_mode_changed.bind("chat"))
	log_panel.add_child(chat_button)
	
	# Actualizar visual de botones
	_update_log_mode_buttons()
	
	# ---- COMBAT LOG CON SCROLLBAR PERSONALIZADA ----
	var scrollbar_width = 35 * scale_factor  # Ancho de scrollbar para móvil
	var log_content_margin_left = margin + 15 * scale_factor  # Extra margen izquierdo por skew
	var log_content_margin_right = margin + 15 * scale_factor  # Margen derecho
	var log_content_top = header_height + 10 * scale_factor
	
	# RichTextLabel SIN scrollbar interna (la ocultamos)
	combat_log = RichTextLabel.new()
	combat_log.position = Vector2(log_content_margin_left, log_content_top)
	combat_log.size = Vector2(
		log_panel.size.x - log_content_margin_left - log_content_margin_right - scrollbar_width - 5 * scale_factor,
		log_panel.size.y - log_content_top - 10 * scale_factor
	)
	combat_log.bbcode_enabled = true
	combat_log.scroll_following = true
	combat_log.scroll_active = false  # Desactivar scroll interno
	combat_log.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_log.add_theme_font_size_override("normal_font_size", int(13 * scale_factor))
	
	# Fondo del área de texto
	var combat_log_bg = StyleBoxFlat.new()
	combat_log_bg.bg_color = Color(0.03, 0.05, 0.08, 0.5)
	combat_log_bg.border_width_left = 1
	combat_log_bg.border_width_top = 1
	combat_log_bg.border_width_right = 1
	combat_log_bg.border_width_bottom = 1
	combat_log_bg.border_color = Color(0.15, 0.3, 0.45, 0.5)
	combat_log_bg.corner_radius_top_left = 4
	combat_log_bg.corner_radius_top_right = 4
	combat_log_bg.corner_radius_bottom_right = 4
	combat_log_bg.corner_radius_bottom_left = 4
	combat_log.add_theme_stylebox_override("normal", combat_log_bg)
	combat_log.add_theme_color_override("default_color", Color(0.85, 0.92, 1, 1))
	log_panel.add_child(combat_log)
	
	# Scrollbar personalizada a la derecha
	combat_log_scrollbar = VScrollBar.new()
	combat_log_scrollbar.position = Vector2(
		log_panel.size.x - log_content_margin_right - scrollbar_width,
		log_content_top
	)
	combat_log_scrollbar.size = Vector2(scrollbar_width, combat_log.size.y)
	combat_log_scrollbar.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Estilo del grabber (la parte que se arrastra)
	var grabber_style = StyleBoxFlat.new()
	grabber_style.bg_color = Color(0.3, 0.5, 0.7, 0.9)
	grabber_style.corner_radius_top_left = 6
	grabber_style.corner_radius_top_right = 6
	grabber_style.corner_radius_bottom_right = 6
	grabber_style.corner_radius_bottom_left = 6
	grabber_style.skew = Vector2(0.03, 0)  # Skew para coincidir con el panel
	combat_log_scrollbar.add_theme_stylebox_override("grabber", grabber_style)
	combat_log_scrollbar.add_theme_stylebox_override("grabber_highlight", grabber_style)
	combat_log_scrollbar.add_theme_stylebox_override("grabber_pressed", grabber_style)
	
	# Estilo del fondo del scroll
	var scroll_bg_style = StyleBoxFlat.new()
	scroll_bg_style.bg_color = Color(0.08, 0.12, 0.18, 0.7)
	scroll_bg_style.corner_radius_top_left = 6
	scroll_bg_style.corner_radius_top_right = 6
	scroll_bg_style.corner_radius_bottom_right = 6
	scroll_bg_style.corner_radius_bottom_left = 6
	scroll_bg_style.skew = Vector2(0.03, 0)  # Skew para coincidir con el panel
	combat_log_scrollbar.add_theme_stylebox_override("scroll", scroll_bg_style)
	
	# Conectar la scrollbar con el RichTextLabel y bloquear clicks
	combat_log_scrollbar.value_changed.connect(_on_log_scrollbar_changed)
	combat_log_scrollbar.gui_input.connect(_on_scrollbar_gui_input)
	log_panel.add_child(combat_log_scrollbar)
	
	# Ocultar scrollbar interna y conectar para sincronizar
	var internal_scrollbar = combat_log.get_v_scroll_bar()
	internal_scrollbar.modulate.a = 0  # Hacerla invisible
	internal_scrollbar.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Ignorar clicks
	internal_scrollbar.value_changed.connect(_on_combat_log_scrolled)
	
	# Chat input (solo visible en modo chat)
	var chat_input_height = 28 * scale_factor
	chat_input_container = HBoxContainer.new()
	chat_input_container.position = Vector2(log_content_margin_left, log_panel.size.y - chat_input_height - 5 * scale_factor)
	chat_input_container.size = Vector2(combat_log.size.x, chat_input_height)
	chat_input_container.visible = false  # Oculto por defecto, solo visible en modo chat
	chat_input_container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Escribe un mensaje..."
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.add_theme_font_size_override("font_size", int(12 * scale_factor))
	chat_input.text_submitted.connect(_on_chat_message_submitted)
	
	var chat_input_style = StyleBoxFlat.new()
	chat_input_style.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	chat_input_style.border_color = Color(0.2, 0.4, 0.6, 0.8)
	chat_input_style.border_width_left = 1
	chat_input_style.border_width_top = 1
	chat_input_style.border_width_right = 1
	chat_input_style.border_width_bottom = 1
	chat_input_style.corner_radius_top_left = 4
	chat_input_style.corner_radius_top_right = 4
	chat_input_style.corner_radius_bottom_right = 4
	chat_input_style.corner_radius_bottom_left = 4
	chat_input.add_theme_stylebox_override("normal", chat_input_style)
	chat_input.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_input.add_theme_color_override("font_color", Color(0.9, 0.95, 1, 1))
	chat_input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.6, 0.7, 0.7))
	chat_input_container.add_child(chat_input)
	
	var send_button = Button.new()
	send_button.text = "➤"
	send_button.custom_minimum_size = Vector2(40 * scale_factor, chat_input_height)
	send_button.theme = battletech_theme
	send_button.add_theme_font_size_override("font_size", int(14 * scale_factor))
	send_button.pressed.connect(_on_send_chat_pressed)
	chat_input_container.add_child(send_button)
	
	log_panel.add_child(chat_input_container)
	
	# ============================================
	# FIN COMBAT LOG
	# ============================================
	
	# Panel selector de tipo de movimiento (centrado, 85% del ancho) - Estilo BattleTech
	var movement_panel_width = screen_width * 0.85
	var movement_panel_height = screen_height * 0.45
	movement_selector_panel = Panel.new()
	movement_selector_panel.position = Vector2((screen_width - movement_panel_width) / 2, (screen_height - movement_panel_height) / 2 - 50 * scale_factor)
	movement_selector_panel.size = Vector2(movement_panel_width, movement_panel_height)
	movement_selector_panel.visible = false
	
	# Estilo BattleTech para el panel de movimiento
	var movement_style = StyleBoxFlat.new()
	movement_style.bg_color = Color(0.08, 0.12, 0.18, 0.5)  # Fondo semi-transparente
	movement_style.border_width_left = int(3 * scale_factor)
	movement_style.border_width_top = int(3 * scale_factor)
	movement_style.border_width_right = int(3 * scale_factor)
	movement_style.border_width_bottom = int(3 * scale_factor)
	movement_style.border_color = Color(0.3, 0.7, 1, 1)  # Cian brillante
	movement_style.corner_radius_top_left = int(12 * scale_factor)
	movement_style.corner_radius_top_right = int(12 * scale_factor)
	movement_style.corner_radius_bottom_left = int(12 * scale_factor)
	movement_style.corner_radius_bottom_right = int(12 * scale_factor)
	movement_style.border_blend = true
	movement_style.anti_aliasing = true
	movement_style.shadow_color = Color(0.3, 0.7, 1, 0.6)
	movement_style.shadow_size = int(10 * scale_factor)
	movement_style.shadow_offset = Vector2(0, 3)
	movement_style.skew = Vector2(0.05, 0)  # Inclinación futurista
	movement_selector_panel.add_theme_stylebox_override("panel", movement_style)
	add_child(movement_selector_panel)
	
	movement_selector_title = Label.new()
	movement_selector_title.text = "SELECT MOVEMENT TYPE"
	movement_selector_title.position = Vector2(margin * 2, margin * 2)
	movement_selector_title.size = Vector2(movement_panel_width - margin * 4, 30 * scale_factor)
	movement_selector_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	movement_selector_title.add_theme_font_size_override("font_size", int(22 * scale_factor))
	movement_selector_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))  # Cian BattleTech
	movement_selector_title.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	movement_selector_title.add_theme_constant_override("outline_size", 2)
	movement_selector_panel.add_child(movement_selector_title)
	
	var button_height = (movement_panel_height - 100 * scale_factor) / 4
	var button_width = movement_panel_width - margin * 4
	var button_x = margin * 2
	
	walk_button = Button.new()
	walk_button.text = "WALK"
	walk_button.position = Vector2(button_x, 55 * scale_factor)
	walk_button.size = Vector2(button_width, button_height)
	walk_button.theme = battletech_theme
	walk_button.add_theme_font_size_override("font_size", int(26 * scale_factor))
	walk_button.pressed.connect(_on_walk_pressed)
	movement_selector_panel.add_child(walk_button)
	
	run_button = Button.new()
	run_button.text = "RUN"
	run_button.position = Vector2(button_x, 55 * scale_factor + button_height + 5)
	run_button.size = Vector2(button_width, button_height)
	run_button.theme = battletech_theme
	run_button.add_theme_font_size_override("font_size", int(26 * scale_factor))
	run_button.pressed.connect(_on_run_pressed)
	movement_selector_panel.add_child(run_button)
	
	jump_button = Button.new()
	jump_button.text = "JUMP"
	jump_button.position = Vector2(button_x, 55 * scale_factor + (button_height + 5) * 2)
	jump_button.size = Vector2(button_width, button_height)
	jump_button.theme = battletech_theme
	jump_button.add_theme_font_size_override("font_size", int(26 * scale_factor))
	jump_button.pressed.connect(_on_jump_pressed)
	movement_selector_panel.add_child(jump_button)
	
	turn_button = Button.new()
	turn_button.text = "TURN"
	turn_button.position = Vector2(button_x, 55 * scale_factor + (button_height + 5) * 3)
	turn_button.size = Vector2(button_width, button_height)
	turn_button.theme = battletech_theme
	turn_button.add_theme_font_size_override("font_size", int(26 * scale_factor))
	turn_button.pressed.connect(_on_turn_pressed)
	movement_selector_panel.add_child(turn_button)
	
	# Selector de orientación (facing) - capa superior
	var FacingSelector = load("res://scripts/ui/facing_selector.gd")
	facing_selector = FacingSelector.new()
	facing_selector.size = Vector2(300 * scale_factor, 300 * scale_factor)
	facing_selector.visible = false
	facing_selector.facing_selected.connect(_on_facing_selected)
	add_child(facing_selector)
	
	# Panel selector de armas (85% del ancho, 50% de la altura)
	var weapon_panel_width = screen_width * 0.85
	var weapon_panel_height = screen_height * 0.50
	weapon_selector_panel = Panel.new()
	weapon_selector_panel.position = Vector2((screen_width - weapon_panel_width) / 2, (screen_height - weapon_panel_height) / 2)
	weapon_selector_panel.size = Vector2(weapon_panel_width, weapon_panel_height)
	weapon_selector_panel.visible = false
	# IMPORTANTE: Bloquear eventos de mouse/touch para que no pasen al battle_scene
	weapon_selector_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Conectar gui_input para consumir eventos y evitar propagación
	weapon_selector_panel.gui_input.connect(_on_weapon_panel_input)
	
	# Estilo BattleTech para el panel de armas - MÁS TRANSPARENTE
	var weapon_style = StyleBoxFlat.new()
	weapon_style.bg_color = Color(0.08, 0.12, 0.18, 0.3)  # Reducida opacidad de 0.5 a 0.3
	weapon_style.border_width_left = int(3 * scale_factor)
	weapon_style.border_width_top = int(3 * scale_factor)
	weapon_style.border_width_right = int(3 * scale_factor)
	weapon_style.border_width_bottom = int(3 * scale_factor)
	weapon_style.border_color = Color(0.3, 0.7, 1, 1)  # Cian brillante
	weapon_style.corner_radius_top_left = int(12 * scale_factor)
	weapon_style.corner_radius_top_right = int(12 * scale_factor)
	weapon_style.corner_radius_bottom_left = int(12 * scale_factor)
	weapon_style.corner_radius_bottom_right = int(12 * scale_factor)
	weapon_style.border_blend = true
	weapon_style.anti_aliasing = true
	weapon_style.shadow_color = Color(0.3, 0.7, 1, 0.6)
	weapon_style.shadow_size = int(10 * scale_factor)
	weapon_style.shadow_offset = Vector2(0, 3)
	weapon_style.skew = Vector2(0.05, 0)  # Inclinación futurista
	weapon_selector_panel.add_theme_stylebox_override("panel", weapon_style)
	add_child(weapon_selector_panel)
	
	weapon_selector_title = Label.new()
	weapon_selector_title.text = "SELECT WEAPONS TO FIRE"
	weapon_selector_title.position = Vector2(margin, margin)
	weapon_selector_title.size = Vector2(weapon_panel_width - margin * 2, 30 * scale_factor)
	weapon_selector_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_selector_title.add_theme_font_size_override("font_size", int(20 * scale_factor))
	weapon_selector_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	weapon_selector_title.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	weapon_selector_title.add_theme_constant_override("outline_size", 2)
	weapon_selector_panel.add_child(weapon_selector_title)
	
	# Los botones de armas se crearán dinámicamente en show_weapon_selector()
	
	# Botón para confirmar disparo
	fire_button = Button.new()
	fire_button.text = "FIRE SELECTED WEAPONS"
	fire_button.position = Vector2(margin, weapon_panel_height - 120 * scale_factor)
	fire_button.size = Vector2(weapon_panel_width - margin * 2, 55 * scale_factor)
	fire_button.add_theme_font_size_override("font_size", int(22 * scale_factor))
	fire_button.pressed.connect(_on_fire_weapons_pressed)
	weapon_selector_panel.add_child(fire_button)
	
	# Botón para cancelar
	cancel_weapon_button = Button.new()
	cancel_weapon_button.text = "CANCEL"
	cancel_weapon_button.position = Vector2(margin, weapon_panel_height - 60 * scale_factor)
	cancel_weapon_button.size = Vector2(weapon_panel_width - margin * 2, 55 * scale_factor)
	cancel_weapon_button.add_theme_font_size_override("font_size", int(22 * scale_factor))
	cancel_weapon_button.pressed.connect(_on_cancel_weapons_pressed)
	weapon_selector_panel.add_child(cancel_weapon_button)
	
	# Panel de información detallada de arma (PANEL INDEPENDIENTE CENTRADO)
	# Tamaño optimizado: 60% ancho x 55% alto
	var info_panel_width = screen_width * 0.60
	var info_panel_height = screen_height * 0.55
	weapon_info_panel = Panel.new()
	# Centrado en la pantalla
	weapon_info_panel.position = Vector2((screen_width - info_panel_width) / 2, (screen_height - info_panel_height) / 2)
	weapon_info_panel.size = Vector2(info_panel_width, info_panel_height)
	weapon_info_panel.visible = false
	weapon_info_panel.z_index = 100  # MUY por encima para asegurar visibilidad
	
	# Crear StyleBox modernizado estilo BattleTech con ROMBOIDE (skew)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.05, 0.08, 0.12, 0.96)  # Azul muy oscuro casi opaco
	style_box.border_width_left = int(4 * scale_factor)
	style_box.border_width_right = int(4 * scale_factor)
	style_box.border_width_top = int(4 * scale_factor)
	style_box.border_width_bottom = int(4 * scale_factor)
	style_box.border_color = Color(0.3, 0.7, 1.0, 1.0)  # Cian brillante
	style_box.corner_radius_top_left = int(2 * scale_factor)
	style_box.corner_radius_top_right = int(12 * scale_factor)
	style_box.corner_radius_bottom_left = int(12 * scale_factor)
	style_box.corner_radius_bottom_right = int(2 * scale_factor)
	style_box.border_blend = true
	style_box.anti_aliasing = true
	style_box.shadow_color = Color(0.2, 0.6, 0.9, 0.7)
	style_box.shadow_size = int(12 * scale_factor)
	style_box.shadow_offset = Vector2(2, 4)
	style_box.skew = Vector2(0.08, 0)  # ROMBOIDE - Inclinación futurista más pronunciada
	weapon_info_panel.add_theme_stylebox_override("panel", style_box)
	
	# Añadir como hijo directo de battle_ui, NO del weapon_selector_panel
	add_child(weapon_info_panel)
	
	var header_bar = Panel.new()
	header_bar.position = Vector2(0, 0)
	header_bar.size = Vector2(info_panel_width, 40 * scale_factor)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.12, 0.22, 0.35, 0.9)
	header_style.border_width_bottom = int(3 * scale_factor)
	header_style.border_color = Color(0.3, 0.7, 1.0, 1.0)
	header_style.skew = Vector2(0.08, 0)  # Mismo skew que el panel principal
	header_bar.add_theme_stylebox_override("panel", header_style)
	weapon_info_panel.add_child(header_bar)
	
	var info_title = Label.new()
	info_title.text = "◢ WEAPON DATA ◣"
	# Centrado normal sin compensación excesiva
	info_title.position = Vector2(margin, 6 * scale_factor)
	info_title.size = Vector2(info_panel_width - margin * 2 - 50 * scale_factor, 28 * scale_factor)
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_title.add_theme_font_size_override("font_size", int(20 * scale_factor))
	info_title.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0, 1.0))
	info_title.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	info_title.add_theme_constant_override("outline_size", 2)
	weapon_info_panel.add_child(info_title)
	
	# Botón para cerrar el panel de info
	var close_info_button = Button.new()
	close_info_button.text = "✕"
	close_info_button.position = Vector2(info_panel_width - 45 * scale_factor, 4 * scale_factor)
	close_info_button.size = Vector2(36 * scale_factor, 32 * scale_factor)
	close_info_button.add_theme_font_size_override("font_size", int(22 * scale_factor))
	close_info_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	close_info_button.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.5, 1.0))
	close_info_button.pressed.connect(_on_close_weapon_info_pressed)
	weapon_info_panel.add_child(close_info_button)
	
	weapon_info_label = RichTextLabel.new()
	weapon_info_label.position = Vector2(margin * 2, 48 * scale_factor)
	weapon_info_label.size = Vector2(info_panel_width - margin * 4, info_panel_height - 60 * scale_factor)
	weapon_info_label.bbcode_enabled = true
	weapon_info_label.fit_content = true
	weapon_info_label.scroll_following = true
	# Fondo semi-transparente SIN skew (el skew del panel principal ya da el efecto)
	var text_bg = StyleBoxFlat.new()
	text_bg.bg_color = Color(0.02, 0.04, 0.08, 0.5)
	text_bg.border_width_left = 1
	text_bg.border_width_right = 1
	text_bg.border_width_top = 1
	text_bg.border_width_bottom = 1
	text_bg.border_color = Color(0.2, 0.4, 0.6, 0.3)
	# NO aplicar skew al texto para evitar deformación
	weapon_info_label.add_theme_stylebox_override("normal", text_bg)
	weapon_info_panel.add_child(weapon_info_label)
	
	# Panel selector de ataque físico (85% del ancho, 50% de la altura)
	var physical_panel_width = screen_width * 0.85
	var physical_panel_height = screen_height * 0.50
	physical_attack_panel = Panel.new()
	physical_attack_panel.position = Vector2((screen_width - physical_panel_width) / 2, (screen_height - physical_panel_height) / 2)
	physical_attack_panel.size = Vector2(physical_panel_width, physical_panel_height)
	physical_attack_panel.visible = false
	add_child(physical_attack_panel)
	
	var physical_title = Label.new()
	physical_title.text = "SELECT PHYSICAL ATTACK"
	physical_title.position = Vector2(margin, margin)
	physical_title.add_theme_font_size_override("font_size", int(20 * scale_factor))
	physical_title.add_theme_color_override("font_color", Color.MAGENTA)
	physical_attack_panel.add_child(physical_title)
	
	var phys_button_height = (physical_panel_height - 80 * scale_factor) / 5
	var phys_button_width = physical_panel_width - margin * 2
	
	# Botón puñetazo izquierdo
	punch_left_button = Button.new()
	punch_left_button.text = "PUNCH (Left Arm)"
	punch_left_button.position = Vector2(margin, 50 * scale_factor)
	punch_left_button.size = Vector2(phys_button_width, phys_button_height)
	punch_left_button.add_theme_font_size_override("font_size", int(22 * scale_factor))
	punch_left_button.pressed.connect(_on_punch_left_pressed)
	physical_attack_panel.add_child(punch_left_button)
	
	# Botón puñetazo derecho
	punch_right_button = Button.new()
	punch_right_button.text = "PUNCH (Right Arm)"
	punch_right_button.position = Vector2(margin, 50 * scale_factor + phys_button_height + 5)
	punch_right_button.size = Vector2(phys_button_width, phys_button_height)
	punch_right_button.add_theme_font_size_override("font_size", int(22 * scale_factor))
	punch_right_button.pressed.connect(_on_punch_right_pressed)
	physical_attack_panel.add_child(punch_right_button)
	
	# Botón patada
	kick_button = Button.new()
	kick_button.text = "KICK"
	kick_button.position = Vector2(margin, 50 * scale_factor + (phys_button_height + 5) * 2)
	kick_button.size = Vector2(phys_button_width, phys_button_height)
	kick_button.add_theme_font_size_override("font_size", int(22 * scale_factor))
	kick_button.pressed.connect(_on_kick_pressed)
	physical_attack_panel.add_child(kick_button)
	
	# Botón embestida
	charge_button = Button.new()
	charge_button.text = "CHARGE"
	charge_button.position = Vector2(margin, 50 * scale_factor + (phys_button_height + 5) * 3)
	charge_button.size = Vector2(phys_button_width, phys_button_height)
	charge_button.add_theme_font_size_override("font_size", int(22 * scale_factor))
	charge_button.pressed.connect(_on_charge_pressed)
	physical_attack_panel.add_child(charge_button)
	
	# Botón cancelar
	cancel_physical_button = Button.new()
	cancel_physical_button.text = "CANCEL"
	cancel_physical_button.position = Vector2(margin, 50 * scale_factor + (phys_button_height + 5) * 4)
	cancel_physical_button.size = Vector2(phys_button_width, phys_button_height)
	cancel_physical_button.add_theme_font_size_override("font_size", int(22 * scale_factor))
	cancel_physical_button.pressed.connect(_on_cancel_physical_pressed)
	physical_attack_panel.add_child(cancel_physical_button)
	
	# Panel de confirmación genérico - Estilo BattleTech (centrado en pantalla, compacto)
	var confirm_panel_width = 420 * scale_factor
	var confirm_panel_height = 90 * scale_factor
	confirmation_panel = Panel.new()
	confirmation_panel.position = Vector2((screen_width - confirm_panel_width) / 2, (screen_height - confirm_panel_height) / 2)  # Centrado
	confirmation_panel.size = Vector2(confirm_panel_width, confirm_panel_height)
	confirmation_panel.visible = false
	confirmation_panel.z_index = 200  # Encima de todo
	add_child(confirmation_panel)
	
	# Estilo BattleTech: fondo azul transparente, borde cian brillante, forma romboide
	var confirm_style = StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.08, 0.12, 0.18, 0.5)  # Azul transparente BattleTech
	confirm_style.border_width_left = int(3 * scale_factor)
	confirm_style.border_width_right = int(3 * scale_factor)
	confirm_style.border_width_top = int(3 * scale_factor)
	confirm_style.border_width_bottom = int(3 * scale_factor)
	confirm_style.border_color = Color(0.3, 0.7, 1, 1)  # Cian brillante
	confirm_style.corner_radius_top_left = int(8 * scale_factor)
	confirm_style.corner_radius_top_right = int(8 * scale_factor)
	confirm_style.corner_radius_bottom_left = int(8 * scale_factor)
	confirm_style.corner_radius_bottom_right = int(8 * scale_factor)
	confirm_style.border_blend = true
	confirm_style.anti_aliasing = true
	confirm_style.shadow_color = Color(0.3, 0.7, 1, 0.6)
	confirm_style.shadow_size = int(10 * scale_factor)
	confirm_style.shadow_offset = Vector2(0, 3)
	confirm_style.skew = Vector2(0.05, 0)  # Inclinación futurista romboide
	confirmation_panel.add_theme_stylebox_override("panel", confirm_style)
	
	# Mensaje centrado horizontalmente en la parte superior del panel
	confirmation_message = Label.new()
	confirmation_message.text = "Confirm action?"
	confirmation_message.position = Vector2(margin, margin)
	confirmation_message.size = Vector2(confirm_panel_width - margin * 2, 30 * scale_factor)
	confirmation_message.add_theme_font_size_override("font_size", int(13 * scale_factor))
	confirmation_message.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))  # Texto claro
	confirmation_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirmation_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirmation_panel.add_child(confirmation_message)
	
	# Título oculto (no necesario en formato banner)
	confirmation_title = Label.new()
	confirmation_title.visible = false
	confirmation_panel.add_child(confirmation_title)
	
	# Botones como iconos grandes centrados horizontalmente
	var button_size = 45 * scale_factor  # Botones cuadrados grandes
	var button_spacing = 30 * scale_factor
	var total_buttons_width = button_size * 2 + button_spacing
	var button_x_start = (confirm_panel_width - total_buttons_width) / 2
	var button_y = 40 * scale_factor
	
	# Botón CONFIRMAR - Tick verde
	confirm_button = Button.new()
	confirm_button.text = "✓"
	confirm_button.position = Vector2(button_x_start, button_y)
	confirm_button.size = Vector2(button_size, button_size)
	confirm_button.add_theme_font_size_override("font_size", int(28 * scale_factor))
	confirm_button.add_theme_color_override("font_color", Color(0.1, 0.9, 0.1))  # Verde brillante
	confirm_button.add_theme_color_override("font_hover_color", Color(0.2, 1.0, 0.2))
	confirm_button.add_theme_color_override("font_pressed_color", Color(0.0, 0.7, 0.0))
	
	# Estilo del botón confirmar
	var confirm_btn_style = StyleBoxFlat.new()
	confirm_btn_style.bg_color = Color(0.05, 0.3, 0.05, 0.8)  # Verde oscuro
	confirm_btn_style.border_width_left = 2
	confirm_btn_style.border_width_right = 2
	confirm_btn_style.border_width_top = 2
	confirm_btn_style.border_width_bottom = 2
	confirm_btn_style.border_color = Color(0.1, 0.9, 0.1)
	confirm_btn_style.corner_radius_top_left = 4
	confirm_btn_style.corner_radius_top_right = 4
	confirm_btn_style.corner_radius_bottom_left = 4
	confirm_btn_style.corner_radius_bottom_right = 4
	confirm_button.add_theme_stylebox_override("normal", confirm_btn_style)
	
	var confirm_btn_hover = confirm_btn_style.duplicate()
	confirm_btn_hover.bg_color = Color(0.1, 0.4, 0.1, 0.9)
	confirm_button.add_theme_stylebox_override("hover", confirm_btn_hover)
	
	confirm_button.pressed.connect(_on_confirmation_confirm)
	confirmation_panel.add_child(confirm_button)
	
	# Botón CANCELAR - Cruz roja
	cancel_button = Button.new()
	cancel_button.text = "✗"
	cancel_button.position = Vector2(button_x_start + button_size + button_spacing, button_y)
	cancel_button.size = Vector2(button_size, button_size)
	cancel_button.add_theme_font_size_override("font_size", int(28 * scale_factor))
	cancel_button.add_theme_color_override("font_color", Color(0.95, 0.15, 0.15))  # Rojo brillante
	cancel_button.add_theme_color_override("font_hover_color", Color(1.0, 0.25, 0.25))
	cancel_button.add_theme_color_override("font_pressed_color", Color(0.7, 0.0, 0.0))
	
	# Estilo del botón cancelar confirmación
	var confirm_cancel_style = StyleBoxFlat.new()
	confirm_cancel_style.bg_color = Color(0.3, 0.05, 0.05, 0.8)  # Rojo oscuro
	confirm_cancel_style.border_width_left = 2
	confirm_cancel_style.border_width_right = 2
	confirm_cancel_style.border_width_top = 2
	confirm_cancel_style.border_width_bottom = 2
	confirm_cancel_style.border_color = Color(0.95, 0.15, 0.15)
	confirm_cancel_style.corner_radius_top_left = 4
	confirm_cancel_style.corner_radius_top_right = 4
	confirm_cancel_style.corner_radius_bottom_left = 4
	confirm_cancel_style.corner_radius_bottom_right = 4
	cancel_button.add_theme_stylebox_override("normal", confirm_cancel_style)
	
	var confirm_cancel_hover = confirm_cancel_style.duplicate()
	confirm_cancel_hover.bg_color = Color(0.4, 0.1, 0.1, 0.9)
	cancel_button.add_theme_stylebox_override("hover", confirm_cancel_hover)
	
	cancel_button.pressed.connect(_on_confirmation_cancel)
	confirmation_panel.add_child(cancel_button)

func _on_turn_changed(_team: String, turn_number: int):
	if turn_label:
		turn_label.text = "T%d" % turn_number

func _on_phase_changed(phase_name: String):
	if phase_label:
		phase_label.text = phase_name.to_upper()
		
		var color = Color.CYAN
		match phase_name:
			"Initiative":
				color = Color.YELLOW
			"Movement":
				color = Color.CYAN
			"Combat":
				color = Color.RED
			"Heat":
				color = Color.ORANGE
			"End":
				color = Color.GRAY
		
		phase_label.add_theme_color_override("font_color", color)

func update_turn_info(turn_number: int, team: String):
	# Actualizar información del turno
	if turn_label:
		turn_label.text = "T%d" % turn_number

func _on_unit_activated(unit):
	if unit:
		# Verificar si es una unidad del jugador
		var is_player_unit = false
		if battle_scene and battle_scene.has_method("is_player_mech"):
			is_player_unit = battle_scene.is_player_mech(unit)
		elif battle_scene and "player_mechs" in battle_scene:
			is_player_unit = unit in battle_scene.player_mechs
		
		# SOLO actualizar info superior si es unidad del jugador
		if is_player_unit:
			# Mostrar el panel de info del mech
			if info_panel:
				info_panel.visible = true
			
			# Obtener nombre del mech correctamente
			var unit_name = ""
			if "mech_name" in unit:
				unit_name = unit.mech_name
			elif "pilot_name" in unit:
				unit_name = unit.pilot_name
			else:
				unit_name = "Mech"

			var mp = unit.current_movement if "current_movement" in unit else 0
			var max_mp = unit.movement_points if "movement_points" in unit else (unit.walk_mp if "walk_mp" in unit else 6)
			var heat = unit.heat if "heat" in unit else 0
			var heat_cap = unit.heat_capacity if "heat_capacity" in unit else 30

			# Actualizar nombre del mech
			if mech_name_label:
				mech_name_label.text = unit_name
			
			# Actualizar barra de heat
			_update_heat_bar(heat, heat_cap)
			
			# Actualizar puntos de MP
			_update_mp_dots(mp, max_mp)
			
			# Mantener unit_info_label por compatibilidad
			if unit_info_label:
				var info = "%s - MP: %s | Heat: %s/%s" % [unit_name, mp, heat, heat_cap]
				unit_info_label.text = info
			
			# Actualizar paper doll si existe
			if mech_paper_doll and mech_paper_doll.has_method("update_from_mech"):
				mech_paper_doll.visible = true
				mech_paper_doll.update_from_mech(unit)
		else:
			# Si es un enemigo, ocultar el panel completo
			if info_panel:
				info_panel.visible = false

func _update_heat_bar(current_heat: int, max_heat: int):
	"""Actualiza la barra de heat con colores según el nivel"""
	if not heat_bar or not heat_label:
		return
	
	heat_bar.max_value = max_heat if max_heat > 0 else 30
	heat_bar.value = current_heat
	heat_label.text = "%d/%d" % [current_heat, max_heat]
	
	# Cambiar color según nivel de heat
	var heat_ratio = float(current_heat) / float(max_heat) if max_heat > 0 else 0
	var fill_style = heat_bar.get_theme_stylebox("fill").duplicate()
	
	if heat_ratio < 0.3:
		fill_style.bg_color = Color(0.2, 0.7, 0.3, 1)  # Verde
		heat_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
	elif heat_ratio < 0.6:
		fill_style.bg_color = Color(0.8, 0.7, 0.2, 1)  # Amarillo
		heat_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5, 1))
	elif heat_ratio < 0.8:
		fill_style.bg_color = Color(0.9, 0.5, 0.1, 1)  # Naranja
		heat_label.add_theme_color_override("font_color", Color(1, 0.7, 0.4, 1))
	else:
		fill_style.bg_color = Color(0.9, 0.2, 0.1, 1)  # Rojo
		heat_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5, 1))
	
	heat_bar.add_theme_stylebox_override("fill", fill_style)

func _update_mp_dots(current_mp: int, max_mp: int):
	"""Actualiza los puntos de MP visuales"""
	if mp_dots.is_empty():
		return
	
	for i in range(mp_dots.size()):
		var dot = mp_dots[i]
		if i < max_mp:
			dot.visible = true
			if i < current_mp:
				dot.texture = mp_dot_filled_texture
				dot.modulate = Color(0.4, 0.9, 0.5, 1)  # Verde brillante
			else:
				dot.texture = mp_dot_empty_texture
				dot.modulate = Color(0.5, 0.5, 0.5, 0.8)  # Gris
		else:
			dot.visible = false

func update_unit_info(unit):
	# Alias para _on_unit_activated para compatibilidad
	_on_unit_activated(unit)

func update_phase_info(phase: String):
	# Alias para _on_phase_changed para compatibilidad
	_on_phase_changed(phase)

func _on_end_turn_pressed():
	if battle_scene and battle_scene.has_method("end_current_activation"):
		battle_scene.end_current_activation()

func _on_cancel_movement_pressed():
	"""Cancelar selección de movimiento y volver al selector de tipo"""
	print("[UI] Cancel movement pressed")
	hide_cancel_movement_button()
	if battle_scene and battle_scene.has_method("cancel_movement_selection"):
		battle_scene.cancel_movement_selection()

func show_cancel_movement_button():
	"""Muestra el botón de cancelar movimiento"""
	if cancel_movement_button:
		cancel_movement_button.visible = true

func hide_cancel_movement_button():
	"""Oculta el botón de cancelar movimiento"""
	if cancel_movement_button:
		cancel_movement_button.visible = false

func _on_log_mode_changed(mode: String):
	combat_log_mode = mode
	_update_log_mode_buttons()
	_refresh_combat_log()
	_update_chat_input_visibility()

func _update_log_mode_buttons():
	"""Actualiza el estilo visual de las pestañas del log"""
	var active_color = Color(0.4, 0.9, 0.5)  # Verde brillante para activo
	var inactive_color = Color(0.7, 0.7, 0.7)  # Gris para inactivo
	
	if full_button:
		full_button.modulate = active_color if combat_log_mode == "full" else inactive_color
	if short_button:
		short_button.modulate = active_color if combat_log_mode == "short" else inactive_color
	if chat_button:
		chat_button.modulate = active_color if combat_log_mode == "chat" else inactive_color

func _update_chat_input_visibility():
	"""Muestra/oculta el campo de entrada de chat según el modo y estado del log"""
	if chat_input_container:
		# Solo visible en modo chat y cuando el log no está colapsado
		chat_input_container.visible = (combat_log_mode == "chat" and not combat_log_collapsed)
		
		# Ajustar el tamaño del RichTextLabel y scrollbar para dejar espacio al input
		if combat_log and log_panel:
			var header_height = 30 * scale_factor
			var log_content_top = header_height + 10 * scale_factor
			var chat_input_height = 28 * scale_factor
			var bottom_margin = 10 * scale_factor
			
			if chat_input_container.visible:
				# Reducir altura del log para dejar espacio al input
				var new_height = log_panel.size.y - log_content_top - chat_input_height - bottom_margin - 5 * scale_factor
				combat_log.size.y = new_height
				if combat_log_scrollbar:
					combat_log_scrollbar.size.y = new_height
			else:
				# Altura completa cuando no hay input visible
				var new_height = log_panel.size.y - log_content_top - bottom_margin
				combat_log.size.y = new_height
				if combat_log_scrollbar:
					combat_log_scrollbar.size.y = new_height

func _on_log_panel_gui_input(event: InputEvent):
	"""Captura todos los eventos de input en el panel de log para que no pasen al mapa"""
	# Solo marcar como manejado para eventos que NO son de la scrollbar
	# La scrollbar necesita procesar sus propios eventos
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()

func _on_scrollbar_gui_input(_event: InputEvent):
	"""La scrollbar maneja sus propios eventos - no hacer nada aquí"""
	# NO llamar set_input_as_handled() porque la scrollbar necesita el evento
	# La protección viene de is_mouse_over_log_panel() en battle_scene
	pass

func is_mouse_over_log_panel() -> bool:
	"""Devuelve true si el mouse/touch está sobre el panel de log o el menú de Eye"""
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Verificar panel de log
	if log_panel and log_panel.visible:
		var panel_rect = Rect2(log_panel.global_position, log_panel.size)
		if panel_rect.has_point(mouse_pos):
			return true
	
	# Verificar botón de Eye
	if eye_button and eye_button.visible:
		var eye_rect = Rect2(eye_button.global_position, eye_button.size)
		if eye_rect.has_point(mouse_pos):
			return true
	
	# Verificar menú de Eye
	if eye_menu_panel and eye_menu_panel.visible:
		var menu_rect = Rect2(eye_menu_panel.global_position, eye_menu_panel.size)
		if menu_rect.has_point(mouse_pos):
			return true
	
	return false

func _on_toggle_log_collapse():
	"""Alterna entre log expandido y colapsado"""
	combat_log_collapsed = not combat_log_collapsed
	_update_log_collapse_state()

func _on_log_scrollbar_changed(value: float):
	"""Sincroniza la scrollbar personalizada con el RichTextLabel"""
	if combat_log:
		var internal_scroll = combat_log.get_v_scroll_bar()
		if internal_scroll and internal_scroll.value != value:
			internal_scroll.value = value

func _on_combat_log_scrolled(value: float):
	"""Sincroniza el scroll interno del RichTextLabel con la scrollbar personalizada"""
	if combat_log_scrollbar and combat_log_scrollbar.value != value:
		combat_log_scrollbar.value = value

func _update_scrollbar_range():
	"""Actualiza el rango de la scrollbar personalizada"""
	if not combat_log or not combat_log_scrollbar:
		return
	var internal_scroll = combat_log.get_v_scroll_bar()
	if internal_scroll:
		combat_log_scrollbar.min_value = internal_scroll.min_value
		combat_log_scrollbar.max_value = internal_scroll.max_value
		combat_log_scrollbar.page = internal_scroll.page
		combat_log_scrollbar.value = internal_scroll.value

func _update_log_collapse_state():
	"""Actualiza el estado visual del log según si está colapsado o no"""
	if not log_panel:
		return
	
	var screen_height = get_viewport().get_visible_rect().size.y
	var target_height = log_collapsed_height if combat_log_collapsed else log_expanded_height
	
	# Actualizar tamaño y posición del panel
	log_panel.size.y = target_height
	log_panel.position.y = screen_height - target_height - margin
	
	# Actualizar botón de colapso
	if collapse_log_button:
		collapse_log_button.text = "▲" if combat_log_collapsed else "▼"
	
	# Mostrar/ocultar contenido del log
	if combat_log:
		combat_log.visible = not combat_log_collapsed
	
	# Mostrar/ocultar scrollbar personalizada
	if combat_log_scrollbar:
		combat_log_scrollbar.visible = not combat_log_collapsed
	
	# Mostrar/ocultar pestañas cuando está colapsado
	if full_button:
		full_button.visible = not combat_log_collapsed
	if short_button:
		short_button.visible = not combat_log_collapsed
	if chat_button:
		chat_button.visible = not combat_log_collapsed
	
	# Actualizar visibilidad del chat input
	_update_chat_input_visibility()

func _refresh_combat_log():
	if not combat_log:
		return
	
	# Limpiar el log
	combat_log.clear()
	
	# Si estamos en modo chat, mostrar mensajes de chat
	if combat_log_mode == "chat":
		for msg_data in chat_history:
			var sender = msg_data.get("sender", "???")
			var text = msg_data.get("text", "")
			var color = msg_data.get("color", Color.WHITE)
			combat_log.push_color(color)
			combat_log.append_text("[%s]: %s\n" % [sender, text])
			combat_log.pop()
		call_deferred("_update_scrollbar_range")
		return
	
	# Regenerar todos los mensajes con el filtrado actual
	for msg_data in message_history:
		_add_message_to_log(msg_data["text"], msg_data["color"])
	
	call_deferred("_update_scrollbar_range")

func _add_message_to_log(message: String, color: Color):
	# Esta función procesa y añade un mensaje al log según el modo actual
	if not combat_log:
		return
	
	var final_message = message
	var final_color = color
	
	# En modo SHORT, filtrar mensajes
	if combat_log_mode == "short":
		var msg = message.strip_edges()
		
		# Ignorar líneas vacías y separadores
		if msg == "":
			return
		if "═══" in msg or "╔═" in msg or "╚═" in msg or "║" in msg:
			return
		if "─────────" in msg:
			return  # Ocultar líneas decorativas
		
		# DEPLOYMENT - Solo mostrar "DEPLOYING MECH [X/Y]"
		if "DEPLOYING MECH" in msg:
			pass  # Mostrar tal cual
		elif "ENEMY DEPLOYMENT" in msg:
			pass  # Mostrar tal cual
		elif "MISSION BRIEF:" in msg or "DEPLOYMENT INSTRUCTIONS:" in msg:
			return  # Ocultar títulos de briefing
		elif "BATTLE ROSTER:" in msg or "PLAYER LANCE:" in msg or "ENEMY LANCE:" in msg or "ENEMY FORCE:" in msg:
			return  # Ocultar títulos de roster
		elif "Invalid deployment location" in msg:
			return  # Ocultar mensaje de error de deployment
		elif "Mech:" in msg or "Tonnage:" in msg or "Movement:" in msg or "Jump:" in msg:
			return  # Ocultar detalles de deployment
		elif "Progress:" in msg or "Click on a GREEN hex" in msg:
			return  # Ocultar instrucciones
		
		# INICIATIVA - Mostrar tiradas y ganador
		if "rolls:" in msg and ("[" in msg or "=" in msg):
			if "Player rolls:" in msg:
				var parts = msg.split("=")
				if parts.size() > 1:
					final_message = "Player Initiative: " + parts[1].strip_edges()
					final_color = Color.CYAN
			elif "Enemy rolls:" in msg:
				var parts = msg.split("=")
				if parts.size() > 1:
					final_message = "Enemy Initiative: " + parts[1].strip_edges()
					final_color = Color.RED
		elif "WINS INITIATIVE" in msg:
			pass  # Mostrar tal cual
		elif "moves first" in msg:
			return  # Ocultar
		
		# MOVIMIENTO
		elif "selected:" in msg:
			return
		elif ("WALK" in msg or "RUN" in msg or "JUMP" in msg) and "from" in msg and "to" in msg:
			var parts = msg.split(" from ")
			if parts.size() > 0:
				var name_and_type = parts[0]
				var rest = parts[1] if parts.size() > 1 else ""
				if " to " in rest:
					var to_parts = rest.split(" to ")
					var destination = to_parts[1].split("(")[0].strip_edges() if to_parts.size() > 1 else ""
					var tmm_match = rest.find("TMM:")
					var tmm = ""
					if tmm_match != -1:
						var tmm_start = rest.find("+", tmm_match)
						var tmm_end = rest.find(")", tmm_start)
						if tmm_start != -1 and tmm_end != -1:
							tmm = " (TMM " + rest.substr(tmm_start, tmm_end - tmm_start) + ")"
					final_message = name_and_type + " → " + destination + tmm
		elif "Moved" in msg and "hexes" in msg and "Cost:" in msg:
			return  # Ocultar detalles de movimiento (hexágonos y coste)
		elif "MPs remaining:" in msg and "TMM:" in msg:
			return  # Ocultar MPs restantes y TMM en modo short
		elif "Movement heat generated" in msg:
			return
		elif "Movimiento realizado" in msg:
			return
		
		# ATAQUE - Solo arma y resultado
		elif "FIRES AT" in msg.to_upper():
			return  # Ocultar encabezado
		elif msg.begins_with("→ "):
			# Nombre del arma - mostrar tal cual
			pass
		elif "Roll:" in msg:
			return  # Ocultar roll (antes de check de "  ")
		elif message.begins_with("  "):  # Usar message original, no msg (que tiene strip_edges)
			# Detalles indentados - filtrar todo excepto resultados importantes
			if "HIT!" in msg:
				if "Location:" in msg and "Damage:" in msg:
					var loc_start = msg.find("Location:") + 9
					var loc_end = msg.find(",", loc_start)
					var location = msg.substr(loc_start, loc_end - loc_start).strip_edges()
					var dmg_start = msg.find("Damage:") + 7
					var damage = msg.substr(dmg_start).strip_edges()
					final_message = "  HIT! Location: " + location + ", Damage: " + damage
					final_color = Color.GREEN
			elif "MISS" in msg:
				final_message = "  MISS"
				final_color = Color.GRAY
			elif "DESTROYED!" in msg and msg.count("☠") > 0:
				pass  # Mostrar mech destruido
			elif "CRITICAL HIT" in msg:
				final_message = "  CRITICAL HIT!"
				final_color = Color.RED
			elif "DESTROYED!" in msg:
				final_message = "  " + msg.replace("⚠ ", "")
			elif "→ " in msg and ("DESTROYED!" in msg or "takes" in msg or "FALLS" in msg):
				pass  # Mostrar eventos importantes de físico
			else:
				# Ocultar: breakdown de skills, modifiers, base TN, etc.
				return
		elif "Heat generated:" in msg and "Current:" in msg:
			var parts = msg.split("(Current:")
			if parts.size() > 1:
				final_message = "Heat: " + parts[1].replace(")", "").strip_edges()
				final_color = Color.ORANGE
		elif "Heat will be processed" in msg:
			return
		
		# FÍSICO
		elif "attacks" in msg and "range:" in msg:
			pass  # Mostrar
		elif "Roll:" in msg:
			return  # Ocultar rolls
		elif "TN:" in msg:
			return  # Ocultar target numbers
		
		# CALOR
		elif "Avoided shutdown" in msg or "Avoided ammo explosion" in msg:
			return
		elif "SHUTDOWN!" in msg or "AMMO EXPLOSION!" in msg:
			final_message = msg.replace("☠", "").strip_edges()
	
	# Escribir al log (modo FULL usa el mensaje original, SHORT usa el filtrado)
	combat_log.push_color(final_color)
	combat_log.append_text(final_message + "\n")
	combat_log.pop()
	
	# Actualizar rango de la scrollbar personalizada
	call_deferred("_update_scrollbar_range")

func add_combat_message(message: String, color: Color = Color.WHITE):
	# Solo evitar duplicados de mensajes específicos que se repiten por señales múltiples
	# (iniciativa, ganadores, etc.), NO mensajes de combate normales
	var msg_stripped = message.strip_edges()
	
	# Lista de mensajes que SÍ queremos detectar como duplicados
	var check_duplicates = false
	if "Initiative" in msg_stripped or "WINS INITIATIVE" in msg_stripped:
		check_duplicates = true
	elif "rolls:" in msg_stripped:  # Quitar check de "=" para capturar más variaciones
		check_duplicates = true
	elif "moves first" in msg_stripped:
		check_duplicates = true
	
	if check_duplicates:
		var check_last = min(15, message_history.size())  # Aumentar a 15 mensajes
		for i in range(check_last):
			var idx = message_history.size() - 1 - i
			var last_msg = message_history[idx]
			if last_msg["text"] == message and last_msg["color"] == color:
				return  # Ignorar duplicado de iniciativa
	
	# Guardar en el historial
	message_history.append({"text": message, "color": color})
	
	# Añadir al log visible (solo si no estamos en modo chat)
	if combat_log_mode != "chat":
		_add_message_to_log(message, color)

func add_chat_message(sender: String, message: String, color: Color = Color.WHITE):
	"""Añade un mensaje de chat (para multiplayer)"""
	chat_history.append({"sender": sender, "text": message, "color": color})
	
	# Si estamos en modo chat, mostrar inmediatamente
	if combat_log_mode == "chat" and combat_log:
		combat_log.push_color(color)
		combat_log.append_text("[%s]: %s\n" % [sender, message])
		combat_log.pop()

func _on_chat_message_submitted(text: String):
	"""Callback cuando se presiona Enter en el campo de chat"""
	if text.strip_edges().is_empty():
		return
	_send_chat_message(text)
	chat_input.clear()

func _on_send_chat_pressed():
	"""Callback cuando se presiona el botón de enviar"""
	if chat_input and not chat_input.text.strip_edges().is_empty():
		_send_chat_message(chat_input.text)
		chat_input.clear()

func _send_chat_message(text: String):
	"""Envía un mensaje de chat. En multiplayer, esto se enviaría por red."""
	# Obtener nombre del jugador local
	var sender_name = "Jugador"
	var battle_scene = get_parent()
	if battle_scene and battle_scene.has_method("get"):
		var network_manager = battle_scene.get("network_manager")
		if network_manager and network_manager.has_method("get_local_player_name"):
			sender_name = network_manager.get_local_player_name()
	
	# Añadir mensaje local
	add_chat_message(sender_name, text, Color(0.7, 0.9, 1, 1))
	
	# En multiplayer, enviar por RPC (esto se implementará en network_manager)
	if battle_scene and battle_scene.has_method("send_chat_message"):
		battle_scene.send_chat_message(text)

func set_help_text(text: String):
	if help_label:
		help_label.text = text

func update_end_turn_button(enabled: bool, text: String = "End Activation"):
	if end_turn_button:
		end_turn_button.disabled = not enabled
		end_turn_button.text = text

## SELECTOR DE TIPO DE MOVIMIENTO ##

func show_movement_type_selector(unit):
	var stack = get_stack()
	for i in range(min(5, stack.size())):  # Mostrar las primeras 5 líneas del stack
		var _frame = stack[i]
	
	# Muestra el selector con información del mech
	if movement_selector_panel:
		# Actualizar título con nombre del mech
		if movement_selector_title:
			movement_selector_title.text = "★ SELECT MOVEMENT TYPE - %s ★" % unit.mech_name.to_upper()
		
		# Actualizar textos de botones con MP disponibles
		walk_button.text = "WALK (%d MP)\nNo penalty" % unit.walk_mp
		run_button.text = "RUN (%d MP)\n+1 defense, +2 to fire" % unit.run_mp
		
		if unit.jump_mp > 0:
			jump_button.text = "JUMP (%d MP)\n+2 defense, +3 to fire" % unit.jump_mp
			jump_button.disabled = false
		else:
			jump_button.text = "JUMP (No Jets)"
			jump_button.disabled = true
		
		turn_button.text = "TURN IN PLACE\nChange facing only"
		
		movement_selector_panel.visible = true

func hide_movement_type_selector():
	# Oculta el selector
	if movement_selector_panel:
		movement_selector_panel.visible = false
	
	# Notificar al battle_scene para evitar clicks fantasma
	if battle_scene and battle_scene.has_method("notify_ui_interaction"):
		battle_scene.notify_ui_interaction()

func _on_walk_pressed():
	if battle_scene and battle_scene.has_method("select_movement_type"):
		battle_scene.select_movement_type(1)  # Mech.MovementType.WALK
	hide_movement_type_selector()

func _on_run_pressed():
	if battle_scene and battle_scene.has_method("select_movement_type"):
		battle_scene.select_movement_type(2)  # Mech.MovementType.RUN
	hide_movement_type_selector()

func _on_jump_pressed():
	if battle_scene and battle_scene.has_method("select_movement_type"):
		battle_scene.select_movement_type(3)  # Mech.MovementType.JUMP
	hide_movement_type_selector()

func _on_turn_pressed():
	if battle_scene and battle_scene.has_method("select_turn_only"):
		battle_scene.select_turn_only()
	hide_movement_type_selector()

## SELECTOR DE ORIENTACIÓN (FACING) ##

func show_facing_selector(screen_position: Vector2, hex: Vector2i = Vector2i(-1, -1)):
	"""Muestra el selector de orientación en una posición de pantalla (para despliegue)"""
	if facing_selector:
		if hex != Vector2i(-1, -1) and battle_scene:
			facing_selector.set_target_hex(hex, battle_scene)
		facing_selector.show_at_position(screen_position, -1, 99)

func show_facing_selector_with_current(screen_position: Vector2, current_facing: int, available_mp: int, hex: Vector2i = Vector2i(-1, -1)):
	"""Muestra el selector de orientación con facing actual y MPs disponibles
	Si se proporciona hex, el selector se anclará a esa posición y seguirá la cámara"""
	if facing_selector:
		# Siempre establecer el hex objetivo si está disponible para que siga la cámara
		if hex != Vector2i(-1, -1) and battle_scene:
			facing_selector.set_target_hex(hex, battle_scene)
			# Obtener la posición actualizada del hex en pantalla
			if battle_scene.has_method("get_screen_position_for_hex"):
				screen_position = battle_scene.get_screen_position_for_hex(hex)
		facing_selector.show_at_position(screen_position, current_facing, available_mp)

func hide_facing_selector():
	"""Oculta el selector de orientación"""
	if facing_selector:
		facing_selector.visible = false

func is_facing_selector_visible() -> bool:
	"""Retorna true si el selector de facing está visible"""
	return facing_selector and facing_selector.visible

func _on_facing_selected(facing: int):
	"""Maneja la selección de una orientación"""
	# Evitar que el release del click del botón pase al mapa (causando selección de hex accidental)
	if battle_scene:
		# Indica al battle_scene que ignore el siguiente click de mouse/touch.
		# Preferimos usar un temporizador en la escena (debounce) si existe.
		if battle_scene.has_method("start_ignore_click_timer"):
			# 200 ms debounce por defecto
			battle_scene.start_ignore_click_timer(200)
		else:
			battle_scene.ignore_next_click = true
	# Ocultar selector (se hace inmediatamente para feedback)
	hide_facing_selector()
	
	# Pequeño delay para evitar clics accidentales
	await get_tree().create_timer(0.1).timeout
	
	if battle_scene and battle_scene.has_method("on_facing_selected"):
		battle_scene.on_facing_selected(facing)

## ATAQUES FÍSICOS ##

func show_physical_attack_options(attacker, target):
	# Mostrar opciones de ataque físico
	if not physical_attack_panel:
		return
	
	# Almacenar información del ataque
	physical_attack_panel.set_meta("attacker", attacker)
	physical_attack_panel.set_meta("target", target)
	
	# Precargar PhysicalAttackSystem
	const physical_attack_sys = preload("res://scripts/core/combat/physical_attack_system.gd")
	
	# Verificar qué ataques están disponibles
	var can_punch_left = physical_attack_sys.can_punch(attacker, "left")
	var can_punch_right = physical_attack_sys.can_punch(attacker, "right")
	var can_kick = physical_attack_sys.can_kick(attacker)
	var can_charge = physical_attack_sys.can_charge(attacker)
	
	# Habilitar/deshabilitar botones según disponibilidad
	punch_left_button.disabled = not can_punch_left["can_punch"]
	if not can_punch_left["can_punch"]:
		punch_left_button.text = "PUNCH (Left) - %s" % can_punch_left["reason"]
	else:
		var damage = physical_attack_sys.calculate_punch_damage(attacker.tonnage)
		punch_left_button.text = "PUNCH (Left Arm) - Dmg: %d" % damage
	
	punch_right_button.disabled = not can_punch_right["can_punch"]
	if not can_punch_right["can_punch"]:
		punch_right_button.text = "PUNCH (Right) - %s" % can_punch_right["reason"]
	else:
		var damage = physical_attack_sys.calculate_punch_damage(attacker.tonnage)
		punch_right_button.text = "PUNCH (Right Arm) - Dmg: %d" % damage
	
	kick_button.disabled = not can_kick["can_kick"]
	if not can_kick["can_kick"]:
		kick_button.text = "KICK - %s" % can_kick["reason"]
	else:
		var damage = physical_attack_sys.calculate_kick_damage(attacker.tonnage)
		kick_button.text = "KICK - Dmg: %d (Risk: Fall)" % damage
	
	charge_button.disabled = not can_charge["can_charge"]
	if not can_charge["can_charge"]:
		charge_button.text = "CHARGE - %s" % can_charge["reason"]
	else:
		var hexes = attacker.hexes_moved_this_turn if "hexes_moved_this_turn" in attacker else 0
		var damage = physical_attack_sys.calculate_charge_damage(attacker.tonnage, hexes)
		charge_button.text = "CHARGE - Dmg: %d (Self: %d)" % [damage, int(damage / 10.0)]
	
	# Mostrar panel
	physical_attack_panel.visible = true
	# Mensaje ya mostrado al activar la fase, no repetir aquí

func hide_physical_attack_options():
	# Ocultar opciones de ataque físico
	if physical_attack_panel:
		physical_attack_panel.visible = false
	
	# Notificar al battle_scene para evitar clicks fantasma
	if battle_scene and battle_scene.has_method("notify_ui_interaction"):
		battle_scene.notify_ui_interaction()

func _on_punch_left_pressed():
	if not physical_attack_panel:
		return
	var attacker = physical_attack_panel.get_meta("attacker")
	var target = physical_attack_panel.get_meta("target")
	if battle_scene and battle_scene.has_method("execute_physical_attack"):
		battle_scene.execute_physical_attack(attacker, target, "punch_left")
	hide_physical_attack_options()

func _on_punch_right_pressed():
	if not physical_attack_panel:
		return
	var attacker = physical_attack_panel.get_meta("attacker")
	var target = physical_attack_panel.get_meta("target")
	if battle_scene and battle_scene.has_method("execute_physical_attack"):
		battle_scene.execute_physical_attack(attacker, target, "punch_right")
	hide_physical_attack_options()

func _on_kick_pressed():
	if not physical_attack_panel:
		return
	var attacker = physical_attack_panel.get_meta("attacker")
	var target = physical_attack_panel.get_meta("target")
	if battle_scene and battle_scene.has_method("execute_physical_attack"):
		battle_scene.execute_physical_attack(attacker, target, "kick")
	hide_physical_attack_options()

func _on_charge_pressed():
	if not physical_attack_panel:
		return
	var attacker = physical_attack_panel.get_meta("attacker")
	var target = physical_attack_panel.get_meta("target")
	if battle_scene and battle_scene.has_method("execute_physical_attack"):
		battle_scene.execute_physical_attack(attacker, target, "charge")
	hide_physical_attack_options()

func _on_cancel_physical_pressed():
	hide_physical_attack_options()
	add_combat_message("Physical attack cancelled", Color.GRAY)

## SELECTOR DE ARMAS ##

func show_weapon_selector(attacker, target, range_hexes: int):
	# Mostrar selector de armas con información del objetivo
	if not weapon_selector_panel or not attacker:
		return
	
	# Actualizar título con nombre del mech atacante y objetivo
	if weapon_selector_title:
		weapon_selector_title.text = "%s attacking %s - SELECT WEAPONS" % [attacker.mech_name, target.mech_name]
	
	# Limpiar botones de armas anteriores y sus contenedores
	for btn in weapon_buttons:
		if btn and is_instance_valid(btn):
			# Si el botón está dentro de un HBoxContainer, eliminar el contenedor completo
			var parent = btn.get_parent()
			if parent and parent is HBoxContainer:
				parent.queue_free()
			else:
				btn.queue_free()
	weapon_buttons.clear()
	selected_weapons.clear()
	
	# Almacenar información del ataque actual
	weapon_selector_panel.set_meta("attacker", attacker)
	weapon_selector_panel.set_meta("target", target)
	weapon_selector_panel.set_meta("range", range_hexes)
	
	# Debug: verificar qué mech y cuántas armas tiene
	# print("[DEBUG] show_weapon_selector - Attacker: %s, Weapons count: %d" % [attacker.mech_name, attacker.weapons.size()])
	
	# Crear filas para cada arma con label clickeable + switch separados
	var y_pos = 50
	var weapon_index = 0
	
	for weapon in attacker.weapons:
		# print("[DEBUG] Processing weapon: %s" % weapon.get("name", "Unknown"))
		# Calcular modificadores de impacto para esta arma
		var weapon_attack_sys = preload("res://scripts/core/combat/weapon_attack_system.gd")
		var to_hit_data = weapon_attack_sys.calculate_to_hit(attacker, target, weapon, range_hexes)
		var target_number = to_hit_data["target_number"]
		var breakdown = to_hit_data.get("breakdown", "")
		
		# Texto compacto para el arma
		var weapon_info = "%s (Dmg:%d Heat:%d)  To-Hit: %d" % [
			weapon.get("name", "Unknown"),
			weapon.get("damage", 0),
			weapon.get("heat", 0),
			target_number
		]
		
		# Verificar si está en rango
		var in_range = _is_weapon_in_range(weapon, range_hexes)
		if not in_range:
			weapon_info += "  [OUT OF RANGE]"
		
		# Contenedor horizontal para label + switch
		var hbox = HBoxContainer.new()
		hbox.position = Vector2(20, y_pos)
		hbox.size = Vector2(480, 40)
		hbox.mouse_filter = Control.MOUSE_FILTER_STOP  # Bloquear eventos
		weapon_selector_panel.add_child(hbox)
		
		# Label clickeable para mostrar info (toma la mayor parte del espacio)
		var weapon_label = Label.new()
		weapon_label.text = weapon_info
		weapon_label.add_theme_font_size_override("font_size", 14)
		weapon_label.custom_minimum_size = Vector2(420, 40)
		weapon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		weapon_label.mouse_filter = Control.MOUSE_FILTER_STOP  # Capturar eventos
		weapon_label.set_meta("weapon_index", weapon_index)
		weapon_label.set_meta("weapon_data", weapon)
		weapon_label.set_meta("breakdown", breakdown)
		weapon_label.set_meta("to_hit_data", to_hit_data)
		
		# Tooltip con el desglose completo
		weapon_label.tooltip_text = breakdown
		
		# Hacer el label clickeable con gui_input
		weapon_label.gui_input.connect(_on_weapon_label_clicked.bind(weapon_index, weapon, breakdown, to_hit_data))
		hbox.add_child(weapon_label)
		
		# Switch personalizado estilo BattleTech
		var weapon_switch = _create_battletech_switch(weapon_index, in_range)
		weapon_switch.set_meta("weapon_index", weapon_index)
		hbox.add_child(weapon_switch)
		
		weapon_buttons.append(weapon_switch)
		y_pos += 45
		weapon_index += 1
	
	# Mostrar panel
	weapon_selector_panel.visible = true

func _on_weapon_panel_input(event: InputEvent):
	"""Consume todos los eventos de input en el panel de armas para evitar propagación"""
	# Marcar cualquier evento de mouse/touch como manejado
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()

func hide_weapon_selector():
	if weapon_selector_panel:
		weapon_selector_panel.visible = false
		selected_weapons.clear()
	if weapon_info_panel:
		weapon_info_panel.visible = false
	
	# Notificar al battle_scene para evitar clicks fantasma
	if battle_scene and battle_scene.has_method("notify_ui_interaction"):
		battle_scene.notify_ui_interaction()

func _on_weapon_label_clicked(event: InputEvent, weapon_index: int, weapon: Dictionary, breakdown: String, to_hit_data: Dictionary):
	# Mostrar info solo cuando se hace clic en el label (no en el checkbox)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Marcar evento como manejado para evitar propagación
		get_viewport().set_input_as_handled()
		_on_weapon_clicked(weapon_index, weapon, breakdown, to_hit_data)

func _on_weapon_clicked(_weapon_index: int, weapon: Dictionary, breakdown: String, to_hit_data: Dictionary):
	# Mostrar información detallada del arma en el panel de información
	if not weapon_info_panel or not weapon_info_label:
		return
	
	weapon_info_panel.visible = true
	
	# Construir información detallada con BBCode modernizado en dos columnas
	var info_text = ""
	
	# Nombre del arma con icono según tipo
	var weapon_icon = _get_weapon_type_icon(weapon.get("type", "energy"))
	info_text += "[center][font_size=20][b][color=#50D0FF]%s %s[/color][/b][/font_size][/center]\n" % [weapon_icon, weapon.get("name", "Unknown Weapon")]
	info_text += "[center][color=#406080]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color][/center]\n"
	
	# Tipo de arma
	var weapon_type = weapon.get("type", "energy")
	var weapon_type_str = _get_weapon_type_name(weapon_type)
	var type_color = _get_weapon_type_color(weapon_type)
	info_text += "[center][color=%s]▸ %s WEAPON ◂[/color][/center]\n\n" % [type_color, weapon_type_str.to_upper()]
	
	# Usar tabla para organizar en dos columnas
	info_text += "[table=2]\n"
	
	# COLUMNA IZQUIERDA: Combat Specs
	info_text += "[cell]"
	info_text += "[color=#FFC040]┏━ COMBAT SPECS ━━━━━━━┓[/color]\n"
	info_text += "[color=#909090]┃[/color] Damage Output\n"
	info_text += "[color=#909090]┃[/color]   [color=#FF4040][b]%d[/b][/color] points\n" % weapon.get("damage", 0)
	info_text += "[color=#909090]┃[/color]\n"
	info_text += "[color=#909090]┃[/color] Heat Generated\n"
	info_text += "[color=#909090]┃[/color]   [color=#FF9030][b]%d[/b][/color] heat\n" % weapon.get("heat", 0)
	
	# Información de munición si requiere
	if weapon.get("requires_ammo", false):
		var ammo = weapon.get("ammo", 0)
		var ammo_color = "#40FF40" if ammo > 5 else ("#FFFF40" if ammo > 2 else "#FF4040")
		info_text += "[color=#909090]┃[/color]\n"
		info_text += "[color=#909090]┃[/color] Ammunition\n"
		info_text += "[color=#909090]┃[/color]   [color=%s][b]%d[/b] rounds[/color]\n" % [ammo_color, ammo]
	
	info_text += "[color=#FFC040]┗━━━━━━━━━━━━━━━━━━━━━━┛[/color]"
	info_text += "[/cell]\n"
	
	# COLUMNA DERECHA: Range Profile
	info_text += "[cell]"
	info_text += "[color=#40C0FF]┏━ RANGE PROFILE ━━━━━┓[/color]\n"
	var min_range = weapon.get("min_range", 0)
	var short_range = weapon.get("short_range", 3)
	var medium_range = weapon.get("medium_range", 6)
	var long_range = weapon.get("long_range", 9)
	
	if min_range > 0:
		info_text += "[color=#909090]┃[/color] Dead Zone\n"
		info_text += "[color=#909090]┃[/color]   [color=#FF4040][b]< %d[/b][/color] hexes\n" % min_range
		info_text += "[color=#909090]┃[/color]\n"
	
	info_text += "[color=#909090]┃[/color] Short Range\n"
	info_text += "[color=#909090]┃[/color]   [color=#40FF40][b]%d[/b][/color] hexes [color=#60A060](+0)[/color]\n" % short_range
	info_text += "[color=#909090]┃[/color]\n"
	info_text += "[color=#909090]┃[/color] Medium Range\n"
	info_text += "[color=#909090]┃[/color]   [color=#FFFF40][b]%d[/b][/color] hexes [color=#A0A040](+2)[/color]\n" % medium_range
	info_text += "[color=#909090]┃[/color]\n"
	info_text += "[color=#909090]┃[/color] Long Range\n"
	info_text += "[color=#909090]┃[/color]   [color=#FFA040][b]%d[/b][/color] hexes [color=#A06040](+4)[/color]\n" % long_range
	info_text += "[color=#40C0FF]┗━━━━━━━━━━━━━━━━━━━━━┛[/color]"
	info_text += "[/cell]\n"
	
	info_text += "[/table]\n"
	
	# TO-HIT ANALYSIS - Ancho completo debajo (sin espacio extra)
	info_text += "[color=#FF80FF]┏━ TO-HIT ANALYSIS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓[/color]\n"
	
	# Parse del breakdown para mejor formato
	var breakdown_lines = breakdown.split("\n")
	for line in breakdown_lines:
		if line.strip_edges() != "":
			# Detectar número target
			if "Target Number" in line or "Final" in line:
				info_text += "[color=#909090]┃[/color] [color=#FFD040][b]%s[/b][/color]\n" % line.strip_edges()
			else:
				info_text += "[color=#909090]┃[/color] [color=#D0D0D0]%s[/color]\n" % line.strip_edges()
	
	# Modifiers individuales con mejor formato
	var modifiers = to_hit_data.get("modifiers", {})
	if modifiers.size() > 0:
		info_text += "[color=#909090]┃[/color]\n"
		info_text += "[color=#909090]┃[/color] [color=#C0C0FF][b]Modifier Breakdown:[/b][/color]\n"
		
		# Organizar modificadores en dos columnas si hay muchos
		var mod_keys = modifiers.keys()
		if mod_keys.size() > 6:
			# Dos columnas para muchos modificadores
			var half = ceili(mod_keys.size() / 2.0)
			for i in range(half):
				var left_key = mod_keys[i]
				var left_val = modifiers[left_key]
				var left_color = "#40FF80" if left_val <= 0 else "#FF6060"
				var left_name = str(left_key).replace("_", " ").capitalize()
				
				var line_text = "[color=#909090]┃[/color]  • %-20s [color=%s]%+d[/color]" % [left_name, left_color, left_val]
				
				# Añadir segunda columna si existe
				var right_idx = i + half
				if right_idx < mod_keys.size():
					var right_key = mod_keys[right_idx]
					var right_val = modifiers[right_key]
					var right_color = "#40FF80" if right_val <= 0 else "#FF6060"
					var right_name = str(right_key).replace("_", " ").capitalize()
					line_text += "  • %s [color=%s]%+d[/color]" % [right_name, right_color, right_val]
				
				info_text += line_text + "\n"
		else:
			# Una columna para pocos modificadores
			for mod_name in mod_keys:
				var mod_val = modifiers[mod_name]
				var color = "#40FF80" if mod_val <= 0 else "#FF6060"
				var formatted_name = str(mod_name).replace("_", " ").capitalize()
				info_text += "[color=#909090]┃[/color]  • %s [color=%s]%+d[/color]\n" % [formatted_name, color, mod_val]
	
	info_text += "[color=#FF80FF]┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛[/color]\n"
	
	weapon_info_label.text = info_text

func _get_weapon_type_icon(weapon_type) -> String:
	"""Retorna un icono según el tipo de arma"""
	if typeof(weapon_type) == TYPE_INT:
		match weapon_type:
			1: return "⚡"  # Energy
			2: return "●"  # Ballistic
			3: return "▲"  # Missile
			_: return "◆"
	else:
		match str(weapon_type).to_lower():
			"energy": return "⚡"
			"ballistic": return "●"
			"missile": return "▲"
			_: return "◆"

func _get_weapon_type_name(weapon_type) -> String:
	"""Retorna el nombre del tipo de arma"""
	if typeof(weapon_type) == TYPE_INT:
		match weapon_type:
			1: return "ENERGY"
			2: return "BALLISTIC"
			3: return "MISSILE"
			_: return "UNKNOWN"
	else:
		return str(weapon_type).to_upper()

func _get_weapon_type_color(weapon_type) -> String:
	"""Retorna el color del tipo de arma"""
	if typeof(weapon_type) == TYPE_INT:
		match weapon_type:
			1: return "#40D0FF"  # Cian para Energy
			2: return "#FFD040"  # Amarillo para Ballistic
			3: return "#FF6060"  # Rojo para Missile
			_: return "#C0C0C0"
	else:
		match str(weapon_type).to_lower():
			"energy": return "#40D0FF"
			"ballistic": return "#FFD040"
			"missile": return "#FF6060"
			_: return "#C0C0C0"

func _is_weapon_in_range(weapon: Dictionary, range_hexes: int) -> bool:
	# Verifica si el arma puede disparar a esta distancia
	var long_range = weapon.get("long_range", 9)
	var min_range = weapon.get("min_range", 0)
	
	return range_hexes >= min_range and range_hexes <= long_range

func _create_battletech_switch(weapon_index: int, enabled: bool) -> Control:
	"""Crea un switch personalizado estilo BattleTech con toggle animado"""
	var switch_container = Control.new()
	switch_container.custom_minimum_size = Vector2(60, 40)
	switch_container.mouse_filter = Control.MOUSE_FILTER_STOP
	switch_container.set_meta("toggled", false)
	switch_container.set_meta("enabled", enabled)
	
	# Panel de fondo del switch (rectángulo redondeado)
	var bg_panel = Panel.new()
	bg_panel.position = Vector2(10, 10)
	bg_panel.size = Vector2(40, 20)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Estilo del fondo (OFF por defecto)
	var bg_style = StyleBoxFlat.new()
	if enabled:
		bg_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)  # Gris oscuro
	else:
		bg_style.bg_color = Color(0.15, 0.15, 0.15, 0.5)  # Gris muy oscuro deshabilitado
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.3, 0.5, 0.7, 0.9) if enabled else Color(0.2, 0.2, 0.2, 0.5)
	bg_style.corner_radius_top_left = 10
	bg_style.corner_radius_top_right = 10
	bg_style.corner_radius_bottom_left = 10
	bg_style.corner_radius_bottom_right = 10
	bg_style.anti_aliasing = true
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	bg_panel.set_meta("style", bg_style)  # Guardar referencia para modificar después
	switch_container.add_child(bg_panel)
	
	# Botón deslizante (círculo)
	var slider = Panel.new()
	slider.position = Vector2(12, 12)  # Posición izquierda (OFF)
	slider.size = Vector2(16, 16)
	slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Estilo del slider
	var slider_style = StyleBoxFlat.new()
	if enabled:
		slider_style.bg_color = Color(0.6, 0.6, 0.7, 1)  # Gris claro
	else:
		slider_style.bg_color = Color(0.4, 0.4, 0.4, 0.6)  # Gris apagado
	slider_style.corner_radius_top_left = 8
	slider_style.corner_radius_top_right = 8
	slider_style.corner_radius_bottom_left = 8
	slider_style.corner_radius_bottom_right = 8
	slider_style.anti_aliasing = true
	if enabled:
		slider_style.shadow_color = Color(0.3, 0.5, 0.7, 0.5)
		slider_style.shadow_size = 3
		slider_style.shadow_offset = Vector2(0, 1)
	slider.add_theme_stylebox_override("panel", slider_style)
	slider.set_meta("style", slider_style)
	switch_container.add_child(slider)
	
	# Guardar referencias
	switch_container.set_meta("bg_panel", bg_panel)
	switch_container.set_meta("slider", slider)
	
	# Conectar evento de clic
	if enabled:
		switch_container.gui_input.connect(_on_switch_clicked.bind(switch_container, weapon_index))
	
	return switch_container

func _on_switch_clicked(event: InputEvent, switch_control: Control, weapon_index: int):
	"""Maneja el clic en el switch personalizado"""
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	# Marcar evento como manejado para evitar propagación al battle_scene
	switch_control.get_viewport().set_input_as_handled()
	
	var enabled = switch_control.get_meta("enabled")
	if not enabled:
		return
	
	# Toggle del estado
	var is_toggled = switch_control.get_meta("toggled")
	is_toggled = !is_toggled
	switch_control.set_meta("toggled", is_toggled)
	
	# Actualizar visualmente
	var bg_panel = switch_control.get_meta("bg_panel")
	var slider = switch_control.get_meta("slider")
	var bg_style = bg_panel.get_meta("style")
	var slider_style = slider.get_meta("style")
	
	if is_toggled:
		# Estado ON - Verde cian brillante
		bg_style.bg_color = Color(0.1, 0.4, 0.5, 0.9)  # Azul verdoso
		bg_style.border_color = Color(0.3, 0.7, 1, 1)  # Cian brillante
		slider_style.bg_color = Color(0.5, 0.9, 1, 1)  # Cian muy brillante
		slider_style.shadow_color = Color(0.5, 0.9, 1, 0.8)
		slider_style.shadow_size = 5
		slider.position.x = 32  # Posición derecha
	else:
		# Estado OFF - Gris
		bg_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
		bg_style.border_color = Color(0.3, 0.5, 0.7, 0.9)
		slider_style.bg_color = Color(0.6, 0.6, 0.7, 1)
		slider_style.shadow_color = Color(0.3, 0.5, 0.7, 0.5)
		slider_style.shadow_size = 3
		slider.position.x = 12  # Posición izquierda
	
	# Forzar redibujado
	bg_panel.queue_redraw()
	slider.queue_redraw()
	
	# Llamar al manejador de toggle
	_on_weapon_toggled(is_toggled, weapon_index)

func _on_weapon_toggled(button_pressed: bool, weapon_index: int):
	# Marcar/desmarcar arma para disparar
	if button_pressed:
		if weapon_index not in selected_weapons:
			selected_weapons.append(weapon_index)
	else:
		selected_weapons.erase(weapon_index)
	
	# Actualizar botón de disparo
	fire_button.disabled = (selected_weapons.size() == 0)

func _on_fire_weapons_pressed():
	# Confirmar disparo con armas seleccionadas
	if not weapon_selector_panel:
		return
	
	var attacker = weapon_selector_panel.get_meta("attacker")
	var target = weapon_selector_panel.get_meta("target")
	var range_hexes = weapon_selector_panel.get_meta("range")
	
	if battle_scene and battle_scene.has_method("execute_weapon_attack"):
		battle_scene.execute_weapon_attack(attacker, target, selected_weapons, range_hexes)
	
	hide_weapon_selector()

func _on_cancel_weapons_pressed():
	# Cancelar selección de armas
	hide_weapon_selector()
	add_combat_message("Weapon attack cancelled", Color.GRAY)

func _on_close_weapon_info_pressed():
	# Cerrar panel de información del arma
	if weapon_info_panel:
		weapon_info_panel.visible = false

func show_game_over(winner_name: String, loser_name: String, loser_death_reason: String):
	if game_over_visible:
		return
	
	game_over_visible = true
	
	# Obtener tamaño de la pantalla
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y
	
	# Crear panel de game over (75% del ancho, 60% de la altura, centrado)
	var panel_width = screen_width * 0.75
	var panel_height = screen_height * 0.6
	game_over_panel = Panel.new()
	game_over_panel.position = Vector2((screen_width - panel_width) / 2, (screen_height - panel_height) / 2)
	game_over_panel.size = Vector2(panel_width, panel_height)
	
	# Estilo del panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_color = Color.GOLD
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	game_over_panel.add_theme_stylebox_override("panel", style)
	add_child(game_over_panel)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(margin * 2, margin * 2)
	vbox.size = Vector2(panel_width - margin * 4, panel_height - margin * 4)
	vbox.add_theme_constant_override("separation", int(20 * scale_factor))
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER  # Centrar verticalmente
	game_over_panel.add_child(vbox)
	
	# Título "BATTLE ENDED"
	var title = Label.new()
	title.text = "⚔ BATTLE ENDED ⚔"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(40 * scale_factor))
	title.add_theme_color_override("font_color", Color.GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Prevenir overflow
	title.clip_text = true  # Cortar texto si es muy largo
	title.custom_minimum_size = Vector2(panel_width - margin * 4, 0)  # Asegurar ancho
	vbox.add_child(title)
	
	# Espaciador
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20 * scale_factor)
	vbox.add_child(spacer1)
	
	# Mensaje del ganador
	var winner_label = Label.new()
	winner_label.text = "🏆 VICTOR: %s 🏆" % winner_name.to_upper()
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", int(32 * scale_factor))
	winner_label.add_theme_color_override("font_color", Color.GREEN)
	winner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Prevenir overflow
	winner_label.clip_text = true  # Cortar texto si es muy largo
	winner_label.custom_minimum_size = Vector2(panel_width - margin * 4, 0)  # Asegurar ancho
	vbox.add_child(winner_label)
	
	# Espaciador
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30 * scale_factor)
	vbox.add_child(spacer2)
	
	# Mensaje de cómo murió el perdedor
	var death_label = RichTextLabel.new()
	death_label.bbcode_enabled = true
	death_label.fit_content = true
	death_label.scroll_active = false
	death_label.custom_minimum_size = Vector2(panel_width - margin * 8, 100 * scale_factor)
	
	var death_text = "[center][color=RED]☠ %s ☠[/color]\n\n[color=ORANGE]%s[/color][/center]" % [loser_name.to_upper(), loser_death_reason]
	death_label.text = death_text
	death_label.add_theme_font_size_override("normal_font_size", int(24 * scale_factor))
	vbox.add_child(death_label)
	
	# Espaciador
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 30 * scale_factor)
	vbox.add_child(spacer3)
	
	# Botón para volver al menú principal
	var menu_button = Button.new()
	menu_button.text = "RETURN TO MAIN MENU"
	menu_button.custom_minimum_size = Vector2(panel_width * 0.6, 80 * scale_factor)
	menu_button.add_theme_font_size_override("font_size", int(28 * scale_factor))
	menu_button.pressed.connect(_on_return_to_menu_pressed)
	
	# Centrar el botón en el HBoxContainer
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_child(menu_button)
	vbox.add_child(button_container)

func _on_return_to_menu_pressed():
	# Volver al menú principal
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func show_mech_inspector(mech):
	if mech_inspector_visible:
		hide_mech_inspector()
		return
	
	mech_inspector_visible = true
	
	# Obtener tamaño de la pantalla
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y
	
	# Crear panel de inspección (50% del ancho, 35% de la altura, centrado)
	var panel_width = screen_width * 0.5
	var panel_height = screen_height * 0.35
	mech_inspector_panel = Panel.new()
	mech_inspector_panel.position = Vector2((screen_width - panel_width) / 2, (screen_height - panel_height) / 2)
	mech_inspector_panel.size = Vector2(panel_width, panel_height)
	
	# Estilo del panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color.CYAN
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	mech_inspector_panel.add_theme_stylebox_override("panel", style)
	add_child(mech_inspector_panel)
	
	# Layout vertical centrado
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(margin, margin)
	vbox.size = Vector2(panel_width - margin * 2, panel_height - margin * 2)
	vbox.add_theme_constant_override("separation", int(5 * scale_factor))
	mech_inspector_panel.add_child(vbox)
	
	# Título con nombre del mech
	var title = Label.new()
	title.text = mech.mech_name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(20 * scale_factor))
	title.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(title)
	
	# Información básica en una línea
	var info_label = Label.new()
	var status = "DESTROYED" if mech.is_destroyed else "OPERATIONAL"
	var status_color = Color.RED if mech.is_destroyed else Color.GREEN
	
	info_label.text = "%s | %d tons | Heat: %d/%d | Pilot: %d" % [status, mech.tonnage, mech.heat, mech.heat_capacity, mech.pilot_skill]
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", int(14 * scale_factor))
	info_label.add_theme_color_override("font_color", status_color)
	vbox.add_child(info_label)
	
	# Espaciador para bajar el gráfico (responsive - 20% de la altura del panel)
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, panel_height * 0.2)
	vbox.add_child(spacer)
	
	# Panel de armadura gráfico (más pequeño)
	var CustomArmorPanel = load("res://scripts/ui/custom_armor_panel.gd")
	mech_inspector_armor = CustomArmorPanel.new()
	mech_inspector_armor.custom_minimum_size = Vector2(panel_width * 0.5, panel_height * 0.5)
	mech_inspector_armor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mech_inspector_armor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mech_inspector_armor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mech_inspector_armor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Preparar datos de armadura para el panel
	var armor_data = {}
	for location in mech.armor.keys():
		armor_data[location] = mech.armor[location].duplicate()
		# Solo agregar datos de estructura si la localización existe en structure
		if mech.structure.has(location):
			armor_data[location + "_structure"] = mech.structure[location]["current"]
			armor_data[location + "_structure_max"] = mech.structure[location]["max"]
		else:
			# Valores por defecto si no existe
			armor_data[location + "_structure"] = 0
			armor_data[location + "_structure_max"] = 1
	
	mech_inspector_armor.set_armor(armor_data)
	vbox.add_child(mech_inspector_armor)
	
	# Botón de cerrar al final, centrado
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_container)
	
	var close_button = Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(panel_width * 0.3, 40 * scale_factor)
	close_button.add_theme_font_size_override("font_size", int(16 * scale_factor))
	close_button.pressed.connect(_on_close_inspector_pressed)
	button_container.add_child(close_button)

func show_mech_paper_doll_dialog(mech):
	"""Open the full paper-doll scene in a centered WindowDialog (modal).
	This does not change the currently selected unit in the battle scene.
	"""
	print("[UI] show_mech_paper_doll_dialog called for mech=", mech)
	if not mech:
		print("[UI] show_mech_paper_doll_dialog called with null mech")
		return
	# Ensure the paper_doll scene exists
	if not ResourceLoader.exists("res://scenes/mech_paper_doll.tscn"):
		print("[UI] Paper doll scene not found")
		return

	var paper_scene = load("res://scenes/mech_paper_doll.tscn")
	if not paper_scene:
		print("[UI] Failed to load mech_paper_doll.tscn")
		return

	# Create a simple custom modal overlay so we control layout and sizing across
	# all targets (mobile/desktop). We'll build a ColorRect full-screen overlay
	# plus a centered Panel that contains the paper doll and a close button.
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.anchor_left = 0
	overlay.anchor_top = 0
	overlay.anchor_right = 1
	overlay.anchor_bottom = 1

	var panel = Panel.new()
	panel.name = "PaperDollModal"
	panel.add_theme_font_size_override("font_size", 16)

	# Use a CenterContainer inside the overlay to avoid setting position/size manually
	var center = CenterContainer.new()
	center.anchor_left = 0
	center.anchor_top = 0
	center.anchor_right = 1
	center.anchor_bottom = 1

	var viewport_size = get_viewport().get_visible_rect().size
	# Make the dialog noticeably smaller and well centered for both mobile and desktop.
	# Use a smaller fraction of the viewport so it doesn't dominate the screen.
	# Prefer a dialog only slightly larger than the internal MechPaperDoll
	# Use the paper doll's base size (or a sensible fallback) and add padding
	# Instantiate paper doll early so we can read its minimum size and layout
	var paper = paper_scene.instantiate()
	var paper_min_size = Vector2(120, 170)
	if paper and paper.has_method("get_minimum_size"):
		# prefer an explicit custom_minimum_size if it exists on the control
		if paper.custom_minimum_size and paper.custom_minimum_size != Vector2.ZERO:
			paper_min_size = paper.custom_minimum_size
		else:
			paper_min_size = paper.get_minimum_size()

	# Add small padding so the dialog frames the paper doll + header comfortably
	var target_width = paper_min_size.x + 48
	var target_height = paper_min_size.y + 72  # header + compact padding

	# Clamp so very small/very large screens still look acceptable
	var panel_width = clamp(target_width, 220, min(viewport_size.x - 40, 600))
	var panel_height = clamp(target_height, 180, min(viewport_size.y - 40, 420))
	var panel_size = Vector2(panel_width, panel_height)
	panel.custom_minimum_size = panel_size

	# Instantiate paper doll and add (add it to panel before calling update_from_mech so onready refs initialize)
	# Expand the paper doll to fit the dialog - we'll set position/size later
	# Add panel sizing is computed above in panel_pos/panel_size

	# Ensure paper fills the content area properly - compute inside the panel

	# Header + close — sized to match the smaller dialog
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(panel_size.x, 30)
	var title = Label.new()
	title.text = mech.mech_name if "mech_name" in mech else "Mech"
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_btn = Button.new()
	close_btn.text = "✕"
	# Small close button with BattleTech theme applied
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.add_theme_font_size_override("font_size", int(14 * scale_factor))
	close_btn.theme = battletech_theme
	close_btn.pressed.connect(Callable(overlay, "queue_free"))
	close_btn.pressed.connect(Callable(panel, "queue_free"))
	header.add_child(close_btn)

	panel.add_child(header)

	# Place paper inside the panel: leave a small border and space for header
	# Leave a small border and space for header — scaled down for smaller dialog
	# Center horizontally the inner content in the panel when paper is narrower
	var inner_size = Vector2(max(panel_size.x - 16, paper_min_size.x), max(panel_size.y - header.custom_minimum_size.y - 12, paper_min_size.y))
	var inner_pos_x = max(8, (panel_size.x - inner_size.x) / 2)
	var inner_pos = Vector2(inner_pos_x, header.custom_minimum_size.y + 6)
	# Control in Godot 4 uses `position`/`size` instead of `rect_position`/`rect_size`.
	paper.position = inner_pos
	paper.size = inner_size
	panel.add_child(paper)

	# Apply BattleTech visual style to the modal panel so it fits the rest of the UI
	var paper_style = StyleBoxFlat.new()
	paper_style.bg_color = Color(0.06, 0.09, 0.13, 0.95)
	paper_style.border_width_left = 3
	paper_style.border_width_top = 2
	paper_style.border_width_right = 3
	paper_style.border_width_bottom = 3
	paper_style.border_color = Color(0.2, 0.55, 0.85, 0.95)
	paper_style.corner_radius_top_left = 10
	paper_style.corner_radius_top_right = 10
	paper_style.corner_radius_bottom_right = 10
	paper_style.corner_radius_bottom_left = 10
	paper_style.shadow_color = Color(0.15, 0.35, 0.55, 0.5)
	paper_style.shadow_size = 8
	paper_style.shadow_offset = Vector2(0, 3)
	paper.add_theme_stylebox_override("panel", paper_style)
	panel.add_theme_stylebox_override("panel", paper_style)
	# Use the project's Battletech theme so controls (fonts, buttons) match the rest of the UI
	panel.theme = battletech_theme

	# Style the title to match the BattleTech look
	title.add_theme_font_size_override("font_size", int(14 * scale_factor))
	title.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.18, 1))
	title.add_theme_constant_override("outline_size", 2)

	# Now it's safe to update the paper doll with the mech data (onready nodes now exist)
	if paper and paper.has_method("update_from_mech"):
		paper.update_from_mech(mech)

	# Add overlay and center->panel so panel is centered and sized by the center container
	add_child(overlay)
	overlay.add_child(center)
	center.add_child(panel)
	print("[UI] paper doll modal shown for", mech.mech_name)

func hide_mech_inspector():
	if mech_inspector_panel:
		mech_inspector_panel.queue_free()
		mech_inspector_panel = null
		mech_inspector_armor = null
	mech_inspector_visible = false

func _on_close_inspector_pressed():
	hide_mech_inspector()

## Panel de confirmación genérico
func show_confirmation_dialog(title: String, message: String, on_confirm: Callable, on_cancel: Callable = Callable()):
	"""Muestra un diálogo de confirmación genérico"""
	print("[UI] Showing confirmation dialog: %s" % title)
	if not confirmation_panel:
		print("[UI] ERROR: confirmation_panel is null!")
		return
	
	confirmation_title.text = title
	confirmation_message.text = message
	on_confirm_callback = on_confirm
	on_cancel_callback = on_cancel
	
	print("[UI] Callbacks set - confirm valid: %s, cancel valid: %s" % [on_confirm.is_valid(), on_cancel.is_valid()])
	
	confirmation_panel.visible = true
	confirmation_visible = true

func hide_confirmation_dialog():
	"""Oculta el diálogo de confirmación"""
	if confirmation_panel:
		confirmation_panel.visible = false
	confirmation_visible = false
	on_confirm_callback = Callable()
	on_cancel_callback = Callable()

func _on_confirmation_confirm():
	"""Botón de confirmación presionado"""
	print("[UI] Confirmation CONFIRM pressed")
	# Establecer cooldown en battle_scene para evitar que el clic se propague al hex
	if battle_scene:
		battle_scene.ui_interaction_cooldown = 0.3
		# Usar el temporizador para resetear automáticamente
		if battle_scene.has_method("start_ignore_click_timer"):
			battle_scene.start_ignore_click_timer(300)
		else:
			battle_scene.ignore_next_click = true
	get_viewport().set_input_as_handled()
	var callback = on_confirm_callback  # Guardar antes de limpiar
	hide_confirmation_dialog()
	if callback and callback.is_valid():
		print("[UI] Calling confirm callback")
		callback.call()
	else:
		print("[UI] No valid confirm callback")

func _on_confirmation_cancel():
	"""Botón de cancelación presionado"""
	print("[UI] Confirmation CANCEL pressed")
	# Establecer cooldown en battle_scene para evitar que el clic se propague al hex
	if battle_scene:
		battle_scene.ui_interaction_cooldown = 0.3
		# Usar el temporizador para resetear automáticamente
		if battle_scene.has_method("start_ignore_click_timer"):
			battle_scene.start_ignore_click_timer(300)
		else:
			battle_scene.ignore_next_click = true
	get_viewport().set_input_as_handled()
	var callback = on_cancel_callback  # Guardar antes de limpiar
	hide_confirmation_dialog()
	if callback and callback.is_valid():
		print("[UI] Calling cancel callback")
		callback.call()
	else:
		print("[UI] No valid cancel callback")

## Funciones para ocultar/mostrar UI completo durante iniciativa
func hide_main_ui():
	"""Oculta el UI principal (info superior, botones, combat log) durante la iniciativa"""
	if info_panel:
		info_panel.visible = false
	if end_turn_button:
		end_turn_button.visible = false
	if cancel_movement_button:
		cancel_movement_button.visible = false
	if log_panel:
		log_panel.visible = false

func show_main_ui():
	"""Muestra el UI principal después de la iniciativa"""
	if info_panel:
		info_panel.visible = true
	if end_turn_button:
		end_turn_button.visible = true
	if cancel_movement_button:
		cancel_movement_button.visible = cancel_movement_button.has_meta("should_be_visible") and cancel_movement_button.get_meta("should_be_visible")
	if log_panel:
		log_panel.visible = true

## Funciones adicionales para compatibilidad multiplayer

func update_phase_display(phase) -> void:
	"""Actualiza el display de fase - alias para update_phase_info"""
	var phase_name = ""
	if typeof(phase) == TYPE_INT:
		# Es un enum, convertir a string
		match phase:
			GameEnums.TurnPhase.DEPLOYMENT:
				phase_name = "Deployment"
			GameEnums.TurnPhase.INITIATIVE:
				phase_name = "Initiative"
			GameEnums.TurnPhase.MOVEMENT:
				phase_name = "Movement"
			GameEnums.TurnPhase.WEAPON_ATTACK:
				phase_name = "Weapon Attack"
			GameEnums.TurnPhase.PHYSICAL_ATTACK:
				phase_name = "Physical Attack"
			GameEnums.TurnPhase.HEAT:
				phase_name = "Heat"
			GameEnums.TurnPhase.END:
				phase_name = "End"
			_:
				phase_name = str(phase)
	else:
		phase_name = str(phase)
	update_phase_info(phase_name)

func show_message(message: String, color: Color = Color.WHITE) -> void:
	"""Muestra un mensaje en el combat log"""
	add_combat_message(message, color)

func show_battle_end(won: bool, reason: String) -> void:
	"""Muestra el mensaje de fin de batalla para multiplayer"""
	# Usar el sistema de game over existente
	if won:
		show_game_over("YOU", "OPPONENT", reason)
	else:
		show_game_over("OPPONENT", "YOU", reason)

func enable_controls(enabled: bool) -> void:
	"""Habilita o deshabilita los controles del jugador"""
	if end_turn_button:
		end_turn_button.disabled = not enabled
	# En multiplayer, mostrar indicador visual de turno
	if not enabled:
		set_help_text("Waiting for opponent...")
	else:
		set_help_text("Your turn!")

# ============================================
# EYE BUTTON - SISTEMA DE OVERLAYS
# ============================================

func _create_eye_menu():
	"""Crea el menú desplegable con opciones de overlay (debajo de la box del mech)"""
	var menu_width = 180 * scale_factor
	var menu_height = 240 * scale_factor  # Altura para 5 toggles
	
	# Posicionar debajo de la box del mech (info_panel)
	var menu_x = info_panel.position.x + info_panel.size.x - menu_width
	var menu_y = info_panel.position.y + info_panel.size.y + 5 * scale_factor
	
	eye_menu_panel = Panel.new()
	eye_menu_panel.position = Vector2(menu_x, menu_y)
	eye_menu_panel.size = Vector2(menu_width, menu_height)
	eye_menu_panel.visible = false
	eye_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
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
	eye_menu_panel.add_theme_stylebox_override("panel", menu_style)
	
	# Título
	var title = Label.new()
	title.text = "MAP OVERLAYS"
	title.position = Vector2(10 * scale_factor, 8 * scale_factor)
	title.add_theme_font_size_override("font_size", int(14 * scale_factor))
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	eye_menu_panel.add_child(title)
	
	# Contenedor para los toggles
	var toggle_start_y = 35 * scale_factor
	var toggle_height = 38 * scale_factor
	var toggle_width = menu_width - 20 * scale_factor
	
	# Toggle Elevación
	overlay_elevation_toggle = _create_overlay_toggle(
		"📊 Elevation", 
		Vector2(10 * scale_factor, toggle_start_y),
		Vector2(toggle_width, toggle_height),
		overlay_settings["elevation"],
		"elevation"
	)
	eye_menu_panel.add_child(overlay_elevation_toggle)
	
	# Toggle Coordenadas
	overlay_coords_toggle = _create_overlay_toggle(
		"📍 Coordinates", 
		Vector2(10 * scale_factor, toggle_start_y + toggle_height),
		Vector2(toggle_width, toggle_height),
		overlay_settings["coords"],
		"coords"
	)
	eye_menu_panel.add_child(overlay_coords_toggle)
	
	# Toggle Terreno
	overlay_terrain_toggle = _create_overlay_toggle(
		"🌲 Terrain Type", 
		Vector2(10 * scale_factor, toggle_start_y + toggle_height * 2),
		Vector2(toggle_width, toggle_height),
		overlay_settings["terrain"],
		"terrain"
	)
	eye_menu_panel.add_child(overlay_terrain_toggle)
	
	# Toggle Movimiento
	overlay_movement_toggle = _create_overlay_toggle(
		"🚶 Move Cost", 
		Vector2(10 * scale_factor, toggle_start_y + toggle_height * 3),
		Vector2(toggle_width, toggle_height),
		overlay_settings["movement"],
		"movement"
	)
	eye_menu_panel.add_child(overlay_movement_toggle)
	
	# Toggle Line of Sight
	overlay_los_toggle = _create_overlay_toggle(
		"👁 Line of Sight", 
		Vector2(10 * scale_factor, toggle_start_y + toggle_height * 4),
		Vector2(toggle_width, toggle_height),
		overlay_settings["los"],
		"los"
	)
	eye_menu_panel.add_child(overlay_los_toggle)
	
	# Ajustar altura del panel para incluir el nuevo toggle
	eye_menu_panel.size.y = toggle_start_y + toggle_height * 5 + 10 * scale_factor
	
	add_child(eye_menu_panel)

func _create_overlay_toggle(text: String, pos: Vector2, size: Vector2, initial_state: bool, overlay_key: String) -> Button:
	"""Crea un botón toggle para una opción de overlay"""
	var btn = Button.new()
	btn.text = ("✓ " if initial_state else "○ ") + text
	btn.position = pos
	btn.size = size
	btn.add_theme_font_size_override("font_size", int(13 * scale_factor))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Guardar el texto base en metadatos para poder restaurarlo
	btn.set_meta("base_text", text)
	
	# Estilo toggle
	var toggle_style = StyleBoxFlat.new()
	toggle_style.bg_color = Color(0.12, 0.18, 0.25, 0.8) if initial_state else Color(0.08, 0.1, 0.14, 0.6)
	toggle_style.border_color = Color(0.3, 0.7, 0.5, 0.8) if initial_state else Color(0.2, 0.3, 0.4, 0.5)
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
	
	btn.pressed.connect(_on_overlay_toggle_pressed.bind(overlay_key, btn))
	return btn

func _on_eye_button_pressed():
	"""Toggle del menú de overlays"""
	if eye_menu_panel:
		eye_menu_panel.visible = not eye_menu_panel.visible

func _on_overlay_toggle_pressed(overlay_key: String, btn: Button):
	"""Maneja el cambio de estado de un overlay"""
	overlay_settings[overlay_key] = not overlay_settings[overlay_key]
	var is_active = overlay_settings[overlay_key]
	
	# Actualizar texto del botón usando el texto base guardado
	var base_text = btn.get_meta("base_text", "")
	btn.text = ("✓ " if is_active else "○ ") + base_text
	
	# Actualizar estilo
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
	
	# Aplicar cambio al mapa
	_apply_overlay_setting(overlay_key, is_active)

func _apply_overlay_setting(overlay_key: String, is_active: bool):
	"""Aplica la configuración del overlay al hex_grid/renderer"""
	var battle_scene = get_parent()
	if not battle_scene:
		return
	
	var hex_grid = battle_scene.get_node_or_null("HexGrid")
	if not hex_grid:
		return
	
	# El surface_renderer se llama __hex_surface_renderer o es accesible vía _surface_renderer
	var surface_renderer = hex_grid.get_node_or_null("__hex_surface_renderer")
	if not surface_renderer and "_surface_renderer" in hex_grid:
		surface_renderer = hex_grid._surface_renderer
	
	if not surface_renderer:
		print("[UI] Warning: surface_renderer not found")
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
	
	# NO llamar queue_redraw() porque borra los overlays de movimiento/deployment
	# Los setters ya llaman a _refresh_labels() automáticamente
	
	print("[UI] Overlay '%s' set to %s" % [overlay_key, is_active])

func is_mouse_over_eye_menu() -> bool:
	"""Devuelve true si el mouse está sobre el menú de Eye"""
	if not eye_menu_panel or not eye_menu_panel.visible:
		return false
	var mouse_pos = get_viewport().get_mouse_position()
	var panel_rect = Rect2(eye_menu_panel.global_position, eye_menu_panel.size)
	return panel_rect.has_point(mouse_pos)

func _toggle_los_overlay(is_active: bool, hex_grid):
	"""Activa/desactiva el overlay de línea de visión para los mechs del jugador"""
	los_overlay_visible = is_active
	
	if not is_active:
		# Limpiar overlay de LOS
		_clear_los_overlay(hex_grid)
		return
	
	# Calcular hexes visibles por todos los mechs del jugador
	_update_los_overlay(hex_grid)

func _update_los_overlay(hex_grid):
	"""Calcula y muestra los hexes visibles por los mechs del jugador"""
	if not los_overlay_visible or not hex_grid:
		return
	
	# Obtener turn_manager para acceder a los mechs del jugador
	var turn_manager = null
	if battle_scene and battle_scene.has_method("get_turn_manager"):
		turn_manager = battle_scene.get_turn_manager()
	
	if not turn_manager:
		print("[UI] No turn_manager found for LOS overlay")
		return
	
	var player_units = turn_manager.player_units
	if player_units.size() == 0:
		return
	
	# Recolectar todos los hexes visibles por cualquier mech del jugador
	var visible_hexes: Dictionary = {}  # hex_key -> true (para evitar duplicados)
	
	# Iterar sobre todos los hexes del mapa
	for q in range(hex_grid.grid_width):
		for r in range(hex_grid.grid_height):
			var target_hex = Vector2i(q, r)
			
			# Verificar si algún mech del jugador puede ver este hex
			for unit in player_units:
				if unit.is_destroyed:
					continue
				
				# Si es el propio hex del mech, siempre visible
				if unit.hex_position == target_hex:
					var hex_key = "%d,%d" % [q, r]
					visible_hexes[hex_key] = target_hex
					break
				
				# Usar el sistema completo de LineOfSight
				var los_data = LineOfSight.calculate_los(hex_grid, unit.hex_position, target_hex)
				
				# Solo marcar como visible si la línea no está bloqueada
				if los_data.result != LineOfSight.Result.BLOCKED:
					var hex_key = "%d,%d" % [q, r]
					visible_hexes[hex_key] = target_hex
					break  # No necesitamos verificar más mechs
	
	# Preparar overlays para el renderer
	var overlays: Array = []
	var los_color = Color(0.2, 0.8, 0.2, 0.25)  # Verde semi-transparente
	
	for hex_key in visible_hexes:
		var hex = visible_hexes[hex_key]
		var elevation = hex_grid.get_elevation(hex)
		overlays.append({
			"hex": hex,
			"color": los_color,
			"elevation": elevation
		})
	
	los_overlay_hexes = overlays
	
	# En lugar de renderizar directamente, pedimos a battle_scene que actualice
	# todos los overlays (incluyendo el de LOS)
	if battle_scene and battle_scene.has_method("update_overlays"):
		battle_scene.update_overlays()
	
	print("[UI] LOS overlay showing %d visible hexes" % visible_hexes.size())

func _clear_los_overlay(hex_grid):
	"""Limpia el overlay de línea de visión"""
	los_overlay_hexes.clear()
	
	# Actualizar overlays en battle_scene para que se quiten los de LOS
	if battle_scene and battle_scene.has_method("update_overlays"):
		battle_scene.update_overlays()

func refresh_los_overlay():
	"""Refresca el overlay de LOS (llamar cuando los mechs se muevan)"""
	if not los_overlay_visible:
		return
	
	var hex_grid = null
	if battle_scene:
		hex_grid = battle_scene.get_node_or_null("HexGrid")
	
	if hex_grid:
		_update_los_overlay(hex_grid)
