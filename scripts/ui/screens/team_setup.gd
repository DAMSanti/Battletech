extends Control

# Sistema de configuración de equipo antes de la batalla
# Permite seleccionar hasta 4 mechs del hangar o rellenar con aleatorios

const MAX_LANCE_SIZE = 4
const SAVED_LOADOUTS_PATH = "user://saved_loadouts.json"

var mech_bay_manager: Node
var selected_mechs: Array = []  # Nombres de loadouts seleccionados para la batalla
var slot_panels: Array = []  # Referencias a los paneles de slots
var slot_labels: Array = []  # Labels que muestran info del mech en cada slot
var saved_loadouts: Dictionary = {}  # Loadouts guardados del Mech Bay

func _ready():
	# Música del menú (continúa si ya está sonando)
	if AudioManager:
		AudioManager.play_music(AudioManager.MUSIC_MENU)
	
	# Obtener referencia al MechBayManager
	mech_bay_manager = get_node_or_null("/root/MechBayManager")
	if not mech_bay_manager:
		push_error("MechBayManager not found!")
		return
	
	# Cargar loadouts guardados del Mech Bay
	_load_saved_loadouts()
	
	# Inicializar slots vacíos
	selected_mechs.resize(MAX_LANCE_SIZE)
	for i in range(MAX_LANCE_SIZE):
		selected_mechs[i] = ""  # String vacío significa slot vacío
	
	# Configurar título
	var title = $MarginContainer/VBoxContainer/Title
	title.add_theme_font_size_override("font_size", 32)
	
	# Configurar slots de la lance
	_setup_lance_slots()
	
	# Poblar lista de mechs disponibles
	_populate_available_mechs()
	
	# Conectar botones con sonido
	var fill_btn = $MarginContainer/VBoxContainer/ButtonsContainer/FillRandomButton
	var clear_btn = $MarginContainer/VBoxContainer/ButtonsContainer/ClearAllButton
	var back_btn = $MarginContainer/VBoxContainer/ActionsContainer/BackButton
	var start_btn = $MarginContainer/VBoxContainer/ActionsContainer/StartBattleButton
	
	fill_btn.pressed.connect(_play_click)
	fill_btn.pressed.connect(_on_fill_random_pressed)
	clear_btn.pressed.connect(_play_click)
	clear_btn.pressed.connect(_on_clear_all_pressed)
	back_btn.pressed.connect(_play_click)
	back_btn.pressed.connect(_on_back_pressed)
	start_btn.pressed.connect(_play_click)
	start_btn.pressed.connect(_on_start_battle_pressed)

func _play_click():
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)

func _load_saved_loadouts():
	# Cargar loadouts guardados desde saved_loadouts.json
	if not FileAccess.file_exists(SAVED_LOADOUTS_PATH):
		print("[TeamSetup] No saved loadouts found")
		saved_loadouts = {}
		return
	
	var file = FileAccess.open(SAVED_LOADOUTS_PATH, FileAccess.READ)
	if not file:
		push_error("Cannot open loadouts file")
		saved_loadouts = {}
		return
	
	# Leer usando get_var() porque el archivo está en formato binario de Godot
	var loaded_data = file.get_var()
	file.close()
	
	if loaded_data == null or typeof(loaded_data) != TYPE_DICTIONARY:
		push_error("Invalid loadouts data")
		saved_loadouts = {}
		return
	
	saved_loadouts = loaded_data
	print("[TeamSetup] Loaded %d saved loadouts" % saved_loadouts.size())
	
	# Debug: mostrar nombres de loadouts
	for loadout_name in saved_loadouts.keys():
		print("[TeamSetup] - Found loadout: %s" % loadout_name)

func _setup_lance_slots():
	# Configurar los 4 slots de la lance
	var lance_container = $MarginContainer/VBoxContainer/LanceContainer
	
	for i in range(MAX_LANCE_SIZE):
		var slot = lance_container.get_child(i)
		
		# Panel para el slot
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(200, 200)
		slot.add_child(panel)
		slot_panels.append(panel)
		
		# Container interior
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		panel.add_child(vbox)
		
		# Título del slot
		var slot_title = Label.new()
		slot_title.text = "SLOT %d" % (i + 1)
		slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_title.add_theme_font_size_override("font_size", 16)
		vbox.add_child(slot_title)
		
		# Separador
		var sep = HSeparator.new()
		vbox.add_child(sep)
		
		# Info del mech (o "Empty")
		var info_label = RichTextLabel.new()
		info_label.bbcode_enabled = true
		info_label.fit_content = true
		info_label.scroll_active = false
		info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		info_label.text = "[center][color=gray]Empty Slot[/color][/center]"
		vbox.add_child(info_label)
		slot_labels.append(info_label)
		
		# Botón para limpiar slot
		var clear_btn = Button.new()
		clear_btn.text = "Clear"
		clear_btn.custom_minimum_size = Vector2(0, 30)
		clear_btn.pressed.connect(_play_click)
		clear_btn.pressed.connect(_on_clear_slot_pressed.bind(i))
		vbox.add_child(clear_btn)

func _populate_available_mechs():
	# Poblar la lista de mechs disponibles del hangar
	var mech_list = $MarginContainer/VBoxContainer/MechListScroll/MechList
	
	# Limpiar lista existente
	for child in mech_list.get_children():
		child.queue_free()
	
	print("[TeamSetup] DEBUG - Saved loadouts count: %d" % saved_loadouts.size())
	
	if saved_loadouts.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No mechs in Mech Bay. Use 'Advanced Loadout' from main menu to create mechs."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mech_list.add_child(empty_label)
		return
	
	# Crear botón para cada loadout guardado
	for loadout_name in saved_loadouts.keys():
		var loadout = saved_loadouts[loadout_name]
		var mech_button = Button.new()
		
		# Mostrar info básica del mech
		var chassis = loadout.get("chassis", "Unknown")
		var tonnage = loadout.get("tonnage", 0)
		var is_selected = loadout_name in selected_mechs
		
		if is_selected:
			mech_button.text = "✓ %s - %s (%d tons) - SELECTED" % [loadout_name, chassis, tonnage]
			mech_button.disabled = true
		else:
			mech_button.text = "%s - %s (%d tons)" % [loadout_name, chassis, tonnage]
		
		mech_button.custom_minimum_size = Vector2(0, 40)
		mech_button.pressed.connect(_play_click)
		mech_button.pressed.connect(_on_mech_selected.bind(loadout_name))
		mech_list.add_child(mech_button)

func _on_mech_selected(loadout_name: String):
	# Añadir mech al primer slot disponible
	var slot_index = _find_first_empty_slot()
	
	if slot_index == -1:
		push_warning("No empty slots available")
		return
	
	selected_mechs[slot_index] = loadout_name
	_update_slot_display(slot_index)
	_populate_available_mechs()  # Actualizar lista

func _on_clear_slot_pressed(slot_index: int):
	# Limpiar un slot específico
	selected_mechs[slot_index] = ""
	_update_slot_display(slot_index)
	_populate_available_mechs()  # Actualizar lista

func _on_clear_all_pressed():
	# Limpiar todos los slots
	for i in range(MAX_LANCE_SIZE):
		selected_mechs[i] = ""
		_update_slot_display(i)
	_populate_available_mechs()

func _on_fill_random_pressed():
	# Rellenar slots vacíos con mechs del hangar o aleatorios
	var available_loadouts = saved_loadouts.keys()
	
	for i in range(MAX_LANCE_SIZE):
		if selected_mechs[i] == "":  # Si el slot está vacío
			if available_loadouts.size() > 0:
				# Intentar usar un loadout que no esté seleccionado
				var unused_loadouts = []
				for loadout_name in available_loadouts:
					if not loadout_name in selected_mechs:
						unused_loadouts.append(loadout_name)
				
				if unused_loadouts.size() > 0:
					selected_mechs[i] = unused_loadouts[randi() % unused_loadouts.size()]
				else:
					# Si todos están usados, generar uno aleatorio
					_assign_random_mech(i)
			else:
				# Si no hay loadouts guardados, generar uno aleatorio
				_assign_random_mech(i)
			
			_update_slot_display(i)
	
	_populate_available_mechs()

func _assign_random_mech(slot_index: int):
	# Asignar un mech aleatorio de la biblioteca (no del hangar)
	# Marca el slot con un nombre especial que indica que es generado
	
	var available_types = mech_bay_manager.get_available_mech_types()
	if available_types.size() == 0:
		return
	
	var random_type = available_types[randi() % available_types.size()]
	var variants = mech_bay_manager.get_variants_for_mech(random_type)
	if variants.size() == 0:
		return
	
	var random_variant = variants[randi() % variants.size()]
	
	# Almacenar la info del mech aleatorio
	var mech_data = mech_bay_manager.get_mech_data(random_type, random_variant)
	
	# Guardar el índice como especial (nombre que empieza con "RANDOM_")
	if not has_meta("generated_mechs"):
		set_meta("generated_mechs", {})
	
	var generated_mechs = get_meta("generated_mechs")
	var generated_name = "RANDOM_%d" % slot_index
	generated_mechs[generated_name] = mech_data
	selected_mechs[slot_index] = generated_name

func _update_slot_display(slot_index: int):
	# Actualizar la visualización de un slot
	var label = slot_labels[slot_index]
	
	if selected_mechs[slot_index] == "":
		# Slot vacío
		label.text = "[center][color=gray]Empty Slot[/color][/center]"
		return
	
	var loadout_name = selected_mechs[slot_index]
	var loadout_data: Dictionary
	
	# Verificar si es un mech generado aleatoriamente
	if loadout_name.begins_with("RANDOM_"):
		if has_meta("generated_mechs"):
			var generated_mechs = get_meta("generated_mechs")
			if generated_mechs.has(loadout_name):
				loadout_data = generated_mechs[loadout_name]
	else:
		# Es un loadout guardado
		if saved_loadouts.has(loadout_name):
			loadout_data = saved_loadouts[loadout_name]
	
	if loadout_data.is_empty():
		label.text = "[center][color=red]Error loading mech[/color][/center]"
		return
	
	# Mostrar info del mech
	var text = "[center]"
	
	# Para loadouts guardados mostrar el nombre personalizado
	if not loadout_name.begins_with("RANDOM_"):
		text += "[b]%s[/b]\n" % loadout_name
		text += "[color=gray]%s[/color]\n" % loadout_data.get("mech_name", "Unknown")
	else:
		text += "[b]%s[/b]\n" % loadout_data.get("name", "Unknown")
		text += "[color=yellow](Random)[/color]\n"
	
	var tonnage = loadout_data.get("mech_tonnage", loadout_data.get("tonnage", 0))
	text += "[color=yellow]%d tons[/color]\n\n" % tonnage
	
	# Calcular movimiento basado en el engine rating y tonelaje
	var engine_rating = loadout_data.get("engine_rating", 0)
	var walk_mp = 0
	var run_mp = 0
	if tonnage > 0 and engine_rating > 0:
		walk_mp = int(engine_rating / tonnage)
		run_mp = int(walk_mp * 1.5)
	
	# Si es un mech aleatorio (del hangar), usar los valores directos
	if loadout_name.begins_with("RANDOM_"):
		walk_mp = loadout_data.get("walk_mp", walk_mp)
		run_mp = loadout_data.get("run_mp", run_mp)
	
	var jump_mp = _count_jump_jets(loadout_data)
	
	text += "Move: %d/%d/%d\n" % [walk_mp, run_mp, jump_mp]
	
	# Calcular armadura total
	var total_armor = 0
	
	# Para loadouts guardados, calcular desde armor_weight o asignar default
	if loadout_data.has("loadout"):
		var armor_weight = loadout_data.get("armor_weight", 0.0)
		
		# Si no hay armadura configurada, asignar una por defecto
		if armor_weight <= 0.0:
			var mech_tonnage = loadout_data.get("mech_tonnage", 50)
			if mech_tonnage <= 20:
				armor_weight = mech_tonnage * 0.25
			elif mech_tonnage <= 55:
				armor_weight = mech_tonnage * 0.35
			elif mech_tonnage <= 75:
				armor_weight = mech_tonnage * 0.40
			else:
				armor_weight = mech_tonnage * 0.45
		
		total_armor = int(armor_weight * 16)  # 1 ton = 16 puntos
	else:
		# Para mechs aleatorios, usar el diccionario de armor
		var armor_dict = loadout_data.get("armor", {})
		for location in armor_dict.keys():
			if armor_dict[location] is Dictionary:
				total_armor += armor_dict[location].get("max", 0)
			elif armor_dict[location] is int:
				total_armor += armor_dict[location]
	
	text += "Armor: %d\n" % total_armor
	
	# Contar armas
	var weapons_count = _count_weapons(loadout_data)
	text += "Weapons: %d\n" % weapons_count
	text += "[/center]"
	
	label.text = text

func _count_jump_jets(loadout_data: Dictionary) -> int:
	# Contar jump jets en el loadout
	if not loadout_data.has("loadout"):
		return loadout_data.get("jump_mp", 0)
	
	var count = 0
	var locations = loadout_data.get("loadout", {})
	for location in locations.values():
		if location is Array:
			for component in location:
				if component is Dictionary and component.get("name", "").to_lower().contains("jump jet"):
					count += 1
	return count

func _count_weapons(loadout_data: Dictionary) -> int:
	# Contar armas en el loadout
	if loadout_data.has("weapons"):
		return loadout_data.get("weapons", []).size()
	
	if not loadout_data.has("loadout"):
		return 0
	
	var count = 0
	var locations = loadout_data.get("loadout", {})
	for location in locations.values():
		if location is Array:
			for component in location:
				if component is Dictionary:
					var comp_type = component.get("type", -1)
					# Tipos de armas: 1=Energy, 2=Ballistic, 3=Missile
					if comp_type in [1, 2, 3]:
						count += 1
	return count

func _find_first_empty_slot() -> int:
	# Encontrar el primer slot vacío
	for i in range(MAX_LANCE_SIZE):
		if selected_mechs[i] == "":
			return i
	return -1

func _on_back_pressed():
	# Volver al menú principal
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_start_battle_pressed():
	# Verificar que hay al menos un mech
	var has_mech = false
	for i in range(MAX_LANCE_SIZE):
		if selected_mechs[i] != "":
			has_mech = true
			break
	
	if not has_mech:
		push_warning("Need at least one mech to start battle!")
		return
	
	# Guardar la configuración de la lance en el MechBayManager
	_save_lance_configuration()
	
	# Iniciar batalla
	get_tree().change_scene_to_file("res://scenes/battle_scene_simple.tscn")

func _save_lance_configuration():
	# Guardar la configuración de la lance seleccionada para que la batalla la use
	var lance_data = []
	
	for i in range(MAX_LANCE_SIZE):
		if selected_mechs[i] == "":
			continue  # Slot vacío
		
		var loadout_name = selected_mechs[i]
		var loadout_data: Dictionary
		
		# Verificar si es un mech generado aleatoriamente
		if loadout_name.begins_with("RANDOM_"):
			if has_meta("generated_mechs"):
				var generated_mechs = get_meta("generated_mechs")
				if generated_mechs.has(loadout_name):
					loadout_data = generated_mechs[loadout_name].duplicate(true)
		else:
			# Es un loadout guardado - convertir al formato de batalla
			if saved_loadouts.has(loadout_name):
				var saved_loadout = saved_loadouts[loadout_name]
				loadout_data = _convert_loadout_to_battle_format(saved_loadout, loadout_name)
		
		if not loadout_data.is_empty():
			lance_data.append(loadout_data)
	
	# Guardar en el manager
	if mech_bay_manager.has_method("set_battle_lance"):
		mech_bay_manager.set_battle_lance(lance_data)
	else:
		# Temporalmente guardar en metadata del manager
		mech_bay_manager.set_meta("battle_lance", lance_data)
	
	print("[TeamSetup] Lance configuration saved: %d mechs" % lance_data.size())

func _convert_loadout_to_battle_format(loadout: Dictionary, custom_name: String) -> Dictionary:
	# Convertir un loadout guardado al formato que espera la batalla
	var mech_name = loadout.get("mech_name", "Unknown")
	var tonnage = loadout.get("mech_tonnage", 50)
	var engine_rating = loadout.get("engine_rating", 200)
	
	# Calcular movimiento
	var walk_mp = 0
	var run_mp = 0
	if tonnage > 0 and engine_rating > 0:
		walk_mp = int(engine_rating / tonnage)
		run_mp = int(walk_mp * 1.5)
	
	# Contar jump jets
	var jump_mp = _count_jump_jets(loadout)
	
	# Extraer armas del loadout
	var weapons = _extract_weapons_from_loadout(loadout)
	
	# Calcular armadura
	var armor = _extract_armor_from_loadout(loadout, tonnage)
	
	# Calcular heat capacity
	var heat_capacity = loadout.get("heat_sinks", 10) + 10  # Base 10 + heat sinks adicionales
	
	return {
		"name": custom_name,  # Nombre personalizado
		"mech_type": mech_name,  # Nombre del chassis
		"tonnage": tonnage,
		"walk_mp": walk_mp,
		"run_mp": run_mp,
		"jump_mp": jump_mp,
		"armor": armor,
		"weapons": weapons,
		"heat_capacity": heat_capacity,
		"gunnery_skill": 4  # Skill por defecto
	}

func _extract_weapons_from_loadout(loadout: Dictionary) -> Array:
	# Extraer armas del loadout guardado
	var weapons = []
	var locations = loadout.get("loadout", {})
	
	for location in locations.values():
		if location is Array:
			for component in location:
				if component is Dictionary:
					var comp_type = component.get("type", -1)
					var comp_name = component.get("name", "")
					
					# Tipos de armas: 1=Energy, 2=Ballistic, 3=Missile
					if comp_type in [1, 2, 3]:
						# Obtener stats del arma desde la base de datos de componentes
						var weapon_data = _get_weapon_stats(comp_name, comp_type)
						weapons.append(weapon_data)
	
	return weapons

func _get_weapon_stats(weapon_name: String, weapon_type: int) -> Dictionary:
	# Obtener estadísticas básicas de armas comunes
	# Esto es una simplificación - idealmente debería consultarse la base de datos
	var type_name = "energy"
	if weapon_type == 2:
		type_name = "ballistic"
	elif weapon_type == 3:
		type_name = "missile"
	
	# Stats por defecto basados en el nombre del arma
	var stats = {
		"name": weapon_name,
		"type": type_name,
		"damage": 5,
		"heat": 3,
		"min_range": 0,
		"short_range": 3,
		"medium_range": 6,
		"long_range": 9
	}
	
	# Ajustar basándose en nombres comunes
	if "AC/20" in weapon_name or "AC20" in weapon_name:
		stats.merge({"damage": 20, "heat": 7, "short_range": 3, "medium_range": 6, "long_range": 9}, true)
	elif "AC/10" in weapon_name or "AC10" in weapon_name:
		stats.merge({"damage": 10, "heat": 3, "short_range": 5, "medium_range": 10, "long_range": 15}, true)
	elif "AC/5" in weapon_name or "AC5" in weapon_name:
		stats.merge({"damage": 5, "heat": 1, "short_range": 6, "medium_range": 13, "long_range": 20}, true)
	elif "PPC" in weapon_name:
		stats.merge({"damage": 10, "heat": 10, "short_range": 6, "medium_range": 12, "long_range": 18}, true)
	elif "Large Laser" in weapon_name:
		stats.merge({"damage": 8, "heat": 8, "short_range": 5, "medium_range": 10, "long_range": 15}, true)
	elif "Medium Laser" in weapon_name:
		stats.merge({"damage": 5, "heat": 3, "short_range": 3, "medium_range": 6, "long_range": 9}, true)
	elif "Small Laser" in weapon_name:
		stats.merge({"damage": 3, "heat": 1, "short_range": 1, "medium_range": 2, "long_range": 3}, true)
	elif "LRM" in weapon_name:
		var lrm_damage = 20
		if "LRM 20" in weapon_name or "LRM-20" in weapon_name:
			lrm_damage = 20
		elif "LRM 15" in weapon_name or "LRM-15" in weapon_name:
			lrm_damage = 15
		elif "LRM 10" in weapon_name or "LRM-10" in weapon_name:
			lrm_damage = 10
		elif "LRM 5" in weapon_name or "LRM-5" in weapon_name:
			lrm_damage = 5
		stats.merge({"damage": lrm_damage, "heat": int(lrm_damage * 0.3), "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21}, true)
	elif "SRM" in weapon_name:
		var srm_damage = 12
		if "SRM 6" in weapon_name or "SRM-6" in weapon_name:
			srm_damage = 12
		elif "SRM 4" in weapon_name or "SRM-4" in weapon_name:
			srm_damage = 8
		elif "SRM 2" in weapon_name or "SRM-2" in weapon_name:
			srm_damage = 4
		stats.merge({"damage": srm_damage, "heat": int(srm_damage * 0.33), "short_range": 3, "medium_range": 6, "long_range": 9}, true)
	
	return stats

func _extract_armor_from_loadout(loadout: Dictionary, _tonnage: int) -> Dictionary:
	# Extraer armadura del loadout
	var armor_weight = loadout.get("armor_weight", 0.0)
	
	# Si no hay armadura configurada, asignar una por defecto según el tonelaje
	if armor_weight <= 0.0:
		var tonnage = loadout.get("mech_tonnage", 50)
		# Usar aproximadamente el 30-40% del tonelaje para armadura
		if tonnage <= 20:
			armor_weight = tonnage * 0.25  # Mechs ligeros tienen menos armadura relativa
		elif tonnage <= 55:
			armor_weight = tonnage * 0.35  # Mechs medios
		elif tonnage <= 75:
			armor_weight = tonnage * 0.40  # Mechs pesados
		else:
			armor_weight = tonnage * 0.45  # Mechs de asalto tienen más armadura relativa
	
	var total_armor_points = int(armor_weight * 16)  # 1 ton = 16 puntos
	
	# Distribuir armadura proporcionalmente según el tonelaje
	# Esto es una aproximación - idealmente debería guardarse la distribución exacta
	var armor = {
		"head": {"current": max(3, int(total_armor_points * 0.03)), "max": max(3, int(total_armor_points * 0.03))},
		"center_torso": {"current": int(total_armor_points * 0.15), "max": int(total_armor_points * 0.15)},
		"center_torso_rear": {"current": int(total_armor_points * 0.05), "max": int(total_armor_points * 0.05)},
		"left_torso": {"current": int(total_armor_points * 0.12), "max": int(total_armor_points * 0.12)},
		"left_torso_rear": {"current": int(total_armor_points * 0.04), "max": int(total_armor_points * 0.04)},
		"right_torso": {"current": int(total_armor_points * 0.12), "max": int(total_armor_points * 0.12)},
		"right_torso_rear": {"current": int(total_armor_points * 0.04), "max": int(total_armor_points * 0.04)},
		"left_arm": {"current": int(total_armor_points * 0.11), "max": int(total_armor_points * 0.11)},
		"right_arm": {"current": int(total_armor_points * 0.11), "max": int(total_armor_points * 0.11)},
		"left_leg": {"current": int(total_armor_points * 0.12), "max": int(total_armor_points * 0.12)},
		"right_leg": {"current": int(total_armor_points * 0.12), "max": int(total_armor_points * 0.12)}
	}
	
	return armor
