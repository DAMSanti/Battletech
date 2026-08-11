# SPECS — Steel Titans: Tactical Warfare

Punto de entrada único al estado técnico real del proyecto. Este documento no duplica el contenido de diseño/arquitectura ya existente en `doc/` — indexa esos documentos y añade una fotografía verificable del código tal como está hoy (2026-08-10), para que no haga falta leer 5 documentos para saber "¿qué hay implementado de verdad?".

> Para el resto de análisis, mejoras propuestas y prioridades, ver [ROADMAP.md](ROADMAP.md).

---

## 1. Índice de documentación

| Documento | Contenido | Última revisión conocida |
|---|---|---|
| [doc/design/GDD.md](doc/design/GDD.md) | Diseño de juego: pilares, narrativa, mecánicas, progresión, monetización | — |
| [doc/design/TDD.md](doc/design/TDD.md) | Diseño técnico: stack, arquitectura cliente/servidor, red, estructuras de datos | — |
| [doc/architecture/SAD.md](doc/architecture/SAD.md) | Arquitectura C4 (contexto, contenedores, componentes, código), patrones de diseño | — |
| [doc/architecture/DATABASE_SCHEMA.md](doc/architecture/DATABASE_SCHEMA.md) | Esquema PostgreSQL completo | — |
| [doc/api/REST_API.md](doc/api/REST_API.md) | Endpoints REST, auth, ejemplos | — |
| [doc/development/GUIDELINES.md](doc/development/GUIDELINES.md) | Convenciones de código y patrones recomendados | — |
| [doc/development/TESTING.md](doc/development/TESTING.md) | Framework GUT, cobertura por módulo, cómo ejecutar tests | 2025-12 |
| [doc/development/LOGGING.md](doc/development/LOGGING.md) | Sistema de logging y Sentry | — |
| [doc/project/ROADMAP.md](doc/project/ROADMAP.md) | Plan de negocio/producto original (fases, presupuesto, monetización, marketing) | 2025-12-02, **desactualizado** |
| [doc/project/CHANGELOG.md](doc/project/CHANGELOG.md) | Historial de versiones | 2025-12 (`[Unreleased]` acumulado) |
| [doc/design/WEAPONS_BALANCE.md](doc/design/WEAPONS_BALANCE.md) + `weapons_balance.csv` | Balance numérico de armas | — |
| [doc/adr/](doc/adr/) | 4 Architecture Decision Records (logging, red, terreno procedural, logger) | — |

`doc/project/ROADMAP.md` está congelado en diciembre de 2025 y describe fases de negocio (presupuesto de equipo, marketing, Steam) que no reflejan el foco actual del repo (proyecto en solitario, sin commits desde 2025-12-01 pese a trabajo local activo). Se mantiene como referencia histórica; las prioridades vigentes están en el nuevo [ROADMAP.md](ROADMAP.md).

---

## 2. Fotografía del estado real del código

Datos extraídos directamente del repositorio, no de documentación (verificar con `git log`, `wc -l`, etc. si hace tiempo que no se actualiza esta sección).

### Stack
- **Motor:** Godot 4.5, GDScript, renderer `mobile`, viewport fijo 720×1280 (portrait, mobile-first)
- **Servidor de partidas:** Godot headless (mismo código base que el cliente)
- **Backend:** FastAPI (Python) + PostgreSQL + Redis, desplegado en DigitalOcean (`steeltitans.damsanti.app`), Alembic para migraciones
- **Red:** ENet (UDP) para la partida en vivo + HTTPS/REST para cuenta, matchmaking, persistencia
- **Testing:** GUT 9.3.0 (GDScript), pytest (server), CI en GitHub Actions

### Tamaño del código
- `scripts/`: 108 archivos `.gd`, ~48.300 líneas
- `tests/`: 29 archivos, ~11.700 líneas (unit + integration)
- Archivos más grandes: `battle_scene.gd` (2789 líneas), `battle_ui.gd` (1354), `hex_surface_renderer.gd` (1253), `battle_components_integrator.gd` (1217), `tutorial_battle_controller.gd` (1204), `player_data_manager.gd` (1200), `weapons_database.gd` (1183), `mech.gd` (1173), `network_manager.gd` (1124), `auth_manager.gd` (1113)

### Autoloads (singletons globales) — `project.godot`
`Log`, `DatabaseManager`, `AuthManager`, `PlayerData`, `MechBayManager`, `SelectedLoadoutManager`, `NetworkManager`, `AudioManager`, `TutorialManager`

### Cobertura de tests (según `doc/development/TESTING.md`, dic-2025)
| Área | Cobertura |
|---|---|
| Core Systems (unit) | 334/334 — 100% |
| Battle Scene (integration) | 0/326 — 0% (excluida) |
| **Total proyecto** | 334/660 — 50.6% |

Los sistemas más grandes y de mayor riesgo (`battle_scene.gd`, `battle_ui.gd`, `hex_surface_renderer.gd`, `battle_components_integrator.gd`, `network_manager.gd`, `procedural_map_generator.gd`) **no tienen test unitario asociado**.

### Estado de git
- Rama activa: `Development` (también existen `master`, `multiplayer`, `3dBranch`)
- Último commit: `9070364` "feat: add GDScript code coverage analyzer to CI pipeline" — **2025-12-01**
- Trabajo local sin commitear en curso (~66 archivos modificados/nuevos): sistema de *facing*/orientación hexagonal (`facing_selector.gd` nuevo), cambios sustanciales en `battle_ai.gd`, `mech.gd`, `hex_grid.gd`, y nuevos tests (`test_movement_system.gd`, `test_database_manager.gd`, `test_error_handler.gd`, etc.)

### Deuda técnica conocida (verificada en código, ver detalle y priorización en ROADMAP.md)
- 3 archivos `.gd.backup` con `class_name` duplicado conviviendo con el código vivo (`scripts/managers/turn_manager.gd.backup`, `scripts/core/component_database.gd.backup`, `scripts/network/server_battle_manager.gd.backup`)
- `ErrorHandler` (`scripts/core/error_handler.gd`) existe pero solo se usa en 1 archivo — infraestructura construida y no adoptada
- 44 comentarios `TODO`/`FIXME`/`HACK` en `scripts/`
- No existe `[input]` map en `project.godot` — toda la interacción se resuelve a mano en `_input()` de `battle_scene.gd`

---

## 3. Endpoints y datos — referencia rápida

Para el detalle completo: [REST_API.md](doc/api/REST_API.md) y [DATABASE_SCHEMA.md](doc/architecture/DATABASE_SCHEMA.md).

- Base URL producción: `https://steeltitans.damsanti.app/api/v1`
- Routers del backend (`server/api/`): auth, users, pilots, mechs, elo, matchmaking, bans, audit, stats, health
- Autenticación: JWT (login/registro/guest/refresh)
- `server/PRODUCTION_CREDENTIALS.md` contiene datos reales de producción (IP, rutas de claves SSH) — **no está trackeado en git** (confirmado en `.gitignore`), pero vive en texto plano en disco. Ver ROADMAP.md § seguridad.

---

## 4. Cómo verificar que esta sección sigue vigente

```bash
git log -1 --format="%ci"                     # fecha del último commit
find scripts -name "*.gd" | wc -l              # nº de scripts
find scripts -name "*.gd" -exec wc -l {} + | tail -1   # líneas totales
grep -c "TODO\|FIXME\|HACK" -r scripts/        # deuda marcada
```

Si estos números difieren mucho de los de arriba, actualiza esta sección antes de fiarte de ella.
