# BATTLETECH GODOT - ARQUITECTURA SOLID

## Estructura del Proyecto

```
scripts/
├── core/                   # Lógica de negocio central (Single Responsibility)
│   ├── combat/
│   │   ├── weapon_system.gd          # Sistema de armas y combate a distancia
│   │   └── physical_attack_system.gd # Sistema de ataques cuerpo a cuerpo
│   ├── movement/
│   │   └── movement_system.gd        # Sistema de movimiento hexagonal
│   └── heat/
│       └── heat_system.gd            # Sistema de gestión de calor
│
├── entities/               # Entidades del juego (Data + Behavior)
│   └── mech_entity.gd                # Entidad Mech que USA los sistemas
│
├── managers/               # Gestores de alto nivel
│   └── turn_manager.gd               # Gestor de turnos y fases
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
├── battle_scene.gd         # Controlador principal de batalla
├── hex_grid.gd             # Grid hexagonal
└── mech.gd                 # LEGACY - A deprecar
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

1. Migrar `battle_scene.gd` para usar `MechEntity` en lugar de `Mech`
2. Crear `TerrainSystem` para costos de terreno
3. Crear `InitiativeSystem` para cálculos de iniciativa
4. Agregar componentes UI reutilizables en `ui/components/`
5. Deprecar y eliminar `mech.gd` legacy

## Convenciones de Código

- **class_name** obligatorio para todas las clases
- **extends RefCounted** para sistemas sin estado (pure functions)
- **extends Node2D** para entidades visuales
- **static func** para sistemas sin estado
- **Documentación** con `##` al inicio de cada clase
- **Signals** para comunicación entre entidades
