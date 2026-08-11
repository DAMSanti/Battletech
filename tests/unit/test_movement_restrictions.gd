extends GutTest

## Tests para MovementRestrictions
## Testea las restricciones de movimiento BattleTech

## Mock de HexGrid para testing
class MockHexGrid:
	var grid_width: int = 10
	var grid_height: int = 10
	var _terrain_map: Dictionary = {}
	var _elevation_map: Dictionary = {}
	var _unit_map: Dictionary = {}
	
	func set_terrain(hex: Vector2i, terrain: TerrainType.Type) -> void:
		_terrain_map[hex] = terrain
	
	func set_elevation(hex: Vector2i, elevation: int) -> void:
		_elevation_map[hex] = elevation
	
	func set_unit(hex: Vector2i, unit) -> void:
		_unit_map[hex] = unit
	
	func is_valid_hex(hex: Vector2i) -> bool:
		return hex.x >= 0 and hex.x < grid_width and hex.y >= 0 and hex.y < grid_height
	
	func get_terrain(hex: Vector2i) -> TerrainType.Type:
		return _terrain_map.get(hex, TerrainType.Type.CLEAR)
	
	func get_elevation(hex: Vector2i) -> int:
		return _elevation_map.get(hex, 0)
	
	func get_unit(hex: Vector2i):
		return _unit_map.get(hex, null)
	
	func get_neighbors(hex: Vector2i) -> Array:
		var neighbors = []
		var offsets_even = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1)]
		var offsets_odd = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]
		var offsets = offsets_odd if hex.y % 2 == 1 else offsets_even
		
		for offset in offsets:
			var neighbor = hex + offset
			if is_valid_hex(neighbor):
				neighbors.append(neighbor)
		return neighbors
	
	func hex_distance(from: Vector2i, to: Vector2i) -> int:
		var dx = abs(to.x - from.x)
		var dy = abs(to.y - from.y)
		return max(dx, dy)

## Mock unit
class MockUnit:
	var team_id: int = 0

var hex_grid: MockHexGrid

func before_each():
	hex_grid = MockHexGrid.new()

# ============================================================================
# is_hex_accessible tests
# ============================================================================

func test_is_hex_accessible_clear_terrain_walk():
	hex_grid.set_terrain(Vector2i(5, 5), TerrainType.Type.CLEAR)
	var unit = MockUnit.new()
	
	var result = MovementRestrictions.is_hex_accessible(
		Vector2i(5, 5), unit, hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_true(result, "Clear terrain should be accessible for walking")

func test_is_hex_accessible_invalid_hex():
	var unit = MockUnit.new()
	
	var result = MovementRestrictions.is_hex_accessible(
		Vector2i(-1, -1), unit, hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_false(result, "Invalid hex should not be accessible")

func test_is_hex_accessible_occupied_by_other():
	var unit1 = MockUnit.new()
	var unit2 = MockUnit.new()
	hex_grid.set_unit(Vector2i(5, 5), unit2)
	
	var result = MovementRestrictions.is_hex_accessible(
		Vector2i(5, 5), unit1, hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_false(result, "Hex occupied by another unit should not be accessible")

func test_is_hex_accessible_occupied_by_self():
	var unit = MockUnit.new()
	hex_grid.set_unit(Vector2i(5, 5), unit)
	
	var result = MovementRestrictions.is_hex_accessible(
		Vector2i(5, 5), unit, hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_true(result, "Hex occupied by self should be accessible")

func test_is_hex_accessible_forest_walk():
	hex_grid.set_terrain(Vector2i(5, 5), TerrainType.Type.LIGHT_WOODS)
	var unit = MockUnit.new()
	
	var result = MovementRestrictions.is_hex_accessible(
		Vector2i(5, 5), unit, hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_true(result, "Light woods should be accessible for walking")

func test_is_hex_accessible_run():
	hex_grid.set_terrain(Vector2i(5, 5), TerrainType.Type.CLEAR)
	var unit = MockUnit.new()
	
	var result = MovementRestrictions.is_hex_accessible(
		Vector2i(5, 5), unit, hex_grid, GameEnums.MovementType.RUN
	)
	
	assert_true(result, "Clear terrain should be accessible for running")

func test_is_hex_accessible_jump():
	hex_grid.set_terrain(Vector2i(5, 5), TerrainType.Type.CLEAR)
	var unit = MockUnit.new()
	
	var result = MovementRestrictions.is_hex_accessible(
		Vector2i(5, 5), unit, hex_grid, GameEnums.MovementType.JUMP
	)
	
	assert_true(result, "Clear terrain should be accessible for jumping")

func test_is_hex_accessible_invalid_movement_type():
	hex_grid.set_terrain(Vector2i(5, 5), TerrainType.Type.CLEAR)
	var unit = MockUnit.new()
	
	var result = MovementRestrictions.is_hex_accessible(
		Vector2i(5, 5), unit, hex_grid, -1  # Invalid type
	)
	
	assert_false(result, "Invalid movement type should not be accessible")

# ============================================================================
# is_elevation_change_valid tests
# ============================================================================

func test_elevation_change_valid_flat():
	hex_grid.set_elevation(Vector2i(4, 5), 0)
	hex_grid.set_elevation(Vector2i(5, 5), 0)
	
	var result = MovementRestrictions.is_elevation_change_valid(
		Vector2i(4, 5), Vector2i(5, 5), hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_true(result, "Flat terrain should be valid")

func test_elevation_change_valid_one_level_up():
	hex_grid.set_elevation(Vector2i(4, 5), 0)
	hex_grid.set_elevation(Vector2i(5, 5), 1)
	
	var result = MovementRestrictions.is_elevation_change_valid(
		Vector2i(4, 5), Vector2i(5, 5), hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_true(result, "One level climb should be valid")

func test_elevation_change_valid_two_levels_up():
	hex_grid.set_elevation(Vector2i(4, 5), 0)
	hex_grid.set_elevation(Vector2i(5, 5), 2)
	
	var result = MovementRestrictions.is_elevation_change_valid(
		Vector2i(4, 5), Vector2i(5, 5), hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_true(result, "Two level climb should be valid (max)")

func test_elevation_change_invalid_three_levels_up():
	hex_grid.set_elevation(Vector2i(4, 5), 0)
	hex_grid.set_elevation(Vector2i(5, 5), 3)
	
	var result = MovementRestrictions.is_elevation_change_valid(
		Vector2i(4, 5), Vector2i(5, 5), hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_false(result, "Three level climb should be invalid")

func test_elevation_change_valid_descent():
	hex_grid.set_elevation(Vector2i(4, 5), 3)
	hex_grid.set_elevation(Vector2i(5, 5), 0)
	
	var result = MovementRestrictions.is_elevation_change_valid(
		Vector2i(4, 5), Vector2i(5, 5), hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_true(result, "Descent should be valid (may cause damage)")

func test_elevation_change_valid_jump_ignores_restriction():
	hex_grid.set_elevation(Vector2i(4, 5), 0)
	hex_grid.set_elevation(Vector2i(5, 5), 5)  # 5 levels up
	
	var result = MovementRestrictions.is_elevation_change_valid(
		Vector2i(4, 5), Vector2i(5, 5), hex_grid, GameEnums.MovementType.JUMP
	)
	
	assert_true(result, "Jump should ignore elevation restrictions")

# ============================================================================
# requires_piloting_check tests
# ============================================================================

func test_requires_piloting_check_clear_terrain_walk():
	hex_grid.set_terrain(Vector2i(5, 5), TerrainType.Type.CLEAR)
	hex_grid.set_elevation(Vector2i(4, 5), 0)
	hex_grid.set_elevation(Vector2i(5, 5), 0)
	
	var result = MovementRestrictions.requires_piloting_check(
		Vector2i(4, 5), Vector2i(5, 5), hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_false(result.required, "Clear terrain should not require piloting check")

func test_requires_piloting_check_jump_always():
	hex_grid.set_terrain(Vector2i(5, 5), TerrainType.Type.CLEAR)
	hex_grid.set_elevation(Vector2i(4, 5), 0)
	hex_grid.set_elevation(Vector2i(5, 5), 0)
	
	var result = MovementRestrictions.requires_piloting_check(
		Vector2i(4, 5), Vector2i(5, 5), hex_grid, GameEnums.MovementType.JUMP
	)
	
	assert_true(result.required, "Jump landing should always require piloting check")
	assert_eq(result.difficulty, 3, "Jump landing difficulty should be 3")

func test_requires_piloting_check_steep_descent():
	hex_grid.set_terrain(Vector2i(5, 5), TerrainType.Type.CLEAR)
	hex_grid.set_elevation(Vector2i(4, 5), 3)
	hex_grid.set_elevation(Vector2i(5, 5), 1)  # 2 level descent
	
	var result = MovementRestrictions.requires_piloting_check(
		Vector2i(4, 5), Vector2i(5, 5), hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_true(result.required, "Steep descent should require piloting check")
	assert_true(result.difficulty >= 4, "Descent difficulty should be at least 4")

func test_requires_piloting_check_returns_dictionary():
	var result = MovementRestrictions.requires_piloting_check(
		Vector2i(4, 5), Vector2i(5, 5), hex_grid, GameEnums.MovementType.WALK
	)
	
	assert_true(result is Dictionary, "Result should be a Dictionary")
	assert_has(result, "required", "Result should have 'required' key")
	assert_has(result, "reason", "Result should have 'reason' key")
	assert_has(result, "difficulty", "Result should have 'difficulty' key")

# ============================================================================
# get_prohibited_hexes tests
# ============================================================================

func test_get_prohibited_hexes_all_clear():
	# All hexes are clear by default in mock
	var result = MovementRestrictions.get_prohibited_hexes(hex_grid)
	
	assert_true(result is Array, "Result should be an Array")
	assert_eq(result.size(), 0, "No prohibited hexes with all clear terrain")

func test_get_prohibited_hexes_with_water():
	# Note: TerrainType.Type.WATER has depth=1, which is NOT prohibited
	# This test verifies get_prohibited_hexes returns array for any terrain
	hex_grid.set_terrain(Vector2i(5, 5), TerrainType.Type.WATER)
	
	var result = MovementRestrictions.get_prohibited_hexes(hex_grid)
	
	# Water depth 1 is not prohibited, so hex should NOT be in result
	assert_true(result is Array, "Result should be an Array")

func test_get_prohibited_hexes_returns_array():
	var result = MovementRestrictions.get_prohibited_hexes(hex_grid)
	
	assert_true(result is Array, "Result should be an Array")

# ============================================================================
# get_movement_penalties tests
# ============================================================================

func test_get_movement_penalties_returns_dictionary():
	var result = MovementRestrictions.get_movement_penalties(
		Vector2i(5, 5), GameEnums.MovementType.WALK, hex_grid
	)
	
	assert_true(result is Dictionary, "Result should be a Dictionary")
	assert_has(result, "to_hit_modifier", "Result should have 'to_hit_modifier' key")
	assert_has(result, "defense_modifier", "Result should have 'defense_modifier' key")
	assert_has(result, "heat_penalty", "Result should have 'heat_penalty' key")
	assert_has(result, "piloting_check", "Result should have 'piloting_check' key")

func test_get_movement_penalties_walk():
	hex_grid.set_terrain(Vector2i(5, 5), TerrainType.Type.CLEAR)
	
	var result = MovementRestrictions.get_movement_penalties(
		Vector2i(5, 5), GameEnums.MovementType.WALK, hex_grid
	)
	
	assert_eq(result.to_hit_modifier, 1, "Walking should add +1 to-hit modifier")

func test_get_movement_penalties_run():
	hex_grid.set_terrain(Vector2i(5, 5), TerrainType.Type.CLEAR)
	
	var result = MovementRestrictions.get_movement_penalties(
		Vector2i(5, 5), GameEnums.MovementType.RUN, hex_grid
	)
	
	assert_eq(result.to_hit_modifier, 2, "Running should add +2 to-hit modifier")
	assert_eq(result.defense_modifier, 2, "Running should add +2 defense modifier")

func test_get_movement_penalties_jump():
	hex_grid.set_terrain(Vector2i(5, 5), TerrainType.Type.CLEAR)
	
	var result = MovementRestrictions.get_movement_penalties(
		Vector2i(5, 5), GameEnums.MovementType.JUMP, hex_grid
	)
	
	assert_eq(result.to_hit_modifier, 3, "Jumping should add +3 to-hit modifier")
	assert_eq(result.defense_modifier, 2, "Jumping should add +2 defense modifier")
	assert_true(result.piloting_check, "Jumping should require piloting check")
