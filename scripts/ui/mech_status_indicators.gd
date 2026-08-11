extends Node2D
class_name MechStatusIndicators

## Sistema de indicadores visuales para el estado del mech
## Muestra barras de salud, calor, y iconos de estado

# Referencias al mech padre
var mech: Node = null

# Nodos de UI
var health_bar: Node2D = null
var heat_bar: Node2D = null
var status_icons: Node2D = null

# Configuración visual
const BAR_WIDTH: float = 60.0
const BAR_HEIGHT: float = 6.0
const BAR_OFFSET_Y: float = -55.0  # Posición encima del mech
const ICON_SIZE: float = 16.0
const ICON_SPACING: float = 18.0

# Colores
const COLOR_HEALTH_GOOD = Color(0.2, 0.9, 0.2)
const COLOR_HEALTH_DAMAGED = Color(0.9, 0.9, 0.2)
const COLOR_HEALTH_CRITICAL = Color(0.9, 0.2, 0.2)
const COLOR_HEAT_LOW = Color(0.2, 0.7, 0.9)
const COLOR_HEAT_MEDIUM = Color(0.9, 0.6, 0.2)
const COLOR_HEAT_HIGH = Color(0.9, 0.2, 0.2)
const COLOR_BAR_BG = Color(0.15, 0.15, 0.15, 0.8)
const COLOR_BAR_BORDER = Color(0.3, 0.3, 0.3)

# Reservado para optimización futura si es necesario

func _init(parent_mech: Node = null):
	mech = parent_mech

func _ready():
	z_index = 100  # Encima de todo
	_setup_indicators()

func _setup_indicators():
	# Crear nodo para la barra de salud
	health_bar = Node2D.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(0, BAR_OFFSET_Y)
	add_child(health_bar)
	
	# Crear nodo para la barra de calor (debajo de salud)
	heat_bar = Node2D.new()
	heat_bar.name = "HeatBar"
	heat_bar.position = Vector2(0, BAR_OFFSET_Y + BAR_HEIGHT + 2)
	add_child(heat_bar)
	
	# Crear nodo para los iconos de estado
	status_icons = Node2D.new()
	status_icons.name = "StatusIcons"
	status_icons.position = Vector2(0, BAR_OFFSET_Y - ICON_SIZE - 4)
	add_child(status_icons)

func _draw():
	if not mech:
		return
	
	_draw_health_bar()
	_draw_heat_bar()
	_draw_status_icons()

func _draw_health_bar():
	"""Dibuja la barra de salud"""
	var health_percent = _get_health_percent()
	
	var bar_pos = Vector2(-BAR_WIDTH / 2, BAR_OFFSET_Y)
	
	# Fondo de la barra
	draw_rect(Rect2(bar_pos, Vector2(BAR_WIDTH, BAR_HEIGHT)), COLOR_BAR_BG)
	
	# Barra de salud (color según porcentaje)
	var health_color = COLOR_HEALTH_GOOD
	if health_percent < 0.3:
		health_color = COLOR_HEALTH_CRITICAL
	elif health_percent < 0.6:
		health_color = COLOR_HEALTH_DAMAGED
	
	var filled_width = BAR_WIDTH * health_percent
	draw_rect(Rect2(bar_pos, Vector2(filled_width, BAR_HEIGHT)), health_color)
	
	# Borde
	draw_rect(Rect2(bar_pos, Vector2(BAR_WIDTH, BAR_HEIGHT)), COLOR_BAR_BORDER, false, 1.0)

func _draw_heat_bar():
	"""Dibuja la barra de calor"""
	var heat_percent = _get_heat_percent()
	
	var bar_pos = Vector2(-BAR_WIDTH / 2, BAR_OFFSET_Y + BAR_HEIGHT + 2)
	var heat_bar_height = BAR_HEIGHT - 2
	
	# Fondo de la barra
	draw_rect(Rect2(bar_pos, Vector2(BAR_WIDTH, heat_bar_height)), COLOR_BAR_BG)
	
	# Barra de calor (color según porcentaje)
	var heat_color = COLOR_HEAT_LOW
	if heat_percent > 0.7:
		heat_color = COLOR_HEAT_HIGH
	elif heat_percent > 0.4:
		heat_color = COLOR_HEAT_MEDIUM
	
	var filled_width = BAR_WIDTH * heat_percent
	if filled_width > 0:
		draw_rect(Rect2(bar_pos, Vector2(filled_width, heat_bar_height)), heat_color)
	
	# Línea de peligro (en 70%)
	var danger_x = bar_pos.x + BAR_WIDTH * 0.7
	draw_line(Vector2(danger_x, bar_pos.y), Vector2(danger_x, bar_pos.y + heat_bar_height), Color.RED, 1.0)
	
	# Borde
	draw_rect(Rect2(bar_pos, Vector2(BAR_WIDTH, heat_bar_height)), COLOR_BAR_BORDER, false, 1.0)

func _draw_status_icons():
	"""Dibuja iconos de estado sobre el mech"""
	var icons_to_draw = []
	
	# Recopilar iconos según estado
	if mech.get("is_shutdown") == true:
		icons_to_draw.append({"icon": "⚡", "color": Color.ORANGE})
	
	if mech.get("is_prone") == true:
		icons_to_draw.append({"icon": "↓", "color": Color.YELLOW})
	
	# Indicador de calor crítico
	if _get_heat_percent() > 0.7:
		icons_to_draw.append({"icon": "🔥", "color": Color.RED})
	
	# Indicador de daño crítico
	if _get_health_percent() < 0.3:
		icons_to_draw.append({"icon": "⚠", "color": Color.RED})
	
	# Dibujar iconos
	if icons_to_draw.size() == 0:
		return
	
	var total_width = icons_to_draw.size() * ICON_SPACING
	var start_x = -total_width / 2 + ICON_SPACING / 2
	
	var font = ThemeDB.fallback_font
	var font_size = 14
	
	for i in range(icons_to_draw.size()):
		var icon_data = icons_to_draw[i]
		var pos = Vector2(start_x + i * ICON_SPACING, BAR_OFFSET_Y - ICON_SIZE - 2)
		draw_string(font, pos, icon_data.icon, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, icon_data.color)

func _get_health_percent() -> float:
	"""Calcula el porcentaje de salud del mech"""
	if not mech:
		return 1.0
	
	var total_current = 0.0
	var total_max = 0.0
	
	# Sumar armadura
	if mech.get("armor"):
		for location in mech.armor.keys():
			total_current += mech.armor[location].get("current", 0)
			total_max += mech.armor[location].get("max", 1)
	
	# Sumar estructura (ponderada x2 porque es más importante)
	if mech.get("structure"):
		for location in mech.structure.keys():
			total_current += mech.structure[location].get("current", 0) * 2
			total_max += mech.structure[location].get("max", 1) * 2
	
	if total_max <= 0:
		return 1.0
	
	return clamp(total_current / total_max, 0.0, 1.0)

func _get_heat_percent() -> float:
	"""Calcula el porcentaje de calor del mech"""
	if not mech:
		return 0.0
	
	var heat = mech.heat if "heat" in mech else 0
	var capacity = mech.heat_capacity if "heat_capacity" in mech else 30
	
	if capacity <= 0:
		return 0.0
	
	return clamp(float(heat) / float(capacity), 0.0, 1.0)

func update_indicators():
	"""Fuerza actualización de los indicadores"""
	queue_redraw()

func set_indicators_visible(should_show: bool):
	"""Muestra u oculta los indicadores"""
	visible = should_show
