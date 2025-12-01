# 📝 Changelog
## Steel Titans: Tactical Warfare

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

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
  - 380+ tests pasando
  - ~80% cobertura en core

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

[Unreleased]: https://github.com/DAMSanti/Battletech/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/DAMSanti/Battletech/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/DAMSanti/Battletech/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/DAMSanti/Battletech/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/DAMSanti/Battletech/releases/tag/v0.0.1
