extends Control

# Panel de opciones
var options_panel: Panel = null

func _ready():
	# Si estamos en modo headless (servidor dedicado), cambiar a escena de servidor
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		print("[MAIN_MENU] Detected headless/server mode, switching to server scene...")
		get_tree().change_scene_to_file("res://scenes/server_main.tscn")
		return
	
	# TEMPORAL: Regenerar hangar para limpiar datos corruptos
	var mech_bay_manager = get_node_or_null("/root/MechBayManager")
	if mech_bay_manager and mech_bay_manager.force_regenerate_hangar:
		mech_bay_manager.force_regenerate()
	
	# Iniciar música del menú
	if AudioManager:
		AudioManager.play_music(AudioManager.MUSIC_MENU, 2.0)
	
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
	var new_battle_btn = _create_menu_button("New Game")
	new_battle_btn.pressed.connect(_on_new_battle_pressed)
	vbox.add_child(new_battle_btn)
	
	# Botón de mechs
	var mechs_btn = _create_menu_button("Mech Bay")
	mechs_btn.pressed.connect(_on_mechs_pressed)
	vbox.add_child(mechs_btn)
	
	# Botón de loadout avanzado
	var loadout_btn = _create_menu_button("Advanced Loadout")
	loadout_btn.pressed.connect(_on_advanced_loadout_pressed)
	vbox.add_child(loadout_btn)
	
	# Botón de Multiplayer
	var multiplayer_btn = _create_menu_button("Multiplayer")
	multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
	vbox.add_child(multiplayer_btn)
	
	# Botón de opciones
	var options_btn = _create_menu_button("Options")
	options_btn.pressed.connect(_on_options_pressed)
	vbox.add_child(options_btn)
	
	# Botón de salir
	var quit_btn = _create_menu_button("Quit")
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)
	
	# Crear panel de opciones (oculto inicialmente)
	_create_options_panel()

func _create_menu_button(text: String) -> Button:
	"""Crea un botón del menú con sonido de click"""
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 50)
	btn.pressed.connect(_play_click_sound)
	return btn

func _play_click_sound():
	"""Reproduce sonido de click"""
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)

func _create_options_panel():
	"""Crea el panel de opciones de audio"""
	options_panel = Panel.new()
	options_panel.anchor_left = 0.5
	options_panel.anchor_top = 0.5
	options_panel.anchor_right = 0.5
	options_panel.anchor_bottom = 0.5
	options_panel.offset_left = -200
	options_panel.offset_top = -180
	options_panel.offset_right = 200
	options_panel.offset_bottom = 180
	options_panel.visible = false
	
	# Estilo del panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.2, 0.95)
	style.border_color = Color(0.3, 0.6, 0.9, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	options_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 15)
	options_panel.add_child(vbox)
	
	# Título
	var title = Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(title)
	
	# Separador
	vbox.add_child(HSeparator.new())
	
	# Master Volume
	var master_label = Label.new()
	master_label.text = "Master Volume"
	master_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(master_label)
	
	var master_slider = HSlider.new()
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.05
	master_slider.value = AudioManager.master_volume if AudioManager else 1.0
	master_slider.custom_minimum_size = Vector2(0, 30)
	master_slider.value_changed.connect(_on_master_volume_changed)
	vbox.add_child(master_slider)
	
	# Music Volume
	var music_label = Label.new()
	music_label.text = "Music Volume"
	music_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(music_label)
	
	var music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = AudioManager.music_volume if AudioManager else 0.7
	music_slider.custom_minimum_size = Vector2(0, 30)
	music_slider.value_changed.connect(_on_music_volume_changed)
	vbox.add_child(music_slider)
	
	# SFX Volume
	var sfx_label = Label.new()
	sfx_label.text = "Sound Effects"
	sfx_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(sfx_label)
	
	var sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = AudioManager.sfx_volume if AudioManager else 0.8
	sfx_slider.custom_minimum_size = Vector2(0, 30)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	vbox.add_child(sfx_slider)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Botón de cerrar
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 40)
	close_btn.pressed.connect(_on_close_options)
	vbox.add_child(close_btn)
	
	add_child(options_panel)

func _on_master_volume_changed(value: float):
	if AudioManager:
		AudioManager.master_volume = value

func _on_music_volume_changed(value: float):
	if AudioManager:
		AudioManager.music_volume = value

func _on_sfx_volume_changed(value: float):
	if AudioManager:
		AudioManager.sfx_volume = value
	# Reproducir sonido de prueba
	_play_click_sound()

func _on_close_options():
	_play_click_sound()
	options_panel.visible = false

func _on_new_battle_pressed():
	# Ir a la pantalla de configuración de equipo
	get_tree().change_scene_to_file("res://scenes/team_setup.tscn")

func _on_mechs_pressed():
	# Abrir Mech Bay
	get_tree().change_scene_to_file("res://scenes/mech_bay_screen.tscn")

func _on_advanced_loadout_pressed():
	# Abrir Advanced Loadout con sistema de slots críticos
	get_tree().change_scene_to_file("res://scenes/mech_bay_advanced.tscn")

func _on_multiplayer_pressed():
	# Abrir lobby de Multiplayer
	get_tree().change_scene_to_file("res://scenes/multiplayer_lobby.tscn")

func _on_options_pressed():
	options_panel.visible = true

func _on_quit_pressed():
	get_tree().quit()
