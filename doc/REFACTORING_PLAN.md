# 🔧 Plan de Refactorización
## Steel Titans: Tactical Warfare

**Fecha:** 30 de Noviembre, 2025  
**Estado:** ✅ Fase 2 COMPLETADA, ✅ Fase 3 COMPLETADA, ✅ Fase 4 COMPLETADA, ✅ Fase 5 COMPLETADA  
**Objetivo:** Aplicar principios SOLID, reducir archivos >500 líneas

---

## 📊 Resumen de Progreso Total

| Fase | Archivo Original | Reducción | Líneas Extraídas |
|------|------------------|-----------|------------------|
| Fase 2 | battle_scene.gd | 4542 → 2337 (~49%) | ~4,920 |
| Fase 3 | battle_ui.gd | 3184 → 1224 (~62%) | 497 + 523 + 282 + 249 + 334 + 500 = 2385 |
| Fase 4 | component_database.gd | 2086 → 194 (~91%) | 1183 + 372 + 508 + 32 = 2095 |
| Fase 5 | server_battle_manager.gd | 1401 → 793 (~43%) | 223 + 187 + 148 = 558 |
| **TOTAL** | - | - | **~9,958 líneas** |

---

## 📊 Progreso de Extracción - battle_scene.gd

| Componente | Archivo | Estado | Líneas |
|------------|---------|--------|--------|
| BattleCameraController | `scripts/core/battle/battle_camera_controller.gd` | ✅ CREADO | ~200 |
| BattleDeploymentManager | `scripts/core/battle/battle_deployment_manager.gd` | ✅ CREADO | ~270 |
| BattleMovementHandler | `scripts/core/battle/battle_movement_handler.gd` | ✅ CREADO | ~350 |
| BattleCombatExecutor | `scripts/core/battle/battle_combat_executor.gd` | ✅ CREADO | ~330 |
| BattleHeatManager | `scripts/core/battle/battle_heat_manager.gd` | ✅ CREADO | ~180 |
| BattleStateCoordinator | `scripts/core/battle/battle_state_coordinator.gd` | ✅ CREADO | ~250 |
| BattleNetworkHandler | `scripts/core/battle/battle_network_handler.gd` | ✅ CREADO | ~450 |
| BattleInputRouter | `scripts/core/battle/battle_input_router.gd` | ✅ CREADO | ~500 |
| BattleOverlayManager | `scripts/core/battle/battle_overlay_manager.gd` | ✅ CREADO | ~270 |
| BattleComponentsIntegrator | `scripts/core/battle/battle_components_integrator.gd` | ✅ CREADO | ~1100 |
| MechFactory | `scripts/entities/mech_factory.gd` | ✅ CREADO | ~200 |
| BattleInitiativePresenter | `scripts/core/battle/battle_initiative_presenter.gd` | ✅ CREADO | ~180 |
| ActiveMechIndicator | `scripts/ui/active_mech_indicator.gd` | ✅ CREADO | ~90 |
| CombatResultPresenter | `scripts/ui/combat_result_presenter.gd` | ✅ CREADO | ~200 |
| LanceData (helpers) | `scripts/core/battle/lance_data.gd` | ✅ AMPLIADO | ~350 |

**Total extraído:** ~4,920 líneas de lógica modular

### ✅ Resultado battle_scene.gd: 4542 → 2337 líneas (~49% reducción)

---

## ✅ Componentes Completados

### 1. BattleCameraController
- Touch/mouse input handling
- Camera zoom/pan
- Pinch detection

### 2. BattleDeploymentManager
- Fase de deployment
- Zonas de deployment
- Deploy de IA
- Señales: `deployment_phase_started`, `mech_deploy_requested`, `my_deployment_complete`

### 3. BattleMovementHandler
- Cálculo de hexes alcanzables
- Preview de path
- Selección de tipo de movimiento
- Ejecución de movimiento
- Señales: `movement_completed`, `movement_cancelled`, `facing_selected`

### 4. BattleCombatExecutor
- Targeting de armas y físico
- Ejecución de ataques
- Resolución de daño
- Señales: `weapon_attack_completed`, `physical_attack_completed`, `target_destroyed`

### 5. BattleHeatManager
- Procesamiento de fase de calor
- Disipación de calor
- Shutdown por sobrecalentamiento
- Señales: `heat_phase_completed`, `mech_shutdown`, `mech_destroyed_by_heat`

### 6. BattleStateCoordinator
- Gestión de estados del juego
- Cambios de fase
- Verificación de fin de batalla
- Señales: `state_changed`, `phase_changed`, `battle_ended`

### 7. BattleNetworkHandler
- Todos los handlers de eventos de red (_on_net_*)
- Todos los requests multiplayer (mp_request_*)
- Señales para cada tipo de mensaje de red

### 8. BattleInputRouter
- Procesamiento unificado de input (touch/mouse)
- Gestos de cámara
- Long press detection
- Click debouncing
- Verificación de UI overlap
- Señales: `hex_clicked`, `hex_long_pressed`, `movement_gesture_detected`

### 9. BattleOverlayManager
- Gestión de overlays de hexágonos
- Overlays de deployment, movimiento, ataque
- Preview path rendering
- LOS overlay integration

### 10. BattleComponentsIntegrator
- Fachada que coordina todos los componentes
- Inicialización y configuración
- Conexión de señales
- API unificada para battle_scene.gd

---

## ✅ Fase 2: COMPLETADA - battle_scene.gd

**Resultado: 4542 → 2337 líneas (~49% reducción)**

Logros:
- ✅ Delegación completa a componentes
- ✅ Extraídos presenters de UI (Initiative, CombatResult, ActiveMechIndicator)
- ✅ Extraída lógica de creación de mechs a MechFactory
- ✅ Simplificada carga de lances via LanceData helpers
- ✅ Eliminados imports sin usar
- ✅ 128 funciones, promedio 18.3 líneas/función

---

## 🔄 Fase 3: Refactorización de battle_ui.gd (EN PROGRESO)

**Estado actual: 3184 → 1224 líneas (~62% reducción) ✅ META SUPERADA**

### Análisis Detallado del Archivo:

| Sección | Líneas | Contenido |
|---------|--------|-----------|
| Variables de clase | 1-117 | 100+ variables de UI |
| `_setup_ui()` | 139-1177 | **~1038 líneas** - Creación procedural de toda la UI |
| Turn/Phase handlers | 1178-1310 | ~130 líneas - Manejo de turnos y fases |
| Combat Log | 1334-1716 | ~380 líneas - Log de combate con tabs |
| Movement Selector | 1727-1812 | ~85 líneas - Selector Walk/Run/Jump/Turn |
| Physical Attack | 1836-1939 | ~100 líneas - Panel de ataque físico |
| Weapon Selector | 1939-2370 | ~430 líneas - Selección de armas |
| Mech Inspector | 2377-2870 | ~500 líneas - Inspector y paper doll dialog |
| Eye Menu/Overlays | 2873-3184 | ~310 líneas - Menú de overlays y LOS |

### Problema Principal: `_setup_ui()` tiene 1038 líneas de código procedural

La función crea todos los elementos UI con StyleBoxFlat inline repetitivos.

### Estrategia de Extracción:

1. **SteelTitansStyles** - Factory para StyleBoxFlat comunes
2. **BattleUIFactory** - Factory methods para crear componentes UI
3. **BattleCombatLogPanel** - Panel de log con tabs y chat
4. **BattleWeaponSelectorPanel** - Selector de armas completo
5. **BattleMechInspector** - Inspector de mech y paper doll
6. **BattleOverlayMenu** - Eye menu y toggles de overlay

### Componentes a Extraer:
| Componente | Responsabilidad | Líneas | Estado |
|------------|-----------------|--------|--------|
| SteelTitansStyles | StyleBoxFlat factory | 497 | ✅ INTEGRADO |
| BattleCombatLogPanel | Log con tabs y chat | 523 | ✅ INTEGRADO |
| BattleOverlayMenu | Eye menu y LOS | 282 | ✅ INTEGRADO |
| BattleMechInspector | Inspector completo | 249 | ✅ INTEGRADO |
| BattleUIFactory | Factory methods UI | 334 | ✅ INTEGRADO |
| BattleWeaponSelectorPanel | Selector de armas | ~500 | ✅ INTEGRADO |

**Total líneas en nuevos componentes:** 2,385 líneas

### Integración de SteelTitansStyles:
- ✅ Eliminados **TODOS los StyleBoxFlat.new()** inline de battle_ui.gd
- ✅ 20+ bloques de código de estilo reemplazados por llamadas a métodos

### Integración de BattleCombatLogPanel:
- ✅ Reemplazado todo el código inline del combat log (~170 líneas de _setup_ui)
- ✅ Eliminadas funciones: `_on_log_mode_changed`, `_update_log_mode_buttons`, `_update_chat_input_visibility`, `_on_toggle_log_collapse`, `_on_log_scrollbar_changed`, `_on_combat_log_scrolled`, `_update_scrollbar_range`, `_update_log_collapse_state`, `_refresh_combat_log`, `_add_message_to_log`, `_on_chat_message_submitted`, `_on_send_chat_pressed`, `_on_scrollbar_gui_input`
- ✅ Funciones delegadas: `add_combat_message()`, `add_chat_message()` → `log_panel.*`
- ✅ Señal `chat_message_sent` conectada a `_on_chat_message_from_panel()`
- ✅ Variables eliminadas: `combat_log`, `combat_log_scrollbar`, `combat_log_mode`, `full_button`, `short_button`, `chat_button`, `collapse_log_button`, `combat_log_collapsed`, `log_expanded_height`, `log_collapsed_height`, `message_history`, `chat_history`, `chat_input_container`, `chat_input`

### Integración de BattleOverlayMenu:
- ✅ Reemplazado todo el código de creación de eye menu (~100 líneas)
- ✅ Eliminadas funciones: `_create_overlay_toggle`, `_on_overlay_toggle_pressed`, `_apply_overlay_setting`, `_toggle_los_overlay`, `_update_los_overlay`, `_clear_los_overlay`
- ✅ Funciones delegadas: `refresh_los_overlay()`, `get_los_overlay_hexes()`, `is_los_overlay_visible()`
- ✅ Variables eliminadas: `overlay_elevation_toggle`, `overlay_coords_toggle`, `overlay_terrain_toggle`, `overlay_movement_toggle`, `overlay_los_toggle`, `overlay_settings`, `los_overlay_visible`, `los_overlay_hexes`

### Integración de BattleMechInspector:
- ✅ Reemplazado todo el código de inspector y paper doll (~210 líneas)
- ✅ Eliminadas funciones inline: `show_mech_inspector` (80 líneas), `show_mech_paper_doll_dialog` (120 líneas)
- ✅ Funciones delegadas: `show_inspector()`, `show_paper_doll_dialog()`, `hide_inspector()`
- ✅ Variables eliminadas: `mech_inspector_panel`, `mech_inspector_armor`, `mech_inspector_visible`
- ✅ Nueva variable: `mech_inspector: BattleMechInspector`

### Integración de BattleWeaponSelectorPanel:
- ✅ Extraído todo el selector de armas a componente independiente (~500 líneas)
- ✅ Señales: `weapons_confirmed`, `selection_cancelled`, `weapon_info_requested`
- ✅ Funcionalidad completa: selección de armas, info panel, toggle switches

### Integración de BattleUIFactory:
- ✅ Factory centralizado para creación de elementos UI (334 líneas)
- ✅ Métodos integrados en battle_ui.gd:
  - `create_turn_label()`, `create_phase_label()`
  - `create_end_turn_button()`, `create_cancel_button()`
  - `create_eye_button()`, `create_help_label()`
  - `create_mech_name_label()`, `create_mp_container()`, `create_mp_dot()`
  - `create_heat_bar()`, `create_heat_label()`
  - `create_title_label()`, `create_movement_button()`
  - `create_physical_attack_button()`
  - `create_confirmation_panel()`, `create_confirmation_message()`
  - `create_confirm_icon_button()`, `create_cancel_icon_button()`
- ✅ Reducción de ~150 líneas adicionales en battle_ui.gd

### Archivos Creados/Actualizados en Fase 3:

```
scripts/ui/
├── steel_titans_styles.gd         # 497 líneas - Factory de estilos Steel Titans (INTEGRADO)
├── battle_combat_log_panel.gd     # 523 líneas - Combat log con tabs FULL/SHORT/CHAT (INTEGRADO)
├── battle_overlay_menu.gd         # 282 líneas - Menú de overlays y LOS (INTEGRADO)
├── battle_mech_inspector.gd       # 249 líneas - Inspector y paper doll dialog (INTEGRADO)
├── battle_ui_factory.gd           # 334 líneas - Factory methods para UI (INTEGRADO)
├── battle_weapon_selector_panel.gd # ~500 líneas - Selector de armas completo (INTEGRADO)
└── battle_ui_components.gd        # 178 líneas - Fachada coordinadora de UI
```

### Resultado Final Fase 3:
- **battle_ui.gd:** 3184 → 1224 líneas (**62% reducción**, -1960 líneas)
- **steel_titans_styles.gd:** 497 líneas (todos los estilos centralizados)
- **battle_combat_log_panel.gd:** 523 líneas (combat log completo)
- **battle_overlay_menu.gd:** 282 líneas (eye menu y LOS overlay)
- **battle_mech_inspector.gd:** 249 líneas (inspector y paper doll)
- **battle_ui_factory.gd:** 334 líneas (factory methods UI)
- **battle_weapon_selector_panel.gd:** ~500 líneas (selector de armas)

### ✅ Fase 3 COMPLETADA

---

## ✅ Fase 4: Refactorización de component_database.gd (COMPLETADA)

**Estado: 2086 → 194 líneas (~91% reducción) ✅ META SUPERADA**

### Problema Original:
El archivo `component_database.gd` contenía 2086 líneas con:
- 1148 líneas de weapons_database (static var)
- 325 líneas de ammo_database (static var)
- 445 líneas de equipment_database (static var)
- ~110 líneas de funciones de consulta

### Estrategia de Extracción:
Separar los datos estáticos en archivos de datos independientes para:
1. Mejorar mantenibilidad de cada tipo de dato
2. Reducir tiempo de carga del archivo principal
3. Permitir modificaciones independientes
4. Evitar dependencias circulares mediante `component_types.gd`

### Archivos Creados:

```
scripts/core/data/
├── component_types.gd      # 32 líneas - Enums ComponentType y WeaponCategory
├── weapons_database.gd     # 1183 líneas - Base de datos de armas completa
├── ammo_database.gd        # 372 líneas - Base de datos de munición
└── equipment_database.gd   # 508 líneas - Base de datos de equipamiento
```

### Componentes Extraídos:

| Componente | Archivo | Líneas | Contenido |
|------------|---------|--------|-----------|
| ComponentTypes | `component_types.gd` | 32 | Enums para evitar dependencias circulares |
| WeaponsDatabase | `weapons_database.gd` | 1183 | Armas de energía, balísticas, misiles, especiales |
| AmmoDatabase | `ammo_database.gd` | 372 | Munición estándar y avanzada |
| EquipmentDatabase | `equipment_database.gd` | 508 | Heat sinks, jump jets, sensores, blindajes, motores |

### Estructura del Nuevo component_database.gd:
- Imports de archivos de datos
- Re-export de enums para compatibilidad hacia atrás
- Static accessors para databases (getters)
- Funciones de consulta delegadas a sub-databases
- Funciones de utilidad (ECM, CASE, hex_distance, etc.)

### Resultado Final Fase 4:
- **component_database.gd:** 2086 → 194 líneas (**91% reducción**)
- **component_types.gd:** 32 líneas (enums centralizados)
- **weapons_database.gd:** 1183 líneas (todas las armas)
- **ammo_database.gd:** 372 líneas (toda la munición)
- **equipment_database.gd:** 508 líneas (todo el equipamiento)

### Compatibilidad Hacia Atrás:
✅ `ComponentDatabase.weapons_database` sigue funcionando (getter)
✅ `ComponentDatabase.get_weapon()` sigue funcionando (delegación)
✅ `ComponentDatabase.ComponentType` sigue disponible (re-export)
✅ `ComponentDatabase.WeaponCategory` sigue disponible (re-export)

### ✅ Fase 4 COMPLETADA

---

## ✅ Fase 5: Refactorización de server_battle_manager.gd (COMPLETADA)

**Estado: 1401 → 793 líneas (~43% reducción) ✅ META CUMPLIDA**

### Problema Original:
El archivo `server_battle_manager.gd` contenía 1401 líneas con:
- Lógica de combate (weapon attacks, physical attacks, damage)
- Gestión de fases (initiative, movement, attack, heat)
- Validaciones y utilidades (match validation, hex calculations)
- RPCs y handlers de red

### Estrategia de Extracción:
Separar responsabilidades en clases helper especializadas:
1. **ServerCombatResolver** - Resolución de combate
2. **ServerPhaseManager** - Gestión de fases y turnos
3. **ServerMatchValidator** - Validaciones y utilidades

### Archivos Creados:

```
scripts/network/
├── server_battle_manager.gd    # 793 líneas - Coordinador principal (refactorizado)
├── server_combat_resolver.gd   # 223 líneas - Lógica de combate
├── server_phase_manager.gd     # 187 líneas - Gestión de fases
└── server_match_validator.gd   # 148 líneas - Validaciones y helpers
```

### Componentes Extraídos:

| Componente | Archivo | Líneas | Contenido |
|------------|---------|--------|-----------|
| ServerCombatResolver | `server_combat_resolver.gd` | 223 | execute_weapon_attack, execute_physical_attack, apply_damage, process_mech_heat |
| ServerPhaseManager | `server_phase_manager.gd` | 187 | execute_initiative_roll, build_activation_order, reset functions |
| ServerMatchValidator | `server_match_validator.gd` | 148 | validate_match_participant, validate_mech_ownership, hex_distance, get_facing_to_hex |

### Resultado Final Fase 5:
- **server_battle_manager.gd:** 1401 → 793 líneas (**43% reducción**)
- **server_combat_resolver.gd:** 223 líneas (resolución de combate)
- **server_phase_manager.gd:** 187 líneas (gestión de fases)
- **server_match_validator.gd:** 148 líneas (validaciones)

### ✅ Fase 5 COMPLETADA

---

## 📊 Estado Actual - Archivos Problemáticos

| Archivo | Líneas | Estado | Prioridad |
|---------|--------|--------|-----------|
| `battle_scene.gd` | 2337 | ✅ Reducido 49% | ✅ COMPLETADO |
| `battle_ui.gd` | 1224 | ✅ Reducido 62% | ✅ COMPLETADO |
| `component_database.gd` | 194 | ✅ Reducido 91% | ✅ COMPLETADO |
| `server_battle_manager.gd` | 793 | ✅ Reducido 43% | ✅ COMPLETADO |

---

## 🧪 Verificación de Compilación

```bash
# Verificar que compila sin errores
G:\godot\Godot_v4.5.1-stable_win64.exe --headless --check-only --path "G:\Battletech"
```

✅ **Última verificación:** Todos los componentes compilan correctamente

---

## 📁 Estructura de Archivos Creados

```
scripts/core/battle/
├── battle_camera_controller.gd    # ~200 líneas
├── battle_deployment_manager.gd   # ~270 líneas
├── battle_movement_handler.gd     # ~350 líneas
├── battle_combat_executor.gd      # ~330 líneas
├── battle_heat_manager.gd         # ~180 líneas
├── battle_state_coordinator.gd    # ~250 líneas
├── battle_network_handler.gd      # ~450 líneas
├── battle_input_router.gd         # ~500 líneas
├── battle_overlay_manager.gd      # ~270 líneas
└── battle_components_integrator.gd # ~750 líneas

scripts/core/data/
├── component_types.gd             # 32 líneas - Enums
├── weapons_database.gd            # 1183 líneas - Armas
├── ammo_database.gd               # 372 líneas - Munición
└── equipment_database.gd          # 508 líneas - Equipamiento

scripts/network/
├── server_combat_resolver.gd      # 223 líneas - Combate
├── server_phase_manager.gd        # 187 líneas - Fases
└── server_match_validator.gd      # 148 líneas - Validaciones
```

**Total de código modular:** ~6,203 líneas
