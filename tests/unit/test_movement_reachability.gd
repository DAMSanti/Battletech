extends Node
class_name TestMovementReachability

const MovementSystemScript = preload("res://scripts/core/movement/movement_system.gd")
const HexGridSC = preload("res://scripts/hex_grid.gd")
const MechSC = preload("res://scripts/mech.gd")
const TerrainTypeSC = preload("res://scripts/core/terrain/terrain_type.gd")
const GameEnumsSC = preload("res://scripts/core/game_enums.gd")

var test_results: Array = []

func _ready():
    run_all_tests()
    print_results()

func run_all_tests():
    test_rotation_cost_limits_reach()
    test_facing_affects_reachability()

func test_rotation_cost_limits_reach():
    # Setup deterministic grid 5x3, all clear terrain
    var grid = HexGrid.new()
    grid.grid_width = 5
    grid.grid_height = 3
    grid.hex_data = {}
    for x in range(grid.grid_width):
        for y in range(grid.grid_height):
            var pos = Vector2i(x, y)
            grid.hex_data[pos] = {"terrain": TerrainType.Type.CLEAR, "elevation": 0, "unit": null, "walkable": true}

    var start = Vector2i(1, 1)

    var mech = Mech.new()
    mech.facing = 0  # Facing North; to move east we need rotation cost
    mech.current_movement = 3

    var details = MovementSystemScript.get_reachable_hexes_with_details(start, mech.current_movement, GameEnumsSC.MovementType.WALK, grid, mech)

    var right_one = Vector2i(2, 1)
    var right_two = Vector2i(3, 1)

    # Right neighbor should be reachable within 3 MP (rotation = 2, move = 1 => total 3)
    assert_test(details.has(right_one), "Right neighbor should be reachable (rotation included)")

    # Two steps to the right should NOT be reachable with 3 MP (needs 4)
    assert_test(not details.has(right_two), "Second hex to the right should NOT be reachable within 3 MP")

func test_facing_affects_reachability():
    var grid = HexGrid.new()
    grid.grid_width = 5
    grid.grid_height = 3
    grid.hex_data = {}
    for x in range(grid.grid_width):
        for y in range(grid.grid_height):
            var pos = Vector2i(x, y)
            grid.hex_data[pos] = {"terrain": TerrainType.Type.CLEAR, "elevation": 0, "unit": null, "walkable": true}

    var start = Vector2i(1, 1)

    var mech = Mech.new()
    mech.facing = 2  # Already facing SE/east in our mapping -> cheap movement to the right
    mech.current_movement = 3

    var details = MovementSystemScript.get_reachable_hexes_with_details(start, mech.current_movement, GameEnumsSC.MovementType.WALK, grid, mech)

    var right_two = Vector2i(3, 1)
    # Now the second hex to the right should be reachable because initial rotation cost is 0
    assert_test(details.has(right_two), "Second hex to the right should be reachable when already facing that direction")

func assert_test(condition: bool, description: String):
    var status = "✅ PASS" if condition else "❌ FAIL"
    test_results.append({"passed": condition, "desc": description})
    print("  %s: %s" % [status, description])

func print_results():
    var passed = 0
    for r in test_results:
        if r.passed:
            passed += 1
    print("\nRESULTS: %d tests, Passed: %d, Failed: %d" % [test_results.size(), passed, test_results.size() - passed])
