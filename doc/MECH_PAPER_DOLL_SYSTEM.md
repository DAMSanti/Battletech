# Sistema de Paper Doll para Mechs - Documentación

## Descripción

El sistema de **Paper Doll** proporciona una visualización en tiempo real del estado de armadura y estructura de un BattleMech durante el combate. Consta de 16 componentes SVG vectoriales que se superponen para crear la silueta completa del mech, con colores que cambian dinámicamente según el daño recibido.

## Componentes

### Archivos SVG (16 en total)

Ubicados en `assets/mech_paperdoll/`:

**Estructura Interna (8 archivos):**
- `head_structure.svg`
- `torso_center_structure.svg`
- `torso_left_structure.svg`
- `torso_right_structure.svg`
- `arm_left_structure.svg`
- `arm_right_structure.svg`
- `leg_left_structure.svg`
- `leg_right_structure.svg`

**Armadura Externa (8 archivos):**
- `head_armor.svg`
- `torso_center_armor.svg`
- `torso_left_armor.svg`
- `torso_right_armor.svg`
- `arm_left_armor.svg`
- `arm_right_armor.svg`
- `leg_left_armor.svg`
- `leg_right_armor.svg`

### Clase Principal

**`MechPaperDoll`** (`scripts/ui/mech_paper_doll.gd`)

Control UI que gestiona la visualización del mech.

## Esquema de Colores

### Armadura (Capa Externa)

| Estado | Color | Descripción |
|--------|-------|-------------|
| **100% - 75%** | Verde brillante `#00FF00` | Armadura intacta |
| **75% - 50%** | Amarillo `#FFFF00` | Daño moderado |
| **50% - 25%** | Naranja `#FF8000` | Daño severo |
| **25% - 0%** | Rojo `#FF0000` | Daño crítico |
| **0%** | Gris transparente | Armadura destruida (invisible) |

### Estructura (Capa Interna)

| Estado | Color | Descripción |
|--------|-------|-------------|
| **100% - 50%** | Gris oscuro `#404040` | Estructura intacta |
| **50% - 25%** | Dorado `#CC9900` | Estructura dañada |
| **25% - 0%** | Rojo anaranjado `#FF3300` | Estructura crítica |
| **0%** | Negro `#101010` | Estructura destruida |

## Uso Básico

### 1. Integración en la UI

El paper doll ya está integrado en `battle_scene.tscn` dentro del panel superior:

```gdscript
# Se carga automáticamente como parte de la UI
var mech_paper_doll: Control  # Referencia automática
```

### 2. Actualización Manual de una Ubicación

```gdscript
# Ejemplo: actualizar el torso central
mech_paper_doll.update_location(
	MechPaperDoll.MechLocation.TORSO_CENTER,
	current_armor,    # Puntos actuales de armadura
	max_armor,        # Puntos máximos de armadura
	current_structure, # Puntos actuales de estructura
	max_structure     # Puntos máximos de estructura
)
```

### 3. Actualización desde un Objeto Mech

La forma más sencilla es actualizar todo el paper doll desde el objeto `Mech`:

```gdscript
# En battle_scene o cualquier script de UI
func update_unit_info(unit):
	if mech_paper_doll and unit:
		mech_paper_doll.update_from_mech(unit)
```

Esto ya está implementado en `battle_scene.tscn` y se actualiza automáticamente cuando:
- Se selecciona una unidad
- Una unidad recibe daño
- Se cambia de unidad activa

## API de MechPaperDoll

### Enums

```gdscript
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
```

### Métodos Principales

#### `update_location(location, current_armor, max_armor, current_structure, max_structure)`

Actualiza una ubicación específica del mech.

**Parámetros:**
- `location` (MechLocation): La ubicación a actualizar
- `current_armor` (int): Puntos de armadura actuales
- `max_armor` (int): Puntos de armadura máximos
- `current_structure` (int): Puntos de estructura actuales
- `max_structure` (int): Puntos de estructura máximos

**Ejemplo:**
```gdscript
mech_paper_doll.update_location(
	MechPaperDoll.MechLocation.ARM_LEFT,
	20, 34,  # Armadura: 20/34
	15, 17   # Estructura: 15/17
)
```

#### `update_from_mech(mech)`

Actualiza todas las ubicaciones desde un objeto Mech.

**Parámetros:**
- `mech` (Mech): Instancia de la clase Mech

**Ejemplo:**
```gdscript
# Actualizar con el mech seleccionado
mech_paper_doll.update_from_mech(selected_unit)
```

#### `flash_location(location, duration = 0.3)`

Aplica un efecto de parpadeo a una ubicación para indicar daño reciente.

**Parámetros:**
- `location` (MechLocation): La ubicación que parpadeará
- `duration` (float): Duración del efecto en segundos

**Ejemplo:**
```gdscript
# Parpadear el brazo derecho al recibir daño
mech_paper_doll.flash_location(MechPaperDoll.MechLocation.ARM_RIGHT, 0.5)
```

#### `reset_all_colors()`

Resetea todos los colores al estado inicial (útil para debugging).

```gdscript
mech_paper_doll.reset_all_colors()
```

## Integración con el Sistema de Daño

Para integrar el paper doll con el sistema de daño existente:

### Opción 1: Actualización en Resolución de Ataque

En `WeaponAttackSystem.resolve_attack()` o similar:

```gdscript
func apply_damage_to_location(mech: Mech, location: String, damage: int):
	# ... código existente de aplicación de daño ...
	
	# Actualizar paper doll si existe
	if battle_scene.ui and battle_scene.ui.mech_paper_doll:
		if mech == battle_scene.selected_unit:
			battle_scene.ui.mech_paper_doll.update_from_mech(mech)
			
			# Efecto de parpadeo para mostrar la ubicación dañada
			var loc_enum = _get_location_enum(location)
			if loc_enum != -1:
				battle_scene.ui.mech_paper_doll.flash_location(loc_enum)
```

### Opción 2: Señales del Mech

Añadir señales al objeto Mech:

```gdscript
# En Mech.gd
signal armor_damaged(location: String, damage: int)
signal structure_damaged(location: String, damage: int)

# Al aplicar daño
func take_damage(location: String, damage: int):
	# ... aplicar daño ...
	armor_damaged.emit(location, damage)
```

Conectar en la UI:

```gdscript
# En battle_scene
selected_unit.armor_damaged.connect(_on_mech_armor_damaged)

func _on_mech_armor_damaged(location: String, damage: int):
	ui.mech_paper_doll.update_from_mech(selected_unit)
	ui.mech_paper_doll.flash_location(_get_location_enum(location))
```

## Ejemplo Completo de Integración

```gdscript
# En tu script de batalla cuando aplicas daño
func _apply_weapon_damage(target: Mech, location: String, damage: int):
	print("Aplicando %d de daño a %s" % [damage, location])
	
	# Aplicar daño al mech
	var armor_remaining = target.armor[location]["current"]
	var damage_to_armor = min(damage, armor_remaining)
	var damage_to_structure = damage - damage_to_armor
	
	target.armor[location]["current"] -= damage_to_armor
	
	if damage_to_structure > 0:
		target.structure[location]["current"] -= damage_to_structure
		target.check_destruction(location)
	
	# Actualizar UI si es el mech del jugador
	if target == selected_unit and ui.mech_paper_doll:
		# Actualizar todos los valores
		ui.mech_paper_doll.update_from_mech(target)
		
		# Efecto visual en la ubicación dañada
		var location_map = {
			"head": MechPaperDoll.MechLocation.HEAD,
			"center_torso": MechPaperDoll.MechLocation.TORSO_CENTER,
			"left_torso": MechPaperDoll.MechLocation.TORSO_LEFT,
			"right_torso": MechPaperDoll.MechLocation.TORSO_RIGHT,
			"left_arm": MechPaperDoll.MechLocation.ARM_LEFT,
			"right_arm": MechPaperDoll.MechLocation.ARM_RIGHT,
			"left_leg": MechPaperDoll.MechLocation.LEG_LEFT,
			"right_leg": MechPaperDoll.MechLocation.LEG_RIGHT
		}
		
		if location_map.has(location):
			ui.mech_paper_doll.flash_location(location_map[location], 0.4)
```

## Personalización

### Modificar Colores

Los colores están definidos como constantes en `mech_paper_doll.gd`:

```gdscript
# Personalizar colores de armadura
const COLOR_ARMOR_FULL = Color(0.0, 1.0, 0.0, 0.9)      # Verde
const COLOR_ARMOR_MODERATE = Color(1.0, 1.0, 0.0, 0.9)  # Amarillo
const COLOR_ARMOR_HEAVY = Color(1.0, 0.5, 0.0, 0.9)     # Naranja
const COLOR_ARMOR_CRITICAL = Color(1.0, 0.0, 0.0, 0.9)  # Rojo
```

### Modificar Umbrales de Daño

Los umbrales determinan cuándo cambian los colores:

```gdscript
# Cambiar umbrales (valores entre 0.0 y 1.0)
const THRESHOLD_MODERATE = 0.75  # 75% o menos = amarillo
const THRESHOLD_HEAVY = 0.50     # 50% o menos = naranja
const THRESHOLD_CRITICAL = 0.25  # 25% o menos = rojo
```

### Modificar SVGs

Los archivos SVG son editables en cualquier editor vectorial (Inkscape, Adobe Illustrator, etc.). 

**Puntos clave:**
- Mantener el viewBox `0 0 100 120` para consistencia
- El color base en el SVG será modulado por el script
- Asegurar que las partes se superpongan correctamente

## Resolución de Problemas

### El paper doll no aparece

```gdscript
# Verificar que la escena se carga correctamente
if mech_paper_doll:
	print("Paper doll cargado correctamente")
else:
	print("ERROR: Paper doll no encontrado")
```

### Los colores no cambian

```gdscript
# Verificar que get_all_locations_status() retorna datos válidos
var status = mech.get_all_locations_status()
print("Estado del mech: ", status)
```

### Las imágenes SVG no se cargan

Asegúrate de que los archivos `.import` de Godot están correctamente generados. Puedes forzar la reimportación:

1. Selecciona los archivos SVG en el FileSystem
2. Click derecho → Reimport
3. Asegúrate de que "SVG" está seleccionado como tipo

## Mejoras Futuras

- Animaciones de transición entre estados de daño
- Efectos de partículas al recibir daño crítico
- Indicadores visuales de críticos (equipamiento destruido)
- Variantes de paper doll para diferentes chassis de mechs
- Modo de vista trasera para armadura posterior
- Tooltips al pasar el mouse sobre cada sección
