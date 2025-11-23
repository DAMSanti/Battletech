extends RefCounted
class_name GameEnums

## Enumeraciones centralizadas del juego Battletech
## Este archivo contiene todos los enums compartidos entre diferentes sistemas
## IMPORTANTE: Esta clase solo contiene enums y funciones estáticas

## Estados del juego en la batalla
enum GameState {
	MOVING,              # Fase de movimiento
	TARGETING,           # Seleccionando objetivo (obsoleto, usar WEAPON_ATTACK)
	WEAPON_ATTACK,       # Fase de ataque con armas
	PHYSICAL_TARGETING,  # Fase de ataque físico
	ENEMY_TURN,          # Turno enemigo
	ANIMATION            # Reproduciendo animación
}

## Fases del turno en Battletech
enum TurnPhase {
	INITIATIVE,       # Tirada de iniciativa
	MOVEMENT,         # Fase de movimiento
	WEAPON_ATTACK,    # Fase de ataque con armas
	PHYSICAL_ATTACK,  # Fase de ataque físico
	HEAT,             # Fase de disipación de calor
	END               # Fin del turno
}

## Tipos de movimiento disponibles para mechs
enum MovementType {
	NONE,   # Sin movimiento
	WALK,   # Caminar (1 MP por hex) - Penaliza -1 a impactar
	RUN,    # Correr (2 MP por hex) - Penaliza -2 a impactar tú, +2 te impactan
	JUMP    # Saltar (1 MP por hex) - Ignora terreno, penalizadores más altos
}

## Tipos de terreno detallados según BattleTech
enum TerrainSubtype {
	# Terrestres básicos
	CLEAR_FLAT,          # Terreno despejado (coste +0)
	LIGHT_WOODS,         # Bosque ligero (coste +1, da cobertura)
	HEAVY_WOODS,         # Bosque denso (coste +2, mucha cobertura)
	
	# Colinas por nivel
	HILL_LEVEL_1,        # Colina nivel +1 (coste +1 al subir)
	HILL_LEVEL_2,        # Colina nivel +2 (coste +1 por nivel)
	
	# Acuáticos
	WATER_DEPTH_1,       # Agua poco profunda (coste +1)
	WATER_DEPTH_2,       # Agua profunda (no accesible caminando)
	
	# Difíciles
	ROUGH_TERRAIN,       # Terreno difícil (coste +1, prohíbe correr)
	BOG_SWAMP,           # Pantanoso (coste +1 + chequeo pilotaje)
	RUBBLE,              # Escombros (coste +2 + chequeo)
	
	# Urbano
	ROAD,                # Carretera (coste -1, mínimo 1)
	PAVEMENT,            # Pavimento (coste base)
	BUILDING,            # Edificio (coste +1 + chequeo)
	
	# Prohibidos
	CLIFF,               # Acantilado (no transitable)
	ABYSS,               # Abismo (no transitable)
	OUT_OF_BOUNDS        # Fuera del mapa
}

## Tipos de ataque físico
enum PhysicalAttackType {
	PUNCH,   # Puñetazo
	KICK,    # Patada
	CHARGE,  # Embestida
	PUSH,    # Empujón
	DFA      # Death From Above (saltar sobre el enemigo)
}

## Localizaciones del mech (para damage)
enum HitLocation {
	HEAD,
	CENTER_TORSO,
	LEFT_TORSO,
	RIGHT_TORSO,
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_LEG,
	RIGHT_LEG
}

## Convertir string a HitLocation enum
static func location_string_to_enum(location: String) -> HitLocation:
	match location:
		"head":
			return HitLocation.HEAD
		"center_torso":
			return HitLocation.CENTER_TORSO
		"left_torso":
			return HitLocation.LEFT_TORSO
		"right_torso":
			return HitLocation.RIGHT_TORSO
		"left_arm":
			return HitLocation.LEFT_ARM
		"right_arm":
			return HitLocation.RIGHT_ARM
		"left_leg":
			return HitLocation.LEFT_LEG
		"right_leg":
			return HitLocation.RIGHT_LEG
		_:
			return HitLocation.CENTER_TORSO

## Convertir HitLocation enum a string
static func location_enum_to_string(location: HitLocation) -> String:
	match location:
		HitLocation.HEAD:
			return "head"
		HitLocation.CENTER_TORSO:
			return "center_torso"
		HitLocation.LEFT_TORSO:
			return "left_torso"
		HitLocation.RIGHT_TORSO:
			return "right_torso"
		HitLocation.LEFT_ARM:
			return "left_arm"
		HitLocation.RIGHT_ARM:
			return "right_arm"
		HitLocation.LEFT_LEG:
			return "left_leg"
		HitLocation.RIGHT_LEG:
			return "right_leg"
		_:
			return "center_torso"

## Obtener nombre legible del tipo de movimiento
static func movement_type_to_string(move_type: MovementType) -> String:
	match move_type:
		MovementType.NONE:
			return "None"
		MovementType.WALK:
			return "Walk"
		MovementType.RUN:
			return "Run"
		MovementType.JUMP:
			return "Jump"
		_:
			return "Unknown"

## Obtener nombre legible de fase
static func phase_to_string(phase: TurnPhase) -> String:
	match phase:
		TurnPhase.INITIATIVE:
			return "Initiative"
		TurnPhase.MOVEMENT:
			return "Movement"
		TurnPhase.WEAPON_ATTACK:
			return "Weapon Attack"
		TurnPhase.PHYSICAL_ATTACK:
			return "Physical Attack"
		TurnPhase.HEAT:
			return "Heat"
		TurnPhase.END:
			return "End"
		_:
			return "Unknown"
