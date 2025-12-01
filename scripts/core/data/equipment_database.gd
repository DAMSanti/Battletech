# equipment_database.gd
# Database containing all equipment definitions for BattleTech
# Part of Phase 4 SOLID refactoring - extracted from component_database.gd
class_name EquipmentDatabase
extends RefCounted

# Component type reference
const CT = preload("res://scripts/core/data/component_types.gd")

# ========== EQUIPMENT DATABASE ==========
static var database = {
	# ========== HEAT SINKS ==========
	"heat_sink": {
		"id": "heat_sink",
		"name": "Heat Sink",
		"type": CT.ComponentType.EQUIPMENT_HEATSINK,
		"weight": 1.0,
		"slots": 1,
		"heat_dissipation": 1,
		"tech_base": "IS",
		"description": "Disipa 1 punto de calor por turno"
	},
	
	"double_heat_sink": {
		"id": "double_heat_sink",
		"name": "Double Heat Sink",
		"type": CT.ComponentType.EQUIPMENT_HEATSINK,
		"weight": 1.0,
		"slots": 3,  # En engine slots: 1, en otros: 3
		"heat_dissipation": 2,
		"tech_base": "IS",
		"description": "Disipa 2 puntos de calor por turno"
	},
	
	"compact_heat_sink": {
		"id": "compact_heat_sink",
		"name": "Compact Heat Sink",
		"type": CT.ComponentType.EQUIPMENT_HEATSINK,
		"weight": 1.0,
		"slots": 1,
		"heat_dissipation": 1,
		"tech_base": "IS",
		"description": "Heatsink compacto - 1 slot siempre"
	},
	
	"laser_heat_sink": {
		"id": "laser_heat_sink",
		"name": "Laser Heat Sink",
		"type": CT.ComponentType.EQUIPMENT_HEATSINK,
		"weight": 1.0,
		"slots": 2,
		"heat_dissipation": 2,
		"tech_base": "Clan",
		"description": "Heatsink Clan para láseres"
	},
	
	# ========== JUMP JETS ==========
	"jump_jet": {
		"id": "jump_jet",
		"name": "Jump Jet",
		"type": CT.ComponentType.EQUIPMENT_JUMPJET,
		"weight": 0.0,  # Varía según tonnage del mech
		"slots": 1,
		"tech_base": "IS",
		"description": "Permite saltar 1 hex por jet"
	},
	
	"improved_jump_jet": {
		"id": "improved_jump_jet",
		"name": "Improved Jump Jet",
		"type": CT.ComponentType.EQUIPMENT_JUMPJET,
		"weight": 0.0,
		"slots": 2,
		"jump_bonus_percent": 50,
		"tech_base": "IS",
		"description": "Jump jet mejorado - +50% distancia"
	},
	
	# ========== ECM & SENSORS ==========
	"ecm_suite": {
		"id": "ecm_suite",
		"name": "Guardian ECM Suite",
		"type": CT.ComponentType.EQUIPMENT_ECM,
		"weight": 1.5,
		"slots": 2,
		"ecm_range": 6,  # Hexágonos
		"tech_base": "IS",
		"description": "ECM: +1 to-hit para armas de misiles dentro de 6 hexes. BAP enemigo lo niega."
	},
	
	"beagle_probe": {
		"id": "beagle_probe",
		"name": "Beagle Active Probe",
		"type": CT.ComponentType.EQUIPMENT_SENSOR,
		"weight": 1.5,
		"slots": 2,
		"sensor_range": 4,  # Hexágonos extra
		"tech_base": "IS",
		"description": "BAP: Niega efectos de ECM enemigo. Mejora targeting (+1 a corto alcance)."
	},
	
	"active_probe": {
		"id": "active_probe",
		"name": "Active Probe",
		"type": CT.ComponentType.EQUIPMENT_SENSOR,
		"weight": 1.0,
		"slots": 1,
		"sensor_range": 3,
		"tech_base": "IS",
		"description": "Sensor activo básico"
	},
	
	"bloodhound_probe": {
		"id": "bloodhound_probe",
		"name": "Bloodhound Active Probe",
		"type": CT.ComponentType.EQUIPMENT_SENSOR,
		"weight": 2.0,
		"slots": 3,
		"sensor_range": 8,
		"tech_base": "IS",
		"description": "Sensor activo de largo alcance"
	},
	
	"light_active_probe": {
		"id": "light_active_probe",
		"name": "Light Active Probe",
		"type": CT.ComponentType.EQUIPMENT_SENSOR,
		"weight": 0.5,
		"slots": 1,
		"sensor_range": 2,
		"tech_base": "IS",
		"description": "Sensor activo ligero"
	},
	
	# ========== C3 SYSTEMS ==========
	"c3_master": {
		"id": "c3_master",
		"name": "C3 Master Computer",
		"type": CT.ComponentType.EQUIPMENT_SENSOR,
		"weight": 5.0,
		"slots": 5,
		"tech_base": "IS",
		"description": "Red de combate C3 - maestro"
	},
	
	"c3_slave": {
		"id": "c3_slave",
		"name": "C3 Slave Unit",
		"type": CT.ComponentType.EQUIPMENT_SENSOR,
		"weight": 1.0,
		"slots": 1,
		"tech_base": "IS",
		"description": "Red de combate C3 - esclavo"
	},
	
	"c3i": {
		"id": "c3i",
		"name": "C3i Computer",
		"type": CT.ComponentType.EQUIPMENT_SENSOR,
		"weight": 2.5,
		"slots": 2,
		"tech_base": "IS",
		"description": "Red de combate C3 mejorada"
	},
	
	# ========== TARGETING SYSTEMS ==========
	"artemis_iv": {
		"id": "artemis_iv",
		"name": "Artemis IV FCS",
		"type": CT.ComponentType.EQUIPMENT_TARGETING,
		"weight": 1.0,
		"slots": 1,
		"to_hit_bonus": -1,
		"tech_base": "IS",
		"description": "Fire Control System - mejora misiles +1 cluster"
	},
	
	"artemis_v": {
		"id": "artemis_v",
		"name": "Artemis V FCS",
		"type": CT.ComponentType.EQUIPMENT_TARGETING,
		"weight": 1.0,
		"slots": 1,
		"to_hit_bonus": -2,
		"tech_base": "Clan",
		"description": "FCS Clan mejorado - +2 cluster, -1 to-hit"
	},
	
	"targeting_computer": {
		"id": "targeting_computer",
		"name": "Targeting Computer",
		"type": CT.ComponentType.EQUIPMENT_TARGETING,
		"weight": 1.0,
		"slots": 1,
		"to_hit_bonus": -1,
		"tech_base": "IS",
		"description": "Mejora armas directas -1 to-hit"
	},
	
	"light_tag": {
		"id": "light_tag",
		"name": "Light TAG",
		"type": CT.ComponentType.EQUIPMENT_TARGETING,
		"weight": 0.5,
		"slots": 1,
		"range": 9,
		"tech_base": "IS",
		"description": "Designador de artillería ligero"
	},
	
	# ========== CASE / PROTECTIVE ==========
	"case": {
		"id": "case",
		"name": "CASE",
		"type": CT.ComponentType.EQUIPMENT_ARMOR,
		"weight": 0.5,
		"slots": 1,
		"tech_base": "IS",
		"description": "Cellular Ammunition Storage Equipment - Previene explosión de munición"
	},
	
	"case2": {
		"id": "case2",
		"name": "CASE II",
		"type": CT.ComponentType.EQUIPMENT_ARMOR,
		"weight": 1.0,
		"slots": 1,
		"tech_base": "IS",
		"description": "CASE mejorado - elimina daño por explosión de munición"
	},
	
	# ========== INTERNAL STRUCTURES ==========
	"endo_steel": {
		"id": "endo_steel",
		"name": "Endo-Steel Structure",
		"type": CT.ComponentType.STRUCTURE,
		"weight_savings_percent": 50,
		"slots": 14,
		"tech_base": "IS",
		"description": "Estructura interna ligera - ahorra 50% peso"
	},
	
	"endo_steel_clan": {
		"id": "endo_steel_clan",
		"name": "Endo-Steel Structure (Clan)",
		"type": CT.ComponentType.STRUCTURE,
		"weight_savings_percent": 50,
		"slots": 7,
		"tech_base": "Clan",
		"description": "Estructura Endo-Steel Clan - menos slots"
	},
	
	"composite_structure": {
		"id": "composite_structure",
		"name": "Composite Structure",
		"type": CT.ComponentType.STRUCTURE,
		"weight_savings_percent": 50,
		"slots": 0,
		"armor_penalty": true,
		"tech_base": "IS",
		"description": "Estructura compuesta - sin slots extras pero penaliza armadura"
	},
	
	"reinforced_structure": {
		"id": "reinforced_structure",
		"name": "Reinforced Structure",
		"type": CT.ComponentType.STRUCTURE,
		"weight_penalty_percent": 100,
		"armor_bonus_percent": 100,
		"slots": 0,
		"tech_base": "IS",
		"description": "Estructura reforzada - doble peso pero doble resistencia"
	},
	
	# ========== ARMOR TYPES ==========
	"ferro_fibrous": {
		"id": "ferro_fibrous",
		"name": "Ferro-Fibrous Armor",
		"type": CT.ComponentType.EQUIPMENT_ARMOR,
		"armor_bonus_percent": 12,
		"slots": 14,
		"tech_base": "IS",
		"description": "Blindaje ligero - +12% protección"
	},
	
	"ferro_fibrous_clan": {
		"id": "ferro_fibrous_clan",
		"name": "Ferro-Fibrous Armor (Clan)",
		"type": CT.ComponentType.EQUIPMENT_ARMOR,
		"armor_bonus_percent": 20,
		"slots": 7,
		"tech_base": "Clan",
		"description": "Blindaje FF Clan - +20% protección"
	},
	
	"light_ferro_fibrous": {
		"id": "light_ferro_fibrous",
		"name": "Light Ferro-Fibrous Armor",
		"type": CT.ComponentType.EQUIPMENT_ARMOR,
		"armor_bonus_percent": 15,
		"slots": 7,
		"tech_base": "IS",
		"description": "Blindaje FF ligero - +15% protección"
	},
	
	"heavy_ferro_fibrous": {
		"id": "heavy_ferro_fibrous",
		"name": "Heavy Ferro-Fibrous Armor",
		"type": CT.ComponentType.EQUIPMENT_ARMOR,
		"armor_bonus_percent": 24,
		"slots": 21,
		"tech_base": "IS",
		"description": "Blindaje FF pesado - +24% protección"
	},
	
	"hardened_armor": {
		"id": "hardened_armor",
		"name": "Hardened Armor",
		"type": CT.ComponentType.EQUIPMENT_ARMOR,
		"weight_penalty_percent": 100,
		"damage_reduction": 2,
		"slots": 0,
		"tech_base": "IS",
		"description": "Blindaje endurecido - reduce daño recibido"
	},
	
	"reactive_armor": {
		"id": "reactive_armor",
		"name": "Reactive Armor",
		"type": CT.ComponentType.EQUIPMENT_ARMOR,
		"weight": 1.0,
		"slots": 1,
		"one_shot_protection": 10,
		"tech_base": "IS",
		"description": "Blindaje reactivo - protección única vs misiles"
	},
	
	"reflective_armor": {
		"id": "reflective_armor",
		"name": "Reflective Armor",
		"type": CT.ComponentType.EQUIPMENT_ARMOR,
		"weight": 1.0,
		"slots": 10,
		"laser_protection": 2,
		"tech_base": "IS",
		"description": "Blindaje reflectivo - reduce daño láser"
	},
	
	"stealth_armor": {
		"id": "stealth_armor",
		"name": "Stealth Armor",
		"type": CT.ComponentType.EQUIPMENT_ARMOR,
		"weight": 1.0,
		"slots": 12,
		"ecm_bonus": true,
		"heat_penalty": 10,
		"tech_base": "IS",
		"description": "Blindaje stealth - ECM integrado pero genera calor"
	},
	
	# ========== ENGINES ==========
	"xl_engine": {
		"id": "xl_engine",
		"name": "XL Engine",
		"type": CT.ComponentType.ENGINE,
		"weight_savings_percent": 50,
		"side_torso_critical": true,
		"tech_base": "IS",
		"description": "Motor extraligero - ahorra 50% pero vulnerable"
	},
	
	"light_engine": {
		"id": "light_engine",
		"name": "Light Engine",
		"type": CT.ComponentType.ENGINE,
		"weight_savings_percent": 25,
		"side_torso_critical": true,
		"tech_base": "IS",
		"description": "Motor ligero - ahorra 25%, menos vulnerable que XL"
	},
	
	"compact_engine": {
		"id": "compact_engine",
		"name": "Compact Engine",
		"type": CT.ComponentType.ENGINE,
		"weight_penalty_percent": 50,
		"slots_savings": 3,
		"tech_base": "IS",
		"description": "Motor compacto - más pesado pero ahorra slots"
	},
	
	# ========== GYROSCOPES ==========
	"xl_gyro": {
		"id": "xl_gyro",
		"name": "XL Gyroscope",
		"type": CT.ComponentType.GYROSCOPE,
		"weight_savings_percent": 50,
		"slots": 6,
		"tech_base": "IS",
		"description": "Gyro extraligero - ahorra peso"
	},
	
	"compact_gyro": {
		"id": "compact_gyro",
		"name": "Compact Gyroscope",
		"type": CT.ComponentType.GYROSCOPE,
		"weight_penalty_percent": 50,
		"slots": 2,
		"tech_base": "IS",
		"description": "Gyro compacto - ahorra slots"
	},
	
	# ========== SPECIAL SYSTEMS ==========
	"masc": {
		"id": "masc",
		"name": "MASC",
		"type": CT.ComponentType.EQUIPMENT_SPECIAL,
		"weight_percent_of_engine": 5,
		"slots": 1,
		"speed_bonus_percent": 50,
		"tech_base": "IS",
		"description": "Myomer Accelerator Signal Circuitry - sprint +50%"
	},
	
	"supercharger": {
		"id": "supercharger",
		"name": "Supercharger",
		"type": CT.ComponentType.EQUIPMENT_SPECIAL,
		"weight_percent_of_engine": 10,
		"slots": 1,
		"speed_bonus_percent": 20,
		"tech_base": "IS",
		"description": "Supercargador - +20% velocidad continuo"
	},
	
	"tsm": {
		"id": "tsm",
		"name": "TSM",
		"type": CT.ComponentType.EQUIPMENT_SPECIAL,
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
		"type": CT.ComponentType.EQUIPMENT_SPECIAL,
		"weight": 2.0,
		"slots": 6,
		"jump_bonus": 3,
		"tech_base": "IS",
		"description": "Ala parcial - mejora saltos"
	},
}

# ========== HELPER METHODS ==========

## Get equipment data by ID
static func get_equipment(equipment_id: String) -> Dictionary:
	return database.get(equipment_id, {})

## Get all equipment IDs
static func get_all_ids() -> Array:
	return database.keys()

## Check if equipment exists
static func has_equipment(equipment_id: String) -> bool:
	return database.has(equipment_id)

## Get equipment by type
static func get_equipment_by_type(type: int) -> Array:
	var result = []
	for equipment_id in database:
		if database[equipment_id].get("type", -1) == type:
			result.append(database[equipment_id])
	return result

## Get all heat sinks
static func get_heat_sinks() -> Array:
	return get_equipment_by_type(CT.ComponentType.EQUIPMENT_HEATSINK)

## Get all jump jets
static func get_jump_jets() -> Array:
	return get_equipment_by_type(CT.ComponentType.EQUIPMENT_JUMPJET)

## Get all armor types
static func get_armor_types() -> Array:
	return get_equipment_by_type(CT.ComponentType.EQUIPMENT_ARMOR)

## Get all engines
static func get_engines() -> Array:
	return get_equipment_by_type(CT.ComponentType.ENGINE)

## Get all structures
static func get_structures() -> Array:
	return get_equipment_by_type(CT.ComponentType.STRUCTURE)

## Get equipment by tech base
static func get_equipment_by_tech(tech_base: String) -> Array:
	var result = []
	for equipment_id in database:
		if database[equipment_id].get("tech_base", "") == tech_base:
			result.append(database[equipment_id])
	return result
