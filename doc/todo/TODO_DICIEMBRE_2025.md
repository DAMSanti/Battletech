# 📅 TODO DICIEMBRE 2025 - Plan Actualizado
## Steel Titans: Tactical Warfare

**Fecha de creación:** 2 de Diciembre, 2025  
**Estado:** Fases 0, 1, 2 COMPLETADAS + Fase 3 ~25%  
**Meta del mes:** Continuar adelantando Fase 3 (Gameplay)

---

## 🏆 LOGROS COMPLETADOS (Diciembre 1-2)

### Infraestructura (Fases 0-2) ✅ 100%
- ✅ 875 tests (841 pasando - 96.1%)
- ✅ 100% cobertura core (334/334 funciones)
- ✅ Matchmaking + ELO funcional
- ✅ CI/CD + Redis + Baneos + Audit logging
- ✅ TDD documento completo
- ✅ API REST versionada (v1)
- ✅ Let's Encrypt SSL
- ✅ Backups automáticos

### Gameplay Adelantado (Fase 3 Parcial) ✅ ~25%
- ✅ **Balance de armas** - weapons_balance.csv + WEAPONS_BALANCE.md
- ✅ **Sistema de IA** - BattleAI con dificultades EASY/NORMAL/HARD
- ✅ **Selector de dificultad** - Integrado en team_setup.tscn
- ✅ **Tutorial 1v1** - TutorialManager + TutorialHintPopup (Atlas vs Hunchback)
- ✅ **Pantalla fin batalla** - BattleEndScreen con estadísticas
- ✅ **Stats tracker** - BattleStatsTracker (daño, precisión, MVP)
- ✅ **Indicadores de mech** - MechStatusIndicators (barras HP/Heat)

---

## 📋 PLAN DICIEMBRE 2025 (Días 3-31)

### 🗓️ SEMANA 1 (3-8 Dic): Testing y Estabilización

| # | Tarea | Prioridad | Estimación | Estado |
|---|-------|-----------|------------|--------|
| 1.1 | **Probar tutorial en dispositivo real** | 🔴 | 2h | ⬜ |
| 1.2 | Probar IA en todas las dificultades | 🔴 | 2h | ⬜ |
| 1.3 | Fix bugs del tutorial/IA encontrados | 🔴 | 4h | ⬜ |
| 1.4 | Tests unitarios para TutorialManager | 🟡 | 2h | ⬜ |
| 1.5 | Tests unitarios para BattleAI | 🟡 | 2h | ⬜ |
| 1.6 | Documentar nuevos sistemas | 🟢 | 2h | ⬜ |

**Entregable Semana 1:** Tutorial y IA estables y testeados

---

### 🗓️ SEMANA 2 (9-15 Dic): Sistema de Progresión Base

| # | Tarea | Prioridad | Estimación | Estado |
|---|-------|-----------|------------|--------|
| 2.1 | **Diseño de progresión de pilotos** | 🔴 | 3h | ⬜ |
| 2.2 | Implementar sistema de XP | 🔴 | 4h | ⬜ |
| 2.3 | UI de estadísticas de piloto | 🟡 | 3h | ⬜ |
| 2.4 | Persistencia de XP (PlayerDataManager) | 🔴 | 2h | ⬜ |
| 2.5 | Rewards post-batalla (XP + C-Bills base) | 🟡 | 3h | ⬜ |

**Entregable Semana 2:** Pilotos ganan XP después de batallas

---

### 🗓️ SEMANA 3 (16-22 Dic): Economía Básica

| # | Tarea | Prioridad | Estimación | Estado |
|---|-------|-----------|------------|--------|
| 3.1 | **Sistema de C-Bills** | 🔴 | 4h | ⬜ |
| 3.2 | Rewards de victoria/derrota | 🔴 | 2h | ⬜ |
| 3.3 | UI de balance de C-Bills | 🟡 | 2h | ⬜ |
| 3.4 | Sistema de reparación básico | 🟡 | 4h | ⬜ |
| 3.5 | Costo de reparación proporcional al daño | 🟡 | 2h | ⬜ |

**Entregable Semana 3:** Economía funcional básica

---

### 🗓️ SEMANA 4 (23-31 Dic): Pulido y Ranked

| # | Tarea | Prioridad | Estimación | Estado |
|---|-------|-----------|------------|--------|
| 4.1 | **UI de Rankings/Leaderboard** | 🟡 | 4h | ⬜ |
| 4.2 | Pantalla de perfil del jugador | 🟡 | 3h | ⬜ |
| 4.3 | Historial de partidas | 🟢 | 3h | ⬜ |
| 4.4 | Polish: animaciones de transición | 🟢 | 4h | ⬜ |
| 4.5 | Polish: feedback visual de combate | 🟢 | 4h | ⬜ |

**Entregable Semana 4:** Experiencia más pulida + Rankings visibles

---

## 🎯 CRITERIOS DE ÉXITO - Fin de Diciembre

### Must Have (Obligatorio)
- [ ] Tutorial funcional sin bugs críticos
- [ ] IA jugable en las 3 dificultades
- [ ] Sistema de XP básico funcionando
- [ ] C-Bills ganados/gastados

### Should Have (Importante)
- [ ] Reparación de mechs
- [ ] UI de Rankings
- [ ] Tests para nuevos sistemas

### Nice to Have (Deseable)
- [ ] Historial de partidas
- [ ] Animaciones de polish
- [ ] Perfil de jugador mejorado

---

## 📊 PROGRESO FASE 3

| Área | Estado Actual | Objetivo Dic |
|------|---------------|--------------|
| Balance combate | ✅ 100% | 100% |
| IA Single-player | ✅ 100% | 100% |
| Tutorial | ✅ 100% | 100% |
| UI/UX Mejoras | ✅ 100% | 100% |
| Progresión pilotos | ⬜ 0% | 50% |
| Economía | ⬜ 0% | 30% |
| Rankings UI | ⬜ 0% | 50% |
| **TOTAL FASE 3** | **~25%** | **~50%** |

---

## 📁 ARCHIVOS CREADOS/MODIFICADOS HOY (2 Dic)

### Nuevos archivos:
```
scripts/managers/
├── tutorial_manager.gd          # Sistema de tutorial
├── battle_stats_tracker.gd      # Tracking de estadísticas

scripts/ui/
├── tutorial_hint_popup.gd       # Popups del tutorial
├── battle_end_screen.gd         # Pantalla fin de batalla
├── mech_status_indicators.gd    # Barras HP/Heat

doc/design/
├── TUTORIAL_DESIGN.md           # Diseño del tutorial
├── WEAPONS_BALANCE.md           # Documentación balance
├── WEAPONS_BALANCE.csv          # Datos de armas
```

### Archivos modificados:
```
scripts/managers/battle_ai.gd    # Sistema de dificultades
scripts/battle_scene.gd          # Integración tutorial + stats
scripts/ui/screens/main_menu.gd  # Prompt de tutorial
scenes/team_setup.tscn           # Selector de dificultad
scripts/ui/team_setup.gd         # Lógica de dificultad
project.godot                    # Autoload TutorialManager
```

---

## 🚫 FUERA DE SCOPE DICIEMBRE

Estas tareas quedan para **Enero 2026**:
- ❌ Árbol de habilidades completo
- ❌ Sistema de salvage
- ❌ Tienda de equipamiento
- ❌ Ranked competitivo completo
- ❌ Campaña single-player
- ❌ Arte profesional
- ❌ Audio completo
- ❌ Battle Pass

---

## 📝 NOTAS TÉCNICAS

### Archivos clave del tutorial:
```gdscript
# TutorialManager (autoload)
TutorialManager.should_start_tutorial()  # ¿Primera partida?
TutorialManager.start_tutorial()          # Inicia tutorial
TutorialManager.skip_tutorial()           # Salta tutorial

# Triggers desde battle_scene.gd
_trigger_tutorial_event("initiative_phase")
_trigger_tutorial_event("movement_phase", {"is_player": true})
_trigger_tutorial_event("target_selected")
```

### Sistema de IA:
```gdscript
# BattleAI.Difficulty
enum Difficulty { EASY, NORMAL, HARD }

# Configuración por dificultad
EASY:   aggression=1.0, fire_all_weapons=true, heat_management=false
NORMAL: aggression=0.7, heat_management=true, prefer_medium_range=true
HARD:   aggression=0.6, use_cover=true, focus_damaged=true
```

---

## 🔗 REFERENCIAS

- [ROADMAP.md](../project/ROADMAP.md) - Plan completo actualizado
- [TODO_DECEMBER_2025.md](../archive/TODO_DECEMBER_2025.md) - Sprint anterior (archivado)
- [TUTORIAL_DESIGN.md](../design/TUTORIAL_DESIGN.md) - Diseño del tutorial
- [WEAPONS_BALANCE.md](../design/WEAPONS_BALANCE.md) - Balance de armas
- [TDD.md](../design/TDD.md) - Documento técnico

---

*Creado: 2 de Diciembre, 2025*  
*Próxima revisión: 9 de Diciembre, 2025*
