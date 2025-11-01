# Guía de Migración - Refactorización Battletech

## Introducción

Este documento te guiará paso a paso para integrar los nuevos sistemas refactorizados en tu proyecto Battletech sin romper la funcionalidad existente.

## Orden de Migración (Recomendado)

### Fase 1: Preparación ✅ COMPLETADO
- [x] Crear archivos de enums y constantes
- [x] Crear nuevos managers
- [x] Refactorizar turn_manager
- [x] Crear backups

### Fase 2: Integración de Enums (SIGUIENTE PASO)

#### 2.1. Actualizar mech.gd para usar GameEnums

**Cambios necesarios**:

```gdscript
# EN LA PARTE SUPERIOR DEL ARCHIVO, DESPUÉS DE class_name Mech
# ELIMINAR:
enum MovementType { NONE, WALK, RUN, JUMP }

# CAMBIAR:
var movement_type_used: MovementType = MovementType.NONE

# POR:
var movement_type_used: GameEnums.MovementType = GameEnums.MovementType.NONE

# EN TODAS LAS FUNCIONES QUE USEN MovementType, CAMBIAR:
func start_movement(movement_type: MovementType):
# POR:
func start_movement(movement_type: GameEnums.MovementType):

# Y en los match statements:
match movement_type:
    MovementType.WALK:  # CAMBIAR POR: GameEnums.MovementType.WALK
    MovementType.RUN:   # CAMBIAR POR: GameEnums.MovementType.RUN
    MovementType.JUMP:  # CAMBIAR POR: GameEnums.MovementType.JUMP
```

#### 2.2. Actualizar battle_scene.gd para usar GameEnums

**Cambios necesarios**:

```gdscript
# ELIMINAR LA DECLARACIÓN DE enum GameState
enum GameState {
    MOVING,
    TARGETING,
    WEAPON_ATTACK,
    PHYSICAL_TARGETING,
    ENEMY_TURN,
    ANIMATION
}

# CAMBIAR:
var current_state: GameState = GameState.MOVING

# POR:
var current_state: GameEnums.GameState = GameEnums.GameState.MOVING

# ACTUALIZAR TODAS LAS REFERENCIAS:
# GameState.MOVING -> GameEnums.GameState.MOVING
# GameState.WEAPON_ATTACK -> GameEnums.GameState.WEAPON_ATTACK
# etc.
```

### Fase 3: Integración de BattleStateManager

#### 3.1. Agregar el manager a battle_scene.gd

```gdscript
# Agregar variable al inicio
var state_manager: BattleStateManager

# En _ready(), después de crear otros managers:
state_manager = BattleStateManager.new()
add_child(state_manager)
state_manager.state_changed.connect(_on_state_changed)

# Crear función de callback:
func _on_state_changed(new_state: GameEnums.GameState):
    current_state = new_state
    update_overlays()
```

#### 3.2. Usar el state_manager en funciones clave

```gdscript
# EN _on_phase_changed, REEMPLAZAR LA LÓGICA MANUAL:
func _on_phase_changed(phase: String):
    state_manager.update_state_for_phase(phase)
    # ... resto del código

# EN _on_unit_activated:
func _on_unit_activated(unit):
    state_manager.set_selected_unit(unit)
    # ... resto del código

# AL INICIO DE select_movement_type:
func select_movement_type(movement_type: int):
    state_manager.end_movement_selection()
    # ... resto del código
```

### Fase 4: Integración de BattleAI

#### 4.1. Agregar el sistema de IA

```gdscript
# Agregar variable
var battle_ai: BattleAI

# En _ready(), después de otros setups:
battle_ai = BattleAI.new()
add_child(battle_ai)
battle_ai.setup(hex_grid, player_mechs, self)

# Actualizar _ai_turn para delegar al BattleAI:
func _ai_turn(unit):
    var current_phase = turn_manager.current_phase
    await battle_ai.execute_ai_turn(unit, current_phase)
```

#### 4.2. Simplificar funciones de IA

Una vez integrado BattleAI, puedes eliminar las funciones `_ai_turn()` antiguas y delegar todo al nuevo sistema.

### Fase 5: Integración de BattleInputHandler

#### 5.1. Agregar el handler

```gdscript
# Agregar variable
var input_handler: BattleInputHandler

# En _ready():
input_handler = BattleInputHandler.new()
add_child(input_handler)
input_handler.setup(hex_grid)

# Conectar señales
input_handler.hex_clicked.connect(_on_hex_clicked)
input_handler.movement_type_selected.connect(_on_movement_type_selected)
input_handler.end_turn_requested.connect(_on_end_turn_requested)

# Mover lógica de _input a estas funciones callback
```

#### 5.2. Actualizar _input()

```gdscript
func _input(event):
    if not battle_started or not input_handler:
        return
    
    # Delegar al handler
    input_handler.handle_input_event(event)
```

### Fase 6: Uso de GameConstants

#### 6.1. Reemplazar valores hardcoded

Busca y reemplaza:

```gdscript
# ANTES:
await get_tree().create_timer(0.2).timeout
await get_tree().create_timer(0.5).timeout
await get_tree().create_timer(2.0).timeout

# DESPUÉS:
await get_tree().create_timer(GameConstants.PHASE_TRANSITION_DELAY).timeout
await get_tree().create_timer(GameConstants.AI_THINK_DELAY).timeout
await get_tree().create_timer(GameConstants.HEAT_DISPLAY_DELAY).timeout
```

```gdscript
# ANTES:
var color = Color.GREEN if pilot_name == "Player" else Color.RED

# DESPUÉS:
var color = GameConstants.COLOR_PLAYER if pilot_name == "Player" else GameConstants.COLOR_ENEMY
```

### Fase 7: Limpieza de Logs

#### 7.1. Centralizar logs con flag

En cada archivo, reemplaza:

```gdscript
# ANTES:
print("DEBUG: Something happened")
print("Unit activated: ", unit.mech_name)

# DESPUÉS:
func _log(message: String):
    if GameConstants.ENABLE_DEBUG_LOGS:
        print("[ClassName] ", message)

_log("Something happened")
_log("Unit activated: %s" % unit.mech_name)
```

#### 7.2. Eliminar logs excesivos

Los logs con bloques de `═══` pueden simplificarse:

```gdscript
# ANTES:
print("═══════════════════════════════════════════════════")
print("DEBUG: _on_phase_changed CALLED")
print("  Phase name: ", phase)
print("═══════════════════════════════════════════════════")

# DESPUÉS:
_log("Phase changed to: %s" % phase)
```

## Script de Migración Automática

Puedes usar este script para ayudar con algunos cambios:

```gdscript
# migration_helper.gd
extends Node

func migrate_enums_in_file(file_path: String):
    var file = FileAccess.open(file_path, FileAccess.READ)
    var content = file.get_as_text()
    file.close()
    
    # Reemplazos comunes
    content = content.replace("GameState.", "GameEnums.GameState.")
    content = content.replace("MovementType.", "GameEnums.MovementType.")
    content = content.replace("Phase.", "GameEnums.TurnPhase.")
    
    # Guardar cambios
    file = FileAccess.open(file_path, FileAccess.WRITE)
    file.store_string(content)
    file.close()
    
    print("Migrated: ", file_path)
```

## Validación Post-Migración

Después de cada fase, verifica:

1. ✅ No hay errores de compilación
2. ✅ El juego inicia correctamente
3. ✅ La fase de movimiento funciona
4. ✅ La fase de armas funciona
5. ✅ La fase física funciona
6. ✅ La IA se comporta correctamente
7. ✅ Los logs aparecen correctamente

## Testing Checklist

- [ ] Iniciar batalla → Pantalla de iniciativa aparece
- [ ] Fase de movimiento → Menú de movimiento aparece SOLO aquí
- [ ] Fase de armas → Selector de armas funciona
- [ ] Fase física → Selector de ataques físicos funciona
- [ ] Fase de calor → Calor se disipa correctamente
- [ ] IA enemiga → Se mueve y ataca
- [ ] Victoria/Derrota → Se detecta correctamente

## Rollback (Si algo sale mal)

Si necesitas revertir cambios:

```powershell
# Restaurar turn_manager original
Copy-Item "g:\Battletech\scripts\managers\turn_manager.gd.backup" "g:\Battletech\scripts\managers\turn_manager.gd" -Force

# Eliminar archivos nuevos si causan problemas
Remove-Item "g:\Battletech\scripts\core\game_enums.gd"
Remove-Item "g:\Battletech\scripts\core\game_constants.gd"
Remove-Item "g:\Battletech\scripts\managers\battle_ai.gd"
Remove-Item "g:\Battletech\scripts\managers\battle_state_manager.gd"
Remove-Item "g:\Battletech\scripts\managers\battle_input_handler.gd"
```

## Soporte y Problemas

Si encuentras problemas durante la migración:

1. Verifica que todos los archivos nuevos se hayan creado correctamente
2. Revisa los errores de compilación de Godot
3. Consulta el archivo `REFACTORING.md` para detalles
4. Usa los backups para revertir si es necesario

---

**Nota**: Esta migración puede hacerse de forma gradual. No es necesario completar todas las fases de una vez.

**Prioridad Alta**: Fases 1-3 (ya completadas la 1 y 2)
**Prioridad Media**: Fases 4-5
**Prioridad Baja**: Fases 6-7 (mejoras cosméticas)
