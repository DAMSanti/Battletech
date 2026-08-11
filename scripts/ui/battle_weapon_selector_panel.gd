extends Panel
class_name BattleWeaponSelectorPanel
## Panel de selección de armas para ataques de combate

signal weapons_confirmed(attacker, target, selected_weapons: Array, range_hexes: int)
signal selection_cancelled()
@warning_ignore("unused_signal")
signal weapon_info_requested(weapon: Dictionary, to_hit_data: Dictionary)

var scale_factor: float = 1.0
var _styles: SteelTitansStyles

# Referencias internas
var title_label: Label
var fire_button: Button
var cancel_button: Button
var weapon_buttons: Array = []
var selected_weapons: Array = []

# Panel de información de arma
var weapon_info_panel: Panel
var weapon_info_name_label: Label
var weapon_info_type_label: Label
var weapon_info_scroll: ScrollContainer
var weapon_info_content: VBoxContainer
var weapon_info_label: RichTextLabel

# Datos del ataque actual
var _current_attacker = null
var _current_target = null
var _current_range: int = 0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func setup(p_scale_factor: float, screen_size: Vector2) -> void:
	scale_factor = p_scale_factor
	_styles = SteelTitansStyles.new(scale_factor)
	
	var margin = 10 * scale_factor
	var panel_width = screen_size.x * 0.85
	var panel_height = screen_size.y * 0.50
	
	position = Vector2((screen_size.x - panel_width) / 2, (screen_size.y - panel_height) / 2 - 60 * scale_factor)
	size = Vector2(panel_width, panel_height)
	
	gui_input.connect(_on_panel_input)
	add_theme_stylebox_override("panel", _styles.create_main_panel_style(0.3))
	
	_create_title(panel_width, margin)
	_create_buttons(panel_width, panel_height, margin)
	_create_weapon_info_panel(screen_size, margin)

func _create_title(panel_width: float, margin: float) -> void:
	title_label = Label.new()
	title_label.text = "SELECT WEAPONS TO FIRE"
	title_label.position = Vector2(margin, margin)
	title_label.size = Vector2(panel_width - margin * 2, 30 * scale_factor)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", int(20 * scale_factor))
	title_label.add_theme_color_override("font_color", SteelTitansStyles.get_cyan_text_color())
	title_label.add_theme_color_override("font_outline_color", SteelTitansStyles.get_outline_color())
	title_label.add_theme_constant_override("outline_size", 2)
	add_child(title_label)

func _create_buttons(panel_width: float, panel_height: float, margin: float) -> void:
	var btn_height = 50 * scale_factor
	var btn_spacing = 8 * scale_factor
	var btn_margin = margin * 1.5
	
	# Fire button
	fire_button = Button.new()
	fire_button.text = "FIRE SELECTED WEAPONS"
	fire_button.position = Vector2(btn_margin, panel_height - (btn_height * 2 + btn_spacing + margin))
	fire_button.size = Vector2(panel_width - btn_margin * 2 - 20 * scale_factor, btn_height)
	fire_button.add_theme_font_size_override("font_size", int(22 * scale_factor))
	fire_button.add_theme_stylebox_override("normal", _styles.create_positive_button_style())
	fire_button.add_theme_stylebox_override("hover", _styles.create_positive_button_hover_style())
	fire_button.add_theme_stylebox_override("pressed", _styles.create_positive_button_hover_style())
	fire_button.pressed.connect(_on_fire_pressed)
	fire_button.disabled = true
	add_child(fire_button)
	
	# Cancel button
	cancel_button = Button.new()
	cancel_button.text = "CANCEL"
	cancel_button.position = Vector2(btn_margin, panel_height - (btn_height + margin))
	cancel_button.size = Vector2(panel_width - btn_margin * 2 - 20 * scale_factor, btn_height)
	cancel_button.add_theme_font_size_override("font_size", int(22 * scale_factor))
	cancel_button.add_theme_stylebox_override("normal", _styles.create_negative_button_style())
	cancel_button.add_theme_stylebox_override("hover", _styles.create_negative_button_hover_style())
	cancel_button.add_theme_stylebox_override("pressed", _styles.create_negative_button_hover_style())
	cancel_button.pressed.connect(_on_cancel_pressed)
	add_child(cancel_button)

func _create_weapon_info_panel(screen_size: Vector2, margin: float) -> void:
	var info_panel_width = screen_size.x * 0.75
	var info_panel_height = screen_size.y * 0.65
	
	weapon_info_panel = Panel.new()
	weapon_info_panel.position = Vector2(
		(screen_size.x - info_panel_width) / 2 - position.x,
		(screen_size.y - info_panel_height) / 2 - 30 * scale_factor - position.y
	)
	weapon_info_panel.size = Vector2(info_panel_width, info_panel_height)
	weapon_info_panel.visible = false
	weapon_info_panel.z_index = 100
	weapon_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	weapon_info_panel.add_theme_stylebox_override("panel", _styles.create_weapon_info_panel_style())
	add_child(weapon_info_panel)
	
	# Header
	var info_header = Panel.new()
	info_header.position = Vector2(0, 0)
	info_header.size = Vector2(info_panel_width, 50 * scale_factor)
	info_header.add_theme_stylebox_override("panel", _styles.create_weapon_info_header_style())
	weapon_info_panel.add_child(info_header)
	
	# Weapon name
	weapon_info_name_label = Label.new()
	weapon_info_name_label.text = "WEAPON NAME"
	weapon_info_name_label.position = Vector2(margin * 2, 8 * scale_factor)
	weapon_info_name_label.size = Vector2(info_panel_width - margin * 4 - 50 * scale_factor, 35 * scale_factor)
	weapon_info_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_info_name_label.add_theme_font_size_override("font_size", int(22 * scale_factor))
	weapon_info_name_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	weapon_info_name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.3))
	weapon_info_name_label.add_theme_constant_override("outline_size", 2)
	weapon_info_panel.add_child(weapon_info_name_label)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(info_panel_width - 48 * scale_factor, 8 * scale_factor)
	close_btn.size = Vector2(38 * scale_factor, 34 * scale_factor)
	close_btn.add_theme_stylebox_override("normal", _styles.create_close_button_style())
	close_btn.add_theme_stylebox_override("hover", _styles.create_close_button_hover_style())
	close_btn.add_theme_font_size_override("font_size", int(20 * scale_factor))
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.pressed.connect(_on_close_weapon_info)
	weapon_info_panel.add_child(close_btn)
	
	# Weapon type
	weapon_info_type_label = Label.new()
	weapon_info_type_label.text = "ENERGY WEAPON"
	weapon_info_type_label.position = Vector2(margin * 2, 42 * scale_factor)
	weapon_info_type_label.size = Vector2(info_panel_width - margin * 4, 20 * scale_factor)
	weapon_info_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_info_type_label.add_theme_font_size_override("font_size", int(14 * scale_factor))
	weapon_info_type_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	weapon_info_panel.add_child(weapon_info_type_label)
	
	# Scroll container
	weapon_info_scroll = ScrollContainer.new()
	weapon_info_scroll.position = Vector2(margin, 58 * scale_factor)
	weapon_info_scroll.size = Vector2(info_panel_width - margin * 2, info_panel_height - 68 * scale_factor)
	weapon_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	weapon_info_panel.add_child(weapon_info_scroll)
	
	# Content container
	weapon_info_content = VBoxContainer.new()
	weapon_info_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_info_scroll.add_child(weapon_info_content)
	
	# RichTextLabel
	weapon_info_label = RichTextLabel.new()
	weapon_info_label.bbcode_enabled = true
	weapon_info_label.fit_content = true
	weapon_info_label.scroll_active = false
	weapon_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_info_label.add_theme_font_size_override("normal_font_size", int(16 * scale_factor))
	weapon_info_label.add_theme_font_size_override("bold_font_size", int(17 * scale_factor))
	weapon_info_content.add_child(weapon_info_label)

# ============================================
# API PÚBLICA
# ============================================

func show_selector(attacker, target, range_hexes: int) -> void:
	if not attacker:
		return
	
	_current_attacker = attacker
	_current_target = target
	_current_range = range_hexes
	
	# Update title
	if title_label:
		title_label.text = "%s attacking %s - SELECT WEAPONS" % [attacker.mech_name, target.mech_name]
	
	# Clear previous
	_clear_weapon_buttons()
	selected_weapons.clear()
	fire_button.disabled = true
	
	# Create weapon rows
	var y_pos = 50
	var weapon_index = 0
	
	for weapon in attacker.weapons:
		var weapon_attack_sys = preload("res://scripts/core/combat/weapon_attack_system.gd")
		var to_hit_data = weapon_attack_sys.calculate_to_hit(attacker, target, weapon, range_hexes)
		var target_number = to_hit_data["target_number"]
		var breakdown = to_hit_data.get("breakdown", "")
		
		var weapon_info = "%s (Dmg:%d Heat:%d)  To-Hit: %d" % [
			weapon.get("name", "Unknown"),
			weapon.get("damage", 0),
			weapon.get("heat", 0),
			target_number
		]
		
		var in_range = _is_weapon_in_range(weapon, range_hexes)
		if not in_range:
			weapon_info += "  [OUT OF RANGE]"
		
		# HBox for label + switch
		var hbox = HBoxContainer.new()
		hbox.position = Vector2(20, y_pos)
		hbox.size = Vector2(480, 40)
		hbox.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(hbox)
		
		# Clickable label
		var weapon_label = Label.new()
		weapon_label.text = weapon_info
		weapon_label.add_theme_font_size_override("font_size", 14)
		weapon_label.custom_minimum_size = Vector2(420, 40)
		weapon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		weapon_label.mouse_filter = Control.MOUSE_FILTER_STOP
		weapon_label.tooltip_text = breakdown
		weapon_label.gui_input.connect(_on_weapon_label_clicked.bind(weapon_index, weapon, breakdown, to_hit_data))
		hbox.add_child(weapon_label)
		
		# Switch
		var weapon_switch = _create_switch(weapon_index, in_range)
		hbox.add_child(weapon_switch)
		
		weapon_buttons.append(weapon_switch)
		y_pos += 45
		weapon_index += 1
	
	visible = true

func hide_selector() -> void:
	visible = false
	selected_weapons.clear()
	if weapon_info_panel:
		weapon_info_panel.visible = false

func is_visible_panel() -> bool:
	return visible

func is_point_over_panel(screen_pos: Vector2) -> bool:
	if visible:
		var rect = get_global_rect()
		if rect.has_point(screen_pos):
			return true
	if weapon_info_panel and weapon_info_panel.visible:
		var rect = weapon_info_panel.get_global_rect()
		if rect.has_point(screen_pos):
			return true
	return false

# ============================================
# HELPERS PRIVADOS
# ============================================

func _clear_weapon_buttons() -> void:
	for btn in weapon_buttons:
		if btn and is_instance_valid(btn):
			var parent = btn.get_parent()
			if parent and parent is HBoxContainer:
				parent.queue_free()
			else:
				btn.queue_free()
	weapon_buttons.clear()

func _is_weapon_in_range(weapon: Dictionary, range_hexes: int) -> bool:
	var long_range = weapon.get("long_range", 9)
	var min_range = weapon.get("min_range", 0)
	return range_hexes >= min_range and range_hexes <= long_range

func _create_switch(weapon_index: int, enabled: bool) -> Control:
	var switch_container = Control.new()
	switch_container.custom_minimum_size = Vector2(60, 40)
	switch_container.mouse_filter = Control.MOUSE_FILTER_STOP
	switch_container.set_meta("toggled", false)
	switch_container.set_meta("enabled", enabled)
	
	var bg_panel = Panel.new()
	bg_panel.position = Vector2(10, 10)
	bg_panel.size = Vector2(40, 20)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style = _styles.create_switch_background_style(enabled)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	bg_panel.set_meta("style", bg_style)
	switch_container.add_child(bg_panel)
	
	var slider = Panel.new()
	slider.position = Vector2(12, 12)
	slider.size = Vector2(16, 16)
	slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slider_style = _styles.create_switch_slider_style(enabled)
	slider.add_theme_stylebox_override("panel", slider_style)
	slider.set_meta("style", slider_style)
	switch_container.add_child(slider)
	
	switch_container.set_meta("bg_panel", bg_panel)
	switch_container.set_meta("slider", slider)
	
	if enabled:
		switch_container.gui_input.connect(_on_switch_clicked.bind(switch_container, weapon_index))
	
	return switch_container

func _on_switch_clicked(event: InputEvent, switch_control: Control, weapon_index: int) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	switch_control.get_viewport().set_input_as_handled()
	
	var enabled = switch_control.get_meta("enabled")
	if not enabled:
		return
	
	var is_toggled = not switch_control.get_meta("toggled")
	switch_control.set_meta("toggled", is_toggled)
	
	var bg_panel = switch_control.get_meta("bg_panel")
	var slider = switch_control.get_meta("slider")
	var bg_style = bg_panel.get_meta("style")
	var slider_style = slider.get_meta("style")
	
	if is_toggled:
		bg_style.bg_color = Color(0.1, 0.4, 0.5, 0.9)
		bg_style.border_color = Color(0.3, 0.7, 1, 1)
		slider_style.bg_color = Color(0.5, 0.9, 1, 1)
		slider_style.shadow_color = Color(0.5, 0.9, 1, 0.8)
		slider_style.shadow_size = 5
		slider.position.x = 32
	else:
		bg_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
		bg_style.border_color = Color(0.3, 0.5, 0.7, 0.9)
		slider_style.bg_color = Color(0.6, 0.6, 0.7, 1)
		slider_style.shadow_color = Color(0.3, 0.5, 0.7, 0.5)
		slider_style.shadow_size = 3
		slider.position.x = 12
	
	bg_panel.queue_redraw()
	slider.queue_redraw()
	
	_on_weapon_toggled(is_toggled, weapon_index)

func _on_weapon_toggled(button_pressed: bool, weapon_index: int) -> void:
	if button_pressed:
		if weapon_index not in selected_weapons:
			selected_weapons.append(weapon_index)
	else:
		selected_weapons.erase(weapon_index)
	
	fire_button.disabled = (selected_weapons.size() == 0)

func _on_weapon_label_clicked(event: InputEvent, _weapon_index: int, weapon: Dictionary, _breakdown: String, to_hit_data: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_show_weapon_info(weapon, to_hit_data)

func _show_weapon_info(weapon: Dictionary, to_hit_data: Dictionary) -> void:
	if not weapon_info_panel or not weapon_info_label:
		return
	
	weapon_info_panel.visible = true
	
	var weapon_icon = _get_weapon_type_icon(weapon.get("type", "energy"))
	var weapon_name = weapon.get("name", "Unknown Weapon")
	if weapon_info_name_label:
		weapon_info_name_label.text = "%s  %s" % [weapon_icon, weapon_name]
	
	var weapon_type = weapon.get("type", "energy")
	var weapon_type_str = _get_weapon_type_name(weapon_type)
	var type_color = _get_weapon_type_color(weapon_type)
	if weapon_info_type_label:
		weapon_info_type_label.text = "▸ %s WEAPON ◂" % weapon_type_str.to_upper()
		weapon_info_type_label.add_theme_color_override("font_color", Color.from_string(type_color, Color.WHITE))
	
	weapon_info_label.text = _build_weapon_info_text(weapon, to_hit_data)

func _build_weapon_info_text(weapon: Dictionary, to_hit_data: Dictionary) -> String:
	var info_text = ""
	
	# COMBAT STATS
	info_text += "[color=#50A0D0]╔════════════════════════════════════════════════════════╗[/color]\n"
	info_text += "[color=#50A0D0]║[/color]  [color=#FFB030][b]⚔ COMBAT STATISTICS[/b][/color]\n"
	info_text += "[color=#50A0D0]╠════════════════════════════════════════════════════════╣[/color]\n"
	
	var damage = weapon.get("damage", 0)
	info_text += "[color=#50A0D0]║[/color]  [color=#A0A0A0]Damage Output:[/color]      [color=#FF5050][b]%d[/b][/color] [color=#808080]points[/color]\n" % damage
	
	var heat = weapon.get("heat", 0)
	info_text += "[color=#50A0D0]║[/color]  [color=#A0A0A0]Heat Generated:[/color]     [color=#FF8030][b]%d[/b][/color] [color=#808080]heat[/color]\n" % heat
	
	if weapon.get("requires_ammo", false):
		var ammo = weapon.get("ammo", 0)
		var ammo_color = "#40FF40" if ammo > 5 else ("#FFFF40" if ammo > 2 else "#FF4040")
		info_text += "[color=#50A0D0]║[/color]  [color=#A0A0A0]Ammunition:[/color]         [color=%s][b]%d[/b][/color] [color=#808080]rounds remaining[/color]\n" % [ammo_color, ammo]
	
	info_text += "[color=#50A0D0]╚════════════════════════════════════════════════════════╝[/color]\n\n"
	
	# RANGE PROFILE
	info_text += "[color=#40B0A0]╔════════════════════════════════════════════════════════╗[/color]\n"
	info_text += "[color=#40B0A0]║[/color]  [color=#40E0D0][b]◎ RANGE PROFILE[/b][/color]\n"
	info_text += "[color=#40B0A0]╠════════════════════════════════════════════════════════╣[/color]\n"
	
	var min_range = weapon.get("min_range", 0)
	var short_range = weapon.get("short_range", 3)
	var medium_range = weapon.get("medium_range", 6)
	var long_range = weapon.get("long_range", 9)
	
	if min_range > 0:
		info_text += "[color=#40B0A0]║[/color]  [color=#FF4040]⊘ Minimum Range:[/color]    [color=#FF4040][b]%d[/b][/color] [color=#808080]hexes (cannot fire)[/color]\n" % min_range
	
	info_text += "[color=#40B0A0]║[/color]  [color=#40FF40]● Short Range:[/color]      [color=#40FF40][b]1-%d[/b][/color] [color=#808080]hexes[/color] [color=#60A060](+0 modifier)[/color]\n" % short_range
	info_text += "[color=#40B0A0]║[/color]  [color=#FFFF40]● Medium Range:[/color]     [color=#FFFF40][b]%d-%d[/b][/color] [color=#808080]hexes[/color] [color=#A0A040](+2 modifier)[/color]\n" % [short_range + 1, medium_range]
	info_text += "[color=#40B0A0]║[/color]  [color=#FFA040]● Long Range:[/color]       [color=#FFA040][b]%d-%d[/b][/color] [color=#808080]hexes[/color] [color=#A06040](+4 modifier)[/color]\n" % [medium_range + 1, long_range]
	
	info_text += "[color=#40B0A0]╚════════════════════════════════════════════════════════╝[/color]\n\n"
	
	# TO-HIT ANALYSIS
	info_text += "[color=#B050D0]╔════════════════════════════════════════════════════════╗[/color]\n"
	info_text += "[color=#B050D0]║[/color]  [color=#E080FF][b]⎯ TO-HIT ANALYSIS[/b][/color]\n"
	info_text += "[color=#B050D0]╠════════════════════════════════════════════════════════╣[/color]\n"
	
	var modifiers = to_hit_data.get("modifiers", {})
	var total_mod = 0
	for mod_name in modifiers.keys():
		var mod_val = modifiers[mod_name]
		total_mod += mod_val
		var color = "#50FF80" if mod_val <= 0 else "#FF6060"
		var formatted_name = str(mod_name).replace("_", " ").capitalize()
		var sign_str = "+" if mod_val > 0 else ""
		info_text += "[color=#B050D0]║[/color]  [color=#A0A0A0]%s:[/color] [color=%s][b]%s%d[/b][/color]\n" % [formatted_name, color, sign_str, mod_val]
	
	info_text += "[color=#B050D0]╠════════════════════════════════════════════════════════╣[/color]\n"
	
	var base_to_hit = to_hit_data.get("base_to_hit", 4)
	var final_to_hit = to_hit_data.get("final_to_hit", base_to_hit + total_mod)
	
	info_text += "[color=#B050D0]║[/color]  [color=#FFD040][b]TARGET NUMBER: %d+[/b][/color] [color=#808080]on 2D6[/color]\n" % final_to_hit
	
	var difficulty_color = "#40FF40" if final_to_hit <= 6 else ("#FFFF40" if final_to_hit <= 9 else "#FF4040")
	var difficulty_text = "Easy" if final_to_hit <= 6 else ("Moderate" if final_to_hit <= 9 else "Difficult")
	info_text += "[color=#B050D0]║[/color]  [color=#808080]Difficulty:[/color] [color=%s][b]%s[/b][/color]\n" % [difficulty_color, difficulty_text]
	
	info_text += "[color=#B050D0]╚════════════════════════════════════════════════════════╝[/color]\n"
	
	return info_text

func _get_weapon_type_icon(weapon_type) -> String:
	if typeof(weapon_type) == TYPE_INT:
		match weapon_type:
			1: return "⚡"
			2: return "●"
			3: return "▲"
			_: return "◆"
	else:
		match str(weapon_type).to_lower():
			"energy": return "⚡"
			"ballistic": return "●"
			"missile": return "▲"
			_: return "◆"

func _get_weapon_type_name(weapon_type) -> String:
	if typeof(weapon_type) == TYPE_INT:
		match weapon_type:
			1: return "ENERGY"
			2: return "BALLISTIC"
			3: return "MISSILE"
			_: return "UNKNOWN"
	else:
		return str(weapon_type).to_upper()

func _get_weapon_type_color(weapon_type) -> String:
	if typeof(weapon_type) == TYPE_INT:
		match weapon_type:
			1: return "#40D0FF"
			2: return "#FFD040"
			3: return "#FF6060"
			_: return "#C0C0C0"
	else:
		match str(weapon_type).to_lower():
			"energy": return "#40D0FF"
			"ballistic": return "#FFD040"
			"missile": return "#FF6060"
			_: return "#C0C0C0"

# ============================================
# EVENTOS
# ============================================

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()

func _on_fire_pressed() -> void:
	weapons_confirmed.emit(_current_attacker, _current_target, selected_weapons, _current_range)
	hide_selector()

func _on_cancel_pressed() -> void:
	selection_cancelled.emit()
	hide_selector()

func _on_close_weapon_info() -> void:
	if weapon_info_panel:
		weapon_info_panel.visible = false
