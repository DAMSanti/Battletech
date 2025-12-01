# ammo_database.gd
# Database containing all ammunition definitions for BattleTech
# Part of Phase 4 SOLID refactoring - extracted from component_database.gd
class_name AmmoDatabase
extends RefCounted

# Component type reference
const CT = preload("res://scripts/core/data/component_types.gd")

# ========== AMMUNITION DATABASE ==========
static var database = {
	# ========== STANDARD AMMUNITION ==========
	"ac2_ammo": {
		"id": "ac2_ammo",
		"name": "AC/2 Ammo",
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 120,
		"ammo_type": "lrm_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
	
	# ========== ADVANCED AMMUNITION ==========
	"lb2x_ammo": {
		"id": "lb2x_ammo",
		"name": "LB 2-X Ammo",
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
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
		"type": CT.ComponentType.EQUIPMENT_AMMO,
		"weight": 1.0,
		"slots": 1,
		"shots_per_ton": 4,
		"ammo_type": "thunderbolt_ammo",
		"explosive": true,
		"tech_base": "IS"
	},
}

# ========== HELPER METHODS ==========

## Get ammo data by ID
static func get_ammo(ammo_id: String) -> Dictionary:
	return database.get(ammo_id, {})

## Get all ammunition IDs
static func get_all_ids() -> Array:
	return database.keys()

## Get ammo for a specific weapon type
static func get_ammo_for_weapon(weapon_ammo_type: String) -> Dictionary:
	for ammo_id in database:
		var ammo = database[ammo_id]
		if ammo.get("ammo_type", "") == weapon_ammo_type:
			return ammo
	return {}

## Check if ammo exists
static func has_ammo(ammo_id: String) -> bool:
	return database.has(ammo_id)

## Get all explosive ammunition
static func get_explosive_ammo() -> Array:
	var result = []
	for ammo_id in database:
		if database[ammo_id].get("explosive", false):
			result.append(database[ammo_id])
	return result

## Get shots per ton for ammo type
static func get_shots_per_ton(ammo_id: String) -> int:
	var ammo = database.get(ammo_id, {})
	return ammo.get("shots_per_ton", 0)
