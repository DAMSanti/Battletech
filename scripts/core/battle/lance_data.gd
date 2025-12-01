## LanceData - Configuraciones predefinidas de lances de mechs
## Extraído de battle_scene.gd para mejorar mantenibilidad
class_name LanceData
extends RefCounted

## Retorna la configuración del lance del jugador (4 mechs)
static func get_player_lance() -> Array:
	return [
		{
			"name": "Atlas", "tonnage": 100, "walk_mp": 3, "run_mp": 5, "jump_mp": 0,
			"gunnery_skill": 4, "piloting_skill": 5,
			"heat_capacity": 30, "heat_dissipation": 20,
			"weapons": [
				{"name": "AC/20", "damage": 20, "heat": 7, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "ballistic", "location": "right_torso"},
				{"name": "LRM 20", "damage": 20, "heat": 6, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile", "location": "left_torso"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "left_arm"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "right_arm"},
				{"name": "SRM 6", "damage": 12, "heat": 4, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "missile", "location": "left_torso"}
			],
			"armor": {
				"head": {"current": 9, "max": 9},
				"center_torso": {"current": 47, "max": 47},
				"center_torso_rear": {"current": 14, "max": 14},
				"left_torso": {"current": 32, "max": 32},
				"left_torso_rear": {"current": 10, "max": 10},
				"right_torso": {"current": 32, "max": 32},
				"right_torso_rear": {"current": 10, "max": 10},
				"left_arm": {"current": 34, "max": 34},
				"right_arm": {"current": 34, "max": 34},
				"left_leg": {"current": 41, "max": 41},
				"right_leg": {"current": 41, "max": 41}
			},
			"internal_structure": {
				"head": {"current": 3, "max": 3},
				"center_torso": {"current": 31, "max": 31},
				"left_torso": {"current": 21, "max": 21},
				"right_torso": {"current": 21, "max": 21},
				"left_arm": {"current": 17, "max": 17},
				"right_arm": {"current": 17, "max": 17},
				"left_leg": {"current": 21, "max": 21},
				"right_leg": {"current": 21, "max": 21}
			}
		},
		{
			"name": "Timber Wolf", "tonnage": 75, "walk_mp": 5, "run_mp": 8, "jump_mp": 0,
			"gunnery_skill": 4, "piloting_skill": 5,
			"heat_capacity": 26, "heat_dissipation": 20,
			"weapons": [
				{"name": "ER Large Laser", "damage": 8, "heat": 12, "min_range": 0, "short_range": 8, "medium_range": 15, "long_range": 25, "type": "energy", "location": "left_arm"},
				{"name": "ER Large Laser", "damage": 8, "heat": 12, "min_range": 0, "short_range": 8, "medium_range": 15, "long_range": 25, "type": "energy", "location": "right_arm"},
				{"name": "LRM 20", "damage": 20, "heat": 6, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile", "location": "left_torso"},
				{"name": "LRM 20", "damage": 20, "heat": 6, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile", "location": "right_torso"},
				{"name": "Medium Pulse Laser", "damage": 6, "heat": 4, "min_range": 0, "short_range": 2, "medium_range": 4, "long_range": 6, "type": "energy", "location": "center_torso"},
				{"name": "Medium Pulse Laser", "damage": 6, "heat": 4, "min_range": 0, "short_range": 2, "medium_range": 4, "long_range": 6, "type": "energy", "location": "center_torso"}
			],
			"armor": {
				"head": {"current": 9, "max": 9},
				"center_torso": {"current": 34, "max": 34},
				"center_torso_rear": {"current": 11, "max": 11},
				"left_torso": {"current": 25, "max": 25},
				"left_torso_rear": {"current": 8, "max": 8},
				"right_torso": {"current": 25, "max": 25},
				"right_torso_rear": {"current": 8, "max": 8},
				"left_arm": {"current": 24, "max": 24},
				"right_arm": {"current": 24, "max": 24},
				"left_leg": {"current": 32, "max": 32},
				"right_leg": {"current": 32, "max": 32}
			},
			"internal_structure": {
				"head": {"current": 3, "max": 3},
				"center_torso": {"current": 23, "max": 23},
				"left_torso": {"current": 16, "max": 16},
				"right_torso": {"current": 16, "max": 16},
				"left_arm": {"current": 12, "max": 12},
				"right_arm": {"current": 12, "max": 12},
				"left_leg": {"current": 16, "max": 16},
				"right_leg": {"current": 16, "max": 16}
			}
		},
		{
			"name": "Hunchback", "tonnage": 50, "walk_mp": 4, "run_mp": 6, "jump_mp": 0,
			"gunnery_skill": 4, "piloting_skill": 5,
			"heat_capacity": 13, "heat_dissipation": 10,
			"weapons": [
				{"name": "AC/20", "damage": 20, "heat": 7, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "ballistic", "location": "right_torso"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "left_arm"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "right_arm"},
				{"name": "Small Laser", "damage": 3, "heat": 1, "min_range": 0, "short_range": 1, "medium_range": 2, "long_range": 3, "type": "energy", "location": "head"}
			],
			"armor": {
				"head": {"current": 9, "max": 9},
				"center_torso": {"current": 21, "max": 21},
				"center_torso_rear": {"current": 7, "max": 7},
				"left_torso": {"current": 16, "max": 16},
				"left_torso_rear": {"current": 6, "max": 6},
				"right_torso": {"current": 16, "max": 16},
				"right_torso_rear": {"current": 6, "max": 6},
				"left_arm": {"current": 16, "max": 16},
				"right_arm": {"current": 16, "max": 16},
				"left_leg": {"current": 20, "max": 20},
				"right_leg": {"current": 20, "max": 20}
			},
			"internal_structure": {
				"head": {"current": 3, "max": 3},
				"center_torso": {"current": 16, "max": 16},
				"left_torso": {"current": 12, "max": 12},
				"right_torso": {"current": 12, "max": 12},
				"left_arm": {"current": 8, "max": 8},
				"right_arm": {"current": 8, "max": 8},
				"left_leg": {"current": 12, "max": 12},
				"right_leg": {"current": 12, "max": 12}
			}
		},
		{
			"name": "Jenner", "tonnage": 35, "walk_mp": 7, "run_mp": 11, "jump_mp": 5,
			"gunnery_skill": 4, "piloting_skill": 5,
			"heat_capacity": 10, "heat_dissipation": 10,
			"weapons": [
				{"name": "SRM 4", "damage": 8, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "missile", "location": "center_torso"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "left_arm"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "right_arm"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "right_arm"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "left_arm"}
			],
			"armor": {
				"head": {"current": 9, "max": 9},
				"center_torso": {"current": 16, "max": 16},
				"center_torso_rear": {"current": 5, "max": 5},
				"left_torso": {"current": 12, "max": 12},
				"left_torso_rear": {"current": 4, "max": 4},
				"right_torso": {"current": 12, "max": 12},
				"right_torso_rear": {"current": 4, "max": 4},
				"left_arm": {"current": 11, "max": 11},
				"right_arm": {"current": 11, "max": 11},
				"left_leg": {"current": 15, "max": 15},
				"right_leg": {"current": 15, "max": 15}
			},
			"internal_structure": {
				"head": {"current": 3, "max": 3},
				"center_torso": {"current": 11, "max": 11},
				"left_torso": {"current": 8, "max": 8},
				"right_torso": {"current": 8, "max": 8},
				"left_arm": {"current": 6, "max": 6},
				"right_arm": {"current": 6, "max": 6},
				"left_leg": {"current": 8, "max": 8},
				"right_leg": {"current": 8, "max": 8}
			}
		}
	]


## Retorna la configuración del lance enemigo (4 mechs)
static func get_enemy_lance() -> Array:
	return [
		{
			"name": "Daishi", "tonnage": 100, "walk_mp": 3, "run_mp": 5, "jump_mp": 0,
			"gunnery_skill": 4, "piloting_skill": 5,
			"heat_capacity": 30, "heat_dissipation": 20,
			"weapons": [
				{"name": "ER PPC", "damage": 10, "heat": 15, "min_range": 0, "short_range": 7, "medium_range": 14, "long_range": 23, "type": "energy", "location": "right_arm"},
				{"name": "ER PPC", "damage": 10, "heat": 15, "min_range": 0, "short_range": 7, "medium_range": 14, "long_range": 23, "type": "energy", "location": "left_arm"},
				{"name": "LRM 10", "damage": 10, "heat": 4, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile", "location": "left_torso"},
				{"name": "LRM 10", "damage": 10, "heat": 4, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile", "location": "right_torso"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "center_torso"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "center_torso"}
			],
			"armor": {
				"head": {"current": 9, "max": 9},
				"center_torso": {"current": 50, "max": 50},
				"center_torso_rear": {"current": 16, "max": 16},
				"left_torso": {"current": 35, "max": 35},
				"left_torso_rear": {"current": 12, "max": 12},
				"right_torso": {"current": 35, "max": 35},
				"right_torso_rear": {"current": 12, "max": 12},
				"left_arm": {"current": 34, "max": 34},
				"right_arm": {"current": 34, "max": 34},
				"left_leg": {"current": 42, "max": 42},
				"right_leg": {"current": 42, "max": 42}
			},
			"internal_structure": {
				"head": {"current": 3, "max": 3},
				"center_torso": {"current": 31, "max": 31},
				"left_torso": {"current": 21, "max": 21},
				"right_torso": {"current": 21, "max": 21},
				"left_arm": {"current": 17, "max": 17},
				"right_arm": {"current": 17, "max": 17},
				"left_leg": {"current": 21, "max": 21},
				"right_leg": {"current": 21, "max": 21}
			}
		},
		{
			"name": "Mad Cat", "tonnage": 75, "walk_mp": 5, "run_mp": 8, "jump_mp": 0,
			"gunnery_skill": 4, "piloting_skill": 5,
			"heat_capacity": 26, "heat_dissipation": 20,
			"weapons": [
				{"name": "ER Large Laser", "damage": 8, "heat": 12, "min_range": 0, "short_range": 8, "medium_range": 15, "long_range": 25, "type": "energy", "location": "left_arm"},
				{"name": "ER Large Laser", "damage": 8, "heat": 12, "min_range": 0, "short_range": 8, "medium_range": 15, "long_range": 25, "type": "energy", "location": "right_arm"},
				{"name": "LRM 20", "damage": 20, "heat": 6, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile", "location": "left_torso"},
				{"name": "LRM 20", "damage": 20, "heat": 6, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile", "location": "right_torso"},
				{"name": "Medium Pulse Laser", "damage": 6, "heat": 4, "min_range": 0, "short_range": 2, "medium_range": 4, "long_range": 6, "type": "energy", "location": "center_torso"},
				{"name": "Medium Pulse Laser", "damage": 6, "heat": 4, "min_range": 0, "short_range": 2, "medium_range": 4, "long_range": 6, "type": "energy", "location": "center_torso"}
			],
			"armor": {
				"head": {"current": 9, "max": 9},
				"center_torso": {"current": 34, "max": 34},
				"center_torso_rear": {"current": 11, "max": 11},
				"left_torso": {"current": 25, "max": 25},
				"left_torso_rear": {"current": 8, "max": 8},
				"right_torso": {"current": 25, "max": 25},
				"right_torso_rear": {"current": 8, "max": 8},
				"left_arm": {"current": 24, "max": 24},
				"right_arm": {"current": 24, "max": 24},
				"left_leg": {"current": 32, "max": 32},
				"right_leg": {"current": 32, "max": 32}
			},
			"internal_structure": {
				"head": {"current": 3, "max": 3},
				"center_torso": {"current": 23, "max": 23},
				"left_torso": {"current": 16, "max": 16},
				"right_torso": {"current": 16, "max": 16},
				"left_arm": {"current": 12, "max": 12},
				"right_arm": {"current": 12, "max": 12},
				"left_leg": {"current": 16, "max": 16},
				"right_leg": {"current": 16, "max": 16}
			}
		},
		{
			"name": "Catapult", "tonnage": 65, "walk_mp": 4, "run_mp": 6, "jump_mp": 4,
			"gunnery_skill": 4, "piloting_skill": 5,
			"heat_capacity": 20, "heat_dissipation": 16,
			"weapons": [
				{"name": "LRM 15", "damage": 15, "heat": 5, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile", "location": "left_arm"},
				{"name": "LRM 15", "damage": 15, "heat": 5, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile", "location": "right_arm"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "center_torso"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "center_torso"}
			],
			"armor": {
				"head": {"current": 9, "max": 9},
				"center_torso": {"current": 31, "max": 31},
				"center_torso_rear": {"current": 10, "max": 10},
				"left_torso": {"current": 24, "max": 24},
				"left_torso_rear": {"current": 6, "max": 6},
				"right_torso": {"current": 24, "max": 24},
				"right_torso_rear": {"current": 6, "max": 6},
				"left_arm": {"current": 20, "max": 20},
				"right_arm": {"current": 20, "max": 20},
				"left_leg": {"current": 30, "max": 30},
				"right_leg": {"current": 30, "max": 30}
			},
			"internal_structure": {
				"head": {"current": 3, "max": 3},
				"center_torso": {"current": 21, "max": 21},
				"left_torso": {"current": 15, "max": 15},
				"right_torso": {"current": 15, "max": 15},
				"left_arm": {"current": 10, "max": 10},
				"right_arm": {"current": 10, "max": 10},
				"left_leg": {"current": 15, "max": 15},
				"right_leg": {"current": 15, "max": 15}
			}
		},
		{
			"name": "Kit Fox", "tonnage": 30, "walk_mp": 8, "run_mp": 12, "jump_mp": 0,
			"gunnery_skill": 4, "piloting_skill": 5,
			"heat_capacity": 12, "heat_dissipation": 10,
			"weapons": [
				{"name": "ER Large Laser", "damage": 8, "heat": 12, "min_range": 0, "short_range": 8, "medium_range": 15, "long_range": 25, "type": "energy", "location": "right_arm"},
				{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy", "location": "left_arm"},
				{"name": "Machine Gun", "damage": 2, "heat": 0, "min_range": 0, "short_range": 1, "medium_range": 2, "long_range": 3, "type": "ballistic", "location": "left_torso"},
				{"name": "Machine Gun", "damage": 2, "heat": 0, "min_range": 0, "short_range": 1, "medium_range": 2, "long_range": 3, "type": "ballistic", "location": "right_torso"}
			],
			"armor": {
				"head": {"current": 9, "max": 9},
				"center_torso": {"current": 14, "max": 14},
				"center_torso_rear": {"current": 4, "max": 4},
				"left_torso": {"current": 11, "max": 11},
				"left_torso_rear": {"current": 3, "max": 3},
				"right_torso": {"current": 11, "max": 11},
				"right_torso_rear": {"current": 3, "max": 3},
				"left_arm": {"current": 10, "max": 10},
				"right_arm": {"current": 10, "max": 10},
				"left_leg": {"current": 13, "max": 13},
				"right_leg": {"current": 13, "max": 13}
			},
			"internal_structure": {
				"head": {"current": 3, "max": 3},
				"center_torso": {"current": 10, "max": 10},
				"left_torso": {"current": 7, "max": 7},
				"right_torso": {"current": 7, "max": 7},
				"left_arm": {"current": 5, "max": 5},
				"right_arm": {"current": 5, "max": 5},
				"left_leg": {"current": 7, "max": 7},
				"right_leg": {"current": 7, "max": 7}
			}
		}
	]


# ============================================================
# MÉTODOS HELPER PARA CARGA DE LANCES
# ============================================================

## Carga el lance del jugador con customizaciones opcionales
## Usa loadout personalizado si está disponible, luego MechBayManager
static func load_player_lance_data(loadout_manager, mech_bay_manager, mech_factory) -> Array:
	var player_mechs_data: Array = []
	var lance_configs = get_player_lance()
	
	if loadout_manager and loadout_manager.has_loadout():
		# Si hay loadout personalizado, usar ese para el primer mech
		var loadout = loadout_manager.get_selected_loadout()
		var player_mech_data = mech_factory.convert_loadout_to_mech_data(loadout)
		player_mechs_data.append(player_mech_data)
		
		# Añadir los 3 mechs restantes del lance predefinido
		for i in range(1, 4):
			player_mechs_data.append(_get_mech_data_from_config(lance_configs[i], mech_bay_manager))
	else:
		# Usar todo el lance predefinido
		for config in lance_configs:
			player_mechs_data.append(_get_mech_data_from_config(config, mech_bay_manager))
	
	return player_mechs_data


## Carga el lance enemigo
static func load_enemy_lance_data(mech_bay_manager) -> Array:
	var enemy_mechs_data: Array = []
	var lance_configs = get_enemy_lance()
	
	for config in lance_configs:
		enemy_mechs_data.append(_get_mech_data_from_config(config, mech_bay_manager))
	
	return enemy_mechs_data


## Obtiene datos de mech desde MechBayManager o usa fallback
static func _get_mech_data_from_config(config: Dictionary, mech_bay_manager) -> Dictionary:
	if mech_bay_manager:
		var mech_data = mech_bay_manager.get_mech_data(config["name"], "")
		if mech_data:
			return mech_data
	return config
