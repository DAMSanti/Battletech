# ============================================================================
# test_game_enums.gd - Tests unitarios para las enumeraciones del juego
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const GameEnums = preload("res://scripts/core/game_enums.gd")


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

func before_each():
	gut.p("--- Preparando test de enums ---")


func after_each():
	gut.p("--- Test de enums completado ---")


# ============================================================================
# TESTS DE CONVERSIÓN STRING -> ENUM
# ============================================================================

func test_location_string_to_enum_head():
	"""Test: 'head' se convierte a HEAD"""
	var result = GameEnums.location_string_to_enum("head")
	assert_eq(result, GameEnums.HitLocation.HEAD, "head -> HEAD")


func test_location_string_to_enum_center_torso():
	"""Test: 'center_torso' se convierte a CENTER_TORSO"""
	var result = GameEnums.location_string_to_enum("center_torso")
	assert_eq(result, GameEnums.HitLocation.CENTER_TORSO, "center_torso -> CENTER_TORSO")


func test_location_string_to_enum_left_torso():
	"""Test: 'left_torso' se convierte a LEFT_TORSO"""
	var result = GameEnums.location_string_to_enum("left_torso")
	assert_eq(result, GameEnums.HitLocation.LEFT_TORSO, "left_torso -> LEFT_TORSO")


func test_location_string_to_enum_right_torso():
	"""Test: 'right_torso' se convierte a RIGHT_TORSO"""
	var result = GameEnums.location_string_to_enum("right_torso")
	assert_eq(result, GameEnums.HitLocation.RIGHT_TORSO, "right_torso -> RIGHT_TORSO")


func test_location_string_to_enum_arms():
	"""Test: brazos se convierten correctamente"""
	var left = GameEnums.location_string_to_enum("left_arm")
	var right = GameEnums.location_string_to_enum("right_arm")
	
	assert_eq(left, GameEnums.HitLocation.LEFT_ARM, "left_arm -> LEFT_ARM")
	assert_eq(right, GameEnums.HitLocation.RIGHT_ARM, "right_arm -> RIGHT_ARM")


func test_location_string_to_enum_legs():
	"""Test: piernas se convierten correctamente"""
	var left = GameEnums.location_string_to_enum("left_leg")
	var right = GameEnums.location_string_to_enum("right_leg")
	
	assert_eq(left, GameEnums.HitLocation.LEFT_LEG, "left_leg -> LEFT_LEG")
	assert_eq(right, GameEnums.HitLocation.RIGHT_LEG, "right_leg -> RIGHT_LEG")


# ============================================================================
# TESTS DE CONVERSIÓN ENUM -> STRING
# ============================================================================

func test_location_enum_to_string_head():
	"""Test: HEAD se convierte a 'head'"""
	var result = GameEnums.location_enum_to_string(GameEnums.HitLocation.HEAD)
	assert_eq(result, "head", "HEAD -> head")


func test_location_enum_to_string_torsos():
	"""Test: torsos se convierten correctamente"""
	var center = GameEnums.location_enum_to_string(GameEnums.HitLocation.CENTER_TORSO)
	var left = GameEnums.location_enum_to_string(GameEnums.HitLocation.LEFT_TORSO)
	var right = GameEnums.location_enum_to_string(GameEnums.HitLocation.RIGHT_TORSO)
	
	assert_eq(center, "center_torso", "CENTER_TORSO -> center_torso")
	assert_eq(left, "left_torso", "LEFT_TORSO -> left_torso")
	assert_eq(right, "right_torso", "RIGHT_TORSO -> right_torso")


func test_location_enum_to_string_extremities():
	"""Test: brazos y piernas se convierten correctamente"""
	var la = GameEnums.location_enum_to_string(GameEnums.HitLocation.LEFT_ARM)
	var ra = GameEnums.location_enum_to_string(GameEnums.HitLocation.RIGHT_ARM)
	var ll = GameEnums.location_enum_to_string(GameEnums.HitLocation.LEFT_LEG)
	var rl = GameEnums.location_enum_to_string(GameEnums.HitLocation.RIGHT_LEG)
	
	assert_eq(la, "left_arm", "LEFT_ARM -> left_arm")
	assert_eq(ra, "right_arm", "RIGHT_ARM -> right_arm")
	assert_eq(ll, "left_leg", "LEFT_LEG -> left_leg")
	assert_eq(rl, "right_leg", "RIGHT_LEG -> right_leg")


# ============================================================================
# TESTS DE MOVEMENT TYPE
# ============================================================================

func test_movement_type_to_string_walk():
	"""Test: WALK se convierte correctamente"""
	var result = GameEnums.movement_type_to_string(GameEnums.MovementType.WALK)
	assert_eq(result, "Walk", "WALK -> Walk")


func test_movement_type_to_string_run():
	"""Test: RUN se convierte correctamente"""
	var result = GameEnums.movement_type_to_string(GameEnums.MovementType.RUN)
	assert_eq(result, "Run", "RUN -> Run")


func test_movement_type_to_string_jump():
	"""Test: JUMP se convierte correctamente"""
	var result = GameEnums.movement_type_to_string(GameEnums.MovementType.JUMP)
	assert_eq(result, "Jump", "JUMP -> Jump")


func test_movement_type_to_string_none():
	"""Test: NONE se convierte correctamente"""
	var result = GameEnums.movement_type_to_string(GameEnums.MovementType.NONE)
	assert_eq(result, "None", "NONE -> None")


# ============================================================================
# TESTS DE PHASE
# ============================================================================

func test_phase_to_string_deployment():
	"""Test: DEPLOYMENT se convierte correctamente"""
	var result = GameEnums.phase_to_string(GameEnums.TurnPhase.DEPLOYMENT)
	assert_eq(result, "Deployment", "DEPLOYMENT -> Deployment")


func test_phase_to_string_movement():
	"""Test: MOVEMENT se convierte correctamente"""
	var result = GameEnums.phase_to_string(GameEnums.TurnPhase.MOVEMENT)
	assert_eq(result, "Movement", "MOVEMENT -> Movement")


func test_phase_to_string_weapon_attack():
	"""Test: WEAPON_ATTACK se convierte correctamente"""
	var result = GameEnums.phase_to_string(GameEnums.TurnPhase.WEAPON_ATTACK)
	assert_eq(result, "Weapon Attack", "WEAPON_ATTACK -> Weapon Attack")


func test_phase_to_string_physical():
	"""Test: PHYSICAL_ATTACK se convierte correctamente"""
	var result = GameEnums.phase_to_string(GameEnums.TurnPhase.PHYSICAL_ATTACK)
	assert_eq(result, "Physical Attack", "PHYSICAL_ATTACK -> Physical Attack")


func test_phase_to_string_heat():
	"""Test: HEAT se convierte correctamente"""
	var result = GameEnums.phase_to_string(GameEnums.TurnPhase.HEAT)
	assert_eq(result, "Heat", "HEAT -> Heat")


# ============================================================================
# TESTS DE VALORES ENUM
# ============================================================================

func test_game_state_values():
	"""Test: GameState tiene todos los valores esperados"""
	assert_eq(GameEnums.GameState.MOVING, 0, "MOVING = 0")
	assert_eq(GameEnums.GameState.WEAPON_ATTACK, 2, "WEAPON_ATTACK = 2")


func test_movement_type_values():
	"""Test: MovementType tiene valores correctos"""
	assert_eq(GameEnums.MovementType.NONE, 0, "NONE = 0")
	assert_eq(GameEnums.MovementType.WALK, 1, "WALK = 1")
	assert_eq(GameEnums.MovementType.RUN, 2, "RUN = 2")
	assert_eq(GameEnums.MovementType.JUMP, 3, "JUMP = 3")


func test_physical_attack_types():
	"""Test: PhysicalAttackType tiene todos los tipos"""
	assert_eq(GameEnums.PhysicalAttackType.PUNCH, 0, "PUNCH = 0")
	assert_eq(GameEnums.PhysicalAttackType.KICK, 1, "KICK = 1")
	assert_eq(GameEnums.PhysicalAttackType.CHARGE, 2, "CHARGE = 2")
