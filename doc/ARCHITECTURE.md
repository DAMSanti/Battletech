# BATTLETECH GODOT - ARQUITECTURA SOLID

## Estructura del Proyecto (Actualizada - Nov 2025)

```
scripts/
├── core/                   # Lógica de negocio central (Single Responsibility)
│   ├── game_enums.gd                 # ✨ NUEVO: Enumeraciones centralizadas
│   ├── game_constants.gd             # ✨ NUEVO: Constantes del juego
│   ├── combat/
│   │   ├── weapon_system.gd          # Sistema de armas y combate a distancia
│   │   ├── weapon_attack_system.gd   # Sistema de ataque con armas
│   │   └── physical_attack_system.gd # Sistema de ataques cuerpo a cuerpo
│   ├── movement/
│   │   └── movement_system.gd        # Sistema de movimiento hexagonal
│   ├── heat/
│   │   └── heat_system.gd            # Sistema de gestión de calor
│   └── terrain/
│       └── terrain_type.gd           # Sistema de tipos de terreno
│
├── entities/               # Entidades del juego (Data + Behavior)
│   └── mech_entity.gd                # Entidad Mech que USA los sistemas
│
├── managers/               # Gestores de alto nivel
│   ├── turn_manager.gd               # ✅ REFACTORIZADO: Gestor de turnos y fases
│   ├── battle_state_manager.gd       # ✨ NUEVO: Gestor de estado de batalla
│   ├── battle_ai.gd                  # ✨ NUEVO: Sistema de IA para enemigos
│   └── battle_input_handler.gd       # ✨ NUEVO: Manejador de input
│
├── ui/                     # Interfaz de usuario
│   ├── screens/
│   │   ├── main_menu.gd              # Pantalla de menú principal
│   │   └── initiative_screen.gd      # Pantalla de iniciativa con dados
│   ├── components/                    # Componentes UI reutilizables
│   └── battle_ui.gd                  # UI principal de batalla
│
├── utils/                  # Utilidades y helpers
│
├── battle_scene.gd         # Controlador principal de batalla (a refactorizar)
├── battle_overlay.gd       # Overlay para visualización de hexágonos
├── hex_grid.gd             # Grid hexagonal
└── mech.gd                 # LEGACY - A deprecar gradualmente
```

### Archivos de Backup
```
├── managers/
│   └── turn_manager.gd.backup        # Backup del turn_manager original
```

## Principios SOLID Aplicados

### 1. **Single Responsibility Principle (SRP)**
Cada clase tiene UNA responsabilidad:
- `WeaponSystem`: Solo combate a distancia
- `PhysicalAttackSystem`: Solo combate cuerpo a cuerpo
- `MovementSystem`: Solo movimiento y alcance
- `HeatSystem`: Solo gestión de calor
- `MechEntity`: Solo propiedades y estado del mech

### 2. **Open/Closed Principle (OCP)**
Los sistemas son **abiertos a extensión** pero **cerrados a modificación**:
- Se pueden agregar nuevos tipos de armas sin modificar `WeaponSystem`
- Se pueden agregar nuevos ataques físicos sin modificar `PhysicalAttackSystem`

### 3. **Liskov Substitution Principle (LSP)**
Todos los sistemas son `RefCounted` y pueden ser sustituidos:
- Podrías crear un `AdvancedWeaponSystem` que extienda `WeaponSystem`
- O un `ClanWeaponSystem` con reglas diferentes

### 4. **Interface Segregation Principle (ISP)**
Cada sistema expone SOLO los métodos que necesita:
- `WeaponSystem` no tiene métodos de movimiento
- `MovementSystem` no tiene métodos de combate
- Los clientes solo dependen de lo que usan

### 5. **Dependency Inversion Principle (DIP)**
`MechEntity` depende de **abstracciones** (los sistemas), no de implementaciones:
```gdscript
# MechEntity NO implementa lógica de calor, DELEGA:
func add_heat(amount: int):
    HeatSystem.add_heat(self, amount)
```

## Beneficios de esta Arquitectura

### ✅ **Testeable**
Cada sistema puede testearse independientemente:
```gdscript
# Test de WeaponSystem
var target_number = WeaponSystem.calculate_to_hit(attacker, target, weapon, 5)
assert(target_number == 6)
```

### ✅ **Mantenible**
Si quieres cambiar cómo funciona el calor, solo editas `HeatSystem`

### ✅ **Extensible**
Agregar nuevas mecánicas es fácil:
- Nuevo archivo: `terrain_system.gd`
- Nuevo método en `MovementSystem`

### ✅ **Reutilizable**
Los sistemas son **static** y se pueden usar desde cualquier parte

### ✅ **Legible**
El código es autodocumentado:
```gdscript
# Claro y expresivo
var damage = PhysicalAttackSystem.calculate_punch_damage(attacker)
var can_kick = PhysicalAttackSystem.can_kick(attacker)
```

## Migración desde código legacy

El archivo `mech.gd` original (461 líneas) ahora se divide en:
- `MechEntity` (187 líneas) - Solo propiedades y estado
- `WeaponSystem` (87 líneas) - Lógica de armas
- `PhysicalAttackSystem` (98 líneas) - Lógica de ataques físicos
- `MovementSystem` (67 líneas) - Lógica de movimiento
- `HeatSystem` (77 líneas) - Lógica de calor

**Total: 516 líneas** (55 más que antes, pero MUCHO más organizado)

## Próximos Pasos

### Fase 1: Refactorización Completada ✅
1. ✅ Crear `GameEnums` y `GameConstants`
2. ✅ Crear `BattleStateManager`
3. ✅ Crear `BattleAI`
4. ✅ Crear `BattleInputHandler`
5. ✅ Refactorizar `TurnManager`

### Fase 2: Integración (En Progreso)
1. ⏳ Migrar `battle_scene.gd` para usar los nuevos managers
2. ⏳ Actualizar `mech.gd` para usar `GameEnums`
3. ⏳ Integrar `BattleStateManager` en el flujo principal
4. ⏳ Delegar lógica de IA a `BattleAI`
5. ⏳ Conectar `BattleInputHandler` con `battle_scene`

### Fase 3: Limpieza (Pendiente)
1. ⬜ Eliminar código duplicado en `battle_scene.gd`
2. ⬜ Reducir tamaño de `battle_scene.gd` (actualmente 944 líneas)
3. ⬜ Eliminar logs de debug excesivos
4. ⬜ Crear componentes UI reutilizables en `ui/components/`
5. ⬜ Deprecar y migrar desde `mech.gd` a `MechEntity`

### Fase 4: Mejoras (Futuro)
1. ⬜ Sistema de guardado/carga
2. ⬜ Crear `TerrainSystem` para costos de terreno
3. ⬜ Crear `InitiativeSystem` para cálculos de iniciativa
4. ⬜ Replay de batalla
5. ⬜ Editor de mechs

## Documentación Adicional

- **[REFACTORING.md](REFACTORING.md)**: Detalles de la refactorización realizada
- **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)**: Guía paso a paso para migrar código
- **[TESTING.md](TESTING.md)**: Guía de testing
- **[dice_system.md](dice_system.md)**: Sistema de dados 3D
- **[initiative_screen.md](initiative_screen.md)**: Pantalla de iniciativa
- **[physical_attacks.md](physical_attacks.md)**: Sistema de ataques físicos

## Notas de la Refactorización (Nov 2025)

### Bug Resuelto: Menú de Movimiento en Fase de Armas ✅
**Problema**: El menú de selección de movimiento (Walk/Run/Jump) aparecía incorrectamente durante la fase de ataque con armas.

**Causa**: Problema de timing en la emisión de señales. La señal `unit_activated` se emitía ANTES de que `phase_changed` actualizara el estado.

**Solución**:
1. Reordenar `advance_phase()` para emitir `phase_changed` ANTES de iniciar fases
2. Agregar delays de sincronización (`PHASE_TRANSITION_DELAY`)
3. Reset condicional de movimiento solo en fase correcta
4. Estado centralizado en `BattleStateManager`

### Mejoras Arquitecturales

**Separación de Responsabilidades**:
- **BattleStateManager**: Gestiona estado y validaciones
- **BattleAI**: Encapsula toda la lógica de IA
- **BattleInputHandler**: Maneja entrada del usuario
- **TurnManager**: Solo control de flujo, sin lógica compleja

**Centralización**:
- **GameEnums**: Un lugar para todos los enums
- **GameConstants**: Un lugar para todas las constantes
- Fácil de modificar y mantener

## Convenciones de Código

- **class_name** obligatorio para todas las clases
- **extends RefCounted** para sistemas sin estado (pure functions)
- **extends Node2D** para entidades visuales
- **static func** para sistemas sin estado
- **Documentación** con `##` al inicio de cada clase
- **Signals** para comunicación entre entidades
