# ============================================================================
# test_mech_loadout.gd - Tests para el sistema de loadout de mechs
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const MechLoadout = preload("res://scripts/core/mech_loadout.gd")


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

var loadout: MechLoadout

func before_each():
	gut.p("--- Preparando test de MechLoadout ---")
	loadout = MechLoadout.new()


func after_each():
	gut.p("--- Test de MechLoadout completado ---")
	if loadout:
		loadout.queue_free()


# ============================================================================
# TESTS DE GET_AVAILABLE_SLOTS
# ============================================================================

func test_get_available_slots_head():
	"""Test: head tiene 6 slots totales menos los fijos"""
	var slots = loadout.get_available_slots(MechLoadout.MechLocation.HEAD)
	
	# Head tiene 6 slots, pero Life Support(1), Sensors(2), Cockpit(1) = 4 fijos
	# Disponibles = 6 - 4 = 2
	assert_eq(slots, 2, "Head tiene 2 slots disponibles")


func test_get_available_slots_arms():
	"""Test: brazos tienen actuadores fijos"""
	var left_slots = loadout.get_available_slots(MechLoadout.MechLocation.LEFT_ARM)
	var right_slots = loadout.get_available_slots(MechLoadout.MechLocation.RIGHT_ARM)
	
	# Brazos: 12 slots - 4 (actuadores) = 8 disponibles
	assert_eq(left_slots, 8, "Left arm tiene 8 slots disponibles")
	assert_eq(right_slots, 8, "Right arm tiene 8 slots disponibles")


func test_get_available_slots_legs():
	"""Test: piernas tienen actuadores fijos"""
	var left_slots = loadout.get_available_slots(MechLoadout.MechLocation.LEFT_LEG)
	var right_slots = loadout.get_available_slots(MechLoadout.MechLocation.RIGHT_LEG)
	
	# Piernas: 6 slots - 4 (actuadores) = 2 disponibles
	assert_eq(left_slots, 2, "Left leg tiene 2 slots disponibles")
	assert_eq(right_slots, 2, "Right leg tiene 2 slots disponibles")


func test_get_available_slots_torsos():
	"""Test: torsos laterales tienen más espacio"""
	var left_slots = loadout.get_available_slots(MechLoadout.MechLocation.LEFT_TORSO)
	var right_slots = loadout.get_available_slots(MechLoadout.MechLocation.RIGHT_TORSO)
	
	# Torsos laterales: 12 slots sin componentes fijos
	assert_eq(left_slots, 12, "Left torso tiene 12 slots")
	assert_eq(right_slots, 12, "Right torso tiene 12 slots")


# ============================================================================
# TESTS DE CALCULATE_ENGINE_WEIGHT
# ============================================================================

func test_calculate_engine_weight_small():
	"""Test: motor pequeño pesa poco"""
	loadout.engine_rating = 100
	var weight = loadout.calculate_engine_weight()
	
	assert_eq(weight, 3.0, "Engine 100 = 3.0 tons")


func test_calculate_engine_weight_medium():
	"""Test: motor medio pesa más"""
	loadout.engine_rating = 200
	var weight = loadout.calculate_engine_weight()
	
	assert_eq(weight, 8.5, "Engine 200 = 8.5 tons")


func test_calculate_engine_weight_large():
	"""Test: motor grande pesa mucho"""
	loadout.engine_rating = 300
	var weight = loadout.calculate_engine_weight()
	
	assert_eq(weight, 22.5, "Engine 300 = 22.5 tons")


# ============================================================================
# TESTS DE ADD_COMPONENT
# ============================================================================

func test_add_component_success():
	"""Test: añadir componente válido"""
	var component = {
		"name": "Medium Laser",
		"slots": 1,
		"weight": 1.0
	}
	
	var result = loadout.add_component(MechLoadout.MechLocation.LEFT_TORSO, component)
	
	assert_true(result, "Componente añadido exitosamente")


func test_add_component_no_space():
	"""Test: añadir componente sin espacio falla"""
	# Llenar el head (solo 2 slots disponibles)
	var big_component = {
		"name": "Big Component",
		"slots": 10,
		"weight": 5.0
	}
	
	var result = loadout.add_component(MechLoadout.MechLocation.HEAD, big_component)
	
	assert_false(result, "Componente grande no cabe en head")


# ============================================================================
# TESTS DE REMOVE_COMPONENT
# ============================================================================

func test_remove_component():
	"""Test: remover componente"""
	var component = {
		"name": "Test Component",
		"slots": 1,
		"weight": 1.0
	}
	
	loadout.add_component(MechLoadout.MechLocation.LEFT_TORSO, component)
	var result = loadout.remove_component(MechLoadout.MechLocation.LEFT_TORSO, 0)
	
	assert_true(result, "Componente removido exitosamente")


# ============================================================================
# TESTS DE CAN_MOUNT_IN_LOCATION
# ============================================================================

func test_can_mount_in_location_valid():
	"""Test: puede montar en ubicación válida"""
	var component = {
		"name": "Medium Laser",
		"slots": 1,
		"allowed_locations": [MechLoadout.MechLocation.LEFT_ARM, MechLoadout.MechLocation.RIGHT_ARM]
	}
	
	var can = loadout.can_mount_in_location(component, MechLoadout.MechLocation.LEFT_ARM)
	
	assert_true(can, "Puede montar en ubicación permitida")


# ============================================================================
# TESTS DE PESO
# ============================================================================

func test_get_available_weight():
	"""Test: peso disponible es razonable"""
	var available = loadout.get_available_weight()
	
	assert_gte(available, 0, "Peso disponible >= 0")


func test_current_weight_tracked():
	"""Test: current_weight se calcula"""
	var weight = loadout.current_weight
	
	assert_gte(weight, 0, "Peso actual >= 0")


# ============================================================================
# TESTS DE VALIDACIÓN
# ============================================================================

func test_is_valid_loadout():
	"""Test: is_valid_loadout retorna diccionario"""
	var result = loadout.is_valid_loadout()
	
	assert_true(result is Dictionary, "Validación retorna diccionario")
	assert_true(result.has("valid"), "Resultado tiene campo valid")


func test_get_loadout_summary():
	"""Test: resumen de loadout contiene información"""
	var summary = loadout.get_loadout_summary()
	
	assert_not_null(summary, "Summary no es null")


# ============================================================================
# TESTS ADICIONALES - get_available_weight
# ============================================================================

func test_get_available_weight_calculated():
	"""Test: peso disponible se calcula correctamente"""
	loadout.mech_tonnage = 50
	var available = loadout.get_available_weight()
	
	assert_true(available is float or available is int, "Available weight es número")
	assert_lte(available, 50.0, "Available weight <= tonnage")


# ============================================================================
# TESTS ADICIONALES - is_valid_loadout
# ============================================================================

func test_is_valid_loadout_empty():
	"""Test: loadout vacío es válido (o retorna resultado)"""
	var result = loadout.is_valid_loadout()
	
	# Puede retornar bool o Dictionary
	assert_true(result is bool or result is Dictionary, "is_valid_loadout retorna resultado")


# ============================================================================
# TESTS ADICIONALES - get_total_heat_sinks
# ============================================================================

func test_get_total_heat_sinks_default():
	"""Test: heat sinks por defecto es 10 (del engine)"""
	var heat_sinks_count = loadout.get_total_heat_sinks()
	
	assert_gte(heat_sinks_count, 10, "Engine incluye 10 heat sinks mínimo")


# ============================================================================
# TESTS ADICIONALES - to_dict / from_dict
# ============================================================================

func test_to_dict_structure():
	"""Test: to_dict retorna diccionario con campos correctos"""
	loadout.mech_name = "Test Mech"
	loadout.mech_tonnage = 75
	loadout.engine_rating = 300
	
	var data = loadout.to_dict()
	
	assert_has(data, "mech_name", "to_dict tiene mech_name")
	assert_has(data, "mech_tonnage", "to_dict tiene mech_tonnage")
	assert_has(data, "engine_rating", "to_dict tiene engine_rating")
	assert_has(data, "loadout", "to_dict tiene loadout")


func test_from_dict_loads_data():
	"""Test: from_dict carga datos correctamente"""
	var data = {
		"mech_name": "Imported Mech",
		"mech_tonnage": 80,
		"engine_rating": 320,
		"heat_sinks": 12,
		"armor_weight": 10.0,
		"loadout": {}
	}
	
	loadout.from_dict(data)
	
	assert_eq(loadout.mech_name, "Imported Mech", "Nombre cargado")
	assert_eq(loadout.mech_tonnage, 80, "Tonnage cargado")
	assert_eq(loadout.engine_rating, 320, "Engine rating cargado")


func test_to_dict_from_dict_roundtrip():
	"""Test: to_dict -> from_dict preserva datos"""
	loadout.mech_name = "Roundtrip Test"
	loadout.mech_tonnage = 65
	loadout.engine_rating = 260
	
	var exported = loadout.to_dict()
	
	var new_loadout = MechLoadout.new()
	new_loadout.from_dict(exported)
	
	assert_eq(new_loadout.mech_name, "Roundtrip Test", "Nombre preservado")
	assert_eq(new_loadout.mech_tonnage, 65, "Tonnage preservado")
	new_loadout.queue_free()


# ============================================================================
# TESTS DE CONSTANTES
# ============================================================================

func test_critical_slots_defined():
	"""Test: CRITICAL_SLOTS tiene todas las ubicaciones"""
	assert_true(MechLoadout.CRITICAL_SLOTS.has(MechLoadout.MechLocation.HEAD), "Head definido")
	assert_true(MechLoadout.CRITICAL_SLOTS.has(MechLoadout.MechLocation.CENTER_TORSO), "CT definido")
	assert_true(MechLoadout.CRITICAL_SLOTS.has(MechLoadout.MechLocation.LEFT_ARM), "LA definido")


func test_fixed_components_defined():
	"""Test: FIXED_COMPONENTS tiene componentes fijos"""
	assert_true(MechLoadout.FIXED_COMPONENTS.has(MechLoadout.MechLocation.HEAD), "Head fijos")
	assert_gt(MechLoadout.FIXED_COMPONENTS[MechLoadout.MechLocation.HEAD].size(), 0, "Head tiene fijos")
