# Configuración de Múltiples Unidades

## Sistema Escalable para 1-4+ Mechs por Equipo

El sistema de batalla está completamente preparado para escalar desde 1v1 hasta 4v4 o más. Todos los sistemas clave están diseñados para manejar múltiples unidades automáticamente.

## Cómo Añadir Más Mechs

### En `battle_scene.gd` - Función `_setup_battle()`

```gdscript
func _setup_battle():
    # Equipo del jugador
    _create_player_mech("Atlas", Vector2i(2, 8), 100, 3, 5, 0)
    _create_player_mech("Timber Wolf", Vector2i(3, 8), 75, 4, 6, 0)
    _create_player_mech("Hunchback", Vector2i(4, 8), 50, 4, 6, 3)
    _create_player_mech("Locust", Vector2i(5, 8), 20, 8, 12, 8)
    
    # Equipo enemigo
    _create_enemy_mech("Mad Cat", Vector2i(8, 8), 75, 4, 6, 0)
    _create_enemy_mech("Dire Wolf", Vector2i(9, 8), 100, 3, 5, 0)
    _create_enemy_mech("Stinger", Vector2i(10, 8), 20, 6, 9, 6)
    _create_enemy_mech("Vulture", Vector2i(11, 8), 60, 5, 8, 5)
    
    turn_manager.start_battle(player_mechs, enemy_mechs)
```

### Parámetros de `_create_player_mech()` y `_create_enemy_mech()`

```gdscript
_create_player_mech(
    name: String,        # Nombre del mech (ej: "Atlas")
    position: Vector2i,  # Posición inicial en hexágonos (ej: Vector2i(2, 8))
    tonnage: int,        # Tonelaje (20-100, afecta durabilidad)
    walk: int,           # Puntos de movimiento caminando (1-8)
    run: int,            # Puntos de movimiento corriendo (walk * 1.5-2)
    jump: int            # Puntos de movimiento saltando (0-8)
)
```

## Posicionamiento Recomendado

### Mapa Pequeño (12x12 hexágonos)
- **1v1**: Separación de 6-8 hexágonos
- **2v2**: Formación en línea o diagonal
  - Player: Vector2i(2, 7), Vector2i(3, 8)
  - Enemy: Vector2i(9, 7), Vector2i(10, 8)
- **3v3**: Formación en "V" o línea
  - Player: Vector2i(2, 7), Vector2i(3, 8), Vector2i(2, 9)
  - Enemy: Vector2i(9, 7), Vector2i(10, 8), Vector2i(9, 9)
- **4v4**: Formación en cuadrado o dos líneas
  - Player: Vector2i(2, 7), Vector2i(3, 7), Vector2i(2, 9), Vector2i(3, 9)
  - Enemy: Vector2i(9, 7), Vector2i(10, 7), Vector2i(9, 9), Vector2i(10, 9)

## Sistemas Automáticos

### ✅ Turn Manager
- **Orden de activación**: Alterna automáticamente entre equipos
- **Movimiento**: El ganador de iniciativa mueve último (BattleTech)
- **Ataque**: El ganador de iniciativa ataca primero
- **Ejemplo 2v2**: Enemy1 → Player1 → Enemy2 → Player2

### ✅ IA
- **Selección de objetivos**: Busca automáticamente el jugador más cercano
- **Movimiento**: Se mueve hacia el objetivo más cercano
- **Combate**: Dispara todas las armas en rango al objetivo más cercano
- **Escala**: Funciona con cualquier número de jugadores

### ✅ Condiciones de Victoria
- **Victoria**: Todas las unidades enemigas destruidas
- **Derrota**: Todas las unidades del jugador destruidas
- **Funciona con**: Cualquier número de unidades por equipo

### ✅ UI y Visualización
- **Overlays**: Muestra hexágonos alcanzables y objetivos válidos
- **Información**: Panel de información actualiza según unidad activa
- **Selección**: Sistema de clic funciona con múltiples unidades
- **Cámara**: Sistema de cámara funciona independientemente del número de mechs

## Tipos de Mechs Recomendados (BattleTech)

### Peso Ligero (20-35 tons)
- **Locust**: 20 tons, 8/12/8 MP, Scout rápido
- **Stinger**: 20 tons, 6/9/6 MP, Scout con jump
- **Spider**: 30 tons, 8/12/8 MP, Mech de reconocimiento

### Peso Medio (40-55 tons)
- **Hunchback**: 50 tons, 4/6/3 MP, Heavy weapons
- **Shadowhawk**: 55 tons, 5/8/5 MP, Versátil
- **Griffin**: 55 tons, 5/8/5 MP, Soporte a largo alcance

### Peso Pesado (60-75 tons)
- **Timber Wolf (Mad Cat)**: 75 tons, 4/6/0 MP, Clan Heavy
- **Marauder**: 75 tons, 4/6/0 MP, Soporte pesado
- **Warhammer**: 70 tons, 4/6/0 MP, Brawler pesado

### Peso Asalto (80-100 tons)
- **Atlas**: 100 tons, 3/5/0 MP, Mech de asalto definitivo
- **Dire Wolf**: 100 tons, 3/5/0 MP, Clan Assault
- **Awesome**: 80 tons, 3/5/0 MP, Soporte de energía

## Balanceo de Combate

### Puntos de Batalla (BV - Battle Value)
Para combates equilibrados, usa puntos de batalla similares:

- **Locust**: ~400 BV
- **Hunchback**: ~1,000 BV
- **Timber Wolf**: ~2,200 BV
- **Atlas**: ~1,800 BV

### Ejemplos de Escenarios Balanceados

#### Escenario 1: Scout vs Scout (1v1)
- Player: 1x Locust (400 BV)
- Enemy: 1x Stinger (400 BV)

#### Escenario 2: Lance Equilibrado (4v4)
- Player Lance:
  - 1x Atlas (1,800 BV)
  - 1x Hunchback (1,000 BV)
  - 2x Locust (800 BV)
  - **Total: 3,600 BV**
- Enemy Lance:
  - 1x Timber Wolf (2,200 BV)
  - 1x Griffin (1,200 BV)
  - 1x Spider (200 BV)
  - **Total: 3,600 BV**

#### Escenario 3: Asalto Pesado (2v2)
- Player: 2x Atlas (3,600 BV)
- Enemy: 2x Timber Wolf (4,400 BV) - Ventaja enemiga

## Notas de Desarrollo

### Límites del Sistema
- **Recomendado**: 4v4 (8 unidades totales)
- **Máximo probado**: No hay límite técnico
- **Performance**: Depende del hardware del dispositivo

### Futuras Mejoras
- [ ] Sistema de carga de escenarios desde archivos JSON
- [ ] Editor de escenarios en el juego
- [ ] Sistema de BV (Battle Value) automático
- [ ] Balanceo dinámico de equipos
- [ ] Modo campaña con progresión de lance
- [ ] Personalización de mechs (armas, equipo)

### Compatibilidad
- ✅ Android (optimizado para móvil)
- ✅ PC (desarrollo)
- ✅ Touch y Mouse
- ✅ Resoluciones variables

## Ejemplo Completo: Escenario 3v3

```gdscript
func _setup_battle():
    # Lance del Jugador: Equilibrado
    _create_player_mech("Atlas", Vector2i(2, 7), 100, 3, 5, 0)      # Asalto
    _create_player_mech("Hunchback", Vector2i(3, 8), 50, 4, 6, 3)   # Pesado
    _create_player_mech("Locust", Vector2i(2, 9), 20, 8, 12, 8)     # Scout
    
    # Lance Enemigo: Velocidad
    _create_enemy_mech("Timber Wolf", Vector2i(9, 7), 75, 4, 6, 0)  # Pesado
    _create_enemy_mech("Griffin", Vector2i(10, 8), 55, 5, 8, 5)     # Medio
    _create_enemy_mech("Spider", Vector2i(9, 9), 30, 8, 12, 8)      # Scout
    
    turn_manager.start_battle(player_mechs, enemy_mechs)
```

Este escenario ofrece:
- **Player**: Poder de fuego superior (Atlas + Hunchback)
- **Enemy**: Mayor movilidad (todos con MP alto)
- **Estrategia**: Player debe usar el Atlas como ancla mientras el Locust flanquea
