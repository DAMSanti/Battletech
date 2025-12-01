# ============================================================================
# test_combat_system.gd - Tests unitarios para el sistema de combate
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const WeaponAttackSystem = preload("res://scripts/core/combat/weapon_attack_system.gd")


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

func before_each():
	# Seed aleatorio fijo para tests reproducibles
	seed(12345)
	gut.p("--- Preparando test de combate ---")


func after_each():
	gut.p("--- Test de combate completado ---")


# ============================================================================
# HELPERS - Crear objetos de prueba
# ============================================================================

class MockMech:
	"""Mock de un mech para testing"""
	var pilot_skill: int = 4
	var hex_position: Vector2i = Vector2i(0, 0)
	var heat: int = 0
	var hexes_moved_this_turn: int = 0
	var last_movement_type: int = 0  # 0=STAND, 1=WALK, 2=RUN, 3=JUMP
	var armor: Dictionary = {}
	var structure: Dictionary = {}
	var weapons: Array = []
	var equipment: Array = []
	var is_shutdown: bool = false
	var destroyed_locations: Array = []
	var is_destroyed: bool = false
	var death_reason: String = ""
	
	# Método has() para compatibilidad con el sistema de combate
	func has(property: String) -> bool:
		match property:
			"armor": return true
			"structure": return true
			"weapons": return true
			"equipment": return true
			"pilot_skill": return true
			"hex_position": return true
			"heat": return true
			"is_shutdown": return true
			"destroyed_locations": return true
			"is_destroyed": return true
			"death_reason": return true
			_: return false
	
	func _init():
		# Inicializar armadura estándar
		armor = {
			"head": {"current": 9, "max": 9},
			"center_torso": {"current": 30, "max": 30},
			"left_torso": {"current": 20, "max": 20},
			"right_torso": {"current": 20, "max": 20},
			"left_arm": {"current": 16, "max": 16},
			"right_arm": {"current": 16, "max": 16},
			"left_leg": {"current": 20, "max": 20},
			"right_leg": {"current": 20, "max": 20}
		}
		# Inicializar estructura
		structure = {
			"head": {"current": 3, "max": 3},
			"center_torso": {"current": 16, "max": 16},
			"left_torso": {"current": 12, "max": 12},
			"right_torso": {"current": 12, "max": 12},
			"left_arm": {"current": 8, "max": 8},
			"right_arm": {"current": 8, "max": 8},
			"left_leg": {"current": 12, "max": 12},
			"right_leg": {"current": 12, "max": 12}
		}
	
	func get_attacker_movement_modifier() -> int:
		match last_movement_type:
			0: return 0  # Estacionario
			1: return 1  # Walk
			2: return 2  # Run
			3: return 3  # Jump
			_: return 0
	
	func add_heat(amount: int):
		heat += amount
	
	func take_damage(location: String, damage: int) -> Dictionary:
		if not armor.has(location):
			return {"success": false, "message": "Invalid location"}
		
		var armor_current = armor[location]["current"]
		var armor_damage = min(damage, armor_current)
		armor[location]["current"] -= armor_damage
		
		var overflow = damage - armor_damage
		var structure_damage = 0
		
		if overflow > 0 and structure.has(location):
			var struct_current = structure[location]["current"]
			structure_damage = min(overflow, struct_current)
			structure[location]["current"] -= structure_damage
		
		return {
			"success": true,
			"armor_damage": armor_damage,
			"structure_damage": structure_damage
		}


func _create_mock_mech(skill: int = 4) -> MockMech:
	"""Crea un mech mock para testing"""
	var mech = MockMech.new()
	mech.pilot_skill = skill
	return mech


func _create_test_weapon_laser() -> Dictionary:
	"""Crea un láser medio de prueba"""
	return {
		"name": "Medium Laser",
		"damage": 5,
		"heat": 3,
		"range_short": 3,
		"range_medium": 6,
		"range_long": 9,
		"requires_ammo": false,
		"destroyed": false,
		"category": 0  # ENERGY
	}


func _create_test_weapon_ac10() -> Dictionary:
	"""Crea un AC/10 de prueba"""
	return {
		"name": "AC/10",
		"damage": 10,
		"heat": 3,
		"range_short": 5,
		"range_medium": 10,
		"range_long": 15,
		"requires_ammo": true,
		"ammo": 10,
		"destroyed": false,
		"category": 1  # BALLISTIC
	}


func _create_test_weapon_lrm10() -> Dictionary:
	"""Crea un LRM-10 de prueba"""
	return {
		"name": "LRM 10",
		"damage": 1,  # Por misil
		"heat": 4,
		"range_short": 7,
		"range_medium": 14,
		"range_long": 21,
		"range_minimum": 6,
		"requires_ammo": true,
		"ammo": 12,
		"missiles_per_salvo": 10,
		"destroyed": false,
		"category": 2  # MISSILE
	}


# ============================================================================
# TESTS DE CÁLCULO TO-HIT
# ============================================================================

func test_base_to_hit_calculation():
	"""Test: Cálculo base de to-hit con gunnery skill"""
	var attacker = _create_mock_mech(4)  # Gunnery 4
	var target = _create_mock_mech()
	var weapon = _create_test_weapon_laser()
	
	var to_hit_data = WeaponAttackSystem.calculate_to_hit(
		attacker, target, weapon, 3  # Rango corto
	)
	
	# Con gunnery 4 y rango corto (0), debería ser 4
	assert_eq(
		to_hit_data["target_number"], 
		4, 
		"To-hit base con gunnery 4 y rango corto debería ser 4"
	)


func test_range_modifier_short():
	"""Test: Sin modificador en rango corto"""
	var attacker = _create_mock_mech(4)
	var target = _create_mock_mech()
	var weapon = _create_test_weapon_laser()  # Short range: 3
	
	var to_hit_data = WeaponAttackSystem.calculate_to_hit(
		attacker, target, weapon, 2  # Dentro de rango corto
	)
	
	# Rango corto = 0 modificador
	assert_eq(
		to_hit_data["modifiers"].get("range", 0),
		0,
		"Modificador de rango corto debería ser 0"
	)


func test_range_modifier_medium():
	"""Test: +2 modificador en rango medio"""
	var attacker = _create_mock_mech(4)
	var target = _create_mock_mech()
	var weapon = _create_test_weapon_laser()  # Medium range: 6
	
	var to_hit_data = WeaponAttackSystem.calculate_to_hit(
		attacker, target, weapon, 5  # Dentro de rango medio
	)
	
	# Rango medio = +2 modificador
	assert_eq(
		to_hit_data["modifiers"].get("range", 0),
		2,
		"Modificador de rango medio debería ser +2"
	)


func test_range_modifier_long():
	"""Test: +4 modificador en rango largo"""
	var attacker = _create_mock_mech(4)
	var target = _create_mock_mech()
	var weapon = _create_test_weapon_laser()  # Long range: 9
	
	var to_hit_data = WeaponAttackSystem.calculate_to_hit(
		attacker, target, weapon, 8  # Dentro de rango largo
	)
	
	# Rango largo = +4 modificador
	assert_eq(
		to_hit_data["modifiers"].get("range", 0),
		4,
		"Modificador de rango largo debería ser +4"
	)


func test_attacker_movement_modifier_walk():
	"""Test: +1 modificador por caminar"""
	var attacker = _create_mock_mech(4)
	attacker.last_movement_type = 1  # WALK
	var target = _create_mock_mech()
	var weapon = _create_test_weapon_laser()
	
	var to_hit_data = WeaponAttackSystem.calculate_to_hit(
		attacker, target, weapon, 3
	)
	
	assert_eq(
		to_hit_data["modifiers"].get("attacker_moved", 0),
		1,
		"Modificador por caminar debería ser +1"
	)


func test_attacker_movement_modifier_run():
	"""Test: +2 modificador por correr"""
	var attacker = _create_mock_mech(4)
	attacker.last_movement_type = 2  # RUN
	var target = _create_mock_mech()
	var weapon = _create_test_weapon_laser()
	
	var to_hit_data = WeaponAttackSystem.calculate_to_hit(
		attacker, target, weapon, 3
	)
	
	assert_eq(
		to_hit_data["modifiers"].get("attacker_moved", 0),
		2,
		"Modificador por correr debería ser +2"
	)


func test_attacker_movement_modifier_jump():
	"""Test: +3 modificador por saltar"""
	var attacker = _create_mock_mech(4)
	attacker.last_movement_type = 3  # JUMP
	var target = _create_mock_mech()
	var weapon = _create_test_weapon_laser()
	
	var to_hit_data = WeaponAttackSystem.calculate_to_hit(
		attacker, target, weapon, 3
	)
	
	assert_eq(
		to_hit_data["modifiers"].get("attacker_moved", 0),
		3,
		"Modificador por saltar debería ser +3"
	)


func test_heat_modifier():
	"""Test: Modificador por calor"""
	var attacker = _create_mock_mech(4)
	attacker.heat = 10  # 10 de calor = +2 to-hit
	var target = _create_mock_mech()
	var weapon = _create_test_weapon_laser()
	
	var to_hit_data = WeaponAttackSystem.calculate_to_hit(
		attacker, target, weapon, 3
	)
	
	assert_eq(
		to_hit_data["modifiers"].get("heat", 0),
		2,
		"10 de calor debería dar +2 to-hit"
	)


func test_target_movement_modifier():
	"""Test: TMM del objetivo"""
	var attacker = _create_mock_mech(4)
	var target = _create_mock_mech()
	target.hexes_moved_this_turn = 5  # 5 hexes = +2 TMM
	var weapon = _create_test_weapon_laser()
	
	var to_hit_data = WeaponAttackSystem.calculate_to_hit(
		attacker, target, weapon, 3
	)
	
	assert_eq(
		to_hit_data["modifiers"].get("target_tmm", 0),
		2,
		"5 hexes de movimiento debería dar TMM +2"
	)


func test_combined_modifiers():
	"""Test: Múltiples modificadores combinados"""
	var attacker = _create_mock_mech(4)  # Gunnery 4
	attacker.last_movement_type = 2  # Corrió (+2)
	attacker.heat = 5  # +1 calor
	
	var target = _create_mock_mech()
	target.hexes_moved_this_turn = 3  # +1 TMM
	
	var weapon = _create_test_weapon_laser()
	
	var to_hit_data = WeaponAttackSystem.calculate_to_hit(
		attacker, target, weapon, 5  # Rango medio (+2)
	)
	
	# Total: 4 (gunnery) + 2 (ran) + 1 (heat) + 1 (tmm) + 2 (range) = 10
	assert_eq(
		to_hit_data["target_number"],
		10,
		"Número objetivo combinado debería ser 10"
	)


# ============================================================================
# TESTS DE TIRADAS Y HITS
# ============================================================================

func test_roll_2d6_range():
	"""Test: Tirada 2D6 produce valores válidos"""
	for i in range(100):
		var roll = WeaponAttackSystem.roll_to_hit()
		assert_gte(roll, 2, "Tirada mínima debe ser 2")
		assert_lte(roll, 12, "Tirada máxima debe ser 12")


func test_hit_check_success():
	"""Test: Tirada >= target_number es hit"""
	assert_true(
		WeaponAttackSystem.check_hit(8, 7),
		"Tirada 8 vs target 7 debería ser hit"
	)


func test_hit_check_failure():
	"""Test: Tirada < target_number es miss"""
	assert_false(
		WeaponAttackSystem.check_hit(6, 8),
		"Tirada 6 vs target 8 debería ser miss"
	)


func test_hit_check_exact():
	"""Test: Tirada exacta es hit"""
	assert_true(
		WeaponAttackSystem.check_hit(7, 7),
		"Tirada exacta 7 vs 7 debería ser hit"
	)


func test_snake_eyes_always_miss():
	"""Test: 2 natural siempre falla"""
	assert_false(
		WeaponAttackSystem.check_hit(2, 2),
		"Snake eyes (2) siempre debería fallar"
	)


func test_boxcars_always_hit():
	"""Test: 12 natural siempre impacta"""
	assert_true(
		WeaponAttackSystem.check_hit(12, 13),
		"Boxcars (12) siempre debería impactar"
	)


# ============================================================================
# TESTS DE LOCALIZACIÓN DE IMPACTOS
# ============================================================================

func test_hit_location_valid():
	"""Test: Localización de impacto es válida"""
	var valid_locations = [
		"head", "center_torso", "left_torso", "right_torso",
		"left_arm", "right_arm", "left_leg", "right_leg"
	]
	
	for i in range(50):
		var location = WeaponAttackSystem.roll_hit_location()
		assert_has(
			valid_locations,
			location,
			"Localización '%s' debería ser válida" % location
		)


# ============================================================================
# TESTS DE CLUSTER TABLE (MISILES)
# ============================================================================

func test_cluster_hits_lrm10():
	"""Test: Cluster table para LRM-10"""
	# Roll 7 en LRM-10 = 7 hits
	var hits = WeaponAttackSystem.get_cluster_hits(10, 7)
	assert_eq(hits, 7, "Roll 7 en LRM-10 debería dar 7 hits")


func test_cluster_hits_minimum():
	"""Test: Cluster table - roll mínimo"""
	# Roll 2 en LRM-10 = 3 hits
	var hits = WeaponAttackSystem.get_cluster_hits(10, 2)
	assert_eq(hits, 3, "Roll 2 en LRM-10 debería dar 3 hits")


func test_cluster_hits_maximum():
	"""Test: Cluster table - roll máximo"""
	# Roll 12 en LRM-10 = 10 hits (todos)
	var hits = WeaponAttackSystem.get_cluster_hits(10, 12)
	assert_eq(hits, 10, "Roll 12 en LRM-10 debería dar 10 hits")


# ============================================================================
# TESTS DE APLICACIÓN DE DAÑO
# ============================================================================

func test_damage_to_armor():
	"""Test: Daño se aplica primero a armadura"""
	var target = _create_mock_mech()
	var initial_armor = target.armor["center_torso"]["current"]
	
	WeaponAttackSystem.apply_damage_to_location(target, "center_torso", 5)
	
	assert_eq(
		target.armor["center_torso"]["current"],
		initial_armor - 5,
		"Armadura debería reducirse en 5"
	)
	assert_eq(
		target.structure["center_torso"]["current"],
		target.structure["center_torso"]["max"],
		"Estructura no debería dañarse"
	)


func test_damage_overflow_to_structure():
	"""Test: Daño excedente pasa a estructura"""
	var target = _create_mock_mech()
	target.armor["left_arm"]["current"] = 3  # Solo 3 de armadura
	var initial_structure = target.structure["left_arm"]["current"]
	
	WeaponAttackSystem.apply_damage_to_location(target, "left_arm", 10)
	
	# 3 a armadura, 7 a estructura
	assert_eq(
		target.armor["left_arm"]["current"],
		0,
		"Armadura debería estar a 0"
	)
	assert_eq(
		target.structure["left_arm"]["current"],
		initial_structure - 7,
		"Estructura debería reducirse en 7"
	)


func test_location_destruction():
	"""Test: Localización se destruye cuando estructura llega a 0"""
	var target = _create_mock_mech()
	target.armor["right_arm"]["current"] = 0  # Sin armadura
	target.structure["right_arm"]["current"] = 5  # Poca estructura
	
	var result = WeaponAttackSystem.apply_damage_to_location(target, "right_arm", 10)
	
	assert_true(
		result["location_destroyed"],
		"Localización debería marcarse como destruida"
	)
	assert_eq(
		target.structure["right_arm"]["current"],
		0,
		"Estructura debería estar a 0"
	)


func test_mech_death_head_destroyed():
	"""Test: Mech muere si cabeza destruida"""
	var target = _create_mock_mech()
	target.armor["head"]["current"] = 0
	target.structure["head"]["current"] = 1
	
	WeaponAttackSystem.apply_damage_to_location(target, "head", 5)
	
	assert_true(
		target.is_destroyed,
		"Mech debería estar destruido"
	)
	assert_string_contains(
		target.death_reason.to_lower(),
		"head",
		"Razón de muerte debería mencionar cabeza"
	)


func test_mech_death_center_torso_destroyed():
	"""Test: Mech muere si torso central destruido"""
	var target = _create_mock_mech()
	target.armor["center_torso"]["current"] = 0
	target.structure["center_torso"]["current"] = 5
	
	WeaponAttackSystem.apply_damage_to_location(target, "center_torso", 10)
	
	assert_true(
		target.is_destroyed,
		"Mech debería estar destruido"
	)


# ============================================================================
# TESTS DE VERIFICACIÓN DE ARMAS
# ============================================================================

func test_weapon_destroyed_cannot_fire():
	"""Test: Arma destruida no puede disparar"""
	var attacker = _create_mock_mech()
	var target = _create_mock_mech()
	var weapon = _create_test_weapon_laser()
	weapon["destroyed"] = true
	
	var result = WeaponAttackSystem.can_fire_weapon(attacker, weapon, target, null)
	
	assert_false(
		result["can_fire"],
		"Arma destruida no debería poder disparar"
	)


func test_weapon_out_of_ammo_cannot_fire():
	"""Test: Arma sin munición no puede disparar"""
	var attacker = _create_mock_mech()
	var target = _create_mock_mech()
	target.hex_position = Vector2i(5, 5)
	var weapon = _create_test_weapon_ac10()
	weapon["ammo"] = 0
	
	# Mock hex_grid para distancia
	var mock_grid = MockHexGrid.new()
	
	var result = WeaponAttackSystem.can_fire_weapon(attacker, weapon, target, mock_grid)
	
	assert_false(
		result["can_fire"],
		"Arma sin munición no debería poder disparar"
	)


class MockHexGrid:
	func hex_distance(from: Vector2i, to: Vector2i) -> int:
		return int(abs(to.x - from.x) + abs(to.y - from.y))
