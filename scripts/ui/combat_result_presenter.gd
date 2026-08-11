class_name CombatResultPresenter
extends RefCounted
## Presenta y anima los resultados de combate en la UI
## Responsabilidad: Formatear mensajes y mostrar efectos visuales de combate

@warning_ignore("unused_signal")
signal result_presentation_complete

var _ui: Node  # BattleUI reference (CanvasLayer)
var _scene_tree: SceneTree

func _init(ui: Node, tree: SceneTree) -> void:
	_ui = ui
	_scene_tree = tree


# ============================================================
# PRESENTACIÓN DE RESULTADOS DE DISPARO
# ============================================================

func present_weapon_fire_result(attacker_name: String, target_name: String, 
		weapon_results: Array, total_heat: int, attacker_heat: int, 
		target_destroyed: bool, target_node: Node = null) -> void:
	"""Presenta el resultado completo de un disparo de armas"""
	_add_message("")
	_add_message("═══════════════════════════════", Color.YELLOW)
	_add_message("%s FIRES AT %s" % [attacker_name.to_upper(), target_name.to_upper()], Color.YELLOW)
	_add_message("═══════════════════════════════", Color.YELLOW)
	
	# Procesar cada arma
	for weapon_result in weapon_results:
		_present_single_weapon_result(weapon_result, target_node)
	
	# Mostrar calor generado
	if total_heat > 0:
		_add_message("Heat generated: +%d (Current: %d)" % [total_heat, attacker_heat], Color.ORANGE)
	
	# Verificar destrucción
	if target_destroyed:
		if target_node:
			show_destruction_effect(target_node)
		_add_message("☠ %s DESTROYED! ☠" % target_name.to_upper(), Color.RED)
	
	_add_message("═══════════════════════════════", Color.YELLOW)


func _present_single_weapon_result(weapon_result: Dictionary, target_node: Node) -> void:
	"""Presenta el resultado de un arma individual"""
	var weapon_name = weapon_result.get("weapon_name", "Unknown")
	var roll = weapon_result.get("roll", 0)
	var target_number = weapon_result.get("target_number", 0)
	var hit = weapon_result.get("hit", false)
	
	_add_message("→ %s (Roll: %d vs TN: %d)" % [weapon_name, roll, target_number], Color.CYAN)
	
	if hit:
		if target_node:
			show_hit_effect(target_node)
		var location = weapon_result.get("location", "unknown")
		var damage = weapon_result.get("damage", 0)
		_add_message("  ✓ HIT! Location: %s, Damage: %d" % [location, damage], Color.GREEN)
		
		var damage_result = weapon_result.get("damage_result", {})
		if damage_result.get("critical_hit", false):
			_add_message("    ⚠ CRITICAL HIT!", Color.RED)
		if damage_result.get("location_destroyed", false):
			_add_message("    ⚠ %s DESTROYED!" % location.to_upper(), Color.RED)
	else:
		if target_node:
			show_miss_effect(target_node)
		var miss_msg = "  ✗ MISS" if roll != 2 else "  ✗ CRITICAL MISS!"
		_add_message(miss_msg, Color.GRAY)


# ============================================================
# PRESENTACIÓN DE ATAQUES FÍSICOS
# ============================================================

const ATTACK_TYPE_NAMES = {
	"punch_left": "Punch (Left)", 
	"punch_right": "Punch (Right)", 
	"kick": "Kick", 
	"charge": "Charge"
}

func present_physical_attack_result(attacker_name: String, target_name: String,
		attack_type: String, attack_result: Dictionary, 
		target_destroyed: bool, target_node: Node = null) -> void:
	"""Presenta el resultado de un ataque físico"""
	_add_message("")
	_add_message("═══════════════════════════════", Color.MAGENTA)
	_add_message("%s PHYSICAL ATTACK vs %s" % [attacker_name.to_upper(), target_name.to_upper()], Color.MAGENTA)
	_add_message("═══════════════════════════════", Color.MAGENTA)
	
	var hit = attack_result.get("hit", false)
	var roll = attack_result.get("roll", 0)
	var target_number = attack_result.get("target_number", 0)
	
	var attack_name = ATTACK_TYPE_NAMES.get(attack_type, attack_type.capitalize())
	_add_message("→ %s (Roll: %d vs TN: %d)" % [attack_name, roll, target_number], Color.CYAN)
	
	if hit:
		if target_node:
			show_hit_effect(target_node)
		_add_message("  ✓ HIT! Location: %s, Damage: %d" % [
			attack_result.get("location", "unknown"), 
			attack_result.get("damage", 0)
		], Color.GREEN)
		
		if target_destroyed:
			if target_node:
				show_destruction_effect(target_node)
			_add_message("  ☠ %s DESTROYED! ☠" % target_name.to_upper(), Color.RED)
	else:
		if target_node:
			show_miss_effect(target_node)
		_add_message("  ✗ MISS", Color.GRAY)
	
	_add_message("═══════════════════════════════", Color.MAGENTA)


# ============================================================
# EFECTOS VISUALES
# ============================================================

func show_hit_effect(target: Node) -> void:
	"""Muestra efecto visual de impacto"""
	if not target or not is_instance_valid(target):
		return
	
	# Marcar que hay efecto visual activo
	if target.get("is_in_visual_effect") != null:
		target.is_in_visual_effect = true
	
	# Guardar color original
	var original_modulate = target.modulate
	
	# Usar tween para garantizar que el color se restaure
	var tween = target.create_tween()
	tween.tween_property(target, "modulate", Color.RED, 0.05)
	tween.tween_property(target, "modulate", original_modulate, 0.15)
	
	# Restaurar bandera al terminar
	tween.tween_callback(func():
		if is_instance_valid(target) and target.get("is_in_visual_effect") != null:
			target.is_in_visual_effect = false
	)


func show_miss_effect(_target: Node) -> void:
	"""Muestra efecto visual de fallo"""
	pass  # TODO: Implementar efecto visual de fallo


func show_destruction_effect(target: Node) -> void:
	"""Muestra efecto de destrucción"""
	if not target:
		return
	# Animación de explosión o fade out
	var tween = target.create_tween()
	tween.tween_property(target, "modulate:a", 0.0, 1.0)


# ============================================================
# UTILIDADES
# ============================================================

func _add_message(text: String, color: Color = Color.WHITE) -> void:
	"""Añade un mensaje a la UI de combate"""
	if _ui and _ui.has_method("add_combat_message"):
		_ui.add_combat_message(text, color)


# ============================================================
# PRESENTACIÓN DE RESULTADOS DE CALOR
# ============================================================

func present_heat_phase_result(mech_name: String, initial_heat: int, 
		final_heat: int, dissipated: int, shutdown: bool) -> void:
	"""Presenta el resultado de la fase de calor para un mech"""
	_add_message("%s: %d → %d heat (dissipated: %d)" % [
		mech_name, initial_heat, final_heat, dissipated
	], Color.CYAN)
	
	if shutdown:
		_add_message("  ☠ %s SHUTDOWN!" % mech_name.to_upper(), Color.RED)


func present_heat_phase_separator() -> void:
	"""Presenta el separador al final de la fase de calor"""
	_add_message("═══════════════════════════════", Color.ORANGE)


func present_battle_end(i_won: bool, reason: String) -> void:
	"""Presenta el fin de la batalla"""
	_add_message("", Color.WHITE)
	_add_message("╔══════════════════════════════════════════╗", Color.GOLD)
	if i_won:
		_add_message("║          🏆 VICTORY! 🏆                 ║", Color.GREEN)
	else:
		_add_message("║          💀 DEFEAT 💀                   ║", Color.RED)
	_add_message("╚══════════════════════════════════════════╝", Color.GOLD)
	_add_message(reason, Color.WHITE)
