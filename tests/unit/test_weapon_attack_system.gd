# ============================================================================
# test_weapon_attack_system.gd - Tests para el sistema de ataques con armas
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const WeaponAttackSystem = preload("res://scripts/core/combat/weapon_attack_system.gd")
const ComponentDatabase = preload("res://scripts/core/component_database.gd")


# ============================================================================
# MOCK HELPERS
# ============================================================================

class MockMech:
	extends RefCounted
	var hex_position: Vector2i = Vector2i(5, 5)
	var pilot_skill: int = 4
	var target_movement_modifier: int = 0
	var heat: int = 0
	var is_shutdown: bool = false
	var has_moved: bool = false
	var movement_type_used: int = 0
	var is_prone: bool = false
	var armor: Dictionary = {
		"head": {"current": 9, "max": 9},
		"center_torso": {"current": 30, "max": 30},
		"left_torso": {"current": 20, "max": 20},
		"right_torso": {"current": 20, "max": 20},
		"left_arm": {"current": 15, "max": 15},
		"right_arm": {"current": 15, "max": 15},
		"left_leg": {"current": 20, "max": 20},
		"right_leg": {"current": 20, "max": 20}
	}
	var structure: Dictionary = {
		"head": {"current": 3, "max": 3},
		"center_torso": {"current": 20, "max": 20},
		"left_torso": {"current": 15, "max": 15},
		"right_torso": {"current": 15, "max": 15},
		"left_arm": {"current": 10, "max": 10},
		"right_arm": {"current": 10, "max": 10},
		"left_leg": {"current": 15, "max": 15},
		"right_leg": {"current": 15, "max": 15}
	}
	
	## Método has para simular comportamiento de Dictionary
	func has(key: String) -> bool:
		match key:
			"armor": return true
			"structure": return true
			"hex_position": return true
			"pilot_skill": return true
			"heat": return true
			"is_shutdown": return true
			"has_moved": return true
			"is_prone": return true
		return false
	
	## Método get con valor por defecto (simula Dictionary.get)
	func get_value(key: String, default_value = null):
		match key:
			"armor": return armor
			"structure": return structure
			"hex_position": return hex_position
			"pilot_skill": return pilot_skill
			"heat": return heat
			"is_shutdown": return is_shutdown
			"has_moved": return has_moved
			"is_prone": return is_prone
			"target_movement_modifier": return target_movement_modifier
			"movement_type_used": return movement_type_used
		return default_value
	
	func get_attacker_movement_modifier() -> int:
		match movement_type_used:
			0: return 0  # No movement
			1: return 1  # Walk
			2: return 2  # Run
			3: return 3  # Jump
		return 0
	
	func add_heat(amount: int):
		heat += amount


class MockHexGrid:
	var elevations: Dictionary = {}
	var terrains: Dictionary = {}
	var units: Dictionary = {}
	
	func is_valid_hex(hex: Vector2i) -> bool:
		return hex.x >= 0 and hex.x < 20 and hex.y >= 0 and hex.y < 20
	
	func get_elevation(hex: Vector2i) -> int:
		return elevations.get(hex, 0)
	
	func get_terrain(hex: Vector2i):
		return terrains.get(hex, TerrainType.Type.CLEAR)
	
	func get_unit(hex: Vector2i):
		return units.get(hex, null)
	
	func hex_distance(from: Vector2i, to: Vector2i) -> int:
		var dq = to.x - from.x
		var dr = to.y - from.y
		return (abs(dq) + abs(dq + dr) + abs(dr)) / 2
	
	func get_neighbors(hex: Vector2i) -> Array:
		return [
			hex + Vector2i(1, 0),
			hex + Vector2i(-1, 0),
			hex + Vector2i(0, 1),
			hex + Vector2i(0, -1),
			hex + Vector2i(1, -1),
			hex + Vector2i(-1, 1)
		]


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

var mock_grid: MockHexGrid

func before_each():
	gut.p("--- Preparando test de WeaponAttackSystem ---")
	mock_grid = MockHexGrid.new()


func after_each():
	gut.p("--- Test de WeaponAttackSystem completado ---")
	mock_grid = null


# ============================================================================
# HELPER PARA CREAR ARMAS DE TEST
# ============================================================================

func _create_weapon(type: String) -> Dictionary:
	match type:
		"medium_laser":
			return {
				"name": "Medium Laser",
				"damage": 5,
				"heat": 3,
				"range_short": 3,
				"range_medium": 6,
				"range_long": 9,
				"requires_ammo": false,
				"category": ComponentDatabase.WeaponCategory.ENERGY
			}
		"ppc":
			return {
				"name": "PPC",
				"damage": 10,
				"heat": 10,
				"range_short": 6,
				"range_medium": 12,
				"range_long": 18,
				"range_minimum": 3,
				"requires_ammo": false,
				"category": ComponentDatabase.WeaponCategory.ENERGY
			}
		"ac10":
			return {
				"name": "AC/10",
				"damage": 10,
				"heat": 3,
				"range_short": 5,
				"range_medium": 10,
				"range_long": 15,
				"requires_ammo": true,
				"ammo": 10,
				"category": ComponentDatabase.WeaponCategory.BALLISTIC
			}
		"lrm10":
			return {
				"name": "LRM-10",
				"damage": 1,
				"missiles_per_salvo": 10,
				"heat": 4,
				"range_short": 7,
				"range_medium": 14,
				"range_long": 21,
				"range_minimum": 6,
				"requires_ammo": true,
				"ammo": 12,
				"category": ComponentDatabase.WeaponCategory.MISSILE
			}
	return {}


# ============================================================================
# TESTS DE TIRADA DE ATAQUE
# ============================================================================

func test_roll_to_hit_range():
	"""Test: tirada de 2D6 está en rango"""
	for _i in range(20):
		var roll = WeaponAttackSystem.roll_to_hit()
		assert_gte(roll, 2, "Mínimo 2")
		assert_lte(roll, 12, "Máximo 12")


func test_check_hit_success():
	"""Test: verificar impacto exitoso"""
	var hit = WeaponAttackSystem.check_hit(8, 8)
	assert_true(hit, "8 vs 8 = impacto")


func test_check_hit_failure():
	"""Test: verificar fallo"""
	var hit = WeaponAttackSystem.check_hit(5, 8)
	assert_false(hit, "5 vs 8 = fallo")


# ============================================================================
# TESTS DE LOCALIZACIÓN DE IMPACTO
# ============================================================================

func test_roll_hit_location():
	"""Test: localización de impacto válida"""
	var valid_locations = [
		"head", "center_torso", "left_torso", "right_torso",
		"left_arm", "right_arm", "left_leg", "right_leg"
	]
	
	for _i in range(20):
		var location = WeaponAttackSystem.roll_hit_location()
		assert_true(location in valid_locations, 
					"Ubicación '%s' es válida" % location)


# ============================================================================
# TESTS DE CLUSTER TABLE (MISILES)
# ============================================================================

func test_get_cluster_hits_lrm10():
	"""Test: LRM-10 cluster table"""
	# Roll 7 (medio) para LRM-10 = 7 misiles impactan
	var hits = WeaponAttackSystem.get_cluster_hits(10, 7)
	assert_eq(hits, 7, "LRM-10 roll 7 = 7 impactos")


func test_get_cluster_hits_lrm20():
	"""Test: LRM-20 cluster table"""
	# Roll 12 (máximo) para LRM-20 = 20 misiles impactan
	var hits = WeaponAttackSystem.get_cluster_hits(20, 12)
	assert_eq(hits, 20, "LRM-20 roll 12 = 20 impactos")


func test_get_cluster_hits_min_roll():
	"""Test: tirada mínima da menos impactos"""
	var hits_min = WeaponAttackSystem.get_cluster_hits(10, 2)
	var hits_max = WeaponAttackSystem.get_cluster_hits(10, 12)
	
	assert_lt(hits_min, hits_max, "Roll bajo = menos impactos que roll alto")


# ============================================================================
# TESTS DE VERIFICACIÓN DE ARMA
# ============================================================================

func test_can_fire_weapon_destroyed():
	"""Test: arma destruida no puede disparar"""
	var attacker = MockMech.new()
	var target = MockMech.new()
	target.hex_position = Vector2i(5, 8)
	
	var weapon = _create_weapon("medium_laser")
	weapon["destroyed"] = true
	
	var result = WeaponAttackSystem.can_fire_weapon(attacker, weapon, target, mock_grid)
	
	assert_false(result["can_fire"], "Arma destruida no dispara")
	assert_eq(result["reason"], "Weapon destroyed", "Razón correcta")


func test_can_fire_weapon_no_ammo():
	"""Test: sin munición no puede disparar"""
	var attacker = MockMech.new()
	var target = MockMech.new()
	target.hex_position = Vector2i(5, 10)
	
	var weapon = _create_weapon("ac10")
	weapon["ammo"] = 0
	
	var result = WeaponAttackSystem.can_fire_weapon(attacker, weapon, target, mock_grid)
	
	assert_false(result["can_fire"], "Sin munición no dispara")
	assert_true("ammo" in result["reason"].to_lower(), "Razón menciona munición")


# ============================================================================
# TESTS DE VERIFICACIÓN DE LINE OF SIGHT
# ============================================================================

func test_verify_los_clear():
	"""Test: LoS clara permite disparo"""
	var attacker = MockMech.new()
	var target = MockMech.new()
	target.hex_position = Vector2i(5, 8)
	
	var result = WeaponAttackSystem.verify_line_of_sight(attacker, target, mock_grid)
	
	assert_true(result["can_shoot"], "LoS clara permite disparo")


func test_verify_los_blocked():
	"""Test: LoS bloqueada impide disparo"""
	var attacker = MockMech.new()
	var target = MockMech.new()
	target.hex_position = Vector2i(5, 10)
	
	# Poner mech bloqueando
	mock_grid.units[Vector2i(5, 7)] = {}
	
	var result = WeaponAttackSystem.verify_line_of_sight(attacker, target, mock_grid)
	
	assert_false(result["can_shoot"], "LoS bloqueada impide disparo")


# ============================================================================
# TESTS DE APLICACIÓN DE DAÑO
# ============================================================================

func test_apply_damage_to_armor():
	"""Test: daño se aplica a blindaje primero"""
	var target = MockMech.new()
	var initial_armor = target.armor["center_torso"]["current"]
	
	var result = WeaponAttackSystem.apply_damage_to_location(target, "center_torso", 10)
	
	assert_lt(target.armor["center_torso"]["current"], initial_armor, 
			  "Blindaje reducido")
	assert_eq(result["armor_damage"], 10, "10 daño al blindaje")


func test_apply_damage_overflow_to_structure():
	"""Test: daño excesivo pasa a estructura"""
	var target = MockMech.new()
	target.armor["left_arm"]["current"] = 5  # Solo 5 de blindaje
	
	var result = WeaponAttackSystem.apply_damage_to_location(target, "left_arm", 10)
	
	assert_eq(target.armor["left_arm"]["current"], 0, "Blindaje a 0")
	assert_eq(result["structure_damage"], 5, "5 daño pasó a estructura")


# ============================================================================
# TESTS DE CRÍTICOS
# ============================================================================

func test_roll_critical_hits():
	"""Test: tirada de críticos retorna resultado válido"""
	var target = MockMech.new()
	
	var result = WeaponAttackSystem.roll_critical_hits(target, "center_torso", 5)
	
	assert_true(result.has("criticals"), "Resultado tiene criticals")
	assert_true(result.has("message"), "Resultado tiene mensaje")


# ============================================================================
# TESTS DE FUNCIONES ADICIONALES
# ============================================================================

func test_calculate_to_hit_structure():
	"""Test: calculate_to_hit retorna estructura correcta"""
	var attacker = MockMech.new()
	var target = MockMech.new()
	target.hex_position = Vector2i(5, 8)
	
	var weapon = _create_weapon("medium_laser")
	
	var result = WeaponAttackSystem.calculate_to_hit(attacker, target, weapon, 3, 0, mock_grid)
	
	assert_true(result.has("target_number"), "Resultado tiene target_number")

func test_apply_damage_returns_dict():
	"""Test: apply_damage retorna diccionario"""
	var target = MockMech.new()
	
	var result = WeaponAttackSystem.apply_damage(target, "center_torso", 5)
	
	assert_true(result is Dictionary, "apply_damage debería retornar Dictionary")

func test_calculate_heat_generated_single():
	"""Test: calculate_heat_generated para una arma"""
	var weapons = [{"name": "Medium Laser", "heat": 3}]
	
	var heat = WeaponAttackSystem.calculate_heat_generated(weapons)
	
	assert_eq(heat, 3, "Un ML genera 3 calor")

func test_calculate_heat_generated_multiple():
	"""Test: calculate_heat_generated para múltiples armas"""
	var weapons = [
		{"name": "Medium Laser", "heat": 3},
		{"name": "Medium Laser", "heat": 3},
		{"name": "PPC", "heat": 10}
	]
	
	var heat = WeaponAttackSystem.calculate_heat_generated(weapons)
	
	assert_eq(heat, 16, "2xML + PPC = 16 calor")

func test_calculate_heat_generated_empty():
	"""Test: calculate_heat_generated sin armas"""
	var heat = WeaponAttackSystem.calculate_heat_generated([])
	
	assert_eq(heat, 0, "Sin armas = 0 calor")

func test_resolve_damage_returns_dict():
	"""Test: resolve_damage retorna diccionario"""
	var attacker = MockMech.new()
	var target = MockMech.new()
	var weapon = _create_weapon("medium_laser")
	
	var result = WeaponAttackSystem.resolve_damage(attacker, target, weapon, {})
	
	assert_true(result is Dictionary, "resolve_damage debería retornar Dictionary")
