# 🔧 Cambios Necesarios en el Código Existente

## ⚠️ IMPORTANTE: Lista de Modificaciones Requeridas

Para que el nuevo sistema de movimiento funcione correctamente, necesitas actualizar los siguientes archivos:

---

## 1. `battle_scene.gd` - Actualizar Lógica de Movimiento

### Cambio 1.1: Importar Nuevos Sistemas

```gdscript
# ANTES: No existían estos sistemas
# AGREGAR al inicio del archivo:

# Ya no es necesario preload si están en autoload, pero si prefieres:
# const MovementSystem = preload("res://scripts/core/movement/movement_system.gd")
# const MovementRestrictions = preload("res://scripts/core/movement/movement_restrictions.gd")
# const FacingSystem = preload("res://scripts/core/movement/facing_system.gd")
```

### Cambio 1.2: Añadir Variable de Tipo de Movimiento

```gdscript
# AGREGAR nueva variable:
var current_movement_type: GameEnums.MovementType = GameEnums.MovementType.WALK
```

### Cambio 1.3: Reemplazar Cálculo de Hexes Alcanzables

```gdscript
# ANTES (en alguna función de selección de mech):
var movement_range = MovementSystem.calculate_walk_distance(selected_mech)
var reachable = MovementSystem.get_reachable_hexes(mech_hex, movement_range, hex_grid)

# DESPUÉS:
var movement_range = 0
match current_movement_type:
    GameEnums.MovementType.WALK:
        movement_range = MovementSystem.calculate_walk_distance(selected_mech)
        reachable = MovementSystem.get_reachable_hexes(
            mech_hex, movement_range, GameEnums.MovementType.WALK, hex_grid, selected_mech
        )
    GameEnums.MovementType.RUN:
        movement_range = MovementSystem.calculate_run_distance(selected_mech)
        reachable = MovementSystem.get_reachable_hexes(
            mech_hex, movement_range, GameEnums.MovementType.RUN, hex_grid, selected_mech
        )
    GameEnums.MovementType.JUMP:
        movement_range = MovementSystem.calculate_jump_distance(selected_mech)
        reachable = MovementSystem.get_jump_hexes(
            mech_hex, movement_range, hex_grid, selected_mech
        )
```

### Cambio 1.4: Actualizar Generación de Calor

```gdscript
# ANTES:
var heat = MovementSystem.calculate_heat_from_movement(mech, hexes_moved, ran)

# DESPUÉS:
var heat = MovementSystem.calculate_heat_from_movement(mech, hexes_moved, current_movement_type)
```

---

## 2. `mech_entity.gd` o `mech.gd` - Añadir Propiedades

### Cambio 2.1: Añadir Facing

```gdscript
# AGREGAR nuevas variables:
var facing: int = FacingSystem.Facing.NORTH  # 0-5
var torso_facing: int = FacingSystem.Facing.NORTH  # Para torso twist
var last_movement_type: GameEnums.MovementType = GameEnums.MovementType.NONE
var hexes_moved_this_turn: int = 0

# Opcional: Si quieres Jump MPs
var jump_mp: int = 0  # Configurar en loadout o stats
```

### Cambio 2.2: Actualizar Rotación Visual

```gdscript
# AGREGAR método para actualizar facing visual:
func update_facing_visual():
    var angle = FacingSystem.get_angle_for_facing(facing)
    rotation_degrees = angle
```

---

## 3. `hex_grid.gd` - Verificar Compatibilidad

### Cambio 3.1: Verificar que Existan Estos Métodos

El nuevo sistema requiere que `hex_grid.gd` tenga:

```gdscript
# Estos métodos DEBEN existir (verifica que estén implementados):
func get_terrain(hex: Vector2i) -> TerrainType.Type
func get_elevation(hex: Vector2i) -> int
func get_unit(hex: Vector2i)  # Retorna mech o null
func is_valid_hex(hex: Vector2i) -> bool
func get_neighbors(hex: Vector2i) -> Array
func hex_distance(a: Vector2i, b: Vector2i) -> int
func get_hexes_in_range(center: Vector2i, range: int) -> Array
```

✅ **Buenas noticias**: Al revisar tu `hex_grid.gd`, estos métodos YA EXISTEN.

---

## 4. UI - Añadir Selector de Tipo de Movimiento

### Opción A: Botones en Battle Overlay

```gdscript
# En battle_overlay.gd o similar, AGREGAR:

@onready var walk_button = $WalkButton
@onready var run_button = $RunButton
@onready var jump_button = $JumpButton

func _ready():
    walk_button.pressed.connect(_on_walk_pressed)
    run_button.pressed.connect(_on_run_pressed)
    jump_button.pressed.connect(_on_jump_pressed)

func _on_walk_pressed():
    movement_type_selected.emit(GameEnums.MovementType.WALK)

func _on_run_pressed():
    movement_type_selected.emit(GameEnums.MovementType.RUN)

func _on_jump_pressed():
    movement_type_selected.emit(GameEnums.MovementType.JUMP)

# Signal
signal movement_type_selected(type: GameEnums.MovementType)
```

### Opción B: Shortcuts de Teclado

```gdscript
# En battle_scene.gd, AGREGAR en _input():

func _input(event):
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_W:  # W = Walk
                current_movement_type = GameEnums.MovementType.WALK
                update_movement_display()
            KEY_R:  # R = Run
                current_movement_type = GameEnums.MovementType.RUN
                update_movement_display()
            KEY_J:  # J = Jump
                current_movement_type = GameEnums.MovementType.JUMP
                update_movement_display()
```

---

## 5. Actualizar Cálculo de To-Hit

### Cambio 5.1: Añadir Modificadores de Movimiento

```gdscript
# En tu sistema de combate (combat_system.gd o similar):

func calculate_to_hit(attacker, target) -> int:
    var base_to_hit = 7  # Base BattleTech
    
    # AGREGAR: Modificador por movimiento del atacante
    var attacker_move_mod = MovementSystem.get_attacker_movement_modifier(
        attacker.last_movement_type
    )
    
    # AGREGAR: Modificador por movimiento del objetivo
    var target_move_mod = MovementSystem.get_target_movement_modifier(
        target.last_movement_type,
        target.hexes_moved_this_turn
    )
    
    # AGREGAR: Modificador por terreno del objetivo
    var target_terrain = hex_grid.get_terrain(target.current_hex)
    var terrain_mod = TerrainType.get_to_hit_modifier(target_terrain)
    
    # AGREGAR: Modificador por elevación
    var height_mod = hex_grid.get_height_modifier(attacker.current_hex, target.current_hex)
    
    # Calcular total
    var total = base_to_hit + attacker_move_mod + target_move_mod + terrain_mod + height_mod
    
    return total
```

---

## 6. Terreno - Actualizar Generación

### Cambio 6.1: Usar Nuevos Tipos de Terreno

Si generas terreno proceduralmente, asegúrate de usar los nuevos tipos:

```gdscript
# En hex_grid.gd o terrain_generator, ACTUALIZAR:

# Ahora tienes estos tipos adicionales:
TerrainType.Type.LIGHT_WOODS   # Bosque ligero
TerrainType.Type.HEAVY_WOODS   # Bosque denso
TerrainType.Type.BOG           # Pantano
TerrainType.Type.ROAD          # Carretera
TerrainType.Type.RUBBLE        # Escombros
```

---

## 7. Sistema de Piloting Checks (NUEVO)

### Cambio 7.1: Implementar Piloting Check

```gdscript
# AGREGAR nueva función en battle_scene.gd o mech_entity.gd:

func perform_piloting_check(mech, difficulty: int) -> bool:
    # Tirar 2d6
    var roll = randi_range(1, 6) + randi_range(1, 6)
    
    # Añadir piloting skill del mech
    var skill = mech.pilot_skill  # Asume que existe
    
    var result = roll + skill
    
    if result >= difficulty:
        print("✅ Piloting check exitoso (%d vs %d)" % [result, difficulty])
        return true
    else:
        print("❌ Piloting check fallido (%d vs %d) - ¡CAÍDA!" % [result, difficulty])
        mech_falls(mech)
        return false

func mech_falls(mech):
    # Aplicar daño por caída (5 puntos cada pierna)
    mech.take_damage("left_leg", 5)
    mech.take_damage("right_leg", 5)
    # Marcar como caído
    mech.is_prone = true
    # Perder turno
    mech.skip_next_turn = true
```

### Cambio 7.2: Ejecutar Check Cuando Sea Necesario

```gdscript
# MODIFICAR en la función de movimiento:

func move_mech_to_hex(mech, target_hex):
    # ... código existente ...
    
    # AGREGAR: Verificar piloting check
    var check = MovementRestrictions.requires_piloting_check(
        mech.current_hex, target_hex, hex_grid, current_movement_type
    )
    
    if check.required:
        var success = perform_piloting_check(mech, check.difficulty)
        if not success:
            return  # No completar movimiento si cayó
    
    # ... resto del código ...
```

---

## 8. Visualización de Hexes Alcanzables

### Cambio 8.1: Colorear Según Coste

```gdscript
# MODIFICAR función que dibuja hexes alcanzables:

func highlight_reachable_hexes(hexes: Array):
    for hex in hexes:
        # AGREGAR: Calcular coste
        var cost = MovementSystem.calculate_movement_cost(
            selected_mech.current_hex, hex, current_movement_type, hex_grid
        )
        
        # AGREGAR: Color según coste
        var color = Color.GREEN
        if cost > 2:
            color = Color.YELLOW
        if cost > 4:
            color = Color.ORANGE
        if cost > 6:
            color = Color.RED
        
        # AGREGAR: Verificar accesibilidad
        var accessible = MovementRestrictions.is_hex_accessible(
            hex, selected_mech, hex_grid, current_movement_type
        )
        
        if not accessible:
            color = Color.GRAY
        
        hex_grid.highlight_hex(hex, color)
```

---

## 9. Checklist de Integración

### Fase 1: Setup Básico
- [ ] Crear carpeta `scripts/core/movement/` si no existe
- [ ] Copiar archivos nuevos:
  - [ ] `movement_system.gd`
  - [ ] `movement_restrictions.gd`
  - [ ] `facing_system.gd`
- [ ] Actualizar `terrain_type.gd` con nuevos tipos
- [ ] Actualizar `game_enums.gd` con MovementType

### Fase 2: Actualizar Entidades
- [ ] Añadir `facing` a MechEntity
- [ ] Añadir `last_movement_type` a MechEntity
- [ ] Añadir `hexes_moved_this_turn` a MechEntity
- [ ] Añadir `jump_mp` a stats de mech
- [ ] Añadir `update_facing_visual()` a MechEntity

### Fase 3: Actualizar Battle Scene
- [ ] Añadir `current_movement_type` variable
- [ ] Reemplazar `get_reachable_hexes()` con nueva versión
- [ ] Actualizar generación de calor
- [ ] Implementar `perform_piloting_check()`
- [ ] Añadir verificación de piloting checks al mover

### Fase 4: UI
- [ ] Añadir botones Walk/Run/Jump
- [ ] Conectar signals de tipo de movimiento
- [ ] Actualizar display de MPs según tipo
- [ ] Mostrar modificadores de disparo en UI
- [ ] Colorear hexes según coste

### Fase 5: Combate
- [ ] Actualizar `calculate_to_hit()` con nuevos modificadores
- [ ] Añadir modificador de movimiento del atacante
- [ ] Añadir modificador de movimiento del defensor
- [ ] Añadir modificador de terreno

### Fase 6: Testing
- [ ] Probar Walk en diferentes terrenos
- [ ] Probar Run (debe ser 1.5x walk)
- [ ] Probar Jump (debe ignorar terreno)
- [ ] Probar elevación (subir cuesta MPs, bajar gratis)
- [ ] Probar piloting checks
- [ ] Probar restricciones de terreno

---

## 10. Compatibilidad con Código Existente

### ✅ Compatible (No Requiere Cambios)

- `hex_grid.gd` - Ya tiene todos los métodos necesarios
- `mech.gd` - Solo necesita añadir facing
- `component_database.gd` - Sin cambios
- Sistema de calor - Solo actualizar llamada

### ⚠️ Requiere Actualización

- `battle_scene.gd` - Ver Cambio 1
- `mech_entity.gd` - Ver Cambio 2
- Sistema de combate - Ver Cambio 5
- UI de batalla - Ver Cambio 4

### 🆕 Archivos Nuevos (No Afectan Existentes)

- `movement_system.gd` - Nuevo
- `movement_restrictions.gd` - Nuevo
- `facing_system.gd` - Nuevo
- `MOVEMENT_SYSTEM.md` - Documentación

---

## 11. Migración Paso a Paso

### Paso 1: Backup
```bash
# Hacer copia de seguridad
git commit -m "Pre-movement system update"
```

### Paso 2: Añadir Archivos Nuevos
- Copiar los 3 archivos .gd a `scripts/core/movement/`
- Actualizar `terrain_type.gd` y `game_enums.gd`

### Paso 3: Actualizar MechEntity (Mínimo)
```gdscript
# En mech_entity.gd, añadir:
var facing: int = 0
var last_movement_type: int = GameEnums.MovementType.NONE
var hexes_moved_this_turn: int = 0
```

### Paso 4: Probar Compilación
```bash
# Abrir Godot y verificar que no haya errores
# Los nuevos archivos no rompen nada existente
```

### Paso 5: Integrar en Battle Scene (Incremental)
- Empezar con Walk solamente
- Añadir Run cuando Walk funcione
- Añadir Jump al final

---

## 🎯 Resultado Final

Después de aplicar todos los cambios, tendrás:

✅ **Movimiento BattleTech completo** con 3 tipos  
✅ **Costes de terreno realistas** (14 tipos)  
✅ **Sistema de elevación** funcional  
✅ **Piloting checks** automáticos  
✅ **Modificadores de combate** precisos  
✅ **UI mejorada** con selector de movimiento  
✅ **Visualización clara** de hexes alcanzables

**El sistema es retrocompatible** - puedes migrar gradualmente sin romper el código existente.

---

**¿Necesitas ayuda con algún paso específico? Avísame y te genero el código exacto.**
