extends CanvasLayer

@onready var battle_scene = get_parent()

var turn_label: Label
var phase_label: Label
var unit_info_label: Label
var end_turn_button: Button
var help_label: Label
var combat_log: RichTextLabel

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

func _on_unit_activated(unit):
	if unit_info_label and unit:
		var info = "%s - Heat: %d/%d - Armor: %d" % [
			unit.name,
			unit.heat,
			unit.max_heat,
			unit.armor
		]
		unit_info_label.text = info

func _on_end_turn_pressed():
	if battle_scene and battle_scene.has_method("end_current_activation"):
		battle_scene.end_current_activation()

func add_combat_message(message: String):
	if combat_log:
		combat_log.append_text(message + "\n")

func set_help_text(text: String):
	if help_label:
		help_label.text = text

func update_end_turn_button(enabled: bool, text: String = "End Activation"):
	if end_turn_button:
		end_turn_button.disabled = not enabled
		end_turn_button.text = text
