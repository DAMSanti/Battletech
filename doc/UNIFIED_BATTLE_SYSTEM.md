# Sistema de Batalla Unificado

## Arquitectura

El nuevo sistema de batalla está diseñado para funcionar tanto en singleplayer como en multiplayer usando la misma interfaz.

### Componentes

```
BattleState          - Estado compartido de la batalla (mechs, fases, turnos)
BattleController     - Clase base abstracta con la interfaz común
├── LocalBattleManager    - Implementación para singleplayer
└── NetworkBattleManager  - Implementación para multiplayer
```

### BattleState

Contiene todo el estado de la batalla:
- Mechs y su estado (posición, armadura, armas, calor, etc.)
- Fase actual del turno
- Número de turno
- Equipo activo
- Unidad activa
- Resultados de iniciativa

```gdscript
var state = BattleState.new()

# Añadir un mech
var mech = BattleState.MechState.new()
mech.id = "atlas_1"
mech.name = "Atlas"
mech.team = "player"
state.add_mech(mech)

# Serializar/deserializar
var data = state.serialize()
state.deserialize(data)
```

### BattleController

Define la interfaz que la UI debe usar:

**Señales:**
- `state_changed(state)` - El estado cambió
- `phase_changed(phase)` - La fase del turno cambió
- `turn_changed(turn)` - El número de turno cambió
- `active_team_changed(team)` - El equipo activo cambió
- `active_unit_changed(mech_id)` - La unidad activa cambió
- `deployment_started(team)` - Empezó despliegue para un equipo
- `deployment_zone_ready(hexes)` - Hexágonos válidos de despliegue
- `mech_deployed(mech_id, position)` - Un mech fue desplegado
- `movement_started(mech_id)` - Un mech puede moverse
- `movement_executed(mech_id, path, position)` - Movimiento completado
- `facing_changed(mech_id, facing, mp_cost)` - Facing cambió
- `attack_resolved(result)` - Ataque resuelto
- `game_over(winner, reason)` - Fin de la batalla
- `error_occurred(code, message)` - Error en acción

**Métodos:**
```gdscript
# Consultas
func get_state() -> BattleState
func is_multiplayer() -> bool
func has_authority() -> bool
func get_local_player_id() -> int
func get_local_team() -> String
func is_local_player_turn() -> bool
func is_local_mech(mech_id) -> bool

# Despliegue
func request_start_deployment()
func get_deployment_zone(team) -> Array[Vector2i]
func request_deploy_mech(mech_id, position, facing)

# Iniciativa
func request_roll_initiative()

# Movimiento
func request_start_movement(mech_id)
func get_movement_options(mech_id) -> Dictionary
func request_execute_movement(mech_id, path, movement_type)
func request_change_facing(mech_id, new_facing)
func request_end_movement(mech_id)

# Combate
func request_declare_attack(attacker_id, defender_id, weapon_index)
func get_valid_targets(mech_id) -> Array
func get_attack_modifier(attacker_id, defender_id, weapon_index) -> int
func request_physical_attack(attacker_id, defender_id, attack_type)

# Control de turno
func request_next_unit()
func request_end_phase()
func request_end_turn()
```

## Uso

### Singleplayer

```gdscript
var battle_manager = LocalBattleManager.new()

battle_manager.initialize({
    "hex_grid": hex_grid,
    "map_size": Vector2i(18, 18),
    "player_mechs": player_mech_configs,
    "enemy_mechs": enemy_mech_configs
})

# Conectar señales
battle_manager.phase_changed.connect(_on_phase_changed)
battle_manager.movement_started.connect(_on_movement_started)
# etc...

# Iniciar despliegue
battle_manager.request_start_deployment()
```

### Multiplayer

```gdscript
var battle_manager = NetworkBattleManager.new()

battle_manager.initialize({
    "battle_client": network_battle_client,
    "match_id": match_id,
    "local_peer_id": multiplayer.get_unique_id(),
    "local_team": my_team,
    "map_size": Vector2i(18, 18)
})

# La interfaz es idéntica a singleplayer
battle_manager.phase_changed.connect(_on_phase_changed)
battle_manager.movement_started.connect(_on_movement_started)

# Las acciones se envían al servidor
battle_manager.request_deploy_mech(mech_id, position, facing)
```

## Migración desde el sistema actual

### Paso 1: Crear el BattleManager apropiado

```gdscript
var battle_manager: BattleController

func _ready():
    if is_multiplayer_mode:
        battle_manager = NetworkBattleManager.new()
        battle_manager.initialize({
            "battle_client": network_battle_client,
            "match_id": match_id,
            "local_peer_id": multiplayer.get_unique_id(),
            "local_team": my_team,
            "map_size": Vector2i(hex_grid.grid_width, hex_grid.grid_height)
        })
    else:
        battle_manager = LocalBattleManager.new()
        battle_manager.initialize({
            "hex_grid": hex_grid,
            "map_size": Vector2i(hex_grid.grid_width, hex_grid.grid_height),
            "player_mechs": player_mech_configs,
            "enemy_mechs": enemy_mech_configs
        })
    
    _connect_battle_signals()
```

### Paso 2: Conectar señales

```gdscript
func _connect_battle_signals():
    battle_manager.phase_changed.connect(_on_battle_phase_changed)
    battle_manager.active_unit_changed.connect(_on_battle_unit_activated)
    battle_manager.deployment_started.connect(_on_battle_deployment_started)
    battle_manager.deployment_zone_ready.connect(_on_battle_deployment_zone)
    battle_manager.mech_deployed.connect(_on_battle_mech_deployed)
    battle_manager.movement_started.connect(_on_battle_movement_started)
    battle_manager.movement_executed.connect(_on_battle_movement_executed)
    battle_manager.facing_changed.connect(_on_battle_facing_changed)
    battle_manager.attack_resolved.connect(_on_battle_attack_resolved)
    battle_manager.game_over.connect(_on_battle_game_over)
    battle_manager.error_occurred.connect(_on_battle_error)
```

### Paso 3: Usar el manager para acciones

```gdscript
# En vez de lógica directa:
# mech.position = new_pos
# mech.facing = new_facing

# Usar el manager:
battle_manager.request_execute_movement(mech.id, path, movement_type)
battle_manager.request_change_facing(mech.id, new_facing)
```

### Paso 4: La UI reacciona a señales

```gdscript
func _on_battle_movement_executed(mech_id: String, path: Array, new_pos: Vector2i):
    var mech = _find_mech_node_by_id(mech_id)
    if mech:
        mech.position = hex_grid.hex_to_pixel(new_pos)
        mech.hex_position = new_pos

func _on_battle_facing_changed(mech_id: String, new_facing: int, mp_cost: int):
    var mech = _find_mech_node_by_id(mech_id)
    if mech:
        mech.set_facing(new_facing)
```

## Ventajas del nuevo sistema

1. **Interfaz unificada**: La UI no necesita saber si es singleplayer o multiplayer
2. **Estado centralizado**: Todo el estado está en BattleState
3. **Fácil sincronización**: El estado se puede serializar/deserializar
4. **Validación consistente**: Las validaciones están en un solo lugar
5. **Señales claras**: La UI solo reacciona a señales, no manipula estado
6. **Testeable**: Se pueden crear mocks fácilmente

## Fases del Turno

```gdscript
enum TurnPhase {
    DEPLOYMENT,       # Despliegue inicial
    INITIATIVE,       # Tirada de iniciativa
    MOVEMENT,         # Fase de movimiento
    WEAPON_ATTACK,    # Fase de ataque con armas
    PHYSICAL_ATTACK,  # Fase de ataque físico
    HEAT,             # Fase de disipación de calor
    END               # Fin del turno
}
```

## Archivos

- `scripts/core/battle/battle_state.gd` - Estado de batalla
- `scripts/core/battle/battle_controller.gd` - Clase base abstracta
- `scripts/core/battle/local_battle_manager.gd` - Singleplayer
- `scripts/core/battle/network_battle_manager.gd` - Multiplayer
