# ============================================================================
# test_line_of_sight.gd - Tests unitarios para el sistema de línea de visión
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const LineOfSight = preload("res://scripts/core/combat/line_of_sight.gd")


# ============================================================================
# MOCK HELPERS
# ============================================================================

class MockHexGrid:
	"""Mock de HexGrid para testing de LoS"""
	var elevations: Dictionary = {}
	var terrains: Dictionary = {}
	var units: Dictionary = {}
	
	func is_valid_hex(hex: Vector2i) -> bool:
		return hex.x >= 0 and hex.x < 20 and hex.y >= 0 and hex.y < 20
	
	func get_elevation(hex: Vector2i) -> int:
		return elevations.get(hex, 0)
	
	func get_terrain(hex: Vector2i):
		return terrains.get(hex, TerrainType.Type.CLEAR)
	
	func get_unit(hex: Vector2i):
		return units.get(hex, null)
	
	func hex_distance(from: Vector2i, to: Vector2i) -> int:
		var dq = to.x - from.x
		var dr = to.y - from.y
		return (abs(dq) + abs(dq + dr) + abs(dr)) / 2
	
	func get_neighbors(hex: Vector2i) -> Array:
		return [
			hex + Vector2i(1, 0),
			hex + Vector2i(-1, 0),
			hex + Vector2i(0, 1),
			hex + Vector2i(0, -1),
			hex + Vector2i(1, -1),
			hex + Vector2i(-1, 1)
		]


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

var mock_grid: MockHexGrid

func before_each():
	gut.p("--- Preparando test de LineOfSight ---")
	mock_grid = MockHexGrid.new()


func after_each():
	gut.p("--- Test de LineOfSight completado ---")
	mock_grid = null


# ============================================================================
# TESTS DE LoS BÁSICA
# ============================================================================

func test_los_clear_adjacent():
	"""Test: LoS clara entre hexes adyacentes"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 6)
	
	var result = LineOfSight.calculate_los(mock_grid, from, to)
	
	assert_eq(result.result, LineOfSight.Result.CLEAR, "LoS clara entre adyacentes")


func test_los_same_hex():
	"""Test: LoS al mismo hex siempre es clara"""
	var hex = Vector2i(5, 5)
	
	var result = LineOfSight.calculate_los(mock_grid, hex, hex)
	
	assert_eq(result.result, LineOfSight.Result.CLEAR, "LoS al mismo hex = clara")


func test_los_invalid_hex():
	"""Test: hex inválido bloquea LoS"""
	var from = Vector2i(5, 5)
	var to = Vector2i(-1, -1)  # Inválido
	
	var result = LineOfSight.calculate_los(mock_grid, from, to)
	
	assert_eq(result.result, LineOfSight.Result.BLOCKED, "Hex inválido = bloqueado")


# ============================================================================
# TESTS DE BLOQUEO POR MECH
# ============================================================================

func test_los_blocked_by_mech():
	"""Test: LoS bloqueada por mech intermedio"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 8)
	var blocking_hex = Vector2i(5, 6)
	
	# Colocar mock mech en el camino
	mock_grid.units[blocking_hex] = {}  # Cualquier objeto no null
	
	var result = LineOfSight.calculate_los(mock_grid, from, to)
	
	assert_eq(result.result, LineOfSight.Result.BLOCKED, "Mech bloquea LoS")
	assert_eq(result.cover_type, LineOfSight.CoverType.MECH_BLOCKING, "Tipo de cobertura correcto")


# ============================================================================
# TESTS DE COBERTURA POR BOSQUE
# ============================================================================

func test_los_light_woods_partial():
	"""Test: bosque ligero da cobertura parcial"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 8)
	var woods_hex = Vector2i(5, 6)
	
	mock_grid.terrains[woods_hex] = TerrainType.Type.LIGHT_WOODS
	
	var result = LineOfSight.calculate_los(mock_grid, from, to)
	
	assert_eq(result.result, LineOfSight.Result.PARTIAL, "Bosque ligero = parcial")
	assert_gt(result.to_hit_modifier, 0, "Hay modificador de to-hit")


func test_los_heavy_woods_blocked():
	"""Test: 2+ hexes de bosque denso bloquean"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 10)
	
	# Colocar 2 hexes de bosque denso
	mock_grid.terrains[Vector2i(5, 6)] = TerrainType.Type.HEAVY_WOODS
	mock_grid.terrains[Vector2i(5, 7)] = TerrainType.Type.HEAVY_WOODS
	
	var result = LineOfSight.calculate_los(mock_grid, from, to)
	
	assert_eq(result.result, LineOfSight.Result.BLOCKED, "2 bosques densos = bloqueado")


# ============================================================================
# TESTS DE HELPER FUNCTIONS
# ============================================================================

func test_can_shoot_clear():
	"""Test: can_shoot retorna true con LoS clara"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 6)
	
	var can = LineOfSight.can_shoot(mock_grid, from, to)
	
	assert_true(can, "Puede disparar con LoS clara")


func test_can_shoot_blocked():
	"""Test: can_shoot retorna false cuando bloqueado"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 8)
	
	mock_grid.units[Vector2i(5, 6)] = {}
	
	var can = LineOfSight.can_shoot(mock_grid, from, to)
	
	assert_false(can, "No puede disparar cuando bloqueado")


# ============================================================================
# TESTS DE MODIFICADOR DE ALTURA
# ============================================================================

func test_height_modifier_same_elevation():
	"""Test: misma elevación = sin modificador"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 6)
	
	var mod = LineOfSight.calculate_height_modifier(mock_grid, from, to)
	
	assert_eq(mod, 0, "Misma elevación = 0 modificador")


func test_height_modifier_attacking_from_high():
	"""Test: atacar desde arriba = bonus"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 6)
	
	mock_grid.elevations[from] = 2
	mock_grid.elevations[to] = 0
	
	var mod = LineOfSight.calculate_height_modifier(mock_grid, from, to)
	
	assert_lt(mod, 0, "Atacar desde arriba = modificador negativo (más fácil)")


func test_height_modifier_attacking_from_low():
	"""Test: atacar desde abajo = penalizador"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 6)
	
	mock_grid.elevations[from] = 0
	mock_grid.elevations[to] = 2
	
	var mod = LineOfSight.calculate_height_modifier(mock_grid, from, to)
	
	assert_gt(mod, 0, "Atacar desde abajo = modificador positivo (más difícil)")


func test_height_modifier_capped():
	"""Test: modificador de altura tiene límite"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 6)
	
	mock_grid.elevations[from] = 10  # Muy alto
	mock_grid.elevations[to] = 0
	
	var mod = LineOfSight.calculate_height_modifier(mock_grid, from, to)
	
	assert_eq(mod, -2, "Modificador máximo = -2")


# ============================================================================
# TESTS DE MODIFICADOR TOTAL
# ============================================================================

func test_get_total_modifier_clear():
	"""Test: modificador total con LoS clara"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 6)
	
	var total = LineOfSight.get_total_modifier(mock_grid, from, to)
	
	assert_eq(total, 0, "LoS clara = 0 modificador")


func test_get_total_modifier_blocked():
	"""Test: modificador infinito cuando bloqueado"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 8)
	
	mock_grid.units[Vector2i(5, 6)] = {}
	
	var total = LineOfSight.get_total_modifier(mock_grid, from, to)
	
	assert_eq(total, 999, "Bloqueado = 999 (imposible)")


# ============================================================================
# TESTS DE DESCRIPCIÓN
# ============================================================================

func test_get_los_description():
	"""Test: descripción de LoS contiene información"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 6)
	
	var desc = LineOfSight.get_los_description(mock_grid, from, to)
	
	assert_not_null(desc, "Descripción no es null")
	assert_true(desc.length() > 0, "Descripción no está vacía")


func test_get_los_description_blocked():
	"""Test: descripción indica cuando está bloqueado"""
	var from = Vector2i(5, 5)
	var to = Vector2i(5, 8)
	
	mock_grid.units[Vector2i(5, 6)] = {}
	
	var desc = LineOfSight.get_los_description(mock_grid, from, to)
	
	assert_true(desc.contains("CANNOT SHOOT") or desc.contains("block"), 
				"Descripción indica bloqueo")


# ============================================================================
# TESTS DE UTILIDADES INTERNAS (si son accesibles)
# ============================================================================

func test_los_data_initialization():
	"""Test: LoSData se inicializa correctamente"""
	var data = LineOfSight.LoSData.new()
	
	assert_eq(data.result, LineOfSight.Result.CLEAR, "Resultado inicial = CLEAR")
	assert_eq(data.to_hit_modifier, 0, "Modificador inicial = 0")
	assert_true(data.can_hit_all_locations, "Puede golpear todas las ubicaciones")
