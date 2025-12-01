class_name TerrainDecoration
extends Sprite2D

## Decoración visual para tiles de terreno (árboles, rocas, edificios, etc.)

enum DecorationType {
	TREE_SINGLE,      # Árbol individual
	TREE_CLUSTER,     # Grupo de árboles
	ROCK_SMALL,       # Roca pequeña
	ROCK_LARGE,       # Roca grande/montaña
	BUILDING_SMALL,   # Edificio bajo
	BUILDING_MEDIUM,  # Edificio mediano
	BUILDING_TALL,    # Rascacielos
	CACTUS,           # Cactus (terreno árido)
	BUSH,             # Arbusto
	WATER_PLANT       # Planta acuática
}

var decoration_type: DecorationType
var terrain_type: TerrainType.Type

# Base de datos de decoraciones por tipo de terreno
# Usando los SVG existentes como placeholders
const DECORATION_PATHS = {
	DecorationType.TREE_SINGLE: "res://assets/sprites/terrain/tree.svg",
	DecorationType.TREE_CLUSTER: "res://assets/sprites/terrain/tree.svg",
	DecorationType.ROCK_SMALL: "res://assets/sprites/terrain/mountain.svg",
	DecorationType.ROCK_LARGE: "res://assets/sprites/terrain/mountain.svg",
	DecorationType.BUILDING_SMALL: "res://assets/sprites/terrain/building.svg",
	DecorationType.BUILDING_MEDIUM: "res://assets/sprites/terrain/building.svg",
	DecorationType.BUILDING_TALL: "res://assets/sprites/terrain/building.svg",
	DecorationType.CACTUS: "res://assets/sprites/terrain/cactus.svg",
	DecorationType.BUSH: "res://assets/sprites/terrain/tree.svg",
	DecorationType.WATER_PLANT: "res://assets/sprites/terrain/water.svg"
}

# Escalas por tipo de decoración
const DECORATION_SCALES = {
	DecorationType.TREE_SINGLE: Vector2(0.6, 0.6),      # Árbol individual más pequeño
	DecorationType.TREE_CLUSTER: Vector2(1.0, 1.0),     # Cluster de tamaño normal
	DecorationType.ROCK_SMALL: Vector2(0.4, 0.4),       # Roca pequeña
	DecorationType.ROCK_LARGE: Vector2(1.2, 1.2),       # Roca grande
	DecorationType.BUILDING_SMALL: Vector2(0.8, 0.8),   # Edificio pequeño
	DecorationType.BUILDING_MEDIUM: Vector2(1.0, 1.0),  # Edificio mediano
	DecorationType.BUILDING_TALL: Vector2(1.2, 1.5),    # Edificio alto (más vertical)
	DecorationType.CACTUS: Vector2(0.5, 0.5),           # Cactus pequeño
	DecorationType.BUSH: Vector2(0.4, 0.4),             # Arbusto pequeño
	DecorationType.WATER_PLANT: Vector2(0.3, 0.3)       # Planta acuática pequeña
}

# Offset Y para centrar visualmente (más alto = más arriba)
const DECORATION_Y_OFFSETS = {
	DecorationType.TREE_SINGLE: -25,
	DecorationType.TREE_CLUSTER: -30,
	DecorationType.ROCK_SMALL: -8,
	DecorationType.ROCK_LARGE: -40,
	DecorationType.BUILDING_SMALL: -20,
	DecorationType.BUILDING_MEDIUM: -25,
	DecorationType.BUILDING_TALL: -35,
	DecorationType.CACTUS: -15,
	DecorationType.BUSH: -8,
	DecorationType.WATER_PLANT: 0
}

func _init(type: DecorationType, terrain: TerrainType.Type):
	decoration_type = type
	terrain_type = terrain
	
	# Configurar sprite
	centered = true
	
	# Cargar textura (si existe)
	var texture_path = DECORATION_PATHS.get(type, "")
	if texture_path != "" and ResourceLoader.exists(texture_path):
		texture = load(texture_path)
		Log.debug("System", "Loaded decoration texture", {"path": texture_path})
	else:
		Log.error("System", "Decoration texture not found", {"path": texture_path})
	
	# Aplicar escala
	scale = DECORATION_SCALES.get(type, Vector2.ONE)
	
	# Z-index MUY alto para que aparezca sobre las tiles
	# z_as_relative = false hace que el z_index sea ABSOLUTO, no relativo al padre
	z_index = 10
	z_as_relative = false  # ✅ CRÍTICO: No heredar z_index del HexGrid (que está en 0)
	
	# Ajuste visual hacia arriba (se aplicará después con adjust_for_elevation)
	# NO aplicar aquí porque position aún no está seteado
	# position.y += DECORATION_Y_OFFSETS.get(type, 0)

## Obtener decoraciones apropiadas para un tipo de terreno
static func get_decorations_for_terrain(terrain: TerrainType.Type) -> Array:
	match terrain:
		TerrainType.Type.FOREST:
			return [
				DecorationType.TREE_SINGLE,
				DecorationType.TREE_CLUSTER,
				DecorationType.BUSH
			]
		
		TerrainType.Type.ROUGH:
			return [
				DecorationType.ROCK_SMALL,
				DecorationType.ROCK_LARGE
			]
		
		TerrainType.Type.HILL:
			return [
				DecorationType.ROCK_SMALL,
				DecorationType.BUSH
			]
		
		TerrainType.Type.SAND:
			return [
				DecorationType.CACTUS,
				DecorationType.ROCK_SMALL
			]
		
		TerrainType.Type.BUILDING:
			return [
				DecorationType.BUILDING_SMALL,
				DecorationType.BUILDING_MEDIUM,
				DecorationType.BUILDING_TALL
			]
		
		TerrainType.Type.WATER:
			return [
				DecorationType.WATER_PLANT
			]
		
		_:
			return []

## Crear decoración aleatoria apropiada para el terreno
static func create_random_for_terrain(terrain: TerrainType.Type) -> TerrainDecoration:
	var available = get_decorations_for_terrain(terrain)
	if available.is_empty():
		return null
	
	var random_type = available[randi() % available.size()]
	return TerrainDecoration.new(random_type, terrain)

## Ajustar posición según elevación del hex
func adjust_for_elevation(elevation: int, base_elevation: int = -2):
	# Ajustar Y según elevación (10 píxeles por nivel)
	position.y -= (elevation - base_elevation) * 10.0
	
	# Aplicar offset Y del tipo de decoración
	var y_offset = DECORATION_Y_OFFSETS.get(decoration_type, 0)
	position.y += y_offset

## Añadir variación aleatoria (escala, rotación leve)
func add_random_variation():
	# Pequeña variación en escala (±10%)
	var scale_variation = randf_range(0.9, 1.1)
	scale *= scale_variation
	
	# Pequeña rotación (±5 grados) para variedad
	rotation = deg_to_rad(randf_range(-5, 5))
	
	# Pequeño offset en posición (±5 píxeles)
	position.x += randf_range(-5, 5)
	position.y += randf_range(-5, 5)
