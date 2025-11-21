# Sistema de Generación Procedural de Terreno

## Filosofía de Diseño

El sistema genera mapas con **lógica y coherencia**, no completamente aleatorios. Los terrenos se agrupan de forma natural siguiendo reglas realistas.

## Proceso de Generación (6 Fases)

### FASE 1: Terreno Base Natural
- Genera terreno base usando ruido Perlin
- **Solo terrenos naturales**: agua, arena, clear, rough, colinas
- No incluye edificios, carreteras ni bosques (se agregan después)

**Distribución aproximada:**
- Agua: 5%
- Arena: 10%
- Clear (despejado): 25%
- Rough (rocoso): 20%
- Hill (colinas): 20%
- Resto: placeholder para bosques

### FASE 2: Zonas Urbanas Coherentes
- Genera **2-4 zonas urbanas** por mapa
- Cada zona tiene **3-6 edificios** agrupados
- Los edificios se colocan cerca de un centro urbano
- **Regla de distancia**: Mínimo 1 tile entre edificios (no se tocan)
- No se colocan sobre agua

**Lógica:**
```
Para cada zona urbana:
  1. Elegir centro aleatorio (alejado de bordes)
  2. Colocar 3-6 edificios en radio de 3 tiles del centro
  3. Verificar que no estén pegados a otros edificios
```

### FASE 3: Red de Carreteras

**Filosofía:** Carreteras realistas que conectan zonas urbanas sin saturación

**Proceso:**
1. Agrupar edificios en clusters por proximidad (distancia <= 6)
2. Para cada cluster, crear **árbol de expansión mínimo**
3. Conectar solo edificios adyacentes en el cluster (no todos con todos)
4. Carreteras tienen **1 tile de ancho** normalmente
5. **Ensanchar SOLO en cruces** (donde 3+ carreteras se encuentran)

**Algoritmo de clustering:**
```
Para cada edificio no asignado:
  1. Crear nuevo cluster
  2. Buscar todos los edificios a distancia <= 6
  3. Agregarlos al mismo cluster
```

**Algoritmo de conexión:**
```
Para cada cluster con 2+ edificios:
  1. Empezar con primer edificio como "conectado"
  2. Mientras haya edificios sin conectar:
     - Buscar par más cercano (conectado vs no conectado)
     - Crear carretera entre ellos (máximo 6 tiles)
     - Marcar edificio como conectado
```

**Ensanchamiento de cruces:**
- Detectar tiles de pavimento con 3+ vecinos de carretera
- Ensanchar 1 tile en todas direcciones
- Resultado: cruces más amplios y realistas

**Resultado:** 
- Red vial mínima y eficiente
- Sin saturación de carreteras
- Carreteras de 1 tile excepto en cruces
- Conecta solo edificios cercanos de la misma zona urbana

### FASE 4: Parches de Bosque
- Genera **4-7 parches de bosque** por mapa
- Cada parche tiene **3-8 tiles** de bosque
- Los bosques se expanden orgánicamente desde un centro
- 60% probabilidad de expandir a cada vecino
- No se expanden sobre agua, edificios o carreteras

**Lógica:**
```
Para cada parche:
  1. Elegir tile central aleatorio
  2. Marcar como bosque
  3. Expandir a vecinos (60% probabilidad por vecino)
  4. Repetir hasta alcanzar tamaño deseado
```

**Resultado:** Bosques en grupos naturales, no árboles sueltos

### FASE 5: Elevación Coherente

**Filosofía:** Elevaciones suaves y realistas, sin cambios bruscos

**Proceso en 2 pasos:**

**Paso 1: Asignación inicial**
- Cada tile recibe elevación base según su tipo de terreno
- Usa ruido multicapa para variación espacial
- Rangos por tipo de terreno:
  - **Agua**: -1 (bajo nivel del mar)
  - **Arena**: 0 (nivel del mar)
  - **Clear**: 0-1
  - **Rough (montañas)**: 0-2
  - **Bosque**: 0-2
  - **Colinas**: 2-4 (más alto)
  - **Edificios**: 1-3
  - **Pavimento**: 0-1

**Paso 2: Suavizado de elevaciones (3 pasadas)**
- Limita cambios de altura entre tiles vecinos
- **Restricciones por tipo de terreno:**
  - **Colinas**: Máximo 2 niveles de diferencia con vecinos
  - **Montañas (rough)**: Máximo 3 niveles de diferencia
  - **Agua**: Máximo 1 nivel de diferencia (muy plana)
  - **Urbano (pavement/building)**: Máximo 1 nivel (terreno plano)
  - **Resto**: Máximo 2 niveles de diferencia

**Algoritmo de suavizado:**
```
Para cada tile:
  1. Obtener elevaciones de vecinos
  2. Determinar max_change según tipo de terreno
  3. Si diferencia > max_change:
     - Ajustar elevación para respetar límite
  4. Repetir 3 veces para convergencia
```

**Resultado:**
- Transiciones suaves entre elevaciones
- Montañas realistas (no muros verticales)
- Zonas urbanas planas
- Coherencia espacial garantizada

### FASE 6: Marcado de Transitabilidad
- Marca qué tiles son caminables
- Solo el agua no es transitable
- Todos los demás terrenos (incluso edificios) son transitables con penalizaciones

## Ventajas del Sistema

✅ **Zonas urbanas realistas**: Edificios agrupados en clusters coherentes

✅ **Carreteras eficientes**: Red mínima sin saturación, 1 tile de ancho (excepto cruces)

✅ **Cruces amplios**: Se ensanchan automáticamente donde se encuentran 3+ carreteras

✅ **Bosques naturales**: Parches orgánicos, no árboles individuales

✅ **Elevación suave**: Sin cambios bruscos, transiciones graduales

✅ **Terreno coherente**: Colinas máximo 2 niveles de diferencia, montañas máximo 3

✅ **Variedad garantizada**: Cada mapa tiene elementos urbanos y naturales balanceados

## Parámetros Configurables

```gdscript
# Zonas urbanas
var num_urban_zones = randi_range(2, 4)      # Número de ciudades
var zone_size = randi_range(3, 6)            # Edificios por ciudad
var min_building_distance = 1                # Tiles entre edificios

# Carreteras
var road_min_distance = 3                    # Distancia mínima para conectar
var road_max_distance = 8                    # Distancia máxima para conectar
var road_probability = 0.4                   # 40% probabilidad de conexión

# Bosques
var num_forest_patches = randi_range(4, 7)   # Número de parches
var patch_size = randi_range(3, 8)           # Tiles por parche
var expansion_probability = 0.6              # 60% probabilidad de expandir
```

## Ejemplo Visual

```
Mapa generado típico (12x16):

  ~~~~  # Agua (bordes)
  ....  # Clear (áreas abiertas)
  ^^^^  # Rough (zonas rocosas)
  ▲▲▲▲  # Hills (colinas agrupadas)
  ♣♣♣♣  # Forest (parches de bosque)
  ■-■-  # Building + Pavement (ciudad con carreteras)
  -■-■  # Red urbana coherente
```

## Mejoras Futuras Posibles

- [ ] Ríos que conectan cuerpos de agua
- [ ] Puentes que cruzan agua
- [ ] Elevación correlacionada entre vecinos (montañas más suaves)
- [ ] Zonas específicas (industrial, residencial, comercial)
- [ ] Vegetación según clima (desierto vs bosque templado)
- [ ] Ruinas/edificios destruidos
