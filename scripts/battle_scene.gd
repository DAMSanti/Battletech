extends Node2D

# Precargar sistemas de combate
const WeaponAttackSystem = preload("res://scripts/core/combat/weapon_attack_system.gd")
const HeatSystem = preload("res://scripts/core/combat/heat_system.gd")
const PhysicalAttackSystem = preload("res://scripts/core/combat/physical_attack_system.gd")

# Referencias (sin @onready porque necesitamos esperar)
var hex_grid
var turn_manager
var ui
var overlay_layer  # Capa para dibujar hexágonos alcanzables ENCIMA del terreno

var player_mechs: Array = []
var enemy_mechs: Array = []

var selected_unit = null
var selected_hex: Vector2i = Vector2i(-1, -1)

var reachable_hexes: Array = []
var target_hexes: Array = []
var physical_target_hexes: Array = []  # Enemigos adyacentes para ataque físico

# Sistema de movimiento
var pending_movement_selection: bool = false  # Esperando que el jugador elija Walk/Run/Jump

# USAR GameEnums en lugar de enum local
var current_state: int = GameEnums.GameState.MOVING
var current_attack_target = null  # Objetivo actual para ataque con armas

var initiative_screen_scene = preload("res://scenes/initiative_screen.tscn")
var initiative_data_stored: Dictionary = {}
var battle_started = false

func update_overlays():
	# Actualizar el redibujado de los overlays
	if overlay_layer:
		overlay_layer.queue_redraw()
	else:
		print("WARNING: overlay_layer is null!")

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
	
	# Conectar señal (usar CONNECT_ONE_SHOT para que se desconecte automáticamente)
	if initiative_screen.initiative_complete.connect(_on_initiative_screen_complete, CONNECT_ONE_SHOT) == OK:
		print("███ Initiative screen signal connected!")
	else:
		print("███ ERROR: Could not connect initiative screen signal!")
	
	print("███ Initiative screen added to scene tree on layer 100")
	print("████████████████████████████████████████")

func _on_initiative_screen_complete(data: Dictionary):
	print("Initiative complete! Data: ", data)
	
	# Guardar datos de iniciativa
	initiative_data_stored = data
	
	# Si es la primera vez, configurar la batalla
	if not battle_started:
		# Obtener referencias a los nodos
		hex_grid = $HexGrid
		turn_manager = $TurnManager
		ui = $BattleUI  # Nombre correcto del nodo en battle_scene_simple.tscn
		
		# Crear capa de overlay para hexágonos alcanzables (z_index más alto)
		overlay_layer = Node2D.new()
		overlay_layer.z_index = 5  # Encima del grid (0) pero debajo de los mechs (10)
		overlay_layer.set_script(preload("res://scripts/battle_overlay.gd"))
		add_child(overlay_layer)
		overlay_layer.battle_scene = self
		
		if ui:
			print("✅ UI encontrado correctamente")
		else:
			print("❌ ERROR: UI no encontrado")
		
		# Configurar la batalla
		_setup_battle()
		
		# Conectar señales DESPUÉS de setup
		# NOTA: unit_activated también necesita conectarse aquí para battle_scene
		turn_manager.turn_changed.connect(_on_turn_changed)
		turn_manager.phase_changed.connect(_on_phase_changed)
		turn_manager.unit_activated.connect(_on_unit_activated)  # Necesario para lógica de juego
		turn_manager.initiative_rolled.connect(_on_initiative_rolled)
		
		# Iniciar el sistema de turnos
		turn_manager.start_battle(player_mechs, enemy_mechs)
		
		battle_started = true
		
		print("Battle started!")
	else:
		# Turno posterior: usar los datos de iniciativa con el turn_manager
		if turn_manager:
			turn_manager.use_precalculated_initiative(data)

func get_stored_initiative() -> Dictionary:
	return initiative_data_stored

func clear_initiative_data():
	initiative_data_stored = {}
	print("Initiative data cleared for next turn")

func _setup_battle():
	# Crear mechs de prueba
	var player_mech = Mech.new()
	player_mech.mech_name = "Atlas"
	player_mech.hex_position = Vector2i(2, 8)
	player_mech.pilot_name = "Player"
	player_mech.walk_mp = 3
	player_mech.run_mp = 5
	player_mech.jump_mp = 0  # Atlas no tiene jump jets
	player_mech.z_index = 10  # Dibujar mechs ENCIMA del grid
	add_child(player_mech)
	player_mechs.append(player_mech)
	hex_grid.set_unit(player_mech.hex_position, player_mech)
	player_mech.update_visual_position(hex_grid)  # Posicionar en pantalla
	
	var enemy_mech = Mech.new()
	enemy_mech.mech_name = "Mad Cat"
	enemy_mech.hex_position = Vector2i(8, 8)
	enemy_mech.pilot_name = "Enemy"
	enemy_mech.tonnage = 75
	enemy_mech.walk_mp = 4
	enemy_mech.run_mp = 6
	enemy_mech.jump_mp = 0
	enemy_mech.z_index = 10  # Dibujar mechs ENCIMA del grid
	add_child(enemy_mech)
	enemy_mechs.append(enemy_mech)
	hex_grid.set_unit(enemy_mech.hex_position, enemy_mech)
	enemy_mech.update_visual_position(hex_grid)  # Posicionar en pantalla
	
	# Iniciar batalla
	turn_manager.start_battle(player_mechs, enemy_mechs)

func _input(event):
	# No procesar input si la batalla aún no ha comenzado
	if not battle_started or hex_grid == null:
		return
		
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.pressed):
		var touch_pos = event.position
		var hex = hex_grid.pixel_to_hex(touch_pos - hex_grid.global_position)
		print("Click at pixel: ", touch_pos, " -> hex: ", hex, " (grid pos: ", hex_grid.global_position, ")")
		_handle_hex_clicked(hex)

func _handle_hex_clicked(hex: Vector2i):
	if not hex_grid.is_valid_hex(hex):
		return
	
	match current_state:
		GameEnums.GameState.MOVING:
			_handle_movement_click(hex)
		GameEnums.GameState.TARGETING:
			_handle_targeting_click(hex)
		GameEnums.GameState.WEAPON_ATTACK:
			_handle_weapon_attack_click(hex)
		GameEnums.GameState.PHYSICAL_TARGETING:
			_handle_physical_targeting_click(hex)

func select_movement_type(movement_type: int):  # Mech.MovementType
	"""Llamado cuando el jugador selecciona Walk/Run/Jump"""
	if not selected_unit or selected_unit not in player_mechs:
		return
	
	pending_movement_selection = false
	selected_unit.start_movement(movement_type)
	
	print("DEBUG: Calculating reachable hexes from ", selected_unit.hex_position, " with ", selected_unit.current_movement, " MP")
	
	# Actualizar hexágonos alcanzables según el tipo de movimiento
	reachable_hexes = hex_grid.get_reachable_hexes(selected_unit.hex_position, selected_unit.current_movement)
	
	print("DEBUG: Found ", reachable_hexes.size(), " reachable hexes")
	if reachable_hexes.size() > 0:
		print("DEBUG: First few reachable hexes: ", reachable_hexes.slice(0, min(5, reachable_hexes.size())))
	
	var movement_names = ["None", "Walk", "Run", "Jump"]
	if ui:
		ui.add_combat_message("%s selected: %s (%d MP)" % [selected_unit.mech_name, movement_names[movement_type], selected_unit.current_movement], Color.CYAN)
	
	update_overlays()

func _handle_movement_click(hex: Vector2i):
	if selected_unit == null:
		return
	
	# Si estamos esperando selección de tipo de movimiento, ignorar clics
	if pending_movement_selection:
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
		
		# Registrar movimiento en el mech (actualiza modificadores)
		unit.move_to_hex(hex, movement_cost)
		hex_grid.set_unit(hex, unit)
		
		# ACTUALIZAR POSICIÓN VISUAL DEL MECH
		unit.update_visual_position(hex_grid)
		
		# Log de movimiento con tipo
		if ui:
			var movement_names = ["", "Walking", "Running", "Jumping"]
			var move_type_str = movement_names[unit.movement_type_used]
			ui.add_combat_message("%s %s from [%d,%d] to [%d,%d] (TMM: +%d)" % [
				unit.mech_name, move_type_str, old_pos.x, old_pos.y, hex.x, hex.y, unit.target_movement_modifier
			], Color.WHITE)
			
			# Aplicar y mostrar calor del movimiento
			var movement_heat = unit.finalize_movement()
			if movement_heat > 0:
				ui.add_combat_message("  → Movement heat: +%d (Total: %d)" % [movement_heat, unit.heat], Color.ORANGE)
			
			ui.update_unit_info(unit)
		
		# Actualizar hexágonos alcanzables
		if unit.current_movement > 0 and unit in player_mechs:
			# Solo para el jugador: permitir movimiento adicional
			reachable_hexes = hex_grid.get_reachable_hexes(unit.hex_position, unit.current_movement)
		else:
			# Para enemigos o cuando no queda movimiento: completar activación
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

func _handle_weapon_attack_click(hex: Vector2i):
	# Manejar selección de objetivo para ataque con armas
	if selected_unit == null or selected_unit not in player_mechs:
		return
	
	var target = hex_grid.get_unit(hex)
	
	# Verificar que hay un enemigo en el hex
	if target != null and target in enemy_mechs:
		var range_hexes = hex_grid.hex_distance(selected_unit.hex_position, target.hex_position)
		current_attack_target = target
		
		# Mostrar selector de armas
		if ui:
			ui.show_weapon_selector(selected_unit, target, range_hexes)

func execute_weapon_attack(attacker, target, weapon_indices: Array, range_hexes: int):
	# Ejecutar ataque con las armas seleccionadas
	if ui:
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("═══════════════════════════════", Color.YELLOW)
		ui.add_combat_message("%s FIRES AT %s (Range: %d)" % [attacker.mech_name.to_upper(), target.mech_name.to_upper(), range_hexes], Color.YELLOW)
		ui.add_combat_message("═══════════════════════════════", Color.YELLOW)
	
	var total_heat = 0
	var weapons_fired = []
	
	# Disparar cada arma seleccionada
	for weapon_index in weapon_indices:
		if weapon_index >= attacker.weapons.size():
			continue
		
		var weapon = attacker.weapons[weapon_index]
		weapons_fired.append(weapon)
		
		# Calcular to-hit usando el nuevo sistema
		var to_hit_data = WeaponAttackSystem.calculate_to_hit(attacker, target, weapon, range_hexes)
		var target_number = to_hit_data["target_number"]
		var modifiers = to_hit_data["modifiers"]
		
		# Tirar 2D6
		var roll = WeaponAttackSystem.roll_to_hit()
		
		# Mostrar información del disparo
		if ui:
			var mod_text = ""
			for mod_name in modifiers.keys():
				mod_text += " +%d(%s)" % [modifiers[mod_name], mod_name]
			
			ui.add_combat_message("→ %s: Roll %d vs TN %d%s" % [
				weapon.get("name", "Unknown"),
				roll,
				target_number,
				mod_text
			], Color.CYAN)
		
		# Verificar impacto
		if WeaponAttackSystem.check_hit(roll, target_number):
			# ¡IMPACTO!
			var hit_location = WeaponAttackSystem.roll_hit_location()
			var damage = weapon.get("damage", 0)
			
			if ui:
				ui.add_combat_message("  ✓ HIT! Location: %s, Damage: %d" % [hit_location, damage], Color.GREEN)
			
			# Aplicar daño
			var damage_result = WeaponAttackSystem.apply_damage(target, hit_location, damage)
			
			if damage_result.get("critical_hit", false):
				if ui:
					ui.add_combat_message("    ⚠ CRITICAL HIT! Structure damaged!", Color.RED)
			
			if damage_result.get("location_destroyed", false):
				if ui:
					ui.add_combat_message("    ⚠ %s DESTROYED!" % hit_location.to_upper(), Color.RED)
			
			if damage_result.get("mech_destroyed", false):
				if ui:
					ui.add_combat_message("    ☠ %s DESTROYED! ☠" % target.mech_name.to_upper(), Color.RED)
		else:
			# FALLO
			if ui:
				var miss_msg = "  ✗ MISS"
				if roll == 2:
					miss_msg = "  ✗ CRITICAL MISS!"
				ui.add_combat_message(miss_msg, Color.GRAY)
		
		# Acumular calor
		total_heat += weapon.get("heat", 0)
	
	# Aplicar calor generado
	if total_heat > 0:
		attacker.heat += total_heat
		if ui:
			ui.add_combat_message("Heat generated: +%d (Total: %d/%d)" % [total_heat, attacker.heat, attacker.heat_capacity], Color.ORANGE)
	
	# Actualizar UI
	if ui:
		ui.add_combat_message("═══════════════════════════════", Color.YELLOW)
	
	# Finalizar ataque y continuar con siguiente unidad
	_end_weapon_attack_phase()

func _end_weapon_attack_phase():
	# Terminar fase de ataque y continuar
	current_state = GameEnums.GameState.MOVING
	current_attack_target = null
	
	# Limpiar overlays
	target_hexes.clear()
	update_overlays()
	
	# Continuar con siguiente unidad o fase
	if turn_manager:
		turn_manager.complete_unit_activation()

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
	update_overlays()

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
		
		# Verificar que exista la clave "winner"
		if data.has("winner"):
			if data["winner"] == "player":
				ui.add_combat_message("★ PLAYER WINS INITIATIVE! ★", Color.GREEN)
				ui.add_combat_message("Player team moves first", Color.CYAN)
			else:
				ui.add_combat_message("★ ENEMY WINS INITIATIVE! ★", Color.ORANGE_RED)
				ui.add_combat_message("Enemy team moves first", Color.RED)
		else:
			push_warning("Initiative data missing 'winner' key")
		
		ui.add_combat_message("", Color.WHITE)

func _on_initiative_result(data: Dictionary):
	# Esta función es llamada directamente por el turn_manager
	_on_initiative_rolled(data)

func _on_phase_changed(phase: String):
	print("═══════════════════════════════════════════════════")
	print("DEBUG: _on_phase_changed CALLED")
	print("  Phase name: ", phase)
	print("  current_state BEFORE = ", GameEnums.GameState.keys()[current_state])
	print("═══════════════════════════════════════════════════")
	
	# IMPORTANTE: phase_to_string() retorna "Movement", "Weapon Attack", "Physical Attack"
	match phase:
		"Movement":
			current_state = GameEnums.GameState.MOVING
			print("DEBUG: ✓ Set current_state to MOVING (", GameEnums.GameState.MOVING, ")")
		"Weapon Attack":
			current_state = GameEnums.GameState.WEAPON_ATTACK
			print("DEBUG: ✓ Set current_state to WEAPON_ATTACK (", GameEnums.GameState.WEAPON_ATTACK, ")")
		"Physical Attack":
			current_state = GameEnums.GameState.PHYSICAL_TARGETING
			print("DEBUG: ✓ Set current_state to PHYSICAL_TARGETING (", GameEnums.GameState.PHYSICAL_TARGETING, ")")
		"Heat":
			# Fase de calor: procesar todos los mechs automáticamente
			print("DEBUG: ✓ HEAT phase - processing automatically")
			_process_heat_phase()
		"Initiative":
			# No cambiar estado durante iniciativa
			print("DEBUG: ✓ INITIATIVE phase")
		_:
			print("DEBUG: ⚠ UNKNOWN PHASE: ", phase)
	
	print("DEBUG: current_state AFTER = ", GameEnums.GameState.keys()[current_state])
	print("═══════════════════════════════════════════════════")
	
	# Actualizar UI con la fase
	if ui:
		ui.update_phase_info(phase)

func _on_unit_activated(unit):
	print("═══════════════════════════════════════════════════")
	print("DEBUG: _on_unit_activated CALLED")
	print("  Unit: ", unit.mech_name)
	print("  current_state = ", GameEnums.GameState.keys()[current_state])
	print("  MOVING = ", GameEnums.GameState.MOVING, " (", GameEnums.GameState.keys()[GameEnums.GameState.MOVING], ")")
	print("  WEAPON_ATTACK = ", GameEnums.GameState.WEAPON_ATTACK, " (", GameEnums.GameState.keys()[GameEnums.GameState.WEAPON_ATTACK], ")")
	print("═══════════════════════════════════════════════════")
	
	selected_unit = unit
	
	# Ocultar menú de movimiento siempre al activar una nueva unidad
	if ui:
		ui.hide_movement_type_selector()
	
	# NO resetear movimiento aquí - lo hace el turn_manager
	
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
		if current_state == GameEnums.GameState.MOVING:
			print("DEBUG: ✓ MOVEMENT PHASE - Showing movement selector")
			# Mostrar menú de selección de tipo de movimiento SOLO en fase de movimiento
			pending_movement_selection = true
			if ui:
				ui.show_movement_type_selector(unit)
				ui.add_combat_message("Your turn: Select movement type for %s" % unit.mech_name, Color.CYAN)
		elif current_state == GameEnums.GameState.TARGETING or current_state == GameEnums.GameState.WEAPON_ATTACK:
			print("DEBUG: ✓ WEAPON ATTACK PHASE - Showing weapon targeting")
			# Cambiar al modo de selección de objetivo para armas
			current_state = GameEnums.GameState.WEAPON_ATTACK
			# Mostrar todos los enemigos como objetivos potenciales
			for enemy in enemy_mechs:
				if not enemy.is_destroyed:
					target_hexes.append(enemy.hex_position)
			if ui:
				ui.add_combat_message("Your turn: Select target for %s to fire weapons" % unit.mech_name, Color.ORANGE)
				ui.set_help_text("Click on an enemy to select weapons")
		elif current_state == GameEnums.GameState.PHYSICAL_TARGETING:
			print("DEBUG: ✓ PHYSICAL ATTACK PHASE - Showing physical targeting")
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
			print("DEBUG: ⚠ UNKNOWN STATE - ", GameEnums.GameState.keys()[current_state])
	else:
		# Turno enemigo - ejecutar IA automáticamente
		if ui:
			ui.add_combat_message("Enemy turn: %s" % unit.mech_name, Color.RED)
		# Esperar un poco antes de que la IA actúe para que se vea
		await get_tree().create_timer(0.5).timeout
		_ai_turn(unit)
	
	update_overlays()

func _ai_turn(unit):
	if current_state == GameEnums.GameState.MOVING:
		# IA: Decidir tipo de movimiento (simple: correr si está lejos, caminar si está cerca)
		var closest_player = null
		var min_distance = INF
		
		for player in player_mechs:
			if not player.is_destroyed:
				var dist = hex_grid.hex_distance(unit.hex_position, player.hex_position)
				if dist < min_distance:
					min_distance = dist
					closest_player = player
		
		if closest_player:
			# Elegir movimiento basado en distancia
			var movement_type = Mech.MovementType.WALK
			if min_distance > 8:
				movement_type = Mech.MovementType.RUN  # Correr si está lejos
			
			unit.start_movement(movement_type)
			
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
	
	elif current_state == GameEnums.GameState.TARGETING or current_state == GameEnums.GameState.WEAPON_ATTACK:
		# IA: Disparar al jugador más cercano en rango
		var closest_player = null
		var min_distance = INF
		
		for player in player_mechs:
			if not player.is_destroyed:
				var dist = hex_grid.hex_distance(unit.hex_position, player.hex_position)
				if dist < min_distance:
					min_distance = dist
					closest_player = player
		
		if closest_player:
			await get_tree().create_timer(0.5).timeout
			
			# La IA dispara todas las armas que están en rango
			var weapon_indices = []
			for i in range(unit.weapons.size()):
				var weapon = unit.weapons[i]
				var long_range = weapon.get("long_range", 9)
				if min_distance <= long_range:
					weapon_indices.append(i)
			
			if weapon_indices.size() > 0:
				execute_weapon_attack(unit, closest_player, weapon_indices, min_distance)
			else:
				# No hay armas en rango
				if ui:
					ui.add_combat_message("%s has no weapons in range" % unit.mech_name, Color.GRAY)
				_end_weapon_attack_phase()
		else:
			_end_weapon_attack_phase()
	
	elif current_state == GameEnums.GameState.PHYSICAL_TARGETING:
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
	# Esta función ya no es necesaria, los overlays se dibujan en overlay_layer
	# y los mechs/terreno se dibujan en sus propios nodos
	pass

func _show_physical_attack_menu(target):
	# Por ahora, mostrar todas las opciones disponibles en la UI
	if ui:
		ui.show_physical_attack_options(selected_unit, target)

func _perform_physical_attack(attacker, target, attack_type: String):
	# Función antigua - usar execute_physical_attack en su lugar
	execute_physical_attack(attacker, target, attack_type)

func execute_physical_attack(attacker, target, attack_type: String):
	# Ejecutar ataque físico usando el nuevo sistema
	var distance = hex_grid.hex_distance(attacker.hex_position, target.hex_position)
	
	if distance > 1:
		if ui:
			ui.add_combat_message("Target too far for physical attack!", Color.RED)
		return
	
	if ui:
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("═══════════════════════════════", Color.MAGENTA)
		ui.add_combat_message("%s PHYSICAL ATTACK vs %s" % [attacker.mech_name.to_upper(), target.mech_name.to_upper()], Color.MAGENTA)
		ui.add_combat_message("═══════════════════════════════", Color.MAGENTA)
	
	var attack_type_enum
	var attack_name = ""
	var arm_used = ""
	
	# Determinar tipo de ataque
	match attack_type:
		"punch_left":
			attack_type_enum = PhysicalAttackSystem.AttackType.PUNCH
			attack_name = "Punch (Left Arm)"
			arm_used = "left"
		"punch_right":
			attack_type_enum = PhysicalAttackSystem.AttackType.PUNCH
			attack_name = "Punch (Right Arm)"
			arm_used = "right"
		"kick":
			attack_type_enum = PhysicalAttackSystem.AttackType.KICK
			attack_name = "Kick"
		"charge":
			attack_type_enum = PhysicalAttackSystem.AttackType.CHARGE
			attack_name = "Charge"
	
	# Calcular to-hit
	var to_hit_data = PhysicalAttackSystem.calculate_to_hit(attacker, target, attack_type_enum)
	var target_number = to_hit_data["target_number"]
	var modifiers = to_hit_data["modifiers"]
	
	# Calcular daño potencial
	var damage = 0
	match attack_type_enum:
		PhysicalAttackSystem.AttackType.PUNCH:
			damage = PhysicalAttackSystem.calculate_punch_damage(attacker.tonnage)
		PhysicalAttackSystem.AttackType.KICK:
			damage = PhysicalAttackSystem.calculate_kick_damage(attacker.tonnage)
		PhysicalAttackSystem.AttackType.CHARGE:
			var hexes = attacker.hexes_moved_this_turn if "hexes_moved_this_turn" in attacker else 0
			damage = PhysicalAttackSystem.calculate_charge_damage(attacker.tonnage, hexes)
	
	# Tirar 2D6
	var roll = PhysicalAttackSystem.roll_to_hit()
	
	# Mostrar información del ataque
	if ui:
		var mod_text = ""
		for mod_name in modifiers.keys():
			mod_text += " +%d(%s)" % [modifiers[mod_name], mod_name]
		
		ui.add_combat_message("→ %s: Roll %d vs TN %d%s (Dmg: %d)" % [
			attack_name,
			roll,
			target_number,
			mod_text,
			damage
		], Color.CYAN)
	
	# Verificar impacto
	if PhysicalAttackSystem.check_hit(roll, target_number):
		# ¡IMPACTO!
		var hit_location = ""
		
		if attack_type_enum == PhysicalAttackSystem.AttackType.PUNCH:
			hit_location = PhysicalAttackSystem.roll_punch_location()
		elif attack_type_enum == PhysicalAttackSystem.AttackType.KICK:
			hit_location = PhysicalAttackSystem.roll_kick_location()
		else:
			# Charge impacta en el torso frontal
			hit_location = "center_torso"
		
		if ui:
			ui.add_combat_message("  ✓ HIT! Location: %s" % hit_location, Color.GREEN)
		
		# Aplicar daño
		var damage_result = target.take_damage(hit_location, damage)
		
		if damage_result.get("critical_hit", false):
			if ui:
				ui.add_combat_message("    ⚠ CRITICAL HIT! Structure damaged!", Color.RED)
		
		if damage_result.get("location_destroyed", false):
			if ui:
				ui.add_combat_message("    ⚠ %s DESTROYED!" % hit_location.to_upper(), Color.RED)
		
		if damage_result.get("mech_destroyed", false):
			if ui:
				ui.add_combat_message("    ☠ %s DESTROYED! ☠" % target.mech_name.to_upper(), Color.RED)
		
		# Efectos especiales según tipo de ataque
		if attack_type_enum == PhysicalAttackSystem.AttackType.CHARGE:
			# Daño al atacante por embestida
			var self_damage = PhysicalAttackSystem.apply_charge_self_damage(attacker, damage)
			if self_damage > 0:
				attacker.take_damage("center_torso", self_damage)
				if ui:
					ui.add_combat_message("  → %s takes %d self-damage from charge" % [attacker.mech_name, self_damage], Color.ORANGE)
	else:
		# FALLO
		if ui:
			var miss_msg = "  ✗ MISS"
			if roll == 2:
				miss_msg = "  ✗ CRITICAL MISS!"
			ui.add_combat_message(miss_msg, Color.GRAY)
		
		# Riesgo de caída al fallar patada
		if attack_type_enum == PhysicalAttackSystem.AttackType.KICK:
			if PhysicalAttackSystem.check_fall_after_kick(attacker):
				attacker.is_prone = true
				if ui:
					ui.add_combat_message("  → %s FALLS DOWN from failed kick!" % attacker.mech_name, Color.YELLOW)
	
	if ui:
		ui.add_combat_message("═══════════════════════════════", Color.MAGENTA)
	
	# Finalizar ataque y continuar
	turn_manager.complete_unit_activation()
	update_overlays()

## FASE DE CALOR ##

func _process_heat_phase():
	# Procesar fase de calor para todos los mechs
	if ui:
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("═══════════════════════════════", Color.ORANGE)
		ui.add_combat_message("        HEAT PHASE", Color.ORANGE)
		ui.add_combat_message("═══════════════════════════════", Color.ORANGE)
	
	# Procesar cada mech
	var all_mechs = player_mechs + enemy_mechs
	for mech in all_mechs:
		if mech.is_destroyed:
			continue
		
		_process_mech_heat(mech)
	
	# Esperar un momento para que el jugador lea los mensajes
	await get_tree().create_timer(2.0).timeout
	
	# Avanzar a la siguiente fase
	if turn_manager:
		turn_manager.advance_phase()

func _process_mech_heat(mech):
	# Procesar calor de un mech individual
	var initial_heat = mech.heat
	
	if ui:
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("%s (Heat: %d)" % [mech.mech_name, initial_heat], Color.CYAN)
	
	# 1. Verificar shutdown ANTES de disipar
	if initial_heat >= 19:
		var shutdown_check = HeatSystem.check_shutdown(initial_heat)
		if shutdown_check["must_shutdown"]:
			mech.is_shutdown = true
			if ui:
				if shutdown_check.get("automatic", false):
					ui.add_combat_message("  ☠ AUTOMATIC SHUTDOWN (Heat >= 30)!", Color.RED)
				else:
					ui.add_combat_message("  ☠ SHUTDOWN! (Rolled %d vs %d)" % [shutdown_check["roll"], shutdown_check["target"]], Color.RED)
		elif shutdown_check["target"] > 0:
			if ui:
				ui.add_combat_message("  ✓ Avoided shutdown (Rolled %d vs %d)" % [shutdown_check["roll"], shutdown_check["target"]], Color.GREEN)
	
	# 2. Verificar explosión de munición
	if initial_heat >= 19:
		var ammo_check = HeatSystem.check_ammo_explosion(initial_heat)
		if ammo_check["explodes"]:
			# Explosión de munición - daño masivo al torso central
			if ui:
				ui.add_combat_message("  ☠☠☠ AMMO EXPLOSION! (Rolled %d vs %d)" % [ammo_check["roll"], ammo_check["target"]], Color.RED)
			var damage_result = mech.take_damage("center_torso", 20)
			if damage_result.get("mech_destroyed", false):
				if ui:
					ui.add_combat_message("    %s DESTROYED BY AMMO EXPLOSION!" % mech.mech_name.to_upper(), Color.DARK_RED)
		elif ammo_check["target"] > 0:
			if ui:
				ui.add_combat_message("  ✓ Avoided ammo explosion (Rolled %d vs %d)" % [ammo_check["roll"], ammo_check["target"]], Color.YELLOW)
	
	# 3. Disipar calor
	var dissipation_result = mech.dissipate_heat()
	var heat_removed = dissipation_result["heat_removed"]
	var current_heat = dissipation_result["current_heat"]
	
	if ui:
		ui.add_combat_message("  → Dissipated %d heat (%d -> %d)" % [heat_removed, initial_heat, current_heat], Color.LIGHT_BLUE)
		
		if dissipation_result.get("restarted", false):
			ui.add_combat_message("  ✓ MECH RESTARTED!", Color.GREEN)
		
		# Mostrar efectos del calor restante
		if current_heat > 0:
			var heat_desc = HeatSystem.get_heat_description(current_heat)
			ui.add_combat_message("  Status: %s" % heat_desc, HeatSystem.get_heat_status_color(current_heat, mech.heat_capacity))
	
	# Actualizar visualización
	mech.queue_redraw()

# Métodos públicos para la UI
func get_turn_manager():
	return turn_manager

func end_current_activation():
	if turn_manager:
		turn_manager.complete_unit_activation()
