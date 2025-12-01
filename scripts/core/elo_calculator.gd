## Sistema de cálculo de ELO para Steel Titans
##
## Basado en el sistema Elo estándar con ajustes para juegos tácticos.
## Sincronizado con el cálculo del servidor.
class_name EloCalculator
extends RefCounted


# =============================================================================
# CONSTANTES
# =============================================================================

## K-factor base para cálculos
const BASE_K_FACTOR: int = 32
## K-factor mínimo para jugadores veteranos
const MIN_K_FACTOR: int = 16
## K-factor máximo para jugadores nuevos
const MAX_K_FACTOR: int = 48

## Partidas para ser considerado "provisional"
const PROVISIONAL_GAMES: int = 10
## Partidas para ser considerado "establecido"
const ESTABLISHED_GAMES: int = 30

## ELO mínimo posible
const MIN_ELO: int = 100
## ELO máximo posible
const MAX_ELO: int = 3000
## Cambio máximo por partida
const MAX_CHANGE_PER_GAME: int = 64

## ELO inicial para nuevos jugadores
const STARTING_ELO: int = 1000

## Peso del bonus de rendimiento
const PERFORMANCE_WEIGHT: float = 0.2
## Bonus máximo por rendimiento
const MAX_PERFORMANCE_BONUS: int = 10

## Rangos por ELO
const RANKS: Array[Dictionary] = [
	{"min_elo": 0, "name": "Recruit", "tier": 1},
	{"min_elo": 500, "name": "Cadet", "tier": 2},
	{"min_elo": 800, "name": "MechWarrior", "tier": 3},
	{"min_elo": 1000, "name": "Veteran", "tier": 4},
	{"min_elo": 1200, "name": "Elite", "tier": 5},
	{"min_elo": 1400, "name": "Star Captain", "tier": 6},
	{"min_elo": 1600, "name": "Star Colonel", "tier": 7},
	{"min_elo": 1800, "name": "Galaxy Commander", "tier": 8},
	{"min_elo": 2000, "name": "Khan", "tier": 9},
	{"min_elo": 2200, "name": "ilKhan", "tier": 10},
	{"min_elo": 2500, "name": "Kerensky", "tier": 11},
]


# =============================================================================
# TIPOS
# =============================================================================

## Resultado de partida
enum MatchResult {
	WIN = 1,
	DRAW = 0,
	LOSS = -1
}

## Datos de cambio de ELO
class EloChange:
	var user_id: String
	var elo_before: int
	var elo_after: int
	var elo_change: int
	var performance_bonus: int
	
	func _init(
		p_user_id: String,
		p_elo_before: int,
		p_elo_after: int,
		p_bonus: int = 0
	) -> void:
		user_id = p_user_id
		elo_before = p_elo_before
		elo_after = p_elo_after
		elo_change = p_elo_after - p_elo_before
		performance_bonus = p_bonus


## Datos de jugador para cálculo ELO
class EloPlayerData:
	var user_id: String
	var elo: int
	var team: int
	var kills: int = 0
	var deaths: int = 0
	var damage_dealt: int = 0
	var mechs_destroyed: int = 0
	var games_played: int = 50
	
	func _init(p_user_id: String, p_elo: int, p_team: int) -> void:
		user_id = p_user_id
		elo = p_elo
		team = p_team


# =============================================================================
# CÁLCULOS PRINCIPALES
# =============================================================================

## Calcula la probabilidad esperada de victoria
## Usa la fórmula estándar de Elo
static func expected_score(player_elo: int, opponent_elo: int) -> float:
	var exponent: float = (opponent_elo - player_elo) / 400.0
	return 1.0 / (1.0 + pow(10, exponent))


## Calcula el K-factor dinámico basado en experiencia y ELO
static func get_k_factor(elo: int, games_played: int) -> float:
	var k: float
	
	# Base K según experiencia
	if games_played < PROVISIONAL_GAMES:
		k = MAX_K_FACTOR
	elif games_played < ESTABLISHED_GAMES:
		var progress: float = float(games_played - PROVISIONAL_GAMES) / float(ESTABLISHED_GAMES - PROVISIONAL_GAMES)
		k = MAX_K_FACTOR - (MAX_K_FACTOR - BASE_K_FACTOR) * progress
	else:
		k = BASE_K_FACTOR
	
	# Reducción para ELO alto
	if elo > 2500:
		k = maxf(MIN_K_FACTOR, k * 0.5)
	elif elo > 2000:
		k = maxf(MIN_K_FACTOR, k * 0.75)
	
	return k


## Calcula bonus por rendimiento individual
static func calculate_performance_bonus(
	kills: int,
	deaths: int,
	mechs_destroyed: int,
	team_avg_elo: int,
	enemy_avg_elo: int
) -> int:
	var bonus: float = 0.0
	
	# K/D ratio bonus (máx +/- 3)
	if deaths > 0:
		var kd_ratio: float = float(kills) / float(deaths)
		if kd_ratio > 2.0:
			bonus += 3
		elif kd_ratio > 1.5:
			bonus += 2
		elif kd_ratio > 1.0:
			bonus += 1
		elif kd_ratio < 0.5:
			bonus -= 2
		elif kd_ratio < 0.75:
			bonus -= 1
	elif kills > 0:
		bonus += 3  # Sin muertes y con kills
	
	# Bonus por mechs destruidos
	if mechs_destroyed >= 3:
		bonus += 3
	elif mechs_destroyed >= 2:
		bonus += 2
	elif mechs_destroyed >= 1:
		bonus += 1
	
	# Ajuste por diferencia de ELO
	var elo_diff: int = enemy_avg_elo - team_avg_elo
	if elo_diff > 200:
		bonus += 2
	elif elo_diff > 100:
		bonus += 1
	elif elo_diff < -200:
		bonus -= 1
	
	return clampi(int(bonus), -MAX_PERFORMANCE_BONUS, MAX_PERFORMANCE_BONUS)


## Calcula cambios de ELO para partida 1v1
static func calculate_1v1(
	winner_id: String,
	winner_elo: int,
	loser_id: String,
	loser_elo: int,
	winner_games: int = 50,
	loser_games: int = 50,
	is_draw: bool = false,
	winner_stats: Dictionary = {},
	loser_stats: Dictionary = {}
) -> Array[EloChange]:
	
	# Puntuaciones
	var winner_score: float = 0.5 if is_draw else 1.0
	var loser_score: float = 0.5 if is_draw else 0.0
	
	# Expectativas
	var winner_expected: float = expected_score(winner_elo, loser_elo)
	var loser_expected: float = expected_score(loser_elo, winner_elo)
	
	# K-factors
	var winner_k: float = get_k_factor(winner_elo, winner_games)
	var loser_k: float = get_k_factor(loser_elo, loser_games)
	
	# Cambios base
	var winner_change: int = int(winner_k * (winner_score - winner_expected))
	var loser_change: int = int(loser_k * (loser_score - loser_expected))
	
	# Performance bonus
	var winner_bonus: int = calculate_performance_bonus(
		winner_stats.get("kills", 0),
		winner_stats.get("deaths", 0),
		winner_stats.get("mechs_destroyed", 0),
		winner_elo,
		loser_elo
	)
	var loser_bonus: int = calculate_performance_bonus(
		loser_stats.get("kills", 0),
		loser_stats.get("deaths", 0),
		loser_stats.get("mechs_destroyed", 0),
		loser_elo,
		winner_elo
	)
	
	# Totales con límites
	var winner_total: int = clampi(winner_change + winner_bonus, -MAX_CHANGE_PER_GAME, MAX_CHANGE_PER_GAME)
	var loser_total: int = clampi(loser_change + loser_bonus, -MAX_CHANGE_PER_GAME, MAX_CHANGE_PER_GAME)
	
	var winner_new: int = clampi(winner_elo + winner_total, MIN_ELO, MAX_ELO)
	var loser_new: int = clampi(loser_elo + loser_total, MIN_ELO, MAX_ELO)
	
	return [
		EloChange.new(winner_id, winner_elo, winner_new, winner_bonus),
		EloChange.new(loser_id, loser_elo, loser_new, loser_bonus)
	]


## Calcula cambios de ELO para partida en equipo
static func calculate_team_match(
	players: Array[EloPlayerData],
	winning_team: int  # 0 = empate, 1 o 2 = equipo ganador
) -> Array[EloChange]:
	
	var results: Array[EloChange] = []
	
	# Separar equipos
	var team1: Array[EloPlayerData] = []
	var team2: Array[EloPlayerData] = []
	
	for player in players:
		if player.team == 1:
			team1.append(player)
		else:
			team2.append(player)
	
	if team1.is_empty() or team2.is_empty():
		return results
	
	# ELO promedio de cada equipo
	var team1_avg: int = 0
	var team2_avg: int = 0
	
	for p in team1:
		team1_avg += p.elo
	team1_avg /= team1.size()
	
	for p in team2:
		team2_avg += p.elo
	team2_avg /= team2.size()
	
	# Calcular para cada jugador
	for player in players:
		var score: float
		if winning_team == 0:
			score = 0.5  # Empate
		elif player.team == winning_team:
			score = 1.0  # Victoria
		else:
			score = 0.0  # Derrota
		
		var team_avg: int = team1_avg if player.team == 1 else team2_avg
		var enemy_avg: int = team2_avg if player.team == 1 else team1_avg
		
		# Expectativa basada en promedios
		var expected: float = expected_score(team_avg, enemy_avg)
		
		# K-factor individual
		var k: float = get_k_factor(player.elo, player.games_played)
		
		# Cambio base
		var base_change: int = int(k * (score - expected))
		
		# Performance bonus
		var perf_bonus: int = calculate_performance_bonus(
			player.kills,
			player.deaths,
			player.mechs_destroyed,
			team_avg,
			enemy_avg
		)
		
		# Total
		var total_change: int = clampi(base_change + perf_bonus, -MAX_CHANGE_PER_GAME, MAX_CHANGE_PER_GAME)
		var new_elo: int = clampi(player.elo + total_change, MIN_ELO, MAX_ELO)
		
		results.append(EloChange.new(player.user_id, player.elo, new_elo, perf_bonus))
	
	return results


# =============================================================================
# UTILIDADES DE RANGO
# =============================================================================

## Obtiene el nombre del rango para un ELO dado
static func get_rank_name(elo: int) -> String:
	var rank_name: String = "Recruit"
	for rank in RANKS:
		if elo >= rank.min_elo:
			rank_name = rank.name
	return rank_name


## Obtiene el tier numérico (1-11) para un ELO dado
static func get_rank_tier(elo: int) -> int:
	var tier: int = 1
	for rank in RANKS:
		if elo >= rank.min_elo:
			tier = rank.tier
	return tier


## Obtiene información completa del rango
static func get_rank_info(elo: int) -> Dictionary:
	var info: Dictionary = {
		"name": "Recruit",
		"tier": 1,
		"min_elo": 0,
		"next_rank_elo": 500,
		"progress_to_next": 0.0
	}
	
	for i in range(RANKS.size()):
		if elo >= RANKS[i].min_elo:
			info.name = RANKS[i].name
			info.tier = RANKS[i].tier
			info.min_elo = RANKS[i].min_elo
			
			# Calcular próximo rango
			if i < RANKS.size() - 1:
				var next_rank = RANKS[i + 1]
				info.next_rank_elo = next_rank.min_elo
				var range_size: int = next_rank.min_elo - RANKS[i].min_elo
				var progress: int = elo - RANKS[i].min_elo
				info.progress_to_next = float(progress) / float(range_size)
			else:
				info.next_rank_elo = -1  # Ya está en el máximo
				info.progress_to_next = 1.0
	
	return info


## Calcula cuántos puntos faltan para el siguiente rango
static func points_to_next_rank(elo: int) -> int:
	for i in range(RANKS.size() - 1):
		if elo < RANKS[i + 1].min_elo:
			return RANKS[i + 1].min_elo - elo
	return 0  # Ya en el máximo


## Verifica si subió de rango
static func check_rank_up(old_elo: int, new_elo: int) -> Dictionary:
	var old_tier: int = get_rank_tier(old_elo)
	var new_tier: int = get_rank_tier(new_elo)
	
	if new_tier > old_tier:
		return {
			"ranked_up": true,
			"old_rank": get_rank_name(old_elo),
			"new_rank": get_rank_name(new_elo),
			"tier_change": new_tier - old_tier
		}
	elif new_tier < old_tier:
		return {
			"ranked_up": false,
			"ranked_down": true,
			"old_rank": get_rank_name(old_elo),
			"new_rank": get_rank_name(new_elo),
			"tier_change": new_tier - old_tier
		}
	
	return {"ranked_up": false, "ranked_down": false}


# =============================================================================
# FUNCIONES HELPER PARA TESTS Y USO SIMPLIFICADO
# =============================================================================

## Sobrecarga simplificada de get_k_factor (solo games_played)
static func get_k_factor_simple(games_played: int) -> int:
	if games_played < 30:
		return 48
	elif games_played < 100:
		return 32
	elif games_played < 200:
		return 24
	else:
		return 16


## Calcula cambio de ELO simplificado para 1v1
## Retorna Dictionary con new_elo y elo_change
static func calculate_elo_change(
	player_elo: int,
	opponent_elo: int,
	won: bool,
	games_played: int = 50
) -> Dictionary:
	var score: float = 1.0 if won else 0.0
	var expected: float = expected_score(player_elo, opponent_elo)
	var k: float = get_k_factor(player_elo, games_played)
	
	var change: int = int(k * (score - expected))
	var new_elo: int = clampi(player_elo + change, MIN_ELO, MAX_ELO)
	
	return {
		"new_elo": new_elo,
		"elo_change": change,
		"expected": expected
	}


## Calcula resultado completo de partida 1v1 (simplificado)
## Retorna datos de winner y loser
static func calculate_match_result(
	p1_elo: int,
	p2_elo: int,
	p1_won: bool,
	p1_games: int = 50,
	p2_games: int = 50
) -> Dictionary:
	var winner_elo := p1_elo if p1_won else p2_elo
	var loser_elo := p2_elo if p1_won else p1_elo
	var winner_games := p1_games if p1_won else p2_games
	var loser_games := p2_games if p1_won else p1_games
	
	var winner_result := calculate_elo_change(winner_elo, loser_elo, true, winner_games)
	var loser_result := calculate_elo_change(loser_elo, winner_elo, false, loser_games)
	
	return {
		"winner": winner_result,
		"loser": loser_result
	}


## Obtiene información de rank simplificada
static func get_rank_for_elo(elo: int) -> Dictionary:
	var rank_name := get_rank_name(elo)
	var tier := get_rank_tier(elo)
	var min_elo := 0
	var max_elo := MAX_ELO
	
	for i in range(RANKS.size()):
		if elo >= RANKS[i].min_elo:
			min_elo = RANKS[i].min_elo
			if i < RANKS.size() - 1:
				max_elo = RANKS[i + 1].min_elo - 1
	
	return {
		"name": rank_name,
		"tier": tier,
		"min_elo": min_elo,
		"max_elo": max_elo
	}
