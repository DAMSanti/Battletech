extends Node
class_name ComponentDatabase

# Base de datos de componentes para BattleTech Total Warfare
# Incluye armas, equipamiento, y sistemas especiales

enum ComponentType {
	WEAPON_ENERGY,
	WEAPON_BALLISTIC,
	WEAPON_MISSILE,
	WEAPON_PHYSICAL,
	WEAPON_SPECIAL,
	EQUIPMENT_HEATSINK,
	EQUIPMENT_JUMPJET,
	EQUIPMENT_ECM,
	EQUIPMENT_SENSOR,
	EQUIPMENT_ARMOR,
	EQUIPMENT_AMMO,
	EQUIPMENT_TARGETING,
	EQUIPMENT_SPECIAL,
	ENGINE,
	STRUCTURE,
	GYROSCOPE,
	ACTUATOR
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
		"heat": 5,
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
		"range_short": 6, 
		"range_medium": 12,
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
		"range_short": 6, 
		"range_medium": 14,
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
		"range_short": 6,
		"range_medium": 14,
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
		"range_short": 6,
		"range_medium": 14,
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
		"range_short": 6,
		"range_medium": 14,
		"range_long": 21,
		"range_minimum": 6,
		"requires_ammo": true,
		"ammo_type": "lrm_ammo",
		"tech_base": "IS",
		"description": "El mayor lanzador estándar"
	},
	
	# ========== ARMAS DE ENERGÍA AVANZADAS ==========
	"small_pulse_laser": {
		"id": "small_pulse_laser",
		"name": "Small Pulse Laser",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 1.0,
		"slots": 1,
		"damage": 3,
		"heat": 2,
		"range_short": 1,
		"range_medium": 2,
		"range_long": 3,
		"to_hit_modifier": -2,
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "Pulse laser ligero con mejor precisión"
	},
	
	"large_pulse_laser": {
		"id": "large_pulse_laser",
		"name": "Large Pulse Laser",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 7.0,
		"slots": 2,
		"damage": 9,
		"heat": 10,
		"range_short": 3,
		"range_medium": 7,
		"range_long": 10,
		"to_hit_modifier": -2,
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "Pulse laser pesado de alta precisión"
	},
	
	"er_small_laser": {
		"id": "er_small_laser",
		"name": "ER Small Laser",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 0.5,
		"slots": 1,
		"damage": 3,
		"heat": 2,
		"range_short": 2,
		"range_medium": 4,
		"range_long": 5,
		"requires_ammo": false,
		"tech_base": "Clan",
		"description": "Extended Range Small Laser Clan"
	},
	
	"er_medium_laser": {
		"id": "er_medium_laser",
		"name": "ER Medium Laser",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 1.0,
		"slots": 1,
		"damage": 5,
		"heat": 5,
		"range_short": 4,
		"range_medium": 8,
		"range_long": 12,
		"requires_ammo": false,
		"tech_base": "Clan",
		"description": "Extended Range Medium Laser Clan"
	},
	
	"er_large_laser": {
		"id": "er_large_laser",
		"name": "ER Large Laser",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 4.0,
		"slots": 2,
		"damage": 10,
		"heat": 12,
		"range_short": 8,
		"range_medium": 15,
		"range_long": 19,
		"requires_ammo": false,
		"tech_base": "Clan",
		"description": "Extended Range Large Laser Clan"
	},
	
	"er_ppc": {
		"id": "er_ppc",
		"name": "ER PPC",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 7.0,
		"slots": 2,
		"damage": 10,
		"heat": 15,
		"range_short": 7,
		"range_medium": 14,
		"range_long": 23,
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "Extended Range PPC - Mayor alcance, más calor"
	},
	
	"heavy_ppc": {
		"id": "heavy_ppc",
		"name": "Heavy PPC",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 10.0,
		"slots": 4,
		"damage": 15,
		"heat": 15,
		"range_short": 6,
		"range_medium": 12,
		"range_long": 18,
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "PPC pesado con daño masivo"
	},
	
	"light_ppc": {
		"id": "light_ppc",
		"name": "Light PPC",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 3.0,
		"slots": 2,
		"damage": 10,
		"heat": 5,
		"range_short": 6,
		"range_medium": 12,
		"range_long": 18,
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "PPC ligero de menor potencia"
	},
	
	"flamer": {
		"id": "flamer",
		"name": "Flamer",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 1.0,
		"slots": 1,
		"damage": 2,
		"heat": 3,
		"heat_damage": 2,
		"range_short": 1,
		"range_medium": 2,
		"range_long": 3,
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "Arma de calor - añade calor al objetivo"
	},
	
	"plasma_cannon": {
		"id": "plasma_cannon",
		"name": "Plasma Cannon",
		"type": ComponentType.WEAPON_ENERGY,
		"category": WeaponCategory.ENERGY,
		"weight": 6.0,
		"slots": 1,
		"damage": 10,
		"heat": 10,
		"heat_damage": 5,
		"range_short": 6,
		"range_medium": 12,
		"range_long": 18,
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "Plasma de alto daño y calor"
	},
	
	# ========== ARMAS BALÍSTICAS AVANZADAS ==========
	"lb2x": {
		"id": "lb2x",
		"name": "LB 2-X AC",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 6.0,
		"slots": 4,
		"damage": 2,
		"heat": 1,
		"range_short": 9,
		"range_medium": 18,
		"range_long": 27,
		"cluster": true,
		"requires_ammo": true,
		"ammo_type": "lb2x_ammo",
		"tech_base": "IS",
		"description": "Autocañón cluster ligero"
	},
	
	"lb5x": {
		"id": "lb5x",
		"name": "LB 5-X AC",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 8.0,
		"slots": 5,
		"damage": 5,
		"heat": 1,
		"range_short": 7,
		"range_medium": 14,
		"range_long": 20,
		"cluster": true,
		"requires_ammo": true,
		"ammo_type": "lb5x_ammo",
		"tech_base": "IS",
		"description": "Autocañón cluster medio"
	},
	
	"lb10x": {
		"id": "lb10x",
		"name": "LB 10-X AC",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 11.0,
		"slots": 6,
		"damage": 10,
		"heat": 2,
		"range_short": 6,
		"range_medium": 12,
		"range_long": 18,
		"cluster": true,
		"requires_ammo": true,
		"ammo_type": "lb10x_ammo",
		"tech_base": "IS",
		"description": "Autocañón cluster pesado"
	},
	
	"lb20x": {
		"id": "lb20x",
		"name": "LB 20-X AC",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 14.0,
		"slots": 11,
		"damage": 20,
		"heat": 6,
		"range_short": 4,
		"range_medium": 8,
		"range_long": 12,
		"cluster": true,
		"requires_ammo": true,
		"ammo_type": "lb20x_ammo",
		"tech_base": "IS",
		"description": "Autocañón cluster devastador"
	},
	
	"uac2": {
		"id": "uac2",
		"name": "Ultra AC/2",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 7.0,
		"slots": 3,
		"damage": 2,
		"heat": 1,
		"range_short": 9,
		"range_medium": 18,
		"range_long": 27,
		"ultra": true,
		"requires_ammo": true,
		"ammo_type": "uac2_ammo",
		"tech_base": "IS",
		"description": "Ultra Autocannon - puede disparar doble"
	},
	
	"uac5": {
		"id": "uac5",
		"name": "Ultra AC/5",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 9.0,
		"slots": 5,
		"damage": 5,
		"heat": 1,
		"range_short": 7,
		"range_medium": 14,
		"range_long": 21,
		"ultra": true,
		"requires_ammo": true,
		"ammo_type": "uac5_ammo",
		"tech_base": "IS",
		"description": "Ultra Autocannon medio"
	},
	
	"uac10": {
		"id": "uac10",
		"name": "Ultra AC/10",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 13.0,
		"slots": 7,
		"damage": 10,
		"heat": 3,
		"range_short": 6,
		"range_medium": 12,
		"range_long": 18,
		"ultra": true,
		"requires_ammo": true,
		"ammo_type": "uac10_ammo",
		"tech_base": "IS",
		"description": "Ultra Autocannon pesado"
	},
	
	"uac20": {
		"id": "uac20",
		"name": "Ultra AC/20",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 15.0,
		"slots": 10,
		"damage": 20,
		"heat": 7,
		"range_short": 3,
		"range_medium": 7,
		"range_long": 10,
		"ultra": true,
		"requires_ammo": true,
		"ammo_type": "uac20_ammo",
		"tech_base": "IS",
		"description": "Ultra Autocannon devastador"
	},
	
	"rac2": {
		"id": "rac2",
		"name": "Rotary AC/2",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 8.0,
		"slots": 3,
		"damage": 2,
		"heat": 1,
		"range_short": 6,
		"range_medium": 12,
		"range_long": 18,
		"rotary": true,
		"requires_ammo": true,
		"ammo_type": "rac2_ammo",
		"tech_base": "IS",
		"description": "Rotary AC - ráfaga rápida"
	},
	
	"rac5": {
		"id": "rac5",
		"name": "Rotary AC/5",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 10.0,
		"slots": 6,
		"damage": 5,
		"heat": 1,
		"range_short": 5,
		"range_medium": 10,
		"range_long": 15,
		"rotary": true,
		"requires_ammo": true,
		"ammo_type": "rac5_ammo",
		"tech_base": "IS",
		"description": "Rotary AC medio"
	},
	
	"light_gauss": {
		"id": "light_gauss",
		"name": "Light Gauss Rifle",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 12.0,
		"slots": 5,
		"damage": 8,
		"heat": 1,
		"range_short": 8,
		"range_medium": 17,
		"range_long": 25,
		"requires_ammo": true,
		"ammo_type": "light_gauss_ammo",
		"explosive": true,
		"tech_base": "IS",
		"description": "Gauss rifle ligero"
	},
	
	"heavy_gauss": {
		"id": "heavy_gauss",
		"name": "Heavy Gauss Rifle",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 18.0,
		"slots": 11,
		"damage": 25,
		"heat": 2,
		"range_short": 6,
		"range_medium": 13,
		"range_long": 20,
		"requires_ammo": true,
		"ammo_type": "heavy_gauss_ammo",
		"explosive": true,
		"tech_base": "IS",
		"description": "Gauss rifle pesado devastador"
	},
	
	"light_mg": {
		"id": "light_mg",
		"name": "Light Machine Gun",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 0.25,
		"slots": 1,
		"damage": 1,
		"heat": 0,
		"range_short": 1,
		"range_medium": 2,
		"range_long": 2,
		"requires_ammo": true,
		"ammo_type": "light_mg_ammo",
		"tech_base": "IS",
		"description": "Ametralladora ligera antipersonal"
	},
	
	"heavy_mg": {
		"id": "heavy_mg",
		"name": "Heavy Machine Gun",
		"type": ComponentType.WEAPON_BALLISTIC,
		"category": WeaponCategory.BALLISTIC,
		"weight": 1.0,
		"slots": 1,
		"damage": 3,
		"heat": 0,
		"range_short": 1,
		"range_medium": 2,
		"range_long": 3,
		"requires_ammo": true,
		"ammo_type": "heavy_mg_ammo",
		"tech_base": "IS",
		"description": "Ametralladora pesada"
	},
	
	# ========== MISILES AVANZADOS ==========
	"streak_srm2": {
		"id": "streak_srm2",
		"name": "Streak SRM-2",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 1.5,
		"slots": 1,
		"damage": 2,
		"missiles_per_salvo": 2,
		"heat": 2,
		"range_short": 3,
		"range_medium": 6,
		"range_long": 9,
		"streak": true,
		"requires_ammo": true,
		"ammo_type": "streak_srm_ammo",
		"tech_base": "IS",
		"description": "SRM que solo dispara si impacta"
	},
	
	"streak_srm4": {
		"id": "streak_srm4",
		"name": "Streak SRM-4",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 3.0,
		"slots": 1,
		"damage": 2,
		"missiles_per_salvo": 4,
		"heat": 3,
		"range_short": 3,
		"range_medium": 6,
		"range_long": 9,
		"streak": true,
		"requires_ammo": true,
		"ammo_type": "streak_srm_ammo",
		"tech_base": "IS",
		"description": "Streak SRM medio"
	},
	
	"streak_srm6": {
		"id": "streak_srm6",
		"name": "Streak SRM-6",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 4.5,
		"slots": 2,
		"damage": 2,
		"missiles_per_salvo": 6,
		"heat": 4,
		"range_short": 3,
		"range_medium": 6,
		"range_long": 9,
		"streak": true,
		"requires_ammo": true,
		"ammo_type": "streak_srm_ammo",
		"tech_base": "IS",
		"description": "Streak SRM pesado"
	},
	
	"mml3": {
		"id": "mml3",
		"name": "MML-3",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 1.5,
		"slots": 2,
		"damage": 1,
		"missiles_per_salvo": 3,
		"heat": 2,
		"multi_missile": true,
		"requires_ammo": true,
		"ammo_type": "mml_ammo",
		"tech_base": "IS",
		"description": "Multi-Missile Launcher - dispara LRM o SRM"
	},
	
	"mml5": {
		"id": "mml5",
		"name": "MML-5",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 3.0,
		"slots": 3,
		"damage": 1,
		"missiles_per_salvo": 5,
		"heat": 3,
		"multi_missile": true,
		"requires_ammo": true,
		"ammo_type": "mml_ammo",
		"tech_base": "IS",
		"description": "Multi-Missile Launcher medio"
	},
	
	"mml7": {
		"id": "mml7",
		"name": "MML-7",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 4.5,
		"slots": 4,
		"damage": 1,
		"missiles_per_salvo": 7,
		"heat": 4,
		"multi_missile": true,
		"requires_ammo": true,
		"ammo_type": "mml_ammo",
		"tech_base": "IS",
		"description": "Multi-Missile Launcher pesado"
	},
	
	"mml9": {
		"id": "mml9",
		"name": "MML-9",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 6.0,
		"slots": 5,
		"damage": 1,
		"missiles_per_salvo": 9,
		"heat": 5,
		"multi_missile": true,
		"requires_ammo": true,
		"ammo_type": "mml_ammo",
		"tech_base": "IS",
		"description": "Multi-Missile Launcher avanzado"
	},
	
	"mrm10": {
		"id": "mrm10",
		"name": "MRM-10",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 3.0,
		"slots": 2,
		"damage": 1,
		"missiles_per_salvo": 10,
		"heat": 4,
		"range_short": 3,
		"range_medium": 8,
		"range_long": 15,
		"requires_ammo": true,
		"ammo_type": "mrm_ammo",
		"tech_base": "IS",
		"description": "Medium Range Missile"
	},
	
	"mrm20": {
		"id": "mrm20",
		"name": "MRM-20",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 7.0,
		"slots": 3,
		"damage": 1,
		"missiles_per_salvo": 20,
		"heat": 6,
		"range_short": 3,
		"range_medium": 8,
		"range_long": 15,
		"requires_ammo": true,
		"ammo_type": "mrm_ammo",
		"tech_base": "IS",
		"description": "MRM pesado"
	},
	
	"mrm30": {
		"id": "mrm30",
		"name": "MRM-30",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 10.0,
		"slots": 5,
		"damage": 1,
		"missiles_per_salvo": 30,
		"heat": 10,
		"range_short": 3,
		"range_medium": 8,
		"range_long": 15,
		"requires_ammo": true,
		"ammo_type": "mrm_ammo",
		"tech_base": "IS",
		"description": "MRM muy pesado"
	},
	
	"mrm40": {
		"id": "mrm40",
		"name": "MRM-40",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 12.0,
		"slots": 7,
		"damage": 1,
		"missiles_per_salvo": 40,
		"heat": 12,
		"range_short": 3,
		"range_medium": 8,
		"range_long": 15,
		"requires_ammo": true,
		"ammo_type": "mrm_ammo",
		"tech_base": "IS",
		"description": "MRM máximo"
	},
	
	# ========== ARMAS ESPECIALES ==========
	"narc": {
		"id": "narc",
		"name": "NARC Missile Beacon",
		"type": ComponentType.WEAPON_SPECIAL,
		"category": WeaponCategory.MISSILE,
		"weight": 3.0,
		"slots": 2,
		"damage": 0,
		"heat": 0,
		"range_short": 3,
		"range_medium": 6,
		"range_long": 9,
		"special_effect": "narc_beacon",
		"requires_ammo": true,
		"ammo_type": "narc_ammo",
		"tech_base": "IS",
		"description": "Beacon para mejorar misiles aliados"
	},
	
	"tag": {
		"id": "tag",
		"name": "TAG",
		"type": ComponentType.WEAPON_SPECIAL,
		"category": WeaponCategory.ENERGY,
		"weight": 1.0,
		"slots": 1,
		"damage": 0,
		"heat": 0,
		"range_short": 5,
		"range_medium": 9,
		"range_long": 15,
		"special_effect": "artillery_designator",
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "Target Acquisition Gear - designador de artillería"
	},
	
	"rocket_launcher_10": {
		"id": "rocket_launcher_10",
		"name": "Rocket Launcher 10",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 0.5,
		"slots": 1,
		"damage": 1,
		"missiles_per_salvo": 10,
		"heat": 3,
		"range_short": 5,
		"range_medium": 11,
		"range_long": 18,
		"one_shot": true,
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "Lanzacohetes desechable"
	},
	
	"rocket_launcher_15": {
		"id": "rocket_launcher_15",
		"name": "Rocket Launcher 15",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 1.0,
		"slots": 2,
		"damage": 1,
		"missiles_per_salvo": 15,
		"heat": 4,
		"range_short": 4,
		"range_medium": 9,
		"range_long": 15,
		"one_shot": true,
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "Lanzacohetes medio desechable"
	},
	
	"rocket_launcher_20": {
		"id": "rocket_launcher_20",
		"name": "Rocket Launcher 20",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 1.5,
		"slots": 3,
		"damage": 1,
		"missiles_per_salvo": 20,
		"heat": 5,
		"range_short": 3,
		"range_medium": 7,
		"range_long": 12,
		"one_shot": true,
		"requires_ammo": false,
		"tech_base": "IS",
		"description": "Lanzacohetes pesado desechable"
	},
	
	"thunderbolt5": {
		"id": "thunderbolt5",
		"name": "Thunderbolt 5",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 3.0,
		"slots": 1,
		"damage": 5,
		"heat": 3,
		"range_short": 5,
		"range_medium": 10,
		"range_long": 15,
		"requires_ammo": true,
		"ammo_type": "thunderbolt_ammo",
		"tech_base": "IS",
		"description": "Misil guiado de precisión"
	},
	
	"thunderbolt10": {
		"id": "thunderbolt10",
		"name": "Thunderbolt 10",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 7.0,
		"slots": 2,
		"damage": 10,
		"heat": 5,
		"range_short": 5,
		"range_medium": 10,
		"range_long": 15,
		"requires_ammo": true,
		"ammo_type": "thunderbolt_ammo",
		"tech_base": "IS",
		"description": "Misil guiado medio"
	},
	
	"thunderbolt15": {
		"id": "thunderbolt15",
		"name": "Thunderbolt 15",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 11.0,
		"slots": 3,
		"damage": 15,
		"heat": 7,
		"range_short": 5,
		"range_medium": 10,
		"range_long": 15,
		"requires_ammo": true,
		"ammo_type": "thunderbolt_ammo",
		"tech_base": "IS",
		"description": "Misil guiado pesado"
	},
	
	"thunderbolt20": {
		"id": "thunderbolt20",
		"name": "Thunderbolt 20",
		"type": ComponentType.WEAPON_MISSILE,
		"category": WeaponCategory.MISSILE,
		"weight": 15.0,
		"slots": 5,
		"damage": 20,
		"heat": 8,
		"range_short": 5,
		"range_medium": 10,
		"range_long": 15,
		"requires_ammo": true,
		"ammo_type": "thunderbolt_ammo",
		"tech_base": "IS",
		"description": "Misil guiado devastador"
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
	
	# ========== MUNICIÓN AVANZADA ==========
	"lb2x_ammo": {
		"id": "lb2x_ammo",
		"name": "LB 2-X Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 45,
		"ammo_type": "lb2x_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"lb5x_ammo": {
		"id": "lb5x_ammo",
		"name": "LB 5-X Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 20,
		"ammo_type": "lb5x_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"lb10x_ammo": {
		"id": "lb10x_ammo",
		"name": "LB 10-X Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 10,
		"ammo_type": "lb10x_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"lb20x_ammo": {
		"id": "lb20x_ammo",
		"name": "LB 20-X Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 5,
		"ammo_type": "lb20x_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"uac2_ammo": {
		"id": "uac2_ammo",
		"name": "Ultra AC/2 Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 45,
		"ammo_type": "uac2_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"uac5_ammo": {
		"id": "uac5_ammo",
		"name": "Ultra AC/5 Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 20,
		"ammo_type": "uac5_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"uac10_ammo": {
		"id": "uac10_ammo",
		"name": "Ultra AC/10 Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 10,
		"ammo_type": "uac10_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"uac20_ammo": {
		"id": "uac20_ammo",
		"name": "Ultra AC/20 Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 5,
		"ammo_type": "uac20_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"rac2_ammo": {
		"id": "rac2_ammo",
		"name": "Rotary AC/2 Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 45,
		"ammo_type": "rac2_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"rac5_ammo": {
		"id": "rac5_ammo",
		"name": "Rotary AC/5 Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 20,
		"ammo_type": "rac5_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"light_gauss_ammo": {
		"id": "light_gauss_ammo",
		"name": "Light Gauss Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 16,
		"ammo_type": "light_gauss_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"heavy_gauss_ammo": {
		"id": "heavy_gauss_ammo",
		"name": "Heavy Gauss Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 4,
		"ammo_type": "heavy_gauss_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"light_mg_ammo": {
		"id": "light_mg_ammo",
		"name": "Light MG Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 200,
		"ammo_type": "light_mg_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"heavy_mg_ammo": {
		"id": "heavy_mg_ammo",
		"name": "Heavy MG Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 100,
		"ammo_type": "heavy_mg_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"streak_srm_ammo": {
		"id": "streak_srm_ammo",
		"name": "Streak SRM Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 100,
		"ammo_type": "streak_srm_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"mml_ammo": {
		"id": "mml_ammo",
		"name": "MML Ammo (LRM/SRM)",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 120,
		"ammo_type": "mml_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"mrm_ammo": {
		"id": "mrm_ammo",
		"name": "MRM Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 240,
		"ammo_type": "mrm_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	"narc_ammo": {
		"id": "narc_ammo",
		"name": "NARC Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 6,
		"ammo_type": "narc_ammo",
		"explosive": false,
		"tech_base": "IS"
	},
	
	"thunderbolt_ammo": {
		"id": "thunderbolt_ammo",
		"name": "Thunderbolt Ammo",
		"type": ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 4,
		"ammo_type": "thunderbolt_ammo",
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
	
	"case2": {
		"id": "case2",
		"name": "CASE II",
		"type": ComponentType.EQUIPMENT_ARMOR,
		"weight": 1.0,
		"slots": 1,
		"tech_base": "IS",
		"description": "CASE mejorado - elimina daño por explosión de munición"
	},
	
	# ========== SISTEMAS DE TARGETING ==========
	"artemis_iv": {
		"id": "artemis_iv",
		"name": "Artemis IV FCS",
		"type": ComponentType.EQUIPMENT_TARGETING,
		"weight": 1.0,
		"slots": 1,
		"to_hit_bonus": -1,
		"tech_base": "IS",
		"description": "Fire Control System - mejora misiles +1 cluster"
	},
	
	"artemis_v": {
		"id": "artemis_v",
		"name": "Artemis V FCS",
		"type": ComponentType.EQUIPMENT_TARGETING,
		"weight": 1.0,
		"slots": 1,
		"to_hit_bonus": -2,
		"tech_base": "Clan",
		"description": "FCS Clan mejorado - +2 cluster, -1 to-hit"
	},
	
	"targeting_computer": {
		"id": "targeting_computer",
		"name": "Targeting Computer",
		"type": ComponentType.EQUIPMENT_TARGETING,
		"weight": 1.0,
		"slots": 1,
		"to_hit_bonus": -1,
		"tech_base": "IS",
		"description": "Mejora armas directas -1 to-hit"
	},
	
	# ========== SENSORES AVANZADOS ==========
	"active_probe": {
		"id": "active_probe",
		"name": "Active Probe",
		"type": ComponentType.EQUIPMENT_SENSOR,
		"weight": 1.0,
		"slots": 1,
		"sensor_range": 3,
		"tech_base": "IS",
		"description": "Sensor activo básico"
	},
	
	"bloodhound_probe": {
		"id": "bloodhound_probe",
		"name": "Bloodhound Active Probe",
		"type": ComponentType.EQUIPMENT_SENSOR,
		"weight": 2.0,
		"slots": 3,
		"sensor_range": 8,
		"tech_base": "IS",
		"description": "Sensor activo de largo alcance"
	},
	
	"light_active_probe": {
		"id": "light_active_probe",
		"name": "Light Active Probe",
		"type": ComponentType.EQUIPMENT_SENSOR,
		"weight": 0.5,
		"slots": 1,
		"sensor_range": 2,
		"tech_base": "IS",
		"description": "Sensor activo ligero"
	},
	
	"light_tag": {
		"id": "light_tag",
		"name": "Light TAG",
		"type": ComponentType.EQUIPMENT_TARGETING,
		"weight": 0.5,
		"slots": 1,
		"range": 9,
		"tech_base": "IS",
		"description": "Designador de artillería ligero"
	},
	
	"c3_master": {
		"id": "c3_master",
		"name": "C3 Master Computer",
		"type": ComponentType.EQUIPMENT_SENSOR,
		"weight": 5.0,
		"slots": 5,
		"tech_base": "IS",
		"description": "Red de combate C3 - maestro"
	},
	
	"c3_slave": {
		"id": "c3_slave",
		"name": "C3 Slave Unit",
		"type": ComponentType.EQUIPMENT_SENSOR,
		"weight": 1.0,
		"slots": 1,
		"tech_base": "IS",
		"description": "Red de combate C3 - esclavo"
	},
	
	"c3i": {
		"id": "c3i",
		"name": "C3i Computer",
		"type": ComponentType.EQUIPMENT_SENSOR,
		"weight": 2.5,
		"slots": 2,
		"tech_base": "IS",
		"description": "Red de combate C3 mejorada"
	},
	
	# ========== ESTRUCTURAS INTERNAS ==========
	"endo_steel": {
		"id": "endo_steel",
		"name": "Endo-Steel Structure",
		"type": ComponentType.STRUCTURE,
		"weight_savings_percent": 50,
		"slots": 14,
		"tech_base": "IS",
		"description": "Estructura interna ligera - ahorra 50% peso"
	},
	
	"endo_steel_clan": {
		"id": "endo_steel_clan",
		"name": "Endo-Steel Structure (Clan)",
		"type": ComponentType.STRUCTURE,
		"weight_savings_percent": 50,
		"slots": 7,
		"tech_base": "Clan",
		"description": "Estructura Endo-Steel Clan - menos slots"
	},
	
	"composite_structure": {
		"id": "composite_structure",
		"name": "Composite Structure",
		"type": ComponentType.STRUCTURE,
		"weight_savings_percent": 50,
		"slots": 0,
		"armor_penalty": true,
		"tech_base": "IS",
		"description": "Estructura compuesta - sin slots extras pero penaliza armadura"
	},
	
	"reinforced_structure": {
		"id": "reinforced_structure",
		"name": "Reinforced Structure",
		"type": ComponentType.STRUCTURE,
		"weight_penalty_percent": 100,
		"armor_bonus_percent": 100,
		"slots": 0,
		"tech_base": "IS",
		"description": "Estructura reforzada - doble peso pero doble resistencia"
	},
	
	# ========== BLINDAJES ==========
	"ferro_fibrous": {
		"id": "ferro_fibrous",
		"name": "Ferro-Fibrous Armor",
		"type": ComponentType.EQUIPMENT_ARMOR,
		"armor_bonus_percent": 12,
		"slots": 14,
		"tech_base": "IS",
		"description": "Blindaje ligero - +12% protección"
	},
	
	"ferro_fibrous_clan": {
		"id": "ferro_fibrous_clan",
		"name": "Ferro-Fibrous Armor (Clan)",
		"type": ComponentType.EQUIPMENT_ARMOR,
		"armor_bonus_percent": 20,
		"slots": 7,
		"tech_base": "Clan",
		"description": "Blindaje FF Clan - +20% protección"
	},
	
	"light_ferro_fibrous": {
		"id": "light_ferro_fibrous",
		"name": "Light Ferro-Fibrous Armor",
		"type": ComponentType.EQUIPMENT_ARMOR,
		"armor_bonus_percent": 15,
		"slots": 7,
		"tech_base": "IS",
		"description": "Blindaje FF ligero - +15% protección"
	},
	
	"heavy_ferro_fibrous": {
		"id": "heavy_ferro_fibrous",
		"name": "Heavy Ferro-Fibrous Armor",
		"type": ComponentType.EQUIPMENT_ARMOR,
		"armor_bonus_percent": 24,
		"slots": 21,
		"tech_base": "IS",
		"description": "Blindaje FF pesado - +24% protección"
	},
	
	"hardened_armor": {
		"id": "hardened_armor",
		"name": "Hardened Armor",
		"type": ComponentType.EQUIPMENT_ARMOR,
		"weight_penalty_percent": 100,
		"damage_reduction": 2,
		"slots": 0,
		"tech_base": "IS",
		"description": "Blindaje endurecido - reduce daño recibido"
	},
	
	"reactive_armor": {
		"id": "reactive_armor",
		"name": "Reactive Armor",
		"type": ComponentType.EQUIPMENT_ARMOR,
		"weight": 1.0,
		"slots": 1,
		"one_shot_protection": 10,
		"tech_base": "IS",
		"description": "Blindaje reactivo - protección única vs misiles"
	},
	
	"reflective_armor": {
		"id": "reflective_armor",
		"name": "Reflective Armor",
		"type": ComponentType.EQUIPMENT_ARMOR,
		"weight": 1.0,
		"slots": 10,
		"laser_protection": 2,
		"tech_base": "IS",
		"description": "Blindaje reflectivo - reduce daño láser"
	},
	
	"stealth_armor": {
		"id": "stealth_armor",
		"name": "Stealth Armor",
		"type": ComponentType.EQUIPMENT_ARMOR,
		"weight": 1.0,
		"slots": 12,
		"ecm_bonus": true,
		"heat_penalty": 10,
		"tech_base": "IS",
		"description": "Blindaje stealth - ECM integrado pero genera calor"
	},
	
	# ========== MOTORES ==========
	"xl_engine": {
		"id": "xl_engine",
		"name": "XL Engine",
		"type": ComponentType.ENGINE,
		"weight_savings_percent": 50,
		"side_torso_critical": true,
		"tech_base": "IS",
		"description": "Motor extraligero - ahorra 50% pero vulnerable"
	},
	
	"light_engine": {
		"id": "light_engine",
		"name": "Light Engine",
		"type": ComponentType.ENGINE,
		"weight_savings_percent": 25,
		"side_torso_critical": true,
		"tech_base": "IS",
		"description": "Motor ligero - ahorra 25%, menos vulnerable que XL"
	},
	
	"compact_engine": {
		"id": "compact_engine",
		"name": "Compact Engine",
		"type": ComponentType.ENGINE,
		"weight_penalty_percent": 50,
		"slots_savings": 3,
		"tech_base": "IS",
		"description": "Motor compacto - más pesado pero ahorra slots"
	},
	
	# ========== GYROSCOPES ==========
	"xl_gyro": {
		"id": "xl_gyro",
		"name": "XL Gyroscope",
		"type": ComponentType.GYROSCOPE,
		"weight_savings_percent": 50,
		"slots": 6,
		"tech_base": "IS",
		"description": "Gyro extraligero - ahorra peso"
	},
	
	"compact_gyro": {
		"id": "compact_gyro",
		"name": "Compact Gyroscope",
		"type": ComponentType.GYROSCOPE,
		"weight_penalty_percent": 50,
		"slots": 2,
		"tech_base": "IS",
		"description": "Gyro compacto - ahorra slots"
	},
	
	# ========== HEATSINKS AVANZADOS ==========
	"compact_heat_sink": {
		"id": "compact_heat_sink",
		"name": "Compact Heat Sink",
		"type": ComponentType.EQUIPMENT_HEATSINK,
		"weight": 1.0,
		"slots": 1,
		"heat_dissipation": 1,
		"tech_base": "IS",
		"description": "Heatsink compacto - 1 slot siempre"
	},
	
	"laser_heat_sink": {
		"id": "laser_heat_sink",
		"name": "Laser Heat Sink",
		"type": ComponentType.EQUIPMENT_HEATSINK,
		"weight": 1.0,
		"slots": 2,
		"heat_dissipation": 2,
		"tech_base": "Clan",
		"description": "Heatsink Clan para láseres"
	},
	
	# ========== JUMP JETS AVANZADOS ==========
	"improved_jump_jet": {
		"id": "improved_jump_jet",
		"name": "Improved Jump Jet",
		"type": ComponentType.EQUIPMENT_JUMPJET,
		"weight": 0.0,
		"slots": 2,
		"jump_bonus_percent": 50,
		"tech_base": "IS",
		"description": "Jump jet mejorado - +50% distancia"
	},
	
	# ========== SISTEMAS ESPECIALES ==========
	"masc": {
		"id": "masc",
		"name": "MASC",
		"type": ComponentType.EQUIPMENT_SPECIAL,
		"weight_percent_of_engine": 5,
		"slots": 1,
		"speed_bonus_percent": 50,
		"tech_base": "IS",
		"description": "Myomer Accelerator Signal Circuitry - sprint +50%"
	},
	
	"supercharger": {
		"id": "supercharger",
		"name": "Supercharger",
		"type": ComponentType.EQUIPMENT_SPECIAL,
		"weight_percent_of_engine": 10,
		"slots": 1,
		"speed_bonus_percent": 20,
		"tech_base": "IS",
		"description": "Supercargador - +20% velocidad continuo"
	},
	
	"tsm": {
		"id": "tsm",
		"name": "TSM",
		"type": ComponentType.EQUIPMENT_SPECIAL,
		"weight_percent_of_structure": 100,
		"slots": 0,
		"strength_bonus": 2,
		"speed_bonus_when_hot": 1,
		"tech_base": "IS",
		"description": "Triple-Strength Myomer - bonus cuando caliente"
	},
	
	"partial_wing": {
		"id": "partial_wing",
		"name": "Partial Wing",
		"type": ComponentType.EQUIPMENT_SPECIAL,
		"weight": 2.0,
		"slots": 6,
		"jump_bonus": 3,
		"tech_base": "IS",
		"description": "Ala parcial - mejora saltos"
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
