# component_types.gd
# Enums for BattleTech component types
# Extracted to avoid circular dependencies between database files
class_name ComponentTypes
extends RefCounted

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
