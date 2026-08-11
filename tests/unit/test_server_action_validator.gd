# test_server_action_validator.gd
# Unit tests for ServerActionValidator - comprehensive server-side validation
extends GutTest

## Tests para validación de acciones server-side
## Verifica que todas las validaciones funcionen correctamente para prevenir cheats

const ServerActionValidator = preload("res://scripts/network/server_action_validator.gd")

# ============================================================
# TEST DATA HELPERS
# ============================================================

func _create_test_match_data() -> Dictionary:
	return {
		"match_id": 12345,
		"player1_peer": 1001,
		"player2_peer": 1002,
		"current_turn": 1,
		"current_phase": "movement",
		"mechs": {}
	}


func _create_test_mech(id: int, owner_peer: int, team: String, pos: Vector2i) -> Dictionary:
	return {
		"id": id,
		"owner_peer": owner_peer,
		"team": team,
		"name": "Test Mech",
		"tonnage": 50,
		"hex_position": pos,
		"facing": 0,
		"walk_mp": 4,
		"run_mp": 6,
		"jump_mp": 4,
		"current_movement": 4,
		"heat": 0,
		"heat_capacity": 30,
		"heat_dissipation": 10,
		"armor": {
			"head": {"current": 9, "max": 9},
			"center_torso": {"current": 30, "max": 30},
			"left_torso": {"current": 20, "max": 20},
			"right_torso": {"current": 20, "max": 20},
			"left_arm": {"current": 16, "max": 16},
			"right_arm": {"current": 16, "max": 16},
			"left_leg": {"current": 20, "max": 20},
			"right_leg": {"current": 20, "max": 20}
		},
		"weapons": [
			{"name": "Medium Laser", "damage": 5, "heat": 3, "range_short": 3, "range_medium": 6, "range_long": 9},
			{"name": "AC/10", "damage": 10, "heat": 3, "range_short": 5, "range_medium": 10, "range_long": 15, "uses_ammo": true, "current_ammo": 10}
		],
		"gunnery_skill": 4,
		"piloting_skill": 5,
		"is_destroyed": false,
		"is_shutdown": false,
		"is_prone": false,
		"moved_this_turn": false,
		"fired_this_turn": false,
		"movement_type_used": 0,
		"hexes_moved": 0
	}


# ============================================================
# MOVEMENT VALIDATION TESTS
# ============================================================

func test_validate_movement_valid_walk() -> void:
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	match_data["mechs"][1] = mech
	
	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(6, 5), 1  # Walk 1 hex
	)
	
	assert_true(result.valid, "Valid walk movement should pass")


func test_validate_movement_invalid_distance() -> void:
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	match_data["mechs"][1] = mech
	
	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(15, 15), 1  # Walk way too far
	)
	
	assert_false(result.valid, "Movement exceeding walk_mp should fail")
	assert_eq(result.reason, "Insufficient movement points")


func test_validate_movement_not_your_mech() -> void:
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	match_data["mechs"][1] = mech
	
	# Peer 1002 intenta mover el mech de peer 1001
	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1002, Vector2i(6, 5), 1
	)
	
	assert_false(result.valid, "Should reject movement of other player's mech")
	assert_eq(result.reason, "Not your mech")


func test_validate_movement_wrong_phase() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "weapon_attack"
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	match_data["mechs"][1] = mech
	
	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(6, 5), 1
	)
	
	assert_false(result.valid, "Movement in wrong phase should fail")
	assert_eq(result.reason, "Not movement phase")


func test_validate_movement_mech_destroyed() -> void:
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	mech["is_destroyed"] = true
	match_data["mechs"][1] = mech
	
	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(6, 5), 1
	)
	
	assert_false(result.valid, "Destroyed mech cannot move")
	assert_eq(result.reason, "Mech is destroyed")


func test_validate_movement_mech_shutdown() -> void:
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	mech["is_shutdown"] = true
	match_data["mechs"][1] = mech
	
	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(6, 5), 1
	)
	
	assert_false(result.valid, "Shutdown mech cannot move")
	assert_eq(result.reason, "Mech is shutdown")


func test_validate_movement_already_moved() -> void:
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	mech["moved_this_turn"] = true
	match_data["mechs"][1] = mech
	
	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(6, 5), 1
	)
	
	assert_false(result.valid, "Cannot move twice in one turn")
	assert_eq(result.reason, "Mech already moved this turn")


func test_validate_movement_cannot_jump() -> void:
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	mech["jump_mp"] = 0  # No jump jets
	match_data["mechs"][1] = mech
	
	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(6, 5), 3  # Jump type
	)
	
	assert_false(result.valid, "Mech without jump jets cannot jump")
	assert_eq(result.reason, "Mech cannot jump")


func test_validate_movement_invalid_movement_type() -> void:
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	match_data["mechs"][1] = mech
	
	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(6, 5), 99  # Invalid type
	)
	
	assert_false(result.valid, "Invalid movement type should fail")
	assert_eq(result.reason, "Invalid movement type")


func test_validate_movement_hex_occupied() -> void:
	var match_data = _create_test_match_data()
	var mech1 = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var mech2 = _create_test_mech(2, 1002, "enemy", Vector2i(6, 5))  # Blocking hex
	match_data["mechs"][1] = mech1
	match_data["mechs"][2] = mech2
	
	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(6, 5), 1  # Try to move to occupied hex
	)
	
	assert_false(result.valid, "Cannot move to occupied hex")
	assert_eq(result.reason, "Hex occupied")


func test_validate_movement_run_distance() -> void:
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	match_data["mechs"][1] = mech
	
	# Walk MP = 4, Run MP = 6, try to move 5 hexes (ok for run, not for walk)
	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(10, 5), 2  # Run 5 hexes
	)
	
	assert_true(result.valid, "Running 5 hexes with run_mp=6 should work")


func test_validate_movement_rejects_out_of_activation_order() -> void:
	# Ver ROADMAP.md Fase T3: _handle_move_request no comprobaba el orden
	# de activacion, solo fase + propiedad + "no se ha movido ya este turno".
	# Un cliente podia mover cualquiera de sus mechs no usados en cualquier
	# orden dentro de la fase, en vez de respetar units_to_activate (ver
	# GDD.md "orden de iniciativa").
	var match_data = _create_test_match_data()
	var mech1 = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var mech2 = _create_test_mech(2, 1001, "player", Vector2i(6, 6))
	match_data["mechs"][1] = mech1
	match_data["mechs"][2] = mech2
	match_data["units_to_activate"] = [2, 1]  # Le toca al mech 2 primero
	match_data["current_unit_index"] = 0

	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(6, 5), 1  # Intenta mover el mech 1 (no le toca)
	)

	assert_false(result.valid, "Should reject moving a mech that isn't up in the activation order")
	assert_eq(result.reason, "Not this mech's turn to activate")


func test_validate_movement_allows_mech_at_front_of_activation_queue() -> void:
	var match_data = _create_test_match_data()
	var mech1 = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var mech2 = _create_test_mech(2, 1001, "player", Vector2i(6, 6))
	match_data["mechs"][1] = mech1
	match_data["mechs"][2] = mech2
	match_data["units_to_activate"] = [2, 1]
	match_data["current_unit_index"] = 0

	var result = ServerActionValidator.validate_movement(
		match_data, 2, 1001, Vector2i(7, 6), 1  # Mueve el mech 2, que si le toca
	)

	assert_true(result.valid, "Should allow moving the mech at the front of the activation queue")


func test_validate_movement_ignores_activation_order_when_queue_empty() -> void:
	# Compatibilidad: partidas/tests que no rellenan units_to_activate no
	# deben verse afectados por esta validacion nueva.
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	match_data["mechs"][1] = mech

	var result = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(6, 5), 1
	)

	assert_true(result.valid, "Without an activation queue, movement should not be restricted by turn order")


# ============================================================
# ROTATION VALIDATION TESTS
# ============================================================

func test_validate_rotation_valid() -> void:
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	mech["current_movement"] = 3
	match_data["mechs"][1] = mech
	
	var result = ServerActionValidator.validate_rotation(
		match_data, 1, 1001, 1  # Rotate from 0 to 1
	)
	
	assert_true(result.valid, "Valid rotation should pass")


func test_validate_rotation_insufficient_mp() -> void:
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	mech["current_movement"] = 0
	match_data["mechs"][1] = mech
	
	var result = ServerActionValidator.validate_rotation(
		match_data, 1, 1001, 3  # Try to rotate 3 facings with 0 MP
	)
	
	assert_false(result.valid, "Rotation without MP should fail")
	assert_eq(result.reason, "Insufficient MPs for rotation")


func test_validate_rotation_invalid_facing() -> void:
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	match_data["mechs"][1] = mech
	
	var result = ServerActionValidator.validate_rotation(
		match_data, 1, 1001, 10  # Invalid facing
	)
	
	assert_false(result.valid, "Invalid facing should fail")
	assert_eq(result.reason, "Invalid facing")


# ============================================================
# WEAPON ATTACK VALIDATION TESTS
# ============================================================

func test_validate_weapon_attack_valid() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "weapon_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var target = _create_test_mech(2, 1002, "enemy", Vector2i(7, 5))  # 2 hexes away
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_weapon_attack(
		match_data, 1, 2, [0], 1001  # Fire medium laser
	)
	
	assert_true(result.valid, "Valid weapon attack should pass")


func test_validate_weapon_attack_wrong_phase() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "movement"  # Wrong phase
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var target = _create_test_mech(2, 1002, "enemy", Vector2i(7, 5))
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_weapon_attack(
		match_data, 1, 2, [0], 1001
	)
	
	assert_false(result.valid, "Attack in wrong phase should fail")
	assert_eq(result.reason, "Not weapon attack phase")


func test_validate_weapon_attack_friendly_fire() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "weapon_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var target = _create_test_mech(2, 1001, "player", Vector2i(7, 5))  # Same team!
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_weapon_attack(
		match_data, 1, 2, [0], 1001
	)
	
	assert_false(result.valid, "Friendly fire should fail")
	assert_eq(result.reason, "Cannot attack ally")


func test_validate_weapon_attack_out_of_range() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "weapon_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(0, 0))
	var target = _create_test_mech(2, 1002, "enemy", Vector2i(20, 20))  # Way too far
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_weapon_attack(
		match_data, 1, 2, [0], 1001  # Medium laser max range = 9
	)
	
	assert_false(result.valid, "Out of range attack should fail")
	assert_eq(result.reason, "All weapons out of range")


func test_validate_weapon_attack_rejects_out_of_activation_order() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "weapon_attack"
	var attacker1 = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var attacker2 = _create_test_mech(2, 1001, "player", Vector2i(6, 5))
	var target = _create_test_mech(3, 1002, "enemy", Vector2i(5, 6))
	match_data["mechs"][1] = attacker1
	match_data["mechs"][2] = attacker2
	match_data["mechs"][3] = target
	match_data["units_to_activate"] = [2, 1]  # Le toca al mech 2 primero
	match_data["current_unit_index"] = 0

	var result = ServerActionValidator.validate_weapon_attack(
		match_data, 1, 3, [0], 1001  # Dispara con el mech 1, que no le toca
	)

	assert_false(result.valid, "Should reject firing with a mech that isn't up in the activation order")
	assert_eq(result.reason, "Not this mech's turn to activate")


func test_validate_weapon_attack_no_ammo() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "weapon_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	attacker["weapons"][1]["current_ammo"] = 0  # AC/10 out of ammo
	var target = _create_test_mech(2, 1002, "enemy", Vector2i(7, 5))
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_weapon_attack(
		match_data, 1, 2, [1], 1001  # Fire AC/10 with no ammo
	)
	
	assert_false(result.valid, "Attack with no ammo should fail")
	assert_eq(result.reason, "No ammunition")


func test_validate_weapon_attack_already_fired() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "weapon_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	attacker["fired_this_turn"] = true
	var target = _create_test_mech(2, 1002, "enemy", Vector2i(7, 5))
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_weapon_attack(
		match_data, 1, 2, [0], 1001
	)
	
	assert_false(result.valid, "Cannot fire twice in one turn")
	assert_eq(result.reason, "Already fired this turn")


func test_validate_weapon_attack_invalid_weapon_index() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "weapon_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var target = _create_test_mech(2, 1002, "enemy", Vector2i(7, 5))
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_weapon_attack(
		match_data, 1, 2, [99], 1001  # Invalid weapon index
	)
	
	assert_false(result.valid, "Invalid weapon index should fail")
	assert_eq(result.reason, "Weapon index out of range")


# ============================================================
# PHYSICAL ATTACK VALIDATION TESTS
# ============================================================

func test_validate_physical_attack_valid() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "physical_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var target = _create_test_mech(2, 1002, "enemy", Vector2i(6, 5))  # Adjacent
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_physical_attack(
		match_data, 1, 2, "punch_left", 1001
	)
	
	assert_true(result.valid, "Valid physical attack should pass")


func test_validate_physical_attack_target_too_far() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "physical_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var target = _create_test_mech(2, 1002, "enemy", Vector2i(8, 5))  # 3 hexes away
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_physical_attack(
		match_data, 1, 2, "punch_left", 1001
	)
	
	assert_false(result.valid, "Physical attack from 3 hexes should fail")
	assert_eq(result.reason, "Target too far for physical attack")


func test_validate_physical_attack_invalid_type() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "physical_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var target = _create_test_mech(2, 1002, "enemy", Vector2i(6, 5))
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_physical_attack(
		match_data, 1, 2, "invalid_attack", 1001
	)
	
	assert_false(result.valid, "Invalid attack type should fail")
	assert_eq(result.reason, "Invalid attack type")


func test_validate_physical_attack_prone() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "physical_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	attacker["is_prone"] = true
	var target = _create_test_mech(2, 1002, "enemy", Vector2i(6, 5))
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_physical_attack(
		match_data, 1, 2, "punch_left", 1001
	)
	
	assert_false(result.valid, "Prone mech cannot attack physically")
	assert_eq(result.reason, "Cannot attack while prone")


# ============================================================
# DEPLOYMENT VALIDATION TESTS
# ============================================================

func test_validate_deployment_valid_player() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "deployment"
	
	var mech_data = {"name": "Atlas", "tonnage": 100, "walk_mp": 3, "run_mp": 5, "jump_mp": 0}
	
	var result = ServerActionValidator.validate_deployment(
		match_data, 1001, Vector2i(5, 15), "player", mech_data  # y >= 13 for player
	)
	
	assert_true(result.valid, "Valid player deployment should pass")


func test_validate_deployment_valid_enemy() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "deployment"
	
	var mech_data = {"name": "Atlas", "tonnage": 100, "walk_mp": 3, "run_mp": 5, "jump_mp": 0}
	
	var result = ServerActionValidator.validate_deployment(
		match_data, 1002, Vector2i(5, 2), "enemy", mech_data  # y < 5 for enemy
	)
	
	assert_true(result.valid, "Valid enemy deployment should pass")


func test_validate_deployment_wrong_zone() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "deployment"
	
	var mech_data = {"name": "Atlas", "tonnage": 100, "walk_mp": 3, "run_mp": 5, "jump_mp": 0}
	
	# Player trying to deploy in enemy zone
	var result = ServerActionValidator.validate_deployment(
		match_data, 1001, Vector2i(5, 2), "player", mech_data
	)
	
	assert_false(result.valid, "Deployment in wrong zone should fail")
	assert_eq(result.reason, "Invalid deployment zone")


func test_validate_deployment_wrong_phase() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "movement"
	
	var mech_data = {"name": "Atlas", "tonnage": 100, "walk_mp": 3, "run_mp": 5, "jump_mp": 0}
	
	var result = ServerActionValidator.validate_deployment(
		match_data, 1001, Vector2i(5, 15), "player", mech_data
	)
	
	assert_false(result.valid, "Deployment in wrong phase should fail")
	assert_eq(result.reason, "Not deployment phase")


func test_validate_deployment_hex_occupied() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "deployment"
	
	# Pre-existing mech
	var existing_mech = _create_test_mech(1, 1001, "player", Vector2i(5, 15))
	match_data["mechs"][1] = existing_mech
	
	var mech_data = {"name": "Atlas", "tonnage": 100, "walk_mp": 3, "run_mp": 5, "jump_mp": 0}
	
	var result = ServerActionValidator.validate_deployment(
		match_data, 1001, Vector2i(5, 15), "player", mech_data  # Same hex
	)
	
	assert_false(result.valid, "Deployment on occupied hex should fail")
	assert_eq(result.reason, "Hex already occupied")


func test_validate_deployment_invalid_tonnage() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "deployment"
	
	var mech_data = {"name": "Exploiter", "tonnage": 500, "walk_mp": 3, "run_mp": 5, "jump_mp": 0}  # Invalid!
	
	var result = ServerActionValidator.validate_deployment(
		match_data, 1001, Vector2i(5, 15), "player", mech_data
	)
	
	assert_false(result.valid, "Invalid tonnage should fail")
	assert_eq(result.reason, "Invalid tonnage")


func test_validate_deployment_invalid_mp() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "deployment"
	
	var mech_data = {"name": "Cheater", "tonnage": 50, "walk_mp": 100, "run_mp": 5, "jump_mp": 0}  # Invalid!
	
	var result = ServerActionValidator.validate_deployment(
		match_data, 1001, Vector2i(5, 15), "player", mech_data
	)
	
	assert_false(result.valid, "Invalid walk_mp should fail")
	assert_eq(result.reason, "Invalid walk_mp")


# ============================================================
# EDGE CASES & SECURITY TESTS
# ============================================================

func test_validate_movement_nonexistent_mech() -> void:
	var match_data = _create_test_match_data()
	
	var result = ServerActionValidator.validate_movement(
		match_data, 99999, 1001, Vector2i(6, 5), 1
	)
	
	assert_false(result.valid, "Nonexistent mech should fail")
	assert_eq(result.reason, "Mech not found")


func test_validate_weapon_attack_nonexistent_target() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "weapon_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	match_data["mechs"][1] = attacker
	
	var result = ServerActionValidator.validate_weapon_attack(
		match_data, 1, 99999, [0], 1001  # Target doesn't exist
	)
	
	assert_false(result.valid, "Attack on nonexistent target should fail")
	assert_eq(result.reason, "Target not found")


func test_validate_weapon_attack_empty_weapons() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "weapon_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var target = _create_test_mech(2, 1002, "enemy", Vector2i(7, 5))
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_weapon_attack(
		match_data, 1, 2, [], 1001  # No weapons selected
	)
	
	assert_false(result.valid, "Attack with no weapons should fail")
	assert_eq(result.reason, "No weapons selected")


func test_validate_weapon_attack_destroyed_target() -> void:
	var match_data = _create_test_match_data()
	match_data["current_phase"] = "weapon_attack"
	var attacker = _create_test_mech(1, 1001, "player", Vector2i(5, 5))
	var target = _create_test_mech(2, 1002, "enemy", Vector2i(7, 5))
	target["is_destroyed"] = true
	match_data["mechs"][1] = attacker
	match_data["mechs"][2] = target
	
	var result = ServerActionValidator.validate_weapon_attack(
		match_data, 1, 2, [0], 1001
	)
	
	assert_false(result.valid, "Attack on destroyed target should fail")
	assert_eq(result.reason, "Target is already destroyed")


# ============================================================
# HELPER FUNCTION TESTS
# ============================================================

func test_hex_distance_calculation() -> void:
	# Usar la función pública a través del validador
	var match_data = _create_test_match_data()
	var mech = _create_test_mech(1, 1001, "player", Vector2i(0, 0))
	match_data["mechs"][1] = mech
	
	# Mover 3 hexes - debería fallar con walk_mp de 4, pero pasar
	var result_short = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(3, 0), 1
	)
	assert_true(result_short.valid, "3 hex movement with 4 walk_mp should pass")
	
	# Reset
	mech["moved_this_turn"] = false
	
	# Mover 5 hexes - debería fallar con walk_mp de 4
	var result_long = ServerActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(5, 0), 1
	)
	assert_false(result_long.valid, "5 hex movement with 4 walk_mp should fail")
