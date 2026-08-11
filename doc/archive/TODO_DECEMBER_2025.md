# 📅 TODO DICIEMBRE 2025
## Steel Titans: Tactical Warfare - Sprint de Infraestructura

**Objetivo:** Completar 100% la infraestructura y backend para cerrar el año  
**Período:** 1 - 31 de Diciembre 2025  
**Estado base:** 383 tests pasando, servidor en producción

---

## 🎯 META DEL MES

> **"Cerrar diciembre con toda la infraestructura y backend listos para que en enero podamos enfocarnos 100% en gameplay y contenido"**

---

## ✅ YA COMPLETADO (Base de Partida)

| Área | Componente | Estado |
|------|------------|--------|
| 🔐 Auth | JWT + AuthManager + AuthValidator | ✅ |
| 🔐 Auth | AuthScreen UI | ✅ |
| 🗄️ DB | PostgreSQL en producción | ✅ |
| 🌐 API | FastAPI + endpoints auth/users/mechs | ✅ |
| 🔒 SSL | Let's Encrypt (steeltitans.damsanti.app) | ✅ |
| 🛡️ Security | Rate limiting middleware | ✅ |
| 🛡️ Security | Anti-cheat básico | ✅ |
| 📊 Monitoring | Health checks (5 endpoints) | ✅ |
| 💾 Backups | PostgreSQL backup scripts | ✅ |
| 🧪 Tests | 383 pasando (~70% coverage core) | ✅ |
| 📝 Logging | Sentry + Logger profesional | ✅ |
| 🎮 Save | PlayerDataManager con auto-save | ✅ |
| 📚 Docs | Documentación reorganizada + TDD | ✅ |

---

## 📋 TAREAS DICIEMBRE - Por Semana

### 🗓️ SEMANA 1 (1-7 Dic): Deployment y Finalizaciones

| # | Tarea | Prioridad | Estimación | Estado |
|---|-------|-----------|------------|--------|
| 1.1 | **Deploy rate limiter y health router al servidor** | 🔴 | 1h | ✅ |
| 1.2 | Configurar cron de backups automáticos en servidor | 🔴 | 30m | ✅ |
| 1.3 | Validación de integridad (checksum) en PlayerDataManager | 🟡 | 3h | ✅ |
| 1.4 | Implementar "Recordar sesión" en AuthScreen | 🟡 | 2h | ✅ |
| 1.5 | Migración de datos entre versiones de save | 🟡 | 4h | ✅ |
| 1.6 | Tests de networking básicos | 🔴 | 4h | ✅ |

**Entregable Semana 1:** Servidor en producción con todas las mejoras desplegadas ✅

---

### 🗓️ SEMANA 2 (8-14 Dic): Backend Avanzado

| # | Tarea | Prioridad | Estimación | Estado |
|---|-------|-----------|------------|--------|
| 2.1 | **Redis para sesiones/cache** | 🟡 | 4h | ✅ |
| 2.2 | Sistema de baneos (API + DB) | 🟡 | 4h | ✅ |
| 2.3 | Audit logging (acciones importantes) | 🟡 | 3h | ✅ |
| 2.4 | API de estadísticas de usuario | 🟡 | 3h | ✅ |
| 2.5 | Versionado de API (v1) | 🟡 | 2h | ✅ |
| 2.6 | Migraciones de DB versionadas (Alembic) | 🟡 | 4h | ✅ |

**Entregable Semana 2:** Backend con cache, baneos y logging completo ✅

---

### 🗓️ SEMANA 3 (15-21 Dic): Matchmaking Básico

| # | Tarea | Prioridad | Estimación | Estado |
|---|-------|-----------|------------|--------|
| 3.1 | **Cola de matchmaking básica (API)** | 🔴 | 6h | ✅ |
| 3.2 | Sistema de ELO inicial | 🔴 | 4h | ✅ |
| 3.3 | Integración matchmaking con Godot server | 🔴 | 4h | ✅ |
| 3.4 | Reconexión automática (cliente) | 🔴 | 4h | ✅ |
| 3.5 | Sistema de lobbies mejorado | 🟡 | 4h | ✅ |
| 3.6 | Tests de matchmaking | 🟡 | 3h | ✅ |

**Entregable Semana 3:** Matchmaking funcional básico ✅

---

### 🗓️ SEMANA 4 (22-31 Dic): Pulido y Documentación

| # | Tarea | Prioridad | Estimación | Estado |
|---|-------|-----------|------------|--------|
| 4.1 | **TDD (Technical Design Document)** | 🟡 | 6h | ✅ |
| 4.2 | Documentación de API (OpenAPI exports) | 🟡 | 2h | ✅ |
| 4.3 | CI/CD pipeline básico (GitHub Actions) | 🟡 | 4h | ✅ |
| 4.4 | Tests: cobertura >80% core | 🟡 | 6h | ✅ (100%) |
| 4.5 | Cleanup: tech debt | 🟢 | 8h | ✅ |

#### 4.5 Desglose Tech Debt (completado)

| Sub | Tarea | Tiempo | Estado |
|-----|-------|--------|--------|
| TD-A | Limpiar prints → push_warning | 30m | ✅ |
| TD-B | Resolver TODOs críticos (señales + toast) | 1.5h | ✅ |
| TD-C | Mover archivos (diferido - riesgo alto, UIDs) | 1h | ⏸️ |
| TD-D | Documentar funciones públicas (hex_grid, mech, battle_scene) | 2h | ✅ |
| TD-E | Verificar arquitectura battle_scene.gd | 3h | ✅ (SOLID ya existe) |

**Resumen TD-A:** Cambiados prints a push_warning en auth_manager.gd y suspicious_activity_detector.gd

**Resumen TD-B:** 
- ✅ Añadidas señales `opponent_reconnected` y `match_rejoined` en network_manager.gd
- ✅ Implementado toast notification visual en mech_bay_ui.gd
- ✅ Integración con SelectedLoadoutManager para batalla

**Resumen TD-C:** Diferido - mover archivos rompe UIDs de Godot y referencias en .tscn

**Resumen TD-D:** Añadidos docstrings GDScript a:
- `hex_grid.gd` - Clase y funciones principales
- `mech.gd` - Clase y sistema de movimiento/daño
- `battle_scene.gd` - Documentación de arquitectura

**Resumen TD-E:** Arquitectura SOLID ya implementada en `scripts/core/battle/`:
- BattleComponentsIntegrator (orquestador)
- BattleDeploymentManager, BattleMovementHandler, BattleCombatExecutor
- BattleNetworkHandler, BattleInputRouter, etc.
- battle_scene.gd actúa como fachada - refactor adicional innecesario

**Entregable Semana 4:** Infraestructura documentada y pulida

---

## 🎯 CRITERIOS DE ÉXITO - Fin de Diciembre

### Must Have (Obligatorio)
- [x] Rate limiter y health checks desplegados en producción
- [x] Backups automáticos funcionando (cron)
- [x] Matchmaking básico funcional
- [x] Reconexión automática implementada
- [x] Tests >80% en core systems (logrado: 100% cobertura unitaria)
- [x] 400+ tests pasando (logrado: 875 tests totales, 841 pasando - 96.1%)

### Should Have (Importante)
- [x] Redis configurado para sesiones
- [x] Sistema de baneos funcional
- [x] Audit logging activo
- [x] TDD documento creado
- [x] CI/CD pipeline básico

### Nice to Have (Deseable)
- [x] Migraciones de DB con Alembic
- [x] API versionada (v1)
- [x] Tech debt reducido (TD-A, TD-B, TD-D, TD-E completados)

---

## 📊 MÉTRICAS A SEGUIR

| Métrica | Actual | Objetivo Dic |
|---------|--------|--------------|
| Tests pasando | **841/875 (96.1%)** | 400+ ✅ |
| Cobertura core | **100%** (334/334) | >80% ✅ |
| Uptime servidor | ~99% | >99% |
| Tiempo respuesta API | ~150ms | <200ms P95 |
| Backups exitosos | 30 | 30 (diarios) |

---

## 📁 ARCHIVOS CREADOS ESTE MES

### Nuevos archivos:
```
server/
├── api/
│   ├── routers/
│   │   ├── matchmaking_router.py     # 3.1 ✅
│   │   └── stats_router.py           # 2.4 ✅
│   └── migrations/                    # 2.6 ✅ (Alembic)
├── scripts/
│   └── cron_setup.sh                  # 1.2 ✅
└── docker-compose.yml                 # Redis setup (2.1) ✅

scripts/
├── core/
│   └── elo_calculator.gd             # 3.2 ✅
└── network/
    ├── reconnection_handler.gd        # 3.4 ✅
    └── matchmaking_client.gd          # 3.3 ✅

doc/
├── design/
│   └── TDD.md                         # 4.1 ✅
├── api/
│   └── REST_API.md                    # 4.2 ✅
└── todo/
    └── TODO_DECEMBER.md               # Este archivo

.github/
└── workflows/
    └── tests.yml                      # 4.3 ⬜
```

---

## 🚫 FUERA DE SCOPE DICIEMBRE

Estas tareas quedan para **Enero 2026**:
- ❌ Balance de armas (GME-001)
- ❌ Tutorial interactivo (GME-005)
- ❌ Arte profesional (ART-*)
- ❌ Audio (AUD-*)
- ❌ Monetización (MON-*)
- ❌ IA para single-player
- ❌ Sistema de rankings completo (solo ELO básico)
- ❌ Campaña single-player

---

## 📝 NOTAS TÉCNICAS

### Deploy de nuevos componentes
```powershell
# Copiar archivos al servidor
scp -i "G:\Battletech\key" -r server/api/* root@159.65.94.179:/root/steeltitans-api/

# Reiniciar servicio
ssh -i "G:\Battletech\key" root@159.65.94.179 "systemctl restart steeltitans-api"
```

### Configurar cron de backups
```bash
# En servidor (crontab -e)
0 3 * * * /root/scripts/backup_db.sh >> /var/log/backup.log 2>&1
```

### Redis (docker-compose)
```yaml
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
```

---

## ✅ TRACKING DIARIO

### Semana 1
- [x] Lunes 2: Deploy rate limiter
- [x] Martes 3: Deploy health router + cron backups
- [x] Miércoles 4: Checksum PlayerDataManager
- [x] Jueves 5: Recordar sesión
- [x] Viernes 6: Migración de versiones
- [x] Sábado 7: Tests networking

### Semana 2
- [x] Lunes 9: Redis setup
- [x] Martes 10: Sistema de baneos
- [x] Miércoles 11: Audit logging
- [x] Jueves 12: API estadísticas
- [x] Viernes 13: Versionado API
- [x] Sábado 14: Migraciones Alembic

### Semana 3
- [x] Lunes 16: Matchmaking API (parte 1)
- [x] Martes 17: Matchmaking API (parte 2)
- [x] Miércoles 18: Sistema ELO
- [x] Jueves 19: Integración matchmaking Godot
- [x] Viernes 20: Reconexión automática
- [x] Sábado 21: Lobbies mejorados

### Semana 4
- [x] Lunes 23: TDD documento
- [x] Martes 24: Docs API (REST_API.md)
- [ ] Miércoles 25: 🎄 NAVIDAD
- [x] Jueves 26: CI/CD pipeline (.github/workflows/ci.yml)
- [x] Viernes 27: Tests cobertura 80% → ¡Logrado 100% core + 875 tests!
- [x] Sábado 28: Tech debt cleanup (TD-A, TD-B, TD-D, TD-E) ✅
- [ ] Domingo 29: Review y retrospectiva
- [ ] Lunes 30-31: Buffer / pendientes

---

## 🔗 REFERENCIAS

- [ROADMAP.md](../project/ROADMAP.md) - Plan completo de desarrollo
- [TDD.md](../design/TDD.md) - Documento técnico de diseño
- [REST_API.md](../api/REST_API.md) - Documentación de API
- [SAD.md](../architecture/SAD.md) - Arquitectura del sistema
- [DATABASE_SCHEMA.md](../architecture/DATABASE_SCHEMA.md) - Esquema de BD

---

*Creado: 1 de Diciembre, 2025*  
*Última actualización: 28 de Diciembre, 2025*
