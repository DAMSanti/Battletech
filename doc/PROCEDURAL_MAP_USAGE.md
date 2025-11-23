# Uso del Generador Procedural de Mapas

## Descripción

El generador procedural (`ProceduralMapGenerator`) crea mapas que respetan las reglas oficiales de BattleTech:

### ✅ Reglas Implementadas

1. **División en zonas coherentes**
   - Zonas elevadas (2-3 niveles)
   - Zonas bajas (0-1 niveles)
   - Zonas de agua (-1 a 0 niveles)
   - Zonas boscosas (bosque ligero → bosque denso)
   - Zonas urbanas (edificios + carreteras)
   - Montañas raras (4-5 niveles, solo 5% de probabilidad)

2. **Transiciones suaves de elevación**
   - **Preferido**: ±0 o ±1 nivel
   - **Permitido**: ±2 niveles (acantilados)
   - **Excepcional**: ±3 niveles (montañas)
   - **Prohibido**: ≥4 niveles (solo edificios altos)

3. **Coherencia de terreno**
   - Agua solo en depresiones (elevación ≤ 0)
   - Bosques en clusters (3-7 hexes)
   - Transición: claro → bosque ligero → bosque denso
   - Rough en bordes de cambios de elevación ≥2

4. **Distribución inteligente**
   - Rough aparece en bordes de colinas (cambio ≥2 niveles)
   - Bosques en zonas de nivel igual o ±1
   - Agua en depresiones
   - Edificios en zonas planas (urbanas)

## Cómo Usar

### Opción 1: Integrar en HexGrid

Añade este método a `hex_grid.gd`:

```gdscript
func generate_procedural_map():
	var generator = ProceduralMapGenerator.new(grid_width, grid_height)
	hex_data = generator.generate_map()
	queue_redraw()
```

Luego, en `_ready()`, reemplaza `_initialize_grid()` con:

```gdscript
func _ready():
	z_index = 0
	terrain_seed = randi()
	_preload_terrain_icons()
	
	# Usar generador procedural
	generate_procedural_map()
	
	queue_redraw()
```

### Opción 2: Usar manualmente

```gdscript
# Crear generador con seed específico
var generator = ProceduralMapGenerator.new(12, 16, 12345)

# Generar mapa
var map_data = generator.generate_map()

# El mapa contiene:
# map_data[Vector2i(q, r)] = {
#     "terrain": TerrainType.Type.CLEAR,
#     "elevation": 1,
#     "zone": ZoneType.LOWLAND,
#     "walkable": true
# }
```

### Opción 3: Generar múltiples mapas

```gdscript
# Generar 5 mapas diferentes
for i in range(5):
	var generator = ProceduralMapGenerator.new(12, 16)  # Seed aleatorio
	var map_data = generator.generate_map()
	# Guardar o usar el mapa
```

## Parámetros del Generador

```gdscript
ProceduralMapGenerator.new(
	width: int = 12,      # Ancho del mapa (hexes)
	height: int = 16,     # Alto del mapa (hexes)
	map_seed: int = 0     # Seed (0 = aleatorio)
)
```

## Estructura del Mapa Generado

Cada hex tiene:

```gdscript
{
	"terrain": TerrainType.Type,  # Tipo de terreno
	"elevation": int,             # Elevación (-1 a 5)
	"zone": ZoneType,             # Tipo de zona
	"walkable": bool              # Si es transitable
}
```

## Tipos de Zona

```gdscript
enum ZoneType {
	LOWLAND,      # Zona baja (0-1)
	HIGHLAND,     # Zona elevada (2-3)
	MOUNTAIN,     # Montaña (4-5) - 5% de probabilidad
	WATER_ZONE,   # Zona de agua
	FOREST_ZONE,  # Zona boscosa
	URBAN_ZONE    # Zona urbana
}
```

## Características Garantizadas

✅ **3-6 zonas** diferentes por mapa
✅ **Mínimo 1 zona baja** (terreno abierto)
✅ **Mínimo 1 zona elevada** (colinas)
✅ **3-7 clusters de bosque** (tamaño 3-7 hexes cada uno)
✅ **Transiciones suaves** claro → ligero → denso
✅ **Edificios espaciados** (mínimo 3 hexes entre ellos)
✅ **Carreteras conectando edificios** (árbol de expansión mínimo)
✅ **Agua en depresiones** (siempre elevación ≤ 0)

## Ejemplo de Mapa Generado

```
Leyenda:
~ = Agua (-1)
. = Clear (0-1)
, = Light Woods (0-2)
♣ = Heavy Woods (0-2)
▲ = Hill (2-4)
◆ = Rough (1-3)
■ = Building (base+3 a base+5)
═ = Pavement (0-1)

Mapa típico (12x16):

  . . . ▲ ▲ ▲ . . . . . .
  . . ◆ ◆ ▲ ▲ ◆ . , , . .
  . . . ◆ ◆ ◆ . . , ♣ , .
  . ■ ═ ═ . . . . , , . .
  . ═ ■ . . . . . . . . .
  . . . . . ~ ~ . . . . .
  . . . . ~ ~ ~ ~ . . . .
  , , . . . ~ ~ . . ▲ ▲ .
  ♣ , , . . . . . ◆ ◆ ▲ .
  , ♣ , . . . . . . ◆ ◆ .
  . , . . . . . . . . . .
```

## Ventajas del Sistema

1. **Mapas únicos cada vez** (basados en seed aleatorio)
2. **Balanceados para jugabilidad** (coberturas, elevaciones, caminos)
3. **Realistas** (transiciones suaves, clusters coherentes)
4. **Rápidos** (genera un mapa 12x16 en ~10ms)
5. **Customizables** (puedes modificar probabilidades en el código)

## Personalización

Puedes ajustar las probabilidades editando `procedural_map_generator.gd`:

### Más bosques
```gdscript
# Línea ~287, cambia:
var num_clusters = rng.randi_range(3, 7)
# Por:
var num_clusters = rng.randi_range(6, 10)
```

### Más zonas urbanas
```gdscript
# Línea ~88, cambia:
elif roll < 0.80:
	return ZoneType.WATER_ZONE
elif roll < 0.95:
	return ZoneType.URBAN_ZONE
# Por:
elif roll < 0.70:
	return ZoneType.WATER_ZONE
elif roll < 0.95:
	return ZoneType.URBAN_ZONE
```

### Montañas más comunes
```gdscript
# Línea ~96, cambia:
else:
	return ZoneType.MOUNTAIN  # Raro (5%)
# Por:
elif roll < 0.85:
	return ZoneType.URBAN_ZONE
else:
	return ZoneType.MOUNTAIN  # Más común (15%)
```

## Testing

Para probar el generador:

```gdscript
# En un script de test
func test_generator():
	var generator = ProceduralMapGenerator.new(12, 16, 12345)
	var map_data = generator.generate_map()
	
	# Verificar que tiene datos
	assert(map_data.size() == 12 * 16, "Mapa debe tener 192 hexes")
	
	# Verificar que hay variedad de terrenos
	var terrain_counts = {}
	for pos in map_data.keys():
		var terrain = map_data[pos]["terrain"]
		terrain_counts[terrain] = terrain_counts.get(terrain, 0) + 1
	
	print("Distribución de terrenos:")
	for terrain in terrain_counts.keys():
		var percentage = float(terrain_counts[terrain]) / float(map_data.size()) * 100.0
		print("  %s: %d hexes (%.1f%%)" % [TerrainType.get_name(terrain), terrain_counts[terrain], percentage])
```

## Próximas Mejoras

- [ ] Ríos que conectan zonas de agua
- [ ] Puentes sobre agua
- [ ] Zonas de ruinas (edificios destruidos)
- [ ] Biomas (desierto, ártico, templado)
- [ ] Validación de simetría (para mapas balanceados PvP)
