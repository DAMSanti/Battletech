extends Control

var armor_data = null

func set_armor(armor: Dictionary):
	armor_data = armor
	queue_redraw()


func get_health_color(current, max):
	# Color basado en el ratio de salud (para estructura y armadura)
	var ratio = float(current) / float(max) if max > 0 else 0.0
	if ratio > 0.66:
		return Color(0.2, 1.0, 0.2) # Verde
	elif ratio > 0.33:
		return Color(1.0, 0.8, 0.1) # Amarillo
	elif ratio > 0.15:
		return Color(1.0, 0.4, 0.0) # Naranja
	else:
		return Color(1.0, 0.1, 0.1) # Rojo

func _draw():
	if armor_data == null:
		return
	
	# Dimensiones base
	var w = size.x
	var h = size.y
	var cx = w / 2
	var y = h * 0.08
	var scale = min(w, h) / 120.0
	
	# Ancho del borde de armadura
	var armor_border = 4 * scale
	
	# === CABEZA ===
	var head_rect = Rect2(cx - 10 * scale, y - 45 * scale, 20 * scale, 15 * scale)
	draw_mech_part(head_rect, "head", armor_border)
	
	# === TORSO CENTRAL ===
	var ct_rect = Rect2(cx - 15 * scale, y - 25 * scale, 30 * scale, 45 * scale)
	draw_mech_part(ct_rect, "center_torso", armor_border)
	
	# === TORSO IZQUIERDO ===
	var lt_rect = Rect2(cx - 30 * scale, y - 20 * scale, 14 * scale, 35 * scale)
	draw_mech_part(lt_rect, "left_torso", armor_border)
	
	# === TORSO DERECHO ===
	var rt_rect = Rect2(cx + 16 * scale, y - 20 * scale, 14 * scale, 35 * scale)
	draw_mech_part(rt_rect, "right_torso", armor_border)
	
	# === BRAZO IZQUIERDO ===
	var la_rect = Rect2(cx - 48 * scale, y - 18 * scale, 14 * scale, 35 * scale)
	draw_mech_part(la_rect, "left_arm", armor_border)
	
	# === BRAZO DERECHO ===
	var ra_rect = Rect2(cx + 34 * scale, y - 18 * scale, 14 * scale, 35 * scale)
	draw_mech_part(ra_rect, "right_arm", armor_border)
	
	# === PIERNA IZQUIERDA ===
	var ll_rect = Rect2(cx - 18 * scale, y + 20 * scale, 13 * scale, 40 * scale)
	draw_mech_part(ll_rect, "left_leg", armor_border)
	
	# === PIERNA DERECHA ===
	var rl_rect = Rect2(cx + 5 * scale, y + 20 * scale, 13 * scale, 40 * scale)
	draw_mech_part(rl_rect, "right_leg", armor_border)

func draw_mech_part(rect: Rect2, part_name: String, border_width: float):
	# Obtener valores de estructura y armadura
	var structure_current = armor_data.get(part_name + "_structure", 0)
	var structure_max = armor_data.get(part_name + "_structure_max", 1)  # Usar 1 como fallback para evitar división por 0

	# Verificar que exista la clave de armadura
	if not armor_data.has(part_name):
		return

	var armor_current = armor_data[part_name]["current"]
	var armor_max = armor_data[part_name]["max"]

	# Si no hay datos de estructura, usar valores por defecto razonables
	if structure_max <= 0:
		structure_max = 1
	if structure_current < 0:
		structure_current = 0

	# Color de la estructura (relleno)
	var structure_color = get_health_color(structure_current, structure_max)

	# Color de la armadura (borde)
	var armor_color = get_health_color(armor_current, armor_max)

	# Dibujar la estructura (relleno)
	draw_rect(rect, structure_color)

	# Dibujar la armadura (borde grueso)
	draw_rect(rect, armor_color, false, border_width)

func draw_text_with_bg(pos, text, color, font=null, fsize=18, outline_color=Color(0,0,0,0.8)):
	if font == null:
		font = get_theme_default_font()
	var pad = 2
	var rect = Rect2(pos - Vector2(pad, fsize*0.8), font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize) + Vector2(pad*2, fsize*1.2))
	draw_rect(rect, outline_color)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, color)
