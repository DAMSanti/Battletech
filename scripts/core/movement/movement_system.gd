class_name MovementSystem
extends RefCounted

## Sistema de movimiento - Calcula movimiento, costos de terreno y alcance
## Responsabilidad única: Gestión de movimiento en grid hexagonal

static func calculate_walk_distance(mech) -> int:
	var base_walk = mech.walk_mp
	
	# Penalización por daño en piernas
	var leg_damage_penalty = 0
	if mech.get_location_armor("right_leg") <= 0 or mech.get_location_armor("left_leg") <= 0:
		leg_damage_penalty = base_walk / 2
	
	# Penalización por calor
	var heat_penalty = 0
	if mech.heat >= 5:
		heat_penalty = 1
	if mech.heat >= 10:
		heat_penalty = 2
	if mech.heat >= 15:
		heat_penalty = 3
	if mech.heat >= 20:
		heat_penalty = 4
	if mech.heat >= 25:
		heat_penalty = 5
	
	var final_walk = base_walk - leg_damage_penalty - heat_penalty
	return max(1, final_walk)  # Mínimo 1

static func calculate_run_distance(mech) -> int:
	var walk = calculate_walk_distance(mech)
	return int(walk * 1.5)

static func get_reachable_hexes(start_hex: Vector2i, max_distance: int, hex_grid) -> Array:
	var reachable = []
	var queue = [{hex = start_hex, distance = 0}]
	var visited = {start_hex: 0}
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_hex = current.hex
		var current_distance = current.distance
		
		if current_distance > max_distance:
			continue
		
		if current_hex != start_hex:
			reachable.append(current_hex)
		
		var neighbors = hex_grid.get_hex_neighbors(current_hex)
		for neighbor in neighbors:
			if not hex_grid.is_valid_hex(neighbor):
				continue
			
			# Usar el nuevo sistema de terreno
			var terrain_cost = hex_grid.get_terrain_cost(neighbor)
			var new_distance = current_distance + terrain_cost
			
			if new_distance > max_distance:
				continue
			
			if not visited.has(neighbor) or new_distance < visited[neighbor]:
				visited[neighbor] = new_distance
				queue.append({hex = neighbor, distance = new_distance})
	
	return reachable

static func calculate_heat_from_movement(mech, hexes_moved: int, ran: bool) -> int:
	var heat = 0
	
	if hexes_moved > 0:
		if ran:
			heat = 2
		else:
			heat = 1
	
	return heat
