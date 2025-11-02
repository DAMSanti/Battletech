extends Node

# Manager para la Mech Bay - gestiona el inventario de mechs y sus configuraciones

signal mech_selected(mech_data: Dictionary)
signal loadout_changed(mech_data: Dictionary)

# Biblioteca de mechs disponibles con sus variantes
var mech_library := {
	"Atlas": {
		"tonnage": 100,
		"variants": {
			"AS7-D": {
				"name": "Atlas AS7-D",
				"walk_mp": 3,
				"run_mp": 5,
				"jump_mp": 0,
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
				"weapons": [
					{"name": "AC/20", "damage": 20, "heat": 7, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "ballistic"},
					{"name": "LRM 20", "damage": 20, "heat": 6, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile"},
					{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy"},
					{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy"},
					{"name": "SRM 6", "damage": 12, "heat": 4, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "missile"},
					{"name": "SRM 6", "damage": 12, "heat": 4, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "missile"}
				],
				"heat_capacity": 30,
				"gunnery_skill": 4
			},
			"AS7-K": {
				"name": "Atlas AS7-K",
				"walk_mp": 3,
				"run_mp": 5,
				"jump_mp": 0,
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
				"weapons": [
					{"name": "Gauss Rifle", "damage": 15, "heat": 1, "min_range": 2, "short_range": 7, "medium_range": 15, "long_range": 22, "type": "ballistic"},
					{"name": "ER Large Laser", "damage": 8, "heat": 12, "min_range": 0, "short_range": 8, "medium_range": 15, "long_range": 25, "type": "energy"},
					{"name": "ER Large Laser", "damage": 8, "heat": 12, "min_range": 0, "short_range": 8, "medium_range": 15, "long_range": 25, "type": "energy"},
					{"name": "LRM 15", "damage": 15, "heat": 5, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile"},
					{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy"}
				],
				"heat_capacity": 30,
				"gunnery_skill": 4
			}
		}
	},
	"Mad Cat": {
		"tonnage": 75,
		"variants": {
			"Timber Wolf Prime": {
				"name": "Mad Cat (Timber Wolf) Prime",
				"walk_mp": 5,
				"run_mp": 8,
				"jump_mp": 0,
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
				"weapons": [
					{"name": "ER Large Laser", "damage": 8, "heat": 12, "min_range": 0, "short_range": 8, "medium_range": 15, "long_range": 25, "type": "energy"},
					{"name": "ER Large Laser", "damage": 8, "heat": 12, "min_range": 0, "short_range": 8, "medium_range": 15, "long_range": 25, "type": "energy"},
					{"name": "LRM 20", "damage": 20, "heat": 6, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile"},
					{"name": "LRM 20", "damage": 20, "heat": 6, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "type": "missile"},
					{"name": "Medium Pulse Laser", "damage": 6, "heat": 4, "min_range": 0, "short_range": 2, "medium_range": 4, "long_range": 6, "type": "energy"},
					{"name": "Medium Pulse Laser", "damage": 6, "heat": 4, "min_range": 0, "short_range": 2, "medium_range": 4, "long_range": 6, "type": "energy"}
				],
				"heat_capacity": 26,
				"gunnery_skill": 4
			},
			"Timber Wolf A": {
				"name": "Mad Cat (Timber Wolf) A",
				"walk_mp": 5,
				"run_mp": 8,
				"jump_mp": 0,
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
				"weapons": [
					{"name": "ER PPC", "damage": 10, "heat": 15, "min_range": 0, "short_range": 7, "medium_range": 14, "long_range": 23, "type": "energy"},
					{"name": "ER PPC", "damage": 10, "heat": 15, "min_range": 0, "short_range": 7, "medium_range": 14, "long_range": 23, "type": "energy"},
					{"name": "Ultra AC/5", "damage": 5, "heat": 1, "min_range": 0, "short_range": 6, "medium_range": 13, "long_range": 20, "type": "ballistic"},
					{"name": "Ultra AC/5", "damage": 5, "heat": 1, "min_range": 0, "short_range": 6, "medium_range": 13, "long_range": 20, "type": "ballistic"},
					{"name": "Streak SRM 6", "damage": 12, "heat": 4, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "missile"}
				],
				"heat_capacity": 26,
				"gunnery_skill": 4
			}
		}
	},
	"Hunchback": {
		"tonnage": 50,
		"variants": {
			"HBK-4G": {
				"name": "Hunchback HBK-4G",
				"walk_mp": 4,
				"run_mp": 6,
				"jump_mp": 0,
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
				"weapons": [
					{"name": "AC/20", "damage": 20, "heat": 7, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "ballistic"},
					{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy"},
					{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy"}
				],
				"heat_capacity": 13,
				"gunnery_skill": 4
			},
			"HBK-4P": {
				"name": "Hunchback HBK-4P",
				"walk_mp": 4,
				"run_mp": 6,
				"jump_mp": 0,
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
				"weapons": [
					{"name": "Large Laser", "damage": 8, "heat": 8, "min_range": 0, "short_range": 5, "medium_range": 10, "long_range": 15, "type": "energy"},
					{"name": "Large Laser", "damage": 8, "heat": 8, "min_range": 0, "short_range": 5, "medium_range": 10, "long_range": 15, "type": "energy"},
					{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy"},
					{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy"},
					{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy"},
					{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy"},
					{"name": "Small Laser", "damage": 3, "heat": 1, "min_range": 0, "short_range": 1, "medium_range": 2, "long_range": 3, "type": "energy"},
					{"name": "Small Laser", "damage": 3, "heat": 1, "min_range": 0, "short_range": 1, "medium_range": 2, "long_range": 3, "type": "energy"}
				],
				"heat_capacity": 13,
				"gunnery_skill": 4
			}
		}
	},
	"Locust": {
		"tonnage": 20,
		"variants": {
			"LCT-1V": {
				"name": "Locust LCT-1V",
				"walk_mp": 8,
				"run_mp": 12,
				"jump_mp": 0,
				"armor": {
					"head": {"current": 6, "max": 6},
					"center_torso": {"current": 8, "max": 8},
					"center_torso_rear": {"current": 2, "max": 2},
					"left_torso": {"current": 6, "max": 6},
					"left_torso_rear": {"current": 2, "max": 2},
					"right_torso": {"current": 6, "max": 6},
					"right_torso_rear": {"current": 2, "max": 2},
					"left_arm": {"current": 4, "max": 4},
					"right_arm": {"current": 4, "max": 4},
					"left_leg": {"current": 6, "max": 6},
					"right_leg": {"current": 6, "max": 6}
				},
				"weapons": [
					{"name": "Medium Laser", "damage": 5, "heat": 3, "min_range": 0, "short_range": 3, "medium_range": 6, "long_range": 9, "type": "energy"},
					{"name": "Machine Gun", "damage": 2, "heat": 0, "min_range": 0, "short_range": 1, "medium_range": 2, "long_range": 3, "type": "ballistic"},
					{"name": "Machine Gun", "damage": 2, "heat": 0, "min_range": 0, "short_range": 1, "medium_range": 2, "long_range": 3, "type": "ballistic"}
				],
				"heat_capacity": 10,
				"gunnery_skill": 4
			}
		}
	}
}

# Inventario del jugador - mechs disponibles en el hangar
var player_hangar := []

# Índice del mech actualmente seleccionado para batalla
var selected_mech_index: int = 0

# Flag temporal para forzar regeneración del hangar (cambiar a true para limpiar datos corruptos)
var force_regenerate_hangar: bool = true

func _ready():
	# Intentar cargar hangar guardado, si no existe usar default
	if force_regenerate_hangar:
		print("[MechBayManager] Force regenerate enabled - clearing hangar")
		player_hangar.clear()
		_initialize_default_hangar()
		save_hangar_to_file()
	elif not load_hangar_from_file():
		_initialize_default_hangar()

func _initialize_default_hangar():
	# Añadir algunos mechs al hangar inicial
	print("[MechBayManager] Initializing default hangar...")
	add_mech_to_hangar("Atlas", "AS7-D")
	add_mech_to_hangar("Atlas", "AS7-K")
	add_mech_to_hangar("Mad Cat", "Timber Wolf Prime")
	add_mech_to_hangar("Mad Cat", "Timber Wolf A")
	add_mech_to_hangar("Hunchback", "HBK-4G")
	add_mech_to_hangar("Hunchback", "HBK-4P")
	add_mech_to_hangar("Locust", "LCT-1V")
	print("[MechBayManager] Default hangar initialized with %d mechs" % player_hangar.size())

func force_regenerate():
	# Método público para regenerar el hangar desde código
	print("[MechBayManager] === FORCE REGENERATING HANGAR ===")
	player_hangar.clear()
	_initialize_default_hangar()
	save_hangar_to_file()
	print("[MechBayManager] === REGENERATION COMPLETE ===")
	return true

func add_mech_to_hangar(mech_type: String, variant: String) -> bool:
	# Añade un mech al hangar del jugador
	if not mech_library.has(mech_type):
		push_error("Mech type not found: " + mech_type)
		return false
	
	if not mech_library[mech_type]["variants"].has(variant):
		push_error("Variant not found: " + variant)
		return false
	
	var mech_data = get_mech_data(mech_type, variant)
	if mech_data:
		player_hangar.append(mech_data)
		return true
	
	return false

func get_mech_data(mech_type: String, variant: String) -> Dictionary:
	# Obtiene una copia de los datos de un mech específico
	if not mech_library.has(mech_type):
		return {}
	
	if not mech_library[mech_type]["variants"].has(variant):
		return {}
	
	var mech_data = mech_library[mech_type]["variants"][variant].duplicate(true)
	mech_data["mech_type"] = mech_type
	mech_data["variant"] = variant
	mech_data["tonnage"] = mech_library[mech_type]["tonnage"]
	
	return mech_data

func get_player_hangar() -> Array:
	# Devuelve la lista de mechs en el hangar del jugador
	return player_hangar

func get_available_mech_types() -> Array:
	# Devuelve lista de tipos de mechs disponibles
	return mech_library.keys()

func get_variants_for_mech(mech_type: String) -> Array:
	# Devuelve las variantes disponibles para un tipo de mech
	if not mech_library.has(mech_type):
		return []
	
	return mech_library[mech_type]["variants"].keys()

func remove_mech_from_hangar(index: int) -> bool:
	# Elimina un mech del hangar por índice
	if index < 0 or index >= player_hangar.size():
		return false
	
	player_hangar.remove_at(index)
	return true

func get_mech_info_summary(mech_data: Dictionary) -> String:
	# Genera un resumen de información del mech
	var summary = "[b]%s[/b]\n" % mech_data.get("name", "Unknown")
	summary += "Tonnage: %d tons\n" % mech_data.get("tonnage", 0)
	summary += "Movement: %d/%d/%d\n" % [
		mech_data.get("walk_mp", 0),
		mech_data.get("run_mp", 0),
		mech_data.get("jump_mp", 0)
	]
	
	# Calcular armadura total
	var total_armor = 0
	var armor_dict = mech_data.get("armor", {})
	for location in armor_dict.keys():
		total_armor += armor_dict[location].get("max", 0)
	
	summary += "Total Armor: %d\n" % total_armor
	summary += "Heat Capacity: %d\n" % mech_data.get("heat_capacity", 0)
	summary += "\nWeapons: %d\n" % mech_data.get("weapons", []).size()
	
	return summary

# Sistema de guardado y carga de configuraciones
const SAVE_FILE_PATH = "user://mech_hangar.json"

func save_hangar_to_file() -> bool:
	# Guarda el hangar actual en un archivo JSON
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Cannot open save file for writing: " + SAVE_FILE_PATH)
		return false
	
	var save_data = {
		"version": "1.0",
		"hangar": player_hangar,
		"selected_mech_index": selected_mech_index
	}
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	print("[MechBayManager] Hangar saved to: ", SAVE_FILE_PATH)
	return true

func load_hangar_from_file() -> bool:
	# Carga el hangar desde un archivo JSON
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("[MechBayManager] No save file found, using default hangar")
		return false
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("Cannot open save file for reading: " + SAVE_FILE_PATH)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse save file: " + str(parse_result))
		return false
	
	var save_data = json.data
	if typeof(save_data) != TYPE_DICTIONARY:
		push_error("Save data is not a dictionary")
		return false
	
	if save_data.has("hangar"):
		player_hangar = save_data["hangar"]
		print("[MechBayManager] Hangar loaded from file: ", player_hangar.size(), " mechs")
		
		# Debug: mostrar armas de cada mech cargado
		for i in range(player_hangar.size()):
			var mech = player_hangar[i]
			print("[DEBUG] Loaded mech %d: %s" % [i, mech.get("name", "Unknown")])
			if mech.has("weapons"):
				print("[DEBUG]   Weapons count: %d" % mech["weapons"].size())
				for j in range(mech["weapons"].size()):
					print("[DEBUG]     Weapon %d: %s" % [j, mech["weapons"][j].get("name", "Unknown")])
		
		# Cargar índice del mech seleccionado
		if save_data.has("selected_mech_index"):
			selected_mech_index = save_data["selected_mech_index"]
		
		return true
	
	return false

func get_selected_player_mech() -> Dictionary:
	# Obtiene el mech seleccionado actualmente para batalla
	if player_hangar.size() > 0 and selected_mech_index >= 0 and selected_mech_index < player_hangar.size():
		return player_hangar[selected_mech_index].duplicate(true)
	
	# Si no hay mech seleccionado, usar el primero
	if player_hangar.size() > 0:
		return player_hangar[0].duplicate(true)
	
	# Si no hay mechs, devolver un Atlas por defecto
	return get_mech_data("Atlas", "AS7-D")

func set_selected_mech(index: int):
	# Establece cuál mech del hangar está seleccionado para batalla
	if index >= 0 and index < player_hangar.size():
		selected_mech_index = index
		print("[MechBayManager] Selected mech for battle: ", player_hangar[index].get("name", "Unknown"))

func get_first_player_mech() -> Dictionary:
	# DEPRECATED: Usar get_selected_player_mech() en su lugar
	return get_selected_player_mech()

func get_player_lance() -> Array:
	# Obtiene los primeros 4 mechs del hangar para usar como lance en batalla
	var lance = []
	var count = min(4, player_hangar.size())
	
	for i in range(count):
		lance.append(player_hangar[i].duplicate(true))
	
	# Si no hay suficientes mechs, rellenar con defaults
	if lance.size() == 0:
		lance.append(get_mech_data("Atlas", "AS7-D"))
	
	return lance
