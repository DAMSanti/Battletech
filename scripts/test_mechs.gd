extends Node2D

# Test script para verificar sprites de mechs

var sprite_manager: MechSpriteManager
var light_mech: Sprite2D
var medium_mech: Sprite2D
var assault_mech: Sprite2D

var current_facing = 0
var rotate_timer = 0.0
const ROTATE_INTERVAL = 1.0  # Rotar cada segundo

func _ready():
	sprite_manager = MechSpriteManager.new()
	
	# Crear mechs de prueba
	_setup_test_mechs()

func _setup_test_mechs():
	# Light Mech (25 tons)
	light_mech = Sprite2D.new()
	light_mech.position = Vector2(200, 500)
	light_mech.scale = Vector2(0.8, 0.8)  # Más pequeño
	add_child(light_mech)
	
	# Medium Mech (50 tons)
	medium_mech = Sprite2D.new()
	medium_mech.position = Vector2(360, 500)
	medium_mech.scale = Vector2(1.0, 1.0)  # Tamaño normal
	add_child(medium_mech)
	
	# Assault Mech (100 tons)
	assault_mech = Sprite2D.new()
	assault_mech.position = Vector2(520, 500)
	assault_mech.scale = Vector2(1.4, 1.4)  # Más grande
	add_child(assault_mech)
	
	# Actualizar sprites iniciales
	_update_sprites()

func _process(delta):
	# Rotar mechs cada ROTATE_INTERVAL segundos
	rotate_timer += delta
	if rotate_timer >= ROTATE_INTERVAL:
		rotate_timer = 0.0
		current_facing = (current_facing + 1) % 8
		_update_sprites()

func _update_sprites():
	# Actualizar sprites según el facing actual
	light_mech.texture = sprite_manager.get_sprite_for_mech(25, current_facing)
	medium_mech.texture = sprite_manager.get_sprite_for_mech(50, current_facing)
	assault_mech.texture = sprite_manager.get_sprite_for_mech(100, current_facing)
	
	# Debug info
	print("Facing: %d" % current_facing)