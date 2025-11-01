extends Node
class_name Mech

# Stats básicos del Mech
var mech_name: String = "Atlas"
var tonnage: int = 100
var movement_points: int = 3
var current_movement: int = 3

# Sistema de armadura por localización
var armor: Dictionary = {
	"head": {"current": 9, "max": 9},
	"center_torso": {"current": 47, "max": 47},
	"left_torso": {"current": 32, "max": 32},
	"right_torso": {"current": 32, "max": 32},
	"left_arm": {"current": 34, "max": 34},
	"right_arm": {"current": 34, "max": 34},
	"left_leg": {"current": 41, "max": 41},
	"right_leg": {"current": 41, "max": 41}
}

# Sistema de estructura interna
var structure: Dictionary = {
	"head": {"current": 3, "max": 3},
	"center_torso": {"current": 31, "max": 31},
	"left_torso": {"current": 21, "max": 21},
	"right_torso": {"current": 21, "max": 21},
	"left_arm": {"current": 17, "max": 17},
	"right_arm": {"current": 17, "max": 17},
	"left_leg": {"current": 21, "max": 21},
	"right_leg": {"current": 21, "max": 21}
}

# Sistema de calor
var heat: int = 0
var heat_capacity: int = 30
var heat_dissipation: int = 10

# Armas equipadas
var weapons: Array = []

# Estado del mech
var is_shutdown: bool = false
var is_destroyed: bool = false
var is_prone: bool = false  # Caído en el suelo
var pilot_name: String = "Pilot"
var pilot_skill: int = 4  # Gunnery/Piloting skill

# Posición en el mapa
var hex_position: Vector2i = Vector2i(0, 0)
var facing: int = 0  # 0-5 para las 6 direcciones hexagonales

# Ataques físicos
var can_punch_left: bool = true
var can_punch_right: bool = true
var can_kick: bool = true

func _ready():
	_setup_default_weapons()

func _setup_default_weapons():
	# Atlas estándar AS7-D
	weapons = [
		{
			"name": "AC/20",
			"damage": 20,
			"heat": 7,
			"min_range": 0,
			"short_range": 3,
			"medium_range": 6,
			"long_range": 9,
			"ammo": 5,
			"location": "right_torso"
		},
		{
			"name": "LRM-20",
			"damage": 20,
			"heat": 6,
			"min_range": 6,
			"short_range": 7,
			"medium_range": 14,
			"long_range": 21,
			"ammo": 6,
			"location": "left_torso"
		},
		{
			"name": "Medium Laser",
			"damage": 5,
			"heat": 3,
			"min_range": 0,
			"short_range": 3,
			"medium_range": 6,
			"long_range": 9,
			"ammo": -1,  # -1 = energía ilimitada
			"location": "left_arm"
		},
		{
			"name": "Medium Laser",
			"damage": 5,
			"heat": 3,
			"min_range": 0,
			"short_range": 3,
			"medium_range": 6,
			"long_range": 9,
			"ammo": -1,
			"location": "right_arm"
		}
	]

func take_damage(location: String, damage: int) -> Dictionary:
	var result = {
		"armor_damage": 0,
		"structure_damage": 0,
		"location_destroyed": false,
		"mech_destroyed": false,
		"critical_hit": false
	}
	
	if not armor.has(location):
		push_error("Invalid location: " + location)
		return result
	
	# Primero daña la armadura
	var armor_remaining = armor[location]["current"]
	var damage_to_armor = min(damage, armor_remaining)
	armor[location]["current"] -= damage_to_armor
	result["armor_damage"] = damage_to_armor
	
	# Si queda daño, va a la estructura
	var overflow_damage = damage - damage_to_armor
	if overflow_damage > 0:
		structure[location]["current"] -= overflow_damage
		result["structure_damage"] = overflow_damage
		result["critical_hit"] = true
		
		# Chequear si la localización está destruida
		if structure[location]["current"] <= 0:
			result["location_destroyed"] = true
			_handle_location_destruction(location)
	
	# Chequear si el mech está destruido
	if _check_destruction():
		is_destroyed = true
		result["mech_destroyed"] = true
	
	return result

func _handle_location_destruction(location: String):
	# Cabeza destruida = mech destruido
	if location == "head":
		is_destroyed = true
	
	# Torso central destruido = mech destruido
	if location == "center_torso":
		is_destroyed = true
	
	# Destruir armas en esa localización
	for weapon in weapons:
		if weapon["location"] == location:
			weapon["destroyed"] = true

func _check_destruction() -> bool:
	# Mech destruido si cabeza o torso central destruidos
	if structure["head"]["current"] <= 0 or structure["center_torso"]["current"] <= 0:
		return true
	
	# Mech destruido si ambas piernas destruidas
	if structure["left_leg"]["current"] <= 0 and structure["right_leg"]["current"] <= 0:
		return true
	
	return false

func add_heat(amount: int):
	heat += amount
	
	# Chequeos de calor
	if heat >= 30:
		is_shutdown = true
	elif heat >= 24:
		# Posibilidad de munición explosionando
		pass
	elif heat >= 14:
		# Penalizadores de movimiento y ataque
		pass

func dissipate_heat():
	heat = max(0, heat - heat_dissipation)
	if heat < 30:
		is_shutdown = false

func reset_movement():
	current_movement = movement_points

func can_fire_weapon(weapon_index: int, target_distance: int) -> Dictionary:
	var result = {"can_fire": false, "reason": ""}
	
	if weapon_index < 0 or weapon_index >= weapons.size():
		result["reason"] = "Invalid weapon"
		return result
	
	var weapon = weapons[weapon_index]
	
	if weapon.get("destroyed", false):
		result["reason"] = "Weapon destroyed"
		return result
	
	if weapon["ammo"] == 0:
		result["reason"] = "No ammo"
		return result
	
	if is_shutdown:
		result["reason"] = "Mech shutdown"
		return result
	
	# Chequear rango
	if target_distance < weapon["min_range"]:
		result["reason"] = "Target too close"
		return result
	
	if target_distance > weapon["long_range"]:
		result["reason"] = "Target out of range"
		return result
	
	result["can_fire"] = true
	return result

func fire_weapon(weapon_index: int, target_distance: int) -> Dictionary:
	var result = can_fire_weapon(weapon_index, target_distance)
	if not result["can_fire"]:
		return result
	
	var weapon = weapons[weapon_index]
	
	# Consumir munición
	if weapon["ammo"] > 0:
		weapon["ammo"] -= 1
	
	# Añadir calor
	add_heat(weapon["heat"])
	
	# Calcular modificadores de ataque basados en rango
	var range_modifier = 0
	if target_distance <= weapon["short_range"]:
		range_modifier = 0
	elif target_distance <= weapon["medium_range"]:
		range_modifier = 2
	elif target_distance <= weapon["long_range"]:
		range_modifier = 4
	
	# Modificadores por calor
	var heat_modifier = 0
	if heat >= 8:
		heat_modifier = 1
	if heat >= 13:
		heat_modifier = 2
	if heat >= 17:
		heat_modifier = 3
	if heat >= 24:
		heat_modifier = 4
	
	result["damage"] = weapon["damage"]
	result["to_hit_modifier"] = range_modifier + heat_modifier + pilot_skill
	result["weapon_name"] = weapon["name"]
	
	return result

func get_status_summary() -> String:
	var status = "Mech: %s (%d tons)\n" % [mech_name, tonnage]
	status += "Heat: %d/%d\n" % [heat, heat_capacity]
	status += "Movement: %d/%d\n" % [current_movement, movement_points]
	status += "\nArmor Status:\n"
	for loc in armor.keys():
		status += "  %s: %d/%d\n" % [loc, armor[loc]["current"], armor[loc]["max"]]
	return status

# ============= ATAQUES FÍSICOS =============

func can_perform_punch(arm: String) -> Dictionary:
	var result = {"can_punch": false, "reason": ""}
	
	if is_destroyed:
		result["reason"] = "Mech destroyed"
		return result
	
	if is_shutdown:
		result["reason"] = "Mech shutdown"
		return result
	
	if is_prone:
		result["reason"] = "Mech is prone"
		return result
	
	# Verificar que el brazo esté funcional
	var arm_loc = "left_arm" if arm == "left" else "right_arm"
	if structure[arm_loc]["current"] <= 0:
		result["reason"] = "Arm destroyed"
		return result
	
	if arm == "left" and not can_punch_left:
		result["reason"] = "Left arm cannot punch"
		return result
	
	if arm == "right" and not can_punch_right:
		result["reason"] = "Right arm cannot punch"
		return result
	
	result["can_punch"] = true
	return result

func perform_punch(arm: String) -> Dictionary:
	var check = can_perform_punch(arm)
	if not check["can_punch"]:
		return check
	
	# Daño del puñetazo = tonelaje / 10 (redondeado)
	var damage = int(tonnage / 10.0)
	
	var result = {
		"can_punch": true,
		"damage": damage,
		"attack_type": "punch",
		"arm": arm,
		"to_hit_modifier": pilot_skill
	}
	
	return result

func can_perform_kick() -> Dictionary:
	var result = {"can_kick": false, "reason": ""}
	
	if is_destroyed:
		result["reason"] = "Mech destroyed"
		return result
	
	if is_shutdown:
		result["reason"] = "Mech shutdown"
		return result
	
	if is_prone:
		result["reason"] = "Mech is prone"
		return result
	
	# Necesitas al menos una pierna funcional
	var left_leg_ok = structure["left_leg"]["current"] > 0
	var right_leg_ok = structure["right_leg"]["current"] > 0
	
	if not left_leg_ok and not right_leg_ok:
		result["reason"] = "Both legs destroyed"
		return result
	
	if not can_kick:
		result["reason"] = "Cannot kick this turn"
		return result
	
	result["can_kick"] = true
	return result

func perform_kick() -> Dictionary:
	var check = can_perform_kick()
	if not check["can_kick"]:
		return check
	
	# Daño de patada = tonelaje / 5 (redondeado)
	var damage = int(tonnage / 5.0)
	
	var result = {
		"can_kick": true,
		"damage": damage,
		"attack_type": "kick",
		"to_hit_modifier": pilot_skill + 2,  # +2 más difícil que puñetazo
		"self_damage_risk": true  # Riesgo de caerse
	}
	
	return result

func can_perform_push() -> Dictionary:
	var result = {"can_push": false, "reason": ""}
	
	if is_destroyed:
		result["reason"] = "Mech destroyed"
		return result
	
	if is_shutdown:
		result["reason"] = "Mech shutdown"
		return result
	
	if is_prone:
		result["reason"] = "Mech is prone"
		return result
	
	# Necesitas al menos un brazo funcional
	var left_arm_ok = structure["left_arm"]["current"] > 0
	var right_arm_ok = structure["right_arm"]["current"] > 0
	
	if not left_arm_ok and not right_arm_ok:
		result["reason"] = "Both arms destroyed"
		return result
	
	result["can_push"] = true
	return result

func perform_push() -> Dictionary:
	var check = can_perform_push()
	if not check["can_push"]:
		return check
	
	# Push no hace daño, pero puede derribar al enemigo
	var result = {
		"can_push": true,
		"damage": 0,
		"attack_type": "push",
		"to_hit_modifier": pilot_skill,
		"knockdown_chance": true
	}
	
	return result

func can_perform_charge(distance_moved: int) -> Dictionary:
	var result = {"can_charge": false, "reason": ""}
	
	if is_destroyed:
		result["reason"] = "Mech destroyed"
		return result
	
	if is_shutdown:
		result["reason"] = "Mech shutdown"
		return result
	
	if is_prone:
		result["reason"] = "Mech is prone"
		return result
	
	# Necesitas haberte movido al menos 1 hex
	if distance_moved < 1:
		result["reason"] = "Must move before charging"
		return result
	
	# Necesitas ambas piernas
	var left_leg_ok = structure["left_leg"]["current"] > 0
	var right_leg_ok = structure["right_leg"]["current"] > 0
	
	if not left_leg_ok or not right_leg_ok:
		result["reason"] = "Need both legs to charge"
		return result
	
	result["can_charge"] = true
	return result

func perform_charge(distance_moved: int) -> Dictionary:
	var check = can_perform_charge(distance_moved)
	if not check["can_charge"]:
		return check
	
	# Daño de carga = (tonelaje / 10) * hexes movidos
	var damage = int((tonnage / 10.0) * distance_moved)
	
	# El atacante también recibe daño
	var self_damage = int(damage / 2.0)
	
	var result = {
		"can_charge": true,
		"damage": damage,
		"self_damage": self_damage,
		"attack_type": "charge",
		"to_hit_modifier": pilot_skill + 1,
		"knockdown_chance": true,
		"self_knockdown_risk": true
	}
	
	return result

func check_piloting_skill_roll(modifier: int = 0) -> bool:
	# Tirar 2d6, necesitas >= pilot_skill + modificador
	var roll = randi() % 6 + randi() % 6 + 2
	return roll >= (pilot_skill + modifier)

func fall_prone():
	is_prone = true
	# Daño por caída: 1 punto por cada 10 toneladas
	var fall_damage = int(tonnage / 10.0)
	
	# El daño de caída va a piernas y torso lateral aleatorio
	var locations = ["left_leg", "right_leg", "left_arm", "right_arm"]
	for i in range(fall_damage):
		var loc = locations[randi() % locations.size()]
		take_damage(loc, 1)

func stand_up():
	if is_prone:
		is_prone = false
		# Levantarse cuesta todo el movimiento del turno
		current_movement = 0
