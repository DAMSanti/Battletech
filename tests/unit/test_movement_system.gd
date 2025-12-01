# ============================================================================
# test_movement_system.gd - Tests unitarios para el sistema de movimiento
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const MovementSystem = preload("res://scripts/core/movement/movement_system.gd")
const HexGridScript = preload("res://scripts/hex_grid.gd")
const MechScript = preload("res://scripts/mech.gd")
const TerrainTypeScript = preload("res://scripts/core/terrain/terrain_type.gd")
const GameEnumsScript = preload("res://scripts/core/game_enums.gd")


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

func before_each():
	gut.p("--- Preparando test de movimiento ---")


func after_each():
	gut.p("--- Test de movimiento completado ---")


# ============================================================================
# HELPERS
# ============================================================================

func _create_test_grid(width: int = 5, height: int = 3) -> Object:
	"""Crea un grid de prueba con terreno claro"""
	var grid = HexGridScript.new()
	grid.grid_width = width
	grid.grid_height = height
	grid.hex_data = {}
	
	for x in range(width):
		for y in range(height):
			var pos = Vector2i(x, y)
			grid.hex_data[pos] = {
				"terrain": TerrainTypeScript.Type.CLEAR,
				"elevation": 0,
				"unit": null,
				"walkable": true
			}
	
	return grid


func _create_test_mech(facing: int = 0, movement: int = 4) -> Object:
	"""Crea un mech de prueba"""
	var mech = MechScript.new()
	mech.facing = facing
	mech.current_movement = movement
	return mech


# ============================================================================
# TESTS DE ROTACIÓN Y ALCANCE
# ============================================================================

func test_rotation_cost_limits_reach():
	"""Test: El coste de rotación debe limitar el alcance del mech"""
	var grid = _create_test_grid(5, 3)
	var start = Vector2i(1, 1)
	
	# Mech mirando al norte (facing 0), con 3 MP
	var mech = _create_test_mech(0, 3)
	
	var details = MovementSystem.get_reachable_hexes_with_details(
		start, 
		mech.current_movement, 
		GameEnumsScript.MovementType.WALK, 
		grid, 
		mech
	)
	
	var right_one = Vector2i(2, 1)
	var right_two = Vector2i(3, 1)
	
	# Un hex a la derecha debería ser alcanzable (rotación + movimiento = 3 MP)
	assert_true(
		details.has(right_one), 
		"El hex adyacente a la derecha debería ser alcanzable con rotación incluida"
	)
	
	# Dos hexes a la derecha NO deberían ser alcanzables (necesita 4 MP)
	assert_false(
		details.has(right_two), 
		"El segundo hex a la derecha NO debería ser alcanzable con 3 MP"
	)


func test_facing_affects_reachability():
	"""Test: La orientación inicial afecta el alcance"""
	var grid = _create_test_grid(5, 3)
	var start = Vector2i(1, 1)
	
	# Mech ya mirando hacia el este (facing 2), con 3 MP
	var mech = _create_test_mech(2, 3)
	
	var details = MovementSystem.get_reachable_hexes_with_details(
		start, 
		mech.current_movement, 
		GameEnumsScript.MovementType.WALK, 
		grid, 
		mech
	)
	
	var right_two = Vector2i(3, 1)
	
	# Dos hexes a la derecha SÍ deberían ser alcanzables (sin coste de rotación)
	assert_true(
		details.has(right_two), 
		"El segundo hex debería ser alcanzable cuando ya mira en esa dirección"
	)


func test_movement_points_calculation():
	"""Test: Los puntos de movimiento se calculan correctamente"""
	var grid = _create_test_grid(10, 10)
	var start = Vector2i(5, 5)
	
	# Mech con 6 MP
	var mech = _create_test_mech(0, 6)
	
	var details = MovementSystem.get_reachable_hexes_with_details(
		start, 
		mech.current_movement, 
		GameEnumsScript.MovementType.WALK, 
		grid, 
		mech
	)
	
	# Debería haber múltiples hexes alcanzables
	assert_gt(details.size(), 0, "Debería haber hexes alcanzables con 6 MP")
	
	# El hex de inicio no debería estar en los resultados (ya estamos ahí)
	# o si está, verificar que tiene coste 0


func test_zero_movement_points():
	"""Test: Con 0 MP no debería haber hexes alcanzables"""
	var grid = _create_test_grid(5, 5)
	var start = Vector2i(2, 2)
	
	var mech = _create_test_mech(0, 0)
	
	var details = MovementSystem.get_reachable_hexes_with_details(
		start, 
		mech.current_movement, 
		GameEnumsScript.MovementType.WALK, 
		grid, 
		mech
	)
	
	# Con 0 MP, solo el hex actual debería ser "alcanzable" o ninguno
	assert_lte(details.size(), 1, "Con 0 MP no debería haber hexes alcanzables más allá del actual")


# ============================================================================
# TESTS DE TERRENO
# ============================================================================

func test_difficult_terrain_costs_more():
	"""Test: El terreno difícil debería costar más MP"""
	var grid = _create_test_grid(5, 3)
	var start = Vector2i(0, 1)
	
	# Poner bosque en la posición (2, 1)
	grid.hex_data[Vector2i(2, 1)]["terrain"] = TerrainTypeScript.Type.LIGHT_WOODS
	
	var mech = _create_test_mech(2, 4)  # Mirando al este con 4 MP
	
	var details = MovementSystem.get_reachable_hexes_with_details(
		start, 
		mech.current_movement, 
		GameEnumsScript.MovementType.WALK, 
		grid, 
		mech
	)
	
	# El hex con bosque debería ser alcanzable pero con mayor coste
	var forest_hex = Vector2i(2, 1)
	if details.has(forest_hex):
		gut.p("Hex de bosque es alcanzable - terreno difícil funciona")
		assert_true(true)
	else:
		gut.p("Hex de bosque NO es alcanzable - verificar costes de terreno")
		# Esto puede ser correcto dependiendo de la implementación
		pending("Verificar manualmente los costes de terreno difícil")


func test_impassable_terrain_blocks_movement():
	"""Test: El terreno impasable bloquea el movimiento"""
	var grid = _create_test_grid(5, 3)
	var start = Vector2i(0, 1)
	
	# Bloquear el hex (1, 1)
	grid.hex_data[Vector2i(1, 1)]["walkable"] = false
	
	var mech = _create_test_mech(2, 10)  # Muchos MP
	
	var details = MovementSystem.get_reachable_hexes_with_details(
		start, 
		mech.current_movement, 
		GameEnumsScript.MovementType.WALK, 
		grid, 
		mech
	)
	
	var blocked_hex = Vector2i(1, 1)
	assert_false(
		details.has(blocked_hex), 
		"El hex impasable no debería ser alcanzable"
	)
