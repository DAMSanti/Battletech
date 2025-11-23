# Ejemplo de Integración del Sistema de Movimiento BattleTech

## Este archivo muestra cómo usar el nuevo sistema de movimiento en battle_scene.gd

extends Node2D

# Referencias
@onready var hex_grid = $HexGrid
var selected_mech = null
var current_movement_type = GameEnums.MovementType.WALK

## ========================================
## FASE 1: SELECCIONAR MECH Y CALCULAR MPs
## ========================================

func on_mech_selected(mech):
	selected_mech = mech
	
	# Calcular MPs disponibles según tipo de movimiento
	var walk_mp = MovementSystem.calculate_walk_distance(mech)
	var run_mp = MovementSystem.calculate_run_distance(mech)
	var jump_mp = MovementSystem.calculate_jump_distance(mech)
	
	print("Mech seleccionado: %s" % mech.name)
	print("Walk MP: %d, Run MP: %d, Jump MP: %d" % [walk_mp, run_mp, jump_mp])
	
	# Mostrar UI de selección de movimiento
	show_movement_type_selector(walk_mp, run_mp, jump_mp)

## ========================================
## FASE 2: ELEGIR TIPO DE MOVIMIENTO
## ========================================

func on_movement_type_selected(movement_type: GameEnums.MovementType):
	current_movement_type = movement_type
	
	# Calcular hexes alcanzables
	var reachable_hexes = []
	var mech_hex = selected_mech.current_hex
	
	match movement_type:
		GameEnums.MovementType.WALK:
			var walk_mp = MovementSystem.calculate_walk_distance(selected_mech)
			reachable_hexes = MovementSystem.get_reachable_hexes(
				mech_hex, walk_mp, GameEnums.MovementType.WALK, hex_grid, selected_mech
			)
		
		GameEnums.MovementType.RUN:
			var run_mp = MovementSystem.calculate_run_distance(selected_mech)
			reachable_hexes = MovementSystem.get_reachable_hexes(
				mech_hex, run_mp, GameEnums.MovementType.RUN, hex_grid, selected_mech
			)
		
		GameEnums.MovementType.JUMP:
			var jump_mp = MovementSystem.calculate_jump_distance(selected_mech)
			reachable_hexes = MovementSystem.get_jump_hexes(
				mech_hex, jump_mp, hex_grid, selected_mech
			)
	
	# Visualizar hexes alcanzables
	highlight_reachable_hexes(reachable_hexes)
	
	print("%s: %d hexes alcanzables" % [
		GameEnums.movement_type_to_string(movement_type),
		reachable_hexes.size()
	])

## ========================================
## FASE 3: VISUALIZAR HEXES ALCANZABLES
## ========================================

func highlight_reachable_hexes(hexes: Array):
	# Limpiar highlights previos
	clear_hex_highlights()
	
	# Colorear hexes según coste de movimiento
	for hex in hexes:
		var cost = MovementSystem.calculate_movement_cost(
			selected_mech.current_hex, hex, current_movement_type, hex_grid
		)
		
		# Color según coste (verde = barato, amarillo = medio, rojo = caro)
		var color = Color.GREEN
		if cost > 3:
			color = Color.YELLOW
		if cost > 5:
			color = Color.RED
		
		# Verificar restricciones
		var accessible = MovementRestrictions.is_hex_accessible(
			hex, selected_mech, hex_grid, current_movement_type
		)
		
		if not accessible:
			color = Color.GRAY  # No accesible
		
		# Aplicar highlight
		hex_grid.highlight_hex(hex, color)

## ========================================
## FASE 4: MOVER MECH A DESTINO
## ========================================

func on_hex_clicked(target_hex: Vector2i):
	if selected_mech == null:
		return
	
	# Verificar si el hex es alcanzable
	var accessible = MovementRestrictions.is_hex_accessible(
		target_hex, selected_mech, hex_grid, current_movement_type
	)
	
	if not accessible:
		print("Hex no accesible")
		return
	
	# Calcular coste de movimiento
	var cost = MovementSystem.calculate_movement_cost(
		selected_mech.current_hex, target_hex, current_movement_type, hex_grid
	)
	
	# Verificar MPs suficientes
	var max_mp = 0
	match current_movement_type:
		GameEnums.MovementType.WALK:
			max_mp = MovementSystem.calculate_walk_distance(selected_mech)
		GameEnums.MovementType.RUN:
			max_mp = MovementSystem.calculate_run_distance(selected_mech)
		GameEnums.MovementType.JUMP:
			max_mp = MovementSystem.calculate_jump_distance(selected_mech)
	
	if cost > max_mp:
		print("MPs insuficientes: necesitas %d, tienes %d" % [cost, max_mp])
		return
	
	# Verificar si requiere piloting check
	var piloting_info = MovementRestrictions.requires_piloting_check(
		selected_mech.current_hex, target_hex, hex_grid, current_movement_type
	)
	
	if piloting_info.required:
		print("¡Piloting check requerido! Razón: %s (dificultad %d)" % [
			piloting_info.reason, piloting_info.difficulty
		])
		# Aquí ejecutarías el piloting check
		# Si falla, el mech cae
	
	# Mover el mech
	move_mech_to_hex(selected_mech, target_hex)
	
	# Calcular calor generado
	var hexes_moved = hex_grid.hex_distance(selected_mech.current_hex, target_hex)
	var heat = MovementSystem.calculate_heat_from_movement(
		selected_mech, hexes_moved, current_movement_type
	)
	
	selected_mech.add_heat(heat)
	print("Calor generado: %d" % heat)
	
	# Actualizar facing (opcional)
	var new_facing = FacingSystem.get_facing_to_hex(selected_mech.current_hex, target_hex)
	selected_mech.facing = new_facing
	
	# Obtener modificadores de combate
	var atk_mod = MovementSystem.get_attacker_movement_modifier(current_movement_type)
	var def_mod = MovementSystem.get_target_movement_modifier(current_movement_type, hexes_moved)
	
	print("Modificadores: Ataque +%d, Defensa +%d" % [atk_mod, def_mod])

## ========================================
## FASE 5: ACTUALIZAR FACING (ORIENTACIÓN)
## ========================================

func update_mech_facing(mech, new_facing: int):
	var old_facing = mech.facing
	
	# Calcular coste de giro (0 en BattleTech clásico)
	var rotation_cost = FacingSystem.get_rotation_cost(old_facing, new_facing, true)
	
	if rotation_cost > 0:
		print("Girar cuesta %d MP" % rotation_cost)
	
	# Actualizar facing
	mech.facing = new_facing
	
	# Actualizar sprite rotation
	var angle = FacingSystem.get_angle_for_facing(new_facing)
	mech.rotation_degrees = angle
	
	print("Facing: %s (%d°)" % [
		FacingSystem.get_facing_name(new_facing),
		angle
	])

## ========================================
## FASE 6: CALCULAR LÍNEA DE DISPARO
## ========================================

func check_firing_arc(shooter, target):
	var shooter_hex = shooter.current_hex
	var target_hex = target.current_hex
	
	# Determinar en qué arco está el objetivo
	var arc = FacingSystem.get_arc(shooter.facing, target_hex, shooter_hex)
	
	print("Objetivo en arco: %s" % arc)
	
	# Aplicar modificadores según arco
	match arc:
		"front":
			print("Disparo frontal - sin modificadores adicionales")
		"right", "left":
			print("Disparo lateral - +1 to-hit")
		"rear":
			print("Disparo trasero - +2 to-hit (o imposible si no hay armas)")

## ========================================
## FUNCIONES DE EJEMPLO: SITUACIONES ESPECIALES
## ========================================

# Ejemplo: Verificar terrenos específicos
func check_terrain_effects(hex: Vector2i):
	var terrain = hex_grid.get_terrain(hex)
	
	# Costes por tipo de movimiento
	var walk_cost = TerrainType.get_movement_cost_by_type(terrain, GameEnums.MovementType.WALK)
	var run_cost = TerrainType.get_movement_cost_by_type(terrain, GameEnums.MovementType.RUN)
	var jump_cost = TerrainType.get_movement_cost_by_type(terrain, GameEnums.MovementType.JUMP)
	
	print("Terreno: %s" % TerrainType.get_name(terrain))
	print("  Walk: %d MP, Run: %d MP, Jump: %d MP" % [walk_cost, run_cost, jump_cost])
	
	# Verificar restricciones
	if TerrainType.prohibits_running(terrain):
		print("  ⚠️ Prohíbe correr")
	
	if TerrainType.requires_piloting_check(terrain):
		print("  ⚠️ Requiere piloting check")
	
	# Modificadores de combate
	var defense = TerrainType.get_defense_bonus(terrain)
	var to_hit = TerrainType.get_to_hit_modifier(terrain)
	
	print("  Defensa: +%d, To-Hit: +%d" % [defense, to_hit])

# Ejemplo: Calcular ruta óptima
func calculate_best_path(from_hex: Vector2i, to_hex: Vector2i):
	# Usar el pathfinding del hex_grid con costes de terreno
	var path = hex_grid.find_path(from_hex, to_hex)
	
	if path.is_empty():
		print("No hay ruta válida")
		return
	
	# Calcular coste total
	var total_cost = 0
	for i in range(1, path.size()):
		var cost = MovementSystem.calculate_movement_cost(
			path[i-1], path[i], current_movement_type, hex_grid
		)
		total_cost += cost
	
	print("Ruta encontrada: %d hexes, coste total: %d MP" % [path.size() - 1, total_cost])
	
	return path

# Ejemplo: Sistema de torso twist
func apply_torso_twist(mech, direction: int):
	var leg_facing = mech.leg_facing  # Asumiendo que el mech tiene leg_facing separado
	var new_torso = FacingSystem.apply_torso_twist(leg_facing, direction)
	
	if FacingSystem.can_torso_twist(new_torso, leg_facing):
		mech.torso_facing = new_torso
		print("Torso girado a: %s" % FacingSystem.get_facing_name(new_torso))
	else:
		print("No se puede girar el torso más")

## ========================================
## HELPERS
## ========================================

func clear_hex_highlights():
	# Limpiar highlights de hexes
	pass

func show_movement_type_selector(walk: int, run: int, jump: int):
	# Mostrar UI para elegir Walk/Run/Jump
	pass

func move_mech_to_hex(mech, hex: Vector2i):
	# Animar movimiento del mech al hex
	mech.current_hex = hex
	mech.position = hex_grid.hex_to_pixel(hex, true)
