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
	WALK,   # Caminar (sin penalizaciones)
	RUN,    # Correr (+1 defensa, +2 atacar)
	JUMP    # Saltar (+2 defensa, +3 atacar)
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
