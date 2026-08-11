# ============================================================================
# test_battle_scene_smoke.gd - Smoke test de instanciación de battle_scene.tscn
# Steel Titans - Framework GUT
#
# battle_scene.gd (ver ROADMAP.md Fase T1) tenía 0% de cobertura porque
# nunca se instanciaba en tests. Este smoke test no cubre lógica de
# gameplay, pero garantiza que la escena arranca sin crashear ni dejar
# referencias nulas en los nodos clave - la red de seguridad mínima antes
# de seguir extrayendo código del god-class.
# ============================================================================
extends GutTest

const BattleSceneScript = preload("res://scripts/battle_scene.gd")

var _scene: Node = null


func before_each():
	var packed: PackedScene = load("res://scenes/battle_scene.tscn")
	_scene = packed.instantiate()
	add_child_autofree(_scene)
	await get_tree().process_frame
	await get_tree().process_frame


func test_battle_scene_ready_without_crashing():
	assert_not_null(_scene, "battle_scene.tscn debe instanciarse")
	assert_true(is_instance_valid(_scene), "La instancia debe seguir siendo válida tras _ready()")


func test_battle_scene_has_hex_grid():
	assert_not_null(_scene.hex_grid, "hex_grid debe existir tras _ready()")


func test_battle_scene_has_turn_manager():
	assert_not_null(_scene.turn_manager, "turn_manager debe existir tras _ready()")


func test_battle_scene_starts_in_singleplayer_by_default():
	# Sin NetworkManager en partida, battle_scene debe caer a singleplayer
	# en vez de quedar en un estado indefinido.
	assert_false(_scene.is_multiplayer_mode, "Sin match activo, debe ser singleplayer")


func test_battle_scene_creates_battle_components():
	assert_not_null(_scene.battle_components, "battle_components (integrator SOLID) debe inicializarse")


func test_battle_scene_creates_long_press_indicator():
	assert_not_null(_scene.long_press_indicator, "long_press_indicator debe crearse en _ready()")
	assert_true(_scene.long_press_indicator is LongPressIndicator, "Debe ser una instancia de LongPressIndicator")


func test_battle_scene_generates_deployment_zones():
	# _setup_battle() -> _setup_deployment_zones() ya se ejecutó durante _ready().
	# Verifica que el pipeline de despliegue corrió de verdad, no solo que no crasheó.
	assert_true(_scene.deployment_zones.has("player"), "Debe existir zona de despliegue del jugador")
	assert_true(_scene.deployment_zones.has("enemy"), "Debe existir zona de despliegue del enemigo")
	assert_gt(_scene.deployment_zones["player"].size(), 0, "La zona del jugador debe tener hexágonos")
	assert_gt(_scene.deployment_zones["enemy"].size(), 0, "La zona del enemigo debe tener hexágonos")


func test_battle_scene_turn_manager_has_valid_phase():
	# El turn_manager debe arrancar en un estado de fase válido (no un valor
	# corrupto), independientemente de si hay mechs desplegados o no.
	var phase: int = _scene.turn_manager.current_phase
	assert_true(GameEnums.TurnPhase.values().has(phase), "current_phase debe ser un TurnPhase válido")
