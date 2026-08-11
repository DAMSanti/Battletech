# ============================================================================
# test_physical_attack_system.gd - Tests para el sistema de ataques físicos
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const PhysicalAttackSystem = preload("res://scripts/core/combat/physical_attack_system.gd")


# ============================================================================
# MOCK HELPERS
# ============================================================================

class MockMech:
	var pilot_skill: int = 4
	var target_movement_modifier: int = 0
	var heat: int = 0
	var is_prone: bool = false
	var movement_type_used: int = 0
	var hexes_moved_this_turn: int = 0
	var structure: Dictionary = {
		"left_arm": {"current": 10},
		"right_arm": {"current": 10},
		"left_leg": {"current": 10},
		"right_leg": {"current": 10}
	}


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

func before_each():
	gut.p("--- Preparando test de PhysicalAttackSystem ---")


func after_each():
	gut.p("--- Test de PhysicalAttackSystem completado ---")


# ============================================================================
# TESTS DE CÁLCULO DE DAÑO
# ============================================================================

func test_punch_damage_light_mech():
	"""Test: daño de puñetazo para mech ligero"""
	var damage = PhysicalAttackSystem.calculate_punch_damage(35)
	assert_eq(damage, 4, "35 tons / 10 = 4 daño")


func test_punch_damage_medium_mech():
	"""Test: daño de puñetazo para mech medio"""
	var damage = PhysicalAttackSystem.calculate_punch_damage(55)
	assert_eq(damage, 6, "55 tons / 10 = 6 daño (redondeado)")


func test_punch_damage_heavy_mech():
	"""Test: daño de puñetazo para mech pesado"""
	var damage = PhysicalAttackSystem.calculate_punch_damage(75)
	assert_eq(damage, 8, "75 tons / 10 = 8 daño")


func test_punch_damage_assault_mech():
	"""Test: daño de puñetazo para mech de asalto"""
	var damage = PhysicalAttackSystem.calculate_punch_damage(100)
	assert_eq(damage, 10, "100 tons / 10 = 10 daño")


func test_kick_damage():
	"""Test: daño de patada es doble del puñetazo"""
	var punch_damage = PhysicalAttackSystem.calculate_punch_damage(50)
	var kick_damage = PhysicalAttackSystem.calculate_kick_damage(50)
	
	assert_eq(kick_damage, 10, "50 tons / 5 = 10 daño")
	assert_eq(kick_damage, punch_damage * 2, "Patada = 2x puñetazo")


func test_charge_damage_base():
	"""Test: daño de embestida basado en hexes movidos"""
	var damage_2hex = PhysicalAttackSystem.calculate_charge_damage(80, 2)
	var damage_5hex = PhysicalAttackSystem.calculate_charge_damage(80, 5)
	
	assert_eq(damage_2hex, 16, "80t / 10 * 2 hexes = 16 daño")
	assert_eq(damage_5hex, 40, "80t / 10 * 5 hexes = 40 daño")


func test_charge_self_damage():
	"""Test: autolesión por embestida"""
	var self_damage = PhysicalAttackSystem.apply_charge_self_damage(null, 30)
	assert_eq(self_damage, 3, "30 daño causado / 10 = 3 autolesión")


# ============================================================================
# TESTS DE CÁLCULO TO-HIT
# ============================================================================

func test_calculate_to_hit_punch():
	"""Test: cálculo base de to-hit para puñetazo"""
	var attacker = MockMech.new()
	var target = MockMech.new()
	
	var result = PhysicalAttackSystem.calculate_to_hit(
		attacker, target, 
		PhysicalAttackSystem.AttackType.PUNCH
	)
	
	# Base 4 + pilot skill 4 = 8
	assert_eq(result["target_number"], 8, "Target number base = 8")


func test_calculate_to_hit_kick_penalty():
	"""Test: patada tiene +2 de penalizador"""
	var attacker = MockMech.new()
	var target = MockMech.new()
	
	var result = PhysicalAttackSystem.calculate_to_hit(
		attacker, target,
		PhysicalAttackSystem.AttackType.KICK
	)
	
	# Base 4 + pilot 4 + kick 2 = 10
	assert_eq(result["target_number"], 10, "Kick = +2 más difícil")
	assert_eq(result["modifiers"]["kick"], 2, "Modificador de kick presente")


func test_calculate_to_hit_charge_bonus():
	"""Test: embestida tiene -2 de bonus"""
	var attacker = MockMech.new()
	var target = MockMech.new()
	
	var result = PhysicalAttackSystem.calculate_to_hit(
		attacker, target,
		PhysicalAttackSystem.AttackType.CHARGE
	)
	
	# Base 4 + pilot 4 - charge 2 = 6
	assert_eq(result["target_number"], 6, "Charge = -2 más fácil")
	assert_eq(result["modifiers"]["charge"], -2, "Modificador de charge presente")


func test_calculate_to_hit_target_tmm():
	"""Test: TMM del objetivo se aplica"""
	var attacker = MockMech.new()
	var target = MockMech.new()
	target.target_movement_modifier = 2
	
	var result = PhysicalAttackSystem.calculate_to_hit(
		attacker, target,
		PhysicalAttackSystem.AttackType.PUNCH
	)
	
	# Base 4 + pilot 4 + TMM 2 = 10
	assert_eq(result["target_number"], 10, "TMM se aplica")
	assert_eq(result["modifiers"]["target_tmm"], 2, "Modificador TMM presente")


func test_calculate_to_hit_heat_penalty():
	"""Test: calor aplica penalizador"""
	var attacker = MockMech.new()
	attacker.heat = 10
	var target = MockMech.new()
	
	var result = PhysicalAttackSystem.calculate_to_hit(
		attacker, target,
		PhysicalAttackSystem.AttackType.PUNCH
	)
	
	# Base 4 + pilot 4 + heat 2 = 10
	assert_true(result["modifiers"].has("heat"), "Penalizador de calor aplicado")


func test_calculate_to_hit_prone_target():
	"""Test: objetivo caído es más fácil de golpear"""
	var attacker = MockMech.new()
	var target = MockMech.new()
	target.is_prone = true
	
	var result = PhysicalAttackSystem.calculate_to_hit(
		attacker, target,
		PhysicalAttackSystem.AttackType.PUNCH
	)
	
	# Base 4 + pilot 4 - prone 2 = 6
	assert_eq(result["target_number"], 6, "Target prone = -2")
	assert_eq(result["modifiers"]["target_prone"], -2, "Modificador prone presente")


# ============================================================================
# TESTS DE TIRADAS
# ============================================================================

func test_roll_to_hit_range():
	"""Test: tirada de 2D6 está en rango válido"""
	for _i in range(20):
		var roll = PhysicalAttackSystem.roll_to_hit()
		assert_gte(roll, 2, "Mínimo 2")
		assert_lte(roll, 12, "Máximo 12")


func test_check_hit_success():
	"""Test: verificar impacto exitoso"""
	var hit = PhysicalAttackSystem.check_hit(8, 8)
	assert_true(hit, "8 vs 8 = impacto")


func test_check_hit_failure():
	"""Test: verificar fallo"""
	var hit = PhysicalAttackSystem.check_hit(5, 8)
	assert_false(hit, "5 vs 8 = fallo")


func test_check_hit_critical_failure():
	"""Test: 2 siempre falla"""
	var hit = PhysicalAttackSystem.check_hit(2, 2)
	assert_false(hit, "2 = fallo crítico siempre")


func test_check_hit_critical_success():
	"""Test: 12 siempre impacta"""
	var hit = PhysicalAttackSystem.check_hit(12, 15)
	assert_true(hit, "12 = impacto crítico siempre")


# ============================================================================
# TESTS DE CHECK FALL AFTER KICK
# ============================================================================

class MockMechWithPiloting:
	var pilot_skill: int = 4
	var will_fail_piloting: bool = false
	
	func check_piloting_skill_roll(_modifier: int) -> bool:
		return not will_fail_piloting


func test_check_fall_after_kick_no_fall():
	"""Test: atacante no cae si pasa pilotaje"""
	var attacker = MockMechWithPiloting.new()
	attacker.will_fail_piloting = false
	
	var falls = PhysicalAttackSystem.check_fall_after_kick(attacker)
	
	assert_false(falls, "No cae si pasa pilotaje")


func test_check_fall_after_kick_falls():
	"""Test: atacante cae si falla pilotaje"""
	var attacker = MockMechWithPiloting.new()
	attacker.will_fail_piloting = true
	
	var falls = PhysicalAttackSystem.check_fall_after_kick(attacker)
	
	assert_true(falls, "Cae si falla pilotaje")


func test_check_fall_after_kick_no_method():
	"""Test: no cae si mech no tiene método de pilotaje"""
	var attacker = MockMech.new()  # Doesn't have check_piloting_skill_roll
	
	var falls = PhysicalAttackSystem.check_fall_after_kick(attacker)
	
	assert_false(falls, "No cae si no tiene método pilotaje")


# ============================================================================
# TESTS DE LOCALIZACIÓN DE IMPACTO
# ============================================================================

func test_roll_punch_location():
	"""Test: localización de puñetazo es válida"""
	var valid_locations = [
		"head", "left_torso", "right_torso", 
		"center_torso", "left_arm", "right_arm"
	]
	
	for _i in range(20):
		var location = PhysicalAttackSystem.roll_punch_location()
		assert_true(location in valid_locations, 
					"Ubicación '%s' es válida para puñetazo" % location)


func test_roll_kick_location():
	"""Test: localización de patada solo piernas"""
	var valid_locations = ["left_leg", "right_leg"]
	
	for _i in range(20):
		var location = PhysicalAttackSystem.roll_kick_location()
		assert_true(location in valid_locations, 
					"Ubicación '%s' es válida para patada" % location)


# ============================================================================
# TESTS DE VALIDACIÓN DE ACCIONES
# ============================================================================

func test_can_punch_healthy_arm():
	"""Test: puede golpear con brazo sano"""
	var mech = MockMech.new()
	
	var result = PhysicalAttackSystem.can_punch(mech, "left")
	
	assert_true(result["can_punch"], "Brazo sano puede golpear")


func test_can_punch_destroyed_arm():
	"""Test: no puede golpear con brazo destruido"""
	var mech = MockMech.new()
	mech.structure["left_arm"]["current"] = 0
	
	var result = PhysicalAttackSystem.can_punch(mech, "left")
	
	assert_false(result["can_punch"], "Brazo destruido no puede golpear")
	assert_eq(result["reason"], "Arm destroyed", "Razón correcta")


func test_can_kick_healthy_legs():
	"""Test: puede patear con piernas sanas"""
	var mech = MockMech.new()
	
	var result = PhysicalAttackSystem.can_kick(mech)
	
	assert_true(result["can_kick"], "Piernas sanas pueden patear")


func test_can_kick_all_legs_destroyed():
	"""Test: no puede patear con ambas piernas destruidas"""
	var mech = MockMech.new()
	mech.structure["left_leg"]["current"] = 0
	mech.structure["right_leg"]["current"] = 0
	
	var result = PhysicalAttackSystem.can_kick(mech)
	
	assert_false(result["can_kick"], "Sin piernas no puede patear")


func test_can_kick_while_prone():
	"""Test: no puede patear mientras caído"""
	var mech = MockMech.new()
	mech.is_prone = true
	
	var result = PhysicalAttackSystem.can_kick(mech)
	
	assert_false(result["can_kick"], "Caído no puede patear")
	assert_true("prone" in result["reason"].to_lower(), "Razón menciona prone")


func test_can_charge_valid():
	"""Test: puede embestir si corrió suficiente"""
	var mech = MockMech.new()
	mech.movement_type_used = 2  # RUN
	mech.hexes_moved_this_turn = 4
	
	var result = PhysicalAttackSystem.can_charge(mech)
	
	assert_true(result["can_charge"], "Corrió 4 hexes = puede embestir")


func test_can_charge_didnt_run():
	"""Test: no puede embestir sin correr"""
	var mech = MockMech.new()
	mech.movement_type_used = 1  # WALK
	mech.hexes_moved_this_turn = 4
	
	var result = PhysicalAttackSystem.can_charge(mech)
	
	assert_false(result["can_charge"], "Caminó = no puede embestir")


func test_can_charge_not_enough_hexes():
	"""Test: no puede embestir con poco movimiento"""
	var mech = MockMech.new()
	mech.movement_type_used = 2  # RUN
	mech.hexes_moved_this_turn = 1
	
	var result = PhysicalAttackSystem.can_charge(mech)
	
	assert_false(result["can_charge"], "Solo 1 hex = no puede embestir")
