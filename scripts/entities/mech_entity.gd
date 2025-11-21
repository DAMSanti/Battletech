class_name MechEntity
extends Node2D

## Entidad Mech - Representa un mech con sus propiedades
## Usa sistemas externos para lógica (SOLID: Dependency Inversion)

signal mech_damaged(location: String, damage: int)
signal mech_destroyed()
signal heat_changed(new_heat: int)
signal mech_fell()
signal mech_stood_up()

# Propiedades básicas
@export var mech_name: String = "Atlas"
@export var tonnage: int = 100
@export var armor: int = 300
@export var max_armor: int = 300

# Movimiento
@export var walk_mp: int = 3
@export var run_mp: int = 5
@export var jump_mp: int = 0

# Calor
@export var heat: int = 0
@export var max_heat: int = 30
@export var heat_sinks: int = 10

# Piloto
@export var pilot_name: String = "Pilot"
@export var pilot_gunnery: int = 4
@export var pilot_piloting: int = 5

# Estado
var hex_position: Vector2i = Vector2i(0, 0)
var facing: int = 0  # 0-7 para las 8 direcciones
var is_prone: bool = false
var is_shutdown: bool = false
var moved_this_turn: bool = false
var ran_this_turn: bool = false
var fired_this_turn: bool = false

# Estructura del mech
var armor_locations: Dictionary = {
	"head": 9,
	"center_torso": 47,
	"left_torso": 32,
	"right_torso": 32,
	"left_arm": 34,
	"right_arm": 34,
	"left_leg": 41,
	"right_leg": 41
}

var internal_structure: Dictionary = {
	"head": 3,
	"center_torso": 31,
	"left_torso": 21,
	"right_torso": 21,
	"left_arm": 17,
	"right_arm": 17,
	"left_leg": 21,
	"right_leg": 21
}

# Armas
var weapons: Array = []
var arms_functional: int = 2

# Sprite visual
var sprite: Sprite2D
var sprite_manager: MechSpriteManager

func _ready():
	# Inicializar sprite manager
	sprite_manager = MechSpriteManager.new()
	
	# Crear sprite visual
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# Configurar sprite inicial
	update_visual()

func initialize(hex_pos: Vector2i, team: String):
	hex_position = hex_pos
	name = mech_name + "_" + team

func update_visual():
	# Actualizar sprite según orientación y estado
	var texture = sprite_manager.get_sprite_for_mech(tonnage, facing)
	if texture:
		sprite.texture = texture
	
	# Aplicar efectos visuales según estado
	if is_prone:
		sprite.rotation_degrees = 90  # Rotar sprite para mostrar que está caído
		modulate = Color(0.7, 0.7, 0.7)
	elif is_shutdown:
		modulate = Color(0.5, 0.5, 0.5)
	else:
		sprite.rotation_degrees = 0
		modulate = Color.WHITE
		
	# Actualizar escala según la clase del mech
	var scale_factor = 1.0
	match sprite_manager.get_mech_class(tonnage):
		MechSpriteManager.MechClass.LIGHT: scale_factor = 0.8
		MechSpriteManager.MechClass.MEDIUM: scale_factor = 1.0
		MechSpriteManager.MechClass.HEAVY: scale_factor = 1.2
		MechSpriteManager.MechClass.ASSAULT: scale_factor = 1.4
	
	sprite.scale = Vector2(scale_factor, scale_factor)

## Métodos que delegan a sistemas

func get_walk_distance() -> int:
	return MovementSystem.calculate_walk_distance(self)

func get_run_distance() -> int:
	return MovementSystem.calculate_run_distance(self)

func add_heat(amount: int):
	HeatSystem.add_heat(self, amount)
	heat_changed.emit(heat)
	update_visual()

func dissipate_heat() -> int:
	var dissipated = HeatSystem.dissipate_heat(self)
	heat_changed.emit(heat)
	return dissipated

func check_shutdown() -> bool:
	var shutdown = HeatSystem.check_shutdown(self)
	if shutdown:
		is_shutdown = true
		update_visual()
	return shutdown

func check_ammo_explosion() -> bool:
	return HeatSystem.check_ammo_explosion(self)

func take_damage(location: String, damage: int):
	var armor_remaining = armor_locations.get(location, 0)
	var structure_remaining = internal_structure.get(location, 0)
	
	if armor_remaining > 0:
		var armor_damage = min(damage, armor_remaining)
		armor_locations[location] -= armor_damage
		damage -= armor_damage
		mech_damaged.emit(location, armor_damage)
	
	if damage > 0 and structure_remaining > 0:
		internal_structure[location] -= damage
		mech_damaged.emit(location, damage)
		
		if internal_structure[location] <= 0:
			_handle_location_destroyed(location)
	
	update_visual()

func _handle_location_destroyed(location: String):
	match location:
		"head", "center_torso":
			mech_destroyed.emit()
		"left_arm":
			arms_functional -= 1
		"right_arm":
			arms_functional -= 1

func fall_prone():
	if not is_prone:
		is_prone = true
		take_damage("random", 5)  # Daño por caída
		mech_fell.emit()
		update_visual()

func stand_up():
	if is_prone:
		is_prone = false
		mech_stood_up.emit()
		update_visual()

func check_piloting_skill_roll(modifier: int = 0) -> bool:
	var target = pilot_piloting + modifier
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1)
	return roll >= target

func get_location_armor(location: String) -> int:
	return armor_locations.get(location, 0)

func get_location_structure(location: String) -> int:
	return internal_structure.get(location, 0)

func get_armor_data_for_ui() -> Dictionary:
	# Retorna un diccionario con toda la información de armadura y estructura
	# formateada para el panel de UI
	
	
	var max_armor_by_location = {
		"head": 9,
		"center_torso": 47,
		"left_torso": 32,
		"right_torso": 32,
		"left_arm": 34,
		"right_arm": 34,
		"left_leg": 41,
		"right_leg": 41
	}
	
	var max_structure_by_location = {
		"head": 3,
		"center_torso": 31,
		"left_torso": 21,
		"right_torso": 21,
		"left_arm": 17,
		"right_arm": 17,
		"left_leg": 21,
		"right_leg": 21
	}
	
	return {
		"head": {
			"current": armor_locations.get("head", 0),
			"max": max_armor_by_location.get("head", 0)
		},
		"center_torso": {
			"current": armor_locations.get("center_torso", 0),
			"max": max_armor_by_location.get("center_torso", 0)
		},
		"left_torso": {
			"current": armor_locations.get("left_torso", 0),
			"max": max_armor_by_location.get("left_torso", 0)
		},
		"right_torso": {
			"current": armor_locations.get("right_torso", 0),
			"max": max_armor_by_location.get("right_torso", 0)
		},
		"left_arm": {
			"current": armor_locations.get("left_arm", 0),
			"max": max_armor_by_location.get("left_arm", 0)
		},
		"right_arm": {
			"current": armor_locations.get("right_arm", 0),
			"max": max_armor_by_location.get("right_arm", 0)
		},
		"left_leg": {
			"current": armor_locations.get("left_leg", 0),
			"max": max_armor_by_location.get("left_leg", 0)
		},
		"right_leg": {
			"current": armor_locations.get("right_leg", 0),
			"max": max_armor_by_location.get("right_leg", 0)
		},
		# Estructura
		"head_structure": internal_structure.get("head", 0),
		"head_structure_max": max_structure_by_location.get("head", 0),
		"center_torso_structure": internal_structure.get("center_torso", 0),
		"center_torso_structure_max": max_structure_by_location.get("center_torso", 0),
		"left_torso_structure": internal_structure.get("left_torso", 0),
		"left_torso_structure_max": max_structure_by_location.get("left_torso", 0),
		"right_torso_structure": internal_structure.get("right_torso", 0),
		"right_torso_structure_max": max_structure_by_location.get("right_torso", 0),
		"left_arm_structure": internal_structure.get("left_arm", 0),
		"left_arm_structure_max": max_structure_by_location.get("left_arm", 0),
		"right_arm_structure": internal_structure.get("right_arm", 0),
		"right_arm_structure_max": max_structure_by_location.get("right_arm", 0),
		"left_leg_structure": internal_structure.get("left_leg", 0),
		"left_leg_structure_max": max_structure_by_location.get("left_leg", 0),
		"right_leg_structure": internal_structure.get("right_leg", 0),
		"right_leg_structure_max": max_structure_by_location.get("right_leg", 0)
	}

func reset_turn_state():
	moved_this_turn = false
	ran_this_turn = false
	fired_this_turn = false
