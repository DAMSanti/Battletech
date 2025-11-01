extends Node
class_name BattleAI

## Sistema de IA para unidades enemigas
## Maneja la lógica de decisiones de los mechs enemigos

const WeaponAttackSystem = preload("res://scripts/core/combat/weapon_attack_system.gd")
const PhysicalAttackSystem = preload("res://scripts/core/combat/physical_attack_system.gd")

var hex_grid: HexGrid
var player_mechs: Array = []
var battle_scene: Node = null

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
	
	var distance = hex_grid.hex_distance(unit.hex_position, closest_player.hex_position)
	
	# Elegir tipo de movimiento basado en distancia
	var movement_type = GameEnums.MovementType.WALK
	if distance > 8:
		movement_type = GameEnums.MovementType.RUN  # Correr si está lejos
	
	unit.start_movement(movement_type)
	
	# Intentar moverse hacia el jugador
	var reachable = hex_grid.get_reachable_hexes(unit.hex_position, unit.current_movement)
	var best_hex = _find_best_movement_hex(unit, closest_player, reachable)
	
	if best_hex != unit.hex_position:
		await get_tree().create_timer(GameConstants.AI_THINK_DELAY).timeout
		if battle_scene and battle_scene.has_method("_move_unit_to_hex"):
			battle_scene._move_unit_to_hex(unit, best_hex)
	else:
		_complete_activation()

## IA para fase de ataque con armas
func _ai_weapon_attack(unit):
	var closest_player = _find_closest_player(unit)
	if not closest_player:
		_complete_activation()
		return
	
	var distance = hex_grid.hex_distance(unit.hex_position, closest_player.hex_position)
	
	await get_tree().create_timer(GameConstants.AI_THINK_DELAY).timeout
	
	# Disparar todas las armas que están en rango
	var weapon_indices = []
	for i in range(unit.weapons.size()):
		var weapon = unit.weapons[i]
		var long_range = weapon.get("long_range", 9)
		if distance <= long_range:
			weapon_indices.append(i)
	
	if weapon_indices.size() > 0 and battle_scene and battle_scene.has_method("execute_weapon_attack"):
		battle_scene.execute_weapon_attack(unit, closest_player, weapon_indices, distance)
	else:
		_complete_activation()

## IA para fase de ataque físico
func _ai_physical_attack(unit):
	var closest_player = _find_closest_adjacent_player(unit)
	
	if closest_player:
		await get_tree().create_timer(GameConstants.AI_THINK_DELAY).timeout
		# La IA elige puñetazo derecho como ataque por defecto
		if battle_scene and battle_scene.has_method("execute_physical_attack"):
			battle_scene.execute_physical_attack(unit, closest_player, "punch_right")
	else:
		_complete_activation()

## Encuentra el jugador más cercano
func _find_closest_player(unit) -> Variant:
	var closest = null
	var min_distance = INF
	
	for player in player_mechs:
		if not player.is_destroyed:
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

## Completa la activación de la unidad
func _complete_activation():
	if battle_scene and battle_scene.has_method("get_turn_manager"):
		var turn_manager = battle_scene.get_turn_manager()
		if turn_manager:
			turn_manager.complete_unit_activation()
