extends Node

# Manager para el loadout seleccionado en el Mech Bay
# Este loadout se usará en la próxima batalla

var selected_loadout: Dictionary = {}
var has_selection: bool = false

func set_selected_loadout(loadout_data: Dictionary):
	selected_loadout = loadout_data.duplicate(true)
	has_selection = true
	print("[SelectedLoadoutManager] Loadout seleccionado: ", loadout_data.get("mech_name", "Unknown"))

func get_selected_loadout() -> Dictionary:
	return selected_loadout

func clear_selection():
	selected_loadout = {}
	has_selection = false

func has_loadout() -> bool:
	return has_selection and selected_loadout.size() > 0
