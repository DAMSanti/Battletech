extends Control
class_name BattleEndScreen

## Pantalla de fin de batalla mejorada con estadísticas completas

signal return_to_menu_pressed
signal play_again_pressed

# Referencias UI
var main_panel: PanelContainer
var title_label: Label
var result_label: Label
var stats_container: VBoxContainer
var buttons_container: HBoxContainer

# Datos
var battle_stats: Dictionary = {}
var player_won: bool = false
var winner_name: String = ""
var loser_name: String = ""
var death_reason: String = ""

# Estilo
var scale_factor: float = 1.0

func _ready():
	# Configurar para cubrir toda la pantalla
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Detectar escala
	var viewport_size = get_viewport().get_visible_rect().size
	scale_factor = min(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	scale_factor = clamp(scale_factor, 0.5, 2.0)

func setup(stats: Dictionary, won: bool, winner: String, loser: String, reason: String):
	"""Configura la pantalla con los datos de la batalla"""
	battle_stats = stats
	player_won = won
	winner_name = winner
	loser_name = loser
	death_reason = reason
	
	_build_ui()

func _build_ui():
	# Fondo oscuro semi-transparente
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	add_child(bg)
	
	# Panel principal centrado
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(900 * scale_factor, 700 * scale_factor)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.15, 0.98)
	panel_style.border_color = Color(0.3, 0.5, 0.8) if player_won else Color(0.8, 0.3, 0.3)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	main_panel.add_theme_stylebox_override("panel", panel_style)
	center_container.add_child(main_panel)
	
	# Contenedor principal
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", int(15 * scale_factor))
	main_panel.add_child(main_vbox)
	
	# Margen interno
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(30 * scale_factor))
	margin.add_theme_constant_override("margin_right", int(30 * scale_factor))
	margin.add_theme_constant_override("margin_top", int(20 * scale_factor))
	margin.add_theme_constant_override("margin_bottom", int(20 * scale_factor))
	main_vbox.add_child(margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", int(15 * scale_factor))
	margin.add_child(content_vbox)
	
	# TÍTULO
	_add_title(content_vbox)
	
	# RESULTADO
	_add_result_section(content_vbox)
	
	# SEPARADOR
	var sep1 = HSeparator.new()
	content_vbox.add_child(sep1)
	
	# ESTADÍSTICAS
	_add_stats_section(content_vbox)
	
	# SEPARADOR
	var sep2 = HSeparator.new()
	content_vbox.add_child(sep2)
	
	# MVP
	_add_mvp_section(content_vbox)
	
	# ESPACIADOR FLEXIBLE
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(spacer)
	
	# BOTONES
	_add_buttons(content_vbox)

func _add_title(parent: Control):
	title_label = Label.new()
	title_label.text = "⚔️ BATTLE COMPLETE ⚔️"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", int(36 * scale_factor))
	title_label.add_theme_color_override("font_color", Color.GOLD)
	parent.add_child(title_label)

func _add_result_section(parent: Control):
	var result_container = VBoxContainer.new()
	result_container.add_theme_constant_override("separation", int(10 * scale_factor))
	parent.add_child(result_container)
	
	# Victoria o Derrota
	result_label = Label.new()
	if player_won:
		result_label.text = "🏆 VICTORY! 🏆"
		result_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	else:
		result_label.text = "💀 DEFEAT 💀"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", int(32 * scale_factor))
	result_container.add_child(result_label)
	
	# Detalles del resultado
	var details = RichTextLabel.new()
	details.bbcode_enabled = true
	details.fit_content = true
	details.scroll_active = false
	details.custom_minimum_size = Vector2(0, 60 * scale_factor)
	
	var details_text = "[center]"
	details_text += "[color=#4d9fff]Winner:[/color] [color=white]%s[/color]\n" % winner_name
	details_text += "[color=#ff6666]%s[/color] - [color=#aaaaaa]%s[/color]" % [loser_name, death_reason]
	details_text += "[/center]"
	details.text = details_text
	result_container.add_child(details)

func _add_stats_section(parent: Control):
	var stats_label = Label.new()
	stats_label.text = "📊 BATTLE STATISTICS"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", int(24 * scale_factor))
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	parent.add_child(stats_label)
	
	# Grid de estadísticas comparativas
	var stats_grid = GridContainer.new()
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", int(40 * scale_factor))
	stats_grid.add_theme_constant_override("v_separation", int(8 * scale_factor))
	parent.add_child(stats_grid)
	
	# Centrar el grid
	var grid_center = CenterContainer.new()
	parent.add_child(grid_center)
	grid_center.add_child(stats_grid)
	
	# Obtener datos
	var player_data = battle_stats.get("player", {})
	var enemy_data = battle_stats.get("enemy", {})
	
	# Headers
	_add_stat_cell(stats_grid, "YOUR TEAM", Color(0.3, 0.7, 1.0), true)
	_add_stat_cell(stats_grid, "", Color.WHITE, true)
	_add_stat_cell(stats_grid, "ENEMY", Color(1.0, 0.4, 0.4), true)
	
	# Filas de stats
	_add_stat_row(stats_grid, player_data.get("total_damage", 0), "Damage Dealt", enemy_data.get("total_damage", 0))
	_add_stat_row(stats_grid, player_data.get("total_received", 0), "Damage Taken", enemy_data.get("total_received", 0))
	_add_stat_row(stats_grid, "%.1f%%" % player_data.get("accuracy", 0), "Accuracy", "%.1f%%" % enemy_data.get("accuracy", 0))
	_add_stat_row(stats_grid, player_data.get("criticals", 0), "Critical Hits", enemy_data.get("criticals", 0))
	_add_stat_row(stats_grid, player_data.get("kills", 0), "Mechs Destroyed", enemy_data.get("kills", 0))
	
	# Duración y turnos
	var duration_label = Label.new()
	duration_label.text = "⏱️ Duration: %s | Turns: %d" % [battle_stats.get("duration", "00:00"), battle_stats.get("turns", 0)]
	duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	duration_label.add_theme_font_size_override("font_size", int(18 * scale_factor))
	duration_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	parent.add_child(duration_label)

func _add_stat_cell(grid: GridContainer, text: String, color: Color, is_header: bool = false):
	var label = Label.new()
	label.text = str(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", int((20 if is_header else 18) * scale_factor))
	label.custom_minimum_size = Vector2(150 * scale_factor, 0)
	grid.add_child(label)

func _add_stat_row(grid: GridContainer, player_val, stat_name: String, enemy_val):
	# Determinar quién tiene mejor valor
	var player_is_better = false
	var enemy_is_better = false
	
	if typeof(player_val) == TYPE_INT or typeof(player_val) == TYPE_FLOAT:
		if stat_name == "Damage Taken":
			player_is_better = player_val < enemy_val
			enemy_is_better = enemy_val < player_val
		else:
			player_is_better = player_val > enemy_val
			enemy_is_better = enemy_val > player_val
	
	# Valor del jugador
	var player_color = Color(0.3, 1.0, 0.3) if player_is_better else Color(0.8, 0.8, 0.8)
	_add_stat_cell(grid, str(player_val), player_color)
	
	# Nombre del stat
	_add_stat_cell(grid, stat_name, Color(0.6, 0.6, 0.6))
	
	# Valor del enemigo
	var enemy_color = Color(1.0, 0.5, 0.5) if enemy_is_better else Color(0.8, 0.8, 0.8)
	_add_stat_cell(grid, str(enemy_val), enemy_color)

func _add_mvp_section(parent: Control):
	var mvp_container = HBoxContainer.new()
	mvp_container.alignment = BoxContainer.ALIGNMENT_CENTER
	mvp_container.add_theme_constant_override("separation", int(50 * scale_factor))
	parent.add_child(mvp_container)
	
	# MVP del jugador
	var player_mvp = battle_stats.get("player", {}).get("mvp", {})
	if player_mvp.get("name", "") != "":
		_add_mvp_card(mvp_container, "🌟 YOUR MVP", player_mvp.get("name", ""), player_mvp.get("damage", 0), Color(0.3, 0.7, 1.0))
	
	# MVP enemigo
	var enemy_mvp = battle_stats.get("enemy", {}).get("mvp", {})
	if enemy_mvp.get("name", "") != "":
		_add_mvp_card(mvp_container, "💀 ENEMY MVP", enemy_mvp.get("name", ""), enemy_mvp.get("damage", 0), Color(1.0, 0.4, 0.4))

func _add_mvp_card(parent: Control, title: String, mech_name: String, damage: int, color: Color):
	var card = VBoxContainer.new()
	card.add_theme_constant_override("separation", int(5 * scale_factor))
	parent.add_child(card)
	
	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", int(16 * scale_factor))
	title_lbl.add_theme_color_override("font_color", color)
	card.add_child(title_lbl)
	
	var name_lbl = Label.new()
	name_lbl.text = mech_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", int(20 * scale_factor))
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	card.add_child(name_lbl)
	
	var dmg_lbl = Label.new()
	dmg_lbl.text = "%d damage dealt" % damage
	dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg_lbl.add_theme_font_size_override("font_size", int(14 * scale_factor))
	dmg_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	card.add_child(dmg_lbl)

func _add_buttons(parent: Control):
	buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_container.add_theme_constant_override("separation", int(30 * scale_factor))
	parent.add_child(buttons_container)
	
	# Botón Play Again
	var play_again_btn = Button.new()
	play_again_btn.text = "🔄 PLAY AGAIN"
	play_again_btn.custom_minimum_size = Vector2(200 * scale_factor, 50 * scale_factor)
	play_again_btn.add_theme_font_size_override("font_size", int(20 * scale_factor))
	play_again_btn.pressed.connect(_on_play_again)
	buttons_container.add_child(play_again_btn)
	
	# Botón Main Menu
	var menu_btn = Button.new()
	menu_btn.text = "🏠 MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(200 * scale_factor, 50 * scale_factor)
	menu_btn.add_theme_font_size_override("font_size", int(20 * scale_factor))
	menu_btn.pressed.connect(_on_return_to_menu)
	buttons_container.add_child(menu_btn)

func _on_play_again():
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	play_again_pressed.emit()
	# Recargar la escena de batalla
	get_tree().change_scene_to_file("res://scenes/team_setup.tscn")

func _on_return_to_menu():
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX_UI_CLICK)
	return_to_menu_pressed.emit()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
