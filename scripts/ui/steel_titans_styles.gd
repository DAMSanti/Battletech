extends RefCounted
class_name SteelTitansStyles
## Factory para crear estilos Steel Titans consistentes
## Centraliza la creación de StyleBoxFlat para evitar duplicación

var scale_factor: float = 1.0

func _init(p_scale_factor: float = 1.0) -> void:
	scale_factor = p_scale_factor

# ============================================
# ESTILOS DE PANELES PRINCIPALES
# ============================================

## Panel principal con skew futurista (usado en weapon selector, movement selector)
func create_main_panel_style(opacity: float = 0.5) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, opacity)
	style.border_width_left = int(3 * scale_factor)
	style.border_width_top = int(3 * scale_factor)
	style.border_width_right = int(3 * scale_factor)
	style.border_width_bottom = int(3 * scale_factor)
	style.border_color = Color(0.3, 0.7, 1, 1)  # Cian brillante
	style.corner_radius_top_left = int(12 * scale_factor)
	style.corner_radius_top_right = int(12 * scale_factor)
	style.corner_radius_bottom_left = int(12 * scale_factor)
	style.corner_radius_bottom_right = int(12 * scale_factor)
	style.border_blend = true
	style.anti_aliasing = true
	style.shadow_color = Color(0.3, 0.7, 1, 0.6)
	style.shadow_size = int(10 * scale_factor)
	style.shadow_offset = Vector2(0, 3)
	style.skew = Vector2(0.05, 0)  # Inclinación futurista
	return style

## Panel secundario sin skew (para sub-paneles)
func create_secondary_panel_style(opacity: float = 0.7) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, opacity)
	style.border_width_left = int(2 * scale_factor)
	style.border_width_top = int(2 * scale_factor)
	style.border_width_right = int(2 * scale_factor)
	style.border_width_bottom = int(2 * scale_factor)
	style.border_color = Color(0.2, 0.4, 0.6, 0.8)
	style.corner_radius_top_left = int(8 * scale_factor)
	style.corner_radius_top_right = int(8 * scale_factor)
	style.corner_radius_bottom_left = int(8 * scale_factor)
	style.corner_radius_bottom_right = int(8 * scale_factor)
	return style

## Panel de información (info_panel, esquina derecha)
func create_info_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.85)
	style.border_width_left = int(2 * scale_factor)
	style.border_width_top = int(2 * scale_factor)
	style.border_width_right = int(2 * scale_factor)
	style.border_width_bottom = int(2 * scale_factor)
	style.border_color = Color(0.2, 0.4, 0.6, 0.8)
	style.corner_radius_top_left = int(8 * scale_factor)
	style.corner_radius_top_right = int(8 * scale_factor)
	style.corner_radius_bottom_left = int(8 * scale_factor)
	style.corner_radius_bottom_right = int(8 * scale_factor)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = int(5 * scale_factor)
	return style

## Panel del log de combate con skew
func create_log_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.75)
	style.border_width_left = int(2 * scale_factor)
	style.border_width_top = int(2 * scale_factor)
	style.border_width_right = int(2 * scale_factor)
	style.border_width_bottom = int(2 * scale_factor)
	style.border_color = Color(0.2, 0.4, 0.6, 0.8)
	style.corner_radius_top_left = int(4 * scale_factor)
	style.corner_radius_top_right = int(8 * scale_factor)
	style.corner_radius_bottom_left = int(4 * scale_factor)
	style.corner_radius_bottom_right = int(8 * scale_factor)
	style.skew = Vector2(0.03, 0)
	return style

## Panel de weapon info (detalle de arma)
func create_weapon_info_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.98)
	style.border_width_left = int(3 * scale_factor)
	style.border_width_right = int(3 * scale_factor)
	style.border_width_top = int(3 * scale_factor)
	style.border_width_bottom = int(3 * scale_factor)
	style.border_color = Color(0.3, 0.7, 1.0, 1.0)
	style.corner_radius_top_left = int(4 * scale_factor)
	style.corner_radius_top_right = int(12 * scale_factor)
	style.corner_radius_bottom_left = int(12 * scale_factor)
	style.corner_radius_bottom_right = int(4 * scale_factor)
	style.shadow_color = Color(0.2, 0.5, 0.8, 0.5)
	style.shadow_size = int(8 * scale_factor)
	style.skew = Vector2(0.03, 0)
	return style

# ============================================
# ESTILOS DE BOTONES
# ============================================

## Botón de acción positiva (verde - Fire, Confirm)
func create_positive_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.35, 0.15, 0.9)
	style.border_width_left = int(2 * scale_factor)
	style.border_width_top = int(2 * scale_factor)
	style.border_width_right = int(2 * scale_factor)
	style.border_width_bottom = int(2 * scale_factor)
	style.border_color = Color(0.3, 0.8, 0.3, 1)
	style.corner_radius_top_left = int(6 * scale_factor)
	style.corner_radius_top_right = int(6 * scale_factor)
	style.corner_radius_bottom_left = int(6 * scale_factor)
	style.corner_radius_bottom_right = int(6 * scale_factor)
	style.skew = Vector2(0.05, 0)
	return style

## Botón de acción positiva (hover)
func create_positive_button_hover_style() -> StyleBoxFlat:
	var style = create_positive_button_style()
	style.bg_color = Color(0.2, 0.45, 0.2, 0.95)
	return style

## Botón de acción negativa (rojo - Cancel)
func create_negative_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.15, 0.15, 0.9)
	style.border_width_left = int(2 * scale_factor)
	style.border_width_top = int(2 * scale_factor)
	style.border_width_right = int(2 * scale_factor)
	style.border_width_bottom = int(2 * scale_factor)
	style.border_color = Color(0.8, 0.3, 0.3, 1)
	style.corner_radius_top_left = int(6 * scale_factor)
	style.corner_radius_top_right = int(6 * scale_factor)
	style.corner_radius_bottom_left = int(6 * scale_factor)
	style.corner_radius_bottom_right = int(6 * scale_factor)
	style.skew = Vector2(0.05, 0)
	return style

## Botón de acción negativa (hover)
func create_negative_button_hover_style() -> StyleBoxFlat:
	var style = create_negative_button_style()
	style.bg_color = Color(0.45, 0.2, 0.2, 0.95)
	return style

## Botón de cerrar (X) pequeño
func create_close_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.15, 0.15, 0.8)
	style.border_color = Color(0.8, 0.3, 0.3, 0.8)
	style.border_width_left = int(2 * scale_factor)
	style.border_width_right = int(2 * scale_factor)
	style.border_width_top = int(2 * scale_factor)
	style.border_width_bottom = int(2 * scale_factor)
	style.corner_radius_top_left = int(4 * scale_factor)
	style.corner_radius_top_right = int(4 * scale_factor)
	style.corner_radius_bottom_left = int(4 * scale_factor)
	style.corner_radius_bottom_right = int(4 * scale_factor)
	style.skew = Vector2(0.03, 0)
	return style

## Botón de cerrar (hover)
func create_close_button_hover_style() -> StyleBoxFlat:
	var style = create_close_button_style()
	style.bg_color = Color(0.6, 0.2, 0.2, 0.9)
	return style

## Botón pequeño del log (collapse)
func create_collapse_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.2, 0.8)
	style.border_color = Color(0.3, 0.5, 0.7, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

## Botón pequeño del log (hover)
func create_collapse_button_hover_style() -> StyleBoxFlat:
	var style = create_collapse_button_style()
	style.bg_color = Color(0.15, 0.2, 0.28, 0.9)
	return style

## Botón de confirmación positivo (tick verde)
func create_confirm_tick_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.3, 0.05, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.1, 0.9, 0.1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

## Botón de confirmación negativo (cruz roja)
func create_cancel_cross_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.05, 0.05, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.95, 0.15, 0.15)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

# ============================================
# ESTILOS DE INPUTS
# ============================================

## Campo de entrada de texto (chat input)
func create_text_input_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	style.border_color = Color(0.2, 0.4, 0.6, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

# ============================================
# ESTILOS DE SCROLLBARS
# ============================================

## Grabber de scrollbar
func create_scrollbar_grabber_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.5, 0.7, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.skew = Vector2(0.03, 0)
	return style

## Fondo de scrollbar
func create_scrollbar_background_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.7)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.skew = Vector2(0.03, 0)
	return style

# ============================================
# ESTILOS DE TEXTO
# ============================================

## Fondo del combat log text area
func create_combat_log_text_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.5)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.15, 0.3, 0.45, 0.5)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

# ============================================
# ESTILOS DE HEADER
# ============================================

## Header de panel con borde inferior
func create_header_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.15, 0.25, 0.95)
	style.border_width_bottom = int(2 * scale_factor)
	style.border_color = Color(0.3, 0.7, 1.0, 0.8)
	style.skew = Vector2(0.03, 0)
	return style

# ============================================
# ESTILOS DE CONFIRMACIÓN
# ============================================

## Panel de confirmación
func create_confirmation_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.5)
	style.border_width_left = int(3 * scale_factor)
	style.border_width_right = int(3 * scale_factor)
	style.border_width_top = int(3 * scale_factor)
	style.border_width_bottom = int(3 * scale_factor)
	style.border_color = Color(0.3, 0.7, 1, 1)
	style.corner_radius_top_left = int(8 * scale_factor)
	style.corner_radius_top_right = int(8 * scale_factor)
	style.corner_radius_bottom_left = int(8 * scale_factor)
	style.corner_radius_bottom_right = int(8 * scale_factor)
	style.border_blend = true
	style.anti_aliasing = true
	style.shadow_color = Color(0.3, 0.7, 1, 0.6)
	style.shadow_size = int(10 * scale_factor)
	style.shadow_offset = Vector2(0, 3)
	style.skew = Vector2(0.05, 0)
	return style

# ============================================
# ESTILOS DE BOTONES ADICIONALES
# ============================================

## Botón de End Turn (verde militar)
func create_end_turn_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.35, 0.2, 0.9)
	style.border_color = Color(0.3, 0.7, 0.4, 1)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 1
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func create_end_turn_button_hover_style() -> StyleBoxFlat:
	var style = create_end_turn_button_style()
	style.bg_color = Color(0.2, 0.45, 0.25, 1)
	return style

## Botón de Eye (azul futurista)
func create_eye_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.22, 0.9)
	style.border_color = Color(0.3, 0.6, 0.9, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style

func create_eye_button_hover_style() -> StyleBoxFlat:
	var style = create_eye_button_style()
	style.bg_color = Color(0.15, 0.22, 0.32, 0.95)
	return style

## Botón de Cancel Movement (rojo)
func create_cancel_movement_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.1, 0.1, 0.9)
	style.border_color = Color(0.8, 0.2, 0.2, 1)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 1
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func create_cancel_movement_button_hover_style() -> StyleBoxFlat:
	var style = create_cancel_movement_button_style()
	style.bg_color = Color(0.5, 0.15, 0.15, 1)
	return style

# ============================================
# ESTILOS DE HEAT BAR
# ============================================

## Fondo de heat bar
func create_heat_bar_background_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_color = Color(0.3, 0.3, 0.3, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style

## Fill de heat bar
func create_heat_bar_fill_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.7, 0.3, 1)
	style.set_corner_radius_all(1)
	return style

# ============================================
# ESTILOS DE HEADER
# ============================================

## Header de weapon info panel
func create_weapon_info_header_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.15, 0.25, 0.95)
	style.border_width_bottom = int(2 * scale_factor)
	style.border_color = Color(0.3, 0.7, 1.0, 0.8)
	style.skew = Vector2(0.03, 0)
	return style

# ============================================
# COLORES COMUNES
# ============================================

static func get_cyan_text_color() -> Color:
	return Color(0.7, 0.9, 1, 1)

static func get_white_text_color() -> Color:
	return Color(0.85, 0.92, 1, 1)

static func get_outline_color() -> Color:
	return Color(0, 0.1, 0.2, 1)

static func get_positive_color() -> Color:
	return Color(0.1, 0.9, 0.1)

static func get_negative_color() -> Color:
	return Color(0.95, 0.15, 0.15)

static func get_weapon_energy_color() -> Color:
	return Color(0.5, 0.8, 0.5)

static func get_weapon_ballistic_color() -> Color:
	return Color(0.8, 0.7, 0.5)

static func get_weapon_missile_color() -> Color:
	return Color(0.5, 0.5, 0.8)

# ============================================
# ESTILOS DE PANELES DE DIALOGO
# ============================================

## Panel de game over
func create_game_over_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_color = Color.GOLD
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	return style

## Panel de mech inspector
func create_mech_inspector_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color.CYAN
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	return style

## Panel de paper doll modal
func create_paper_doll_modal_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.13, 0.95)
	style.border_width_left = 3
	style.border_width_top = 2
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.2, 0.55, 0.85, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = Color(0.15, 0.35, 0.55, 0.5)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style

## Menu de overlay (eye menu)
func create_overlay_menu_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	style.border_color = Color(0.3, 0.6, 0.9, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

## Toggle button (activo/inactivo)
func create_toggle_button_style(is_active: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.25, 0.8) if is_active else Color(0.08, 0.1, 0.14, 0.6)
	style.border_color = Color(0.3, 0.7, 0.5, 0.8) if is_active else Color(0.2, 0.3, 0.4, 0.5)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 2
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

# ============================================
# ESTILOS DE SWITCH
# ============================================

## Fondo del switch
func create_switch_background_style(enabled: bool = true) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	if enabled:
		style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
	else:
		style.bg_color = Color(0.15, 0.15, 0.15, 0.5)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.5, 0.7, 0.9) if enabled else Color(0.2, 0.2, 0.2, 0.5)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.anti_aliasing = true
	return style

## Slider del switch
func create_switch_slider_style(enabled: bool = true) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	if enabled:
		style.bg_color = Color(0.6, 0.6, 0.7, 1)
	else:
		style.bg_color = Color(0.4, 0.4, 0.4, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.anti_aliasing = true
	if enabled:
		style.shadow_color = Color(0.3, 0.5, 0.7, 0.5)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 1)
	return style
