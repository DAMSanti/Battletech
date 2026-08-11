# ============================================================================
# test_weapon_system.gd - Tests unitarios para el sistema de armas
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const WeaponSystem = preload("res://scripts/core/combat/weapon_system.gd")


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

func before_each():
	gut.p("--- Preparando test de armas ---")


func after_each():
	gut.p("--- Test de armas completado ---")


# ============================================================================
# HELPERS
# ============================================================================

class MockAttacker:
	var pilot_gunnery: int = 4
	var heat: int = 0
	var moved_this_turn: bool = false
	var ran_this_turn: bool = false
	var is_prone: bool = false


class MockTarget:
	var moved_this_turn: bool = false
	var ran_this_turn: bool = false


func _create_attacker(gunnery: int = 4) -> MockAttacker:
	var attacker = MockAttacker.new()
	attacker.pilot_gunnery = gunnery
	return attacker


func _create_target() -> MockTarget:
	return MockTarget.new()


func _create_weapon(damage: int = 10, short: int = 3, medium: int = 6, long: int = 9) -> Dictionary:
	return {
		"name": "Test Laser",
		"damage": damage,
		"short_range": short,
		"medium_range": medium,
		"long_range": long,
		"heat": 4
	}


# ============================================================================
# TESTS DE CÁLCULO TO-HIT
# ============================================================================

func test_calculate_to_hit_base():
	"""Test: To-hit base es la habilidad de artillería del piloto"""
	var attacker = _create_attacker(4)
	var target = _create_target()
	var weapon = _create_weapon()
	
	var to_hit = WeaponSystem.calculate_to_hit(attacker, target, weapon, 2)
	
	# Rango corto (2 hexes), sin modificadores = gunnery base
	assert_eq(to_hit, 4, "To-hit debería ser 4 (gunnery base)")


func test_calculate_to_hit_medium_range():
	"""Test: Rango medio añade +2"""
	var attacker = _create_attacker(4)
	var target = _create_target()
	var weapon = _create_weapon()
	
	var to_hit = WeaponSystem.calculate_to_hit(attacker, target, weapon, 5)
	
	# Rango medio = +2
	assert_eq(to_hit, 6, "To-hit debería ser 6 (4 + 2 rango medio)")


func test_calculate_to_hit_long_range():
	"""Test: Rango largo añade +4"""
	var attacker = _create_attacker(4)
	var target = _create_target()
	var weapon = _create_weapon()
	
	var to_hit = WeaponSystem.calculate_to_hit(attacker, target, weapon, 8)
	
	# Rango largo = +4
	assert_eq(to_hit, 8, "To-hit debería ser 8 (4 + 4 rango largo)")


func test_calculate_to_hit_out_of_range():
	"""Test: Fuera de rango retorna -1"""
	var attacker = _create_attacker(4)
	var target = _create_target()
	var weapon = _create_weapon()
	
	var to_hit = WeaponSystem.calculate_to_hit(attacker, target, weapon, 15)
	
	assert_eq(to_hit, -1, "Fuera de rango debería retornar -1")


func test_calculate_to_hit_attacker_moved():
	"""Test: Atacante que se movió tiene +1"""
	var attacker = _create_attacker(4)
	attacker.moved_this_turn = true
	var target = _create_target()
	var weapon = _create_weapon()
	
	var to_hit = WeaponSystem.calculate_to_hit(attacker, target, weapon, 2)
	
	assert_eq(to_hit, 5, "To-hit debería ser 5 (4 + 1 movimiento)")


func test_calculate_to_hit_attacker_ran():
	"""Test: Atacante que corrió tiene +2"""
	var attacker = _create_attacker(4)
	attacker.moved_this_turn = true
	attacker.ran_this_turn = true
	var target = _create_target()
	var weapon = _create_weapon()
	
	var to_hit = WeaponSystem.calculate_to_hit(attacker, target, weapon, 2)
	
	assert_eq(to_hit, 6, "To-hit debería ser 6 (4 + 2 corriendo)")


func test_calculate_to_hit_target_moved():
	"""Test: Objetivo que se movió tiene +1 para impactarle"""
	var attacker = _create_attacker(4)
	var target = _create_target()
	target.moved_this_turn = true
	var weapon = _create_weapon()
	
	var to_hit = WeaponSystem.calculate_to_hit(attacker, target, weapon, 2)
	
	assert_eq(to_hit, 5, "To-hit debería ser 5 (4 + 1 objetivo moviéndose)")


func test_calculate_to_hit_high_heat():
	"""Test: Calor alto penaliza precisión"""
	var attacker = _create_attacker(4)
	attacker.heat = 15
	var target = _create_target()
	var weapon = _create_weapon()
	
	var to_hit = WeaponSystem.calculate_to_hit(attacker, target, weapon, 2)
	
	# Heat 13+ = +2 penalty
	assert_eq(to_hit, 6, "To-hit debería ser 6 (4 + 2 calor)")


func test_calculate_to_hit_prone():
	"""Test: Atacante tumbado tiene +2"""
	var attacker = _create_attacker(4)
	attacker.is_prone = true
	var target = _create_target()
	var weapon = _create_weapon()
	
	var to_hit = WeaponSystem.calculate_to_hit(attacker, target, weapon, 2)
	
	assert_eq(to_hit, 6, "To-hit debería ser 6 (4 + 2 tumbado)")


func test_calculate_to_hit_combined_modifiers():
	"""Test: Múltiples modificadores se suman"""
	var attacker = _create_attacker(4)
	attacker.moved_this_turn = true  # +1
	attacker.heat = 10               # +1
	var target = _create_target()
	target.moved_this_turn = true    # +1
	var weapon = _create_weapon()
	
	var to_hit = WeaponSystem.calculate_to_hit(attacker, target, weapon, 5)  # +2 rango medio
	
	# 4 + 2 (rango) + 1 (mov atacante) + 1 (mov objetivo) + 1 (calor) = 9
	assert_eq(to_hit, 9, "To-hit debería sumar todos los modificadores")


# ============================================================================
# TESTS DE ROLL TO-HIT
# ============================================================================

func test_roll_to_hit_impossible():
	"""Test: Target > 12 siempre falla"""
	# Con target 13+, es imposible acertar con 2d6
	var result = WeaponSystem.roll_to_hit(13)
	assert_false(result, "Target 13+ debería ser imposible")


func test_roll_to_hit_minimum():
	"""Test: Target < 2 se convierte en 2"""
	# Ejecutar múltiples veces para probar
	var successes = 0
	for i in range(100):
		if WeaponSystem.roll_to_hit(1):
			successes += 1
	
	# Con target 2, casi siempre deberíamos acertar (97% probabilidad)
	assert_gt(successes, 80, "Target 2 debería acertar casi siempre")


# ============================================================================
# TESTS DE DAÑO
# ============================================================================

func test_calculate_damage():
	"""Test: El daño es el del arma"""
	var weapon = _create_weapon(15)
	
	var damage = WeaponSystem.calculate_damage(weapon)
	
	assert_eq(damage, 15, "Daño debería ser 15")


func test_calculate_damage_default():
	"""Test: Daño por defecto es 5"""
	var weapon = {}  # Sin damage definido
	
	var damage = WeaponSystem.calculate_damage(weapon)
	
	assert_eq(damage, 5, "Daño por defecto debería ser 5")


# ============================================================================
# TESTS DE HIT LOCATION
# ============================================================================

func test_determine_hit_location_returns_valid():
	"""Test: La localización de impacto es válida"""
	var valid_locations = [
		"head", "center_torso", "left_torso", "right_torso",
		"left_arm", "right_arm", "left_leg", "right_leg"
	]
	
	for i in range(50):
		var location = WeaponSystem.determine_hit_location()
		assert_has(valid_locations, location, "Localización debería ser válida")
