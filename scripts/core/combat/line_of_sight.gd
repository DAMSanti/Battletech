class_name LineOfSight
extends RefCounted

## Sistema de Line of Sight (LoS) para BattleTech
## Implementa todas las reglas de visibilidad, cobertura y bloqueo según BattleTech

## Resultado del cálculo de LoS
enum Result {
	CLEAR,           # LoS clara - sin penalizadores
	PARTIAL,         # Cobertura parcial - penalizadores
	BLOCKED          # LoS bloqueada - no se puede disparar
}

## Tipo de cobertura
enum CoverType {
	NONE,            # Sin cobertura
	LIGHT_WOODS,     # Bosque ligero: +1 por hex atravesado
	HEAVY_WOODS,     # Bosque denso: +2 si atraviesa 1, bloquea si atraviesa 2+
	HULL_DOWN,       # Parcialmente detrás de colina: solo partes superiores
	BUILDING,        # Edificio intermedio
	MECH_BLOCKING    # Otro mech en la línea
}

## Datos del resultado de LoS
class LoSData:
	var result: Result = Result.CLEAR
	var to_hit_modifier: int = 0
	var cover_type: CoverType = CoverType.NONE
	var can_hit_all_locations: bool = true  # Si false, solo partes superiores
	var blocking_hexes: Array = []          # Hexes que causan el bloqueo/cobertura
	var message: String = ""                # Descripción del resultado
	
	func _init():
		result = Result.CLEAR
		to_hit_modifier = 0
		cover_type = CoverType.NONE
		can_hit_all_locations = true
		blocking_hexes = []
		message = "Clear line of sight"

## Constantes de altura (en niveles)
const MECH_HEIGHT_LEVELS = 2  # Un mech mide ~2 niveles de altura
const HEAVY_WOODS_HEIGHT = 2  # Bosque denso añade 2 niveles
const LIGHT_WOODS_HEIGHT = 1  # Bosque ligero añade 1 nivel
const BUILDING_BASE_HEIGHT = 3  # Edificios base añaden 3 niveles (ajustable por elevación)

## Calcular Line of Sight entre dos hexes
static func calculate_los(hex_grid, attacker_hex: Vector2i, target_hex: Vector2i, attacker_height: int = MECH_HEIGHT_LEVELS, target_height: int = MECH_HEIGHT_LEVELS) -> LoSData:
	var data = LoSData.new()
	
	# Validar hexes
	if not hex_grid.is_valid_hex(attacker_hex) or not hex_grid.is_valid_hex(target_hex):
		data.result = Result.BLOCKED
		data.message = "Invalid hex"
		return data
	
	# Si es el mismo hex, LoS clara
	if attacker_hex == target_hex:
		return data
	
	# Obtener elevaciones
	var attacker_elevation = hex_grid.get_elevation(attacker_hex)
	var target_elevation = hex_grid.get_elevation(target_hex)
	
	# Calcular altura total (elevación del terreno + altura del mech)
	var attacker_total_height = attacker_elevation + attacker_height
	var target_total_height = target_elevation + target_height
	
	# Obtener hexes en la línea (excluyendo inicio y fin)
	var line_hexes = _get_line_hexes(hex_grid, attacker_hex, target_hex)
	
	# Contadores para bosques
	var light_woods_count = 0
	var heavy_woods_count = 0
	
	# Verificar cada hex intermedio
	for i in range(line_hexes.size()):
		var hex = line_hexes[i]
		var hex_elevation = hex_grid.get_elevation(hex)
		var hex_terrain = hex_grid.get_terrain(hex)
		
		# Verificar si hay un mech bloqueando
		var unit = hex_grid.get_unit(hex)
		if unit != null:
			data.result = Result.BLOCKED
			data.message = "Mech blocking line of sight"
			data.blocking_hexes.append(hex)
			data.cover_type = CoverType.MECH_BLOCKING
			return data
		
		# Calcular altura efectiva del obstáculo
		var obstacle_height = _get_obstacle_height(hex_terrain, hex_elevation)
		
		# Calcular altura de la línea en este punto (interpolación)
		var progress = float(i + 1) / float(line_hexes.size() + 1)
		var line_height = lerp(float(attacker_total_height), float(target_total_height), progress)
		
		# Regla especial: verificar si la línea toca un borde entre niveles diferentes
		if _line_crosses_elevation_edge(hex_grid, attacker_hex, target_hex, hex, attacker_total_height, target_total_height):
			data.result = Result.BLOCKED
			data.message = "Line crosses elevation edge"
			data.blocking_hexes.append(hex)
			return data
		
		# Verificar bloqueo por altura
		if obstacle_height >= line_height:
			# Bloqueo total
			data.result = Result.BLOCKED
			data.message = "Obstacle blocks line of sight at elevation %d" % obstacle_height
			data.blocking_hexes.append(hex)
			return data
		
		# Contar bosques para penalizadores
		if hex_terrain == TerrainType.Type.LIGHT_WOODS:
			light_woods_count += 1
			data.blocking_hexes.append(hex)
		elif hex_terrain == TerrainType.Type.HEAVY_WOODS or hex_terrain == TerrainType.Type.FOREST:
			heavy_woods_count += 1
			data.blocking_hexes.append(hex)
		
		# Verificar edificios
		if hex_terrain == TerrainType.Type.BUILDING:
			if obstacle_height >= line_height - 1:  # Margen de 1 nivel
				# Edificio da cobertura parcial si está cerca de la altura de la línea
				data.result = Result.PARTIAL
				data.to_hit_modifier += 2
				data.cover_type = CoverType.BUILDING
				data.blocking_hexes.append(hex)
	
	# Aplicar reglas de bosques
	if heavy_woods_count >= 2:
		# 2+ hexes de bosque denso = bloqueo total
		data.result = Result.BLOCKED
		data.message = "Heavy woods block line of sight (%d hexes)" % heavy_woods_count
		data.cover_type = CoverType.HEAVY_WOODS
		return data
	elif heavy_woods_count == 1:
		# 1 hex de bosque denso = +2 penalizador
		data.result = Result.PARTIAL
		data.to_hit_modifier += 2
		data.cover_type = CoverType.HEAVY_WOODS
		data.message = "Heavy woods provide cover (+2)"
	
	if light_woods_count > 0:
		# Cada hex de bosque ligero = +1 penalizador
		if data.result == Result.CLEAR:
			data.result = Result.PARTIAL
			data.cover_type = CoverType.LIGHT_WOODS
		data.to_hit_modifier += light_woods_count
		data.message = "Light woods provide cover (+%d)" % light_woods_count
	
	# Verificar Hull-Down (cobertura parcial por elevación)
	if _check_hull_down(hex_grid, attacker_hex, target_hex, target_elevation):
		data.result = Result.PARTIAL
		data.to_hit_modifier += 1
		data.can_hit_all_locations = false
		data.cover_type = CoverType.HULL_DOWN
		if data.message == "Clear line of sight":
			data.message = "Target is hull-down (+1, upper locations only)"
		else:
			data.message += " and hull-down (+1 additional, upper locations only)"
	
	# Mensaje final
	if data.result == Result.CLEAR:
		data.message = "Clear line of sight"
	
	return data

## Obtener altura efectiva de un obstáculo
static func _get_obstacle_height(terrain: TerrainType.Type, elevation: int) -> float:
	var height = float(elevation)
	
	match terrain:
		TerrainType.Type.FOREST, TerrainType.Type.HEAVY_WOODS:
			height += HEAVY_WOODS_HEIGHT
		TerrainType.Type.LIGHT_WOODS:
			height += LIGHT_WOODS_HEIGHT
		TerrainType.Type.BUILDING:
			height += BUILDING_BASE_HEIGHT
		TerrainType.Type.HILL:
			# Las colinas solo usan su elevación
			pass
		_:
			# Terreno claro, agua, etc. solo usan elevación
			pass
	
	return height

## Verificar si la línea cruza un borde de elevación
static func _line_crosses_elevation_edge(hex_grid, attacker_hex: Vector2i, target_hex: Vector2i, obstacle_hex: Vector2i, attacker_height: float, target_height: float) -> bool:
	# Si el hex intermedio es más alto que ambos extremos y la línea pasa por su borde
	var obstacle_elevation = hex_grid.get_elevation(obstacle_hex)
	
	# Obtener vecinos del hex obstáculo
	var neighbors = hex_grid.get_neighbors(obstacle_hex)
	
	for neighbor in neighbors:
		var neighbor_elevation = hex_grid.get_elevation(neighbor)
		
		# Si hay una diferencia de elevación de 1+ nivel
		if abs(obstacle_elevation - neighbor_elevation) >= 1:
			# Verificar si la línea pasa cerca de este borde
			var higher_elev = max(obstacle_elevation, neighbor_elevation)
			
			# Calcular altura de la línea en este punto
			var line_hexes = _get_line_hexes(hex_grid, attacker_hex, target_hex)
			var index = line_hexes.find(obstacle_hex)
			if index >= 0:
				var progress = float(index + 1) / float(line_hexes.size() + 1)
				var line_height = lerp(attacker_height, target_height, progress)
				
				# Si la línea está por debajo del borde de elevación, bloquea
				if line_height < higher_elev:
					return true
	
	return false

## Verificar Hull-Down (objetivo parcialmente detrás de elevación)
static func _check_hull_down(hex_grid, attacker_hex: Vector2i, target_hex: Vector2i, target_elevation: int) -> bool:
	# Obtener vecinos del objetivo en dirección al atacante
	var target_neighbors = hex_grid.get_neighbors(target_hex)
	
	# Dirección aproximada desde el objetivo hacia el atacante
	var direction = attacker_hex - target_hex
	
	# Buscar hex adyacente al objetivo que esté más alto
	for neighbor in target_neighbors:
		var neighbor_elevation = hex_grid.get_elevation(neighbor)
		
		# Si el vecino es 1 nivel más alto que el objetivo
		if neighbor_elevation == target_elevation + 1:
			# Verificar si está "delante" del objetivo (entre atacante y objetivo)
			var neighbor_direction = neighbor - target_hex
			
			# Producto punto para ver si está en la dirección correcta
			var dot = neighbor_direction.x * direction.x + neighbor_direction.y * direction.y
			
			if dot > 0:  # Mismo lado general
				return true
	
	return false

## Obtener hexes en la línea entre dos puntos (excluyendo inicio y fin)
static func _get_line_hexes(hex_grid, from_hex: Vector2i, to_hex: Vector2i) -> Array:
	var distance = hex_grid.hex_distance(from_hex, to_hex)
	var results = []
	
	if distance <= 1:
		return results  # Adyacentes o mismo hex
	
	# Usar interpolación lineal para trazar la línea
	for i in range(1, distance):
		var t = float(i) / float(distance)
		var lerped = _hex_lerp(from_hex, to_hex, t)
		results.append(lerped)
	
	return results

## Interpolación lineal entre hexes
static func _hex_lerp(a: Vector2i, b: Vector2i, t: float) -> Vector2i:
	var ax = float(a.x)
	var ay = float(a.y)
	var bx = float(b.x)
	var by = float(b.y)
	
	var x = lerp(ax, bx, t)
	var y = lerp(ay, by, t)
	
	return _axial_round(Vector2(x, y))

## Redondear coordenadas axiales
static func _axial_round(hex: Vector2) -> Vector2i:
	var q = round(hex.x)
	var r = round(hex.y)
	var s = round(-hex.x - hex.y)
	
	var q_diff = abs(q - hex.x)
	var r_diff = abs(r - hex.y)
	var s_diff = abs(s - (-hex.x - hex.y))
	
	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
	
	return Vector2i(int(q), int(r))

## Calcular modificador de altura (ventaja de elevación)
static func calculate_height_modifier(hex_grid, attacker_hex: Vector2i, target_hex: Vector2i) -> int:
	var attacker_elevation = hex_grid.get_elevation(attacker_hex)
	var target_elevation = hex_grid.get_elevation(target_hex)
	
	var diff = attacker_elevation - target_elevation
	
	# En BattleTech, atacar desde arriba es ventajoso
	# Cada nivel de diferencia da -1 al to-hit (más fácil)
	# Atacar desde abajo da +1 al to-hit (más difícil)
	
	if diff > 0:
		# Atacando desde arriba: -1 por nivel (más fácil)
		return -min(diff, 2)  # Máximo -2
	elif diff < 0:
		# Atacando desde abajo: +1 por nivel (más difícil)
		return min(abs(diff), 2)  # Máximo +2
	else:
		return 0

## Verificar si se puede disparar (wrapper simple)
static func can_shoot(hex_grid, attacker_hex: Vector2i, target_hex: Vector2i) -> bool:
	var los_data = calculate_los(hex_grid, attacker_hex, target_hex)
	return los_data.result != Result.BLOCKED

## Obtener penalizador total de LoS
static func get_total_modifier(hex_grid, attacker_hex: Vector2i, target_hex: Vector2i) -> int:
	var los_data = calculate_los(hex_grid, attacker_hex, target_hex)
	
	if los_data.result == Result.BLOCKED:
		return 999  # Imposible disparar
	
	var total_mod = los_data.to_hit_modifier
	
	# Añadir modificador de altura
	total_mod += calculate_height_modifier(hex_grid, attacker_hex, target_hex)
	
	return total_mod

## Obtener descripción completa de LoS
static func get_los_description(hex_grid, attacker_hex: Vector2i, target_hex: Vector2i) -> String:
	var los_data = calculate_los(hex_grid, attacker_hex, target_hex)
	var height_mod = calculate_height_modifier(hex_grid, attacker_hex, target_hex)
	
	var description = los_data.message
	
	if height_mod != 0:
		if height_mod < 0:
			description += "\nHeight advantage: %d" % height_mod
		else:
			description += "\nHeight disadvantage: +%d" % height_mod
	
	if not los_data.can_hit_all_locations:
		description += "\n(Can only hit upper locations)"
	
	if los_data.result == Result.BLOCKED:
		description += "\nCANNOT SHOOT"
	elif los_data.result == Result.PARTIAL:
		description += "\nTotal modifier: +%d" % (los_data.to_hit_modifier + max(0, height_mod))
	
	return description
