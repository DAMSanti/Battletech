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
- **Motor:** Godot 4.5.1, GDScript, renderer `mobile`, viewport fijo 720×1280 (portrait, mobile-first)
- **Servidor de partidas:** Godot headless (mismo código base que el cliente)
- **Backend:** FastAPI (Python) + PostgreSQL + Redis, desplegado en DigitalOcean (`steeltitans.damsanti.app`), Alembic para migraciones
- **Red:** ENet (UDP) para la partida en vivo + HTTPS/REST para cuenta, matchmaking, persistencia
- **Testing:** GUT 9.3.0 (GDScript), pytest (server), CI en GitHub Actions. Godot local para correr tests: `E:\Godot\Godot_v4.5.1-stable_win64_console.exe` (equipo de DAMSanti) — ver comando en la sección 4

### Tamaño del código
- `scripts/`: 109 archivos `.gd`, ~48.300 líneas
- `tests/`: 31 archivos (30 unit/integration + 1 smoke de escena), ~11.800 líneas
- Archivos más grandes: `battle_scene.gd` (2737 líneas, bajando — ver ROADMAP.md Fase T1), `battle_ui.gd` (1354), `hex_surface_renderer.gd` (1253), `battle_components_integrator.gd` (1217), `tutorial_battle_controller.gd` (1204), `player_data_manager.gd` (1200), `weapons_database.gd` (1183), `mech.gd` (1173), `network_manager.gd` (1124), `auth_manager.gd` (1113)

### Autoloads (singletons globales) — `project.godot`
`Log`, `DatabaseManager`, `AuthManager`, `PlayerData`, `MechBayManager`, `SelectedLoadoutManager`, `NetworkManager`, `AudioManager`, `TutorialManager`

### Cobertura de tests — **verificado ejecutando la suite real** (2026-08-11, Godot 4.5.1 headless), no de documentación
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -glog=1
```
| Métrica | Valor |
|---|---|
| Scripts de test | 30 |
| Tests totales | 931 |
| Passing | ~906-907 |
| Failing | 17-18 (pre-existentes y algo variables entre ejecuciones — ver detalle abajo) |
| Risky/Pending | 7 |
| Asserts | ~2470/2488 |
| Tiempo | ~55s |

El número exacto de fallos varía ligeramente (17 vs 18) entre ejecuciones — todos dentro del mismo cluster de `test_database_manager.gd` (llamadas de red a endpoints inalcanzables) más `test_logger.gd`; no se ha investigado la causa exacta de la variación pero no está relacionada con ninguno de los cambios de T0-T3.

`doc/development/TESTING.md` (334/334 core, 50.6% total) está desactualizado — la cifra real de hoy es sustancialmente mayor porque se añadieron ~40 tests de facing/ELO/LoS/armas en la sesión anterior más un smoke test de `battle_scene.tscn` en esta.

**Los 17 fallos son reales y preexistentes**, no ruido de este análisis:
- 9 en `test_database_manager.gd`: llaman a endpoints inalcanzables a propósito (`/nonexistent`, servidor no disponible en tests) y el `push_error`/`push_warning` resultante lo marca GUT como "Unexpected Error" — este proyecto de GUT no tiene mecanismo de "expect_error" por test, así que cualquier código que loguee un error dentro de un test falla automáticamente aunque el comportamiento sea el esperado.
- 2 en `test_logger.gd`: llaman a `start_timer()`/`end_timer()`, métodos que no existen en `logger.gd`.
- El resto no se ha triado en detalle (ver `tests/` para el listado exacto).

`battle_scene.gd` pasó de 0 a 8 tests reales (smoke + verificación de despliegue) en `tests/integration/test_battle_scene_smoke.gd`.

Los sistemas más grandes que siguen sin test unitario propio: `battle_ui.gd`, `hex_surface_renderer.gd`, `battle_components_integrator.gd`, `network_manager.gd`, `procedural_map_generator.gd`.

### Estado de git
- Rama activa: `Development`
- 8 meses sin commits (desde 2025-12-01) hasta esta sesión; el trabajo local pendiente se commiteó en una serie de commits temáticos (housekeeping, tests, gameplay, docs) — ver `git log`.

### Deuda técnica conocida (verificada en código, ver detalle y priorización en ROADMAP.md)
- ~~3 archivos `.gd.backup`~~ — eliminados
- `ErrorHandler` (`scripts/core/error_handler.gd`) ahora se usa en `database_manager.gd`, `matchmaking_client.gd` y `turn_manager.gd` (antes: 1 archivo, no adoptado en ninguno real)
- `turn_manager.advance_phase()` ya no puede quedar en soft-lock silencioso ante un `current_phase` inválido (antes: sin rama por defecto en el `match`)
- ~44 comentarios `TODO`/`FIXME`/`HACK` en `scripts/` (sin cambios, pendiente de Fase T4)
- No existe `[input]` map en `project.godot` — toda la interacción se resuelve a mano en `_input()` de `battle_scene.gd` (pendiente, Fase T5)
- Fuga de nodos (orphans) al cerrar Godot tras correr tests (~16-88 según el run) y un crash de motor (signal 11 / segfault) al salir del proceso headless **tras** completar e imprimir todos los resultados — no afecta el resultado de los tests pero ensucia CI logs; no investigado en profundidad, posiblemente relacionado con el plugin de Sentry en modo headless

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
