## LongPressIndicator - Indicador visual circular de progreso para long-press
## Extraído de battle_scene.gd (ver ROADMAP.md Fase T1) para reducir el
## tamaño del god-class y aislar la lógica de dibujado del estado de juego.
class_name LongPressIndicator
extends Node2D

const VISUAL_DELAY: float = 0.15
const DURATION: float = 0.5
const RADIUS: float = 30.0

## Referencia a la escena de batalla propietaria. Se usa en vez de recibir
## el input_router directamente porque este nodo se crea en _ready() antes
## de que battle_components (y por tanto input_router) exista.
var scene: Node = null


func _process(_delta: float) -> void:
	var router := _get_input_router()
	if router == null or not router.is_long_press_active():
		visible = false
		return

	var timer: float = router.long_press_timer
	position = router.get_long_press_start_pos()
	visible = timer >= VISUAL_DELAY
	queue_redraw()


func _draw() -> void:
	var router := _get_input_router()
	if router == null:
		return

	var timer: float = router.long_press_timer
	var visual_timer: float = max(0.0, timer - VISUAL_DELAY)
	var visual_duration: float = DURATION - VISUAL_DELAY
	var progress: float = min(visual_timer / visual_duration, 1.0)

	draw_circle(Vector2.ZERO, RADIUS, Color(0.2, 0.2, 0.2, 0.5))
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 32, Color.WHITE, 2.0)

	if progress > 0:
		var end_angle: float = -PI / 2 + (TAU * progress)
		draw_arc(Vector2.ZERO, RADIUS - 5, -PI / 2, end_angle, 32, Color.CYAN, 6.0)

	if progress > 0.8:
		draw_circle(Vector2.ZERO, 5.0, Color.CYAN)


func _get_input_router() -> Object:
	if not (scene and scene.use_component_input and scene.battle_components and scene.battle_components.input_router):
		return null
	return scene.battle_components.input_router
