extends Node
class_name BattleAI

## Sistema de IA mejorado para unidades enemigas
## Maneja la lógica de decisiones de los mechs enemigos con evaluación táctica
## Soporta 3 niveles de dificultad: EASY, NORMAL, HARD

# Niveles de dificultad
enum Difficulty { EASY, NORMAL, HARD }

var hex_grid: HexGrid
var player_mechs: Array = []
var battle_scene: Node = null
var difficulty: Difficulty = Difficulty.NORMAL

# Constantes base para evaluación táctica (se modifican según dificultad)
const THREAT_WEIGHT_DAMAGE = 1.5
const THREAT_WEIGHT_DISTANCE = 1.0
const SURVIVAL_THRESHOLD = 0.3
const HEAT_DANGER_THRESHOLD = 20
const OPTIMAL_RANGE_BONUS = 100.0

# Configuración por dificultad
var _config: Dictionary = {}

func _ready():
	_apply_difficulty_config()

func set_difficulty(new_difficulty: Difficulty):
	difficulty = new_difficulty
	_apply_difficulty_config()
	Log.info("AI", "Difficulty set to: %s" % Difficulty.keys()[difficulty])

func _apply_difficulty_config():
	"""Aplica la configuración según el nivel de dificultad"""
	match difficulty:
		Difficulty.EASY:
			# KAMIKAZE: Corre directo al enemigo, ignora calor, dispara todo
			_config = {
				"aggression": 1.0,           # Máxima agresión
				"heat_management": false,     # Ignora calor completamente
				"use_cover": false,           # No busca cobertura
				"target_priority_weak": 0.2,  # No prioriza débiles (ataca al más cercano)
				"target_priority_close": 1.0, # Siempre va al más cercano
				"preferred_movement": GameEnums.MovementType.RUN,  # Siempre corre
				"min_attack_range": 0,        # No respeta rango mínimo (quiere melee)
				"fire_all_weapons": true,     # Dispara TODO sin pensar
				"retreat_threshold": 0.0,     # NUNCA retrocede
				"think_delay": 0.2,           # Muy rápido (no piensa mucho)
				"accuracy_penalty": 0.3,      # 30% menos precisión (dispara sin apuntar bien)
			}
		Difficulty.NORMAL:
			# BALANCEADA: Agresiva pero con algo de sentido común
			_config = {
				"aggression": 0.7,
				"heat_management": true,
				"use_cover": false,           # No pierde tiempo buscando cobertura
				"target_priority_weak": 0.5,
				"target_priority_close": 0.5,
				"preferred_movement": GameEnums.MovementType.RUN,  # Prefiere correr
				"min_attack_range": 1,
				"fire_all_weapons": false,
				"retreat_threshold": 0.15,    # Solo retrocede si está MUY mal
				"think_delay": 0.3,
				"accuracy_penalty": 0.0,
			}
		Difficulty.HARD:
			# TÁCTICA: Inteligente pero agresiva - no alarga la partida
			_config = {
				"aggression": 0.6,
				"heat_management": true,
				"use_cover": true,
				"target_priority_weak": 0.8,  # Prioriza eliminar objetivos
				"target_priority_close": 0.3,
				"preferred_movement": GameEnums.MovementType.RUN,  # Agresiva
				"min_attack_range": 2,
				"fire_all_weapons": false,
				"retreat_threshold": 0.1,     # Casi nunca retrocede
				"think_delay": 0.4,
				"accuracy_penalty": 0.0,
			}

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
	
	# En EASY, ignorar evaluación táctica - ir directo al enemigo
	var best_target = closest_player
	if difficulty != Difficulty.EASY:
		best_target = _select_best_target(unit)
		if not best_target:
			best_target = closest_player
	
	var distance = hex_grid.hex_distance(unit.hex_position, best_target.hex_position)
	
	# Evaluar estado del mech (solo importa en NORMAL/HARD)
	var health_percent = _calculate_health_percent(unit)
	var is_critical = health_percent < _config.get("retreat_threshold", SURVIVAL_THRESHOLD)
	
	# En EASY, nunca estamos en modo crítico
	if difficulty == Difficulty.EASY:
		is_critical = false
	
	# Determinar rango óptimo de armas
	var optimal_range = _calculate_optimal_weapon_range(unit)
	
	# En EASY, el rango óptimo es 0 (quiere llegar a melee)
	if difficulty == Difficulty.EASY:
		optimal_range = 1
	
	# Elegir tipo de movimiento basado en dificultad
	var movement_type = _decide_movement_type(unit, best_target, distance, optimal_range, is_critical)
	
	unit.start_movement(movement_type)
	
	# Obtener hexágonos alcanzables
	var reachable = hex_grid.get_reachable_hexes(unit.hex_position, unit.current_movement)
	
	# Encontrar mejor hexágono según dificultad
	var best_hex = unit.hex_position
	if difficulty == Difficulty.EASY:
		# EASY: Simplemente ir al hex más cercano al enemigo
		best_hex = _find_closest_hex_to_target(unit, best_target, reachable)
	else:
		# NORMAL/HARD: Evaluación táctica
		best_hex = _find_tactical_movement_hex(unit, best_target, reachable, optimal_range, is_critical)
	
	var think_delay = _config.get("think_delay", GameConstants.AI_THINK_DELAY)
	
	if best_hex != unit.hex_position:
		await get_tree().create_timer(think_delay).timeout
		if battle_scene and battle_scene.has_method("_move_unit_to_hex"):
			battle_scene._move_unit_to_hex(unit, best_hex)
	else:
		_complete_activation()

## Encuentra el hex más cercano al objetivo (para EASY)
func _find_closest_hex_to_target(unit, target, reachable_hexes: Array) -> Vector2i:
	var best_hex = unit.hex_position
	var best_distance = hex_grid.hex_distance(unit.hex_position, target.hex_position)
	
	for hex in reachable_hexes:
		# Verificar que el hex esté libre
		if hex_grid.get_unit(hex) != null:
			continue
		
		var dist = hex_grid.hex_distance(hex, target.hex_position)
		if dist < best_distance:
			best_distance = dist
			best_hex = hex
	
	return best_hex

## IA para fase de ataque con armas
func _ai_weapon_attack(unit):
	# En EASY, atacar al más cercano sin pensar
	var best_target = null
	if difficulty == Difficulty.EASY:
		best_target = _find_closest_player(unit)
	else:
		best_target = _select_best_target(unit)
	
	if not best_target:
		Log.debug("AI", "No valid targets with line of sight", {"unit": unit.mech_name})
		_complete_activation()
		return
	
	# Doble verificación de LoS por seguridad
	if not _has_line_of_sight(unit, best_target):
		Log.debug("AI", "Lost line of sight to target, aborting attack", {
			"unit": unit.mech_name,
			"target": best_target.mech_name
		})
		_complete_activation()
		return
	
	Log.info("AI", "Unit attacking target (LoS confirmed)", {
		"attacker": unit.mech_name,
		"target": best_target.mech_name
	})
	
	var distance = hex_grid.hex_distance(unit.hex_position, best_target.hex_position)
	
	var think_delay = _config.get("think_delay", GameConstants.AI_THINK_DELAY)
	await get_tree().create_timer(think_delay).timeout
	
	# Seleccionar armas según dificultad
	var weapon_selection: Dictionary
	if _config.get("fire_all_weapons", false):
		# EASY: Disparar TODAS las armas sin pensar en calor
		weapon_selection = _select_all_weapons_in_range(unit, distance)
	else:
		# NORMAL/HARD: Selección inteligente
		weapon_selection = _select_weapons_intelligently(unit, best_target, distance)
	
	if weapon_selection["weapons"].size() > 0 and battle_scene and battle_scene.has_method("execute_weapon_attack"):
		battle_scene.execute_weapon_attack(unit, best_target, weapon_selection["weapons"], distance)
	else:
		_complete_activation()

## Selecciona TODAS las armas en rango (para EASY - ignora calor)
func _select_all_weapons_in_range(unit, distance: int) -> Dictionary:
	var result = {
		"weapons": [],
		"expected_heat": 0,
		"expected_damage": 0
	}
	
	if not "weapons" in unit:
		return result
	
	for i in range(unit.weapons.size()):
		var weapon = unit.weapons[i]
		
		if weapon.get("destroyed", false):
			continue
		
		if weapon.get("ammo", -1) == 0:
			continue
		
		var weapon_range = weapon.get("long_range", 9)
		if distance > weapon_range:
			continue
		
		# En EASY, añadir todas las armas sin importar nada más
		result["weapons"].append(i)
		result["expected_heat"] += weapon.get("heat", 0)
		result["expected_damage"] += weapon.get("damage", 0)
	
	return result

## IA para fase de ataque físico
func _ai_physical_attack(unit):
	var closest_player = _find_closest_adjacent_player(unit)
	
	if closest_player:
		# Verificar LoS aunque sea adyacente (por seguridad)
		if not _has_line_of_sight(unit, closest_player):
			Log.debug("AI", "No LoS to adjacent target for physical attack", {
				"target": closest_player.mech_name
			})
			_complete_activation()
			return
		
		var think_delay = _config.get("think_delay", GameConstants.AI_THINK_DELAY)
		await get_tree().create_timer(think_delay).timeout
		
		# Elegir tipo de ataque físico según dificultad
		var attack_type = _select_physical_attack_type(unit, closest_player)
		
		if battle_scene and battle_scene.has_method("execute_physical_attack"):
			battle_scene.execute_physical_attack(unit, closest_player, attack_type)
	else:
		_complete_activation()

## Selecciona el tipo de ataque físico
func _select_physical_attack_type(unit, target) -> String:
	# En EASY, siempre usar el ataque más simple
	if difficulty == Difficulty.EASY:
		return "punch_right"
	
	# En NORMAL/HARD, elegir basado en situación
	var unit_tonnage = unit.get("tonnage", 50)
	var target_tonnage = target.get("tonnage", 50)
	
	# Si somos más pesados, patada hace más daño
	if unit_tonnage >= target_tonnage and unit_tonnage >= 60:
		return "kick"
	
	# Si el objetivo está muy dañado, doble puñetazo
	var target_health = _calculate_health_percent(target)
	if target_health < 0.3:
		return "punch_both"
	
	return "punch_right"


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

## ========== FUNCIONES DE EVALUACIÓN TÁCTICA ==========

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

## Evalúa la prioridad de un objetivo (modificado por dificultad)
func _evaluate_target_priority(unit, target) -> float:
	var distance = hex_grid.hex_distance(unit.hex_position, target.hex_position)
	var target_health = _calculate_health_percent(target)
	
	var score = 0.0
	
	# Factor de priorización de objetivos débiles (configurable)
	var weak_priority = _config.get("target_priority_weak", 0.5)
	score += (1.0 - target_health) * 50.0 * weak_priority
	
	# Factor de priorización de objetivos cercanos (configurable)
	var close_priority = _config.get("target_priority_close", 0.5)
	score -= distance * 5.0 * (1.0 - close_priority)
	score += (15 - distance) * 3.0 * close_priority  # Bonus por cercanía
	
	# Bonus si el objetivo está en rango óptimo (solo NORMAL/HARD)
	if difficulty != Difficulty.EASY:
		var optimal_range = _calculate_optimal_weapon_range(unit)
		if abs(distance - optimal_range) < 2:
			score += 20.0
	
	# Priorizar objetivos que nos pueden hacer más daño (evaluación de amenazas - HARD)
	if difficulty == Difficulty.HARD:
		var threat = _estimate_threat_from_target(unit, target, distance)
		score += threat * 15.0  # Mayor peso en HARD
	
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

## Decide el tipo de movimiento basado en dificultad y situación
func _decide_movement_type(unit, _target, distance: int, optimal_range: int, is_critical: bool) -> int:
	# EASY: Siempre correr (o saltar si puede y está lejos)
	if difficulty == Difficulty.EASY:
		if distance > 6 and unit.jump_mp > 0:
			return GameEnums.MovementType.JUMP
		return GameEnums.MovementType.RUN
	
	# Si estamos críticos (solo NORMAL/HARD con retreat_threshold > 0)
	if is_critical:
		if distance < 3 and unit.jump_mp > 0:
			return GameEnums.MovementType.JUMP
		return GameEnums.MovementType.WALK
	
	# Gestión de calor (solo si está habilitado)
	if _config.get("heat_management", true):
		if unit.heat >= HEAT_DANGER_THRESHOLD:
			return GameEnums.MovementType.WALK
	
	# Por defecto, preferir correr para ser agresivo
	var preferred = _config.get("preferred_movement", GameEnums.MovementType.RUN)
	
	# Si estamos muy lejos, correr definitivamente
	if distance > optimal_range + 4:
		return GameEnums.MovementType.RUN
	
	# Si estamos demasiado cerca y queremos reposicionarnos (HARD)
	if difficulty == Difficulty.HARD and distance < optimal_range - 2 and unit.jump_mp > 0:
		return GameEnums.MovementType.JUMP
	
	return preferred

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

## Evalúa el valor táctico de un hexágono (modificado para ser más agresivo)
func _evaluate_hex_tactical_value(unit, target, hex: Vector2i, optimal_range: int, is_critical: bool) -> float:
	var score = 0.0
	var aggression = _config.get("aggression", 1.0)
	
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
	
	# Si no hay LoS desde este hex, es muy malo (pero no imposible en EASY)
	if not has_los:
		if difficulty == Difficulty.EASY:
			score -= 100.0  # EASY: penaliza pero no descarta, puede acercarse ciegamente
		else:
			return -INF
	
	# FACTOR 1: Rango óptimo - TODOS quieren acercarse al rango óptimo
	var range_diff = abs(distance_to_target - optimal_range)
	score += OPTIMAL_RANGE_BONUS / (1.0 + range_diff)
	
	# FACTOR 2: Acercarse al enemigo (AGRESIVO en todas las dificultades)
	var current_distance = hex_grid.hex_distance(original_pos, target.hex_position)
	
	if difficulty == Difficulty.EASY:
		# EASY: Siempre quiere acercarse lo más posible (kamikaze)
		score += (current_distance - distance_to_target) * 30.0 * aggression
		# Bonus extra por estar muy cerca (melee range)
		if distance_to_target <= 1:
			score += 100.0
	else:
		# NORMAL/HARD: Prefiere acercarse pero respeta el rango óptimo
		if distance_to_target > optimal_range:
			# Muy lejos, acercarse
			score += (current_distance - distance_to_target) * 20.0 * aggression
		elif distance_to_target < optimal_range - 2:
			# Demasiado cerca solo en HARD, reposicionar
			if difficulty == Difficulty.HARD:
				score -= 10.0
		# En rango óptimo, mantener posición agresiva
	
	# FACTOR 3: Modo defensivo SOLO si estamos críticos Y en HARD
	if is_critical and difficulty == Difficulty.HARD:
		# Solo en HARD y crítico consideramos alejarnos un poco
		if distance_to_target > current_distance:
			score += 20.0  # Pequeño bonus por alejarse
	elif is_critical:
		# EASY/NORMAL: Ignorar el modo defensivo, seguir atacando
		pass
	
	# FACTOR 4: Terreno y cobertura (reducido, solo HARD lo usa bien)
	if _config.get("use_cover", false):
		var terrain_bonus = _evaluate_terrain_defense(hex)
		score += terrain_bonus * 0.5  # Reducido para no ser defensivo
	
	# FACTOR 5: No penalizar demasiado estar cerca
	if distance_to_target < 2:
		if difficulty == Difficulty.EASY:
			score += 50.0  # EASY: BONUS por estar cerca (melee!)
		elif difficulty == Difficulty.NORMAL:
			score -= 5.0  # NORMAL: Pequeña penalización
		else:
			score -= 15.0  # HARD: Penalización moderada
	
	# FACTOR 6: Evaluar exposición (reducido significativamente)
	if difficulty == Difficulty.HARD:
		var exposure_penalty = _evaluate_exposure_to_enemies(hex)
		score -= exposure_penalty * 0.3  # Muy reducido
	# EASY/NORMAL: Ignoran la exposición
	
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
	
	var fire_everything = _config.get("fire_all_weapons", false)
	var heat_management = _config.get("heat_management", true)
	
	# Calcular cuánto calor podemos permitirnos generar
	var current_heat = unit.heat if "heat" in unit else 0
	var heat_capacity = unit.heat_capacity if "heat_capacity" in unit else 30
	var _heat_dissipation = unit.heat_dissipation if "heat_dissipation" in unit else 10
	
	# En EASY (fire_everything), no nos importa el límite de calor
	var safe_heat_limit = min(HEAT_DANGER_THRESHOLD, heat_capacity - 5)
	if fire_everything:
		safe_heat_limit = 999  # Ignora el calor, dispara todo
	
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
	
	# EASY: Disparar todas las armas en rango
	if fire_everything:
		for option in weapon_options:
			result["weapons"].append(option["index"])
			result["expected_heat"] += option["heat"]
			result["expected_damage"] += option["damage"]
		return result
	
	# NORMAL/HARD: Seleccionar armas hasta el límite de calor
	var total_heat = 0
	for option in weapon_options:
		var weapon_heat = option["heat"]
		
		# Si añadir esta arma nos pondría en peligro, evaluar si vale la pena
		if total_heat + weapon_heat > available_heat:
			# Solo disparar si podemos hacer mucho daño y no estamos cerca del shutdown
			if not heat_management or (option["damage"] >= 15 and current_heat + total_heat < 18):
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
		Log.debug("AI", "Unit CANNOT see target", {
			"from": from_unit.mech_name,
			"to": to_unit.mech_name,
			"message": los_data.message
		})
	
	# Solo podemos disparar si no está bloqueado
	return has_los
