# 📅 TODO DICIEMBRE 2025 - FASE 2
## Steel Titans: Tactical Warfare - Adelantando Gameplay

**Objetivo:** Aprovechar el tiempo restante de diciembre para adelantar Fase 3 (Gameplay)  
**Período:** 29 Dic 2025 - 31 Dic 2025 (3 días bonus)  
**Estado base:** Fases 0, 1 y 2 COMPLETADAS ✅

---

## 🎯 META DE ESTA FASE

> **"Aprovechar el impulso de diciembre para adelantar las tareas de gameplay más críticas de Enero"**

---

## ✅ RESUMEN DICIEMBRE (Completado)

| Fase | Objetivo | Estado |
|------|----------|--------|
| Fase 0 | Pre-producción | ✅ 100% |
| Fase 1 | Core Técnico | ✅ 100% |
| Fase 2 | Backend | ✅ 100% |
| **Total** | **3 fases completas** | **1 mes adelantado** |

**Logros destacados:**
- 875 tests (841 pasando - 96.1%)
- 100% cobertura core (334/334 funciones)
- Matchmaking + ELO funcional
- CI/CD + Redis + Baneos + Audit logging
- TDD documento completo

---

## 📋 TAREAS ADELANTABLES - Fase 3 Gameplay

### Prioridad 1: Balance y Combate (Impacto Alto, Riesgo Bajo)

| # | Tarea | Prioridad | Estimación | Dependencias |
|---|-------|-----------|------------|--------------|
| 3.1.1 | **Spreadsheet de balance de armas** | 🔴 | 3h | Ninguna |
| 3.1.2 | Implementar tabla de balance en código | 🔴 | 2h | 3.1.1 |
| 3.1.3 | Shutdown por calor excesivo | 🟡 | 2h | Ninguna |
| 3.1.4 | Explosión de munición | 🟡 | 3h | Ninguna |

**Detalle 3.1.1 - Spreadsheet de Balance:**
```
Crear weapons_balance.csv con:
- Nombre, Daño, Calor, Rango (min/short/med/long)
- Tonelaje, Slots críticos, Munición
- DPS efectivo, Heat/Damage ratio
```

### Prioridad 2: IA Básica (Impacto Alto, Complejidad Media)

| # | Tarea | Prioridad | Estimación | Dependencias |
|---|-------|-----------|------------|--------------|
| 3.4.1 | **IA de combate básica** | 🔴 | 6h | Ninguna |
| 3.4.2 | Selector de dificultad (Easy/Normal/Hard) | 🟡 | 2h | 3.4.1 |
| 3.4.3 | IA: Evaluación de amenazas | 🟡 | 3h | 3.4.1 |

**Detalle 3.4.1 - IA Básica:**
```gdscript
# battle_ai.gd ya existe, pero necesita:
- Evaluación de posición táctica
- Selección inteligente de objetivos
- Gestión de calor
- Uso de cobertura
```

### Prioridad 3: Tutorial (Impacto Alto, Esfuerzo Medio)

| # | Tarea | Prioridad | Estimación | Dependencias |
|---|-------|-----------|------------|--------------|
| 3.3.1 | **Diseño de tutorial (documento)** | 🔴 | 2h | Ninguna |
| 3.3.2 | Sistema de hints/tooltips | 🟡 | 3h | Ninguna |
| 3.3.3 | Misión tutorial básica | 🟡 | 4h | 3.3.1, 3.4.1 |

### Prioridad 4: UI/UX Mejoras (Impacto Medio, Riesgo Bajo)

| # | Tarea | Prioridad | Estimación | Dependencias |
|---|-------|-----------|------------|--------------|
| 3.5.1 | Pantalla de fin de partida mejorada | 🟢 | 2h | Ninguna |
| 3.5.2 | Estadísticas post-batalla | 🟢 | 2h | Ninguna |
| 3.5.3 | Indicadores visuales de estado de mech | 🟢 | 2h | Ninguna |

---

## 🗓️ PLAN SUGERIDO (29-31 Dic)

### Domingo 29 Dic - Balance
| Hora | Tarea | Tiempo |
|------|-------|--------|
| AM | 3.1.1 Spreadsheet balance armas | 3h |
| PM | 3.1.2 Implementar en código | 2h |
| | **Total día** | **5h** |

### Lunes 30 Dic - IA
| Hora | Tarea | Tiempo |
|------|-------|--------|
| AM | 3.4.1 IA combate básica (parte 1) | 3h |
| PM | 3.4.1 IA combate básica (parte 2) | 3h |
| | **Total día** | **6h** |

### Martes 31 Dic - Tutorial/Pulido
| Hora | Tarea | Tiempo |
|------|-------|--------|
| AM | 3.3.1 Diseño tutorial + 3.3.2 Hints | 4h |
| PM | 🎆 Año Nuevo - Descanso merecido | - |
| | **Total día** | **4h** |

**Total estimado: 15h de trabajo**

---

## 🎯 CRITERIOS DE ÉXITO - Bonus Diciembre

### Must Have
- [ ] Spreadsheet de balance de armas completo
- [ ] IA básica funcional (puede jugar una partida)

### Should Have
- [ ] Shutdown por calor implementado
- [ ] Documento de diseño de tutorial

### Nice to Have
- [ ] Sistema de hints/tooltips
- [ ] Pantalla de fin de partida mejorada

---

## 📊 IMPACTO ESPERADO

Si completamos estas tareas:

| Área | Estado Actual | Estado Post-Dic2 |
|------|---------------|------------------|
| Balance | Valores hardcodeados | Configurable, documentado |
| IA | Solo multijugador | Single-player básico |
| Tutorial | No existe | Diseño listo |
| Fase 3 | 0% | ~15-20% |

**Ventaja:** Enero empieza con Fase 3 adelantada, pudiendo enfocarse en progresión y economía.

---

## 📁 ARCHIVOS A CREAR

```
data/
└── balance/
    └── weapons_balance.csv          # 3.1.1

scripts/
├── managers/
│   └── battle_ai.gd                 # 3.4.1 (mejorar existente)
└── ui/
    └── tutorial_hint_system.gd      # 3.3.2

doc/
└── design/
    └── TUTORIAL_DESIGN.md           # 3.3.1
```

---

## 🚫 FUERA DE SCOPE (Para Enero)

- ❌ Progresión de pilotos
- ❌ Economía de C-Bills
- ❌ Sistema de reparaciones
- ❌ Ranked con temporadas
- ❌ Arte profesional
- ❌ Audio

---

## 🔗 REFERENCIAS

- [ROADMAP.md](../project/ROADMAP.md) - Fase 3 detallada
- [TODO_DECEMBER.md](./TODO_DECEMBER.md) - Lo completado este mes
- [GDD.md](../design/GDD.md) - Reglas de combate
- [TDD.md](../design/TDD.md) - Arquitectura técnica

---

*Creado: 28 de Diciembre, 2025*  
*Este es un sprint bonus para aprovechar el adelanto conseguido*
