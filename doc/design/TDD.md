# 📐 Technical Design Document (TDD)
## Steel Titans: Tactical Warfare

**Versión:** 1.0  
**Fecha:** 1 de Diciembre, 2025  
**Autor:** DAMSanti  
**Estado:** Living Document

---

## 📑 Índice

1. [Introducción](#1-introducción)
2. [Stack Tecnológico](#2-stack-tecnológico)
3. [Arquitectura del Cliente](#3-arquitectura-del-cliente)
4. [Arquitectura del Servidor](#4-arquitectura-del-servidor)
5. [Sistema de Red](#5-sistema-de-red)
6. [Persistencia de Datos](#6-persistencia-de-datos)
7. [Sistemas de Juego](#7-sistemas-de-juego)
8. [Seguridad](#8-seguridad)
9. [Testing y QA](#9-testing-y-qa)
10. [DevOps y Deployment](#10-devops-y-deployment)

---

# 1. Introducción

## 1.1 Propósito

Este documento define las especificaciones técnicas detalladas de Steel Titans, incluyendo arquitectura, protocolos, estructuras de datos y flujos de implementación.

## 1.2 Alcance

Cubre todos los componentes técnicos:
- Cliente Godot (Android/PC)
- Servidor de juego (Godot Headless)
- API REST (FastAPI)
- Base de datos (PostgreSQL)
- Cache y colas (Redis)

## 1.3 Referencias

| Documento | Descripción |
|-----------|-------------|
| [GDD.md](GDD.md) | Game Design Document |
| [SAD.md](../architecture/SAD.md) | Software Architecture Document |
| [DATABASE_SCHEMA.md](../architecture/DATABASE_SCHEMA.md) | Esquema de base de datos |
| [GUIDELINES.md](../development/GUIDELINES.md) | Guías de desarrollo |

---

# 2. Stack Tecnológico

## 2.1 Cliente

| Componente | Tecnología | Versión | Propósito |
|------------|------------|---------|-----------|
| Motor | Godot Engine | 4.5.1 | Renderizado, física, input |
| Lenguaje | GDScript | 4.x | Lógica de juego |
| Networking | ENet | Built-in | Comunicación UDP confiable |
| HTTP | HTTPRequest | Built-in | Comunicación con API REST |
| Storage | FileAccess | Built-in | Persistencia local |

## 2.2 Servidor de Juego

| Componente | Tecnología | Versión | Propósito |
|------------|------------|---------|-----------|
| Runtime | Godot Headless | 4.5.1 | Servidor autoritativo |
| Lenguaje | GDScript | 4.x | Validación y estado |
| Networking | ENet | Built-in | Gestión de clientes |

## 2.3 Backend API

| Componente | Tecnología | Versión | Propósito |
|------------|------------|---------|-----------|
| Framework | FastAPI | 0.104+ | API REST |
| Runtime | Python | 3.11+ | Backend logic |
| ORM | SQLAlchemy | 2.0+ | Database access |
| Validation | Pydantic | 2.0+ | Request/Response models |
| Auth | python-jose | 3.3+ | JWT tokens |
| Password | passlib[bcrypt] | 1.7+ | Password hashing |

## 2.4 Infraestructura

| Componente | Tecnología | Especificación | Propósito |
|------------|------------|----------------|-----------|
| Database | PostgreSQL | 15+ | Persistencia principal |
| Cache | Redis | 7+ | Sesiones, matchmaking |
| Hosting | DigitalOcean | Droplet 2GB | Servidor producción |
| Proxy | Nginx | 1.18+ | Reverse proxy, SSL |
| SSL | Let's Encrypt | Certbot | Certificados HTTPS |
| Monitoring | Sentry | Cloud | Error tracking |

## 2.5 Diagrama de Stack

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              STEEL TITANS STACK                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         CLIENTE (Godot 4.5)                          │    │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────────────┐   │    │
│  │  │  Scenes   │ │  Scripts  │ │    UI     │ │  NetworkManager   │   │    │
│  │  │  (.tscn)  │ │  (.gd)    │ │ Controls  │ │  ENet + HTTP      │   │    │
│  │  └───────────┘ └───────────┘ └───────────┘ └─────────┬─────────┘   │    │
│  └──────────────────────────────────────────────────────┼──────────────┘    │
│                                                         │                    │
│                          ┌──────────────────────────────┴─────┐              │
│                          │                                    │              │
│                    ENet (UDP:7777)                    HTTPS (443)            │
│                          │                                    │              │
│                          ▼                                    ▼              │
│  ┌──────────────────────────────────┐    ┌──────────────────────────────┐   │
│  │      GAME SERVER (Godot)         │    │      API SERVER (FastAPI)    │   │
│  │  ┌──────────────────────────┐    │    │  ┌──────────────────────┐    │   │
│  │  │   NetworkManager         │    │    │  │   Routers            │    │   │
│  │  │   ServerActionValidator  │    │    │  │   - auth_router      │    │   │
│  │  │   MatchManager           │    │    │  │   - users_router     │    │   │
│  │  └──────────────────────────┘    │    │  │   - mechs_router     │    │   │
│  │                                  │    │  │   - matchmaking      │    │   │
│  │  Port: 7777 (UDP)                │    │  │   - elo_router       │    │   │
│  └──────────────────────────────────┘    │  └──────────────────────┘    │   │
│                                          │                               │   │
│                                          │  Port: 8080 → Nginx → 443    │   │
│                                          └───────────────┬───────────────┘   │
│                                                          │                   │
│                    ┌─────────────────────────────────────┴────────┐          │
│                    │                                              │          │
│                    ▼                                              ▼          │
│  ┌──────────────────────────────┐          ┌──────────────────────────────┐ │
│  │        PostgreSQL            │          │          Redis               │ │
│  │  ┌────────────────────────┐  │          │  ┌────────────────────────┐  │ │
│  │  │ users, mechs, pilots   │  │          │  │ sessions (TTL: 24h)    │  │ │
│  │  │ matches, transactions  │  │          │  │ mm:queue:{mode}        │  │ │
│  │  │ sessions, audit_logs   │  │          │  │ mm:player:{id}         │  │ │
│  │  │ user_bans              │  │          │  │ cache:* (TTL: 5min)    │  │ │
│  │  └────────────────────────┘  │          │  └────────────────────────┘  │ │
│  │  Port: 5432                  │          │  Port: 6379                  │ │
│  └──────────────────────────────┘          └──────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# 3. Arquitectura del Cliente

## 3.1 Estructura de Directorios

```
scripts/
├── core/                    # Lógica de negocio pura (sin dependencias UI)
│   ├── game_enums.gd        # Enumeraciones centralizadas
│   ├── game_constants.gd    # Constantes del juego
│   ├── logger.gd            # Sistema de logging (autoload)
│   ├── error_handler.gd     # Manejo centralizado de errores
│   ├── auth_manager.gd      # Autenticación y sesiones
│   ├── auth_validator.gd    # Validación de credenciales
│   ├── database_manager.gd  # Cliente HTTP para API
│   ├── player_data_manager.gd # Persistencia de datos de jugador
│   ├── combat/              # Sistemas de combate
│   │   ├── weapon_system.gd
│   │   ├── weapon_attack_system.gd
│   │   └── physical_attack_system.gd
│   ├── movement/            # Sistema de movimiento
│   │   └── movement_system.gd
│   ├── heat/                # Sistema de calor
│   │   └── heat_system.gd
│   └── terrain/             # Sistema de terreno
│       └── terrain_type.gd
│
├── entities/                # Entidades de datos
│   ├── mech.gd              # Clase Mech principal
│   ├── weapon.gd            # Definición de armas
│   └── pilot.gd             # Datos de piloto
│
├── managers/                # Gestores de alto nivel
│   ├── turn_manager.gd      # Gestión de turnos
│   ├── battle_state_manager.gd
│   ├── mech_bay_manager.gd  # Gestión del hangar
│   └── battle_ai.gd         # IA para single-player
│
├── network/                 # Componentes de red
│   ├── network_manager.gd   # Singleton de networking (autoload)
│   ├── matchmaking_client.gd # Cliente de matchmaking
│   ├── reconnection_manager.gd # Reconexión automática
│   └── server_action_validator.gd # Validación server-side
│
├── ui/                      # Interfaz de usuario
│   ├── screens/             # Pantallas completas
│   │   ├── auth_screen.gd
│   │   ├── main_menu.gd
│   │   └── initiative_screen.gd
│   ├── components/          # Componentes reutilizables
│   │   ├── mech_card.gd
│   │   └── weapon_list.gd
│   ├── battle_ui.gd
│   ├── battle_overlay.gd
│   └── matchmaking_ui.gd
│
└── utils/                   # Utilidades
    ├── hex_utils.gd
    └── math_utils.gd
```

## 3.2 Autoloads (Singletons)

| Nombre | Script | Propósito |
|--------|--------|-----------|
| `Log` | `core/logger.gd` | Logging centralizado |
| `NetworkManager` | `network/network_manager.gd` | Conexiones de red |
| `AuthManager` | `core/auth_manager_singleton.gd` | Estado de autenticación |
| `AudioManager` | `managers/audio_manager.gd` | Audio global |
| `PlayerData` | `core/player_data_manager_singleton.gd` | Datos persistentes |
| `MechBayManager` | `managers/mech_bay_manager.gd` | Inventario de mechs |

## 3.3 Flujo de Escenas

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Splash     │────▶│  AuthScreen │────▶│  MainMenu   │
│  Screen     │     │  (Login)    │     │             │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
                    ▼                          ▼                          ▼
             ┌─────────────┐           ┌─────────────┐           ┌─────────────┐
             │  MechBay    │           │  Matchmaking│           │  Settings   │
             │  Screen     │           │  Screen     │           │  Screen     │
             └─────────────┘           └──────┬──────┘           └─────────────┘
                                              │
                                              ▼
                                       ┌─────────────┐
                                       │  TeamSetup  │
                                       │  Screen     │
                                       └──────┬──────┘
                                              │
                                              ▼
                                       ┌─────────────┐
                                       │  Battle     │
                                       │  Scene      │
                                       └──────┬──────┘
                                              │
                                              ▼
                                       ┌─────────────┐
                                       │  Results    │
                                       │  Screen     │
                                       └─────────────┘
```

## 3.4 Sistema de Señales

### Señales Globales (NetworkManager)

```gdscript
# Conexión
signal connected_to_server()
signal disconnected_from_server(reason: String)
signal connection_failed(reason: String)

# Matchmaking
signal matchmaking_queue_joined(position: int, estimated_wait: float)
signal matchmaking_queue_left()
signal api_match_found(match_data: Dictionary)
signal matchmaking_error(error: String)

# Partida
signal match_ready(match_id: int, team: String)
signal opponent_disconnected(opponent_id: int)
signal match_ended(result: Dictionary)

# Sincronización
signal game_state_updated(state: Dictionary)
signal turn_changed(current_player: int)
```

### Señales de Batalla (BattleScene)

```gdscript
signal mech_selected(mech: Mech)
signal hex_clicked(hex_pos: Vector2i)
signal movement_completed(mech: Mech, path: Array)
signal attack_resolved(result: Dictionary)
signal turn_ended()
```

---

# 4. Arquitectura del Servidor

## 4.1 Servidor de Juego (Godot Headless)

### Responsabilidades

1. **Autoridad de estado** - Única fuente de verdad del estado de la partida
2. **Validación** - Verificar todas las acciones de clientes
3. **Sincronización** - Broadcast de estado a todos los clientes
4. **Matchmaking local** - Emparejar jugadores conectados en lobby

### Estructura

```
server/
├── server_main.gd           # Entry point del servidor
├── network_manager.gd       # Gestión de conexiones (modo servidor)
└── server_action_validator.gd # Validación de acciones
```

### Flujo de Validación

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Cliente    │────▶│  Recepción  │────▶│  Validación │────▶│  Aplicación │
│  Envía RPC  │     │  del Server │     │  de Acción  │     │  de Estado  │
└─────────────┘     └─────────────┘     └──────┬──────┘     └──────┬──────┘
                                               │                   │
                                               ▼                   ▼
                                        ┌─────────────┐     ┌─────────────┐
                                        │  Rechazar   │     │  Broadcast  │
                                        │  si inválido│     │  a clientes │
                                        └─────────────┘     └─────────────┘
```

### Validaciones Implementadas

| Acción | Validaciones |
|--------|--------------|
| Movimiento | Distancia, terreno, ZoC, MP disponibles |
| Ataque armas | Rango, LOS, munición, armas funcionales |
| Ataque físico | Rango (adyacente), armas disponibles |
| Fin de turno | Es el turno del jugador, fase correcta |

## 4.2 API REST (FastAPI)

### Estructura del Proyecto

```
server/api/
├── main.py                  # Entry point FastAPI
├── config.py                # Configuración (settings)
├── auth.py                  # Utilidades de autenticación
├── database.py              # Configuración SQLAlchemy
├── models/                  # Modelos SQLAlchemy
│   ├── user.py
│   ├── mech.py
│   ├── pilot.py
│   ├── match.py
│   └── session.py
├── schemas/                 # Schemas Pydantic
│   ├── user.py
│   ├── auth.py
│   └── mech.py
├── routers/                 # Endpoints por dominio
│   ├── api_v1.py            # Router agregador v1
│   ├── auth_router.py
│   ├── users_router.py
│   ├── mechs_router.py
│   ├── pilots_router.py
│   ├── matchmaking_router.py
│   ├── elo_router.py
│   ├── bans_router.py
│   ├── audit_router.py
│   ├── stats_router.py
│   └── health_router.py
├── middleware/
│   └── rate_limiter.py
├── services/
│   └── redis_manager.py
└── requirements.txt
```

### Endpoints Principales

#### Autenticación (`/api/v1/auth`)

| Método | Endpoint | Descripción | Auth |
|--------|----------|-------------|------|
| POST | `/register` | Registro de usuario | No |
| POST | `/login` | Login con credenciales | No |
| POST | `/guest` | Login como invitado | No |
| POST | `/refresh` | Renovar access token | Sí |
| POST | `/logout` | Cerrar sesión | Sí |

#### Usuarios (`/api/v1/users`)

| Método | Endpoint | Descripción | Auth |
|--------|----------|-------------|------|
| GET | `/me` | Datos del usuario actual | Sí |
| PUT | `/me` | Actualizar perfil | Sí |
| GET | `/{id}` | Datos de otro usuario | Sí |

#### Matchmaking (`/api/v1/queue`)

| Método | Endpoint | Descripción | Auth |
|--------|----------|-------------|------|
| POST | `/join` | Unirse a cola | Sí |
| POST | `/leave` | Abandonar cola | Sí |
| GET | `/status` | Estado en cola | Sí |
| GET | `/check-match` | Verificar si hay match | Sí |
| POST | `/accept` | Aceptar partida | Sí |
| POST | `/decline` | Rechazar partida | Sí |

#### ELO (`/api/v1/elo`)

| Método | Endpoint | Descripción | Auth |
|--------|----------|-------------|------|
| GET | `/rating/{user_id}` | Rating de usuario | Sí |
| GET | `/leaderboard` | Top jugadores | No |
| POST | `/report-match` | Reportar resultado | Sí (Server) |

---

# 5. Sistema de Red

## 5.1 Protocolos

| Protocolo | Uso | Puerto | Características |
|-----------|-----|--------|-----------------|
| ENet/UDP | Gameplay en tiempo real | 7777 | Confiable, ordenado, baja latencia |
| HTTPS | API REST | 443 | Seguro, stateless |
| WebSocket | (Futuro) Chat, notificaciones | 443 | Bidireccional, persistente |

## 5.2 ENet - Configuración

```gdscript
# Cliente
var peer = ENetMultiplayerPeer.new()
peer.create_client(server_ip, 7777)
multiplayer.multiplayer_peer = peer

# Servidor  
var peer = ENetMultiplayerPeer.new()
peer.create_server(7777, MAX_CLIENTS)
multiplayer.multiplayer_peer = peer
```

### Canales ENet

| Canal | Propósito | Modo |
|-------|-----------|------|
| 0 | Control (conexión, auth) | Reliable |
| 1 | Estado de juego | Reliable Ordered |
| 2 | Acciones de jugador | Reliable |
| 3 | Chat | Reliable |

## 5.3 RPC - Definiciones

### Cliente → Servidor

```gdscript
# Registro de jugador
@rpc("any_peer", "reliable")
func server_register_player(player_name: String) -> void

# Solicitar movimiento
@rpc("any_peer", "reliable")  
func server_request_move(mech_id: int, path: Array[Vector2i], move_type: int) -> void

# Solicitar ataque
@rpc("any_peer", "reliable")
func server_request_attack(attacker_id: int, target_id: int, weapon_index: int) -> void

# Fin de turno
@rpc("any_peer", "reliable")
func server_end_turn() -> void
```

### Servidor → Cliente(s)

```gdscript
# Confirmar registro
@rpc("authority", "reliable")
func client_registration_confirmed(peer_id: int) -> void

# Estado del lobby
@rpc("authority", "reliable")
func client_lobby_state(lobby_info: Dictionary) -> void

# Partida encontrada
@rpc("authority", "reliable")
func client_match_found(match_id: int, team: String, opponent: String, seed: int) -> void

# Actualizar estado de mech
@rpc("authority", "reliable")
func client_mech_state_update(mech_id: int, state: Dictionary) -> void

# Resultado de ataque
@rpc("authority", "reliable")
func client_attack_result(result: Dictionary) -> void
```

## 5.4 Reconexión Automática

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Desconexión │────▶│  Guardar    │────▶│  Intentar   │
│ Detectada   │     │  Estado     │     │  Reconexión │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                         ┌─────────────────────┼─────────────────────┐
                         │                     │                     │
                         ▼                     ▼                     ▼
                  ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
                  │  Éxito      │       │  Reintento  │       │  Fallo      │
                  │  Restaurar  │       │  (max 5)    │       │  Mostrar    │
                  │  Estado     │       │  Backoff    │       │  Error      │
                  └─────────────┘       └─────────────┘       └─────────────┘
```

### Parámetros de Reconexión

```gdscript
const MAX_RECONNECTION_ATTEMPTS := 5
const INITIAL_BACKOFF_MS := 1000
const MAX_BACKOFF_MS := 30000
const BACKOFF_MULTIPLIER := 2.0
```

---

# 6. Persistencia de Datos

## 6.1 Almacenamiento Local (Cliente)

### Ubicación

```
user://                          # Godot user data directory
├── settings.cfg                 # Configuración del juego
├── player_data.json             # Datos del jugador (offline)
├── hangar.json                  # Mechs del jugador
└── logs/                        # Logs locales
    └── game_YYYYMMDD.log
```

### Formato de PlayerData

```json
{
  "version": "1.0.0",
  "user_id": "uuid",
  "username": "Player1",
  "last_sync": 1701432000,
  "currency": {
    "c_bills": 50000,
    "premium": 0
  },
  "stats": {
    "matches_played": 42,
    "wins": 25,
    "losses": 17,
    "elo_rating": 1250
  },
  "preferences": {
    "music_volume": 0.8,
    "sfx_volume": 1.0,
    "language": "es"
  },
  "checksum": "sha256..."
}
```

## 6.2 Base de Datos (Servidor)

Ver documento completo: [DATABASE_SCHEMA.md](../architecture/DATABASE_SCHEMA.md)

### Tablas Principales

| Tabla | Propósito | Registros esperados |
|-------|-----------|---------------------|
| `users` | Cuentas de usuario | 10K-100K |
| `mechs` | Mechs de usuarios | 50K-500K |
| `pilots` | Pilotos de usuarios | 20K-200K |
| `matches` | Historial de partidas | 100K-1M |
| `sessions` | Sesiones activas | 1K-10K |
| `audit_logs` | Logs de auditoría | 1M+ |

## 6.3 Redis (Cache y Colas)

### Estructuras de Datos

```
# Sesiones de usuario
session:{user_id} = {token, expires, ...}  [TTL: 24h]

# Cola de matchmaking
mm:queue:{mode} = ZSET(user_id, timestamp)

# Datos de jugador en cola
mm:player:{user_id} = HASH(elo, mode, joined_at)

# Match encontrado
mm:match_found:{user_id} = {match_id, opponent_id, server_ip}  [TTL: 60s]

# Cache de usuario
cache:user:{user_id} = {user_data}  [TTL: 5min]
```

---

# 7. Sistemas de Juego

## 7.1 Sistema de Combate

### Resolución de Ataque

```
Tirada = 2d6
Objetivo = 4 + Gunnery + Modificadores

Si Tirada >= Objetivo → Impacto
```

### Modificadores de Ataque

| Fuente | Modificador |
|--------|-------------|
| Gunnery del piloto | +Gunnery |
| Movimiento atacante (Walk) | +1 |
| Movimiento atacante (Run) | +2 |
| Movimiento atacante (Jump) | +3 |
| Movimiento objetivo (Walk) | +1 |
| Movimiento objetivo (Run/Jump) | +2 |
| Terreno (Bosque ligero) | +1 |
| Terreno (Bosque denso) | +2 |
| Rango (Corto) | +0 |
| Rango (Medio) | +2 |
| Rango (Largo) | +4 |
| Calor atacante (15-17) | +1 |
| Calor atacante (18-23) | +2 |
| Calor atacante (24+) | +3 |

### Tabla de Localizaciones

```
2d6  | Ubicación
-----|------------------
2    | Torso Central (Crítico)
3    | Brazo Derecho
4    | Brazo Derecho
5    | Pierna Derecha
6    | Torso Derecho
7    | Torso Central
8    | Torso Izquierdo
9    | Pierna Izquierda
10   | Brazo Izquierdo
11   | Brazo Izquierdo
12   | Cabeza
```

## 7.2 Sistema de Movimiento

### Tipos de Movimiento

| Tipo | MP | Modificador Ataque | Modificador Defensa | Calor |
|------|----|--------------------|---------------------|-------|
| Estacionario | 0 | +0 | +0 | 0 |
| Walk | Base | +1 | +1 | 0 |
| Run | Base×1.5 | +2 | +2 | +2 |
| Jump | Variable | +3 | +3 | +Jets |

### Costos de Terreno

| Terreno | Walk/Run | Jump |
|---------|----------|------|
| Llano | 1 | 1 |
| Bosque Ligero | 2 | 1 |
| Bosque Denso | 3 | 1 |
| Agua Poca | 2 | 1 |
| Agua Profunda | 4 | 1 |
| Elevación (+1) | +1 | 1 |

## 7.3 Sistema de Calor

### Generación de Calor

| Fuente | Calor |
|--------|-------|
| Correr | +2 |
| Saltar (por jet) | +1 |
| Láser Medio | +3 |
| Láser Grande | +8 |
| ER Large Laser | +12 |
| PPC | +10 |
| AC (todos) | +1-2 |
| LRM | +4-6 |
| SRM | +2-4 |

### Disipación

```
Base: 10 puntos/turno (single heat sinks)
Doble: 20 puntos/turno (double heat sinks)
Agua poca: +2 disipación
Agua profunda: +4 disipación
```

### Efectos de Sobrecalentamiento

| Calor | Efecto |
|-------|--------|
| 15-17 | +1 modificador ataque |
| 18-20 | +2 modificador ataque |
| 21-23 | +3 modificador ataque, -1 MP |
| 24-26 | +4 modificador ataque, -2 MP |
| 27-29 | +4 modificador ataque, -3 MP |
| 30+ | Shutdown automático |

## 7.4 Sistema de ELO

### Fórmula

```
Nueva Rating = Rating Actual + K × (Resultado - Esperado)

K = 32 (nuevos jugadores) / 16 (establecidos)
Esperado = 1 / (1 + 10^((Rating Oponente - Rating)/400))
Resultado = 1 (victoria) / 0.5 (empate) / 0 (derrota)
```

### Rangos

| Rango | ELO | Icono |
|-------|-----|-------|
| Bronce | 0-999 | 🥉 |
| Plata | 1000-1499 | 🥈 |
| Oro | 1500-1999 | 🥇 |
| Platino | 2000-2499 | 💎 |
| Diamante | 2500+ | 👑 |

---

# 8. Seguridad

## 8.1 Autenticación

### JWT Tokens

```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "sub": "user_id",
    "username": "Player1",
    "exp": 1701518400,
    "iat": 1701432000,
    "type": "access"
  }
}
```

### Tiempos de Expiración

| Token | Duración |
|-------|----------|
| Access Token | 15 minutos |
| Refresh Token | 7 días |
| Session (Redis) | 24 horas |

## 8.2 Rate Limiting

```python
RATE_LIMITS = {
    "/auth/login": (5, 60),      # 5 req/min
    "/auth/register": (3, 60),   # 3 req/min
    "/auth/guest": (10, 60),     # 10 req/min
    "/queue/join": (10, 60),     # 10 req/min
    "default": (100, 60),        # 100 req/min
}
```

## 8.3 Validación Server-Side

### Acciones Validadas

| Acción | Validaciones |
|--------|--------------|
| Movimiento | Turno correcto, MP suficientes, camino válido, sin obstáculos |
| Ataque | Turno correcto, arma disponible, munición, rango, LOS |
| Fin turno | Es el jugador activo, fase correcta |

### Detección de Anomalías

```gdscript
# suspicious_activity_detector.gd
- Acciones demasiado rápidas (< 100ms entre acciones)
- Valores imposibles (daño negativo, HP > max)
- Secuencias inválidas (atacar antes de mover en fase incorrecta)
- Múltiples intentos de acción rechazada
```

## 8.4 Encriptación

| Componente | Método |
|------------|--------|
| Contraseñas | bcrypt (cost=12) |
| Comunicación API | TLS 1.3 (Let's Encrypt) |
| JWT Secret | 256-bit random |
| Checksums | SHA-256 |

---

# 9. Testing y QA

## 9.1 Framework

- **GUT** (Godot Unit Test) v9.3.0
- **pytest** para backend Python

## 9.2 Estructura de Tests

```
tests/
├── unit/                    # Tests unitarios
│   ├── test_movement_system.gd
│   ├── test_combat_system.gd
│   ├── test_heat_system.gd
│   ├── test_auth_manager.gd
│   ├── test_auth_validator.gd
│   ├── test_player_data_manager.gd
│   ├── test_server_action_validator.gd
│   └── test_matchmaking_*.gd
└── integration/             # Tests de integración
    └── test_battle_flow.gd
```

## 9.3 Cobertura Objetivo

| Módulo | Objetivo | Actual |
|--------|----------|--------|
| Core (combat, movement) | 95% | ~85% |
| Auth/Security | 95% | ~90% |
| Network | 80% | ~75% |
| UI | 60% | ~40% |
| **Total** | **80%** | **~75%** |

## 9.4 Ejecución

```powershell
# Todos los tests
& "G:\godot\Godot_v4.5.1-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Test específico
& "G:\godot\Godot_v4.5.1-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_combat_system.gd -gexit
```

---

# 10. DevOps y Deployment

## 10.1 Entornos

| Entorno | URL | Propósito |
|---------|-----|-----------|
| Local | localhost | Desarrollo |
| Producción | steeltitans.damsanti.app | Usuarios reales |

## 10.2 Servicios Systemd

```bash
# API
/etc/systemd/system/steeltitans-api.service
ExecStart=/opt/steeltitans/api/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8080

# Game Server
/etc/systemd/system/steeltitans-game.service
ExecStart=/opt/steeltitans/game_server/battletech_server.x86_64 --headless
```

## 10.3 Backups

```bash
# PostgreSQL - Diario a las 3 AM
0 3 * * * /opt/steeltitans/scripts/backup_db.sh

# Retención: 7 días
# Ubicación: /opt/steeltitans/backups/
```

## 10.4 Monitoreo

| Herramienta | Propósito |
|-------------|-----------|
| Sentry | Error tracking (cliente y servidor) |
| Health endpoints | Liveness, readiness, métricas |
| Journalctl | Logs de servicios |

### Health Endpoints

```
GET /health           # Basic health
GET /health/detailed  # Con stats
GET /health/live      # Kubernetes liveness
GET /health/ready     # Kubernetes readiness
GET /health/metrics   # Prometheus format
```

---

# Apéndices

## A. Glosario Técnico

| Término | Definición |
|---------|------------|
| **ENet** | Biblioteca de networking UDP confiable |
| **RPC** | Remote Procedure Call |
| **JWT** | JSON Web Token |
| **ORM** | Object-Relational Mapping |
| **TTL** | Time To Live |
| **LOS** | Line of Sight |
| **MP** | Movement Points |
| **ZoC** | Zone of Control |

## B. Configuración de Desarrollo

```gdscript
# project.godot - Autoloads
[autoload]
Log="*res://scripts/core/logger.gd"
NetworkManager="*res://scripts/network/network_manager.gd"
AuthManager="*res://scripts/core/auth_manager_singleton.gd"
AudioManager="*res://scripts/managers/audio_manager.gd"
```

## C. Variables de Entorno (Servidor)

```bash
# .env
DATABASE_URL=postgresql://user:pass@localhost:5432/steeltitans
REDIS_URL=redis://localhost:6379
JWT_SECRET=<256-bit-secret>
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7
SENTRY_DSN=https://...@sentry.io/...
```

---

*Documento generado: Diciembre 2025*  
*Próxima revisión: Enero 2026*
