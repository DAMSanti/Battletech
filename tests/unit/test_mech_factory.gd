extends GutTest

## Tests para MechFactory
## Testea la creación y configuración de mechs

var factory: MechFactory

## Mock de HexGrid para testing
class MockHexGrid:
	extends HexGrid
	
	func _init():
		grid_width = 10
		grid_height = 10
		# Inicializar hex_data para evitar errores
		hex_data = {}
		for x in range(grid_width):
			for y in range(grid_height):
				var hex = Vector2i(x, y)
				hex_data[hex] = {
					"elevation": 0,
					"terrain": TerrainType.Type.CLEAR
				}
	
	func hex_to_pixel(hex: Vector2i, _include_elevation: bool = false) -> Vector2:
		return Vector2(hex.x * 75, hex.y * 87)
	
	func get_elevation(hex: Vector2i) -> int:
		if hex_data.has(hex):
			return hex_data[hex].get("elevation", 0)
		return 0

func before_each():
	factory = MechFactory.new()

# ============================================================================
# configure tests
# ============================================================================

func test_configure_sets_hex_grid():
	var grid = MockHexGrid.new()
	add_child_autofree(grid)
	factory.configure(grid, false, "")
	
	assert_eq(factory.hex_grid, grid, "hex_grid should be set")

func test_configure_sets_multiplayer_mode():
	var grid = MockHexGrid.new()
	add_child_autofree(grid)
	factory.configure(grid, true, "")
	
	assert_true(factory.is_multiplayer_mode, "is_multiplayer_mode should be true")

func test_configure_sets_my_team():
	var grid = MockHexGrid.new()
	add_child_autofree(grid)
	factory.configure(grid, true, "team1")
	
	assert_eq(factory.my_team, "team1", "my_team should be set")

# ============================================================================
# create_for_deployment tests
# ============================================================================

func test_create_for_deployment_returns_mech():
	var mech_data = {
		"name": "Test Mech",
		"tonnage": 50,
		"walk_mp": 4,
		"run_mp": 6,
		"jump_mp": 2
	}
	
	var mech = factory.create_for_deployment(mech_data, "player")
	
	assert_not_null(mech, "Should create a mech")
	assert_true(mech is Mech, "Should be a Mech instance")
	mech.queue_free()

func test_create_for_deployment_sets_name():
	var mech_data = {"name": "Atlas", "tonnage": 100}
	
	var mech = factory.create_for_deployment(mech_data, "player")
	
	assert_eq(mech.mech_name, "Atlas", "Mech name should be set")
	mech.queue_free()

func test_create_for_deployment_sets_tonnage():
	var mech_data = {"name": "Test", "tonnage": 75}
	
	var mech = factory.create_for_deployment(mech_data, "player")
	
	assert_eq(mech.tonnage, 75, "Tonnage should be set")
	mech.queue_free()

func test_create_for_deployment_sets_team():
	var mech_data = {"name": "Test", "tonnage": 50}
	
	var mech = factory.create_for_deployment(mech_data, "enemy")
	
	assert_eq(mech.get_meta("team"), "enemy", "Team meta should be set")
	mech.queue_free()

func test_create_for_deployment_sets_z_index():
	var mech_data = {"name": "Test", "tonnage": 50}
	
	var mech = factory.create_for_deployment(mech_data, "player")
	
	assert_eq(mech.z_index, 10, "z_index should be 10")
	mech.queue_free()

# ============================================================================
# create_basic tests
# ============================================================================

func test_create_basic_returns_mech():
	var grid = MockHexGrid.new()
	add_child_autofree(grid)
	factory.configure(grid, false, "")
	
	var mech = factory.create_basic("Locust", Vector2i(0, 0), 20, 8, 12, 0, "player")
	
	assert_not_null(mech, "Should create a mech")
	assert_true(mech is Mech, "Should be a Mech instance")
	mech.queue_free()

func test_create_basic_sets_all_properties():
	var grid = MockHexGrid.new()
	add_child_autofree(grid)
	factory.configure(grid, false, "")
	
	var mech = factory.create_basic("Hunchback", Vector2i(3, 3), 50, 4, 6, 4, "player")
	
	assert_eq(mech.mech_name, "Hunchback", "Name should be set")
	assert_eq(mech.tonnage, 50, "Tonnage should be set")
	assert_eq(mech.walk_mp, 4, "Walk MP should be set")
	assert_eq(mech.run_mp, 6, "Run MP should be set")
	assert_eq(mech.jump_mp, 4, "Jump MP should be set")
	mech.queue_free()

func test_create_basic_sets_hex_position():
	var grid = MockHexGrid.new()
	add_child_autofree(grid)
	factory.configure(grid, false, "")
	
	var mech = factory.create_basic("Test", Vector2i(5, 5), 50, 4, 6, 0, "player")
	
	assert_eq(mech.hex_position, Vector2i(5, 5), "Hex position should be set")
	mech.queue_free()

# ============================================================================
# create_player_mech tests
# ============================================================================

func test_create_player_mech_returns_mech():
	var grid = MockHexGrid.new()
	add_child_autofree(grid)
	factory.configure(grid, false, "")
	var mech_data = {"name": "Player Mech", "tonnage": 50}
	
	var mech = factory.create_player_mech(mech_data, Vector2i(2, 2))
	
	assert_not_null(mech, "Should create a mech")
	assert_eq(mech.get_meta("team"), "player", "Should be player team")
	mech.queue_free()

func test_create_player_mech_is_player_controlled():
	var grid = MockHexGrid.new()
	add_child_autofree(grid)
	factory.configure(grid, false, "")
	var mech_data = {"name": "Player Mech", "tonnage": 50}
	
	var mech = factory.create_player_mech(mech_data, Vector2i(2, 2))
	
	assert_true(mech.is_player_controlled, "Should be player controlled")
	mech.queue_free()

# ============================================================================
# create_enemy_mech tests
# ============================================================================

func test_create_enemy_mech_returns_mech():
	var grid = MockHexGrid.new()
	add_child_autofree(grid)
	factory.configure(grid, false, "")
	var mech_data = {"name": "Enemy Mech", "tonnage": 75}
	
	var mech = factory.create_enemy_mech(mech_data, Vector2i(7, 7))
	
	assert_not_null(mech, "Should create a mech")
	assert_eq(mech.get_meta("team"), "enemy", "Should be enemy team")
	mech.queue_free()

func test_create_enemy_mech_is_not_player_controlled():
	var grid = MockHexGrid.new()
	add_child_autofree(grid)
	factory.configure(grid, false, "")
	var mech_data = {"name": "Enemy Mech", "tonnage": 75}
	
	var mech = factory.create_enemy_mech(mech_data, Vector2i(7, 7))
	
	assert_false(mech.is_player_controlled, "Should not be player controlled")
	mech.queue_free()

# ============================================================================
# create_from_network tests
# ============================================================================

func test_create_from_network_sets_network_id():
	var mech_data = {"name": "Network Mech", "tonnage": 60}
	
	var mech = factory.create_from_network(123, mech_data, Vector2i(4, 4), 2, "team1")
	
	assert_eq(mech.get_meta("network_id"), 123, "Network ID should be set")
	mech.queue_free()

func test_create_from_network_sets_facing():
	var mech_data = {"name": "Network Mech", "tonnage": 60}
	
	var mech = factory.create_from_network(123, mech_data, Vector2i(4, 4), 3, "team1")
	
	assert_eq(mech.facing, 3, "Facing should be set")
	mech.queue_free()

func test_create_from_network_sets_position():
	var mech_data = {"name": "Network Mech", "tonnage": 60}
	
	var mech = factory.create_from_network(123, mech_data, Vector2i(4, 4), 0, "team1")
	
	assert_eq(mech.hex_position, Vector2i(4, 4), "Hex position should be set")
	mech.queue_free()

# ============================================================================
# generate_default_armor tests
# ============================================================================

func test_generate_default_armor_returns_dictionary():
	var armor = factory.generate_default_armor(50)
	
	assert_true(armor is Dictionary, "Should return a Dictionary")

func test_generate_default_armor_has_all_locations():
	var armor = factory.generate_default_armor(50)
	
	assert_has(armor, "head", "Should have head")
	assert_has(armor, "center_torso", "Should have center_torso")
	assert_has(armor, "center_torso_rear", "Should have center_torso_rear")
	assert_has(armor, "left_torso", "Should have left_torso")
	assert_has(armor, "right_torso", "Should have right_torso")
	assert_has(armor, "left_arm", "Should have left_arm")
	assert_has(armor, "right_arm", "Should have right_arm")
	assert_has(armor, "left_leg", "Should have left_leg")
	assert_has(armor, "right_leg", "Should have right_leg")

func test_generate_default_armor_location_has_current_and_max():
	var armor = factory.generate_default_armor(50)
	
	assert_has(armor["head"], "current", "Head should have current")
	assert_has(armor["head"], "max", "Head should have max")

func test_generate_default_armor_current_equals_max():
	var armor = factory.generate_default_armor(50)
	
	for location in armor.keys():
		assert_eq(armor[location]["current"], armor[location]["max"], 
			"Current should equal max for %s" % location)

func test_generate_default_armor_scales_with_tonnage():
	var light_armor = factory.generate_default_armor(20)
	var heavy_armor = factory.generate_default_armor(75)
	var assault_armor = factory.generate_default_armor(100)
	
	assert_true(heavy_armor["center_torso"]["max"] > light_armor["center_torso"]["max"],
		"Heavy mech should have more armor than light")
	assert_true(assault_armor["center_torso"]["max"] > heavy_armor["center_torso"]["max"],
		"Assault mech should have more armor than heavy")

# ============================================================================
# generate_default_structure tests
# ============================================================================

func test_generate_default_structure_returns_dictionary():
	var structure = factory.generate_default_structure(50)
	
	assert_true(structure is Dictionary, "Should return a Dictionary")

func test_generate_default_structure_has_all_locations():
	var structure = factory.generate_default_structure(50)
	
	assert_has(structure, "head", "Should have head")
	assert_has(structure, "center_torso", "Should have center_torso")
	assert_has(structure, "left_torso", "Should have left_torso")
	assert_has(structure, "right_torso", "Should have right_torso")
	assert_has(structure, "left_arm", "Should have left_arm")
	assert_has(structure, "right_arm", "Should have right_arm")
	assert_has(structure, "left_leg", "Should have left_leg")
	assert_has(structure, "right_leg", "Should have right_leg")

func test_generate_default_structure_50_ton():
	var structure = factory.generate_default_structure(50)
	
	# 50 ton mech internal structure values from BattleTech rules
	assert_eq(structure["head"]["max"], 3, "Head structure should be 3")
	assert_eq(structure["center_torso"]["max"], 16, "CT structure should be 16")

func test_generate_default_structure_scales_with_tonnage():
	var light_structure = factory.generate_default_structure(20)
	var assault_structure = factory.generate_default_structure(100)
	
	assert_true(assault_structure["center_torso"]["max"] > light_structure["center_torso"]["max"],
		"Assault mech should have more structure than light")

# ============================================================================
# convert_loadout_to_mech_data tests
# ============================================================================

func test_convert_loadout_basic():
	var loadout = {
		"mech_name": "Custom Mech",
		"mech_tonnage": 50,
		"engine_rating": 200,
		"loadout": {}
	}
	
	var result = factory.convert_loadout_to_mech_data(loadout)
	
	assert_eq(result["name"], "Custom Mech", "Name should be set")
	assert_eq(result["tonnage"], 50, "Tonnage should be set")

func test_convert_loadout_calculates_walk_mp():
	var loadout = {
		"mech_name": "Test",
		"mech_tonnage": 50,
		"engine_rating": 200,  # 200 / 50 = 4 walk MP
		"loadout": {}
	}
	
	var result = factory.convert_loadout_to_mech_data(loadout)
	
	assert_eq(result["walk_mp"], 4, "Walk MP should be engine_rating / tonnage")
	assert_eq(result["run_mp"], 6, "Run MP should be walk_mp * 1.5")

func test_convert_loadout_counts_jump_jets():
	var loadout = {
		"mech_name": "Test",
		"mech_tonnage": 50,
		"engine_rating": 200,
		"loadout": {
			"left_leg": [{"id": "jump_jet"}],
			"right_leg": [{"id": "jump_jet"}],
			"center_torso": [{"id": "jump_jet"}]
		}
	}
	
	var result = factory.convert_loadout_to_mech_data(loadout)
	
	assert_eq(result["jump_mp"], 3, "Should count 3 jump jets")

func test_convert_loadout_returns_required_keys():
	var loadout = {
		"mech_name": "Test",
		"mech_tonnage": 50,
		"loadout": {}
	}
	
	var result = factory.convert_loadout_to_mech_data(loadout)
	
	assert_has(result, "weapons", "Should have weapons key")
	assert_has(result, "equipment", "Should have equipment key")
	assert_has(result, "armor", "Should have armor key")
	assert_has(result, "structure", "Should have structure key")
	assert_has(result, "gunnery_skill", "Should have gunnery_skill key")
	assert_has(result, "piloting_skill", "Should have piloting_skill key")

# ============================================================================
# _convert_location_to_string tests  
# ============================================================================

func test_convert_location_string_passthrough():
	# Testing private method indirectly through convert_loadout_to_mech_data
	# When location is already a string, it should pass through
	var loadout = {
		"mech_name": "Test",
		"mech_tonnage": 50,
		"loadout": {
			"left_arm": [{"id": "test", "type": -1}]
		}
	}
	
	var result = factory.convert_loadout_to_mech_data(loadout)
	
	assert_has(result["critical_slots"], "left_arm", "Should have left_arm")
