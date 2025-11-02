
extends CanvasLayer
var scale_factor := 1.0
var margin := 10.0

@onready var battle_scene = get_parent()

var turn_label: Label
var phase_label: Label
var unit_info_label: Label
var armor_panel: Control = null
var end_turn_button: Button
var help_label: Label
var combat_log: RichTextLabel
var combat_log_mode: String = "full"  # "full" o "short"
var full_button: Button
var short_button: Button
var message_history: Array = []  # Almacenar todos los mensajes [{text: String, color: Color}]

# Selector de tipo de movimiento
var movement_selector_panel: Panel
var movement_selector_title: Label
var walk_button: Button
var run_button: Button
var jump_button: Button

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
	
	# Panel de información superior (20% del ancho de pantalla)
	var info_panel = Panel.new()
	info_panel.position = Vector2(margin, margin)
	info_panel.size = Vector2(screen_width * 0.95, screen_height * 0.18)
	add_child(info_panel)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(margin, margin)
	vbox.size = Vector2(info_panel.size.x - margin * 2, info_panel.size.y - margin * 2)
	info_panel.add_child(vbox)
	
	turn_label = Label.new()
	turn_label.text = "Turn: 1"
	turn_label.add_theme_font_size_override("font_size", int(24 * scale_factor))
	vbox.add_child(turn_label)
	
	phase_label = Label.new()
	phase_label.text = "Phase: Movement"
	phase_label.add_theme_font_size_override("font_size", int(20 * scale_factor))
	phase_label.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(phase_label)
	
	unit_info_label = Label.new()
	unit_info_label.text = "No unit selected"
	unit_info_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
	vbox.add_child(unit_info_label)

	# Panel gráfico de armadura alineado a la derecha dentro del vbox (CustomArmorPanel)
	var CustomArmorPanel = load("res://scripts/ui/custom_armor_panel.gd")
	armor_panel = CustomArmorPanel.new()
	armor_panel.custom_minimum_size = Vector2(180 * scale_factor, vbox.size.y)
	armor_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	armor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(armor_panel)
	
	# Label de ayuda
	help_label = Label.new()
	help_label.text = ""
	help_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
	help_label.add_theme_color_override("font_color", Color.YELLOW)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	help_label.custom_minimum_size = Vector2(vbox.size.x, 40 * scale_factor)
	vbox.add_child(help_label)
	
	# Botón de fin de turno
	end_turn_button = Button.new()
	end_turn_button.text = "End Activation"
	end_turn_button.position = Vector2(margin, info_panel.position.y + info_panel.size.y + margin)
	end_turn_button.size = Vector2(screen_width * 0.95, 70 * scale_factor)
	end_turn_button.add_theme_font_size_override("font_size", int(22 * scale_factor))
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	add_child(end_turn_button)
	
	# Log de combate (en la parte inferior, 23% de la altura)
	var log_height = screen_height * 0.23
	var log_panel = Panel.new()
	log_panel.position = Vector2(margin, screen_height - log_height - margin)
	log_panel.size = Vector2(screen_width * 0.95, log_height)
	add_child(log_panel)
	
	var log_title = Label.new()
	log_title.text = "Combat Log:"
	log_title.position = Vector2(margin, margin)
	log_title.add_theme_font_size_override("font_size", int(18 * scale_factor))
	log_panel.add_child(log_title)
	
	# Botones de modo Full/Short (a la derecha del título)
	var log_button_y = margin
	var log_button_width = 60 * scale_factor
	var log_button_height = 25 * scale_factor
	var log_button_x_start = log_panel.size.x - margin - log_button_width * 2 - 5 * scale_factor
	
	full_button = Button.new()
	full_button.text = "FULL"
	full_button.position = Vector2(log_button_x_start, log_button_y)
	full_button.size = Vector2(log_button_width, log_button_height)
	full_button.add_theme_font_size_override("font_size", int(12 * scale_factor))
	full_button.pressed.connect(_on_log_mode_changed.bind("full"))
	log_panel.add_child(full_button)
	
	short_button = Button.new()
	short_button.text = "SHORT"
	short_button.position = Vector2(log_button_x_start + log_button_width + 5 * scale_factor, log_button_y)
	short_button.size = Vector2(log_button_width, log_button_height)
	short_button.add_theme_font_size_override("font_size", int(12 * scale_factor))
	short_button.pressed.connect(_on_log_mode_changed.bind("short"))
	log_panel.add_child(short_button)
	
	# Actualizar visual de botones
	_update_log_mode_buttons()
	
	combat_log = RichTextLabel.new()
	combat_log.position = Vector2(margin, 35 * scale_factor)
	combat_log.size = Vector2(log_panel.size.x - margin * 2, log_panel.size.y - 40 * scale_factor)
	combat_log.bbcode_enabled = true
	combat_log.scroll_following = true
	combat_log.mouse_filter = Control.MOUSE_FILTER_STOP  # Evita que el scroll pase a la cámara
	combat_log.add_theme_font_size_override("normal_font_size", int(14 * scale_factor))
	log_panel.add_child(combat_log)
	
	# Panel selector de tipo de movimiento (centrado, 50% del ancho)
	var movement_panel_width = screen_width * 0.85
	var movement_panel_height = screen_height * 0.35
	movement_selector_panel = Panel.new()
	movement_selector_panel.position = Vector2((screen_width - movement_panel_width) / 2, (screen_height - movement_panel_height) / 2)
	movement_selector_panel.size = Vector2(movement_panel_width, movement_panel_height)
	movement_selector_panel.visible = false
	add_child(movement_selector_panel)
	
	movement_selector_title = Label.new()
	movement_selector_title.text = "SELECT MOVEMENT TYPE"
	movement_selector_title.position = Vector2(margin, margin)
	movement_selector_title.add_theme_font_size_override("font_size", int(20 * scale_factor))
	movement_selector_title.add_theme_color_override("font_color", Color.GOLD)
	movement_selector_panel.add_child(movement_selector_title)
	
	var button_height = (movement_panel_height - 80 * scale_factor) / 3
	var button_width = movement_panel_width - margin * 2
	
	walk_button = Button.new()
	walk_button.text = "WALK"
	walk_button.position = Vector2(margin, 50 * scale_factor)
	walk_button.size = Vector2(button_width, button_height)
	walk_button.add_theme_font_size_override("font_size", int(26 * scale_factor))
	walk_button.pressed.connect(_on_walk_pressed)
	movement_selector_panel.add_child(walk_button)
	
	run_button = Button.new()
	run_button.text = "RUN"
	run_button.position = Vector2(margin, 50 * scale_factor + button_height + 5)
	run_button.size = Vector2(button_width, button_height)
	run_button.add_theme_font_size_override("font_size", int(26 * scale_factor))
	run_button.pressed.connect(_on_run_pressed)
	movement_selector_panel.add_child(run_button)
	
	jump_button = Button.new()
	jump_button.text = "JUMP"
	jump_button.position = Vector2(margin, 50 * scale_factor + (button_height + 5) * 2)
	jump_button.size = Vector2(button_width, button_height)
	jump_button.add_theme_font_size_override("font_size", int(26 * scale_factor))
	jump_button.pressed.connect(_on_jump_pressed)
	movement_selector_panel.add_child(jump_button)
	
	# Panel selector de armas (85% del ancho, 65% de la altura)
	var weapon_panel_width = screen_width * 0.85
	var weapon_panel_height = screen_height * 0.65
	weapon_selector_panel = Panel.new()
	weapon_selector_panel.position = Vector2((screen_width - weapon_panel_width) / 2, (screen_height - weapon_panel_height) / 2)
	weapon_selector_panel.size = Vector2(weapon_panel_width, weapon_panel_height)
	weapon_selector_panel.visible = false
	add_child(weapon_selector_panel)
	
	weapon_selector_title = Label.new()
	weapon_selector_title.text = "SELECT WEAPONS TO FIRE"
	weapon_selector_title.position = Vector2(margin, margin)
	weapon_selector_title.add_theme_font_size_override("font_size", int(20 * scale_factor))
	weapon_selector_title.add_theme_color_override("font_color", Color.GOLD)
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
	
	# Panel de información detallada de arma (dentro del selector, lado derecho)
	var info_panel_width = weapon_panel_width * 0.45
	var info_panel_height = weapon_panel_height * 0.75
	weapon_info_panel = Panel.new()
	weapon_info_panel.position = Vector2(weapon_panel_width * 0.52, 50 * scale_factor)
	weapon_info_panel.size = Vector2(info_panel_width, info_panel_height)
	weapon_info_panel.visible = false
	
	# Crear StyleBox para fondo opaco
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 1.0)  # Azul oscuro opaco
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.CYAN
	weapon_info_panel.add_theme_stylebox_override("panel", style_box)
	
	weapon_selector_panel.add_child(weapon_info_panel)
	
	var info_title = Label.new()
	info_title.text = "WEAPON INFO"
	info_title.position = Vector2(margin, margin)
	info_title.add_theme_font_size_override("font_size", int(18 * scale_factor))
	info_title.add_theme_color_override("font_color", Color.CYAN)
	weapon_info_panel.add_child(info_title)
	
	# Botón para cerrar el panel de info
	var close_info_button = Button.new()
	close_info_button.text = "X"
	close_info_button.position = Vector2(info_panel_width - 40 * scale_factor, margin)
	close_info_button.size = Vector2(30 * scale_factor, 30 * scale_factor)
	close_info_button.add_theme_font_size_override("font_size", int(18 * scale_factor))
	close_info_button.pressed.connect(_on_close_weapon_info_pressed)
	weapon_info_panel.add_child(close_info_button)
	
	weapon_info_label = RichTextLabel.new()
	weapon_info_label.position = Vector2(margin, 40 * scale_factor)
	weapon_info_label.size = Vector2(info_panel_width - margin * 2, info_panel_height - 50 * scale_factor)
	weapon_info_label.bbcode_enabled = true
	weapon_info_label.fit_content = true
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

func _on_turn_changed(turn_number: int):
	if turn_label:
		turn_label.text = "Turn: " + str(turn_number)

func _on_phase_changed(phase_name: String):
	if phase_label:
		phase_label.text = "Phase: " + phase_name
		
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
		turn_label.text = "Turn: %d - %s" % [turn_number, team]

func _on_unit_activated(unit):
	if unit_info_label and unit:
		# Obtener nombre del mech correctamente
		var name = ""
		if "mech_name" in unit:
			name = unit.mech_name
		elif "pilot_name" in unit:
			name = unit.pilot_name
		else:
			name = "Mech"

		var mp = unit.current_movement if "current_movement" in unit else 0
		var heat = unit.heat if "heat" in unit else 0
		var heat_cap = unit.heat_capacity if "heat_capacity" in unit else 0

		# Resumir armadura: suma de valores actuales y máximos
		var armor_str = "?"
		if "armor" in unit and typeof(unit.armor) == TYPE_DICTIONARY:
			var armor_dict = unit.armor
			var armor_current = 0
			var armor_max = 0
			for k in armor_dict.keys():
				armor_current += armor_dict[k]["current"]
				armor_max += armor_dict[k]["max"]
			armor_str = "%d/%d" % [armor_current, armor_max]
		else:
			armor_str = str(unit.armor) if "armor" in unit else "?"

		var info = "%s - MP: %s | Heat: %s/%s" % [name, mp, heat, heat_cap]
		unit_info_label.text = info

		# Mostrar valores individuales de armadura en el panel gráfico
		# SOLO para unidades del jugador, no mostrar armadura de enemigos
		if armor_panel:
			var is_player_unit = false
			if battle_scene and battle_scene.has_method("is_player_mech"):
				is_player_unit = battle_scene.is_player_mech(unit)
			elif battle_scene and "player_mechs" in battle_scene:
				is_player_unit = unit in battle_scene.player_mechs
			
			if is_player_unit:
				if unit.has_method("get_armor_data_for_ui"):
					armor_panel.set_armor(unit.get_armor_data_for_ui())
				elif "armor" in unit and typeof(unit.armor) == TYPE_DICTIONARY:
					armor_panel.set_armor(unit.armor)
				else:
					armor_panel.set_armor(null)
			# No actualizar el panel si es un enemigo, mantener el estado anterior

func update_unit_info(unit):
	# Alias para _on_unit_activated para compatibilidad
	_on_unit_activated(unit)

func update_phase_info(phase: String):
	# Alias para _on_phase_changed para compatibilidad
	_on_phase_changed(phase)

func _on_end_turn_pressed():
	if battle_scene and battle_scene.has_method("end_current_activation"):
		battle_scene.end_current_activation()

func _on_log_mode_changed(mode: String):
	combat_log_mode = mode
	_update_log_mode_buttons()
	_refresh_combat_log()

func _update_log_mode_buttons():
	if full_button and short_button:
		if combat_log_mode == "full":
			full_button.modulate = Color(0.5, 1.0, 0.5)
			short_button.modulate = Color(1.0, 1.0, 1.0)
		else:
			full_button.modulate = Color(1.0, 1.0, 1.0)
			short_button.modulate = Color(0.5, 1.0, 0.5)

func _refresh_combat_log():
	if not combat_log:
		return
	
	# Limpiar el log
	combat_log.clear()
	
	# Regenerar todos los mensajes con el filtrado actual
	for msg_data in message_history:
		_add_message_to_log(msg_data["text"], msg_data["color"])

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
	
	# Añadir al log visible
	_add_message_to_log(message, color)

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
		var frame = stack[i]
	
	# Muestra el selector con información del mech
	if movement_selector_panel:
		# Actualizar título con nombre del mech
		if movement_selector_title:
			movement_selector_title.text = "SELECT MOVEMENT TYPE - %s" % unit.mech_name
		
		# Actualizar textos de botones con MP disponibles
		walk_button.text = "WALK (%d MP)\nNo penalty" % unit.walk_mp
		run_button.text = "RUN (%d MP)\n+1 defense, +2 to fire" % unit.run_mp
		
		if unit.jump_mp > 0:
			jump_button.text = "JUMP (%d MP)\n+2 defense, +3 to fire" % unit.jump_mp
			jump_button.disabled = false
		else:
			jump_button.text = "JUMP (No Jets)"
			jump_button.disabled = true
		
		movement_selector_panel.visible = true

func hide_movement_type_selector():
	# Oculta el selector
	if movement_selector_panel:
		movement_selector_panel.visible = false

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

## ATAQUES FÍSICOS ##

func show_physical_attack_options(attacker, target):
	# Mostrar opciones de ataque físico
	if not physical_attack_panel:
		return
	
	# Almacenar información del ataque
	physical_attack_panel.set_meta("attacker", attacker)
	physical_attack_panel.set_meta("target", target)
	
	# Precargar PhysicalAttackSystem
	const PhysicalAttackSystem = preload("res://scripts/core/combat/physical_attack_system.gd")
	
	# Verificar qué ataques están disponibles
	var can_punch_left = PhysicalAttackSystem.can_punch(attacker, "left")
	var can_punch_right = PhysicalAttackSystem.can_punch(attacker, "right")
	var can_kick = PhysicalAttackSystem.can_kick(attacker)
	var can_charge = PhysicalAttackSystem.can_charge(attacker)
	
	# Habilitar/deshabilitar botones según disponibilidad
	punch_left_button.disabled = not can_punch_left["can_punch"]
	if not can_punch_left["can_punch"]:
		punch_left_button.text = "PUNCH (Left) - %s" % can_punch_left["reason"]
	else:
		var damage = PhysicalAttackSystem.calculate_punch_damage(attacker.tonnage)
		punch_left_button.text = "PUNCH (Left Arm) - Dmg: %d" % damage
	
	punch_right_button.disabled = not can_punch_right["can_punch"]
	if not can_punch_right["can_punch"]:
		punch_right_button.text = "PUNCH (Right) - %s" % can_punch_right["reason"]
	else:
		var damage = PhysicalAttackSystem.calculate_punch_damage(attacker.tonnage)
		punch_right_button.text = "PUNCH (Right Arm) - Dmg: %d" % damage
	
	kick_button.disabled = not can_kick["can_kick"]
	if not can_kick["can_kick"]:
		kick_button.text = "KICK - %s" % can_kick["reason"]
	else:
		var damage = PhysicalAttackSystem.calculate_kick_damage(attacker.tonnage)
		kick_button.text = "KICK - Dmg: %d (Risk: Fall)" % damage
	
	charge_button.disabled = not can_charge["can_charge"]
	if not can_charge["can_charge"]:
		charge_button.text = "CHARGE - %s" % can_charge["reason"]
	else:
		var hexes = attacker.hexes_moved_this_turn if "hexes_moved_this_turn" in attacker else 0
		var damage = PhysicalAttackSystem.calculate_charge_damage(attacker.tonnage, hexes)
		charge_button.text = "CHARGE - Dmg: %d (Self: %d)" % [damage, damage / 10]
	
	# Mostrar panel
	physical_attack_panel.visible = true
	# Mensaje ya mostrado al activar la fase, no repetir aquí

func hide_physical_attack_options():
	# Ocultar opciones de ataque físico
	if physical_attack_panel:
		physical_attack_panel.visible = false

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
	print("[DEBUG] show_weapon_selector - Attacker: %s, Weapons count: %d" % [attacker.mech_name, attacker.weapons.size()])
	
	# Crear filas para cada arma con label clickeable + checkbox separados
	var y_pos = 50
	var weapon_index = 0
	
	for weapon in attacker.weapons:
		print("[DEBUG] Processing weapon: %s" % weapon.get("name", "Unknown"))
		# Calcular modificadores de impacto para esta arma
		var WeaponAttackSystem = preload("res://scripts/core/combat/weapon_attack_system.gd")
		var to_hit_data = WeaponAttackSystem.calculate_to_hit(attacker, target, weapon, range_hexes)
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
		
		# Contenedor horizontal para label + checkbox
		var hbox = HBoxContainer.new()
		hbox.position = Vector2(20, y_pos)
		hbox.size = Vector2(480, 40)
		weapon_selector_panel.add_child(hbox)
		
		# Label clickeable para mostrar info (toma la mayor parte del espacio)
		var weapon_label = Label.new()
		weapon_label.text = weapon_info
		weapon_label.add_theme_font_size_override("font_size", 14)
		weapon_label.custom_minimum_size = Vector2(420, 40)
		weapon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		weapon_label.mouse_filter = Control.MOUSE_FILTER_PASS
		weapon_label.set_meta("weapon_index", weapon_index)
		weapon_label.set_meta("weapon_data", weapon)
		weapon_label.set_meta("breakdown", breakdown)
		weapon_label.set_meta("to_hit_data", to_hit_data)
		
		# Tooltip con el desglose completo
		weapon_label.tooltip_text = breakdown
		
		# Hacer el label clickeable con gui_input
		weapon_label.gui_input.connect(_on_weapon_label_clicked.bind(weapon_index, weapon, breakdown, to_hit_data))
		hbox.add_child(weapon_label)
		
		# CheckButton (switch/toggle) para activar/desactivar el arma
		var weapon_check = CheckButton.new()
		weapon_check.custom_minimum_size = Vector2(60, 40)
		weapon_check.disabled = not in_range
		weapon_check.set_meta("weapon_index", weapon_index)
		weapon_check.toggled.connect(_on_weapon_toggled.bind(weapon_index))
		hbox.add_child(weapon_check)
		
		weapon_buttons.append(weapon_check)
		y_pos += 45
		weapon_index += 1
	
	# Mostrar panel
	weapon_selector_panel.visible = true

func hide_weapon_selector():
	if weapon_selector_panel:
		weapon_selector_panel.visible = false
		selected_weapons.clear()
	if weapon_info_panel:
		weapon_info_panel.visible = false

func _on_weapon_label_clicked(event: InputEvent, weapon_index: int, weapon: Dictionary, breakdown: String, to_hit_data: Dictionary):
	# Mostrar info solo cuando se hace clic en el label (no en el checkbox)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_weapon_clicked(weapon_index, weapon, breakdown, to_hit_data)

func _on_weapon_clicked(weapon_index: int, weapon: Dictionary, breakdown: String, to_hit_data: Dictionary):
	# Mostrar información detallada del arma en el panel de información
	if not weapon_info_panel or not weapon_info_label:
		return
	
	weapon_info_panel.visible = true
	
	# Construir información detallada con BBCode
	var info_text = "[b][color=cyan]%s[/color][/b]\n\n" % weapon.get("name", "Unknown Weapon")
	
	# Estadísticas básicas
	info_text += "[color=yellow]WEAPON STATS[/color]\n"
	info_text += "Damage: [color=red]%d[/color]\n" % weapon.get("damage", 0)
	info_text += "Heat: [color=orange]%d[/color]\n" % weapon.get("heat", 0)
	info_text += "Min Range: [color=white]%d[/color]\n" % weapon.get("min_range", 0)
	info_text += "Short Range: [color=green]%d[/color]\n" % weapon.get("short_range", 3)
	info_text += "Medium Range: [color=yellow]%d[/color]\n" % weapon.get("medium_range", 6)
	info_text += "Long Range: [color=red]%d[/color]\n" % weapon.get("long_range", 9)
	
	# Tipo de arma
	var weapon_type = weapon.get("type", "energy")
	info_text += "\nType: [color=cyan]%s[/color]\n" % weapon_type.capitalize()
	
	# Información de to-hit
	info_text += "\n[color=yellow]TO-HIT CALCULATION[/color]\n"
	info_text += "[color=white]%s[/color]\n" % breakdown.replace("\n", "\n")
	
	# Modifiers individuales
	var modifiers = to_hit_data.get("modifiers", {})
	if modifiers.size() > 0:
		info_text += "\n[color=yellow]MODIFIERS BREAKDOWN[/color]\n"
		for mod_name in modifiers.keys():
			var mod_val = modifiers[mod_name]
			var color = "green" if mod_val <= 0 else "red"
			info_text += "%s: [color=%s]%+d[/color]\n" % [mod_name.replace("_", " ").capitalize(), color, mod_val]
	
	weapon_info_label.text = info_text

func _is_weapon_in_range(weapon: Dictionary, range_hexes: int) -> bool:
	# Verifica si el arma puede disparar a esta distancia
	var long_range = weapon.get("long_range", 9)
	var min_range = weapon.get("min_range", 0)
	
	return range_hexes >= min_range and range_hexes <= long_range

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
	game_over_panel.add_child(vbox)
	
	# Título "BATTLE ENDED"
	var title = Label.new()
	title.text = "⚔ BATTLE ENDED ⚔"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(40 * scale_factor))
	title.add_theme_color_override("font_color", Color.GOLD)
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
	var team = "PLAYER" if mech in battle_scene.player_mechs else "ENEMY"
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

func hide_mech_inspector():
	if mech_inspector_panel:
		mech_inspector_panel.queue_free()
		mech_inspector_panel = null
		mech_inspector_armor = null
	mech_inspector_visible = false

func _on_close_inspector_pressed():
	hide_mech_inspector()
