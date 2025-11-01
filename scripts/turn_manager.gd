extends Node
class_name TurnManager

signal turn_changed(team: String, turn_number: int)
signal phase_changed(phase: String)
signal unit_activated(unit)
signal initiative_rolled(data: Dictionary)

enum Phase {
	INITIATIVE,
	MOVEMENT,
	WEAPON_ATTACK,
	PHYSICAL_ATTACK,
	HEAT,
	END
}

var current_turn: int = 1
var current_phase: Phase = Phase.INITIATIVE
var current_team: String = "player"  # "player" o "enemy"

var player_units: Array = []
var enemy_units: Array = []

var units_to_activate: Array = []
var current_unit_index: int = 0

var initiative_order: Array = []

func _ready():
	pass

func start_battle(player_mechs: Array, enemy_mechs: Array):
	player_units = player_mechs
	enemy_units = enemy_mechs
	current_turn = 1
	
	# Verificar si ya tenemos datos de iniciativa guardados
	if owner and owner.has_method("get_stored_initiative"):
		var stored_data = owner.get_stored_initiative()
		if stored_data and stored_data.size() > 0:
			# Usar iniciativa pre-calculada
			use_precalculated_initiative(stored_data)
			return
	
	start_turn()

func start_turn():
	current_phase = Phase.INITIATIVE
	emit_signal("turn_changed", current_team, current_turn)
	emit_signal("phase_changed", Phase.keys()[current_phase])
	# Esperar un poco antes de tirar iniciativa para que se vea
	await get_tree().create_timer(0.5).timeout
	roll_initiative()

func roll_initiative():
	# En Battletech, la iniciativa se tira con 2d6
	var die1_player = (randi() % 6) + 1
	var die2_player = (randi() % 6) + 1
	var player_initiative = die1_player + die2_player
	
	var die1_enemy = (randi() % 6) + 1
	var die2_enemy = (randi() % 6) + 1
	var enemy_initiative = die1_enemy + die2_enemy
	
	# Emitir evento con los resultados para mostrar en UI
	var initiative_data = {
		"player_dice": [die1_player, die2_player],
		"player_total": player_initiative,
		"enemy_dice": [die1_enemy, die2_enemy],
		"enemy_total": enemy_initiative
	}
	
	# Crear señal personalizada para iniciativa
	if has_signal("initiative_rolled"):
		emit_signal("initiative_rolled", initiative_data)
	
	# Quien gana la iniciativa mueve primero
	if player_initiative >= enemy_initiative:
		current_team = "player"
		initiative_data["winner"] = "player"
	else:
		current_team = "enemy"
		initiative_data["winner"] = "enemy"
	
	# Notificar al sistema sobre el ganador
	if owner and owner.has_method("_on_initiative_result"):
		owner._on_initiative_result(initiative_data)
	
	# Esperar para que se lean los mensajes
	await get_tree().create_timer(1.5).timeout
	advance_phase()

func use_precalculated_initiative(data: Dictionary):
	# Usar los datos de iniciativa ya calculados en la pantalla de dados
	current_phase = Phase.INITIATIVE
	current_team = data["winner"]
	
	# Emitir señales
	emit_signal("turn_changed", current_team, current_turn)
	emit_signal("phase_changed", Phase.keys()[current_phase])
	
	# Notificar sobre el resultado
	if has_signal("initiative_rolled"):
		emit_signal("initiative_rolled", data)
	
	if owner and owner.has_method("_on_initiative_result"):
		owner._on_initiative_result(data)
	
	# Ir directamente a la fase de movimiento
	await get_tree().create_timer(0.5).timeout
	advance_phase()

func advance_phase():
	match current_phase:
		Phase.INITIATIVE:
			current_phase = Phase.MOVEMENT
			start_movement_phase()
		Phase.MOVEMENT:
			current_phase = Phase.WEAPON_ATTACK
			start_weapon_phase()
		Phase.WEAPON_ATTACK:
			current_phase = Phase.PHYSICAL_ATTACK
			start_physical_phase()
		Phase.PHYSICAL_ATTACK:
			current_phase = Phase.HEAT
			start_heat_phase()
		Phase.HEAT:
			current_phase = Phase.END
			end_turn()
		Phase.END:
			current_turn += 1
			start_turn()
	
	emit_signal("phase_changed", Phase.keys()[current_phase])

func start_movement_phase():
	_build_activation_order()
	current_unit_index = 0
	# Pequeño delay para que la UI se actualice
	await get_tree().create_timer(0.1).timeout
	activate_next_unit()

func _build_activation_order():
	# En Battletech, las unidades se activan alternadamente
	units_to_activate.clear()
	
	var player_active = player_units.filter(func(u): return not u.is_destroyed)
	var enemy_active = enemy_units.filter(func(u): return not u.is_destroyed)
	
	var max_units = max(player_active.size(), enemy_active.size())
	
	# Alternar activación entre equipos
	for i in range(max_units):
		if current_team == "player":
			if i < player_active.size():
				units_to_activate.append(player_active[i])
			if i < enemy_active.size():
				units_to_activate.append(enemy_active[i])
		else:
			if i < enemy_active.size():
				units_to_activate.append(enemy_active[i])
			if i < player_active.size():
				units_to_activate.append(player_active[i])

func activate_next_unit():
	if current_unit_index >= units_to_activate.size():
		advance_phase()
		return
	
	var unit = units_to_activate[current_unit_index]
	
	# Resetear movimiento de la unidad
	if unit.has_method("reset_movement"):
		unit.reset_movement()
	
	emit_signal("unit_activated", unit)

func complete_unit_activation():
	current_unit_index += 1
	activate_next_unit()

func start_weapon_phase():
	# Similar a movimiento, pero para disparar
	_build_activation_order()
	current_unit_index = 0
	await get_tree().create_timer(0.1).timeout
	activate_next_unit()

func start_physical_phase():
	# Fase de ataques físicos (puñetazos, patadas, cargas)
	_build_activation_order()
	current_unit_index = 0
	await get_tree().create_timer(0.1).timeout
	activate_next_unit()

func start_heat_phase():
	# Disipar calor de todas las unidades
	for unit in player_units:
		if unit.has_method("dissipate_heat"):
			unit.dissipate_heat()
	
	for unit in enemy_units:
		if unit.has_method("dissipate_heat"):
			unit.dissipate_heat()
	
	advance_phase()

func end_turn():
	# Chequear condiciones de victoria
	var player_alive = player_units.any(func(u): return not u.is_destroyed)
	var enemy_alive = enemy_units.any(func(u): return not u.is_destroyed)
	
	if not player_alive:
		end_battle("defeat")
	elif not enemy_alive:
		end_battle("victory")
	else:
		advance_phase()  # Siguiente turno

func end_battle(result: String):
	print("Battle ended: " + result)
	# Aquí se podría mostrar pantalla de resultados

func get_current_phase_name() -> String:
	return Phase.keys()[current_phase]

func is_player_turn() -> bool:
	if units_to_activate.size() == 0:
		return current_team == "player"
	
	if current_unit_index >= units_to_activate.size():
		return false
	
	var current_unit = units_to_activate[current_unit_index]
	return current_unit in player_units
