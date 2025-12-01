extends CanvasLayer

signal initiative_complete(data: Dictionary)

@onready var steeltitans_theme = load("res://assets/themes/steeltitans_theme.tres")

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
var player_mech_destroyed = []  # Array de booleanos indicando si cada mech está destruido
var enemy_mech_destroyed = []   # Array de booleanos indicando si cada mech está destruido

# Variables para multiplayer
var is_multiplayer_mode: bool = false
var match_id: int = -1
var waiting_for_opponent_roll: bool = false
var waiting_for_opponent_start: bool = false

func _ready():
	visible = true
	layer = 100
	
	setup_ui()
	
	# Actualizar labels de mechs después de crear la UI
	call_deferred("_update_mech_labels")
	
	# Verificar si estamos en modo servidor (multijugador)
	call_deferred("_check_server_mode")
	
	# Conectar señales de multiplayer
	var network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager:
		if network_manager.is_in_match():
			is_multiplayer_mode = true
			match_id = network_manager.get_current_match_id()
			Log.info("Network", "Multiplayer mode detected", {"match_id": match_id})
			# Conectar señal de espera
			if not network_manager.initiative_waiting_update.is_connected(_on_waiting_update):
				network_manager.initiative_waiting_update.connect(_on_waiting_update)
			# Conectar señal de resultado de iniciativa
			if not network_manager.battle_initiative_result.is_connected(_on_server_initiative_result):
				network_manager.battle_initiative_result.connect(_on_server_initiative_result)

func _on_waiting_update(players_ready: int, players_total: int, wait_type: String):
	"""Actualiza UI cuando el servidor notifica estado de espera"""
	Log.debug("Network", "Waiting update", {
		"ready": players_ready,
		"total": players_total,
		"type": wait_type,
		"my_roll_sent": waiting_for_opponent_roll,
		"my_start_sent": waiting_for_opponent_start
	})
	
	if wait_type == "roll":
		# Solo actualizar UI si YO ya presioné Roll
		if waiting_for_opponent_roll:
			roll_button.text = "⏳ WAITING (%d/%d)" % [players_ready, players_total]
			roll_button.disabled = true
			subtitle_label.text = "Waiting for opponent to roll..."
		# Si ambos están listos, el servidor enviará client_initiative_result
	elif wait_type == "start":
		# Solo actualizar UI si YO ya presioné Start
		if waiting_for_opponent_start:
			continue_button.text = "⏳ WAITING (%d/%d)" % [players_ready, players_total]
			continue_button.disabled = true
		
		if players_ready >= players_total:
			# Ambos listos para empezar - cerrar pantalla
			Log.info("Match", "Both players ready to start - closing screen")
			_do_continue_animation()

func _on_server_initiative_result(result: Dictionary):
	"""Recibe el resultado de iniciativa del servidor"""
	Log.debug("Combat", "Server result received", result)
	waiting_for_opponent_roll = false
	_show_server_results(result)

func _update_mech_labels():
	# Buscar todos los labels de mechs y actualizar sus nombres
	for child in get_children():
		if child is Label and child.has_meta("mech_index"):
			var mech_index = child.get_meta("mech_index")
			var team = child.get_meta("team")
			
			if team == "player" and mech_index < player_mech_names.size():
				var is_dead = mech_index < player_mech_destroyed.size() and player_mech_destroyed[mech_index]
				if is_dead:
					# Tachar el nombre del mech muerto y cambiar color a gris
					child.text = "☠ " + player_mech_names[mech_index]
					child.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
					# Añadir línea de tachado usando una línea horizontal
					_add_strikethrough_to_label(child)
				else:
					child.text = player_mech_names[mech_index]
			elif team == "enemy" and mech_index < enemy_mech_names.size():
				var is_dead = mech_index < enemy_mech_destroyed.size() and enemy_mech_destroyed[mech_index]
				if is_dead:
					# Tachar el nombre del mech muerto y cambiar color a gris
					child.text = "☠ " + enemy_mech_names[mech_index]
					child.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
					_add_strikethrough_to_label(child)
				else:
					child.text = enemy_mech_names[mech_index]
	
	# También marcar visualmente los dados de mechs muertos
	_mark_dead_mech_dice()

func _add_strikethrough_to_label(label: Label):
	"""Añade una línea de tachado sobre el label"""
	# Esperar un frame para que el label tenga su tamaño
	await get_tree().process_frame
	
	if not is_instance_valid(label):
		return
	
	var line = ColorRect.new()
	line.color = Color(0.6, 0.6, 0.6, 0.8)
	line.size = Vector2(label.size.x * 0.8, 2)
	line.position = Vector2(label.position.x + 5, label.position.y + label.size.y / 2)
	add_child(line)

func _mark_dead_mech_dice():
	"""Marca visualmente los dados de mechs muertos con tachado y color gris"""
	# Marcar dados del jugador
	for i in range(4):
		var is_dead = i < player_mech_destroyed.size() and player_mech_destroyed[i]
		if is_dead:
			var dice_idx1 = i * 2
			var dice_idx2 = i * 2 + 1
			if dice_idx1 < player_dice.size():
				_mark_dice_as_dead(player_dice[dice_idx1])
			if dice_idx2 < player_dice.size():
				_mark_dice_as_dead(player_dice[dice_idx2])
	
	# Marcar dados del enemigo
	for i in range(4):
		var is_dead = i < enemy_mech_destroyed.size() and enemy_mech_destroyed[i]
		if is_dead:
			var dice_idx1 = i * 2
			var dice_idx2 = i * 2 + 1
			if dice_idx1 < enemy_dice.size():
				_mark_dice_as_dead(enemy_dice[dice_idx1])
			if dice_idx2 < enemy_dice.size():
				_mark_dice_as_dead(enemy_dice[dice_idx2])

func _mark_dice_as_dead(dice: Control):
	"""Marca un dado como perteneciente a un mech muerto"""
	if not is_instance_valid(dice):
		return
	
	# Reducir opacidad
	dice.modulate = Color(0.5, 0.5, 0.5, 0.6)
	
	# Cambiar el símbolo a X
	var label = dice.get_meta("label")
	if label:
		label.text = "✕"
		label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	
	# Añadir línea de tachado sobre el dado
	var dice_size = dice.get_meta("dice_size")
	var strike_line = ColorRect.new()
	strike_line.color = Color(0.7, 0.2, 0.2, 0.8)
	strike_line.size = Vector2(dice_size * 1.2, 3)
	strike_line.position = Vector2(-dice_size * 0.1, dice_size / 2 - 1)
	strike_line.rotation = -0.15  # Ligera inclinación
	dice.add_child(strike_line)
	
	# Marcar que este dado está muerto para no animarlo
	dice.set_meta("is_dead", true)

func _check_server_mode():
	"""Si estamos en modo servidor, mostrar resultados directamente"""
	if has_meta("server_mode") and get_meta("server_mode"):
		var server_result = get_meta("server_result")
		if server_result:
			Log.debug("Combat", "Server mode - showing server results")
			_show_server_results(server_result)

func _show_server_results(server_result: Dictionary):
	"""Muestra los resultados del servidor con animación de dados"""
	is_rolling = true
	roll_button.disabled = true
	roll_button.visible = false  # Ocultar botón de tirar
	subtitle_label.text = "Rolling initiative..."
	
	# Extraer datos del servidor - ahora es un array de [die1, die2] por mech
	var player_mech_rolls = server_result.get("player_mech_rolls", [])
	var enemy_mech_rolls = server_result.get("enemy_mech_rolls", [])
	
	Log.debug("Combat", "Server rolls", {
		"player_mechs": player_mech_rolls.size(),
		"enemy_mechs": enemy_mech_rolls.size()
	})
	
	# Asignar los dados de cada mech
	for i in range(4):
		if i < player_mech_rolls.size():
			var rolls = player_mech_rolls[i]
			player_results[i][0] = rolls[0] if rolls.size() > 0 else 1
			player_results[i][1] = rolls[1] if rolls.size() > 1 else 1
		else:
			# Mech no existe o está destruido
			player_results[i][0] = 0
			player_results[i][1] = 0
	
	for i in range(4):
		if i < enemy_mech_rolls.size():
			var rolls = enemy_mech_rolls[i]
			enemy_results[i][0] = rolls[0] if rolls.size() > 0 else 1
			enemy_results[i][1] = rolls[1] if rolls.size() > 1 else 1
		else:
			# Mech no existe o está destruido
			enemy_results[i][0] = 0
			enemy_results[i][1] = 0
	
	# Animar los dados con delays escalonados (como en single player)
	var delay = 0.0
	for i in range(4):
		if i < player_mech_rolls.size():
			# Dados del jugador (mech i)
			if i * 2 < player_dice.size():
				animate_dice_3d(player_dice[i * 2], player_results[i][0], delay)
				delay += 0.1
			if i * 2 + 1 < player_dice.size():
				animate_dice_3d(player_dice[i * 2 + 1], player_results[i][1], delay)
				delay += 0.1
	
	for i in range(4):
		if i < enemy_mech_rolls.size():
			# Dados del enemigo (mech i)
			if i * 2 < enemy_dice.size():
				animate_dice_3d(enemy_dice[i * 2], enemy_results[i][0], delay)
				delay += 0.1
			if i * 2 + 1 < enemy_dice.size():
				animate_dice_3d(enemy_dice[i * 2 + 1], enemy_results[i][1], delay)
				delay += 0.1
	
	# Esperar a que terminen las animaciones
	await get_tree().create_timer(2.5).timeout
	show_results()
	
	# En multiplayer, NO cerrar automáticamente - esperar a que ambos presionen Start Battle
	# El botón Start Battle ya se muestra en show_results()

func _auto_continue_server_mode():
	"""Cierra automáticamente la pantalla en modo servidor"""
	if not has_meta("server_mode") or not get_meta("server_mode"):
		return
	
	# Emitir señal y cerrar como si el usuario hubiera presionado continuar
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
	
	initiative_complete.emit(data)
	queue_free()

func _show_dice_result(dice: Control, value: int):
	"""Muestra un resultado de dado sin animación"""
	if not is_instance_valid(dice):
		return
	var label = dice.get_meta("label")
	if label:
		label.text = dice_faces[value - 1]

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
	roll_button.theme = steeltitans_theme
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
	continue_button.theme = steeltitans_theme
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
	
	# En modo multiplayer, notificar al servidor y esperar
	if is_multiplayer_mode:
		Log.debug("Network", "Multiplayer mode - sending roll ready to server")
		is_rolling = true
		roll_button.disabled = true
		roll_button.text = "⏳ WAITING (1/2)"
		subtitle_label.text = "Waiting for opponent to roll..."
		waiting_for_opponent_roll = true
		
		var network_manager = get_node_or_null("/root/NetworkManager")
		if network_manager:
			network_manager.rpc_id(1, "server_initiative_roll_ready", match_id)
		return
	
	# Modo singleplayer - comportamiento original
	is_rolling = true
	roll_button.disabled = true
	subtitle_label.text = "Rolling dice for all mechs..."
	
	# Tirar 2D6 para cada mech (solo para los vivos)
	for i in range(4):
		var player_is_dead = i < player_mech_destroyed.size() and player_mech_destroyed[i]
		var enemy_is_dead = i < enemy_mech_destroyed.size() and enemy_mech_destroyed[i]
		
		if not player_is_dead:
			player_results[i][0] = (randi() % 6) + 1
			player_results[i][1] = (randi() % 6) + 1
		else:
			player_results[i][0] = 0
			player_results[i][1] = 0
		
		if not enemy_is_dead:
			enemy_results[i][0] = (randi() % 6) + 1
			enemy_results[i][1] = (randi() % 6) + 1
		else:
			enemy_results[i][0] = 0
			enemy_results[i][1] = 0
	
	# Animar los 16 dados con delays escalonados (solo los vivos)
	var delay = 0.0
	for i in range(4):
		var player_is_dead = i < player_mech_destroyed.size() and player_mech_destroyed[i]
		if not player_is_dead:
			# Dados del jugador (mech i)
			animate_dice_3d(player_dice[i * 2], player_results[i][0], delay)
			delay += 0.1
			animate_dice_3d(player_dice[i * 2 + 1], player_results[i][1], delay)
			delay += 0.1
	
	for i in range(4):
		var enemy_is_dead = i < enemy_mech_destroyed.size() and enemy_mech_destroyed[i]
		if not enemy_is_dead:
			# Dados del enemigo (mech i)
			animate_dice_3d(enemy_dice[i * 2], enemy_results[i][0], delay)
			delay += 0.1
			animate_dice_3d(enemy_dice[i * 2 + 1], enemy_results[i][1], delay)
			delay += 0.1
	
	await get_tree().create_timer(2.5).timeout  # Optimizado para móvil: 0.4s lanzamiento + 0.7s caída + 0.3s flash + margen
	show_results()

func animate_dice_3d(dice: Control, final_result: int, delay: float):
	if not is_instance_valid(dice):
		return
	
	# No animar dados de mechs muertos
	if dice.has_meta("is_dead") and dice.get_meta("is_dead"):
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
	
	# OPTIMIZACIÓN MÓVIL: Reducir altura y efectos
	var launch_height = dice_size * 1.5  # Reducido aún más
	var horizontal_throw = (randf() - 0.5) * dice_size * 0.4
	
	# FASE 1: LANZAMIENTO (duración reducida, sin bucles await)
	var launch = create_tween()
	launch.set_parallel(true)
	launch.tween_property(dice, "position:y", original_pos.y - launch_height, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	launch.tween_property(dice, "position:x", original_pos.x + horizontal_throw, 0.4) \
		.set_trans(Tween.TRANS_CUBIC)
	# Reducir rotación a TAU (360°)
	launch.tween_property(dice, "rotation", TAU, 0.4) \
		.set_trans(Tween.TRANS_LINEAR)
	launch.tween_property(dice, "scale", Vector2(1.2, 1.2), 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# OPTIMIZACIÓN: Solo 3 cambios de cara durante lanzamiento
	await get_tree().create_timer(0.13).timeout
	if is_instance_valid(label):
		label.text = dice_faces[randi() % 6]
	await get_tree().create_timer(0.13).timeout
	if is_instance_valid(label):
		label.text = dice_faces[randi() % 6]
	await get_tree().create_timer(0.14).timeout
	if is_instance_valid(label):
		label.text = dice_faces[randi() % 6]
	
	# FASE 2: CAÍDA (duración reducida, sin bucles)
	var fall = create_tween()
	fall.set_parallel(true)
	fall.tween_property(dice, "position:y", original_pos.y, 0.7) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(dice, "position:x", original_pos.x, 0.6) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Reducir rotación a TAU * 2 (720°)
	fall.tween_property(dice, "rotation", TAU * 2, 0.7) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	fall.tween_property(dice, "scale", Vector2(1.0, 1.0), 0.6) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# OPTIMIZACIÓN: Solo 2 cambios de cara durante caída
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(label):
		label.text = dice_faces[randi() % 6]
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(label):
		label.text = dice_faces[randi() % 6]
	
	if not is_instance_valid(dice) or not is_instance_valid(label):
		return
	
	# FASE 3: RESULTADO FINAL
	dice.rotation = 0
	label.text = dice_faces[final_result - 1]
	
	# Bounce final más rápido
	dice.scale = Vector2(1.3, 1.3)
	var final_bounce = create_tween()
	final_bounce.tween_property(dice, "scale", Vector2(1.0, 1.0), 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if not is_instance_valid(panel):
		return
	
	# OPTIMIZACIÓN: Flash más simple - solo 1 pulso
	var original_style = panel.get_theme_stylebox("panel")
	if original_style == null:
		return
	
	# Cachear valores
	var border_width = int(dice_size * 0.08)
	var shadow_size_flash = int(dice_size * 0.16)
	
	# Crear estilo amarillo
	var yellow_style = original_style.duplicate()
	yellow_style.border_width_top = border_width
	yellow_style.border_width_bottom = border_width
	yellow_style.border_width_left = border_width
	yellow_style.border_width_right = border_width
	yellow_style.border_color = Color.YELLOW
	yellow_style.shadow_color = Color.YELLOW
	yellow_style.shadow_size = shadow_size_flash
	
	# Aplicar flash amarillo
	panel.add_theme_stylebox_override("panel", yellow_style)
	
	# Esperar y volver al color original
	await get_tree().create_timer(0.3).timeout
	
	if not is_instance_valid(panel):
		return
	
	# Restaurar estilo original con color del equipo
	var final_style = original_style.duplicate()
	final_style.border_width_top = int(dice_size * 0.04)
	final_style.border_width_bottom = int(dice_size * 0.04)
	final_style.border_width_left = int(dice_size * 0.04)
	final_style.border_width_right = int(dice_size * 0.04)
	final_style.border_color = glow_color
	final_style.shadow_color = glow_color
	final_style.shadow_size = int(dice_size * 0.14)
	panel.add_theme_stylebox_override("panel", final_style)

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
		var is_dead = i < player_mech_destroyed.size() and player_mech_destroyed[i]
		
		var row = HBoxContainer.new()
		row.position = Vector2(margin * 2, y_offset)
		row.size = Vector2(panel_width - margin * 4, 25 * scale_factor)
		player_panel.add_child(row)
		
		var name_label = Label.new()
		if is_dead:
			name_label.text = "☠ " + player_name
			name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
		else:
			name_label.text = player_name
			name_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1, 1))
		name_label.custom_minimum_size = Vector2(panel_width * 0.6, 25 * scale_factor)
		name_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		
		var score_label = Label.new()
		if is_dead:
			score_label.text = "――"  # Tachado visual para muertos
			score_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
		else:
			score_label.text = str(player_total)
			score_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
			score_label.add_theme_color_override("font_outline_color", Color(0, 0.2, 0, 1))
			score_label.add_theme_constant_override("outline_size", 2)
		score_label.custom_minimum_size = Vector2(50 * scale_factor, 25 * scale_factor)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score_label.add_theme_font_size_override("font_size", int(22 * scale_factor))
		row.add_child(score_label)
		
		# Añadir línea de tachado si está muerto
		if is_dead:
			var strike_line = ColorRect.new()
			strike_line.color = Color(0.7, 0.2, 0.2, 0.8)
			strike_line.size = Vector2(panel_width - margin * 6, 2)
			strike_line.position = Vector2(margin * 2, y_offset + 12 * scale_factor)
			player_panel.add_child(strike_line)
		
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
		var is_dead = i < enemy_mech_destroyed.size() and enemy_mech_destroyed[i]
		
		var row = HBoxContainer.new()
		row.position = Vector2(margin * 2, y_offset)
		row.size = Vector2(panel_width - margin * 4, 25 * scale_factor)
		enemy_panel.add_child(row)
		
		var name_label = Label.new()
		if is_dead:
			name_label.text = "☠ " + enemy_name
			name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
		else:
			name_label.text = enemy_name
			name_label.add_theme_color_override("font_color", Color(1, 0.8, 0.8, 1))
		name_label.custom_minimum_size = Vector2(panel_width * 0.6, 25 * scale_factor)
		name_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		
		var score_label = Label.new()
		if is_dead:
			score_label.text = "――"  # Tachado visual para muertos
			score_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
		else:
			score_label.text = str(enemy_total)
			score_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
			score_label.add_theme_color_override("font_outline_color", Color(0.2, 0, 0, 1))
			score_label.add_theme_constant_override("outline_size", 2)
		score_label.custom_minimum_size = Vector2(50 * scale_factor, 25 * scale_factor)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score_label.add_theme_font_size_override("font_size", int(22 * scale_factor))
		row.add_child(score_label)
		
		# Añadir línea de tachado si está muerto
		if is_dead:
			var strike_line = ColorRect.new()
			strike_line.color = Color(0.7, 0.2, 0.2, 0.8)
			strike_line.size = Vector2(panel_width - margin * 6, 2)
			strike_line.position = Vector2(margin * 2, y_offset + 12 * scale_factor)
			enemy_panel.add_child(strike_line)
		
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
	
	# En modo multiplayer, notificar al servidor y esperar
	if is_multiplayer_mode:
		Log.debug("Network", "Multiplayer mode - sending start ready to server")
		continue_button.text = "⏳ WAITING (1/2)"
		waiting_for_opponent_start = true
		
		var network_manager = get_node_or_null("/root/NetworkManager")
		if network_manager:
			network_manager.rpc_id(1, "server_start_battle_ready", match_id)
		return
	
	# Modo singleplayer - comportamiento original
	_do_continue_animation()

func _do_continue_animation():
	"""Animación de salida y emitir señal de completado"""
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
		if is_instance_valid(dice):
			var exit = create_tween()
			exit.set_parallel(true)
			exit.tween_property(dice, "position:y", -300, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			exit.tween_property(dice, "modulate:a", 0.0, 0.8)
	
	var fade = create_tween()
	fade.set_parallel(true)
	if is_instance_valid(roll_button):
		fade.tween_property(roll_button, "modulate:a", 0.0, 0.6)
	if is_instance_valid(result_label):
		fade.tween_property(result_label, "modulate:a", 0.0, 0.6)
	if is_instance_valid(continue_button):
		fade.tween_property(continue_button, "modulate:a", 0.0, 0.6)
	
	await fade.finished
	
	initiative_complete.emit(data)
	queue_free()
