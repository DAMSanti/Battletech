# Sistema de Movimiento BattleTech

## Descripción General

Este documento describe la implementación del sistema de movimiento de BattleTech en el juego, incluyendo todos los tipos de movimiento, costes de terreno, y restricciones según las reglas oficiales.

## Tipos de Movimiento

### 1. Caminar (Walk)
- **Coste base**: 1 MP por hex
- **Penalizadores**:
  - Al disparar: +1 to-hit (más difícil acertar)
  - Defensa: Sin bonificación
- **Características**:
  - Movimiento estándar
  - Afectado por terreno
  - Afectado por elevación al subir

### 2. Correr (Run)
- **Coste base**: 2 MP por hex (calculado como 1.5x Walk MP)
- **Penalizadores**:
  - Al disparar: +2 to-hit
  - Defensa: +2 (más difícil de impactar)
- **Restricciones**:
  - No se puede correr en terreno ROUGH (opcional según edición)
  - No se puede correr en HEAVY_WOODS (opcional)
- **Características**:
  - Mayor velocidad
  - Genera 2 puntos de calor (vs 1 de Walk)

### 3. Saltar (Jump)
- **Coste base**: 1 MP por hex saltado
- **Penalizadores**:
  - Al disparar: +3 to-hit (mayor penalización)
  - Defensa: +2 (más difícil de impactar)
- **Características**:
  - **Ignora terreno** - El coste NO aumenta por bosques, rough, etc.
  - **Ignora elevación** - No cuesta MP adicional subir niveles
  - No puede interrumpirse una vez iniciado
  - Genera calor = 1 por cada hex saltado
  - Siempre requiere chequeo de pilotaje al aterrizar

## Costes de Terreno

### Terrenos Terrestres (afectan Walk/Run)

| Terreno | Walk Cost | Run Cost | Jump Cost | Notas |
|---------|-----------|----------|-----------|-------|
| CLEAR (Despejado) | 1 | 2 | 1 | Terreno base |
| LIGHT_WOODS (Bosque Ligero) | 2 | 4 | 1 | +1 coste, da cobertura +1 |
| HEAVY_WOODS (Bosque Denso) | 3 | 5 | 1 | +2 coste, cobertura +2 |
| ROUGH (Difícil) | 2 | 4 | 1 | Prohíbe correr (opcional) |
| SAND (Arena) | 2 | 4 | 1 | +1 coste |
| BOG (Pantano) | 2 | 4 | 1 | Requiere piloting check |
| RUBBLE (Escombros) | 3 | 5 | 1 | +2 coste, piloting check |
| ROAD (Carretera) | 0* | 1* | 1 | -1 coste (mín 1 total) |
| PAVEMENT | 1 | 2 | 1 | Coste base |
| BUILDING | 2 | 4 | 1 | Requiere piloting check |

\* Las carreteras reducen el coste en 1, pero el mínimo es siempre 1 MP.

### Terrenos Acuáticos

| Terreno | Depth | Walk/Run | Jump | Notas |
|---------|-------|----------|------|-------|
| WATER (poco profunda) | 1 | +1 coste | 1 | Mechs pueden entrar |
| Agua profunda | 2+ | ❌ Prohibido | ⚠️ Según altura | Solo mechs altos |

### Colinas y Elevación

**Subir**:
- +1 MP por cada nivel de elevación ascendido
- Máximo cambio: 2 niveles sin transición
- Ejemplo: Subir de nivel 0 → 2 = coste base + 2 MP

**Bajar**:
- ❌ NO cuesta MPs adicionales
- ⚠️ Bajar más de 1 nivel requiere piloting check
- ⚠️ Bajar más de 2 niveles puede causar daño

**Saltar**:
- Ignora costes de elevación completamente
- Solo cuenta la distancia en hexes

## Restricciones de Movimiento

### Hexes Prohibidos

**No se puede entrar a**:
- Hexes ocupados por enemigos
- Hexes ocupados por aliados (salvo DFA)
- Agua profunda (depth 2+) sin capacidad
- Acantilados con cambio > 2 niveles
- Fuera del mapa

### Hexes con Riesgo

**Requieren piloting check**:
- BOG/SWAMP (pantano) - Riesgo de atascarse
- RUBBLE (escombros)
- BUILDING (entrar a edificio)
- ICE (hielo) - Al moverse sobre él
- Cualquier aterrizaje de salto
- Bajar más de 1 nivel de elevación

### Zona de Control de Enemigos (ZOC)

En BattleTech NO hay ZOC tradicional, PERO:
- **Salir de hex adyacente a enemigo** → Requiere piloting check
- Si fallas el check → Caída (daño + pierdes turno)

## Sistema de Orientación (Facing)

### Facetas Hexagonales

Los hexes tienen 6 facetas (0-5):
- 0 = Norte (N)
- 1 = Noreste (NE)
- 2 = Sureste (SE)
- 3 = Sur (S)
- 4 = Suroeste (SW)
- 5 = Noroeste (NW)

### Costes de Giro

- **Durante movimiento**: 0 MP (gratis)
- **Sin moverse**: 0 MP (regla estándar)
- **Torso twist**: Gratis, máximo ±1 faceta respecto a piernas

### Arcos de Disparo

- **Frontal**: Facing ± 1 faceta (3 facetas)
- **Lateral Derecho**: Facetas 1-2
- **Lateral Izquierdo**: Facetas 4-5
- **Trasero**: Faceta opuesta (3 facetas)

## Modificadores de Combate

### Al Disparar (Atacante)

| Movimiento | Modificador to-hit |
|------------|-------------------|
| No movió | 0 |
| Walk | +1 |
| Run | +2 |
| Jump | +3 |

### Defensa (Objetivo)

| Movimiento | Modificador to-hit enemigo |
|------------|---------------------------|
| No movió | 0 |
| Walk | 0 |
| Run | +2 (más difícil impactarte) |
| Jump | +2 (más difícil impactarte) |

### Modificadores de Terreno

| Terreno | Defensa | To-hit Modificador |
|---------|---------|-------------------|
| CLEAR | 0 | 0 |
| LIGHT_WOODS | +1 | +1 |
| HEAVY_WOODS | +2 | +2 |
| BUILDING | +2 | +2 |
| WATER | 0 | +1 |

## Generación de Calor

| Acción | Calor Generado |
|--------|---------------|
| Walk | 1 punto |
| Run | 2 puntos |
| Jump | 1 punto por hex saltado |
| Sin moverse | 0 |

## Ejemplos Prácticos

### Ejemplo 1: Moverse a Bosque Ligero

**Escenario**: Atlas (Walk 3) quiere entrar a hex de bosque ligero

**Caminando**:
- Coste base: 1 MP
- Terreno (Light Woods): +1 MP
- **Total**: 2 MP

**Corriendo**:
- Coste base: 2 MP
- Terreno (Light Woods): +1 MP
- **Total**: 4 MP (pero Run MP del Atlas = 3×1.5 = 4.5)

**Saltando** (si tiene JJ):
- Coste: 1 MP (ignora terreno)
- Calor: 1 punto por hex

### Ejemplo 2: Subir Colina

**Escenario**: Subir de nivel 0 → 2 en terreno ROUGH

**Caminando**:
- Coste base: 1 MP
- Terreno rough: +1 MP
- Elevación (subir 2 niveles): +2 MP
- **Total**: 4 MP

**Saltando**:
- Coste: 1 MP (ignora todo)
- Calor: 1 punto

### Ejemplo 3: Moverse por Carretera

**Escenario**: Mech corriendo por carretera (hex plano)

**Corriendo**:
- Coste base: 2 MP
- Modificador carretera: -1 MP
- **Total**: 1 MP por hex (mínimo 1)

### Ejemplo 4: Zona de Enemigos

**Escenario**: Mech adyacente a enemigo quiere alejarse

**Salir del hex**:
- Movimiento normal (coste según terreno)
- **Piloting check** requerido (dificultad 4)
- Si falla → Caída (5 puntos daño por pierna + prone)

## Archivos de Implementación

### Scripts Principales

1. **movement_system.gd**
   - `calculate_walk_distance(mech)` - MPs de caminata
   - `calculate_run_distance(mech)` - MPs de carrera
   - `calculate_jump_distance(mech)` - MPs de salto
   - `calculate_movement_cost(from, to, type, grid)` - Coste de mover
   - `get_reachable_hexes(start, max, type, grid)` - Hexes alcanzables
   - `get_jump_hexes(start, max, grid)` - Hexes saltables

2. **movement_restrictions.gd**
   - `is_hex_accessible(hex, unit, grid, type)` - Validar acceso
   - `requires_piloting_check(from, to, grid, type)` - Chequeos
   - `get_movement_penalties(hex, type, grid)` - Penalizadores

3. **facing_system.gd**
   - `get_rotation_cost(from, to, moving)` - Coste de giro
   - `get_facing_to_hex(from, to)` - Calcular facing
   - `is_in_front_arc(facing, target, mech)` - Arcos de disparo
   - `can_torso_twist(torso, legs)` - Validar torso twist

4. **terrain_type.gd**
   - `get_movement_cost_by_type(terrain, move_type)` - Coste por tipo
   - `requires_piloting_check(terrain)` - Si requiere check
   - `prohibits_running(terrain)` - Si prohíbe correr
   - `get_cost_modifier(terrain)` - Modificador (carreteras)

### Enums (game_enums.gd)

```gdscript
enum MovementType {
    NONE,   # Sin movimiento
    WALK,   # Caminar
    RUN,    # Correr
    JUMP    # Saltar
}
```

## Integración con Battle Scene

### Flujo de Movimiento

1. **Seleccionar Mech** → Mostrar MPs disponibles
2. **Elegir Tipo** → Walk/Run/Jump
3. **Calcular Alcance** → `get_reachable_hexes()` o `get_jump_hexes()`
4. **Mostrar Hexes** → Visualizar con colores
5. **Click en Destino** → Validar con `is_hex_accessible()`
6. **Calcular Ruta** → Pathfinding considerando costes
7. **Mover Mech** → Actualizar posición y facing
8. **Chequeos** → Piloting checks si es necesario
9. **Generar Calor** → `calculate_heat_from_movement()`
10. **Actualizar UI** → Mostrar modificadores de disparo

## Futuras Mejoras

- [ ] Sistema de DFA (Death From Above)
- [ ] Embestidas (Charge)
- [ ] Skidding en hielo
- [ ] Caídas y daño por caída
- [ ] Prone/Standing (levantarse del suelo)
- [ ] Evasión (Evade) como acción
- [ ] Sprint (variante de Run más rápida)
- [ ] Masc (sistema de aceleración)
