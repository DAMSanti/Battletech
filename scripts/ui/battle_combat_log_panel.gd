extends Panel
class_name BattleCombatLogPanel
## Panel de log de combate con tabs (FULL/SHORT/CHAT) y chat multiplayer

signal chat_message_sent(text: String)

var scale_factor: float = 1.0
var margin: float = 10.0

# Componentes UI internos
var combat_log: RichTextLabel
var combat_log_scrollbar: VScrollBar
var collapse_log_button: Button
var full_button: Button
var short_button: Button
var chat_button: Button
var chat_input_container: HBoxContainer
var chat_input: LineEdit

# Estado
var combat_log_mode: String = "full"  # "full", "short", "chat"
var combat_log_collapsed: bool = false
var log_expanded_height: float = 0.0
var log_collapsed_height: float = 40.0
var message_history: Array = []  # [{text: String, color: Color}]
var chat_history: Array = []  # [{text: String, sender: String, color: Color}]

var _styles: SteelTitansStyles
var _theme: Theme

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(p_scale_factor: float, p_margin: float, p_theme: Theme) -> void:
	scale_factor = p_scale_factor
	margin = p_margin
	log_collapsed_height = 40 * scale_factor
	_styles = SteelTitansStyles.new(scale_factor)
	_theme = p_theme
	_setup_panel()

func _setup_panel() -> void:
	# Aplicar estilo del panel
	add_theme_stylebox_override("panel", _styles.create_log_panel_style())
	
	# Guardar altura expandida
	log_expanded_height = size.y
	
	var header_height = 30 * scale_factor
	
	# Botón de colapso
	collapse_log_button = Button.new()
	collapse_log_button.text = "▼"
	collapse_log_button.position = Vector2(margin, 6 * scale_factor)
	collapse_log_button.size = Vector2(30 * scale_factor, 22 * scale_factor)
	collapse_log_button.add_theme_font_size_override("font_size", int(12 * scale_factor))
	collapse_log_button.add_theme_stylebox_override("normal", _styles.create_collapse_button_style())
	collapse_log_button.add_theme_stylebox_override("hover", _styles.create_collapse_button_hover_style())
	collapse_log_button.add_theme_stylebox_override("pressed", _styles.create_collapse_button_hover_style())
	collapse_log_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	collapse_log_button.add_theme_color_override("font_color", SteelTitansStyles.get_cyan_text_color())
	collapse_log_button.pressed.connect(_on_toggle_collapse)
	add_child(collapse_log_button)
	
	# Título "Log"
	var log_title = Label.new()
	log_title.text = "Log"
	log_title.position = Vector2(margin + 38 * scale_factor, 6 * scale_factor)
	log_title.add_theme_font_size_override("font_size", int(16 * scale_factor))
	log_title.add_theme_color_override("font_color", SteelTitansStyles.get_cyan_text_color())
	log_title.add_theme_color_override("font_outline_color", SteelTitansStyles.get_outline_color())
	log_title.add_theme_constant_override("outline_size", 1)
	add_child(log_title)
	
	# Pestañas FULL | SHORT | CHAT
	_setup_tabs(header_height)
	
	# RichTextLabel y Scrollbar
	_setup_log_content(header_height)
	
	# Chat input
	_setup_chat_input()

func _setup_tabs(_header_height: float) -> void:
	var tab_button_width = 55 * scale_factor
	var tab_button_height = 22 * scale_factor
	var tab_spacing = 3 * scale_factor
	var tabs_total_width = tab_button_width * 3 + tab_spacing * 2
	var tabs_x_start = size.x - margin - tabs_total_width - 35 * scale_factor
	var tab_y = 5 * scale_factor
	
	full_button = Button.new()
	full_button.text = "FULL"
	full_button.position = Vector2(tabs_x_start, tab_y)
	full_button.size = Vector2(tab_button_width, tab_button_height)
	full_button.theme = _theme
	full_button.add_theme_font_size_override("font_size", int(10 * scale_factor))
	full_button.pressed.connect(_on_mode_changed.bind("full"))
	add_child(full_button)
	
	short_button = Button.new()
	short_button.text = "SHORT"
	short_button.position = Vector2(tabs_x_start + tab_button_width + tab_spacing, tab_y)
	short_button.size = Vector2(tab_button_width, tab_button_height)
	short_button.theme = _theme
	short_button.add_theme_font_size_override("font_size", int(10 * scale_factor))
	short_button.pressed.connect(_on_mode_changed.bind("short"))
	add_child(short_button)
	
	chat_button = Button.new()
	chat_button.text = "CHAT"
	chat_button.position = Vector2(tabs_x_start + (tab_button_width + tab_spacing) * 2, tab_y)
	chat_button.size = Vector2(tab_button_width, tab_button_height)
	chat_button.theme = _theme
	chat_button.add_theme_font_size_override("font_size", int(10 * scale_factor))
	chat_button.pressed.connect(_on_mode_changed.bind("chat"))
	add_child(chat_button)
	
	_update_tab_buttons()

func _setup_log_content(header_height: float) -> void:
	var scrollbar_width = 35 * scale_factor
	var log_content_margin_left = margin + 15 * scale_factor
	var log_content_margin_right = margin + 15 * scale_factor
	var log_content_top = header_height + 10 * scale_factor
	
	# RichTextLabel SIN scrollbar interna
	combat_log = RichTextLabel.new()
	combat_log.position = Vector2(log_content_margin_left, log_content_top)
	combat_log.size = Vector2(
		size.x - log_content_margin_left - log_content_margin_right - scrollbar_width - 5 * scale_factor,
		size.y - log_content_top - 10 * scale_factor
	)
	combat_log.bbcode_enabled = true
	combat_log.scroll_following = true
	combat_log.scroll_active = false
	combat_log.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_log.add_theme_font_size_override("normal_font_size", int(13 * scale_factor))
	combat_log.add_theme_stylebox_override("normal", _styles.create_combat_log_text_style())
	combat_log.add_theme_color_override("default_color", SteelTitansStyles.get_white_text_color())
	add_child(combat_log)
	
	# Scrollbar personalizada
	combat_log_scrollbar = VScrollBar.new()
	combat_log_scrollbar.position = Vector2(
		size.x - log_content_margin_right - scrollbar_width,
		log_content_top
	)
	combat_log_scrollbar.size = Vector2(scrollbar_width, combat_log.size.y)
	combat_log_scrollbar.mouse_filter = Control.MOUSE_FILTER_STOP
	combat_log_scrollbar.add_theme_stylebox_override("grabber", _styles.create_scrollbar_grabber_style())
	combat_log_scrollbar.add_theme_stylebox_override("grabber_highlight", _styles.create_scrollbar_grabber_style())
	combat_log_scrollbar.add_theme_stylebox_override("grabber_pressed", _styles.create_scrollbar_grabber_style())
	combat_log_scrollbar.add_theme_stylebox_override("scroll", _styles.create_scrollbar_background_style())
	combat_log_scrollbar.value_changed.connect(_on_scrollbar_changed)
	combat_log_scrollbar.gui_input.connect(_on_scrollbar_gui_input)
	add_child(combat_log_scrollbar)
	
	# Ocultar scrollbar interna
	var internal_scrollbar = combat_log.get_v_scroll_bar()
	internal_scrollbar.modulate.a = 0
	internal_scrollbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	internal_scrollbar.value_changed.connect(_on_internal_scroll_changed)

func _setup_chat_input() -> void:
	var chat_input_height = 28 * scale_factor
	var log_content_margin_left = margin + 15 * scale_factor
	
	chat_input_container = HBoxContainer.new()
	chat_input_container.position = Vector2(log_content_margin_left, size.y - chat_input_height - 5 * scale_factor)
	chat_input_container.size = Vector2(combat_log.size.x, chat_input_height)
	chat_input_container.visible = false
	chat_input_container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Escribe un mensaje..."
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.add_theme_font_size_override("font_size", int(12 * scale_factor))
	chat_input.add_theme_stylebox_override("normal", _styles.create_text_input_style())
	chat_input.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_input.add_theme_color_override("font_color", Color(0.9, 0.95, 1, 1))
	chat_input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.6, 0.7, 0.7))
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_input_container.add_child(chat_input)
	
	var send_button = Button.new()
	send_button.text = "➤"
	send_button.custom_minimum_size = Vector2(40 * scale_factor, chat_input_height)
	send_button.theme = _theme
	send_button.add_theme_font_size_override("font_size", int(14 * scale_factor))
	send_button.pressed.connect(_on_send_pressed)
	chat_input_container.add_child(send_button)
	
	add_child(chat_input_container)

# ============================================
# CALLBACKS
# ============================================

func _on_toggle_collapse() -> void:
	combat_log_collapsed = not combat_log_collapsed
	_update_collapse_state()

func _on_mode_changed(mode: String) -> void:
	combat_log_mode = mode
	_update_tab_buttons()
	refresh_log()
	_update_chat_input_visibility()

func _on_scrollbar_changed(value: float) -> void:
	if combat_log:
		var internal_scroll = combat_log.get_v_scroll_bar()
		if internal_scroll and internal_scroll.value != value:
			internal_scroll.value = value

func _on_internal_scroll_changed(value: float) -> void:
	if combat_log_scrollbar and combat_log_scrollbar.value != value:
		combat_log_scrollbar.value = value

func _on_scrollbar_gui_input(_event: InputEvent) -> void:
	pass  # No bloquear eventos de scrollbar

func _on_chat_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	chat_message_sent.emit(text)
	chat_input.clear()

func _on_send_pressed() -> void:
	if chat_input and not chat_input.text.strip_edges().is_empty():
		chat_message_sent.emit(chat_input.text)
		chat_input.clear()

# ============================================
# ACTUALIZACIÓN DE ESTADO
# ============================================

func _update_tab_buttons() -> void:
	var active_color = Color(0.4, 0.9, 0.5)
	var inactive_color = Color(0.7, 0.7, 0.7)
	
	if full_button:
		full_button.modulate = active_color if combat_log_mode == "full" else inactive_color
	if short_button:
		short_button.modulate = active_color if combat_log_mode == "short" else inactive_color
	if chat_button:
		chat_button.modulate = active_color if combat_log_mode == "chat" else inactive_color

func _update_chat_input_visibility() -> void:
	if not chat_input_container:
		return
	
	chat_input_container.visible = (combat_log_mode == "chat" and not combat_log_collapsed)
	
	if combat_log:
		var header_height = 30 * scale_factor
		var log_content_top = header_height + 10 * scale_factor
		var chat_input_height = 28 * scale_factor
		var bottom_margin = 10 * scale_factor
		
		if chat_input_container.visible:
			var new_height = size.y - log_content_top - chat_input_height - bottom_margin - 5 * scale_factor
			combat_log.size.y = new_height
			if combat_log_scrollbar:
				combat_log_scrollbar.size.y = new_height
		else:
			var new_height = size.y - log_content_top - bottom_margin
			combat_log.size.y = new_height
			if combat_log_scrollbar:
				combat_log_scrollbar.size.y = new_height

func _update_collapse_state() -> void:
	var target_height = log_collapsed_height if combat_log_collapsed else log_expanded_height
	
	# Actualizar tamaño (la posición la maneja el padre)
	size.y = target_height
	
	if collapse_log_button:
		collapse_log_button.text = "▲" if combat_log_collapsed else "▼"
	
	if combat_log:
		combat_log.visible = not combat_log_collapsed
	if combat_log_scrollbar:
		combat_log_scrollbar.visible = not combat_log_collapsed
	if full_button:
		full_button.visible = not combat_log_collapsed
	if short_button:
		short_button.visible = not combat_log_collapsed
	if chat_button:
		chat_button.visible = not combat_log_collapsed
	
	_update_chat_input_visibility()

func _update_scrollbar_range() -> void:
	if not combat_log or not combat_log_scrollbar:
		return
	var internal_scroll = combat_log.get_v_scroll_bar()
	if internal_scroll:
		combat_log_scrollbar.min_value = internal_scroll.min_value
		combat_log_scrollbar.max_value = internal_scroll.max_value
		combat_log_scrollbar.page = internal_scroll.page
		combat_log_scrollbar.value = internal_scroll.value

# ============================================
# API PÚBLICA
# ============================================

func add_combat_message(message: String, color: Color = Color.WHITE) -> void:
	var msg_stripped = message.strip_edges()
	
	# Detectar duplicados de iniciativa
	var check_duplicates = false
	if "Initiative" in msg_stripped or "WINS INITIATIVE" in msg_stripped:
		check_duplicates = true
	elif "rolls:" in msg_stripped:
		check_duplicates = true
	elif "moves first" in msg_stripped:
		check_duplicates = true
	
	if check_duplicates:
		var check_last = min(15, message_history.size())
		for i in range(check_last):
			var idx = message_history.size() - 1 - i
			var last_msg = message_history[idx]
			if last_msg["text"] == message and last_msg["color"] == color:
				return
	
	message_history.append({"text": message, "color": color})
	
	if combat_log_mode != "chat":
		_add_message_to_log(message, color)

func add_chat_message(sender: String, message: String, color: Color = Color.WHITE) -> void:
	chat_history.append({"sender": sender, "text": message, "color": color})
	
	if combat_log_mode == "chat" and combat_log:
		combat_log.push_color(color)
		combat_log.append_text("[%s]: %s\n" % [sender, message])
		combat_log.pop()

func refresh_log() -> void:
	if not combat_log:
		return
	
	combat_log.clear()
	
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
	
	for msg_data in message_history:
		_add_message_to_log(msg_data["text"], msg_data["color"])
	
	call_deferred("_update_scrollbar_range")

func is_collapsed() -> bool:
	return combat_log_collapsed

func get_expanded_height() -> float:
	return log_expanded_height

func set_expanded_height(h: float) -> void:
	log_expanded_height = h
	if not combat_log_collapsed:
		size.y = h

# ============================================
# FILTRADO DE MENSAJES (modo SHORT)
# ============================================

func _add_message_to_log(message: String, color: Color) -> void:
	if not combat_log:
		return
	
	var final_message = message
	var final_color = color
	
	if combat_log_mode == "short":
		var result = _filter_message_for_short_mode(message, color)
		if result.is_empty():
			return
		final_message = result["text"]
		final_color = result["color"]
	
	combat_log.push_color(final_color)
	combat_log.append_text(final_message + "\n")
	combat_log.pop()
	
	call_deferred("_update_scrollbar_range")

func _filter_message_for_short_mode(message: String, color: Color) -> Dictionary:
	var msg = message.strip_edges()
	
	# Ignorar líneas vacías y separadores
	if msg == "":
		return {}
	if "═══" in msg or "╔═" in msg or "╚═" in msg or "║" in msg:
		return {}
	if "─────────" in msg:
		return {}
	
	# DEPLOYMENT
	if "DEPLOYING MECH" in msg or "ENEMY DEPLOYMENT" in msg:
		return {"text": msg, "color": color}
	if "MISSION BRIEF:" in msg or "DEPLOYMENT INSTRUCTIONS:" in msg:
		return {}
	if "BATTLE ROSTER:" in msg or "PLAYER LANCE:" in msg or "ENEMY LANCE:" in msg or "ENEMY FORCE:" in msg:
		return {}
	if "Invalid deployment location" in msg:
		return {}
	if "Mech:" in msg or "Tonnage:" in msg or "Movement:" in msg or "Jump:" in msg:
		return {}
	if "Progress:" in msg or "Click on a GREEN hex" in msg:
		return {}
	
	# INICIATIVA
	if "rolls:" in msg and ("[" in msg or "=" in msg):
		if "Player rolls:" in msg:
			var parts = msg.split("=")
			if parts.size() > 1:
				return {"text": "Player Initiative: " + parts[1].strip_edges(), "color": Color.CYAN}
		elif "Enemy rolls:" in msg:
			var parts = msg.split("=")
			if parts.size() > 1:
				return {"text": "Enemy Initiative: " + parts[1].strip_edges(), "color": Color.RED}
	if "WINS INITIATIVE" in msg:
		return {"text": msg, "color": color}
	if "moves first" in msg:
		return {}
	
	# MOVIMIENTO
	if "selected:" in msg:
		return {}
	if ("WALK" in msg or "RUN" in msg or "JUMP" in msg) and "from" in msg and "to" in msg:
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
				return {"text": name_and_type + " → " + destination + tmm, "color": color}
	if "Moved" in msg and "hexes" in msg and "Cost:" in msg:
		return {}
	if "MPs remaining:" in msg and "TMM:" in msg:
		return {}
	if "Movement heat generated" in msg:
		return {}
	if "Movimiento realizado" in msg:
		return {}
	
	# ATAQUE
	if "FIRES AT" in msg.to_upper():
		return {}
	if msg.begins_with("→ "):
		return {"text": msg, "color": color}
	if "Roll:" in msg:
		return {}
	if message.begins_with("  "):
		if "HIT!" in msg:
			if "Location:" in msg and "Damage:" in msg:
				var loc_start = msg.find("Location:") + 9
				var loc_end = msg.find(",", loc_start)
				var location = msg.substr(loc_start, loc_end - loc_start).strip_edges()
				var dmg_start = msg.find("Damage:") + 7
				var damage = msg.substr(dmg_start).strip_edges()
				return {"text": "  HIT! Location: " + location + ", Damage: " + damage, "color": Color.GREEN}
		elif "MISS" in msg:
			return {"text": "  MISS", "color": Color.GRAY}
		elif "DESTROYED!" in msg and msg.count("☠") > 0:
			return {"text": msg, "color": color}
		elif "CRITICAL HIT" in msg:
			return {"text": "  CRITICAL HIT!", "color": Color.RED}
		elif "DESTROYED!" in msg:
			return {"text": "  " + msg.replace("⚠ ", ""), "color": color}
		elif "→ " in msg and ("DESTROYED!" in msg or "takes" in msg or "FALLS" in msg):
			return {"text": msg, "color": color}
		else:
			return {}
	if "Heat generated:" in msg and "Current:" in msg:
		var parts = msg.split("(Current:")
		if parts.size() > 1:
			return {"text": "Heat: " + parts[1].replace(")", "").strip_edges(), "color": Color.ORANGE}
	if "Heat will be processed" in msg:
		return {}
	
	# FÍSICO
	if "attacks" in msg and "range:" in msg:
		return {"text": msg, "color": color}
	if "TN:" in msg:
		return {}
	
	# CALOR
	if "Avoided shutdown" in msg or "Avoided ammo explosion" in msg:
		return {}
	if "SHUTDOWN!" in msg or "AMMO EXPLOSION!" in msg:
		return {"text": msg.replace("☠", "").strip_edges(), "color": color}
	
	# Por defecto, mostrar en modo FULL
	return {"text": msg, "color": color}

# ============================================
# INPUT HANDLING
# ============================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
