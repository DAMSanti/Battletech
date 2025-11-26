# Configuración Multiplayer Online

## Arquitectura del Sistema

El sistema multiplayer usa **ENet** con un **servidor dedicado autoritativo**. Los clientes se conectan al servidor, que valida todas las acciones y sincroniza el estado de la partida.

```
┌─────────────┐         ┌─────────────────────┐         ┌─────────────┐
│  Cliente 1  │◄───────►│  Servidor Dedicado  │◄───────►│  Cliente 2  │
│  (Player)   │  ENet   │  (DigitalOcean)     │  ENet   │  (Enemy)    │
└─────────────┘  UDP    └─────────────────────┘  UDP    └─────────────┘
```

## Archivos del Sistema

```
scripts/network/
├── network_manager.gd      # Autoload - Gestión de conexiones y matchmaking
├── server_main.gd          # Punto de entrada del servidor headless
├── server_battle_manager.gd # Lógica de batalla en servidor (autoritativo)
└── network_battle_client.gd # Cliente de batalla (envía peticiones, recibe resultados)

scenes/
├── server_main.tscn        # Escena del servidor
└── multiplayer_lobby.tscn  # UI del lobby de matchmaking

server/
├── Dockerfile              # Imagen Docker para el servidor
├── docker-compose.yml      # Configuración de despliegue
└── deploy.ps1              # Script de despliegue a DigitalOcean
```

## Flujo de Conexión

1. **Cliente abre lobby** → Muestra UI de conexión
2. **Cliente conecta** → `NetworkManager.connect_to_server(ip, port, name)`
3. **Servidor acepta** → `peer_connected` signal
4. **Cliente se registra** → RPC `server_register_player(name)`
5. **Cliente entra a cola** → RPC `server_join_lobby()`
6. **Matchmaking** → Servidor empareja 2 jugadores
7. **Partida inicia** → `client_match_found` RPC a ambos
8. **Batalla** → Todas las acciones via RPC al servidor

## Flujo de Batalla (Servidor Autoritativo)

### Despliegue
```
Cliente → server_request_deploy_mech(match_id, mech_data, hex, facing)
Servidor → Valida zona → Crea mech → client_mech_deployed() a ambos
```

### Movimiento
```
Cliente → server_request_move(match_id, mech_id, target_hex, movement_type)
Servidor → Valida MPs y path → Aplica movimiento → client_mech_moved() a ambos
```

### Ataque con Armas
```
Cliente → server_request_fire(match_id, attacker_id, target_id, weapon_indices)
Servidor → Calcula to-hit → Tira dados → Aplica daño → client_weapons_fired() a ambos
```

## RPCs Principales

### Cliente → Servidor
| RPC | Descripción |
|-----|-------------|
| `server_register_player(name)` | Registra nombre del jugador |
| `server_join_lobby()` | Entra a cola de matchmaking |
| `server_leave_lobby()` | Sale de la cola |
| `server_request_deploy_mech(...)` | Despliega un mech |
| `server_request_move(...)` | Solicita movimiento |
| `server_request_rotate(...)` | Solicita rotación |
| `server_request_fire(...)` | Solicita disparo |
| `server_request_physical_attack(...)` | Solicita ataque físico |
| `server_request_end_activation(...)` | Termina activación |

### Servidor → Cliente
| RPC | Descripción |
|-----|-------------|
| `client_registration_confirmed(peer_id)` | Confirma registro |
| `client_lobby_update(players)` | Actualiza lista de cola |
| `client_match_found(match_id, team, opponent)` | Partida encontrada |
| `client_start_deployment(match_id, team)` | Inicio de despliegue |
| `client_mech_deployed(...)` | Mech desplegado |
| `client_initiative_result(result)` | Resultado de iniciativa |
| `client_phase_changed(phase, turn)` | Cambio de fase |
| `client_unit_activated(mech_id, is_mine)` | Unidad activada |
| `client_mech_moved(result)` | Movimiento ejecutado |
| `client_weapons_fired(result)` | Resultado de disparo |
| `client_battle_ended(winner, reason)` | Fin de batalla |

---

# Despliegue en DigitalOcean

## Requisitos

- Droplet Ubuntu 22.04 (mínimo 1GB RAM, 1 vCPU)
- Docker instalado en el Droplet
- Puerto 7777/UDP abierto en firewall
- Godot 4.x con export templates de Linux

## Pasos Rápidos

### 1. Crear Droplet en DigitalOcean

```bash
# En el panel de DigitalOcean:
# - Create Droplet
# - Ubuntu 22.04
# - Basic plan ($6/mes es suficiente)
# - Datacenter cercano a tus jugadores
# - SSH Key authentication
```

### 2. Configurar Droplet

```bash
# Conectar por SSH
ssh root@TU_IP

# Instalar Docker
curl -fsSL https://get.docker.com | sh

# Crear directorio
mkdir -p /opt/battletech

# Abrir puerto UDP
ufw allow 7777/udp
```

### 3. Exportar y Desplegar

```powershell
# Desde tu PC (en el directorio del proyecto)
.\server\deploy.ps1 -ServerIP TU_IP_DIGITALOCEAN
```

### 4. Verificar

```bash
# Ver logs del servidor
ssh root@TU_IP 'docker logs -f battletech-server'

# Debería mostrar:
# ========================================
#   BATTLETECH DEDICATED SERVER
#   Version: 1.0.0
# ========================================
# [SERVER] Dedicated server started on port 7777
# [SERVER] Waiting for connections...
```

## Comandos Útiles

```bash
# Reiniciar servidor
ssh root@TU_IP 'cd /opt/battletech && docker-compose restart'

# Detener servidor
ssh root@TU_IP 'cd /opt/battletech && docker-compose down'

# Ver estado
ssh root@TU_IP 'docker ps'

# Actualizar servidor (después de nuevo deploy.ps1)
ssh root@TU_IP 'cd /opt/battletech && docker-compose pull && docker-compose up -d'
```

## Configuración del Cliente

En el juego, los jugadores deben:

1. Ir a **Multiplayer** en el menú principal
2. Ingresar la IP del servidor: `TU_IP_DIGITALOCEAN`
3. Escribir su nombre
4. Hacer clic en **Connect**
5. Hacer clic en **Join Matchmaking**
6. Esperar a que otro jugador se una

---

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
