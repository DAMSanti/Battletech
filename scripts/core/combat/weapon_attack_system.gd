class_name WeaponAttackSystem
extends RefCounted

## Sistema de ataque con armas
## Responsabilidad: Calcular to-hit, aplicar daño, generar calor

# Modificadores base para to-hit
const BASE_TO_HIT = 4  # Target number base en Battletech

# Tabla de localización de impactos (2D6)
# Para disparos frontales/laterales
const HIT_LOCATION_TABLE = {
	2: "center_torso",   # Centro del torso
	3: "right_arm",      # Brazo derecho
	4: "right_arm",      # Brazo derecho
	5: "right_leg",      # Pierna derecha
	6: "right_torso",    # Torso derecho
	7: "center_torso",   # Centro del torso
	8: "left_torso",     # Torso izquierdo
	9: "left_leg",       # Pierna izquierda
	10: "left_arm",      # Brazo izquierdo
	11: "left_arm",      # Brazo izquierdo
	12: "head"           # Cabeza
}

static func calculate_to_hit(attacker, target, weapon, range_hexes: int, terrain_modifier: int = 0) -> Dictionary:
	# Calcula el número objetivo y modificadores para impactar
	# Retorna: { "target_number": int, "modifiers": Dictionary }
	
	var target_number = BASE_TO_HIT
	var modifiers = {}
	
	# Modificador por habilidad del piloto (menor es mejor)
	var pilot_skill = attacker.pilot_skill if "pilot_skill" in attacker else 4
	modifiers["pilot_skill"] = pilot_skill
	target_number += pilot_skill
	
	# Modificador por movimiento propio (atacante)
	var attacker_movement_mod = attacker.get_attacker_movement_modifier()
	if attacker_movement_mod > 0:
		modifiers["attacker_moved"] = attacker_movement_mod
		target_number += attacker_movement_mod
	
	# Modificador por movimiento del objetivo (TMM)
	var target_tmm = target.target_movement_modifier if "target_movement_modifier" in target else 0
	if target_tmm > 0:
		modifiers["target_tmm"] = target_tmm
		target_number += target_tmm
	
	# Modificador por rango del arma
	var range_mod = _get_range_modifier(weapon, range_hexes)
	if range_mod != 0:
		modifiers["range"] = range_mod
		target_number += range_mod
	
	# Modificador por terreno/cobertura
	if terrain_modifier != 0:
		modifiers["terrain"] = terrain_modifier
		target_number += terrain_modifier
	
	# Modificador por calor (cada 5 puntos de calor = +1 to-hit)
	if "heat" in attacker and attacker.heat >= 5:
		var heat_mod = int(attacker.heat / 5)
		modifiers["heat"] = heat_mod
		target_number += heat_mod
	
	return {
		"target_number": target_number,
		"modifiers": modifiers
	}

static func _get_range_modifier(weapon, range_hexes: int) -> int:
	# Retorna el modificador por rango según el tipo de arma
	var short_range = weapon.get("range_short", 3)
	var medium_range = weapon.get("range_medium", 6)
	var long_range = weapon.get("range_long", 9)
	
	if range_hexes <= short_range:
		return 0  # Rango corto, sin modificador
	elif range_hexes <= medium_range:
		return 2  # Rango medio, +2
	elif range_hexes <= long_range:
		return 4  # Rango largo, +4
	else:
		return 999  # Fuera de rango, imposible

static func roll_to_hit() -> int:
	# Tira 2D6
	var die1 = randi() % 6 + 1
	var die2 = randi() % 6 + 1
	return die1 + die2

static func check_hit(roll: int, target_number: int) -> bool:
	# Verifica si el disparo impacta
	# En Battletech: 2 siempre falla, 12 siempre impacta
	if roll == 2:
		return false  # Fallo crítico
	if roll == 12:
		return true   # Impacto crítico
	
	return roll >= target_number

static func roll_hit_location() -> String:
	# Tira 2D6 para determinar dónde impactó
	var roll = roll_to_hit()  # Reusar la misma función de 2D6
	return HIT_LOCATION_TABLE.get(roll, "CT")

static func apply_damage(target, location: String, damage: int) -> Dictionary:
	# Aplica daño a la localización específica usando el sistema del mech
	# Retorna información sobre el daño aplicado
	
	if target.has_method("take_damage"):
		return target.take_damage(location, damage)
	
	# Fallback si no tiene el método
	return {
		"success": false,
		"message": "Target cannot take damage"
	}

static func calculate_heat_generated(weapons_fired: Array) -> int:
	# Calcula el calor total generado por las armas disparadas
	var total_heat = 0
	for weapon in weapons_fired:
		total_heat += weapon.get("heat", 0)
	return total_heat
