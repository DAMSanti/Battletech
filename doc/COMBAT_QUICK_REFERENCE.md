# Sistema de Combate - Referencia Rápida

## 🎯 Resolución de Ataque de Arma

### Función Principal
```gdscript
var result = WeaponAttackSystem.resolve_weapon_attack(attacker, target, weapon, hex_grid)
```

### Resultado
- `success`: ¿Se procesó el ataque?
- `can_shoot`: ¿Puede disparar? (LoS, rango)
- `hit`: ¿Impactó?
- `damage_applied`: Daño total
- `locations_hit`: Array de localizaciones golpeadas
- `critical_hits`: Array de críticos
- `breakdown`: Desglose de modificadores

## 📐 Modificadores de To-Hit

### Atacante
- **Gunnery Skill**: +4 (promedio)
- **Caminó**: +1
- **Corrió**: +2
- **Saltó**: +3
- **Calor**: +1 cada 5 puntos

### Objetivo
- **0-2 hexes**: +0
- **3-4 hexes**: +1
- **5-6 hexes**: +2
- **7-9 hexes**: +3
- **10+ hexes**: +4
- **Saltó**: +1 adicional

### Rango
- **Corto**: +0
- **Medio**: +2
- **Largo**: +4

### Cobertura
- **Bosque ligero**: +1 por hex
- **Bosque denso**: +2 (bloquea si 2+ hexes)
- **Hull-down**: +1, solo partes superiores
- **Edificio**: +2

### Altura
- **Desde arriba**: -1 por nivel (máx -2)
- **Desde abajo**: +1 por nivel (máx +2)

## 🎲 Tabla de Localización (2D6)

| 2D6 | Localización |
|-----|-------------|
| 2 | Centro Torso |
| 3-4 | Brazo Derecho |
| 5 | Pierna Derecha |
| 6 | Torso Derecho |
| 7 | Centro Torso |
| 8 | Torso Izquierdo |
| 9 | Pierna Izquierda |
| 10-11 | Brazo Izquierdo |
| 12 | Cabeza |

## 🚀 Cluster Tables (Misiles)

### SRM-2
- 2-6: 1 misil
- 7-12: 2 misiles

### SRM-4
- 2-3: 1 misil
- 4-6: 2 misiles
- 7-9: 3 misiles
- 10-12: 4 misiles

### SRM-6
- 2-3: 2 misiles
- 4-5: 2 misiles
- 6-7: 3-4 misiles
- 8-9: 4-5 misiles
- 10-12: 6 misiles

### LRM-10
- 2-3: 3 misiles
- 4: 4 misiles
- 5-6: 6 misiles
- 7-9: 7-9 misiles
- 10-12: 10 misiles

## 💥 Críticos (2D6 por punto de daño a estructura)

| 2D6 | Efecto |
|-----|--------|
| 2-7 | Sin crítico |
| 8-9 | 1 slot crítico |
| 10-11 | 2 slots críticos |
| 12+ | 3 slots críticos |

### Componentes Críticos
- **Arma**: Destruida
- **Munición**: EXPLOSIÓN (salvo CASE)
- **Heatsink**: -1 disipación
- **Gyro**: Caída, +3 PSR
- **Motor**: 3 hits = destrucción

## 🔥 Efectos del Calor

| Calor | Movimiento | To-Hit |
|-------|-----------|--------|
| 0-4 | Normal | +0 |
| 5-9 | Normal | +1 |
| 10-14 | -1 MP | +2 |
| 15-19 | -2 MP | +3 |
| 20-24 | -3 MP | +4 |
| 25-29 | -4 MP | +5 |
| 30+ | Shutdown | - |

## ⚠️ Destrucción de Mech

### Automática
- ✅ Cabeza destruida
- ✅ Centro torso destruido
- ✅ Ambas piernas destruidas
- ✅ 3 hits al motor

### Explosión de Munición
**Sin CASE**: Daño masivo interno, probable destrucción
**Con CASE**: Solo destruye la localización

## 📊 Probabilidades de Impacto (2D6)

| TN | % |
|----|---|
| 2 | 100% |
| 3 | 97.2% |
| 4 | 91.7% |
| 5 | 83.3% |
| 6 | 72.2% |
| 7 | 58.3% |
| 8 | 41.7% |
| 9 | 27.8% |
| 10 | 16.7% |
| 11 | 8.3% |
| 12 | 2.8% |
| 13+ | 2.8% (solo con 12 crítico) |

## 🔧 Ejemplos de Código

### Disparar un Arma
```gdscript
var result = WeaponAttackSystem.resolve_weapon_attack(
    attacker_mech,
    target_mech,
    weapon,
    hex_grid
)

if result.hit:
    print("HIT for %d damage!" % result.damage_applied)
```

### Verificar LoS
```gdscript
var los = LineOfSight.calculate_los(hex_grid, attacker_pos, target_pos)
if los.result == LineOfSight.Result.BLOCKED:
    print("Cannot shoot!")
```

### Calcular To-Hit
```gdscript
var range = hex_grid.hex_distance(attacker_pos, target_pos)
var to_hit = WeaponAttackSystem.calculate_to_hit(
    attacker, target, weapon, range, 0, hex_grid
)
print("Need %d+ on 2D6" % to_hit.target_number)
```

### Armas Funcionales
```gdscript
var weapons = mech.get_functional_weapons()
for weapon in weapons:
    print(weapon.name)
```

## 🎮 Flujo de Combate

1. **Seleccionar objetivo** → Verificar LoS
2. **Seleccionar armas** → Mostrar To-Hit preview
3. **Confirmar disparo** → Resolver cada arma
4. **Aplicar daño** → Armadura → Estructura → Críticos
5. **Actualizar estado** → Verificar destrucción
6. **Mostrar resultados** → UI + Efectos visuales

## 📝 Notas Importantes

- **2 en 2D6**: Siempre falla (excepto si TN=2)
- **12 en 2D6**: Siempre impacta (incluso si TN=13+)
- **Hull-down**: Solo golpea cabeza, torsos y brazos
- **Misiles**: Se agrupan en 5s para distribución de daño
- **CASE**: Salva el mech de explosiones de munición
- **ECM**: +1 vs misiles dentro de 6 hexes
- **BAP**: Niega ECM, -1 a corto alcance
