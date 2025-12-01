# component_database.gd
# Main component database facade for BattleTech Total Warfare
# Refactored to use separate data files for weapons, ammo, and equipment
# Phase 4 SOLID refactoring - reduced from 2086 lines
extends Node
class_name ComponentDatabase

# Import component types
const CT = preload("res://scripts/core/data/component_types.gd")

# Re-export enums for backwards compatibility
const ComponentType = CT.ComponentType
const WeaponCategory = CT.WeaponCategory

# Import data databases
const WeaponsDB = preload("res://scripts/core/data/weapons_database.gd")
const AmmoDBClass = preload("res://scripts/core/data/ammo_database.gd")
const EquipmentDB = preload("res://scripts/core/data/equipment_database.gd")

# ========== STATIC DATA ACCESSORS ==========
# These provide backwards-compatible access to the databases

static var weapons_database: Dictionary:
	get:
		return WeaponsDB.database

static var ammo_database: Dictionary:
	get:
		return AmmoDBClass.database

static var equipment_database: Dictionary:
	get:
		return EquipmentDB.database

# ========== WEAPON QUERY FUNCTIONS ==========

static func get_weapon(weapon_id: String) -> Dictionary:
	return WeaponsDB.get_weapon(weapon_id)

static func get_all_weapons() -> Array:
	return WeaponsDB.get_all()

static func get_weapons_by_category(category: WeaponCategory) -> Array:
	return WeaponsDB.get_by_category(category)

static func has_weapon(weapon_id: String) -> bool:
	return WeaponsDB.has_weapon(weapon_id)

# ========== AMMO QUERY FUNCTIONS ==========

static func get_ammo(ammo_id: String) -> Dictionary:
	return AmmoDBClass.get_ammo(ammo_id)

static func get_all_ammo() -> Array:
	var result = []
	for ammo_id in AmmoDBClass.database.keys():
		result.append(AmmoDBClass.database[ammo_id].duplicate(true))
	return result

static func get_ammo_for_weapon(weapon_ammo_type: String) -> Dictionary:
	return AmmoDBClass.get_ammo_for_weapon(weapon_ammo_type)

static func has_ammo(ammo_id: String) -> bool:
	return AmmoDBClass.has_ammo(ammo_id)

static func get_shots_per_ton(ammo_id: String) -> int:
	return AmmoDBClass.get_shots_per_ton(ammo_id)

# ========== EQUIPMENT QUERY FUNCTIONS ==========

static func get_equipment(equipment_id: String) -> Dictionary:
	return EquipmentDB.get_equipment(equipment_id)

static func get_all_equipment() -> Array:
	var result = []
	for equip_id in EquipmentDB.database.keys():
		result.append(EquipmentDB.database[equip_id].duplicate(true))
	return result

static func has_equipment(equipment_id: String) -> bool:
	return EquipmentDB.has_equipment(equipment_id)

static func get_equipment_by_type(type: int) -> Array:
	return EquipmentDB.get_equipment_by_type(type)

static func get_heat_sinks() -> Array:
	return EquipmentDB.get_heat_sinks()

static func get_jump_jets() -> Array:
	return EquipmentDB.get_jump_jets()

static func get_armor_types() -> Array:
	return EquipmentDB.get_armor_types()

static func get_engines() -> Array:
	return EquipmentDB.get_engines()

static func get_structures() -> Array:
	return EquipmentDB.get_structures()

# ========== UTILITY FUNCTIONS ==========

## Calculate jump jet weight based on mech tonnage
static func calculate_jump_jet_weight(mech_tonnage: int) -> float:
	if mech_tonnage <= 55:
		return 0.5
	elif mech_tonnage <= 85:
		return 1.0
	else:
		return 2.0

## Check if a mech has an active ECM suite
static func has_ecm_suite(mech) -> bool:
	if not "weapons" in mech:
		return false
	
	for weapon in mech.weapons:
		if weapon.get("id", "") == "ecm_suite":
			# Verify it's not destroyed
			if not weapon.get("destroyed", false):
				return true
	return false

## Check if a mech has an active Beagle Active Probe
static func has_beagle_probe(mech) -> bool:
	if not "weapons" in mech:
		return false
	
	for weapon in mech.weapons:
		if weapon.get("id", "") == "beagle_probe":
			# Verify it's not destroyed
			if not weapon.get("destroyed", false):
				return true
	return false

## Calculate hex distance between two positions
static func hex_distance(pos1: Vector2i, pos2: Vector2i) -> int:
	var dx = abs(pos2.x - pos1.x)
	var dy = abs(pos2.y - pos1.y)
	var dz = abs((pos1.x + pos1.y) - (pos2.x + pos2.y))
	return max(dx, max(dy, dz))

## Check if a mech has CASE in a specific location
static func has_case_in_location(mech, location: String) -> bool:
	if not "weapons" in mech:
		return false
	
	for weapon in mech.weapons:
		if weapon.get("id", "") == "case":
			# Verify it's not destroyed and in the correct location
			if not weapon.get("destroyed", false):
				var weapon_location = weapon.get("location", "")
				if weapon_location == location:
					return true
	return false

## Find explosive ammo in a specific location
static func get_explosive_ammo_in_location(mech, location: String) -> Array:
	var explosive_ammo = []
	
	if not "weapons" in mech:
		return explosive_ammo
	
	for weapon in mech.weapons:
		# Check if it's explosive ammo in that location
		if weapon.get("explosive", false) and not weapon.get("destroyed", false):
			var weapon_location = weapon.get("location", "")
			if weapon_location == location:
				explosive_ammo.append(weapon)
	
	return explosive_ammo

## Get component by ID from any database
static func get_component(component_id: String) -> Dictionary:
	# Try weapons first
	var result = get_weapon(component_id)
	if not result.is_empty():
		return result
	
	# Try ammo
	result = get_ammo(component_id)
	if not result.is_empty():
		return result
	
	# Try equipment
	result = get_equipment(component_id)
	if not result.is_empty():
		return result
	
	return {}

## Check if component exists in any database
static func has_component(component_id: String) -> bool:
	return has_weapon(component_id) or has_ammo(component_id) or has_equipment(component_id)
