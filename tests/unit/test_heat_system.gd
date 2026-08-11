# ============================================================================
# test_heat_system.gd - Tests unitarios para el sistema de calor
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

func before_each():
	gut.p("--- Preparando test de calor ---")


func after_each():
	gut.p("--- Test de calor completado ---")


# ============================================================================
# HELPERS
# ============================================================================

class MockMechHeat:
	"""Mock de un mech para testing de calor"""
	var heat: int = 0
	var heat_sinks: int = 10  # Heat sinks base
	var double_heat_sinks: bool = false
	
	func add_heat(amount: int):
		heat += amount
	
	func dissipate_heat():
		var dissipation = heat_sinks
		if double_heat_sinks:
			dissipation *= 2
		heat = max(0, heat - dissipation)
	
	func get_heat_effects() -> Dictionary:
		"""Retorna los efectos del calor según las reglas de BattleTech"""
		var effects = {
			"to_hit_penalty": 0,
			"movement_penalty": 0,
			"shutdown_risk": 0,
			"ammo_explosion_risk": 0
		}
		
		if heat >= 5:
			effects["to_hit_penalty"] = 1
		if heat >= 8:
			effects["to_hit_penalty"] = 2
			effects["movement_penalty"] = 1
		if heat >= 13:
			effects["to_hit_penalty"] = 3
			effects["movement_penalty"] = 2
			effects["shutdown_risk"] = 4  # 4+ en 2D6
		if heat >= 18:
			effects["to_hit_penalty"] = 4
			effects["movement_penalty"] = 3
			effects["shutdown_risk"] = 6
		if heat >= 23:
			effects["to_hit_penalty"] = 4
			effects["movement_penalty"] = 4
			effects["shutdown_risk"] = 8
			effects["ammo_explosion_risk"] = 4  # 4+ en 2D6
		if heat >= 28:
			effects["shutdown_risk"] = 10
			effects["ammo_explosion_risk"] = 6
		
		return effects


func _create_mock_mech_heat() -> MockMechHeat:
	return MockMechHeat.new()


# ============================================================================
# TESTS DE GENERACIÓN DE CALOR
# ============================================================================

func test_heat_generation():
	"""Test: El calor se genera correctamente"""
	var mech = _create_mock_mech_heat()
	
	mech.add_heat(5)
	
	assert_eq(mech.heat, 5, "Calor debería ser 5")


func test_heat_accumulation():
	"""Test: El calor se acumula"""
	var mech = _create_mock_mech_heat()
	
	mech.add_heat(3)
	mech.add_heat(4)
	
	assert_eq(mech.heat, 7, "Calor debería acumularse a 7")


# ============================================================================
# TESTS DE DISIPACIÓN DE CALOR
# ============================================================================

func test_heat_dissipation_normal():
	"""Test: Disipación normal con 10 heat sinks"""
	var mech = _create_mock_mech_heat()
	mech.heat = 15
	mech.heat_sinks = 10
	
	mech.dissipate_heat()
	
	assert_eq(mech.heat, 5, "Calor debería reducirse a 5")


func test_heat_dissipation_double():
	"""Test: Disipación con double heat sinks"""
	var mech = _create_mock_mech_heat()
	mech.heat = 25
	mech.heat_sinks = 10
	mech.double_heat_sinks = true
	
	mech.dissipate_heat()
	
	assert_eq(mech.heat, 5, "Calor debería reducirse a 5 con DHS")


func test_heat_cannot_go_negative():
	"""Test: El calor no puede ser negativo"""
	var mech = _create_mock_mech_heat()
	mech.heat = 5
	mech.heat_sinks = 10
	
	mech.dissipate_heat()
	
	assert_eq(mech.heat, 0, "Calor no debería ser negativo")


# ============================================================================
# TESTS DE EFECTOS DEL CALOR
# ============================================================================

func test_heat_effects_none():
	"""Test: Sin efectos bajo calor 5"""
	var mech = _create_mock_mech_heat()
	mech.heat = 4
	
	var effects = mech.get_heat_effects()
	
	assert_eq(effects["to_hit_penalty"], 0, "Sin penalización bajo calor 5")
	assert_eq(effects["shutdown_risk"], 0, "Sin riesgo de shutdown bajo calor 13")


func test_heat_effects_moderate():
	"""Test: Efectos moderados (calor 8-12)"""
	var mech = _create_mock_mech_heat()
	mech.heat = 10
	
	var effects = mech.get_heat_effects()
	
	assert_eq(effects["to_hit_penalty"], 2, "+2 to-hit con calor 10")
	assert_eq(effects["movement_penalty"], 1, "-1 MP con calor 10")


func test_heat_effects_high():
	"""Test: Efectos severos (calor 18+)"""
	var mech = _create_mock_mech_heat()
	mech.heat = 20
	
	var effects = mech.get_heat_effects()
	
	assert_eq(effects["to_hit_penalty"], 4, "+4 to-hit con calor 20")
	assert_eq(effects["movement_penalty"], 3, "-3 MP con calor 20")
	assert_gt(effects["shutdown_risk"], 0, "Riesgo de shutdown con calor 20")


func test_heat_effects_critical():
	"""Test: Efectos críticos (calor 23+)"""
	var mech = _create_mock_mech_heat()
	mech.heat = 25
	
	var effects = mech.get_heat_effects()
	
	assert_gt(effects["ammo_explosion_risk"], 0, "Riesgo de explosión con calor 25")


# ============================================================================
# TESTS DE ESCENARIOS DE COMBATE
# ============================================================================

func test_heat_scenario_alpha_strike():
	"""Test: Escenario - Alpha strike genera mucho calor"""
	var mech = _create_mock_mech_heat()
	mech.heat_sinks = 15
	
	# Simular alpha strike con múltiples armas
	var weapons_heat = [8, 8, 5, 3, 3]  # 2 PPC, Large Laser, 2 Medium Lasers
	
	for heat in weapons_heat:
		mech.add_heat(heat)
	
	# Total: 27 de calor
	assert_eq(mech.heat, 27, "Alpha strike debería generar 27 de calor")
	
	# Verificar efectos
	var effects = mech.get_heat_effects()
	assert_gt(effects["shutdown_risk"], 0, "Debería haber riesgo de shutdown")


func test_heat_scenario_sustained_fire():
	"""Test: Escenario - Fuego sostenido con disipación"""
	var mech = _create_mock_mech_heat()
	mech.heat_sinks = 12
	
	# Turno 1: Dispara y genera 8 de calor
	mech.add_heat(8)
	assert_eq(mech.heat, 8)
	
	# Fin de turno: Disipa
	mech.dissipate_heat()
	assert_eq(mech.heat, 0, "12 HS deberían disipar 8 de calor")
	
	# Turno 2: Dispara más
	mech.add_heat(15)
	assert_eq(mech.heat, 15)
	
	# Fin de turno: Disipa
	mech.dissipate_heat()
	assert_eq(mech.heat, 3, "Debería quedar 3 de calor residual")


# ============================================================================
# TESTS DE FUNCIONES ESTÁTICAS DE HeatSystem
# ============================================================================

const HeatSystem = preload("res://scripts/core/combat/heat_system.gd")

class MockMechForHeatSystem:
	var heat: int = 0
	var heat_dissipation: int = 10
	var is_shutdown: bool = false


func test_heatsystem_get_heat_effects():
	"""Test: HeatSystem.get_heat_effects retorna efectos correctos"""
	var effects = HeatSystem.get_heat_effects(0)
	assert_eq(effects["name"], "Normal", "Calor 0 = Normal")
	
	effects = HeatSystem.get_heat_effects(14)
	assert_eq(effects["name"], "Critical Heat", "Calor 14 = Critical Heat")


func test_heatsystem_get_heat_status_color():
	"""Test: HeatSystem.get_heat_status_color retorna colores"""
	var color_low = HeatSystem.get_heat_status_color(5, 30)
	assert_eq(color_low, Color.GREEN, "Calor bajo = verde")
	
	var color_high = HeatSystem.get_heat_status_color(25, 30)
	assert_eq(color_high, Color.RED, "Calor alto = rojo")


func test_heatsystem_calculate_movement_heat():
	"""Test: HeatSystem.calculate_movement_heat calcula correctamente"""
	var walk_heat = HeatSystem.calculate_movement_heat(1, 5)  # WALK
	assert_eq(walk_heat, 0, "Caminar no genera calor")
	
	var run_heat = HeatSystem.calculate_movement_heat(2, 5)  # RUN
	assert_eq(run_heat, 2, "Correr genera 2 calor")
	
	var jump_heat = HeatSystem.calculate_movement_heat(3, 4)  # JUMP
	assert_eq(jump_heat, 4, "Saltar 4 hexes = 4 calor")


func test_heatsystem_check_shutdown():
	"""Test: HeatSystem.check_shutdown verifica shutdown"""
	var result_low = HeatSystem.check_shutdown(10)
	assert_false(result_low["must_shutdown"], "Calor bajo no causa shutdown")
	
	var result_max = HeatSystem.check_shutdown(30)
	assert_true(result_max["must_shutdown"], "Calor 30 = shutdown automático")


func test_heatsystem_check_ammo_explosion():
	"""Test: HeatSystem.check_ammo_explosion verifica explosiones"""
	var result_low = HeatSystem.check_ammo_explosion(10)
	assert_false(result_low["explodes"], "Calor bajo no causa explosión")


func test_heatsystem_apply_heat_dissipation():
	"""Test: HeatSystem.apply_heat_dissipation disipa calor"""
	var mech = MockMechForHeatSystem.new()
	mech.heat = 15
	mech.heat_dissipation = 10
	
	var result = HeatSystem.apply_heat_dissipation(mech)
	
	assert_eq(result["heat_removed"], 10, "Disipó 10 calor")
	assert_eq(mech.heat, 5, "Mech tiene 5 calor restante")


func test_heatsystem_get_heat_description():
	"""Test: HeatSystem.get_heat_description retorna descripción"""
	var desc = HeatSystem.get_heat_description(0)
	assert_eq(desc, "Normal", "Descripción de calor 0")
