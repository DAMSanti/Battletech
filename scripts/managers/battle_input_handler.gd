extends Node
class_name BattleInputHandler

## Manejador centralizado de input para la batalla
## Separa la lógica de entrada del sistema de batalla principal

signal hex_clicked(hex_position: Vector2i)
signal movement_type_selected(movement_type: int)
signal weapon_selected(weapon_indices: Array)
signal physical_attack_selected(attack_type: String)
signal end_turn_requested()

var hex_grid: HexGrid
var is_input_enabled: bool = true

func _init():
	pass

func setup(grid: HexGrid):
	hex_grid = grid

func enable_input():
	is_input_enabled = true

func disable_input():
	is_input_enabled = false

func handle_input_event(event: InputEvent) -> bool:
	if not is_input_enabled or not hex_grid:
		return false
	
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.pressed):
		var touch_pos = event.position
		var hex = hex_grid.pixel_to_hex(touch_pos - hex_grid.global_position)
		
		if hex_grid.is_valid_hex(hex):
			hex_clicked.emit(hex)
			return true
	
	return false

func request_movement_type(movement_type: int):
	movement_type_selected.emit(movement_type)

func request_weapon_fire(weapon_indices: Array):
	weapon_selected.emit(weapon_indices)

func request_physical_attack(attack_type: String):
	physical_attack_selected.emit(attack_type)

func request_end_turn():
	end_turn_requested.emit()
