extends CanvasLayer

# Pantalla de Mech Bay - Configuración de mechs con vistas múltiples

signal mech_bay_closed()
signal mech_configuration_saved(mech_data: Dictionary)

# Estados/vistas del Mech Bay
enum MechBayView {
	MECH_SELECTION,      # Vista de selección de mech
	WEAPON_CONFIG,       # Vista de configuración de armas
	ARMOR_CONFIG,        # Vista de configuración de armadura (futuro)
	EQUIPMENT_CONFIG     # Vista de otros equipamientos (futuro)
}

var current_view: MechBayView = MechBayView.MECH_SELECTION
var scale_factor := 1.0
var margin := 10.0

@onready var mech_bay_manager = get_node("/root/MechBayManager") if has_node("/root/MechBayManager") else null

# Referencias a UI compartidas
var main_panel: Panel
var title_label: Label

# Vista 1: Selección de Mech
var mech_selection_container: Control
var hangar_list: VBoxContainer
var mech_detail_label: RichTextLabel
var variant_selector: OptionButton
var next_to_weapons_button: Button

# Vista 2: Configuración de Armas
var weapon_config_container: Control
var weapons_list: VBoxContainer
var heatsinks_spinbox: SpinBox
var current_mech_summary: RichTextLabel

# Botones de navegación/acción
var back_button: Button
var save_and_exit_button: Button

# Datos actuales
var current_editing_mech: Dictionary = {}
var current_editing_index: int = -1

func _ready():
	_setup_ui()
	_show_view(MechBayView.MECH_SELECTION)
	_refresh_hangar_list()

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
	
	# Título (compartido entre vistas)
	title_label = Label.new()
	title_label.text = "MECH BAY - SELECT YOUR MECH"
	title_label.position = Vector2(margin * 2, margin * 2)
	title_label.add_theme_font_size_override("font_size", int(28 * scale_factor))
	title_label.add_theme_color_override("font_color", Color.GOLD)
	main_panel.add_child(title_label)
	
	# Crear todas las vistas
	_setup_mech_selection_view()
	_setup_weapon_config_view()
	
	# Botones de navegación (en la parte inferior)
	back_button = Button.new()
	back_button.text = "BACK"
	back_button.position = Vector2(margin * 2, main_panel.size.y - 60 * scale_factor)
	back_button.size = Vector2(200 * scale_factor, 50 * scale_factor)
	back_button.add_theme_font_size_override("font_size", int(18 * scale_factor))
	back_button.pressed.connect(_on_back_button_pressed)
	main_panel.add_child(back_button)
	
	save_and_exit_button = Button.new()
	save_and_exit_button.text = "SAVE & EXIT"
	save_and_exit_button.position = Vector2(main_panel.size.x - 220 * scale_factor, main_panel.size.y - 60 * scale_factor)
	save_and_exit_button.size = Vector2(210 * scale_factor, 50 * scale_factor)
	save_and_exit_button.add_theme_font_size_override("font_size", int(18 * scale_factor))
	save_and_exit_button.pressed.connect(_on_save_and_exit_pressed)
	main_panel.add_child(save_and_exit_button)

func _setup_mech_selection_view():
	# Contenedor para la vista de selección
	mech_selection_container = Control.new()
	mech_selection_container.position = Vector2(0, 60 * scale_factor)
	mech_selection_container.size = Vector2(main_panel.size.x, main_panel.size.y - 130 * scale_factor)
	main_panel.add_child(mech_selection_container)
	
	# Panel izquierdo - Lista de mechs
	var hangar_panel = Panel.new()
	hangar_panel.position = Vector2(margin * 2, 0)
	hangar_panel.size = Vector2(mech_selection_container.size.x * 0.35, mech_selection_container.size.y)
	
	var hangar_style = StyleBoxFlat.new()
	hangar_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	hangar_panel.add_theme_stylebox_override("panel", hangar_style)
	mech_selection_container.add_child(hangar_panel)
	
	var hangar_title = Label.new()
	hangar_title.text = "AVAILABLE MECHS"
	hangar_title.position = Vector2(margin, margin)
	hangar_title.add_theme_font_size_override("font_size", int(18 * scale_factor))
	hangar_title.add_theme_color_override("font_color", Color.CYAN)
	hangar_panel.add_child(hangar_title)
	
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(margin, 40 * scale_factor)
	scroll.size = Vector2(hangar_panel.size.x - margin * 2, hangar_panel.size.y - 50 * scale_factor)
	hangar_panel.add_child(scroll)
	
	hangar_list = VBoxContainer.new()
	hangar_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(hangar_list)
	
	# Panel derecho - Detalles del mech
	var detail_panel = Panel.new()
	detail_panel.position = Vector2(hangar_panel.position.x + hangar_panel.size.x + margin, 0)
	detail_panel.size = Vector2(mech_selection_container.size.x * 0.6, mech_selection_container.size.y)
	
	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	mech_selection_container.add_child(detail_panel)
	
	var detail_title = Label.new()
	detail_title.text = "MECH DETAILS"
	detail_title.position = Vector2(margin, margin)
	detail_title.add_theme_font_size_override("font_size", int(20 * scale_factor))
	detail_title.add_theme_color_override("font_color", Color.CYAN)
	detail_panel.add_child(detail_title)
	
	# Selector de variante
	var variant_label = Label.new()
	variant_label.text = "Select Variant:"
	variant_label.position = Vector2(margin, 45 * scale_factor)
	variant_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
	detail_panel.add_child(variant_label)
	
	variant_selector = OptionButton.new()
	variant_selector.position = Vector2(margin, 70 * scale_factor)
	variant_selector.size = Vector2(detail_panel.size.x - margin * 2, 45 * scale_factor)
	variant_selector.add_theme_font_size_override("font_size", int(18 * scale_factor))
	variant_selector.item_selected.connect(_on_variant_selected)
	detail_panel.add_child(variant_selector)
	
	# Detalles del mech
	mech_detail_label = RichTextLabel.new()
	mech_detail_label.position = Vector2(margin, 125 * scale_factor)
	mech_detail_label.size = Vector2(detail_panel.size.x - margin * 2, detail_panel.size.y - 240 * scale_factor)
	mech_detail_label.bbcode_enabled = true
	mech_detail_label.scroll_following = true
	mech_detail_label.add_theme_font_size_override("normal_font_size", int(15 * scale_factor))
	detail_panel.add_child(mech_detail_label)
	
	# Botón para continuar a configuración de armas
	next_to_weapons_button = Button.new()
	next_to_weapons_button.text = "CONFIGURE WEAPONS →"
	next_to_weapons_button.position = Vector2(margin, detail_panel.size.y - 60 * scale_factor)
	next_to_weapons_button.size = Vector2(detail_panel.size.x - margin * 2, 55 * scale_factor)
	next_to_weapons_button.add_theme_font_size_override("font_size", int(20 * scale_factor))
	next_to_weapons_button.disabled = true
	next_to_weapons_button.pressed.connect(_on_next_to_weapons_pressed)
	detail_panel.add_child(next_to_weapons_button)

func _setup_weapon_config_view():
	# Contenedor para la vista de configuración de armas
	weapon_config_container = Control.new()
	weapon_config_container.position = Vector2(0, 60 * scale_factor)
	weapon_config_container.size = Vector2(main_panel.size.x, main_panel.size.y - 130 * scale_factor)
	weapon_config_container.visible = false
	main_panel.add_child(weapon_config_container)
	
	# Panel izquierdo - Resumen del mech
	var summary_panel = Panel.new()
	summary_panel.position = Vector2(margin * 2, 0)
	summary_panel.size = Vector2(weapon_config_container.size.x * 0.3, weapon_config_container.size.y)
	
	var summary_style = StyleBoxFlat.new()
	summary_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	summary_panel.add_theme_stylebox_override("panel", summary_style)
	weapon_config_container.add_child(summary_panel)
	
	var summary_title = Label.new()
	summary_title.text = "CURRENT MECH"
	summary_title.position = Vector2(margin, margin)
	summary_title.add_theme_font_size_override("font_size", int(18 * scale_factor))
	summary_title.add_theme_color_override("font_color", Color.YELLOW)
	summary_panel.add_child(summary_title)
	
	current_mech_summary = RichTextLabel.new()
	current_mech_summary.position = Vector2(margin, 40 * scale_factor)
	current_mech_summary.size = Vector2(summary_panel.size.x - margin * 2, summary_panel.size.y - 50 * scale_factor)
	current_mech_summary.bbcode_enabled = true
	current_mech_summary.add_theme_font_size_override("normal_font_size", int(14 * scale_factor))
	summary_panel.add_child(current_mech_summary)
	
	# Panel derecho - Configuración de armas
	var weapons_panel = Panel.new()
	weapons_panel.position = Vector2(summary_panel.position.x + summary_panel.size.x + margin, 0)
	weapons_panel.size = Vector2(weapon_config_container.size.x * 0.65, weapon_config_container.size.y)
	
	var weapons_style = StyleBoxFlat.new()
	weapons_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	weapons_panel.add_theme_stylebox_override("panel", weapons_style)
	weapon_config_container.add_child(weapons_panel)
	
	var weapons_title = Label.new()
	weapons_title.text = "WEAPONS LOADOUT"
	weapons_title.position = Vector2(margin, margin)
	weapons_title.add_theme_font_size_override("font_size", int(20 * scale_factor))
	weapons_title.add_theme_color_override("font_color", Color.CYAN)
	weapons_panel.add_child(weapons_title)
	
	# Lista de armas
	var weapons_scroll = ScrollContainer.new()
	weapons_scroll.position = Vector2(margin, 45 * scale_factor)
	weapons_scroll.size = Vector2(weapons_panel.size.x - margin * 2, weapons_panel.size.y * 0.65)
	weapons_panel.add_child(weapons_scroll)
	
	weapons_list = VBoxContainer.new()
	weapons_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons_scroll.add_child(weapons_list)
	
	# Sección de disipadores de calor
	var heatsinks_y = weapons_scroll.position.y + weapons_scroll.size.y + 10
	var heatsinks_title = Label.new()
	heatsinks_title.text = "Heat Sinks Configuration:"
	heatsinks_title.position = Vector2(margin, heatsinks_y)
	heatsinks_title.add_theme_font_size_override("font_size", int(16 * scale_factor))
	heatsinks_title.add_theme_color_override("font_color", Color.ORANGE)
	weapons_panel.add_child(heatsinks_title)
	
	var heatsinks_hbox = HBoxContainer.new()
	heatsinks_hbox.position = Vector2(margin, heatsinks_y + 30 * scale_factor)
	weapons_panel.add_child(heatsinks_hbox)
	
	var heatsinks_label = Label.new()
	heatsinks_label.text = "Heat Capacity: "
	heatsinks_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
	heatsinks_hbox.add_child(heatsinks_label)
	
	heatsinks_spinbox = SpinBox.new()
	heatsinks_spinbox.min_value = 10
	heatsinks_spinbox.max_value = 50
	heatsinks_spinbox.step = 1
	heatsinks_spinbox.custom_minimum_size = Vector2(120 * scale_factor, 45 * scale_factor)
	heatsinks_spinbox.add_theme_font_size_override("font_size", int(16 * scale_factor))
	heatsinks_spinbox.value_changed.connect(_on_heatsinks_changed)
	heatsinks_hbox.add_child(heatsinks_spinbox)
	
	# Info
	var info_label = RichTextLabel.new()
	info_label.position = Vector2(margin, heatsinks_y + 85 * scale_factor)
	info_label.size = Vector2(weapons_panel.size.x - margin * 2, 80 * scale_factor)
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.add_theme_font_size_override("normal_font_size", int(13 * scale_factor))
	info_label.text = "[color=gray][i]Add, edit, or remove weapons from your mech's loadout. Adjust heat capacity to match your configuration. Remember to save your changes![/i][/color]"
	weapons_panel.add_child(info_label)

func _show_view(view: MechBayView):
	# Mostrar/ocultar contenedores según la vista actual
	current_view = view
	
	match view:
		MechBayView.MECH_SELECTION:
			title_label.text = "MECH BAY - SELECT YOUR MECH"
			mech_selection_container.visible = true
			weapon_config_container.visible = false
			back_button.text = "BACK TO MENU"
			
		MechBayView.WEAPON_CONFIG:
			title_label.text = "MECH BAY - WEAPON CONFIGURATION"
			mech_selection_container.visible = false
			weapon_config_container.visible = true
			back_button.text = "← BACK TO SELECTION"
			_update_weapon_config_view()

func _refresh_hangar_list():
	# Limpiar lista actual
	for child in hangar_list.get_children():
		child.queue_free()
	
	if not mech_bay_manager:
		return
	
	var hangar = mech_bay_manager.get_player_hangar()
	
	for i in range(hangar.size()):
		var mech = hangar[i]
		var button = Button.new()
		button.text = "%s\n%d tons" % [mech.get("name", "Unknown"), mech.get("tonnage", 0)]
		button.custom_minimum_size = Vector2(0, 70 * scale_factor)
		button.add_theme_font_size_override("font_size", int(16 * scale_factor))
		button.pressed.connect(_on_hangar_mech_selected.bind(i, mech))
		hangar_list.add_child(button)

func _on_hangar_mech_selected(index: int, mech: Dictionary):
	# Seleccionar mech del hangar
	current_editing_mech = mech.duplicate(true)
	current_editing_index = index
	
	# Marcar este mech como seleccionado para batalla
	if mech_bay_manager:
		mech_bay_manager.set_selected_mech(index)
	
	# Actualizar selector de variantes
	variant_selector.clear()
	if mech_bay_manager and mech.has("mech_type"):
		var variants = mech_bay_manager.get_variants_for_mech(mech["mech_type"])
		for variant in variants:
			variant_selector.add_item(variant)
		
		var current_variant = mech.get("variant", "")
		for i in range(variant_selector.item_count):
			if variant_selector.get_item_text(i) == current_variant:
				variant_selector.select(i)
				break
	
	_update_mech_details(current_editing_mech)
	next_to_weapons_button.disabled = false

func _on_variant_selected(index: int):
	# Cambiar variante
	if not current_editing_mech.has("mech_type"):
		return
	
	var variant_name = variant_selector.get_item_text(index)
	var new_mech = mech_bay_manager.get_mech_data(current_editing_mech["mech_type"], variant_name)
	
	if new_mech:
		current_editing_mech = new_mech
		_update_mech_details(new_mech)

func _update_mech_details(mech: Dictionary):
	# Actualizar panel de detalles
	var details = "[b][color=cyan]%s[/color][/b]\n\n" % mech.get("name", "Unknown")
	
	details += "[color=yellow]SPECIFICATIONS[/color]\n"
	details += "Tonnage: [color=white]%d tons[/color]\n" % mech.get("tonnage", 0)
	details += "Walk MP: [color=green]%d[/color]\n" % mech.get("walk_mp", 0)
	details += "Run MP: [color=green]%d[/color]\n" % mech.get("run_mp", 0)
	details += "Jump MP: [color=green]%d[/color]\n" % mech.get("jump_mp", 0)
	details += "Heat Capacity: [color=orange]%d[/color]\n" % mech.get("heat_capacity", 0)
	
	var total_armor = 0
	var armor_dict = mech.get("armor", {})
	for location in armor_dict.keys():
		total_armor += armor_dict[location].get("max", 0)
	details += "Total Armor: [color=cyan]%d[/color]\n\n" % total_armor
	
	details += "[color=yellow]WEAPONS[/color]\n"
	var weapons = mech.get("weapons", [])
	for weapon in weapons:
		var w_name = weapon.get("name", "Unknown")
		var w_dmg = weapon.get("damage", 0)
		var w_heat = weapon.get("heat", 0)
		var w_type = weapon.get("type", "unknown")
		
		var type_color = Color.WHITE
		match w_type:
			"energy":
				type_color = Color.RED
			"ballistic":
				type_color = Color.ORANGE
			"missile":
				type_color = Color.YELLOW
		
		details += "• [color=#%s]%s[/color] - Dmg:%d Heat:%d\n" % [type_color.to_html(false), w_name, w_dmg, w_heat]
	
	mech_detail_label.text = details

func _on_next_to_weapons_pressed():
	# Navegar a configuración de armas
	_show_view(MechBayView.WEAPON_CONFIG)

func _update_weapon_config_view():
	# Actualizar resumen del mech
	var summary = "[b][color=cyan]%s[/color][/b]\n" % current_editing_mech.get("name", "Unknown")
	summary += "[color=yellow]%d tons[/color]\n\n" % current_editing_mech.get("tonnage", 0)
	summary += "Walk/Run/Jump:\n%d / %d / %d\n\n" % [
		current_editing_mech.get("walk_mp", 0),
		current_editing_mech.get("run_mp", 0),
		current_editing_mech.get("jump_mp", 0)
	]
	
	var total_armor = 0
	var armor_dict = current_editing_mech.get("armor", {})
	for location in armor_dict.keys():
		total_armor += armor_dict[location].get("max", 0)
	summary += "Armor: [color=cyan]%d[/color]\n" % total_armor
	summary += "Heat Cap: [color=orange]%d[/color]\n" % current_editing_mech.get("heat_capacity", 0)
	
	current_mech_summary.text = summary
	
	# Actualizar lista de armas
	for child in weapons_list.get_children():
		child.queue_free()
	
	var weapons = current_editing_mech.get("weapons", [])
	for i in range(weapons.size()):
		_create_weapon_row(i, weapons[i])
	
	# Botón para añadir arma
	var add_weapon_btn = Button.new()
	add_weapon_btn.text = "+ ADD WEAPON"
	add_weapon_btn.custom_minimum_size = Vector2(0, 50 * scale_factor)
	add_weapon_btn.add_theme_font_size_override("font_size", int(18 * scale_factor))
	add_weapon_btn.pressed.connect(_on_add_weapon_pressed)
	weapons_list.add_child(add_weapon_btn)
	
	# Actualizar heat capacity
	heatsinks_spinbox.value = current_editing_mech.get("heat_capacity", 10)

func _create_weapon_row(index: int, weapon: Dictionary):
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 45 * scale_factor)
	
	var weapon_label = Label.new()
	weapon_label.text = "%s (Dmg:%d Heat:%d)" % [
		weapon.get("name", "Unknown"),
		weapon.get("damage", 0),
		weapon.get("heat", 0)
	]
	weapon_label.add_theme_font_size_override("font_size", int(14 * scale_factor))
	weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(weapon_label)
	
	var edit_btn = Button.new()
	edit_btn.text = "Edit"
	edit_btn.custom_minimum_size = Vector2(60 * scale_factor, 0)
	edit_btn.add_theme_font_size_override("font_size", int(13 * scale_factor))
	edit_btn.pressed.connect(_on_edit_weapon_pressed.bind(index))
	hbox.add_child(edit_btn)
	
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.custom_minimum_size = Vector2(45 * scale_factor, 0)
	remove_btn.add_theme_font_size_override("font_size", int(16 * scale_factor))
	remove_btn.pressed.connect(_on_remove_weapon_pressed.bind(index))
	hbox.add_child(remove_btn)
	
	weapons_list.add_child(hbox)

func _on_add_weapon_pressed():
	# TODO: Implementar diálogo de selección de armas
	print("Add weapon dialog")
	var new_weapon = {
		"name": "Medium Laser",
		"damage": 5,
		"heat": 3,
		"min_range": 0,
		"short_range": 3,
		"medium_range": 6,
		"long_range": 9,
		"type": "energy"
	}
	current_editing_mech["weapons"].append(new_weapon)
	_update_weapon_config_view()

func _on_edit_weapon_pressed(index: int):
	# TODO: Implementar diálogo de edición de arma
	print("Edit weapon: ", index)

func _on_remove_weapon_pressed(index: int):
	if current_editing_mech.has("weapons"):
		var weapons = current_editing_mech["weapons"]
		if index >= 0 and index < weapons.size():
			weapons.remove_at(index)
			_update_weapon_config_view()

func _on_heatsinks_changed(value: float):
	if current_editing_mech:
		current_editing_mech["heat_capacity"] = int(value)

func _on_back_button_pressed():
	# Navegación hacia atrás
	match current_view:
		MechBayView.MECH_SELECTION:
			# Volver al menú principal
			emit_signal("mech_bay_closed")
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		
		MechBayView.WEAPON_CONFIG:
			# Volver a selección de mech
			_show_view(MechBayView.MECH_SELECTION)

func _on_save_and_exit_pressed():
	# Guardar configuración y salir
	if current_editing_index >= 0 and mech_bay_manager:
		var hangar = mech_bay_manager.get_player_hangar()
		if current_editing_index < hangar.size():
			hangar[current_editing_index] = current_editing_mech.duplicate(true)
			mech_bay_manager.save_hangar_to_file()
			emit_signal("mech_configuration_saved", current_editing_mech)
	
	emit_signal("mech_bay_closed")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
