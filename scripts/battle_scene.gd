extends Node2D

# Referencias (sin @onready porque necesitamos esperar)
var hex_grid
var turn_manager
var ui

var player_mechs: Array = []
var enemy_mechs: Array = []

var selected_unit = null
var selected_hex: Vector2i = Vector2i(-1, -1)

var reachable_hexes: Array = []
var target_hexes: Array = []
var physical_target_hexes: Array = []  # Enemigos adyacentes para ataque físico

enum GameState {
	MOVING,
	TARGETING,
	PHYSICAL_TARGETING,
	ENEMY_TURN,
	ANIMATION
}

var current_state: GameState = GameState.MOVING

var initiative_screen_scene = preload("res://scenes/initiative_screen.tscn")
var initiative_data_stored: Dictionary = {}
var battle_started = false

func _ready():
	print("████████████████████████████████████████")
	print("███ BATTLE SCENE READY ███")
	print("████████████████████████████████████████")
	
	# Mostrar pantalla de iniciativa INMEDIATAMENTE
	show_initiative_screen()

func show_initiative_screen():
	print("████████████████████████████████████████")
	print("███ CREATING INITIATIVE SCREEN ███")
	print("████████████████████████████████████████")
	var initiative_screen = initiative_screen_scene.instantiate()
	
	# CRÍTICO: Poner el CanvasLayer en un layer MÁS ALTO que el UI
	# Los layers más altos se renderizan encima
	initiative_screen.layer = 100  # UI está en layer 0 por defecto
	
	add_child(initiative_screen)
	
	# Conectar señal
	if initiative_screen.initiative_complete.connect(_on_initiative_screen_complete) == OK:
		print("███ Initiative screen signal connected!")
	else:
		print("███ ERROR: Could not connect initiative screen signal!")
	
	print("███ Initiative screen added to scene tree on layer 100")
	print("████████████████████████████████████████")

func _on_initiative_screen_complete(data: Dictionary):
	print("Initiative complete! Starting battle with data: ", data)
	
	# Guardar datos de iniciativa
	initiative_data_stored = data
	
	# Ahora obtener referencias a los nodos
	hex_grid = $HexGrid
	turn_manager = $TurnManager
	ui = $UI
	
	# Configurar la batalla
	_setup_battle()
	
	# Conectar señales DESPUÉS de setup
	turn_manager.turn_changed.connect(_on_turn_changed)
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.unit_activated.connect(_on_unit_activated)
	turn_manager.initiative_rolled.connect(_on_initiative_rolled)
	
	battle_started = true
	
	print("Battle started!")

func get_stored_initiative() -> Dictionary:
	return initiative_data_stored

func _setup_battle():
	# Crear mechs de prueba
	var player_mech = Mech.new()
	player_mech.mech_name = "Atlas"
	player_mech.hex_position = Vector2i(2, 8)
	player_mech.pilot_name = "Player"
	add_child(player_mech)
	player_mechs.append(player_mech)
	hex_grid.set_unit(player_mech.hex_position, player_mech)
	
	var enemy_mech = Mech.new()
	enemy_mech.mech_name = "Mad Cat"
	enemy_mech.hex_position = Vector2i(8, 8)
	enemy_mech.pilot_name = "Enemy"
	enemy_mech.tonnage = 75
	enemy_mech.movement_points = 5
	add_child(enemy_mech)
	enemy_mechs.append(enemy_mech)
	hex_grid.set_unit(enemy_mech.hex_position, enemy_mech)
	
	# Iniciar batalla
	turn_manager.start_battle(player_mechs, enemy_mechs)

func _input(event):
	# No procesar input si la batalla aún no ha comenzado
	if not battle_started or hex_grid == null:
		return
		
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.pressed):
		var touch_pos = event.position
		var hex = hex_grid.pixel_to_hex(touch_pos - hex_grid.global_position)
		_handle_hex_clicked(hex)

func _handle_hex_clicked(hex: Vector2i):
	if not hex_grid.is_valid_hex(hex):
		return
	
	match current_state:
		GameState.MOVING:
			_handle_movement_click(hex)
		GameState.TARGETING:
			_handle_targeting_click(hex)
		GameState.PHYSICAL_TARGETING:
			_handle_physical_targeting_click(hex)

func _handle_movement_click(hex: Vector2i):
	if selected_unit == null:
		return
	
	# Solo permitir movimiento si es el turno del jugador
	if selected_unit not in player_mechs:
		return
	
	# Verificar que el hexágono sea alcanzable
	if hex in reachable_hexes:
		_move_unit_to_hex(selected_unit, hex)

func _move_unit_to_hex(unit, hex: Vector2i):
	# Calcular camino
	var path = hex_grid.find_path(unit.hex_position, hex, unit.current_movement)
	
	if path.size() > 0:
		# Calcular coste de movimiento
		var movement_cost = path.size() - 1
		
		# Actualizar posición en el grid
		hex_grid.set_unit(unit.hex_position, null)
		var old_pos = unit.hex_position
		unit.hex_position = hex
		hex_grid.set_unit(hex, unit)
		
		# Reducir movimiento
		unit.current_movement -= movement_cost
		
		# Log de movimiento
		if ui:
			ui.add_combat_message("%s moves from [%d,%d] to [%d,%d]" % [unit.mech_name, old_pos.x, old_pos.y, hex.x, hex.y], Color.WHITE)
			ui.update_unit_info(unit)
		
		# Actualizar hexágonos alcanzables
		if unit.current_movement > 0:
			reachable_hexes = hex_grid.get_reachable_hexes(unit.hex_position, unit.current_movement)
		else:
			reachable_hexes.clear()
			turn_manager.complete_unit_activation()
		
		queue_redraw()

func _handle_targeting_click(hex: Vector2i):
	# Solo permitir atacar si es el turno del jugador
	if selected_unit == null or selected_unit not in player_mechs:
		return
	
	var target = hex_grid.get_unit(hex)
	
	if target != null and target in enemy_mechs:
		_attack_target(selected_unit, target)

func _handle_physical_targeting_click(hex: Vector2i):
	# Solo permitir ataque físico si es el turno del jugador
	if selected_unit == null or selected_unit not in player_mechs:
		return
	
	var target = hex_grid.get_unit(hex)
	
	if target != null and target in enemy_mechs and hex in physical_target_hexes:
		_show_physical_attack_menu(target)

func _attack_target(attacker, target):
	var distance = hex_grid.hex_distance(attacker.hex_position, target.hex_position)
	
	if ui:
		ui.add_combat_message("=== %s attacks %s (range: %d) ===" % [attacker.mech_name, target.mech_name, distance], Color.YELLOW)
	
	# Por ahora, disparar con el primer arma disponible
	for i in range(attacker.weapons.size()):
		var fire_result = attacker.fire_weapon(i, distance)
		
		if fire_result.get("can_fire", false):
			# Tirar para impactar (2d6 + modificadores vs target 8)
			var roll = randi() % 6 + randi() % 6 + 2
			var target_number = 8 + fire_result["to_hit_modifier"]
			
			var msg = "%s fires %s (roll: %d vs %d)" % [attacker.mech_name, fire_result["weapon_name"], roll, target_number]
			
			if roll >= target_number:
				# Impacto! Determinar localización
				var hit_location = _roll_hit_location()
				var damage_result = target.take_damage(hit_location, fire_result["damage"])
				
				if ui:
					ui.add_combat_message(msg + " - HIT!", Color.GREEN)
					ui.add_combat_message("  → Hit %s in %s for %d damage" % [
						target.mech_name,
						hit_location,
						fire_result["damage"]
					], Color.ORANGE)
				
				if damage_result["mech_destroyed"]:
					if ui:
						ui.add_combat_message("  → %s DESTROYED!" % target.mech_name, Color.RED)
			else:
				if ui:
					ui.add_combat_message(msg + " - MISS", Color.GRAY)
	
	if ui:
		ui.update_unit_info(attacker)
	
	turn_manager.complete_unit_activation()
	queue_redraw()

func _roll_hit_location() -> String:
	var roll = randi() % 6 + randi() % 6 + 2
	
	match roll:
		2:
			return "center_torso"
		3:
			return "right_arm"
		4:
			return "right_arm"
		5:
			return "right_leg"
		6:
			return "right_torso"
		7:
			return "center_torso"
		8:
			return "left_torso"
		9:
			return "left_leg"
		10:
			return "left_arm"
		11:
			return "left_arm"
		12:
			return "head"
	
	return "center_torso"

func _on_turn_changed(team: String, turn_number: int):
	print("Turn %d - %s team" % [turn_number, team])
	
	# Actualizar UI con el turno
	if ui:
		ui.update_turn_info(turn_number, team)

func _on_initiative_rolled(data: Dictionary):
	# No mostrar animación de dados 3D porque ya se vio en la pantalla de iniciativa
	
	# Solo mostrar en el chat como referencia
	if ui:
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("╔═══════════════════════════════╗", Color.GOLD)
		ui.add_combat_message("║     INITIATIVE PHASE          ║", Color.GOLD)
		ui.add_combat_message("╚═══════════════════════════════╝", Color.GOLD)
		
		ui.add_combat_message("Player rolls: [%d] + [%d] = %d" % [
			data["player_dice"][0],
			data["player_dice"][1],
			data["player_total"]
		], Color.CYAN)
		
		ui.add_combat_message("Enemy rolls: [%d] + [%d] = %d" % [
			data["enemy_dice"][0],
			data["enemy_dice"][1],
			data["enemy_total"]
		], Color.RED)
		
		ui.add_combat_message("", Color.WHITE)
		
		if data["winner"] == "player":
			ui.add_combat_message("★ PLAYER WINS INITIATIVE! ★", Color.GREEN)
			ui.add_combat_message("Player team moves first", Color.CYAN)
		else:
			ui.add_combat_message("★ ENEMY WINS INITIATIVE! ★", Color.ORANGE_RED)
			ui.add_combat_message("Enemy team moves first", Color.RED)
		
		ui.add_combat_message("", Color.WHITE)

func _on_initiative_result(data: Dictionary):
	# Esta función es llamada directamente por el turn_manager
	_on_initiative_rolled(data)

func _on_phase_changed(phase: String):
	print("Phase: " + phase)
	
	match phase:
		"MOVEMENT":
			current_state = GameState.MOVING
		"WEAPON_ATTACK":
			current_state = GameState.TARGETING
		"PHYSICAL_ATTACK":
			current_state = GameState.PHYSICAL_TARGETING
		"ENEMY_TURN":
			current_state = GameState.ENEMY_TURN
	
	# Actualizar UI con la fase
	if ui:
		ui.update_phase_info(phase)

func _on_unit_activated(unit):
	print("Unit activated: " + unit.mech_name)
	selected_unit = unit
	
	# Limpiar hexágonos anteriores
	reachable_hexes.clear()
	target_hexes.clear()
	
	# Actualizar UI inmediatamente
	if ui:
		ui.update_unit_info(unit)
		print("UI updated with unit info")
	else:
		print("WARNING: UI is null!")
	
	if unit in player_mechs:
		# Turno del jugador - ESPERAR input del usuario
		if current_state == GameState.MOVING:
			reachable_hexes = hex_grid.get_reachable_hexes(unit.hex_position, unit.current_movement)
			if ui:
				ui.add_combat_message("Your turn: Move %s" % unit.mech_name, Color.CYAN)
		elif current_state == GameState.TARGETING:
			# Mostrar enemigos en rango
			for enemy in enemy_mechs:
				if not enemy.is_destroyed:
					target_hexes.append(enemy.hex_position)
			if ui:
				ui.add_combat_message("Your turn: Fire weapons with %s" % unit.mech_name, Color.ORANGE)
		elif current_state == GameState.PHYSICAL_TARGETING:
			# Mostrar enemigos adyacentes para ataque físico
			physical_target_hexes.clear()
			for enemy in enemy_mechs:
				if not enemy.is_destroyed:
					var dist = hex_grid.hex_distance(unit.hex_position, enemy.hex_position)
					if dist <= 1:
						physical_target_hexes.append(enemy.hex_position)
			if ui:
				ui.add_combat_message("Your turn: Physical attack with %s" % unit.mech_name, Color.MAGENTA)
	else:
		# Turno enemigo - ejecutar IA automáticamente
		if ui:
			ui.add_combat_message("Enemy turn: %s" % unit.mech_name, Color.RED)
		# Esperar un poco antes de que la IA actúe para que se vea
		await get_tree().create_timer(0.5).timeout
		_ai_turn(unit)
	
	queue_redraw()

func _ai_turn(unit):
	if current_state == GameState.MOVING:
		# Mover hacia el jugador más cercano
		var closest_player = null
		var min_distance = INF
		
		for player in player_mechs:
			if not player.is_destroyed:
				var dist = hex_grid.hex_distance(unit.hex_position, player.hex_position)
				if dist < min_distance:
					min_distance = dist
					closest_player = player
		
		if closest_player:
			# Intentar moverse hacia el jugador
			var reachable = hex_grid.get_reachable_hexes(unit.hex_position, unit.current_movement)
			
			var best_hex = unit.hex_position
			var best_distance = min_distance
			
			for hex in reachable:
				var dist = hex_grid.hex_distance(hex, closest_player.hex_position)
				if dist < best_distance:
					best_distance = dist
					best_hex = hex
			
			if best_hex != unit.hex_position:
				await get_tree().create_timer(0.3).timeout
				_move_unit_to_hex(unit, best_hex)
			else:
				# No puede moverse, terminar activación
				turn_manager.complete_unit_activation()
		else:
			turn_manager.complete_unit_activation()
	
	elif current_state == GameState.TARGETING:
		# Disparar al jugador más cercano
		var closest_player = null
		var min_distance = INF
		
		for player in player_mechs:
			if not player.is_destroyed:
				var dist = hex_grid.hex_distance(unit.hex_position, player.hex_position)
				if dist < min_distance:
					min_distance = dist
					closest_player = player
		
		if closest_player:
			await get_tree().create_timer(0.3).timeout
			_attack_target(unit, closest_player)
		else:
			turn_manager.complete_unit_activation()
	
	elif current_state == GameState.PHYSICAL_TARGETING:
		# Ataque físico al jugador más cercano (si está adyacente)
		var closest_player = null
		var min_distance = INF
		
		for player in player_mechs:
			if not player.is_destroyed:
				var dist = hex_grid.hex_distance(unit.hex_position, player.hex_position)
				if dist <= 1 and dist < min_distance:
					min_distance = dist
					closest_player = player
		
		if closest_player:
			await get_tree().create_timer(0.3).timeout
			# IA elige puñetazo como ataque por defecto
			_perform_physical_attack(unit, closest_player, "punch_right")
		else:
			turn_manager.complete_unit_activation()

func _draw():
	if hex_grid == null:
		return
	
	# Dibujar grid hexagonal
	for q in range(hex_grid.grid_width):
		for r in range(hex_grid.grid_height):
			var hex = Vector2i(q, r)
			var pixel = hex_grid.hex_to_pixel(hex) + hex_grid.global_position
			
			# Color base
			var color = Color(0.2, 0.2, 0.25, 1.0)
			var border_color = Color(0.4, 0.4, 0.45, 1.0)
			var border_width = 1.0
			
			# Hexágonos alcanzables (azul brillante)
			if hex in reachable_hexes:
				color = Color(0.2, 0.5, 1.0, 0.5)
				border_color = Color.CYAN
				border_width = 3.0
			
			# Hexágonos con objetivos (rojo brillante)
			if hex in target_hexes:
				color = Color(1.0, 0.2, 0.2, 0.5)
				border_color = Color.ORANGE_RED
				border_width = 3.0
			
			# Hexágonos con objetivos físicos (magenta brillante)
			if hex in physical_target_hexes:
				color = Color(1.0, 0.0, 1.0, 0.5)
				border_color = Color.MAGENTA
				border_width = 3.0
			
			# Dibujar hexágono
			_draw_hexagon(pixel, hex_grid.hex_size, color, border_color, border_width)
			
			# Dibujar unidad si existe
			var unit = hex_grid.get_unit(hex)
			if unit != null:
				var unit_color = Color.GREEN if unit in player_mechs else Color.RED
				var outline_color = Color.DARK_GREEN if unit in player_mechs else Color.DARK_RED
				
				# Círculo exterior (outline)
				draw_circle(pixel, 26, outline_color)
				# Círculo principal
				draw_circle(pixel, 22, unit_color)
				
				# Si es la unidad seleccionada, añadir un anillo brillante
				if unit == selected_unit:
					draw_arc(pixel, 30, 0, TAU, 32, Color.YELLOW, 3.0)
				
				# Nombre del mech
				var font = ThemeDB.fallback_font
				var font_size = 14
				var text = unit.mech_name
				var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
				draw_string(font, pixel + Vector2(-text_size.x / 2, -35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
				
				# Barra de salud (armadura)
				var total_armor = 0
				var current_armor = 0
				for loc in unit.armor.keys():
					total_armor += unit.armor[loc]["max"]
					current_armor += unit.armor[loc]["current"]
				
				var health_percent = float(current_armor) / float(total_armor)
				var bar_width = 40.0
				var bar_height = 4.0
				var bar_pos = pixel + Vector2(-bar_width/2, 32)
				
				# Fondo de la barra
				draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color.BLACK)
				# Barra de vida
				var health_color = Color.GREEN
				if health_percent < 0.3:
					health_color = Color.RED
				elif health_percent < 0.6:
					health_color = Color.YELLOW
				draw_rect(Rect2(bar_pos, Vector2(bar_width * health_percent, bar_height)), health_color)

func _draw_hexagon(center: Vector2, size: float, color: Color, border_color: Color = Color.WHITE, border_width: float = 2.0):
	var points = PackedVector2Array()
	
	for i in range(6):
		var angle_deg = 60.0 * i
		var angle_rad = deg_to_rad(angle_deg)
		var x = center.x + size * cos(angle_rad)
		var y = center.y + size * sin(angle_rad)
		points.append(Vector2(x, y))
	
	draw_polygon(points, PackedColorArray([color]))
	draw_polyline(points + PackedVector2Array([points[0]]), border_color, border_width)

func _show_physical_attack_menu(target):
	# Por ahora, mostrar todas las opciones disponibles en la UI
	if ui:
		ui.show_physical_attack_options(selected_unit, target)

func _perform_physical_attack(attacker, target, attack_type: String):
	var distance = hex_grid.hex_distance(attacker.hex_position, target.hex_position)
	
	if distance > 1:
		if ui:
			ui.add_combat_message("Target too far for physical attack!", Color.RED)
		return
	
	var attack_result = {}
	
	match attack_type:
		"punch_left":
			attack_result = attacker.perform_punch("left")
		"punch_right":
			attack_result = attacker.perform_punch("right")
		"kick":
			attack_result = attacker.perform_kick()
		"push":
			attack_result = attacker.perform_push()
		"charge":
			# Para carga necesitamos saber cuánto se movió
			var moved = attacker.movement_points - attacker.current_movement
			attack_result = attacker.perform_charge(moved)
	
	var can_attack = attack_result.get("can_punch", false) or attack_result.get("can_kick", false) or attack_result.get("can_push", false) or attack_result.get("can_charge", false)
	
	if not can_attack:
		if ui:
			ui.add_combat_message("Cannot perform %s: %s" % [attack_type, attack_result.get("reason", "Unknown")], Color.RED)
		return
	
	# Tirar para impactar
	var roll = randi() % 6 + randi() % 6 + 2
	var target_number = 8 + attack_result["to_hit_modifier"]
	
	var attack_name = attack_type.replace("_", " ").capitalize()
	var msg = "%s performs %s (roll: %d vs %d)" % [attacker.mech_name, attack_name, roll, target_number]
	
	if roll >= target_number:
		# Impacto!
		var hit_location = _roll_hit_location()
		var damage = attack_result.get("damage", 0)
		
		if ui:
			ui.add_combat_message(msg + " - HIT!", Color.GREEN)
		
		if damage > 0:
			var damage_result = target.take_damage(hit_location, damage)
			
			if ui:
				ui.add_combat_message("  → Hit %s in %s for %d damage" % [
					target.mech_name,
					hit_location,
					damage
				], Color.ORANGE)
			
			if damage_result["mech_destroyed"]:
				if ui:
					ui.add_combat_message("  → %s DESTROYED!" % target.mech_name, Color.RED)
		
		# Chequeo de derribo para el objetivo
		if attack_result.get("knockdown_chance", false):
			if not target.check_piloting_skill_roll(0):
				target.fall_prone()
				if ui:
					ui.add_combat_message("  → %s FALLS DOWN!" % target.mech_name, Color.YELLOW)
		
		# Daño a sí mismo (carga)
		if attack_result.has("self_damage"):
			var self_damage = attack_result["self_damage"]
			var self_loc = "center_torso"
			attacker.take_damage(self_loc, self_damage)
			if ui:
				ui.add_combat_message("  → %s takes %d damage from charge!" % [attacker.mech_name, self_damage], Color.ORANGE)
		
		# Chequeo de derribo para el atacante (patada, carga)
		if attack_result.get("self_damage_risk", false) or attack_result.get("self_knockdown_risk", false):
			if not attacker.check_piloting_skill_roll(2):
				attacker.fall_prone()
				if ui:
					ui.add_combat_message("  → %s FALLS DOWN!" % attacker.mech_name, Color.YELLOW)
	else:
		# Fallo
		if ui:
			ui.add_combat_message(msg + " - MISS", Color.GRAY)
		
		# Riesgo de caerse al fallar patada
		if attack_type == "kick":
			if not attacker.check_piloting_skill_roll(0):
				attacker.fall_prone()
				if ui:
					ui.add_combat_message("  → %s FALLS DOWN!" % attacker.mech_name, Color.YELLOW)
	
	if ui:
		ui.update_unit_info(attacker)
		ui.hide_physical_attack_options()
	
	turn_manager.complete_unit_activation()
	queue_redraw()

# Métodos públicos para la UI
func get_turn_manager():
	return turn_manager

func end_current_activation():
	if turn_manager:
		turn_manager.complete_unit_activation()
