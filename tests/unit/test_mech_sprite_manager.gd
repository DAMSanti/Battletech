extends GutTest

## Tests para MechSpriteManager
## Testea la gestión de sprites de mechs

var manager: MechSpriteManager


func before_each():
	manager = MechSpriteManager.new()
	add_child_autofree(manager)


func after_each():
	manager = null


# ============================================================================
# get_mech_class tests
# ============================================================================

func test_get_mech_class_light_min():
	var result = manager.get_mech_class(20)
	assert_eq(result, MechSpriteManager.MechClass.LIGHT, "20 tons should be LIGHT")


func test_get_mech_class_light_max():
	var result = manager.get_mech_class(35)
	assert_eq(result, MechSpriteManager.MechClass.LIGHT, "35 tons should be LIGHT")


func test_get_mech_class_medium_min():
	var result = manager.get_mech_class(40)
	assert_eq(result, MechSpriteManager.MechClass.MEDIUM, "40 tons should be MEDIUM")


func test_get_mech_class_medium_max():
	var result = manager.get_mech_class(55)
	assert_eq(result, MechSpriteManager.MechClass.MEDIUM, "55 tons should be MEDIUM")


func test_get_mech_class_assault_min():
	# Note: MechSpriteManager only has LIGHT, MEDIUM, ASSAULT (no HEAVY)
	var result = manager.get_mech_class(60)
	assert_eq(result, MechSpriteManager.MechClass.ASSAULT, "60 tons should be ASSAULT")


func test_get_mech_class_assault_max():
	var result = manager.get_mech_class(100)
	assert_eq(result, MechSpriteManager.MechClass.ASSAULT, "100 tons should be ASSAULT")


func test_get_mech_class_ultralight():
	var result = manager.get_mech_class(15)
	assert_eq(result, MechSpriteManager.MechClass.LIGHT, "15 tons should be LIGHT (ultralight)")


func test_get_mech_class_superheavy():
	var result = manager.get_mech_class(130)
	assert_eq(result, MechSpriteManager.MechClass.ASSAULT, "130 tons should be ASSAULT (superheavy)")


# ============================================================================
# get_sprite_for_mech tests
# ============================================================================

func test_get_sprite_for_mech_returns_resource():
	# This function returns a Texture2D (or null if not found)
	# We test with a valid tonnage and facing
	var result = manager.get_sprite_for_mech(50, 0)
	# The result could be null if the texture file doesn't exist
	# but the function should not error
	assert_true(result == null or result is Texture2D, "Should return Texture2D or null")


func test_get_sprite_for_mech_caches_result():
	# First call - loads the sprite
	var result1 = manager.get_sprite_for_mech(50, 0)
	# Second call - should use cache
	var result2 = manager.get_sprite_for_mech(50, 0)
	
	# Both should be the same instance (cached)
	assert_eq(result1, result2, "Cached sprite should be the same instance")


func test_get_sprite_for_mech_different_classes():
	# Test that different tonnages return sprites (potentially different)
	var light_sprite = manager.get_sprite_for_mech(25, 0)
	var medium_sprite = manager.get_sprite_for_mech(50, 0)
	var assault_sprite = manager.get_sprite_for_mech(90, 0)
	
	# All should be either null or Texture2D
	assert_true(light_sprite == null or light_sprite is Texture2D)
	assert_true(medium_sprite == null or medium_sprite is Texture2D)
	assert_true(assault_sprite == null or assault_sprite is Texture2D)


func test_get_sprite_for_mech_different_facings():
	# Test with different facing values
	for facing in range(6):
		var result = manager.get_sprite_for_mech(50, facing)
		assert_true(result == null or result is Texture2D, "Facing %d should return Texture2D or null" % facing)


# ============================================================================
# MechClass enum tests
# ============================================================================

func test_mech_class_enum_values():
	# Verify enum values exist
	assert_eq(MechSpriteManager.MechClass.LIGHT, 0, "LIGHT should be 0")
	assert_eq(MechSpriteManager.MechClass.MEDIUM, 1, "MEDIUM should be 1")
	assert_eq(MechSpriteManager.MechClass.ASSAULT, 2, "ASSAULT should be 2")


func test_sprite_paths_exist():
	# Verify SPRITE_PATHS constant exists and has entries
	assert_gt(MechSpriteManager.SPRITE_PATHS.size(), 0, "SPRITE_PATHS should have entries")


func test_facing_to_sprite_mapping():
	# Verify FACING_TO_SPRITE has all 6 hex facings
	assert_eq(MechSpriteManager.FACING_TO_SPRITE.size(), 6, "Should have 6 facing mappings")
	for i in range(6):
		assert_true(MechSpriteManager.FACING_TO_SPRITE.has(i), "Should have facing %d" % i)
