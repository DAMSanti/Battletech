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
	HILL,       # Colina - ventaja de altura
	LIGHT_WOODS, # Bosque ligero (menor coste que FOREST)
	HEAVY_WOODS, # Bosque denso (mayor coste que FOREST)
	BOG,         # Pantano
	ROAD,        # Carretera (reduce coste)
	RUBBLE       # Escombros
}

# Propiedades de cada terreno
const TERRAIN_DATA = {
	Type.CLEAR: {
		"name": "Clear",
		"name_es": "Despejado",
		"movement_cost": 1,
		"walk_cost": 1,      # BattleTech: 1 MP
		"run_cost": 1,       # BattleTech: mismo costo que walk (solo cambia MPs totales)
		"jump_cost": 1,      # BattleTech: 1 MP saltando
		"defense_bonus": 0,
		"to_hit_modifier": 0,
		"blocks_los": false,
		"color": Color(0.4, 0.7, 0.3),  # Verde claro
		"symbol": "·",
		"icon": "",  # Sin icono para terreno despejado
		"description": "Terreno abierto sin obstáculos"
	},
	Type.LIGHT_WOODS: {
		"name": "Light Woods",
		"name_es": "Bosque Ligero",
		"movement_cost": 2,
		"walk_cost": 2,      # BattleTech: 2 MP
		"run_cost": 2,       # Mismo costo que walk
		"jump_cost": 1,      # Saltar ignora terreno
		"defense_bonus": 1,
		"to_hit_modifier": 1,  # +1 por cada hex atravesado
		"blocks_los": false,
		"reduces_los": true,
		"los_height": 1,     # Añade 1 nivel de altura para LoS
		"color": Color(0.3, 0.6, 0.3),  # Verde medio
		"symbol": "♠",
		"icon": "res://assets/sprites/terrain/tree.svg",
		"description": "Bosque ligero - +1 por cada hex atravesado"
	},
	Type.HEAVY_WOODS: {
		"name": "Heavy Woods",
		"name_es": "Bosque Denso",
		"movement_cost": 3,
		"walk_cost": 3,      # BattleTech: 3 MP
		"run_cost": 3,       # Mismo costo que walk
		"jump_cost": 1,      # Saltar ignora terreno
		"defense_bonus": 2,
		"to_hit_modifier": 2,  # +2 si atraviesa 1 hex, bloquea si 2+
		"blocks_los": false,  # No bloquea directamente (ver reglas especiales)
		"reduces_los": true,
		"los_height": 2,     # Añade 2 niveles de altura para LoS
		"blocks_after_count": 2,  # Bloquea si atraviesas 2+ hexes
		"prohibits_running": false,
		"color": Color(0.2, 0.5, 0.2),  # Verde oscuro
		"symbol": "♣",
		"icon": "res://assets/sprites/terrain/tree.svg",
		"description": "Bosque denso - +2 si atraviesa 1 hex, bloquea si 2+"
	},
	Type.FOREST: {
		"name": "Forest",
		"name_es": "Bosque",
		"movement_cost": 2,
		"walk_cost": 2,
		"run_cost": 2,       # Mismo costo que walk
		"jump_cost": 1,
		"defense_bonus": 1,
		"to_hit_modifier": 2,  # Tratado como Heavy Woods
		"blocks_los": false,
		"los_height": 2,     # Añade 2 niveles como Heavy Woods
		"blocks_after_count": 2,  # Bloquea si atraviesas 2+ hexes
		"color": Color(0.2, 0.5, 0.2),  # Verde oscuro
		"symbol": "♣",
		"icon": "res://assets/sprites/terrain/tree.svg",
		"description": "Bosque denso - +2 si atraviesa 1 hex, bloquea si 2+"
	},
	Type.WATER: {
		"name": "Water",
		"name_es": "Agua",
		"movement_cost": 2,
		"walk_cost": 2,      # Agua poco profunda: 2 MP
		"run_cost": 2,       # Mismo costo que walk
		"jump_cost": 1,      # Saltar ignora terreno
		"depth": 1,          # Profundidad en niveles
		"defense_bonus": 0,
		"to_hit_modifier": 1,
		"blocks_los": false,
		"color": Color(0.2, 0.4, 0.8),  # Azul
		"symbol": "≈",
		"icon": "res://assets/sprites/terrain/water.svg",
		"description": "Agua poco profunda - Mechs pueden entrar, vehículos a veces no"
	},
	Type.ROUGH: {
		"name": "Rough",
		"name_es": "Difícil",
		"movement_cost": 2,
		"walk_cost": 2,      # BattleTech: 2 MP
		"run_cost": 2,       # Mismo costo que walk
		"jump_cost": 1,      # Saltar ignora terreno
		"prohibits_running": true,  # Según edición
		"defense_bonus": 0,
		"to_hit_modifier": 0,
		"blocks_los": false,
		"color": Color(0.5, 0.4, 0.3),  # Marrón
		"symbol": "◆",
		"icon": "res://assets/sprites/terrain/mountain.svg",
		"description": "Terreno irregular - puede prohibir correr"
	},
	Type.BOG: {
		"name": "Bog/Swamp",
		"name_es": "Pantano",
		"movement_cost": 2,
		"walk_cost": 2,      # BattleTech: 2 MP
		"run_cost": 2,       # Mismo costo que walk
		"jump_cost": 1,      # Saltar ignora terreno
		"defense_bonus": 0,
		"to_hit_modifier": 0,
		"requires_piloting_check": true,  # Riesgo de atascarse
		"blocks_los": false,
		"color": Color(0.4, 0.5, 0.3),  # Verde pantanoso
		"symbol": "≋",
		"icon": "res://assets/sprites/terrain/water.svg",
		"description": "Pantano - requiere chequeo de pilotaje o te atascas"
	},
	Type.RUBBLE: {
		"name": "Rubble",
		"name_es": "Escombros",
		"movement_cost": 3,
		"walk_cost": 3,      # BattleTech: 3 MP
		"run_cost": 3,       # Mismo costo que walk
		"jump_cost": 1,      # Saltar ignora terreno
		"requires_piloting_check": true,
		"defense_bonus": 1,
		"to_hit_modifier": 0,
		"blocks_los": false,
		"color": Color(0.5, 0.5, 0.5),  # Gris
		"symbol": "▒",
		"icon": "res://assets/sprites/terrain/mountain.svg",
		"description": "Escombros - coste +2 y chequeo de pilotaje"
	},
	Type.ROAD: {
		"name": "Road",
		"name_es": "Carretera",
		"movement_cost": 1,
		"walk_cost": 0,      # -1 al coste (mínimo 1 total)
		"run_cost": 0,       # Mismo costo que walk (mínimo 1 total)
		"jump_cost": 1,      # Saltar no beneficia de carretera
		"cost_modifier": -1, # Reduce coste en 1 (mínimo 1)
		"defense_bonus": 0,
		"to_hit_modifier": 0,
		"blocks_los": false,
		"color": Color(0.3, 0.3, 0.3),  # Gris oscuro
		"symbol": "═",
		"icon": "res://assets/sprites/terrain/pavement.svg",
		"description": "Carretera - reduce coste de movimiento (mínimo 1)"
	},
	Type.PAVEMENT: {
		"name": "Pavement",
		"name_es": "Pavimento",
		"movement_cost": 1,
		"walk_cost": 1,
		"run_cost": 1,       # Mismo costo que walk
		"jump_cost": 1,
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
		"walk_cost": 2,
		"run_cost": 2,       # Mismo costo que walk
		"jump_cost": 1,
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
		"walk_cost": 1,
		"run_cost": 1,       # Mismo costo que walk
		"jump_cost": 1,
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
		"movement_cost": 2,
		"walk_cost": 2,      # BattleTech: 2 MP entrar
		"run_cost": 2,       # Mismo costo que walk
		"jump_cost": 1,      # Saltar a edificio (según altura)
		"requires_piloting_check": true,
		"defense_bonus": 2,
		"to_hit_modifier": 2,
		"blocks_los": true,  # Bloquea si es más alto que la línea
		"los_height": 3,     # Añade 3 niveles base (más elevación)
		"color": Color(0.6, 0.6, 0.6),  # Gris oscuro
		"symbol": "■",
		"icon": "res://assets/sprites/terrain/building.svg",
		"description": "Edificio - bloquea LoS si más alto que línea de visión"
	},
	Type.HILL: {
		"name": "Hill",
		"name_es": "Colina",
		"movement_cost": 2,
		"walk_cost": 1,      # +1 por cada nivel ascendido (bajar=0)
		"run_cost": 1,       # Mismo costo que walk, +1 por nivel
		"jump_cost": 1,      # Saltar ignora coste de elevación
		"elevation_cost_per_level": 1,  # +1 MP por nivel al subir
		"defense_bonus": 0,
		"to_hit_modifier": -1,
		"blocks_los": false,
		"color": Color(0.6, 0.5, 0.3),  # Marrón claro
		"symbol": "▴",
		"icon": "res://assets/sprites/terrain/hill.svg",
		"description": "Elevación - coste +1 MP por nivel al subir (bajar gratis)",
		"special": "height_advantage"
	}
}

static func get_movement_cost(terrain_type: Type) -> int:
	return TERRAIN_DATA[terrain_type]["movement_cost"]

## Obtener coste de movimiento según el tipo (walk, run, jump)
static func get_movement_cost_by_type(terrain_type: Type, movement_type: int) -> int:
	var data = TERRAIN_DATA[terrain_type]
	
	# movement_type: 1=WALK, 2=RUN, 3=JUMP (desde GameEnums.MovementType)
	# IMPORTANTE: En BattleTech, el costo por hex es el MISMO para Walk y Run
	# Solo cambia el total de MPs disponibles (Run = 1.5x Walk)
	match movement_type:
		1:  # WALK
			return data.get("walk_cost", data["movement_cost"])
		2:  # RUN - mismo costo que Walk
			return data.get("run_cost", data.get("walk_cost", data["movement_cost"]))
		3:  # JUMP
			return data.get("jump_cost", 1)
		_:
			return data["movement_cost"]

## Verificar si el terreno requiere chequeo de pilotaje
static func requires_piloting_check(terrain_type: Type) -> bool:
	return TERRAIN_DATA[terrain_type].get("requires_piloting_check", false)

## Verificar si el terreno prohíbe correr
static func prohibits_running(terrain_type: Type) -> bool:
	return TERRAIN_DATA[terrain_type].get("prohibits_running", false)

## Obtener modificador de coste (para carreteras = -1)
static func get_cost_modifier(terrain_type: Type) -> int:
	return TERRAIN_DATA[terrain_type].get("cost_modifier", 0)

## Obtener profundidad del agua
static func get_water_depth(terrain_type: Type) -> int:
	return TERRAIN_DATA[terrain_type].get("depth", 0)

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

## Obtener altura LoS del terreno (para cálculo de visibilidad)
static func get_los_height(terrain_type: Type) -> int:
	return TERRAIN_DATA[terrain_type].get("los_height", 0)

## Verificar si reduce LoS (bosques)
static func reduces_los(terrain_type: Type) -> bool:
	return TERRAIN_DATA[terrain_type].get("reduces_los", false)

## Obtener cuenta de bloqueo (cuántos hexes antes de bloquear)
static func get_blocks_after_count(terrain_type: Type) -> int:
	return TERRAIN_DATA[terrain_type].get("blocks_after_count", 1)
