extends Node2D

# Precargar sistemas de combate
const weapon_attack_sys = preload("res://scripts/core/combat/weapon_attack_system.gd")
const heat_sys = preload("res://scripts/core/combat/heat_system.gd")
const physical_attack_sys = preload("res://scripts/core/combat/physical_attack_system.gd")
const component_db = preload("res://scripts/core/component_database.gd")

# Referencias (sin @onready porque necesitamos esperar)
var hex_grid
var turn_manager
var ui
var overlay_layer  # Capa para dibujar hexágonos alcanzables ENCIMA del terreno
var battle_ai: BattleAI  # Sistema de IA mejorado

var player_mechs: Array = []
var enemy_mechs: Array = []

var selected_unit = null
var selected_hex: Vector2i = Vector2i(-1, -1)

var reachable_hexes: Array = []
var target_hexes: Array = []
var physical_target_hexes: Array = []  # Enemigos adyacentes para ataque físico

# Sistema de movimiento
var pending_movement_selection: bool = false  # Esperando que el jugador elija Walk/Run/Jump
var pending_turn_only: bool = false  # Esperando selección de facing para girar sin moverse
var ignore_next_click: bool = false  # Ignorar el próximo click (usado después de cerrar UI)
var ui_interaction_cooldown: float = 0.0  # Tiempo de cooldown después de interacción con UI

# Sistema de confirmación de movimiento
var pending_move_confirmation: bool = false  # Esperando confirmación de movimiento
var preview_path: Array = []  # Camino a previsualizar
var preview_destination: Vector2i = Vector2i(-1, -1)  # Destino del movimiento pendiente

# USAR GameEnums en lugar de enum local
var current_state: int = GameEnums.GameState.MOVING
var current_attack_target = null  # Objetivo actual para ataque con armas

var initiative_screen_scene = preload("res://scenes/initiative_screen.tscn")
var initiative_data_stored: Dictionary = {}
var battle_started = false

# Sistema de despliegue
var deployment_phase: bool = false
var deployment_zones: Dictionary = {}  # Zonas de despliegue por equipo
var mechs_to_deploy: Array = []  # Mechs pendientes de desplegar
var current_deploying_mech = null  # Mech que se está desplegando
var valid_deployment_hexes: Array = []  # Hexágonos válidos para despliegue

# Sistema de cámara táctil
var camera: Camera2D
var is_dragging: bool = false
var drag_start_pos: Vector2
var camera_start_pos: Vector2
var touch_points: Dictionary = {}  # ID del toque -> posición
var initial_pinch_distance: float = 0.0
var initial_zoom: Vector2 = Vector2.ONE

# Sistema de detección de tap vs drag
var touch_start_positions: Dictionary = {}  # ID del toque -> posición inicial
var has_moved_significantly: bool = false  # True si se movió más del umbral
const TOUCH_MOVE_THRESHOLD: float = 15.0  # Píxeles de umbral para considerar movimiento

# Sistema de tap largo para inspección
var long_press_timer: float = 0.0
var long_press_start_pos: Vector2  # Posición en pantalla
var long_press_start_hex: Vector2i  # Hexágono donde empezó el long press
var long_press_active: bool = false
var long_press_indicator: Node2D = null  # Indicador visual del long press
const LONG_PRESS_DURATION: float = 0.5  # Medio segundo para tap largo

# Límites de zoom y movimiento
const MIN_ZOOM = 0.3
const MAX_ZOOM = 2.0
const CAMERA_SMOOTH_SPEED = 10.0

# Sistema de indicador de mech activo
var active_mech_indicator: Control = null
var active_mech_indicator_tween: Tween = null

func update_mech_visibility():
	"""Actualiza la visibilidad de mechs enemigos según LoS desde mechs aliados"""
	if not hex_grid:
		return
	
	# Actualizar visibilidad de cada mech enemigo
	for enemy in enemy_mechs:
		if enemy.is_destroyed:
			enemy.set_visibility(false)
			continue
		
		# Verificar si algún mech aliado tiene LoS a este enemigo
		var mech_is_visible = false
		for player_mech in player_mechs:
			if player_mech.is_destroyed:
				continue
			
			# Verificar LoS desde este mech aliado al enemigo
			var has_los = LineOfSight.can_shoot(hex_grid, player_mech.hex_position, enemy.hex_position)
			if has_los:
				mech_is_visible = true
				break
		
		enemy.set_visibility(mech_is_visible)

func has_enemies_in_los(unit) -> bool:
	"""Verifica si la unidad tiene algún enemigo en línea de vista"""
	if not hex_grid:
		return false
	
	var enemies = enemy_mechs if unit in player_mechs else player_mechs
	
	for enemy in enemies:
		if enemy.is_destroyed:
			continue
		
		# Verificar LoS
		var has_los = LineOfSight.can_shoot(hex_grid, unit.hex_position, enemy.hex_position)
		if has_los:
			return true
	
	return false

func has_adjacent_enemies(unit) -> bool:
	"""Verifica si la unidad tiene algún enemigo adyacente para ataque físico"""
	if not hex_grid:
		return false
	
	var enemies = enemy_mechs if unit in player_mechs else player_mechs
	
	for enemy in enemies:
		if enemy.is_destroyed:
			continue
		
		var dist = hex_grid.hex_distance(unit.hex_position, enemy.hex_position)
		if dist <= 1:
			return true
	
	return false

func update_overlays():
	# Preparar datos de overlays para renderizado con oclusión
	if not hex_grid or not hex_grid._surface_renderer:
		return
	
	var overlays = []
	
	# Deployment phase overlays
	if deployment_phase and valid_deployment_hexes.size() > 0:
		for hex in valid_deployment_hexes:
			var color = Color(0.2, 1.0, 0.2, 0.4)  # Green
			if hex_grid.get_unit(hex):
				color = Color(0.5, 0.5, 0.5, 0.3)  # Gray for occupied
			
			# Get terrain elevation for this hex
			var terrain_elev = hex_grid.get_elevation(hex)
			var overlay_elev = terrain_elev + 0.5  # Slightly above terrain
			
			overlays.append({
				"hex": hex,
				"color": color,
				"elevation": overlay_elev
			})
	else:
		# Preview path overlays (yellow/orange - highest priority)
		if preview_path.size() > 0:
			for i in range(preview_path.size()):
				var hex = preview_path[i]
				var terrain_elev = hex_grid.get_elevation(hex)
				var alpha = 0.6 if i == preview_path.size() - 1 else 0.4  # Destino más brillante
				overlays.append({
					"hex": hex,
					"color": Color(1.0, 0.8, 0.0, alpha),  # Amarillo/naranja
					"elevation": terrain_elev + 0.5
				})
		else:
			# Movement overlays (cyan) - solo si no hay preview
			for hex in reachable_hexes:
				var terrain_elev = hex_grid.get_elevation(hex)
				overlays.append({
					"hex": hex,
					"color": Color(0.2, 0.5, 1.0, 0.4),
					"elevation": terrain_elev + 0.5
				})
		
		# Attack target overlays (red)
		for hex in target_hexes:
			var terrain_elev = hex_grid.get_elevation(hex)
			overlays.append({
				"hex": hex,
				"color": Color(1.0, 0.2, 0.2, 0.4),
				"elevation": terrain_elev + 0.5
			})
		
		# Physical attack overlays (magenta)
		for hex in physical_target_hexes:
			var terrain_elev = hex_grid.get_elevation(hex)
			overlays.append({
				"hex": hex,
				"color": Color(1.0, 0.0, 1.0, 0.4),
				"elevation": terrain_elev + 0.5
			})
	
	# Render overlays using hex_surface_renderer
	hex_grid._surface_renderer.render_overlays(overlays, hex_grid)

func _ready():
	print("[BATTLE] _ready() called")
	
	# Crear indicador de long press
	_create_long_press_indicator()
	
	# Obtener referencias a los nodos
	hex_grid = $HexGrid
	turn_manager = $TurnManager
	ui = $BattleUI
	
	print("[BATTLE] Got references - hex_grid: %s, turn_manager: %s, ui: %s" % [hex_grid != null, turn_manager != null, ui != null])
	
	# Crear y configurar cámara
	camera = Camera2D.new()
	camera.enabled = true
	camera.zoom = Vector2(0.8, 0.8)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTH_SPEED
	camera.add_to_group("cameras")
	add_child(camera)
	camera.make_current()
	
	# Centrar cámara en el mapa
	if hex_grid:
		var map_center = hex_grid.hex_to_pixel(Vector2i(hex_grid.grid_width / 2, hex_grid.grid_height / 2))
		camera.position = map_center
	
	# Crear CanvasLayer para overlays que se dibuja ENCIMA de todo
	var overlay_canvas = CanvasLayer.new()
	overlay_canvas.layer = 100
	overlay_canvas.follow_viewport_enabled = true
	add_child(overlay_canvas)
	
	# Crear overlay layer que dibuja con _draw()
	overlay_layer = Node2D.new()
	overlay_layer.set_script(preload("res://scripts/battle_overlay.gd"))
	overlay_canvas.add_child(overlay_layer)
	overlay_layer.battle_scene = self
	
	# Conectar señales
	turn_manager.turn_changed.connect(_on_turn_changed)
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.unit_activated.connect(_on_unit_activated)
	
	# Inicializar sistema de IA mejorado
	battle_ai = BattleAI.new()
	add_child(battle_ai)
	
	# Iniciar la batalla con fase de despliegue
	_setup_battle()

func _process(delta):
	# Decrementar cooldown de interacción con UI
	if ui_interaction_cooldown > 0:
		ui_interaction_cooldown -= delta
	
	# Procesar timer de tap largo
	if long_press_active:
		var prev_timer = long_press_timer
		long_press_timer += delta
		
		# Actualizar indicador visual solo si cambió el progreso visual (cada 5%)
		if long_press_indicator:
			long_press_indicator.visible = true
			long_press_indicator.global_position = long_press_start_pos
			# Optimización: Solo redibujar si cambió visualmente
			var prev_percent = int(prev_timer / LONG_PRESS_DURATION * 20)
			var curr_percent = int(long_press_timer / LONG_PRESS_DURATION * 20)
			if prev_percent != curr_percent:
				long_press_indicator.queue_redraw()
		
		if long_press_timer >= LONG_PRESS_DURATION:
			# Tap largo completado - inspeccionar mech
			long_press_active = false
			
			# Feedback háptico en móvil
			if OS.has_feature("mobile"):
				Input.vibrate_handheld(50)  # 50ms de vibración
			
			# Ocultar indicador
			if long_press_indicator:
				long_press_indicator.visible = false
			
			# Inspeccionar el mech en el hexágono donde empezó el long press
			print("[DEBUG] Long press completed at hex:", long_press_start_hex)
			_handle_mech_inspect(long_press_start_hex)
	else:
		# Ocultar indicador si no está activo
		if long_press_indicator:
			long_press_indicator.visible = false

func show_initiative_screen():
	# Ocultar el UI principal durante la iniciativa
	if ui and ui.has_method("hide_main_ui"):
		ui.hide_main_ui()
	
	var initiative_screen = initiative_screen_scene.instantiate()
	
	# CRÍTICO: Poner el CanvasLayer en un layer MÁS ALTO que el UI
	# Los layers más altos se renderizan encima
	initiative_screen.layer = 100  # UI está en layer 0 por defecto
	
	add_child(initiative_screen)
	
	# Pasar los nombres de los mechs a la pantalla de iniciativa
	initiative_screen.player_mech_names = []
	for mech in player_mechs:
		initiative_screen.player_mech_names.append(mech.mech_name)
	
	initiative_screen.enemy_mech_names = []
	for mech in enemy_mechs:
		initiative_screen.enemy_mech_names.append(mech.mech_name)
	
	# Conectar señal (usar CONNECT_ONE_SHOT para que se desconecte automáticamente)
	initiative_screen.initiative_complete.connect(_on_initiative_screen_complete, CONNECT_ONE_SHOT)

func _on_initiative_screen_complete(data: Dictionary):
	# Mostrar el UI principal de nuevo
	if ui and ui.has_method("show_main_ui"):
		ui.show_main_ui()
	
	# Guardar datos de iniciativa
	initiative_data_stored = data
	
	# Asignar iniciativas individuales a cada mech
	if data.has("player_initiatives") and data.has("enemy_initiatives"):
		for i in range(min(player_mechs.size(), data["player_initiatives"].size())):
			player_mechs[i].initiative = data["player_initiatives"][i]
		
		for i in range(min(enemy_mechs.size(), data["enemy_initiatives"].size())):
			enemy_mechs[i].initiative = data["enemy_initiatives"][i]
		
		# Mostrar resultados en el log
		if ui:
			ui.add_combat_message("", Color.WHITE)
			ui.add_combat_message("╔═══════════════════════════════╗", Color.GOLD)
			ui.add_combat_message("║     INITIATIVE RESULTS        ║", Color.GOLD)
			ui.add_combat_message("╚═══════════════════════════════╝", Color.GOLD)
			ui.add_combat_message("", Color.WHITE)
			ui.add_combat_message("PLAYER LANCE:", Color.CYAN)
			for i in range(player_mechs.size()):
				ui.add_combat_message("  • %s: %d" % [player_mechs[i].mech_name, player_mechs[i].initiative], Color.WHITE)
			ui.add_combat_message("", Color.WHITE)
			ui.add_combat_message("ENEMY FORCE:", Color.RED)
			for i in range(enemy_mechs.size()):
				ui.add_combat_message("  • %s: %d" % [enemy_mechs[i].mech_name, enemy_mechs[i].initiative], Color.ORANGE_RED)
			ui.add_combat_message("", Color.WHITE)
	
	# Si es la primera vez, iniciar la batalla
	if not battle_started:
		# Iniciar el sistema de turnos
		turn_manager.start_battle(player_mechs, enemy_mechs)
		
		# Configurar el sistema de IA mejorado
		if battle_ai:
			battle_ai.setup(hex_grid, player_mechs, self)
		
		# Actualizar visibilidad inicial
		update_mech_visibility()
		
		battle_started = true
		
		# Mostrar mensaje de ayuda para inspección de mechs
		if ui and ui.has_method("add_combat_message"):
			ui.add_combat_message("💡 TIP: Long press on a mech to inspect its armor and status", Color(0.7, 0.9, 1.0))
	else:
		# Turno posterior: usar los datos de iniciativa con el turn_manager
		if turn_manager:
			turn_manager.use_precalculated_initiative(data)

func get_stored_initiative() -> Dictionary:
	return initiative_data_stored

func clear_initiative_data():
	initiative_data_stored = {}

func _setup_battle():
	# Definir zonas de despliegue
	# Jugador: borde sur (filas 14-17 de un mapa de 18 filas)
	# Enemigo: borde norte (filas 0-3)
	deployment_zones["player"] = []
	deployment_zones["enemy"] = []
	
	# Generar hexágonos de despliegue para cada equipo
	for x in range(hex_grid.grid_width):
		for y in range(hex_grid.grid_height):
			var hex_pos = Vector2i(x, y)
			var terrain = hex_grid.get_terrain(hex_pos)
			
			# No permitir despliegue en agua
			if terrain == TerrainType.Type.WATER:
				continue
			
			# Zona del jugador (sur del mapa)
			if y >= hex_grid.grid_height - 4:
				deployment_zones["player"].append(hex_pos)
			# Zona enemiga (norte del mapa)
			elif y < 4:
				deployment_zones["enemy"].append(hex_pos)
	
	# Crear 4 mechs para el jugador
	var loadout_manager = get_node_or_null("/root/SelectedLoadoutManager")
	var mech_bay_manager = get_node_or_null("/root/MechBayManager")
	
	# Array para almacenar todos los mechs del jugador (4 mechs)
	var player_mechs_data: Array = []
	
	# Lance del jugador - 4 mechs diferentes
	var player_lance_configs = [
		{"name": "Atlas", "tonnage": 100, "walk_mp": 3, "run_mp": 5, "jump_mp": 0},
		{"name": "Timber Wolf", "tonnage": 75, "walk_mp": 5, "run_mp": 8, "jump_mp": 0},
		{"name": "Hunchback", "tonnage": 50, "walk_mp": 4, "run_mp": 6, "jump_mp": 0},
		{"name": "Jenner", "tonnage": 35, "walk_mp": 7, "run_mp": 11, "jump_mp": 5}
	]
	
	if loadout_manager and loadout_manager.has_loadout():
		# Si hay loadout personalizado, usar ese para el primer mech
		var loadout = loadout_manager.get_selected_loadout()
		var player_mech_data = _convert_loadout_to_mech_data(loadout)
		player_mechs_data.append(player_mech_data)
		
		# Añadir los 3 mechs restantes del lance predefinido
		for i in range(1, 4):
			if mech_bay_manager:
				var mech_data = mech_bay_manager.get_mech_data(player_lance_configs[i]["name"], "")
				if mech_data:
					player_mechs_data.append(mech_data)
				else:
					player_mechs_data.append(player_lance_configs[i])
			else:
				player_mechs_data.append(player_lance_configs[i])
	else:
		# Usar todo el lance predefinido
		if mech_bay_manager:
			for config in player_lance_configs:
				var mech_data = mech_bay_manager.get_mech_data(config["name"], "")
				if mech_data:
					player_mechs_data.append(mech_data)
				else:
					player_mechs_data.append(config)
		else:
			# Fallback: usar configuración básica
			print("[INFO] Using default player lance (4 mechs)")
			player_mechs_data = player_lance_configs.duplicate()
	
	# Crear todos los mechs del jugador para despliegue
	for mech_data in player_mechs_data:
		var player_mech = _create_mech_for_deployment(mech_data, "player")
		mechs_to_deploy.append(player_mech)
	
	# Crear 4 mechs para el enemigo
	var enemy_mechs_data: Array = []
	
	# Lance enemigo - 4 mechs diferentes
	var enemy_lance_configs = [
		{"name": "Daishi", "tonnage": 100, "walk_mp": 3, "run_mp": 5, "jump_mp": 0},
		{"name": "Mad Cat", "tonnage": 75, "walk_mp": 5, "run_mp": 8, "jump_mp": 0},
		{"name": "Catapult", "tonnage": 65, "walk_mp": 4, "run_mp": 6, "jump_mp": 4},
		{"name": "Kit Fox", "tonnage": 30, "walk_mp": 8, "run_mp": 12, "jump_mp": 0}
	]
	
	if mech_bay_manager:
		for config in enemy_lance_configs:
			var mech_data = mech_bay_manager.get_mech_data(config["name"], "")
			if mech_data:
				enemy_mechs_data.append(mech_data)
			else:
				enemy_mechs_data.append(config)
	else:
		# Fallback: usar configuración básica
		print("[INFO] Using default enemy lance (4 mechs)")
		enemy_mechs_data = enemy_lance_configs.duplicate()
	
	# Crear todos los mechs enemigos para despliegue
	for mech_data in enemy_mechs_data:
		var enemy_mech = _create_mech_for_deployment(mech_data, "enemy")
		mechs_to_deploy.append(enemy_mech)
	
	# Iniciar fase de despliegue
	_start_deployment_phase()

func _create_mech_for_deployment(mech_data: Dictionary, team: String) -> Mech:
	"""Crea un mech pero no lo coloca en el mapa todavía"""
	var mech = Mech.new()
	mech.mech_name = mech_data.get("name", "Unknown")
	mech.pilot_name = "Player" if team == "player" else "Enemy"
	mech.tonnage = mech_data.get("tonnage", 50)
	mech.walk_mp = mech_data.get("walk_mp", 4)
	mech.run_mp = mech_data.get("run_mp", 6)
	mech.jump_mp = mech_data.get("jump_mp", 0)
	mech.current_movement = mech.walk_mp
	mech.is_player_controlled = (team == "player")  # Marcar si es del jugador
	
	# Copiar armadura
	if mech_data.has("armor"):
		mech.armor = mech_data["armor"].duplicate(true)
	
	# Copiar armas
	if mech_data.has("weapons"):
		mech.weapons = mech_data["weapons"].duplicate(true)
	
	# Copiar heat capacity y dissipation
	if mech_data.has("heat_capacity"):
		mech.heat_capacity = mech_data["heat_capacity"]
	if mech_data.has("heat_dissipation"):
		mech.heat_dissipation = mech_data["heat_dissipation"]
	
	# Copiar gunnery skill
	if mech_data.has("gunnery_skill"):
		mech.pilot_skill = mech_data["gunnery_skill"]
	
	mech.z_index = 10
	mech.set_meta("team", team)  # Guardar el equipo como metadata
	
	return mech

func _start_deployment_phase():
	"""Inicia la fase de despliegue"""
	deployment_phase = true
	
	# Contar total de mechs por equipo
	var total_player = 0
	var total_enemy = 0
	for mech in mechs_to_deploy:
		if mech.get_meta("team") == "player":
			total_player += 1
		else:
			total_enemy += 1
	
	if ui:
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("╔════════════════════════════════════════════╗", Color.GOLD)
		ui.add_combat_message("║       DEPLOYMENT PHASE - PLACE MECHS      ║", Color.GOLD)
		ui.add_combat_message("╚════════════════════════════════════════════╝", Color.GOLD)
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("📋 MISSION BRIEF:", Color.CYAN)
		ui.add_combat_message("  • Your Lance: %d mechs to deploy" % total_player, Color.WHITE)
		ui.add_combat_message("  • Enemy Force: %d mechs detected" % total_enemy, Color.RED)
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("🎯 DEPLOYMENT INSTRUCTIONS:", Color.YELLOW)
		ui.add_combat_message("  1. Click on a GREEN hex in the southern zone", Color.WHITE)
		ui.add_combat_message("  2. Select facing direction for each mech", Color.WHITE)
		ui.add_combat_message("  3. Deploy all %d mechs to begin battle" % total_player, Color.WHITE)
		ui.add_combat_message("", Color.WHITE)
	
	# Comenzar con el primer mech del jugador
	_deploy_next_mech()

func _deploy_next_mech():
	"""Selecciona el siguiente mech para desplegar"""
	
	if mechs_to_deploy.is_empty():
		_end_deployment_phase()
		return
	
	current_deploying_mech = mechs_to_deploy.pop_front()
	var team = current_deploying_mech.get_meta("team")
	
	# Contar cuántos mechs quedan por desplegar de cada equipo
	var player_remaining = 0
	var _enemy_remaining = 0  # Prefijo _ para evitar warning
	for mech in mechs_to_deploy:
		if mech.get_meta("team") == "player":
			player_remaining += 1
		else:
			_enemy_remaining += 1
	
	if team == "player":
		# Jugador despliega manualmente
		valid_deployment_hexes = deployment_zones["player"].duplicate()
		if ui:
			var total_player_mechs = player_mechs.size() + player_remaining + 1
			var deployed_count = total_player_mechs - player_remaining - 1
			var current_num = deployed_count + 1
			
			ui.add_combat_message("─────────────────────────────────────────", Color.GRAY)
			ui.add_combat_message("⚔️  DEPLOYING MECH [%d/%d]" % [current_num, total_player_mechs], Color.GOLD)
			ui.add_combat_message("─────────────────────────────────────────", Color.GRAY)
			ui.add_combat_message("🤖 Mech: %s" % current_deploying_mech.mech_name, Color.CYAN)
			ui.add_combat_message("⚖️  Tonnage: %d tons" % current_deploying_mech.tonnage, Color.WHITE)
			ui.add_combat_message("🏃 Movement: Walk %d / Run %d" % [current_deploying_mech.walk_mp, current_deploying_mech.run_mp], Color.WHITE)
			if current_deploying_mech.jump_mp > 0:
				ui.add_combat_message("🚀 Jump: %d MP" % current_deploying_mech.jump_mp, Color.LIGHT_BLUE)
			ui.add_combat_message("", Color.WHITE)
			if player_remaining > 0:
				ui.add_combat_message("📊 Progress: %d deployed, %d remaining" % [deployed_count, player_remaining], Color.YELLOW)
			else:
				ui.add_combat_message("📊 Progress: This is your LAST mech!" % [], Color.ORANGE)
			ui.add_combat_message("👉 Click on a GREEN hex to deploy", Color.GREEN)
			ui.add_combat_message("", Color.WHITE)
		update_overlays()
	else:
		# IA despliega automáticamente
		_deploy_ai_mech()

func _deploy_ai_mech():
	"""Despliega un mech de la IA automáticamente"""
	var team = current_deploying_mech.get_meta("team")
	var zone = deployment_zones[team]
	
	# Elegir una posición aleatoria válida
	var valid_hexes = []
	for hex in zone:
		if not hex_grid.get_unit(hex):
			valid_hexes.append(hex)
	
	if valid_hexes.is_empty():
		push_error("No valid deployment hexes for AI")
		return
	
	var deploy_hex = valid_hexes[randi() % valid_hexes.size()]
	var facing = randi() % 6  # Orientación aleatoria
	
	# Contar cuántos enemigos quedan por desplegar
	var enemy_remaining = 0
	for mech in mechs_to_deploy:
		if mech.get_meta("team") == "enemy":
			enemy_remaining += 1
	
	if ui:
		var total_enemy_mechs = enemy_mechs.size() + enemy_remaining + 1
		var deployed_count = total_enemy_mechs - enemy_remaining - 1
		ui.add_combat_message("🔴 ENEMY DEPLOYMENT [%d/%d]: %s" % [deployed_count + 1, total_enemy_mechs, current_deploying_mech.mech_name], Color.RED)
		ui.add_combat_message("  Position: [%d, %d], Facing: %s" % [deploy_hex.x, deploy_hex.y, FacingSystem.get_facing_name(facing)], Color.ORANGE)
	
	_place_mech(current_deploying_mech, deploy_hex, facing)
	
	# Continuar con el siguiente mech después de un delay
	await get_tree().create_timer(0.5).timeout
	_deploy_next_mech()

func _place_mech(mech: Mech, hex: Vector2i, facing: int):
	"""Coloca un mech en el mapa"""
	mech.hex_position = hex
	mech.facing = facing
	
	var team = mech.get_meta("team")
	
	add_child(mech)
	mech.visible = true  # Asegurar que sea visible
	hex_grid.set_unit(hex, mech)
	mech.update_visual_position(hex_grid)
	mech.update_facing_visual()  # Actualizar sprite según facing
	
	# Añadir a la lista correcta y mostrar confirmación
	if team == "player":
		player_mechs.append(mech)
		if ui:
			ui.add_combat_message("✓ %s deployed at [%d, %d], facing %s" % [
				mech.mech_name, 
				hex.x, 
				hex.y, 
				FacingSystem.get_facing_name(facing)
			], Color.GREEN)
			ui.add_combat_message("", Color.WHITE)
	else:
		enemy_mechs.append(mech)

func _end_deployment_phase():
	"""Finaliza la fase de despliegue e inicia la batalla"""
	deployment_phase = false
	valid_deployment_hexes.clear()
	current_deploying_mech = null
	
	if ui:
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("╔══════════════════════════════════════════╗", Color.GREEN)
		ui.add_combat_message("║     ✓ DEPLOYMENT COMPLETE!              ║", Color.GREEN)
		ui.add_combat_message("╚══════════════════════════════════════════╝", Color.GREEN)
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("📊 BATTLE ROSTER:", Color.CYAN)
		ui.add_combat_message("  ► YOUR LANCE: %d mechs deployed" % player_mechs.size(), Color.LIGHT_BLUE)
		for mech in player_mechs:
			ui.add_combat_message("    • %s (%d tons)" % [mech.mech_name, mech.tonnage], Color.WHITE)
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("  ► ENEMY FORCE: %d mechs detected" % enemy_mechs.size(), Color.ORANGE_RED)
		for mech in enemy_mechs:
			ui.add_combat_message("    • %s (%d tons)" % [mech.mech_name, mech.tonnage], Color.RED)
		ui.add_combat_message("", Color.WHITE)
		ui.add_combat_message("⚔️  Preparing for combat...", Color.YELLOW)
		ui.add_combat_message("🎲 Rolling for initiative...", Color.GOLD)
		ui.add_combat_message("", Color.WHITE)
	
	# Asegurar que selected_unit apunte al primer mech del jugador
	if player_mechs.size() > 0:
		selected_unit = player_mechs[0]
	
	update_overlays()
	
	# Mostrar pantalla de iniciativa DESPUÉS del despliegue
	show_initiative_screen()

## Crea un mech desde datos del MechBayManager
func _create_player_mech_from_data(mech_data: Dictionary, hex_position: Vector2i) -> Mech:
	var mech = Mech.new()
	mech.mech_name = mech_data.get("name", "Unknown")
	mech.hex_position = hex_position
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
	
	# Copiar heat dissipation
	if mech_data.has("heat_dissipation"):
		mech.heat_dissipation = mech_data["heat_dissipation"]
	
	# Copiar gunnery skill (se mapea a pilot_skill en Mech)
	if mech_data.has("gunnery_skill"):
		mech.pilot_skill = mech_data["gunnery_skill"]
	
	mech.z_index = 10
	add_child(mech)
	player_mechs.append(mech)
	hex_grid.set_unit(mech.hex_position, mech)
	mech.update_visual_position(hex_grid)
	
	return mech

## Crea un mech enemigo desde datos del MechBayManager
func _create_enemy_mech_from_data(mech_data: Dictionary, hex_position: Vector2i) -> Mech:
	var mech = Mech.new()
	mech.mech_name = mech_data.get("name", "Unknown")
	mech.hex_position = hex_position
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
	
	# Copiar heat dissipation
	if mech_data.has("heat_dissipation"):
		mech.heat_dissipation = mech_data["heat_dissipation"]
	
	# Copiar gunnery skill (se mapea a pilot_skill en Mech)
	if mech_data.has("gunnery_skill"):
		mech.pilot_skill = mech_data["gunnery_skill"]
	
	mech.z_index = 10
	add_child(mech)
	enemy_mechs.append(mech)
	hex_grid.set_unit(mech.hex_position, mech)
	mech.update_visual_position(hex_grid)
	
	return mech

## Convierte un loadout del Mech Bay al formato de mech_data para batalla
func _convert_loadout_to_mech_data(loadout: Dictionary) -> Dictionary:
	var mech_data = {}
	
	# Datos básicos del mech
	mech_data["name"] = loadout.get("mech_name", "Custom Mech")
	mech_data["tonnage"] = loadout.get("mech_tonnage", 50)
	var engine_rating = loadout.get("engine_rating", 200)
	
	# Calcular movimiento basado en engine rating y tonnage
	# Walk MP = engine_rating / tonnage (redondeado hacia abajo)
	var walk_mp = int(engine_rating / mech_data["tonnage"])
	mech_data["walk_mp"] = walk_mp
	mech_data["run_mp"] = int(walk_mp * 1.5)  # Run es 1.5x walk
	
	# Contar jump jets en el loadout
	var jump_jet_count = 0
	var loadout_components = loadout.get("loadout", {})
	for location in loadout_components.keys():
		for component in loadout_components[location]:
			if component.get("id", "") == "jump_jet":
				jump_jet_count += 1
	mech_data["jump_mp"] = jump_jet_count
	
	# Extraer armas del loadout
	var weapons = []
	for location in loadout_components.keys():
		for component in loadout_components[location]:
			var comp_type = component.get("type", -1)
			# Solo añadir armas (no equipamiento)
			if comp_type in [
				ComponentDatabase.ComponentType.WEAPON_ENERGY,
				ComponentDatabase.ComponentType.WEAPON_BALLISTIC,
				ComponentDatabase.ComponentType.WEAPON_MISSILE
			]:
				# Crear copia del arma con datos completos
				var weapon = component.duplicate(true)
				# Convertir location enum a string para compatibilidad con battle system
				weapon["location"] = _convert_location_to_string(location)
				weapons.append(weapon)
	
	mech_data["weapons"] = weapons
	
	# Calcular heat capacity basado en heat sinks
	var heat_sink_count = 10  # Engine incluye 10 por defecto
	for location in loadout_components.keys():
		for component in loadout_components[location]:
			if component.get("type", -1) == ComponentDatabase.ComponentType.EQUIPMENT_HEATSINK:
				heat_sink_count += component.get("heat_dissipation", 1)
	
	# Heat capacity = 30 + (heat sinks adicionales * 1)
	# Por defecto el mech tiene capacidad 30, cada heat sink adicional suma 1
	mech_data["heat_capacity"] = 30 + (heat_sink_count - 10)
	
	# Heat dissipation = número total de heat sinks
	# Cada heat sink disipa 1 punto de calor por turno
	mech_data["heat_dissipation"] = heat_sink_count
	
	# Gunnery skill por defecto
	mech_data["gunnery_skill"] = 4
	
	# TODO: Armadura - por ahora usar valores por defecto basados en tonnage
	# En el futuro, el loadout debería incluir configuración de armadura
	mech_data["armor"] = _generate_default_armor(mech_data["tonnage"])
	
	return mech_data

## Genera valores de armadura por defecto basados en tonnage
func _generate_default_armor(tonnage: int) -> Dictionary:
	# Armadura aproximada: usar ~80% de la capacidad máxima
	var armor_points = int(tonnage * 3.2)  # Aproximadamente 3.2 puntos por tonelada
	
	# Distribución por localización (porcentajes aproximados)
	return {
		"head": {"current": max(9, int(armor_points * 0.04)), "max": max(9, int(armor_points * 0.04))},
		"center_torso": {"current": int(armor_points * 0.20), "max": int(armor_points * 0.20)},
		"left_torso": {"current": int(armor_points * 0.15), "max": int(armor_points * 0.15)},
		"right_torso": {"current": int(armor_points * 0.15), "max": int(armor_points * 0.15)},
		"left_arm": {"current": int(armor_points * 0.12), "max": int(armor_points * 0.12)},
		"right_arm": {"current": int(armor_points * 0.12), "max": int(armor_points * 0.12)},
		"left_leg": {"current": int(armor_points * 0.11), "max": int(armor_points * 0.11)},
		"right_leg": {"current": int(armor_points * 0.11), "max": int(armor_points * 0.11)}
	}

## Convierte location enum (del loadout) a string (para battle system)
func _convert_location_to_string(location) -> String:
	# Si ya es un string, devolverlo tal cual
	if typeof(location) == TYPE_STRING:
		return location
	
	# Si es un int (enum), convertirlo
	match location:
		0:  # HEAD
			return "head"
		1:  # CENTER_TORSO
			return "center_torso"
		2:  # LEFT_TORSO
			return "left_torso"
		3:  # RIGHT_TORSO
			return "right_torso"
		4:  # LEFT_ARM
			return "left_arm"
		5:  # RIGHT_ARM
			return "right_arm"
		6:  # LEFT_LEG
			return "left_leg"
		7:  # RIGHT_LEG
			return "right_leg"
		_:
			return "center_torso"

## Crea un mech para el equipo del jugador (legacy - para compatibilidad)
func _create_player_mech(mech_name: String, mech_position: Vector2i, tonnage: int, walk: int, run: int, jump: int) -> Mech:
	var mech = Mech.new()
	mech.mech_name = mech_name
	mech.hex_position = mech_position
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
func _create_enemy_mech(mech_name: String, mech_position: Vector2i, tonnage: int, walk: int, run: int, jump: int) -> Mech:
	var mech = Mech.new()
	mech.mech_name = mech_name
	mech.hex_position = mech_position
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
	# Permitir input durante la fase de despliegue
	if hex_grid == null or camera == null:
		return
	
	# Bloquear input solo si no estamos en despliegue y la batalla no ha comenzado
	if not deployment_phase and not battle_started:
		return
	
	# Detectar inicio de tap largo (táctil o mouse)
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		# Solo iniciar tap largo si no hay otros toques activos (evitar durante pinch zoom)
		if touch_points.size() == 0:
			long_press_active = true
			long_press_timer = 0.0
			long_press_start_pos = event.position
			has_moved_significantly = false  # Reset del flag de movimiento
			
			# Guardar posición inicial del toque para detectar drags
			if event is InputEventScreenTouch:
				touch_start_positions[event.index] = event.position
			
			# Calcular el hexágono donde empezó el long press
			var world_pos = camera.get_global_mouse_position()
			long_press_start_hex = hex_grid.pixel_to_hex(world_pos - hex_grid.global_position)
	
	# Cancelar tap largo si se mueve mucho o se suelta antes de tiempo
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if long_press_active and event.position.distance_to(long_press_start_pos) > TOUCH_MOVE_THRESHOLD:
			long_press_active = false
			has_moved_significantly = true
		
		# Detectar movimiento significativo para cualquier toque
		if event is InputEventScreenDrag and touch_start_positions.has(event.index):
			if event.position.distance_to(touch_start_positions[event.index]) > TOUCH_MOVE_THRESHOLD:
				has_moved_significantly = true
		
		# Detectar movimiento significativo para mouse
		if event is InputEventMouseMotion and touch_start_positions.has(0):
			if event.position.distance_to(touch_start_positions[0]) > TOUCH_MOVE_THRESHOLD:
				has_moved_significantly = true
	
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
		# Limpiar la posición inicial del toque
		if touch_start_positions.has(event.index):
			touch_start_positions.erase(event.index)
		
		# Solo procesar como click si no hubo movimiento significativo
		if touch_points.size() == 0 and not long_press_active and not has_moved_significantly:
			# Verificar cooldown de interacción con UI
			if ui_interaction_cooldown > 0:
				return
			
			# Bloquear clics si el facing selector está visible
			if ui and ui.has_method("is_facing_selector_visible") and ui.is_facing_selector_visible():
				return
			
			# Verificar si debemos ignorar este click
			if ignore_next_click:
				ignore_next_click = false
				return
			
			var world_pos = camera.get_global_mouse_position()
			var hex = hex_grid.pixel_to_hex(world_pos - hex_grid.global_position)
			_handle_hex_clicked(hex)
		
		# Resetear el flag de movimiento cuando se sueltan todos los toques
		# Usar call_deferred para evitar race conditions con eventos emulados de mouse
		if touch_points.size() == 0:
			call_deferred("_reset_movement_flag")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Guardar posición inicial para detectar drags con mouse
		touch_start_positions[0] = event.position
		has_moved_significantly = false
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Solo procesar como click si no hubo movimiento significativo
		if not long_press_active and not has_moved_significantly:
			# Verificar cooldown de interacción con UI (solo en móvil, no en PC)
			if OS.has_feature("mobile") and ui_interaction_cooldown > 0:
				return
			
			# Bloquear clics si el facing selector está visible
			if ui and ui.has_method("is_facing_selector_visible") and ui.is_facing_selector_visible():
				return
			
			# Verificar si debemos ignorar este click
			if ignore_next_click:
				ignore_next_click = false
				return
			
			var world_pos = camera.get_global_mouse_position()
			var hex = hex_grid.pixel_to_hex(world_pos - hex_grid.global_position)
			_handle_hex_clicked(hex)
		
		# Limpiar posición inicial y resetear flag con deferred
		touch_start_positions.erase(0)
		call_deferred("_reset_movement_flag")

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
			# NO marcar movimiento aquí - solo se marca durante el drag real
			
			touch_points.erase(event.index)
			
			if touch_points.size() == 0:
				is_dragging = false
			elif touch_points.size() == 1:
				# Volver a modo arrastre con el dedo restante
				is_dragging = true
				var remaining_point = touch_points.values()[0]
				drag_start_pos = remaining_point
				camera_start_pos = camera.position
		
		return touch_points.size() > 0
	
	# Movimiento táctil
	if event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		
		if touch_points.size() == 1 and is_dragging:
			# Arrastrar cámara con un dedo
			var drag_delta = (drag_start_pos - event.position) / camera.zoom.x
			camera.position = camera_start_pos + drag_delta
			has_moved_significantly = true  # Marcar que hubo movimiento de cámara
			return true
		elif touch_points.size() == 2:
			# Zoom con pellizco (pinch)
			has_moved_significantly = true  # Marcar que hubo gesto de zoom
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
				# NO marcar movimiento aquí - solo se marca durante el drag real
				is_dragging = false
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= 1.1
			camera.zoom.x = clamp(camera.zoom.x, MIN_ZOOM, MAX_ZOOM)
			camera.zoom.y = clamp(camera.zoom.y, MIN_ZOOM, MAX_ZOOM)
			has_moved_significantly = true  # Zoom también cuenta como gesto de cámara
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom *= 0.9
			camera.zoom.x = clamp(camera.zoom.x, MIN_ZOOM, MAX_ZOOM)
			camera.zoom.y = clamp(camera.zoom.y, MIN_ZOOM, MAX_ZOOM)
			has_moved_significantly = true  # Zoom también cuenta como gesto de cámara
			return true
	
	if event is InputEventMouseMotion and is_dragging:
		var drag_delta = (drag_start_pos - event.position) / camera.zoom.x
		camera.position = camera_start_pos + drag_delta
		has_moved_significantly = true  # Marcar que hubo movimiento de cámara
		return true
	
	return false

func _reset_movement_flag():
	"""Helper para resetear el flag de movimiento de forma diferida"""
	has_moved_significantly = false

func _handle_hex_clicked(hex: Vector2i):
	if not hex_grid.is_valid_hex(hex):
		return
	
	# Manejar fase de despliegue
	if deployment_phase:
		_handle_deployment_click(hex)
		return
	
	# print("[DEBUG] _handle_hex_clicked: hex=%s, current_state=%d" % [hex, current_state])
	
	match current_state:
		GameEnums.GameState.MOVING:
			_handle_movement_click(hex)
		GameEnums.GameState.TARGETING:
			_handle_targeting_click(hex)
		GameEnums.GameState.WEAPON_ATTACK:
			_handle_weapon_attack_click(hex)
		GameEnums.GameState.PHYSICAL_TARGETING:
			_handle_physical_targeting_click(hex)

func _handle_deployment_click(hex: Vector2i):
	"""Maneja clics durante la fase de despliegue"""
	if not current_deploying_mech:
		return
	
	# Verificar que el hex esté en la zona de despliegue válida
	if hex not in valid_deployment_hexes:
		if ui:
			ui.add_combat_message("Invalid deployment location", Color.RED)
		return
	
	# Verificar que no haya otro mech en esa posición
	if hex_grid.get_unit(hex):
		if ui:
			ui.add_combat_message("Hex already occupied", Color.RED)
		return
	
	# Mostrar selector de orientación
	# Guardar el hex seleccionado temporalmente
	selected_hex = hex
	
	# Convertir posición del hex a posición de pantalla (con elevación)
	var hex_pixel = hex_grid.hex_to_pixel(hex, true) + hex_grid.global_position
	var screen_pos = hex_pixel
	if camera:
		# Ajustar por la posición de la cámara
		screen_pos = hex_pixel - camera.position + get_viewport().get_visible_rect().size / 2
	
	# IMPORTANTE: Solo mostrar si no está ya visible
	if ui and ui.has_method("show_facing_selector") and not ui.is_facing_selector_visible():
		ui.show_facing_selector(screen_pos, hex)

var _cached_hex_screen_pos: Dictionary = {}
var _camera_last_pos: Vector2 = Vector2.ZERO

func get_screen_position_for_hex(hex: Vector2i) -> Vector2:
	"""Convierte una posición hex a coordenadas de pantalla"""
	# Optimización: Cachear si la cámara no se movió
	var current_cam_pos = camera.position if camera else Vector2.ZERO
	if current_cam_pos != _camera_last_pos:
		_cached_hex_screen_pos.clear()
		_camera_last_pos = current_cam_pos
	
	var cache_key = str(hex)
	if _cached_hex_screen_pos.has(cache_key):
		return _cached_hex_screen_pos[cache_key]
	
	var hex_pixel = hex_grid.hex_to_pixel(hex, true) + hex_grid.global_position
	var screen_pos = hex_pixel
	if camera:
		screen_pos = hex_pixel - camera.position + get_viewport().get_visible_rect().size / 2
	
	_cached_hex_screen_pos[cache_key] = screen_pos
	return screen_pos

func on_facing_selected(facing: int):
	"""Llamado cuando el jugador selecciona una orientación"""
	
	# Manejar cancelación (facing = -1)
	if facing == -1:
		print("[BATTLE] Facing selection cancelled")
		selected_hex = Vector2i(-1, -1)
		if ui and ui.has_method("hide_facing_selector"):
			ui.hide_facing_selector()
		# En deployment, no hacer nada más - permitir que el jugador elija otro hex
		return
	
	if deployment_phase and current_deploying_mech and selected_hex != Vector2i(-1, -1):
		# Estamos en fase de despliegue
		_place_mech(current_deploying_mech, selected_hex, facing)
		selected_hex = Vector2i(-1, -1)  # Reset
		
		# Asegurar que el selector se cierre antes de continuar
		if ui and ui.has_method("hide_facing_selector"):
			ui.hide_facing_selector()
		
		# Pequeño delay para asegurar que el selector se cerró completamente
		await get_tree().create_timer(0.1).timeout
		
		# Siguiente mech
		_deploy_next_mech()
	elif pending_turn_only and selected_unit and selected_unit in player_mechs:
		# Estamos en modo Turn Only - girar sin moverse
		print("[BATTLE] Turn only: %d -> %d" % [selected_unit.facing, facing])
		
		var rotation_cost = MovementSystem.get_rotation_cost(selected_unit.facing, facing)
		
		# Aplicar rotación
		selected_unit.facing = facing
		selected_unit.update_visual_position(hex_grid)
		if selected_unit.has_method("update_facing_visual"):
			selected_unit.update_facing_visual()
		
		if ui:
			ui.add_combat_message("  → New facing: %s (Cost: %d MP)" % [FacingSystem.get_facing_name(facing), rotation_cost], Color.CYAN)
			ui.update_unit_info(selected_unit)
		
		pending_turn_only = false
		
		# Finalizar activación
		await get_tree().create_timer(0.2).timeout
		turn_manager.complete_unit_activation()
	elif selected_unit and selected_unit in player_mechs and selected_hex != Vector2i(-1, -1):
		# Estamos después del movimiento - ajuste final de facing (gratis)
		print("[BATTLE] Post-movement facing adjustment: %d -> %d" % [selected_unit.facing, facing])
		
		# Aplicar rotación sin costo (es parte del movimiento)
		selected_unit.facing = facing
		selected_unit.update_visual_position(hex_grid)
		if selected_unit.has_method("update_facing_visual"):
			selected_unit.update_facing_visual()
		
		if ui:
			ui.add_combat_message("  → Final facing: %s" % FacingSystem.get_facing_name(facing), Color.CYAN)
			ui.update_unit_info(selected_unit)
		
		selected_hex = Vector2i(-1, -1)  # Reset
		
		# Finalizar activación
		await get_tree().create_timer(0.2).timeout
		turn_manager.complete_unit_activation()

func _calculate_rotations(from_facing: int, to_facing: int) -> int:
	"""Calcula el número mínimo de rotaciones (cada una cuesta 1 MP)"""
	# Calcular diferencia
	var diff = (to_facing - from_facing + 6) % 6
	
	# El camino más corto es el mínimo entre ir en sentido horario o antihorario
	var clockwise = diff
	var counter_clockwise = 6 - diff
	
	return min(clockwise, counter_clockwise)

func select_movement_type(movement_type: int):  # Mech.MovementType
	"""Llamado cuando el jugador selecciona Walk/Run/Jump"""
	if not selected_unit or selected_unit not in player_mechs:
		return
	
	pending_movement_selection = false
	
	# Activar cooldown para evitar que el release del botón se interprete como click en mapa
	ui_interaction_cooldown = 0.2  # 200ms de cooldown
	
	selected_unit.start_movement(movement_type)
	
	var movement_names = ["None", "Walk", "Run", "Jump"]
	
	# Verificar si hay MPs disponibles
	if selected_unit.current_movement <= 0:
		if ui:
			ui.add_combat_message("%s: Cannot move (%s) - 0 MP available" % [selected_unit.mech_name, movement_names[movement_type]], Color.RED)
			var penalties = []
			# Verificar penalizaciones
			if selected_unit.heat > 0:
				var heat_penalty = selected_unit.get_heat_movement_penalty()
				if heat_penalty > 0:
					penalties.append("Heat: -%d MP" % heat_penalty)
			if selected_unit.armor["left_leg"]["current"] <= 0 or selected_unit.armor["right_leg"]["current"] <= 0:
				penalties.append("Leg damage")
			if penalties.size() > 0:
				ui.add_combat_message("  Penalties: %s" % ", ".join(penalties), Color.YELLOW)
			ui.add_combat_message("  Skipping movement phase...", Color.GRAY)
		# Auto-completar activación si no hay movimiento posible
		await get_tree().create_timer(1.0).timeout
		turn_manager.complete_unit_activation()
		return
	
	# Actualizar hexagonos alcanzables segun el tipo de movimiento usando MovementSystem
	if movement_type == GameEnums.MovementType.JUMP:
		reachable_hexes = MovementSystem.get_jump_hexes(selected_unit.hex_position, selected_unit.current_movement, hex_grid, selected_unit)
	else:
		reachable_hexes = MovementSystem.get_reachable_hexes(selected_unit.hex_position, selected_unit.current_movement, movement_type, hex_grid, selected_unit)
	
	# Verificar si se encontraron hexágonos alcanzables
	if ui:
		if reachable_hexes.size() == 0 and selected_unit.current_movement > 0:
			ui.add_combat_message("%s: No reachable hexes (%s, %d MP)" % [selected_unit.mech_name, movement_names[movement_type], selected_unit.current_movement], Color.ORANGE)
			ui.add_combat_message("  Surrounded or blocked. Skipping movement...", Color.GRAY)
			# Auto-completar si está bloqueado
			await get_tree().create_timer(1.0).timeout
			turn_manager.complete_unit_activation()
			return
		else:
			ui.add_combat_message("%s selected: %s (%d MP, %d hexes)" % [selected_unit.mech_name, movement_names[movement_type], selected_unit.current_movement, reachable_hexes.size()], Color.CYAN)
			# Mostrar botón de cancelar movimiento
			ui.show_cancel_movement_button()
	
	update_overlays()

func select_turn_only():
	"""Llamado cuando el jugador selecciona solo girar sin moverse"""
	if not selected_unit or selected_unit not in player_mechs:
		return
	
	pending_movement_selection = false
	pending_turn_only = true
	
	# Activar cooldown para evitar que el release del botón se interprete como click en mapa
	ui_interaction_cooldown = 0.2  # 200ms de cooldown
	
	if ui:
		ui.add_combat_message("%s: Select new facing (Turn only)" % selected_unit.mech_name, Color.CYAN)
	
	# Mostrar selector de facing en la posición del mech
	var mech_screen_pos = selected_unit.global_position
	if ui and ui.has_method("show_facing_selector_with_current"):
		ui.show_facing_selector_with_current(mech_screen_pos, selected_unit.facing, 99)

func cancel_movement_selection():
	"""Cancela la selección de movimiento actual y vuelve al selector de tipo"""
	print("[BATTLE] Cancelling movement selection")
	
	# Limpiar hexágonos alcanzables y overlays
	reachable_hexes = []
	preview_path = []
	preview_destination = Vector2i(-1, -1)
	pending_move_confirmation = false
	update_overlays()
	
	# Volver a mostrar el selector de tipo de movimiento
	if ui and selected_unit:
		ui.hide_cancel_movement_button()
		pending_movement_selection = true
		ui.show_movement_type_selector(selected_unit)
		ui.add_combat_message("Movement cancelled - select new movement type", Color.GRAY)

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
		_preview_movement_path(selected_unit, hex)


func _preview_movement_path(unit, hex: Vector2i):
	"""Muestra el camino de movimiento y pide confirmación"""
	# Calcular camino
	var path = hex_grid.find_path(unit.hex_position, hex, unit.current_movement)
	
	if path.size() == 0:
		return
	
	# Guardar información del movimiento pendiente
	preview_path = path
	preview_destination = hex
	pending_move_confirmation = true
	
	# Calcular coste del movimiento
	var movement_cost = 0
	var rotation_cost = 0
	var current_facing = unit.facing
	
	for i in range(1, path.size()):
		var from_hex = path[i - 1]
		var to_hex = path[i]
		
		# Calcular facing necesario para este paso
		var step_facing = FacingSystem.get_facing_to_hex(from_hex, to_hex)
		
		# Calcular costo de rotación
		var step_rotation = MovementSystem.get_rotation_cost(current_facing, step_facing)
		rotation_cost += step_rotation
		
		# Calcular costo de terreno
		var step_cost = MovementSystem.calculate_movement_cost(from_hex, to_hex, unit.movement_type_used, hex_grid)
		movement_cost += step_cost
		
		current_facing = step_facing
	
	var total_cost = movement_cost + rotation_cost
	
	# Mostrar UI de confirmación
	if ui:
		var movement_names = {
			GameEnums.MovementType.WALK: "Walking",
			GameEnums.MovementType.RUN: "Running",
			GameEnums.MovementType.JUMP: "Jumping"
		}
		var move_type = movement_names.get(unit.movement_type_used, "Moving")
		var hex_count = path.size() - 1
		
		var message = "%s: %s %d hex" % [unit.mech_name, move_type, hex_count]
		if hex_count != 1:
			message += "es"
		message += " (Cost: %d MP" % total_cost
		if rotation_cost > 0:
			message += ", Rotation: %d MP" % rotation_cost
		message += ")"
		
		ui.show_confirmation_dialog(
			"Confirm Movement",
			message,
			_on_movement_confirmed,
			_on_movement_cancelled
		)
	
	# Actualizar overlays para mostrar el camino
	update_overlays()

func _on_movement_confirmed():
	"""Ejecutar el movimiento confirmado"""
	print("[BATTLE] Movement confirmed - pending: %s, dest: %s" % [pending_move_confirmation, preview_destination])
	
	if not pending_move_confirmation or preview_destination == Vector2i(-1, -1):
		print("[BATTLE] Movement confirmation failed - invalid state")
		return
	
	if not selected_unit:
		print("[BATTLE] Movement confirmation failed - no unit selected")
		return
	
	pending_move_confirmation = false
	
	# Ocultar botón de cancelar
	if ui:
		ui.hide_cancel_movement_button()
	
	# Ejecutar movimiento
	print("[BATTLE] Executing movement to %s" % preview_destination)
	_execute_movement(selected_unit, preview_destination, preview_path)
	
	# Limpiar previsualización y estado
	preview_path = []
	preview_destination = Vector2i(-1, -1)
	reachable_hexes = []  # Limpiar hexágonos alcanzables después del movimiento
	
	# Actualizar overlays
	print("[BATTLE] Updating overlays after movement")
	update_overlays()

func _on_movement_cancelled():
	"""Cancelar el movimiento"""
	print("[BATTLE] Movement cancelled")
	
	pending_move_confirmation = false
	preview_path = []
	preview_destination = Vector2i(-1, -1)
	
	# Restaurar overlays de movimiento si aún hay una unidad seleccionada
	print("[BATTLE] Restoring movement overlays - reachable hexes: %d" % reachable_hexes.size())
	update_overlays()
	
	if ui:
		ui.add_combat_message("Movement cancelled", Color.GRAY)

func _execute_movement(unit, hex: Vector2i, path: Array):
	"""Ejecuta el movimiento del mech"""
	# Calcular camino si no se proporciona
	if path.size() == 0:
		path = hex_grid.find_path(unit.hex_position, hex, unit.current_movement)
	
	if path.size() == 0:
		return
	
	# Calcular coste REAL de movimiento recorriendo el path
	var movement_cost = 0
	var rotation_cost = 0
	var current_facing = unit.facing
	
	for i in range(1, path.size()):
		var from_hex = path[i - 1]
		var to_hex = path[i]
		
		# Calcular facing necesario para este paso
		var step_facing = FacingSystem.get_facing_to_hex(from_hex, to_hex)
		
		# Calcular costo de rotación
		var step_rotation = MovementSystem.get_rotation_cost(current_facing, step_facing)
		rotation_cost += step_rotation
		
		# Calcular costo de terreno
		var step_cost = MovementSystem.calculate_movement_cost(from_hex, to_hex, unit.movement_type_used, hex_grid)
		movement_cost += step_cost
		
		current_facing = step_facing
	
	var total_cost = movement_cost + rotation_cost
	
	# Actualizar posición en el grid
	hex_grid.set_unit(unit.hex_position, null)
	var old_pos = unit.hex_position
	
	# Registrar movimiento en el mech (actualiza modificadores)
	unit.move_to_hex(hex, total_cost)
	hex_grid.set_unit(hex, unit)
	
	# Actualizar facing al final del movimiento
	unit.facing = current_facing
	
	# ACTUALIZAR POSICIÓN VISUAL DEL MECH
	unit.update_visual_position(hex_grid)
	
	# Actualizar visibilidad de todos los mechs tras movimiento
	update_mech_visibility()
	
	# Log de movimiento con tipo
	if ui:
		var movement_names = {
			GameEnums.MovementType.WALK: "Walking",
			GameEnums.MovementType.RUN: "Running",
			GameEnums.MovementType.JUMP: "Jumping"
		}
		var move_type_str = movement_names.get(unit.movement_type_used, "Moving")
		
		# Calcular distancia en hexágonos
		var hex_distance = path.size() - 1
		
		# Calcular cambio de elevación
		var old_elevation = hex_grid.get_elevation(old_pos)
		var new_elevation = hex_grid.get_elevation(hex)
		var elevation_change = new_elevation - old_elevation
		
		# Mensaje principal de movimiento
		ui.add_combat_message("%s %s from [%d,%d] to [%d,%d]" % [
			unit.mech_name, move_type_str, old_pos.x, old_pos.y, hex.x, hex.y
		], Color.WHITE)
		
		# Detalles del movimiento
		var details = "  → Moved %d hex%s, Cost: %d MP" % [
			hex_distance, 
			"es" if hex_distance != 1 else "",
			total_cost
		]
		
		if rotation_cost > 0:
			details += " (Terrain: %d MP, Rotation: %d MP)" % [movement_cost, rotation_cost]
		
		if elevation_change != 0:
			var elev_str = "+%d" % elevation_change if elevation_change > 0 else str(elevation_change)
			details += ", Elevation: %s" % elev_str
		
		ui.add_combat_message(details, Color.CYAN)
	
	# El estado se limpia en _on_movement_confirmed
	print("[BATTLE] Movement execution completed")
	
	# Después del movimiento, mostrar selector de facing para ajustar orientación final (sin costo)
	if ui and unit and unit in player_mechs:
		print("[BATTLE] Showing post-movement facing selector")
		var mech_screen_pos = hex_grid.hex_to_pixel(unit.hex_position, true) + hex_grid.global_position
		ui.add_combat_message("Adjust final facing (free rotation)", Color.YELLOW)
		
		# Guardar el hex actual para el callback de facing
		selected_hex = unit.hex_position
		selected_unit = unit  # Asegurar que selected_unit esté disponible
		
		# Mostrar selector
		ui.show_facing_selector_with_current(mech_screen_pos, unit.facing, 99)
	else:
		# Si no hay UI o no es mech del jugador, completar activación directamente
		print("[BATTLE] No facing selector needed, completing activation")
		if turn_manager:
			await get_tree().create_timer(0.3).timeout
			turn_manager.complete_unit_activation()


func _move_unit_to_hex(unit, hex: Vector2i):
	# Calcular camino
	var path = hex_grid.find_path(unit.hex_position, hex, unit.current_movement)
	
	if path.size() > 0:
		# Calcular coste REAL de movimiento recorriendo el path
		var movement_cost = 0
		for i in range(1, path.size()):  # Empezar desde 1 (el 0 es la posición actual)
			var from_hex = path[i - 1]
			var to_hex = path[i]
			var step_cost = MovementSystem.calculate_movement_cost(from_hex, to_hex, unit.movement_type_used, hex_grid)
			movement_cost += step_cost
		
		# Actualizar posición en el grid
		hex_grid.set_unit(unit.hex_position, null)
		var old_pos = unit.hex_position
		
		# Registrar movimiento en el mech (actualiza modificadores)
		unit.move_to_hex(hex, movement_cost)
		hex_grid.set_unit(hex, unit)
		
		# Actualizar facing automaticamente basado en la direccion del movimiento
		if old_pos != hex:
			var new_facing = FacingSystem.get_facing_to_hex(old_pos, hex)
			unit.facing = new_facing
		
		# ACTUALIZAR POSICIÓN VISUAL DEL MECH
		unit.update_visual_position(hex_grid)
		
		# Actualizar visibilidad de todos los mechs tras movimiento
		update_mech_visibility()
		
		# Log de movimiento con tipo
		if ui:
			var movement_names = ["", "Walking", "Running", "Jumping"]
			var move_type_str = movement_names[unit.movement_type_used]
			
			# Calcular distancia en hexágonos
			var hex_distance = path.size() - 1
			
			# Calcular cambio de elevación
			var old_elevation = hex_grid.get_elevation(old_pos)
			var new_elevation = hex_grid.get_elevation(hex)
			var elevation_change = new_elevation - old_elevation
			
			# Mensaje principal de movimiento
			ui.add_combat_message("%s %s from [%d,%d] to [%d,%d]" % [
				unit.mech_name, move_type_str, old_pos.x, old_pos.y, hex.x, hex.y
			], Color.WHITE)
			
			# Detalles del movimiento
			var details = "  → Moved %d hex%s, Cost: %d MP" % [
				hex_distance, 
				"es" if hex_distance != 1 else "",
				movement_cost
			]
			if elevation_change != 0:
				var elev_sign = "+" if elevation_change > 0 else ""
				details += " (Elev: %s%d)" % [elev_sign, elevation_change]
			ui.add_combat_message(details, Color.CYAN)
			
			ui.add_combat_message("  → MPs remaining: %d, TMM: +%d" % [unit.current_movement, unit.target_movement_modifier], Color.CYAN)
			
			# Registrar calor del movimiento (no aplicar aún, se procesará en fase de calor)
			var movement_heat = unit.finalize_movement()
			if movement_heat > 0:
				ui.add_combat_message("  → Movement heat generated: +%d" % movement_heat, Color.ORANGE)
			
			ui.update_unit_info(unit)
		
		# Para jugadores: mostrar selector de facing si hay MPs restantes
		if unit in player_mechs:
			reachable_hexes.clear()
			
			# Verificar si tiene al menos 1 MP para rotar (incluso si current_movement quedó en 0)
			# El selector mostrará correctamente cuántos MPs tiene disponibles
			# IMPORTANTE: Solo mostrar si el selector NO está ya visible (evita doble-apertura)
			if ui and ui.has_method("show_facing_selector_with_current") and not ui.is_facing_selector_visible():
				# Mostrar selector de facing
				selected_hex = hex  # Guardar posición actual
				var hex_pixel = hex_grid.hex_to_pixel(hex, true) + hex_grid.global_position
				var screen_pos = hex_pixel
				if camera:
					screen_pos = hex_pixel - camera.position + get_viewport().get_visible_rect().size / 2
				
				# Siempre mostrar el selector, que internamente manejará si hay MPs o no
				ui.show_facing_selector_with_current(screen_pos, unit.facing, unit.current_movement)
			else:
				# Fallback si no hay método mejorado
				if unit.current_movement > 0:
					if ui:
						ui.add_combat_message("Select final facing (costs 1 MP per rotation)", Color.YELLOW)
					
					selected_hex = hex
					var hex_pixel = hex_grid.hex_to_pixel(hex, true) + hex_grid.global_position
					var screen_pos = hex_pixel
					if camera:
						screen_pos = hex_pixel - camera.position + get_viewport().get_visible_rect().size / 2
					
					if ui and ui.has_method("show_facing_selector"):
						ui.show_facing_selector(screen_pos)
				else:
					# No hay MPs, finalizar
					if ui:
						ui.add_combat_message("No MPs remaining. Movement complete.", Color.YELLOW)
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
	# print("[DEBUG] _handle_weapon_attack_click called: hex=%s" % hex)
	# Manejar selección de objetivo para ataque con armas
	if selected_unit == null or selected_unit not in player_mechs:
		# print("[DEBUG] No selected_unit or not player mech")
		return
	
	var target = hex_grid.get_unit(hex)
	# print("[DEBUG] Target at hex: %s, is_enemy=%s" % [target.mech_name if target else "null", target in enemy_mechs if target else false])
	
	# Verificar que hay un enemigo en el hex
	if target != null and target in enemy_mechs:
		var range_hexes = hex_grid.hex_distance(selected_unit.hex_position, target.hex_position)
		current_attack_target = target
		
		# print("[DEBUG] Showing weapon selector for target %s at range %d" % [target.mech_name, range_hexes])
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
	# print("[DEBUG] _on_phase_changed: %s" % phase)
	
	# Limpiar hexágonos de objetivos al cambiar de fase
	physical_target_hexes.clear()
	target_hexes.clear()
	reachable_hexes.clear()
	update_overlays()
	
	# IMPORTANTE: phase_to_string() retorna "Movement", "Weapon Attack", "Physical Attack"
	match phase:
		"Movement":
			current_state = GameEnums.GameState.MOVING
			# print("[DEBUG] Set current_state to MOVING (%d)" % current_state)
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
	
	# Centrar cámara en el mech activo
	if camera and unit:
		var target_pos = unit.global_position
		var tween = create_tween()
		tween.tween_property(camera, "position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Mostrar overlay de mech activo si es del jugador
	if unit in player_mechs:
		_show_active_mech_indicator(unit)
	
	# print("[DEBUG] _on_unit_activated: %s, current_state=%d, is_player=%s" % [
	# 	unit.mech_name, 
	# 	current_state,
	# 	unit in player_mechs
	# ])
	if typeof(unit.weapons) == TYPE_ARRAY:
		pass
		# print("[DEBUG]   Weapons count: %d" % unit.weapons.size())
		# for i in range(unit.weapons.size()):
		# 	print("[DEBUG]     Weapon %d: %s" % [i, unit.weapons[i].get("name", "Unknown")])
	# print("[DEBUG] selected_unit id: %s, unit id: %s" % [str(selected_unit), str(unit)])
	
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
			
			# Verificar si hay enemigos adyacentes
			if not has_adjacent_enemies(unit):
				# No hay enemigos adyacentes - saltar automáticamente
				if ui:
					ui.add_combat_message("%s: No adjacent enemies - skipping physical attack" % unit.mech_name, Color.GRAY)
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
			
			# Verificar si hay enemigos en LoS
			if not has_enemies_in_los(unit):
				# No hay enemigos en LoS - saltar automáticamente
				if ui:
					ui.add_combat_message("%s: No enemies in line of sight - skipping weapon attack" % unit.mech_name, Color.GRAY)
				turn_manager.complete_unit_activation()
				return
			
			# Mostrar enemigos visibles y con LoS como objetivos potenciales
			for enemy in enemy_mechs:
				if not enemy.is_destroyed and enemy.is_visible_to_player:
					# Verificar Line of Sight desde la unidad actual
					var has_los = LineOfSight.can_shoot(hex_grid, unit.hex_position, enemy.hex_position)
					if has_los:
						target_hexes.append(enemy.hex_position)
			if ui:
				var los_count = target_hexes.size()
				var total_enemies = enemy_mechs.filter(func(e): return not e.is_destroyed).size()
				var message = "Your turn: Select target for %s to fire weapons" % unit.mech_name
				if los_count < total_enemies:
					message += " (%d/%d in LoS)" % [los_count, total_enemies]
				ui.add_combat_message(message, Color.ORANGE)
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
	
	# Actualizar visibilidad después de cada acción
	update_mech_visibility()
	update_overlays()

func _ai_turn(unit):
	# Usar el sistema de IA mejorado
	if battle_ai and turn_manager:
		await battle_ai.execute_ai_turn(unit, turn_manager.current_phase)
	else:
		# Fallback si no hay IA configurada
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
	
	# Determinar tipo de ataque
	match attack_type:
		"punch_left":
			attack_type_enum = PhysicalAttackSystem.AttackType.PUNCH
			attack_name = "Punch (Left Arm)"
		"punch_right":
			attack_type_enum = PhysicalAttackSystem.AttackType.PUNCH
			attack_name = "Punch (Right Arm)"
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
			# Explosión de munición - verificar si hay CASE para mitigar daño
			if ui:
				ui.add_combat_message("  ☠☠☠ AMMO EXPLOSION! (Rolled %d vs %d)" % [ammo_check["roll"], ammo_check["target"]], Color.RED)
			
			# Determinar localización de la explosión (normalmente torsos donde hay munición)
			var explosion_location = _find_ammo_explosion_location(mech)
			var has_case = ComponentDatabase.has_case_in_location(mech, explosion_location)
			
			if has_case:
				# CASE ventila la explosión - daño reducido solo a esa localización
				if ui:
					ui.add_combat_message("    ✓ CASE activated! Explosion vented safely.", Color.YELLOW)
				var _damage_result = mech.take_damage(explosion_location, 10)  # Daño reducido
				# Destruir la munición en esa localización
				_destroy_ammo_in_location(mech, explosion_location)
			else:
				# Sin CASE - explosión catastrófica al torso central
				if ui:
					ui.add_combat_message("    ⚠ NO CASE! Catastrophic explosion!", Color.ORANGE)
				var damage_result = mech.take_damage("center_torso", 20)  # Daño completo
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

func notify_ui_interaction():
	"""Llamar esta función desde la UI cuando se hace click en un botón para evitar clics fantasma en el mapa"""
	ui_interaction_cooldown = 0.2  # 200ms de cooldown

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

func _find_ammo_explosion_location(mech) -> String:
	# Encuentra dónde está la munición explosiva (prioridad: torsos > brazos)
	# Retorna la localización con munición, o "center_torso" por defecto
	
	var locations_priority = ["left_torso", "right_torso", "center_torso", "left_arm", "right_arm"]
	
	for location in locations_priority:
		var ammo = ComponentDatabase.get_explosive_ammo_in_location(mech, location)
		if ammo.size() > 0:
			return location
	
	# Fallback si no se encuentra munición
	return "center_torso"

func _destroy_ammo_in_location(mech, location: String):
	# Destruye toda la munición en una localización específica
	if not "weapons" in mech:
		return
	
	for weapon in mech.weapons:
		if weapon.get("explosive", false):
			var weapon_location = weapon.get("location", "")
			if weapon_location == location:
				weapon["destroyed"] = true
				if ui:
					ui.add_combat_message("      → %s destroyed" % weapon.get("name", "Ammo"), Color.GRAY)

func _create_long_press_indicator():
	# Crear un nodo 2D para el indicador visual del long press
	long_press_indicator = Node2D.new()
	long_press_indicator.name = "LongPressIndicator"
	long_press_indicator.visible = false
	long_press_indicator.z_index = 1000  # Muy arriba para que se vea sobre todo
	long_press_indicator.draw.connect(_draw_long_press_indicator)
	add_child(long_press_indicator)

func _draw_long_press_indicator():
	if not long_press_indicator or not long_press_active:
		return
	
	# Calcular progreso (0.0 a 1.0)
	var progress = min(long_press_timer / LONG_PRESS_DURATION, 1.0)
	
	# Radio del círculo
	var radius = 30.0
	
	# Dibujar círculo de fondo (semi-transparente)
	long_press_indicator.draw_circle(Vector2.ZERO, radius, Color(0.2, 0.2, 0.2, 0.5))
	
	# Dibujar borde del círculo
	long_press_indicator.draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.WHITE, 2.0)
	
	# Dibujar progreso (arco que se llena)
	if progress > 0:
		var end_angle = -PI/2 + (TAU * progress)  # Empezar arriba y girar en sentido horario
		long_press_indicator.draw_arc(Vector2.ZERO, radius - 5, -PI/2, end_angle, 32, Color.CYAN, 6.0)
	
	# Dibujar icono de inspección en el centro (opcional)
	if progress > 0.8:  # Mostrar el icono cuando está casi completo
		# Nota: Para un texto centrado necesitarías usar draw_string con una fuente
		# Por simplicidad, solo dibujamos un punto central
		long_press_indicator.draw_circle(Vector2.ZERO, 5.0, Color.CYAN)

func _show_active_mech_indicator(unit):
	"""Muestra un indicador visual sobre el mech activo"""
	# Limpiar indicador anterior si existe
	_hide_active_mech_indicator()
	
	# Crear contenedor para el indicador
	active_mech_indicator = Control.new()
	active_mech_indicator.name = "ActiveMechIndicator"
	active_mech_indicator.z_index = 150
	
	# Añadir al árbol principal (no como hijo del mech para que siga la cámara)
	add_child(active_mech_indicator)
	
	# Panel de fondo
	var panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.3, 0.6, 0.9)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color.CYAN
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	active_mech_indicator.add_child(panel)
	
	# Label con el nombre del mech
	var label = Label.new()
	label.text = "► %s ACTIVE ◄" % unit.mech_name
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	
	# Posicionar en la parte superior central de la pantalla
	var viewport_size = get_viewport().get_visible_rect().size
	var indicator_width = 300
	var indicator_height = 50
	
	active_mech_indicator.position = Vector2(
		(viewport_size.x - indicator_width) / 2,
		20
	)
	active_mech_indicator.size = Vector2(indicator_width, indicator_height)
	panel.position = Vector2.ZERO
	panel.size = Vector2(indicator_width, indicator_height)
	label.position = Vector2.ZERO
	label.size = Vector2(indicator_width, indicator_height)
	
	# Animación de entrada (slide down)
	active_mech_indicator.modulate = Color(1, 1, 1, 0)
	active_mech_indicator.position.y = -indicator_height
	
	active_mech_indicator_tween = create_tween()
	active_mech_indicator_tween.set_parallel(true)
	active_mech_indicator_tween.tween_property(active_mech_indicator, "position:y", 20, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_mech_indicator_tween.tween_property(active_mech_indicator, "modulate:a", 1.0, 0.3)
	
	# Auto-ocultar después de 3 segundos
	await get_tree().create_timer(3.0).timeout
	_hide_active_mech_indicator()

func _hide_active_mech_indicator():
	"""Oculta el indicador de mech activo"""
	if active_mech_indicator_tween:
		active_mech_indicator_tween.kill()
		active_mech_indicator_tween = null
	
	if active_mech_indicator and is_instance_valid(active_mech_indicator):
		# Animación de salida
		var exit_tween = create_tween()
		exit_tween.set_parallel(true)
		exit_tween.tween_property(active_mech_indicator, "position:y", -100, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		exit_tween.tween_property(active_mech_indicator, "modulate:a", 0.0, 0.3)
		
		await exit_tween.finished
		
		# Verificar nuevamente antes de liberar
		if active_mech_indicator and is_instance_valid(active_mech_indicator):
			active_mech_indicator.queue_free()
		active_mech_indicator = null
