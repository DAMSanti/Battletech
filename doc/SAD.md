# 📐 Software Architecture Document (SAD)
## Steel Titans: Tactical Warfare

**Versión:** 1.0  
**Fecha:** 29 de Noviembre, 2025  
**Autor:** DAMSanti  
**Estado:** Living Document

---

## 📑 Índice

1. [Introducción](#1-introducción)
2. [Restricciones Arquitectónicas](#2-restricciones-arquitectónicas)
3. [Vista de Contexto](#3-vista-de-contexto)
4. [Vista de Contenedores](#4-vista-de-contenedores)
5. [Vista de Componentes](#5-vista-de-componentes)
6. [Vista de Código](#6-vista-de-código)
7. [Decisiones Arquitectónicas](#7-decisiones-arquitectónicas)
8. [Calidad y Atributos](#8-calidad-y-atributos)
9. [Riesgos y Deuda Técnica](#9-riesgos-y-deuda-técnica)

---

# 1. Introducción

## 1.1 Propósito

Este documento describe la arquitectura de software de **Steel Titans: Tactical Warfare**, un juego de combate táctico por turnos para dispositivos móviles Android. Está dirigido a desarrolladores, arquitectos y stakeholders técnicos.

## 1.2 Alcance

Steel Titans es un juego multiplayer competitivo (1v1, 2v2, 4v4) con:
- Cliente móvil (Android) desarrollado en Godot 4.5
- Servidor dedicado autoritativo
- Persistencia en la nube
- Autenticación con Google

## 1.3 Definiciones

| Término | Definición |
|---------|------------|
| **Titan** | Unidad de combate (mech) controlable |
| **Lance** | Grupo de 2-4 Titans de un jugador |
| **CR (Combat Rating)** | Valor de poder de un Titan |
| **Loadout** | Configuración de armas/equipo de un Titan |
| **Hex** | Celda hexagonal del mapa de batalla |

## 1.4 Referencias

- [GDD.md](./GDD.md) - Game Design Document
- [ROADMAP.md](./ROADMAP.md) - Plan de desarrollo
- [TODO_PRODUCTION.md](./TODO_PRODUCTION.md) - Backlog técnico
- [ADR/](./ADR/) - Architecture Decision Records

---

# 2. Restricciones Arquitectónicas

## 2.1 Restricciones de Negocio

| ID | Restricción | Impacto |
|----|-------------|---------|
| BUS-01 | Modelo de pago inicial + tienda in-game | Requiere sistema de compras y verificación de recibos |
| BUS-02 | Partidas de 10-15 minutos | Limita complejidad de estado, favorece reconexión rápida |
| BUS-03 | Plataforma principal Android | Optimización para móviles, touch controls |

## 2.2 Restricciones Técnicas

| ID | Restricción | Impacto |
|----|-------------|---------|
| TEC-01 | Motor: Godot 4.5 | GDScript como lenguaje principal, ENet para networking |
| TEC-02 | Servidor: DigitalOcean | Infraestructura inicial en droplet único |
| TEC-03 | Autenticación: Google Sign-In | Integración con Google Play Services |
| TEC-04 | Base de datos: PostgreSQL | Persistencia relacional |

## 2.3 Restricciones de Calidad

| ID | Restricción | Métrica |
|----|-------------|---------|
| QUA-01 | Cobertura de tests críticos | ≥95% |
| QUA-02 | Cobertura de tests importantes | ≥80% |
| QUA-03 | Cobertura de tests generales | ≥70% |
| QUA-04 | Latencia de red aceptable | <200ms P95 |

---

# 3. Vista de Contexto

## 3.1 Diagrama de Contexto

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CONTEXTO DEL SISTEMA                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                           ┌─────────────────┐                               │
│                           │   Google Play   │                               │
│                           │    Services     │                               │
│                           └────────┬────────┘                               │
│                                    │ OAuth2                                 │
│                                    ▼                                        │
│  ┌──────────────┐    ENet/UDP    ┌─────────────────────┐                   │
│  │              │◄──────────────►│                     │                   │
│  │   Cliente    │                │   Steel Titans      │                   │
│  │   Android    │    HTTPS       │   Game Server       │                   │
│  │   (Godot)    │◄──────────────►│   (Godot Headless)  │                   │
│  │              │                │                     │                   │
│  └──────────────┘                └──────────┬──────────┘                   │
│         │                                   │                               │
│         │                                   │ TCP                           │
│         │                                   ▼                               │
│         │                        ┌─────────────────────┐                   │
│         │                        │    PostgreSQL       │                   │
│         │                        │    Database         │                   │
│         │                        └─────────────────────┘                   │
│         │                                   │                               │
│         │ HTTPS                             │                               │
│         ▼                                   ▼                               │
│  ┌──────────────┐                ┌─────────────────────┐                   │
│  │   Sentry     │                │   Redis             │                   │
│  │   (Logging)  │                │   (Sessions/Cache)  │                   │
│  └──────────────┘                └─────────────────────┘                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 3.2 Actores Externos

| Actor | Tipo | Descripción |
|-------|------|-------------|
| **Jugador** | Usuario | Usuario final que juega en Android |
| **Google Play Services** | Sistema | Autenticación OAuth2, pagos in-app |
| **Sentry** | Sistema | Monitoreo de errores y crashes |
| **DigitalOcean** | Infraestructura | Hosting de servidor y base de datos |

---

# 4. Vista de Contenedores

## 4.1 Diagrama de Contenedores

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           STEEL TITANS SYSTEM                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        CLIENTE (Android)                             │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐           │   │
│  │  │    UI     │ │  Battle   │ │  Network  │ │   Data    │           │   │
│  │  │  Scenes   │ │  Engine   │ │  Client   │ │  Storage  │           │   │
│  │  └───────────┘ └───────────┘ └───────────┘ └───────────┘           │   │
│  │       Godot 4.5 | GDScript | ~50MB APK                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                          ENet (UDP) + HTTPS                                 │
│                                    │                                        │
│  ┌─────────────────────────────────▼───────────────────────────────────┐   │
│  │                        GAME SERVER                                   │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐           │   │
│  │  │  Match    │ │  Battle   │ │  Network  │ │   Auth    │           │   │
│  │  │  Making   │ │ Validator │ │  Server   │ │  Service  │           │   │
│  │  └───────────┘ └───────────┘ └───────────┘ └───────────┘           │   │
│  │       Godot 4.5 Headless | DigitalOcean Droplet                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                               TCP/HTTP                                      │
│                                    │                                        │
│  ┌──────────────────┐    ┌────────▼─────────┐    ┌──────────────────┐     │
│  │   PostgreSQL     │◄───│                  │───►│     Redis        │     │
│  │   ─────────────  │    │   Data Layer     │    │   ───────────    │     │
│  │   Users          │    │                  │    │   Sessions       │     │
│  │   Matches        │    │                  │    │   Matchmaking    │     │
│  │   Titans         │    │                  │    │   Cache          │     │
│  │   Transactions   │    │                  │    │                  │     │
│  └──────────────────┘    └──────────────────┘    └──────────────────┘     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 4.2 Descripción de Contenedores

### Cliente Android
| Aspecto | Detalle |
|---------|---------|
| **Tecnología** | Godot 4.5, GDScript |
| **Responsabilidad** | UI, renderizado, input, predicción cliente |
| **Comunicación** | ENet (gameplay), HTTPS (API) |
| **Almacenamiento** | user:// para configuración local |

### Game Server
| Aspecto | Detalle |
|---------|---------|
| **Tecnología** | Godot 4.5 Headless |
| **Responsabilidad** | Autoridad de juego, validación, matchmaking |
| **Comunicación** | ENet (clientes), HTTP (servicios) |
| **Escalado** | Vertical inicial, horizontal futuro |

### PostgreSQL
| Aspecto | Detalle |
|---------|---------|
| **Tecnología** | PostgreSQL 15+ |
| **Responsabilidad** | Persistencia de datos de usuario |
| **Esquemas** | users, titans, matches, transactions |

### Redis
| Aspecto | Detalle |
|---------|---------|
| **Tecnología** | Redis 7+ |
| **Responsabilidad** | Sesiones, cache, cola de matchmaking |
| **TTL** | Sesiones: 24h, Cache: 5min, MM Queue: 3min |

---

# 5. Vista de Componentes

## 5.1 Componentes del Cliente

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CLIENTE - COMPONENTES                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           PRESENTATION LAYER                         │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │   │
│  │  │ MainMenu    │ │ MechBay     │ │ BattleUI    │ │ Lobby       │   │   │
│  │  │ Screen      │ │ Screen      │ │             │ │ Screen      │   │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           GAME LOGIC LAYER                           │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │   │
│  │  │ BattleScene │ │ HexGrid     │ │ Mech        │ │ Combat      │   │   │
│  │  │ Controller  │ │ System      │ │ Entity      │ │ Calculator  │   │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           CORE SERVICES (Autoloads)                  │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │   │
│  │  │ Log         │ │ Network     │ │ MechBay     │ │ Audio       │   │   │
│  │  │ (Logger)    │ │ Manager     │ │ Manager     │ │ Manager     │   │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │   │
│  │  ┌─────────────┐                                                    │   │
│  │  │ Selected    │                                                    │   │
│  │  │ Loadout Mgr │                                                    │   │
│  │  └─────────────┘                                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 5.2 Autoloads (Singletons)

| Autoload | Archivo | Responsabilidad |
|----------|---------|-----------------|
| **Log** | `scripts/core/logger.gd` | Logging centralizado, integración Sentry |
| **NetworkManager** | `scripts/network/network_manager.gd` | Conexiones, RPCs, estado de red |
| **MechBayManager** | `scripts/managers/mech_bay_manager.gd` | Biblioteca de Titans, hangar del jugador |
| **SelectedLoadoutManager** | `scripts/managers/selected_loadout_manager.gd` | Loadouts seleccionados para batalla |
| **AudioManager** | `scripts/managers/audio_manager.gd` | Música, SFX, configuración de audio |
| **AuthManager** | `scripts/managers/auth_manager.gd` | Autenticación, tokens JWT, sesiones |

## 5.3 Core Services (No Autoload)

| Servicio | Archivo | Responsabilidad |
|----------|---------|-----------------|
| **ErrorHandler** | `scripts/core/error_handler.gd` | Manejo centralizado de errores, reportes, callbacks |
| **ServerActionValidator** | `scripts/core/server_action_validator.gd` | Validación server-side de todas las acciones |

## 5.4 Componentes del Servidor

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          SERVER - COMPONENTES                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           NETWORK LAYER                              │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                   │   │
│  │  │ ServerMain  │ │ Network     │ │ Network     │                   │   │
│  │  │             │ │ Manager     │ │ BattleClient│                   │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           GAME LOGIC LAYER                           │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                   │   │
│  │  │ ServerBattle│ │ Validation  │ │ Match       │                   │   │
│  │  │ Manager     │ │ Service     │ │ Manager     │                   │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           DATA LAYER (Futuro)                        │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                   │   │
│  │  │ User        │ │ Match       │ │ Leaderboard │                   │   │
│  │  │ Repository  │ │ Repository  │ │ Service     │                   │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# 6. Vista de Código

## 6.1 Estructura de Carpetas

```
Steel Titans/
├── 📁 addons/                    # Plugins de terceros
│   ├── gut/                      # Framework de testing
│   └── sentry/                   # SDK de Sentry
│
├── 📁 assets/                    # Recursos del juego
│   ├── audio/                    # Música y SFX
│   ├── sprites/                  # Imágenes de juego
│   ├── textures/                 # Texturas de terreno
│   ├── themes/                   # Themes de UI
│   └── ui/                       # Iconos y elementos de UI
│
├── 📁 doc/                       # Documentación
│   ├── ADR/                      # Architecture Decision Records
│   ├── GDD.md                    # Game Design Document
│   ├── SAD.md                    # Este documento
│   ├── DEVELOPMENT_GUIDELINES.md # Guía de desarrollo
│   └── ...
│
├── 📁 scenes/                    # Escenas de Godot (.tscn)
│   ├── battle_scene.tscn         # Escena principal de combate
│   ├── main_menu.tscn            # Menú principal
│   ├── mech_bay.tscn             # Configuración de mechs
│   └── ...
│
├── 📁 scripts/                   # Código fuente
│   ├── 📁 core/                  # Sistemas fundamentales
│   │   ├── logger.gd             # Sistema de logging
│   │   ├── 📁 battle/            # Lógica de batalla core
│   │   └── 📁 terrain/           # Sistema de terreno
│   │
│   ├── 📁 entities/              # Entidades del juego
│   │   ├── mech_data.gd          # Datos de mech
│   │   └── weapon.gd             # Sistema de armas
│   │
│   ├── 📁 managers/              # Managers (NO autoloads)
│   │   ├── battle_state_manager.gd
│   │   ├── battle_ai.gd
│   │   └── ...
│   │
│   ├── 📁 network/               # Networking
│   │   ├── network_manager.gd    # Autoload de red
│   │   ├── network_battle_client.gd
│   │   ├── server_main.gd
│   │   └── server_battle_manager.gd
│   │
│   ├── 📁 ui/                    # UI específica
│   │   ├── battle_ui.gd
│   │   ├── 📁 screens/           # Pantallas completas
│   │   └── 📁 components/        # Componentes reutilizables
│   │
│   └── 📁 utils/                 # Utilidades
│       ├── hex_utils.gd
│       └── math_utils.gd
│
├── 📁 server/                    # Configuración de servidor
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── deploy.ps1
│
├── 📁 tests/                     # Tests automatizados
│   ├── 📁 unit/                  # Tests unitarios
│   └── 📁 integration/           # Tests de integración
│
├── 📁 exports/                   # Builds exportados
│
├── project.godot                 # Configuración del proyecto
└── export_presets.cfg            # Presets de exportación
```

## 6.2 Patrones de Diseño Utilizados

### Singleton (Autoload)
```gdscript
# Acceso global a servicios core
Log.info("Combat", "Damage calculated", {"damage": 10})
NetworkManager.connect_to_server(ip, port)
```

### Observer (Signals)
```gdscript
# Comunicación desacoplada entre componentes
signal mech_destroyed(mech: Mech)
signal turn_ended(player_id: int)
signal damage_applied(target: Mech, amount: int, location: String)
```

### State Machine
```gdscript
# Flujo de batalla controlado por estados
enum BattlePhase { DEPLOYMENT, INITIATIVE, MOVEMENT, COMBAT, HEAT, END_TURN }
var current_phase: BattlePhase = BattlePhase.DEPLOYMENT
```

### Command Pattern (para acciones de juego)
```gdscript
# Acciones validables y reversibles (futuro)
class_name GameAction
func execute() -> bool
func validate() -> bool
func undo() -> void
```

### Repository Pattern (futuro, para persistencia)
```gdscript
# Abstracción de acceso a datos
class_name UserRepository
func get_by_id(id: String) -> User
func save(user: User) -> bool
```

## 6.3 Flujo de Datos en Batalla

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FLUJO DE DATOS - MOVIMIENTO                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  CLIENTE A                           SERVIDOR                 CLIENTE B    │
│  ─────────                           ────────                 ─────────    │
│      │                                   │                        │        │
│      │  1. Tap en hex destino            │                        │        │
│      │─────────────────────────────────► │                        │        │
│      │  {action: MOVE, from, to, path}   │                        │        │
│      │                                   │                        │        │
│      │                          2. Validar                        │        │
│      │                             - Distancia                    │        │
│      │                             - Terreno                      │        │
│      │                             - ZoC                          │        │
│      │                             - MP disponibles               │        │
│      │                                   │                        │        │
│      │  3. Si válido: broadcast          │                        │        │
│      │◄──────────────────────────────────│───────────────────────►│        │
│      │  {event: MECH_MOVED, ...}         │                        │        │
│      │                                   │                        │        │
│      │  4. Actualizar estado local       │   4. Actualizar estado │        │
│      │     Animar movimiento             │      Animar movimiento │        │
│      │                                   │                        │        │
│      │  3b. Si inválido: reject          │                        │        │
│      │◄──────────────────────────────────│                        │        │
│      │  {error: INVALID_MOVE, reason}    │                        │        │
│      │                                   │                        │        │
│      ▼                                   ▼                        ▼        │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# 7. Decisiones Arquitectónicas

Las decisiones arquitectónicas significativas se documentan en ADRs (Architecture Decision Records) separados en `doc/ADR/`.

## 7.1 Resumen de ADRs

| ID | Título | Estado | Fecha |
|----|--------|--------|-------|
| [ADR-001](./adr/ADR-001-logging-system.md) | Sistema de Logging con Sentry | Aceptada | Nov 2025 |
| [ADR-002](./adr/ADR-002-networking-architecture.md) | Arquitectura de Red Cliente-Servidor | Aceptada | Nov 2025 |
| [ADR-003](./adr/ADR-003-procedural-terrain.md) | Sistema de Terreno Procedural | Aceptada | Nov 2025 |
| [ADR-004](./adr/ADR-004-string-categories-logger.md) | Categorías de log como Strings | Aceptada | Nov 2025 |
| ADR-005 | Autenticación con Google Sign-In | Propuesta | - |
| ADR-006 | PostgreSQL + Redis para Persistencia | Propuesta | - |
| ADR-007 | Modelo de Monetización (Paid + Store) | Propuesta | - |

---

# 8. Calidad y Atributos

## 8.1 Atributos de Calidad

### Rendimiento
| Métrica | Objetivo | Medición |
|---------|----------|----------|
| FPS en batalla | ≥30 FPS estable | Profiler de Godot |
| Latencia de red | <200ms P95 | Logs del servidor |
| Tiempo de carga inicial | <5 segundos | Medición manual |
| Tamaño APK | <100 MB | Build de release |

### Disponibilidad
| Métrica | Objetivo | Medición |
|---------|----------|----------|
| Uptime del servidor | 99.5% | Monitoring DigitalOcean |
| Reconexión exitosa | 95% en <10s | Logs de servidor |

### Seguridad
| Aspecto | Implementación |
|---------|----------------|
| Autenticación | Google Sign-In + JWT |
| Autoridad de juego | 100% servidor (anti-cheat) |
| Comunicación | TLS para API, ENet encryption |
| Datos sensibles | Nunca en cliente, hash de passwords |

### Mantenibilidad
| Aspecto | Implementación |
|---------|----------------|
| Código | SOLID principles, DRY |
| Testing | ≥70-95% cobertura según criticidad |
| Logging | Centralizado con Log autoload |
| Documentación | ADRs, SAD, Guidelines actualizados |

## 8.2 Objetivos de Testing

| Categoría | Cobertura Mínima | Archivos |
|-----------|------------------|----------|
| **Crítico** | ≥95% | combat_system, damage_calculation, network_validation |
| **Importante** | ≥80% | movement, heat, initiative, mech_data |
| **Normal** | ≥70% | ui, audio, utils |

---

# 9. Riesgos y Deuda Técnica

## 9.1 Riesgos Arquitectónicos

| ID | Riesgo | Probabilidad | Impacto | Mitigación |
|----|--------|--------------|---------|------------|
| R-01 | Escalabilidad del servidor único | Media | Alto | Diseñar para horizontal scaling desde inicio |
| R-02 | Latencia en regiones lejanas | Alta | Medio | Múltiples servidores regionales (futuro) |
| R-03 | Pérdida de conexión durante partida | Alta | Alto | Sistema robusto de reconexión |
| R-04 | Cheating/exploits | Media | Alto | Validación 100% server-side |

## 9.2 Deuda Técnica Conocida

| ID | Descripción | Impacto | Esfuerzo Estimado | Prioridad |
|----|-------------|---------|-------------------|-----------|
| TD-001 | battle_scene.gd tiene 4600+ líneas | Alto | 1 semana | Alta |
| TD-002 | Falta validación server-side | Crítico | 2 semanas | Crítica |
| TD-003 | Duplicación en configs de mechs | Medio | 3 días | Media |
| TD-004 | No hay sistema de reconexión | Alto | 1 semana | Alta |
| TD-005 | UI hardcodeada para resoluciones | Medio | 3 días | Media |

## 9.3 Plan de Evolución

### Fase 1: Estabilización (Sprint 1-2)
- Validación server-side completa
- Refactor de battle_scene.gd
- Tests de cobertura objetivo

### Fase 2: Escalabilidad (Sprint 3-4)
- Autenticación Google
- PostgreSQL + Redis
- Sistema de reconexión

### Fase 3: Producción (Sprint 5-6)
- Múltiples servidores
- Monitoring avanzado
- Load testing

---

# Apéndices

## A. Glosario Técnico

| Término | Definición |
|---------|------------|
| **Autoload** | Singleton global en Godot, cargado automáticamente |
| **ENet** | Protocolo de red UDP confiable usado por Godot |
| **RPC** | Remote Procedure Call, llamadas entre cliente/servidor |
| **Headless** | Modo de Godot sin renderizado, para servidores |
| **Signal** | Sistema de eventos de Godot (observer pattern) |

## B. Herramientas de Desarrollo

| Herramienta | Uso |
|-------------|-----|
| Godot 4.5.1 | Motor de juego y editor |
| GUT 9.5.0 | Framework de testing |
| Sentry SDK | Monitoreo de errores |
| Git/GitHub | Control de versiones |
| VS Code | Editor de código alternativo |

---

*Documento vivo - Actualizar con cada decisión arquitectónica significativa*

*Última actualización: 29 de Noviembre, 2025*
