extends Node
class_name BattleAI

## Sistema de IA mejorado para unidades enemigas
## Maneja la lógica de decisiones de los mechs enemigos con evaluación táctica

const WeaponAttackSystem = preload("res://scripts/core/combat/weapon_attack_system.gd")
const PhysicalAttackSystem = preload("res://scripts/core/combat/physical_attack_system.gd")

var hex_grid: HexGrid
var player_mechs: Array = []
var battle_scene: Node = null

# Constantes para evaluación táctica
const THREAT_WEIGHT_DAMAGE = 1.5     # Peso del daño potencial en evaluación
const THREAT_WEIGHT_DISTANCE = 1.0   # Peso de la distancia
const SURVIVAL_THRESHOLD = 0.3       # 30% salud = modo defensivo
const HEAT_DANGER_THRESHOLD = 20     # Evitar shutdown
const OPTIMAL_RANGE_BONUS = 100.0    # Bonus por estar en rango óptimo

func setup(grid: HexGrid, players: Array, scene: Node):
	hex_grid = grid
	player_mechs = players
	battle_scene = scene

## Ejecuta la IA para una unidad según la fase actual
func execute_ai_turn(unit, phase: int):
	match phase:
		GameEnums.TurnPhase.MOVEMENT:
			await _ai_movement(unit)
		GameEnums.TurnPhase.WEAPON_ATTACK:
			await _ai_weapon_attack(unit)
		GameEnums.TurnPhase.PHYSICAL_ATTACK:
			await _ai_physical_attack(unit)

## IA para fase de movimiento
func _ai_movement(unit):
	var closest_player = _find_closest_player(unit)
	if not closest_player:
		_complete_activation()
		return
	
	# Evaluar estado del mech
	var health_percent = _calculate_health_percent(unit)
	var is_critical = health_percent < SURVIVAL_THRESHOLD
	
	# Encontrar el mejor objetivo (podría no ser el más cercano)
	var best_target = _select_best_target(unit)
	if not best_target:
		best_target = closest_player
	
	var distance = hex_grid.hex_distance(unit.hex_position, best_target.hex_position)
	
	# Determinar rango óptimo de armas
	var optimal_range = _calculate_optimal_weapon_range(unit)
	
	# Elegir tipo de movimiento basado en situación táctica
	var movement_type = _decide_movement_type(unit, best_target, distance, optimal_range, is_critical)
	
	unit.start_movement(movement_type)
	
	# Obtener hexágonos alcanzables
	var reachable = hex_grid.get_reachable_hexes(unit.hex_position, unit.current_movement)
	
	# Encontrar mejor hexágono considerando múltiples factores
	var best_hex = _find_tactical_movement_hex(unit, best_target, reachable, optimal_range, is_critical)
	
	if best_hex != unit.hex_position:
		await get_tree().create_timer(GameConstants.AI_THINK_DELAY).timeout
		if battle_scene and battle_scene.has_method("_move_unit_to_hex"):
			battle_scene._move_unit_to_hex(unit, best_hex)
	else:
		_complete_activation()

## IA para fase de ataque con armas
func _ai_weapon_attack(unit):
	# Seleccionar mejor objetivo visible (ya verifica LoS internamente)
	var best_target = _select_best_target(unit)
	if not best_target:
		print("[AI] No valid targets with line of sight for %s" % unit.mech_name)
		_complete_activation()
		return
	
	# Doble verificación de LoS por seguridad
	if not _has_line_of_sight(unit, best_target):
		print("[AI] Lost line of sight to target %s, aborting attack" % best_target.mech_name)
		_complete_activation()
		return
	
	print("[AI] %s attacking %s (LoS confirmed)" % [unit.mech_name, best_target.mech_name])
	
	var distance = hex_grid.hex_distance(unit.hex_position, best_target.hex_position)
	
	await get_tree().create_timer(GameConstants.AI_THINK_DELAY).timeout
	
	# Seleccionar armas inteligentemente basado en calor y efectividad
	var weapon_selection = _select_weapons_intelligently(unit, best_target, distance)
	
	if weapon_selection["weapons"].size() > 0 and battle_scene and battle_scene.has_method("execute_weapon_attack"):
		battle_scene.execute_weapon_attack(unit, best_target, weapon_selection["weapons"], distance)
	else:
		_complete_activation()

## IA para fase de ataque físico
func _ai_physical_attack(unit):
	var closest_player = _find_closest_adjacent_player(unit)
	
	if closest_player:
		# Verificar LoS aunque sea adyacente (por seguridad)
		if not _has_line_of_sight(unit, closest_player):
			print("[AI] No LoS to adjacent target %s for physical attack" % closest_player.mech_name)
			_complete_activation()
			return
		
		await get_tree().create_timer(GameConstants.AI_THINK_DELAY).timeout
		# La IA elige puñetazo derecho como ataque por defecto
		if battle_scene and battle_scene.has_method("execute_physical_attack"):
			battle_scene.execute_physical_attack(unit, closest_player, "punch_right")
	else:
		_complete_activation()


## Encuentra el jugador más cercano (que se pueda ver)
func _find_closest_player(unit) -> Variant:
	var closest = null
	var min_distance = INF
	
	for player in player_mechs:
		if not player.is_destroyed:
			# Verificar línea de visión
			if not _has_line_of_sight(unit, player):
				continue
			
			var dist = hex_grid.hex_distance(unit.hex_position, player.hex_position)
			if dist < min_distance:
				min_distance = dist
				closest = player
	
	return closest

## Encuentra el jugador adyacente más cercano
func _find_closest_adjacent_player(unit) -> Variant:
	var closest = null
	var min_distance = INF
	
	for player in player_mechs:
		if not player.is_destroyed:
			var dist = hex_grid.hex_distance(unit.hex_position, player.hex_position)
			if dist <= 1 and dist < min_distance:
				min_distance = dist
				closest = player
	
	return closest

## Encuentra el mejor hexágono para moverse
func _find_best_movement_hex(unit, target, reachable_hexes: Array) -> Vector2i:
	var best_hex = unit.hex_position
	var best_distance = hex_grid.hex_distance(unit.hex_position, target.hex_position)
	
	for hex in reachable_hexes:
		var dist = hex_grid.hex_distance(hex, target.hex_position)
		if dist < best_distance:
			best_distance = dist
			best_hex = hex
	
	return best_hex

## ========== NUEVAS FUNCIONES DE EVALUACIÓN TÁCTICA ==========

## Calcula el porcentaje de salud del mech (0.0 - 1.0)
func _calculate_health_percent(unit) -> float:
	if not unit or not "armor" in unit or not "structure" in unit:
		return 1.0
	
	var total_armor = 0.0
	var current_armor = 0.0
	var total_structure = 0.0
	var current_structure = 0.0
	
	# Sumar toda la armadura
	for location in unit.armor.keys():
		total_armor += unit.armor[location]["max"]
		current_armor += unit.armor[location]["current"]
	
	# Sumar toda la estructura
	for location in unit.structure.keys():
		total_structure += unit.structure[location]["max"]
		current_structure += unit.structure[location]["current"]
	
	# Calcular salud combinada (armadura + estructura)
	var total_health = total_armor + total_structure
	var current_health = current_armor + current_structure
	
	if total_health <= 0:
		return 0.0
	
	return current_health / total_health

## Selecciona el mejor objetivo basado en amenaza y oportunidad
func _select_best_target(unit) -> Variant:
	var best_target = null
	var best_score = -INF
	
	for player in player_mechs:
		if player.is_destroyed:
			continue
		
		# IMPORTANTE: Verificar línea de visión
		if not _has_line_of_sight(unit, player):
			continue
		
		var score = _evaluate_target_priority(unit, player)
		if score > best_score:
			best_score = score
			best_target = player
	
	return best_target

## Evalúa la prioridad de un objetivo
func _evaluate_target_priority(unit, target) -> float:
	var distance = hex_grid.hex_distance(unit.hex_position, target.hex_position)
	var target_health = _calculate_health_percent(target)
	
	var score = 0.0
	
	# Priorizar objetivos más débiles (más fáciles de destruir)
	score += (1.0 - target_health) * 50.0
	
	# Penalizar por distancia (objetivos cercanos son más peligrosos)
	score -= distance * 5.0
	
	# Bonus si el objetivo está en rango óptimo
	var optimal_range = _calculate_optimal_weapon_range(unit)
	if abs(distance - optimal_range) < 2:
		score += 20.0
	
	# Priorizar objetivos que nos pueden hacer más daño
	var threat = _estimate_threat_from_target(unit, target, distance)
	score += threat * 10.0
	
	return score

## Estima la amenaza que representa un objetivo
func _estimate_threat_from_target(_unit, target, distance: int) -> float:
	if not "weapons" in target:
		return 0.0
	
	var potential_damage = 0.0
	
	# Sumar daño de todas las armas en rango
	for weapon in target.weapons:
		if weapon.get("destroyed", false):
			continue
		
		var weapon_range = weapon.get("long_range", 9)
		if distance <= weapon_range:
			potential_damage += weapon.get("damage", 0)
	
	return potential_damage

## Calcula el rango óptimo de las armas del mech
func _calculate_optimal_weapon_range(unit) -> int:
	if not "weapons" in unit or unit.weapons.size() == 0:
		return 6  # Rango medio por defecto
	
	var total_damage = 0.0
	var weighted_range = 0.0
	
	for weapon in unit.weapons:
		if weapon.get("destroyed", false):
			continue
		
		var damage = weapon.get("damage", 0)
		# Usar rango corto o medio como óptimo
		var optimal = weapon.get("medium_range", weapon.get("short_range", 6))
		
		weighted_range += optimal * damage
		total_damage += damage
	
	if total_damage <= 0:
		return 6
	
	return int(weighted_range / total_damage)

## Decide el tipo de movimiento basado en situación táctica
func _decide_movement_type(unit, _target, distance: int, optimal_range: int, is_critical: bool) -> int:
	# Si estamos críticos, priorizar sobrevivir
	if is_critical:
		# Si estamos muy cerca, intentar retroceder usando Jump si es posible
		if distance < 3 and unit.jump_mp > 0:
			return GameEnums.MovementType.JUMP
		# Si no, caminar para minimizar modificadores de disparo
		return GameEnums.MovementType.WALK
	
	# Evaluar calor - evitar shutdown (podría usarse en futuras mejoras)
	# var _heat_percent = 0.0
	# if "heat" in unit and "heat_capacity" in unit and unit.heat_capacity > 0:
	# 	_heat_percent = float(unit.heat) / float(unit.heat_capacity)
	
	# Si el calor es alto, caminar para evitar sobrecalentamiento
	if unit.heat >= HEAT_DANGER_THRESHOLD:
		return GameEnums.MovementType.WALK
	
	# Si estamos lejos del rango óptimo, correr para acercarnos
	if distance > optimal_range + 3:
		return GameEnums.MovementType.RUN
	
	# Si estamos demasiado cerca, usar jump para reposicionarnos
	if distance < optimal_range - 2 and unit.jump_mp > 0:
		return GameEnums.MovementType.JUMP
	
	# Por defecto, caminar (balance entre movilidad y precisión)
	return GameEnums.MovementType.WALK

## Encuentra el mejor hexágono táctico para moverse
func _find_tactical_movement_hex(unit, target, reachable_hexes: Array, optimal_range: int, is_critical: bool) -> Vector2i:
	var best_hex = unit.hex_position
	var best_score = -INF
	
	for hex in reachable_hexes:
		var score = _evaluate_hex_tactical_value(unit, target, hex, optimal_range, is_critical)
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex

## Evalúa el valor táctico de un hexágono
func _evaluate_hex_tactical_value(unit, target, hex: Vector2i, optimal_range: int, is_critical: bool) -> float:
	var score = 0.0
	
	# Verificar que el hex esté libre
	if hex_grid.get_unit(hex) != null:
		return -INF
	
	var distance_to_target = hex_grid.hex_distance(hex, target.hex_position)
	
	# FACTOR CRÍTICO: Verificar LoS desde el nuevo hex
	# Simular la posición del mech en el nuevo hex para verificar LoS
	var original_pos = unit.hex_position
	unit.hex_position = hex  # Temporalmente mover para verificar LoS
	var has_los = _has_line_of_sight(unit, target)
	unit.hex_position = original_pos  # Restaurar posición original
	
	# Si no hay LoS desde este hex, es inútil
	if not has_los:
		return -INF
	
	# FACTOR 1: Rango óptimo
	var range_diff = abs(distance_to_target - optimal_range)
	score += OPTIMAL_RANGE_BONUS / (1.0 + range_diff)
	
	# FACTOR 2: Modo defensivo si estamos críticos
	if is_critical:
		# Priorizar alejarse del enemigo
		var current_distance = hex_grid.hex_distance(original_pos, target.hex_position)
		if distance_to_target > current_distance:
			score += 50.0  # Bonus por alejarse
		else:
			score -= 30.0  # Penalización por acercarse
	
	# FACTOR 3: Terreno y cobertura
	var terrain_bonus = _evaluate_terrain_defense(hex)
	score += terrain_bonus
	
	# FACTOR 4: No acercarse demasiado si podemos evitarlo
	if distance_to_target < 2:
		score -= 20.0
	
	# FACTOR 5: Evaluar exposición a múltiples enemigos
	var exposure_penalty = _evaluate_exposure_to_enemies(hex)
	score -= exposure_penalty
	
	return score

## Evalúa el valor defensivo del terreno
func _evaluate_terrain_defense(hex: Vector2i) -> float:
	if not hex_grid.hex_data.has(hex):
		return 0.0
	
	var terrain_type = hex_grid.hex_data[hex].get("terrain", 0)
	
	# TerrainType proporciona modificadores de to-hit
	# Bosques y edificios son mejores para defensa
	match terrain_type:
		1: return 20.0  # FOREST - mejor cobertura
		2: return 10.0  # ROUGH - cobertura moderada
		6: return 15.0  # BUILDING - buena cobertura
		_: return 0.0

## Evalúa la exposición a múltiples enemigos
func _evaluate_exposure_to_enemies(hex: Vector2i) -> float:
	var exposure = 0.0
	
	for player in player_mechs:
		if player.is_destroyed:
			continue
		
		var distance = hex_grid.hex_distance(hex, player.hex_position)
		
		# Penalizar estar en rango de múltiples enemigos
		if distance <= 9:  # Rango largo típico
			# Más penalización si está más cerca
			exposure += 10.0 / max(1.0, distance)
	
	return exposure

## Selecciona armas inteligentemente basado en calor y efectividad
func _select_weapons_intelligently(unit, _target, distance: int) -> Dictionary:
	var result = {
		"weapons": [],
		"expected_heat": 0,
		"expected_damage": 0
	}
	
	if not "weapons" in unit:
		return result
	
	# Calcular cuánto calor podemos permitirnos generar
	var current_heat = unit.heat if "heat" in unit else 0
	var heat_capacity = unit.heat_capacity if "heat_capacity" in unit else 30
	var _heat_dissipation = unit.heat_dissipation if "heat_dissipation" in unit else 10
	
	# Dejar margen de seguridad para evitar shutdown (23+)
	var safe_heat_limit = min(HEAT_DANGER_THRESHOLD, heat_capacity - 5)
	var available_heat = max(0, safe_heat_limit - current_heat)
	
	# Crear lista de armas utilizables con su efectividad
	var weapon_options = []
	for i in range(unit.weapons.size()):
		var weapon = unit.weapons[i]
		
		if weapon.get("destroyed", false):
			continue
		
		if weapon.get("ammo", -1) == 0:
			continue
		
		var weapon_range = weapon.get("long_range", 9)
		if distance > weapon_range:
			continue
		
		# Calcular efectividad de esta arma
		var effectiveness = _calculate_weapon_effectiveness(weapon, distance)
		
		weapon_options.append({
			"index": i,
			"weapon": weapon,
			"effectiveness": effectiveness,
			"heat": weapon.get("heat", 0),
			"damage": weapon.get("damage", 0)
		})
	
	# Ordenar por efectividad
	weapon_options.sort_custom(func(a, b): return a["effectiveness"] > b["effectiveness"])
	
	# Seleccionar armas hasta el límite de calor
	var total_heat = 0
	for option in weapon_options:
		var weapon_heat = option["heat"]
		
		# Si añadir esta arma nos pondría en peligro, evaluar si vale la pena
		if total_heat + weapon_heat > available_heat:
			# Solo disparar si podemos hacer mucho daño y no estamos cerca del shutdown
			if option["damage"] >= 15 and current_heat + total_heat < 18:
				result["weapons"].append(option["index"])
				total_heat += weapon_heat
			continue
		
		result["weapons"].append(option["index"])
		total_heat += weapon_heat
	
	result["expected_heat"] = total_heat
	
	# Si no podemos disparar nada sin sobrecalentarnos, al menos disparar lo más efectivo
	if result["weapons"].size() == 0 and weapon_options.size() > 0:
		var best_weapon = weapon_options[0]
		result["weapons"].append(best_weapon["index"])
		result["expected_heat"] = best_weapon["heat"]
	
	return result

## Calcula la efectividad de un arma a cierta distancia
func _calculate_weapon_effectiveness(weapon: Dictionary, distance: int) -> float:
	var damage = weapon.get("damage", 0)
	var heat = weapon.get("heat", 1)
	
	# Daño por calor = eficiencia base
	var efficiency = float(damage) / max(1.0, float(heat))
	
	# Modificar por rango
	var short_range = weapon.get("short_range", 3)
	var medium_range = weapon.get("medium_range", 6)
	var long_range = weapon.get("long_range", 9)
	
	var range_modifier = 1.0
	if distance <= short_range:
		range_modifier = 1.5  # Muy efectivo a corto rango
	elif distance <= medium_range:
		range_modifier = 1.0  # Efectividad normal
	elif distance <= long_range:
		range_modifier = 0.6  # Menos efectivo a largo rango
	else:
		range_modifier = 0.0  # Fuera de rango
	
	return efficiency * range_modifier * damage

## Completa la activación de la unidad
func _complete_activation():
	if battle_scene and battle_scene.has_method("get_turn_manager"):
		var turn_manager = battle_scene.get_turn_manager()
		if turn_manager:
			turn_manager.complete_unit_activation()

## Verifica si hay línea de visión entre dos unidades
func _has_line_of_sight(from_unit, to_unit) -> bool:
	if not hex_grid:
		return true  # Si no hay grid, asumir que sí hay LoS
	
	if not "hex_position" in from_unit or not "hex_position" in to_unit:
		return true  # Si no tienen posición, asumir que sí
	
	# Usar el sistema LineOfSight
	var los_data = LineOfSight.calculate_los(hex_grid, from_unit.hex_position, to_unit.hex_position)
	
	var has_los = los_data.result != LineOfSight.Result.BLOCKED
	
	# Debug: mostrar estado de LoS
	if not has_los:
		print("[AI LoS] %s CANNOT see %s: %s" % [from_unit.mech_name, to_unit.mech_name, los_data.message])
	
	# Solo podemos disparar si no está bloqueado
	return has_los
