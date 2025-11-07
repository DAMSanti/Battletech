extends Node
class_name MechLoadout

# Sistema de loadout y slots críticos para BattleTech
# Gestiona la configuración de armas y equipamiento del mech

enum MechLocation {
	HEAD,
	CENTER_TORSO,
	LEFT_TORSO,
	RIGHT_TORSO,
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_LEG,
	RIGHT_LEG
}

# Slots críticos por locación según Total Warfare
const CRITICAL_SLOTS = {
	MechLocation.HEAD: 6,
	MechLocation.CENTER_TORSO: 12,
	MechLocation.LEFT_TORSO: 12,
	MechLocation.RIGHT_TORSO: 12,
	MechLocation.LEFT_ARM: 12,
	MechLocation.RIGHT_ARM: 12,
	MechLocation.LEFT_LEG: 6,
	MechLocation.RIGHT_LEG: 6
}

# Componentes fijos que ocupan slots
const FIXED_COMPONENTS = {
	MechLocation.HEAD: [
		{"name": "Life Support", "slots": 1},
		{"name": "Sensors", "slots": 2},
		{"name": "Cockpit", "slots": 1}
	],
	MechLocation.CENTER_TORSO: [
		# Engine y Gyro se calculan dinámicamente
	],
	MechLocation.LEFT_TORSO: [],
	MechLocation.RIGHT_TORSO: [],
	MechLocation.LEFT_ARM: [
		{"name": "Shoulder", "slots": 1},
		{"name": "Upper Arm Actuator", "slots": 1},
		{"name": "Lower Arm Actuator", "slots": 1},
		{"name": "Hand Actuator", "slots": 1}
	],
	MechLocation.RIGHT_ARM: [
		{"name": "Shoulder", "slots": 1},
		{"name": "Upper Arm Actuator", "slots": 1},
		{"name": "Lower Arm Actuator", "slots": 1},
		{"name": "Hand Actuator", "slots": 1}
	],
	MechLocation.LEFT_LEG: [
		{"name": "Hip", "slots": 1},
		{"name": "Upper Leg Actuator", "slots": 1},
		{"name": "Lower Leg Actuator", "slots": 1},
		{"name": "Foot Actuator", "slots": 1}
	],
	MechLocation.RIGHT_LEG: [
		{"name": "Hip", "slots": 1},
		{"name": "Upper Leg Actuator", "slots": 1},
		{"name": "Lower Leg Actuator", "slots": 1},
		{"name": "Foot Actuator", "slots": 1}
	]
}

var mech_name: String = ""
var mech_tonnage: int = 50
var engine_rating: int = 200
var heat_sinks: int = 10

# Estructura de loadout: {location: [componentes]}
var loadout: Dictionary = {}

# Tracking de peso
var current_weight: float = 0.0
var armor_weight: float = 0.0
var structure_weight: float = 0.0
var engine_weight: float = 0.0

func _init():
	_initialize_loadout()
	_recalculate_weight()  # Calcular peso inicial con componentes fijos

func _initialize_loadout():
	# Inicializar todas las locaciones vacías
	for location in MechLocation.values():
		loadout[location] = []

# Calcular slots disponibles en una locación
func get_available_slots(location: MechLocation) -> int:
	var total_slots = CRITICAL_SLOTS[location]
	var used_slots = 0
	
	# Contar slots fijos
	if FIXED_COMPONENTS.has(location):
		for component in FIXED_COMPONENTS[location]:
			used_slots += component["slots"]
	
	# Contar slots de engine y gyro en center torso
	if location == MechLocation.CENTER_TORSO:
		used_slots += _calculate_engine_slots()
		used_slots += _calculate_gyro_slots()
	
	# Contar slots de componentes instalados
	if loadout.has(location):
		for component in loadout[location]:
			used_slots += component.get("slots", 0)
	
	return max(0, total_slots - used_slots)

# Calcular cuántos slots ocupa el engine
func _calculate_engine_slots() -> int:
	# Según Total Warfare, engines ocupan slots según rating
	var rating = engine_rating
	if rating <= 100:
		return 0
	elif rating <= 400:
		return 6
	else:
		return 12  # Engines muy grandes

# Calcular cuántos slots ocupa el gyro
func _calculate_gyro_slots() -> int:
	return 4  # Gyro siempre ocupa 4 slots

# Calcular peso del engine
func calculate_engine_weight() -> float:
	# Tabla de peso de engines según Total Warfare (Fusion Standard)
	# Basado en la tabla oficial de TechManual
	var rating = engine_rating
	
	# Para ratings comunes, usar valores exactos
	match rating:
		10: return 0.5
		20: return 0.5
		30: return 0.5
		40: return 0.5
		50: return 0.5
		60: return 1.0
		70: return 1.0
		75: return 1.5
		80: return 1.5
		85: return 1.5
		90: return 2.0
		95: return 2.0
		100: return 3.0
		105: return 3.0
		110: return 3.0
		115: return 3.5
		120: return 4.0
		125: return 4.0
		130: return 4.5
		135: return 4.5
		140: return 5.0
		145: return 5.5
		150: return 5.5
		155: return 6.0
		160: return 6.0
		165: return 6.5
		170: return 7.0
		175: return 7.0
		180: return 7.5
		185: return 8.0
		190: return 8.5
		195: return 8.5
		200: return 8.5
		205: return 9.5
		210: return 10.0
		215: return 10.5
		220: return 11.0
		225: return 11.5
		230: return 12.0
		235: return 12.5
		240: return 13.0
		245: return 13.5
		250: return 14.5
		255: return 15.0
		260: return 15.5
		265: return 16.5
		270: return 17.0
		275: return 18.0
		280: return 18.5
		285: return 19.5
		290: return 20.5
		295: return 21.5
		300: return 22.5
		305: return 23.5
		310: return 25.0
		315: return 26.0
		320: return 27.5
		325: return 28.5
		330: return 30.5
		335: return 31.5
		340: return 33.5
		345: return 35.0
		350: return 36.5
		355: return 38.5
		360: return 40.5
		365: return 42.5
		370: return 44.5
		375: return 47.0
		380: return 49.5
		385: return 52.5
		390: return 55.5
		395: return 58.5
		400: return 61.5
		_: 
			# Aproximación para ratings no estándar
			if rating < 100:
				return rating * 0.05
			else:
				return rating * 0.1

# Añadir componente a una locación
func add_component(location: MechLocation, component_data: Dictionary) -> bool:
	var required_slots = component_data.get("slots", 0)
	var available = get_available_slots(location)
	
	if available < required_slots:
		push_error("No hay slots suficientes en %s (requiere %d, disponibles %d)" % [
			MechLocation.keys()[location], required_slots, available
		])
		return false
	
	# Verificar restricciones de locación
	if not _can_mount_in_location(component_data, location):
		push_error("El componente %s no se puede montar en %s" % [
			component_data.get("name", "Unknown"),
			MechLocation.keys()[location]
		])
		return false
	
	# Añadir componente
	if not loadout.has(location):
		loadout[location] = []
	
	loadout[location].append(component_data.duplicate(true))
	_recalculate_weight()
	return true

# Remover componente de una locación
func remove_component(location: MechLocation, component_index: int) -> bool:
	if not loadout.has(location):
		return false
	
	if component_index < 0 or component_index >= loadout[location].size():
		return false
	
	loadout[location].remove_at(component_index)
	_recalculate_weight()
	return true

# Verificar si un componente puede montarse en una locación (método público)
func can_mount_in_location(component: Dictionary, location: MechLocation) -> bool:
	return _can_mount_in_location(component, location)

# Verificar si un componente puede montarse en una locación
func _can_mount_in_location(component: Dictionary, location: MechLocation) -> bool:
	var comp_type = component.get("type", -1)
	
	# Algunas armas no pueden ir en piernas
	if location in [MechLocation.LEFT_LEG, MechLocation.RIGHT_LEG]:
		# Solo permitir ciertos equipos en piernas
		if comp_type in [
			ComponentDatabase.ComponentType.WEAPON_ENERGY,
			ComponentDatabase.ComponentType.WEAPON_BALLISTIC,
			ComponentDatabase.ComponentType.WEAPON_MISSILE
		]:
			return false  # No armas en piernas por defecto
	
	# CASE solo puede ir en torsos con munición
	if component.get("id", "") == "case":
		if not location in [MechLocation.LEFT_TORSO, MechLocation.RIGHT_TORSO]:
			return false
	
	return true

# Recalcular peso total
func _recalculate_weight():
	current_weight = 0.0
	
	# Peso de estructura (según Total Warfare, aproximadamente 10% del tonnage)
	structure_weight = mech_tonnage * 0.1
	current_weight += structure_weight
	
	# Peso de engine (varía según rating)
	engine_weight = calculate_engine_weight()
	current_weight += engine_weight
	
	# Peso de gyro (engine_rating / 100, redondeado arriba)
	var gyro_weight = ceil(engine_rating / 100.0)
	current_weight += gyro_weight
	
	# Peso de componentes fijos según Total Warfare:
	var fixed_weight = 0.0
	
	# Cockpit: 3 tons (incluye life support y sensors)
	fixed_weight += 3.0
	
	# Actuadores: según Total Warfare, el peso de los actuadores está incluido
	# en el peso de la estructura interna, NO se cuentan aparte
	# Solo ocupan slots críticos, pero no peso adicional
	
	current_weight += fixed_weight
	
	# Peso de componentes instalados por el usuario
	for location in loadout.keys():
		for component in loadout[location]:
			var weight = component.get("weight", 0.0)
			
			# Calcular peso de jump jets dinámicamente
			if component.get("id", "") == "jump_jet":
				weight = ComponentDatabase.calculate_jump_jet_weight(mech_tonnage)
			
			current_weight += weight
	
	# Peso de armadura (se añade externamente)
	current_weight += armor_weight

# Obtener peso disponible
func get_available_weight() -> float:
	return max(0.0, mech_tonnage - current_weight)

# Verificar si el loadout es válido
func is_valid_loadout() -> Dictionary:
	var errors = []
	var warnings = []
	
	# Verificar peso
	if current_weight > mech_tonnage:
		errors.append("Sobrepeso: %.1f / %d tons" % [current_weight, mech_tonnage])
	
	# Verificar que armas con munición tengan munición
	var weapons_needing_ammo = {}
	var ammo_available = {}
	
	for location in loadout.keys():
		for component in loadout[location]:
			if component.get("requires_ammo", false):
				var ammo_type = component.get("ammo_type", "")
				if not weapons_needing_ammo.has(ammo_type):
					weapons_needing_ammo[ammo_type] = []
				weapons_needing_ammo[ammo_type].append(component.get("name", "Unknown"))
			
			if component.get("type", -1) == ComponentDatabase.ComponentType.EQUIPMENT_AMMO:
				var ammo_type = component.get("ammo_type", "")
				if not ammo_available.has(ammo_type):
					ammo_available[ammo_type] = 0
				ammo_available[ammo_type] += 1
	
	# Verificar munición
	for ammo_type in weapons_needing_ammo.keys():
		if not ammo_available.has(ammo_type) or ammo_available[ammo_type] == 0:
			warnings.append("Armas de tipo %s no tienen munición" % ammo_type)
	
	# Verificar heat sinks (mínimo 10)
	var heat_sink_count = get_total_heat_sinks()
	
	# Calcular calor total generado por armas
	var max_heat_generation = 0
	for location in loadout.keys():
		for component in loadout[location]:
			if component.has("heat"):
				max_heat_generation += component["heat"]
	
	if max_heat_generation > heat_sink_count:
		warnings.append("Calor generado (%d) excede disipación (%d)" % [
			max_heat_generation, heat_sink_count
		])
	
	return {
		"valid": errors.size() == 0,
		"errors": errors,
		"warnings": warnings
	}

# Obtener resumen del loadout
func get_loadout_summary() -> Dictionary:
	var weapons_count = 0
	var total_heat = 0
	var total_damage = 0
	
	for location in loadout.keys():
		for component in loadout[location]:
			var comp_type = component.get("type", -1)
			if comp_type in [
				ComponentDatabase.ComponentType.WEAPON_ENERGY,
				ComponentDatabase.ComponentType.WEAPON_BALLISTIC,
				ComponentDatabase.ComponentType.WEAPON_MISSILE
			]:
				weapons_count += 1
				total_heat += component.get("heat", 0)
				total_damage += component.get("damage", 0)
	
	return {
		"tonnage": mech_tonnage,
		"current_weight": current_weight,
		"available_weight": get_available_weight(),
		"weapons_count": weapons_count,
		"total_heat": total_heat,
		"total_damage": total_damage,
		"engine_rating": engine_rating,
		"heat_sinks": get_total_heat_sinks()
	}

# Contar heat sinks totales (engine + equipados)
func get_total_heat_sinks() -> int:
	var heat_sink_count = 10  # Engine incluye 10 por defecto
	for location in loadout.keys():
		for component in loadout[location]:
			if component.get("type", -1) == ComponentDatabase.ComponentType.EQUIPMENT_HEATSINK:
				heat_sink_count += component.get("heat_dissipation", 1)
	return heat_sink_count

# Exportar loadout a diccionario (para guardar)
func to_dict() -> Dictionary:
	return {
		"mech_name": mech_name,
		"mech_tonnage": mech_tonnage,
		"engine_rating": engine_rating,
		"heat_sinks": get_total_heat_sinks(),  # Contar heat sinks equipados
		"armor_weight": armor_weight,
		"current_weight": current_weight,
		"loadout": loadout.duplicate(true)
	}

# Importar loadout desde diccionario
func from_dict(data: Dictionary):
	mech_name = data.get("mech_name", "")
	mech_tonnage = data.get("mech_tonnage", 50)
	engine_rating = data.get("engine_rating", 200)
	heat_sinks = data.get("heat_sinks", 10)
	armor_weight = data.get("armor_weight", 0.0)
	loadout = data.get("loadout", {}).duplicate(true)
	_recalculate_weight()
