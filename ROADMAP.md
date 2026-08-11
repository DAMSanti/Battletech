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

Es el ítem de mayor impacto técnico del proyecto: mezcla input táctil, estado de partida, presentación de UI, y ~15 manejadores de eventos de red. Tenía **0% de cobertura de tests** (326 casos excluidos explícitamente en `doc/development/TESTING.md`); ahora tiene una primera capa de 8 tests de integración reales (ver más abajo), aunque el grueso de la lógica de negocio (despliegue/activación, handlers de red) sigue sin extraer ni cubrir.

- [x] Auditar cuánta lógica *ya* vive fuera de `battle_scene.gd` — **hallazgo corregido:** `_input(event)` ya delega 100% en `battle_components.input_router` (5 líneas, `battle_scene.gd:1151`); la extracción a `battle_controller.gd`/`battle_deployment_manager.gd`/`battle_input_router.gd`/`battle_movement_handler.gd`/`battle_state_coordinator.gd` ya cubre una parte real. Lo que **no** está extraído son los ~700 líneas de despliegue/activación (816-2116 aprox.) y los ~15 `_on_handler_*` de red — eso sigue siendo un god-class de verdad, no solo apariencia
- [x] Extraer el dibujado del indicador de long-press a un componente propio — nuevo `scripts/ui/long_press_indicator.gd` (`class_name LongPressIndicator`), gestiona su propio `_process`/`_draw` leyendo `battle_components.input_router`; `battle_scene.gd` pasó de 2789 a 2737 líneas
- [x] Escribir tests de integración reales para `battle_scene.tscn` — **hecho y verificado**: se encontró Godot 4.5.1 local (`E:\Godot`, coincide con `project.godot`), se corrió la suite real (923 tests, 899 passing, 17 fallos preexistentes sin relación) y se añadió `tests/integration/test_battle_scene_smoke.gd` (8 tests: arranca sin crashear, `hex_grid`/`turn_manager`/`battle_components`/`long_press_indicator` se inicializan, las zonas de despliegue se generan de verdad, `turn_manager` arranca en una fase válida). Esta es la primera cobertura real de `battle_scene.gd`, que tenía 0%
- [ ] Separar el manejo de red (los ~15 `_on_handler_*`) en un adaptador dedicado — **no completado en esta sesión**: ahora sí hay Godot disponible y un smoke test como red de seguridad, pero mover ~15 handlers de resultado de red (movimiento/disparo/ataque/fase de calor) es un refactor grande que requiere entender cada uno en detalle; se dejó fuera de alcance para no forzar un cambio grande sin revisión humana intermedia. Recomendado: extraer un handler a la vez, escribir su test antes de moverlo (TDD real), correr la suite completa entre cada uno. El comando para correr tests ya está documentado en SPECS.md §4
- [ ] Hacer testeable el flujo de turno/activación/despliegue (las ~700 líneas 816-2116) — mismo motivo que el punto anterior, pendiente de una extracción incremental futura

---

## FASE T2 — Consistencia de manejo de errores

Solo 71 `push_error` y 14 `push_warning` en 108 archivos, concentrados en ~15 de ellos; `assert()` no se usa nunca; `ErrorHandler` (`scripts/core/error_handler.gd`) existe pero solo se referencia en 1 archivo.

- [x] Decidir si `ErrorHandler` sigue siendo la estrategia — **se mantiene**: está bien diseñado (categorías, severidad, historial, integración con `Log`) y es `static`/`RefCounted`, se puede llamar directamente sin autoload
- [x] Adoptarlo en `database_manager.gd` — los dos puntos de fallo real (error de red HTTP y JSON inválido en `_parse_response`) ahora reportan vía `ErrorHandler.report(..., auto_recover=false)` en vez de solo `Log.error`/`Log.warning`
- [x] Adoptarlo en `matchmaking_client.gd` — mismo patrón en `_parse_response` (fallo de parseo JSON)
- [x] Revisar `network_manager.gd` — **auditado, sin cambio**: no tiene parsing de JSON ni operaciones de archivo (usa RPCs tipados de ENet, no HTTP); los `if not is_server: return` son guardas de control de flujo normales, no errores — forzar `ErrorHandler` ahí habría sido ruido, no valor
- [x] Revisar `weapons_database.gd` — **auditado, sin cambio**: es una tabla de datos `const`, sin I/O ni operación falible que envolver
- [x] Revisar `mech_loadout.gd` — **auditado, sin cambio**: `from_dict()` ya usa `.get()` con valores por defecto en cada campo, no hay parseo que pueda lanzar
- [x] Revisar `server_action_validator.gd` — **auditado, sin cambio**: ya tiene su propio patrón `ValidationResult` (success/failure) apropiado al dominio; un rechazo de validación no es un error del sistema, es un resultado esperado de una acción de cliente inválida — mezclar `ErrorHandler` ahí sería incorrecto conceptualmente
- [x] Invariante de estado de turno — `turn_manager.advance_phase()` tenía un `match` sin rama por defecto que cubría solo 6 de los 7 valores de `GameEnums.TurnPhase` (faltaba `DEPLOYMENT`): un `current_phase` inesperado dejaba `is_phase_transitioning` en `true` para siempre, congelando el turno en silencio. Se añadió la rama `_:` que resetea el flag y reporta vía `ErrorHandler` (LOW). **No se usó `assert()` desnudo**: se probó primero (forzando `current_phase = -1` y `= DEPLOYMENT` y llamando `advance_phase()`), y un `assert()` que falla se registra como `push_error`-equivalente; este GUT no tiene forma de marcar un error como "esperado" en un test, así que cualquier test que dispare esa rama fallaría automáticamente aunque el comportamiento fuera correcto — se optó por `ErrorHandler` a severidad LOW (no bloquea tests) en su lugar. Verificado manualmente que `is_phase_transitioning` vuelve a `false` en ambos casos; suite completa re-verificada sin regresiones (923/899/17/7, igual que el baseline)

---

## FASE T3 — Auditoría de la capa de red server-authoritative

El patrón general (RPCs `any_peer` vs `authority`, uso de `multiplayer.get_remote_sender_id()` en vez de confiar en IDs del cliente, `ServerActionValidator` dedicado) está bien planteado. Lo que faltaba era **verificación sistemática**, no rediseño — y la auditoría encontró dos huecos reales, no solo teóricos.

- [x] Auditar, RPC por RPC en `network_manager.gd`, que toda mutación de estado autoritativo pase por `server_action_validator.gd` — **hallazgo confirmado**: los `@rpc("any_peer")` de combate (`server_request_deploy_mech`, `server_request_move`, `server_request_rotate`, `server_request_fire`, `server_request_physical_attack`, `server_request_end_activation`) son puro *forwarding* (`if not is_server: return` + delegar a `server_battle._handle_*`), no mutan estado directamente. Los RPCs de lobby/meta (`server_register_player`, `server_send_chat`, etc.) solo tocan el estado del propio peer que llama — sin hallazgos críticos ahí.
- [x] Auditar, RPC por RPC en `server_battle_manager.gd`, que toda mutación pase por `server_action_validator.gd` — **2 huecos reales encontrados y corregidos** (ver commits `6ee6fad` y `edb0bf5`):
  - `_handle_move_request`, `_handle_rotate_request`, `_handle_fire_request`, `_handle_physical_request` validaban propiedad + fase, pero **no** el orden de activación (`units_to_activate`/`current_unit_index`) — un cliente podía actuar con cualquiera de sus propios mechs no usados en cualquier orden dentro de la fase, en vez de respetar el "orden de iniciativa" que documenta `GDD.md`. Corregido con `ServerActionValidator._validate_activation_order()`, aplicado a los 3 validadores de acción.
  - `_handle_end_activation` **no validaba en absoluto** que el mech pasado fuera la unidad activa: cualquier cliente podía llamar `server_request_end_activation` con cualquiera de sus propios mechs en cualquier momento y forzar `_advance_to_next_unit()`, saltándose el turno del rival de activar su propia unidad. Corregido con `ServerActionValidator.validate_end_activation()`.
- [x] Revisar la duplicación de superficie RPC entre `network_manager.gd` y `server_battle_manager.gd` — **confirmada**: `server_battle_manager.gd` tiene su propia sección "LEGACY RPCs" (líneas ~557-586) que redeclara `server_request_deploy_mech`/`_move`/`_rotate`/`_fire`/`_end_activation` como `@rpc` propios, además de los que ya existen en `network_manager.gd` reenviando a los mismos handlers. Funcionalmente inofensivo (ambos acaban llamando al mismo `_handle_*`), pero es superficie RPC duplicada y confusa sobre quién es la fuente de verdad. No se ha tocado en esta sesión — fusionar/eliminar la sección legacy es candidato para Fase T5 (requiere confirmar que ningún cliente depende de invocar esos RPCs directamente sobre `ServerBattleManager` en vez de `NetworkManager`).
- [x] Añadir test: intento de acción fuera de turno — `test_validate_movement_rejects_out_of_activation_order`, `test_validate_weapon_attack_rejects_out_of_activation_order`, `test_validate_end_activation_rejects_wrong_mech_in_queue`
- [x] Añadir test: intento de acción sobre unidad ajena — ya cubierto por `test_validate_movement_not_your_mech` (preexistente) + nuevo `test_validate_end_activation_rejects_other_players_mech`
- [x] Añadir test: acción con datos fuera de rango — ya cubierto por `test_validate_weapon_attack_out_of_range` e `test_validate_weapon_attack_invalid_weapon_index` (preexistentes) + nuevo `test_validate_end_activation_rejects_unknown_mech`

Verificado con Godot 4.5.1: suite de `server_action_validator` 45/45 passing, suite completa del proyecto sin regresiones frente al baseline (los fallos preexistentes de `test_database_manager.gd`/`test_logger.gd` no relacionados con esta fase se mantienen igual).

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

## FASE T6 — Backlog de bugs y mejoras reportadas manualmente

Bugs y tareas de pulido detectadas por el desarrollador jugando el build actual (no derivadas de auditoría de código). A diferencia de T0-T5, esto no es deuda técnica estructural sino comportamiento incorrecto o incompleto observable en juego.

### General & Refactorización
- [ ] **Rebranding de IP:** Buscar y reemplazar todas las referencias de texto y código de "BattleTech" a "Steel Titans".
- [ ] **Sistema de Localización:** Implementar el sistema base para la traducción y localización de todos los textos del juego.

### Estabilidad y rendimiento
- [x] **Memory leaks al cerrar el juego — causa principal encontrada y corregida:** `TutorialManager` (autoload persistente) guarda una referencia fuerte a `battle_controller` (`RefCounted` con 5 señales conectadas) y a `_battle_scene`. Solo se limpiaban en `_on_tutorial_completed()`/`reset_tutorial()`; `skip_tutorial()` no lo hacía, y **ninguna** vía cubría salir a mitad de partida (Exit to Main Menu / Quit Game del menú de pausa nuevo, o cerrar la ventana) — el caso más probable en la práctica. Nuevo helper `_cleanup_battle_controller()` centraliza la limpieza y se llama desde los tres finales del tutorial, más un `battle_scene._exit_tree()` nuevo que la fuerza si la escena se destruye con el tutorial todavía activo.
  - Investigadas también otras dos pistas del mismo análisis, descartadas por ahora: (a) las texturas cacheadas en `combat_animation_manager.gd` — en realidad viven en la caché global de `ResourceLoader` de Godot por diseño, no algo que un `RefCounted` pueda "soltar" limpiando su propio diccionario; (b) los `await get_tree().create_timer(...)` en `_on_handler_battle_ended()`/`_on_handler_opponent_disconnected()` que retienen la corrutina (y su `self`) unos segundos - de menor severidad, pendiente de revisar si el problema persiste tras el fix principal.

### UI/UX
- [x] **Chat / Combat Log:** ahora anima con `Tween` y se colapsa hacia su borde inferior fijo (`_anchor_bottom_y`) en vez de encogerse hacia arriba (`scripts/ui/battle_combat_log_panel.gd`).
- [x] **Menú de pausa in-game:** botón "☰" persistente (`battle_ui.gd`) abre un panel con Resume / volumen (HSlider ligado a `AudioManager.master_volume`) / Exit to Main Menu / Quit Game. Pausa el árbol (`get_tree().paused`) solo en single player; en multiplayer no pausa para no desincronizar.

### Gráficos y animaciones
- [x] **Feedback visual de LoS:** `battle_overlay_menu._update_los_overlay()` tiñe ahora las casillas **fuera** de LoS con un overlay oscuro semi-transparente (antes hacía lo contrario: resaltaba en verde las visibles). Sigue siendo un toggle opcional vía el menú "eye", como el resto de overlays de terreno.
  - **Bug crítico encontrado después:** el overlay no se veía en absoluto, independientemente del color. `battle_overlay_manager.sync_from_ui(ui)` se llamaba pasando `battle_ui.gd`, pero `los_overlay_visible`/`los_overlay_hexes` viven en su hijo `eye_menu_panel` (`BattleOverlayMenu`) - la comprobación `"los_overlay_visible" in ui_node` nunca era cierta sobre `battle_ui.gd`, así que el overlay se calculaba bien pero jamás llegaba a `overlay_manager` para renderizarse. Bug preexistente, no introducido por el cambio de color de arriba. Corregido para que `sync_from_ui()` mire dentro de `eye_menu_panel` cuando las propiedades no están en el nodo directo.
  - **Bug de rendimiento relacionado:** el merge de overlays con tiles en `hex_surface_renderer.update_surfaces()` buscaba el tile de cada overlay con un escaneo lineal de todo `surf_entries` — barato con un puñado de hexes (despliegue, movimiento), pero un overlay que cubre buena parte del mapa (como el de LoS, una vez arreglado el bug anterior) lo convertía en O(overlays × tiles) y podía colgar/laguear el juego al activarlo. Sustituido por una tabla `hex -> tile` en O(1).
- [x] **Clipping de proyectiles:** causa real — `hex_surface_renderer.gd` calcula el z_index del terreno dinámicamente (`avg_y + elevación*10`) para el pintado por profundidad, y en hexes al sur del mapa o con elevación alta supera fácilmente el z_index fijo (1000, con el padre `effects_layer` a 500) que usaban los proyectiles/flashes/impactos de `combat_animation_manager.gd`. Ahora esos nodos usan `z_as_relative = false` + `z_index = 4000` (absoluto, por debajo del límite de Godot de 4096 pero por encima de cualquier profundidad de terreno realista).
- [x] **VFX de temperatura:** reutiliza el patrón ya existente de `show_shutdown_effect()`/`smoke_shutdown.svg`. Nuevo `Mech.show_heat_dissipation_effect(dissipated)` (puff de vapor que sube y se desvanece, en sprite propio para no interferir con el tween en bucle del humo de shutdown) y `Mech.update_overheat_glow(heat)` (tinte rojo/naranja progresivo desde el umbral de shutdown de `HeatSystem`, sin efecto si el mech ya está apagado). Conectados en `battle_components_integrator._on_mech_heat_processed()`.

### Modo Tutorial
- [x] **Z-Index y bloqueos de modal:** el fix inicial (mouse_filter en el contenedor) no bastaba — `title_label`/`content_label`/`tip_label` (RichTextLabel, `STOP` por defecto) seguían capturando clics porque `mouse_filter` no se hereda de los padres. Ahora `_set_mouse_filter_recursive()` pone `IGNORE` en todo el árbol del hint cuando es `action_required_mode` (`scripts/ui/tutorial_hint_popup.gd`).
- [x] **Animaciones de combate:** nodos temporales con `process_mode = PROCESS_MODE_ALWAYS` para no congelarse si una pausa del tutorial cae en mitad del vuelo (`scripts/managers/combat_animation_manager.gd`).
- [x] **Fase de despliegue / iniciativa / ataque / melee / calor:** `TutorialBattleController.can_end_turn()` mantiene el botón END bloqueado (grisado, con toast si se pulsa) en todos estos pasos. La única fase donde el motor real necesita que el jugador pulse END es **movimiento** (`MOVEMENT_SELECT_HEX`/`FACING_EXPLANATION`/`FACING_SELECT`): disparo y ataque físico completan la activación solos al ejecutarse, pero el movimiento no — sin pulsar END ahí el turno nunca avanza a la fase de armas. (Mi primer intento bloqueaba END también en movimiento e introducía un `ROUND_END_PROMPT` inexistente en el motor real; revertido tras comprobar en `turn_manager.gd` que las rondas avanzan solas.)
- [x] **Fase de iniciativa (bonificador):** +1 por cada 5 toneladas bajo 100, calculado en `battle_initiative_presenter._compute_initiative_bonus` y aplicado también en tutorial. Los dados del tutorial pasaron de rangos aleatorios (5-6 / 1-3) a **fijos** (jugador 6+6, enemigo 1+1) porque con el bonus real el Hunchback (50t, +10) podía ganarle al Atlas (100t, +0) con dados aleatorios; fijos, `12 >= 2+10` se cumple siempre (empate cuenta como victoria del jugador).
- [x] **Fase de movimiento (jugador) — causa raíz real:** el jugador podía moverse a cualquier hex alcanzable pese a la validación. El motivo no era la validación (que funcionaba) sino que **`allowed_hexes` estaba siempre vacío**: `battle_scene.select_movement_type()` notificaba al tutorial vía `_trigger_tutorial_event()`, que es un **stub deprecado sin cuerpo** (`func _trigger_tutorial_event(...): pass`). Al no llegar nunca "el jugador pulsó WALK", el tutorial no avanzaba de `MOVEMENT_SELECT_WALK` a `MOVEMENT_SELECT_HEX`, `_setup_hex_selection()` no se ejecutaba y `allowed_hexes` quedaba vacío — y `is_hex_allowed()` devuelve `true` para todo cuando la lista está vacía. Sustituido por `_notify_tutorial("movement_type_selected", "walk"/"run"/"jump")`. Lo mismo pasaba con `movement_completed`, ahora notificado desde `_on_movement_execution_complete()` (cuando el mech llega al hex, no tras elegir facing). La restricción del clic vive en `battle_movement_handler.handle_movement_click()`, mismo nivel y patrón que `battle_deployment_manager.handle_hex_click()`; el overlay muestra todo el rango alcanzable y el hex del tutorial encima, igual que hace el despliegue.
- [x] **Fase de movimiento (enemigo):** dos bugs. (a) El enemigo no se movía en su fase de movimiento: al desactivar la IA real, el movimiento scriptado solo se aplicaba mucho más tarde como narración (`ENEMY_TURN_MOVEMENT`); ahora `battle_scene._handle_enemy_unit_activation()` llama a `TutorialManager.force_enemy_movement_to_target()` durante `turn_manager.current_phase == MOVEMENT`. (b) Hex objetivo corregido a `(6,8)` (`ENEMY_MOVEMENT_TARGET_HEX`), adyacente al `(6,9)` del jugador.
- [x] **Ataque no respondía al clicar el enemigo (crítico):** `TutorialManager._force_enemy_move()` movía al enemigo **solo visualmente** — nunca llamaba a `hex_grid.set_unit()`, al contrario que `_force_enemy_deploy()` y que el movimiento normal (`battle_movement_handler.execute_movement()`). El grid seguía con el enemigo registrado en su hex anterior y el nuevo vacío, así que `hex_grid.get_unit(hex)` devolvía `null` al clicarlo → sin objetivo válido → el selector de armas no se abría y el ataque parecía no responder. Afectaba igual al ataque físico y al targeting (todos usan `get_unit`), y dejaba una unidad fantasma bloqueando el hex viejo para pathfinding/LoS. Ahora libera el hex viejo, registra el nuevo y refresca visibilidad.
- [x] **Fase de ataque (hint):** el hint indica tocar el nombre del arma para ver detalles y usar el switch para seleccionarla. Además, el popup en modo `action_required` tenía `fit_content = true` en sus labels, así que con texto largo **crecía más allá de su caja** (CenterContainer no recorta a sus hijos) y se desbordaba sobre los paneles reales del juego. Ahora ese modo usa tamaño **fijo** (`fit_content = false` + `custom_minimum_size`, texto scrolleable dentro), de modo que no puede tapar la UI por muy largo que sea el texto; el modo normal (centrado) restaura `fit_content = true`.
- [x] **Ronda 1 saltaba directa de disparo a calor sin pararse en melee:** el motor real pasa por `WEAPON_ATTACK → PHYSICAL_ATTACK → HEAT` (`turn_manager.advance_phase`), pero `on_weapon_fired()` avanzaba directo a `HEAT_EXPLANATION`, ignorando la fase de ataque físico por completo. Como el jugador y el enemigo ya quedan adyacentes tras el movimiento forzado de la ronda 1 (`(6,9)`/`(6,8)`), no hace falta un paso de aproximación: ahora se reutilizan los pasos `PHYSICAL_EXPLANATION`/`PHYSICAL_ATTACK` (ya existían, pero solo se usaban en la ronda 2 que ya no se juega) entre el disparo y la explicación de calor. Se añadió también un nuevo paso `END_OF_TURN` explícito (recap de movimiento→armas→melee→calor) antes de pasar a la iniciativa de la ronda 2, para que quede claro que el turno 1 ha terminado.
- [x] **Fin de ronda 2 / cierre del tutorial:** la iniciativa automática de la ronda 2 (`turn_manager.start_turn()` → `show_initiative_screen()`) se disparaba a la vez que el guion post-combate del tutorial (recap del turno enemigo + explicación de daño), dos modales bloqueantes compitiendo → softlock. Ahora `_show_heat_explanation()` bloquea esa iniciativa automática (`force_action "block_initiative"`, mismo mecanismo ya usado para la ronda 1) y el paso silencioso `WAITING_ROUND2_INITIATIVE` la desbloquea y la muestra manualmente cuando el guion termina. Al cerrar el hint de "ROUND 2 BEGINS", el tutorial termina ahí (no continúa a shutdown/explosión de munición, que seguían siendo contenido de una ronda 2 que ya no se juega): marca la partida como completada y navega a `team_setup.tscn` para una partida real.
- [x] **Melee no avanzaba tras atacar (calor/fin de turno se saltaban en silencio):** mismo patrón de bug que el de movimiento — `_notify_tutorial("physical_attack_completed")` tenía su caso listo en el dispatcher pero **nadie lo llamaba nunca**. `_on_physical_attack_complete()` (el callback real, invocado desde `battle_components_integrator` tras cada puñetazo/patada) nunca lo disparaba, así que `TutorialBattleController` se quedaba esperando `on_physical_attack_completed()` para siempre: la partida seguía sola (calor, fin de turno real, iniciativa de la ronda 2) sin mostrar ni un hint más. Añadida la llamada que faltaba.
- [x] **Menú de ataque físico sin estilo:** `create_physical_attack_button()` no aplicaba el `theme` compartido (a diferencia de `create_movement_button()`) y el panel no tenía `create_main_panel_style()` — botones grises por defecto y título en magenta suelto. Igualado al mismo patrón que el selector de movimiento.
- [x] **Tras el fin de turno no se enseñaba a avanzar de ronda:** el paso `END_OF_TURN` pasaba directo a mostrar la iniciativa de la ronda 2 sin que el jugador tuviera que hacer nada. Ahora hay un paso intermedio `PROMPT_END_TURN` (acción requerida, sin bloquear el juego) que pide pulsar el botón END real; `battle_ui._on_end_turn_pressed()` notifica al tutorial (`notify_end_turn_pressed`) y solo entonces se avanza a la iniciativa — pero sin llamar a `end_current_activation()` en este caso concreto, porque a esa altura el motor ya completó la fase de calor y el avance de ronda en segundo plano (solo estaba oculto tras `block_initiative`), así que no hay ninguna activación real pendiente y forzarla arriesgaría un doble avance de ronda. Además, la tirada de iniciativa de la ronda 2 ya **no está trucada**: `TutorialManager.initiative_roll_forced` se pone a `false` justo antes de mostrarla (`force_action "stop_forcing_initiative"`), así que `initiative_screen.gd` tira dados reales (con el bonificador de tonelaje real aplicado) en vez de forzar 6+6/1+1 como en la ronda 1.
- [x] **Menú de ataque físico sin estilo:** `create_physical_attack_button()` nunca aplicaba el `theme` compartido (a diferencia de `create_movement_button()`), así que salía con botones grises por defecto de Godot; el panel tampoco tenía `create_main_panel_style()` aplicado, y el título usaba magenta suelto en vez de un `create_title_label()` themed. Igualado al mismo patrón que el selector de movimiento.

---

## Qué NO incluye este roadmap

Presupuesto, contratación, marketing, publicación en tiendas, localización y monetización ya están cubiertos con detalle en [doc/project/ROADMAP.md](doc/project/ROADMAP.md) (Fases 4-8). Ese documento sigue siendo válido como plan de producto a largo plazo; simplemente asume un estado de "Fase 3 gameplay" que este análisis matiza con lo que realmente hay en el repo hoy.

---

## Orden de prioridad entre fases

- [x] **T0** — no perder trabajo, no dejar landmines (`.backup`, credenciales en claro)
- [~] **T1** — el núcleo del juego (`battle_scene.gd`) necesita tests antes de seguir creciendo: primer smoke test hecho y verificado con Godot real; la extracción grande de handlers de red y despliegue/activación queda pendiente de una sesión incremental con TDD
- [x] **T3** — la validación server-side es lo único que impide hacer trampas en PvP; verificarla vale más que features nuevas — auditada, 2 huecos reales corregidos con TDD (orden de activación en movimiento/disparo/físico, y en fin de activación)
- [x] **T2** — manejo de errores consistente, para que T1/T3 sean depurables
- [ ] **T4** — completar el core loop de gameplay (progresión, economía, reparación)
- [ ] **T5** — limpieza estructural cuando haya margen
- [ ] **T6** — backlog de bugs y pulido (UI/UX, gráficos, tutorial) reportado jugando el build actual
