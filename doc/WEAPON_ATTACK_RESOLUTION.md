# Sistema de Resolución de Ataques con Armas

Sistema completo de combate implementado según las reglas de BattleTech Total Warfare.

## Descripción General

El sistema maneja el proceso completo de ataque con armas:

1. **Verificación de Línea de Visión (LoS)**
2. **Cálculo del Número Objetivo (To-Hit)**
3. **Tirada de Ataque (2D6)**
4. **Resolución de Daño**
5. **Agotamiento de Armadura → Daño Interno**
6. **Resolución de Críticos**

## 1. Verificación de Línea de Visión

### Tipos de LoS
- **CLEAR**: Línea de visión despejada (sin modificadores)
- **PARTIAL**: Cobertura parcial (modificadores de to-hit)
- **BLOCKED**: Línea bloqueada (no se puede disparar)

### Tipos de Cobertura
- **Bosque Ligero**: +1 por hex atravesado
- **Bosque Denso**: +2 si atraviesa 1 hex, BLOQUEA si atraviesa 2+
- **Hull-Down**: +1, solo puede golpear partes superiores
- **Edificios**: Bloquean o dan +2 según altura
- **Mechs**: Bloquean completamente

### Modificadores de Altura
- Atacando desde arriba: -1 por nivel (más fácil, máx -2)
- Atacando desde abajo: +1 por nivel (más difícil, máx +2)

## 2. Cálculo del To-Hit Number

Formula: `Gunnery Skill + Modificadores`

### Modificadores del Atacante
- **Gunnery Skill**: Base del piloto (4 = promedio)
- **Movimiento**:
  - Caminó: +1
  - Corrió: +2
  - Saltó: +3
- **Calor**: +1 por cada 5 puntos de calor

### Modificadores del Objetivo
- **TMM (Target Movement Modifier)**:
  - 0-2 hexes: +0
  - 3-4 hexes: +1
  - 5-6 hexes: +2
  - 7-9 hexes: +3
  - 10+ hexes: +4
  - +1 adicional si saltó

### Modificadores de Rango
- **Corto**: +0
- **Medio**: +2
- **Largo**: +4
- **Fuera de rango**: Imposible disparar

### Modificadores de Terreno/Cobertura
- **Bosque ligero**: +1 por hex
- **Bosque denso**: +2
- **Edificio**: +2
- **Hull-down**: +1

### Modificadores Especiales
- **ECM enemigo**: +1 para misiles (dentro de 6 hexes)
- **BAP propio**: -1 a corto alcance
- **Rango mínimo**: Imposible disparar si está demasiado cerca

## 3. Tirada de Ataque (2D6)

### Reglas Especiales
- **2**: Siempre falla (fallo crítico)
- **12**: Siempre impacta (impacto crítico)
- **Otro resultado**: Impacta si >= To-Hit Number

## 4. Resolución de Daño

### A) Armas Directas (Energía/Balística)

El daño se aplica en un solo paquete:

1. Se tira localización (2D6)
2. Se aplica todo el daño a esa localización
3. Primero se agota armadura, luego va a estructura

**Tabla de Localización (2D6)**:
- 2: Centro del Torso
- 3-4: Brazo Derecho
- 5: Pierna Derecha
- 6: Torso Derecho
- 7: Centro del Torso
- 8: Torso Izquierdo
- 9: Pierna Izquierda
- 10-11: Brazo Izquierdo
- 12: Cabeza

**Hull-Down**: Si el objetivo está hull-down, solo se pueden golpear localizaciones superiores (cabeza, torsos, brazos).

### B) Armas de Misiles (LRM/SRM)

El daño se distribuye en clusters:

1. Se tira **Cluster Table** (2D6) para ver cuántos misiles impactan
2. Los misiles se agrupan (normalmente grupos de 5)
3. Cada grupo tira su propia localización
4. Se aplica el daño de cada grupo

**Tablas de Cluster**:

**SRM-2** (2 misiles):
- 2-6: 1 impacta
- 7-12: 2 impactan

**SRM-4** (4 misiles):
- 2-3: 1 impacta
- 4-6: 2 impactan
- 7-9: 3 impactan
- 10-12: 4 impactan

**SRM-6** (6 misiles):
- 2-3: 2 impactan
- 4-5: 2 impactan
- 6-7: 3-4 impactan
- 8-9: 4-5 impactan
- 10-12: 6 impactan

**LRM-10** (10 misiles):
- 2-3: 3 impactan
- 4: 4 impactan
- 5-6: 6 impactan
- 7: 7 impactan
- 8: 8 impactan
- 9: 9 impactan
- 10-12: 10 impactan

**LRM-15** y **LRM-20**: Tablas similares escaladas

## 5. Armor Depletion → Internal Damage

### Secuencia de Daño

1. **Daño a Armadura**: Se aplica primero al blindaje de la localización
2. **Overflow a Estructura**: Si el blindaje llega a 0, el daño sobrante pasa a estructura interna
3. **Localización Destruida**: Si la estructura llega a 0, la localización queda destruida

### Casos Especiales

**Cabeza Destruida**: Mech destruido inmediatamente
**Centro del Torso Destruido**: Mech destruido inmediatamente
**Ambas Piernas Destruidas**: Mech destruido (no puede moverse)

## 6. Critical Hit Resolution

### Cuándo Ocurren

Por cada punto de daño a estructura interna, se tira 2D6:

- **2-7**: Sin crítico adicional (solo daño estructural)
- **8-9**: 1 slot crítico
- **10-11**: 2 slots críticos
- **12+**: 3 slots críticos

### Efectos de Críticos

Se seleccionan componentes al azar en la localización:

- **Armas**: Destruidas, no se pueden usar
- **Munición**: EXPLOSIÓN si no hay CASE
- **Heatsinks**: -1 disipación de calor
- **Actuadores**: Penalizaciones de movimiento/combate
- **Gyro**: Caída del mech, +3 PSR para levantarse
- **Motor**: 3 hits = mech destruido

### Explosión de Munición

**Sin CASE**:
- Explosión interna devastadora
- Daño al centro del torso
- Daño a localizaciones adyacentes
- Probable destrucción del mech

**Con CASE**:
- La explosión es contenida
- Solo destruye la localización donde está la munición
- El mech sobrevive (pero pierde esa sección)

## Uso del Sistema

### Código de Ejemplo

```gdscript
# En battle_scene.gd o similar

# Resolver un ataque completo
var attacker = player_mech
var target = enemy_mech
var weapon = attacker.weapons[0]  # Primera arma

var result = WeaponAttackSystem.resolve_weapon_attack(
    attacker,
    target,
    weapon,
    hex_grid
)

if result.success:
    if result.hit:
        print("HIT! %s" % result.message)
        print("Damage applied: %d" % result.damage_applied)
        print("Locations hit: %s" % str(result.locations_hit))
        
        if result.critical_hits.size() > 0:
            print("CRITICAL HITS:")
            for crit in result.critical_hits:
                print("  - %s" % crit.description)
    else:
        print("MISS! %s" % result.message)
    
    print("\nBreakdown:\n%s" % result.breakdown)
else:
    print("Cannot shoot: %s" % result.message)
```

### Verificar LoS Independientemente

```gdscript
var los_data = LineOfSight.calculate_los(
    hex_grid,
    attacker.hex_position,
    target.hex_position
)

if los_data.result == LineOfSight.Result.BLOCKED:
    print("Cannot shoot - LoS blocked")
elif los_data.result == LineOfSight.Result.PARTIAL:
    print("Partial cover: +%d to-hit" % los_data.to_hit_modifier)
else:
    print("Clear shot")
```

### Calcular To-Hit sin Disparar

```gdscript
var range = hex_grid.hex_distance(attacker.hex_position, target.hex_position)
var to_hit_data = WeaponAttackSystem.calculate_to_hit(
    attacker,
    target,
    weapon,
    range,
    0,
    hex_grid
)

print("Target Number: %d" % to_hit_data.target_number)
print("\nBreakdown:\n%s" % to_hit_data.breakdown)
```

## Datos Retornados

### resolve_weapon_attack()

```gdscript
{
    "success": bool,              # True si el ataque se procesó (hit o miss)
    "can_shoot": bool,            # True si puede disparar (LoS, rango OK)
    "hit": bool,                  # True si el ataque impactó
    "roll": int,                  # Tirada 2D6
    "target_number": int,         # Número objetivo para impactar
    "damage_applied": int,        # Daño total aplicado
    "locations_hit": Array,       # [{location, damage, armor_damage, structure_damage, critical_hit}]
    "critical_hits": Array,       # [{location, roll, component_hit, description, effect}]
    "heat_generated": int,        # Calor generado por el disparo
    "ammo_consumed": int,         # Munición consumida
    "message": String,            # Mensaje resumen
    "breakdown": String           # Desglose completo de modificadores
}
```

## Integración con Battle Scene

El sistema está listo para integrarse con `battle_scene.gd` en la fase de ataque con armas:

1. Jugador selecciona objetivo
2. Jugador selecciona armas a disparar
3. Por cada arma, llamar a `resolve_weapon_attack()`
4. Mostrar resultados en UI
5. Actualizar estado de mechs
6. Verificar si algún mech fue destruido

## Características Implementadas

✅ Line of Sight completo con cobertura y elevación
✅ Cálculo de To-Hit con todos los modificadores
✅ Tirada de ataque 2D6 con reglas especiales
✅ Daño directo para energía/balística
✅ Cluster table para misiles (LRM/SRM)
✅ Armor depletion y daño a estructura
✅ Critical hit resolution
✅ Explosión de munición con CASE
✅ Destrucción de componentes
✅ Modificadores de ECM/BAP
✅ Hull-down targeting
✅ Modificadores de altura

## Próximos Pasos

- [ ] Integrar con UI de batalla
- [ ] Animaciones de impacto
- [ ] Efectos visuales de daño
- [ ] Log de combate detallado
- [ ] Estadísticas de batalla
