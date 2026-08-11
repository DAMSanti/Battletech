extends RefCounted
class_name WeaponsBalanceTable
## Tabla de balance de armas para análisis y balanceo en tiempo de ejecución
## Genera métricas de eficiencia para todas las armas del juego

const WeaponsDB = preload("res://scripts/core/data/weapons_database.gd")

# Estructura de datos de balance por arma
class WeaponBalanceData:
	var id: String
	var name: String
	var category: String
	var tech_base: String
	var weight: float
	var slots: int
	var damage: int
	var heat: int
	var range_short: int
	var range_medium: int
	var range_long: int
	var range_min: int
	var requires_ammo: bool
	var special: String
	var dps_per_weight: float  # Damage per ton
	var heat_efficiency: float  # Damage per heat
	var range_score: float  # Weighted range metric
	var overall_score: float  # Combined balance score
	
	func _init(weapon_data: Dictionary) -> void:
		id = weapon_data.get("id", "")
		name = weapon_data.get("name", "")
		category = _get_category_name(weapon_data.get("category", 0))
		tech_base = weapon_data.get("tech_base", "IS")
		weight = weapon_data.get("weight", 1.0)
		slots = weapon_data.get("slots", 1)
		heat = weapon_data.get("heat", 0)
		range_short = weapon_data.get("range_short", 0)
		range_medium = weapon_data.get("range_medium", 0)
		range_long = weapon_data.get("range_long", 0)
		range_min = weapon_data.get("range_minimum", 0)
		requires_ammo = weapon_data.get("requires_ammo", false)
		special = _get_special_abilities(weapon_data)
		
		# Calcular daño (considerando misiles)
		damage = _calculate_total_damage(weapon_data)
		
		# Calcular métricas
		_calculate_metrics()
	
	func _get_category_name(cat: int) -> String:
		# WeaponCategory enum: ENERGY=0, BALLISTIC=1, MISSILE=2, PHYSICAL=3
		match cat:
			0: return "Energy"
			1: return "Ballistic"
			2: return "Missile"
			3: return "Physical"
			_: return "Special"
	
	func _get_special_abilities(data: Dictionary) -> String:
		var specials: Array[String] = []
		
		if data.get("to_hit_modifier", 0) != 0:
			specials.append("%+d To-Hit" % data.get("to_hit_modifier"))
		if data.get("range_minimum", 0) > 0:
			specials.append("Min Range %d" % data.get("range_minimum"))
		if data.get("heat_damage", 0) > 0:
			specials.append("Heat Dmg %d" % data.get("heat_damage"))
		if data.get("cluster", false):
			specials.append("Cluster")
		if data.get("ultra", false):
			specials.append("Ultra (x2)")
		if data.get("rotary", false):
			specials.append("Rotary (x6)")
		if data.get("streak", false):
			specials.append("Streak")
		if data.get("multi_missile", false):
			specials.append("Multi (LRM/SRM)")
		if data.get("one_shot", false):
			specials.append("One-Shot")
		if data.get("explosive", false):
			specials.append("Explosive")
		if data.get("missiles_per_salvo", 0) > 0:
			specials.append("%d missiles" % data.get("missiles_per_salvo"))
		
		return ", ".join(specials) if specials.size() > 0 else ""
	
	func _calculate_total_damage(data: Dictionary) -> int:
		var base_damage = data.get("damage", 0)
		var missiles = data.get("missiles_per_salvo", 0)
		
		if missiles > 0:
			return base_damage * missiles
		return base_damage
	
	func _calculate_metrics() -> void:
		# DPS per Weight (Damage per Ton)
		if weight > 0:
			dps_per_weight = float(damage) / weight
		else:
			dps_per_weight = float(damage)
		
		# Heat Efficiency (Damage per Heat)
		if heat > 0:
			heat_efficiency = float(damage) / float(heat)
		else:
			heat_efficiency = INF  # Infinite efficiency for 0 heat weapons
		
		# Range Score (weighted average favoring long range)
		range_score = (range_short * 0.2 + range_medium * 0.3 + range_long * 0.5)
		if range_min > 0:
			range_score *= 0.9  # Penalty for minimum range
		
		# Overall Score (balanced metric)
		_calculate_overall_score()
	
	func _calculate_overall_score() -> void:
		# Normalize metrics to 0-10 scale
		var dps_score = minf(dps_per_weight, 10.0)
		var heat_score = minf(heat_efficiency, 10.0) if heat_efficiency != INF else 10.0
		var range_normalized = minf(range_score / 2.0, 10.0)
		var slot_efficiency = 10.0 - minf(float(slots), 10.0)
		
		# Weighted combination
		overall_score = (
			dps_score * 0.35 +
			heat_score * 0.25 +
			range_normalized * 0.25 +
			slot_efficiency * 0.15
		)
	
	func to_dictionary() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"category": category,
			"tech_base": tech_base,
			"weight": weight,
			"slots": slots,
			"damage": damage,
			"heat": heat,
			"range_short": range_short,
			"range_medium": range_medium,
			"range_long": range_long,
			"range_min": range_min,
			"requires_ammo": requires_ammo,
			"special": special,
			"dps_per_weight": dps_per_weight,
			"heat_efficiency": heat_efficiency,
			"range_score": range_score,
			"overall_score": overall_score
		}


# Cache de datos de balance
static var _balance_cache: Dictionary = {}
static var _is_initialized: bool = false


static func initialize() -> void:
	"""Inicializa la tabla de balance procesando todas las armas"""
	if _is_initialized:
		return
	
	_balance_cache.clear()
	
	for weapon_id in WeaponsDB.database.keys():
		var weapon_data = WeaponsDB.database[weapon_id]
		var balance_data = WeaponBalanceData.new(weapon_data)
		_balance_cache[weapon_id] = balance_data
	
	_is_initialized = true


static func reset_cache() -> void:
	"""Resetea el cache (para tests)"""
	_is_initialized = false
	_balance_cache.clear()


static func get_balance_data(weapon_id: String) -> WeaponBalanceData:
	"""Obtiene datos de balance para un arma específica"""
	if not _is_initialized:
		initialize()
	
	if _balance_cache.has(weapon_id):
		return _balance_cache[weapon_id]
	return null


static func get_all_balance_data() -> Array[WeaponBalanceData]:
	"""Obtiene todos los datos de balance"""
	if not _is_initialized:
		initialize()
	
	var result: Array[WeaponBalanceData] = []
	for weapon_id in _balance_cache.keys():
		result.append(_balance_cache[weapon_id])
	return result


static func get_by_category(category_name: String) -> Array[WeaponBalanceData]:
	"""Obtiene armas filtradas por categoría"""
	if not _is_initialized:
		initialize()
	
	var result: Array[WeaponBalanceData] = []
	for weapon_id in _balance_cache.keys():
		var data: WeaponBalanceData = _balance_cache[weapon_id]
		if data.category == category_name:
			result.append(data)
	return result


static func get_top_by_metric(metric: String, count: int = 10) -> Array[WeaponBalanceData]:
	"""Obtiene las mejores armas según una métrica específica"""
	if not _is_initialized:
		initialize()
	
	var all_data = get_all_balance_data()
	
	# Ordenar por métrica
	match metric:
		"dps_per_weight":
			all_data.sort_custom(func(a, b): return a.dps_per_weight > b.dps_per_weight)
		"heat_efficiency":
			all_data.sort_custom(func(a, b): 
				var a_val = a.heat_efficiency if a.heat_efficiency != INF else 999999
				var b_val = b.heat_efficiency if b.heat_efficiency != INF else 999999
				return a_val > b_val
			)
		"range_score":
			all_data.sort_custom(func(a, b): return a.range_score > b.range_score)
		"overall_score":
			all_data.sort_custom(func(a, b): return a.overall_score > b.overall_score)
		"damage":
			all_data.sort_custom(func(a, b): return a.damage > b.damage)
		_:
			pass
	
	return all_data.slice(0, mini(count, all_data.size()))


static func get_weapons_in_range(min_score: float, max_score: float) -> Array[WeaponBalanceData]:
	"""Obtiene armas dentro de un rango de puntuación overall"""
	if not _is_initialized:
		initialize()
	
	var result: Array[WeaponBalanceData] = []
	for weapon_id in _balance_cache.keys():
		var data: WeaponBalanceData = _balance_cache[weapon_id]
		if data.overall_score >= min_score and data.overall_score <= max_score:
			result.append(data)
	return result


static func compare_weapons(weapon_id_a: String, weapon_id_b: String) -> Dictionary:
	"""Compara dos armas y retorna las diferencias"""
	var a = get_balance_data(weapon_id_a)
	var b = get_balance_data(weapon_id_b)
	
	if not a or not b:
		return {}
	
	return {
		"weapon_a": weapon_id_a,
		"weapon_b": weapon_id_b,
		"damage_diff": a.damage - b.damage,
		"heat_diff": a.heat - b.heat,
		"weight_diff": a.weight - b.weight,
		"dps_diff": a.dps_per_weight - b.dps_per_weight,
		"efficiency_diff": _safe_efficiency_diff(a.heat_efficiency, b.heat_efficiency),
		"range_diff": a.range_score - b.range_score,
		"overall_diff": a.overall_score - b.overall_score,
		"winner": weapon_id_a if a.overall_score > b.overall_score else weapon_id_b
	}


static func _safe_efficiency_diff(a: float, b: float) -> float:
	"""Calcula diferencia de eficiencia manejando INF"""
	if a == INF and b == INF:
		return 0.0
	if a == INF:
		return 999.0
	if b == INF:
		return -999.0
	return a - b


static func get_balance_report() -> String:
	"""Genera un reporte de balance completo"""
	if not _is_initialized:
		initialize()
	
	var report = "=== WEAPONS BALANCE REPORT ===\n\n"
	
	# Top 5 por DPS/Weight
	report += "TOP 5 DPS/WEIGHT:\n"
	var top_dps = get_top_by_metric("dps_per_weight", 5)
	for i in range(top_dps.size()):
		var w = top_dps[i]
		report += "  %d. %s (%.2f)\n" % [i + 1, w.name, w.dps_per_weight]
	
	report += "\nTOP 5 HEAT EFFICIENCY:\n"
	var top_heat = get_top_by_metric("heat_efficiency", 5)
	for i in range(top_heat.size()):
		var w = top_heat[i]
		var eff_str = "∞" if w.heat_efficiency == INF else "%.2f" % w.heat_efficiency
		report += "  %d. %s (%s)\n" % [i + 1, w.name, eff_str]
	
	report += "\nTOP 5 RANGE:\n"
	var top_range = get_top_by_metric("range_score", 5)
	for i in range(top_range.size()):
		var w = top_range[i]
		report += "  %d. %s (%.2f)\n" % [i + 1, w.name, w.range_score]
	
	report += "\nTOP 5 OVERALL:\n"
	var top_overall = get_top_by_metric("overall_score", 5)
	for i in range(top_overall.size()):
		var w = top_overall[i]
		report += "  %d. %s (%.2f)\n" % [i + 1, w.name, w.overall_score]
	
	# Estadísticas por categoría
	report += "\n=== BY CATEGORY ===\n"
	for cat in ["Energy", "Ballistic", "Missile", "Special"]:
		var weapons = get_by_category(cat)
		if weapons.size() > 0:
			var avg_score = 0.0
			for w in weapons:
				avg_score += w.overall_score
			avg_score /= weapons.size()
			report += "%s: %d weapons, avg score: %.2f\n" % [cat, weapons.size(), avg_score]
	
	return report


static func export_to_csv() -> String:
	"""Exporta la tabla de balance a formato CSV"""
	if not _is_initialized:
		initialize()
	
	var csv = "ID,Name,Category,Tech Base,Weight,Slots,Damage,Heat,Range Short,Range Medium,Range Long,Min Range,Requires Ammo,Special,DPS/Weight,Heat Efficiency,Range Score,Overall Score\n"
	
	var all_data = get_all_balance_data()
	all_data.sort_custom(func(a, b): return a.category < b.category or (a.category == b.category and a.name < b.name))
	
	for w in all_data:
		var heat_eff_str = "∞" if w.heat_efficiency == INF else "%.2f" % w.heat_efficiency
		csv += "%s,%s,%s,%s,%.2f,%d,%d,%d,%d,%d,%d,%d,%s,%s,%.2f,%s,%.2f,%.2f\n" % [
			w.id, w.name, w.category, w.tech_base,
			w.weight, w.slots, w.damage, w.heat,
			w.range_short, w.range_medium, w.range_long, w.range_min,
			"Yes" if w.requires_ammo else "No",
			w.special.replace(",", ";"),  # Escape commas in special
			w.dps_per_weight, heat_eff_str, w.range_score, w.overall_score
		]
	
	return csv


# ============================================
# BALANCE THRESHOLDS FOR WARNINGS
# ============================================

const BALANCE_THRESHOLDS = {
	"dps_per_weight_max": 8.0,  # Warning if above
	"dps_per_weight_min": 0.5,  # Warning if below
	"heat_efficiency_max": 10.0,  # Warning if above (excluding INF)
	"overall_score_max": 8.5,  # Potentially OP
	"overall_score_min": 3.0,  # Potentially UP
}


static func get_balance_warnings() -> Array[Dictionary]:
	"""Retorna advertencias de balance para armas potencialmente desequilibradas"""
	if not _is_initialized:
		initialize()
	
	var warnings: Array[Dictionary] = []
	
	for weapon_id in _balance_cache.keys():
		var data: WeaponBalanceData = _balance_cache[weapon_id]
		
		# Check DPS/Weight
		if data.dps_per_weight > BALANCE_THRESHOLDS.dps_per_weight_max:
			warnings.append({
				"weapon": data.name,
				"issue": "HIGH_DPS_WEIGHT",
				"value": data.dps_per_weight,
				"threshold": BALANCE_THRESHOLDS.dps_per_weight_max,
				"severity": "warning"
			})
		elif data.dps_per_weight < BALANCE_THRESHOLDS.dps_per_weight_min:
			warnings.append({
				"weapon": data.name,
				"issue": "LOW_DPS_WEIGHT",
				"value": data.dps_per_weight,
				"threshold": BALANCE_THRESHOLDS.dps_per_weight_min,
				"severity": "info"
			})
		
		# Check Heat Efficiency
		if data.heat_efficiency != INF and data.heat_efficiency > BALANCE_THRESHOLDS.heat_efficiency_max:
			warnings.append({
				"weapon": data.name,
				"issue": "HIGH_HEAT_EFFICIENCY",
				"value": data.heat_efficiency,
				"threshold": BALANCE_THRESHOLDS.heat_efficiency_max,
				"severity": "warning"
			})
		
		# Check Overall Score
		if data.overall_score > BALANCE_THRESHOLDS.overall_score_max:
			warnings.append({
				"weapon": data.name,
				"issue": "POTENTIALLY_OVERPOWERED",
				"value": data.overall_score,
				"threshold": BALANCE_THRESHOLDS.overall_score_max,
				"severity": "error"
			})
		elif data.overall_score < BALANCE_THRESHOLDS.overall_score_min:
			warnings.append({
				"weapon": data.name,
				"issue": "POTENTIALLY_UNDERPOWERED",
				"value": data.overall_score,
				"threshold": BALANCE_THRESHOLDS.overall_score_min,
				"severity": "info"
			})
	
	return warnings
