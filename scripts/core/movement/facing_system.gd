class_name FacingSystem
extends RefCounted

## Sistema de orientación y giro para BattleTech
## Maneja facing de hexágonos (6 direcciones) y costes de giro

## Constantes de facing (0-5, representan las 6 facetas del hexágono)
## Para flat-top hexagons:
## 0 = Norte (N), 1 = Noreste (NE), 2 = Sureste (SE)
## 3 = Sur (S), 4 = Suroeste (SW), 5 = Noroeste (NW)
enum Facing {
	NORTH = 0,      # N
	NORTHEAST = 1,  # NE
	SOUTHEAST = 2,  # SE
	SOUTH = 3,      # S
	SOUTHWEST = 4,  # SW
	NORTHWEST = 5   # NW
}

## Nombres de direcciones en español
const FACING_NAMES_ES = {
	Facing.NORTH: "Norte",
	Facing.NORTHEAST: "Noreste",
	Facing.SOUTHEAST: "Sureste",
	Facing.SOUTH: "Sur",
	Facing.SOUTHWEST: "Suroeste",
	Facing.NORTHWEST: "Noroeste"
}

## Ángulos para cada facing (en grados)
const FACING_ANGLES = {
	Facing.NORTH: -90,      # Apuntando hacia arriba
	Facing.NORTHEAST: -30,
	Facing.SOUTHEAST: 30,
	Facing.SOUTH: 90,       # Apuntando hacia abajo
	Facing.SOUTHWEST: 150,
	Facing.NORTHWEST: -150
}

## Calcular coste de MP por girar
## BattleTech clásico: girar NO cuesta MPs durante el movimiento
## Pero girar sin moverse puede costar 1 MP en algunas variantes
static func get_rotation_cost(from_facing: int, to_facing: int, is_moving: bool = true) -> int:
	if from_facing == to_facing:
		return 0  # Sin giro, sin coste
	
	# En BattleTech clásico, girar durante el movimiento NO cuesta MPs
	if is_moving:
		return 0
	
	# Girar sin moverse (cambiar facing estático) puede costar 1 MP
	# Esto es opcional según variante de reglas
	var _hexsides_turned = get_hexsides_turned(from_facing, to_facing)
	
	# Opción 1: Sin coste (regla estándar)
	return 0
	
	# Opción 2: 1 MP por cualquier giro sin moverse (regla opcional)
	# return 1 if hexsides_turned > 0 else 0

## Calcular cuántas facetas se gira (camino más corto)
static func get_hexsides_turned(from_facing: int, to_facing: int) -> int:
	var diff = abs(to_facing - from_facing)
	
	# Tomar el camino más corto (máximo 3 facetas)
	if diff > 3:
		diff = 6 - diff
	
	return diff

## Normalizar facing a rango 0-5
static func normalize_facing(facing: int) -> int:
	facing = facing % 6
	if facing < 0:
		facing += 6
	return facing

## Girar facing en N facetas (sentido horario = positivo)
static func rotate_facing(current_facing: int, hexsides: int) -> int:
	return normalize_facing(current_facing + hexsides)

## Obtener facing opuesto (180 grados)
static func get_opposite_facing(facing: int) -> int:
	return normalize_facing(facing + 3)

## Calcular facing hacia un hex objetivo
static func get_facing_to_hex(from_hex: Vector2i, to_hex: Vector2i) -> int:
	var delta = to_hex - from_hex

	# Explicit mapping for flat-top axial neighbor deltas used by HexGrid
	# HexGrid.HEX_DIRECTIONS (flat-top) used in this project:
	# 0: ( 0,-1) -> NORTH
	# 1: ( 1,-1) -> NORTHEAST
	# 2: (-1, 0) -> NORTHWEST
	# 3: ( 0, 1) -> SOUTH
	# 4: (-1, 1) -> SOUTHWEST
	# 5: ( 1, 0) -> SOUTHEAST

	if delta == Vector2i(0, -1):
		return Facing.NORTH
	elif delta == Vector2i(1, -1):
		return Facing.NORTHEAST
	elif delta == Vector2i(1, 0):
		return Facing.SOUTHEAST
	elif delta == Vector2i(0, 1):
		return Facing.SOUTH
	elif delta == Vector2i(-1, 1):
		return Facing.SOUTHWEST
	elif delta == Vector2i(-1, 0):
		return Facing.NORTHWEST

	# Fallback: calculate by sign heuristics for non-adjacent deltas
	if delta.x == 0:
		return Facing.NORTH if delta.y < 0 else Facing.SOUTH
	elif delta.x > 0:
		return Facing.NORTHEAST if delta.y < 0 else Facing.SOUTHEAST
	else:
		return Facing.NORTHWEST if delta.y < 0 else Facing.SOUTHWEST

## Verificar si un hex está en el arco frontal del mech
## Frontal = facing ± 1 faceta (3 facetas frontales en total)
static func is_in_front_arc(mech_facing: int, target_hex: Vector2i, mech_hex: Vector2i) -> bool:
	var facing_to_target = get_facing_to_hex(mech_hex, target_hex)
	var diff = get_hexsides_turned(mech_facing, facing_to_target)
	
	# Arco frontal = facing ± 1 (3 facetas)
	return diff <= 1

## Verificar si un hex está en el arco lateral derecho
static func is_in_right_arc(mech_facing: int, target_hex: Vector2i, mech_hex: Vector2i) -> bool:
	var facing_to_target = get_facing_to_hex(mech_hex, target_hex)
	var relative_facing = normalize_facing(facing_to_target - mech_facing)
	
	# Arco derecho = facetas 1-2 (en sentido horario)
	return relative_facing == 1 or relative_facing == 2

## Verificar si un hex está en el arco lateral izquierdo
static func is_in_left_arc(mech_facing: int, target_hex: Vector2i, mech_hex: Vector2i) -> bool:
	var facing_to_target = get_facing_to_hex(mech_hex, target_hex)
	var relative_facing = normalize_facing(facing_to_target - mech_facing)
	
	# Arco izquierdo = facetas 4-5 (en sentido antihorario)
	return relative_facing == 4 or relative_facing == 5

## Verificar si un hex está en el arco trasero
static func is_in_rear_arc(mech_facing: int, target_hex: Vector2i, mech_hex: Vector2i) -> bool:
	var facing_to_target = get_facing_to_hex(mech_hex, target_hex)
	var diff = get_hexsides_turned(mech_facing, facing_to_target)
	
	# Arco trasero = facing opuesto (3 facetas)
	return diff == 3

## Obtener arco donde está un hex (front/right/left/rear)
static func get_arc(mech_facing: int, target_hex: Vector2i, mech_hex: Vector2i) -> String:
	if is_in_front_arc(mech_facing, target_hex, mech_hex):
		return "front"
	elif is_in_rear_arc(mech_facing, target_hex, mech_hex):
		return "rear"
	elif is_in_right_arc(mech_facing, target_hex, mech_hex):
		return "right"
	elif is_in_left_arc(mech_facing, target_hex, mech_hex):
		return "left"
	else:
		return "unknown"

## Obtener ángulo en grados para el facing
static func get_angle_for_facing(facing: int) -> float:
	return FACING_ANGLES.get(normalize_facing(facing), 0.0)

## Obtener nombre del facing
static func get_facing_name(facing: int, spanish: bool = true) -> String:
	var normalized = normalize_facing(facing)
	
	if spanish:
		return FACING_NAMES_ES.get(normalized, "Desconocido")
	else:
		match normalized:
			Facing.NORTH: return "North"
			Facing.NORTHEAST: return "Northeast"
			Facing.SOUTHEAST: return "Southeast"
			Facing.SOUTH: return "South"
			Facing.SOUTHWEST: return "Southwest"
			Facing.NORTHWEST: return "Northwest"
			_: return "Unknown"

## Calcular el facing resultante al moverse de un hex a otro
## (Útil para actualizar facing automáticamente al moverse)
static func get_facing_after_move(_from_hex: Vector2i, _to_hex: Vector2i, current_facing: int) -> int:
	# Por defecto, mantener el facing actual
	# Algunas variantes actualizan el facing al moverse
	# Para BattleTech clásico, el jugador elige el facing
	return current_facing

## Verificar si se puede torcer el torso (torso twist)
## BattleTech permite girar el torso ±1 faceta sin girar las piernas
static func can_torso_twist(torso_facing: int, leg_facing: int) -> bool:
	var diff = get_hexsides_turned(leg_facing, torso_facing)
	
	# Torso puede girar máximo 1 faceta respecto a piernas
	return diff <= 1

## Aplicar torso twist (girar torso ±1 faceta)
static func apply_torso_twist(leg_facing: int, direction: int) -> int:
	# direction: -1 = izquierda, +1 = derecha
	var new_torso = normalize_facing(leg_facing + direction)
	
	# Validar que no exceda límite de torso twist
	if get_hexsides_turned(leg_facing, new_torso) <= 1:
		return new_torso
	else:
		return leg_facing  # No puede girar más
