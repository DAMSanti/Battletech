# 📅 TODO DICIEMBRE 2025
## Steel Titans: Tactical Warfare - Sprint de Infraestructura

**Objetivo:** Completar 100% la infraestructura y backend para cerrar el año  
**Período:** 1 - 31 de Diciembre 2025  
**Estado base:** 331/334 tests pasando, servidor en producción

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
| 🧪 Tests | 321/324 pasando (~70% coverage core) | ✅ |
| 📝 Logging | Sentry + Logger profesional | ✅ |
| 🎮 Save | PlayerDataManager con auto-save | ✅ |

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
| 3.1 | **Cola de matchmaking básica (API)** | 🔴 | 6h | ⬜ |
| 3.2 | Sistema de ELO inicial | 🔴 | 4h | ⬜ |
| 3.3 | Integración matchmaking con Godot server | 🔴 | 4h | ⬜ |
| 3.4 | Reconexión automática (cliente) | 🔴 | 4h | ⬜ |
| 3.5 | Sistema de lobbies mejorado | 🟡 | 4h | ⬜ |
| 3.6 | Tests de matchmaking | 🟡 | 3h | ⬜ |

**Entregable Semana 3:** Matchmaking funcional básico

---

### 🗓️ SEMANA 4 (22-31 Dic): Pulido y Documentación

| # | Tarea | Prioridad | Estimación | Estado |
|---|-------|-----------|------------|--------|
| 4.1 | **TDD (Technical Design Document)** | 🟡 | 6h | ⬜ |
| 4.2 | Documentación de API (OpenAPI exports) | 🟡 | 2h | ⬜ |
| 4.3 | CI/CD pipeline básico (GitHub Actions) | 🟡 | 4h | ⬜ |
| 4.4 | Tests: cobertura >80% core | 🟡 | 6h | ⬜ |
| 4.5 | Cleanup: tech debt TD-001 a TD-005 | 🟢 | 8h | ⬜ |
| 4.6 | **Review y retrospectiva del mes** | 🟡 | 2h | ⬜ |

**Entregable Semana 4:** Infraestructura documentada y pulida

---

## 🎯 CRITERIOS DE ÉXITO - Fin de Diciembre

### Must Have (Obligatorio)
- [ ] Rate limiter y health checks desplegados en producción
- [ ] Backups automáticos funcionando (cron)
- [ ] Matchmaking básico funcional
- [ ] Reconexión automática implementada
- [ ] Tests >80% en core systems
- [ ] 340+ tests pasando (de 324 actuales)

### Should Have (Importante)
- [ ] Redis configurado para sesiones
- [ ] Sistema de baneos funcional
- [ ] Audit logging activo
- [ ] TDD documento creado
- [ ] CI/CD pipeline básico

### Nice to Have (Deseable)
- [ ] Migraciones de DB con Alembic
- [ ] API versionada (v1)
- [ ] Tech debt reducido (TD-001 a TD-003)

---

## 📊 MÉTRICAS A SEGUIR

| Métrica | Actual | Objetivo Dic |
|---------|--------|--------------|
| Tests pasando | 383 | 400+ |
| Cobertura core | ~70% | >80% |
| Uptime servidor | N/A | >99% |
| Tiempo respuesta API | N/A | <200ms P95 |
| Backups exitosos | 0 | 30 (diarios) |

---

## 📁 ARCHIVOS A CREAR/MODIFICAR

### Nuevos archivos esperados:
```
server/
├── api/
│   ├── routers/
│   │   ├── matchmaking_router.py     # 3.1
│   │   └── stats_router.py           # 2.4
│   └── migrations/                    # 2.6 (Alembic)
├── scripts/
│   └── cron_setup.sh                  # 1.2
└── docker-compose.yml                 # Redis setup (2.1)

scripts/
├── core/
│   └── elo_calculator.gd             # 3.2
└── network/
    └── reconnection_handler.gd        # 3.4

doc/
├── TDD.md                             # 4.1
└── API_DOCUMENTATION.md               # 4.2

.github/
└── workflows/
    └── tests.yml                      # 4.3
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
- [ ] Jueves 5: Recordar sesión
- [ ] Viernes 6: Migración de versiones
- [ ] Sábado 7: Tests networking

### Semana 2
- [ ] Lunes 9: Redis setup
- [ ] Martes 10: Sistema de baneos
- [ ] Miércoles 11: Audit logging
- [ ] Jueves 12: API estadísticas
- [ ] Viernes 13: Versionado API
- [ ] Sábado 14: Migraciones Alembic

### Semana 3
- [ ] Lunes 16: Matchmaking API (parte 1)
- [ ] Martes 17: Matchmaking API (parte 2)
- [ ] Miércoles 18: Sistema ELO
- [ ] Jueves 19: Integración matchmaking Godot
- [ ] Viernes 20: Reconexión automática
- [ ] Sábado 21: Lobbies mejorados

### Semana 4
- [ ] Lunes 23: TDD documento
- [ ] Martes 24: 🎄 (opcional: docs API)
- [ ] Miércoles 25: 🎄 NAVIDAD
- [ ] Jueves 26: CI/CD pipeline
- [ ] Viernes 27: Tests cobertura 80%
- [ ] Sábado 28: Tech debt cleanup
- [ ] Domingo 29: Review y retrospectiva
- [ ] Lunes 30-31: Buffer / pendientes

---

## 🔗 REFERENCIAS

- [ROADMAP.md](./ROADMAP.md) - Plan completo de desarrollo
- [TODO_PRODUCTION.md](./TODO_PRODUCTION.md) - Backlog detallado
- [DEPLOY.md](../server/DEPLOY.md) - Guía de deployment
- [DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md) - Esquema de BD

---

*Creado: 1 de Diciembre, 2025*  
*Próxima revisión: 7 de Diciembre, 2025 (fin Semana 1)*
