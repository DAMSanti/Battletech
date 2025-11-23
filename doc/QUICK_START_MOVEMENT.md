# 🎮 Guía Rápida: Sistema de Movimiento BattleTech

## 📋 Resumen Ejecutivo

He implementado un **sistema de movimiento completo** para BattleTech con todas las reglas oficiales:

✅ **3 tipos de movimiento** (Walk/Run/Jump)  
✅ **Costes de terreno detallados** (14 tipos de terreno)  
✅ **Sistema de elevación** (subir cuesta MPs, bajar gratis)  
✅ **Restricciones de acceso** (hexes prohibidos, agua profunda, etc.)  
✅ **Sistema de orientación** (6 facetas, arcos de disparo)  
✅ **Piloting checks** (terreno peligroso, saltos, ZOC)  
✅ **Modificadores de combate** (to-hit, defensa según movimiento)  
✅ **Generación de calor** (1 Walk, 2 Run, 1/hex Jump)

---

## 🚀 Uso Rápido

### 1️⃣ Calcular MPs Disponibles

```gdscript
# Obtener MPs según tipo de movimiento
var walk_mp = MovementSystem.calculate_walk_distance(mech)    # 4 MP
var run_mp = MovementSystem.calculate_run_distance(mech)      # 6 MP (1.5x walk)
var jump_mp = MovementSystem.calculate_jump_distance(mech)    # 3 MP (si tiene JJ)
```

### 2️⃣ Obtener Hexes Alcanzables

```gdscript
# Hexes alcanzables caminando
var walk_hexes = MovementSystem.get_reachable_hexes(
    mech_position, walk_mp, GameEnums.MovementType.WALK, hex_grid, mech
)

# Hexes alcanzables saltando (ignora terreno)
var jump_hexes = MovementSystem.get_jump_hexes(
    mech_position, jump_mp, hex_grid, mech
)
```

### 3️⃣ Calcular Coste de Movimiento

```gdscript
# Coste de moverse de hex A a hex B
var cost = MovementSystem.calculate_movement_cost(
    from_hex, to_hex, GameEnums.MovementType.WALK, hex_grid
)
# Resultado: 1 (clear) + 1 (bosque) + 1 (subir nivel) = 3 MP
```

### 4️⃣ Verificar Accesibilidad

```gdscript
# ¿Se puede entrar a este hex?
var accessible = MovementRestrictions.is_hex_accessible(
    target_hex, mech, hex_grid, GameEnums.MovementType.WALK
)
# false si: ocupado, agua profunda, prohibido para correr, etc.
```

### 5️⃣ Chequear Piloting Checks

```gdscript
# ¿Requiere piloting check?
var check_info = MovementRestrictions.requires_piloting_check(
    from_hex, to_hex, hex_grid, GameEnums.MovementType.JUMP
)

if check_info.required:
    print("Piloting check necesario: %s (dificultad %d)" % [
        check_info.reason,        # "Aterrizaje de salto"
        check_info.difficulty     # 3
    ])
```

### 6️⃣ Sistema de Facing

```gdscript
# Calcular facing hacia objetivo
var facing = FacingSystem.get_facing_to_hex(shooter_hex, target_hex)
# Resultado: FacingSystem.Facing.NORTHEAST (1)

# Verificar arco de disparo
var arc = FacingSystem.get_arc(mech.facing, target_hex, mech_hex)
# Resultado: "front", "left", "right", "rear"

if FacingSystem.is_in_front_arc(mech.facing, target_hex, mech_hex):
    print("¡Disparo frontal!")
```

---

## 📊 Tabla de Costes (Referencia Rápida)

| Terreno | Walk | Run | Jump | Notas |
|---------|------|-----|------|-------|
| **CLEAR** | 1 | 2 | 1 | Base |
| **LIGHT_WOODS** | 2 | 4 | 1 | +1 def |
| **HEAVY_WOODS** | 3 | 5 | 1 | +2 def |
| **ROUGH** | 2 | ❌ | 1 | Prohíbe correr |
| **WATER (d1)** | 2 | 4 | 1 | Poco profunda |
| **WATER (d2+)** | ❌ | ❌ | ⚠️ | Prohibido |
| **BOG** | 2 | 4 | 1 | ⚠️ Piloting check |
| **RUBBLE** | 3 | 5 | 1 | ⚠️ Piloting check |
| **ROAD** | 0* | 1* | 1 | -1 coste (mín 1) |
| **BUILDING** | 2 | 4 | 1 | ⚠️ Piloting check |

**Elevación**: +1 MP por nivel al **subir** (bajar = gratis)  
**Saltar**: Ignora terreno y elevación, siempre 1 MP/hex

---

## 🎯 Modificadores de Combate

### Al Disparar (Atacante)
```gdscript
var mod = MovementSystem.get_attacker_movement_modifier(movement_type)
```
- No movió: **0**
- Walk: **+1** to-hit
- Run: **+2** to-hit
- Jump: **+3** to-hit

### Defensa (Objetivo)
```gdscript
var mod = MovementSystem.get_target_movement_modifier(movement_type, hexes_moved)
```
- No movió: **0**
- Walk: **0**
- Run: **+2** (más difícil impactarte)
- Jump: **+2**

---

## 🔥 Generación de Calor

```gdscript
var heat = MovementSystem.calculate_heat_from_movement(
    mech, hexes_moved, movement_type
)
```

- Walk: **1 punto**
- Run: **2 puntos**
- Jump: **1 punto × hexes saltados** (saltar 3 hexes = 3 calor)

---

## 🛠️ Archivos Implementados

| Archivo | Descripción |
|---------|-------------|
| `movement_system.gd` | Core del movimiento (MPs, alcance, costes) |
| `movement_restrictions.gd` | Validación de hexes accesibles |
| `facing_system.gd` | Orientación, giros, arcos de disparo |
| `terrain_type.gd` | Costes de terreno actualizados |
| `game_enums.gd` | Enums de MovementType |
| `MOVEMENT_SYSTEM.md` | Documentación completa |
| `movement_integration_example.gd` | Ejemplo de integración |

---

## 💡 Ejemplos de Uso

### Ejemplo 1: Mostrar Hexes Alcanzables

```gdscript
func show_movement_options(mech):
    var mech_hex = mech.current_hex
    var walk_mp = MovementSystem.calculate_walk_distance(mech)
    
    # Obtener hexes alcanzables
    var hexes = MovementSystem.get_reachable_hexes(
        mech_hex, walk_mp, GameEnums.MovementType.WALK, hex_grid, mech
    )
    
    # Visualizar en verde
    for hex in hexes:
        hex_grid.highlight_hex(hex, Color.GREEN)
```

### Ejemplo 2: Mover y Calcular Calor

```gdscript
func move_mech(mech, target_hex, movement_type):
    var distance = hex_grid.hex_distance(mech.current_hex, target_hex)
    
    # Generar calor
    var heat = MovementSystem.calculate_heat_from_movement(
        mech, distance, movement_type
    )
    mech.add_heat(heat)
    
    # Mover
    mech.current_hex = target_hex
    
    print("Movido %d hexes, calor: +%d" % [distance, heat])
```

### Ejemplo 3: Verificar Disparo

```gdscript
func calculate_to_hit(shooter, target):
    var base_to_hit = 7  # BattleTech base
    
    # Modificador por movimiento del atacante
    var atk_mod = MovementSystem.get_attacker_movement_modifier(
        shooter.last_movement_type
    )
    
    # Modificador por movimiento del objetivo
    var def_mod = MovementSystem.get_target_movement_modifier(
        target.last_movement_type, target.hexes_moved
    )
    
    # Modificador por terreno
    var terrain = hex_grid.get_terrain(target.current_hex)
    var terrain_mod = TerrainType.get_to_hit_modifier(terrain)
    
    var final_to_hit = base_to_hit + atk_mod + def_mod + terrain_mod
    
    print("To-hit: %d (base %d, atk +%d, def +%d, terreno +%d)" % [
        final_to_hit, base_to_hit, atk_mod, def_mod, terrain_mod
    ])
```

---

## ⚠️ Casos Especiales

### Agua Profunda
```gdscript
var depth = TerrainType.get_water_depth(terrain)
if depth >= 2:
    # Solo accesible saltando (y según altura del mech)
    if movement_type != GameEnums.MovementType.JUMP:
        return false  # No se puede entrar
```

### Zona de Control (ZOC)
```gdscript
# Salir de hex adyacente a enemigo requiere piloting check
var check = MovementRestrictions.requires_piloting_check(
    from_hex, to_hex, hex_grid, movement_type
)
if check.required and check.reason == "Salir de hex adyacente a enemigo":
    perform_piloting_check(mech, check.difficulty)
```

### Torso Twist
```gdscript
# Girar torso ±1 faceta sin girar piernas
var new_torso = FacingSystem.apply_torso_twist(mech.leg_facing, 1)  # +1 = derecha
if FacingSystem.can_torso_twist(new_torso, mech.leg_facing):
    mech.torso_facing = new_torso
```

---

## 🎨 Integración con UI

### Visualización de Hexes

```gdscript
# Colorear hexes según coste
for hex in reachable_hexes:
    var cost = MovementSystem.calculate_movement_cost(
        mech_hex, hex, movement_type, hex_grid
    )
    
    var color = Color.GREEN      # Coste 1-2
    if cost > 3: color = Color.YELLOW  # Coste 3-5
    if cost > 5: color = Color.RED     # Coste 6+
    
    hex_grid.highlight_hex(hex, color)
```

### Botones de Tipo de Movimiento

```gdscript
# UI con 3 botones: Walk / Run / Jump
func _on_walk_button_pressed():
    current_movement_type = GameEnums.MovementType.WALK
    update_movement_display()

func _on_run_button_pressed():
    current_movement_type = GameEnums.MovementType.RUN
    update_movement_display()

func _on_jump_button_pressed():
    current_movement_type = GameEnums.MovementType.JUMP
    update_movement_display()
```

---

## 🔄 Próximos Pasos

Para integrar en `battle_scene.gd`:

1. ✅ Importar los nuevos scripts (autoload o directo)
2. ✅ Reemplazar `MovementSystem.get_reachable_hexes()` con la nueva versión
3. ✅ Añadir UI para elegir Walk/Run/Jump
4. ✅ Actualizar visualización de hexes (colores según coste)
5. ✅ Implementar piloting checks cuando sea necesario
6. ✅ Actualizar cálculo de to-hit con los nuevos modificadores

**Todo el código está listo para usar** - solo necesitas conectarlo a tu UI existente.

---

## 📚 Documentación Completa

Lee `doc/MOVEMENT_SYSTEM.md` para:
- Reglas detalladas de BattleTech
- Todos los tipos de terreno
- Ejemplos paso a paso
- Tabla de modificadores completa
- Casos especiales (DFA, Charge, etc.)

---

**¡Sistema de movimiento BattleTech completo implementado! 🎉**
