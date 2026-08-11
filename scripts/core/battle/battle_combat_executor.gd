## BattleCombatExecutor - Gestiona la ejecución de ataques y combate
## Responsabilidad única: Resolución de ataques con armas y físicos
## Extraído de battle_scene.gd como parte del refactoring SOLID
class_name BattleCombatExecutor
extends RefCounted

# Preload del animation manager
const CombatAnimationManagerClass = preload("res://scripts/managers/combat_animation_manager.gd")

# ==============================================================================
# SIGNALS
# ==============================================================================
signal weapon_attack_started(attacker: Mech, target: Mech)
signal weapon_fired(attacker: Mech, weapon: Dictionary, hit: bool, damage: int, location: String)
signal weapon_attack_completed(attacker: Mech, total_heat: int)
signal physical_attack_completed(attacker: Mech, target: Mech, attack_type: String, hit: bool)
signal target_destroyed(target: Mech, destroyed_by: Mech)
signal combat_message(text: String, color: Color)
signal unit_info_update_requested(unit: Mech)
signal battle_end_check_requested()
signal activation_complete_requested()

# ==============================================================================
# STATE
# ==============================================================================
var current_attack_target: Mech = null
var target_hexes: Array = []
var physical_target_hexes: Array = []

# ==============================================================================
# REFERENCES
# ==============================================================================
var hex_grid: HexGrid = null
var is_multiplayer_mode: bool = false
var player_mechs: Array = []
var enemy_mechs: Array = []
var animation_manager = null  # CombatAnimationManagerClass instance
var _scene_tree: SceneTree = null
var _parent_node: Node2D = null


func setup(p_hex_grid: HexGrid, p_is_multiplayer: bool = false) -> void:
	"""Configura el combat executor"""
	hex_grid = p_hex_grid
	is_multiplayer_mode = p_is_multiplayer
	
	# Crear animation manager
	animation_manager = CombatAnimationManagerClass.new()


func set_scene_tree(tree: SceneTree) -> void:
	"""Configura el SceneTree para animaciones"""
	_scene_tree = tree
	if animation_manager:
		animation_manager.set_scene_tree(tree)


func set_parent_node(parent: Node2D) -> void:
	"""Configura el nodo padre para crear sprites de animación"""
	_parent_node = parent
	if animation_manager:
		animation_manager.set_parent_node(parent)


func set_mechs(p_player_mechs: Array, p_enemy_mechs: Array) -> void:
	"""Actualiza las referencias a mechs"""
	player_mechs = p_player_mechs
	enemy_mechs = p_enemy_mechs
	Log.debug("Combat", "CombatExecutor.set_mechs called: player=%d, enemy=%d" % [player_mechs.size(), enemy_mechs.size()])


func handle_weapon_attack_click(hex: Vector2i, selected_unit: Mech) -> bool:
	"""Maneja click en hex durante fase de ataque con armas. Retorna true si fue procesado."""
	if selected_unit == null or not _can_control_unit(selected_unit):
		return false
	
	var target = hex_grid.get_unit(hex)
	
	# Verificar que hay un enemigo en el hex
	if not _is_enemy_target(target):
		return false
	
	var range_hexes = hex_grid.hex_distance(selected_unit.hex_position, target.hex_position)
	current_attack_target = target
	
	# Emitir señal para mostrar selector de armas
	weapon_attack_started.emit(selected_unit, target)
	combat_message.emit("Select weapons to fire at %s (Range: %d)" % [target.mech_name, range_hexes], Color.YELLOW)
	
	return true


func _is_enemy_target(target) -> bool:
	"""Verifica si el target es un enemigo"""
	if target == null:
		return false
	
	if is_multiplayer_mode:
		return not target.is_player_controlled
	else:
		return target in enemy_mechs


func execute_weapon_attack(attacker: Mech, target: Mech, weapon_indices: Array, range_hexes: int) -> void:
	"""Ejecuta un ataque con armas (singleplayer)"""
	combat_message.emit("", Color.WHITE)
	combat_message.emit("═══════════════════════════════", Color.YELLOW)
	combat_message.emit("%s FIRES AT %s (Range: %d)" % [attacker.mech_name.to_upper(), target.mech_name.to_upper(), range_hexes], Color.YELLOW)
	combat_message.emit("═══════════════════════════════", Color.YELLOW)
	
	var total_heat = 0
	var weapons_fired = []
	
	# Disparar cada arma seleccionada
	for weapon_index in weapon_indices:
		if weapon_index >= attacker.weapons.size():
			continue
		
		var weapon = attacker.weapons[weapon_index]
		weapons_fired.append(weapon)
		
		# Calcular to-hit usando el sistema
		var to_hit_data = WeaponAttackSystem.calculate_to_hit(attacker, target, weapon, range_hexes)
		var target_number = to_hit_data["target_number"]
		var breakdown = to_hit_data.get("breakdown", "")
		
		# Tirar 2D6
		var roll = WeaponAttackSystem.roll_to_hit()
		
		# Mostrar información del disparo
		combat_message.emit("→ %s" % weapon.get("name", "Unknown"), Color.CYAN)
		if breakdown != "":
			for line in breakdown.split("\n"):
				if line.strip_edges() != "":
					combat_message.emit("  %s" % line, Color.WHITE)
		combat_message.emit("  Roll: %d" % roll, Color.CYAN)
		
		# Verificar impacto
		var hit = WeaponAttackSystem.check_hit(roll, target_number)
		var is_critical = false
		
		if hit:
			is_critical = _process_weapon_hit(attacker, target, weapon, roll)
		else:
			_process_weapon_miss(roll)
		
		# Reproducir animación de disparo
		Log.info("Combat", "Attempting animation: manager=%s, tree=%s" % [animation_manager != null, _scene_tree != null])
		if animation_manager and _scene_tree:
			await _play_weapon_animation(attacker, target, weapon, hit, is_critical)
		else:
			Log.warning("Combat", "Skipping animation - manager or tree is null")
		
		# Acumular calor
		total_heat += weapon.get("heat", 0)
	
	# Aplicar calor generado
	if total_heat > 0:
		attacker.heat += total_heat
		combat_message.emit("Heat generated: +%d (Current: %d/%d)" % [total_heat, attacker.heat, attacker.heat_capacity], Color.ORANGE)
		combat_message.emit("  (Heat will be processed in Heat Phase)", Color.GRAY)
		unit_info_update_requested.emit(attacker)
	
	combat_message.emit("═══════════════════════════════", Color.YELLOW)
	
	weapon_attack_completed.emit(attacker, total_heat)


func _play_weapon_animation(attacker: Mech, target: Mech, weapon: Dictionary, hit: bool, is_critical: bool) -> void:
	"""Reproduce la animación de disparo del arma"""
	if not animation_manager:
		return
	
	var weapon_name = weapon.get("name", "").to_lower()
	
	# Para misiles, usar animación especial de salva
	if "lrm" in weapon_name or "srm" in weapon_name:
		var missile_count = 1
		if "lrm" in weapon_name:
			# Extraer número de misiles (LRM-5, LRM-10, LRM-15, LRM-20)
			var regex = RegEx.new()
			regex.compile("lrm[- ]?(\\d+)")
			var result = regex.search(weapon_name)
			if result:
				missile_count = int(result.get_string(1))
		elif "srm" in weapon_name:
			# SRM-2, SRM-4, SRM-6
			var regex = RegEx.new()
			regex.compile("srm[- ]?(\\d+)")
			var result = regex.search(weapon_name)
			if result:
				missile_count = int(result.get_string(1))
		
		# Calcular cuántos misiles impactan (simplificado)
		var hits = missile_count if hit else 0
		if hit and missile_count > 1:
			# En BattleTech real se tira en tabla de cluster, simplificamos
			hits = max(1, int(missile_count * randf_range(0.4, 0.9)))
		
		await animation_manager.play_multi_missile_animation(attacker, target, missile_count, hits)
	else:
		# Animación normal para otras armas
		await animation_manager.play_attack_animation(attacker, target, weapon, hit, is_critical)


func _process_weapon_hit(attacker: Mech, target: Mech, weapon: Dictionary, _roll: int) -> bool:
	"""Procesa un impacto de arma. Retorna true si hubo crítico."""
	var hit_location = WeaponAttackSystem.roll_hit_location()
	var damage = weapon.get("damage", 0)
	var is_critical = false
	
	combat_message.emit("  ✓ HIT! Location: %s, Damage: %d" % [hit_location, damage], Color.GREEN)
	
	# Aplicar daño
	var damage_result = WeaponAttackSystem.apply_damage(target, hit_location, damage)
	
	if damage_result.get("critical_hit", false):
		combat_message.emit("    ⚠ CRITICAL HIT! Structure damaged!", Color.RED)
		is_critical = true
	
	if damage_result.get("location_destroyed", false):
		combat_message.emit("    ⚠ %s DESTROYED!" % hit_location.to_upper(), Color.RED)
		is_critical = true
	
	if damage_result.get("mech_destroyed", false):
		target.destroyed_by = attacker.mech_name
		if target.death_reason == "":
			target.death_reason = "Destroyed by weapons fire"
		combat_message.emit("    ☠ %s DESTROYED! ☠" % target.mech_name.to_upper(), Color.RED)
		target_destroyed.emit(target, attacker)
		battle_end_check_requested.emit()
	
	weapon_fired.emit(attacker, weapon, true, damage, hit_location)
	return is_critical


func _process_weapon_miss(roll: int) -> void:
	"""Procesa un fallo de arma"""
	var miss_msg = "  ✗ MISS"
	if roll == 2:
		miss_msg = "  ✗ CRITICAL MISS!"
	combat_message.emit(miss_msg, Color.GRAY)


func execute_physical_attack(attacker: Mech, target: Mech, attack_type: String) -> void:
	"""Ejecuta un ataque físico (singleplayer)"""
	var distance = hex_grid.hex_distance(attacker.hex_position, target.hex_position)
	
	if distance > 1:
		combat_message.emit("Target too far for physical attack!", Color.RED)
		return
	
	combat_message.emit("", Color.WHITE)
	combat_message.emit("═══════════════════════════════", Color.MAGENTA)
	combat_message.emit("%s PHYSICAL ATTACK vs %s" % [attacker.mech_name.to_upper(), target.mech_name.to_upper()], Color.MAGENTA)
	combat_message.emit("═══════════════════════════════", Color.MAGENTA)
	
	var attack_type_enum = _get_attack_type_enum(attack_type)
	var attack_name = _get_attack_name(attack_type)
	
	# Calcular to-hit
	var to_hit_data = PhysicalAttackSystem.calculate_to_hit(attacker, target, attack_type_enum)
	var target_number = to_hit_data["target_number"]
	var modifiers = to_hit_data["modifiers"]
	
	# Calcular daño potencial
	var damage = _calculate_physical_damage(attacker, attack_type_enum)
	
	# Tirar 2D6
	var roll = PhysicalAttackSystem.roll_to_hit()
	
	# Mostrar información del ataque
	var mod_text = ""
	for mod_name in modifiers.keys():
		mod_text += " +%d(%s)" % [modifiers[mod_name], mod_name]
	
	combat_message.emit("→ %s: Roll %d vs TN %d%s (Dmg: %d)" % [attack_name, roll, target_number, mod_text, damage], Color.CYAN)
	
	# Verificar impacto
	var hit = PhysicalAttackSystem.check_hit(roll, target_number)
	
	if hit:
		_process_physical_hit(attacker, target, attack_type_enum, damage)
	else:
		_process_physical_miss(attacker, attack_type_enum, roll)
	
	# Marcar que realizó ataque físico
	attacker.has_performed_physical_attack = true
	
	combat_message.emit("═══════════════════════════════", Color.MAGENTA)
	
	physical_attack_completed.emit(attacker, target, attack_type, hit)


func _get_attack_type_enum(attack_type: String) -> int:
	"""Convierte string de tipo de ataque a enum"""
	match attack_type:
		"punch_left", "punch_right":
			return PhysicalAttackSystem.AttackType.PUNCH
		"kick":
			return PhysicalAttackSystem.AttackType.KICK
		"charge":
			return PhysicalAttackSystem.AttackType.CHARGE
	return PhysicalAttackSystem.AttackType.PUNCH


func _get_attack_name(attack_type: String) -> String:
	"""Obtiene nombre legible del tipo de ataque"""
	match attack_type:
		"punch_left":
			return "Punch (Left Arm)"
		"punch_right":
			return "Punch (Right Arm)"
		"kick":
			return "Kick"
		"charge":
			return "Charge"
	return "Unknown Attack"


func _calculate_physical_damage(attacker: Mech, attack_type_enum: int) -> int:
	"""Calcula daño del ataque físico"""
	match attack_type_enum:
		PhysicalAttackSystem.AttackType.PUNCH:
			return PhysicalAttackSystem.calculate_punch_damage(attacker.tonnage)
		PhysicalAttackSystem.AttackType.KICK:
			return PhysicalAttackSystem.calculate_kick_damage(attacker.tonnage)
		PhysicalAttackSystem.AttackType.CHARGE:
			var hexes = attacker.hexes_moved_this_turn if "hexes_moved_this_turn" in attacker else 0
			return PhysicalAttackSystem.calculate_charge_damage(attacker.tonnage, hexes)
	return 0


func _process_physical_hit(attacker: Mech, target: Mech, attack_type_enum: int, damage: int) -> void:
	"""Procesa un impacto físico"""
	var hit_location = _roll_physical_hit_location(attack_type_enum)
	
	combat_message.emit("  ✓ HIT! Location: %s" % hit_location, Color.GREEN)
	
	# Aplicar daño
	var damage_result = target.take_damage(hit_location, damage)
	
	if damage_result.get("critical_hit", false):
		combat_message.emit("    ⚠ CRITICAL HIT! Structure damaged!", Color.RED)
	
	if damage_result.get("location_destroyed", false):
		combat_message.emit("    ⚠ %s DESTROYED!" % hit_location.to_upper(), Color.RED)
	
	if damage_result.get("mech_destroyed", false):
		target.destroyed_by = attacker.mech_name
		if target.death_reason == "":
			var attack_name = PhysicalAttackSystem.AttackType.keys()[attack_type_enum].capitalize()
			target.death_reason = "Destroyed by " + attack_name.to_lower()
		combat_message.emit("    ☠ %s DESTROYED! ☠" % target.mech_name.to_upper(), Color.RED)
		target_destroyed.emit(target, attacker)
		battle_end_check_requested.emit()
	
	# Efectos especiales del charge
	if attack_type_enum == PhysicalAttackSystem.AttackType.CHARGE:
		var self_damage = PhysicalAttackSystem.apply_charge_self_damage(attacker, damage)
		if self_damage > 0:
			attacker.take_damage("center_torso", self_damage)
			combat_message.emit("  → %s takes %d self-damage from charge" % [attacker.mech_name, self_damage], Color.ORANGE)


func _roll_physical_hit_location(attack_type_enum: int) -> String:
	"""Tira la localización del impacto físico"""
	if attack_type_enum == PhysicalAttackSystem.AttackType.PUNCH:
		return PhysicalAttackSystem.roll_punch_location()
	elif attack_type_enum == PhysicalAttackSystem.AttackType.KICK:
		return PhysicalAttackSystem.roll_kick_location()
	else:
		return "center_torso"


func _process_physical_miss(attacker: Mech, attack_type_enum: int, roll: int) -> void:
	"""Procesa un fallo de ataque físico"""
	var miss_msg = "  ✗ MISS"
	if roll == 2:
		miss_msg = "  ✗ CRITICAL MISS!"
	combat_message.emit(miss_msg, Color.GRAY)
	
	# Riesgo de caída al fallar patada
	if attack_type_enum == PhysicalAttackSystem.AttackType.KICK:
		if PhysicalAttackSystem.check_fall_after_kick(attacker):
			attacker.is_prone = true
			combat_message.emit("  → %s FALLS DOWN from failed kick!" % attacker.mech_name, Color.YELLOW)


func end_weapon_attack_phase() -> void:
	"""Finaliza la fase de ataque con armas"""
	current_attack_target = null
	target_hexes.clear()
	activation_complete_requested.emit()


func end_physical_attack_phase() -> void:
	"""Finaliza la fase de ataque físico"""
	current_attack_target = null
	target_hexes.clear()
	activation_complete_requested.emit()


func has_enemies_in_los(unit: Mech) -> bool:
	"""Verifica si la unidad tiene algún enemigo en línea de vista"""
	if not hex_grid:
		Log.warn("Combat", "has_enemies_in_los: hex_grid is null!")
		return false
	
	var can_control = _can_control_unit(unit)
	var enemies = enemy_mechs if can_control else player_mechs
	
	Log.debug("Combat", "has_enemies_in_los check for %s: can_control=%s, player_mechs=%d, enemy_mechs=%d, checking enemies=%d" % [
		unit.mech_name, can_control, player_mechs.size(), enemy_mechs.size(), enemies.size()
	])
	
	for enemy in enemies:
		if enemy.is_destroyed:
			Log.debug("Combat", "  - Enemy %s is destroyed, skipping" % enemy.mech_name)
			continue
		
		var has_los = LineOfSight.can_shoot(hex_grid, unit.hex_position, enemy.hex_position)
		Log.debug("Combat", "  - Enemy %s at %s: LoS from %s = %s" % [enemy.mech_name, enemy.hex_position, unit.hex_position, has_los])
		if has_los:
			return true
	
	Log.debug("Combat", "has_enemies_in_los: No valid targets found for %s" % unit.mech_name)
	return false


func has_adjacent_enemies(unit: Mech) -> bool:
	"""Verifica si hay enemigos adyacentes para ataques físicos"""
	if not hex_grid:
		Log.warn("Combat", "has_adjacent_enemies: hex_grid is null!")
		return false
	
	var neighbors = hex_grid.get_neighbors(unit.hex_position)
	Log.debug("Combat", "has_adjacent_enemies check for %s at %s: %d neighbors" % [unit.mech_name, unit.hex_position, neighbors.size()])
	
	for neighbor in neighbors:
		var other_unit = hex_grid.get_unit(neighbor)
		if other_unit:
			var is_enemy = _is_enemy_target(other_unit)
			Log.debug("Combat", "  - Unit at %s: %s, is_enemy=%s" % [neighbor, other_unit.mech_name, is_enemy])
			if is_enemy:
				return true
		else:
			Log.debug("Combat", "  - No unit at %s" % [neighbor])
	
	Log.debug("Combat", "has_adjacent_enemies: No adjacent enemies found for %s" % unit.mech_name)
	return false


func get_adjacent_enemies(unit: Mech) -> Array:
	"""Retorna lista de enemigos adyacentes"""
	var enemies = []
	if not hex_grid:
		return enemies
	
	var neighbors = hex_grid.get_neighbors(unit.hex_position)
	for neighbor in neighbors:
		var other_unit = hex_grid.get_unit(neighbor)
		if other_unit and _is_enemy_target(other_unit):
			enemies.append(other_unit)
	return enemies


func get_target_hexes() -> Array:
	"""Retorna los hexes de objetivos actuales"""
	return target_hexes


func get_physical_target_hexes() -> Array:
	"""Retorna los hexes de objetivos físicos"""
	return physical_target_hexes


func clear_target_hexes() -> void:
	"""Limpia los hexes de objetivos"""
	target_hexes.clear()
	physical_target_hexes.clear()


func calculate_weapon_targets(unit: Mech) -> Array:
	"""Calcula y establece los hexes de objetivos con LoS"""
	target_hexes.clear()
	var enemies = enemy_mechs if _can_control_unit(unit) else player_mechs
	
	for enemy in enemies:
		if not enemy.is_destroyed and enemy.is_visible_to_player:
			var enemy_has_los = LineOfSight.can_shoot(hex_grid, unit.hex_position, enemy.hex_position)
			if enemy_has_los:
				target_hexes.append(enemy.hex_position)
	
	return target_hexes


func calculate_physical_targets(unit: Mech) -> Array:
	"""Calcula y establece los hexes de objetivos físicos (adyacentes)"""
	physical_target_hexes.clear()
	var enemies = enemy_mechs if _can_control_unit(unit) else player_mechs
	
	for enemy in enemies:
		if not enemy.is_destroyed:
			var dist = hex_grid.hex_distance(unit.hex_position, enemy.hex_position)
			if dist <= 1:
				physical_target_hexes.append(enemy.hex_position)
	
	return physical_target_hexes


func _can_control_unit(unit: Mech) -> bool:
	"""Verifica si el jugador puede controlar esta unidad"""
	if is_multiplayer_mode:
		return unit.is_player_controlled
	else:
		return unit in player_mechs


func roll_hit_location() -> String:
	"""Tira la localización de impacto (2D6)"""
	var roll = randi() % 6 + randi() % 6 + 2
	
	match roll:
		2:
			return "center_torso"
		3:
			return "right_arm"
		4:
			return "right_arm"
		5:
			return "right_leg"
		6:
			return "right_torso"
		7:
			return "center_torso"
		8:
			return "left_torso"
		9:
			return "left_leg"
		10:
			return "left_arm"
		11:
			return "left_arm"
		12:
			return "head"
	
	return "center_torso"
