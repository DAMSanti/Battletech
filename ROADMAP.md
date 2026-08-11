# ROADMAP técnico — Steel Titans: Tactical Warfare

**Fecha de este análisis:** 2026-08-10
**Basado en:** inspección directa del código (no de documentación previa). Ver [SPECS.md](SPECS.md) para la fotografía de datos que sustenta este documento.

Este roadmap complementa, no sustituye, a [doc/project/ROADMAP.md](doc/project/ROADMAP.md) (plan de negocio/producto original). Aquí el foco es: **¿qué hay que hacer en el código para que el juego que ya existe sea sostenible y termine el trabajo empezado?** No incluye presupuesto, contratación ni marketing.

Cada bloque es una lista de tareas marcable. Marca `[x]` según se complete; no borres las tareas hechas — el histórico de lo tachado es tan útil como lo pendiente.

---

## 0. Diagnóstico en una frase

El proyecto tiene una base jugable sorprendentemente completa (combate por turnos, hex grid, LoS, calor, red cliente-servidor, backend con auth/matchmaking/ELO en producción), pero el archivo que ejecuta el propio juego (`battle_scene.gd`, 2789 líneas) es un god-class sin ningún test, y no ha habido un commit desde el 1 de diciembre de 2025 pese a que hay ~66 archivos con cambios locales sin subir. El riesgo mayor no es "falta contenido", es "el núcleo del juego no está protegido contra regresiones y el trabajo en curso no está respaldado en el repositorio remoto".

---

## FASE T0 — Higiene inmediata (días, no semanas)

Bloqueante para todo lo demás: sin esto, cualquier cambio adicional aumenta el riesgo de perder trabajo o de introducir bugs invisibles.

- [x] Commitear el trabajo en curso (sistema de *facing*, `battle_ai.gd`, `mech.gd`, `hex_grid.gd`, tutorial, VFX, stats, ~40 tests nuevos) — 3 commits: gitignore/cache, tests, gameplay
- [x] Eliminar `scripts/**/*.gd.backup` (3 archivos) — hecho, ya no están en disco ni en git
  - [x] `scripts/managers/turn_manager.gd.backup`
  - [x] `scripts/core/component_database.gd.backup`
  - [x] `scripts/network/server_battle_manager.gd.backup`
- [x] Decidir el destino de `server/PRODUCTION_CREDENTIALS.md` — *ya está correctamente gitignorado y no trackeado; además `server/api/.env.example` ya existe como plantilla de configuración por variables de entorno, así que el patrón recomendado ya estaba en uso. No se requería refactor adicional.*
- [x] Revisar y limpiar `.gitignore` vs. `git status` — `.godot/editor/*` y demás cache desengachados de git con `git rm --cached`; `.claude/` añadido a `.gitignore`
- [x] Actualizar `doc/project/CHANGELOG.md` `[Unreleased]` y cortar una versión real — cambios de matchmaking/ELO/reconexión cerrados como `0.4.0` (2025-12-02); nuevo `[Unreleased]` documenta facing/tutorial/VFX/stats/tests

---

## FASE T1 — Romper el god-class de `battle_scene.gd`

Es el ítem de mayor impacto técnico del proyecto: 2789 líneas que mezclan input táctil, estado de partida, presentación de UI, y ~15 manejadores de eventos de red, con **0% de cobertura de tests** (326 casos excluidos explícitamente en `doc/development/TESTING.md`).

- [ ] Auditar cuánta lógica *ya* vive fuera de `battle_scene.gd` (`battle_controller.gd`, `battle_deployment_manager.gd`, `battle_input_router.gd`, `battle_movement_handler.gd`, `battle_state_coordinator.gd`) antes de mover nada más — parece que la extracción ya se empezó y `battle_scene.gd` quedó como fallback/pegamento
- [ ] Extraer el router de input (`_input(event)` y el dibujado del indicador de long-press) a un componente propio, testeable sin escena
- [ ] Separar el manejo de red (los ~15 `_on_handler_*`) en un adaptador dedicado que traduzca señales de `NetworkManager` a llamadas sobre un `BattleState` sin UI
- [ ] Hacer testeable el flujo de turno/activación/despliegue (líneas 816-2116 aprox.) una vez extraído del nodo de escena
- [ ] Escribir tests de integración reales para el flujo "desplegar → mover → atacar → fin de turno", en sustitución de los 326 casos excluidos (no hace falta 100%, sí cubrir el camino feliz + los casos de error más probables)

---

## FASE T2 — Consistencia de manejo de errores

Solo 71 `push_error` y 14 `push_warning` en 108 archivos, concentrados en ~15 de ellos; `assert()` no se usa nunca; `ErrorHandler` (`scripts/core/error_handler.gd`) existe pero solo se referencia en 1 archivo.

- [ ] Decidir si `ErrorHandler` sigue siendo la estrategia (parece bien diseñado, solo no adoptado) o se retira
- [ ] Si se mantiene, adoptarlo en `network_manager.gd` (parsing de respuestas de red)
- [ ] Adoptarlo en `database_manager.gd` (parsing de respuestas de red)
- [ ] Adoptarlo en `weapons_database.gd` y `mech_loadout.gd` (carga de datos de mechs/armas)
- [ ] Adoptarlo en `server_action_validator.gd` (validación server-side)
- [ ] Añadir `assert()` en invariantes de desarrollo (p. ej. estados de turno imposibles) — hoy un estado inconsistente probablemente falla en silencio

---

## FASE T3 — Auditoría de la capa de red server-authoritative

El patrón general (RPCs `any_peer` vs `authority`, uso de `multiplayer.get_remote_sender_id()` en vez de confiar en IDs del cliente, `ServerActionValidator` dedicado) está bien planteado. Lo que falta es **verificación sistemática**, no rediseño.

- [ ] Auditar, RPC por RPC en `network_manager.gd`, que toda mutación de estado autoritativo pase por `server_action_validator.gd` antes de aplicarse
- [ ] Auditar, RPC por RPC en `server_battle_manager.gd`, lo mismo
- [ ] Revisar la duplicación de superficie RPC entre `network_manager.gd` y `server_battle_manager.gd` (4753 líneas combinadas) — candidato a fusión o a una interfaz más clara de quién es dueño de qué mensaje
- [ ] Añadir test: intento de acción fuera de turno
- [ ] Añadir test: intento de acción sobre unidad ajena
- [ ] Añadir test: acción con datos fuera de rango (posición inválida, arma inexistente, etc.)

---

## FASE T4 — Cerrar el core de gameplay documentado como pendiente

Según `doc/project/ROADMAP.md` (Fase 3, ~25%) y confirmado por TODOs reales en código.

- [ ] Explosiones de munición
- [ ] Caídas y levantarse
- [ ] Completar los casos parciales del sistema de críticos
- [ ] Transferencia de daño a ubicación adyacente (`local_battle_manager.gd:638`, hoy sin implementar)
- [ ] Verificación de línea de visión pendiente (`local_battle_manager.gd:649`)
- [ ] Progresión de pilotos
- [ ] Economía de C-Bills
- [ ] Reparación de mechs
- [ ] Sistema de salvage

> Nota: esto es trabajo de *gameplay*, no de arquitectura — tiene sentido abordarlo después de T1-T3, porque hoy cualquier función nueva se añadiría sobre el mismo `battle_scene.gd` sin red de seguridad.

---

## FASE T5 — Accesos y mantenibilidad menores

Bajo impacto individual pero fáciles de agrupar en un sprint de limpieza.

- [ ] Definir un `[input]` map real en `project.godot` en vez de resolver toda la interacción a mano en `_input()` (facilita remapeo, testing y accesibilidad)
- [ ] Extraer la lógica de negocio de `NetworkManager` a clases `RefCounted` invocadas por el autoload, para poder testearla sin árbol de escena activo
- [ ] Extraer la lógica de negocio de `PlayerData` de la misma forma
- [ ] Arreglar los enlaces rotos de `README.md` (`doc/GDD.md`, `doc/ROADMAP.md`, `doc/ARCHITECTURE.md`) para que apunten a la estructura real (`doc/design/GDD.md`, `doc/project/ROADMAP.md`, `doc/architecture/SAD.md`)

---

## Qué NO incluye este roadmap

Presupuesto, contratación, marketing, publicación en tiendas, localización y monetización ya están cubiertos con detalle en [doc/project/ROADMAP.md](doc/project/ROADMAP.md) (Fases 4-8). Ese documento sigue siendo válido como plan de producto a largo plazo; simplemente asume un estado de "Fase 3 gameplay" que este análisis matiza con lo que realmente hay en el repo hoy.

---

## Orden de prioridad entre fases

- [ ] **T0** — no perder trabajo, no dejar landmines (`.backup`, credenciales en claro)
- [ ] **T1** — el núcleo del juego (`battle_scene.gd`) necesita tests antes de seguir creciendo
- [ ] **T3** — la validación server-side es lo único que impide hacer trampas en PvP; verificarla vale más que features nuevas
- [ ] **T2** — manejo de errores consistente, para que T1/T3 sean depurables
- [ ] **T4** — completar el core loop de gameplay (progresión, economía, reparación)
- [ ] **T5** — limpieza estructural cuando haya margen
