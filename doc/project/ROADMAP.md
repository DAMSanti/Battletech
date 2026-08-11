# 🎮 ROADMAP DE DESARROLLO PROFESIONAL
## Steel Titans: Tactical Warfare

**Versión del documento:** 2.1  
**Última actualización:** 2 de Diciembre, 2025  
**Estado del proyecto:** Alpha Ready ✅ + Fase 3 ~25% (Gameplay adelantado)

---

## 📋 ÍNDICE

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Estado Actual del Proyecto](#estado-actual-del-proyecto)
3. [Fases de Desarrollo](#fases-de-desarrollo)
4. [Detalles por Fase](#detalles-por-fase)
5. [Recursos y Presupuesto](#recursos-y-presupuesto)
6. [Consideraciones Legales](#consideraciones-legales)
7. [Métricas de Éxito](#métricas-de-éxito)
8. [Riesgos y Mitigación](#riesgos-y-mitigación)

---

## 🎯 RESUMEN EJECUTIVO

### Visión del Producto
Juego de combate táctico por turnos basado en mechs, con multijugador competitivo y progresión persistente, diseñado para PC y dispositivos móviles.

### Objetivos Principales
- Experiencia de combate táctico profunda y satisfactoria
- Multijugador estable y competitivo
- Modelo de monetización ético (cosméticos, sin pay-to-win)
- Comunidad activa y comprometida

### Timeline Estimado
| Fase | Duración | Fecha Estimada | Estado |
|------|----------|----------------|--------|
| Fase 0: Pre-producción | 2-4 semanas | Dic 2025 | ✅ COMPLETADA |
| Fase 1: Core Técnico | 4-8 semanas | Dic 2025 | ✅ COMPLETADA |
| Fase 2: Backend | 6-10 semanas | Dic 2025 | ✅ COMPLETADA |
| Fase 3: Gameplay | 8-12 semanas | Ene-Mar 2026 | 🔄 EN PROGRESO |
| Fase 4: Arte y Audio | 6-10 semanas | Abr-Jun 2026 | ⬜ Pendiente |
| Fase 5: Monetización | 4-6 semanas | Jul-Ago 2026 | ⬜ Pendiente |
| Fase 6: Pulido y QA | 4-8 semanas | Sep-Oct 2026 | ⬜ Pendiente |
| Fase 7: Lanzamiento | 2-4 semanas | Nov 2026 | ⬜ Pendiente |
| Fase 8: Post-lanzamiento | Continuo | Nov 2026+ | ⬜ Pendiente |

**Tiempo total estimado:** 10-12 meses hasta lanzamiento (adelantado 3-4 meses)

---

## 📊 ESTADO ACTUAL DEL PROYECTO

### Funcionalidades Implementadas ✅

#### Sistema de Combate
- [x] Grid hexagonal funcional
- [x] Sistema de movimiento por turnos
- [x] Sistema de iniciativa
- [x] Línea de visión (LOS)
- [x] Sistema de armas (energía, balísticas, misiles)
- [x] Sistema de daño y armadura
- [x] Sistema de calor
- [x] Ataques físicos básicos

#### Multijugador
- [x] Servidor dedicado (Godot headless)
- [x] Lobby de partidas
- [x] Sincronización de estado de mechs
- [x] Deploy de mechs por equipos
- [x] Sistema de turnos en red

#### UI/UX
- [x] Menú principal
- [x] Mech Bay (hangar)
- [x] Team Setup (configuración de lance)
- [x] Overlay de batalla
- [x] Paper doll de mechs
- [x] **AuthScreen (Login/Register UI)**

#### Infraestructura
- [x] Servidor en DigitalOcean
- [x] Sistema de deploy automatizado
- [x] Generador procedural de mapas
- [x] Sistema de logging profesional (Sentry integrado)
- [x] Sistema de manejo de errores (ErrorHandler)
- [x] Framework de testing (GUT - **875 tests, 841 pasando, 100% cobertura core**)
- [x] Validación server-side (ServerActionValidator)
- [x] Sistema de autenticación (AuthManager + AuthValidator)
- [x] **Base de datos PostgreSQL** (producción)
- [x] **API REST FastAPI** (HTTPS en producción)
- [x] **Arquitectura SOLID** (AuthValidator separado de UI)
- [x] **Let's Encrypt SSL** (steeltitans.damsanti.app)
- [x] **PlayerDataManager** (auto-save, sync, progreso)
- [x] **Rate Limiting** (middleware con límites por endpoint)
- [x] **Health Checks** (detailed, liveness, readiness, metrics)
- [x] **Anti-Cheat básico** (SuspiciousActivityDetector)
- [x] **Sistema de Backups** (PostgreSQL con retención 7 días)
- [x] **Redis** (sesiones y cache)
- [x] **Sistema de Baneos** (API + DB)
- [x] **Audit Logging** (acciones importantes)
- [x] **Matchmaking básico** (cola ELO, API + Godot)
- [x] **Reconexión automática** (ReconnectionHandler)
- [x] **Sistema de lobbies mejorado**
- [x] **Migraciones DB** (Alembic)
- [x] **API versionada** (v1)
- [x] **CI/CD** (GitHub Actions)
- [x] **TDD documento** (Technical Design Document)

### Funcionalidades Pendientes ❌

#### Críticas (Bloqueantes para Alpha)
- [x] ~~Autenticación de usuarios~~ ✅ (AuthManager completo)
- [x] ~~Base de datos PostgreSQL~~ ✅ (159.65.94.179)
- [x] ~~Validación server-side completa~~ ✅ (ServerActionValidator)
- [x] ~~Sistema de guardado/carga~~ ✅ (PlayerDataManager)
- [x] ~~Let's Encrypt certificado válido~~ ✅ (steeltitans.damsanti.app)
- [x] ~~Rate limiting~~ ✅ (middleware/rate_limiter.py)
- [x] ~~Health checks~~ ✅ (routers/health_router.py)
- [x] ~~Backups~~ ✅ (server/scripts/backup_db.sh)
- [x] ~~Anti-cheat básico~~ ✅ (suspicious_activity_detector.gd)
- [x] ~~Matchmaking~~ ✅ (matchmaking_router.py + matchmaking_client.gd)
- [x] ~~Balance de combate~~ ✅ (weapons_balance.csv + WEAPONS_BALANCE.md)
- [x] ~~Tutorial~~ ✅ (TutorialManager + TutorialHintPopup)

#### Importantes (Necesarias para Beta)
- [x] ~~Matchmaking~~ ✅ (completado en Diciembre)
- [x] ~~IA Single-player básica~~ ✅ (BattleAI con dificultades EASY/NORMAL/HARD)
- [ ] Sistema de rankings (ELO básico implementado, falta UI)
- [ ] Progresión de pilotos
- [ ] Economía in-game
- [ ] Sistema de reparaciones
- [ ] Arte profesional
- [ ] Audio completo

#### Deseables (Para lanzamiento)
- [ ] Campaña single-player
- [ ] Modo espectador
- [ ] Sistema de replays
- [ ] Torneos automatizados
- [ ] Battle Pass

---

## 🗓️ FASES DE DESARROLLO

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        TIMELINE DE DESARROLLO                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  FASE 0        FASE 1         FASE 2          FASE 3                    │
│  Pre-prod      Core           Backend         Gameplay                   │
│  ████          ████████       ██████████      ████████████              │
│  2-4 sem       4-8 sem        6-10 sem        8-12 sem                  │
│                                                                          │
│  FASE 4        FASE 5         FASE 6          FASE 7      FASE 8       │
│  Arte          Monetización   QA/Pulido       Launch      Live         │
│  ██████████    ██████         ████████        ████        ∞            │
│  6-10 sem      4-6 sem        4-8 sem         2-4 sem     Continuo     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Hitos Principales (Milestones)

| Milestone | Descripción | Criterio de Éxito |
|-----------|-------------|-------------------|
| **M1: Vertical Slice** | Demo jugable completa | 1 partida completa funcional |
| **M2: Alpha Cerrada** | Core loop completo | 100 testers, <5% crash rate |
| **M3: Beta Cerrada** | Features completas | 1000 testers, feedback positivo |
| **M4: Beta Abierta** | Stress test público | 10000 usuarios simultáneos |
| **M5: Release Candidate** | Listo para lanzamiento | 0 bugs críticos |
| **M6: Launch** | Lanzamiento público | Métricas de retención >30% D7 |

---

## 📚 DETALLES POR FASE

---

### FASE 0: PRE-PRODUCCIÓN ✅ COMPLETADA
**Duración:** 2-4 semanas  
**Completada:** Diciembre 2025  
**Objetivo:** Establecer bases sólidas antes del desarrollo intensivo

#### 0.1 Documentación de Diseño

| Tarea | Prioridad | Responsable | Estado |
|-------|-----------|-------------|--------|
| Game Design Document (GDD) completo | 🔴 Crítica | Game Designer | ✅ (doc/GDD.md) |
| Technical Design Document (TDD) | 🔴 Crítica | Lead Programmer | ✅ (doc/design/TDD.md) |
| Art Bible (guía de estilo visual) | 🟡 Alta | Art Director | ⬜ Pendiente |
| Audio Design Document | 🟡 Alta | Sound Designer | ⬜ Pendiente |
| Documento de monetización | 🔴 Crítica | Product Manager | ⬜ Pendiente |

**GDD debe incluir:**
- Mecánicas core detalladas
- Flujo de juego completo
- Sistemas de progresión
- Balance inicial de unidades
- Wireframes de UI
- User stories

#### 0.2 Análisis Legal

| Tarea | Prioridad | Responsable | Estado |
|-------|-----------|-------------|--------|
| Investigar licencia BattleTech | 🔴 Crítica | Legal | ✅ (IP propia decidida) |
| Contactar Catalyst Game Labs | 🔴 Crítica | Business Dev | ❌ N/A (IP propia) |
| Evaluar opciones de IP | 🔴 Crítica | Director | ✅ (Steel Titans) |
| Preparar documentos de empresa | 🔴 Crítica | Legal | ⬜ Pendiente |

**Opciones de IP:**
1. **Licencia oficial** - Costoso pero seguro
2. **IP original** - Renombrar todo (recomendado para indie)
3. **Fan game** - Sin monetización posible

#### 0.3 Infraestructura de Desarrollo

| Tarea | Prioridad | Responsable | Estado |
|-------|-----------|-------------|--------|
| Configurar Git Flow profesional | 🟡 Alta | DevOps | ✅ (main/Development) |
| Pipeline CI/CD (GitHub Actions) | 🟡 Alta | DevOps | ✅ (.github/workflows/ci.yml) |
| Sistema de builds automatizado | 🟡 Alta | DevOps | ✅ (CI/CD) |
| Entorno de staging | 🟡 Alta | DevOps | ✅ (servidor producción) |
| Sistema de issues/tracking | 🟢 Media | PM | ✅ (GitHub Issues) |

**Estructura de branches recomendada:**
```
main (producción)
├── develop (integración)
│   ├── feature/auth-system
│   ├── feature/matchmaking
│   └── feature/combat-balance
├── release/v0.1.0
└── hotfix/critical-bug
```

#### 0.4 Definición de Plataformas

| Plataforma | Prioridad | Requisitos Técnicos |
|------------|-----------|---------------------|
| Android | 🔴 Primaria | Android 8+, 2GB RAM |
| iOS | 🟡 Secundaria | iOS 14+, iPhone 8+ |
| PC (Steam) | 🟢 Terciaria | Windows 10+, 4GB RAM |
| Linux | 🟢 Terciaria | Ubuntu 20.04+ |
| Mac | 🟢 Terciaria | macOS 11+ |

---

### FASE 1: CORE TÉCNICO ✅ COMPLETADA
**Duración:** 4-8 semanas  
**Completada:** Diciembre 2025  
**Objetivo:** Infraestructura robusta y código mantenible

#### 1.1 Arquitectura de Código

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Refactorizar a arquitectura modular | 🟡 Alta | Alta | ⬜ Pendiente |
| Sistema de eventos global (EventBus) | 🟡 Alta | Media | ⬜ Pendiente |
| Sistema de estados (State Machine) | 🟡 Alta | Media | ⬜ Pendiente |
| Inyección de dependencias | 🟢 Media | Alta | ⬜ Pendiente |
| Documentación de API interna | 🟡 Alta | Baja | ⬜ Pendiente |

**Patrón de arquitectura recomendado:**
```
┌─────────────────────────────────────────────────┐
│                    GAME LAYER                    │
│  ┌─────────┐  ┌─────────┐  ┌─────────────────┐ │
│  │ Scenes  │  │   UI    │  │     Audio       │ │
│  └────┬────┘  └────┬────┘  └────────┬────────┘ │
├───────┼────────────┼────────────────┼──────────┤
│       │            │                │          │
│       ▼            ▼                ▼          │
│  ┌─────────────────────────────────────────┐   │
│  │              MANAGERS LAYER              │   │
│  │  GameManager | BattleManager | Network  │   │
│  └─────────────────────┬───────────────────┘   │
├────────────────────────┼───────────────────────┤
│                        ▼                        │
│  ┌─────────────────────────────────────────┐   │
│  │               DATA LAYER                 │   │
│  │   Models | Database | Config | Save     │   │
│  └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

#### 1.2 Sistema de Logging

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Logger centralizado con niveles | 🔴 Crítica | Baja | ✅ Completado |
| Rotación de logs | 🟡 Alta | Baja | ✅ Completado |
| Envío de logs a servidor (Sentry/similar) | 🟡 Alta | Media | ✅ Completado |
| Dashboard de errores | 🟢 Media | Media | ✅ (Sentry) |

**Implementación sugerida:**
```gdscript
# Logger.gd
enum Level { DEBUG, INFO, WARNING, ERROR, CRITICAL }

func log(level: Level, category: String, message: String):
    var timestamp = Time.get_datetime_string_from_system()
    var log_entry = "[%s] [%s] [%s] %s" % [timestamp, Level.keys()[level], category, message]
    
    if level >= current_log_level:
        print(log_entry)
        _write_to_file(log_entry)
        
    if level >= Level.ERROR:
        _send_to_remote(log_entry)
```

#### 1.3 Manejo de Errores

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Try/catch en operaciones críticas | 🔴 Crítica | Baja | ✅ Completado |
| Recuperación graceful de errores | 🔴 Crítica | Media | ✅ Completado |
| Pantalla de error amigable | 🟡 Alta | Baja | ✅ Completado |
| Sistema de crash reports | 🟡 Alta | Media | ✅ (Sentry) |
| Validación de datos de entrada | 🔴 Crítica | Media | ✅ Completado |

#### 1.4 Sistema de Guardado

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Formato de save versionado | 🔴 Crítica | Media | ✅ Completado |
| Migración entre versiones | 🔴 Crítica | Alta | ✅ Completado |
| Guardado automático | 🟡 Alta | Baja | ✅ Completado |
| Validación de integridad | 🔴 Crítica | Media | ✅ Completado |
| Backup de saves | 🟡 Alta | Baja | ✅ Completado |
| Cloud saves (Steam/Platform) | 🟢 Media | Alta | ⬜ Pendiente |

**Estructura de save recomendada:**
```json
{
    "version": "1.2.0",
    "created_at": "2026-01-15T10:30:00Z",
    "updated_at": "2026-01-15T12:45:00Z",
    "checksum": "sha256:abc123...",
    "data": {
        "player": {...},
        "mechs": [...],
        "pilots": [...],
        "inventory": {...},
        "progress": {...}
    }
}
```

#### 1.5 Optimización de Rendimiento

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Object pooling para proyectiles/efectos | 🟡 Alta | Media | ⬜ Pendiente |
| Lazy loading de recursos | 🟡 Alta | Media | ⬜ Pendiente |
| LOD para sprites/modelos | 🟢 Media | Media | ⬜ Pendiente |
| Profiling automatizado | 🟢 Media | Alta | ⬜ Pendiente |
| Memory leak detection | 🟡 Alta | Alta | ⬜ Pendiente |

#### 1.6 Testing

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Framework de unit tests (GUT) | 🔴 Crítica | Baja | ✅ Completado |
| Tests de combate (daño, hits) | 🔴 Crítica | Media | ✅ Completado |
| Tests de networking | 🔴 Crítica | Alta | ✅ Completado |
| Tests de UI automatizados | 🟢 Media | Alta | ⬜ Pendiente |
| Cobertura >80% en core | 🔴 Crítica | Alta | ✅ 100% (334/334) |
| Integration tests | 🟡 Alta | Alta | ✅ (875 tests) |

**Estructura de tests:**
```
tests/
├── unit/
│   ├── test_combat_calculator.gd
│   ├── test_mech_data.gd
│   ├── test_heat_system.gd
│   └── test_movement.gd
├── integration/
│   ├── test_battle_flow.gd
│   ├── test_multiplayer_sync.gd
│   └── test_save_load.gd
└── e2e/
    ├── test_full_battle.gd
    └── test_user_journey.gd
```

---

### FASE 2: BACKEND Y SERVICIOS ✅ COMPLETADA
**Duración:** 6-10 semanas  
**Completada:** Diciembre 2025  
**Objetivo:** Infraestructura de servidor escalable y segura

#### 2.1 Seguridad (CRÍTICO)

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Autenticación JWT/OAuth2 | 🔴 Crítica | Alta | ✅ Completado |
| Encriptación TLS para todo tráfico | 🔴 Crítica | Media | ✅ Completado |
| Validación server-side de acciones | 🔴 Crítica | Alta | ✅ Completado |
| Rate limiting | 🔴 Crítica | Media | ✅ Completado |
| Sanitización de inputs | 🔴 Crítica | Media | ✅ Completado |
| Anti-cheat básico | 🔴 Crítica | Alta | ✅ Completado |
| Sistema de baneos | 🟡 Alta | Media | ✅ Completado |
| Audit logging | 🟡 Alta | Media | ✅ Completado |

**Checklist de seguridad:**
- [x] No confiar en datos del cliente
- [x] Validar TODA acción en servidor
- [x] Tokens con expiración corta
- [x] Refresh tokens seguros
- [x] Rate limit por IP y por usuario
- [x] Detectar patrones sospechosos
- [x] Logs de seguridad separados

#### 2.2 Base de Datos

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Diseño de esquema (PostgreSQL) | 🔴 Crítica | Alta | ✅ Completado |
| Migraciones versionadas | 🔴 Crítica | Media | ✅ Completado (Alembic) |
| Índices optimizados | 🟡 Alta | Media | ✅ Completado |
| Backups automáticos diarios | 🔴 Crítica | Baja | ✅ Completado |
| Réplicas de lectura | 🟢 Media | Alta | ⬜ Pendiente |
| Redis para cache/sessions | 🟡 Alta | Media | ✅ Completado |

**Esquema de base de datos:**
```sql
-- Usuarios
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP,
    is_banned BOOLEAN DEFAULT FALSE,
    ban_reason TEXT,
    premium_until TIMESTAMP
);

-- Pilotos
CREATE TABLE pilots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    callsign VARCHAR(50),
    experience INT DEFAULT 0,
    gunnery_skill INT DEFAULT 4,
    piloting_skill INT DEFAULT 5,
    skills JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Mechs
CREATE TABLE mechs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    chassis_id VARCHAR(100) NOT NULL,
    variant_id VARCHAR(100) NOT NULL,
    custom_name VARCHAR(100),
    loadout JSONB NOT NULL,
    damage_state JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Partidas
CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mode VARCHAR(50) NOT NULL,
    map_id VARCHAR(100) NOT NULL,
    started_at TIMESTAMP DEFAULT NOW(),
    ended_at TIMESTAMP,
    winner_team INT,
    replay_data BYTEA
);

-- Participantes de partida
CREATE TABLE match_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES matches(id),
    user_id UUID REFERENCES users(id),
    team INT NOT NULL,
    mechs_used JSONB NOT NULL,
    result VARCHAR(20), -- 'victory', 'defeat', 'draw', 'disconnect'
    stats JSONB DEFAULT '{}'
);

-- Transacciones
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    type VARCHAR(50) NOT NULL, -- 'purchase', 'reward', 'repair', 'salvage'
    amount INT NOT NULL,
    currency VARCHAR(20) NOT NULL, -- 'cbills', 'premium'
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Rankings
CREATE TABLE rankings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) UNIQUE,
    season INT NOT NULL,
    elo INT DEFAULT 1000,
    wins INT DEFAULT 0,
    losses INT DEFAULT 0,
    rank_tier VARCHAR(20) DEFAULT 'bronze'
);
```

#### 2.3 API REST

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| API de autenticación | 🔴 Crítica | Alta | ✅ Completado |
| API de perfil/usuario | 🔴 Crítica | Media | ✅ Completado |
| API de mechs/inventario | 🔴 Crítica | Media | ✅ Completado |
| API de matchmaking | 🔴 Crítica | Alta | ✅ Completado |
| API de tienda | 🔴 Crítica | Alta | ⬜ Pendiente |
| API de estadísticas | 🟡 Alta | Media | ✅ Completado |
| Documentación OpenAPI | 🟡 Alta | Baja | ✅ (FastAPI auto) |
| Versionado de API | 🟡 Alta | Media | ✅ Completado (v1) |

**Endpoints principales:**
```
Authentication:
POST   /api/v1/auth/register
POST   /api/v1/auth/login
POST   /api/v1/auth/refresh
POST   /api/v1/auth/logout
POST   /api/v1/auth/forgot-password

Users:
GET    /api/v1/users/me
PATCH  /api/v1/users/me
GET    /api/v1/users/:id/profile

Mechs:
GET    /api/v1/mechs
POST   /api/v1/mechs
GET    /api/v1/mechs/:id
PATCH  /api/v1/mechs/:id
DELETE /api/v1/mechs/:id

Pilots:
GET    /api/v1/pilots
POST   /api/v1/pilots
GET    /api/v1/pilots/:id
PATCH  /api/v1/pilots/:id

Matches:
GET    /api/v1/matches
GET    /api/v1/matches/:id
POST   /api/v1/matches/queue
DELETE /api/v1/matches/queue
GET    /api/v1/matches/:id/replay

Shop:
GET    /api/v1/shop/items
POST   /api/v1/shop/purchase
GET    /api/v1/shop/inventory

Rankings:
GET    /api/v1/rankings
GET    /api/v1/rankings/me
GET    /api/v1/rankings/season/:season
```

#### 2.4 Servidor de Juego

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Arquitectura de microservicios | 🟡 Alta | Alta | ⬜ Pendiente |
| Servidor de matchmaking | 🔴 Crítica | Alta | ✅ Completado |
| Sistema de lobbies mejorado | 🔴 Crítica | Media | ✅ Completado |
| Reconexión automática | 🔴 Crítica | Alta | ✅ Completado |
| Escalado horizontal | 🟡 Alta | Alta | ⬜ Pendiente |
| Load balancing | 🟡 Alta | Alta | ⬜ Pendiente |
| Health checks | 🔴 Crítica | Baja | ✅ Completado |

**Arquitectura de servidores:**
```
                    ┌─────────────────┐
                    │  Load Balancer  │
                    │   (Nginx/HAProxy)│
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   API Server    │ │   API Server    │ │   API Server    │
│   (Node/Go)     │ │   (Node/Go)     │ │   (Node/Go)     │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                    ▼                 ▼
           ┌─────────────┐   ┌─────────────┐
           │  PostgreSQL │   │    Redis    │
           │   (Primary) │   │   (Cache)   │
           └──────┬──────┘   └─────────────┘
                  │
           ┌──────┴──────┐
           │  PostgreSQL │
           │  (Replica)  │
           └─────────────┘

         ┌─────────────────────────────────────────┐
         │           GAME SERVER CLUSTER           │
         │                                         │
         │  ┌──────────┐ ┌──────────┐ ┌──────────┐│
         │  │ Godot    │ │ Godot    │ │ Godot    ││
         │  │ Server 1 │ │ Server 2 │ │ Server 3 ││
         │  └──────────┘ └──────────┘ └──────────┘│
         │                                         │
         │  ┌──────────────────────────────────┐  │
         │  │      Matchmaking Service         │  │
         │  └──────────────────────────────────┘  │
         └─────────────────────────────────────────┘
```

#### 2.5 Matchmaking

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Cola de matchmaking por ELO | 🔴 Crítica | Alta | ✅ Completado |
| Filtros (modo, mapa, región) | 🟡 Alta | Media | ⬜ Pendiente |
| Tiempo de espera adaptativo | 🟡 Alta | Media | ⬜ Pendiente |
| Partidas privadas/custom | 🟡 Alta | Media | ⬜ Pendiente |
| Prevención de queue dodging | 🟢 Media | Media | ⬜ Pendiente |

---

### FASE 3: GAMEPLAY COMPLETO 🔄 EN PROGRESO (~25% completado)
**Duración:** 8-12 semanas  
**Inicio:** Diciembre 2025 (adelantado)  
**Objetivo:** Experiencia de juego completa y balanceada

#### 3.1 Sistema de Combate

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Balance de armas (spreadsheet) | 🔴 Crítica | Alta | ✅ Completado (weapons_balance.csv) |
| Sistema de críticos completo | 🔴 Crítica | Media | ✅ Parcial |
| Explosiones de munición | 🔴 Crítica | Media | ⬜ Pendiente |
| Mecánica de calor refinada | 🔴 Crítica | Media | ✅ Parcial |
| Shutdown por calor | 🟡 Alta | Baja | ✅ Completado |
| Ataques físicos completos | 🟡 Alta | Media | ✅ Parcial |
| Caídas y levantarse | 🟡 Alta | Media | ⬜ Pendiente |
| Terreno destructible | 🟢 Media | Alta | ⬜ Pendiente |
| Clima y efectos ambientales | 🟢 Media | Media | ⬜ Pendiente |

**Tabla de balance de armas:** Ver `doc/design/WEAPONS_BALANCE.md` y `weapons_balance.csv`

#### 3.2 Sistema de Progresión

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Experiencia de pilotos | 🔴 Crítica | Media | ⬜ Pendiente |
| Árbol de habilidades | 🟡 Alta | Media | ⬜ Pendiente |
| Sistema de rangos | 🟡 Alta | Media | ⬜ Pendiente |
| Desbloqueo de mechs | 🔴 Crítica | Media | ⬜ Pendiente |
| Sistema de salvage | 🔴 Crítica | Alta | ⬜ Pendiente |
| Economía de C-Bills | 🔴 Crítica | Alta | ⬜ Pendiente |
| Reparación de mechs | 🔴 Crítica | Media | ⬜ Pendiente |
| Compra de equipamiento | 🔴 Crítica | Media | ⬜ Pendiente |

**Curva de progresión:**
```
Nivel    XP Requerida    Beneficios
──────────────────────────────────────────────
1        0               Piloto básico
2        1,000           +1 Skill point
3        2,500           +1 Skill point, Habilidad pasiva
4        5,000           +1 Skill point
5        8,000           +1 Skill point, Especialización
6        12,000          +1 Skill point
7        17,000          +1 Skill point, Habilidad pasiva
8        23,000          +1 Skill point
9        30,000          +1 Skill point
10       40,000          Piloto élite, Todas las habilidades
```

#### 3.3 Modos de Juego

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Quick Play (partidas rápidas) | 🔴 Crítica | Baja | ✅ Completado |
| Ranked (competitivo) | 🔴 Crítica | Alta | ⬜ Pendiente |
| Custom Games | 🟡 Alta | Media | ⬜ Pendiente |
| Tutorial interactivo | 🔴 Crítica | Media | ✅ Completado (TutorialManager) |
| Modo práctica vs IA | 🟡 Alta | Alta | ✅ Completado (BattleAI) |
| Campaña single-player | 🟢 Media | Alta | ⬜ Pendiente |
| Cooperativo vs IA | 🟢 Media | Alta | ⬜ Pendiente |
| Torneos automatizados | 🟢 Media | Alta | ⬜ Pendiente |

#### 3.4 IA para Single-Player

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| IA de combate básica | 🟡 Alta | Alta | ✅ Completado (battle_ai.gd) |
| Dificultades ajustables | 🟡 Alta | Media | ✅ Completado (EASY/NORMAL/HARD) |
| Selector de dificultad en UI | 🟡 Alta | Baja | ✅ Completado (team_setup.tscn) |
| Comportamientos tácticos | 🟢 Media | Alta | ✅ Parcial (gestión calor, cobertura) |
| IA de equipo/coordinación | 🟢 Media | Alta | ⬜ Pendiente |

#### 3.5 UI/UX Mejoras

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Pantalla fin de partida mejorada | 🟢 Media | Baja | ✅ Completado (BattleEndScreen) |
| Estadísticas post-batalla | 🟢 Media | Media | ✅ Completado (BattleStatsTracker) |
| Indicadores visuales de mech | 🟢 Media | Baja | ✅ Completado (MechStatusIndicators) |

---

### FASE 4: ARTE Y AUDIO
**Duración:** 6-10 semanas  
**Objetivo:** Assets de calidad profesional

#### 4.1 Arte Visual

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Diseños de 20+ mechs | 🔴 Crítica | Alta | ⬜ Pendiente |
| Sprites/modelos de mechs | 🔴 Crítica | Alta | ⬜ Pendiente |
| Animaciones de combate | 🔴 Crítica | Alta | ⬜ Pendiente |
| Efectos visuales (VFX) | 🔴 Crítica | Media | ⬜ Pendiente |
| Tiles de terreno (5+ biomas) | 🔴 Crítica | Media | ⬜ Pendiente |
| UI profesional completa | 🔴 Crítica | Alta | ⬜ Pendiente |
| Iconografía de armas/equipos | 🟡 Alta | Media | ⬜ Pendiente |
| Portraits de pilotos | 🟡 Alta | Media | ⬜ Pendiente |
| Logo y branding | 🔴 Crítica | Media | ⬜ Pendiente |
| Cinematics/trailer | 🟢 Media | Alta | ⬜ Pendiente |

**Lista de mechs a diseñar:**
```
Light (20-35 tons):
- [ ] Commando (25t)
- [ ] Jenner (35t)
- [ ] Spider (30t)
- [ ] Firestarter (35t)

Medium (40-55 tons):
- [ ] Hunchback (50t)
- [ ] Shadowhawk (55t)
- [ ] Wolverine (55t)
- [ ] Griffin (55t)

Heavy (60-75 tons):
- [ ] Catapult (65t)
- [ ] Orion (75t)
- [ ] Thunderbolt (65t)
- [ ] Rifleman (60t)

Assault (80-100 tons):
- [ ] Atlas (100t)
- [ ] Awesome (80t)
- [ ] BattleMaster (85t)
- [ ] King Crab (100t)

Clan (si aplica):
- [ ] Mad Cat/Timber Wolf (75t)
- [ ] Dire Wolf (100t)
- [ ] Nova (50t)
- [ ] Summoner (70t)
```

#### 4.2 Audio

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Música original (5+ tracks) | 🔴 Crítica | Alta | ⬜ Pendiente |
| Música de menú | 🔴 Crítica | Media | ⬜ Pendiente |
| Música de combate (dinámica) | 🔴 Crítica | Alta | ⬜ Pendiente |
| SFX de armas (20+ sonidos) | 🔴 Crítica | Media | ⬜ Pendiente |
| SFX de movimiento de mechs | 🔴 Crítica | Media | ⬜ Pendiente |
| SFX de impactos/explosiones | 🔴 Crítica | Media | ⬜ Pendiente |
| SFX de UI | 🟡 Alta | Baja | ⬜ Pendiente |
| Ambientes (5+ biomas) | 🟡 Alta | Media | ⬜ Pendiente |
| Voces de pilotos | 🟢 Media | Alta | ⬜ Pendiente |
| Audio posicional 3D | 🟢 Media | Media | ⬜ Pendiente |

---

### FASE 5: MONETIZACIÓN
**Duración:** 4-6 semanas  
**Objetivo:** Sistema de ingresos sostenible y ético

#### 5.1 Modelo de Negocio

**Opción A: Free-to-Play con Cosméticos (RECOMENDADO)**
```
┌─────────────────────────────────────────────────────────────┐
│                    MODELO F2P ÉTICO                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  GRATIS:                    PREMIUM (Opcional):             │
│  ✓ Juego completo           • Skins de mechs               │
│  ✓ Todos los mechs          • Colores/camos                │
│  ✓ Matchmaking              • Efectos visuales             │
│  ✓ Ranked                   • Portraits de piloto          │
│  ✓ Progresión               • Battle Pass cosmético        │
│  ✓ 3 slots de mech          • Slots extra de mech          │
│                             • Aceleradores de XP           │
│                                                             │
│  ⚠️ NUNCA VENDER:                                          │
│  ✗ Mechs más fuertes                                       │
│  ✗ Armas/equipos mejores                                   │
│  ✗ Ventajas en combate                                     │
│  ✗ Loot boxes con items de poder                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Opción B: Premium (Compra Única)**
```
Precio base: $19.99 - $29.99
- Juego completo
- Todos los mechs actuales
- Actualizaciones gratuitas
- DLC de expansión opcionales ($9.99 cada uno)
```

#### 5.2 Sistema de Tienda

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Integración Stripe/PayPal | 🔴 Crítica | Alta | ⬜ Pendiente |
| Moneda premium (MC - Mech Credits) | 🔴 Crítica | Media | ⬜ Pendiente |
| Catálogo de cosméticos | 🔴 Crítica | Media | ⬜ Pendiente |
| Battle Pass sistema | 🟡 Alta | Alta | ⬜ Pendiente |
| Daily/Weekly deals | 🟡 Alta | Media | ⬜ Pendiente |
| Gift system | 🟢 Media | Media | ⬜ Pendiente |
| Refund policy | 🔴 Crítica | Baja | ⬜ Pendiente |

**Precios sugeridos:**
```
Moneda Premium (Mech Credits):
- 500 MC  = $4.99
- 1100 MC = $9.99  (10% bonus)
- 2400 MC = $19.99 (20% bonus)
- 6500 MC = $49.99 (30% bonus)

Items:
- Skin de mech básica: 200-400 MC
- Skin de mech premium: 600-1000 MC
- Pack de colores: 300 MC
- Battle Pass (temporada): 1000 MC
- Slot de mech extra: 400 MC
```

#### 5.3 Battle Pass

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Track gratuito (30 niveles) | 🟡 Alta | Media | ⬜ Pendiente |
| Track premium (30 niveles) | 🟡 Alta | Media | ⬜ Pendiente |
| Sistema de XP de pase | 🟡 Alta | Media | ⬜ Pendiente |
| Misiones/challenges | 🟡 Alta | Media | ⬜ Pendiente |
| Recompensas exclusivas | 🟡 Alta | Media | ⬜ Pendiente |

---

### FASE 6: PULIDO Y QA
**Duración:** 4-8 semanas  
**Objetivo:** Calidad de lanzamiento

#### 6.1 Testing

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| QA interno completo | 🔴 Crítica | Alta | ⬜ Pendiente |
| Beta cerrada (NDA) | 🔴 Crítica | Media | ⬜ Pendiente |
| Beta abierta | 🔴 Crítica | Media | ⬜ Pendiente |
| Stress test (10k usuarios) | 🔴 Crítica | Alta | ⬜ Pendiente |
| Test de regresión | 🔴 Crítica | Media | ⬜ Pendiente |
| Compatibilidad de hardware | 🟡 Alta | Media | ⬜ Pendiente |
| Test de localización | 🟡 Alta | Media | ⬜ Pendiente |

**Plan de beta:**
```
Beta Cerrada (4 semanas):
- 100-500 testers seleccionados
- NDA obligatorio
- Encuestas semanales
- Discord privado
- Bug bounty program

Beta Abierta (2 semanas):
- Acceso público
- Stress testing
- Marketing pre-launch
- Feedback masivo
- Server capacity testing
```

#### 6.2 Optimización Final

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| 60 FPS estable en specs mínimas | 🔴 Crítica | Alta | ⬜ Pendiente |
| Tiempos de carga <5 segundos | 🟡 Alta | Media | ⬜ Pendiente |
| Tamaño de descarga optimizado | 🟡 Alta | Media | ⬜ Pendiente |
| Uso de memoria <2GB | 🟡 Alta | Media | ⬜ Pendiente |
| Latencia de red <100ms | 🔴 Crítica | Alta | ⬜ Pendiente |

**Specs objetivo:**
```
Mínimos:
- OS: Windows 10
- CPU: Intel Core i3 / AMD Ryzen 3
- RAM: 4 GB
- GPU: Intel HD 4000 / GTX 660
- Storage: 2 GB
- Network: 1 Mbps

Recomendados:
- OS: Windows 10/11
- CPU: Intel Core i5 / AMD Ryzen 5
- RAM: 8 GB
- GPU: GTX 1060 / RX 580
- Storage: 4 GB SSD
- Network: 5 Mbps
```

#### 6.3 Accesibilidad

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Modo para daltonismo | 🟡 Alta | Baja | ⬜ Pendiente |
| Escalado de UI (100%-200%) | 🟡 Alta | Media | ⬜ Pendiente |
| Subtítulos configurables | 🟡 Alta | Baja | ⬜ Pendiente |
| Controles remapeables | 🟡 Alta | Media | ⬜ Pendiente |
| Soporte de teclado completo | 🟡 Alta | Media | ⬜ Pendiente |
| Reducción de movimiento | 🟢 Media | Baja | ⬜ Pendiente |

#### 6.4 Localización

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Inglés (base) | 🔴 Crítica | - | ✅ Hecho |
| Español | 🔴 Crítica | Media | ⬜ Pendiente |
| Alemán | 🟡 Alta | Media | ⬜ Pendiente |
| Francés | 🟡 Alta | Media | ⬜ Pendiente |
| Portugués (BR) | 🟡 Alta | Media | ⬜ Pendiente |
| Ruso | 🟢 Media | Media | ⬜ Pendiente |
| Japonés | 🟢 Media | Alta | ⬜ Pendiente |
| Chino simplificado | 🟢 Media | Alta | ⬜ Pendiente |

---

### FASE 7: LANZAMIENTO
**Duración:** 2-4 semanas  
**Objetivo:** Lanzamiento exitoso en plataformas

#### 7.1 Marketing

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| Trailer de lanzamiento | 🔴 Crítica | Alta | ⬜ Pendiente |
| Screenshots profesionales | 🔴 Crítica | Baja | ⬜ Pendiente |
| Press kit | 🔴 Crítica | Media | ⬜ Pendiente |
| Página web oficial | 🔴 Crítica | Media | ⬜ Pendiente |
| Steam page optimizada | 🔴 Crítica | Media | ⬜ Pendiente |
| Redes sociales activas | 🔴 Crítica | Baja | ⬜ Pendiente |
| Outreach a streamers/YouTubers | 🟡 Alta | Media | ⬜ Pendiente |
| Notas de prensa | 🟡 Alta | Baja | ⬜ Pendiente |

#### 7.2 Publicación en Plataformas

| Plataforma | Prioridad | Costo | Proceso |
|------------|-----------|-------|---------|
| Steam | 🔴 Principal | $100 | Steamworks Partner |
| Epic Games Store | 🟡 Alta | $0 | Epic Publishing Tools |
| GOG | 🟢 Media | $0 | GOG Partner Program |
| itch.io | 🟢 Baja | $0 | Direct upload |
| Google Play | 🟡 Alta | $25 | Google Play Console |
| Apple App Store | 🟡 Alta | $99/año | App Store Connect |

#### 7.3 Legal Pre-lanzamiento

| Tarea | Prioridad | Complejidad | Estado |
|-------|-----------|-------------|--------|
| EULA / ToS | 🔴 Crítica | Media | ⬜ Pendiente |
| Política de privacidad (GDPR) | 🔴 Crítica | Media | ⬜ Pendiente |
| Licencias de terceros | 🔴 Crítica | Baja | ⬜ Pendiente |
| Clasificación PEGI/ESRB | 🔴 Crítica | Media | ⬜ Pendiente |
| Registro de empresa | 🔴 Crítica | Alta | ⬜ Pendiente |

---

### FASE 8: POST-LANZAMIENTO
**Duración:** Continuo  
**Objetivo:** Mantener y crecer el juego

#### 8.1 Operaciones Live

| Tarea | Prioridad | Frecuencia |
|-------|-----------|------------|
| Monitoreo de servidores 24/7 | 🔴 Crítica | Continuo |
| Hotfixes críticos | 🔴 Crítica | <24 horas |
| Parches regulares | 🔴 Crítica | Bi-semanal |
| Actualizaciones de contenido | 🟡 Alta | Mensual |
| Eventos estacionales | 🟡 Alta | Trimestral |

#### 8.2 Community Management

| Tarea | Prioridad | Responsable |
|-------|-----------|-------------|
| Discord oficial | 🔴 Crítica | CM |
| Respuesta a reviews | 🔴 Crítica | CM |
| Programa de moderadores | 🟡 Alta | CM |
| Dev blogs/updates | 🟡 Alta | Dev + CM |
| Eventos de comunidad | 🟡 Alta | CM |

#### 8.3 Analytics y Métricas

| Métrica | Objetivo | Frecuencia |
|---------|----------|------------|
| DAU (usuarios diarios) | Tracking | Diario |
| MAU (usuarios mensuales) | Tracking | Mensual |
| Retención D1/D7/D30 | >40%/20%/10% | Semanal |
| ARPU (ingreso por usuario) | $0.50+ | Mensual |
| Conversion rate (F2P→Pago) | >5% | Mensual |
| Session length | 20+ min | Semanal |
| NPS (Net Promoter Score) | >30 | Mensual |

---

## 💰 RECURSOS Y PRESUPUESTO

### Equipo Mínimo Viable

| Rol | Cantidad | Salario/Año | Total/Año |
|-----|----------|-------------|-----------|
| Game Designer / Director | 1 | $60,000 | $60,000 |
| Programador Senior | 1 | $80,000 | $80,000 |
| Programador | 1-2 | $55,000 | $55,000-$110,000 |
| Artista 2D | 1 | $50,000 | $50,000 |
| Sound Designer (Freelance) | 0.5 | $40,000 | $20,000 |
| QA | 1 | $40,000 | $40,000 |
| Community Manager | 1 | $40,000 | $40,000 |
| **TOTAL** | 6-7 | - | **$345,000-$400,000** |

### Costos Adicionales

| Categoría | Costo Estimado |
|-----------|----------------|
| Servidores (año 1) | $12,000 - $36,000 |
| Herramientas/Software | $5,000 |
| Marketing | $20,000 - $50,000 |
| Legal (LLC, contratos, licencias) | $10,000 - $20,000 |
| Audio profesional | $10,000 - $30,000 |
| Certificaciones (ESRB, etc) | $3,000 |
| Contingencia (15%) | $50,000 |
| **TOTAL ADICIONAL** | **$110,000 - $194,000** |

### Presupuesto Total Estimado

| Escenario | Costo Total (18 meses) |
|-----------|------------------------|
| Indie Bootstrap | $100,000 - $150,000 |
| Indie Profesional | $300,000 - $500,000 |
| Studio Pequeño | $500,000 - $1,000,000 |

---

## ⚖️ CONSIDERACIONES LEGALES

### Propiedad Intelectual

**BattleTech/MechWarrior pertenece a:**
- **Catalyst Game Labs** - Derechos de juego de mesa
- **Microsoft** - Derechos de videojuegos
- **The Topps Company** - Propietario de la IP

### Opciones

| Opción | Pros | Contras |
|--------|------|---------|
| **Licencia Oficial** | Legal, acceso a IP, credibilidad | Muy costoso, negociación larga, royalties |
| **IP Original** | Control total, sin royalties | Perder reconocimiento de marca, diseño desde cero |
| **Fan Game (No comercial)** | Simple, comunidad | Sin ingresos posibles |

### Recomendación
**Crear IP original inspirada en el género "mech combat"**, evitando cualquier nombre, diseño o término específico de BattleTech. Ejemplos de juegos que hicieron esto:
- Battletech → Iron Harvest (mismo género, IP diferente)
- Warhammer → Warcraft/Starcraft (inspirado pero original)

---

## 📈 MÉTRICAS DE ÉXITO

### Pre-lanzamiento
| Milestone | Criterio de Éxito |
|-----------|-------------------|
| Vertical Slice | Demo completa de 1 batalla |
| Alpha | 100 testers, <10 crashes/día |
| Beta Cerrada | 500 testers, NPS >20 |
| Beta Abierta | 5000+ participantes, servidores estables |

### Post-lanzamiento
| Métrica | Mes 1 | Mes 3 | Mes 6 | Año 1 |
|---------|-------|-------|-------|-------|
| Downloads | 10,000 | 50,000 | 100,000 | 200,000 |
| DAU | 1,000 | 3,000 | 5,000 | 8,000 |
| Revenue | $5,000 | $20,000 | $15,000 | $150,000 |
| Rating | 3.5★ | 4.0★ | 4.2★ | 4.5★ |

---

## ⚠️ RIESGOS Y MITIGACIÓN

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Problemas legales de IP | Alta | Crítico | Crear IP original |
| Servidor sobrecargado | Media | Alto | Auto-scaling, load testing |
| Balance roto | Alta | Alto | Beta extensiva, ajustes rápidos |
| Cheaters/hackers | Alta | Alto | Validación server-side, anti-cheat |
| Falta de jugadores | Media | Crítico | Bots, cross-play, marketing |
| Burnout del equipo | Media | Alto | Scope realista, vacaciones |
| Competencia lanza similar | Baja | Medio | Diferenciación, nicho |

---

## 📝 NOTAS FINALES

Este roadmap es un documento vivo que debe actualizarse según:
- Feedback de testers
- Cambios en el mercado
- Recursos disponibles
- Prioridades del negocio

**Próxima revisión:** Enero 2026

---

*Documento creado: 29 de Noviembre, 2025*  
*Versión: 1.0*
