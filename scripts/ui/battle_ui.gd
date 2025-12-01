
extends CanvasLayer
var scale_factor := 1.0
var margin := 10.0

@onready var battle_scene = get_parent()
@onready var steeltitans_theme = load("res://assets/themes/steeltitans_theme.tres")

# Preload de componentes UI
const BattleWeaponSelectorPanelClass = preload("res://scripts/ui/battle_weapon_selector_panel.gd")
const BattleUIFactoryClass = preload("res://scripts/ui/battle_ui_factory.gd")

# Componente de estilos centralizado
var _styles: SteelTitansStyles
var _factory  # BattleUIFactory

# Paneles principales para ocultar/mostrar
var info_panel: Panel
var log_panel: BattleCombatLogPanel  # Componente extraído

var turn_label: Label
var phase_label: Label
var unit_info_label: Label
var mech_paper_doll: Control = null  # Paper doll del mech
var end_turn_button: Button
var help_label: Label
var cancel_movement_button: Button  # Botón para cancelar selección de movimiento

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
var eye_menu_panel: BattleOverlayMenu = null  # Componente extraído

# Selector de tipo de movimiento
var movement_selector_panel: Panel
var movement_selector_title: Label
var walk_button: Button
var run_button: Button
var jump_button: Button
var turn_button: Button

# Selector de orientación (facing)
var facing_selector: Control

# Selector de armas para disparo (delegado a BattleWeaponSelectorPanel)
var weapon_selector: Panel = null  # Tipo Panel para evitar errores de carga

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

# Panel de inspección de mech (delegado a BattleMechInspector)
var mech_inspector: BattleMechInspector = null

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
	
	# Conectar señal de chat del NetworkManager
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager and network_manager.has_signal("chat_message_received"):
		if not network_manager.chat_message_received.is_connected(_on_chat_message_received):
			network_manager.chat_message_received.connect(_on_chat_message_received)

func _on_chat_message_received(sender_name: String, message: String):
	"""Callback cuando se recibe un mensaje de chat del oponente"""
	add_chat_message(sender_name, message, Color(1, 0.8, 0.5, 1))  # Color naranja para oponente

func _setup_ui():
	# Obtener tamaño de la pantalla
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y
	
	# Escalar todo basado en el ancho de pantalla
	scale_factor = screen_width / 720.0  # Resolución base 720px de ancho
	margin = 10 * scale_factor
	
	# Inicializar componente de estilos y factory
	_styles = SteelTitansStyles.new(scale_factor)
	_factory = BattleUIFactoryClass.new(scale_factor, margin, steeltitans_theme)
	
	# Cargar texturas de MP dots
	if ResourceLoader.exists("res://assets/ui/mp_dot_filled.svg"):
		mp_dot_filled_texture = load("res://assets/ui/mp_dot_filled.svg")
	if ResourceLoader.exists("res://assets/ui/mp_dot_empty.svg"):
		mp_dot_empty_texture = load("res://assets/ui/mp_dot_empty.svg")
	
	# ============================================
	# SECCIÓN IZQUIERDA (SIN BOX): T1 + MOVEMENT + END
	# ============================================
	
	# Turn label (arriba izquierda, sin panel)
	turn_label = _factory.create_turn_label("T1")
	turn_label.position = Vector2(margin + 8 * scale_factor, margin + 4 * scale_factor)
	add_child(turn_label)
	
	# Phase label (debajo de T1)
	phase_label = _factory.create_phase_label("MOVEMENT")
	phase_label.position = Vector2(margin + 8 * scale_factor, margin + 30 * scale_factor)
	add_child(phase_label)
	
	# Botón End (debajo de phase)
	end_turn_button = _factory.create_end_turn_button(_on_end_turn_pressed)
	end_turn_button.position = Vector2(margin + 8 * scale_factor, margin + 52 * scale_factor)
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
	
	# Estilo Steel Titans azul
	info_panel.add_theme_stylebox_override("panel", _styles.create_info_panel_style())
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
	var _doll_center_x = doll_x + doll_width * 0.5
	
	# Posiciones Y relativas
	var doll_y = panel_padding + content_height * 0.15
	var heat_y = box_height - panel_padding - heat_section_height
	
	# 1. EYE BUTTON (arriba a la derecha de la box)
	eye_button = _factory.create_eye_button(eye_btn_size, _on_eye_button_pressed)
	eye_button.position = Vector2(box_width - panel_padding - eye_btn_size, panel_padding)
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
	mech_name_label = _factory.create_mech_name_label(name_font_size)
	mech_name_label.position = Vector2(doll_x - doll_width * 0.1, doll_y - content_height * 0.15)
	mech_name_label.size = Vector2(doll_width * 1.2, box_height * 0.12)
	info_panel.add_child(mech_name_label)
	
	# 4. MP DOTS (columna vertical a la izquierda del robot)
	var mp_dot_size = mp_column_width * 0.9
	mp_dot_size = clampf(mp_dot_size, 10, 20)
	
	mp_container = _factory.create_mp_container()
	mp_container.position = Vector2(mp_x, doll_y - content_height * 0.15)
	mp_container.size = Vector2(mp_column_width, doll_height)
	info_panel.add_child(mp_container)
	
	for i in range(12):
		var dot = _factory.create_mp_dot(mp_dot_size, mp_dot_empty_texture)
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
	
	heat_bar = _factory.create_heat_bar()
	heat_bar.position = Vector2(heat_start_x + heat_icon_width, heat_y + heat_section_height * 0.15)
	heat_bar.size = Vector2(heat_bar_width, heat_row_height)
	info_panel.add_child(heat_bar)
	
	heat_label = _factory.create_heat_label(heat_font_size)
	heat_label.position = Vector2(heat_start_x + heat_icon_width + heat_bar_width + panel_padding * 0.5, heat_y)
	heat_label.size = Vector2(heat_label_width, heat_section_height)
	info_panel.add_child(heat_label)
	
	# ============================================
	# Help label y Cancel button (debajo de END, sin box)
	# ============================================
	help_label = _factory.create_help_label()
	help_label.position = Vector2(margin + 8 * scale_factor, margin + 85 * scale_factor)
	add_child(help_label)
	
	# Botón de cancelar movimiento - CENTRADO EN PARTE SUPERIOR DE PANTALLA
	cancel_movement_button = _factory.create_cancel_button(_on_cancel_movement_pressed)
	var cancel_btn_width = 120 * scale_factor
	cancel_movement_button.position = Vector2((screen_width - cancel_btn_width) / 2, margin)
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
	# COMBAT LOG - Usando componente BattleCombatLogPanel
	# ============================================
	var log_height = screen_height * 0.26
	
	log_panel = BattleCombatLogPanel.new()
	log_panel.position = Vector2(margin, screen_height - log_height - margin)
	log_panel.size = Vector2(screen_width * 0.95, log_height)
	log_panel.setup(scale_factor, margin, steeltitans_theme)
	log_panel.chat_message_sent.connect(_on_chat_message_from_panel)
	log_panel.gui_input.connect(_on_log_panel_gui_input)
	add_child(log_panel)
	
	# ============================================
	# FIN COMBAT LOG
	# ============================================
	
	# Panel selector de tipo de movimiento (centrado, 85% del ancho) - Estilo Steel Titans
	var movement_panel_width = screen_width * 0.85
	var movement_panel_height = screen_height * 0.45
	movement_selector_panel = Panel.new()
	movement_selector_panel.position = Vector2((screen_width - movement_panel_width) / 2, (screen_height - movement_panel_height) / 2 - 50 * scale_factor)
	movement_selector_panel.size = Vector2(movement_panel_width, movement_panel_height)
	movement_selector_panel.visible = false
	
	# Usar estilo centralizado
	movement_selector_panel.add_theme_stylebox_override("panel", _styles.create_main_panel_style())
	add_child(movement_selector_panel)
	
	movement_selector_title = _factory.create_title_label("SELECT MOVEMENT TYPE")
	movement_selector_title.position = Vector2(margin * 2, margin * 2)
	movement_selector_title.size = Vector2(movement_panel_width - margin * 4, 30 * scale_factor)
	movement_selector_panel.add_child(movement_selector_title)
	
	var button_height = (movement_panel_height - 100 * scale_factor) / 4
	var button_width = movement_panel_width - margin * 4
	var button_x = margin * 2
	
	walk_button = _factory.create_movement_button("WALK", _on_walk_pressed)
	walk_button.position = Vector2(button_x, 55 * scale_factor)
	walk_button.size = Vector2(button_width, button_height)
	movement_selector_panel.add_child(walk_button)
	
	run_button = _factory.create_movement_button("RUN", _on_run_pressed)
	run_button.position = Vector2(button_x, 55 * scale_factor + button_height + 5)
	run_button.size = Vector2(button_width, button_height)
	movement_selector_panel.add_child(run_button)
	
	jump_button = _factory.create_movement_button("JUMP", _on_jump_pressed)
	jump_button.position = Vector2(button_x, 55 * scale_factor + (button_height + 5) * 2)
	jump_button.size = Vector2(button_width, button_height)
	movement_selector_panel.add_child(jump_button)
	
	turn_button = _factory.create_movement_button("TURN", _on_turn_pressed)
	turn_button.position = Vector2(button_x, 55 * scale_factor + (button_height + 5) * 3)
	turn_button.size = Vector2(button_width, button_height)
	movement_selector_panel.add_child(turn_button)
	
	# Selector de orientación (facing) - capa superior
	var FacingSelector = load("res://scripts/ui/facing_selector.gd")
	facing_selector = FacingSelector.new()
	facing_selector.size = Vector2(300 * scale_factor, 300 * scale_factor)
	facing_selector.visible = false
	facing_selector.facing_selected.connect(_on_facing_selected)
	add_child(facing_selector)
	
	# Panel selector de armas (delegado a BattleWeaponSelectorPanel)
	weapon_selector = BattleWeaponSelectorPanelClass.new()
	weapon_selector.setup(scale_factor, viewport_size)
	weapon_selector.weapons_confirmed.connect(_on_weapons_confirmed)
	weapon_selector.selection_cancelled.connect(_on_weapon_selection_cancelled)
	add_child(weapon_selector)
	
	# ═══════════════════════════════════════════════════════════════════════════
	# PANEL SELECTOR DE ATAQUE FÍSICO
	# ═══════════════════════════════════════════════════════════════════════════
	var physical_panel_width = screen_width * 0.85
	var physical_panel_height = screen_height * 0.50
	physical_attack_panel = Panel.new()
	physical_attack_panel.position = Vector2((screen_width - physical_panel_width) / 2, (screen_height - physical_panel_height) / 2 - 60 * scale_factor)
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
	punch_left_button = _factory.create_physical_attack_button("PUNCH (Left Arm)", _on_punch_left_pressed)
	punch_left_button.position = Vector2(margin, 50 * scale_factor)
	punch_left_button.size = Vector2(phys_button_width, phys_button_height)
	physical_attack_panel.add_child(punch_left_button)
	
	# Botón puñetazo derecho
	punch_right_button = _factory.create_physical_attack_button("PUNCH (Right Arm)", _on_punch_right_pressed)
	punch_right_button.position = Vector2(margin, 50 * scale_factor + phys_button_height + 5)
	punch_right_button.size = Vector2(phys_button_width, phys_button_height)
	physical_attack_panel.add_child(punch_right_button)
	
	# Botón patada
	kick_button = _factory.create_physical_attack_button("KICK", _on_kick_pressed)
	kick_button.position = Vector2(margin, 50 * scale_factor + (phys_button_height + 5) * 2)
	kick_button.size = Vector2(phys_button_width, phys_button_height)
	physical_attack_panel.add_child(kick_button)
	
	# Botón embestida
	charge_button = _factory.create_physical_attack_button("CHARGE", _on_charge_pressed)
	charge_button.position = Vector2(margin, 50 * scale_factor + (phys_button_height + 5) * 3)
	charge_button.size = Vector2(phys_button_width, phys_button_height)
	physical_attack_panel.add_child(charge_button)
	
	# Botón cancelar
	cancel_physical_button = _factory.create_physical_attack_button("CANCEL", _on_cancel_physical_pressed)
	cancel_physical_button.position = Vector2(margin, 50 * scale_factor + (phys_button_height + 5) * 4)
	cancel_physical_button.size = Vector2(phys_button_width, phys_button_height)
	physical_attack_panel.add_child(cancel_physical_button)
	
	# Panel de confirmación genérico - Estilo Steel Titans (centrado en pantalla, compacto)
	var confirm_panel_width = 420 * scale_factor
	var confirm_panel_height = 90 * scale_factor
	confirmation_panel = _factory.create_confirmation_panel(confirm_panel_width, confirm_panel_height)
	confirmation_panel.position = Vector2((screen_width - confirm_panel_width) / 2, (screen_height - confirm_panel_height) / 2)
	add_child(confirmation_panel)
	
	# Mensaje centrado horizontalmente en la parte superior del panel
	confirmation_message = _factory.create_confirmation_message()
	confirmation_message.position = Vector2(margin, margin)
	confirmation_message.size = Vector2(confirm_panel_width - margin * 2, 30 * scale_factor)
	confirmation_panel.add_child(confirmation_message)
	
	# Título oculto (no necesario en formato banner)
	confirmation_title = Label.new()
	confirmation_title.visible = false
	confirmation_panel.add_child(confirmation_title)
	
	# Botones como iconos grandes centrados horizontalmente
	var button_size = 45 * scale_factor
	var button_spacing = 30 * scale_factor
	var total_buttons_width = button_size * 2 + button_spacing
	var button_x_start = (confirm_panel_width - total_buttons_width) / 2
	var button_y = 40 * scale_factor
	
	# Botón CONFIRMAR - Tick verde
	confirm_button = _factory.create_confirm_icon_button(button_size, _on_confirmation_confirm)
	confirm_button.position = Vector2(button_x_start, button_y)
	confirmation_panel.add_child(confirm_button)
	
	# Botón CANCELAR - Cruz roja
	cancel_button = _factory.create_cancel_icon_button(button_size, _on_confirmation_cancel)
	cancel_button.position = Vector2(button_x_start + button_size + button_spacing, button_y)
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

func update_turn_info(turn_number: int, _team: String):
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
	var heat_ratio = float(current_heat) / float(max_heat) if max_heat > 0 else 0.0
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
	Log.debug("UI", "Cancel movement pressed")
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

# ============================================
# COMBAT LOG - Funciones delegadas al componente
# ============================================

func _on_log_panel_gui_input(event: InputEvent):
	"""Captura todos los eventos de input en el panel de log para que no pasen al mapa"""
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()

func _on_chat_message_from_panel(text: String):
	"""Callback cuando el componente de log emite un mensaje de chat"""
	_send_chat_message(text)

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

func add_combat_message(message: String, color: Color = Color.WHITE):
	"""Añade un mensaje de combate al log"""
	if log_panel:
		log_panel.add_combat_message(message, color)

func add_chat_message(sender: String, message: String, color: Color = Color.WHITE):
	"""Añade un mensaje de chat (para multiplayer)"""
	if log_panel:
		log_panel.add_chat_message(sender, message, color)

func _send_chat_message(text: String):
	"""Envía un mensaje de chat. En multiplayer, se envía por red."""
	var sender_name = "Jugador"
	var network_manager = get_node_or_null("/root/NetworkManager")
	
	if network_manager and network_manager.has_method("get_local_player_name"):
		sender_name = network_manager.get_local_player_name()
	
	# Añadir mensaje local inmediatamente
	add_chat_message(sender_name, text, Color(0.7, 0.9, 1, 1))
	
	# En multiplayer, enviar por RPC al oponente
	if network_manager and network_manager.is_in_match():
		network_manager.send_chat_message(text)

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
	Log.debug("UI", "_on_facing_selected called", {"facing": facing})
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
	
	Log.debug("UI", "Calling battle_scene.on_facing_selected", {"facing": facing})
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

## SELECTOR DE ARMAS (DELEGADO A BattleWeaponSelectorPanel) ##

func show_weapon_selector(attacker, target, range_hexes: int):
	"""Muestra el selector de armas (delegado al componente)"""
	if weapon_selector:
		weapon_selector.show_selector(attacker, target, range_hexes)

func hide_weapon_selector():
	"""Oculta el selector de armas"""
	if weapon_selector:
		weapon_selector.hide_selector()
	if battle_scene and battle_scene.has_method("notify_ui_interaction"):
		battle_scene.notify_ui_interaction()

func is_weapon_selector_visible() -> bool:
	"""Verifica si el panel de selección de armas está visible"""
	return weapon_selector != null and weapon_selector.is_visible_panel()

func is_physical_attack_panel_visible() -> bool:
	"""Verifica si el panel de ataques físicos está visible"""
	return physical_attack_panel != null and physical_attack_panel.visible

func is_point_over_attack_panels(screen_pos: Vector2) -> bool:
	"""Verifica si un punto de pantalla está sobre algún panel de ataque"""
	if weapon_selector and weapon_selector.is_point_over_panel(screen_pos):
		return true
	if physical_attack_panel and physical_attack_panel.visible:
		var rect = physical_attack_panel.get_global_rect()
		if rect.has_point(screen_pos):
			return true
	return false

func _on_weapons_confirmed(attacker, target, selected_weapons: Array, range_hexes: int):
	"""Callback cuando se confirma el disparo de armas"""
	if battle_scene and battle_scene.has_method("execute_weapon_attack"):
		battle_scene.execute_weapon_attack(attacker, target, selected_weapons, range_hexes)

func _on_weapon_selection_cancelled():
	"""Callback cuando se cancela la selección de armas"""
	add_combat_message("Weapon attack cancelled", Color.GRAY)

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
	game_over_panel.add_theme_stylebox_override("panel", _styles.create_game_over_panel_style())
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
	"""Muestra el inspector de mech (delegado a BattleMechInspector)"""
	if not mech_inspector:
		mech_inspector = BattleMechInspector.new(self, steeltitans_theme, scale_factor, margin)
	mech_inspector.show_inspector(mech)

func show_mech_paper_doll_dialog(mech):
	"""Muestra el diálogo de paper doll (delegado a BattleMechInspector)"""
	if not mech_inspector:
		mech_inspector = BattleMechInspector.new(self, steeltitans_theme, scale_factor, margin)
	mech_inspector.show_paper_doll_dialog(mech)

func hide_mech_inspector():
	"""Oculta el inspector de mech"""
	if mech_inspector:
		mech_inspector.hide_inspector()

func _on_close_inspector_pressed():
	hide_mech_inspector()

## Panel de confirmación genérico
func show_confirmation_dialog(title: String, message: String, on_confirm: Callable, on_cancel: Callable = Callable()):
	"""Muestra un diálogo de confirmación genérico"""
	Log.debug("UI", "Showing confirmation dialog", {"title": title})
	if not confirmation_panel:
		Log.error("UI", "confirmation_panel is null!")
		return
	
	confirmation_title.text = title
	confirmation_message.text = message
	on_confirm_callback = on_confirm
	on_cancel_callback = on_cancel
	
	Log.debug("UI", "Callbacks set", {
		"confirm_valid": on_confirm.is_valid(),
		"cancel_valid": on_cancel.is_valid()
	})
	
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
	Log.debug("UI", "Confirmation CONFIRM pressed")
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
		Log.debug("UI", "Calling confirm callback")
		callback.call()
	else:
		Log.debug("UI", "No valid confirm callback")

func _on_confirmation_cancel():
	"""Botón de cancelación presionado"""
	Log.debug("UI", "Confirmation CANCEL pressed")
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
		Log.debug("UI", "Calling cancel callback")
		callback.call()
	else:
		Log.debug("UI", "No valid cancel callback")

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
# EYE BUTTON - SISTEMA DE OVERLAYS (DELEGADO A BattleOverlayMenu)
# ============================================

func _create_eye_menu():
	"""Crea el menú desplegable usando el componente BattleOverlayMenu"""
	eye_menu_panel = BattleOverlayMenu.new()
	eye_menu_panel.setup(scale_factor, battle_scene)
	
	# Posicionar debajo de la box del mech (info_panel)
	var menu_x = info_panel.position.x + info_panel.size.x - eye_menu_panel.size.x
	var menu_y = info_panel.position.y + info_panel.size.y + 5 * scale_factor
	eye_menu_panel.position = Vector2(menu_x, menu_y)
	
	# Conectar señales para actualizar overlays en battle_scene
	eye_menu_panel.los_overlay_requested.connect(_on_los_overlay_requested)
	eye_menu_panel.los_overlay_cleared.connect(_on_los_overlay_cleared)
	
	add_child(eye_menu_panel)

func _on_eye_button_pressed():
	"""Toggle del menú de overlays"""
	if eye_menu_panel:
		eye_menu_panel.toggle_visibility()

func _on_los_overlay_requested(_visible_hexes: Array):
	"""Callback cuando el componente solicita mostrar overlay de LOS"""
	if battle_scene and battle_scene.has_method("update_overlays"):
		battle_scene.update_overlays()

func _on_los_overlay_cleared():
	"""Callback cuando el componente limpia el overlay de LOS"""
	if battle_scene and battle_scene.has_method("update_overlays"):
		battle_scene.update_overlays()

func is_mouse_over_eye_menu() -> bool:
	"""Devuelve true si el mouse está sobre el menú de Eye"""
	return eye_menu_panel != null and eye_menu_panel.is_mouse_over()

func refresh_los_overlay():
	"""Refresca el overlay de LOS (llamar cuando los mechs se muevan)"""
	if eye_menu_panel:
		eye_menu_panel.refresh_los_overlay()

func get_los_overlay_hexes() -> Array:
	"""Obtiene los hexes del overlay de LOS para renderizar"""
	if eye_menu_panel:
		return eye_menu_panel.get_los_overlay_hexes()
	return []

func is_los_overlay_visible() -> bool:
	"""Indica si el overlay de LOS está visible"""
	return eye_menu_panel != null and eye_menu_panel.is_los_overlay_visible()
