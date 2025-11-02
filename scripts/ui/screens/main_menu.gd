extends Control

func _ready():
	# TEMPORAL: Regenerar hangar para limpiar datos corruptos
	var mech_bay_manager = get_node_or_null("/root/MechBayManager")
	if mech_bay_manager and mech_bay_manager.force_regenerate_hangar:
		mech_bay_manager.force_regenerate()
	
	# Configurar UI del menú
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -150
	vbox.offset_top = -200
	vbox.offset_right = 150
	vbox.offset_bottom = 200
	add_child(vbox)
	
	# Título
	var title = Label.new()
	title.text = "BATTLETECH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)
	
	vbox.add_child(Control.new())  # Spacer
	
	# Botón de nueva batalla
	var new_battle_btn = Button.new()
	new_battle_btn.text = "New Battle"
	new_battle_btn.custom_minimum_size = Vector2(200, 50)
	new_battle_btn.pressed.connect(_on_new_battle_pressed)
	vbox.add_child(new_battle_btn)
	
	# Botón de mechs
	var mechs_btn = Button.new()
	mechs_btn.text = "Mech Bay"
	mechs_btn.custom_minimum_size = Vector2(200, 50)
	mechs_btn.pressed.connect(_on_mechs_pressed)
	vbox.add_child(mechs_btn)
	
	# Botón de opciones
	var options_btn = Button.new()
	options_btn.text = "Options"
	options_btn.custom_minimum_size = Vector2(200, 50)
	options_btn.pressed.connect(_on_options_pressed)
	vbox.add_child(options_btn)
	
	# Botón de salir
	var quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(200, 50)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

func _on_new_battle_pressed():
	get_tree().change_scene_to_file("res://scenes/battle_scene_simple.tscn")

func _on_mechs_pressed():
	# Abrir Mech Bay
	get_tree().change_scene_to_file("res://scenes/mech_bay_screen.tscn")

func _on_options_pressed():
	pass  # Coming soon

func _on_quit_pressed():
	get_tree().quit()
