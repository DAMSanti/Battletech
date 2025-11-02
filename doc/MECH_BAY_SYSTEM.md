# MECH BAY SYSTEM

## Overview
El sistema de Mech Bay permite a los jugadores seleccionar y configurar sus mechs antes de entrar en batalla. Incluye gestión de hangar, selección de variantes y formación de lance.

## Componentes

### 1. MechBayManager (`scripts/managers/mech_bay_manager.gd`)
**Propósito**: Gestión centralizada del inventario de mechs y biblioteca de configuraciones.

**Características**:
- Base de datos de mechs con múltiples variantes
- Gestión del hangar del jugador
- Sistema de variantes por cada tipo de mech
- Generación de información resumida de mechs

**Mechs Disponibles**:
- **Atlas** (100 tons): Asalto pesado
  - AS7-D: Configuración estándar con AC/20 y LRMs
  - AS7-K: Variante de energía con Gauss Rifle y ER Large Lasers

- **Mad Cat / Timber Wolf** (75 tons): Asalto medio
  - Prime: Configuración OmniMech estándar con ER Large Lasers y LRM 20s
  - A: Variante con PPCs y Ultra AC/5s

- **Hunchback** (50 tons): Mech medio
  - HBK-4G: Hunchback clásico con AC/20
  - HBK-4P: Variante de energía con múltiples láseres

- **Locust** (20 tons): Scout ligero
  - LCT-1V: Configuración estándar para reconocimiento

### 2. MechBayScreen (`scripts/ui/screens/mech_bay_screen.gd`)
**Propósito**: Interfaz de usuario para la selección de mechs.

**Secciones de UI**:

#### Panel Izquierdo - Hangar Disponible
- Lista de todos los mechs en el hangar del jugador
- Click en un mech para ver sus detalles
- Scroll para ver todos los mechs disponibles

#### Panel Central - Detalles del Mech
- Especificaciones completas del mech seleccionado
- Selector de variantes (dropdown)
- Lista detallada de armas con tipo, daño y calor
- Botón "ADD TO LANCE" para añadir a la selección

#### Panel Derecho - Lance Seleccionado
- Muestra los mechs seleccionados para batalla (máx. 4)
- Botón "X" en cada mech para removerlo
- Contador "YOUR LANCE (X/4)"
- Botón "START BATTLE" (solo activo con al menos 1 mech)
- Botón "BACK TO MENU"

### 3. Integración con Battle Scene
El sistema está diseñado para integrarse con `battle_scene.gd` mediante la señal `mech_bay_closed`:

```gdscript
# En battle_scene.gd o main_menu.gd
mech_bay_screen.mech_bay_closed.connect(_on_mech_bay_closed)

func _on_mech_bay_closed(selected_mechs: Array):
    if selected_mechs.size() > 0:
        # Iniciar batalla con los mechs seleccionados
        start_battle_with_mechs(selected_mechs)
```

## Flujo de Usuario

1. Usuario hace click en "Mech Bay" desde el menú principal
2. Se carga `mech_bay_screen.tscn`
3. Se muestra la lista de mechs disponibles del hangar
4. Usuario selecciona un mech para ver detalles
5. Usuario puede cambiar de variante usando el dropdown
6. Usuario añade mechs a su lance (máx. 4)
7. Usuario puede remover mechs de la selección
8. Usuario presiona "START BATTLE" para continuar
9. Se emite señal con array de mechs seleccionados
10. Se carga la escena de batalla con los mechs configurados

## Datos de Mech

Cada mech contiene:
```gdscript
{
    "name": "Atlas AS7-D",
    "mech_type": "Atlas",
    "variant": "AS7-D",
    "tonnage": 100,
    "walk_mp": 3,
    "run_mp": 5,
    "jump_mp": 0,
    "armor": {
        "head": {"current": 9, "max": 9},
        "center_torso": {"current": 47, "max": 47},
        # ... otros locations
    },
    "weapons": [
        {
            "name": "AC/20",
            "damage": 20,
            "heat": 7,
            "min_range": 0,
            "short_range": 3,
            "medium_range": 6,
            "long_range": 9,
            "type": "ballistic"
        },
        # ... más armas
    ],
    "heat_capacity": 30,
    "gunnery_skill": 4
}
```

## Funciones Principales del Manager

### `add_mech_to_hangar(mech_type: String, variant: String)`
Añade un mech específico al hangar del jugador.

### `get_mech_data(mech_type: String, variant: String) -> Dictionary`
Obtiene una copia de los datos completos de un mech/variante.

### `get_player_hangar() -> Array`
Devuelve array con todos los mechs en el hangar.

### `get_variants_for_mech(mech_type: String) -> Array`
Lista todas las variantes disponibles para un tipo de mech.

### `get_mech_info_summary(mech_data: Dictionary) -> String`
Genera resumen formateado de un mech.

## Expansión Futura

### Añadir Nuevos Mechs
1. Agregar entrada en `mech_library` en `mech_bay_manager.gd`
2. Definir todas las variantes con stats completos
3. Opcionalmente añadir al hangar inicial en `_initialize_default_hangar()`

### Personalización de Loadouts
Para implementar personalización de armas:
1. Añadir sistema de slots de equipamiento
2. Implementar límites de tonelaje por slot
3. Crear UI de editor de loadout
4. Guardar configuraciones personalizadas

### Sistema de Persistencia
Para guardar el hangar entre sesiones:
1. Implementar serialización de `player_hangar`
2. Guardar en archivo de save (JSON o Resource)
3. Cargar al iniciar el juego

### Battle Value (BV) Balancing
Para multiplayer equilibrado:
1. Añadir campo `battle_value` a cada variante
2. Mostrar BV total del lance seleccionado
3. Implementar límite de BV para matchmaking

## Uso en Código

### Ejemplo: Obtener un mech específico
```gdscript
var mech_manager = get_node("/root/MechBayManager")
var atlas_data = mech_manager.get_mech_data("Atlas", "AS7-D")
```

### Ejemplo: Listar todos los mechs del hangar
```gdscript
var mech_manager = get_node("/root/MechBayManager")
var hangar = mech_manager.get_player_hangar()
for mech in hangar:
    print(mech["name"])
```

### Ejemplo: Añadir mech al hangar
```gdscript
var mech_manager = get_node("/root/MechBayManager")
mech_manager.add_mech_to_hangar("Hunchback", "HBK-4G")
```

## Notas de Implementación

- **Autoload**: `MechBayManager` se registra como singleton en `project.godot`
- **Escalabilidad**: Sistema diseñado para soportar 4+ mechs por equipo
- **UI Responsiva**: Todos los elementos escalan según resolución de pantalla
- **Datos Inmutables**: Los mechs en la biblioteca son inmutables; se duplican al añadir al hangar
- **Compatibilidad BattleTech**: Todos los stats siguen reglas de Total Warfare

## Testing

Para testear el sistema:
1. Ejecutar el juego desde `main_menu.tscn`
2. Click en "Mech Bay"
3. Verificar que aparecen 7 mechs en el hangar
4. Seleccionar diferentes mechs y verificar detalles
5. Cambiar variantes y verificar cambios en stats/armas
6. Añadir mechs al lance (máx. 4)
7. Remover mechs del lance
8. Verificar que "START BATTLE" solo se activa con mechs seleccionados
