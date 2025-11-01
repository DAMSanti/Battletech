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
	print("████ INITIATIVE SCREEN LOADING ████")
	visible = true
	layer = 100
	
	# TEST: Verificar array de dados
	print("████ DICE ARRAY TEST ████")
	for i in range(6):
		print("Index ", i, " (dice value ", i+1, "): '", dice_faces[i], "'")
	print("████████████████████████")
	
	setup_ui()
	print("████ INITIATIVE SCREEN READY ████")

func setup_ui():
	# Fondo oscuro
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.08, 0.98)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1080, 1920)
	add_child(bg)
	
	# Panel decorativo superior
	var top_panel = Panel.new()
	top_panel.position = Vector2(90, 80)
	top_panel.size = Vector2(900, 180)
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.08, 0.08, 0.15, 0.9)
	top_style.border_width_top = 3
	top_style.border_width_bottom = 3
	top_style.border_width_left = 3
	top_style.border_width_right = 3
	top_style.border_color = Color.GOLD
	top_style.corner_radius_top_left = 15
	top_style.corner_radius_top_right = 15
	top_style.corner_radius_bottom_left = 15
	top_style.corner_radius_bottom_right = 15
	top_panel.add_theme_stylebox_override("panel", top_style)
	add_child(top_panel)
	
	# Título
	var title = Label.new()
	title.text = "⚔ BATTLETECH INITIATIVE ⚔"
	title.position = Vector2(180, 110)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color.GOLD)
	add_child(title)
	
	# Subtítulo
	subtitle_label = Label.new()
	subtitle_label.text = "Roll for initiative to determine move order"
	subtitle_label.position = Vector2(270, 190)
	subtitle_label.add_theme_font_size_override("font_size", 24)
	subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	add_child(subtitle_label)
	
	# Headers y dados
	var player_header = Label.new()
	player_header.text = "★ PLAYER DICE ★"
	player_header.position = Vector2(120, 320)
	player_header.add_theme_font_size_override("font_size", 36)
	player_header.add_theme_color_override("font_color", Color.CYAN)
	add_child(player_header)
	
	player_dice.append(create_3d_dice(Vector2(150, 500), Color.CYAN))
	player_dice.append(create_3d_dice(Vector2(350, 500), Color.CYAN))
	
	var enemy_header = Label.new()
	enemy_header.text = "★ ENEMY DICE ★"
	enemy_header.position = Vector2(620, 320)
	enemy_header.add_theme_font_size_override("font_size", 36)
	enemy_header.add_theme_color_override("font_color", Color.RED)
	add_child(enemy_header)
	
	enemy_dice.append(create_3d_dice(Vector2(600, 500), Color.RED))
	enemy_dice.append(create_3d_dice(Vector2(800, 500), Color.RED))
	
	# Botón Roll
	roll_button = Button.new()
	roll_button.text = "🎲 ROLL DICE 🎲"
	roll_button.position = Vector2(290, 900)
	roll_button.custom_minimum_size = Vector2(500, 140)
	roll_button.add_theme_font_size_override("font_size", 52)
	roll_button.pressed.connect(_on_roll_pressed)
	add_child(roll_button)
	
	# Resultado
	result_label = Label.new()
	result_label.position = Vector2(150, 1100)
	result_label.add_theme_font_size_override("font_size", 48)
	result_label.visible = false
	add_child(result_label)
	
	# Botón continuar
	continue_button = Button.new()
	continue_button.text = "⚔ START BATTLE ⚔"
	continue_button.position = Vector2(290, 1450)
	continue_button.custom_minimum_size = Vector2(500, 140)
	continue_button.add_theme_font_size_override("font_size", 52)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = false
	add_child(continue_button)

func create_3d_dice(pos: Vector2, glow_color: Color) -> Control:
	var dice = Control.new()
	dice.position = pos
	dice.custom_minimum_size = Vector2(180, 180)
	add_child(dice)
	
	# Sombra
	var shadow = Panel.new()
	shadow.position = Vector2(15, 15)
	shadow.custom_minimum_size = Vector2(180, 180)
	var shadow_style = StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.5)
	shadow_style.corner_radius_top_left = 25
	shadow_style.corner_radius_top_right = 25
	shadow_style.corner_radius_bottom_left = 25
	shadow_style.corner_radius_bottom_right = 25
	shadow.add_theme_stylebox_override("panel", shadow_style)
	dice.add_child(shadow)
	
	# Panel del dado
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(180, 180)
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.corner_radius_top_left = 25
	style.corner_radius_top_right = 25
	style.corner_radius_bottom_left = 25
	style.corner_radius_bottom_right = 25
	style.border_width_top = 8
	style.border_width_bottom = 8
	style.border_width_left = 8
	style.border_width_right = 8
	style.border_color = glow_color
	style.shadow_color = glow_color
	style.shadow_size = 20
	panel.add_theme_stylebox_override("panel", style)
	dice.add_child(panel)
	
	# Label
	var label = Label.new()
	label.text = "?"
	label.custom_minimum_size = Vector2(180, 180)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 120)
	label.add_theme_color_override("font_color", Color.BLACK)
	dice.add_child(label)
	
	dice.set_meta("label", label)
	dice.set_meta("panel", panel)
	dice.set_meta("shadow", shadow)
	dice.set_meta("glow_color", glow_color)
	dice.set_meta("original_pos", pos)
	
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
	
	print("████ DICE RESULTS ████")
	print("Player Dice 1: ", player_results[0], " (index:", player_results[0] - 1, " showing: '", dice_faces[player_results[0] - 1], "')")
	print("Player Dice 2: ", player_results[1], " (index:", player_results[1] - 1, " showing: '", dice_faces[player_results[1] - 1], "')")
	print("Enemy Dice 1: ", enemy_results[0], " (index:", enemy_results[0] - 1, " showing: '", dice_faces[enemy_results[0] - 1], "')")
	print("Enemy Dice 2: ", enemy_results[1], " (index:", enemy_results[1] - 1, " showing: '", dice_faces[enemy_results[1] - 1], "')")
	print("Dice faces array: ", dice_faces)
	print("████████████████████████")
	
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
	
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	
	if not is_instance_valid(dice):
		return
	
	# FASE 1: LANZAMIENTO EXPLOSIVO
	var launch_height = 500
	var horizontal_throw = (randf() - 0.5) * 150
	
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
	
	print("████ FINAL DICE: ", final_result, " showing: ", correct_face, " ████")
	
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
		
	style = style.duplicate()
	style.border_width_top = 15
	style.border_width_bottom = 15
	style.border_width_left = 15
	style.border_width_right = 15
	style.border_color = Color.YELLOW
	style.shadow_color = Color.YELLOW
	style.shadow_size = 40
	panel.add_theme_stylebox_override("panel", style)
	
	# Pulsar 3 veces
	for i in range(3):
		await get_tree().create_timer(0.15).timeout
		if not is_instance_valid(panel):
			return
		var pulse = style.duplicate()
		pulse.shadow_size = 40 if i % 2 == 0 else 25
		panel.add_theme_stylebox_override("panel", pulse)
	
	await get_tree().create_timer(0.3).timeout
	
	if not is_instance_valid(panel):
		return
	
	# Volver al color original
	style = style.duplicate()
	style.border_width_top = 8
	style.border_width_bottom = 8
	style.border_width_left = 8
	style.border_width_right = 8
	style.border_color = glow_color
	style.shadow_color = glow_color
	style.shadow_size = 25
	panel.add_theme_stylebox_override("panel", style)

func show_results():
	print("████ SHOW_RESULTS CALLED ████")
	print("player_results array: ", player_results)
	print("enemy_results array: ", enemy_results)
	
	var player_total = player_results[0] + player_results[1]
	var enemy_total = enemy_results[0] + enemy_results[1]
	var winner = "player" if player_total >= enemy_total else "enemy"
	
	print("Player total: ", player_total, " (", player_results[0], " + ", player_results[1], ")")
	print("Enemy total: ", enemy_total, " (", enemy_results[0], " + ", enemy_results[1], ")")
	print("████████████████████████")
	
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
	
	print("Initiative complete: ", data)
	
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
