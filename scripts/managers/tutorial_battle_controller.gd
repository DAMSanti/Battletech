class_name TutorialBattleController
extends RefCounted

## TutorialBattleController - Controla una batalla tutorial paso a paso
##
## Este controlador maneja una batalla completamente scriptada donde:
## - El jugador solo puede hacer las acciones indicadas
## - Los eventos están predeterminados (shutdown, ammo explosion, etc)
## - El mapa es fijo y plano para visibilidad clara
## - Cada paso espera a que el jugador complete la acción

# ============================================================
# CONSTANTES - MAPA TUTORIAL FIJO
# ============================================================

# Seed fijo para el tutorial (genera mapa consistente)
const TUTORIAL_MAP_SEED: int = 42424242

# Posiciones fijas de los mechs
const PLAYER_START_HEX := Vector2i(6, 12)   # Centro-sur del mapa
const PLAYER_START_FACING := 0              # Mirando norte
const ENEMY_START_HEX := Vector2i(6, 3)     # Centro-norte del mapa
const ENEMY_START_FACING := 3               # Mirando sur

# Posición a la que se fuerza al enemigo durante SU fase de movimiento real de la ronda 1
const ENEMY_MOVEMENT_TARGET_HEX := Vector2i(6, 8)
const ENEMY_MOVEMENT_TARGET_FACING := 3     # Mirando sur (hacia el jugador)

# ============================================================
# PASOS DEL TUTORIAL
# ============================================================

enum TutorialStep {
	WELCOME,                    # Bienvenida inicial
	DEPLOYMENT_EXPLANATION,     # Explicar fase de despliegue
	DEPLOYMENT_SELECT_HEX,      # Jugador debe desplegar en hex indicado
	DEPLOYMENT_FACING,          # Elegir facing inicial
	ENEMY_DEPLOYMENT,           # Enemigo se despliega (automático)
	INITIATIVE_EXPLANATION,     # Explicar tirada de iniciativa
	INITIATIVE_ROLL,            # Mostrar resultado de iniciativa
	MOVEMENT_TYPES,             # Explicar Walk/Run/Jump
	MOVEMENT_SELECT_WALK,       # Jugador debe seleccionar WALK
	MOVEMENT_SELECT_HEX,        # Jugador debe moverse al hex indicado
	FACING_EXPLANATION,         # Explicar facing
	FACING_SELECT,              # Jugador debe elegir facing
	WEAPONS_EXPLANATION,        # Explicar fase de armas
	WEAPONS_SELECT_TARGET,      # Jugador debe seleccionar enemigo
	WEAPONS_SELECT_WEAPONS,     # Jugador debe seleccionar armas
	WEAPONS_FIRE,               # Jugador dispara, mostrar resultado
	HEAT_EXPLANATION,           # Explicar sistema de calor
	ENEMY_TURN_MOVEMENT,        # Enemigo se mueve (automático)
	ENEMY_TURN_ATTACK,          # Enemigo ataca, jugador recibe daño
	DAMAGE_EXPLANATION,         # Explicar daño y armadura
	END_OF_TURN,                # Cierre explícito del turno 1 (recap antes de pasar de ronda)
	PROMPT_END_TURN,            # Acción requerida: pulsar END de verdad para avanzar de ronda
	WAITING_ROUND2_INITIATIVE,  # Paso silencioso: bloquea la iniciativa automática y la muestra cuando el guion está listo
	ROUND_2_START,              # Inicio ronda 2 (fin del tutorial guiado)
	PHYSICAL_APPROACH,          # Acercarse para ataque físico (sin usar en ronda 1: jugador y enemigo ya quedan adyacentes tras el movimiento)
	PHYSICAL_EXPLANATION,       # Explicar ataques físicos
	PHYSICAL_ATTACK,            # Jugador hace ataque físico
	ENEMY_SHUTDOWN_SETUP,       # Enemigo sobrecalentado
	SHUTDOWN_EXPLANATION,       # Explicar shutdown
	FINAL_ATTACK,               # Ataque final al enemigo apagado
	AMMO_EXPLOSION,             # Explosión de munición (forzada)
	AMMO_EXPLANATION,           # Explicar explosiones de munición
	VICTORY,                    # Victoria y resumen
	COMPLETED                   # Tutorial completado
}

# ============================================================
# ESTADO
# ============================================================

var current_step: TutorialStep = TutorialStep.WELCOME
var battle_scene: Node = null
var is_active: bool = false

# Hexes permitidos para cada paso (si aplica)
var allowed_hexes: Array[Vector2i] = []
var allowed_facings: Array[int] = []
var required_action: String = ""  # "move", "face", "select_target", "fire", "physical"

# Datos del paso actual para validación
var step_data: Dictionary = {}

# Callbacks para bloquear/desbloquear input
signal input_blocked
signal input_unblocked
signal hint_requested(hint_data: Dictionary)
signal force_action(action_type: String, action_data: Dictionary)
signal tutorial_completed

# ============================================================
# DATOS DEL MAPA TUTORIAL
# ============================================================

## Genera los datos del mapa tutorial (plano, sin obstáculos en el centro)
static func generate_tutorial_map_data(width: int, height: int) -> Dictionary:
	var hex_data: Dictionary = {}
	
	for q in range(width):
		for r in range(height):
			var pos = Vector2i(q, r)
			
			# Todo el mapa es terreno claro con elevación 0
			# Excepto algunos detalles decorativos en los bordes
			var terrain = TerrainType.Type.CLEAR
			var elevation = 0
			
			# Añadir algunos árboles en los bordes para que no sea totalmente vacío
			if _is_border_hex(q, r, width, height):
				# 30% de probabilidad de árbol en bordes
				if (q * 7 + r * 13) % 10 < 3:
					terrain = TerrainType.Type.LIGHT_WOODS
			
			hex_data[pos] = {
				"terrain": terrain,
				"elevation": elevation,
				"unit": null
			}
	
	return hex_data

static func _is_border_hex(q: int, r: int, width: int, height: int) -> bool:
	return q <= 1 or q >= width - 2 or r <= 1 or r >= height - 2

# ============================================================
# CONTROL DEL TUTORIAL
# ============================================================

func start(scene: Node):
	"""Inicia el controlador del tutorial"""
	battle_scene = scene
	is_active = true
	current_step = TutorialStep.WELCOME
	
	Log.info("Tutorial", "TutorialBattleController started")
	
	# Mostrar bienvenida después de un breve delay
	await battle_scene.get_tree().create_timer(0.5).timeout
	_show_step(TutorialStep.WELCOME)

func _show_step(step: TutorialStep):
	"""Muestra el hint y configura el paso actual"""
	current_step = step
	allowed_hexes.clear()
	allowed_facings.clear()
	required_action = ""
	step_data.clear()
	
	match step:
		TutorialStep.WELCOME:
			_show_welcome()
		TutorialStep.DEPLOYMENT_EXPLANATION:
			_show_deployment_explanation()
		TutorialStep.DEPLOYMENT_SELECT_HEX:
			_setup_deployment_hex_selection()
		TutorialStep.DEPLOYMENT_FACING:
			_setup_deployment_facing()
		TutorialStep.ENEMY_DEPLOYMENT:
			_execute_enemy_deployment()
		TutorialStep.INITIATIVE_EXPLANATION:
			_show_initiative_explanation()
		TutorialStep.INITIATIVE_ROLL:
			_show_initiative_roll()
		TutorialStep.MOVEMENT_TYPES:
			_show_movement_types()
		TutorialStep.MOVEMENT_SELECT_WALK:
			_setup_movement_selection()
		TutorialStep.MOVEMENT_SELECT_HEX:
			_setup_hex_selection()
		TutorialStep.FACING_EXPLANATION:
			_show_facing_explanation()
		TutorialStep.FACING_SELECT:
			_setup_facing_selection()
		TutorialStep.WEAPONS_EXPLANATION:
			_show_weapons_explanation()
		TutorialStep.WEAPONS_SELECT_TARGET:
			_setup_target_selection()
		TutorialStep.WEAPONS_SELECT_WEAPONS:
			_setup_weapon_selection()
		TutorialStep.WEAPONS_FIRE:
			_execute_weapon_fire()
		TutorialStep.HEAT_EXPLANATION:
			_show_heat_explanation()
		TutorialStep.ENEMY_TURN_MOVEMENT:
			_execute_enemy_movement()
		TutorialStep.ENEMY_TURN_ATTACK:
			_execute_enemy_attack()
		TutorialStep.DAMAGE_EXPLANATION:
			_show_damage_explanation()
		TutorialStep.END_OF_TURN:
			_show_end_of_turn()
		TutorialStep.PROMPT_END_TURN:
			_setup_prompt_end_turn()
		TutorialStep.WAITING_ROUND2_INITIATIVE:
			_setup_waiting_round2_initiative()
		TutorialStep.ROUND_2_START:
			_show_round_2_start()
		TutorialStep.PHYSICAL_APPROACH:
			_setup_physical_approach()
		TutorialStep.PHYSICAL_EXPLANATION:
			_show_physical_explanation()
		TutorialStep.PHYSICAL_ATTACK:
			_setup_physical_attack()
		TutorialStep.ENEMY_SHUTDOWN_SETUP:
			_setup_enemy_shutdown()
		TutorialStep.SHUTDOWN_EXPLANATION:
			_show_shutdown_explanation()
		TutorialStep.FINAL_ATTACK:
			_setup_final_attack()
		TutorialStep.AMMO_EXPLOSION:
			_trigger_ammo_explosion()
		TutorialStep.AMMO_EXPLANATION:
			_show_ammo_explanation()
		TutorialStep.VICTORY:
			_show_victory()
		TutorialStep.COMPLETED:
			_complete_tutorial()

# ============================================================
# VALIDACIÓN DE ACCIONES DEL JUGADOR
# ============================================================

func is_hex_allowed(hex: Vector2i) -> bool:
	"""Verifica si el jugador puede moverse/interactuar con este hex"""
	if not is_active:
		return true  # Si no está activo, permitir todo
	
	if allowed_hexes.is_empty():
		return true  # Si no hay restricción, permitir todo
	
	return hex in allowed_hexes

func is_facing_allowed(facing: int) -> bool:
	"""Verifica si el jugador puede elegir este facing"""
	if not is_active:
		return true
	
	if allowed_facings.is_empty():
		return true
	
	return facing in allowed_facings

func is_action_allowed(action: String) -> bool:
	"""Verifica si esta acción está permitida en el paso actual"""
	if not is_active:
		return true
	
	if required_action.is_empty():
		return true
	
	return action == required_action

func can_select_movement_type(type: String) -> bool:
	"""Verifica si se puede seleccionar este tipo de movimiento"""
	if current_step == TutorialStep.MOVEMENT_SELECT_WALK:
		return type == "walk"  # Solo permitir WALK en el tutorial
	return true

func can_skip_movement() -> bool:
	"""El tutorial no permite saltar movimiento en ciertos pasos"""
	if current_step in [TutorialStep.MOVEMENT_SELECT_HEX, TutorialStep.PHYSICAL_APPROACH]:
		return false
	return true

func can_end_turn() -> bool:
	"""El botón END termina la ACTIVACIÓN de la unidad actual (turn_manager.
	complete_unit_activation), no la ronda - las rondas avanzan solas cuando
	todas las unidades han actuado en todas las fases. La única fase donde el
	motor de verdad necesita que el jugador pulse END es la de MOVIMIENTO: el
	disparo y el ataque físico completan la activación automáticamente al
	ejecutarse (ver battle_scene._end_weapon_attack_phase), pero el movimiento
	no, así que sin pulsar END aquí el turno nunca avanza a la fase de armas.
	En despliegue, iniciativa, ataque, melee y calor el tutorial es 100%
	guiado y END no tiene ninguna acción legítima que completar."""
	return current_step in [
		TutorialStep.MOVEMENT_SELECT_HEX,
		TutorialStep.FACING_EXPLANATION,
		TutorialStep.FACING_SELECT,
		TutorialStep.PHYSICAL_APPROACH,
		# El turno 1 ya está completo (movimiento, armas, melee, calor) y se
		# le pide activamente al jugador que pulse END para avanzar de ronda
		# - ver _setup_prompt_end_turn()/on_end_turn_pressed().
		TutorialStep.PROMPT_END_TURN,
	]

func can_skip_attack() -> bool:
	"""El tutorial no permite saltar ataques en ciertos pasos"""
	if current_step in [TutorialStep.WEAPONS_FIRE, TutorialStep.PHYSICAL_ATTACK, TutorialStep.FINAL_ATTACK]:
		return false
	return true

# ============================================================
# CALLBACKS DESDE BATTLE_SCENE
# ============================================================

func on_movement_type_selected(type: String):
	"""Llamado cuando el jugador selecciona tipo de movimiento"""
	if current_step == TutorialStep.MOVEMENT_SELECT_WALK and type == "walk":
		_advance_to(TutorialStep.MOVEMENT_SELECT_HEX)

func on_deployment_completed(hex: Vector2i):
	"""Llamado cuando el jugador despliega su mech"""
	if current_step == TutorialStep.DEPLOYMENT_SELECT_HEX:
		if hex in allowed_hexes or allowed_hexes.is_empty():
			_advance_to(TutorialStep.DEPLOYMENT_FACING)

func on_deployment_facing_selected(_facing: int):
	"""Llamado cuando el jugador elige facing de deployment"""
	if current_step == TutorialStep.DEPLOYMENT_FACING:
		_advance_to(TutorialStep.ENEMY_DEPLOYMENT)

func on_movement_completed(hex: Vector2i):
	"""Llamado cuando el jugador completa su movimiento"""
	if current_step == TutorialStep.MOVEMENT_SELECT_HEX:
		if hex in allowed_hexes or allowed_hexes.is_empty():
			_advance_to(TutorialStep.FACING_EXPLANATION)
	elif current_step == TutorialStep.PHYSICAL_APPROACH:
		# Bug reportado: si el hex de destino no es realmente adyacente al
		# enemigo, el tutorial avanzaba igualmente a PHYSICAL_ATTACK, donde
		# el ataque fisico real es rechazado por falta de objetivo en rango
		# y el tutorial se queda bloqueado esperando on_physical_attack_completed().
		if hex in allowed_hexes or allowed_hexes.is_empty():
			_advance_to(TutorialStep.PHYSICAL_EXPLANATION)

func on_weapon_attack_phase():
	"""Llamado cuando empieza la fase de ataque con armas"""
	Log.info("Tutorial", "on_weapon_attack_phase called, current_step=%d" % current_step)
	
	# Solo procesar si estamos en un paso de movimiento (evitar llamadas duplicadas)
	if current_step < TutorialStep.MOVEMENT_TYPES or current_step > TutorialStep.FACING_SELECT:
		Log.info("Tutorial", "Ignoring weapon_attack_phase - not in movement step")
		return
	
	# Cerrar el hint actual de movimiento SIN notificar (para evitar avanzar dos veces)
	# IMPORTANTE: Esperar a que termine antes de mostrar el nuevo hint
	if battle_scene and battle_scene.tutorial_hint_popup and battle_scene.tutorial_hint_popup.visible:
		await battle_scene.tutorial_hint_popup.hide_hint_silent()
		Log.info("Tutorial", "Forced hint popup to hide (silent)")
	
	Log.info("Tutorial", "Transitioning to WEAPONS_EXPLANATION from step %d" % current_step)
	
	# Avanzar a la explicación de armas
	_advance_to(TutorialStep.WEAPONS_EXPLANATION)

func on_facing_selected(facing: int):
	"""Llamado cuando el jugador selecciona facing"""
	if current_step == TutorialStep.DEPLOYMENT_FACING:
		# En deployment, aplicar el facing al mech del jugador
		if facing == 0:  # Solo norte permitido
			if battle_scene and battle_scene.player_mechs.size() > 0:
				var player_mech = battle_scene.player_mechs[0]
				player_mech.facing = facing
				if player_mech.has_method("update_facing_visual"):
					player_mech.update_facing_visual()
				Log.info("Tutorial", "Player facing set to %d (North)" % facing)
			_advance_to(TutorialStep.ENEMY_DEPLOYMENT)
	elif current_step == TutorialStep.FACING_SELECT:
		# NO avanzar aquí - esperar a que llegue weapon_attack_phase
		Log.info("Tutorial", "Facing selected, waiting for weapon_attack_phase event")

func on_target_selected():
	"""Llamado cuando el jugador selecciona un objetivo"""
	Log.info("Tutorial", "on_target_selected called, current_step=%d" % current_step)
	if current_step == TutorialStep.WEAPONS_SELECT_TARGET:
		_advance_to(TutorialStep.WEAPONS_SELECT_WEAPONS)

func on_weapons_selected():
	"""Llamado cuando el jugador selecciona armas"""
	Log.info("Tutorial", "on_weapons_selected called, current_step=%d" % current_step)
	if current_step == TutorialStep.WEAPONS_SELECT_WEAPONS:
		_advance_to(TutorialStep.WEAPONS_FIRE)

func on_weapon_fired():
	"""Llamado después de disparar"""
	Log.info("Tutorial", "on_weapon_fired called, current_step=%d" % current_step)
	if current_step == TutorialStep.WEAPONS_FIRE:
		# Esperar un momento para que se vea el resultado
		await battle_scene.get_tree().create_timer(1.5).timeout
		# El motor real pasa de WEAPON_ATTACK a PHYSICAL_ATTACK antes que a
		# HEAT (ver turn_manager.advance_phase). El tutorial saltaba
		# directamente a la explicación de calor sin pararse en el ataque a
		# melee - el jugador y el enemigo ya quedan adyacentes tras el
		# movimiento forzado de la ronda 1 (6,9)/(6,8), así que no hace
		# falta un paso de aproximación: se puede atacar cuerpo a cuerpo ya.
		_advance_to(TutorialStep.PHYSICAL_EXPLANATION)

func on_physical_attack_completed():
	"""Llamado después de ataque físico"""
	if current_step == TutorialStep.PHYSICAL_ATTACK:
		await battle_scene.get_tree().create_timer(1.0).timeout
		_advance_to(TutorialStep.HEAT_EXPLANATION)
	elif current_step == TutorialStep.FINAL_ATTACK:
		await battle_scene.get_tree().create_timer(1.0).timeout
		_advance_to(TutorialStep.AMMO_EXPLOSION)

func on_initiative_completed(data: Dictionary):
	"""Llamado cuando se completa la pantalla de iniciativa"""
	if current_step == TutorialStep.WAITING_ROUND2_INITIATIVE:
		# Iniciativa de la ronda 2 ya resuelta (mostrada manualmente desde
		# _setup_waiting_round2_initiative) - pasar directo al cierre del
		# tutorial guiado, sin repetir la explicación de "quién gana".
		_advance_to(TutorialStep.ROUND_2_START)
		return

	if current_step == TutorialStep.INITIATIVE_ROLL:
		# Bloquear input mientras mostramos el resultado
		input_blocked.emit()
		
		# Calcular totales desde los arrays de iniciativa
		var player_initiatives = data.get("player_initiatives", [7])
		var enemy_initiatives = data.get("enemy_initiatives", [5])
		
		var player_total = 0
		for init in player_initiatives:
			player_total += init
		
		var enemy_total = 0
		for init in enemy_initiatives:
			enemy_total += init
		
		var player_won = player_total >= enemy_total
		
		var result_text: String
		var result_title: String
		
		if player_won:
			result_title = "🎲 YOU WON INITIATIVE!"
			result_text = """You rolled [color=cyan]%d[/color] vs enemy's [color=red]%d[/color]

[color=yellow]WINNER moves LAST![/color]

This means the [color=red]ENEMY[/color] must move first.
You'll see what they do, then [color=green]react strategically[/color]!""" % [player_total, enemy_total]
		else:
			result_title = "🎲 ENEMY WON INITIATIVE"
			result_text = """You rolled [color=cyan]%d[/color] vs enemy's [color=red]%d[/color]

[color=yellow]LOSER moves FIRST![/color]

You must move first this turn.
The enemy will see your move and react!""" % [player_total, enemy_total]
		
		hint_requested.emit({
			"id": "initiative_result",
			"title": result_title,
			"content": result_text,
			"tip": "💡 In BattleTech, moving LAST is usually advantageous!",
			"button_text": "START BATTLE",
			"blocks_game": true
		})
		
		# El siguiente paso se mostrará cuando el usuario cierre este hint

func on_hint_dismissed():
	"""Llamado cuando el jugador cierra un hint"""
	# Avanzar al siguiente paso si el hint actual era informativo
	match current_step:
		TutorialStep.WELCOME:
			_advance_to(TutorialStep.DEPLOYMENT_EXPLANATION)
		TutorialStep.DEPLOYMENT_EXPLANATION:
			_advance_to(TutorialStep.DEPLOYMENT_SELECT_HEX)
		TutorialStep.ENEMY_DEPLOYMENT:
			_advance_to(TutorialStep.INITIATIVE_EXPLANATION)
		TutorialStep.INITIATIVE_EXPLANATION:
			_advance_to(TutorialStep.INITIATIVE_ROLL)
		TutorialStep.INITIATIVE_ROLL:
			# Después del hint de resultado de iniciativa, mostrar tipos de movimiento
			_advance_to(TutorialStep.MOVEMENT_TYPES)
		TutorialStep.MOVEMENT_TYPES:
			_advance_to(TutorialStep.MOVEMENT_SELECT_WALK)
		TutorialStep.FACING_EXPLANATION:
			_advance_to(TutorialStep.FACING_SELECT)
		TutorialStep.WEAPONS_EXPLANATION:
			_advance_to(TutorialStep.WEAPONS_SELECT_TARGET)
		TutorialStep.HEAT_EXPLANATION:
			# Desbloquear la fase de calor cuando el usuario cierra el hint
			var tutorial_mgr = battle_scene.get_node_or_null("/root/TutorialManager")
			if tutorial_mgr:
				tutorial_mgr.heat_phase_blocked = false
			_advance_to(TutorialStep.ENEMY_TURN_MOVEMENT)
		TutorialStep.DAMAGE_EXPLANATION:
			_advance_to(TutorialStep.END_OF_TURN)
		TutorialStep.END_OF_TURN:
			_advance_to(TutorialStep.PROMPT_END_TURN)
		TutorialStep.ROUND_2_START:
			# El tutorial guiado termina aquí - el jugador ya ha visto un
			# round completo (iniciativa, movimiento, ataque, calor, turno
			# enemigo). Se cierra el tutorial y se le lleva a elegir mechs
			# para una partida real en vez de continuar el guion de melee/
			# shutdown/explosión de munición.
			_end_tutorial_and_return_to_mech_select()
		TutorialStep.PHYSICAL_EXPLANATION:
			_advance_to(TutorialStep.PHYSICAL_ATTACK)
		TutorialStep.SHUTDOWN_EXPLANATION:
			_advance_to(TutorialStep.FINAL_ATTACK)
		TutorialStep.AMMO_EXPLANATION:
			_advance_to(TutorialStep.VICTORY)
		TutorialStep.VICTORY:
			_advance_to(TutorialStep.COMPLETED)

func _advance_to(next_step: TutorialStep):
	"""Avanza al siguiente paso del tutorial"""
	Log.debug("Tutorial", "Advancing from %d to %d" % [current_step, next_step])
	_show_step(next_step)

# ============================================================
# IMPLEMENTACIÓN DE CADA PASO
# ============================================================

func _show_welcome():
	input_blocked.emit()
	hint_requested.emit({
		"id": "welcome",
		"title": "🎮 WELCOME TO STEEL TITANS!",
		"content": """Welcome, MechWarrior! This tutorial will teach you the basics of BattleMech combat.

You command an [color=cyan]ATLAS AS7-D[/color] - a 100-ton assault mech, one of the most fearsome war machines ever built.

Your enemy: A [color=red]HUNCHBACK HBK-4G[/color] - a 50-ton medium mech with a devastating AC/20.

Let's learn how to pilot your mech to victory!""",
		"tip": "💡 Follow each step carefully. The tutorial will guide you through every action.",
		"button_text": "LET'S BEGIN!",
		"blocks_game": true
	})

func _show_deployment_explanation():
	input_blocked.emit()
	hint_requested.emit({
		"id": "deployment_explain",
		"title": "📍 DEPLOYMENT PHASE",
		"content": """Before combat begins, you must [color=cyan]DEPLOY[/color] your mech on the battlefield.

Your deployment zone is shown in the [color=green]southern part[/color] of the map.

You need to:
1. [color=yellow]Choose a hex[/color] to place your mech
2. [color=yellow]Choose a facing direction[/color]

Position wisely - it affects your first moves!""",
		"tip": "💡 Deploy where you have good line of sight to the enemy zone.",
		"button_text": "DEPLOY MY MECH",
		"blocks_game": true
	})

func _setup_deployment_hex_selection():
	input_unblocked.emit()
	
	# Hex recomendado para el tutorial (centro de la zona de deployment)
	allowed_hexes = [PLAYER_START_HEX]
	required_action = "deploy"
	
	# IMPORTANTE: Configurar allowed_facings AHORA para que cuando el usuario
	# haga click en el hex, el facing selector ya sepa que solo mostrar Norte
	allowed_facings = [0]  # Solo norte
	
	Log.info("Tutorial", "Setting up deployment hex selection: allowed_hexes=%s, allowed_facings=%s" % [allowed_hexes, allowed_facings])
	
	# Forzar highlight del hex permitido
	force_action.emit("highlight_hexes", {"hexes": allowed_hexes, "color": "tutorial"})
	
	hint_requested.emit({
		"id": "deploy_hex",
		"title": "📍 DEPLOYMENT",
		"content": "Tap the [color=cyan]highlighted hex[/color] to deploy your Atlas",
		"action_required": true,
		"highlight_hex": PLAYER_START_HEX,
		"blocks_game": false
	})

func _setup_deployment_facing():
	# En el tutorial, mostramos el facing selector pero solo con norte habilitado
	input_unblocked.emit()
	
	# Configurar que solo norte está permitido
	allowed_facings = [0]  # Solo norte
	required_action = "facing"
	
	# Mostrar hint explicando el facing
	hint_requested.emit({
		"id": "deploy_facing",
		"title": "🧭 CHOOSE FACING",
		"content": """Your Atlas is deployed! Now choose which direction it [color=cyan]faces[/color].

In BattleTech, facing determines:
• [color=green]Front arc[/color] - strongest armor
• [color=yellow]Side arcs[/color] - weaker armor  
• [color=red]Rear arc[/color] - weakest armor

For this tutorial, select [color=cyan]NORTH[/color] to face the enemy.""",
		"tip": "💡 Facing also affects which weapons can fire at targets.",
		"action_required": true,
		"blocks_game": false
	})
	
	# Obtener posición del hex del jugador en pantalla para mostrar el selector
	var screen_pos = Vector2(400, 300)  # Posición por defecto
	if battle_scene and battle_scene.has_method("get_screen_position_for_hex"):
		screen_pos = battle_scene.get_screen_position_for_hex(PLAYER_START_HEX)
	
	# Mostrar el facing selector en modo tutorial (solo norte habilitado)
	if battle_scene and battle_scene.has_method("_ui_show_facing_selector_tutorial"):
		battle_scene._ui_show_facing_selector_tutorial(screen_pos, 0, PLAYER_START_HEX)
	elif battle_scene and battle_scene.ui and battle_scene.ui.has_method("show_facing_selector_tutorial"):
		battle_scene.ui.show_facing_selector_tutorial(screen_pos, 0, PLAYER_START_HEX)

func _execute_enemy_deployment():
	input_blocked.emit()
	
	# Bloquear la pantalla de iniciativa para que no aparezca todavía
	force_action.emit("block_initiative", {})
	
	# Forzar deployment del enemigo
	force_action.emit("enemy_deploy", {
		"hex": ENEMY_START_HEX,
		"facing": ENEMY_START_FACING
	})
	
	hint_requested.emit({
		"id": "enemy_deploy",
		"title": "⚔️ ENEMY DEPLOYED!",
		"content": """The enemy [color=red]HUNCHBACK[/color] has deployed in the north!

It's facing south - directly toward you.

Both mechs are now on the field. [color=yellow]Combat begins![/color]""",
		"button_text": "CONTINUE",
		"blocks_game": true
	})

func _show_initiative_explanation():
	input_blocked.emit()
	hint_requested.emit({
		"id": "initiative_explain",
		"title": "🎲 INITIATIVE PHASE",
		"content": """Every turn begins with an [color=yellow]INITIATIVE ROLL[/color].

Both sides roll 2D6 (two six-sided dice).

[color=red]The LOSER moves first[/color]
[color=green]The WINNER moves last[/color]

Moving LAST is usually better - you can see what your enemy does and react!""",
		"tip": "💡 Lighter mechs get +1 to initiative for every 5 tons under 100.",
		"button_text": "ROLL INITIATIVE",
		"blocks_game": true
	})

func _show_initiative_roll():
	# Desbloquear la pantalla de iniciativa
	force_action.emit("unblock_initiative", {})
	
	# Forzar que el jugador gane la iniciativa (para que vea al enemigo moverse primero)
	force_action.emit("set_initiative", {"player_wins": true})
	
	# Abrir la pantalla de iniciativa real
	if battle_scene and battle_scene.has_method("show_initiative_screen"):
		battle_scene.show_initiative_screen()
	
	# No mostrar hint aquí - esperar a que la pantalla de iniciativa termine
	# El siguiente hint se mostrará cuando se cierre la pantalla de iniciativa

func _show_movement_types():
	# Centrar la cámara en el mech del jugador
	_center_camera_on_player()
	
	# Desbloquear input para que el selector de movimiento pueda mostrarse
	input_unblocked.emit()
	
	# Pequeño delay para que la cámara se centre antes de mostrar UI
	await battle_scene.get_tree().create_timer(0.3).timeout
	
	# Mostrar el selector de movimiento
	if battle_scene and battle_scene.player_mechs.size() > 0:
		var player_mech = battle_scene.player_mechs[0]
		if battle_scene.ui and battle_scene.ui.has_method("show_movement_type_selector"):
			battle_scene.ui.show_movement_type_selector(player_mech)
	
	hint_requested.emit({
		"id": "movement_types",
		"title": "🦿 MOVEMENT OPTIONS",
		"content": """Now it's your turn to move! You have three options:

[color=cyan]🚶 WALK[/color] - Move up to [color=cyan]3 hexes[/color]
  • +1 to-hit modifier (harder to hit)
  • Can fire all weapons

[color=yellow]🏃 RUN[/color] - Move up to [color=yellow]5 hexes[/color]
  • +2 to-hit modifier
  • [color=red]CANNOT fire weapons![/color]

[color=green]🚀 JUMP[/color] - [color=gray]Not available (no jump jets)[/color]""",
		"tip": "💡 For now, choose WALK so you can shoot after moving.",
		"button_text": "UNDERSTOOD",
		"blocks_game": false
	})


func _center_camera_on_player():
	"""Centra la cámara en el mech del jugador"""
	if not battle_scene or battle_scene.player_mechs.size() == 0:
		return
	
	var player_mech = battle_scene.player_mechs[0]
	var target_pos = battle_scene.hex_grid.hex_to_pixel(player_mech.hex_position)
	
	if battle_scene.camera:
		var tween = battle_scene.create_tween()
		tween.tween_property(battle_scene.camera, "position", target_pos, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _setup_movement_selection():
	input_unblocked.emit()
	required_action = "select_movement_type"
	
	hint_requested.emit({
		"id": "select_walk",
		"title": "🚶 SELECT WALK",
		"content": """[color=cyan]Tap the WALK button[/color] in the movement panel to begin moving.

Walking lets you move AND attack in the same turn.""",
		"tip": "⚡ Action required: Tap WALK",
		"button_text": "",  # No button, espera acción
		"blocks_game": false,
		"highlight_ui": "walk_button"
	})

const MOVEMENT_TARGET_HEX := Vector2i(6, 9)  # Único hex permitido - 3 hexes al norte, máximo walk del Atlas

func _setup_hex_selection():
	# Un único hex permitido (no un abanico de opciones): el tutorial guía a
	# una posición exacta para que el resto del guion (facing, rango de
	# armas, aproximación en la ronda 2) sea siempre predecible.
	allowed_hexes = [MOVEMENT_TARGET_HEX]
	required_action = "move"

	# Highlight del hex permitido (el overlay normal de rango de movimiento
	# se oculta automáticamente mientras haya tutorial_hexes activos - ver
	# battle_overlay_manager._build_movement_overlays)
	force_action.emit("highlight_hexes", {"hexes": allowed_hexes, "color": "tutorial"})

	hint_requested.emit({
		"id": "select_hex",
		"title": "📍 MOVE YOUR MECH",
		"content": """The [color=cyan]highlighted hex[/color] shows exactly where to walk.

[color=yellow]Tap it[/color] to move there.""",
		"tip": "⚡ Action required: Tap the highlighted hex",
		"button_text": "",
		"blocks_game": false
	})

func _show_facing_explanation():
	input_blocked.emit()
	hint_requested.emit({
		"id": "facing_explain",
		"title": "🧭 FACING DIRECTION",
		"content": """After moving, you must choose which direction your mech faces.

[color=green]FRONT[/color] - Strongest armor
[color=yellow]SIDES[/color] - Medium armor
[color=red]REAR[/color] - Weakest armor (avoid showing your back!)

Your weapons have firing arcs:
• [color=cyan]Torso weapons[/color] can fire forward and to the sides
• [color=cyan]Arm weapons[/color] have wider arcs""",
		"tip": "💡 Always try to face your enemy!",
		"button_text": "CHOOSE FACING",
		"blocks_game": true
	})

func _setup_facing_selection():
	input_unblocked.emit()
	# Permitir solo facing hacia el enemigo (norte)
	allowed_facings = [0, 1, 5]  # N, NE, NW
	required_action = "select_facing"
	
	hint_requested.emit({
		"id": "select_facing",
		"title": "🧭 FACE THE ENEMY",
		"content": """[color=cyan]Tap the direction arrows[/color] to choose your facing.

Face [color=yellow]NORTH[/color] toward the enemy Hunchback.""",
		"tip": "⚡ Action required: Select facing direction",
		"button_text": "",
		"blocks_game": false
	})

func _show_weapons_explanation():
	input_blocked.emit()
	hint_requested.emit({
		"id": "weapons_explain",
		"title": "🔫 WEAPON ATTACK PHASE",
		"content": """Time to attack! Your Atlas has powerful weapons:

[color=cyan]AC/20[/color] - 20 damage, short range
[color=orange]Medium Lasers (x2)[/color] - 5 damage each
[color=green]LRM-20[/color] - 20 damage, long range
[color=yellow]SRM-6[/color] - 12 damage, short range

First, select your target. Then choose which weapons to fire.""",
		"tip": "⚠️ Each weapon generates HEAT. Don't overheat!",
		"button_text": "SELECT TARGET",
		"blocks_game": true
	})

func _setup_target_selection():
	input_unblocked.emit()
	required_action = "select_target"
	
	hint_requested.emit({
		"id": "select_target",
		"title": "🎯 SELECT TARGET",
		"content": """[color=cyan]Tap on the enemy HUNCHBACK[/color] to target it.

The targeting computer will calculate hit chances based on:
• Range to target
• Your movement (walking = +1 difficulty)
• Target's movement
• Cover and terrain""",
		"tip": "⚡ Action required: Tap the enemy mech",
		"button_text": "",
		"blocks_game": false
	})

func _setup_weapon_selection():
	required_action = "select_weapons"
	
	hint_requested.emit({
		"id": "select_weapons",
		"title": "🔫 SELECT WEAPONS",
		"content": """[color=cyan]Tap a weapon's name[/color] for details, or its [color=cyan]switch[/color] to select it.

Select [color=cyan]AC/20[/color] + [color=orange]Medium Lasers[/color], watch your [color=red]HEAT[/color].""",
		"tip": "⚡ Select weapons, then tap FIRE",
		"button_text": "",
		"blocks_game": false,
		"highlight_ui": "weapon_panel"
	})

func _execute_weapon_fire():
	# El disparo ya se ejecutó, mostrar resultado
	hint_requested.emit({
		"id": "fire_result",
		"title": "💥 WEAPONS FIRED!",
		"content": """Your weapons have fired!

Watch the damage apply to the enemy mech.

The [color=yellow]hit location[/color] is randomly determined:
• Torso hits are most common
• Head hits are rare but devastating
• Arm/Leg hits can cripple the enemy""",
		"tip": "💡 Destroyed weapons can't fire. Destroyed legs slow the mech.",
		"button_text": "",
		"blocks_game": false
	})

func _show_heat_explanation():
	input_blocked.emit()

	# Bloquear la fase de calor hasta que el usuario cierre este hint
	var tutorial_mgr = battle_scene.get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		tutorial_mgr.heat_phase_blocked = true

	# Bug: la pantalla de iniciativa de la ronda 2 se dispara automáticamente
	# en cuanto termina la fase de calor real (turn_manager.start_turn()),
	# lo cual podía coincidir con el resto del guion post-combate (recap del
	# turno del enemigo + explicación de daño) que todavía se está mostrando,
	# dejando dos modales bloqueantes compitiendo a la vez. Se bloquea aquí
	# y se vuelve a pedir manualmente cuando el guion está listo, en
	# _setup_waiting_round2_initiative() - mismo patrón que ya se usa para
	# bloquear la iniciativa de la ronda 1 durante el despliegue del enemigo.
	force_action.emit("block_initiative", {})
	
	hint_requested.emit({
		"id": "heat_explain",
		"title": "🌡️ HEAT MANAGEMENT",
		"content": """Your mech generated [color=red]HEAT[/color] from firing!

[color=orange]Heat Sources:[/color]
• Energy weapons (lasers, PPCs)
• Jump jets
• Some ballistic weapons

[color=cyan]Heat Sinks:[/color] Dissipate heat each turn

[color=red]DANGER![/color] At 30 heat, your mech [color=red]SHUTS DOWN[/color]!
A shutdown mech cannot move or attack until it cools.""",
		"tip": "⚠️ Manage your heat! Firing everything every turn will overheat you.",
		"button_text": "UNDERSTOOD",
		"blocks_game": true
	})

func _execute_enemy_movement():
	input_blocked.emit()
	
	# Nota: el movimiento real ya se aplicó antes, en la fase de movimiento
	# real del enemigo (ver battle_scene._handle_enemy_unit_activation ->
	# TutorialManager.force_enemy_movement_to_target). Re-emitirlo aquí es
	# idempotente (mismo hex) y mantiene el recap narrativo funcionando
	# aunque algo cambie el orden en el futuro.
	force_action.emit("enemy_move", {"hex": ENEMY_MOVEMENT_TARGET_HEX, "facing": ENEMY_MOVEMENT_TARGET_FACING})

	hint_requested.emit({
		"id": "enemy_moving",
		"title": "⚔️ ENEMY TURN",
		"content": """The enemy Hunchback moved into position!

It advanced toward you during its movement phase.

Next, it will attack you.""",
		"tip": "👀 Pay attention to enemy movement to predict their attacks.",
		"button_text": "",
		"blocks_game": false,
		"auto_dismiss": 2.0  # Auto-cerrar después de 2 segundos
	})
	
	await battle_scene.get_tree().create_timer(2.5).timeout
	_advance_to(TutorialStep.ENEMY_TURN_ATTACK)

func _execute_enemy_attack():
	# Forzar que el enemigo ataque y haga daño controlado
	force_action.emit("enemy_attack", {
		"damage": 15,
		"location": "left_torso",
		"weapon": "AC/20"
	})
	
	await battle_scene.get_tree().create_timer(2.0).timeout
	_advance_to(TutorialStep.DAMAGE_EXPLANATION)

func _show_damage_explanation():
	input_blocked.emit()
	hint_requested.emit({
		"id": "damage_explain",
		"title": "🛡️ DAMAGE & ARMOR",
		"content": """You took damage! Here's how it works:

[color=cyan]ARMOR[/color] - Outer protection, absorbs damage first
[color=yellow]STRUCTURE[/color] - Internal frame, if armor is gone
[color=red]CRITICAL HITS[/color] - Can destroy weapons & equipment

Each body part has separate armor:
• Head, Center Torso, Side Torsos
• Arms, Legs
• Rear armor is thinner!

[color=gray]Long-press your mech to see the damage display.[/color]""",
		"tip": "💡 Focus fire on one location to break through armor faster!",
		"button_text": "CONTINUE",
		"blocks_game": true
	})

func _show_end_of_turn():
	"""Cierre explícito del turno 1: movimiento, disparo, melee, calor y el
	turno del enemigo ya han pasado. Antes de esto el tutorial saltaba
	directamente a la iniciativa de la ronda 2 sin marcar claramente que el
	turno había terminado."""
	input_blocked.emit()
	hint_requested.emit({
		"id": "end_of_turn",
		"title": "🏁 END OF TURN 1",
		"content": """Turn 1 is complete! You've now seen the full sequence:

[color=cyan]Movement[/color] → [color=cyan]Weapons[/color] → [color=cyan]Physical Attack[/color] → [color=cyan]Heat[/color]

Both sides acted, damage was dealt, and heat was dissipated.

Every turn in Steel Titans follows this same order.""",
		"tip": "🔄 Next: tap END to advance to the next round.",
		"button_text": "CONTINUE",
		"blocks_game": true
	})

func _setup_prompt_end_turn():
	"""Acción requerida: en vez de que el tutorial avance solo, se le pide al
	jugador que pulse el botón END real para avanzar de ronda - así aprende el
	gesto que usará en partidas normales. can_end_turn() desbloquea el botón
	solo en este paso."""
	input_unblocked.emit()
	required_action = "end_turn"

	hint_requested.emit({
		"id": "prompt_end_turn",
		"title": "🔄 END THE ROUND",
		"content": """[color=cyan]Tap the END button[/color] (top-left) to advance to the next round.""",
		"tip": "⚡ Action required: Tap END",
		"button_text": "",
		"blocks_game": false,
		"highlight_ui": "end_turn_button"
	})

func on_end_turn_pressed():
	"""Llamado cuando el jugador pulsa el botón END real durante el tutorial"""
	if current_step == TutorialStep.PROMPT_END_TURN:
		_advance_to(TutorialStep.WAITING_ROUND2_INITIATIVE)

func _setup_waiting_round2_initiative():
	"""Paso silencioso (sin hint): la iniciativa automática de la ronda 2 quedó
	bloqueada en _show_heat_explanation() para que no colisionara con el resto
	del guion post-combate. Ahora que ese guion terminó, se desbloquea y se
	pide manualmente - mismo patrón que _show_initiative_roll() usa para la
	ronda 1.

	A diferencia de la ronda 1, aquí NO se fuerza el resultado: se le pide al
	TutorialManager que deje de trucar los dados (ver
	TutorialManager.initiative_roll_forced), así el jugador ve una tirada real
	con el bonificador de tonelaje aplicado de verdad."""
	force_action.emit("stop_forcing_initiative", {})
	force_action.emit("unblock_initiative", {})
	if battle_scene and battle_scene.has_method("show_initiative_screen"):
		battle_scene.show_initiative_screen()

func _end_tutorial_and_return_to_mech_select():
	"""Cierra el tutorial guiado y lleva al jugador a elegir mechs para una
	partida real, en vez de continuar el guion de melee/shutdown/explosión."""
	is_active = false
	tutorial_completed.emit()  # TutorialManager marca el save como completado aquí
	if battle_scene and battle_scene.get_tree():
		battle_scene.get_tree().change_scene_to_file("res://scenes/team_setup.tscn")

func _show_round_2_start():
	input_blocked.emit()
	hint_requested.emit({
		"id": "round_2",
		"title": "🔄 ROUND 2 BEGINS",
		"content": """A new round begins - initiative is rolled again at the start of every round, just like you just saw.

You've now seen a full round of combat: initiative, movement, facing, weapons, heat, and how the enemy reacts.

[color=green]That's the core loop of Steel Titans![/color] Every battle from here plays out the same way - just with more mechs and tougher decisions.""",
		"tip": "🎮 Time to build your own lance and jump into a real battle!",
		"button_text": "FINISH TUTORIAL",
		"blocks_game": true,
		"is_final": true
	})

func _setup_physical_approach():
	input_unblocked.emit()
	
	# Hexes adyacentes al enemigo. Antes esto era una lista fija de
	# vecinos de un hex asumido como posicion del enemigo (6,6), pero el
	# Hunchback llega a esta fase habiendose movido por su propia IA
	# durante los turnos anteriores, asi que esa posicion fija casi nunca
	# coincidia con donde estaba realmente - las casillas resaltadas no
	# rodeaban al enemigo. Se calcula ahora a partir de su hex_position real.
	allowed_hexes = []
	if battle_scene and battle_scene.enemy_mechs.size() > 0 and battle_scene.hex_grid:
		var enemy = battle_scene.enemy_mechs[0]
		allowed_hexes = battle_scene.hex_grid.get_neighbors(enemy.hex_position)
	required_action = "move"
	
	force_action.emit("highlight_hexes", {"hexes": allowed_hexes, "color": "tutorial"})
	
	hint_requested.emit({
		"id": "approach_enemy",
		"title": "🦿 GET CLOSE!",
		"content": """[color=cyan]Move to a hex ADJACENT to the enemy[/color] to enable physical attacks.

The highlighted hexes are next to the Hunchback.""",
		"tip": "⚡ Action required: Move next to the enemy",
		"button_text": "",
		"blocks_game": false
	})

func _show_physical_explanation():
	input_blocked.emit()
	hint_requested.emit({
		"id": "physical_explain",
		"title": "👊 PHYSICAL ATTACKS",
		"content": """You're adjacent to the enemy! You can now make physical attacks:

[color=cyan]🤜 PUNCH[/color]
• Uses arm actuators
• Can hit upper body (chance for HEAD hit!)
• Damage based on mech weight

[color=yellow]🦵 KICK[/color]
• Uses leg actuators
• Hits legs only
• Can knock enemy DOWN (Piloting roll)
• Higher damage than punch""",
		"tip": "💡 A kick to the legs can immobilize an enemy!",
		"button_text": "ATTACK!",
		"blocks_game": true
	})

func _setup_physical_attack():
	input_unblocked.emit()
	required_action = "physical_attack"
	
	hint_requested.emit({
		"id": "do_physical",
		"title": "👊 MAKE YOUR ATTACK",
		"content": """[color=cyan]Tap the PUNCH or KICK button[/color] to attack!

Try a KICK to potentially knock the enemy down.""",
		"tip": "⚡ Action required: Execute physical attack",
		"button_text": "",
		"blocks_game": false,
		"highlight_ui": "physical_buttons"
	})

func _setup_enemy_shutdown():
	input_blocked.emit()
	
	# Forzar que el enemigo dispare todo y se sobrecaliente
	force_action.emit("enemy_overheat", {"heat": 32})
	
	hint_requested.emit({
		"id": "enemy_shutdown",
		"title": "🌡️ ENEMY OVERHEATED!",
		"content": """The Hunchback fired too many weapons!

Its heat level reached [color=red]32[/color] - above the critical threshold!

[color=red]⚠️ EMERGENCY SHUTDOWN ⚠️[/color]

The enemy mech has automatically shut down to prevent reactor meltdown!""",
		"tip": "👀 A shutdown mech is helpless - it cannot move or defend!",
		"button_text": "",
		"blocks_game": false,
		"auto_dismiss": 3.0
	})
	
	await battle_scene.get_tree().create_timer(3.5).timeout
	_advance_to(TutorialStep.SHUTDOWN_EXPLANATION)

func _show_shutdown_explanation():
	input_blocked.emit()
	hint_requested.emit({
		"id": "shutdown_explain",
		"title": "💤 SHUTDOWN MECHANICS",
		"content": """When a mech shuts down:

[color=red]❌ Cannot move[/color]
[color=red]❌ Cannot attack[/color]
[color=red]❌ Very easy to hit (+4 to-hit bonus)[/color]
[color=cyan]✓ Heat dissipates normally[/color]

The pilot can try to restart each turn (Piloting roll).

[color=yellow]This is your chance![/color] Attack while it's defenseless!""",
		"tip": "⚡ Attack the shutdown enemy before it restarts!",
		"button_text": "FINISH IT!",
		"blocks_game": true
	})

func _setup_final_attack():
	input_unblocked.emit()
	required_action = "attack"
	
	hint_requested.emit({
		"id": "final_attack",
		"title": "💀 DESTROY THE ENEMY!",
		"content": """The enemy is shutdown and helpless!

[color=cyan]Select the Hunchback and fire your weapons![/color]

Aim for maximum damage to finish it off.

[color=yellow]Watch what happens when you destroy its ammo...[/color]""",
		"tip": "⚡ Action required: Attack the shutdown enemy",
		"button_text": "",
		"blocks_game": false
	})

func _trigger_ammo_explosion():
	input_blocked.emit()
	
	# Forzar explosión de munición
	force_action.emit("ammo_explosion", {
		"location": "right_torso",
		"ammo_type": "AC/20",
		"damage": 20
	})
	
	hint_requested.emit({
		"id": "ammo_explode",
		"title": "💥 AMMUNITION EXPLOSION!",
		"content": """[color=red]CRITICAL HIT![/color]

Your attack struck the enemy's [color=orange]AC/20 ammunition[/color]!

The ammo cooked off, causing [color=red]MASSIVE internal damage[/color]!

Ammunition explosions are devastating - they can destroy a mech instantly!""",
		"tip": "💥 CASE (Cellular Ammo Storage Equipment) can prevent this!",
		"button_text": "",
		"blocks_game": false,
		"auto_dismiss": 3.0
	})
	
	await battle_scene.get_tree().create_timer(3.5).timeout
	_advance_to(TutorialStep.AMMO_EXPLANATION)

func _show_ammo_explanation():
	input_blocked.emit()
	hint_requested.emit({
		"id": "ammo_explain",
		"title": "💣 AMMO STORAGE",
		"content": """Ammunition is dangerous! When hit:

[color=red]Critical Hit on Ammo[/color] = EXPLOSION
• Damage = remaining ammo × weapon damage
• Usually destroys the mech

[color=cyan]Protection:[/color]
• CASE equipment vents explosion outside
• Store ammo in legs (less likely to be hit)
• Use energy weapons (no ammo needed)""",
		"tip": "💡 In the Mech Bay, you can customize ammo placement!",
		"button_text": "CONTINUE",
		"blocks_game": true
	})

func _show_victory():
	input_blocked.emit()
	hint_requested.emit({
		"id": "victory",
		"title": "🏆 VICTORY! TUTORIAL COMPLETE!",
		"content": """[color=green]Congratulations, MechWarrior![/color]

You've learned the essentials:

✅ [color=cyan]Initiative[/color] - determines turn order
✅ [color=cyan]Movement[/color] - Walk, Run, or Jump
✅ [color=cyan]Facing[/color] - armor facing matters
✅ [color=cyan]Weapons[/color] - different ranges and damage
✅ [color=cyan]Heat[/color] - manage or shutdown!
✅ [color=cyan]Physical Attacks[/color] - heat-free melee
✅ [color=cyan]Damage[/color] - armor, structure, crits
✅ [color=cyan]Ammo[/color] - can explode!

You're ready for real combat!""",
		"tip": "🎮 Try the Mech Bay to customize your lance!",
		"button_text": "COMPLETE TUTORIAL",
		"blocks_game": true,
		"is_final": true
	})

func _complete_tutorial():
	is_active = false
	tutorial_completed.emit()
	Log.info("Tutorial", "Tutorial completed!")

# ============================================================
# MECHS DEL TUTORIAL
# ============================================================

static func get_tutorial_player_mech() -> Dictionary:
	"""Atlas AS7-D optimizado para el tutorial"""
	return {
		"name": "Atlas AS7-D",
		"chassis": "Atlas",
		"variant": "AS7-D",
		"tonnage": 100,
		"walk_mp": 3,
		"run_mp": 5,
		"jump_mp": 0,
		"heat_sinks": 20,
		"armor": {
			"head": {"current": 9, "max": 9},
			"center_torso": {"current": 47, "max": 47},
			"center_torso_rear": {"current": 14, "max": 14},
			"left_torso": {"current": 32, "max": 32},
			"left_torso_rear": {"current": 10, "max": 10},
			"right_torso": {"current": 32, "max": 32},
			"right_torso_rear": {"current": 10, "max": 10},
			"left_arm": {"current": 34, "max": 34},
			"right_arm": {"current": 34, "max": 34},
			"left_leg": {"current": 41, "max": 41},
			"right_leg": {"current": 41, "max": 41}
		},
		"structure": {
			"head": {"current": 3, "max": 3},
			"center_torso": {"current": 31, "max": 31},
			"left_torso": {"current": 21, "max": 21},
			"right_torso": {"current": 21, "max": 21},
			"left_arm": {"current": 17, "max": 17},
			"right_arm": {"current": 17, "max": 17},
			"left_leg": {"current": 21, "max": 21},
			"right_leg": {"current": 21, "max": 21}
		},
		"weapons": [
			{"name": "AC/20", "damage": 20, "heat": 7, "short_range": 3, "medium_range": 6, "long_range": 9, "ammo": 5, "location": "right_torso"},
			{"name": "Medium Laser", "damage": 5, "heat": 3, "short_range": 3, "medium_range": 6, "long_range": 9, "location": "left_torso"},
			{"name": "Medium Laser", "damage": 5, "heat": 3, "short_range": 3, "medium_range": 6, "long_range": 9, "location": "left_torso"},
			{"name": "LRM-20", "damage": 20, "heat": 6, "min_range": 6, "short_range": 7, "medium_range": 14, "long_range": 21, "ammo": 6, "location": "left_torso"},
			{"name": "SRM-6", "damage": 12, "heat": 4, "short_range": 3, "medium_range": 6, "long_range": 9, "ammo": 15, "location": "center_torso"}
		]
	}

static func get_tutorial_enemy_mech() -> Dictionary:
	"""Hunchback HBK-4G - enemigo del tutorial"""
	return {
		"name": "Hunchback HBK-4G",
		"chassis": "Hunchback",
		"variant": "HBK-4G",
		"tonnage": 50,
		"walk_mp": 4,
		"run_mp": 6,
		"jump_mp": 0,
		"heat_sinks": 10,  # Pocos heat sinks para que se sobrecaliente fácil
		"armor": {
			"head": {"current": 8, "max": 8},
			"center_torso": {"current": 16, "max": 20},  # Pre-dañado para acabar más rápido
			"center_torso_rear": {"current": 6, "max": 8},
			"left_torso": {"current": 10, "max": 14},
			"left_torso_rear": {"current": 4, "max": 6},
			"right_torso": {"current": 10, "max": 14},  # Pre-dañado
			"right_torso_rear": {"current": 4, "max": 6},
			"left_arm": {"current": 6, "max": 8},
			"right_arm": {"current": 6, "max": 8},
			"left_leg": {"current": 10, "max": 12},
			"right_leg": {"current": 10, "max": 12}
		},
		"structure": {
			"head": {"current": 3, "max": 3},
			"center_torso": {"current": 16, "max": 16},
			"left_torso": {"current": 12, "max": 12},
			"right_torso": {"current": 12, "max": 12},
			"left_arm": {"current": 8, "max": 8},
			"right_arm": {"current": 8, "max": 8},
			"left_leg": {"current": 12, "max": 12},
			"right_leg": {"current": 12, "max": 12}
		},
		"weapons": [
			{"name": "AC/20", "damage": 20, "heat": 7, "short_range": 3, "medium_range": 6, "long_range": 9, "ammo": 5, "location": "right_torso"},
			{"name": "Medium Laser", "damage": 5, "heat": 3, "short_range": 3, "medium_range": 6, "long_range": 9, "location": "head"},
			{"name": "Small Laser", "damage": 3, "heat": 1, "short_range": 1, "medium_range": 2, "long_range": 3, "location": "left_arm"}
		]
	}
