## Tests para validadores de networking
## Cobertura de ServerActionValidator y ServerMatchValidator
extends GutTest

const ActionValidator := preload("res://scripts/network/server_action_validator.gd")
const MatchValidator := preload("res://scripts/network/server_match_validator.gd")


## ═══════════════════════════════════════════════════════════════════════════
## HELPERS
## ═══════════════════════════════════════════════════════════════════════════

func _create_test_mech(owner_peer: int, team: String, position: Vector2i = Vector2i(5, 5)) -> Dictionary:
	return {
		"mech_id": randi(),
		"owner_peer": owner_peer,
		"team": team,
		"hex_position": position,
		"facing": 0,
		"walk_mp": 4,
		"run_mp": 6,
		"jump_mp": 0,
		"moved_this_turn": false,
		"is_destroyed": false,
		"is_shutdown": false,
		"heat": 0,
	}


func _create_test_match(player1_peer: int = 1001, player2_peer: int = 1002) -> Dictionary:
	var mech1_id := 1
	var mech2_id := 2
	return {
		"match_id": 1,
		"player1_peer": player1_peer,
		"player2_peer": player2_peer,
		"current_phase": "movement",
		"current_turn": 1,
		"mechs": {
			mech1_id: _create_test_mech(player1_peer, "player", Vector2i(5, 14)),
			mech2_id: _create_test_mech(player2_peer, "enemy", Vector2i(5, 3)),
		},
	}


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE ValidationResult
## ═══════════════════════════════════════════════════════════════════════════

func test_validation_result_success() -> void:
	var result := ActionValidator.ValidationResult.success()
	
	assert_true(result.valid, "success() debe ser válido")
	assert_eq(result.reason, "", "success() no debe tener razón de fallo")


func test_validation_result_failure() -> void:
	var result := ActionValidator.ValidationResult.failure("Test error", {"key": "value"})
	
	assert_false(result.valid, "failure() no debe ser válido")
	assert_eq(result.reason, "Test error", "failure() debe tener razón")
	assert_eq(result.context["key"], "value", "failure() debe preservar contexto")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE ServerMatchValidator
## ═══════════════════════════════════════════════════════════════════════════

func test_validate_match_participant_valid() -> void:
	var match_data := _create_test_match(1001, 1002)
	var active_battles := {1: match_data}
	
	# Player 1 es participante
	assert_true(
		MatchValidator.validate_match_participant(active_battles, 1, 1001),
		"Player 1 debe ser participante válido"
	)
	
	# Player 2 es participante
	assert_true(
		MatchValidator.validate_match_participant(active_battles, 1, 1002),
		"Player 2 debe ser participante válido"
	)


func test_validate_match_participant_invalid_peer() -> void:
	var match_data := _create_test_match(1001, 1002)
	var active_battles := {1: match_data}
	
	# Peer 9999 no es participante
	assert_false(
		MatchValidator.validate_match_participant(active_battles, 1, 9999),
		"Peer desconocido no debe ser participante"
	)


func test_validate_match_participant_invalid_match() -> void:
	# Nota: Este test verifica que un match inexistente retorna false
	# El validator internamente loguea un warning, pero eso es comportamiento esperado
	# Usamos assert_engine_error para indicar que el warning es esperado
	var active_battles := {}
	
	# Match inexistente - generará un warning esperado del Logger
	assert_false(
		MatchValidator.validate_match_participant(active_battles, 999, 1001),
		"Match inexistente no debe validar"
	)
	
	# Indicar que esperábamos un warning (se ve como engine error por push_warning)
	assert_engine_error("Match not found")


func test_validate_mech_ownership_valid() -> void:
	var match_data := _create_test_match(1001, 1002)
	
	# Peer 1001 es dueño del mech 1
	assert_true(
		MatchValidator.validate_mech_ownership(match_data, 1, 1001),
		"Owner debe validar como propietario"
	)


func test_validate_mech_ownership_invalid() -> void:
	var match_data := _create_test_match(1001, 1002)
	
	# Peer 1002 NO es dueño del mech 1
	assert_false(
		MatchValidator.validate_mech_ownership(match_data, 1, 1002),
		"Non-owner no debe validar como propietario"
	)
	
	# Mech inexistente
	assert_false(
		MatchValidator.validate_mech_ownership(match_data, 999, 1001),
		"Mech inexistente no debe validar"
	)


func test_is_valid_deployment_hex_player() -> void:
	# Player deploya en sur (y >= 13)
	assert_true(MatchValidator.is_valid_deployment_hex(Vector2i(5, 13), "player"))
	assert_true(MatchValidator.is_valid_deployment_hex(Vector2i(5, 17), "player"))
	assert_false(MatchValidator.is_valid_deployment_hex(Vector2i(5, 12), "player"))
	assert_false(MatchValidator.is_valid_deployment_hex(Vector2i(5, 0), "player"))


func test_is_valid_deployment_hex_enemy() -> void:
	# Enemy deploya en norte (y < 5)
	assert_true(MatchValidator.is_valid_deployment_hex(Vector2i(5, 0), "enemy"))
	assert_true(MatchValidator.is_valid_deployment_hex(Vector2i(5, 4), "enemy"))
	assert_false(MatchValidator.is_valid_deployment_hex(Vector2i(5, 5), "enemy"))
	assert_false(MatchValidator.is_valid_deployment_hex(Vector2i(5, 13), "enemy"))


func test_get_team_for_peer() -> void:
	var match_data := _create_test_match(1001, 1002)
	
	assert_eq(MatchValidator.get_team_for_peer(match_data, 1001), "player")
	assert_eq(MatchValidator.get_team_for_peer(match_data, 1002), "enemy")


func test_get_opponent_peer() -> void:
	var match_data := _create_test_match(1001, 1002)
	
	assert_eq(MatchValidator.get_opponent_peer(match_data, 1001), 1002)
	assert_eq(MatchValidator.get_opponent_peer(match_data, 1002), 1001)


func test_hex_distance() -> void:
	# Misma posición
	assert_eq(MatchValidator.hex_distance(Vector2i(5, 5), Vector2i(5, 5)), 0)
	
	# Distancia horizontal
	assert_eq(MatchValidator.hex_distance(Vector2i(0, 0), Vector2i(3, 0)), 3)
	
	# Distancia vertical
	assert_eq(MatchValidator.hex_distance(Vector2i(0, 0), Vector2i(0, 4)), 4)
	
	# Distancia diagonal
	assert_eq(MatchValidator.hex_distance(Vector2i(0, 0), Vector2i(3, 3)), 3)


func test_get_facing_to_hex() -> void:
	var origin := Vector2i(5, 5)
	
	# Norte (dy < 0, dx = 0)
	assert_eq(MatchValidator.get_facing_to_hex(origin, Vector2i(5, 3)), 0)
	
	# Sur (dy > 0, dx = 0)
	assert_eq(MatchValidator.get_facing_to_hex(origin, Vector2i(5, 7)), 3)
	
	# Noreste (dx > 0, dy <= 0)
	assert_eq(MatchValidator.get_facing_to_hex(origin, Vector2i(7, 4)), 1)
	
	# Sureste (dx > 0, dy > 0)
	assert_eq(MatchValidator.get_facing_to_hex(origin, Vector2i(7, 6)), 2)
	
	# Suroeste (dx < 0, dy > 0)
	assert_eq(MatchValidator.get_facing_to_hex(origin, Vector2i(3, 6)), 4)
	
	# Noroeste (dx < 0, dy <= 0)
	assert_eq(MatchValidator.get_facing_to_hex(origin, Vector2i(3, 4)), 5)


func test_get_max_movement() -> void:
	var mech := _create_test_mech(1001, "player")
	mech["walk_mp"] = 4
	mech["run_mp"] = 6
	mech["jump_mp"] = 3
	
	assert_eq(MatchValidator.get_max_movement(mech, 1), 4, "Walk debe usar walk_mp")
	assert_eq(MatchValidator.get_max_movement(mech, 2), 6, "Run debe usar run_mp")
	assert_eq(MatchValidator.get_max_movement(mech, 3), 3, "Jump debe usar jump_mp")
	assert_eq(MatchValidator.get_max_movement(mech, 99), 4, "Default debe usar walk_mp")


func test_calculate_rotations() -> void:
	# Sin rotación
	assert_eq(MatchValidator.calculate_rotations(0, 0), 0)
	
	# Rotación de 1
	assert_eq(MatchValidator.calculate_rotations(0, 1), 1)
	assert_eq(MatchValidator.calculate_rotations(1, 0), 1)
	
	# Rotación de 2
	assert_eq(MatchValidator.calculate_rotations(0, 2), 2)
	
	# Rotación de 3 (máximo en sistema hexagonal de 6)
	assert_eq(MatchValidator.calculate_rotations(0, 3), 3)
	
	# Rotación de 4 → debe ser 2 (por el otro lado)
	assert_eq(MatchValidator.calculate_rotations(0, 4), 2)
	
	# Rotación de 5 → debe ser 1 (por el otro lado)
	assert_eq(MatchValidator.calculate_rotations(0, 5), 1)


func test_check_battle_end_ongoing() -> void:
	var match_data := _create_test_match()
	
	var result := MatchValidator.check_battle_end(match_data)
	
	assert_false(result["ended"], "Batalla con mechs vivos no ha terminado")
	assert_eq(result["winner"], "")


func test_check_battle_end_player_wins() -> void:
	var match_data := _create_test_match()
	# Destruir mech enemigo
	match_data["mechs"][2]["is_destroyed"] = true
	
	var result := MatchValidator.check_battle_end(match_data)
	
	assert_true(result["ended"], "Batalla debe terminar")
	assert_eq(result["winner"], "player", "Player debe ganar")


func test_check_battle_end_enemy_wins() -> void:
	var match_data := _create_test_match()
	# Destruir mech del player
	match_data["mechs"][1]["is_destroyed"] = true
	
	var result := MatchValidator.check_battle_end(match_data)
	
	assert_true(result["ended"], "Batalla debe terminar")
	assert_eq(result["winner"], "enemy", "Enemy debe ganar")


func test_generate_mech_id_unique() -> void:
	var id1 := MatchValidator.generate_mech_id(1, "player")
	await get_tree().create_timer(0.01).timeout  # Pequeña espera para diferentes ticks
	var id2 := MatchValidator.generate_mech_id(1, "player")
	
	# IDs deben ser diferentes (basados en time)
	assert_ne(id1, id2, "IDs generados deben ser únicos")


func test_generate_match_id_unique() -> void:
	var id1 := MatchValidator.generate_match_id(1001, 1002)
	await get_tree().create_timer(0.01).timeout
	var id2 := MatchValidator.generate_match_id(1001, 1002)
	
	assert_ne(id1, id2, "Match IDs generados deben ser únicos")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE ServerActionValidator - Movement
## ═══════════════════════════════════════════════════════════════════════════

func test_validate_movement_mech_not_found() -> void:
	var match_data := _create_test_match()
	
	var result := ActionValidator.validate_movement(
		match_data, 999, 1001, Vector2i(5, 13), 1
	)
	
	assert_false(result.valid, "Mech inexistente debe fallar")
	assert_true(result.reason.contains("not found"), "Debe indicar mech no encontrado")


func test_validate_movement_not_your_mech() -> void:
	var match_data := _create_test_match(1001, 1002)
	
	# Peer 1002 intenta mover mech de peer 1001
	var result := ActionValidator.validate_movement(
		match_data, 1, 1002, Vector2i(5, 13), 1
	)
	
	assert_false(result.valid, "Mover mech ajeno debe fallar")
	assert_true(result.reason.contains("Not your mech"), "Debe indicar no es tu mech")


func test_validate_movement_wrong_phase() -> void:
	var match_data := _create_test_match()
	match_data["current_phase"] = "combat"
	
	var result := ActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(5, 13), 1
	)
	
	assert_false(result.valid, "Mover en fase incorrecta debe fallar")
	assert_true(result.reason.contains("Not movement phase"), "Debe indicar fase incorrecta")


func test_validate_movement_mech_destroyed() -> void:
	var match_data := _create_test_match()
	match_data["mechs"][1]["is_destroyed"] = true
	
	var result := ActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(5, 13), 1
	)
	
	assert_false(result.valid, "Mech destruido no puede moverse")
	assert_true(result.reason.contains("destroyed"), "Debe indicar mech destruido")


func test_validate_movement_mech_shutdown() -> void:
	var match_data := _create_test_match()
	match_data["mechs"][1]["is_shutdown"] = true
	
	var result := ActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(5, 13), 1
	)
	
	assert_false(result.valid, "Mech en shutdown no puede moverse")
	assert_true(result.reason.contains("shutdown"), "Debe indicar mech en shutdown")


func test_validate_movement_already_moved() -> void:
	var match_data := _create_test_match()
	match_data["mechs"][1]["moved_this_turn"] = true
	
	var result := ActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(5, 13), 1
	)
	
	assert_false(result.valid, "Mech que ya se movió no puede moverse")
	assert_true(result.reason.contains("already moved"), "Debe indicar ya se movió")


func test_validate_movement_invalid_type() -> void:
	var match_data := _create_test_match()
	
	var result := ActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(5, 13), 99  # Tipo inválido
	)
	
	assert_false(result.valid, "Tipo de movimiento inválido debe fallar")
	assert_true(result.reason.contains("Invalid movement type"), "Debe indicar tipo inválido")


func test_validate_movement_jump_without_jump_mp() -> void:
	var match_data := _create_test_match()
	match_data["mechs"][1]["jump_mp"] = 0
	
	var result := ActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(5, 13), 3  # Jump
	)
	
	assert_false(result.valid, "Mech sin jump_mp no puede saltar")
	assert_true(result.reason.contains("cannot jump"), "Debe indicar no puede saltar")


func test_validate_movement_insufficient_mp() -> void:
	var match_data := _create_test_match()
	match_data["mechs"][1]["walk_mp"] = 2
	match_data["mechs"][1]["hex_position"] = Vector2i(0, 0)
	
	# Intentar mover 10 hexes con solo 2 MP
	var result := ActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(10, 0), 1  # Walk
	)
	
	assert_false(result.valid, "Movimiento sin suficientes MP debe fallar")
	assert_true(result.reason.contains("Insufficient movement points"), "Debe indicar MP insuficientes")


func test_validate_movement_success() -> void:
	var match_data := _create_test_match()
	match_data["mechs"][1]["hex_position"] = Vector2i(5, 14)
	match_data["mechs"][1]["walk_mp"] = 4
	
	# Mover 2 hexes con 4 MP disponibles
	var result := ActionValidator.validate_movement(
		match_data, 1, 1001, Vector2i(5, 12), 1  # Walk
	)
	
	assert_true(result.valid, "Movimiento válido debe pasar")


## ═══════════════════════════════════════════════════════════════════════════
## TESTS DE CONSTANTES
## ═══════════════════════════════════════════════════════════════════════════

func test_action_validator_constants() -> void:
	# Verificar que las constantes de seguridad están definidas
	assert_eq(ActionValidator.MAX_MOVEMENT_POINTS, 20, "MAX_MOVEMENT_POINTS debe ser 20")
	assert_eq(ActionValidator.MAX_JUMP_POINTS, 10, "MAX_JUMP_POINTS debe ser 10")
	assert_eq(ActionValidator.MAX_HEAT, 50, "MAX_HEAT debe ser 50")
	assert_eq(ActionValidator.MAX_WEAPONS_PER_SALVO, 10, "MAX_WEAPONS_PER_SALVO debe ser 10")
	assert_eq(ActionValidator.MAX_FACING, 5, "MAX_FACING debe ser 5")
	assert_eq(ActionValidator.MIN_FACING, 0, "MIN_FACING debe ser 0")


func test_movement_type_constants() -> void:
	assert_eq(ActionValidator.MOVEMENT_WALK, 1)
	assert_eq(ActionValidator.MOVEMENT_RUN, 2)
	assert_eq(ActionValidator.MOVEMENT_JUMP, 3)
