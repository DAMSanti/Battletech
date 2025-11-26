# Ejemplo de Integración del Sistema de Combate
# Este archivo muestra cómo integrar el sistema completo de resolución de ataques
# en battle_scene.gd

extends Node2D

# Referencias
var hex_grid: HexGrid
var player_mech: Mech
var enemy_mech: Mech
var selected_weapon_indices: Array = []

# UI Referencias
var combat_log: RichTextLabel
var to_hit_display: Label
var weapon_selection_panel: Control

## ========== FASE DE ATAQUE CON ARMAS ==========

func start_weapon_attack_phase():
	"""Inicia la fase de ataque con armas"""
	print("=== WEAPON ATTACK PHASE ===")
	
	# Mostrar armas disponibles
	show_available_weapons()
	
	# Esperar selección del jugador
	await player_selects_target_and_weapons()
	
	# Resolver todos los ataques
	resolve_all_weapon_attacks()

func show_available_weapons():
	"""Muestra las armas disponibles del mech activo"""
	var functional_weapons = player_mech.get_functional_weapons()
	
	print("\nAvailable weapons:")
	for i in range(functional_weapons.size()):
		var weapon = functional_weapons[i]
		var ammo_str = ""
		if weapon.get("requires_ammo", false):
			ammo_str = " [%d rounds]" % weapon.get("ammo", 0)
		
		print("  %d. %s - Damage: %d, Heat: %d%s" % [
			i + 1,
			weapon.get("name", "Unknown"),
			weapon.get("damage", 0),
			weapon.get("heat", 0),
			ammo_str
		])

func player_selects_target_and_weapons():
	"""
	Permitir al jugador seleccionar objetivo y armas
	Esta es una versión simplificada - en tu implementación real
	esto será manejado por el UI
	"""
	# Por ahora, simulamos selección automática para el ejemplo
	selected_weapon_indices = [0, 1, 2]  # Primeras 3 armas
	
	# En una implementación real:
	# - Mostrar panel de selección de armas
	# - Permitir click en hexágonos para seleccionar objetivo
	# - Mostrar probabilidad de impacto para cada arma
	# - Permitir confirmar selección

func resolve_all_weapon_attacks():
	"""Resuelve todos los ataques de armas seleccionadas"""
	print("\n=== RESOLVING ATTACKS ===")
	
	var total_damage = 0
	var total_heat = 0
	var hits = 0
	var misses = 0
	
	for weapon_idx in selected_weapon_indices:
		var weapon = player_mech.get_weapon_by_index(weapon_idx)
		if weapon.is_empty():
			continue
		
		# Añadir separador visual en el log
		add_to_combat_log("\n" + "─".repeat(50))
		add_to_combat_log("Firing: %s" % weapon.get("name", "Unknown"))
		
		# Resolver el ataque
		var result = WeaponAttackSystem.resolve_weapon_attack(
			player_mech,
			enemy_mech,
			weapon,
			hex_grid
		)
		
		# Procesar resultado
		process_attack_result(result, weapon)
		
		# Acumular estadísticas
		total_heat += result.heat_generated
		total_damage += result.damage_applied
		
		if result.hit:
			hits += 1
		elif result.success:
			misses += 1
		
		# Pequeña pausa entre disparos (para efectos visuales)
		await get_tree().create_timer(0.5).timeout
	
	# Resumen final
	print("\n=== ATTACK PHASE SUMMARY ===")
	print("Hits: %d, Misses: %d" % [hits, misses])
	print("Total Damage: %d" % total_damage)
	print("Total Heat: %d" % total_heat)
	
	add_to_combat_log("\n" + "═".repeat(50))
	add_to_combat_log("PHASE SUMMARY: %d hits, %d misses, %d damage, +%d heat" % [
		hits, misses, total_damage, total_heat
	])

func process_attack_result(result: Dictionary, weapon: Dictionary):
	"""Procesa el resultado de un ataque individual"""
	
	# Verificar si puede disparar
	if not result.can_shoot:
		add_to_combat_log("❌ CANNOT FIRE: %s" % result.message, Color.RED)
		print("Cannot fire: %s" % result.message)
		return
	
	# Mostrar breakdown de modificadores
	add_to_combat_log("\n%s" % result.breakdown, Color.GRAY)
	
	# Verificar impacto
	if not result.hit:
		add_to_combat_log("❌ MISS! Rolled %d, needed %d+" % [
			result.roll,
			result.target_number
		], Color.YELLOW)
		
		# Efecto visual de miss
		show_miss_effect(enemy_mech.position)
		return
	
	# ¡IMPACTO!
	add_to_combat_log("✅ HIT! Rolled %d vs %d" % [
		result.roll,
		result.target_number
	], Color.GREEN)
	
	# Mostrar daño por localización
	for location_data in result.locations_hit:
		var loc_name = location_data.location
		var damage = location_data.damage
		var armor_dmg = location_data.armor_damage
		var struct_dmg = location_data.structure_damage
		
		var msg = "  → %s: %d damage" % [loc_name.to_upper(), damage]
		
		if struct_dmg > 0:
			msg += " (%d armor, %d STRUCTURE)" % [armor_dmg, struct_dmg]
			add_to_combat_log(msg, Color.ORANGE_RED)
		else:
			msg += " (armor)"
			add_to_combat_log(msg, Color.WHITE)
		
		# Efecto visual de impacto
		show_hit_effect(enemy_mech.position, loc_name)
	
	# Mostrar críticos
	if result.critical_hits.size() > 0:
		add_to_combat_log("\n⚠️ CRITICAL HITS:", Color.RED)
		
		for crit in result.critical_hits:
			var crit_msg = "  💥 %s: %s - %s" % [
				crit.location.to_upper(),
				crit.description,
				crit.effect
			]
			add_to_combat_log(crit_msg, Color.RED)
			
			# Efecto especial para explosiones de munición
			if crit.effect.contains("EXPLOSION"):
				show_explosion_effect(enemy_mech.position)
	
	# Verificar si el objetivo fue destruido
	if enemy_mech.is_destroyed:
		add_to_combat_log("\n💀 TARGET DESTROYED!", Color.DARK_RED)
		show_destruction_effect(enemy_mech.position)

## ========== PREVIEW DE TO-HIT ==========

func show_to_hit_preview(target_mech: Mech, weapon_idx: int):
	"""
	Muestra un preview del número objetivo antes de disparar
	Útil para que el jugador tome decisiones informadas
	"""
	var weapon = player_mech.get_weapon_by_index(weapon_idx)
	if weapon.is_empty():
		return
	
	# Calcular to-hit
	var range = hex_grid.hex_distance(
		player_mech.hex_position,
		target_mech.hex_position
	)
	
	var to_hit_data = WeaponAttackSystem.calculate_to_hit(
		player_mech,
		target_mech,
		weapon,
		range,
		0,
		hex_grid
	)
	
	# Calcular probabilidad de impacto
	var probability = calculate_hit_probability(to_hit_data.target_number)
	
	# Actualizar UI
	if to_hit_display:
		var display_text = ""
		display_text += "Weapon: %s\n" % weapon.get("name", "Unknown")
		display_text += "Target Number: %d\n" % to_hit_data.target_number
		display_text += "Hit Chance: %.1f%%\n" % probability
		display_text += "Damage: %d\n" % weapon.get("damage", 0)
		display_text += "Heat: +%d\n" % weapon.get("heat", 0)
		
		to_hit_display.text = display_text
	
	# También mostrar breakdown detallado
	print("\n=== TO-HIT PREVIEW ===")
	print(to_hit_data.breakdown)

func calculate_hit_probability(target_number: int) -> float:
	"""Calcula la probabilidad de impactar con 2D6"""
	# Casos especiales
	if target_number <= 2:
		return 100.0  # Siempre impacta (excepto 2, pero 12 siempre impacta)
	if target_number >= 13:
		return 2.78   # Solo con 12 (impacto automático)
	
	# Tabla de probabilidades 2D6
	var probabilities = {
		2: 2.78,    # 1/36
		3: 8.33,    # 3/36
		4: 16.67,   # 6/36
		5: 27.78,   # 10/36
		6: 41.67,   # 15/36
		7: 58.33,   # 21/36
		8: 72.22,   # 26/36
		9: 83.33,   # 30/36
		10: 91.67,  # 33/36
		11: 97.22,  # 35/36
		12: 100.0   # 36/36
	}
	
	return probabilities.get(target_number, 0.0)

## ========== EFECTOS VISUALES ==========

func show_hit_effect(position: Vector2, location: String):
	"""Muestra efecto visual de impacto"""
	# Aquí irían tus partículas, animaciones, etc.
	print("  [VFX] Hit effect at %s on %s" % [position, location])
	
	# Ejemplo:
	# var particles = hit_particles_scene.instantiate()
	# particles.position = position
	# add_child(particles)
	# particles.emitting = true

func show_miss_effect(position: Vector2):
	"""Muestra efecto visual de fallo"""
	print("  [VFX] Miss effect near %s" % position)
	
	# Ejemplo:
	# var particles = miss_particles_scene.instantiate()
	# particles.position = position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	# add_child(particles)

func show_explosion_effect(position: Vector2):
	"""Muestra efecto de explosión (munición)"""
	print("  [VFX] EXPLOSION at %s" % position)
	
	# Ejemplo:
	# var explosion = explosion_scene.instantiate()
	# explosion.position = position
	# add_child(explosion)

func show_destruction_effect(position: Vector2):
	"""Muestra efecto de mech destruido"""
	print("  [VFX] Mech destroyed at %s" % position)
	
	# Ejemplo:
	# var destruction = destruction_scene.instantiate()
	# destruction.position = position
	# add_child(destruction)

## ========== COMBAT LOG ==========

func add_to_combat_log(message: String, color: Color = Color.WHITE):
	"""Añade un mensaje al log de combate"""
	if combat_log:
		combat_log.push_color(color)
		combat_log.append_text(message + "\n")
		combat_log.pop()
		
		# Auto-scroll al final
		combat_log.scroll_to_line(combat_log.get_line_count() - 1)
	
	# También imprimir a consola
	print(message)

## ========== EJEMPLO DE USO COMPLETO ==========

func example_full_combat_turn():
	"""
	Ejemplo completo de un turno de combate
	"""
	print("\n╔═══════════════════════════════════════╗")
	print("║     COMBAT TURN - WEAPON PHASE        ║")
	print("╔═══════════════════════════════════════╝")
	
	# 1. Verificar LoS antes de empezar
	var los_data = LineOfSight.calculate_los(
		hex_grid,
		player_mech.hex_position,
		enemy_mech.hex_position
	)
	
	if los_data.result == LineOfSight.Result.BLOCKED:
		print("Cannot attack - Line of Sight blocked!")
		return
	
	# 2. Mostrar armas disponibles
	var weapons = player_mech.get_functional_weapons()
	print("\nAvailable weapons: %d" % weapons.size())
	
	# 3. Para cada arma, mostrar preview de to-hit
	for i in range(weapons.size()):
		show_to_hit_preview(enemy_mech, i)
		print("")
	
	# 4. Jugador selecciona armas (simulado)
	selected_weapon_indices = [0, 2]  # Disparar armas 0 y 2
	
	# 5. Resolver ataques
	await resolve_all_weapon_attacks()
	
	# 6. Verificar estado del objetivo
	var status = enemy_mech.get_combat_status()
	print("\n=== TARGET STATUS ===")
	print("Name: %s" % status.name)
	print("Destroyed: %s" % status.is_destroyed)
	print("Shutdown: %s" % status.is_shutdown)
	print("Heat: %d/%d" % [status.heat, enemy_mech.heat_capacity])
	print("Functional weapons: %d/%d" % [status.functional_weapons, status.total_weapons])
	
	if status.destroyed_locations.size() > 0:
		print("Destroyed locations: %s" % str(status.destroyed_locations))

## ========== MODO DEBUG ==========

func debug_test_weapon_system():
	"""
	Función de prueba para verificar el sistema
	"""
	print("\n=== DEBUG: Testing Weapon Attack System ===\n")
	
	# Crear mechs de prueba
	player_mech = Mech.new()
	player_mech.mech_name = "Atlas"
	player_mech.hex_position = Vector2i(5, 5)
	player_mech.pilot_skill = 4
	
	enemy_mech = Mech.new()
	enemy_mech.mech_name = "Locust"
	enemy_mech.hex_position = Vector2i(8, 8)
	enemy_mech.hexes_moved_this_turn = 6  # Movió 6 hexes
	
	# Arma de prueba
	var test_weapon = {
		"name": "Medium Laser",
		"damage": 5,
		"heat": 3,
		"range_short": 3,
		"range_medium": 6,
		"range_long": 9,
		"category": ComponentDatabase.WeaponCategory.ENERGY,
		"requires_ammo": false
	}
	
	player_mech.weapons.append(test_weapon)
	
	# Disparar
	var result = WeaponAttackSystem.resolve_weapon_attack(
		player_mech,
		enemy_mech,
		test_weapon,
		hex_grid
	)
	
	# Mostrar resultado
	print("Can shoot: %s" % result.can_shoot)
	print("Hit: %s" % result.hit)
	if result.hit:
		print("Damage: %d" % result.damage_applied)
		print("Locations: %s" % str(result.locations_hit))
	print("\nFull breakdown:\n%s" % result.breakdown)
