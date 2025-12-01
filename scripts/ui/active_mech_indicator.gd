## ActiveMechIndicator - Indicador visual del mech activo
## Muestra un banner en la parte superior de la pantalla indicando qué mech está activo
class_name ActiveMechIndicator
extends Control

# ==============================================================================
# CONFIGURATION
# ==============================================================================
const INDICATOR_WIDTH: float = 300.0
const INDICATOR_HEIGHT: float = 50.0
const AUTO_HIDE_DELAY: float = 3.0
const SLIDE_DURATION: float = 0.4
const FADE_DURATION: float = 0.3

# ==============================================================================
# STATE
# ==============================================================================
var _panel: Panel
var _label: Label
var _tween: Tween
var _is_showing: bool = false


func _ready() -> void:
	_setup_ui()
	visible = false


func _setup_ui() -> void:
	"""Configura los elementos de UI del indicador"""
	name = "ActiveMechIndicator"
	z_index = 150
	
	# Panel de fondo
	_panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.3, 0.6, 0.9)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color.CYAN
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	
	# Label con el nombre del mech
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(_label)
	
	# Configurar tamaños
	custom_minimum_size = Vector2(INDICATOR_WIDTH, INDICATOR_HEIGHT)
	size = Vector2(INDICATOR_WIDTH, INDICATOR_HEIGHT)
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(INDICATOR_WIDTH, INDICATOR_HEIGHT)
	_label.position = Vector2.ZERO
	_label.size = Vector2(INDICATOR_WIDTH, INDICATOR_HEIGHT)


func show_for_unit(unit_name: String, auto_hide: bool = true) -> void:
	"""Muestra el indicador para una unidad"""
	# Cancelar tween anterior si existe
	if _tween and _tween.is_running():
		_tween.kill()
	
	_label.text = "► %s ACTIVE ◄" % unit_name
	_is_showing = true
	
	# Posicionar en la parte superior central de la pantalla
	var viewport_size = get_viewport().get_visible_rect().size
	position = Vector2(
		(viewport_size.x - INDICATOR_WIDTH) / 2,
		-INDICATOR_HEIGHT  # Empieza arriba de la pantalla
	)
	
	visible = true
	modulate = Color(1, 1, 1, 0)
	
	# Animación de entrada (slide down + fade in)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", 20.0, SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)
	
	# Auto-ocultar después de un delay
	if auto_hide:
		_tween.chain().tween_callback(_start_auto_hide)


func _start_auto_hide() -> void:
	"""Inicia el temporizador para auto-ocultar"""
	if not _is_showing:
		return
	
	await get_tree().create_timer(AUTO_HIDE_DELAY).timeout
	
	if _is_showing:
		hide_indicator()


func hide_indicator() -> void:
	"""Oculta el indicador con animación"""
	if not _is_showing:
		return
	
	_is_showing = false
	
	# Cancelar tween anterior si existe
	if _tween and _tween.is_running():
		_tween.kill()
	
	# Animación de salida (slide up + fade out)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", -100.0, FADE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	
	_tween.chain().tween_callback(func(): visible = false)


func is_showing() -> bool:
	"""Retorna si el indicador está visible"""
	return _is_showing
