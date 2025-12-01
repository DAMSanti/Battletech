## MechFactory - Factory para creación de mechs
## Centraliza la lógica de instanciación y configuración de mechs
class_name MechFactory
extends RefCounted

## Referencia a la escena de mech (opcional)
var mech_scene: PackedScene = null

## Referencia al hex_grid para posicionamiento
var hex_grid: HexGrid = null

## Modo multiplayer
var is_multiplayer_mode: bool = false

## Equipo del jugador (para multiplayer)
var my_team: String = ""


func _init() -> void:
	# Intentar cargar la escena de mech
	if ResourceLoader.exists("res://scenes/mech.tscn"):
		mech_scene = load("res://scenes/mech.tscn")


## Configura el factory con las referencias necesarias
func configure(p_hex_grid: HexGrid, p_is_multiplayer: bool, p_my_team: String = "") -> void:
	hex_grid = p_hex_grid
	is_multiplayer_mode = p_is_multiplayer
	my_team = p_my_team


## Crea un mech para la fase de deployment (sin colocar en el mapa)
func create_for_deployment(mech_data: Dictionary, team: String) -> Mech:
	var mech = Mech.new()
	_apply_base_data(mech, mech_data)
	_apply_combat_data(mech, mech_data)
	_configure_control(mech, team)
	
	mech.z_index = 10
	mech.set_meta("team", team)
	
	return mech


## Crea un mech desde datos de red (multiplayer)
func create_from_network(mech_id: int, mech_data: Dictionary, hex_pos: Vector2i, facing: int, team: String) -> Mech:
	var mech: Mech
	
	if mech_scene:
		mech = mech_scene.instantiate()
	else:
		# Crear nuevo mech instanciando la clase directamente
		mech = Mech.new()
	
	_apply_base_data(mech, mech_data)
	_apply_combat_data(mech, mech_data)
	_configure_control(mech, team)
	
	# Datos específicos de red
	mech.set_meta("network_id", mech_id)
	mech.set_meta("team", team)
	mech.hex_position = hex_pos
	mech.facing = facing
	
	Log.debug("Mech", "MechFactory: Created %s with facing=%d at [%d,%d]" % [
		mech.mech_name, mech.facing, hex_pos.x, hex_pos.y
	])
	
	return mech


## Crea un mech del jugador desde datos completos y lo posiciona
func create_player_mech(mech_data: Dictionary, hex_position: Vector2i) -> Mech:
	var mech = create_for_deployment(mech_data, "player")
	_position_mech(mech, hex_position)
	return mech


## Crea un mech enemigo desde datos completos y lo posiciona
func create_enemy_mech(mech_data: Dictionary, hex_position: Vector2i) -> Mech:
	var mech = create_for_deployment(mech_data, "enemy")
	_position_mech(mech, hex_position)
	return mech


## Crea un mech básico con parámetros mínimos (legacy support)
func create_basic(
	mech_name: String, 
	mech_position: Vector2i, 
	tonnage: int, 
	walk: int, 
	run: int, 
	jump: int, 
	team: String
) -> Mech:
	var mech = Mech.new()
	mech.mech_name = mech_name
	mech.tonnage = tonnage
	mech.walk_mp = walk
	mech.run_mp = run
	mech.jump_mp = jump
	mech.current_movement = walk
	mech.z_index = 10
	mech.pilot_name = "Pilot"
	mech.set_meta("team", team)
	
	_configure_control(mech, team)
	_position_mech(mech, mech_position)
	
	return mech


# ==============================================================================
# MÉTODOS PRIVADOS
# ==============================================================================

## Aplica datos base al mech
func _apply_base_data(mech: Mech, data: Dictionary) -> void:
	mech.mech_name = data.get("name", "Unknown")
	mech.pilot_name = data.get("pilot_name", "Pilot")
	mech.tonnage = data.get("tonnage", 50)
	mech.walk_mp = data.get("walk_mp", 4)
	mech.run_mp = data.get("run_mp", 6)
	mech.jump_mp = data.get("jump_mp", 0)
	mech.current_movement = mech.walk_mp


## Aplica datos de combate al mech
func _apply_combat_data(mech: Mech, data: Dictionary) -> void:
	# Armadura
	if data.has("armor"):
		mech.armor = data["armor"].duplicate(true)
	
	# Estructura interna
	if data.has("internal_structure"):
		mech.structure = data["internal_structure"].duplicate(true)
	elif data.has("structure"):
		mech.structure = data["structure"].duplicate(true)
	
	# Armas
	if data.has("weapons"):
		mech.weapons = data["weapons"].duplicate(true)
		Log.debug("Mech", "%s: %d weapons loaded" % [mech.mech_name, mech.weapons.size()])
	else:
		Log.warning("Mech", "%s has NO weapons!" % mech.mech_name)
	
	# Equipamiento
	if data.has("equipment"):
		mech.equipment = data["equipment"].duplicate(true)
	
	# Critical slots
	if data.has("critical_slots"):
		mech.critical_slots = data["critical_slots"].duplicate(true)
	
	# Munición (añadir a equipment)
	if data.has("ammo"):
		for ammo_item in data["ammo"]:
			mech.equipment.append(ammo_item.duplicate(true))
	
	# Heat
	if data.has("heat_capacity"):
		mech.heat_capacity = data["heat_capacity"]
	if data.has("heat_dissipation"):
		mech.heat_dissipation = data["heat_dissipation"]
	
	# Skills
	if data.has("gunnery_skill"):
		mech.pilot_skill = data["gunnery_skill"]
	if data.has("piloting_skill"):
		mech.piloting_skill = data["piloting_skill"]


## Configura el control del mech (player vs AI)
func _configure_control(mech: Mech, team: String) -> void:
	if is_multiplayer_mode:
		mech.is_player_controlled = (team == my_team)
	else:
		mech.is_player_controlled = (team == "player")
	
	# Pilot name basado en equipo
	if not mech.pilot_name or mech.pilot_name == "Pilot":
		mech.pilot_name = "Player" if team == "player" else "Enemy"


## Posiciona el mech en un hex
func _position_mech(mech: Mech, hex_pos: Vector2i) -> void:
	if not hex_grid:
		Log.warning("Mech", "MechFactory: hex_grid not set, cannot position mech")
		return
	
	mech.hex_position = hex_pos
	var pixel_pos = hex_grid.hex_to_pixel(hex_pos)
	mech.position = pixel_pos + hex_grid.global_position
	mech.z_index = 10
	
	if mech.has_method("update_visual_position"):
		mech.update_visual_position(hex_grid)


# ==============================================================================
# CONVERSIÓN DE LOADOUT A MECH DATA
# ==============================================================================

## Convierte un loadout del Mech Bay al formato de mech_data para batalla
func convert_loadout_to_mech_data(loadout: Dictionary) -> Dictionary:
	var mech_data = {}
	
	# Datos básicos del mech
	mech_data["name"] = loadout.get("mech_name", "Custom Mech")
	mech_data["tonnage"] = loadout.get("mech_tonnage", 50)
	var engine_rating = loadout.get("engine_rating", 200)
	
	# Calcular movimiento basado en engine rating y tonnage
	var walk_mp = int(engine_rating / mech_data["tonnage"])
	mech_data["walk_mp"] = walk_mp
	mech_data["run_mp"] = int(walk_mp * 1.5)
	
	# Contar jump jets en el loadout
	var jump_jet_count = 0
	var loadout_components = loadout.get("loadout", {})
	for location in loadout_components.keys():
		for component in loadout_components[location]:
			if component.get("id", "") == "jump_jet":
				jump_jet_count += 1
	mech_data["jump_mp"] = jump_jet_count
	
	# Extraer componentes
	var weapons = []
	var equipment = []
	var critical_slots = {
		"head": [], "center_torso": [], "left_torso": [], "right_torso": [],
		"left_arm": [], "right_arm": [], "left_leg": [], "right_leg": []
	}
	var ammo = []
	
	for location in loadout_components.keys():
		var location_str = _convert_location_to_string(location)
		for component in loadout_components[location]:
			var comp_type = component.get("type", -1)
			var comp_copy = component.duplicate(true)
			comp_copy["location"] = location_str
			
			if critical_slots.has(location_str):
				critical_slots[location_str].append(comp_copy)
			
			# Clasificar por tipo
			if comp_type in [
				ComponentDatabase.ComponentType.WEAPON_ENERGY,
				ComponentDatabase.ComponentType.WEAPON_BALLISTIC,
				ComponentDatabase.ComponentType.WEAPON_MISSILE
			]:
				weapons.append(comp_copy)
			elif comp_type == ComponentDatabase.ComponentType.EQUIPMENT_AMMO:
				ammo.append(comp_copy)
			elif comp_type in [
				ComponentDatabase.ComponentType.EQUIPMENT_ECM,
				ComponentDatabase.ComponentType.EQUIPMENT_SENSOR,
				ComponentDatabase.ComponentType.EQUIPMENT_TARGETING,
				ComponentDatabase.ComponentType.EQUIPMENT_SPECIAL,
				ComponentDatabase.ComponentType.EQUIPMENT_ARMOR
			]:
				equipment.append(comp_copy)
	
	mech_data["weapons"] = weapons
	mech_data["equipment"] = equipment
	mech_data["critical_slots"] = critical_slots
	mech_data["ammo"] = ammo
	
	# Calcular heat capacity basado en heat sinks
	var heat_sink_count = 10  # Engine incluye 10 por defecto
	for location in loadout_components.keys():
		for component in loadout_components[location]:
			if component.get("type", -1) == ComponentDatabase.ComponentType.EQUIPMENT_HEATSINK:
				heat_sink_count += component.get("heat_dissipation", 1)
	
	mech_data["heat_capacity"] = 30 + (heat_sink_count - 10)
	mech_data["heat_dissipation"] = heat_sink_count
	
	# Skills por defecto
	mech_data["gunnery_skill"] = 4
	mech_data["piloting_skill"] = 5
	
	# Armadura y estructura por defecto
	mech_data["armor"] = generate_default_armor(mech_data["tonnage"])
	mech_data["structure"] = generate_default_structure(mech_data["tonnage"])
	
	Log.debug("Mech", "[CONVERT_LOADOUT] Created mech_data for %s: %d weapons, %d equipment, %d ammo" % [
		mech_data["name"], weapons.size(), equipment.size(), ammo.size()])
	
	return mech_data


## Convierte location enum a string
func _convert_location_to_string(location) -> String:
	if typeof(location) == TYPE_STRING:
		return location
	
	match location:
		0: return "head"
		1: return "center_torso"
		2: return "left_torso"
		3: return "right_torso"
		4: return "left_arm"
		5: return "right_arm"
		6: return "left_leg"
		7: return "right_leg"
		_: return "center_torso"


# ==============================================================================
# GENERACIÓN DE VALORES POR DEFECTO
# ==============================================================================

## Genera valores de armadura por defecto basados en tonnage
func generate_default_armor(tonnage: int) -> Dictionary:
	var armor_points = int(tonnage * 3.2)
	
	return {
		"head": {"current": max(9, int(armor_points * 0.04)), "max": max(9, int(armor_points * 0.04))},
		"center_torso": {"current": int(armor_points * 0.20), "max": int(armor_points * 0.20)},
		"center_torso_rear": {"current": int(armor_points * 0.05), "max": int(armor_points * 0.05)},
		"left_torso": {"current": int(armor_points * 0.13), "max": int(armor_points * 0.13)},
		"left_torso_rear": {"current": int(armor_points * 0.04), "max": int(armor_points * 0.04)},
		"right_torso": {"current": int(armor_points * 0.13), "max": int(armor_points * 0.13)},
		"right_torso_rear": {"current": int(armor_points * 0.04), "max": int(armor_points * 0.04)},
		"left_arm": {"current": int(armor_points * 0.10), "max": int(armor_points * 0.10)},
		"right_arm": {"current": int(armor_points * 0.10), "max": int(armor_points * 0.10)},
		"left_leg": {"current": int(armor_points * 0.09), "max": int(armor_points * 0.09)},
		"right_leg": {"current": int(armor_points * 0.09), "max": int(armor_points * 0.09)}
	}


## Genera valores de estructura interna por defecto basados en tonnage
func generate_default_structure(tonnage: int) -> Dictionary:
	const STRUCTURE_TABLE = {
		20: {"head": 3, "ct": 6, "st": 5, "arm": 3, "leg": 4},
		25: {"head": 3, "ct": 8, "st": 6, "arm": 4, "leg": 6},
		30: {"head": 3, "ct": 10, "st": 7, "arm": 5, "leg": 7},
		35: {"head": 3, "ct": 11, "st": 8, "arm": 6, "leg": 8},
		40: {"head": 3, "ct": 12, "st": 10, "arm": 6, "leg": 10},
		45: {"head": 3, "ct": 14, "st": 11, "arm": 7, "leg": 11},
		50: {"head": 3, "ct": 16, "st": 12, "arm": 8, "leg": 12},
		55: {"head": 3, "ct": 18, "st": 13, "arm": 9, "leg": 13},
		60: {"head": 3, "ct": 20, "st": 14, "arm": 10, "leg": 14},
		65: {"head": 3, "ct": 21, "st": 15, "arm": 10, "leg": 15},
		70: {"head": 3, "ct": 22, "st": 15, "arm": 11, "leg": 15},
		75: {"head": 3, "ct": 23, "st": 16, "arm": 12, "leg": 16},
		80: {"head": 3, "ct": 25, "st": 17, "arm": 13, "leg": 17},
		85: {"head": 3, "ct": 27, "st": 18, "arm": 14, "leg": 18},
		90: {"head": 3, "ct": 29, "st": 19, "arm": 15, "leg": 19},
		95: {"head": 3, "ct": 30, "st": 20, "arm": 16, "leg": 20},
		100: {"head": 3, "ct": 31, "st": 21, "arm": 17, "leg": 21}
	}
	
	# Encontrar el tonnage más cercano
	var closest_tonnage = 50
	for t in STRUCTURE_TABLE.keys():
		if abs(t - tonnage) < abs(closest_tonnage - tonnage):
			closest_tonnage = t
	
	var base = STRUCTURE_TABLE[closest_tonnage]
	return {
		"head": {"current": base["head"], "max": base["head"]},
		"center_torso": {"current": base["ct"], "max": base["ct"]},
		"left_torso": {"current": base["st"], "max": base["st"]},
		"right_torso": {"current": base["st"], "max": base["st"]},
		"left_arm": {"current": base["arm"], "max": base["arm"]},
		"right_arm": {"current": base["arm"], "max": base["arm"]},
		"left_leg": {"current": base["leg"], "max": base["leg"]},
		"right_leg": {"current": base["leg"], "max": base["leg"]}
	}
