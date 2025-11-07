extends Control

# UI del Mech Bay - Sistema de customización de mechs

@onready var component_palette = $ComponentSelectorPopup/VBoxContainer/ScrollContainer/ComponentsList
@onready var mech_selector = $MainContainer/MechDisplay/VBoxContainer/MechSelector
@onready var weight_display = $MainContainer/MechDisplay/VBoxContainer/WeightDisplay
@onready var validation_panel = $MainContainer/BottomPanel/HBoxContainer/ValidationContainer/ValidationPanel
@onready var info_panel = $ComponentSelectorPopup/VBoxContainer/InfoPanel
@onready var stats_panel = $MainContainer/BottomPanel/HBoxContainer/StatsContainer/StatsPanel
@onready var save_button = $MainContainer/MechDisplay/VBoxContainer/ButtonsContainer/SaveButton
@onready var load_button = $MainContainer/MechDisplay/VBoxContainer/ButtonsContainer/LoadButton
@onready var apply_button = $MainContainer/BottomPanel/HBoxContainer/StatsContainer/ApplyButton
@onready var back_button = $TopBar/BackButton
@onready var component_popup = $ComponentSelectorPopup
@onready var popup_add_button = $ComponentSelectorPopup/VBoxContainer/ButtonContainer/AddButton
@onready var popup_cancel_button = $ComponentSelectorPopup/VBoxContainer/ButtonContainer/CancelButton
@onready var search_box = $ComponentSelectorPopup/VBoxContainer/SearchBox
@onready var save_loadout_popup = $SaveLoadoutPopup
@onready var loadout_name_input = $SaveLoadoutPopup/VBoxContainer/LoadoutNameInput
@onready var save_loadout_confirm_button = $SaveLoadoutPopup/VBoxContainer/ButtonContainer/SaveButton
@onready var save_loadout_cancel_button = $SaveLoadoutPopup/VBoxContainer/ButtonContainer/CancelButton
@onready var load_loadout_popup = $LoadLoadoutPopup
@onready var loadouts_list = $LoadLoadoutPopup/VBoxContainer/LoadoutsList
@onready var load_loadout_confirm_button = $LoadLoadoutPopup/VBoxContainer/ButtonContainer/LoadButton
@onready var load_loadout_cancel_button = $LoadLoadoutPopup/VBoxContainer/ButtonContainer/CancelButton
@onready var delete_loadout_button = $LoadLoadoutPopup/VBoxContainer/ButtonContainer/DeleteButton
@onready var location_panels = {}

var current_loadout: MechLoadout = null
var selected_component: Dictionary = {}
var dragging_component = false
var current_location_for_add: MechLoadout.MechLocation = -1  # Para saber a qué locación añadir

# Colores para feedback visual
const COLOR_VALID = Color(0.2, 0.8, 0.2)
const COLOR_WARNING = Color(0.9, 0.7, 0.2)
const COLOR_ERROR = Color(0.9, 0.2, 0.2)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7)

func _ready():
	_setup_ui()
	
	# Conectar botones
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Conectar botones del popup
	if popup_add_button:
		popup_add_button.pressed.connect(_on_popup_add_pressed)
	if popup_cancel_button:
		popup_cancel_button.pressed.connect(_on_popup_cancel_pressed)
	
	# Conectar búsqueda
	if search_box:
		search_box.text_changed.connect(_on_search_changed)
	
	# Conectar botones del popup de guardado
	if save_loadout_confirm_button:
		save_loadout_confirm_button.pressed.connect(_on_save_loadout_confirm)
	if save_loadout_cancel_button:
		save_loadout_cancel_button.pressed.connect(_on_save_loadout_cancel)
	
	# Conectar botones del popup de carga
	if load_loadout_confirm_button:
		load_loadout_confirm_button.pressed.connect(_on_load_loadout_confirm)
	if load_loadout_cancel_button:
		load_loadout_cancel_button.pressed.connect(_on_load_loadout_cancel)
	if delete_loadout_button:
		delete_loadout_button.pressed.connect(_on_delete_loadout)
	
	# Verificar si hay un loadout pendiente para editar desde el Mech Bay
	_check_for_loadout_to_edit()
	
	# Cargar mech de prueba DESPUÉS de crear la UI (solo si no hay loadout para editar)
	if not current_loadout:
		_load_test_mech()

func _setup_ui():
	# Configurar selector de mechs
	_setup_mech_selector()
	
	# Configurar scroll táctil para la lista de componentes
	if component_palette:
		# Habilitar scroll táctil natural
		component_palette.set_focus_mode(Control.FOCUS_NONE)  # Evitar que capture el foco
	
	# Configurar paneles de locaciones
	_create_location_panels()
	
	# Configurar paleta de componentes (en popup)
	_populate_component_palette()
	
	# Conectar señales
	if component_palette:
		component_palette.item_selected.connect(_on_component_selected)
	
	# Configurar popup
	if component_popup:
		component_popup.popup_hide.connect(_on_popup_hidden)

func _setup_mech_selector():
	if not mech_selector:
		return
	
	# Lista de mechs disponibles (puedes expandir esto)
	var available_mechs = [
		{"name": "Locust LCT-1V", "tonnage": 20, "engine": 160},
		{"name": "Commando COM-2D", "tonnage": 25, "engine": 150},
		{"name": "Urbanmech UM-R60", "tonnage": 30, "engine": 60},
		{"name": "Jenner JR7-D", "tonnage": 35, "engine": 245},
		{"name": "Hunchback HBK-4G", "tonnage": 50, "engine": 200},
		{"name": "Centurion CN9-A", "tonnage": 50, "engine": 200},
		{"name": "Enforcer ENF-4R", "tonnage": 50, "engine": 200},
		{"name": "Trebuchet TBT-5N", "tonnage": 50, "engine": 250},
		{"name": "Shadowhawk SHD-2H", "tonnage": 55, "engine": 275},
		{"name": "Griffin GRF-1N", "tonnage": 55, "engine": 275},
		{"name": "Wolverine WVR-6R", "tonnage": 55, "engine": 275},
		{"name": "Thunderbolt TDR-5S", "tonnage": 65, "engine": 260},
		{"name": "Catapult CPLT-C1", "tonnage": 65, "engine": 260},
		{"name": "Archer ARC-2R", "tonnage": 70, "engine": 280},
		{"name": "Warhammer WHM-6R", "tonnage": 70, "engine": 280},
		{"name": "Marauder MAD-3R", "tonnage": 75, "engine": 300},
		{"name": "Awesome AWS-8Q", "tonnage": 80, "engine": 240},
		{"name": "Victor VTR-9B", "tonnage": 80, "engine": 320},
		{"name": "Stalker STK-3F", "tonnage": 85, "engine": 255},
		{"name": "Atlas AS7-D", "tonnage": 100, "engine": 300}
	]
	
	# Añadir mechs al selector
	mech_selector.clear()
	for i in range(available_mechs.size()):
		var mech = available_mechs[i]
		mech_selector.add_item("%s (%d tons)" % [mech.name, mech.tonnage])
		mech_selector.set_item_metadata(i, mech)
	
	# Seleccionar el primero por defecto (Hunchback)
	mech_selector.select(4)  # Hunchback HBK-4G
	
	# Conectar señal de cambio
	mech_selector.item_selected.connect(_on_mech_selected)

func _create_location_panels():
	# Crear paneles para cada locación del mech en orden específico
	var locations_container = $MainContainer/MechDisplay/VBoxContainer/ScrollContainer/CenterContainer/LocationsContainer
	
	if not locations_container:
		push_warning("LocationsContainer no encontrado")
		return
	
	# Orden personalizado: 
	# Fila 1: Left Arm, Head, Right Arm
	# Fila 2: Left Torso, Center Torso, Right Torso
	# Fila 3: Left Leg, (espacio), Right Leg
	var location_order = [
		MechLoadout.MechLocation.LEFT_ARM,
		MechLoadout.MechLocation.HEAD,
		MechLoadout.MechLocation.RIGHT_ARM,
		MechLoadout.MechLocation.LEFT_TORSO,
		MechLoadout.MechLocation.CENTER_TORSO,
		MechLoadout.MechLocation.RIGHT_TORSO,
		MechLoadout.MechLocation.LEFT_LEG,
		-1,  # Espaciador vacío
		MechLoadout.MechLocation.RIGHT_LEG
	]
	
	for location in location_order:
		if location == -1:
			# Añadir panel vacío como espaciador
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(180, 220)
			locations_container.add_child(spacer)
		else:
			var panel = _create_location_panel(location)
			location_panels[location] = panel
			locations_container.add_child(panel)

func _create_location_panel(location: MechLoadout.MechLocation) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(180, 220)  # Más compacto
	
	# Estilo visual
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.3, 0.6, 0.8, 1.0)
	panel.add_theme_stylebox_override("panel", style_box)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 5
	vbox.offset_top = 5
	vbox.offset_right = -5
	vbox.offset_bottom = -5
	
	# Título de la locación (más compacto)
	var label = Label.new()
	label.text = MechLoadout.MechLocation.keys()[location]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(label)
	
	# Indicador de slots
	var slots_label = Label.new()
	slots_label.name = "SlotsLabel"
	slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slots_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(slots_label)
	
	# Lista de componentes instalados (más pequeña)
	var components_list = ItemList.new()
	components_list.name = "ComponentsList"
	components_list.custom_minimum_size = Vector2(0, 120)
	components_list.add_theme_font_size_override("font_size", 10)
	components_list.item_clicked.connect(_on_installed_component_clicked.bind(location))
	vbox.add_child(components_list)
	
	# Botón para añadir componente (más pequeño)
	var add_button = Button.new()
	add_button.text = "+"
	add_button.tooltip_text = "Add Component"
	add_button.custom_minimum_size = Vector2(0, 30)
	add_button.add_theme_font_size_override("font_size", 16)
	add_button.pressed.connect(_on_add_component_to_location.bind(location))
	vbox.add_child(add_button)
	
	# Configurar drop zone
	panel.set_meta("location", location)
	
	return panel

func _populate_component_palette(search_filter: String = ""):
	# Llenar la paleta con todos los componentes disponibles
	if not component_palette:
		return
	
	component_palette.clear()
	component_palette.add_theme_font_size_override("font_size", 11)  # Fuente más pequeña
	
	var filter_lower = search_filter.to_lower()
	
	# Añadir categorías y componentes
	_add_filtered_category("▼ ENERGY", ComponentDatabase.get_weapons_by_category(ComponentDatabase.WeaponCategory.ENERGY), filter_lower)
	_add_filtered_category("▼ BALLISTIC", ComponentDatabase.get_weapons_by_category(ComponentDatabase.WeaponCategory.BALLISTIC), filter_lower)
	_add_filtered_category("▼ MISSILE", ComponentDatabase.get_weapons_by_category(ComponentDatabase.WeaponCategory.MISSILE), filter_lower)
	_add_filtered_category("▼ AMMO", ComponentDatabase.get_all_ammo(), filter_lower)
	_add_filtered_category("▼ EQUIPMENT", ComponentDatabase.get_all_equipment(), filter_lower)

func _populate_component_palette_for_location(location: MechLoadout.MechLocation, search_filter: String = ""):
	# Llenar la paleta solo con componentes que se pueden montar en esta locación
	if not component_palette:
		return
	
	component_palette.clear()
	component_palette.add_theme_font_size_override("font_size", 11)
	
	var filter_lower = search_filter.to_lower()
	
	# Filtrar componentes por locación
	_add_filtered_category_for_location("▼ ENERGY", ComponentDatabase.get_weapons_by_category(ComponentDatabase.WeaponCategory.ENERGY), filter_lower, location)
	_add_filtered_category_for_location("▼ BALLISTIC", ComponentDatabase.get_weapons_by_category(ComponentDatabase.WeaponCategory.BALLISTIC), filter_lower, location)
	_add_filtered_category_for_location("▼ MISSILE", ComponentDatabase.get_weapons_by_category(ComponentDatabase.WeaponCategory.MISSILE), filter_lower, location)
	_add_filtered_category_for_location("▼ AMMO", ComponentDatabase.get_all_ammo(), filter_lower, location)
	_add_filtered_category_for_location("▼ EQUIPMENT", ComponentDatabase.get_all_equipment(), filter_lower, location)

func _add_filtered_category(category_name: String, components: Array, filter: String):
	if not component_palette:
		return
	
	var added_components = 0
	var category_index = -1
	
	# Si no hay filtro o algún componente coincide, añadir categoría
	for component in components:
		var name_lower = component.get("name", "").to_lower()
		if filter == "" or name_lower.contains(filter):
			# Añadir categoría solo una vez
			if category_index == -1:
				category_index = component_palette.add_item(category_name)
				component_palette.set_item_disabled(category_index, true)
				component_palette.set_item_custom_fg_color(category_index, Color.GOLD)
				component_palette.set_item_custom_bg_color(category_index, Color(0.2, 0.2, 0.3, 1.0))
			
			_add_component_to_palette(component)
			added_components += 1

func _add_filtered_category_for_location(category_name: String, components: Array, filter: String, location: MechLoadout.MechLocation):
	if not component_palette or not current_loadout:
		return
	
	var added_components = 0
	var category_index = -1
	
	# Obtener límites actuales
	var available_slots = current_loadout.get_available_slots(location)
	var available_weight = current_loadout.get_available_weight()
	
	# Si no hay filtro o algún componente coincide, añadir categoría
	for component in components:
		var name_lower = component.get("name", "").to_lower()
		if filter == "" or name_lower.contains(filter):
			# Verificar si se puede montar en esta locación
			if not current_loadout.can_mount_in_location(component, location):
				continue
			
			# Verificar si hay slots suficientes
			var required_slots = component.get("slots", 0)
			if required_slots > available_slots:
				continue
			
			# Verificar si hay peso suficiente
			var component_weight = component.get("weight", 0.0)
			# Para jump jets, calcular peso dinámicamente
			if component.get("id", "") == "jump_jet":
				component_weight = ComponentDatabase.calculate_jump_jet_weight(current_loadout.mech_tonnage)
			
			if component_weight > available_weight:
				continue
			
			# Si pasa todos los filtros, añadir
			# Añadir categoría solo una vez
			if category_index == -1:
				category_index = component_palette.add_item(category_name)
				component_palette.set_item_disabled(category_index, true)
				component_palette.set_item_custom_fg_color(category_index, Color.GOLD)
				component_palette.set_item_custom_bg_color(category_index, Color(0.2, 0.2, 0.3, 1.0))
			
			_add_component_to_palette(component)
			added_components += 1



func _add_component_to_palette(component: Dictionary):
	if not component_palette:
		return
	
	# Formato más compacto
	var display_text = "%s" % component.get("name", "Unknown")
	
	# Info compacta entre paréntesis
	var info_parts = []
	info_parts.append("%.1ft" % component.get("weight", 0.0))
	info_parts.append("%ds" % component.get("slots", 0))
	
	# Añadir info adicional para armas
	if component.has("damage"):
		info_parts.append("D%d" % component.get("damage", 0))
		info_parts.append("H%d" % component.get("heat", 0))
	
	display_text += " (%s)" % ", ".join(info_parts)
	
	var index = component_palette.add_item(display_text)
	component_palette.set_item_metadata(index, component)

func _on_component_selected(index: int):
	if not component_palette:
		return
	
	selected_component = component_palette.get_item_metadata(index)
	
	if selected_component and selected_component.size() > 0:
		_show_component_info(selected_component)

func _show_component_info(component: Dictionary):
	# Mostrar información detallada del componente seleccionado
	if not info_panel:
		return
	
	var info_text = "[b][color=cyan]%s[/color][/b]\n" % component.get("name", "Unknown")
	info_text += "[color=gray]Weight:[/color] %.1ft  [color=gray]Slots:[/color] %d\n" % [
		component.get("weight", 0.0),
		component.get("slots", 0)
	]
	
	if component.has("damage"):
		info_text += "[color=orange]Damage:[/color] %d  [color=red]Heat:[/color] %d\n" % [
			component["damage"],
			component["heat"]
		]
	
	if component.has("range_short"):
		info_text += "[color=green]Range:[/color] %d/%d/%d\n" % [
			component.get("range_short", 0),
			component.get("range_medium", 0),
			component.get("range_long", 0)
		]
	
	if component.has("description"):
		info_text += "\n[color=gray][i]%s[/i][/color]" % component["description"]
	
	info_panel.text = info_text

func _on_add_component_to_location(location: MechLoadout.MechLocation):
	# Guardar la locación actual y mostrar popup
	current_location_for_add = location
	selected_component = {}
	
	if component_popup:
		# Centrar el popup (convertir Vector2i a Vector2)
		var viewport_size = get_viewport().get_visible_rect().size
		var popup_size = Vector2(component_popup.size)  # Convertir Vector2i a Vector2
		component_popup.position = Vector2i((viewport_size - popup_size) / 2)
		
		# Actualizar el título del popup
		var title_label = component_popup.find_child("Title")
		if title_label:
			title_label.text = "Add Component to %s" % MechLoadout.MechLocation.keys()[location]
		
		# Repoblar la lista de componentes filtrada por locación
		_populate_component_palette_for_location(location, "")
		
		component_popup.popup()

func _on_installed_component_clicked(index: int, at_position: Vector2, mouse_button_index: int, location: MechLoadout.MechLocation):
	# Clic derecho para eliminar
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		# Calcular el índice real del componente (sin contar los fijos)
		var fixed_count = 0
		
		# Contar componentes fijos
		if MechLoadout.FIXED_COMPONENTS.has(location):
			fixed_count += MechLoadout.FIXED_COMPONENTS[location].size()
		
		# Para Center Torso, añadir engine y gyro
		if location == MechLoadout.MechLocation.CENTER_TORSO:
			if current_loadout._calculate_engine_slots() > 0:
				fixed_count += 1
			if current_loadout._calculate_gyro_slots() > 0:
				fixed_count += 1
		
		# El índice del componente del usuario es: index - fixed_count
		var user_component_index = index - fixed_count
		
		# Solo permitir eliminar componentes del usuario (no fijos)
		if user_component_index >= 0:
			if current_loadout.remove_component(location, user_component_index):
				_show_message("Componente eliminado", COLOR_VALID)
				_refresh_location_display(location)
				_update_weight_display()
				_validate_loadout()
		else:
			_show_message("No puedes eliminar componentes fijos", COLOR_WARNING)

func _refresh_location_display(location: MechLoadout.MechLocation):
	if not location_panels.has(location):
		print("[DEBUG] Location panel not found for: ", MechLoadout.MechLocation.keys()[location])
		return
	
	var panel = location_panels[location]
	
	# Buscar nodos hijos directamente
	var components_list = null
	var slots_label = null
	
	for child in panel.get_children():
		if child is VBoxContainer:
			for subchild in child.get_children():
				if subchild.name == "ComponentsList":
					components_list = subchild
				elif subchild.name == "SlotsLabel":
					slots_label = subchild
	
	if not components_list:
		print("[DEBUG] ComponentsList not found in panel!")
		print("[DEBUG] Panel children: ", panel.get_children())
		return
		
	if not slots_label:
		print("[DEBUG] SlotsLabel not found in panel!")
		return
		
	if not current_loadout:
		print("[DEBUG] No current_loadout!")
		return
	
	print("[DEBUG] Refreshing location: ", MechLoadout.MechLocation.keys()[location])
	
	# Actualizar lista de componentes (formato compacto)
	components_list.clear()
	
	# Primero añadir componentes fijos (deshabilitados y en gris)
	if MechLoadout.FIXED_COMPONENTS.has(location):
		for fixed_comp in MechLoadout.FIXED_COMPONENTS[location]:
			var idx = components_list.add_item("[FIXED] %s" % fixed_comp.get("name", "?"))
			components_list.set_item_disabled(idx, true)
			components_list.set_item_custom_fg_color(idx, Color.DARK_GRAY)
	
	# Para Center Torso, mostrar engine y gyro
	if location == MechLoadout.MechLocation.CENTER_TORSO:
		var engine_slots = current_loadout._calculate_engine_slots()
		if engine_slots > 0:
			var idx = components_list.add_item("[FIXED] Engine (%d slots)" % engine_slots)
			components_list.set_item_disabled(idx, true)
			components_list.set_item_custom_fg_color(idx, Color.DARK_GRAY)
		
		var gyro_slots = current_loadout._calculate_gyro_slots()
		if gyro_slots > 0:
			var idx = components_list.add_item("[FIXED] Gyro (%d slots)" % gyro_slots)
			components_list.set_item_disabled(idx, true)
			components_list.set_item_custom_fg_color(idx, Color.DARK_GRAY)
	
	# Luego añadir componentes instalados por el usuario
	if current_loadout.loadout.has(location):
		print("[DEBUG] Components in location: ", current_loadout.loadout[location].size())
		for component in current_loadout.loadout[location]:
			var display_text = "%s" % component.get("name", "?")
			# Añadir solo info crítica
			if component.has("damage"):
				display_text += " [D%d]" % component.get("damage", 0)
			components_list.add_item(display_text)
			print("[DEBUG] Added component to list: ", display_text)
	else:
		print("[DEBUG] Location has no components yet")
	
	# Actualizar contador de slots
	var available = current_loadout.get_available_slots(location)
	var total = MechLoadout.CRITICAL_SLOTS[location]
	var used = total - available
	
	slots_label.text = "Slots: %d/%d" % [used, total]
	print("[DEBUG] Slots updated: ", slots_label.text)
	
	# Color coding
	if available < 0:
		slots_label.modulate = COLOR_ERROR
	elif available < 2:
		slots_label.modulate = COLOR_WARNING
	else:
		slots_label.modulate = COLOR_VALID

func _refresh_all_locations():
	for location in location_panels.keys():
		_refresh_location_display(location)

func _update_weight_display():
	if not weight_display or not current_loadout:
		return
	
	var summary = current_loadout.get_loadout_summary()
	
	weight_display.text = "Weight: %.1f / %d tons (%.1f available)" % [
		summary["current_weight"],
		summary["tonnage"],
		summary["available_weight"]
	]
	
	# Color coding
	if summary["available_weight"] < 0:
		weight_display.modulate = COLOR_ERROR
	elif summary["available_weight"] < 2:
		weight_display.modulate = COLOR_WARNING
	else:
		weight_display.modulate = COLOR_VALID
	
	# Actualizar panel de estadísticas
	_update_stats_panel(summary)

func _update_stats_panel(summary: Dictionary):
	if not stats_panel:
		return
	
	var stats_text = "[b]Weapons:[/b] [color=cyan]%d[/color]\n" % summary.get("weapons_count", 0)
	stats_text += "[b]Heat:[/b] [color=orange]%d[/color]\n" % summary.get("total_heat", 0)
	stats_text += "[b]Damage:[/b] [color=red]%d[/color]\n" % summary.get("total_damage", 0)
	stats_text += "[b]Engine:[/b] [color=green]%d[/color]\n" % summary.get("engine_rating", 0)
	
	stats_panel.text = stats_text

func _validate_loadout():
	if not current_loadout or not validation_panel:
		return
	
	var validation = current_loadout.is_valid_loadout()
	
	validation_panel.clear()
	
	if validation["valid"]:
		validation_panel.add_item("✓ Loadout válido")
		validation_panel.set_item_custom_fg_color(0, COLOR_VALID)
	else:
		for error in validation["errors"]:
			var index = validation_panel.add_item("✗ " + error)
			validation_panel.set_item_custom_fg_color(index, COLOR_ERROR)
	
	for warning in validation["warnings"]:
		var index = validation_panel.add_item("⚠ " + warning)
		validation_panel.set_item_custom_fg_color(index, COLOR_WARNING)

func _show_message(message: String, color: Color = COLOR_NORMAL):
	# Mostrar mensaje temporal
	print("[MechBay] ", message)
	# TODO: Añadir toast notification visual

func _load_test_mech():
	# El mech inicial se carga automáticamente del selector
	# Triggear la selección del mech por defecto
	if mech_selector and mech_selector.item_count > 0:
		_on_mech_selected(mech_selector.selected)

# Funciones de guardado/carga
func save_loadout(filepath: String) -> bool:
	if not current_loadout:
		return false
	
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if not file:
		push_error("No se pudo abrir archivo para escribir: " + filepath)
		return false
	
	var data = current_loadout.to_dict()
	file.store_var(data)
	file.close()
	
	_show_message("Loadout guardado", COLOR_VALID)
	return true

func load_loadout(filepath: String) -> bool:
	var file = FileAccess.open(filepath, FileAccess.READ)
	if not file:
		push_error("No se pudo abrir archivo: " + filepath)
		return false
	
	var data = file.get_var()
	file.close()
	
	if not data or typeof(data) != TYPE_DICTIONARY:
		push_error("Datos de loadout inválidos")
		return false
	
	current_loadout = MechLoadout.new()
	current_loadout.from_dict(data)
	
	_refresh_all_locations()
	_update_weight_display()
	_validate_loadout()
	
	_show_message("Loadout cargado: " + current_loadout.mech_name, COLOR_VALID)
	return true

func get_current_loadout() -> MechLoadout:
	return current_loadout

func _check_for_loadout_to_edit():
	# Verificar si hay un loadout seleccionado desde el Mech Bay screen
	if has_node("/root/SelectedLoadoutManager"):
		var manager = get_node("/root/SelectedLoadoutManager")
		var loadout_data = manager.get_selected_loadout()
		
		if loadout_data != null and not loadout_data.is_empty():
			print("[MechBayUI] Cargando loadout para editar: ", loadout_data.get("mech_name", "Unknown"))
			load_loadout_from_dict(loadout_data)
			# Limpiar el manager después de cargar
			manager.clear_selection()

func load_loadout_from_dict(data: Dictionary) -> bool:
	# Cargar un loadout desde un diccionario (usado cuando se edita desde Mech Bay)
	if not data or data.is_empty():
		push_error("Datos de loadout inválidos o vacíos")
		return false
	
	print("[MechBayUI] Creando MechLoadout desde diccionario...")
	current_loadout = MechLoadout.new()
	current_loadout.from_dict(data)
	
	print("[MechBayUI] Loadout cargado: ", current_loadout.mech_name)
	print("[MechBayUI] Peso actual: ", current_loadout.current_weight)
	
	_refresh_all_locations()
	_update_weight_display()
	_validate_loadout()
	
	_show_message("Loadout cargado: " + current_loadout.mech_name, COLOR_VALID)
	return true

# Handlers de botones
func _on_save_pressed():
	# Abrir popup para pedir nombre del loadout
	if not current_loadout:
		_show_message("No hay loadout para guardar", COLOR_ERROR)
		return
	
	if save_loadout_popup and loadout_name_input:
		# Sugerir nombre basado en el mech
		loadout_name_input.text = current_loadout.mech_name
		loadout_name_input.select_all()
		
		# Centrar popup
		var viewport_size = get_viewport().get_visible_rect().size
		var popup_size = Vector2(save_loadout_popup.size)
		save_loadout_popup.position = Vector2i((viewport_size - popup_size) / 2)
		
		save_loadout_popup.popup()
		loadout_name_input.grab_focus()

func _on_load_pressed():
	# Abrir popup con lista de loadouts guardados
	if not load_loadout_popup or not loadouts_list:
		return
	
	# Cargar lista de loadouts
	var save_path = "user://saved_loadouts.json"
	if not FileAccess.file_exists(save_path):
		_show_message("No hay loadouts guardados", COLOR_WARNING)
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		_show_message("Error al cargar loadouts", COLOR_ERROR)
		return
	
	var saved_loadouts = file.get_var()
	file.close()
	
	# Llenar lista
	loadouts_list.clear()
	for loadout_name in saved_loadouts.keys():
		var loadout_data = saved_loadouts[loadout_name]
		var display_text = "%s (%s, %d tons)" % [
			loadout_name,
			loadout_data.get("mech_name", "Unknown"),
			loadout_data.get("mech_tonnage", 0)
		]
		var index = loadouts_list.add_item(display_text)
		loadouts_list.set_item_metadata(index, loadout_name)
	
	# Centrar y mostrar popup
	var viewport_size = get_viewport().get_visible_rect().size
	var popup_size = Vector2(load_loadout_popup.size)
	load_loadout_popup.position = Vector2i((viewport_size - popup_size) / 2)
	
	load_loadout_popup.popup()

func _on_apply_pressed():
	if not current_loadout:
		_show_message("No hay loadout para aplicar", COLOR_ERROR)
		return
	
	var validation = current_loadout.is_valid_loadout()
	if not validation["valid"]:
		_show_message("El loadout tiene errores, corrígelos primero", COLOR_ERROR)
		return
	
	_show_message("Loadout aplicado al mech", COLOR_VALID)
	# TODO: Integrar con sistema de batalla
	# Emit signal o llamar a función para actualizar el mech en batalla

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Funciones del popup de selección de componentes
func _on_popup_add_pressed():
	if not selected_component or selected_component.size() == 0:
		_show_message("Selecciona un componente primero", COLOR_WARNING)
		return
	
	if not current_loadout or current_location_for_add < 0:
		_show_message("Error: no hay locación seleccionada", COLOR_ERROR)
		return
	
	# Intentar añadir el componente
	if current_loadout.add_component(current_location_for_add, selected_component):
		_show_message("Componente añadido: %s" % selected_component.get("name", "Unknown"), COLOR_VALID)
		_refresh_location_display(current_location_for_add)
		_update_weight_display()
		_validate_loadout()
		
		# Cerrar popup
		if component_popup:
			component_popup.hide()
	else:
		_show_message("No se puede añadir el componente", COLOR_ERROR)

func _on_popup_cancel_pressed():
	if component_popup:
		component_popup.hide()
	selected_component = {}
	current_location_for_add = -1

func _on_popup_hidden():
	selected_component = {}
	current_location_for_add = -1

func _on_search_changed(new_text: String):
	# Filtrar componentes según búsqueda
	# Si tenemos una locación seleccionada, filtrar por ella también
	if current_location_for_add != -1:
		_populate_component_palette_for_location(current_location_for_add, new_text)
	else:
		_populate_component_palette(new_text)

func _on_mech_selected(index: int):
	if not mech_selector:
		return
	
	var mech_data = mech_selector.get_item_metadata(index)
	if not mech_data:
		return
	
	# Crear nuevo loadout con los datos del mech seleccionado
	current_loadout = MechLoadout.new()
	current_loadout.mech_name = mech_data.name
	current_loadout.mech_tonnage = mech_data.tonnage
	current_loadout.engine_rating = mech_data.engine
	
	# IMPORTANTE: Recalcular peso después de cambiar tonnage y engine
	current_loadout._recalculate_weight()
	
	# Actualizar UI
	_refresh_all_locations()
	_update_weight_display()
	_validate_loadout()
	
	_show_message("Mech cargado: %s" % mech_data.name, COLOR_VALID)

func _on_save_loadout_confirm():
	if not loadout_name_input or not current_loadout:
		return
	
	var loadout_name = loadout_name_input.text.strip_edges()
	
	if loadout_name == "":
		_show_message("Debes introducir un nombre", COLOR_WARNING)
		return
	
	# Guardar el loadout con el nombre personalizado
	var save_path = "user://saved_loadouts.json"
	
	# Cargar loadouts existentes
	var saved_loadouts = {}
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file:
			saved_loadouts = file.get_var()
			file.close()
	
	# Añadir/actualizar el loadout actual
	saved_loadouts[loadout_name] = current_loadout.to_dict()
	
	# Guardar de vuelta
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_var(saved_loadouts)
		file.close()
		_show_message("Loadout '%s' guardado" % loadout_name, COLOR_VALID)
		save_loadout_popup.hide()
	else:
		_show_message("Error al guardar", COLOR_ERROR)

func _on_save_loadout_cancel():
	if save_loadout_popup:
		save_loadout_popup.hide()

func _on_load_loadout_confirm():
	if not loadouts_list:
		return
	
	var selected_items = loadouts_list.get_selected_items()
	if selected_items.size() == 0:
		_show_message("Selecciona un loadout primero", COLOR_WARNING)
		return
	
	var loadout_name = loadouts_list.get_item_metadata(selected_items[0])
	
	# Cargar el loadout
	var save_path = "user://saved_loadouts.json"
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		_show_message("Error al cargar", COLOR_ERROR)
		return
	
	var saved_loadouts = file.get_var()
	file.close()
	
	if not saved_loadouts.has(loadout_name):
		_show_message("Loadout no encontrado", COLOR_ERROR)
		return
	
	# Crear nuevo loadout desde los datos guardados
	current_loadout = MechLoadout.new()
	current_loadout.from_dict(saved_loadouts[loadout_name])
	
	# Actualizar UI
	_refresh_all_locations()
	_update_weight_display()
	_validate_loadout()
	
	_show_message("Loadout '%s' cargado" % loadout_name, COLOR_VALID)
	load_loadout_popup.hide()

func _on_load_loadout_cancel():
	if load_loadout_popup:
		load_loadout_popup.hide()

func _on_delete_loadout():
	if not loadouts_list:
		return
	
	var selected_items = loadouts_list.get_selected_items()
	if selected_items.size() == 0:
		_show_message("Selecciona un loadout primero", COLOR_WARNING)
		return
	
	var loadout_name = loadouts_list.get_item_metadata(selected_items[0])
	
	# Cargar loadouts
	var save_path = "user://saved_loadouts.json"
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return
	
	var saved_loadouts = file.get_var()
	file.close()
	
	# Eliminar el loadout
	saved_loadouts.erase(loadout_name)
	
	# Guardar de vuelta
	file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_var(saved_loadouts)
		file.close()
		_show_message("Loadout '%s' eliminado" % loadout_name, COLOR_WARNING)
		
		# Actualizar lista
		_on_load_pressed()
