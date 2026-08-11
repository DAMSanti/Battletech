extends Node
class_name BattleStatsTracker

## Sistema de tracking de estadísticas de batalla
## Registra todas las acciones importantes para mostrar al final de la partida

# Estadísticas por equipo
var player_stats: Dictionary = {}
var enemy_stats: Dictionary = {}

# Estadísticas globales de la batalla
var battle_stats: Dictionary = {
	"total_turns": 0,
	"battle_duration_seconds": 0.0,
	"start_time": 0.0
}

# Constantes para tipos de stats
const STAT_DAMAGE_DEALT = "damage_dealt"
const STAT_DAMAGE_RECEIVED = "damage_received"
const STAT_SHOTS_FIRED = "shots_fired"
const STAT_SHOTS_HIT = "shots_hit"
const STAT_MISSILES_FIRED = "missiles_fired"
const STAT_MISSILES_HIT = "missiles_hit"
const STAT_PHYSICAL_ATTACKS = "physical_attacks"
const STAT_PHYSICAL_HITS = "physical_hits"
const STAT_CRITICAL_HITS = "critical_hits"
const STAT_HEAT_GENERATED = "heat_generated"
const STAT_LOCATIONS_DESTROYED = "locations_destroyed"
const STAT_HEXES_MOVED = "hexes_moved"
const STAT_KILLS = "kills"

func _ready():
	start_battle()

func start_battle():
	"""Inicializa las estadísticas para una nueva batalla"""
	player_stats = {}
	enemy_stats = {}
	battle_stats = {
		"total_turns": 0,
		"battle_duration_seconds": 0.0,
		"start_time": Time.get_unix_time_from_system()
	}

func register_mech(mech_name: String, is_player: bool):
	"""Registra un mech para trackear sus stats"""
	var stats_dict = player_stats if is_player else enemy_stats
	
	if not stats_dict.has(mech_name):
		stats_dict[mech_name] = _create_empty_stats()

func _create_empty_stats() -> Dictionary:
	return {
		STAT_DAMAGE_DEALT: 0,
		STAT_DAMAGE_RECEIVED: 0,
		STAT_SHOTS_FIRED: 0,
		STAT_SHOTS_HIT: 0,
		STAT_MISSILES_FIRED: 0,
		STAT_MISSILES_HIT: 0,
		STAT_PHYSICAL_ATTACKS: 0,
		STAT_PHYSICAL_HITS: 0,
		STAT_CRITICAL_HITS: 0,
		STAT_HEAT_GENERATED: 0,
		STAT_LOCATIONS_DESTROYED: 0,
		STAT_HEXES_MOVED: 0,
		STAT_KILLS: 0
	}

func _get_mech_stats(mech_name: String, is_player: bool) -> Dictionary:
	var stats_dict = player_stats if is_player else enemy_stats
	if not stats_dict.has(mech_name):
		register_mech(mech_name, is_player)
	return stats_dict[mech_name]

# ============================================================
# FUNCIONES DE REGISTRO DE ESTADÍSTICAS
# ============================================================

func record_damage(attacker_name: String, attacker_is_player: bool, 
				   target_name: String, target_is_player: bool, damage: int):
	"""Registra daño infligido/recibido"""
	var attacker_stats = _get_mech_stats(attacker_name, attacker_is_player)
	var target_stats = _get_mech_stats(target_name, target_is_player)
	
	attacker_stats[STAT_DAMAGE_DEALT] += damage
	target_stats[STAT_DAMAGE_RECEIVED] += damage

func record_weapon_attack(attacker_name: String, is_player: bool, hit: bool, is_missile: bool = false, missile_count: int = 1):
	"""Registra un ataque con arma"""
	var stats = _get_mech_stats(attacker_name, is_player)
	
	if is_missile:
		stats[STAT_MISSILES_FIRED] += missile_count
		if hit:
			stats[STAT_MISSILES_HIT] += missile_count
	else:
		stats[STAT_SHOTS_FIRED] += 1
		if hit:
			stats[STAT_SHOTS_HIT] += 1

func record_physical_attack(attacker_name: String, is_player: bool, hit: bool):
	"""Registra un ataque físico"""
	var stats = _get_mech_stats(attacker_name, is_player)
	stats[STAT_PHYSICAL_ATTACKS] += 1
	if hit:
		stats[STAT_PHYSICAL_HITS] += 1

func record_critical_hit(attacker_name: String, is_player: bool):
	"""Registra un crítico"""
	var stats = _get_mech_stats(attacker_name, is_player)
	stats[STAT_CRITICAL_HITS] += 1

func record_heat_generated(mech_name: String, is_player: bool, heat: int):
	"""Registra calor generado"""
	var stats = _get_mech_stats(mech_name, is_player)
	stats[STAT_HEAT_GENERATED] += heat

func record_location_destroyed(attacker_name: String, is_player: bool):
	"""Registra una localización destruida"""
	var stats = _get_mech_stats(attacker_name, is_player)
	stats[STAT_LOCATIONS_DESTROYED] += 1

func record_movement(mech_name: String, is_player: bool, hexes: int):
	"""Registra movimiento"""
	var stats = _get_mech_stats(mech_name, is_player)
	stats[STAT_HEXES_MOVED] += hexes

func record_kill(killer_name: String, is_player: bool):
	"""Registra una kill"""
	var stats = _get_mech_stats(killer_name, is_player)
	stats[STAT_KILLS] += 1

func record_turn_end():
	"""Registra el fin de un turno"""
	battle_stats["total_turns"] += 1

# ============================================================
# FUNCIONES DE OBTENCIÓN DE ESTADÍSTICAS
# ============================================================

func get_battle_duration() -> float:
	"""Retorna la duración de la batalla en segundos"""
	return Time.get_unix_time_from_system() - battle_stats["start_time"]

func get_battle_duration_formatted() -> String:
	"""Retorna la duración formateada como MM:SS"""
	var duration = get_battle_duration()
	var minutes = int(duration / 60)
	var seconds = int(duration) % 60
	return "%02d:%02d" % [minutes, seconds]

func get_team_total(is_player: bool, stat_key: String) -> int:
	"""Obtiene el total de una estadística para un equipo"""
	var stats_dict = player_stats if is_player else enemy_stats
	var total = 0
	for mech_stats in stats_dict.values():
		total += mech_stats.get(stat_key, 0)
	return total

func get_mvp(is_player: bool) -> Dictionary:
	"""Obtiene el MVP basado en daño infligido"""
	var stats_dict = player_stats if is_player else enemy_stats
	var mvp_name = ""
	var mvp_damage = 0
	
	for mech_name in stats_dict.keys():
		var damage = stats_dict[mech_name][STAT_DAMAGE_DEALT]
		if damage > mvp_damage:
			mvp_damage = damage
			mvp_name = mech_name
	
	return {"name": mvp_name, "damage": mvp_damage}

func get_accuracy(is_player: bool) -> float:
	"""Obtiene la precisión del equipo (% de hits)"""
	var shots = get_team_total(is_player, STAT_SHOTS_FIRED)
	var hits = get_team_total(is_player, STAT_SHOTS_HIT)
	if shots == 0:
		return 0.0
	return (float(hits) / float(shots)) * 100.0

func get_full_summary() -> Dictionary:
	"""Retorna un resumen completo de la batalla"""
	return {
		"duration": get_battle_duration_formatted(),
		"turns": battle_stats["total_turns"],
		"player": {
			"mechs": player_stats,
			"total_damage": get_team_total(true, STAT_DAMAGE_DEALT),
			"total_received": get_team_total(true, STAT_DAMAGE_RECEIVED),
			"accuracy": get_accuracy(true),
			"criticals": get_team_total(true, STAT_CRITICAL_HITS),
			"kills": get_team_total(true, STAT_KILLS),
			"mvp": get_mvp(true)
		},
		"enemy": {
			"mechs": enemy_stats,
			"total_damage": get_team_total(false, STAT_DAMAGE_DEALT),
			"total_received": get_team_total(false, STAT_DAMAGE_RECEIVED),
			"accuracy": get_accuracy(false),
			"criticals": get_team_total(false, STAT_CRITICAL_HITS),
			"kills": get_team_total(false, STAT_KILLS),
			"mvp": get_mvp(false)
		}
	}
