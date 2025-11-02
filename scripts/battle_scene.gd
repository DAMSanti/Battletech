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

# Sistema de cámara táctil
var camera: Camera2D
var is_dragging: bool = false
var drag_start_pos: Vector2
var camera_start_pos: Vector2
var touch_points: Dictionary = {}  # ID del toque -> posición
var initial_pinch_distance: float = 0.0
var initial_zoom: Vector2 = Vector2.ONE

# Sistema de tap largo para inspección
var long_press_timer: float = 0.0
var long_press_start_pos: Vector2
var long_press_active: bool = false
const LONG_PRESS_DURATION: float = 0.5  # Medio segundo para tap largo

# Límites de zoom y movimiento
const MIN_ZOOM = 0.3
const MAX_ZOOM = 2.0
const CAMERA_SMOOTH_SPEED = 10.0

func update_overlays():
	# Actualizar el redibujado de los overlays
	if overlay_layer:
		overlay_layer.queue_redraw()

func _ready():
	# Mostrar pantalla de iniciativa INMEDIATAMENTE
	show_initiative_screen()

func _process(delta):
	# Procesar timer de tap largo
	if long_press_active:
		long_press_timer += delta
		if long_press_timer >= LONG_PRESS_DURATION:
			# Tap largo completado - inspeccionar mech
			long_press_active = false
			var world_pos = camera.get_global_mouse_position() if camera else get_global_mouse_position()
			if hex_grid:
				var hex = hex_grid.pixel_to_hex(world_pos - hex_grid.global_position)
				_handle_mech_inspect(hex)

func show_initiative_screen():
	var initiative_screen = initiative_screen_scene.instantiate()
	
	# CRÍTICO: Poner el CanvasLayer en un layer MÁS ALTO que el UI
	# Los layers más altos se renderizan encima
	initiative_screen.layer = 100  # UI está en layer 0 por defecto
	
	add_child(initiative_screen)
	
	# Conectar señal (usar CONNECT_ONE_SHOT para que se desconecte automáticamente)
	initiative_screen.initiative_complete.connect(_on_initiative_screen_complete, CONNECT_ONE_SHOT)

func _on_initiative_screen_complete(data: Dictionary):
	# Guardar datos de iniciativa
	initiative_data_stored = data
	
	# Si es la primera vez, configurar la batalla
	if not battle_started:
		# Obtener referencias a los nodos
		hex_grid = $HexGrid
		turn_manager = $TurnManager
		ui = $BattleUI  # Nombre correcto del nodo en battle_scene_simple.tscn
		
		# Crear y configurar cámara ANTES de los overlays
		camera = Camera2D.new()
		camera.enabled = true
		camera.zoom = Vector2(0.8, 0.8)  # Zoom inicial para ver más mapa
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = CAMERA_SMOOTH_SPEED
		camera.add_to_group("cameras")
		call_deferred("add_child", camera)
		# Hacer la cámara actual después de agregarla al árbol
		await get_tree().process_frame
		camera.make_current()
		
		# Centrar cámara en el mapa después de un frame
		await get_tree().process_frame
		if hex_grid:
			var map_center = hex_grid.hex_to_pixel(Vector2i(hex_grid.grid_width / 2, hex_grid.grid_height / 2))
			camera.position = map_center
		
		# Crear capa de overlay para hexágonos alcanzables (z_index más alto)
		overlay_layer = Node2D.new()
		overlay_layer.z_index = 5  # Encima del grid (0) pero debajo de los mechs (10)
		overlay_layer.set_script(preload("res://scripts/battle_overlay.gd"))
		add_child(overlay_layer)
		overlay_layer.battle_scene = self
		
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
	else:
		# Turno posterior: usar los datos de iniciativa con el turn_manager
		if turn_manager:
			turn_manager.use_precalculated_initiative(data)

func get_stored_initiative() -> Dictionary:
	return initiative_data_stored

func clear_initiative_data():
	initiative_data_stored = {}

func _setup_battle():
	# Obtener mechs configurados del MechBayManager
	var mech_bay_manager = get_node_or_null("/root/MechBayManager")
	
	if mech_bay_manager:
		# Mostrar índice y nombre del mech seleccionado
		print("[DEBUG] selected_mech_index:", mech_bay_manager.selected_mech_index)
		var player_mech_data = mech_bay_manager.get_first_player_mech()
		print("[DEBUG] get_first_player_mech() returned: ", player_mech_data.get("name", "Unknown"))
		if player_mech_data.has("weapons"):
			print("[DEBUG] Weapons count: ", player_mech_data["weapons"].size())
			for i in range(player_mech_data["weapons"].size()):
				var weapon = player_mech_data["weapons"][i]
				print("[DEBUG]   Weapon %d: %s" % [i, weapon.get("name", "Unknown")])
		_create_player_mech_from_data(player_mech_data, Vector2i(2, 8))
	else:
		# Fallback si no existe el manager
		print("[WARNING] MechBayManager not found, using default Atlas")
		_create_player_mech("Atlas", Vector2i(2, 8), 100, 3, 5, 0)
	
	# Equipo enemigo - usar datos del manager también
	if mech_bay_manager:
		var enemy_mech_data = mech_bay_manager.get_mech_data("Mad Cat", "Timber Wolf Prime")
		if enemy_mech_data:
			_create_enemy_mech_from_data(enemy_mech_data, Vector2i(8, 8))
		else:
			_create_enemy_mech("Mad Cat", Vector2i(8, 8), 75, 4, 6, 0)
	else:
		_create_enemy_mech("Mad Cat", Vector2i(8, 8), 75, 4, 6, 0)
	
	# Asegurar que selected_unit apunte al Mech correcto (el primero del array, que es el seleccionado)
	if player_mechs.size() > 0:
		selected_unit = player_mechs[0]
		print("[DEBUG] selected_unit set to: %s" % selected_unit.mech_name)
	
	# Iniciar batalla con todos los mechs creados
	turn_manager.start_battle(player_mechs, enemy_mechs)

## Crea un mech desde datos del MechBayManager
func _create_player_mech_from_data(mech_data: Dictionary, position: Vector2i) -> Mech:
	var mech = Mech.new()
	mech.mech_name = mech_data.get("name", "Unknown")
	mech.hex_position = position
	mech.pilot_name = "Player"
	mech.tonnage = mech_data.get("tonnage", 50)
	mech.walk_mp = mech_data.get("walk_mp", 4)
	mech.run_mp = mech_data.get("run_mp", 6)
	mech.jump_mp = mech_data.get("jump_mp", 0)
	mech.current_movement = mech.walk_mp
	
	# Copiar armadura
	if mech_data.has("armor"):
		mech.armor = mech_data["armor"].duplicate(true)
	
	# Copiar armas
	if mech_data.has("weapons"):
		mech.weapons = mech_data["weapons"].duplicate(true)
		print("[DEBUG] _create_player_mech_from_data - Copied %d weapons to mech" % mech.weapons.size())
		for i in range(mech.weapons.size()):
			print("[DEBUG]   Mech weapon %d: %s" % [i, mech.weapons[i].get("name", "Unknown")])
	
	# Copiar heat capacity
	if mech_data.has("heat_capacity"):
		mech.heat_capacity = mech_data["heat_capacity"]
	
	# Copiar gunnery skill (se mapea a pilot_skill en Mech)
	if mech_data.has("gunnery_skill"):
		mech.pilot_skill = mech_data["gunnery_skill"]
	
	mech.z_index = 10
	add_child(mech)
	player_mechs.append(mech)
	hex_grid.set_unit(mech.hex_position, mech)
	mech.update_visual_position(hex_grid)
	
	print("[BATTLE] Created player mech: ", mech.mech_name, " (", mech.tonnage, " tons)")
	return mech

## Crea un mech enemigo desde datos del MechBayManager
func _create_enemy_mech_from_data(mech_data: Dictionary, position: Vector2i) -> Mech:
	var mech = Mech.new()
	mech.mech_name = mech_data.get("name", "Unknown")
	mech.hex_position = position
	mech.pilot_name = "Enemy"
	mech.tonnage = mech_data.get("tonnage", 50)
	mech.walk_mp = mech_data.get("walk_mp", 4)
	mech.run_mp = mech_data.get("run_mp", 6)
	mech.jump_mp = mech_data.get("jump_mp", 0)
	mech.current_movement = mech.walk_mp
	
	# Copiar armadura
	if mech_data.has("armor"):
		mech.armor = mech_data["armor"].duplicate(true)
	
	# Copiar armas
	if mech_data.has("weapons"):
		mech.weapons = mech_data["weapons"].duplicate(true)
	
	# Copiar heat capacity
	if mech_data.has("heat_capacity"):
		mech.heat_capacity = mech_data["heat_capacity"]
	
	# Copiar gunnery skill (se mapea a pilot_skill en Mech)
	if mech_data.has("gunnery_skill"):
		mech.pilot_skill = mech_data["gunnery_skill"]
	
	mech.z_index = 10
	add_child(mech)
	enemy_mechs.append(mech)
	hex_grid.set_unit(mech.hex_position, mech)
	mech.update_visual_position(hex_grid)
	
	print("[BATTLE] Created enemy mech: ", mech.mech_name, " (", mech.tonnage, " tons)")
	return mech

## Crea un mech para el equipo del jugador (legacy - para compatibilidad)
func _create_player_mech(name: String, position: Vector2i, tonnage: int, walk: int, run: int, jump: int) -> Mech:
	var mech = Mech.new()
	mech.mech_name = name
	mech.hex_position = position
	mech.pilot_name = "Player"
	mech.tonnage = tonnage
	mech.walk_mp = walk
	mech.run_mp = run
	mech.jump_mp = jump
	mech.z_index = 10  # Dibujar mechs ENCIMA del grid
	add_child(mech)
	player_mechs.append(mech)
	hex_grid.set_unit(mech.hex_position, mech)
	mech.update_visual_position(hex_grid)
	return mech

## Crea un mech para el equipo enemigo
func _create_enemy_mech(name: String, position: Vector2i, tonnage: int, walk: int, run: int, jump: int) -> Mech:
	var mech = Mech.new()
	mech.mech_name = name
	mech.hex_position = position
	mech.pilot_name = "Enemy"
	mech.tonnage = tonnage
	mech.walk_mp = walk
	mech.run_mp = run
	mech.jump_mp = jump
	mech.z_index = 10  # Dibujar mechs ENCIMA del grid
	add_child(mech)
	enemy_mechs.append(mech)
	hex_grid.set_unit(mech.hex_position, mech)
	mech.update_visual_position(hex_grid)
	return mech

func _input(event):
	# No procesar input si la batalla aún no ha comenzado
	if not battle_started or hex_grid == null or camera == null:
		return
	
	# Detectar inicio de tap largo (táctil o mouse)
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		# Solo iniciar tap largo si no hay otros toques activos (evitar durante pinch zoom)
		if touch_points.size() == 0:
			long_press_active = true
			long_press_timer = 0.0
			long_press_start_pos = event.position
	
	# Cancelar tap largo si se mueve mucho o se suelta antes de tiempo
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if long_press_active and event.position.distance_to(long_press_start_pos) > 20:
			long_press_active = false
	
	if (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if long_press_active and long_press_timer < LONG_PRESS_DURATION:
			# Tap corto - procesar como clic normal
			long_press_active = false
	
	# Clic derecho para inspección en PC (mantener para testing)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var world_pos = camera.get_global_mouse_position()
		var hex = hex_grid.pixel_to_hex(world_pos - hex_grid.global_position)
		_handle_mech_inspect(hex)
		return
	
	# Manejar gestos de cámara primero
	if _handle_camera_input(event):
		long_press_active = false  # Cancelar tap largo si se detecta gesto de cámara
		return  # Si fue un gesto de cámara, no procesar como click en hexágono
		
	# Click/toque en hexágono
	if event is InputEventScreenTouch and not event.pressed:  # Solo en release
		if touch_points.size() == 0 and not long_press_active:  # Asegurar que no fue un gesto o tap largo
			var world_pos = camera.get_global_mouse_position()
			var hex = hex_grid.pixel_to_hex(world_pos - hex_grid.global_position)
			_handle_hex_clicked(hex)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not long_press_active:  # Solo si no está en proceso de tap largo
			var world_pos = camera.get_global_mouse_position()
			var hex = hex_grid.pixel_to_hex(world_pos - hex_grid.global_position)
			_handle_hex_clicked(hex)

func _handle_camera_input(event) -> bool:
	# Retorna true si el evento fue procesado como gesto de cámara
	
	if camera == null:
		return false
	
	# Gestos táctiles
	if event is InputEventScreenTouch:
		if event.pressed:
			# Nuevo toque
			touch_points[event.index] = event.position
			
			if touch_points.size() == 1:
				# Un dedo: iniciar arrastre
				is_dragging = true
				drag_start_pos = event.position
				camera_start_pos = camera.position
			elif touch_points.size() == 2:
				# Dos dedos: iniciar zoom con pellizco
				is_dragging = false
				var points = touch_points.values()
				initial_pinch_distance = points[0].distance_to(points[1])
				initial_zoom = camera.zoom
		else:
			# Soltar toque
			touch_points.erase(event.index)
			
			if touch_points.size() == 0:
				is_dragging = false
			elif touch_points.size() == 1:
				# Volver a modo arrastre con el dedo restante
				is_dragging = true
				var remaining_point = touch_points.values()[0]
				drag_start_pos = remaining_point
				camera_start_pos = camera.position
		
		return touch_points.size() > 0 or is_dragging
	
	# Movimiento táctil
	if event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		
		if touch_points.size() == 1 and is_dragging:
			# Arrastrar cámara con un dedo
			var drag_delta = (drag_start_pos - event.position) / camera.zoom.x
			camera.position = camera_start_pos + drag_delta
			return true
		elif touch_points.size() == 2:
			# Zoom con pellizco (pinch)
			var points = touch_points.values()
			var current_distance = points[0].distance_to(points[1])
			var zoom_factor = initial_pinch_distance / current_distance
			
			# Calcular nuevo zoom
			var new_zoom = initial_zoom * zoom_factor
			new_zoom.x = clamp(new_zoom.x, MIN_ZOOM, MAX_ZOOM)
			new_zoom.y = clamp(new_zoom.y, MIN_ZOOM, MAX_ZOOM)
			camera.zoom = new_zoom
			return true
	
	# Soporte de mouse para testing en PC
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				drag_start_pos = event.position
				camera_start_pos = camera.position
			else:
				is_dragging = false
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= 1.1
			camera.zoom.x = clamp(camera.zoom.x, MIN_ZOOM, MAX_ZOOM)
			camera.zoom.y = clamp(camera.zoom.y, MIN_ZOOM, MAX_ZOOM)
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom *= 0.9
			camera.zoom.x = clamp(camera.zoom.x, MIN_ZOOM, MAX_ZOOM)
			camera.zoom.y = clamp(camera.zoom.y, MIN_ZOOM, MAX_ZOOM)
			return true
	
	if event is InputEventMouseMotion and is_dragging:
		var drag_delta = (drag_start_pos - event.position) / camera.zoom.x
		camera.position = camera_start_pos + drag_delta
		return true
	
	return false

func _handle_hex_clicked(hex: Vector2i):
	if not hex_grid.is_valid_hex(hex):
		return
	
	print("[DEBUG] _handle_hex_clicked: hex=%s, current_state=%d" % [hex, current_state])
	
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
	
	
	# Actualizar hexágonos alcanzables según el tipo de movimiento
	reachable_hexes = hex_grid.get_reachable_hexes(selected_unit.hex_position, selected_unit.current_movement)
	
	
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
			
			# Registrar calor del movimiento (no aplicar aún, se procesará en fase de calor)
			var movement_heat = unit.finalize_movement()
			if movement_heat > 0:
				ui.add_combat_message("  → Movement heat generated: +%d" % movement_heat, Color.ORANGE)
			
			ui.update_unit_info(unit)
		
		# Terminar activación tras el movimiento
		if unit in player_mechs:
			reachable_hexes.clear()
			if ui:
				ui.add_combat_message("Movimiento realizado. Fase terminada.", Color.YELLOW)
			await get_tree().create_timer(0.5).timeout
			turn_manager.complete_unit_activation()
		else:
			# Para enemigos: también completar activación después de moverse
			reachable_hexes.clear()
			await get_tree().create_timer(0.3).timeout
			turn_manager.complete_unit_activation()
		
		queue_redraw()

func _handle_targeting_click(hex: Vector2i):
	# Solo permitir atacar si es el turno del jugador
	if selected_unit == null or selected_unit not in player_mechs:
		return
	
	var target = hex_grid.get_unit(hex)
	
	if target != null and target in enemy_mechs:
		# NOTA: Sistema viejo deshabilitado - usar selector de armas
		# _attack_target(selected_unit, target)
		print("[DEBUG] Use weapon selector for attacks")

func _handle_physical_targeting_click(hex: Vector2i):
	# Solo permitir ataque físico si es el turno del jugador Y estamos en la fase correcta
	if selected_unit == null or selected_unit not in player_mechs:
		return
	
	# Verificar que estamos en la fase de ataque físico
	if current_state != GameEnums.GameState.PHYSICAL_TARGETING:
		return
	
	var target = hex_grid.get_unit(hex)
	
	if target != null and target in enemy_mechs and hex in physical_target_hexes:
		_show_physical_attack_menu(target)

func _handle_weapon_attack_click(hex: Vector2i):
	print("[DEBUG] _handle_weapon_attack_click called: hex=%s" % hex)
	# Manejar selección de objetivo para ataque con armas
	if selected_unit == null or selected_unit not in player_mechs:
		print("[DEBUG] No selected_unit or not player mech")
		return
	
	var target = hex_grid.get_unit(hex)
	print("[DEBUG] Target at hex: %s, is_enemy=%s" % [target.mech_name if target else "null", target in enemy_mechs if target else false])
	
	# Verificar que hay un enemigo en el hex
	if target != null and target in enemy_mechs:
		var range_hexes = hex_grid.hex_distance(selected_unit.hex_position, target.hex_position)
		current_attack_target = target
		
		print("[DEBUG] Showing weapon selector for target %s at range %d" % [target.mech_name, range_hexes])
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
		var breakdown = to_hit_data.get("breakdown", "")
		
		# Tirar 2D6
		var roll = WeaponAttackSystem.roll_to_hit()
		
		# Mostrar información del disparo con el desglose completo
		if ui:
			ui.add_combat_message("→ %s" % weapon.get("name", "Unknown"), Color.CYAN)
			# Mostrar el breakdown completo (si está disponible) en líneas separadas
			if breakdown != "":
				for line in breakdown.split("\n"):
					if line.strip_edges() != "":
						ui.add_combat_message("  %s" % line, Color.WHITE)
			ui.add_combat_message("  Roll: %d" % roll, Color.CYAN)
		
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
				target.destroyed_by = attacker.mech_name
				if target.death_reason == "":
					target.death_reason = "Destroyed by weapons fire"
				if ui:
					ui.add_combat_message("    ☠ %s DESTROYED! ☠" % target.mech_name.to_upper(), Color.RED)
				_check_battle_end()
		else:
			# FALLO
			if ui:
				var miss_msg = "  ✗ MISS"
				if roll == 2:
					miss_msg = "  ✗ CRITICAL MISS!"
				ui.add_combat_message(miss_msg, Color.GRAY)
		
		# Acumular calor
		total_heat += weapon.get("heat", 0)
	
	# Registrar calor generado (no aplicar aún, se procesará en fase de calor)
	if total_heat > 0:
		attacker.heat += total_heat
		if ui:
			ui.add_combat_message("Heat generated: +%d (Current: %d/%d)" % [total_heat, attacker.heat, attacker.heat_capacity], Color.ORANGE)
			ui.add_combat_message("  (Heat will be processed in Heat Phase)", Color.GRAY)
	
	# Actualizar UI
	if ui:
		ui.add_combat_message("═══════════════════════════════", Color.YELLOW)
	
	# Finalizar ataque y continuar con siguiente unidad
	_end_weapon_attack_phase()

func _end_weapon_attack_phase():
	# Terminar fase de ataque y continuar
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
	print("[DEBUG] _on_phase_changed: %s" % phase)
	
	# Limpiar hexágonos de objetivos al cambiar de fase
	physical_target_hexes.clear()
	target_hexes.clear()
	reachable_hexes.clear()
	update_overlays()
	
	# IMPORTANTE: phase_to_string() retorna "Movement", "Weapon Attack", "Physical Attack"
	match phase:
		"Movement":
			current_state = GameEnums.GameState.MOVING
			print("[DEBUG] Set current_state to MOVING (%d)" % current_state)
		"Weapon Attack":
			current_state = GameEnums.GameState.WEAPON_ATTACK
		"Physical Attack":
			current_state = GameEnums.GameState.PHYSICAL_TARGETING
		"Heat":
			# Fase de calor: procesar todos los mechs automáticamente
			_process_heat_phase()
		"Initiative":
			# No cambiar estado durante iniciativa
			pass
		_:
			pass
	
	# Actualizar UI con la fase
	if ui:
		ui.update_phase_info(phase)

func _on_unit_activated(unit):
	selected_unit = unit
	print("[DEBUG] _on_unit_activated: %s, current_state=%d, is_player=%s" % [
		unit.mech_name, 
		current_state,
		unit in player_mechs
	])
	if typeof(unit.weapons) == TYPE_ARRAY:
		print("[DEBUG]   Weapons count: %d" % unit.weapons.size())
		for i in range(unit.weapons.size()):
			print("[DEBUG]     Weapon %d: %s" % [i, unit.weapons[i].get("name", "Unknown")])
	print("[DEBUG] selected_unit id: %s, unit id: %s" % [str(selected_unit), str(unit)])
	
	# Resetear flag de ataque físico al inicio de cada activación
	unit.has_performed_physical_attack = false
	
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
	
	if unit in player_mechs:
		# Turno del jugador - ESPERAR input del usuario
		if current_state == GameEnums.GameState.MOVING:
			# Mostrar menú de selección de tipo de movimiento SOLO en fase de movimiento
			pending_movement_selection = true
			if ui:
				ui.show_movement_type_selector(unit)
				ui.add_combat_message("Your turn: Select movement type for %s" % unit.mech_name, Color.CYAN)
		elif current_state == GameEnums.GameState.PHYSICAL_TARGETING:
			# Verificar si ya realizó un ataque físico
			if unit.has_performed_physical_attack:
				# Ya atacó, terminar turno automáticamente
				if ui:
					ui.add_combat_message("%s has already performed a physical attack this turn" % unit.mech_name, Color.GRAY)
				turn_manager.complete_unit_activation()
				return
			
			# Mostrar enemigos adyacentes para ataque físico
			physical_target_hexes.clear()
			for enemy in enemy_mechs:
				if not enemy.is_destroyed:
					var dist = hex_grid.hex_distance(unit.hex_position, enemy.hex_position)
					if dist <= 1:
						physical_target_hexes.append(enemy.hex_position)
			if ui:
				ui.add_combat_message("Your turn: Physical attack with %s" % unit.mech_name, Color.MAGENTA)
				# Mostrar mensaje de ayuda en fase de ataque físico
				if turn_manager and turn_manager.current_phase == GameEnums.TurnPhase.PHYSICAL_ATTACK:
					ui.set_help_text("Click on an enemy to select weapons")
		elif current_state == GameEnums.GameState.TARGETING or current_state == GameEnums.GameState.WEAPON_ATTACK:
			# Cambiar al modo de selección de objetivo para armas
			current_state = GameEnums.GameState.WEAPON_ATTACK
			# Mostrar todos los enemigos como objetivos potenciales
			for enemy in enemy_mechs:
				if not enemy.is_destroyed:
					target_hexes.append(enemy.hex_position)
			if ui:
				ui.add_combat_message("Your turn: Select target for %s to fire weapons" % unit.mech_name, Color.ORANGE)
				# Mostrar mensaje de ayuda solo en fases de ataque (Weapon Attack y Physical Attack)
				if turn_manager and (turn_manager.current_phase == GameEnums.TurnPhase.WEAPON_ATTACK or turn_manager.current_phase == GameEnums.TurnPhase.PHYSICAL_ATTACK):
					ui.set_help_text("Click on an enemy to select weapons")
	else:
		# Turno enemigo - ejecutar IA automáticamente
		if ui:
			ui.add_combat_message("Enemy turn: %s" % unit.mech_name, Color.RED)
		# Esperar un poco antes de que la IA actúe para que se vea
		await get_tree().create_timer(0.5).timeout
		_ai_turn(unit)
	
	update_overlays()

func _ai_turn(unit):
	# IA ESCALABLE: Busca entre TODOS los mechs del jugador (1-4+)
	# Selecciona el objetivo más cercano/apropiado automáticamente
	if current_state == GameEnums.GameState.MOVING:
		# IA: Decidir tipo de movimiento (simple: correr si está lejos, caminar si está cerca)
		var closest_player = null
		var min_distance = INF
		
		# Buscar el jugador más cercano entre TODOS los jugadores disponibles
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
			target.destroyed_by = attacker.mech_name
			if target.death_reason == "":
				var attack_type_name = PhysicalAttackSystem.AttackType.keys()[attack_type_enum].capitalize()
				target.death_reason = "Destroyed by " + attack_type_name.to_lower()
			if ui:
				ui.add_combat_message("    ☠ %s DESTROYED! ☠" % target.mech_name.to_upper(), Color.RED)
			_check_battle_end()
		
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
	
	# Marcar que el atacante ya realizó su ataque físico este turno
	attacker.has_performed_physical_attack = true
	
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
				mech.death_reason = "Ammo explosion"
				if ui:
					ui.add_combat_message("    %s DESTROYED BY AMMO EXPLOSION!" % mech.mech_name.to_upper(), Color.DARK_RED)
				_check_battle_end()
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

func _check_battle_end():
	# Verificar si todos los mechs de un bando están destruidos
	var players_alive = 0
	var enemies_alive = 0
	
	for mech in player_mechs:
		if not mech.is_destroyed:
			players_alive += 1
	
	for mech in enemy_mechs:
		if not mech.is_destroyed:
			enemies_alive += 1
	
	# Si un bando fue eliminado, mostrar pantalla de fin de juego
	if players_alive == 0 or enemies_alive == 0:
		var winner_name = ""
		var loser_name = ""
		var death_reason = ""
		
		if players_alive == 0:
			# Enemigos ganaron
			winner_name = enemy_mechs[0].mech_name if enemy_mechs.size() > 0 else "Enemy"
			# Buscar el jugador destruido
			for mech in player_mechs:
				if mech.is_destroyed:
					loser_name = mech.mech_name
					# Crear mensaje de muerte
					if mech.destroyed_by != "":
						death_reason = "%s destroyed by %s" % [loser_name, mech.destroyed_by]
					else:
						death_reason = loser_name
					
					if mech.death_reason != "":
						death_reason += "\n" + mech.death_reason.capitalize()
					break
		else:
			# Jugador ganó
			winner_name = player_mechs[0].mech_name if player_mechs.size() > 0 else "Player"
			# Buscar el enemigo destruido
			for mech in enemy_mechs:
				if mech.is_destroyed:
					loser_name = mech.mech_name
					# Crear mensaje de muerte
					if mech.destroyed_by != "":
						death_reason = "%s destroyed by %s" % [loser_name, mech.destroyed_by]
					else:
						death_reason = loser_name
					
					if mech.death_reason != "":
						death_reason += "\n" + mech.death_reason.capitalize()
					break
		
		# Mostrar pantalla de fin de juego
		if ui and ui.has_method("show_game_over"):
			ui.show_game_over(winner_name, loser_name, death_reason)

func _handle_mech_inspect(hex: Vector2i):
	# Verificar si hay un mech en este hexágono
	if not hex_grid.is_valid_hex(hex):
		return
	
	var unit = hex_grid.get_unit(hex)
	if unit and ui and ui.has_method("show_mech_inspector"):
		ui.show_mech_inspector(unit)
