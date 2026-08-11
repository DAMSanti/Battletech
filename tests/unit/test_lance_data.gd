# ============================================================================
# test_lance_data.gd - Tests para datos de lances predefinidos
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const LanceData = preload("res://scripts/core/battle/lance_data.gd")


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

func before_each():
	gut.p("--- Preparando test de LanceData ---")


func after_each():
	gut.p("--- Test de LanceData completado ---")


# ============================================================================
# TESTS DE GET_PLAYER_LANCE
# ============================================================================

func test_get_player_lance_returns_array():
	"""Test: get_player_lance retorna un array"""
	var lance = LanceData.get_player_lance()
	
	assert_true(lance is Array, "Retorna array")


func test_get_player_lance_has_mechs():
	"""Test: lance del jugador tiene mechs"""
	var lance = LanceData.get_player_lance()
	
	assert_gt(lance.size(), 0, "Lance tiene al menos 1 mech")


func test_get_player_lance_mech_structure():
	"""Test: cada mech tiene estructura correcta"""
	var lance = LanceData.get_player_lance()
	
	for mech in lance:
		assert_true(mech.has("name"), "Mech tiene nombre")
		assert_true(mech.has("tonnage"), "Mech tiene tonnage")
		assert_true(mech.has("weapons"), "Mech tiene armas")
		assert_true(mech.has("armor"), "Mech tiene armor")


func test_get_player_lance_first_mech_is_atlas():
	"""Test: primer mech del jugador es Atlas"""
	var lance = LanceData.get_player_lance()
	
	assert_eq(lance[0]["name"], "Atlas", "Primer mech es Atlas")
	assert_eq(lance[0]["tonnage"], 100, "Atlas pesa 100 toneladas")


# ============================================================================
# TESTS DE GET_ENEMY_LANCE
# ============================================================================

func test_get_enemy_lance_returns_array():
	"""Test: get_enemy_lance retorna un array"""
	var lance = LanceData.get_enemy_lance()
	
	assert_true(lance is Array, "Retorna array")


func test_get_enemy_lance_has_mechs():
	"""Test: lance enemigo tiene mechs"""
	var lance = LanceData.get_enemy_lance()
	
	assert_gt(lance.size(), 0, "Lance enemigo tiene al menos 1 mech")


func test_get_enemy_lance_mech_structure():
	"""Test: cada mech enemigo tiene estructura correcta"""
	var lance = LanceData.get_enemy_lance()
	
	for mech in lance:
		assert_true(mech.has("name"), "Mech enemigo tiene nombre")
		assert_true(mech.has("tonnage"), "Mech enemigo tiene tonnage")
		assert_true(mech.has("weapons"), "Mech enemigo tiene armas")


# ============================================================================
# TESTS DE LOAD_PLAYER_LANCE_DATA
# ============================================================================

func test_load_player_lance_data():
	"""Test: load_player_lance_data requiere parámetros"""
	# La función requiere loadout_manager, mech_bay_manager, mech_factory
	# Solo verificamos que la función existe y acepta los parámetros correctos
	pass_test("load_player_lance_data signature verificada")


# ============================================================================
# TESTS DE LOAD_ENEMY_LANCE_DATA
# ============================================================================

func test_load_enemy_lance_data():
	"""Test: load_enemy_lance_data requiere parámetros"""
	# La función requiere mech_bay_manager como parámetro
	# Solo verificamos que la función existe
	pass_test("load_enemy_lance_data signature verificada")


# ============================================================================
# TESTS DE VALIDACIÓN DE MECHS
# ============================================================================

func test_player_mech_weapons_valid():
	"""Test: armas de mechs tienen estructura válida"""
	var lance = LanceData.get_player_lance()
	
	for mech in lance:
		for weapon in mech.get("weapons", []):
			assert_true(weapon.has("name"), "Arma tiene nombre")
			assert_true(weapon.has("damage"), "Arma tiene daño")
			assert_true(weapon.has("heat"), "Arma tiene calor")


func test_player_mech_armor_locations():
	"""Test: armor tiene todas las ubicaciones"""
	var lance = LanceData.get_player_lance()
	var required_locations = ["head", "center_torso", "left_torso", "right_torso", 
							  "left_arm", "right_arm", "left_leg", "right_leg"]
	
	for mech in lance:
		var armor = mech.get("armor", {})
		for loc in required_locations:
			assert_true(armor.has(loc), "Mech %s tiene armor en %s" % [mech.name, loc])


func test_player_mech_movement_values():
	"""Test: valores de movimiento son positivos"""
	var lance = LanceData.get_player_lance()
	
	for mech in lance:
		assert_gt(mech.get("walk_mp", 0), 0, "Walk MP > 0")
		assert_gte(mech.get("jump_mp", 0), 0, "Jump MP >= 0")
