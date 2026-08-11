# 📝 Changelog
## Steel Titans: Tactical Warfare

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Sistema de facing/orientación hexagonal (facing_selector, hex_grid, mech,
  hex_surface_renderer) con implicaciones de arco de armas e impactos traseros
- Modo tutorial interactivo (TutorialManager, TutorialBattleController,
  TutorialHintPopup)
- Combat Animation Manager y VFX de proyectiles/impactos
- Battle Stats Tracker y pantalla de fin de partida con resumen post-batalla
- Indicadores visuales de estado de mech y tabla de datos de balance de armas
- Sprites decorativos de terreno (bosques, escombros, agua, pavimento, edificio)
- ~40 tests unitarios nuevos (facing, ELO, LoS, sistemas de armas, mechs, etc.)
- SPECS.md y ROADMAP.md técnico en la raíz del repo

### Changed
- Comportamiento táctico de battle_ai.gd (gestión de calor, uso de cobertura)
- Turn manager, initiative screen, selector de armas y log de combate refinados

### Removed
- Scripts `.gd.backup` obsoletos con `class_name` duplicado
- Cache del editor de Godot (`.godot/`) deja de trackearse en git

---

## [0.4.0] - 2025-12-02 - Matchmaking y Documentación

### Added
- Sistema de matchmaking via API REST
- Sistema de ELO y rankings
- Reconexión automática de clientes
- Sistema de lobbies mejorado
- TDD (Technical Design Document)
- Reorganización completa de documentación

### Changed
- Estructura de carpetas de documentación
- NetworkManager soporta conexión API + ENet simultánea

### Fixed
- Propagación de token de auth después de registro
- Estados de conexión para matchmaking
- Transición automática a batalla después de match

---

## [0.3.0] - 2025-12-01 - Infraestructura Completa

### Added
- **Backend API** (FastAPI)
  - Autenticación JWT (login, registro, guest, refresh)
  - Endpoints de usuarios, mechs, pilotos
  - Endpoints de matchmaking y cola
  - Sistema de ELO
  - Rate limiting
  - Health checks (5 endpoints)
  - Audit logging
  - Sistema de baneos
  
- **Base de datos PostgreSQL**
  - Esquema completo (users, mechs, pilots, matches, sessions)
  - Migraciones con Alembic
  - Backups automáticos

- **Redis**
  - Cache de sesiones
  - Colas de matchmaking
  - TTLs configurados

- **Cliente Godot**
  - AuthScreen UI
  - AuthManager + AuthValidator
  - DatabaseManager (cliente HTTP)
  - PlayerDataManager (persistencia local)
  - MatchmakingUI
  - ReconnectionManager

- **Seguridad**
  - SSL/TLS con Let's Encrypt
  - Validación server-side completa
  - Anti-cheat básico (SuspiciousActivityDetector)

- **Testing**
  - 383+ tests pasando
  - **100% cobertura en core** (334/334 funciones)
  - 50.6% cobertura total (excluyendo battle scene integration)

### Changed
- Servidor desplegado en DigitalOcean (steeltitans.damsanti.app)
- API versionada bajo /api/v1

---

## [0.2.0] - 2025-11-15 - Multijugador Básico

### Added
- Servidor dedicado Godot Headless
- NetworkManager con ENet
- Sistema de lobby básico
- Sincronización de estado de mechs
- Deploy de mechs por equipos
- Sistema de turnos en red
- ServerActionValidator

### Changed
- Battle scene soporta modo online/offline

---

## [0.1.0] - 2025-11-01 - Core Gameplay

### Added
- **Sistema de combate**
  - Grid hexagonal funcional
  - Sistema de movimiento (Walk, Run, Jump)
  - Sistema de iniciativa con dados
  - Línea de visión (LOS)
  - Sistema de armas (energía, balísticas, misiles)
  - Sistema de daño por localizaciones
  - Sistema de calor
  - Ataques físicos (Punch, Kick, Charge)

- **UI/UX**
  - Menú principal
  - Mech Bay (hangar)
  - Team Setup
  - Overlay de batalla
  - Paper doll de mechs

- **Infraestructura**
  - Sistema de logging (Sentry)
  - Error handler
  - Framework de testing (GUT)
  - Generador procedural de mapas

---

## [0.0.1] - 2025-10-15 - Proyecto Inicial

### Added
- Estructura inicial del proyecto Godot 4.5
- Documentación base (GDD, ROADMAP)
- Configuración de Git

---

## Tipos de Cambios

- `Added` - Nuevas funcionalidades
- `Changed` - Cambios en funcionalidades existentes
- `Deprecated` - Funcionalidades que serán eliminadas
- `Removed` - Funcionalidades eliminadas
- `Fixed` - Corrección de bugs
- `Security` - Correcciones de vulnerabilidades

---

[Unreleased]: https://github.com/DAMSanti/Battletech/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/DAMSanti/Battletech/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/DAMSanti/Battletech/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/DAMSanti/Battletech/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/DAMSanti/Battletech/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/DAMSanti/Battletech/releases/tag/v0.0.1
