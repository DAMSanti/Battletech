# ============================================================================
# test_elo_calculator.gd - Tests unitarios para el calculador de ELO
# Steel Titans - Framework GUT
# ============================================================================
extends GutTest

const EloCalculator = preload("res://scripts/core/elo_calculator.gd")


# ============================================================================
# SETUP Y TEARDOWN
# ============================================================================

func before_each():
	gut.p("--- Preparando test de ELO ---")


func after_each():
	gut.p("--- Test de ELO completado ---")


# ============================================================================
# TESTS DE EXPECTED SCORE
# ============================================================================

func test_expected_score_equal_elo():
	"""Test: Jugadores con mismo ELO tienen 50% de probabilidad"""
	var expected = EloCalculator.expected_score(1000, 1000)
	assert_almost_eq(expected, 0.5, 0.01, "Mismo ELO = 50% probabilidad")


func test_expected_score_higher_elo():
	"""Test: Mayor ELO = mayor probabilidad de ganar"""
	var expected = EloCalculator.expected_score(1200, 1000)
	assert_gt(expected, 0.5, "Mayor ELO debería tener >50% probabilidad")
	assert_lt(expected, 1.0, "Probabilidad debería ser <100%")


func test_expected_score_lower_elo():
	"""Test: Menor ELO = menor probabilidad de ganar"""
	var expected = EloCalculator.expected_score(1000, 1200)
	assert_lt(expected, 0.5, "Menor ELO debería tener <50% probabilidad")
	assert_gt(expected, 0.0, "Probabilidad debería ser >0%")


func test_expected_score_symmetry():
	"""Test: Las probabilidades son simétricas y suman 1"""
	var expected_a = EloCalculator.expected_score(1000, 1200)
	var expected_b = EloCalculator.expected_score(1200, 1000)
	assert_almost_eq(expected_a + expected_b, 1.0, 0.01, "Probabilidades deberían sumar 1")


# ============================================================================
# TESTS DE K-FACTOR (con 2 parámetros: elo, games_played)
# ============================================================================

func test_k_factor_new_player():
	"""Test: Jugadores nuevos tienen K-factor alto"""
	var k = EloCalculator.get_k_factor(1000, 5)
	assert_eq(k, EloCalculator.MAX_K_FACTOR, "Jugador nuevo debería tener K máximo")


func test_k_factor_provisional():
	"""Test: Jugadores provisionales tienen K moderado"""
	var k = EloCalculator.get_k_factor(1000, 15)
	assert_gt(k, EloCalculator.MIN_K_FACTOR, "K debería ser > mínimo")
	assert_lt(k, EloCalculator.MAX_K_FACTOR, "K debería ser < máximo")


func test_k_factor_established():
	"""Test: Jugadores establecidos tienen K-factor bajo"""
	var k = EloCalculator.get_k_factor(1000, 100)
	assert_lte(k, EloCalculator.BASE_K_FACTOR, "Jugador veterano debería tener K base o menor")


func test_k_factor_high_elo_reduction():
	"""Test: ELO alto reduce el K-factor"""
	var k_normal = EloCalculator.get_k_factor(1500, 100)
	var k_high = EloCalculator.get_k_factor(2500, 100)
	assert_lt(k_high, k_normal, "ELO alto debería reducir K-factor")


# ============================================================================
# TESTS DE GET_K_FACTOR_SIMPLE (solo games_played)
# ============================================================================

func test_get_k_factor_simple_new():
	"""Test: K-factor simple para jugador nuevo"""
	var k = EloCalculator.get_k_factor_simple(10)
	assert_eq(k, 48, "Menos de 30 partidas = K de 48")


func test_get_k_factor_simple_intermediate():
	"""Test: K-factor simple para jugador intermedio"""
	var k = EloCalculator.get_k_factor_simple(50)
	assert_eq(k, 32, "30-99 partidas = K de 32")


func test_get_k_factor_simple_experienced():
	"""Test: K-factor simple para jugador experimentado"""
	var k = EloCalculator.get_k_factor_simple(150)
	assert_eq(k, 24, "100-199 partidas = K de 24")


func test_get_k_factor_simple_veteran():
	"""Test: K-factor simple para veterano"""
	var k = EloCalculator.get_k_factor_simple(300)
	assert_eq(k, 16, "200+ partidas = K de 16")


# ============================================================================
# TESTS DE CALCULATE_ELO_CHANGE
# ============================================================================

func test_calculate_elo_change_win():
	"""Test: Ganar incrementa ELO"""
	var result = EloCalculator.calculate_elo_change(1000, 1000, true, 50)
	assert_gt(result.elo_change, 0, "Ganar debería dar cambio positivo")
	assert_gt(result.new_elo, 1000, "Nuevo ELO debería ser mayor")


func test_calculate_elo_change_loss():
	"""Test: Perder decrementa ELO"""
	var result = EloCalculator.calculate_elo_change(1000, 1000, false, 50)
	assert_lt(result.elo_change, 0, "Perder debería dar cambio negativo")
	assert_lt(result.new_elo, 1000, "Nuevo ELO debería ser menor")


func test_calculate_elo_change_upset_win():
	"""Test: Ganar contra mejor oponente da más puntos"""
	var normal_win = EloCalculator.calculate_elo_change(1000, 1000, true, 50)
	var upset_win = EloCalculator.calculate_elo_change(1000, 1200, true, 50)
	assert_gt(upset_win.elo_change, normal_win.elo_change, "Upset debería dar más puntos")


func test_calculate_elo_change_returns_dict():
	"""Test: calculate_elo_change retorna diccionario con campos correctos"""
	var result = EloCalculator.calculate_elo_change(1000, 1000, true, 50)
	assert_has(result, "new_elo", "Debe tener new_elo")
	assert_has(result, "elo_change", "Debe tener elo_change")
	assert_has(result, "expected", "Debe tener expected")


# ============================================================================
# TESTS DE CALCULATE_MATCH_RESULT
# ============================================================================

func test_calculate_match_result_p1_wins():
	"""Test: Resultado de partida cuando P1 gana"""
	var result = EloCalculator.calculate_match_result(1000, 1000, true, 50, 50)
	assert_gt(result.winner.new_elo, 1000, "Ganador gana ELO")
	assert_lt(result.loser.new_elo, 1000, "Perdedor pierde ELO")


func test_calculate_match_result_p2_wins():
	"""Test: Resultado de partida cuando P2 gana"""
	var result = EloCalculator.calculate_match_result(1000, 1000, false, 50, 50)
	assert_gt(result.winner.new_elo, 1000, "Ganador gana ELO")
	assert_lt(result.loser.new_elo, 1000, "Perdedor pierde ELO")


func test_calculate_match_result_structure():
	"""Test: Estructura del resultado de partida"""
	var result = EloCalculator.calculate_match_result(1000, 1000, true)
	assert_has(result, "winner", "Debe tener winner")
	assert_has(result, "loser", "Debe tener loser")
	assert_has(result.winner, "new_elo", "Winner debe tener new_elo")
	assert_has(result.loser, "new_elo", "Loser debe tener new_elo")


# ============================================================================
# TESTS DE GET_RANK_NAME
# ============================================================================

func test_get_rank_name_recruit():
	"""Test: ELO bajo es Recruit"""
	var rank = EloCalculator.get_rank_name(400)
	assert_eq(rank, "Recruit", "ELO 400 debería ser Recruit")


func test_get_rank_name_mid():
	"""Test: ELO medio tiene rango apropiado"""
	var rank = EloCalculator.get_rank_name(1500)
	assert_ne(rank, "Recruit", "ELO 1500 no debería ser Recruit")


func test_get_rank_name_high():
	"""Test: ELO alto tiene rango alto"""
	var rank = EloCalculator.get_rank_name(2500)
	assert_true(rank is String, "Rank debe ser String")
	assert_ne(rank, "", "Rank no debe estar vacío")


# ============================================================================
# TESTS DE GET_RANK_TIER
# ============================================================================

func test_get_rank_tier_minimum():
	"""Test: ELO mínimo tiene tier 1"""
	var tier = EloCalculator.get_rank_tier(0)
	assert_eq(tier, 1, "ELO 0 debería ser tier 1")


func test_get_rank_tier_increases():
	"""Test: Mayor ELO = mayor tier"""
	var tier_low = EloCalculator.get_rank_tier(500)
	var tier_high = EloCalculator.get_rank_tier(2000)
	assert_gt(tier_high, tier_low, "ELO alto debería tener tier mayor")


func test_get_rank_tier_valid_range():
	"""Test: Tier está en rango válido"""
	var tier = EloCalculator.get_rank_tier(1500)
	assert_gte(tier, 1, "Tier debe ser >= 1")
	assert_lte(tier, 11, "Tier debe ser <= 11")


# ============================================================================
# TESTS DE GET_RANK_INFO
# ============================================================================

func test_get_rank_info_structure():
	"""Test: get_rank_info retorna estructura correcta"""
	var info = EloCalculator.get_rank_info(1000)
	assert_has(info, "name", "Debe tener name")
	assert_has(info, "tier", "Debe tener tier")
	assert_has(info, "min_elo", "Debe tener min_elo")
	assert_has(info, "next_rank_elo", "Debe tener next_rank_elo")
	assert_has(info, "progress_to_next", "Debe tener progress_to_next")


func test_get_rank_info_progress():
	"""Test: Progreso está entre 0 y 1"""
	var info = EloCalculator.get_rank_info(1200)
	assert_gte(info.progress_to_next, 0.0, "Progreso debe ser >= 0")
	assert_lte(info.progress_to_next, 1.0, "Progreso debe ser <= 1")


# ============================================================================
# TESTS DE POINTS_TO_NEXT_RANK
# ============================================================================

func test_points_to_next_rank_positive():
	"""Test: Puntos al siguiente rango es positivo o cero"""
	var points = EloCalculator.points_to_next_rank(1000)
	assert_gte(points, 0, "Puntos debe ser >= 0")


func test_points_to_next_rank_max():
	"""Test: En rango máximo, puntos es 0"""
	var points = EloCalculator.points_to_next_rank(3000)
	assert_eq(points, 0, "En rango máximo puntos = 0")


# ============================================================================
# TESTS DE CHECK_RANK_UP
# ============================================================================

func test_check_rank_up_no_change():
	"""Test: Sin cambio de rango"""
	var result = EloCalculator.check_rank_up(1000, 1010)
	assert_false(result.ranked_up, "No debería subir de rango")


func test_check_rank_up_promotion():
	"""Test: Subida de rango"""
	var result = EloCalculator.check_rank_up(490, 510)
	assert_true(result.ranked_up, "Debería detectar subida de rango")
	assert_has(result, "old_rank", "Debe tener old_rank")
	assert_has(result, "new_rank", "Debe tener new_rank")


func test_check_rank_up_demotion():
	"""Test: Bajada de rango"""
	var result = EloCalculator.check_rank_up(510, 490)
	assert_true(result.get("ranked_down", false), "Debería detectar bajada de rango")


# ============================================================================
# TESTS DE GET_RANK_FOR_ELO
# ============================================================================

func test_get_rank_for_elo_structure():
	"""Test: get_rank_for_elo retorna estructura correcta"""
	var info = EloCalculator.get_rank_for_elo(1500)
	assert_has(info, "name", "Debe tener name")
	assert_has(info, "tier", "Debe tener tier")
	assert_has(info, "min_elo", "Debe tener min_elo")
	assert_has(info, "max_elo", "Debe tener max_elo")


func test_get_rank_for_elo_valid():
	"""Test: Información de rango es válida"""
	var info = EloCalculator.get_rank_for_elo(1000)
	assert_true(info.name is String, "Name debe ser String")
	assert_gte(info.tier, 1, "Tier debe ser >= 1")


# ============================================================================
# TESTS DE PERFORMANCE_BONUS
# ============================================================================

func test_calculate_performance_bonus_neutral():
	"""Test: Sin kills/deaths da bonus cercano a 0"""
	var bonus = EloCalculator.calculate_performance_bonus(0, 0, 0, 1000, 1000)
	assert_true(bonus is int, "Bonus debe ser entero")


func test_calculate_performance_bonus_good_kd():
	"""Test: Buen K/D da bonus positivo"""
	var bonus = EloCalculator.calculate_performance_bonus(5, 1, 3, 1000, 1000)
	assert_gte(bonus, 0, "Buen K/D debería dar bonus >= 0")


func test_calculate_performance_bonus_bad_kd():
	"""Test: Mal K/D puede dar bonus negativo"""
	var bonus = EloCalculator.calculate_performance_bonus(0, 5, 0, 1000, 1000)
	assert_lte(bonus, 0, "Mal K/D debería dar bonus <= 0")


func test_calculate_performance_bonus_clamped():
	"""Test: Bonus está limitado"""
	var bonus = EloCalculator.calculate_performance_bonus(100, 0, 50, 1000, 1000)
	assert_lte(bonus, EloCalculator.MAX_PERFORMANCE_BONUS, "Bonus no debe exceder máximo")
	assert_gte(bonus, -EloCalculator.MAX_PERFORMANCE_BONUS, "Bonus no debe ser menor que -máximo")


# ============================================================================
# TESTS DE CALCULATE_1V1 (función principal)
# ============================================================================

func test_calculate_1v1_returns_array():
	"""Test: calculate_1v1 retorna Array"""
	var result = EloCalculator.calculate_1v1("p1", 1000, "p2", 1000)
	assert_true(result is Array, "Debe retornar Array")
	assert_eq(result.size(), 2, "Debe tener 2 elementos (winner y loser)")


func test_calculate_1v1_winner_gains():
	"""Test: Ganador gana ELO en 1v1"""
	var result = EloCalculator.calculate_1v1("winner", 1000, "loser", 1000)
	var winner_change = result[0]
	assert_gt(winner_change.elo_after, winner_change.elo_before, "Ganador debe ganar ELO")


func test_calculate_1v1_loser_loses():
	"""Test: Perdedor pierde ELO en 1v1"""
	var result = EloCalculator.calculate_1v1("winner", 1000, "loser", 1000)
	var loser_change = result[1]
	assert_lt(loser_change.elo_after, loser_change.elo_before, "Perdedor debe perder ELO")


func test_calculate_1v1_draw():
	"""Test: Empate en 1v1"""
	var result = EloCalculator.calculate_1v1("p1", 1000, "p2", 1000, 50, 50, true)
	assert_eq(result.size(), 2, "Empate también retorna 2 cambios")


# ============================================================================
# TESTS DE CALCULATE_TEAM_MATCH
# ============================================================================

func test_calculate_team_match_returns_array():
	"""Test: calculate_team_match retorna Array"""
	var players: Array[EloCalculator.EloPlayerData] = []
	players.append(EloCalculator.EloPlayerData.new("p1", 1000, 1))
	players.append(EloCalculator.EloPlayerData.new("p2", 1000, 2))
	var result = EloCalculator.calculate_team_match(players, 1)
	assert_true(result is Array, "Debe retornar Array")


func test_calculate_team_match_winner_gains():
	"""Test: Equipo ganador gana ELO"""
	var players: Array[EloCalculator.EloPlayerData] = []
	players.append(EloCalculator.EloPlayerData.new("p1", 1000, 1))
	players.append(EloCalculator.EloPlayerData.new("p2", 1000, 2))
	var result = EloCalculator.calculate_team_match(players, 1)
	
	for change in result:
		if change.user_id == "p1":
			assert_gt(change.elo_after, change.elo_before, "Ganador debe ganar ELO")


# ============================================================================
# TESTS DE CLASES INTERNAS
# ============================================================================

func test_elo_change_class():
	"""Test: Clase EloChange funciona correctamente"""
	var change = EloCalculator.EloChange.new("test_user", 1000, 1020, 5)
	assert_eq(change.user_id, "test_user", "user_id correcto")
	assert_eq(change.elo_before, 1000, "elo_before correcto")
	assert_eq(change.elo_after, 1020, "elo_after correcto")
	assert_eq(change.performance_bonus, 5, "performance_bonus correcto")
	assert_eq(change.elo_change, 20, "elo_change calculado correctamente")


func test_elo_player_data_class():
	"""Test: Clase EloPlayerData funciona correctamente"""
	var player = EloCalculator.EloPlayerData.new("test_user", 1500, 1)
	assert_eq(player.user_id, "test_user", "user_id correcto")
	assert_eq(player.elo, 1500, "elo correcto")
	assert_eq(player.team, 1, "team correcto")


# ============================================================================
# TESTS DE CONSTANTES
# ============================================================================

func test_constants_defined():
	"""Test: Constantes están definidas"""
	assert_gt(EloCalculator.STARTING_ELO, 0, "STARTING_ELO debe ser > 0")
	assert_gt(EloCalculator.MIN_ELO, -1, "MIN_ELO debe ser >= 0")
	assert_gt(EloCalculator.MAX_ELO, EloCalculator.MIN_ELO, "MAX_ELO > MIN_ELO")
	assert_gt(EloCalculator.MAX_K_FACTOR, EloCalculator.MIN_K_FACTOR, "MAX_K > MIN_K")


func test_ranks_defined():
	"""Test: Rangos están definidos"""
	assert_gt(EloCalculator.RANKS.size(), 0, "Debe haber rangos definidos")
