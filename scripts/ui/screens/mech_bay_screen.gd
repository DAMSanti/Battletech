extends CanvasLayer

# Pantalla de Mech Bay - Muestra los mechs guardados y permite editarlos o seleccionarlos

signal mech_bay_closed()
signal mech_selected_for_battle(loadout_data: Dictionary)

# Referencias a UI (desde la escena)
@onready var loadouts_list: ItemList = $MainContainer/HBoxContainer/LeftPanel/LoadoutsPanel/VBoxContainer/LoadoutsList
@onready var mech_name_label: Label = $MainContainer/HBoxContainer/RightPanel/DetailsPanel/ScrollContainer/DetailsContent/MechNameLabel
@onready var mech_stats_label: RichTextLabel = $MainContainer/HBoxContainer/RightPanel/DetailsPanel/ScrollContainer/DetailsContent/StatsPanel/MarginContainer/MechStatsLabel
@onready var components_label: RichTextLabel = $MainContainer/HBoxContainer/RightPanel/DetailsPanel/ScrollContainer/DetailsContent/ComponentsPanel/MarginContainer/ComponentsListLabel
@onready var back_button: Button = $MainContainer/HBoxContainer/RightPanel/ActionsPanel/HBoxContainer/BackButton
@onready var edit_button: Button = $MainContainer/HBoxContainer/RightPanel/ActionsPanel/HBoxContainer/EditButton
@onready var delete_button: Button = $MainContainer/HBoxContainer/RightPanel/DetailsPanel/ScrollContainer/DetailsContent/HeaderContainer/DeleteButton
@onready var create_new_button: Button = $MainContainer/HBoxContainer/LeftPanel/QuickActionsPanel/VBoxContainer/CreateNewButton

# Datos
var saved_loadouts: Dictionary = {}
var selected_loadout_name: String = ""

func _ready():
	_connect_signals()
	_apply_custom_styles()
	_load_saved_loadouts()

func _connect_signals():
	loadouts_list.item_selected.connect(_on_loadout_selected)
	back_button.pressed.connect(_on_back_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	create_new_button.pressed.connect(_on_create_new_pressed)

func _apply_custom_styles():
	# Estilo personalizado solo para el botón de eliminar (rojo peligro) - los demás usan el theme
	var delete_normal = StyleBoxFlat.new()
	delete_normal.bg_color = Color(0.5, 0.1, 0.1, 0.95)
	delete_normal.border_width_left = 3
	delete_normal.border_width_top = 1
	delete_normal.border_width_right = 3
	delete_normal.border_width_bottom = 3
	delete_normal.border_color = Color(0.8, 0.2, 0.2, 0.9)
	delete_normal.corner_radius_top_left = 8
	delete_normal.corner_radius_top_right = 8
	delete_normal.corner_radius_bottom_right = 8
	delete_normal.corner_radius_bottom_left = 8
	delete_normal.border_blend = true
	delete_normal.anti_aliasing = true
	delete_normal.shadow_color = Color(0.8, 0.2, 0.2, 0.4)
	delete_normal.shadow_size = 4
	delete_normal.shadow_offset = Vector2(0, 2)
	delete_button.add_theme_stylebox_override("normal", delete_normal)
	
	var delete_hover = StyleBoxFlat.new()
	delete_hover.bg_color = Color(0.7, 0.15, 0.15, 1)
	delete_hover.border_width_left = 3
	delete_hover.border_width_top = 1
	delete_hover.border_width_right = 3
	delete_hover.border_width_bottom = 4
	delete_hover.border_color = Color(1, 0.3, 0.3, 1)
	delete_hover.corner_radius_top_left = 8
	delete_hover.corner_radius_top_right = 8
	delete_hover.corner_radius_bottom_right = 8
	delete_hover.corner_radius_bottom_left = 8
	delete_hover.border_blend = true
	delete_hover.anti_aliasing = true
	delete_hover.shadow_color = Color(1, 0.3, 0.3, 0.7)
	delete_hover.shadow_size = 8
	delete_hover.shadow_offset = Vector2(0, 3)
	delete_button.add_theme_stylebox_override("hover", delete_hover)
	
	var delete_pressed = StyleBoxFlat.new()
	delete_pressed.bg_color = Color(0.8, 0.2, 0.2, 1)
	delete_pressed.border_width_left = 3
	delete_pressed.border_width_top = 3
	delete_pressed.border_width_right = 3
	delete_pressed.border_width_bottom = 1
	delete_pressed.border_color = Color(1, 0.4, 0.4, 1)
	delete_pressed.corner_radius_top_left = 8
	delete_pressed.corner_radius_top_right = 8
	delete_pressed.corner_radius_bottom_right = 8
	delete_pressed.corner_radius_bottom_left = 8
	delete_pressed.border_blend = true
	delete_pressed.anti_aliasing = true
	delete_pressed.shadow_color = Color(1, 0.3, 0.3, 0.9)
	delete_pressed.shadow_size = 12
	delete_button.add_theme_stylebox_override("pressed", delete_pressed)

func _load_saved_loadouts():
	saved_loadouts = {}
	loadouts_list.clear()
	
	var save_path = "user://saved_loadouts.json"
	if not FileAccess.file_exists(save_path):
		mech_stats_label.text = "[center][color=#ff9933]⚠ NO SAVED LOADOUTS FOUND[/color]\n\n[color=gray]Create a new loadout using the\nAdvanced Loadout Editor[/color][/center]"
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	
	saved_loadouts = file.get_var()
	file.close()
	
	# Llenar lista con iconos y formato mejorado
	for loadout_name in saved_loadouts.keys():
		var loadout_data = saved_loadouts[loadout_name]
		var display_text = "▸ %s\n  [%s - %d tons]" % [
			loadout_name,
			loadout_data.get("mech_name", "Unknown"),
			loadout_data.get("mech_tonnage", 0)
		]
		var index = loadouts_list.add_item(display_text)
		loadouts_list.set_item_metadata(index, loadout_name)
	
	if saved_loadouts.size() > 0:
		mech_stats_label.text = "[center][color=#4d9fff]← Select a loadout from the list[/color][/center]"

func _on_loadout_selected(index: int):
	selected_loadout_name = loadouts_list.get_item_metadata(index)
	
	# Habilitar botón de delete
	delete_button.disabled = false
	
	if not saved_loadouts.has(selected_loadout_name):
		return
	
	var loadout_data = saved_loadouts[selected_loadout_name]
	
	# Actualizar panel de detalles
	mech_name_label.text = "⬢ " + loadout_data.get("mech_name", "Unknown")
	
	# Mostrar stats con formato mejorado
	var stats_text = ""
	stats_text += "[color=#4d9fff]┌─ SPECIFICATIONS ─────────────[/color]\n"
	stats_text += "[color=#66b3ff]│[/color] [b]Class:[/b] %d-ton BattleMech\n" % loadout_data.get("mech_tonnage", 0)
	stats_text += "[color=#66b3ff]│[/color] [b]Engine:[/b] Rating %d\n" % loadout_data.get("engine_rating", 0)
	stats_text += "[color=#66b3ff]│[/color] [b]Total Weight:[/b] [color=%s]%.1f[/color] / %d tons\n" % [
		"#ff6666" if loadout_data.get("current_weight", 0.0) > loadout_data.get("mech_tonnage", 0) else "#66ff66",
		loadout_data.get("current_weight", 0.0),
		loadout_data.get("mech_tonnage", 0)
	]
	stats_text += "[color=#66b3ff]│[/color] [b]Heat Sinks:[/b] %d\n" % loadout_data.get("heat_sinks", 10)
	stats_text += "[color=#4d9fff]└───────────────────────────────[/color]\n"
	
	mech_stats_label.text = stats_text
	
	# Mostrar componentes instalados con mejor formato
	var components_text = ""
	var loadout = loadout_data.get("loadout", {})
	
	for location_str in loadout.keys():
		var location_int = int(location_str)
		var location_name = _get_location_name(location_int)
		var components = loadout[location_str]
		
		if components.size() > 0:
			components_text += "[color=#4d9fff]▸ %s[/color]\n" % location_name
			for component in components:
				var comp_name = component.get("name", "?")
				var comp_type = component.get("type", "")
				# Convertir a string si es necesario
				if typeof(comp_type) == TYPE_INT:
					comp_type = str(comp_type)
				var icon = _get_component_icon(comp_type)
				components_text += "  [color=#66b3ff]%s[/color] %s\n" % [icon, comp_name]
			components_text += "\n"
	
	if components_text == "":
		components_text = "[center][color=gray]⚠ No components installed[/color][/center]"
	
	components_label.text = components_text

func _get_location_name(location: int) -> String:
	var names = ["HEAD", "CENTER TORSO", "LEFT TORSO", "RIGHT TORSO", "LEFT ARM", "RIGHT ARM", "LEFT LEG", "RIGHT LEG"]
	if location >= 0 and location < names.size():
		return names[location]
	return "UNKNOWN"

func _get_component_icon(comp_type: String) -> String:
	match comp_type:
		"weapon": return "⚔"
		"ammo": return "▪"
		"heat_sink": return "◉"
		"engine": return "⚙"
		_: return "•"

func _on_delete_pressed():
	if selected_loadout_name == "" or not saved_loadouts.has(selected_loadout_name):
		return
	
	# Crear popup de confirmación
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to delete '%s'?\nThis action cannot be undone." % selected_loadout_name
	confirm_dialog.title = "Delete Loadout"
	confirm_dialog.size = Vector2(400, 150)
	
	# Conectar señales
	confirm_dialog.confirmed.connect(_on_delete_confirmed)
	confirm_dialog.canceled.connect(func(): confirm_dialog.queue_free())
	
	# Mostrar dialog
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _on_delete_confirmed():
	if selected_loadout_name == "" or not saved_loadouts.has(selected_loadout_name):
		return
	
	# Eliminar del diccionario
	saved_loadouts.erase(selected_loadout_name)
	
	# Guardar cambios
	var save_path = "user://saved_loadouts.json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_var(saved_loadouts)
		file.close()
	
	# Limpiar selección
	selected_loadout_name = ""
	delete_button.disabled = true
	
	# Recargar lista
	_load_saved_loadouts()
	
	# Limpiar panel de detalles
	mech_name_label.text = "Select a loadout"
	mech_stats_label.text = "[center][color=gray]No loadout selected[/color][/center]"
	components_label.text = "[center][color=gray]No components to display[/color][/center]"
	
	print("[MECH BAY] Loadout deleted successfully")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_create_new_pressed():
	get_tree().change_scene_to_file("res://scenes/mech_bay_advanced.tscn")

func _on_edit_pressed():
	if selected_loadout_name == "" or not saved_loadouts.has(selected_loadout_name):
		return
	
	# Guardar el loadout seleccionado en el manager para que lo cargue el Advanced Mech Bay
	var loadout_data = saved_loadouts[selected_loadout_name]
	
	# Verificar si existe el manager (autoload)
	if has_node("/root/SelectedLoadoutManager"):
		var manager = get_node("/root/SelectedLoadoutManager")
		manager.set_selected_loadout(loadout_data)
	
	# Abrir Advanced Mech Bay para editar
	get_tree().change_scene_to_file("res://scenes/mech_bay_advanced.tscn")
