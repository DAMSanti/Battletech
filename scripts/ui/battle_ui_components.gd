extends RefCounted
class_name BattleUIComponents
## Fachada que coordina todos los componentes de UI de batalla
## Utilizada por battle_ui.gd para delegar funcionalidad a componentes modulares

var _parent: CanvasLayer
var _scale_factor: float = 1.0
var _margin: float = 10.0
var _theme: Theme

# Componentes
var styles: SteelTitansStyles
var mech_inspector: BattleMechInspector
var combat_log_panel: BattleCombatLogPanel
var overlay_menu: BattleOverlayMenu

# Estado del log (para compatibilidad con código existente)
var message_history: Array:
	get:
		if combat_log_panel:
			return combat_log_panel.message_history
		return []
var chat_history: Array:
	get:
		if combat_log_panel:
			return combat_log_panel.chat_history
		return []
var combat_log_mode: String:
	get:
		if combat_log_panel:
			return combat_log_panel.combat_log_mode
		return "full"
var combat_log_collapsed: bool:
	get:
		if combat_log_panel:
			return combat_log_panel.combat_log_collapsed
		return false

# Estado de overlays (para compatibilidad)
var overlay_settings: Dictionary:
	get:
		if overlay_menu:
			return overlay_menu.overlay_settings
		return {}
var los_overlay_visible: bool:
	get:
		if overlay_menu:
			return overlay_menu.los_overlay_visible
		return false
var los_overlay_hexes: Array:
	get:
		if overlay_menu:
			return overlay_menu.los_overlay_hexes
		return []

func _init(parent: CanvasLayer, theme: Theme, scale_factor: float, p_margin: float) -> void:
	_parent = parent
	_theme = theme
	_scale_factor = scale_factor
	_margin = p_margin
	
	# Inicializar componentes
	styles = SteelTitansStyles.new(_scale_factor)
	mech_inspector = BattleMechInspector.new(_parent, _theme, _scale_factor, _margin)

func setup_combat_log(position: Vector2, size: Vector2, battle_scene: Node) -> BattleCombatLogPanel:
	"""Crea y configura el panel de combat log"""
	combat_log_panel = BattleCombatLogPanel.new()
	combat_log_panel.position = position
	combat_log_panel.size = size
	combat_log_panel.setup(_scale_factor, _margin, _theme)
	combat_log_panel.chat_message_sent.connect(_on_chat_message_sent.bind(battle_scene))
	_parent.add_child(combat_log_panel)
	return combat_log_panel

func setup_overlay_menu(info_panel: Panel, battle_scene: Node) -> BattleOverlayMenu:
	"""Crea y configura el menú de overlays"""
	overlay_menu = BattleOverlayMenu.new()
	
	# Posicionar debajo del info_panel
	var menu_width = 180 * _scale_factor
	var menu_x = info_panel.position.x + info_panel.size.x - menu_width
	var menu_y = info_panel.position.y + info_panel.size.y + 5 * _scale_factor
	
	overlay_menu.position = Vector2(menu_x, menu_y)
	overlay_menu.setup(_scale_factor, battle_scene)
	
	# Conectar señales para actualizar overlays en battle_scene
	overlay_menu.los_overlay_requested.connect(_on_los_overlay_requested.bind(battle_scene))
	overlay_menu.los_overlay_cleared.connect(_on_los_overlay_cleared.bind(battle_scene))
	
	_parent.add_child(overlay_menu)
	return overlay_menu

# ============================================
# API DE COMBAT LOG
# ============================================

func add_combat_message(message: String, color: Color = Color.WHITE) -> void:
	if combat_log_panel:
		combat_log_panel.add_combat_message(message, color)

func add_chat_message(sender: String, message: String, color: Color = Color.WHITE) -> void:
	if combat_log_panel:
		combat_log_panel.add_chat_message(sender, message, color)

func refresh_combat_log() -> void:
	if combat_log_panel:
		combat_log_panel.refresh_log()

func get_log_panel() -> Panel:
	return combat_log_panel

func is_log_collapsed() -> bool:
	if combat_log_panel:
		return combat_log_panel.is_collapsed()
	return false

func get_log_expanded_height() -> float:
	if combat_log_panel:
		return combat_log_panel.get_expanded_height()
	return 0.0

# ============================================
# API DE OVERLAY MENU
# ============================================

func toggle_overlay_menu() -> void:
	if overlay_menu:
		overlay_menu.toggle_visibility()

func is_overlay_active(key: String) -> bool:
	if overlay_menu:
		return overlay_menu.is_overlay_active(key)
	return false

func refresh_los_overlay() -> void:
	if overlay_menu:
		overlay_menu.refresh_los_overlay()

func is_mouse_over_overlay_menu() -> bool:
	if overlay_menu:
		return overlay_menu.is_mouse_over()
	return false

# ============================================
# API DE MECH INSPECTOR
# ============================================

func show_mech_inspector(mech) -> void:
	if mech_inspector:
		mech_inspector.show_inspector(mech)

func hide_mech_inspector() -> void:
	if mech_inspector:
		mech_inspector.hide_inspector()

func is_mech_inspector_visible() -> bool:
	if mech_inspector:
		return mech_inspector.is_inspector_visible()
	return false

func show_paper_doll_dialog(mech) -> void:
	if mech_inspector:
		mech_inspector.show_paper_doll_dialog(mech)

# ============================================
# CALLBACKS INTERNOS
# ============================================

func _on_chat_message_sent(text: String, battle_scene: Node) -> void:
	var sender_name = "Jugador"
	var network_manager = _parent.get_node_or_null("/root/NetworkManager")
	
	if network_manager and network_manager.has_method("get_local_player_name"):
		sender_name = network_manager.get_local_player_name()
	
	# Añadir mensaje local
	add_chat_message(sender_name, text, Color(0.7, 0.9, 1, 1))
	
	# Enviar por red en multiplayer
	if network_manager and network_manager.is_in_match():
		network_manager.send_chat_message(text)

func _on_los_overlay_requested(overlays: Array, battle_scene: Node) -> void:
	if battle_scene and battle_scene.has_method("update_overlays"):
		battle_scene.update_overlays()

func _on_los_overlay_cleared(battle_scene: Node) -> void:
	if battle_scene and battle_scene.has_method("update_overlays"):
		battle_scene.update_overlays()

# ============================================
# ESTILOS (delegación a SteelTitansStyles)
# ============================================

func create_main_panel_style(opacity: float = 0.5) -> StyleBoxFlat:
	return styles.create_main_panel_style(opacity)

func create_info_panel_style() -> StyleBoxFlat:
	return styles.create_info_panel_style()

func create_log_panel_style() -> StyleBoxFlat:
	return styles.create_log_panel_style()

func create_positive_button_style() -> StyleBoxFlat:
	return styles.create_positive_button_style()

func create_negative_button_style() -> StyleBoxFlat:
	return styles.create_negative_button_style()

func create_confirmation_panel_style() -> StyleBoxFlat:
	return styles.create_confirmation_panel_style()
