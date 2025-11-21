class_name TerrainType
extends RefCounted

## Tipos de terreno con sus propiedades
## Responsabilidad: Definir características de cada terreno

enum Type {
	CLEAR,      # Terreno despejado
	FOREST,     # Bosque - dificulta movimiento, ofrece cobertura
	WATER,      # Agua - dificulta mucho el movimiento, penaliza ataque
	ROUGH,      # Terreno difícil - rocas, escombros
	PAVEMENT,   # Pavimento - facilita movimiento
	SAND,       # Arena - dificulta movimiento moderadamente
	ICE,        # Hielo - muy resbaladizo
	BUILDING,   # Edificio - cobertura total, dificulta movimiento
	HILL        # Colina - ventaja de altura
}

# Propiedades de cada terreno
const TERRAIN_DATA = {
	Type.CLEAR: {
		"name": "Clear",
		"name_es": "Despejado",
		"movement_cost": 1,
		"defense_bonus": 0,
		"to_hit_modifier": 0,
		"blocks_los": false,
		"color": Color(0.4, 0.7, 0.3),  # Verde claro
		"symbol": "·",
		"icon": "",  # Sin icono para terreno despejado
		"description": "Terreno abierto sin obstáculos"
	},
	Type.FOREST: {
		"name": "Forest",
		"name_es": "Bosque",
		"movement_cost": 2,
		"defense_bonus": 1,
		"to_hit_modifier": 1,
		"blocks_los": false,
		"color": Color(0.2, 0.5, 0.2),  # Verde oscuro
		"symbol": "♣",
		"icon": "res://assets/sprites/terrain/tree.svg",
		"description": "Bosque denso que dificulta el movimiento y proporciona cobertura"
	},
	Type.WATER: {
		"name": "Water",
		"name_es": "Agua",
		"movement_cost": 4,
		"defense_bonus": 0,
		"to_hit_modifier": 2,
		"blocks_los": false,
		"color": Color(0.2, 0.4, 0.8),  # Azul
		"symbol": "≈",
		"icon": "res://assets/sprites/terrain/water.svg",
		"description": "Agua profunda que ralentiza mucho el movimiento"
	},
	Type.ROUGH: {
		"name": "Rough",
		"name_es": "Difícil",
		"movement_cost": 2,
		"defense_bonus": 0,
		"to_hit_modifier": 0,
		"blocks_los": false,
		"color": Color(0.5, 0.4, 0.3),  # Marrón
		"symbol": "◆",
		"icon": "res://assets/sprites/terrain/mountain.svg",
		"description": "Terreno irregular con rocas y escombros"
	},
	Type.PAVEMENT: {
		"name": "Pavement",
		"name_es": "Pavimento",
		"movement_cost": 1,
		"defense_bonus": 0,
		"to_hit_modifier": 0,
		"blocks_los": false,
		"color": Color(0.4, 0.4, 0.4),  # Gris
		"symbol": "▬",
		"icon": "res://assets/sprites/terrain/pavement.svg",
		"description": "Superficie pavimentada, ideal para movimiento"
	},
	Type.SAND: {
		"name": "Sand",
		"name_es": "Arena",
		"movement_cost": 2,
		"defense_bonus": 0,
		"to_hit_modifier": 0,
		"blocks_los": false,
		"color": Color(0.9, 0.8, 0.5),  # Amarillo arena
		"symbol": "∴",
		"icon": "res://assets/sprites/terrain/cactus.svg",
		"description": "Arena suelta que dificulta el movimiento"
	},
	Type.ICE: {
		"name": "Ice",
		"name_es": "Hielo",
		"movement_cost": 1,
		"defense_bonus": 0,
		"to_hit_modifier": 0,
		"blocks_los": false,
		"color": Color(0.7, 0.9, 1.0),  # Azul claro
		"symbol": "❄",
		"icon": "res://assets/sprites/terrain/ice.svg",
		"description": "Hielo resbaladizo - requiere chequeos de pilotaje",
		"special": "piloting_check_on_move"
	},
	Type.BUILDING: {
		"name": "Building",
		"name_es": "Edificio",
		"movement_cost": 3,
		"defense_bonus": 2,
		"to_hit_modifier": 2,
		"blocks_los": true,
		"color": Color(0.6, 0.6, 0.6),  # Gris oscuro
		"symbol": "■",
		"icon": "res://assets/sprites/terrain/building.svg",
		"description": "Edificio que proporciona cobertura pesada"
	},
	Type.HILL: {
		"name": "Hill",
		"name_es": "Colina",
		"movement_cost": 2,
		"defense_bonus": 0,
		"to_hit_modifier": -1,
		"blocks_los": false,
		"color": Color(0.6, 0.5, 0.3),  # Marrón claro
		"symbol": "▴",
		"icon": "res://assets/sprites/terrain/hill.svg",
		"description": "Elevación que proporciona ventaja de altura",
		"special": "height_advantage"
	}
}

static func get_movement_cost(terrain_type: Type) -> int:
	return TERRAIN_DATA[terrain_type]["movement_cost"]

static func get_defense_bonus(terrain_type: Type) -> int:
	return TERRAIN_DATA[terrain_type]["defense_bonus"]

static func get_to_hit_modifier(terrain_type: Type) -> int:
	return TERRAIN_DATA[terrain_type]["to_hit_modifier"]

static func blocks_line_of_sight(terrain_type: Type) -> bool:
	return TERRAIN_DATA[terrain_type]["blocks_los"]

static func get_color(terrain_type: Type) -> Color:
	return TERRAIN_DATA[terrain_type]["color"]

static func get_symbol(terrain_type: Type) -> String:
	return TERRAIN_DATA[terrain_type]["symbol"]

static func get_name(terrain_type: Type, spanish: bool = true) -> String:
	if spanish:
		return TERRAIN_DATA[terrain_type]["name_es"]
	return TERRAIN_DATA[terrain_type]["name"]

static func get_description(terrain_type: Type) -> String:
	return TERRAIN_DATA[terrain_type]["description"]

static func has_special_rule(terrain_type: Type) -> bool:
	return TERRAIN_DATA[terrain_type].has("special")

static func get_special_rule(terrain_type: Type) -> String:
	if has_special_rule(terrain_type):
		return TERRAIN_DATA[terrain_type]["special"]
	return ""

static func get_icon(terrain_type: Type) -> String:
	return TERRAIN_DATA[terrain_type]["icon"]
