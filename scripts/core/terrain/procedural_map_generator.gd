class_name ProceduralMapGenerator
extends RefCounted

## Generador Procedural de Mapas BattleTech
## 
## Respeta las reglas oficiales de generación:
## 1. Divide el mapa en zonas (elevadas, bajas, agua, bosque)
## 2. Asigna elevaciones coherentes (0-3 normal, 4-5 montañas raras)
## 3. Transiciones suaves (±1 preferido, ±2 acantilados, ±3 excepcional)
## 4. Terrenos coherentes en clusters
## 5. Reglas de adyacencia (agua→agua, claro→bosque ligero→denso, etc.)

# Configuración del generador
var grid_width: int = 12
var grid_height: int = 16
var seed_value: int = 0
var rng: RandomNumberGenerator

# Tipos de zona
enum ZoneType {
	LOWLAND,      # Zona baja (0-1)
	HIGHLAND,     # Zona elevada (2-3)
	MOUNTAIN,     # Montaña (4-5) - raro
	WATER_ZONE,   # Zona de agua
	FOREST_ZONE,  # Zona boscosa
	URBAN_ZONE    # Zona urbana
}

# Datos de zonas
var zones: Dictionary = {}  # Vector2i -> ZoneType
var zone_centers: Array = []  # Centros de cada zona

# Datos del mapa generado
var hex_data: Dictionary = {}

func _init(width: int = 12, height: int = 16, map_seed: int = 0):
	grid_width = width
	grid_height = height
	seed_value = map_seed if map_seed != 0 else randi()
	
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value

## Generar mapa completo siguiendo las reglas oficiales
func generate_map() -> Dictionary:
	hex_data.clear()
	zones.clear()
	zone_centers.clear()
	
	# PASO 1: Dividir en zonas
	_generate_zones()
	
	# PASO 2: Asignar elevación base a cada zona
	_assign_zone_elevations()
	
	# PASO 3: Generar terreno base coherente
	_generate_base_terrain()
	
	# PASO 4: Aplicar transiciones suaves (primera pasada ligera)
	_smooth_elevation_transitions(2)  # Solo 2 pasadas iniciales
	
	# PASO 5: Distribuir detalles (rough, bosques, agua, COLINAS)
	_distribute_terrain_details()
	
	# PASO 6: Suavizar de nuevo DESPUÉS de elevar colinas
	_smooth_elevation_transitions(3)  # 3 pasadas finales para pendientes graduales
	
	# PASO 7: Añadir obstáculos (carreteras, edificios)
	_add_obstacles()
	
	# PASO 8: Validar jugabilidad
	_validate_playability()
	
	return hex_data

## PASO 1: Dividir el mapa en zonas coherentes
func _generate_zones():
	# Decidir número de zonas (3-6)
	var num_zones = rng.randi_range(3, 6)
	
	# Generar centros de zonas usando Poisson disk sampling
	zone_centers = _poisson_disk_sampling(num_zones)
	
	# Asignar tipo a cada zona
	var zone_types = []
	for i in range(num_zones):
		var zone_type = _decide_zone_type(i, num_zones)
		zone_types.append(zone_type)
	
	# Asignar cada hex a la zona más cercana (Voronoi)
	for q in range(grid_width):
		for r in range(grid_height):
			var pos = Vector2i(q, r)
			var closest_zone = _find_closest_zone(pos)
			zones[pos] = zone_types[closest_zone]

## Decidir tipo de zona basado en distribución balanceada
func _decide_zone_type(zone_index: int, total_zones: int) -> ZoneType:
	# Garantizar al menos 1 zona de cada tipo principal
	if zone_index == 0:
		return ZoneType.LOWLAND
	elif zone_index == 1:
		return ZoneType.HIGHLAND
	elif zone_index == 2 and total_zones >= 3:
		return ZoneType.FOREST_ZONE
	
	# Resto aleatorio con probabilidades
	var roll = rng.randf()
	if roll < 0.3:
		return ZoneType.LOWLAND
	elif roll < 0.5:
		return ZoneType.HIGHLAND
	elif roll < 0.65:
		return ZoneType.FOREST_ZONE
	elif roll < 0.80:
		return ZoneType.WATER_ZONE
	elif roll < 0.95:
		return ZoneType.URBAN_ZONE
	else:
		return ZoneType.MOUNTAIN  # Raro (5%)

## Poisson disk sampling para distribuir zonas uniformemente
func _poisson_disk_sampling(num_samples: int) -> Array:
	var samples = []
	var attempts = 0
	var max_attempts = num_samples * 30
	var min_distance = sqrt(float(grid_width * grid_height) / float(num_samples)) * 0.8
	
	# Primera muestra aleatoria
	samples.append(Vector2i(rng.randi_range(2, grid_width - 3), rng.randi_range(2, grid_height - 3)))
	
	while samples.size() < num_samples and attempts < max_attempts:
		attempts += 1
		
		var candidate = Vector2i(
			rng.randi_range(1, grid_width - 2),
			rng.randi_range(1, grid_height - 2)
		)
		
		var valid = true
		for existing in samples:
			var dist = _hex_distance(candidate, existing)
			if dist < min_distance:
				valid = false
				break
		
		if valid:
			samples.append(candidate)
	
	return samples

## Encontrar zona más cercana (índice en zone_centers)
func _find_closest_zone(pos: Vector2i) -> int:
	var min_dist = INF
	var closest_idx = 0
	
	for i in range(zone_centers.size()):
		var dist = _hex_distance(pos, zone_centers[i])
		if dist < min_dist:
			min_dist = dist
			closest_idx = i
	
	return closest_idx

## PASO 2: Asignar elevación base según tipo de zona con ruido continuo
func _assign_zone_elevations():
	# Primera pasada: generar mapa de altura continuo usando ruido Perlin multi-octava
	var elevation_map = {}
	
	for pos in zones.keys():
		var zone_type = zones[pos]
		
		# Generar ruido continuo para cada posición (0.0-1.0)
		# Usamos múltiples octavas para crear colinas realistas
		var noise_value = 0.0
		var frequency = 0.1  # Frecuencia baja = colinas grandes
		var amplitude = 1.0
		var total_amplitude = 0.0
		
		# 4 octavas de ruido para detalles a diferentes escalas
		for octave in range(4):
			var sample_x = pos.x * frequency
			var sample_y = pos.y * frequency
			var octave_noise = _octave_noise(sample_x, sample_y, octave)
			noise_value += octave_noise * amplitude
			total_amplitude += amplitude
			
			frequency *= 2.0  # Cada octava es más detallada
			amplitude *= 0.5  # Pero con menos influencia
		
		# Normalizar ruido a 0.0-1.0
		noise_value = (noise_value / total_amplitude + 1.0) / 2.0
		
		# Convertir ruido a elevación según el tipo de zona
		var base_elevation = _get_zone_base_elevation(zone_type)
		var elevation_range = _get_zone_elevation_range(zone_type)
		
		# Mapear el ruido al rango de elevación de la zona
		var elevation = base_elevation + int(noise_value * elevation_range)
		
		# Clampear según tipo de zona (límites de BattleTech)
		match zone_type:
			ZoneType.LOWLAND:
				elevation = clampi(elevation, 0, 1)
			ZoneType.HIGHLAND:
				elevation = clampi(elevation, 2, 3)
			ZoneType.MOUNTAIN:
				elevation = clampi(elevation, 3, 5)
			ZoneType.WATER_ZONE:
				elevation = clampi(elevation, -1, 0)
			ZoneType.FOREST_ZONE:
				elevation = clampi(elevation, 0, 2)
			ZoneType.URBAN_ZONE:
				elevation = clampi(elevation, 0, 1)
		
		elevation_map[pos] = elevation
	
	# Segunda pasada: suavizar transiciones entre zonas diferentes
	for pos in zones.keys():
		var zone_type = zones[pos]
		var elevation = elevation_map[pos]
		
		# Verificar vecinos de otras zonas
		var neighbors = _get_neighbors(pos)
		var different_zone_neighbors = []
		
		for neighbor in neighbors:
			if zones.has(neighbor) and zones[neighbor] != zone_type:
				different_zone_neighbors.append(neighbor)
		
		# Si está en el borde de una zona, suavizar la transición
		if different_zone_neighbors.size() > 0:
			var neighbor_elevations = []
			for neighbor in different_zone_neighbors:
				neighbor_elevations.append(elevation_map[neighbor])
			
			if neighbor_elevations.size() > 0:
				var avg_neighbor = 0
				for elev in neighbor_elevations:
					avg_neighbor += elev
				avg_neighbor = avg_neighbor / neighbor_elevations.size()
				
				# Mezclar 70% propio, 30% vecinos para transición suave
				elevation = int(elevation * 0.7 + avg_neighbor * 0.3)
		
		# Aplicar elevación final
		if not hex_data.has(pos):
			hex_data[pos] = {}
		hex_data[pos]["elevation"] = elevation
		hex_data[pos]["zone"] = zone_type

## Obtener rango de elevación para una zona
func _get_zone_elevation_range(zone_type: ZoneType) -> int:
	match zone_type:
		ZoneType.LOWLAND:
			return 2  # 0-1 = rango de 2
		ZoneType.HIGHLAND:
			return 2  # 2-3 = rango de 2
		ZoneType.MOUNTAIN:
			return 3  # 3-5 = rango de 3
		ZoneType.WATER_ZONE:
			return 2  # -1-0 = rango de 2
		ZoneType.FOREST_ZONE:
			return 3  # 0-2 = rango de 3
		ZoneType.URBAN_ZONE:
			return 2  # 0-1 = rango de 2
		_:
			return 2

## Obtener elevación base de una zona
func _get_zone_base_elevation(zone_type: ZoneType) -> int:
	match zone_type:
		ZoneType.LOWLAND:
			return 0
		ZoneType.HIGHLAND:
			return 2
		ZoneType.MOUNTAIN:
			return 3
		ZoneType.WATER_ZONE:
			return -1
		ZoneType.FOREST_ZONE:
			return 0
		ZoneType.URBAN_ZONE:
			return 0
		_:
			return 0

## PASO 3: Generar terreno base coherente
func _generate_base_terrain():
	for pos in hex_data.keys():
		var zone_type = hex_data[pos]["zone"]
		var terrain = _get_base_terrain_for_zone(zone_type, pos)
		hex_data[pos]["terrain"] = terrain
		hex_data[pos]["walkable"] = (terrain != TerrainType.Type.WATER)
		hex_data[pos]["unit"] = null  # Inicializar unidad como null

## Obtener terreno base según zona
func _get_base_terrain_for_zone(zone_type: ZoneType, pos: Vector2i) -> TerrainType.Type:
	match zone_type:
		ZoneType.LOWLAND:
			# Clear con algo de rough
			var noise = _octave_noise(pos.x, pos.y, 3)
			if noise > 0.7:
				return TerrainType.Type.ROUGH
			else:
				return TerrainType.Type.CLEAR
		
		ZoneType.HIGHLAND:
			# Rough y colinas
			var noise = _octave_noise(pos.x, pos.y, 3)
			if noise > 0.6:
				return TerrainType.Type.HILL
			else:
				return TerrainType.Type.ROUGH
		
		ZoneType.MOUNTAIN:
			# Principalmente rough y colinas
			return TerrainType.Type.HILL
		
		ZoneType.WATER_ZONE:
			# Agua con transición a arena
			var dist_to_center = _distance_to_zone_center(pos)
			if dist_to_center < 2.0:
				return TerrainType.Type.WATER
			elif dist_to_center < 3.0:
				return TerrainType.Type.SAND  # Transición
			else:
				return TerrainType.Type.CLEAR
		
		ZoneType.FOREST_ZONE:
			# Se añadirá bosque después
			return TerrainType.Type.CLEAR
		
		ZoneType.URBAN_ZONE:
			# Pavimento y edificios se añaden después
			return TerrainType.Type.CLEAR
		
		_:
			return TerrainType.Type.CLEAR

## Distancia al centro de zona más cercano
func _distance_to_zone_center(pos: Vector2i) -> float:
	var closest_idx = _find_closest_zone(pos)
	return float(_hex_distance(pos, zone_centers[closest_idx]))

## PASO 4: Aplicar transiciones suaves de elevación
func _smooth_elevation_transitions(passes: int):
	for _pass in range(passes):
		var new_elevations = {}
		
		for pos in hex_data.keys():
			var current_elev = hex_data[pos]["elevation"]
			var neighbors = _get_neighbors(pos)
			
			if neighbors.is_empty():
				new_elevations[pos] = current_elev
				continue
			
			# Obtener elevaciones vecinas
			var neighbor_elevs = []
			for neighbor in neighbors:
				if hex_data.has(neighbor):
					neighbor_elevs.append(hex_data[neighbor]["elevation"])
			
			if neighbor_elevs.is_empty():
				new_elevations[pos] = current_elev
				continue
			
			# Calcular diferencias con vecinos
			var max_neighbor = neighbor_elevs.max()
			var min_neighbor = neighbor_elevs.min()
			var avg_neighbor = 0
			for elev in neighbor_elevs:
				avg_neighbor += elev
			avg_neighbor = avg_neighbor / neighbor_elevs.size()
			
			# Determinar cambio máximo permitido según zona
			var zone_type = hex_data[pos]["zone"]
			var max_change = 1  # Por defecto preferir ±1
			
			match zone_type:
				ZoneType.MOUNTAIN:
					max_change = 2  # Montañas pueden ser más abruptas
				ZoneType.WATER_ZONE, ZoneType.URBAN_ZONE:
					max_change = 1  # Zonas planas
				_:
					max_change = 1  # Preferir transiciones graduales
			
			# Crear pendientes graduales: si hay mucha diferencia, acercar al promedio
			var adjusted_elev = current_elev
			
			# Si la diferencia con vecinos es grande, suavizar hacia el promedio
			if abs(current_elev - avg_neighbor) > max_change:
				# Mover 60% hacia el promedio para crear pendiente
				adjusted_elev = int(current_elev * 0.4 + avg_neighbor * 0.6)
			
			# Aplicar límites de cambio máximo respecto a vecinos
			if adjusted_elev > max_neighbor + max_change:
				adjusted_elev = max_neighbor + max_change
			elif adjusted_elev < min_neighbor - max_change:
				adjusted_elev = min_neighbor - max_change
			
			# Respetar los límites de la zona
			match zone_type:
				ZoneType.LOWLAND:
					adjusted_elev = clampi(adjusted_elev, 0, 1)
				ZoneType.HIGHLAND:
					adjusted_elev = clampi(adjusted_elev, 1, 3)
				ZoneType.MOUNTAIN:
					adjusted_elev = clampi(adjusted_elev, 2, 5)
				ZoneType.WATER_ZONE:
					adjusted_elev = clampi(adjusted_elev, -1, 0)
				ZoneType.FOREST_ZONE:
					adjusted_elev = clampi(adjusted_elev, 0, 2)
				ZoneType.URBAN_ZONE:
					adjusted_elev = clampi(adjusted_elev, 0, 1)
			
			new_elevations[pos] = adjusted_elev
		
		# Aplicar nuevas elevaciones
		for pos in new_elevations.keys():
			hex_data[pos]["elevation"] = new_elevations[pos]

## PASO 5: Distribuir detalles del terreno
func _distribute_terrain_details():
	_add_forest_clusters()
	_add_hill_elevation()  # Elevar colinas ANTES de suavizar el agua
	_add_water_features()
	_add_rough_on_elevation_changes()

## Añadir clusters de bosque coherentes
func _add_forest_clusters():
	# Identificar zonas forestales
	var forest_zones = []
	for pos in hex_data.keys():
		if hex_data[pos]["zone"] == ZoneType.FOREST_ZONE:
			forest_zones.append(pos)
	
	if forest_zones.is_empty():
		return
	
	# Generar 3-7 clusters de bosque
	var num_clusters = rng.randi_range(3, 7)
	
	for i in range(num_clusters):
		if forest_zones.is_empty():
			break
		
		# Elegir centro del cluster
		var center = forest_zones[rng.randi_range(0, forest_zones.size() - 1)]
		forest_zones.erase(center)
		
		# Tamaño del cluster (3-7 hexes)
		var cluster_size = rng.randi_range(3, 7)
		
		# Generar cluster con transiciones (claro → ligero → denso)
		_generate_forest_cluster(center, cluster_size)

## Generar cluster de bosque con transiciones suaves
func _generate_forest_cluster(center: Vector2i, size: int):
	var forest_tiles = [center]
	var processed = {}
	
	# Marcar centro como bosque denso
	hex_data[center]["terrain"] = TerrainType.Type.HEAVY_WOODS
	processed[center] = 2  # Nivel 2 = denso
	
	# Expansión
	for i in range(size):
		if forest_tiles.is_empty():
			break
		
		var current = forest_tiles[rng.randi_range(0, forest_tiles.size() - 1)]
		var current_level = processed.get(current, 0)
		
		for neighbor in _get_neighbors(current):
			if processed.has(neighbor):
				continue
			
			# Probabilidad de expansión (70%)
			if rng.randf() > 0.7:
				continue
			
			# No expandir sobre agua, edificios o zonas urbanas
			if hex_data[neighbor]["zone"] in [ZoneType.WATER_ZONE, ZoneType.URBAN_ZONE]:
				continue
			
			if hex_data[neighbor]["terrain"] in [TerrainType.Type.WATER, TerrainType.Type.BUILDING]:
				continue
			
			# Transición suave: denso → ligero → claro
			var new_level = current_level
			if rng.randf() < 0.4:  # 40% de reducir nivel
				new_level = max(0, current_level - 1)
			
			match new_level:
				2:
					hex_data[neighbor]["terrain"] = TerrainType.Type.HEAVY_WOODS
				1:
					hex_data[neighbor]["terrain"] = TerrainType.Type.LIGHT_WOODS
				0:
					# Mantener terreno actual (borde del bosque)
					pass
			
			if new_level > 0:
				processed[neighbor] = new_level
				forest_tiles.append(neighbor)

## Elevar tiles de HILL para formar colinas reales
func _add_hill_elevation():
	# Encontrar todos los tiles de HILL
	var hill_tiles = []
	for pos in hex_data.keys():
		if hex_data[pos]["terrain"] == TerrainType.Type.HILL:
			hill_tiles.append(pos)
	
	if hill_tiles.is_empty():
		return
	
	# Agrupar hills en clusters conectados
	var hill_clusters = []
	var processed = {}
	
	for hill_tile in hill_tiles:
		if processed.has(hill_tile):
			continue
		
		# Encontrar todos los hills conectados
		var cluster = []
		var to_check = [hill_tile]
		
		while not to_check.is_empty():
			var current = to_check.pop_front()
			
			if processed.has(current):
				continue
			
			processed[current] = true
			cluster.append(current)
			
			# Añadir vecinos que también son HILL
			for neighbor in _get_neighbors(current):
				if hex_data.has(neighbor) and hex_data[neighbor]["terrain"] == TerrainType.Type.HILL:
					if not processed.has(neighbor):
						to_check.append(neighbor)
		
		hill_clusters.append(cluster)
	
	# Para cada cluster de hills, elevar el centro y crear pendiente
	for cluster in hill_clusters:
		if cluster.size() == 1:
			# Hill solitario: elevar +1
			var pos = cluster[0]
			hex_data[pos]["elevation"] += 1
		else:
			# Cluster de hills: encontrar centro geométrico
			var center_x = 0
			var center_y = 0
			for pos in cluster:
				center_x += pos.x
				center_y += pos.y
			center_x /= cluster.size()
			center_y /= cluster.size()
			var center_point = Vector2(center_x, center_y)
			
			# Elevar cada tile según distancia al centro
			for pos in cluster:
				var distance = Vector2(pos.x, pos.y).distance_to(center_point)
				var elevation_bonus = 0
				
				# Centro de la colina: +2 o +3
				if distance < 1.0:
					elevation_bonus = rng.randi_range(2, 3)
				# Media distancia: +1 o +2
				elif distance < 2.0:
					elevation_bonus = rng.randi_range(1, 2)
				# Borde: +1
				else:
					elevation_bonus = 1
				
				hex_data[pos]["elevation"] += elevation_bonus
				
				# Respetar límites máximos de zona
				var zone_type = hex_data[pos]["zone"]
				match zone_type:
					ZoneType.LOWLAND:
						hex_data[pos]["elevation"] = mini(hex_data[pos]["elevation"], 2)
					ZoneType.HIGHLAND:
						hex_data[pos]["elevation"] = mini(hex_data[pos]["elevation"], 4)
					ZoneType.MOUNTAIN:
						hex_data[pos]["elevation"] = mini(hex_data[pos]["elevation"], 5)
					ZoneType.FOREST_ZONE:
						hex_data[pos]["elevation"] = mini(hex_data[pos]["elevation"], 3)

## Añadir características de agua coherentes
func _add_water_features():
	# Encontrar zonas de agua
	var water_tiles = []
	for pos in hex_data.keys():
		if hex_data[pos]["terrain"] == TerrainType.Type.WATER:
			water_tiles.append(pos)
	
	if water_tiles.is_empty():
		return
	
	# Agrupar agua en clusters conectados
	var water_clusters = []
	var processed = {}
	
	for water_tile in water_tiles:
		if processed.has(water_tile):
			continue
		
		# Encontrar todos los tiles de agua conectados
		var cluster = []
		var to_check = [water_tile]
		
		while not to_check.is_empty():
			var current = to_check.pop_front()
			
			if processed.has(current):
				continue
			
			processed[current] = true
			cluster.append(current)
			
			# Añadir vecinos de agua
			for neighbor in _get_neighbors(current):
				if hex_data.has(neighbor) and hex_data[neighbor]["terrain"] == TerrainType.Type.WATER:
					if not processed.has(neighbor):
						to_check.append(neighbor)
		
		water_clusters.append(cluster)
	
	# Para cada cluster de agua, establecer elevación basada en vecinos NO-agua
	for cluster in water_clusters:
		var min_neighbor_elevation = 999
		
		# Buscar la elevación mínima de todos los vecinos NO-agua del cluster
		for water_tile in cluster:
			for neighbor in _get_neighbors(water_tile):
				if hex_data.has(neighbor) and hex_data[neighbor]["terrain"] != TerrainType.Type.WATER:
					var neighbor_elev = hex_data[neighbor]["elevation"]
					if neighbor_elev < min_neighbor_elevation:
						min_neighbor_elevation = neighbor_elev
		
		# Establecer todas las tiles del cluster al mismo nivel: 1 por debajo del mínimo vecino
		var water_elevation = min_neighbor_elevation - 1 if min_neighbor_elevation != 999 else -1
		
		for water_tile in cluster:
			hex_data[water_tile]["elevation"] = water_elevation

## Añadir rough en bordes de cambios de elevación
func _add_rough_on_elevation_changes():
	for pos in hex_data.keys():
		var current_elev = hex_data[pos]["elevation"]
		var neighbors = _get_neighbors(pos)
		
		# Verificar si hay cambio de elevación significativo
		var max_diff = 0
		for neighbor in neighbors:
			if hex_data.has(neighbor):
				var diff = abs(hex_data[neighbor]["elevation"] - current_elev)
				if diff > max_diff:
					max_diff = diff
		
		# Si hay cambio ≥2 niveles, añadir rough
		if max_diff >= 2:
			# No sobrescribir bosques, agua o edificios
			if hex_data[pos]["terrain"] in [TerrainType.Type.CLEAR, TerrainType.Type.SAND]:
				hex_data[pos]["terrain"] = TerrainType.Type.ROUGH

## PASO 6: Añadir obstáculos (edificios, carreteras)
func _add_obstacles():
	# Identificar zonas urbanas
	var urban_tiles = []
	for pos in hex_data.keys():
		if hex_data[pos]["zone"] == ZoneType.URBAN_ZONE:
			urban_tiles.append(pos)
	
	if urban_tiles.is_empty():
		return
	
	# Generar 2-5 edificios
	var num_buildings = rng.randi_range(2, 5)
	var buildings = []
	
	for i in range(num_buildings):
		if urban_tiles.is_empty():
			break
		
		var pos = urban_tiles[rng.randi_range(0, urban_tiles.size() - 1)]
		urban_tiles.erase(pos)
		
		# Verificar que no haya edificio cercano
		var too_close = false
		for building in buildings:
			if _hex_distance(pos, building) < 3:
				too_close = true
				break
		
		if not too_close:
			hex_data[pos]["terrain"] = TerrainType.Type.BUILDING
			# Elevar edificio (3-5 niveles sobre base)
			hex_data[pos]["elevation"] += rng.randi_range(3, 5)
			buildings.append(pos)
	
	# Conectar edificios con carreteras
	_connect_buildings_with_roads(buildings)

## Conectar edificios con carreteras
func _connect_buildings_with_roads(buildings: Array):
	if buildings.size() < 2:
		return
	
	# Árbol de expansión mínimo
	var connected = [buildings[0]]
	var unconnected = buildings.slice(1)
	
	while unconnected.size() > 0:
		var best_pair = null
		var best_distance = INF
		
		for conn in connected:
			for unconn in unconnected:
				var dist = _hex_distance(conn, unconn)
				if dist < best_distance:
					best_distance = dist
					best_pair = [conn, unconn]
		
		if best_pair:
			_create_road_between(best_pair[0], best_pair[1])
			connected.append(best_pair[1])
			unconnected.erase(best_pair[1])
		else:
			break

## Crear carretera entre dos puntos
func _create_road_between(start: Vector2i, end: Vector2i):
	var path = _find_path(start, end)
	
	for tile in path:
		if tile == start or tile == end:
			continue  # No sobrescribir edificios
		
		if hex_data[tile]["terrain"] not in [TerrainType.Type.BUILDING, TerrainType.Type.WATER]:
			hex_data[tile]["terrain"] = TerrainType.Type.PAVEMENT

## PASO 7: Validar jugabilidad
func _validate_playability():
	# Asegurar que hay caminos posibles entre zonas
	# Asegurar coberturas distribuidas
	# Asegurar alturas que permitan LoS
	
	# Por ahora: marcar walkable
	for pos in hex_data.keys():
		var terrain = hex_data[pos]["terrain"]
		hex_data[pos]["walkable"] = (terrain != TerrainType.Type.WATER)

## FUNCIONES AUXILIARES

## Obtener vecinos de un hexágono
func _get_neighbors(hex: Vector2i) -> Array:
	const HEX_DIRECTIONS = [
		Vector2i(0, -1),   # N
		Vector2i(1, -1),   # NE
		Vector2i(-1, 0),   # NW
		Vector2i(0, 1),    # S
		Vector2i(-1, 1),   # SW
		Vector2i(1, 0)     # SE
	]
	
	var neighbors = []
	for direction in HEX_DIRECTIONS:
		var neighbor = hex + direction
		if _is_valid_hex(neighbor):
			neighbors.append(neighbor)
	return neighbors

func _is_valid_hex(hex: Vector2i) -> bool:
	return hex.x >= 0 and hex.x < grid_width and hex.y >= 0 and hex.y < grid_height

## Distancia entre hexágonos
func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac = _axial_to_cube(a)
	var bc = _axial_to_cube(b)
	return (abs(ac.x - bc.x) + abs(ac.y - bc.y) + abs(ac.z - bc.z)) / 2

func _axial_to_cube(hex: Vector2i) -> Vector3i:
	var x = hex.x
	var z = hex.y
	var y = -x - z
	return Vector3i(x, y, z)

## Ruido procedural multicapa
func _octave_noise(x: int, y: int, octaves: int = 3) -> float:
	var value = 0.0
	var amplitude = 1.0
	var frequency = 1.0
	var max_value = 0.0
	
	for i in range(octaves):
		var sample_x = x * frequency
		var sample_y = y * frequency
		value += _simple_noise(int(sample_x), int(sample_y)) * amplitude
		max_value += amplitude
		amplitude *= 0.5
		frequency *= 2.0
	
	return value / max_value

func _simple_noise(x: int, y: int) -> float:
	var n = x + y * 57 + seed_value * 131
	n = (n << 13) ^ n
	var nn = (n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff
	return float(nn) / 2147483647.0

## Pathfinding simple para carreteras
func _find_path(start: Vector2i, goal: Vector2i) -> Array:
	var open_set = [start]
	var came_from = {}
	var g_score = {start: 0}
	var f_score = {start: _hex_distance(start, goal)}
	
	while open_set.size() > 0:
		var current = _get_lowest_f_score(open_set, f_score)
		
		if current == goal:
			return _reconstruct_path(came_from, current)
		
		open_set.erase(current)
		
		for neighbor in _get_neighbors(current):
			var tentative_g = g_score[current] + 1
			
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _hex_distance(neighbor, goal)
				
				if not open_set.has(neighbor):
					open_set.append(neighbor)
	
	return []

func _get_lowest_f_score(open_set: Array, f_score: Dictionary) -> Vector2i:
	var lowest = open_set[0]
	var lowest_score = f_score.get(lowest, INF)
	
	for node in open_set:
		var score = f_score.get(node, INF)
		if score < lowest_score:
			lowest = node
			lowest_score = score
	
	return lowest

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path
