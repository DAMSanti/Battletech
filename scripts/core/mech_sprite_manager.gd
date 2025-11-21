extends Node

class_name MechSpriteManager

# Enum para los tipos de mechs
enum MechClass {
	LIGHT,
	MEDIUM,
	ASSAULT
}

# Dictionary para mapear tonelaje a clase de mech
const TONNAGE_TO_CLASS = {
	# Light: 20-35 tons
	"20-35": MechClass.LIGHT,
	# Medium: 40-55 tons
	"40-55": MechClass.MEDIUM,
	# Heavy/Assault: 60-100 tons
	"60-100": MechClass.ASSAULT
}

# Paths base para los sprites
const BASE_PATH = "res://assets/sprites/mechs/red/"
const SPRITE_PATHS = {
	MechClass.LIGHT: BASE_PATH + "light/",
	MechClass.MEDIUM: BASE_PATH + "medium/",
	MechClass.ASSAULT: BASE_PATH + "assault/"
}

# Debug info
func _init():
	print("[MechSpriteManager] Initialized")
	print("[MechSpriteManager] Base path: ", BASE_PATH)
	# Verificar que los directorios existen
	for mech_class in SPRITE_PATHS.keys():
		var dir = SPRITE_PATHS[mech_class]
		print("[MechSpriteManager] Checking directory: ", dir)

# Mapping de facing hexagonal (6 direcciones) a índice de sprite (8 direcciones)
# Facing hexagonal: 0=N, 1=NE, 2=SE, 3=S, 4=SW, 5=NW
# Sprites: 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW
const FACING_TO_SPRITE = {
	0: 0,  # Norte -> Norte
	1: 1,  # Noreste -> Noreste
	2: 3,  # Sureste (hex) -> Sureste (sprite)
	3: 4,  # Sur -> Sur
	4: 5,  # Suroeste -> Suroeste
	5: 7   # Noroeste -> Noroeste
}

# Cache de texturas
var _texture_cache = {}

func get_mech_class(tonnage: int) -> int:
	# Determinar la clase basada en el tonelaje
	if tonnage <= 35:
		return MechClass.LIGHT
	elif tonnage <= 55:
		return MechClass.MEDIUM
	else:
		return MechClass.ASSAULT

func get_sprite_for_mech(tonnage: int, facing: int) -> Texture2D:
	var mech_class = get_mech_class(tonnage)
	var base_path = SPRITE_PATHS[mech_class]
	
	# Normalizar el facing a 6 direcciones hexagonales (0-5)
	var normalized_facing = facing % 6
	
	# Convertir facing hexagonal a índice de sprite (8 direcciones)
	var sprite_index = FACING_TO_SPRITE[normalized_facing]
	var sprite_name = "mech_%d.png" % sprite_index
	var full_path = base_path + sprite_name
	
	# Check cache first
	if _texture_cache.has(full_path):
		return _texture_cache[full_path]
	
	# Load and cache texture
	var texture = load(full_path)
	if texture:
		_texture_cache[full_path] = texture
	
	return texture

func clear_cache():
	_texture_cache.clear()