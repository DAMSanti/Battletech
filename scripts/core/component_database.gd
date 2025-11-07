extends Node
class_name ComponentDatabase

# Base de datos de componentes para BattleTech Total Warfare
# Incluye armas, equipamiento, y sistemas especiales

enum ComponentType {
	WEAPON_ENERGY,
	WEAPON_BALLISTIC,
	WEAPON_MISSILE,
	WEAPON_PHYSICAL,
	EQUIPMENT_HEATSINK,
	EQUIPMENT_JUMPJET,
	EQUIPMENT_ECM,
	EQUIPMENT_SENSOR,
	EQUIPMENT_ARMOR,
	EQUIPMENT_AMMO,
	ENGINE,
	STRUCTURE
}

enum WeaponCategory {
	ENERGY,
	BALLISTIC,
	MISSILE,
	PHYSICAL
}

# Estructura de datos para componentes
# {
#   "id": String,
#   "name": String,
#   "type": ComponentType,
#   "weight": float (toneladas),
#   "slots": int (critical slots),
#   "damage": int (para armas),
#   "heat": int (calor generado),
#   "range_short": int,
#   "range_medium": int,
#   "range_long": int,
#   "ammo_per_ton": int (para armas con munición),
#   "requires_ammo": bool,
#   "ammo_type": String (id de munición compatible)
# }

static var weapons_database = {
	# ========== ARMAS DE ENERGÍA ==========
	"small_laser": {
		"id": "small_laser",
		"name": "Small Laser",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 0.5,
		"slots": 1,
		"damage": 3,
		"heat": 1,
		"range_short": 1,
		"range_medium": 2,
		"range_long": 3,
		"requires_ammo": false,
		"tech_base": "IS",  # Inner Sphere
		"description": "Laser básico de corto alcance"
	},
	
	"medium_laser": {
		"id": "medium_laser",
		"name": "Medium Laser",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 1.0,
		"slots": 1,
		"damage": 5,
		"heat": 3,
		"range_short": 3,
		"range_medium": 6,
		"range_long": 9,
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "El arma estándar más equilibrada"
	},
	
	"large_laser": {
		"id": "large_laser",
		"name": "Large Laser",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 5.0,
		"slots": 2,
		"damage": 8,
		"heat": 8,
		"range_short": 5,
		"range_medium": 10,
		"range_long": 15,
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "Laser pesado de largo alcance"
	},
	
	"medium_pulse_laser": {
		"id": "medium_pulse_laser",
		"name": "Medium Pulse Laser",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 2.0,
		"slots": 1,
		"damage": 6,
		"heat": 4,
		"range_short": 2,
		"range_medium": 4,
		"range_long": 6,
		"requires_ammo": false,
		"to_hit_modifier": -2,  # Bonus al impactar
		"tech_base": "IS",
		"description": "Versión pulse con mayor precisión"
	},
	
	"ppc": {
		"id": "ppc",
		"name": "PPC",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 7.0,
		"slots": 3,
		"damage": 10,
		"heat": 10,
		"range_short": 0,  # No dispara a corto rango
		"range_medium": 6,
		"range_long": 18,
		"range_minimum": 3,  # Rango mínimo
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "Particle Projection Cannon - Alto daño y calor"
	},
	
	# ========== ARMAS BALÍSTICAS ==========
	"ac2": {
		"id": "ac2",
		"name": "Autocannon/2",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 6.0,
		"slots": 1,
		"damage": 2,
		"heat": 1,
		"range_short": 8,
		"range_medium": 16,
		"range_long": 24,
		"requires_ammo": true,
		"ammo_type": "ac2_ammo",
		"tech_base": "IS",
		"description": "Autocañón ligero de largo alcance"
	},
	
	"ac5": {
		"id": "ac5",
		"name": "Autocannon/5",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 8.0,
		"slots": 4,
		"damage": 5,
		"heat": 1,
		"range_short": 6,
		"range_medium": 12,
		"range_long": 18,
		"requires_ammo": true,
		"ammo_type": "ac5_ammo",
		"tech_base": "IS",
		"description": "Autocañón medio versátil"
	},
	
	"ac10": {
		"id": "ac10",
		"name": "Autocannon/10",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 12.0,
		"slots": 7,
		"damage": 10,
		"heat": 3,
		"range_short": 5,
		"range_medium": 10,
		"range_long": 15,
		"requires_ammo": true,
		"ammo_type": "ac10_ammo",
		"tech_base": "IS",
		"description": "Autocañón pesado equilibrado"
	},
	
	"ac20": {
		"id": "ac20",
		"name": "Autocannon/20",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 14.0,
		"slots": 10,
		"damage": 20,
		"heat": 7,
		"range_short": 3,
		"range_medium": 6,
		"range_long": 9,
		"requires_ammo": true,
		"ammo_type": "ac20_ammo",
		"tech_base": "IS",
		"description": "El autocañón más devastador"
	},
	
	"gauss_rifle": {
		"id": "gauss_rifle",
		"name": "Gauss Rifle",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 15.0,
		"slots": 7,
		"damage": 15,
		"heat": 1,
		"range_short": 7,
		"range_medium": 15,
		"range_long": 22,
		"requires_ammo": true,
		"ammo_type": "gauss_ammo",
		"explosive": true,  # Explota si se destruye
		"tech_base": "IS",
		"description": "Rifle magnético de alta energía"
	},
	
	"machine_gun": {
		"id": "machine_gun",
		"name": "Machine Gun",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 0.5,
		"slots": 1,
		"damage": 2,
		"heat": 0,
		"range_short": 1,
		"range_medium": 2,
		"range_long": 3,
		"requires_ammo": true,
		"ammo_type": "mg_ammo",
		"tech_base": "IS",
		"description": "Arma antipersonal ligera"
	},
	
	# ========== MISILES ==========
	"srm2": {
		"id": "srm2",
		"name": "SRM-2",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 1.0,
		"slots": 1,
		"damage": 2,  # Por misil
		"missiles_per_salvo": 2,
		"heat": 2,
		"range_short": 3,
		"range_medium": 6,
		"range_long": 9,
		"requires_ammo": true,
		"ammo_type": "srm_ammo",
		"tech_base": "IS",
		"description": "Lanzador de misiles de corto alcance"
	},
	
	"srm4": {
		"id": "srm4",
		"name": "SRM-4",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 2.0,
		"slots": 1,
		"damage": 2,
		"missiles_per_salvo": 4,
		"heat": 3,
		"range_short": 3,
		"range_medium": 6,
		"range_long": 9,
		"requires_ammo": true,
		"ammo_type": "srm_ammo",
		"tech_base": "IS",
		"description": "Lanzador medio de corto alcance"
	},
	
	"srm6": {
		"id": "srm6",
		"name": "SRM-6",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 3.0,
		"slots": 2,
		"damage": 2,
		"missiles_per_salvo": 6,
		"heat": 4,
		"range_short": 3,
		"range_medium": 6,
		"range_long": 9,
		"requires_ammo": true,
		"ammo_type": "srm_ammo",
		"tech_base": "IS",
		"description": "Lanzador pesado de corto alcance"
	},
	
	"lrm5": {
		"id": "lrm5",
		"name": "LRM-5",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 2.0,
		"slots": 1,
		"damage": 1,  # Por misil
		"missiles_per_salvo": 5,
		"heat": 2,
		"range_short": 0,  # No dispara a corto rango
		"range_medium": 7,
		"range_long": 21,
		"range_minimum": 6,
		"requires_ammo": true,
		"ammo_type": "lrm_ammo",
		"tech_base": "IS",
		"description": "Lanzador ligero de largo alcance"
	},
	
	"lrm10": {
		"id": "lrm10",
		"name": "LRM-10",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 5.0,
		"slots": 2,
		"damage": 1,
		"missiles_per_salvo": 10,
		"heat": 4,
		"range_short": 0,
		"range_medium": 7,
		"range_long": 21,
		"range_minimum": 6,
		"requires_ammo": true,
		"ammo_type": "lrm_ammo",
		"tech_base": "IS",
		"description": "Lanzador medio de largo alcance"
	},
	
	"lrm15": {
		"id": "lrm15",
		"name": "LRM-15",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 7.0,
		"slots": 3,
		"damage": 1,
		"missiles_per_salvo": 15,
		"heat": 5,
		"range_short": 0,
		"range_medium": 7,
		"range_long": 21,
		"range_minimum": 6,
		"requires_ammo": true,
		"ammo_type": "lrm_ammo",
		"tech_base": "IS",
		"description": "Lanzador pesado de largo alcance"
	},
	
	"lrm20": {
		"id": "lrm20",
		"name": "LRM-20",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 10.0,
		"slots": 5,
		"damage": 1,
		"missiles_per_salvo": 20,
		"heat": 6,
		"range_short": 0,
		"range_medium": 7,
		"range_long": 21,
		"range_minimum": 6,
		"requires_ammo": true,
		"ammo_type": "lrm_ammo",
		"tech_base": "IS",
		"description": "El mayor lanzador estándar"
	},
}

static var ammo_database = {
	"ac2_ammo": {
		"id": "ac2_ammo",
		"name": "AC/2 Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 45,
		"ammo_type": "ac2_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"ac5_ammo": {
		"id": "ac5_ammo",
		"name": "AC/5 Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 20,
		"ammo_type": "ac5_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"ac10_ammo": {
		"id": "ac10_ammo",
		"name": "AC/10 Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 10,
		"ammo_type": "ac10_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"ac20_ammo": {
		"id": "ac20_ammo",
		"name": "AC/20 Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 5,
		"ammo_type": "ac20_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"gauss_ammo": {
		"id": "gauss_ammo",
		"name": "Gauss Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 8,
		"ammo_type": "gauss_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"mg_ammo": {
		"id": "mg_ammo",
		"name": "Machine Gun Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 200,
		"ammo_type": "mg_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"srm_ammo": {
		"id": "srm_ammo",
		"name": "SRM Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 100,  # Total de misiles
		"ammo_type": "srm_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"lrm_ammo": {
		"id": "lrm_ammo",
		"name": "LRM Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 120,
		"ammo_type": "lrm_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
}

static var equipment_database = {
	"heat_sink": {
		"id": "heat_sink",
		"name": "Heat Sink",
		"type": ComponentType.EQUIPMENT_HEATSINK,
		"weight": 1.0,
		"slots": 1,
		"heat_dissipation": 1,
		"tech_base": "IS",
		"description": "Disipa 1 punto de calor por turno"
	},
	
	"double_heat_sink": {
		"id": "double_heat_sink",
		"name": "Double Heat Sink",
		"type": ComponentType.EQUIPMENT_HEATSINK,
		"weight": 1.0,
		"slots": 3,  # En engine slots: 1, en otros: 3
		"heat_dissipation": 2,
		"tech_base": "IS",
		"description": "Disipa 2 puntos de calor por turno"
	},
	
	"jump_jet": {
		"id": "jump_jet",
		"name": "Jump Jet",
		"type": ComponentType.EQUIPMENT_JUMPJET,
		"weight": 0.0,  # Varía según tonnage del mech
		"slots": 1,
		"tech_base": "IS",
		"description": "Permite saltar 1 hex por jet"
	},
	
	"ecm_suite": {
		"id": "ecm_suite",
		"name": "Guardian ECM Suite",
		"type": ComponentType.EQUIPMENT_ECM,
		"weight": 1.5,
		"slots": 2,
		"ecm_range": 6,  # Hexágonos
		"tech_base": "IS",
		"description": "ECM: +1 to-hit para armas de misiles dentro de 6 hexes. BAP enemigo lo niega."
	},
	
	"beagle_probe": {
		"id": "beagle_probe",
		"name": "Beagle Active Probe",
		"type": ComponentType.EQUIPMENT_SENSOR,
		"weight": 1.5,
		"slots": 2,
		"sensor_range": 4,  # Hexágonos extra
		"tech_base": "IS",
		"description": "BAP: Niega efectos de ECM enemigo. Mejora targeting (+1 a corto alcance)."
	},
	
	"case": {
		"id": "case",
		"name": "CASE",
		"type": ComponentType.EQUIPMENT_ARMOR,
		"weight": 0.5,
		"slots": 1,
		"tech_base": "IS",
		"description": "Cellular Ammunition Storage Equipment - Previene explosión de munición"
	},
}

# Funciones de consulta
static func get_weapon(weapon_id: String) -> Dictionary:
	if weapons_database.has(weapon_id):
		return weapons_database[weapon_id].duplicate(true)
	return {}

static func get_ammo(ammo_id: String) -> Dictionary:
	if ammo_database.has(ammo_id):
		return ammo_database[ammo_id].duplicate(true)
	return {}

static func get_equipment(equipment_id: String) -> Dictionary:
	if equipment_database.has(equipment_id):
		return equipment_database[equipment_id].duplicate(true)
	return {}

static func get_all_weapons() -> Array:
	var result = []
	for weapon_id in weapons_database.keys():
		result.append(weapons_database[weapon_id].duplicate(true))
	return result

static func get_weapons_by_category(category: WeaponCategory) -> Array:
	var result = []
	for weapon_id in weapons_database.keys():
		var weapon = weapons_database[weapon_id]
		if weapon.get("category", -1) == category:
			result.append(weapon.duplicate(true))
	return result

static func get_all_ammo() -> Array:
	var result = []
	for ammo_id in ammo_database.keys():
		result.append(ammo_database[ammo_id].duplicate(true))
	return result

static func get_all_equipment() -> Array:
	var result = []
	for equip_id in equipment_database.keys():
		result.append(equipment_database[equip_id].duplicate(true))
	return result

# Calcular peso de jump jet según tonnage del mech
static func calculate_jump_jet_weight(mech_tonnage: int) -> float:
	if mech_tonnage <= 55:
		return 0.5
	elif mech_tonnage <= 85:
		return 1.0
	else:
		return 2.0

# Verificar si un mech tiene ECM activo
static func has_ecm_suite(mech) -> bool:
	if not "weapons" in mech:
		return false
	
	for weapon in mech.weapons:
		if weapon.get("id", "") == "ecm_suite":
			# Verificar que no esté destruido
			if not weapon.get("destroyed", false):
				return true
	return false

# Verificar si un mech tiene Beagle Active Probe activo
static func has_beagle_probe(mech) -> bool:
	if not "weapons" in mech:
		return false
	
	for weapon in mech.weapons:
		if weapon.get("id", "") == "beagle_probe":
			# Verificar que no esté destruido
			if not weapon.get("destroyed", false):
				return true
	return false

# Calcular distancia en hexágonos entre dos posiciones
static func hex_distance(pos1: Vector2i, pos2: Vector2i) -> int:
	var dx = abs(pos2.x - pos1.x)
	var dy = abs(pos2.y - pos1.y)
	var dz = abs((pos1.x + pos1.y) - (pos2.x + pos2.y))
	return max(dx, max(dy, dz))

# Verificar si un mech tiene CASE en una localización específica
static func has_case_in_location(mech, location: String) -> bool:
	if not "weapons" in mech:
		return false
	
	for weapon in mech.weapons:
		if weapon.get("id", "") == "case":
			# Verificar que no esté destruido y que esté en la localización correcta
			if not weapon.get("destroyed", false):
				var weapon_location = weapon.get("location", "")
				if weapon_location == location:
					return true
	return false

# Encontrar munición explosiva en una localización específica
static func get_explosive_ammo_in_location(mech, location: String) -> Array:
	var explosive_ammo = []
	
	if not "weapons" in mech:
		return explosive_ammo
	
	for weapon in mech.weapons:
		# Verificar si es munición explosiva en esa localización
		if weapon.get("explosive", false) and not weapon.get("destroyed", false):
			var weapon_location = weapon.get("location", "")
			if weapon_location == location:
				explosive_ammo.append(weapon)
	
	return explosive_ammo
