extends CanvasLayer

signal initiative_complete(data: Dictionary)

var roll_button: Button
var result_label: Label
var continue_button: Button
var subtitle_label: Label

var player_dice: Array = []
var enemy_dice: Array = []

var player_results = [0, 0]
var enemy_results = [0, 0]

# Unicode dice: ⚀ ⚁ ⚂ ⚃ ⚄ ⚅
var dice_faces = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
var is_rolling = false

func _ready():
	visible = true
	layer = 100
	
	setup_ui()

func setup_ui():
	# Obtener tamaño de pantalla
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y
	var scale_factor = screen_width / 720.0  # Escalar basado en ancho de 720px
	var margin = 10 * scale_factor
	
	
	# Fondo oscuro
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.08, 0.98)
	bg.position = Vector2.ZERO
	bg.size = viewport_size
	add_child(bg)
	
	# Panel decorativo superior (95% del ancho)
	var panel_width = screen_width * 0.95
	var top_panel = Panel.new()
	top_panel.position = Vector2((screen_width - panel_width) / 2, margin * 2)
	top_panel.size = Vector2(panel_width, screen_height * 0.12)
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.08, 0.08, 0.15, 0.9)
	top_style.border_width_top = int(3 * scale_factor)
	top_style.border_width_bottom = int(3 * scale_factor)
	top_style.border_width_left = int(3 * scale_factor)
	top_style.border_width_right = int(3 * scale_factor)
	top_style.border_color = Color.GOLD
	top_style.corner_radius_top_left = int(15 * scale_factor)
	top_style.corner_radius_top_right = int(15 * scale_factor)
	top_style.corner_radius_bottom_left = int(15 * scale_factor)
	top_style.corner_radius_bottom_right = int(15 * scale_factor)
	top_panel.add_theme_stylebox_override("panel", top_style)
	add_child(top_panel)
	
	# Título
	var title = Label.new()
	title.text = "⚔ BATTLETECH INITIATIVE ⚔"
	title.position = Vector2(screen_width * 0.05, screen_height * 0.04)
	title.size = Vector2(screen_width * 0.9, screen_height * 0.06)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", int(32 * scale_factor))
	title.add_theme_color_override("font_color", Color.GOLD)
	add_child(title)
	
	# Subtítulo
	subtitle_label = Label.new()
	subtitle_label.text = "Roll for initiative to determine move order"
	subtitle_label.position = Vector2(screen_width * 0.05, screen_height * 0.10)
	subtitle_label.size = Vector2(screen_width * 0.9, screen_height * 0.04)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", int(18 * scale_factor))
	subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	add_child(subtitle_label)
	
	# Headers y dados
	var dice_size = screen_width * 0.22  # 22% del ancho
	var dice_y_pos = screen_height * 0.25
	
	var player_header = Label.new()
	player_header.text = "★ PLAYER DICE ★"
	player_header.position = Vector2(screen_width * 0.05, screen_height * 0.18)
	player_header.size = Vector2(screen_width * 0.4, screen_height * 0.05)
	player_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_header.add_theme_font_size_override("font_size", int(22 * scale_factor))
	player_header.add_theme_color_override("font_color", Color.CYAN)
	add_child(player_header)
	
	# Dados del jugador (uno arriba del otro)
	player_dice.append(create_3d_dice(Vector2(screen_width * 0.25 - dice_size / 2, dice_y_pos), Color.CYAN, dice_size))
	player_dice.append(create_3d_dice(Vector2(screen_width * 0.25 - dice_size / 2, dice_y_pos + dice_size + margin * 2), Color.CYAN, dice_size))
	
	var enemy_header = Label.new()
	enemy_header.text = "★ ENEMY DICE ★"
	enemy_header.position = Vector2(screen_width * 0.55, screen_height * 0.18)
	enemy_header.size = Vector2(screen_width * 0.4, screen_height * 0.05)
	enemy_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_header.add_theme_font_size_override("font_size", int(22 * scale_factor))
	enemy_header.add_theme_color_override("font_color", Color.RED)
	add_child(enemy_header)
	
	# Dados del enemigo (uno arriba del otro)
	enemy_dice.append(create_3d_dice(Vector2(screen_width * 0.75 - dice_size / 2, dice_y_pos), Color.RED, dice_size))
	enemy_dice.append(create_3d_dice(Vector2(screen_width * 0.75 - dice_size / 2, dice_y_pos + dice_size + margin * 2), Color.RED, dice_size))
	
	# Botón Roll
	var button_y = dice_y_pos + dice_size * 2 + margin * 8
	roll_button = Button.new()
	roll_button.text = "🎲 ROLL DICE 🎲"
	roll_button.position = Vector2(screen_width * 0.1, button_y)
	roll_button.custom_minimum_size = Vector2(screen_width * 0.8, screen_height * 0.08)
	roll_button.add_theme_font_size_override("font_size", int(28 * scale_factor))
	roll_button.pressed.connect(_on_roll_pressed)
	add_child(roll_button)
	
	# Resultado
	result_label = Label.new()
	result_label.position = Vector2(screen_width * 0.05, button_y + screen_height * 0.12)
	result_label.size = Vector2(screen_width * 0.9, screen_height * 0.15)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", int(24 * scale_factor))
	result_label.visible = false
	add_child(result_label)
	
	# Botón continuar
	continue_button = Button.new()
	continue_button.text = "⚔ START BATTLE ⚔"
	continue_button.position = Vector2(screen_width * 0.1, screen_height - screen_height * 0.15)
	continue_button.custom_minimum_size = Vector2(screen_width * 0.8, screen_height * 0.08)
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
	subtitle_label.text = "Rolling dice..."
	
	player_results[0] = (randi() % 6) + 1
	player_results[1] = (randi() % 6) + 1
	enemy_results[0] = (randi() % 6) + 1
	enemy_results[1] = (randi() % 6) + 1
	
	
	# Animar dados con delays
	animate_dice_3d(player_dice[0], player_results[0], 0.0)
	animate_dice_3d(player_dice[1], player_results[1], 0.2)
	animate_dice_3d(enemy_dice[0], enemy_results[0], 0.4)
	animate_dice_3d(enemy_dice[1], enemy_results[1], 0.6)
	
	await get_tree().create_timer(4.5).timeout
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
	
	var player_total = player_results[0] + player_results[1]
	var enemy_total = enemy_results[0] + enemy_results[1]
	var winner = "player" if player_total >= enemy_total else "enemy"
	
	
	subtitle_label.text = "Initiative determined!"
	
	result_label.text = "PLAYER: %d + %d = %d\nENEMY: %d + %d = %d\n\n" % [
		player_results[0], player_results[1], player_total,
		enemy_results[0], enemy_results[1], enemy_total
	]
	
	if winner == "player":
		result_label.text += "★★★ PLAYER WINS! ★★★"
		result_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		result_label.text += "⚠ ENEMY WINS! ⚠"
		result_label.add_theme_color_override("font_color", Color.ORANGE_RED)
	
	result_label.visible = true
	result_label.modulate = Color(1, 1, 1, 0)
	result_label.scale = Vector2(0.5, 0.5)
	
	var fade = create_tween()
	fade.set_parallel(true)
	fade.tween_property(result_label, "modulate", Color.WHITE, 0.6)
	fade.tween_property(result_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(0.8).timeout
	
	continue_button.visible = true
	continue_button.modulate = Color(1, 1, 1, 0)
	
	var btn_fade = create_tween()
	btn_fade.tween_property(continue_button, "modulate", Color.WHITE, 0.5)
	
	is_rolling = false

func _on_continue_pressed():
	continue_button.disabled = true
	
	var player_total = player_results[0] + player_results[1]
	var enemy_total = enemy_results[0] + enemy_results[1]
	
	var data = {
		"player_dice": player_results.duplicate(),
		"player_total": player_total,
		"enemy_dice": enemy_results.duplicate(),
		"enemy_total": enemy_total,
		"winner": "player" if player_total >= enemy_total else "enemy"
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
