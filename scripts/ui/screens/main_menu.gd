extends Control

# Panel de opciones
var options_panel: Panel = null
var _is_server_mode: bool = false
var _auth_manager: Node = null
var _user_info_label: Label = null
var _logout_button: Button = null
var _menu_container: VBoxContainer = null

func _ready():
	# Si estamos en modo headless (servidor dedicado), cambiar a escena de servidor
	if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"):
		Log.info("System", "Detected headless/server mode, switching to server scene...")
		_is_server_mode = true
		# Programar cambio de escena para el próximo frame
		call_deferred("_switch_to_server_scene")
		return
	
	# Obtener AuthManager
	_auth_manager = get_node_or_null("/root/AuthManager")
	
	# Verificar si el usuario está autenticado
	if _auth_manager and not _auth_manager.is_authenticated():
		# Mostrar pantalla de login
		_show_auth_screen()
		return
	
	# Usuario autenticado, mostrar menú normal
	_setup_main_menu()


func _show_auth_screen() -> void:
	"""Muestra la pantalla de autenticación"""
	var auth_scene := preload("res://scenes/auth_screen.tscn")
	var auth_screen := auth_scene.instantiate()
	add_child(auth_screen)
	
	# Conectar señales
	auth_screen.login_successful.connect(_on_login_successful)
	auth_screen.login_cancelled.connect(_on_login_cancelled)


func _on_login_successful(user_data: Dictionary) -> void:
	"""Callback cuando el login es exitoso"""
	Log.info("MainMenu", "Login successful, loading player data", {"username": user_data.get("username", "unknown")})
	
	# Cargar datos del jugador con PlayerDataManager
	var user_id: String = str(user_data.get("user_id", ""))
	if user_id.is_empty():
		user_id = str(user_data.get("id", ""))
	
	if not user_id.is_empty():
		var player_data = get_node_or_null("/root/PlayerData")
		if player_data:
			# Determinar si es online u offline basado en si es guest
			var is_guest: bool = user_data.get("is_guest", false)
			if is_guest:
				player_data.load_offline_data()
				Log.info("MainMenu", "Loaded offline player data for guest")
			else:
				# En modo online, cargar datos del servidor
				player_data.load_player_data(user_id)
				Log.info("MainMenu", "Loading online player data", {"user_id": user_id})
	
	# Remover pantalla de auth
	for child in get_children():
		if child.has_method("_on_login_pressed"):  # Es AuthScreen
			child.queue_free()
	
	# Configurar menú principal
	_setup_main_menu()


func _on_login_cancelled() -> void:
	"""Callback cuando se cancela el login"""
	# Por ahora, permitir continuar como invitado offline
	if _auth_manager:
		_auth_manager.login_as_guest()


func _setup_main_menu() -> void:
	"""Configura el menú principal"""
	# TEMPORAL: Regenerar hangar para limpiar datos corruptos
	var mech_bay_manager = get_node_or_null("/root/MechBayManager")
	if mech_bay_manager and mech_bay_manager.force_regenerate_hangar:
		mech_bay_manager.force_regenerate()
	
	# Iniciar música del menú
	if AudioManager:
		AudioManager.play_music(AudioManager.MUSIC_MENU, 2.0)
	
	# Crear barra de usuario en la parte superior
	_create_user_bar()
	
	# Configurar UI del menú
	_menu_container = VBoxContainer.new()
	_menu_container.anchor_left = 0.5
	_menu_container.anchor_top = 0.5
	_menu_container.anchor_right = 0.5
	_menu_container.anchor_bottom = 0.5
	_menu_container.offset_left = -150
	_menu_container.offset_top = -200
	_menu_container.offset_right = 150
	_menu_container.offset_bottom = 200
	add_child(_menu_container)
	
	# Título
	var title = Label.new()
	title.text = "STEEL TITANS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	_menu_container.add_child(title)
	
	_menu_container.add_child(Control.new())  # Spacer
	
	# Botón de nueva batalla
	var new_battle_btn = _create_menu_button("New Game")
	new_battle_btn.pressed.connect(_on_new_battle_pressed)
	_menu_container.add_child(new_battle_btn)
	
	# Botón de mechs
	var mechs_btn = _create_menu_button("Mech Bay")
	mechs_btn.pressed.connect(_on_mechs_pressed)
	_menu_container.add_child(mechs_btn)
	
	# Botón de loadout avanzado
	var loadout_btn = _create_menu_button("Advanced Loadout")
	loadout_btn.pressed.connect(_on_advanced_loadout_pressed)
	_menu_container.add_child(loadout_btn)
	
	# Botón de Multiplayer
	var multiplayer_btn = _create_menu_button("Multiplayer")
	multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
	_menu_container.add_child(multiplayer_btn)
	
	# Botón de opciones
	var options_btn = _create_menu_button("Options")
	options_btn.pressed.connect(_on_options_pressed)
	_menu_container.add_child(options_btn)
	
	# Botón de salir
	var quit_btn = _create_menu_button("Quit")
	quit_btn.pressed.connect(_on_quit_pressed)
	_menu_container.add_child(quit_btn)
	
	# Crear panel de opciones (oculto inicialmente)
	_create_options_panel()


func _create_user_bar() -> void:
	"""Crea la barra superior con info del usuario"""
	var user_bar := HBoxContainer.new()
	user_bar.anchor_left = 0.0
	user_bar.anchor_top = 0.0
	user_bar.anchor_right = 1.0
	user_bar.anchor_bottom = 0.0
	user_bar.offset_left = 15
	user_bar.offset_top = 10
	user_bar.offset_right = -15
	user_bar.offset_bottom = 50
	user_bar.add_theme_constant_override("separation", 15)
	add_child(user_bar)
	
	# Icono de usuario
	var user_icon := Label.new()
	user_icon.text = "👤"
	user_icon.add_theme_font_size_override("font_size", 24)
	user_bar.add_child(user_icon)
	
	# Info del usuario
	_user_info_label = Label.new()
	_user_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_user_info_label.add_theme_font_size_override("font_size", 16)
	
	if _auth_manager and _auth_manager.is_authenticated():
		var user_data: Dictionary = _auth_manager.get_current_user()
		var username: String = str(user_data.get("username", "Guest"))
		
		# Obtener datos de progreso desde PlayerDataManager
		var player_data = get_node_or_null("/root/PlayerData")
		var level: int = 1
		var elo: int = 1000
		var credits: int = 0
		
		if player_data and player_data.progress:
			level = player_data.progress.level
			elo = player_data.progress.elo_rating
			credits = player_data.progress.credits
		else:
			# Fallback a datos de auth si PlayerData no está disponible
			elo = user_data.get("elo_rating", 1000)
			credits = user_data.get("c_bills", 0)
		
		_user_info_label.text = "%s  |  Lv.%d  |  ELO: %d  |  CT: %s" % [username, level, elo, _format_number(credits)]
	else:
		_user_info_label.text = "Not logged in"
	
	user_bar.add_child(_user_info_label)
	
	# Botón de logout
	_logout_button = Button.new()
	_logout_button.text = "Logout"
	_logout_button.custom_minimum_size = Vector2(80, 30)
	_logout_button.pressed.connect(_on_logout_pressed)
	user_bar.add_child(_logout_button)


func _format_number(num: int) -> String:
	"""Formatea un número con separadores de miles"""
	var str_num := str(num)
	var result := ""
	var count := 0
	for i in range(str_num.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = str_num[i] + result
		count += 1
	return result


func _on_logout_pressed() -> void:
	"""Maneja el logout"""
	# Primero guardar y limpiar datos del jugador
	var player_data = get_node_or_null("/root/PlayerData")
	if player_data:
		player_data.on_logout()
		Log.info("MainMenu", "Player data saved on logout")
	
	if _auth_manager:
		_auth_manager.logout()
	
	# Recargar la escena para mostrar login
	get_tree().reload_current_scene()

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

func _switch_to_server_scene():
	"""Cambia a la escena del servidor (llamado de forma diferida)"""
	get_tree().change_scene_to_file("res://scenes/server_main.tscn")
