extends CanvasLayer

# Pantalla de Mech Bay - Muestra los mechs guardados y permite editarlos o seleccionarlos

signal mech_bay_closed()
signal mech_selected_for_battle(loadout_data: Dictionary)

var scale_factor := 1.0
var margin := 10.0

# Referencias a UI
var main_panel: Panel
var title_label: Label
var loadouts_list: ItemList
var detail_panel: Panel
var mech_name_label: Label
var mech_stats_label: RichTextLabel
var components_label: RichTextLabel

# Botones
var back_button: Button
var edit_button: Button
var select_for_battle_button: Button
var delete_button: Button

# Datos
var saved_loadouts: Dictionary = {}
var selected_loadout_name: String = ""

func _ready():
	_setup_ui()
	_load_saved_loadouts()

func _setup_ui():
	# Obtener tamaño de pantalla
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y
	
	scale_factor = screen_width / 720.0
	margin = 10 * scale_factor
	
	# Panel principal de fondo
	var background = ColorRect.new()
	background.color = Color(0.05, 0.05, 0.1, 1.0)
	background.size = viewport_size
	add_child(background)
	
	# Panel principal
	main_panel = Panel.new()
	main_panel.position = Vector2(margin, margin)
	main_panel.size = Vector2(screen_width - margin * 2, screen_height - margin * 2)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style_box.border_width_left = 3
	style_box.border_width_right = 3
	style_box.border_width_top = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color.CYAN
	main_panel.add_theme_stylebox_override("panel", style_box)
	add_child(main_panel)
	
	# Título
	title_label = Label.new()
	title_label.text = "MECH BAY - SAVED LOADOUTS"
	title_label.position = Vector2(margin * 2, margin * 2)
	title_label.add_theme_font_size_override("font_size", int(28 * scale_factor))
	title_label.add_theme_color_override("font_color", Color.GOLD)
	main_panel.add_child(title_label)
	
	# Panel izquierdo - Lista de loadouts
	var list_panel = Panel.new()
	list_panel.position = Vector2(margin * 2, 60 * scale_factor)
	list_panel.size = Vector2(main_panel.size.x * 0.35, main_panel.size.y - 130 * scale_factor)
	
	var list_style = StyleBoxFlat.new()
	list_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	list_panel.add_theme_stylebox_override("panel", list_style)
	main_panel.add_child(list_panel)
	
	var list_title = Label.new()
	list_title.text = "SAVED MECHS"
	list_title.position = Vector2(margin, margin)
	list_title.add_theme_font_size_override("font_size", int(18 * scale_factor))
	list_title.add_theme_color_override("font_color", Color.CYAN)
	list_panel.add_child(list_title)
	
	loadouts_list = ItemList.new()
	loadouts_list.position = Vector2(margin, 40 * scale_factor)
	loadouts_list.size = Vector2(list_panel.size.x - margin * 2, list_panel.size.y - 50 * scale_factor)
	loadouts_list.add_theme_font_size_override("font_size", int(14 * scale_factor))
	loadouts_list.item_selected.connect(_on_loadout_selected)
	list_panel.add_child(loadouts_list)
	
	# Panel derecho - Detalles del loadout
	detail_panel = Panel.new()
	detail_panel.position = Vector2(list_panel.position.x + list_panel.size.x + margin, 60 * scale_factor)
	detail_panel.size = Vector2(main_panel.size.x * 0.6, main_panel.size.y - 130 * scale_factor)
	
	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	main_panel.add_child(detail_panel)
	
	var detail_title = Label.new()
	detail_title.text = "LOADOUT DETAILS"
	detail_title.position = Vector2(margin, margin)
	detail_title.add_theme_font_size_override("font_size", int(20 * scale_factor))
	detail_title.add_theme_color_override("font_color", Color.CYAN)
	detail_panel.add_child(detail_title)
	
	# Botón DELETE en el panel de detalles
	delete_button = Button.new()
	delete_button.text = "🗑 DELETE"
	delete_button.position = Vector2(detail_panel.size.x - 120 * scale_factor, margin * 0.5)
	delete_button.size = Vector2(110 * scale_factor, 35 * scale_factor)
	delete_button.add_theme_font_size_override("font_size", int(14 * scale_factor))
	delete_button.disabled = true  # Deshabilitado hasta que se seleccione un loadout
	delete_button.pressed.connect(_on_delete_pressed)
	
	# Estilo del botón delete (rojo)
	var delete_style_normal = StyleBoxFlat.new()
	delete_style_normal.bg_color = Color(0.6, 0.1, 0.1, 1.0)
	delete_style_normal.border_width_left = 2
	delete_style_normal.border_width_right = 2
	delete_style_normal.border_width_top = 2
	delete_style_normal.border_width_bottom = 2
	delete_style_normal.border_color = Color.DARK_RED
	delete_button.add_theme_stylebox_override("normal", delete_style_normal)
	
	var delete_style_hover = StyleBoxFlat.new()
	delete_style_hover.bg_color = Color(0.8, 0.1, 0.1, 1.0)
	delete_style_hover.border_width_left = 2
	delete_style_hover.border_width_right = 2
	delete_style_hover.border_width_top = 2
	delete_style_hover.border_width_bottom = 2
	delete_style_hover.border_color = Color.RED
	delete_button.add_theme_stylebox_override("hover", delete_style_hover)
	
	var delete_style_disabled = StyleBoxFlat.new()
	delete_style_disabled.bg_color = Color(0.3, 0.3, 0.3, 1.0)
	delete_button.add_theme_stylebox_override("disabled", delete_style_disabled)
	
	detail_panel.add_child(delete_button)
	
	mech_name_label = Label.new()
	mech_name_label.position = Vector2(margin, 45 * scale_factor)
	mech_name_label.add_theme_font_size_override("font_size", int(18 * scale_factor))
	mech_name_label.add_theme_color_override("font_color", Color.GOLD)
	mech_name_label.text = "Select a loadout"
	detail_panel.add_child(mech_name_label)
	
	mech_stats_label = RichTextLabel.new()
	mech_stats_label.position = Vector2(margin, 75 * scale_factor)
	mech_stats_label.size = Vector2(detail_panel.size.x - margin * 2, 150 * scale_factor)
	mech_stats_label.bbcode_enabled = true
	mech_stats_label.add_theme_font_size_override("normal_font_size", int(14 * scale_factor))
	detail_panel.add_child(mech_stats_label)
	
	var components_title = Label.new()
	components_title.text = "Installed Components:"
	components_title.position = Vector2(margin, 235 * scale_factor)
	components_title.add_theme_font_size_override("font_size", int(16 * scale_factor))
	components_title.add_theme_color_override("font_color", Color.CYAN)
	detail_panel.add_child(components_title)
	
	components_label = RichTextLabel.new()
	components_label.position = Vector2(margin, 265 * scale_factor)
	components_label.size = Vector2(detail_panel.size.x - margin * 2, detail_panel.size.y - 275 * scale_factor)
	components_label.bbcode_enabled = true
	components_label.add_theme_font_size_override("normal_font_size", int(12 * scale_factor))
	detail_panel.add_child(components_label)
	
	# Botones
	back_button = Button.new()
	back_button.text = "BACK TO MENU"
	back_button.position = Vector2(margin * 2, main_panel.size.y - 60 * scale_factor)
	back_button.size = Vector2(200 * scale_factor, 50 * scale_factor)
	back_button.add_theme_font_size_override("font_size", int(16 * scale_factor))
	back_button.pressed.connect(_on_back_pressed)
	main_panel.add_child(back_button)
	
	edit_button = Button.new()
	edit_button.text = "EDIT LOADOUT"
	edit_button.position = Vector2(main_panel.size.x - 430 * scale_factor, main_panel.size.y - 60 * scale_factor)
	edit_button.size = Vector2(200 * scale_factor, 50 * scale_factor)
	edit_button.add_theme_font_size_override("font_size", int(16 * scale_factor))
	edit_button.pressed.connect(_on_edit_pressed)
	main_panel.add_child(edit_button)
	
	select_for_battle_button = Button.new()
	select_for_battle_button.text = "SELECT FOR BATTLE"
	select_for_battle_button.position = Vector2(main_panel.size.x - 220 * scale_factor, main_panel.size.y - 60 * scale_factor)
	select_for_battle_button.size = Vector2(210 * scale_factor, 50 * scale_factor)
	select_for_battle_button.add_theme_font_size_override("font_size", int(16 * scale_factor))
	select_for_battle_button.pressed.connect(_on_select_for_battle_pressed)
	main_panel.add_child(select_for_battle_button)

func _load_saved_loadouts():
	saved_loadouts = {}
	loadouts_list.clear()
	
	var save_path = "user://saved_loadouts.json"
	if not FileAccess.file_exists(save_path):
		mech_stats_label.text = "[color=yellow]No saved loadouts found.\nGo to Advanced Loadout to create one.[/color]"
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	
	saved_loadouts = file.get_var()
	file.close()
	
	# Llenar lista
	for loadout_name in saved_loadouts.keys():
		var loadout_data = saved_loadouts[loadout_name]
		var display_text = "%s (%s, %d tons)" % [
			loadout_name,
			loadout_data.get("mech_name", "Unknown"),
			loadout_data.get("mech_tonnage", 0)
		]
		var index = loadouts_list.add_item(display_text)
		loadouts_list.set_item_metadata(index, loadout_name)

func _on_loadout_selected(index: int):
	selected_loadout_name = loadouts_list.get_item_metadata(index)
	
	# Habilitar botón de delete
	delete_button.disabled = false
	
	if not saved_loadouts.has(selected_loadout_name):
		return
	
	var loadout_data = saved_loadouts[selected_loadout_name]
	
	# Actualizar panel de detalles
	mech_name_label.text = loadout_data.get("mech_name", "Unknown")
	
	# Mostrar stats
	var stats_text = ""
	stats_text += "[b]Tonnage:[/b] %d tons\n" % loadout_data.get("mech_tonnage", 0)
	stats_text += "[b]Engine:[/b] Rating %d\n" % loadout_data.get("engine_rating", 0)
	stats_text += "[b]Weight:[/b] %.1f / %d tons\n" % [
		loadout_data.get("current_weight", 0.0),
		loadout_data.get("mech_tonnage", 0)
	]
	stats_text += "[b]Heat Sinks:[/b] %d\n" % loadout_data.get("heat_sinks", 10)
	
	mech_stats_label.text = stats_text
	
	# Mostrar componentes instalados
	var components_text = ""
	var loadout = loadout_data.get("loadout", {})
	
	for location_str in loadout.keys():
		var location_int = int(location_str)
		var location_name = _get_location_name(location_int)
		var components = loadout[location_str]
		
		if components.size() > 0:
			components_text += "[b][color=cyan]%s:[/color][/b]\n" % location_name
			for component in components:
				components_text += "  • %s\n" % component.get("name", "?")
	
	if components_text == "":
		components_text = "[color=gray]No components installed[/color]"
	
	components_label.text = components_text

func _get_location_name(location: int) -> String:
	var names = ["HEAD", "CENTER TORSO", "LEFT TORSO", "RIGHT TORSO", "LEFT ARM", "RIGHT ARM", "LEFT LEG", "RIGHT LEG"]
	if location >= 0 and location < names.size():
		return names[location]
	return "UNKNOWN"

func _on_delete_pressed():
	if selected_loadout_name == "" or not saved_loadouts.has(selected_loadout_name):
		return
	
	# Crear popup de confirmación
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to delete '%s'?\nThis action cannot be undone." % selected_loadout_name
	confirm_dialog.title = "Delete Loadout"
	confirm_dialog.size = Vector2(400 * scale_factor, 150 * scale_factor)
	
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
	mech_stats_label.text = ""
	components_label.text = ""
	
	print("[MECH BAY] Loadout deleted successfully")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

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

func _on_select_for_battle_pressed():
	if selected_loadout_name == "" or not saved_loadouts.has(selected_loadout_name):
		return
	
	# Guardar el loadout seleccionado en el manager
	var loadout_data = saved_loadouts[selected_loadout_name]
	
	# Verificar si existe el manager (autoload)
	if has_node("/root/SelectedLoadoutManager"):
		var manager = get_node("/root/SelectedLoadoutManager")
		manager.set_selected_loadout(loadout_data)
	
	# Emitir señal con el loadout seleccionado
	mech_selected_for_battle.emit(loadout_data)
	
	# Ir directamente a la batalla
	get_tree().change_scene_to_file("res://scenes/battle_scene_simple.tscn")

