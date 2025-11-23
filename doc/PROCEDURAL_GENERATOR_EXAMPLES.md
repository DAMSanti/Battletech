# Ejemplos de Uso - Generador Procedural

## Ejemplo 1: Uso Básico

```gdscript
extends Node2D

func _ready():
	# Crear generador con tamaño 12x16
	var generator = ProceduralMapGenerator.new(12, 16)
	
	# Generar mapa
	var map_data = generator.generate_map()
	
	# Usar los datos
	for pos in map_data.keys():
		var hex_info = map_data[pos]
		print("Hex %s: %s (elevación %d)" % [
			pos,
			TerrainType.get_name(hex_info["terrain"]),
			hex_info["elevation"]
		])
```

---

## Ejemplo 2: Seed Específico

```gdscript
# Generar siempre el mismo mapa
var SEED_FAVORITO = 123456789
var generator = ProceduralMapGenerator.new(12, 16, SEED_FAVORITO)
var map_data = generator.generate_map()

# Guardar el seed para repetir más tarde
print("Mapa generado con seed: ", SEED_FAVORITO)
```

---

## Ejemplo 3: Generar Múltiples Mapas

```gdscript
# Generar 10 mapas y elegir el mejor
var mejor_mapa = null
var mejor_score = -1

for i in range(10):
	var generator = ProceduralMapGenerator.new(12, 16)
	var map_data = generator.generate_map()
	
	# Evaluar el mapa
	var score = _evaluar_mapa(map_data)
	
	if score > mejor_score:
		mejor_score = score
		mejor_mapa = map_data

print("Mejor mapa encontrado con score: ", mejor_score)

func _evaluar_mapa(map_data: Dictionary) -> float:
	# Contar variedad de terrenos
	var terrain_types = {}
	for pos in map_data.keys():
		var terrain = map_data[pos]["terrain"]
		terrain_types[terrain] = true
	
	# Más variedad = mejor
	return float(terrain_types.size())
```

---

## Ejemplo 4: Filtrar Mapas por Características

```gdscript
# Generar hasta encontrar un mapa con montañas
var map_data = null
var intentos = 0
var max_intentos = 50

while map_data == null and intentos < max_intentos:
	intentos += 1
	var generator = ProceduralMapGenerator.new(12, 16)
	var candidate = generator.generate_map()
	
	# Verificar si tiene montañas (elevación ≥4)
	if _tiene_montañas(candidate):
		map_data = candidate
		print("Mapa con montañas encontrado en intento %d" % intentos)

if map_data == null:
	print("No se encontró mapa con montañas, usando uno normal")
	map_data = ProceduralMapGenerator.new(12, 16).generate_map()

func _tiene_montañas(map_data: Dictionary) -> bool:
	for pos in map_data.keys():
		if map_data[pos]["elevation"] >= 4:
			return true
	return false
```

---

## Ejemplo 5: Integración con HexGrid

```gdscript
extends HexGrid

func _ready():
	# Activar generador procedural
	use_procedural_generator = true
	
	# Llamar al _ready original
	super._ready()
	
	# Opcional: Analizar el mapa generado
	_analizar_mapa()

func _analizar_mapa():
	var total_hexes = hex_data.size()
	var terrain_counts = {}
	
	for pos in hex_data.keys():
		var terrain = hex_data[pos]["terrain"]
		terrain_counts[terrain] = terrain_counts.get(terrain, 0) + 1
	
	print("\n=== Análisis del Mapa ===")
	print("Total hexes: ", total_hexes)
	for terrain in terrain_counts.keys():
		var count = terrain_counts[terrain]
		var pct = float(count) / float(total_hexes) * 100.0
		print("  %s: %.1f%%" % [TerrainType.get_name(terrain), pct])
```

---

## Ejemplo 6: Guardar y Cargar Mapas

```gdscript
# Guardar mapa
func guardar_mapa(map_data: Dictionary, seed_value: int, filename: String):
	var save_data = {
		"seed": seed_value,
		"width": 12,
		"height": 16,
		"map": {}
	}
	
	# Convertir Vector2i a String para JSON
	for pos in map_data.keys():
		var key = "%d,%d" % [pos.x, pos.y]
		save_data["map"][key] = map_data[pos]
	
	var file = FileAccess.open(filename, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	print("Mapa guardado en: ", filename)

# Cargar mapa
func cargar_mapa(filename: String) -> Dictionary:
	if not FileAccess.file_exists(filename):
		print("Archivo no encontrado: ", filename)
		return {}
	
	var file = FileAccess.open(filename, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("Error al parsear JSON")
		return {}
	
	var save_data = json.get_data()
	var map_data = {}
	
	# Convertir String a Vector2i
	for key in save_data["map"].keys():
		var coords = key.split(",")
		var pos = Vector2i(int(coords[0]), int(coords[1]))
		map_data[pos] = save_data["map"][key]
	
	print("Mapa cargado (seed: %d)" % save_data["seed"])
	return map_data
```

---

## Ejemplo 7: Exportar a Formato de Texto

```gdscript
func exportar_mapa_ascii(map_data: Dictionary, width: int, height: int) -> String:
	var output = ""
	var symbols = {
		TerrainType.Type.CLEAR: ".",
		TerrainType.Type.LIGHT_WOODS: ",",
		TerrainType.Type.HEAVY_WOODS: "♣",
		TerrainType.Type.WATER: "~",
		TerrainType.Type.SAND: ":",
		TerrainType.Type.ROUGH: "◆",
		TerrainType.Type.HILL: "▲",
		TerrainType.Type.PAVEMENT: "=",
		TerrainType.Type.BUILDING: "■",
	}
	
	for r in range(height):
		# Offset para hexágonos (flat-top)
		if r % 2 == 1:
			output += " "
		
		for q in range(width):
			var pos = Vector2i(q, r)
			if map_data.has(pos):
				var terrain = map_data[pos]["terrain"]
				output += symbols.get(terrain, "?") + " "
			else:
				output += "  "
		output += "\n"
	
	return output

# Uso
func _ready():
	var generator = ProceduralMapGenerator.new(12, 16)
	var map_data = generator.generate_map()
	
	var ascii_map = exportar_mapa_ascii(map_data, 12, 16)
	print("\n=== Mapa ASCII ===\n")
	print(ascii_map)
```

---

## Ejemplo 8: Generar Miniatura del Mapa

```gdscript
func generar_miniatura(map_data: Dictionary, width: int, height: int, pixel_size: int = 4) -> Image:
	var img_width = width * pixel_size
	var img_height = height * pixel_size
	var img = Image.create(img_width, img_height, false, Image.FORMAT_RGB8)
	
	for pos in map_data.keys():
		var terrain = map_data[pos]["terrain"]
		var elevation = map_data[pos]["elevation"]
		
		# Color base del terreno
		var color = TerrainType.get_color(terrain)
		
		# Ajustar brillo por elevación
		var brightness = 1.0 + (elevation * 0.15)
		color = color * brightness
		
		# Pintar píxeles
		var x = pos.x * pixel_size
		var y = pos.y * pixel_size
		
		for px in range(pixel_size):
			for py in range(pixel_size):
				img.set_pixel(x + px, y + py, color)
	
	return img

# Uso
func _ready():
	var generator = ProceduralMapGenerator.new(12, 16)
	var map_data = generator.generate_map()
	
	var miniatura = generar_miniatura(map_data, 12, 16, 8)
	var texture = ImageTexture.create_from_image(miniatura)
	
	# Mostrar en Sprite
	var sprite = Sprite2D.new()
	sprite.texture = texture
	add_child(sprite)
```

---

## Ejemplo 9: Estadísticas Detalladas

```gdscript
func analizar_mapa_detallado(map_data: Dictionary):
	var stats = {
		"total_hexes": map_data.size(),
		"terrenos": {},
		"elevaciones": {},
		"zonas": {},
		"min_elev": 999,
		"max_elev": -999,
		"hexes_transitables": 0
	}
	
	for pos in map_data.keys():
		var hex = map_data[pos]
		
		# Contar terrenos
		var terrain = hex["terrain"]
		stats["terrenos"][terrain] = stats["terrenos"].get(terrain, 0) + 1
		
		# Contar elevaciones
		var elev = hex["elevation"]
		stats["elevaciones"][elev] = stats["elevaciones"].get(elev, 0) + 1
		stats["min_elev"] = min(stats["min_elev"], elev)
		stats["max_elev"] = max(stats["max_elev"], elev)
		
		# Contar zonas
		if hex.has("zone"):
			var zone = hex["zone"]
			stats["zonas"][zone] = stats["zonas"].get(zone, 0) + 1
		
		# Contar transitables
		if hex["walkable"]:
			stats["hexes_transitables"] += 1
	
	# Imprimir reporte
	print("\n╔═══════════════════════════════════╗")
	print("║   ANÁLISIS DETALLADO DEL MAPA    ║")
	print("╚═══════════════════════════════════╝\n")
	
	print("📊 General:")
	print("  Total hexes: %d" % stats["total_hexes"])
	print("  Transitables: %d (%.1f%%)" % [
		stats["hexes_transitables"],
		float(stats["hexes_transitables"]) / float(stats["total_hexes"]) * 100.0
	])
	
	print("\n🏔️ Elevaciones:")
	print("  Rango: %d a %d niveles" % [stats["min_elev"], stats["max_elev"]])
	var sorted_elevs = stats["elevaciones"].keys()
	sorted_elevs.sort()
	for elev in sorted_elevs:
		var count = stats["elevaciones"][elev]
		var pct = float(count) / float(stats["total_hexes"]) * 100.0
		print("  Nivel %+d: %d hexes (%.1f%%)" % [elev, count, pct])
	
	print("\n🗺️ Terrenos:")
	for terrain in stats["terrenos"].keys():
		var count = stats["terrenos"][terrain]
		var pct = float(count) / float(stats["total_hexes"]) * 100.0
		print("  %s: %d hexes (%.1f%%)" % [
			TerrainType.get_name(terrain),
			count,
			pct
		])
	
	if not stats["zonas"].is_empty():
		print("\n🌍 Zonas:")
		var zone_names = {
			0: "Lowland",
			1: "Highland",
			2: "Mountain",
			3: "Water Zone",
			4: "Forest Zone",
			5: "Urban Zone"
		}
		for zone in stats["zonas"].keys():
			var count = stats["zonas"][zone]
			var pct = float(count) / float(stats["total_hexes"]) * 100.0
			print("  %s: %d hexes (%.1f%%)" % [
				zone_names.get(zone, "Unknown"),
				count,
				pct
			])
```

---

## Ejemplo 10: Validación de Mapa Balanceado

```gdscript
func validar_mapa_balanceado(map_data: Dictionary) -> Dictionary:
	var validacion = {
		"valido": true,
		"errores": [],
		"advertencias": []
	}
	
	# 1. Verificar variedad de terrenos (mínimo 3 tipos)
	var terrains = {}
	for pos in map_data.keys():
		terrains[map_data[pos]["terrain"]] = true
	
	if terrains.size() < 3:
		validacion["errores"].append("Muy poca variedad de terrenos (%d tipos)" % terrains.size())
		validacion["valido"] = false
	
	# 2. Verificar distribución de elevaciones
	var elevations = {}
	for pos in map_data.keys():
		var elev = map_data[pos]["elevation"]
		elevations[elev] = elevations.get(elev, 0) + 1
	
	# Al menos 2 niveles diferentes
	if elevations.size() < 2:
		validacion["advertencias"].append("Mapa muy plano (solo %d niveles)" % elevations.size())
	
	# 3. Verificar transiciones bruscas
	var transiciones_bruscas = 0
	for pos in map_data.keys():
		var elev = map_data[pos]["elevation"]
		for neighbor_pos in _get_neighbors(pos):
			if not map_data.has(neighbor_pos):
				continue
			var neigh_elev = map_data[neighbor_pos]["elevation"]
			if abs(elev - neigh_elev) >= 4:
				transiciones_bruscas += 1
	
	if transiciones_bruscas > 0:
		validacion["errores"].append("%d transiciones bruscas (≥4 niveles)" % transiciones_bruscas)
		validacion["valido"] = false
	
	# 4. Verificar que haya cobertura (bosques o edificios)
	var cobertura_count = 0
	for pos in map_data.keys():
		var terrain = map_data[pos]["terrain"]
		if terrain in [TerrainType.Type.LIGHT_WOODS, TerrainType.Type.HEAVY_WOODS, TerrainType.Type.BUILDING]:
			cobertura_count += 1
	
	var cobertura_pct = float(cobertura_count) / float(map_data.size()) * 100.0
	if cobertura_pct < 10.0:
		validacion["advertencias"].append("Poca cobertura disponible (%.1f%%)" % cobertura_pct)
	
	# 5. Verificar transitabilidad
	var walkable_count = 0
	for pos in map_data.keys():
		if map_data[pos]["walkable"]:
			walkable_count += 1
	
	var walkable_pct = float(walkable_count) / float(map_data.size()) * 100.0
	if walkable_pct < 70.0:
		validacion["advertencias"].append("Poco espacio transitable (%.1f%%)" % walkable_pct)
	
	return validacion

# Uso
func _ready():
	var generator = ProceduralMapGenerator.new(12, 16)
	var map_data = generator.generate_map()
	
	var val = validar_mapa_balanceado(map_data)
	
	if val["valido"]:
		print("✅ Mapa válido y balanceado")
	else:
		print("❌ Mapa no válido:")
		for error in val["errores"]:
			print("  - " + error)
	
	if not val["advertencias"].is_empty():
		print("⚠️ Advertencias:")
		for warning in val["advertencias"]:
			print("  - " + warning)

func _get_neighbors(hex: Vector2i) -> Array:
	const HEX_DIRECTIONS = [
		Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, 0)
	]
	var neighbors = []
	for dir in HEX_DIRECTIONS:
		neighbors.append(hex + dir)
	return neighbors
```

---

## 🎯 Consejos de Uso

1. **Siempre valida el mapa** antes de usarlo en producción
2. **Guarda el seed** si encuentras un mapa bueno
3. **Genera múltiples mapas** y elige el mejor
4. **Analiza las estadísticas** para entender la distribución
5. **Exporta a formato de texto** para debuggeo rápido

---

¡Estos ejemplos deberían cubrir la mayoría de casos de uso! 🚀
