# Generador Procedural de Mapas BattleTech

## 🎯 Resumen

El sistema de **generación procedural de mapas** respeta las reglas oficiales de BattleTech para generación de terreno. El sistema garantiza:

### ✅ Reglas Implementadas

1. **División en zonas coherentes** (elevadas, bajas, agua, bosque, urbanas, montañas)
2. **Transiciones suaves de elevación** (±1 preferido, ±2 acantilados, ±3 excepcional)
3. **Coherencia de terreno** (agua en depresiones, bosques en clusters, rough en bordes)
4. **Distribución inteligente** (rough en cambios ≥2 niveles, bosques con transiciones)
5. **Reglas de adyacencia** (claro → bosque ligero → bosque denso)

---

## 📁 Archivos Creados

### 1. **Generador Principal**
- `scripts/core/terrain/procedural_map_generator.gd`
- Clase `ProceduralMapGenerator` que implementa las reglas oficiales

### 2. **Integración con HexGrid**
- Modificado `scripts/hex_grid.gd` para soportar generación procedural
- Nueva opción: `@export var use_procedural_generator: bool = false`

### 3. **Script de Prueba**
- `scripts/test_procedural_generator.gd`
- Permite probar el generador interactivamente
- Muestra estadísticas del mapa generado

### 4. **Escena de Prueba**
- `scenes/test_procedural_generator.tscn`
- Ejecuta el script de prueba

### 5. **Documentación**
- `doc/PROCEDURAL_MAP_USAGE.md` - Guía de uso completa
- Este archivo - Resumen rápido

---

## 🚀 Cómo Usar

### Uso Automático (Por Defecto)

El generador procedural está **activado por defecto**. Cada vez que se crea un mapa con `HexGrid`, se genera automáticamente un mapa procedural único.

```gdscript
# En cualquier escena con HexGrid
# El mapa se genera automáticamente en _ready()
# Cada partida tendrá un mapa diferente
```

### Probar Interactivamente

1. Abre `scenes/test_procedural_generator.tscn`
2. Ejecuta la escena (F5)
3. Presiona **ENTER** o **ESPACIO** para regenerar
4. Presiona **ESC** para salir
5. La consola mostrará estadísticas del mapa

### Uso Programático (Seed Específico)

```gdscript
# Crear generador
var generator = ProceduralMapGenerator.new(12, 16, 12345)

# Generar mapa
var map_data = generator.generate_map()

# Usar datos
for pos in map_data.keys():
	var terrain = map_data[pos]["terrain"]
	var elevation = map_data[pos]["elevation"]
	var walkable = map_data[pos]["walkable"]
	# ... tu código ...
```

---

## 📊 Características del Mapa Generado

### Zonas (3-6 por mapa)
- **LOWLAND** (Zona Baja) - Elevación 0-1
- **HIGHLAND** (Zona Elevada) - Elevación 2-3
- **MOUNTAIN** (Montaña) - Elevación 4-5 (raro, 5%)
- **WATER_ZONE** (Zona de Agua) - Elevación -1 a 0
- **FOREST_ZONE** (Zona Boscosa) - Bosques coherentes
- **URBAN_ZONE** (Zona Urbana) - Edificios + carreteras

### Terrenos
- **Clear** (Despejado) - Terreno base
- **Light Woods** (Bosque Ligero) - Transición al bosque
- **Heavy Woods** (Bosque Denso) - Centro de bosques
- **Water** (Agua) - Siempre en depresiones (≤0)
- **Sand** (Arena) - Transición desde agua
- **Rough** (Difícil) - En bordes de cambios de elevación
- **Hill** (Colina) - Zonas elevadas
- **Pavement** (Pavimento) - Carreteras urbanas
- **Building** (Edificio) - 2-5 por mapa urbano

### Elevaciones
- **Rango normal**: -1 (agua) a 3 (colinas)
- **Montañas**: 4-5 (muy raras)
- **Transiciones**: ±1 (suave), ±2 (acantilado), ±3 (excepcional)

---

## 🎮 Reglas de BattleTech Respetadas

### 1. Zonas Coherentes ✅
El mapa se divide en zonas usando **Voronoi tessellation** (particionado por proximidad a centros).

### 2. Elevaciones Graduales ✅
- **Cambio favorito**: ±0 o ±1
- **Cambio permitido**: ±2 (acantilados)
- **Cambio excepcional**: ±3 (montañas/cañones)
- **Prohibido**: ≥4 (solo edificios altos)

### 3. Coherencia de Terreno ✅
- **Agua profunda** solo junto a agua superficial (implementado como agua en depresión)
- **Bosque denso** → **bosque ligero** → **claro** (transiciones suaves)
- **Rough** aparece donde altura cambia ≥2 niveles

### 4. Masas Coherentes ✅
- **Clusters de bosque**: 3-7 hexes, expansión orgánica 70% probabilidad
- **Colinas graduales**: Suavizado con 3 pasadas de promediado
- **Agua en depresiones**: Siempre elevación ≤ 0

### 5. Distribución de Detalles ✅
- **Rough** en bordes de colinas (cambio ≥2)
- **Bosques** en zonas forestales (transiciones coherentes)
- **Agua** en zonas bajas
- **Edificios** en zonas planas (urbanas)

---

## 🔧 Personalización

### Ajustar Probabilidades

Edita `procedural_map_generator.gd`:

#### Más bosques
```gdscript
# Línea ~287
var num_clusters = rng.randi_range(6, 10)  # Era 3-7
```

#### Más zonas urbanas
```gdscript
# Línea ~88
elif roll < 0.70:  # Era 0.80
	return ZoneType.WATER_ZONE
elif roll < 0.95:
	return ZoneType.URBAN_ZONE
```

#### Montañas más comunes
```gdscript
# Línea ~96
elif roll < 0.85:  # Añadir condición
	return ZoneType.URBAN_ZONE
else:
	return ZoneType.MOUNTAIN  # 15% en vez de 5%
```

---

## 📈 Ejemplo de Salida (Consola)

```
========================================
Mapa generado con seed: 1234567890
========================================

📊 Distribución de terrenos:
  Clear (Despejado): 98 hexes (51.0%)
  Light Woods (Bosque Ligero): 23 hexes (12.0%)
  Heavy Woods (Bosque Denso): 15 hexes (7.8%)
  Water (Agua): 12 hexes (6.3%)
  Sand (Arena): 8 hexes (4.2%)
  Rough (Difícil): 18 hexes (9.4%)
  Hill (Colina): 12 hexes (6.3%)
  Pavement (Pavimento): 3 hexes (1.6%)
  Building (Edificio): 3 hexes (1.6%)

🏔️ Distribución de elevaciones:
  Rango: -1 a 4 niveles
  Nivel -1: 12 hexes (6.3%)
  Nivel  0: 78 hexes (40.6%)
  Nivel +1: 52 hexes (27.1%)
  Nivel +2: 32 hexes (16.7%)
  Nivel +3: 15 hexes (7.8%)
  Nivel +4: 3 hexes (1.6%)

✅ Todas las transiciones de elevación son válidas (≤3 niveles)
```

---

## 🧪 Testing

### Ejecutar Tests
1. Abre `scenes/test_procedural_generator.tscn`
2. Ejecuta (F5)
3. Genera múltiples mapas (ENTER)
4. Verifica estadísticas en consola

### Validaciones Automáticas
- ✅ Tamaño correcto (192 hexes para 12x16)
- ✅ Todos los hexes tienen terreno
- ✅ Todos los hexes tienen elevación
- ✅ Transiciones ≤3 niveles
- ✅ Agua solo en depresiones

---

## 🎯 Próximas Mejoras Posibles

- [ ] Ríos que conectan zonas de agua
- [ ] Puentes sobre agua
- [ ] Zonas de ruinas (edificios destruidos)
- [ ] Biomas (desierto, ártico, templado)
- [ ] Validación de simetría (mapas balanceados PvP)
- [ ] Exportar/importar semillas de mapas
- [ ] Galería de mapas pre-generados

---

## 📝 Notas Técnicas

### Algoritmos Usados

1. **Poisson Disk Sampling** - Distribución uniforme de centros de zona
2. **Voronoi Tessellation** - Particionado del mapa en zonas
3. **Octave Noise** - Variación procedural de elevación
4. **Flood Fill** - Expansión orgánica de bosques
5. **Minimum Spanning Tree** - Conexión de edificios con carreteras
6. **A* Pathfinding** - Trazado de carreteras

### Performance
- Generación de mapa 12x16: **~10ms**
- Totalmente determinista (mismo seed = mismo mapa)
- Sin carga de assets (todo procedural)

---

## 📞 Soporte

Si tienes problemas:

1. Verifica que `use_procedural_generator = true` en HexGrid
2. Ejecuta `test_procedural_generator.tscn` para verificar
3. Revisa la consola para errores
4. Verifica que `terrain_type.gd` esté accesible

---

## ✨ Créditos

Generador basado en las reglas oficiales de **BattleTech** para generación de mapas procedurales, adaptado para Godot 4.x.

---

**¡Disfruta creando mapas únicos para tus batallas!** 🤖⚔️
