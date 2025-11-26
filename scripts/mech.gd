extends Node2D
class_name Mech

# Stats básicos del Mech
var mech_name: String = "Atlas"
var tonnage: int = 100
var walk_mp: int = 3  # Velocidad de caminata
var run_mp: int = 5   # Velocidad de carrera (walk_mp * 1.5 redondeado)
var jump_mp: int = 0  # Puntos de salto (0 si no tiene jump jets)
var current_movement: int = 3

# Iniciativa individual del mech (2D6)
var initiative: int = 7  # Default, será sobreescrito por la tirada

# Tipo de movimiento usado este turno
enum MovementType { NONE, WALK, RUN, JUMP }
var movement_type_used: int = GameEnums.MovementType.NONE
var hexes_moved_this_turn: int = 0
var last_movement_type: int = GameEnums.MovementType.NONE  # Para modificadores de combate

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

# Equipamiento adicional (heatsinks, ECM, BAP, etc.)
var equipment: Array = []

# Localizaciones destruidas
var destroyed_locations: Array = []

# Componentes críticos por localización
var critical_slots: Dictionary = {
	"head": [],
	"center_torso": [],
	"left_torso": [],
	"right_torso": [],
	"left_arm": [],
	"right_arm": [],
	"left_leg": [],
	"right_leg": []
}

# Estado del mech
var is_shutdown: bool = false
var is_destroyed: bool = false
var is_prone: bool = false  # Caído en el suelo
var death_reason: String = ""  # Descripción de cómo fue destruido
var destroyed_by: String = ""  # Nombre del mech que lo destruyó
var pilot_name: String = "Pilot"
var pilot_skill: int = 4  # Gunnery/Piloting skill

# Sistema de visibilidad (Line of Sight / Fog of War)
var is_visible_to_player: bool = true  # Controlado por sistema de LoS
var is_player_controlled: bool = false  # True si es del jugador

# Posición en el mapa
var hex_position: Vector2i = Vector2i(0, 0)
var facing: int = 0  # 0-5 para las 6 direcciones hexagonales (FacingSystem.Facing)
var torso_facing: int = 0  # Para torso twist (opcional)

# Modificadores de combate basados en movimiento
var target_movement_modifier: int = 0  # Modificador al ser atacado
var attacker_movement_modifier: int = 0  # Modificador al atacar

# Ataques físicos
var can_punch_left: bool = true
var can_punch_right: bool = true
var can_kick: bool = true
var has_performed_physical_attack: bool = false  # Flag para prevenir múltiples ataques físicos

# Sprite del mech
var sprite: Sprite2D

func _ready():
	# Solo configurar armas por defecto si no se han configurado desde fuera
	if weapons.size() == 0:
		_setup_default_weapons()
	_setup_sprite()

var sprite_manager: MechSpriteManager

func _setup_sprite():
	# Inicializar sprite manager
	sprite_manager = MechSpriteManager.new()
	
	# Crear sprite para el mech
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# Configurar z-index para que aparezca sobre el terreno
	sprite.z_index = 1
	
	# Actualizar sprite inicial
	_update_sprite()

func _draw():
	# Dibujar indicador de dirección (facing)
	var radius = 40
	var facing_angle = deg_to_rad(facing * 60 - 90)  # -90 para que apunte hacia arriba
	var facing_point = Vector2(cos(facing_angle), sin(facing_angle)) * radius * 0.5
	draw_line(Vector2.ZERO, facing_point, Color.YELLOW, 3.0)
	
	# Nombre del mech (centrado sobre el sprite)
	var font = ThemeDB.fallback_font
	var font_size = 16
	var text_width = font.get_string_size(mech_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var text_pos = Vector2(-text_width / 2, -radius - 5)
	draw_string(font, text_pos, mech_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	
	# Indicador si está destruido
	if is_destroyed:
		draw_circle(Vector2.ZERO, 50, Color(0.2, 0.2, 0.2, 0.7))
		var destroyed_text = "DESTROYED"
		var destroyed_pos = Vector2(-40, 5)
		draw_string(font, destroyed_pos, destroyed_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.RED)

func update_visual_position(hex_grid):
	# Actualizar posición en pantalla basado en hex_position
	if hex_grid:
		# Usar hex_to_pixel con elevación para que el mech se posicione correctamente
		var base_pos = hex_grid.hex_to_pixel(hex_position, true)
		# El mech es hijo de battle_scene, no de hex_grid, así que necesitamos las coordenadas globales
		position = base_pos + hex_grid.position
		
		# Ajustar z_index basado en la elevación y posición Y para simular profundidad
		var elevation = hex_grid.get_elevation(hex_position)
		# Usar posición Y para que cosas al sur (Y mayor) aparezcan delante
		# LÍMITE: RenderingServer.CANVAS_ITEM_Z_MAX = 4096
		# Mantener valores altos pero dentro del límite permitido
		var base_z = int(position.y) + (elevation * 1000)
		# Normalizar al rango válido manteniendo el orden relativo
		z_index = clampi(base_z, -4096, 4096)
	# Siempre redibujar para actualizar facing y otros indicadores visuales
	queue_redraw()

func update_facing_visual():
	# Actualizar solo la dirección visual sin mover el mech
	_update_sprite()  # Actualizar textura del sprite según facing
	queue_redraw()    # Actualizar indicador de dirección

## SISTEMA DE MOVIMIENTO ##

func get_available_movement(movement_type: MovementType) -> int:
	# Retorna los MP disponibles según el tipo de movimiento (BT TW)
	if is_prone:
		return 1  # Mechs caídos solo pueden arrastrarse
	var base_mp = 0
	match movement_type:
		MovementType.WALK:
			base_mp = walk_mp
		MovementType.RUN:
			base_mp = run_mp
		MovementType.JUMP:
			base_mp = jump_mp
		_:
			return 0
	# Penalización por calor
	var heat_penalty = get_heat_movement_penalty()
	return max(1, base_mp - heat_penalty)  # Mínimo 1 MP

func start_movement(movement_type: int):  # GameEnums.MovementType
	# Inicia un movimiento del tipo especificado
	movement_type_used = movement_type
	last_movement_type = movement_type
	hexes_moved_this_turn = 0
	has_performed_physical_attack = false  # Reset flag de ataque físico al inicio del turno
	
	# Calcular MPs disponibles según tipo usando el nuevo sistema
	match movement_type:
		GameEnums.MovementType.WALK:
			current_movement = MovementSystem.calculate_walk_distance(self)
			attacker_movement_modifier = 1  # +1 to-hit al disparar caminando
		GameEnums.MovementType.RUN:
			current_movement = MovementSystem.calculate_run_distance(self)
			attacker_movement_modifier = 2  # +2 to-hit al disparar corriendo
		GameEnums.MovementType.JUMP:
			current_movement = MovementSystem.calculate_jump_distance(self)
			attacker_movement_modifier = 3  # +3 to-hit al disparar saltando
		_:
			current_movement = 0
			attacker_movement_modifier = 0

func move_to_hex(new_hex: Vector2i, cost: int):
	# Registra un movimiento a un nuevo hexágono
	hex_position = new_hex
	hexes_moved_this_turn += 1
	current_movement -= cost
	
	# Calcular modificador de objetivo basado en movimiento
	_calculate_target_movement_modifier()

func _calculate_target_movement_modifier():
	# Calcula el modificador de defensa basado en el movimiento realizado
	# Según BattleTech Total Warfare:
	# 0-2 hexes: +0, 3-4: +1, 5-6: +2, 7-9: +3, 10+: +4
	# Jump añade +1 adicional
	
	# Si el mech está en shutdown, es más fácil de impactar (-4 al TN)
	if is_shutdown:
		target_movement_modifier = -4
		return
	
	var tmm = 0
	if hexes_moved_this_turn >= 10:
		tmm = 4
	elif hexes_moved_this_turn >= 7:
		tmm = 3
	elif hexes_moved_this_turn >= 5:
		tmm = 2
	elif hexes_moved_this_turn >= 3:
		tmm = 1
	else:
		tmm = 0
	
	# Bonus adicional por salto
	if movement_type_used == GameEnums.MovementType.JUMP:
		tmm += 1
	
	target_movement_modifier = tmm

func get_attacker_movement_modifier() -> int:
	# Modificador al disparar basado en cómo te moviste
	# Según BattleTech Total Warfare:
	# Walked: +1, Ran: +2, Jumped: +3
	var movement_mod = 0
	match movement_type_used:
		GameEnums.MovementType.WALK:
			movement_mod = 1  # +1 al caminar
		GameEnums.MovementType.RUN:
			movement_mod = 2  # +2 al correr
		GameEnums.MovementType.JUMP:
			movement_mod = 3  # +3 al saltar
		_:
			movement_mod = 0  # No se movió
	
	# Sumar penalización por calor
	var heat_mod = get_heat_to_hit_penalty()
	return movement_mod + heat_mod

func can_change_facing(_direction: int) -> bool:
	# Verifica si puede girar en una dirección (cuesta 1 MP por hex)
	return current_movement >= 1

func change_facing(new_facing: int, is_jump: bool=false):
	# Cambia la dirección del mech
	# Caminar/correr: cada giro cuesta 1 MP
	# Saltar: giros gratis
	if is_jump:
		facing = new_facing % 6  # Hexagonal tiene 6 direcciones
	elif can_change_facing(new_facing):
		facing = new_facing % 6
		current_movement -= 1
	
	# Actualizar sprite con la nueva orientación
	_update_sprite()

func _update_sprite():
	# Ocultar mech si no es visible al jugador
	if not is_player_controlled and not is_visible_to_player:
		visible = false
		return
	else:
		visible = true
	
	print("[MECH] _update_sprite called for %s, facing=%d, sprite_manager=%s" % [mech_name, facing, sprite_manager != null])
	
	if sprite_manager and sprite:
		# Obtener el sprite correcto según tonelaje y orientación
		var new_texture = sprite_manager.get_sprite_for_mech(tonnage, facing)
		if new_texture:
			sprite.texture = new_texture
			print("[MECH] Sprite texture updated for facing %d" % facing)
		else:
			print("[MECH] WARNING: No texture returned for facing %d" % facing)
		
		# Aplicar efectos visuales según estado
		if is_prone:
			sprite.rotation_degrees = 90
			modulate = Color(0.7, 0.7, 0.7)
		elif is_shutdown:
			sprite.rotation_degrees = 0
			modulate = Color(0.5, 0.5, 0.5)
		else:
			sprite.rotation_degrees = 0
			modulate = Color.WHITE

func reset_movement():
	# Resetea el movimiento al inicio del turno
	movement_type_used = GameEnums.MovementType.NONE
	last_movement_type = GameEnums.MovementType.NONE
	hexes_moved_this_turn = 0
	target_movement_modifier = 0
	attacker_movement_modifier = 0
	# Calcular walk_mp con penalizaciones (daño en piernas, calor, etc.)
	current_movement = MovementSystem.calculate_walk_distance(self)

func finalize_movement():
	# Aplica efectos del movimiento (calor) al finalizar
	var movement_heat = 0
	match movement_type_used:
		GameEnums.MovementType.WALK:
			movement_heat = 1
		GameEnums.MovementType.RUN:
			movement_heat = 2
		GameEnums.MovementType.JUMP:
			movement_heat = hexes_moved_this_turn  # 1 por hex saltado
	if movement_heat > 0:
		add_heat(movement_heat)
	return movement_heat

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
		if death_reason == "":
			death_reason = "Head destroyed"
	
	# Torso central destruido = mech destruido
	if location == "center_torso":
		is_destroyed = true
		if death_reason == "":
			death_reason = "Center torso destroyed"
	
	# Destruir armas en esa localización
	for weapon in weapons:
		if weapon.get("location", "") == location:
			weapon["destroyed"] = true

func _check_destruction() -> bool:
	# Mech destruido si cabeza o torso central destruidos
	if structure["head"]["current"] <= 0 or structure["center_torso"]["current"] <= 0:
		return true
	
	# Mech destruido si ambas piernas destruidas
	if structure["left_leg"]["current"] <= 0 and structure["right_leg"]["current"] <= 0:
		if death_reason == "":
			death_reason = "Both legs destroyed"
		return true
	
	return false

func add_heat(amount: int):
	heat += amount
	queue_redraw()  # Actualizar visualización de la barra de calor
	
	# Chequeos automáticos en niveles críticos
	if heat >= 30:
		is_shutdown = true
	
	# Los demás chequeos (shutdown risk, ammo explosion) se hacen en la fase de calor

func dissipate_heat():
	# Disipar calor usando el sistema de calor
	var result = HeatSystem.apply_heat_dissipation(self)
	queue_redraw()  # Actualizar visualización
	return result

func get_heat_effects() -> Dictionary:
	# Retorna los efectos actuales del calor
	return HeatSystem.get_heat_effects(heat)

func get_heat_movement_penalty() -> int:
	# Retorna la penalización de movimiento por calor
	var effects = get_heat_effects()
	return effects.get("movement_penalty", 0)

func get_heat_to_hit_penalty() -> int:
	# Retorna la penalización de to-hit por calor
	var effects = get_heat_effects()
	return effects.get("to_hit_penalty", 0)

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
	status += "Movement: %d (Walk:%d Run:%d Jump:%d)\n" % [current_movement, walk_mp, run_mp, jump_mp]
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

func get_armor_data_for_ui() -> Dictionary:
	# Retorna un diccionario con toda la información de armadura y estructura
	# formateada para el panel de UI
	var result = {}
	
	# Copiar datos de armadura
	for location in armor.keys():
		result[location] = {
			"current": armor[location]["current"],
			"max": armor[location]["max"]
		}
	
	# Agregar datos de estructura
	for location in structure.keys():
		result[location + "_structure"] = structure[location]["current"]
		result[location + "_structure_max"] = structure[location]["max"]
	
	return result

func set_visibility(visible_state: bool):
	"""Actualiza la visibilidad del mech según LoS"""
	is_visible_to_player = visible_state
	_update_sprite()

## ========== FUNCIONES DE COMBATE AVANZADO ==========

func get_functional_weapons() -> Array:
	"""Retorna solo las armas que pueden disparar"""
	var functional = []
	for weapon in weapons:
		if not weapon.get("destroyed", false):
			# Verificar que la localización no esté destruida
			var loc = weapon.get("location", "")
			if loc != "" and not destroyed_locations.has(loc):
				functional.append(weapon)
	return functional

func get_weapon_by_index(index: int) -> Dictionary:
	"""Obtiene un arma por índice"""
	if index >= 0 and index < weapons.size():
		return weapons[index]
	return {}

func add_equipment(equip: Dictionary):
	"""Añade equipamiento al mech"""
	equipment.append(equip)

func get_equipment_in_location(location: String) -> Array:
	"""Obtiene todo el equipamiento en una localización"""
	var result = []
	for equip in equipment:
		if equip.get("location", "") == location and not equip.get("destroyed", false):
			result.append(equip)
	return result

func is_location_destroyed(location: String) -> bool:
	"""Verifica si una localización está destruida"""
	return destroyed_locations.has(location)

func get_armor_percentage(location: String) -> float:
	"""Obtiene el porcentaje de armadura restante en una localización"""
	if not armor.has(location):
		return 0.0
	var current = armor[location]["current"]
	var maximum = armor[location]["max"]
	if maximum <= 0:
		return 0.0
	return (float(current) / float(maximum)) * 100.0

func get_structure_percentage(location: String) -> float:
	"""Obtiene el porcentaje de estructura restante en una localización"""
	if not structure.has(location):
		return 0.0
	var current = structure[location]["current"]
	var maximum = structure[location]["max"]
	if maximum <= 0:
		return 0.0
	return (float(current) / float(maximum)) * 100.0

func get_combat_status() -> Dictionary:
	"""Retorna el estado de combate completo del mech"""
	return {
		"name": mech_name,
		"is_destroyed": is_destroyed,
		"is_shutdown": is_shutdown,
		"is_prone": is_prone,
		"heat": heat,
		"heat_capacity": heat_capacity,
		"functional_weapons": get_functional_weapons().size(),
		"total_weapons": weapons.size(),
		"destroyed_locations": destroyed_locations.duplicate()
	}

func get_all_locations_status() -> Dictionary:
	"""Retorna el estado de armadura y estructura de todas las ubicaciones del mech"""
	var status = {}
	
	# Lista de todas las ubicaciones
	var locations = ["head", "center_torso", "left_torso", "right_torso", 
					 "left_arm", "right_arm", "left_leg", "right_leg"]
	
	for loc in locations:
		status[loc] = {
			"armor": armor[loc]["current"] if armor.has(loc) else 0,
			"max_armor": armor[loc]["max"] if armor.has(loc) else 0,
			"structure": structure[loc]["current"] if structure.has(loc) else 0,
			"max_structure": structure[loc]["max"] if structure.has(loc) else 0
		}
	
	return status
