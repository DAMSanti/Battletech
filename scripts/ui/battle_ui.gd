extends CanvasLayer

@onready var battle_scene = get_parent()

var turn_label: Label
var phase_label: Label
var unit_info_label: Label
var end_turn_button: Button
var help_label: Label
var combat_log: RichTextLabel

# Selector de tipo de movimiento
var movement_selector_panel: Panel
var walk_button: Button
var run_button: Button
var jump_button: Button

# Selector de armas para disparo
var weapon_selector_panel: Panel
var weapon_buttons: Array = []
var selected_weapons: Array = []
var fire_button: Button
var cancel_weapon_button: Button

# Selector de ataque físico
var physical_attack_panel: Panel
var punch_left_button: Button
var punch_right_button: Button
var kick_button: Button
var charge_button: Button
var cancel_physical_button: Button

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
	# Panel de información superior
	var info_panel = Panel.new()
	info_panel.position = Vector2(10, 10)
	info_panel.size = Vector2(400, 200)
	add_child(info_panel)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(15, 15)
	vbox.size = Vector2(370, 170)
	info_panel.add_child(vbox)
	
	turn_label = Label.new()
	turn_label.text = "Turn: 1"
	turn_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(turn_label)
	
	phase_label = Label.new()
	phase_label.text = "Phase: Movement"
	phase_label.add_theme_font_size_override("font_size", 18)
	phase_label.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(phase_label)
	
	unit_info_label = Label.new()
	unit_info_label.text = "No unit selected"
	unit_info_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(unit_info_label)
	
	# Label de ayuda
	help_label = Label.new()
	help_label.text = ""
	help_label.add_theme_font_size_override("font_size", 16)
	help_label.add_theme_color_override("font_color", Color.YELLOW)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	help_label.custom_minimum_size = Vector2(370, 40)
	vbox.add_child(help_label)
	
	# Botón de fin de turno
	end_turn_button = Button.new()
	end_turn_button.text = "End Activation"
	end_turn_button.position = Vector2(10, 220)
	end_turn_button.size = Vector2(200, 50)
	end_turn_button.add_theme_font_size_override("font_size", 18)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	add_child(end_turn_button)
	
	# Log de combate
	var log_panel = Panel.new()
	log_panel.position = Vector2(10, 1600)
	log_panel.size = Vector2(1060, 300)
	add_child(log_panel)
	
	var log_title = Label.new()
	log_title.text = "Combat Log:"
	log_title.position = Vector2(15, 10)
	log_title.add_theme_font_size_override("font_size", 16)
	log_panel.add_child(log_title)
	
	combat_log = RichTextLabel.new()
	combat_log.position = Vector2(15, 40)
	combat_log.size = Vector2(1030, 250)
	combat_log.bbcode_enabled = true
	combat_log.scroll_following = true
	log_panel.add_child(combat_log)
	
	# Panel selector de tipo de movimiento (inicialmente oculto)
	movement_selector_panel = Panel.new()
	movement_selector_panel.position = Vector2(400, 800)
	movement_selector_panel.size = Vector2(280, 240)
	movement_selector_panel.visible = false
	add_child(movement_selector_panel)
	
	var selector_title = Label.new()
	selector_title.text = "SELECT MOVEMENT TYPE"
	selector_title.position = Vector2(20, 10)
	selector_title.add_theme_font_size_override("font_size", 18)
	selector_title.add_theme_color_override("font_color", Color.GOLD)
	movement_selector_panel.add_child(selector_title)
	
	walk_button = Button.new()
	walk_button.text = "WALK"
	walk_button.position = Vector2(20, 50)
	walk_button.size = Vector2(240, 50)
	walk_button.add_theme_font_size_override("font_size", 20)
	walk_button.pressed.connect(_on_walk_pressed)
	movement_selector_panel.add_child(walk_button)
	
	run_button = Button.new()
	run_button.text = "RUN"
	run_button.position = Vector2(20, 110)
	run_button.size = Vector2(240, 50)
	run_button.add_theme_font_size_override("font_size", 20)
	run_button.pressed.connect(_on_run_pressed)
	movement_selector_panel.add_child(run_button)
	
	jump_button = Button.new()
	jump_button.text = "JUMP"
	jump_button.position = Vector2(20, 170)
	jump_button.size = Vector2(240, 50)
	jump_button.add_theme_font_size_override("font_size", 20)
	jump_button.pressed.connect(_on_jump_pressed)
	movement_selector_panel.add_child(jump_button)
	
	# Panel selector de armas (inicialmente oculto)
	weapon_selector_panel = Panel.new()
	weapon_selector_panel.position = Vector2(300, 400)
	weapon_selector_panel.size = Vector2(480, 600)
	weapon_selector_panel.visible = false
	add_child(weapon_selector_panel)
	
	var weapon_title = Label.new()
	weapon_title.text = "SELECT WEAPONS TO FIRE"
	weapon_title.position = Vector2(20, 10)
	weapon_title.add_theme_font_size_override("font_size", 20)
	weapon_title.add_theme_color_override("font_color", Color.GOLD)
	weapon_selector_panel.add_child(weapon_title)
	
	# Los botones de armas se crearán dinámicamente en show_weapon_selector()
	
	# Botón para confirmar disparo
	fire_button = Button.new()
	fire_button.text = "FIRE SELECTED WEAPONS"
	fire_button.position = Vector2(20, 500)
	fire_button.size = Vector2(440, 40)
	fire_button.add_theme_font_size_override("font_size", 18)
	fire_button.pressed.connect(_on_fire_weapons_pressed)
	weapon_selector_panel.add_child(fire_button)
	
	# Botón para cancelar
	cancel_weapon_button = Button.new()
	cancel_weapon_button.text = "CANCEL"
	cancel_weapon_button.position = Vector2(20, 550)
	cancel_weapon_button.size = Vector2(440, 40)
	cancel_weapon_button.add_theme_font_size_override("font_size", 18)
	cancel_weapon_button.pressed.connect(_on_cancel_weapons_pressed)
	weapon_selector_panel.add_child(cancel_weapon_button)
	
	# Panel selector de ataque físico (inicialmente oculto)
	physical_attack_panel = Panel.new()
	physical_attack_panel.position = Vector2(350, 500)
	physical_attack_panel.size = Vector2(380, 400)
	physical_attack_panel.visible = false
	add_child(physical_attack_panel)
	
	var physical_title = Label.new()
	physical_title.text = "SELECT PHYSICAL ATTACK"
	physical_title.position = Vector2(20, 10)
	physical_title.add_theme_font_size_override("font_size", 20)
	physical_title.add_theme_color_override("font_color", Color.MAGENTA)
	physical_attack_panel.add_child(physical_title)
	
	# Botón puñetazo izquierdo
	punch_left_button = Button.new()
	punch_left_button.text = "PUNCH (Left Arm)"
	punch_left_button.position = Vector2(20, 60)
	punch_left_button.size = Vector2(340, 50)
	punch_left_button.add_theme_font_size_override("font_size", 18)
	punch_left_button.pressed.connect(_on_punch_left_pressed)
	physical_attack_panel.add_child(punch_left_button)
	
	# Botón puñetazo derecho
	punch_right_button = Button.new()
	punch_right_button.text = "PUNCH (Right Arm)"
	punch_right_button.position = Vector2(20, 120)
	punch_right_button.size = Vector2(340, 50)
	punch_right_button.add_theme_font_size_override("font_size", 18)
	punch_right_button.pressed.connect(_on_punch_right_pressed)
	physical_attack_panel.add_child(punch_right_button)
	
	# Botón patada
	kick_button = Button.new()
	kick_button.text = "KICK"
	kick_button.position = Vector2(20, 180)
	kick_button.size = Vector2(340, 50)
	kick_button.add_theme_font_size_override("font_size", 18)
	kick_button.pressed.connect(_on_kick_pressed)
	physical_attack_panel.add_child(kick_button)
	
	# Botón embestida
	charge_button = Button.new()
	charge_button.text = "CHARGE"
	charge_button.position = Vector2(20, 240)
	charge_button.size = Vector2(340, 50)
	charge_button.add_theme_font_size_override("font_size", 18)
	charge_button.pressed.connect(_on_charge_pressed)
	physical_attack_panel.add_child(charge_button)
	
	# Botón cancelar
	cancel_physical_button = Button.new()
	cancel_physical_button.text = "CANCEL"
	cancel_physical_button.position = Vector2(20, 320)
	cancel_physical_button.size = Vector2(340, 50)
	cancel_physical_button.add_theme_font_size_override("font_size", 18)
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
		var info = "%s - Heat: %d/%d - Armor: %d" % [
			unit.name,
			unit.heat,
			unit.heat_capacity,
			unit.armor
		]
		unit_info_label.text = info

func update_unit_info(unit):
	# Alias para _on_unit_activated para compatibilidad
	_on_unit_activated(unit)

func update_phase_info(phase: String):
	# Alias para _on_phase_changed para compatibilidad
	_on_phase_changed(phase)

func _on_end_turn_pressed():
	if battle_scene and battle_scene.has_method("end_current_activation"):
		battle_scene.end_current_activation()

func add_combat_message(message: String, color: Color = Color.WHITE):
	if combat_log:
		combat_log.push_color(color)
		combat_log.append_text(message + "\n")
		combat_log.pop()

func set_help_text(text: String):
	if help_label:
		help_label.text = text

func update_end_turn_button(enabled: bool, text: String = "End Activation"):
	if end_turn_button:
		end_turn_button.disabled = not enabled
		end_turn_button.text = text

## SELECTOR DE TIPO DE MOVIMIENTO ##

func show_movement_type_selector(unit):
	print("═══════════════════════════════════════════════════")
	print("DEBUG: show_movement_type_selector CALLED")
	print("  Unit: ", unit.mech_name)
	print("  Called from:")
	var stack = get_stack()
	for i in range(min(5, stack.size())):  # Mostrar las primeras 5 líneas del stack
		var frame = stack[i]
		print("    [", i, "] ", frame.source, ":", frame.line, " in ", frame.function)
	print("═══════════════════════════════════════════════════")
	
	# Muestra el selector con información del mech
	if movement_selector_panel:
		print("DEBUG: Setting panel visible to true")
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
		print("DEBUG: Panel visible = ", movement_selector_panel.visible)
	else:
		print("ERROR: movement_selector_panel is null!")

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
	add_combat_message("Select physical attack type for %s" % attacker.mech_name, Color.MAGENTA)

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
	
	# Limpiar botones de armas anteriores
	for btn in weapon_buttons:
		btn.queue_free()
	weapon_buttons.clear()
	selected_weapons.clear()
	
	# Almacenar información del ataque actual
	weapon_selector_panel.set_meta("attacker", attacker)
	weapon_selector_panel.set_meta("target", target)
	weapon_selector_panel.set_meta("range", range_hexes)
	
	# Crear botones para cada arma
	var y_pos = 50
	var weapon_index = 0
	
	for weapon in attacker.weapons:
		var weapon_btn = CheckButton.new()
		
		# Información del arma
		var weapon_info = "%s (Dmg:%d Heat:%d)" % [
			weapon.get("name", "Unknown"),
			weapon.get("damage", 0),
			weapon.get("heat", 0)
		]
		
		# Verificar si está en rango
		var in_range = _is_weapon_in_range(weapon, range_hexes)
		if not in_range:
			weapon_info += " [OUT OF RANGE]"
			weapon_btn.disabled = true
		
		weapon_btn.text = weapon_info
		weapon_btn.position = Vector2(20, y_pos)
		weapon_btn.size = Vector2(440, 40)
		weapon_btn.set_meta("weapon_index", weapon_index)
		weapon_btn.toggled.connect(_on_weapon_toggled.bind(weapon_index))
		
		weapon_selector_panel.add_child(weapon_btn)
		weapon_buttons.append(weapon_btn)
		
		y_pos += 50
		weapon_index += 1
	
	# Mostrar panel
	weapon_selector_panel.visible = true
	
	# Mensaje en el log
	add_combat_message("Select weapons to fire at %s (Range: %d hexes)" % [target.mech_name, range_hexes], Color.CYAN)

func hide_weapon_selector():
	if weapon_selector_panel:
		weapon_selector_panel.visible = false
		selected_weapons.clear()

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
