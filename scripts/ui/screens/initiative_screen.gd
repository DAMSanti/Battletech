extends CanvasLayer

signal initiative_complete(data: Dictionary)

@onready var battletech_theme = load("res://assets/themes/battletech_theme.tres")

var roll_button: Button
var result_label: Label
var continue_button: Button
var subtitle_label: Label

var player_dice: Array = []  # 8 dados para jugador (2 por mech)
var enemy_dice: Array = []   # 8 dados para enemigo (2 por mech)

var player_results = [[0, 0], [0, 0], [0, 0], [0, 0]]  # 4 mechs, 2 dados cada uno
var enemy_results = [[0, 0], [0, 0], [0, 0], [0, 0]]   # 4 mechs, 2 dados cada uno

# Unicode dice: ⚀ ⚁ ⚂ ⚃ ⚄ ⚅
var dice_faces = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
var is_rolling = false

var player_mech_names = []
var enemy_mech_names = []

func _ready():
	visible = true
	layer = 100
	
	setup_ui()
	
	# Actualizar labels de mechs después de crear la UI
	call_deferred("_update_mech_labels")

func _update_mech_labels():
	# Buscar todos los labels de mechs y actualizar sus nombres
	for child in get_children():
		if child is Label and child.has_meta("mech_index"):
			var mech_index = child.get_meta("mech_index")
			var team = child.get_meta("team")
			
			if team == "player" and mech_index < player_mech_names.size():
				child.text = player_mech_names[mech_index]
			elif team == "enemy" and mech_index < enemy_mech_names.size():
				child.text = enemy_mech_names[mech_index]

func setup_ui():
	# Obtener tamaño de pantalla
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y
	var scale_factor = screen_width / 720.0  # Escalar basado en ancho de 720px
	var margin = 10 * scale_factor
	
	
	# Fondo con transparencia para ver el mapa (20% opaco)
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.08, 0.2)
	bg.position = Vector2.ZERO
	bg.size = viewport_size
	add_child(bg)
	
	# Panel decorativo superior (95% del ancho) - Estilo BattleTech
	var panel_width = screen_width * 0.95
	var top_panel = Panel.new()
	top_panel.position = Vector2((screen_width - panel_width) / 2, margin * 2)
	top_panel.size = Vector2(panel_width, screen_height * 0.12)
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.08, 0.12, 0.18, 0.4)  # Transparente
	top_style.border_width_top = int(3 * scale_factor)
	top_style.border_width_bottom = int(3 * scale_factor)
	top_style.border_width_left = int(3 * scale_factor)
	top_style.border_width_right = int(3 * scale_factor)
	top_style.border_color = Color(0.3, 0.7, 1, 1)  # Cian brillante BattleTech
	top_style.corner_radius_top_left = int(8 * scale_factor)
	top_style.corner_radius_top_right = int(8 * scale_factor)
	top_style.corner_radius_bottom_left = int(8 * scale_factor)
	top_style.corner_radius_bottom_right = int(8 * scale_factor)
	top_style.border_blend = true
	top_style.anti_aliasing = true
	top_style.shadow_color = Color(0.3, 0.7, 1, 0.5)
	top_style.shadow_size = int(6 * scale_factor)
	top_style.shadow_offset = Vector2(0, 2)
	top_style.skew = Vector2(0.05, 0)  # Skew futurista
	top_panel.add_theme_stylebox_override("panel", top_style)
	add_child(top_panel)
	
	# Título con estilo BattleTech
	var title = Label.new()
	title.text = "⚔ BATTLETECH INITIATIVE ⚔"
	title.position = Vector2(screen_width * 0.05, screen_height * 0.04)
	title.size = Vector2(screen_width * 0.9, screen_height * 0.06)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(32 * scale_factor))
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))  # Color BattleTech
	title.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	title.add_theme_constant_override("outline_size", 3)
	add_child(title)
	
	# Subtítulo con estilo BattleTech
	subtitle_label = Label.new()
	subtitle_label.text = "Roll for initiative - Each mech rolls 2D6"
	subtitle_label.position = Vector2(screen_width * 0.05, screen_height * 0.10)
	subtitle_label.size = Vector2(screen_width * 0.9, screen_height * 0.04)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", int(18 * scale_factor))
	subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9, 1))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	subtitle_label.add_theme_constant_override("outline_size", 2)
	add_child(subtitle_label)
	
	# Dados más grandes y con espacio para labels
	var dice_size = screen_width * 0.07  # Más grandes
	var dice_y_start = screen_height * 0.18
	var spacing_x = dice_size + margin * 0.8
	var spacing_y = dice_size + margin * 1.5
	var label_x_offset = dice_size * 2 + margin * 2  # Espacio para el label del mech
	
	# JUGADOR - Lado izquierdo con estilo BattleTech
	var player_header = Label.new()
	player_header.text = "★ PLAYER LANCE ★"
	player_header.position = Vector2(screen_width * 0.02, screen_height * 0.145)
	player_header.size = Vector2(screen_width * 0.46, screen_height * 0.03)
	player_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_header.add_theme_font_size_override("font_size", int(18 * scale_factor))
	player_header.add_theme_color_override("font_color", Color(0.3, 0.7, 1, 1))  # Cian BattleTech
	player_header.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	player_header.add_theme_constant_override("outline_size", 2)
	add_child(player_header)
	
	# 4 filas de 2 dados cada una (jugador) + label del mech
	var player_start_x = screen_width * 0.03
	for row in range(4):
		var y_pos = dice_y_start + row * spacing_y
		# Primer dado del mech
		player_dice.append(create_3d_dice(Vector2(player_start_x, y_pos), Color.CYAN, dice_size))
		# Segundo dado del mech
		player_dice.append(create_3d_dice(Vector2(player_start_x + spacing_x, y_pos), Color.CYAN, dice_size))
		
		# Label con el nombre del mech (estilo BattleTech)
		var mech_label = Label.new()
		mech_label.position = Vector2(player_start_x + label_x_offset, y_pos)
		mech_label.size = Vector2(screen_width * 0.15, dice_size)
		mech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mech_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
		mech_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
		mech_label.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
		mech_label.add_theme_constant_override("outline_size", 1)
		# El nombre se actualizará después cuando tengamos los datos
		mech_label.set_meta("mech_index", row)
		mech_label.set_meta("team", "player")
		add_child(mech_label)
	
	# ENEMIGO - Lado derecho con estilo BattleTech
	var enemy_header = Label.new()
	enemy_header.text = "★ ENEMY FORCE ★"
	enemy_header.position = Vector2(screen_width * 0.52, screen_height * 0.145)
	enemy_header.size = Vector2(screen_width * 0.46, screen_height * 0.03)
	enemy_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_header.add_theme_font_size_override("font_size", int(18 * scale_factor))
	enemy_header.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))  # Rojo más brillante
	enemy_header.add_theme_color_override("font_outline_color", Color(0.2, 0, 0, 1))
	enemy_header.add_theme_constant_override("outline_size", 2)
	add_child(enemy_header)
	
	# 4 filas de 2 dados cada una (enemigo) + label del mech
	var enemy_start_x = screen_width * 0.53
	for row in range(4):
		var y_pos = dice_y_start + row * spacing_y
		# Primer dado del mech
		enemy_dice.append(create_3d_dice(Vector2(enemy_start_x, y_pos), Color.RED, dice_size))
		# Segundo dado del mech
		enemy_dice.append(create_3d_dice(Vector2(enemy_start_x + spacing_x, y_pos), Color.RED, dice_size))
		
		# Label con el nombre del mech (estilo BattleTech)
		var mech_label = Label.new()
		mech_label.position = Vector2(enemy_start_x + label_x_offset, y_pos)
		mech_label.size = Vector2(screen_width * 0.15, dice_size)
		mech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mech_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
		mech_label.add_theme_color_override("font_color", Color(1, 0.7, 0.7, 1))
		mech_label.add_theme_color_override("font_outline_color", Color(0.2, 0, 0, 1))
		mech_label.add_theme_constant_override("outline_size", 1)
		# El nombre se actualizará después cuando tengamos los datos
		mech_label.set_meta("mech_index", row)
		mech_label.set_meta("team", "enemy")
		add_child(mech_label)
	
	# Botón Roll - estilo BattleTech
	var button_y = dice_y_start + (spacing_y * 4) + margin * 3
	roll_button = Button.new()
	roll_button.text = "🎲 ROLL DICE 🎲"
	roll_button.position = Vector2(screen_width * 0.1, button_y)
	roll_button.custom_minimum_size = Vector2(screen_width * 0.8, screen_height * 0.08)
	roll_button.theme = battletech_theme
	roll_button.add_theme_font_size_override("font_size", int(28 * scale_factor))
	roll_button.pressed.connect(_on_roll_pressed)
	add_child(roll_button)
	
	# Resultado con paneles visuales en lugar de label
	result_label = Label.new()
	result_label.position = Vector2(screen_width * 0.05, button_y + screen_height * 0.12)
	result_label.size = Vector2(screen_width * 0.9, screen_height * 0.15)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", int(20 * scale_factor))
	result_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1, 1))
	result_label.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	result_label.add_theme_constant_override("outline_size", 2)
	result_label.visible = false
	result_label.set_meta("is_results_container", true)  # Marcador para identificar contenedor
	add_child(result_label)
	
	# Botón continuar - estilo BattleTech
	continue_button = Button.new()
	continue_button.text = "⚔ START BATTLE ⚔"
	continue_button.position = Vector2(screen_width * 0.1, screen_height - screen_height * 0.15)
	continue_button.custom_minimum_size = Vector2(screen_width * 0.8, screen_height * 0.08)
	continue_button.theme = battletech_theme
	continue_button.add_theme_font_size_override("font_size", int(28 * scale_factor))
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = false
	add_child(continue_button)

func create_3d_dice(pos: Vector2, glow_color: Color, dice_size: float) -> Control:
	var dice = Control.new()
	dice.position = pos
	dice.custom_minimum_size = Vector2(dice_size, dice_size)
	add_child(dice)
	
	var corner_radius = int(dice_size * 0.14)
	var border_width = int(dice_size * 0.04)
	
	# Sombra
	var shadow = Panel.new()
	shadow.position = Vector2(dice_size * 0.08, dice_size * 0.08)
	shadow.custom_minimum_size = Vector2(dice_size, dice_size)
	var shadow_style = StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.5)
	shadow_style.corner_radius_top_left = corner_radius
	shadow_style.corner_radius_top_right = corner_radius
	shadow_style.corner_radius_bottom_left = corner_radius
	shadow_style.corner_radius_bottom_right = corner_radius
	shadow.add_theme_stylebox_override("panel", shadow_style)
	dice.add_child(shadow)
	
	# Panel del dado
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(dice_size, dice_size)
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_color = glow_color
	style.shadow_color = glow_color
	style.shadow_size = int(dice_size * 0.11)
	panel.add_theme_stylebox_override("panel", style)
	dice.add_child(panel)
	
	# Label
	var label = Label.new()
	label.text = "?"
	label.custom_minimum_size = Vector2(dice_size, dice_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(dice_size * 0.67))
	label.add_theme_color_override("font_color", Color.BLACK)
	dice.add_child(label)
	
	dice.set_meta("label", label)
	dice.set_meta("panel", panel)
	dice.set_meta("shadow", shadow)
	dice.set_meta("glow_color", glow_color)
	dice.set_meta("original_pos", pos)
	dice.set_meta("dice_size", dice_size)
	
	return dice

func _on_roll_pressed():
	if is_rolling:
		return
	
	is_rolling = true
	roll_button.disabled = true
	subtitle_label.text = "Rolling dice for all mechs..."
	
	# Tirar 2D6 para cada mech
	for i in range(4):
		player_results[i][0] = (randi() % 6) + 1
		player_results[i][1] = (randi() % 6) + 1
		enemy_results[i][0] = (randi() % 6) + 1
		enemy_results[i][1] = (randi() % 6) + 1
	
	# Animar los 16 dados con delays escalonados
	var delay = 0.0
	for i in range(4):
		# Dados del jugador (mech i)
		animate_dice_3d(player_dice[i * 2], player_results[i][0], delay)
		delay += 0.1
		animate_dice_3d(player_dice[i * 2 + 1], player_results[i][1], delay)
		delay += 0.1
	
	for i in range(4):
		# Dados del enemigo (mech i)
		animate_dice_3d(enemy_dice[i * 2], enemy_results[i][0], delay)
		delay += 0.1
		animate_dice_3d(enemy_dice[i * 2 + 1], enemy_results[i][1], delay)
		delay += 0.1
	
	await get_tree().create_timer(5.5).timeout
	show_results()

func animate_dice_3d(dice: Control, final_result: int, delay: float):
	if not is_instance_valid(dice):
		return
		
	var label = dice.get_meta("label")
	var panel = dice.get_meta("panel")
	var glow_color = dice.get_meta("glow_color")
	var original_pos = dice.get_meta("original_pos")
	var dice_size = dice.get_meta("dice_size")
	
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	
	if not is_instance_valid(dice):
		return
	
	# FASE 1: LANZAMIENTO EXPLOSIVO
	var launch_height = dice_size * 2.5
	var horizontal_throw = (randf() - 0.5) * dice_size * 0.8
	
	var launch = create_tween()
	launch.set_parallel(true)
	# Movimiento vertical tipo parábola
	launch.tween_property(dice, "position:y", original_pos.y - launch_height, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Movimiento horizontal
	launch.tween_property(dice, "position:x", original_pos.x + horizontal_throw, 0.7) \
		.set_trans(Tween.TRANS_CUBIC)
	# Rotación RÁPIDA
	launch.tween_property(dice, "rotation", TAU * 4, 0.7) \
		.set_trans(Tween.TRANS_LINEAR)
	# Escala
	launch.tween_property(dice, "scale", Vector2(1.5, 1.5), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Cambiar caras MUY RÁPIDO durante el vuelo
	var time = 0.0
	while time < 0.7:
		await get_tree().create_timer(0.03).timeout
		if not is_instance_valid(dice) or not is_instance_valid(label):
			return
		time += 0.03
		label.text = dice_faces[randi() % 6]
		# Pulso de brillo
		if is_instance_valid(panel):
			var style_temp = panel.get_theme_stylebox("panel")
			if style_temp:
				style_temp = style_temp.duplicate()
				style_temp.shadow_size = 10 + randi() % 20
				panel.add_theme_stylebox_override("panel", style_temp)
	
	if not is_instance_valid(dice):
		return
	
	# FASE 2: CAÍDA CON REBOTES MÚLTIPLES
	var fall = create_tween()
	fall.set_parallel(true)
	# Caída con rebote realista
	fall.tween_property(dice, "position:y", original_pos.y, 1.4) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Volver al centro
	fall.tween_property(dice, "position:x", original_pos.x, 1.2) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Rotación desacelerando
	fall.tween_property(dice, "rotation", TAU * 8, 1.4) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Escala vuelve a normal
	fall.tween_property(dice, "scale", Vector2(1.0, 1.0), 1.2) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Cambiar caras más lento durante caída
	time = 0.0
	while time < 1.0:
		await get_tree().create_timer(0.06).timeout
		if not is_instance_valid(dice) or not is_instance_valid(label):
			return
		time += 0.06
		label.text = dice_faces[randi() % 6]
	
	# Esperar a que termine la animación de caída
	await fall.finished
	
	if not is_instance_valid(dice) or not is_instance_valid(label):
		return
	
	# FASE 3: RESULTADO FINAL DRAMÁTICO
	dice.rotation = 0
	
	# FORZAR EL RESULTADO CORRECTO
	# final_result es un valor de 1-6 (cara del dado)
	var correct_face = dice_faces[final_result - 1]
	label.text = correct_face
	
	
	# Bounce épico
	dice.scale = Vector2(1.8, 1.8)
	var final_bounce = create_tween()
	final_bounce.tween_property(dice, "scale", Vector2(1.0, 1.0), 0.6) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	if not is_instance_valid(panel):
		return
	
	# FLASH AMARILLO BRILLANTE
	var style = panel.get_theme_stylebox("panel")
	if style == null:
		return
	
	var border_width = int(dice_size * 0.08)
	var shadow_large = int(dice_size * 0.22)
	var shadow_small = int(dice_size * 0.14)
		
	style = style.duplicate()
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_color = Color.YELLOW
	style.shadow_color = Color.YELLOW
	style.shadow_size = shadow_large
	panel.add_theme_stylebox_override("panel", style)
	
	# Pulsar 3 veces
	for i in range(3):
		await get_tree().create_timer(0.15).timeout
		if not is_instance_valid(panel):
			return
		var pulse = style.duplicate()
		pulse.shadow_size = shadow_large if i % 2 == 0 else shadow_small
		panel.add_theme_stylebox_override("panel", pulse)
	
	await get_tree().create_timer(0.3).timeout
	
	if not is_instance_valid(panel):
		return
	
	# Volver al color original
	var border_normal = int(dice_size * 0.04)
	var shadow_normal = int(dice_size * 0.14)
	style = style.duplicate()
	style.border_width_top = border_normal
	style.border_width_bottom = border_normal
	style.border_width_left = border_normal
	style.border_width_right = border_normal
	style.border_color = glow_color
	style.shadow_color = glow_color
	style.shadow_size = shadow_normal
	panel.add_theme_stylebox_override("panel", style)

func show_results():
	subtitle_label.text = "Initiative determined!"
	
	# Obtener tamaño de pantalla para escalado
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y
	var scale_factor = screen_width / 720.0
	var margin = 10 * scale_factor
	
	# Crear título principal
	var title_y = result_label.position.y - 30 * scale_factor
	var results_title = Label.new()
	results_title.text = "★ INITIATIVE RESULTS ★"
	results_title.position = Vector2(screen_width * 0.05, title_y)
	results_title.size = Vector2(screen_width * 0.9, 30 * scale_factor)
	results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_title.add_theme_font_size_override("font_size", int(24 * scale_factor))
	results_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	results_title.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	results_title.add_theme_constant_override("outline_size", 3)
	add_child(results_title)
	
	# Panel izquierdo (Jugador)
	var panel_width = screen_width * 0.43
	var panel_height = screen_height * 0.25
	var panel_y = result_label.position.y + 10 * scale_factor
	
	var player_panel = Panel.new()
	player_panel.position = Vector2(screen_width * 0.04, panel_y)
	player_panel.size = Vector2(panel_width, panel_height)
	
	var player_style = StyleBoxFlat.new()
	player_style.bg_color = Color(0.08, 0.15, 0.22, 0.6)
	player_style.border_width_left = int(3 * scale_factor)
	player_style.border_width_top = int(3 * scale_factor)
	player_style.border_width_right = int(3 * scale_factor)
	player_style.border_width_bottom = int(3 * scale_factor)
	player_style.border_color = Color(0.3, 0.7, 1, 0.9)
	player_style.corner_radius_top_left = int(8 * scale_factor)
	player_style.corner_radius_top_right = int(8 * scale_factor)
	player_style.corner_radius_bottom_left = int(8 * scale_factor)
	player_style.corner_radius_bottom_right = int(8 * scale_factor)
	player_style.shadow_color = Color(0.3, 0.7, 1, 0.6)
	player_style.shadow_size = int(8 * scale_factor)
	player_style.shadow_offset = Vector2(0, 2)
	player_style.skew = Vector2(0.03, 0)
	player_panel.add_theme_stylebox_override("panel", player_style)
	add_child(player_panel)
	
	# Header del panel jugador
	var player_header = Label.new()
	player_header.text = "★ PLAYER LANCE ★"
	player_header.position = Vector2(margin, margin)
	player_header.size = Vector2(panel_width - margin * 2, 25 * scale_factor)
	player_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_header.add_theme_font_size_override("font_size", int(18 * scale_factor))
	player_header.add_theme_color_override("font_color", Color(0.5, 0.9, 1, 1))
	player_header.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 1))
	player_header.add_theme_constant_override("outline_size", 2)
	player_panel.add_child(player_header)
	
	# Línea separadora
	var player_line = ColorRect.new()
	player_line.color = Color(0.3, 0.7, 1, 0.5)
	player_line.position = Vector2(margin, 35 * scale_factor)
	player_line.size = Vector2(panel_width - margin * 2, 2)
	player_panel.add_child(player_line)
	
	# Resultados del jugador
	var y_offset = 45 * scale_factor
	for i in range(4):
		var player_name = player_mech_names[i] if i < player_mech_names.size() else ("Mech " + str(i + 1))
		var player_total = player_results[i][0] + player_results[i][1]
		
		var row = HBoxContainer.new()
		row.position = Vector2(margin * 2, y_offset)
		row.size = Vector2(panel_width - margin * 4, 25 * scale_factor)
		player_panel.add_child(row)
		
		var name_label = Label.new()
		name_label.text = player_name
		name_label.custom_minimum_size = Vector2(panel_width * 0.6, 25 * scale_factor)
		name_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
		name_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1, 1))
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		
		var score_label = Label.new()
		score_label.text = str(player_total)
		score_label.custom_minimum_size = Vector2(50 * scale_factor, 25 * scale_factor)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score_label.add_theme_font_size_override("font_size", int(22 * scale_factor))
		score_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
		score_label.add_theme_color_override("font_outline_color", Color(0, 0.2, 0, 1))
		score_label.add_theme_constant_override("outline_size", 2)
		row.add_child(score_label)
		
		y_offset += 30 * scale_factor
	
	# Panel derecho (Enemigo)
	var enemy_panel = Panel.new()
	enemy_panel.position = Vector2(screen_width * 0.53, panel_y)
	enemy_panel.size = Vector2(panel_width, panel_height)
	
	var enemy_style = StyleBoxFlat.new()
	enemy_style.bg_color = Color(0.22, 0.08, 0.08, 0.6)
	enemy_style.border_width_left = int(3 * scale_factor)
	enemy_style.border_width_top = int(3 * scale_factor)
	enemy_style.border_width_right = int(3 * scale_factor)
	enemy_style.border_width_bottom = int(3 * scale_factor)
	enemy_style.border_color = Color(1, 0.3, 0.3, 0.9)
	enemy_style.corner_radius_top_left = int(8 * scale_factor)
	enemy_style.corner_radius_top_right = int(8 * scale_factor)
	enemy_style.corner_radius_bottom_left = int(8 * scale_factor)
	enemy_style.corner_radius_bottom_right = int(8 * scale_factor)
	enemy_style.shadow_color = Color(1, 0.3, 0.3, 0.6)
	enemy_style.shadow_size = int(8 * scale_factor)
	enemy_style.shadow_offset = Vector2(0, 2)
	enemy_style.skew = Vector2(-0.03, 0)
	enemy_panel.add_theme_stylebox_override("panel", enemy_style)
	add_child(enemy_panel)
	
	# Header del panel enemigo
	var enemy_header = Label.new()
	enemy_header.text = "★ ENEMY FORCE ★"
	enemy_header.position = Vector2(margin, margin)
	enemy_header.size = Vector2(panel_width - margin * 2, 25 * scale_factor)
	enemy_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_header.add_theme_font_size_override("font_size", int(18 * scale_factor))
	enemy_header.add_theme_color_override("font_color", Color(1, 0.5, 0.5, 1))
	enemy_header.add_theme_color_override("font_outline_color", Color(0.2, 0, 0, 1))
	enemy_header.add_theme_constant_override("outline_size", 2)
	enemy_panel.add_child(enemy_header)
	
	# Línea separadora
	var enemy_line = ColorRect.new()
	enemy_line.color = Color(1, 0.3, 0.3, 0.5)
	enemy_line.position = Vector2(margin, 35 * scale_factor)
	enemy_line.size = Vector2(panel_width - margin * 2, 2)
	enemy_panel.add_child(enemy_line)
	
	# Resultados del enemigo
	y_offset = 45 * scale_factor
	for i in range(4):
		var enemy_name = enemy_mech_names[i] if i < enemy_mech_names.size() else ("Enemy " + str(i + 1))
		var enemy_total = enemy_results[i][0] + enemy_results[i][1]
		
		var row = HBoxContainer.new()
		row.position = Vector2(margin * 2, y_offset)
		row.size = Vector2(panel_width - margin * 4, 25 * scale_factor)
		enemy_panel.add_child(row)
		
		var name_label = Label.new()
		name_label.text = enemy_name
		name_label.custom_minimum_size = Vector2(panel_width * 0.6, 25 * scale_factor)
		name_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
		name_label.add_theme_color_override("font_color", Color(1, 0.8, 0.8, 1))
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		
		var score_label = Label.new()
		score_label.text = str(enemy_total)
		score_label.custom_minimum_size = Vector2(50 * scale_factor, 25 * scale_factor)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score_label.add_theme_font_size_override("font_size", int(22 * scale_factor))
		score_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
		score_label.add_theme_color_override("font_outline_color", Color(0.2, 0, 0, 1))
		score_label.add_theme_constant_override("outline_size", 2)
		row.add_child(score_label)
		
		y_offset += 30 * scale_factor
	
	# Animación de entrada
	results_title.modulate = Color(1, 1, 1, 0)
	player_panel.modulate = Color(1, 1, 1, 0)
	enemy_panel.modulate = Color(1, 1, 1, 0)
	player_panel.scale = Vector2(0.8, 0.8)
	enemy_panel.scale = Vector2(0.8, 0.8)
	
	var fade = create_tween()
	fade.set_parallel(true)
	fade.tween_property(results_title, "modulate", Color.WHITE, 0.5)
	fade.tween_property(player_panel, "modulate", Color.WHITE, 0.6).set_delay(0.2)
	fade.tween_property(enemy_panel, "modulate", Color.WHITE, 0.6).set_delay(0.3)
	fade.tween_property(player_panel, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)
	fade.tween_property(enemy_panel, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3)
	
	await get_tree().create_timer(0.8).timeout
	
	continue_button.visible = true
	continue_button.modulate = Color(1, 1, 1, 0)
	
	var btn_fade = create_tween()
	btn_fade.tween_property(continue_button, "modulate", Color.WHITE, 0.5)
	
	is_rolling = false

func _on_continue_pressed():
	continue_button.disabled = true
	
	# Calcular totales para cada mech (suma de 2D6)
	var player_totals = []
	var enemy_totals = []
	
	for i in range(4):
		player_totals.append(player_results[i][0] + player_results[i][1])
		enemy_totals.append(enemy_results[i][0] + enemy_results[i][1])
	
	var data = {
		"player_initiatives": player_totals,
		"enemy_initiatives": enemy_totals,
		"player_mech_names": player_mech_names.duplicate(),
		"enemy_mech_names": enemy_mech_names.duplicate()
	}
	
	
	# Fade out
	for dice in player_dice + enemy_dice:
		var exit = create_tween()
		exit.set_parallel(true)
		exit.tween_property(dice, "position:y", -300, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		exit.tween_property(dice, "modulate:a", 0.0, 0.8)
	
	var fade = create_tween()
	fade.set_parallel(true)
	fade.tween_property(roll_button, "modulate:a", 0.0, 0.6)
	fade.tween_property(result_label, "modulate:a", 0.0, 0.6)
	fade.tween_property(continue_button, "modulate:a", 0.0, 0.6)
	
	await fade.finished
	
	initiative_complete.emit(data)
	queue_free()
