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

var player_mechs: Array = []
var enemy_mechs: Array = []

var selected_unit = null
var selected_hex: Vector2i = Vector2i(-1, -1)

var reachable_hexes: Array = []
var target_hexes: Array = []
var physical_target_hexes: Array = []  # Enemigos adyacentes para ataque físico

# Sistema de movimiento
var pending_movement_selection: bool = false  # Esperando que el jugador elija Walk/Run/Jump
var ignore_next_click: bool = false  # Ignorar el próximo click (usado después de cerrar UI)
var ui_interaction_cooldown: float = 0.0  # Tiempo de cooldown después de interacción con UI

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
		# Movement overlays (cyan)
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
	turn_manager.initiative_rolled.connect(_on_initiative_rolled)
	
	# Iniciar la batalla con fase de despliegue
	_setup_battle()

func _process(delta):
	# Decrementar cooldown de interacción con UI
	if ui_interaction_cooldown > 0:
		ui_interaction_cooldown -= delta
	
	# Procesar timer de tap largo
	if long_press_active:
		long_press_timer += delta
		
		# Actualizar indicador visual
		if long_press_indicator:
			long_press_indicator.visible = true
			long_press_indicator.global_position = long_press_start_pos
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
	
	# Si es la primera vez, iniciar la batalla
	if not battle_started:
		# Iniciar el sistema de turnos
		turn_manager.start_battle(player_mechs, enemy_mechs)
		
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
	
	# Primero verificar si hay un loadout seleccionado desde el Mech Bay
	var loadout_manager = get_node_or_null("/root/SelectedLoadoutManager")
	var mech_bay_manager = get_node_or_null("/root/MechBayManager")
	var player_mech_data: Dictionary = {}
	
	if loadout_manager and loadout_manager.has_loadout():
		var loadout = loadout_manager.get_selected_loadout()
		player_mech_data = _convert_loadout_to_mech_data(loadout)
	else:
		# Fallback: usar MechBayManager si no hay loadout seleccionado
		if mech_bay_manager:
			print("[DEBUG] selected_mech_index:", mech_bay_manager.selected_mech_index)
			player_mech_data = mech_bay_manager.get_first_player_mech()
			print("[DEBUG] get_first_player_mech() returned: ", player_mech_data.get("name", "Unknown"))
		else:
			# Fallback si no existe el manager
			print("[WARNING] MechBayManager not found, using default Atlas")
			player_mech_data = {
				"name": "Atlas",
				"tonnage": 100,
				"walk_mp": 3,
				"run_mp": 5,
				"jump_mp": 0
			}
	
	# Crear mechs pero NO colocarlos todavía - guardarlos para despliegue
	var player_mech = _create_mech_for_deployment(player_mech_data, "player")
	mechs_to_deploy.append(player_mech)
	
	# Equipo enemigo
	var enemy_mech_data: Dictionary
	if mech_bay_manager:
		enemy_mech_data = mech_bay_manager.get_mech_data("Mad Cat", "Timber Wolf Prime")
		if not enemy_mech_data:
			enemy_mech_data = {
				"name": "Mad Cat",
				"tonnage": 75,
				"walk_mp": 4,
				"run_mp": 6,
				"jump_mp": 0
			}
	else:
		enemy_mech_data = {
			"name": "Mad Cat",
			"tonnage": 75,
			"walk_mp": 4,
			"run_mp": 6,
			"jump_mp": 0
		}
	
	var enemy_mech = _create_mech_for_deployment(enemy_mech_data, "enemy")
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
	
	if ui:
		ui.add_combat_message("=== DEPLOYMENT PHASE ===", Color.GOLD)
		ui.add_combat_message("Place your mechs in the deployment zone", Color.CYAN)
	
	# Comenzar con el primer mech del jugador
	_deploy_next_mech()

func _deploy_next_mech():
	"""Selecciona el siguiente mech para desplegar"""
	
	if mechs_to_deploy.is_empty():
		_end_deployment_phase()
		return
	
	current_deploying_mech = mechs_to_deploy.pop_front()
	var team = current_deploying_mech.get_meta("team")
	
	
	if team == "player":
		# Jugador despliega manualmente
		valid_deployment_hexes = deployment_zones["player"].duplicate()
		if ui:
			ui.add_combat_message("Deploy %s - Click on a hex in the deployment zone" % current_deploying_mech.mech_name, Color.CYAN)
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
	
	# Añadir a la lista correcta
	if team == "player":
		player_mechs.append(mech)
	else:
		enemy_mechs.append(mech)

func _end_deployment_phase():
	"""Finaliza la fase de despliegue e inicia la batalla"""
	deployment_phase = false
	valid_deployment_hexes.clear()
	current_deploying_mech = null
	
	
	if ui:
		ui.add_combat_message("=== DEPLOYMENT COMPLETE ===", Color.GOLD)
	
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
			
			# Calcular el hexágono donde empezó el long press
			var world_pos = camera.get_global_mouse_position()
			long_press_start_hex = hex_grid.pixel_to_hex(world_pos - hex_grid.global_position)
	
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
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not long_press_active:  # Solo si no está en proceso de tap largo
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
	
	# Manejar fase de despliegue
	if deployment_phase:
		_handle_deployment_click(hex)
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
	
	if ui and ui.has_method("show_facing_selector"):
		ui.show_facing_selector(screen_pos)

func on_facing_selected(facing: int):
	"""Llamado cuando el jugador selecciona una orientación"""
	
	if deployment_phase and current_deploying_mech and selected_hex != Vector2i(-1, -1):
		# Estamos en fase de despliegue
		_place_mech(current_deploying_mech, selected_hex, facing)
		selected_hex = Vector2i(-1, -1)  # Reset
		
		# Siguiente mech
		_deploy_next_mech()
	elif selected_unit and selected_unit in player_mechs and selected_hex != Vector2i(-1, -1):
		# Estamos después del movimiento - calcular rotación necesaria
		var current_facing = selected_unit.facing
		var rotations_needed = _calculate_rotations(current_facing, facing)
		
		
		if rotations_needed <= selected_unit.current_movement:
			# Aplicar rotación
			selected_unit.facing = facing
			selected_unit.current_movement -= rotations_needed
			selected_unit.update_visual_position(hex_grid)
			selected_unit.update_facing_visual()  # Forzar actualización visual
			
			if ui:
				ui.add_combat_message("  → Rotated to facing %d (-%d MP)" % [facing, rotations_needed], Color.CYAN)
				ui.add_combat_message("  → Final facing: %d, MPs remaining: %d" % [facing, selected_unit.current_movement], Color.WHITE)
				ui.update_unit_info(selected_unit)
			
			# Modo secuencial: finalizar
			await get_tree().create_timer(0.3).timeout
			turn_manager.complete_unit_activation()
		else:
			if ui:
				ui.add_combat_message("Not enough MPs for that rotation!", Color.RED)
		
		selected_hex = Vector2i(-1, -1)  # Reset

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
			ui.add_combat_message("  → MPs remaining: %d" % unit.current_movement, Color.CYAN)
			
			# Registrar calor del movimiento (no aplicar aún, se procesará en fase de calor)
			var movement_heat = unit.finalize_movement()
			if movement_heat > 0:
				ui.add_combat_message("  → Movement heat generated: +%d" % movement_heat, Color.ORANGE)
			
			ui.update_unit_info(unit)
		
		# Para jugadores: mostrar selector de facing si hay MPs restantes
		if unit in player_mechs:
			reachable_hexes.clear()
			
			if unit.current_movement > 0:
				# Hay MPs restantes, permitir rotación
				if ui:
					ui.add_combat_message("Select final facing (costs 1 MP per rotation)", Color.YELLOW)
				
				# Mostrar selector de facing
				selected_hex = hex  # Guardar posición actual
				var hex_pixel = hex_grid.hex_to_pixel(hex, true) + hex_grid.global_position
				var screen_pos = hex_pixel
				if camera:
					screen_pos = hex_pixel - camera.position + get_viewport().get_visible_rect().size / 2
				
				if ui and ui.has_method("show_facing_selector_with_current"):
					ui.show_facing_selector_with_current(screen_pos, unit.facing, unit.current_movement)
				elif ui and ui.has_method("show_facing_selector"):
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
