# ADR-003: Sistema de Terreno Procedural

## Estado
✅ Aceptada

## Fecha
2025-11-29

## Contexto

El juego necesita mapas de batalla con terreno hexagonal variado. Teníamos dos aproximaciones:

1. **Mapas pre-diseñados**: Crear manualmente cada mapa
2. **Generación procedural**: Algoritmos que crean mapas únicos

Para un juego competitivo PvP necesitamos:
- **Variedad**: Cada partida debe sentirse diferente
- **Balance**: Los mapas deben ser justos para ambos equipos
- **Escalabilidad**: Soportar diferentes tamaños de partida (1v1, 2v2, 4v4)

## Decisión

Implementar un **Sistema de Generación Procedural de Terreno** con soporte para diferentes biomas y tipos de mapa.

### Componentes del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                 PROCEDURAL MAP GENERATOR                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │  BiomeConfig    │    │  MapSettings    │                │
│  │  - terrain types│    │  - width/height │                │
│  │  - decoration   │    │  - seed         │                │
│  │  - colors       │    │  - symmetry     │                │
│  └────────┬────────┘    └────────┬────────┘                │
│           │                      │                          │
│           ▼                      ▼                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              NOISE-BASED GENERATION                  │   │
│  │                                                      │   │
│  │  1. Generate height map (FastNoiseLite)              │   │
│  │  2. Apply biome rules to heights                     │   │
│  │  3. Place spawn zones (symmetric)                    │   │
│  │  4. Generate decorations                             │   │
│  │  5. Validate connectivity                            │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│                          ▼                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    OUTPUT                            │   │
│  │  - TerrainGrid with hex types                        │   │
│  │  - Spawn positions for each team                     │   │
│  │  - Decoration positions                              │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Biomas Disponibles

| Bioma | Terrenos | Característica |
|-------|----------|----------------|
| **Forest** | Grass, Dense Forest, Light Forest, Water | Mucha cobertura, movimiento reducido |
| **Desert** | Sand, Rock, Dunes, Oasis | Terreno abierto, pocas obstrucciones |
| **Urban** | Pavement, Rubble, Building, Park | Estructuras de cobertura, líneas de tiro |
| **Arctic** | Snow, Ice, Frozen Lake, Rocky | Terreno resbaladizo, penalizaciones |
| **Volcanic** | Lava, Rock, Ash, Crater | Daño ambiental, terreno difícil |

### Simetría para Balance

```gdscript
# Garantizar fairness: mapa simétrico
enum SymmetryType {
    NONE,           # Sin simetría (PvE)
    ROTATIONAL,     # Rotación 180° (1v1, 2v2)
    MIRROR_X,       # Espejo horizontal
    MIRROR_Y,       # Espejo vertical
    QUAD            # 4 zonas iguales (4v4)
}

func generate_with_symmetry(settings: MapSettings) -> TerrainGrid:
    # 1. Generar solo una porción del mapa
    var half = generate_half(settings)
    
    # 2. Aplicar simetría para completar
    match settings.symmetry:
        SymmetryType.ROTATIONAL:
            return apply_rotational_symmetry(half)
        SymmetryType.MIRROR_X:
            return apply_mirror_x(half)
        # ...
```

### Seed System

```gdscript
# Mismo seed = mismo mapa
var map1 = generator.generate(seed: 12345)
var map2 = generator.generate(seed: 12345)
# map1 == map2 ✓

# En multijugador: servidor genera seed, clientes replican
@rpc("authority")
func start_match(map_seed: int, biome: String) -> void:
    var map = generator.generate(seed: map_seed, biome: biome)
    # Todos los clientes tienen el mismo mapa
```

## Consecuencias

### Positivas
- ✅ **Variedad infinita**: Cada seed genera un mapa único
- ✅ **Balance garantizado**: Simetría asegura fairness
- ✅ **Rejugabilidad**: Jugadores no memorizan mapas
- ✅ **Escalable**: Mismo sistema para diferentes tamaños
- ✅ **Determinístico**: Mismo seed = mismo resultado en todos los clientes

### Negativas
- ⚠️ **Posibles mapas "malos"**: Algunos seeds pueden generar mapas desequilibrados
- ⚠️ **Sin diseño artístico manual**: Los mapas no tienen "personalidad" diseñada
- ⚠️ **Complejidad de debugging**: Reproducir bug requiere conocer el seed

### Mitigaciones
- Sistema de "seed validation" rechaza mapas obviamente malos
- Se pueden crear "curated seeds" para mapas ranked/competitivos
- Logs siempre incluyen el seed usado

## Alternativas Consideradas

### Alternativa 1: Solo Mapas Pre-diseñados
- Diseñadores crean manualmente cada mapa
- **Rechazada**:
  - No escala (¿cuántos mapas necesitamos?)
  - Jugadores memorizan estrategias por mapa
  - Mucho trabajo de diseño manual

### Alternativa 2: Wave Function Collapse
- Algoritmo más sofisticado basado en constraints
- **Rechazada**:
  - Más lento de generar
  - Más difícil de garantizar simetría
  - Overkill para terreno hexagonal simple

### Alternativa 3: Híbrido (templates + variación)
- Templates base con variaciones procedurales
- **Considerada para futuro**:
  - Podría usarse para "mapas especiales" o eventos

## Referencias

- [Documentación del Generador](../PROCEDURAL_GENERATOR_README.md)
- [Ejemplos de Uso](../PROCEDURAL_GENERATOR_EXAMPLES.md)
- [Sistema de Terreno](../TERRAIN_GENERATION.md)
- [FastNoiseLite en Godot](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html)
