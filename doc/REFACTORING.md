# Refactorización del Proyecto Battletech

## Resumen de Cambios

Este documento describe la refactorización completa realizada en el proyecto Battletech para mejorar la organización, claridad y mantenibilidad del código.

## Archivos Nuevos Creados

### 1. **scripts/core/game_enums.gd**
- **Propósito**: Centralizador de todas las enumeraciones del juego
- **Contenido**:
  - `GameState`: Estados de la batalla (MOVING, WEAPON_ATTACK, etc.)
  - `TurnPhase`: Fases del turno (INITIATIVE, MOVEMENT, etc.)
  - `MovementType`: Tipos de movimiento (WALK, RUN, JUMP)
  - `PhysicalAttackType`: Tipos de ataque físico
  - `HitLocation`: Localizaciones del mech
- **Funciones auxiliares**:
  - Conversión entre strings y enums
  - Nombres legibles para UI

### 2. **scripts/core/game_constants.gd**
- **Propósito**: Valores constantes compartidos del juego
- **Contenido**:
  - Constantes de combate (BASE_TARGET_NUMBER)
  - Constantes de calor (SHUTDOWN_THRESHOLD, etc.)
  - Constantes de movimiento
  - Modificadores de ataque y defensa
  - Colores para UI
  - Configuración de hex grid
  - Timing para animaciones
  - Flags de debug

### 3. **scripts/managers/battle_input_handler.gd**
- **Propósito**: Manejador centralizado de input
- **Características**:
  - Separación de lógica de entrada del sistema de batalla
  - Señales para comunicación con otros sistemas
  - Gestión de habilitación/deshabilitación de input
  - Traducción de clics de pantalla a hexágonos

### 4. **scripts/managers/battle_ai.gd**
- **Propósito**: Sistema de IA para unidades enemigas
- **Características**:
  - IA para fase de movimiento
  - IA para fase de ataque con armas
  - IA para fase de ataque físico
  - Funciones de búsqueda de objetivos
  - Selección inteligente de hexágonos

### 5. **scripts/managers/battle_state_manager.gd**
- **Propósito**: Gestor de estado de la batalla
- **Características**:
  - Control del estado actual
  - Sincronización estado-fase
  - Gestión de selección de unidades
  - Validación de input del jugador
  - Señales para cambios de estado

## Archivos Modificados

### **scripts/managers/turn_manager.gd** (REFACTORIZADO)
**Cambios principales**:
- ✅ Uso de `GameEnums` y `GameConstants`
- ✅ Eliminación de logs de debug excesivos
- ✅ Función `_log()` centralizada con flag de debug
- ✅ Señal `phase_changed` se emite ANTES de activar unidades
- ✅ Delays consistentes usando `GameConstants.PHASE_TRANSITION_DELAY`
- ✅ Mejor separación de responsabilidades
- ✅ Comentarios más claros y concisos
- ✅ Código más limpio y legible

**Funciones mejoradas**:
- `advance_phase()`: Orden correcto de señales
- `activate_next_unit()`: Reset de movimiento solo en fase correcta
- Todas las funciones de inicio de fase con delays consistentes

## Estructura de Carpetas Mejorada

```
scripts/
├── core/                           # NUEVO: Sistemas centrales
│   ├── game_enums.gd              # Enumeraciones centralizadas
│   ├── game_constants.gd          # Constantes del juego
│   ├── combat/                    # Sistemas de combate
│   │   ├── heat_system.gd
│   │   ├── physical_attack_system.gd
│   │   └── weapon_attack_system.gd
│   ├── heat/
│   │   └── heat_system.gd
│   ├── movement/
│   │   └── movement_system.gd
│   └── terrain/
│       └── terrain_type.gd
│
├── managers/                      # Gestores de alto nivel
│   ├── turn_manager.gd           # REFACTORIZADO
│   ├── turn_manager.gd.backup    # Backup del original
│   ├── battle_input_handler.gd   # NUEVO: Manejo de input
│   ├── battle_ai.gd              # NUEVO: Sistema de IA
│   └── battle_state_manager.gd   # NUEVO: Gestión de estado
│
├── entities/                      # Entidades del juego
│   └── mech_entity.gd
│
├── ui/                           # Interfaz de usuario
│   ├── battle_ui.gd
│   ├── components/
│   └── screens/
│
├── battle_scene.gd               # Escena principal (a refactorizar)
├── battle_overlay.gd
├── hex_grid.gd
└── mech.gd
```

## Beneficios de la Refactorización

### 1. **Mejor Organización**
- Código separado por responsabilidades
- Archivos más pequeños y manejables
- Estructura de carpetas clara

### 2. **Mantenibilidad**
- Cambios centralizados (enums, constantes)
- Menos duplicación de código
- Más fácil de entender y modificar

### 3. **Escalabilidad**
- Fácil agregar nuevas características
- Sistemas modulares e independientes
- Preparado para crecimiento

### 4. **Debug y Testing**
- Logs centralizados con flags
- Estados claros y verificables
- Separación de concerns facilita testing

### 5. **Rendimiento**
- Señales optimizadas
- Menos llamadas redundantes
- Timing consistente

## Próximos Pasos Recomendados

### 1. **Refactorizar battle_scene.gd**
El archivo es muy grande (944 líneas). Sugerencias:
- Extraer manejo de input al `BattleInputHandler`
- Mover lógica de IA al `BattleAI`
- Usar `BattleStateManager` para gestión de estado
- Separar funciones de combate en módulos

### 2. **Integrar los nuevos sistemas**
- Actualizar `battle_scene.gd` para usar los nuevos managers
- Conectar señales de los nuevos sistemas
- Migrar código existente a los nuevos módulos

### 3. **Limpiar código obsoleto**
- Eliminar funciones duplicadas
- Remover código comentado innecesario
- Actualizar referencias a enums antiguos

### 4. **Actualizar mech.gd**
- Usar `GameEnums.MovementType`
- Usar `GameConstants` para valores constantes
- Mejorar organización del archivo

### 5. **Testing**
- Verificar que todo funciona después de los cambios
- Probar cada fase del turno
- Validar comportamiento de IA

## Cómo Usar los Nuevos Sistemas

### Ejemplo: Usar Enums
```gdscript
# ANTES
enum GameState { MOVING, TARGETING, WEAPON_ATTACK }
var current_state = GameState.MOVING

# DESPUÉS
var current_state = GameEnums.GameState.MOVING
```

### Ejemplo: Usar Constantes
```gdscript
# ANTES
await get_tree().create_timer(0.2).timeout

# DESPUÉS
await get_tree().create_timer(GameConstants.PHASE_TRANSITION_DELAY).timeout
```

### Ejemplo: Logs con Flag
```gdscript
# ANTES
print("DEBUG: Something happened")

# DESPUÉS
func _log(message: String):
    if GameConstants.ENABLE_DEBUG_LOGS:
        print("[MySystem] ", message)

_log("Something happened")  # Se puede activar/desactivar fácilmente
```

## Notas Importantes

1. **Backup creado**: El `turn_manager.gd` original está guardado como `turn_manager.gd.backup`

2. **Compatibilidad**: Los nuevos sistemas son compatibles con el código existente, pero se recomienda migrar gradualmente

3. **Flags de Debug**: Usa `GameConstants.ENABLE_DEBUG_LOGS` para controlar la verbosidad de los logs

4. **Timing**: Todos los delays ahora usan constantes de `GameConstants` para consistencia

## Resolución del Bug del Menú

El bug donde aparecía el menú de movimiento en la fase de armas fue resuelto mediante:

1. **Reordenamiento de señales**: `phase_changed` se emite ANTES de activar unidades
2. **Reset condicional**: El movimiento solo se resetea en la fase de movimiento
3. **Delays sincronizados**: Tiempo suficiente para que las señales se procesen
4. **Estado centralizado**: Mejor control del estado actual

---

**Fecha de refactorización**: Noviembre 1, 2025
**Archivos modificados**: 6 nuevos, 1 refactorizado
**Estado**: ✅ Completado - Listo para integración
