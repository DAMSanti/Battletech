# ============================================================================
# test_facing_system.gd - Tests unitarios para el sistema de facing
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const FacingSystem = preload("res://scripts/core/movement/facing_system.gd")


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

func before_each():
	gut.p("--- Preparando test de FacingSystem ---")


func after_each():
	gut.p("--- Test de FacingSystem completado ---")


# ============================================================================
# TESTS DE NORMALIZE_FACING
# ============================================================================

func test_normalize_facing_valid():
	"""Test: valores válidos no cambian"""
	for i in range(6):
		var result = FacingSystem.normalize_facing(i)
		assert_eq(result, i, "Facing %d no cambia" % i)


func test_normalize_facing_overflow():
	"""Test: valores mayores a 5 se normalizan"""
	assert_eq(FacingSystem.normalize_facing(6), 0, "6 -> 0")
	assert_eq(FacingSystem.normalize_facing(7), 1, "7 -> 1")
	assert_eq(FacingSystem.normalize_facing(12), 0, "12 -> 0")


func test_normalize_facing_negative():
	"""Test: valores negativos se normalizan"""
	assert_eq(FacingSystem.normalize_facing(-1), 5, "-1 -> 5")
	assert_eq(FacingSystem.normalize_facing(-2), 4, "-2 -> 4")
	assert_eq(FacingSystem.normalize_facing(-6), 0, "-6 -> 0")


# ============================================================================
# TESTS DE GET_HEXSIDES_TURNED
# ============================================================================

func test_hexsides_turned_same():
	"""Test: sin giro = 0 facetas"""
	var result = FacingSystem.get_hexsides_turned(0, 0)
	assert_eq(result, 0, "Mismo facing = 0 facetas")


func test_hexsides_turned_adjacent():
	"""Test: facing adyacente = 1 faceta"""
	assert_eq(FacingSystem.get_hexsides_turned(0, 1), 1, "0 -> 1 = 1")
	assert_eq(FacingSystem.get_hexsides_turned(5, 0), 1, "5 -> 0 = 1")


func test_hexsides_turned_opposite():
	"""Test: facing opuesto = 3 facetas"""
	assert_eq(FacingSystem.get_hexsides_turned(0, 3), 3, "0 -> 3 = 3")
	assert_eq(FacingSystem.get_hexsides_turned(2, 5), 3, "2 -> 5 = 3")


func test_hexsides_turned_shortest_path():
	"""Test: siempre toma el camino más corto"""
	# De 0 a 5, el camino corto es 1 (no 5)
	assert_eq(FacingSystem.get_hexsides_turned(0, 5), 1, "0 -> 5 = 1 (camino corto)")


# ============================================================================
# TESTS DE ROTATE_FACING
# ============================================================================

func test_rotate_facing_clockwise():
	"""Test: rotación en sentido horario"""
	assert_eq(FacingSystem.rotate_facing(0, 1), 1, "0 + 1 = 1")
	assert_eq(FacingSystem.rotate_facing(0, 2), 2, "0 + 2 = 2")
	assert_eq(FacingSystem.rotate_facing(5, 1), 0, "5 + 1 = 0 (wrap)")


func test_rotate_facing_counterclockwise():
	"""Test: rotación en sentido antihorario"""
	assert_eq(FacingSystem.rotate_facing(0, -1), 5, "0 - 1 = 5")
	assert_eq(FacingSystem.rotate_facing(1, -2), 5, "1 - 2 = 5")


# ============================================================================
# TESTS DE GET_OPPOSITE_FACING
# ============================================================================

func test_opposite_facing():
	"""Test: facing opuesto correcto"""
	assert_eq(FacingSystem.get_opposite_facing(0), 3, "North <-> South")
	assert_eq(FacingSystem.get_opposite_facing(1), 4, "Northeast <-> Southwest")
	assert_eq(FacingSystem.get_opposite_facing(2), 5, "Southeast <-> Northwest")


func test_opposite_facing_symmetric():
	"""Test: opuesto del opuesto = original"""
	for i in range(6):
		var opposite = FacingSystem.get_opposite_facing(i)
		var double_opposite = FacingSystem.get_opposite_facing(opposite)
		assert_eq(double_opposite, i, "Opuesto del opuesto de %d = %d" % [i, i])


# ============================================================================
# TESTS DE GET_FACING_TO_HEX
# ============================================================================

func test_facing_to_hex_north():
	"""Test: hex al norte"""
	var result = FacingSystem.get_facing_to_hex(Vector2i(0, 0), Vector2i(0, -1))
	assert_eq(result, FacingSystem.Facing.NORTH, "Hex al norte = NORTH")


func test_facing_to_hex_south():
	"""Test: hex al sur"""
	var result = FacingSystem.get_facing_to_hex(Vector2i(0, 0), Vector2i(0, 1))
	assert_eq(result, FacingSystem.Facing.SOUTH, "Hex al sur = SOUTH")


func test_facing_to_hex_northeast():
	"""Test: hex al noreste"""
	var result = FacingSystem.get_facing_to_hex(Vector2i(0, 0), Vector2i(1, -1))
	assert_eq(result, FacingSystem.Facing.NORTHEAST, "Hex al noreste = NORTHEAST")


func test_facing_to_hex_southwest():
	"""Test: hex al suroeste"""
	var result = FacingSystem.get_facing_to_hex(Vector2i(0, 0), Vector2i(-1, 1))
	assert_eq(result, FacingSystem.Facing.SOUTHWEST, "Hex al suroeste = SOUTHWEST")


# ============================================================================
# TESTS DE ARCOS (FRONT/REAR/LEFT/RIGHT)
# ============================================================================

func test_is_in_front_arc():
	"""Test: detección de arco frontal"""
	var mech_hex = Vector2i(5, 5)
	var mech_facing = FacingSystem.Facing.NORTH
	
	# Hex directamente al norte está en arco frontal
	var north_hex = Vector2i(5, 4)
	assert_true(FacingSystem.is_in_front_arc(mech_facing, north_hex, mech_hex), 
				"Norte está en arco frontal")


func test_is_in_rear_arc():
	"""Test: detección de arco trasero"""
	var mech_hex = Vector2i(5, 5)
	var mech_facing = FacingSystem.Facing.NORTH
	
	# Hex directamente al sur está en arco trasero
	var south_hex = Vector2i(5, 6)
	assert_true(FacingSystem.is_in_rear_arc(mech_facing, south_hex, mech_hex), 
				"Sur está en arco trasero cuando facing North")


func test_is_in_right_arc():
	"""Test: detección de arco derecho"""
	var mech_hex = Vector2i(5, 5)
	var mech_facing = FacingSystem.Facing.NORTH
	
	# Hex al sureste está en arco derecho cuando facing North
	var se_hex = Vector2i(6, 5)
	assert_true(FacingSystem.is_in_right_arc(mech_facing, se_hex, mech_hex), 
				"Sureste está en arco derecho cuando facing North")


func test_is_in_left_arc():
	"""Test: detección de arco izquierdo"""
	var mech_hex = Vector2i(5, 5)
	var mech_facing = FacingSystem.Facing.NORTH
	
	# Hex al noroeste está en arco izquierdo cuando facing North
	var nw_hex = Vector2i(4, 5)
	assert_true(FacingSystem.is_in_left_arc(mech_facing, nw_hex, mech_hex), 
				"Noroeste está en arco izquierdo cuando facing North")


func test_get_arc():
	"""Test: get_arc retorna string correcto"""
	var mech_hex = Vector2i(5, 5)
	var mech_facing = FacingSystem.Facing.NORTH
	
	var north_hex = Vector2i(5, 4)
	var south_hex = Vector2i(5, 6)
	
	assert_eq(FacingSystem.get_arc(mech_facing, north_hex, mech_hex), "front", "Norte = front")
	assert_eq(FacingSystem.get_arc(mech_facing, south_hex, mech_hex), "rear", "Sur = rear")


# ============================================================================
# TESTS DE ROTATION COST
# ============================================================================

func test_rotation_cost_same_facing():
	"""Test: sin giro = sin coste"""
	var cost = FacingSystem.get_rotation_cost(0, 0, true)
	assert_eq(cost, 0, "Sin giro = 0 MPs")


func test_rotation_cost_while_moving():
	"""Test: girar durante movimiento no cuesta"""
	var cost = FacingSystem.get_rotation_cost(0, 3, true)
	assert_eq(cost, 0, "Girar durante movimiento = 0 MPs")


# ============================================================================
# TESTS DE TORSO TWIST
# ============================================================================

func test_can_torso_twist_valid():
	"""Test: torso puede girar ±1 faceta"""
	assert_true(FacingSystem.can_torso_twist(0, 0), "Sin giro válido")
	assert_true(FacingSystem.can_torso_twist(1, 0), "1 faceta derecha válido")
	assert_true(FacingSystem.can_torso_twist(5, 0), "1 faceta izquierda válido")


func test_can_torso_twist_invalid():
	"""Test: torso no puede girar más de 1 faceta"""
	assert_false(FacingSystem.can_torso_twist(2, 0), "2 facetas inválido")
	assert_false(FacingSystem.can_torso_twist(3, 0), "3 facetas inválido")


func test_apply_torso_twist():
	"""Test: aplicar torso twist"""
	var result_right = FacingSystem.apply_torso_twist(0, 1)
	var result_left = FacingSystem.apply_torso_twist(0, -1)
	
	assert_eq(result_right, 1, "Twist derecha = 1")
	assert_eq(result_left, 5, "Twist izquierda = 5")


# ============================================================================
# TESTS DE UTILIDADES
# ============================================================================

func test_get_angle_for_facing():
	"""Test: ángulos de facing correctos"""
	assert_eq(FacingSystem.get_angle_for_facing(FacingSystem.Facing.NORTH), -90.0, "North = -90°")
	assert_eq(FacingSystem.get_angle_for_facing(FacingSystem.Facing.SOUTH), 90.0, "South = 90°")


func test_get_facing_name_spanish():
	"""Test: nombres en español"""
	assert_eq(FacingSystem.get_facing_name(0, true), "Norte", "0 = Norte")
	assert_eq(FacingSystem.get_facing_name(3, true), "Sur", "3 = Sur")


func test_get_facing_name_english():
	"""Test: nombres en inglés"""
	assert_eq(FacingSystem.get_facing_name(0, false), "North", "0 = North")
	assert_eq(FacingSystem.get_facing_name(3, false), "South", "3 = South")


func test_get_facing_after_move():
	"""Test: facing después de moverse mantiene facing"""
	var result = FacingSystem.get_facing_after_move(Vector2i(0, 0), Vector2i(1, 0), 2)
	assert_eq(result, 2, "Facing se mantiene por defecto")
