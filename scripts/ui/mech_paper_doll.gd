extends Control
class_name MechPaperDoll

## Sistema de visualización de Paper Doll para BattleMechs
## Muestra el estado de armadura y estructura en 8 ubicaciones del mech
## Cambia dinámicamente los colores basándose en el daño recibido

# Referencias a las texturas SVG (estructura interna)
@onready var head_structure: TextureRect = $Container/Head/Structure
@onready var torso_center_structure: TextureRect = $Container/TorsoCenter/Structure
@onready var torso_left_structure: TextureRect = $Container/TorsoLeft/Structure
@onready var torso_right_structure: TextureRect = $Container/TorsoRight/Structure
@onready var arm_left_structure: TextureRect = $Container/ArmLeft/Structure
@onready var arm_right_structure: TextureRect = $Container/ArmRight/Structure
@onready var leg_left_structure: TextureRect = $Container/LegLeft/Structure
@onready var leg_right_structure: TextureRect = $Container/LegRight/Structure

# Referencias a las texturas SVG (armadura externa)
@onready var head_armor: TextureRect = $Container/Head/Armor
@onready var torso_center_armor: TextureRect = $Container/TorsoCenter/Armor
@onready var torso_left_armor: TextureRect = $Container/TorsoLeft/Armor
@onready var torso_right_armor: TextureRect = $Container/TorsoRight/Armor
@onready var arm_left_armor: TextureRect = $Container/ArmLeft/Armor
@onready var arm_right_armor: TextureRect = $Container/ArmRight/Armor
@onready var leg_left_armor: TextureRect = $Container/LegLeft/Armor
@onready var leg_right_armor: TextureRect = $Container/LegRight/Armor

# Colores para diferentes estados de daño
# Make armor more translucent so inner structure details remain visible under the plating
const COLOR_ARMOR_FULL = Color(0.0, 1.0, 0.0, 0.45)      # Verde brillante (más translúcido)
const COLOR_ARMOR_MODERATE = Color(1.0, 1.0, 0.0, 0.45)  # Amarillo (más translúcido)
const COLOR_ARMOR_HEAVY = Color(1.0, 0.5, 0.0, 0.5)     # Naranja
const COLOR_ARMOR_CRITICAL = Color(1.0, 0.0, 0.0, 0.55) # Rojo
const COLOR_ARMOR_DESTROYED = Color(1.0, 1.0, 1.0, 0.0) # Completamente transparente

# Use brighter / fully opaque structure colors so details remain readable under the armor
const COLOR_STRUCTURE_INTACT = Color(0.85, 0.85, 0.85, 1.0)     # Gris claro, más visible
const COLOR_STRUCTURE_DAMAGED = Color(1.0, 0.85, 0.4, 1.0)    # Dorado claro
const COLOR_STRUCTURE_CRITICAL = Color(1.0, 0.5, 0.2, 1.0)   # Rojo anaranjado
const COLOR_STRUCTURE_DESTROYED = Color(0.15, 0.15, 0.15, 0.9)  # Oscuro pero visible

# For improved blending behavior (avoid fully blocking structure) we'll assign
# a lightweight CanvasItemMaterial to armor nodes in _ready().
@onready var _armor_material: CanvasItemMaterial = null

# Umbrales de daño (porcentajes)
const THRESHOLD_MODERATE = 0.75
const THRESHOLD_HEAVY = 0.50
const THRESHOLD_CRITICAL = 0.25

# Enum para las ubicaciones del mech
enum MechLocation {
	HEAD,
	TORSO_CENTER,
	TORSO_LEFT,
	TORSO_RIGHT,
	ARM_LEFT,
	ARM_RIGHT,
	LEG_LEFT,
	LEG_RIGHT
}


## Actualiza el estado visual de una ubicación específica del mech
## @param location: La ubicación del mech (enum MechLocation)
## @param current_armor: Puntos de armadura actuales
## @param max_armor: Puntos de armadura máximos
## @param current_structure: Puntos de estructura actuales
## @param max_structure: Puntos de estructura máximos
func update_location(location: MechLocation, current_armor: int, max_armor: int, 
					current_structure: int, max_structure: int) -> void:
	var armor_node = _get_armor_node(location)
	var structure_node = _get_structure_node(location)
	
	if not armor_node or not structure_node:
		push_error("No se encontraron los nodos para la ubicación: " + str(location))
		return
	
	# Calcular porcentajes
	var armor_percent = 0.0 if max_armor == 0 else float(current_armor) / float(max_armor)
	var structure_percent = 0.0 if max_structure == 0 else float(current_structure) / float(max_structure)
	
	# Actualizar color de estructura (siempre visible)
	structure_node.modulate = _get_structure_color(structure_percent)
	structure_node.visible = true
	
	# Actualizar color de armadura (con transparencia para que se vea la estructura debajo)
	if current_armor > 0:
		# Apply the material if available (ensures better blending behaviour across platforms)
		if _armor_material:
			armor_node.material = _armor_material
		armor_node.modulate = _get_armor_color(armor_percent)
		armor_node.visible = true
	else:
		# Si no hay armadura, hacerla completamente transparente
		armor_node.modulate = Color(1.0, 1.0, 1.0, 0.0)
		armor_node.visible = false


## Actualiza todo el mech desde un objeto Mech completo
## @param mech: Instancia de la clase Mech
func update_from_mech(mech) -> void:
	if not mech:
		push_error("Mech es null")
		return
	
	# Obtener estado de todas las ubicaciones
	var locations = mech.get_all_locations_status()
	
	# Actualizar cada ubicación
	for loc_name in locations.keys():
		var data = locations[loc_name]
		var location_enum = _location_name_to_enum(loc_name)
		
		if location_enum != -1:
			update_location(
				location_enum,
				data.armor,
				data.max_armor,
				data.structure,
				data.max_structure
			)


## Obtiene el nodo de armadura para una ubicación específica
func _get_armor_node(location: MechLocation) -> TextureRect:
	match location:
		MechLocation.HEAD: return head_armor
		MechLocation.TORSO_CENTER: return torso_center_armor
		MechLocation.TORSO_LEFT: return torso_left_armor
		MechLocation.TORSO_RIGHT: return torso_right_armor
		MechLocation.ARM_LEFT: return arm_left_armor
		MechLocation.ARM_RIGHT: return arm_right_armor
		MechLocation.LEG_LEFT: return leg_left_armor
		MechLocation.LEG_RIGHT: return leg_right_armor
	return null


## Obtiene el nodo de estructura para una ubicación específica
func _get_structure_node(location: MechLocation) -> TextureRect:
	match location:
		MechLocation.HEAD: return head_structure
		MechLocation.TORSO_CENTER: return torso_center_structure
		MechLocation.TORSO_LEFT: return torso_left_structure
		MechLocation.TORSO_RIGHT: return torso_right_structure
		MechLocation.ARM_LEFT: return arm_left_structure
		MechLocation.ARM_RIGHT: return arm_right_structure
		MechLocation.LEG_LEFT: return leg_left_structure
		MechLocation.LEG_RIGHT: return leg_right_structure
	return null


## Calcula el color apropiado para la armadura basándose en el porcentaje
func _get_armor_color(percent: float) -> Color:
	if percent <= 0.0:
		return COLOR_ARMOR_DESTROYED
	elif percent <= THRESHOLD_CRITICAL:
		return COLOR_ARMOR_CRITICAL
	elif percent <= THRESHOLD_HEAVY:
		return COLOR_ARMOR_HEAVY
	elif percent <= THRESHOLD_MODERATE:
		return COLOR_ARMOR_MODERATE
	else:
		return COLOR_ARMOR_FULL


## Calcula el color apropiado para la estructura basándose en el porcentaje
func _get_structure_color(percent: float) -> Color:
	if percent <= 0.0:
		return COLOR_STRUCTURE_DESTROYED
	elif percent <= THRESHOLD_CRITICAL:
		return COLOR_STRUCTURE_CRITICAL
	elif percent <= THRESHOLD_HEAVY:
		return COLOR_STRUCTURE_DAMAGED
	else:
		return COLOR_STRUCTURE_INTACT


## Convierte un nombre de ubicación a su enum correspondiente
func _location_name_to_enum(loc_name: String) -> int:
	match loc_name.to_upper():
		"HEAD": return MechLocation.HEAD
		"CENTER_TORSO", "TORSO_CENTER": return MechLocation.TORSO_CENTER
		"LEFT_TORSO", "TORSO_LEFT": return MechLocation.TORSO_LEFT
		"RIGHT_TORSO", "TORSO_RIGHT": return MechLocation.TORSO_RIGHT
		"LEFT_ARM", "ARM_LEFT": return MechLocation.ARM_LEFT
		"RIGHT_ARM", "ARM_RIGHT": return MechLocation.ARM_RIGHT
		"LEFT_LEG", "LEG_LEFT": return MechLocation.LEG_LEFT
		"RIGHT_LEG", "LEG_RIGHT": return MechLocation.LEG_RIGHT
	return -1


func _ready() -> void:
	# Create a lightweight CanvasItemMaterial for armor overlays so they blend
	# nicely with structure assets underneath. Using MIX keeps the alpha working
	# while ensuring underlying lines/details are visible.
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_armor_material = mat

	# Apply to all armor nodes that exist already in the scene
	for armor_node in [head_armor, torso_center_armor, torso_left_armor, torso_right_armor,
					   arm_left_armor, arm_right_armor, leg_left_armor, leg_right_armor]:
		if armor_node:
			armor_node.material = _armor_material


## Aplica un efecto de parpadeo a una ubicación (útil para mostrar daño reciente)
## @param location: La ubicación a parpadear
## @param duration: Duración del parpadeo en segundos
func flash_location(location: MechLocation, duration: float = 0.3) -> void:
	var armor_node = _get_armor_node(location)
	if armor_node:
		var tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(armor_node, "modulate:a", 0.3, duration / 6)
		tween.tween_property(armor_node, "modulate:a", 1.0, duration / 6)


## Resetea todos los colores al estado inicial (útil para debugging)
func reset_all_colors() -> void:
	for location in MechLocation.values():
		var armor_node = _get_armor_node(location)
		var structure_node = _get_structure_node(location)
		
		if armor_node:
			if _armor_material:
				armor_node.material = _armor_material
			armor_node.modulate = COLOR_ARMOR_FULL
			armor_node.visible = true
		
		if structure_node:
			structure_node.modulate = COLOR_STRUCTURE_INTACT
