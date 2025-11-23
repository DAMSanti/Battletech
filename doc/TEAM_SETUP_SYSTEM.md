# Sistema de Configuración de Equipo (Team Setup)

## Descripción General

Se ha implementado un nuevo sistema de configuración de equipo que se activa al seleccionar "New Game" desde el menú principal. Este sistema permite al jugador personalizar su lance (equipo de hasta 4 mechs) antes de entrar en batalla.

## Características

### 1. Pantalla de Configuración de Lance
- **Ubicación**: `scenes/team_setup.tscn`
- **Script**: `scripts/ui/screens/team_setup.gd`
- Se accede desde el menú principal al seleccionar "New Game"

### 2. Funcionalidades

#### Selección de Mechs del Hangar
- La pantalla muestra todos los mechs disponibles en el hangar del jugador
- Cada mech muestra su nombre y tonelaje
- Al seleccionar un mech, se añade al primer slot disponible de la lance
- Los mechs ya seleccionados aparecen marcados y deshabilitados

#### Slots de Lance (4 posiciones)
Cada slot muestra:
- Nombre del mech asignado
- Tonelaje
- Capacidad de movimiento (Walk/Run/Jump)
- Armadura total
- Número de armas
- Botón para limpiar el slot

#### Opciones de Configuración

**Fill with Random Mechs**
- Rellena los slots vacíos con mechs aleatorios
- Primero intenta usar mechs del hangar que no estén ya seleccionados
- Si no hay suficientes mechs en el hangar, genera mechs aleatorios de la biblioteca

**Clear All**
- Limpia todos los slots de la lance
- Permite empezar la configuración desde cero

**Back to Menu**
- Vuelve al menú principal sin iniciar batalla
- No guarda la configuración

**Start Battle**
- Inicia la batalla con la configuración actual
- Requiere al menos 1 mech asignado
- Guarda la configuración de la lance en el MechBayManager

## Integración con el Sistema Existente

### MechBayManager
Se han añadido tres nuevos métodos al `MechBayManager`:

```gdscript
# Establece la configuración de lance para batalla
func set_battle_lance(lance_data: Array)

# Limpia la configuración de lance guardada
func clear_battle_lance()

# Modificado para usar la lance configurada si existe
func get_player_lance() -> Array
```

### Flujo del Juego

1. **Menú Principal** → "New Game" → **Team Setup**
2. **Team Setup** → Configurar lance → "Start Battle" → **Battle Scene**
3. La batalla usa la lance configurada automáticamente

## Mechs Aleatorios

Cuando se generan mechs aleatorios:
- Se selecciona un tipo de mech al azar de la biblioteca
- Se selecciona una variante al azar de ese tipo
- El mech generado se marca con un índice especial (-2)
- Los mechs generados se almacenan temporalmente en metadata

## Notas Técnicas

### Almacenamiento de la Configuración
- La configuración de la lance se guarda en el `MechBayManager` usando metadata
- Esto permite que la batalla acceda a la configuración sin necesidad de paso de parámetros
- La configuración persiste hasta que se limpie explícitamente o se configure una nueva lance

### Validación
- Se requiere al menos 1 mech para iniciar batalla
- Los slots pueden estar vacíos (máximo 4 mechs)
- No se pueden seleccionar mechs duplicados del hangar en la misma lance

## Archivos Modificados/Creados

### Nuevos
- `scenes/team_setup.tscn` - Escena de configuración de equipo
- `scripts/ui/screens/team_setup.gd` - Lógica de la pantalla
- `scripts/ui/screens/team_setup.gd.uid` - UID del script
- `doc/TEAM_SETUP_SYSTEM.md` - Esta documentación

### Modificados
- `scripts/ui/screens/main_menu.gd` - Cambiado "New Battle" → "New Game" y redirige a team_setup
- `scripts/managers/mech_bay_manager.gd` - Añadidos métodos para gestión de lance de batalla

## Posibles Mejoras Futuras

1. **Persistencia**: Guardar la última configuración de lance usada
2. **Presets**: Permitir guardar y cargar configuraciones predefinidas
3. **Validación de BV**: Limitar el valor de batalla total de la lance
4. **Vista previa**: Mostrar sprite o modelo 3D del mech en los slots
5. **Drag & Drop**: Permitir arrastrar mechs a los slots
6. **Reordenamiento**: Permitir reorganizar el orden de los mechs en los slots
7. **Estadísticas**: Mostrar estadísticas totales de la lance (tonelaje total, firepower, etc.)
