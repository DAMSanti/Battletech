# 📘 Development Guidelines
## Steel Titans: Tactical Warfare

**Versión:** 1.0  
**Fecha:** 29 de Noviembre, 2025  
**Aplicable a:** Todo el equipo de desarrollo

---

## 📑 Índice

1. [Principios Generales](#1-principios-generales)
2. [Convenciones de Código](#2-convenciones-de-código)
3. [Arquitectura y Patrones](#3-arquitectura-y-patrones)
4. [Gestión de Archivos](#4-gestión-de-archivos)
5. [Testing](#5-testing)
6. [Control de Versiones](#6-control-de-versiones)
7. [Logging y Debugging](#7-logging-y-debugging)
8. [Networking](#8-networking)
9. [Rendimiento](#9-rendimiento)
10. [Checklist de Pull Request](#10-checklist-de-pull-request)

---

# 1. Principios Generales

## 1.1 Filosofía de Desarrollo

> **"Código que funciona hoy, se mantiene mañana"**

1. **Claridad sobre brevedad** - Código legible > código corto
2. **SOLID principles** - Single Responsibility, Open/Closed, Liskov, Interface Segregation, Dependency Inversion
3. **DRY** - Don't Repeat Yourself
4. **KISS** - Keep It Simple, Stupid
5. **YAGNI** - You Aren't Gonna Need It (no implementar "por si acaso")

## 1.2 Idiomas

| Elemento | Idioma | Ejemplo |
|----------|--------|---------|
| Variables | Inglés | `current_health`, `target_hex` |
| Funciones | Inglés | `calculate_damage()`, `get_movement_range()` |
| Clases | Inglés | `BattleStateManager`, `MechLoadout` |
| Comentarios | Español | `# Calcula el daño base sin modificadores` |
| Documentación | Español | `## Este sistema maneja...` |
| Commits | Inglés | `fix: resolve damage calculation bug` |
| Strings de UI | Inglés (localizable) | `"Attack"`, `"Move"` |

## 1.3 Regla de Oro

> Si un archivo supera **500 líneas**, considera dividirlo.
> Si una función supera **50 líneas**, considera refactorizarla.
> Si una función tiene más de **5 parámetros**, considera usar un objeto/diccionario.

---

# 2. Convenciones de Código

## 2.1 Naming Conventions

### Variables
```gdscript
# ✅ Correcto - snake_case, descriptivo
var current_health: int = 100
var selected_mech: Mech = null
var is_player_turn: bool = false
var _private_cache: Dictionary = {}  # Prefijo _ para privadas

# ❌ Incorrecto
var hp: int = 100           # Muy corto, no descriptivo
var CurrentHealth: int      # PascalCase es para clases
var current_Health: int     # Mezcla de estilos
```

### Constantes
```gdscript
# ✅ Correcto - SCREAMING_SNAKE_CASE
const MAX_HEAT: int = 30
const DEFAULT_ARMOR: int = 100
const HEX_SIZE: float = 64.0

# ❌ Incorrecto
const maxHeat: int = 30     # camelCase
const max_heat: int = 30    # snake_case (confunde con variables)
```

### Funciones
```gdscript
# ✅ Correcto - snake_case, verbo + sustantivo
func calculate_damage(attacker: Mech, defender: Mech) -> int:
func get_available_targets() -> Array[Mech]:
func is_valid_move(from: Vector2i, to: Vector2i) -> bool:
func _on_button_pressed() -> void:  # Callbacks con prefijo _on_

# ❌ Incorrecto
func damage() -> int:              # No es claro qué hace
func GetTargets() -> Array:        # PascalCase
func check(x, y) -> bool:          # Parámetros no descriptivos
```

### Clases y Enums
```gdscript
# ✅ Correcto - PascalCase
class_name BattleStateManager
class_name MechLoadout

enum BattlePhase { DEPLOYMENT, MOVEMENT, COMBAT, END_TURN }
enum DamageType { ENERGY, BALLISTIC, MISSILE, PHYSICAL }

# ❌ Incorrecto
class_name battle_state_manager   # snake_case
enum battle_phase { ... }         # snake_case
```

### Signals
```gdscript
# ✅ Correcto - snake_case, pasado o descripción de evento
signal damage_applied(target: Mech, amount: int)
signal turn_ended(player_id: int)
signal mech_destroyed(mech: Mech)
signal movement_completed(mech: Mech, path: Array)

# ❌ Incorrecto
signal DamageApplied()            # PascalCase
signal apply_damage()             # Imperativo (parece función)
signal dmg()                      # Abreviación
```

## 2.2 Formato de Código

### Indentación y Espaciado
```gdscript
# ✅ Correcto
func calculate_to_hit(attacker: Mech, defender: Mech, weapon: Weapon) -> int:
    var base_to_hit: int = 4
    var gunnery: int = attacker.pilot.gunnery
    
    # Modificadores de movimiento
    var movement_mod: int = _get_movement_modifier(attacker)
    var target_mod: int = _get_target_movement_modifier(defender)
    
    # Modificadores de terreno
    var terrain_mod: int = _get_terrain_modifier(defender.hex_position)
    
    var total: int = base_to_hit + gunnery + movement_mod + target_mod + terrain_mod
    return clampi(total, 2, 12)

# ❌ Incorrecto - sin espacios, sin organización
func calculate_to_hit(attacker:Mech,defender:Mech,weapon:Weapon)->int:
    var base_to_hit:int=4
    var gunnery:int=attacker.pilot.gunnery
    var movement_mod:int=_get_movement_modifier(attacker)
    var target_mod:int=_get_target_movement_modifier(defender)
    var terrain_mod:int=_get_terrain_modifier(defender.hex_position)
    var total:int=base_to_hit+gunnery+movement_mod+target_mod+terrain_mod
    return clampi(total,2,12)
```

### Líneas en Blanco
```gdscript
# ✅ Correcto - agrupar lógicamente
func _ready() -> void:
    _initialize_components()
    _connect_signals()
    _load_data()


func _initialize_components() -> void:
    hex_grid = $HexGrid
    ui = $BattleUI
    

func _connect_signals() -> void:
    hex_grid.hex_clicked.connect(_on_hex_clicked)
    ui.action_selected.connect(_on_action_selected)
```

### Longitud de Línea
- **Máximo recomendado:** 100 caracteres
- **Máximo absoluto:** 120 caracteres

```gdscript
# ✅ Correcto - dividir líneas largas
var damage_result: DamageResult = combat_calculator.calculate_damage(
    attacker_mech,
    defender_mech,
    selected_weapon,
    attack_modifiers
)

# ❌ Incorrecto - línea demasiado larga
var damage_result: DamageResult = combat_calculator.calculate_damage(attacker_mech, defender_mech, selected_weapon, attack_modifiers)
```

## 2.3 Comentarios

### Cuándo Comentar
```gdscript
# ✅ Comentar el "por qué", no el "qué"

# El daño se divide entre estructura y blindaje porque las reglas
# de BattleTech especifican transferencia de daño excedente
var remaining_damage: int = damage - armor
if remaining_damage > 0:
    structure -= remaining_damage

# ❌ No comentar lo obvio
# Resta el daño del blindaje
armor -= damage
```

### Formato de Comentarios
```gdscript
# Comentario de una línea

# Comentario de múltiples líneas que explica
# algo más complejo y requiere más espacio
# para ser claro y comprensible

## Documentación de clase/función (docstring)
## Se muestra en el editor de Godot
func calculate_damage() -> int:
    pass
```

### TODOs y FIXMEs
```gdscript
# TODO: Implementar sistema de críticos cuando se defina en GDD
# FIXME: Este cálculo no considera el terreno correctamente
# HACK: Workaround temporal hasta refactor de networking
# NOTE: Este valor viene del GDD sección 4.3
```

## 2.4 Type Hints

> **OBLIGATORIO** usar type hints en todo el código nuevo.

```gdscript
# ✅ Correcto - tipos explícitos
var health: int = 100
var name: String = "Atlas"
var position: Vector2i = Vector2i.ZERO
var weapons: Array[Weapon] = []
var armor_values: Dictionary = {}

func get_damage(weapon: Weapon, range_bracket: int) -> int:
    return weapon.damage * range_modifiers[range_bracket]

func find_targets(origin: Vector2i, max_range: int) -> Array[Mech]:
    var targets: Array[Mech] = []
    # ...
    return targets

# ❌ Incorrecto - sin tipos
var health = 100
var weapons = []

func get_damage(weapon, range_bracket):
    return weapon.damage * range_modifiers[range_bracket]
```

---

# 3. Arquitectura y Patrones

## 3.1 Estructura de Archivos por Responsabilidad

```
scripts/
├── core/           # Lógica fundamental, sin dependencias de UI
│   ├── combat/     # Cálculos de combate puros
│   ├── movement/   # Lógica de movimiento
│   └── terrain/    # Sistema de terreno
│
├── entities/       # Clases de datos/entidades
│   ├── mech.gd
│   ├── weapon.gd
│   └── pilot.gd
│
├── managers/       # Orquestadores de sistemas
│   ├── battle_state_manager.gd
│   └── turn_manager.gd
│
├── network/        # Todo lo relacionado con red
│   ├── network_manager.gd
│   └── rpc_handlers.gd
│
├── ui/             # Interfaz de usuario
│   ├── screens/    # Pantallas completas
│   └── components/ # Componentes reutilizables
│
└── utils/          # Utilidades genéricas
    ├── hex_utils.gd
    └── math_utils.gd
```

## 3.2 Principio de Responsabilidad Única

```gdscript
# ❌ INCORRECTO - Clase que hace demasiado
class_name MechManager

func load_mech_from_file() -> void: pass
func calculate_damage() -> int: return 0
func render_mech_sprite() -> void: pass
func play_attack_sound() -> void: pass
func send_network_update() -> void: pass
func save_to_database() -> void: pass


# ✅ CORRECTO - Responsabilidades separadas
class_name MechDataLoader
func load_from_file(path: String) -> MechData: pass

class_name CombatCalculator
func calculate_damage(attacker: Mech, defender: Mech) -> int: pass

class_name MechRenderer
func render(mech: Mech, position: Vector2) -> void: pass

class_name CombatAudioController  
func play_attack_sound(weapon_type: String) -> void: pass
```

## 3.3 Dependency Injection (Preferido sobre Singletons)

```gdscript
# ❌ INCORRECTO - Acoplamiento fuerte a singleton
class_name BattleController

func process_attack() -> void:
    var damage = CombatCalculator.instance.calculate_damage()
    AudioManager.play_sound("attack")
    NetworkManager.send_attack_result()


# ✅ CORRECTO - Dependencias inyectadas
class_name BattleController

var _combat_calculator: CombatCalculator
var _audio: AudioController
var _network: NetworkClient

func _init(
    combat_calc: CombatCalculator,
    audio: AudioController,
    network: NetworkClient
) -> void:
    _combat_calculator = combat_calc
    _audio = audio
    _network = network

func process_attack() -> void:
    var damage = _combat_calculator.calculate_damage()
    _audio.play_sound("attack")
    _network.send_attack_result()
```

## 3.4 Uso de Signals para Desacoplamiento

```gdscript
# ✅ CORRECTO - Comunicación por signals
class_name BattleScene

signal mech_selected(mech: Mech)
signal attack_requested(attacker: Mech, target: Mech, weapon: Weapon)
signal turn_ended()

func _ready() -> void:
    # La UI escucha eventos de batalla
    mech_selected.connect(ui.on_mech_selected)
    attack_requested.connect(combat_controller.on_attack_requested)

func _on_hex_clicked(hex: Vector2i) -> void:
    var mech = get_mech_at(hex)
    if mech:
        mech_selected.emit(mech)  # Notificar sin conocer quién escucha
```

## 3.5 Autoloads - Cuándo Usar

| ✅ Usar Autoload Para | ❌ NO Usar Autoload Para |
|----------------------|-------------------------|
| Logging (Log) | Lógica de batalla |
| Audio global | UI específica de escena |
| Network connection | Managers de escena |
| Configuración global | Datos de partida actual |
| Analytics | Cualquier cosa con estado mutable complejo |

```gdscript
# ✅ Autoloads legítimos
Log.info("Combat", "Attack resolved")
AudioManager.play_music("battle_theme")
NetworkManager.is_connected()

# ❌ NO debería ser autoload
BattleManager.current_turn  # Estado mutable de partida
UIManager.show_dialog()     # UI debería ser por escena
```

---

# 4. Gestión de Archivos

## 4.1 Tamaño Máximo de Archivos

| Tipo de Archivo | Máximo Recomendado | Acción si Excede |
|-----------------|-------------------|------------------|
| Script (.gd) | 500 líneas | Dividir en clases |
| Escena (.tscn) | 1000 líneas | Usar sub-escenas |
| Resource (.tres) | Sin límite | - |

## 4.2 Organización de Escenas

```
scenes/
├── battle/
│   ├── battle_scene.tscn          # Escena principal
│   ├── hex_grid.tscn              # Sub-escena del grid
│   └── mech_instance.tscn         # Template de mech
│
├── ui/
│   ├── battle_ui.tscn
│   ├── components/
│   │   ├── health_bar.tscn
│   │   ├── weapon_button.tscn
│   │   └── mech_info_panel.tscn
│   └── dialogs/
│       ├── confirmation_dialog.tscn
│       └── settings_dialog.tscn
│
└── screens/
    ├── main_menu.tscn
    ├── mech_bay.tscn
    └── multiplayer_lobby.tscn
```

## 4.3 Nomenclatura de Archivos

```
# Scripts: snake_case.gd
battle_state_manager.gd
mech_data.gd
hex_utils.gd

# Escenas: snake_case.tscn
battle_scene.tscn
main_menu.tscn

# Resources: snake_case.tres
steeltitans_theme.tres
atlas_config.tres

# Assets: snake_case con categoría
mech_atlas_idle.png
sfx_laser_fire.wav
music_battle_01.ogg
```

---

# 5. Testing

## 5.1 Objetivos de Cobertura

| Categoría | Cobertura Mínima | Ejemplos |
|-----------|------------------|----------|
| **Crítico** | ≥95% | `combat_calculator.gd`, `damage_system.gd`, `network_validation.gd` |
| **Importante** | ≥80% | `movement_system.gd`, `heat_system.gd`, `initiative.gd` |
| **Normal** | ≥70% | `ui_components/`, `utils/`, `audio/` |

## 5.2 Estructura de Tests

```gdscript
# tests/unit/test_combat_system.gd
extends GutTest

var combat_calc: CombatCalculator

func before_each() -> void:
    combat_calc = CombatCalculator.new()

func after_each() -> void:
    combat_calc.free()

# Nomenclatura: test_[método]_[escenario]_[resultado_esperado]
func test_calculate_damage_medium_laser_at_short_range_returns_5() -> void:
    var weapon = _create_medium_laser()
    var result = combat_calc.calculate_base_damage(weapon, RangeBracket.SHORT)
    assert_eq(result, 5, "Medium Laser should do 5 damage at short range")

func test_calculate_damage_with_null_weapon_returns_zero() -> void:
    var result = combat_calc.calculate_base_damage(null, RangeBracket.SHORT)
    assert_eq(result, 0, "Null weapon should return 0 damage")

# Helpers privados para setup
func _create_medium_laser() -> Weapon:
    var weapon = Weapon.new()
    weapon.name = "Medium Laser"
    weapon.damage = 5
    return weapon
```

## 5.3 Qué Testear

```gdscript
# ✅ TESTEAR
# - Cálculos de daño
# - Validaciones de movimiento
# - Lógica de estados
# - Parsing de datos
# - Casos límite (null, vacío, máximo)

# ❌ NO TESTEAR (directamente)
# - UI visual
# - Sonidos
# - Godot engine internals
# - Código de terceros
```

## 5.4 Ejecutar Tests

```bash
# Todos los tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Tests específicos
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_combat.gd -gexit

# Con cobertura (si está configurado)
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gcoverage -gexit
```

---

# 6. Control de Versiones

## 6.1 Branching Strategy

```
main (producción)
  │
  └── develop (integración)
        │
        ├── feature/[nombre]     # Nuevas funcionalidades
        ├── fix/[nombre]         # Corrección de bugs
        ├── refactor/[nombre]    # Mejoras de código
        └── hotfix/[nombre]      # Fixes urgentes a main
```

## 6.2 Commits

### Formato (Conventional Commits)
```
<tipo>(<alcance>): <descripción>

[cuerpo opcional]

[footer opcional]
```

### Tipos
| Tipo | Uso |
|------|-----|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de bug |
| `refactor` | Cambio de código sin cambiar funcionalidad |
| `test` | Añadir o modificar tests |
| `docs` | Documentación |
| `style` | Formateo, sin cambios de lógica |
| `perf` | Mejoras de rendimiento |
| `chore` | Mantenimiento, dependencias |

### Ejemplos
```
feat(combat): add critical hit system

fix(network): resolve desync on reconnection

refactor(battle): extract damage calculator to separate class

test(movement): add edge cases for ZoC validation

docs: update SAD with new architecture decisions
```

## 6.3 .gitignore

```gitignore
# Godot
.godot/
*.import
export_presets.cfg

# Builds
exports/
*.pck
*.apk

# IDE
.vscode/
*.code-workspace

# OS
.DS_Store
Thumbs.db

# Secrets
*.key
*.pem
.env
```

---

# 7. Logging y Debugging

## 7.1 Uso del Sistema de Log

```gdscript
# Niveles disponibles
Log.debug("Category", "Mensaje detallado para desarrollo")
Log.info("Category", "Evento normal del flujo")
Log.warning("Category", "Situación anómala pero manejable")
Log.error("Category", "Error que afecta funcionalidad")
Log.critical("Category", "Error grave, posible crash")

# Categorías estándar
"System"    # Inicialización, configuración
"Combat"    # Sistema de combate
"Network"   # Conexiones, RPCs
"UI"        # Interfaz de usuario
"Heat"      # Sistema de calor
"Movement"  # Movimiento de mechs
"Save"      # Guardado/carga
"Audio"     # Sistema de audio
"AI"        # Inteligencia artificial
"Match"     # Gestión de partidas
"Mech"      # Estado de mechs
"Input"     # Input del jugador
"Test"      # Tests
```

## 7.2 Contexto en Logs

```gdscript
# ✅ CORRECTO - Incluir contexto relevante
Log.info("Combat", "Damage applied", {
    "attacker": attacker.name,
    "defender": defender.name,
    "damage": damage,
    "location": location
})

Log.error("Network", "Failed to connect", {
    "ip": server_ip,
    "port": port,
    "error_code": error
})

# ❌ INCORRECTO - Sin contexto
Log.info("Combat", "Damage applied")
Log.error("Network", "Failed")
```

## 7.3 Cuándo Usar Cada Nivel

| Nivel | Usar Para | Ejemplo |
|-------|-----------|---------|
| DEBUG | Flujo detallado de desarrollo | "Calculating movement range for hex (5,3)" |
| INFO | Eventos importantes del flujo normal | "Match started", "Player connected" |
| WARNING | Situaciones recuperables | "Reconnecting to server...", "Asset not found, using default" |
| ERROR | Fallos que afectan funcionalidad | "Failed to save game", "Invalid action received" |
| CRITICAL | Errores que pueden crashear | "Database connection lost", "Out of memory" |

---

# 8. Networking

## 8.1 Principios de Networking

1. **Servidor Autoritativo** - El servidor SIEMPRE tiene la última palabra
2. **Never Trust the Client** - Validar TODO lo que viene del cliente
3. **Predict on Client** - El cliente puede predecir, pero el servidor confirma
4. **Minimize Bandwidth** - Enviar solo lo necesario

## 8.2 Estructura de RPCs

```gdscript
# Cliente → Servidor: Peticiones
@rpc("any_peer", "call_remote", "reliable")
func request_move(mech_id: int, target_hex: Vector2i) -> void:
    # Solo el servidor procesa
    if not multiplayer.is_server():
        return
    
    # Validar
    if not _validate_move(mech_id, target_hex):
        _reject_action.rpc_id(sender_id, "Invalid move")
        return
    
    # Ejecutar y broadcast
    _execute_move(mech_id, target_hex)
    _broadcast_move.rpc(mech_id, target_hex)


# Servidor → Clientes: Resultados
@rpc("authority", "call_remote", "reliable")
func _broadcast_move(mech_id: int, target_hex: Vector2i) -> void:
    # Todos los clientes actualizan su estado
    var mech = get_mech_by_id(mech_id)
    mech.move_to(target_hex)
```

## 8.3 Validación Server-Side (OBLIGATORIA)

```gdscript
func _validate_move(mech_id: int, target_hex: Vector2i) -> bool:
    var mech = get_mech_by_id(mech_id)
    
    # Validaciones básicas
    if mech == null:
        Log.warning("Network", "Invalid mech_id", {"id": mech_id})
        return false
    
    if not _is_player_turn(mech.owner_id):
        Log.warning("Network", "Not player's turn")
        return false
    
    # Validaciones de gameplay
    var distance = hex_grid.distance(mech.position, target_hex)
    if distance > mech.movement_points:
        Log.warning("Network", "Move too far", {"distance": distance, "mp": mech.movement_points})
        return false
    
    if not hex_grid.is_passable(target_hex):
        Log.warning("Network", "Hex not passable", {"hex": target_hex})
        return false
    
    # Más validaciones...
    return true
```

---

# 9. Rendimiento

## 9.1 Objetivos de Rendimiento

| Métrica | Objetivo | Medición |
|---------|----------|----------|
| FPS en batalla | ≥30 FPS | Profiler |
| Memoria máxima | <500 MB | Monitor de Godot |
| Tiempo de carga | <5 segundos | Manual |
| Tamaño APK | <100 MB | Build |

## 9.2 Prácticas de Optimización

```gdscript
# ✅ CORRECTO - Cache de cálculos costosos
var _cached_visible_hexes: Array[Vector2i] = []
var _cache_valid: bool = false

func get_visible_hexes() -> Array[Vector2i]:
    if not _cache_valid:
        _cached_visible_hexes = _calculate_visible_hexes()
        _cache_valid = true
    return _cached_visible_hexes

func on_mech_moved() -> void:
    _cache_valid = false  # Invalidar cache


# ❌ INCORRECTO - Recalcular cada frame
func _process(delta: float) -> void:
    var visible = _calculate_visible_hexes()  # ¡Costoso cada frame!
```

```gdscript
# ✅ CORRECTO - Object pooling para objetos frecuentes
var _projectile_pool: Array[Projectile] = []

func get_projectile() -> Projectile:
    if _projectile_pool.is_empty():
        return Projectile.new()
    return _projectile_pool.pop_back()

func return_projectile(p: Projectile) -> void:
    p.reset()
    _projectile_pool.append(p)
```

## 9.3 Profiling

```gdscript
# Usar el sistema de timers del Log para medir
func expensive_operation() -> void:
    Log.start_timer("expensive_op")
    
    # ... operación costosa ...
    
    Log.end_timer("expensive_op", "Combat")
    # Output: Timer 'expensive_op' completado | elapsed_sec=0.045
```

---

# 10. Checklist de Pull Request

## 10.1 Antes de Crear PR

- [ ] El código compila sin errores (`--check-only`)
- [ ] Todos los tests pasan
- [ ] No hay `print()` statements (usar `Log.*`)
- [ ] Type hints en todas las funciones nuevas
- [ ] Comentarios en español donde sea necesario
- [ ] Archivos nuevos siguen la estructura de carpetas
- [ ] No hay archivos >500 líneas sin justificación

## 10.2 Descripción del PR

```markdown
## Descripción
[Qué hace este PR]

## Tipo de Cambio
- [ ] Bug fix
- [ ] Nueva funcionalidad
- [ ] Refactor
- [ ] Documentación
- [ ] Tests

## Testing
- [ ] Tests unitarios añadidos/actualizados
- [ ] Probado manualmente en editor
- [ ] Probado en build Android (si aplica)

## Screenshots (si aplica UI)
[Imágenes]

## Notas
[Cualquier contexto adicional]
```

## 10.3 Review Checklist

- [ ] Código sigue las convenciones de este documento
- [ ] Lógica es clara y mantenible
- [ ] No introduce deuda técnica innecesaria
- [ ] Tests cubren casos importantes
- [ ] Documentación actualizada si es necesario
- [ ] No hay secrets/credentials hardcodeados

---

*Documento vivo - Actualizar cuando se establezcan nuevas convenciones*

*Última actualización: 29 de Noviembre, 2025*
