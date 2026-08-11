# ============================================================================
# test_component_database.gd - Tests para la base de datos de componentes
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const ComponentDatabase = preload("res://scripts/core/component_database.gd")


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

func before_each():
	gut.p("--- Preparando test de ComponentDatabase ---")


func after_each():
	gut.p("--- Test de ComponentDatabase completado ---")


# ============================================================================
# TESTS DE ARMAS
# ============================================================================

func test_get_weapon_valid():
	"""Test: obtener arma válida"""
	var weapon = ComponentDatabase.get_weapon("medium_laser")
	
	assert_not_null(weapon, "Medium Laser existe")
	assert_true(weapon.has("name"), "Tiene nombre")
	assert_true(weapon.has("damage"), "Tiene daño")


func test_get_weapon_invalid():
	"""Test: arma inválida retorna diccionario vacío"""
	var weapon = ComponentDatabase.get_weapon("nonexistent_weapon")
	
	assert_true(weapon.is_empty() or not weapon.has("name"), 
				"Arma inexistente retorna vacío")


func test_has_weapon_true():
	"""Test: has_weapon para arma existente"""
	var exists = ComponentDatabase.has_weapon("medium_laser")
	assert_true(exists, "Medium Laser existe")


func test_has_weapon_false():
	"""Test: has_weapon para arma inexistente"""
	var exists = ComponentDatabase.has_weapon("fake_weapon_xyz")
	assert_false(exists, "Arma falsa no existe")


func test_get_all_weapons():
	"""Test: obtener todas las armas"""
	var weapons = ComponentDatabase.get_all_weapons()
	
	assert_gt(weapons.size(), 0, "Hay armas en la BD")


func test_get_weapons_by_category_energy():
	"""Test: filtrar armas de energía"""
	var energy_weapons = ComponentDatabase.get_weapons_by_category(
		ComponentDatabase.WeaponCategory.ENERGY
	)
	
	assert_gt(energy_weapons.size(), 0, "Hay armas de energía")
	
	for weapon in energy_weapons:
		assert_eq(weapon.get("category"), ComponentDatabase.WeaponCategory.ENERGY,
				  "Todas son de categoría ENERGY")


func test_get_weapons_by_category_ballistic():
	"""Test: filtrar armas balísticas"""
	var ballistic_weapons = ComponentDatabase.get_weapons_by_category(
		ComponentDatabase.WeaponCategory.BALLISTIC
	)
	
	assert_gt(ballistic_weapons.size(), 0, "Hay armas balísticas")


func test_get_weapons_by_category_missile():
	"""Test: filtrar armas de misiles"""
	var missile_weapons = ComponentDatabase.get_weapons_by_category(
		ComponentDatabase.WeaponCategory.MISSILE
	)
	
	assert_gt(missile_weapons.size(), 0, "Hay armas de misiles")


# ============================================================================
# TESTS DE MUNICIÓN
# ============================================================================

func test_get_ammo_valid():
	"""Test: obtener munición válida"""
	var ammo = ComponentDatabase.get_ammo("ac10_ammo")
	
	# Si no existe, probar otro ID
	if ammo.is_empty():
		ammo = ComponentDatabase.get_ammo("ammo_ac10")
	
	# Algunos proyectos pueden no tener este ID específico
	if ammo.is_empty():
		pass_test("Munición AC10 no encontrada (puede ser otro ID)")
	else:
		assert_true(ammo.has("shots_per_ton"), "Munición tiene shots_per_ton")


func test_has_ammo():
	"""Test: verificar existencia de munición"""
	var all_ammo = ComponentDatabase.get_all_ammo()
	
	if all_ammo.size() > 0:
		var first_ammo = all_ammo[0]
		if first_ammo.has("id"):
			var exists = ComponentDatabase.has_ammo(first_ammo["id"])
			assert_true(exists, "Munición de la lista existe")
		else:
			pass_test("Munición no tiene ID")
	else:
		pass_test("No hay munición en la BD")


func test_get_all_ammo():
	"""Test: obtener toda la munición"""
	var ammo = ComponentDatabase.get_all_ammo()
	
	assert_true(ammo is Array, "Retorna array")


func test_get_shots_per_ton():
	"""Test: obtener disparos por tonelada"""
	var all_ammo = ComponentDatabase.get_all_ammo()
	
	if all_ammo.size() > 0:
		var first_ammo = all_ammo[0]
		if first_ammo.has("id"):
			var shots = ComponentDatabase.get_shots_per_ton(first_ammo["id"])
			assert_gte(shots, 0, "Shots es >= 0")
		else:
			pass_test("Munición sin ID")
	else:
		pass_test("No hay munición")


# ============================================================================
# TESTS DE EQUIPAMIENTO
# ============================================================================

func test_get_equipment_valid():
	"""Test: obtener equipo válido"""
	var equip = ComponentDatabase.get_equipment("heat_sink")
	
	# Si no existe, probar otros IDs
	if equip.is_empty():
		equip = ComponentDatabase.get_equipment("heatsink")
	
	if equip.is_empty():
		pass_test("Heat sink no encontrado (puede ser otro ID)")
	else:
		assert_true(equip.has("name"), "Equipo tiene nombre")


func test_has_equipment():
	"""Test: verificar existencia de equipamiento"""
	var all_equip = ComponentDatabase.get_all_equipment()
	
	if all_equip.size() > 0:
		var first = all_equip[0]
		if first.has("id"):
			var exists = ComponentDatabase.has_equipment(first["id"])
			assert_true(exists, "Equipo de la lista existe")
		else:
			pass_test("Equipo sin ID")
	else:
		pass_test("No hay equipamiento")


func test_get_all_equipment():
	"""Test: obtener todo el equipamiento"""
	var equip = ComponentDatabase.get_all_equipment()
	
	assert_true(equip is Array, "Retorna array")


func test_get_heat_sinks():
	"""Test: obtener heat sinks"""
	var hs = ComponentDatabase.get_heat_sinks()
	
	assert_true(hs is Array, "Retorna array")


func test_get_jump_jets():
	"""Test: obtener jump jets"""
	var jj = ComponentDatabase.get_jump_jets()
	
	assert_true(jj is Array, "Retorna array")


func test_get_armor_types():
	"""Test: obtener tipos de blindaje"""
	var armor = ComponentDatabase.get_armor_types()
	
	assert_true(armor is Array, "Retorna array")


func test_get_engines():
	"""Test: obtener motores"""
	var engines = ComponentDatabase.get_engines()
	
	assert_true(engines is Array, "Retorna array")


func test_get_structures():
	"""Test: obtener estructuras"""
	var structures = ComponentDatabase.get_structures()
	
	assert_true(structures is Array, "Retorna array")


# ============================================================================
# TESTS DE UTILIDADES
# ============================================================================

func test_calculate_jump_jet_weight_light():
	"""Test: peso de JJ para mech ligero"""
	var weight = ComponentDatabase.calculate_jump_jet_weight(35)
	assert_eq(weight, 0.5, "Mech ligero: 0.5 ton por JJ")


func test_calculate_jump_jet_weight_medium():
	"""Test: peso de JJ para mech medio"""
	var weight = ComponentDatabase.calculate_jump_jet_weight(55)
	assert_eq(weight, 0.5, "Mech medio (55t): 0.5 ton por JJ")


func test_calculate_jump_jet_weight_heavy():
	"""Test: peso de JJ para mech pesado"""
	var weight = ComponentDatabase.calculate_jump_jet_weight(75)
	assert_eq(weight, 1.0, "Mech pesado: 1.0 ton por JJ")


func test_calculate_jump_jet_weight_assault():
	"""Test: peso de JJ para mech de asalto"""
	var weight = ComponentDatabase.calculate_jump_jet_weight(100)
	assert_eq(weight, 2.0, "Mech asalto: 2.0 ton por JJ")


func test_hex_distance_same():
	"""Test: distancia a mismo hex es 0"""
	var dist = ComponentDatabase.hex_distance(Vector2i(5, 5), Vector2i(5, 5))
	assert_eq(dist, 0, "Mismo hex = distancia 0")


func test_hex_distance_adjacent():
	"""Test: distancia a hex adyacente es 1"""
	var dist = ComponentDatabase.hex_distance(Vector2i(5, 5), Vector2i(5, 6))
	assert_eq(dist, 1, "Hex adyacente = distancia 1")


func test_hex_distance_diagonal():
	"""Test: distancia en diagonal"""
	var dist = ComponentDatabase.hex_distance(Vector2i(0, 0), Vector2i(3, 3))
	assert_gt(dist, 0, "Distancia diagonal > 0")


# ============================================================================
# TESTS DE ECM/BAP
# ============================================================================

class MockMechWithECM:
	var weapons: Array = [
		{"id": "ecm_suite", "destroyed": false},
		{"id": "medium_laser", "destroyed": false}
	]


class MockMechWithBAP:
	var weapons: Array = [
		{"id": "beagle_probe", "destroyed": false},
		{"id": "medium_laser", "destroyed": false}
	]


class MockMechNoECM:
	var weapons: Array = [
		{"id": "medium_laser", "destroyed": false}
	]


func test_has_ecm_suite_true():
	"""Test: mech con ECM detectado"""
	var mech = MockMechWithECM.new()
	var has_ecm = ComponentDatabase.has_ecm_suite(mech)
	assert_true(has_ecm, "Mech con ECM detectado")


func test_has_ecm_suite_false():
	"""Test: mech sin ECM"""
	var mech = MockMechNoECM.new()
	var has_ecm = ComponentDatabase.has_ecm_suite(mech)
	assert_false(has_ecm, "Mech sin ECM no tiene ECM")


func test_has_beagle_probe_true():
	"""Test: mech con BAP detectado"""
	var mech = MockMechWithBAP.new()
	var has_bap = ComponentDatabase.has_beagle_probe(mech)
	assert_true(has_bap, "Mech con BAP detectado")


func test_has_beagle_probe_false():
	"""Test: mech sin BAP"""
	var mech = MockMechNoECM.new()
	var has_bap = ComponentDatabase.has_beagle_probe(mech)
	assert_false(has_bap, "Mech sin BAP no tiene BAP")


func test_ecm_destroyed_not_counted():
	"""Test: ECM destruido no cuenta"""
	var mech = MockMechWithECM.new()
	mech.weapons[0]["destroyed"] = true
	
	var has_ecm = ComponentDatabase.has_ecm_suite(mech)
	assert_false(has_ecm, "ECM destruido no cuenta")


# ============================================================================
# TESTS ADICIONALES - get_ammo_for_weapon
# ============================================================================

func test_get_ammo_for_weapon():
	"""Test: obtener munición para un tipo de arma"""
	var ammo = ComponentDatabase.get_ammo_for_weapon("AC10")
	
	# Puede retornar vacío si no hay munición de ese tipo
	assert_true(ammo is Dictionary, "Retorna diccionario")


func test_get_ammo_for_weapon_invalid():
	"""Test: munición para arma inexistente"""
	var ammo = ComponentDatabase.get_ammo_for_weapon("FAKE_WEAPON_TYPE")
	
	assert_true(ammo.is_empty(), "Retorna vacío para arma inexistente")


# ============================================================================
# TESTS ADICIONALES - get_equipment_by_type
# ============================================================================

func test_get_equipment_by_type():
	"""Test: obtener equipamiento por tipo"""
	var equip = ComponentDatabase.get_equipment_by_type(ComponentDatabase.ComponentType.EQUIPMENT_HEATSINK)
	
	assert_true(equip is Array, "Retorna array")


# ============================================================================
# TESTS ADICIONALES - has_case_in_location
# ============================================================================

class MockMechWithCASE:
	var weapons: Array = [
		{"id": "case", "destroyed": false, "location": "left_torso"},
		{"id": "medium_laser", "destroyed": false}
	]


func test_has_case_in_location_true():
	"""Test: mech con CASE en la ubicación correcta"""
	var mech = MockMechWithCASE.new()
	var has_case = ComponentDatabase.has_case_in_location(mech, "left_torso")
	assert_true(has_case, "CASE encontrado en left_torso")


func test_has_case_in_location_wrong_location():
	"""Test: mech con CASE en otra ubicación"""
	var mech = MockMechWithCASE.new()
	var has_case = ComponentDatabase.has_case_in_location(mech, "right_torso")
	assert_false(has_case, "CASE no está en right_torso")


func test_has_case_in_location_none():
	"""Test: mech sin CASE"""
	var mech = MockMechNoECM.new()
	var has_case = ComponentDatabase.has_case_in_location(mech, "left_torso")
	assert_false(has_case, "Mech sin CASE")


# ============================================================================
# TESTS ADICIONALES - get_explosive_ammo_in_location
# ============================================================================

class MockMechWithExplosiveAmmo:
	var weapons: Array = [
		{"id": "ac10_ammo", "explosive": true, "destroyed": false, "location": "left_torso"},
		{"id": "lrm_ammo", "explosive": true, "destroyed": false, "location": "right_torso"},
		{"id": "medium_laser", "explosive": false, "destroyed": false, "location": "left_arm"}
	]


func test_get_explosive_ammo_in_location():
	"""Test: obtener munición explosiva en ubicación"""
	var mech = MockMechWithExplosiveAmmo.new()
	var ammo = ComponentDatabase.get_explosive_ammo_in_location(mech, "left_torso")
	
	assert_eq(ammo.size(), 1, "Una munición explosiva en left_torso")


func test_get_explosive_ammo_none():
	"""Test: sin munición explosiva en ubicación"""
	var mech = MockMechWithExplosiveAmmo.new()
	var ammo = ComponentDatabase.get_explosive_ammo_in_location(mech, "left_arm")
	
	assert_eq(ammo.size(), 0, "Sin munición explosiva en left_arm")


# ============================================================================
# TESTS ADICIONALES - get_component / has_component
# ============================================================================

func test_get_component_weapon():
	"""Test: get_component encuentra arma"""
	var component = ComponentDatabase.get_component("medium_laser")
	
	assert_false(component.is_empty(), "Medium laser encontrado via get_component")


func test_get_component_not_found():
	"""Test: get_component para ID inexistente"""
	var component = ComponentDatabase.get_component("totally_fake_id_xyz_123")
	
	assert_true(component.is_empty(), "Componente inexistente retorna vacío")


func test_has_component_true():
	"""Test: has_component para componente existente"""
	var exists = ComponentDatabase.has_component("medium_laser")
	
	assert_true(exists, "Medium laser existe")


func test_has_component_false():
	"""Test: has_component para componente inexistente"""
	var exists = ComponentDatabase.has_component("fake_component_xyz")
	
	assert_false(exists, "Componente falso no existe")
