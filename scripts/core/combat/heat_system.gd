class_name HeatSystem
extends RefCounted

## Sistema de gestión de calor
## Responsabilidad: Calcular efectos del calor y gestionar disipación

# Tabla de efectos del calor (según nivel de calor)
const HEAT_EFFECTS = {
	0: {"name": "Normal", "movement_penalty": 0, "to_hit_penalty": 0, "shutdown_risk": 0, "ammo_explosion_risk": 0},
	5: {"name": "Hot", "movement_penalty": 0, "to_hit_penalty": 1, "shutdown_risk": 0, "ammo_explosion_risk": 0},
	8: {"name": "Very Hot", "movement_penalty": 0, "to_hit_penalty": 1, "shutdown_risk": 0, "ammo_explosion_risk": 0},
	10: {"name": "Heating Up", "movement_penalty": 1, "to_hit_penalty": 1, "shutdown_risk": 0, "ammo_explosion_risk": 0},
	14: {"name": "Critical Heat", "movement_penalty": 2, "to_hit_penalty": 2, "shutdown_risk": 0, "ammo_explosion_risk": 0},
	17: {"name": "Dangerous", "movement_penalty": 3, "to_hit_penalty": 2, "shutdown_risk": 0, "ammo_explosion_risk": 0},
	19: {"name": "Ammo Risk", "movement_penalty": 4, "to_hit_penalty": 3, "shutdown_risk": 6, "ammo_explosion_risk": 4},
	23: {"name": "Shutdown Risk", "movement_penalty": 5, "to_hit_penalty": 4, "shutdown_risk": 8, "ammo_explosion_risk": 5},
	26: {"name": "Critical!", "movement_penalty": 6, "to_hit_penalty": 5, "shutdown_risk": 10, "ammo_explosion_risk": 8},
	30: {"name": "SHUTDOWN!", "movement_penalty": 999, "to_hit_penalty": 999, "shutdown_risk": 100, "ammo_explosion_risk": 10}
}

# Calor generado por movimiento
const MOVEMENT_HEAT = {
	"WALK": 0,
	"RUN": 2,
	"JUMP": 1  # 1 por hex saltado
}

static func get_heat_effects(current_heat: int) -> Dictionary:
	# Retorna los efectos del calor actual
	var effects = HEAT_EFFECTS[0].duplicate()
	
	# Buscar el nivel de calor más alto que no supere el actual
	for heat_level in HEAT_EFFECTS.keys():
		if current_heat >= heat_level:
			effects = HEAT_EFFECTS[heat_level].duplicate()
	
	return effects

static func get_heat_status_color(current_heat: int, max_heat: int) -> Color:
	# Retorna el color según el nivel de calor
	var heat_percent = float(current_heat) / float(max_heat)
	
	if heat_percent < 0.3:
		return Color.GREEN
	elif heat_percent < 0.5:
		return Color.YELLOW
	elif heat_percent < 0.7:
		return Color.ORANGE
	elif heat_percent < 0.9:
		return Color.RED
	else:
		return Color.DARK_RED

static func calculate_movement_heat(movement_type: int, hexes_moved: int) -> int:
	# Calcula calor generado por movimiento
	match movement_type:
		1:  # WALK
			return 0
		2:  # RUN
			return 2
		3:  # JUMP
			return hexes_moved  # 1 calor por hex saltado
	return 0

static func check_shutdown(current_heat: int) -> Dictionary:
	# Verifica si el mech debe apagarse
	var effects = get_heat_effects(current_heat)
	var shutdown_risk = effects.get("shutdown_risk", 0)
	
	if shutdown_risk == 0:
		return {"must_shutdown": false, "roll": 0, "target": 0}
	
	if shutdown_risk >= 100:
		return {"must_shutdown": true, "roll": 0, "target": 0, "automatic": true}
	
	# Tirar 2D6 para evitar shutdown
	var roll = randi() % 6 + randi() % 6 + 2
	var target = shutdown_risk
	
	return {
		"must_shutdown": roll < target,
		"roll": roll,
		"target": target,
		"automatic": false
	}

static func check_ammo_explosion(current_heat: int) -> Dictionary:
	# Verifica si hay riesgo de explosión de munición
	var effects = get_heat_effects(current_heat)
	var explosion_risk = effects.get("ammo_explosion_risk", 0)
	
	if explosion_risk == 0:
		return {"explodes": false, "roll": 0, "target": 0}
	
	# Tirar 2D6 para evitar explosión
	var roll = randi() % 6 + randi() % 6 + 2
	var target = explosion_risk
	
	return {
		"explodes": roll <= target,
		"roll": roll,
		"target": target
	}

static func apply_heat_dissipation(mech) -> Dictionary:
	# Aplica la disipación de calor de un mech
	var initial_heat = mech.heat
	var dissipation = mech.heat_dissipation
	
	# Si está en agua, disipa el doble (regla opcional)
	# TODO: Implementar cuando tengamos detección de terreno bajo el mech
	
	mech.heat = max(0, mech.heat - dissipation)
	var heat_removed = initial_heat - mech.heat
	
	# Si el calor baja de 30, el mech puede reiniciarse
	if initial_heat >= 30 and mech.heat < 30:
		mech.is_shutdown = false
	
	return {
		"initial_heat": initial_heat,
		"heat_removed": heat_removed,
		"current_heat": mech.heat,
		"restarted": initial_heat >= 30 and mech.heat < 30
	}

static func get_heat_description(current_heat: int) -> String:
	# Retorna descripción del estado de calor
	var effects = get_heat_effects(current_heat)
	var desc = effects["name"]
	
	if effects["to_hit_penalty"] > 0:
		desc += " (+%d to-hit)" % effects["to_hit_penalty"]
	
	if effects["movement_penalty"] > 0:
		desc += " (-%d MP)" % effects["movement_penalty"]
	
	if effects["shutdown_risk"] > 0:
		desc += " (Shutdown: %d+)" % effects["shutdown_risk"]
	
	if effects["ammo_explosion_risk"] > 0:
		desc += " (Ammo: %d-)" % effects["ammo_explosion_risk"]
	
	return desc
