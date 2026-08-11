extends CanvasLayer

## TutorialHintPopup - Popup UI para mostrar hints del tutorial
## Muestra mensajes educativos con estilo visual atractivo
## Soporta dos modos:
## - blocks_game=true: Popup grande centrado que pausa el juego
## - action_required=true: Popup pequeño en esquina, sin cerrar, espera acción

signal hint_dismissed
signal hint_action_requested(action: String)

# Nodos UI
var panel: PanelContainer
var title_label: RichTextLabel
var content_label: RichTextLabel
var tip_label: RichTextLabel
var button: Button
var close_button: Button
var button_container: CenterContainer
var spacer: Control
var separator: HSeparator
var animation_player: AnimationPlayer
var center_container: CenterContainer

# Estado
var current_hint_id: String = ""
var blocks_game: bool = false
var action_required_mode: bool = false  # Modo pequeño sin cerrar

func _ready():
	_setup_ui()
	hide()

func _setup_ui():
	# Configurar CanvasLayer
	layer = 100  # Por encima de todo
	
	# Fondo semi-transparente (opcional, para hints que bloquean)
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.visible = false
	add_child(bg)
	
	# Contenedor centrado
	center_container = CenterContainer.new()
	center_container.name = "CenterContainer"
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	# Panel principal
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(500, 200)
	
	# Estilo del panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	style.border_color = Color(0.3, 0.6, 1.0, 0.8)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	center_container.add_child(panel)
	
	# VBox para contenido
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	# Header con título y botón cerrar
	var header = HBoxContainer.new()
	header.name = "Header"
	vbox.add_child(header)
	
	# Título
	title_label = RichTextLabel.new()
	title_label.name = "Title"
	title_label.bbcode_enabled = true
	title_label.fit_content = true
	title_label.scroll_active = false
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("normal_font_size", 24)
	title_label.add_theme_color_override("default_color", Color(1, 0.9, 0.3))
	header.add_child(title_label)
	
	# Botón cerrar (X)
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.flat = true
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(_on_close_pressed)
	close_button.tooltip_text = "Skip this hint"
	header.add_child(close_button)
	
	# Separador
	separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	vbox.add_child(separator)
	
	# Contenido principal
	content_label = RichTextLabel.new()
	content_label.name = "Content"
	content_label.bbcode_enabled = true
	content_label.fit_content = true
	content_label.scroll_active = false
	content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_label.add_theme_font_size_override("normal_font_size", 16)
	content_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(content_label)
	
	# Tip (consejo)
	tip_label = RichTextLabel.new()
	tip_label.name = "Tip"
	tip_label.bbcode_enabled = true
	tip_label.fit_content = true
	tip_label.scroll_active = false
	tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_label.add_theme_font_size_override("normal_font_size", 14)
	tip_label.add_theme_color_override("default_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(tip_label)
	
	# Espaciador
	spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Botón de acción
	button_container = CenterContainer.new()
	vbox.add_child(button_container)
	
	button = Button.new()
	button.name = "ActionButton"
	button.text = "GOT IT"
	button.custom_minimum_size = Vector2(150, 40)
	button.add_theme_font_size_override("font_size", 16)
	
	# Estilo del botón
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.5, 0.9)
	btn_style.set_corner_radius_all(8)
	btn_style.content_margin_left = 20
	btn_style.content_margin_right = 20
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.3, 0.6, 1.0)
	button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.15, 0.4, 0.8)
	button.add_theme_stylebox_override("pressed", btn_pressed)
	
	button.pressed.connect(_on_button_pressed)
	button_container.add_child(button)
	
	# Animation Player
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	_setup_animations()

func _setup_animations():
	# Animación de entrada
	var show_anim = Animation.new()
	show_anim.length = 0.3
	
	# Track para modulate del panel
	var track_idx = show_anim.add_track(Animation.TYPE_VALUE)
	show_anim.track_set_path(track_idx, "CenterContainer/Panel:modulate")
	show_anim.track_insert_key(track_idx, 0.0, Color(1, 1, 1, 0))
	show_anim.track_insert_key(track_idx, 0.3, Color(1, 1, 1, 1))
	
	# Track para scale
	var scale_track = show_anim.add_track(Animation.TYPE_VALUE)
	show_anim.track_set_path(scale_track, "CenterContainer/Panel:scale")
	show_anim.track_insert_key(scale_track, 0.0, Vector2(0.8, 0.8))
	show_anim.track_insert_key(scale_track, 0.3, Vector2(1.0, 1.0))
	
	var lib = AnimationLibrary.new()
	lib.add_animation("show", show_anim)
	
	# Animación de salida
	var hide_anim = Animation.new()
	hide_anim.length = 0.2
	
	var hide_track = hide_anim.add_track(Animation.TYPE_VALUE)
	hide_anim.track_set_path(hide_track, "CenterContainer/Panel:modulate")
	hide_anim.track_insert_key(hide_track, 0.0, Color(1, 1, 1, 1))
	hide_anim.track_insert_key(hide_track, 0.2, Color(1, 1, 1, 0))
	
	lib.add_animation("hide", hide_anim)
	
	animation_player.add_animation_library("", lib)

func _set_mouse_filter_recursive(node: Node, filter: int) -> void:
	"""Aplica mouse_filter a un Control y a todos sus descendientes.
	mouse_filter no se propaga automáticamente: cada Control decide por su
	cuenta si intercepta el ratón dentro de su propio rect, sin importar lo
	que haga su padre."""
	if node is Control:
		node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)

func show_hint(hint_data: Dictionary):
	"""Muestra un hint con los datos proporcionados"""
	current_hint_id = hint_data.get("id", "")
	blocks_game = hint_data.get("blocks_game", false)
	
	# Detectar si es modo "action required" (sin botón, no se puede cerrar)
	var button_text = hint_data.get("button_text", "GOT IT")
	action_required_mode = button_text.is_empty()
	
	# Configurar contenido
	title_label.text = hint_data.get("title", "HINT")
	content_label.text = hint_data.get("content", "")
	
	var tip = hint_data.get("tip", "")
	if tip.is_empty():
		tip_label.visible = false
	else:
		tip_label.visible = true
		tip_label.text = tip
	
	# Configurar visibilidad de elementos según el modo
	if action_required_mode:
		# Modo pequeño: sin botón, sin cerrar, posición en esquina superior
		button_container.visible = false
		close_button.visible = false
		spacer.visible = false
		separator.visible = false

		# Panel de tamaño FIJO (no solo mínimo). Antes title_label/content_label
		# tenían fit_content=true, así que un hint con mucho texto hacía crecer
		# el panel más allá de esta caja - CenterContainer no recorta a sus
		# hijos, así que el desborde tapaba paneles reales por debajo (selector
		# de armas) por muy corto que se intentara dejar el texto. Ahora el
		# texto se recorta/scrollea DENTRO de una altura fija en vez de
		# empujar el panel entero hacia abajo.
		panel.custom_minimum_size = Vector2(350, 150)
		title_label.fit_content = false
		title_label.scroll_active = false
		title_label.custom_minimum_size = Vector2(310, 22)
		title_label.add_theme_font_size_override("normal_font_size", 16)
		content_label.fit_content = false
		content_label.scroll_active = true
		content_label.custom_minimum_size = Vector2(310, 70)
		content_label.add_theme_font_size_override("normal_font_size", 13)
		tip_label.fit_content = false
		tip_label.scroll_active = true
		tip_label.custom_minimum_size = Vector2(310, 20)

		# Posicionar en esquina superior derecha. Con el panel ahora acotado
		# arriba, este rect ya no necesita ser generoso "por si acaso".
		center_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		center_container.offset_left = -370
		center_container.offset_top = 20
		center_container.offset_right = -20
		center_container.offset_bottom = 190

		# Bug: la caja de este hint (aunque solo pinta un panel pequeño en
		# la esquina) tenía mouse_filter STOP por defecto en toda su área
		# rectangular, incluyendo el espacio vacío. Eso bloqueaba clics en
		# botones reales que caían debajo (seleccionar arma, cerrar el
		# detalle de armas) causando soft-locks. mouse_filter no se hereda:
		# poner IGNORE solo en center_container/panel no bastaba porque
		# title_label/content_label/tip_label (RichTextLabel, STOP por
		# defecto) seguían capturando clics dentro de sus propios rects.
		# Este modo es puramente informativo - nada debajo del panel debe
		# capturar el ratón.
		_set_mouse_filter_recursive(center_container, Control.MOUSE_FILTER_IGNORE)
	else:
		# Modo normal: centrado, con botón
		button_container.visible = true
		close_button.visible = not blocks_game  # Solo mostrar X si no bloquea
		spacer.visible = true
		separator.visible = true

		# Panel tamaño normal - centrado, con espacio de sobra, así que aquí sí
		# puede crecer libremente con el contenido (restaurar lo que el modo
		# action_required pudo dejar fijo/acotado).
		panel.custom_minimum_size = Vector2(500, 200)
		title_label.fit_content = true
		title_label.scroll_active = false
		title_label.custom_minimum_size = Vector2.ZERO
		title_label.add_theme_font_size_override("normal_font_size", 24)
		content_label.fit_content = true
		content_label.scroll_active = false
		content_label.custom_minimum_size = Vector2.ZERO
		content_label.add_theme_font_size_override("normal_font_size", 16)
		tip_label.fit_content = true
		tip_label.scroll_active = false
		tip_label.custom_minimum_size = Vector2.ZERO

		# Centrar
		center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		center_container.offset_left = 0
		center_container.offset_top = 0
		center_container.offset_right = 0
		center_container.offset_bottom = 0

		# Restaurar filtro de ratón normal (el modo action_required pudo dejarlo en IGNORE)
		_set_mouse_filter_recursive(center_container, Control.MOUSE_FILTER_STOP)

		button.text = button_text
	
	# Mostrar/ocultar fondo según si bloquea
	var bg = get_node_or_null("Background")
	if bg:
		bg.visible = blocks_game
	
	# Mostrar con animación
	show()
	panel.pivot_offset = panel.size / 2
	animation_player.play("show")
	
	# Pausar el juego si bloquea
	if blocks_game:
		get_tree().paused = true

func hide_hint():
	"""Oculta el hint actual"""
	animation_player.play("hide")
	await animation_player.animation_finished
	hide()
	
	# Despausar si estaba pausado
	if blocks_game:
		get_tree().paused = false
		blocks_game = false
	
	# Reset action_required_mode
	action_required_mode = false
	
	hint_dismissed.emit()
	
	# Notificar al TutorialManager que el hint fue cerrado
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		tutorial_mgr.notify_hint_dismissed()

func hide_hint_silent():
	"""Oculta el hint sin emitir señales (para cuando se completa una acción)"""
	animation_player.play("hide")
	await animation_player.animation_finished
	hide()
	
	if blocks_game:
		get_tree().paused = false
		blocks_game = false
	
	action_required_mode = false

func _on_button_pressed():
	"""Callback cuando se presiona el botón principal"""
	hint_action_requested.emit(current_hint_id)
	hide_hint()

func _on_close_pressed():
	"""Callback cuando se presiona el botón cerrar"""
	if not action_required_mode:
		hide_hint()

func _input(event):
	"""Permite cerrar con ESC si no bloquea el juego y no es action_required"""
	if visible and event.is_action_pressed("ui_cancel") and not blocks_game and not action_required_mode:
		hide_hint()
		get_viewport().set_input_as_handled()
