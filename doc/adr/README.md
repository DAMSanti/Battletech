# 📋 Architecture Decision Records (ADR)
## Steel Titans: Tactical Warfare

Este directorio contiene los registros de decisiones arquitectónicas del proyecto.

---

## 📑 Índice de ADRs

| # | Título | Estado | Fecha |
|---|--------|--------|-------|
| [ADR-001](ADR-001-logging-system.md) | Sistema de Logging con Sentry | ✅ Aceptada | 2025-11-29 |
| [ADR-002](ADR-002-networking-architecture.md) | Arquitectura de Red Cliente-Servidor | ✅ Aceptada | 2025-11-29 |
| [ADR-003](ADR-003-procedural-terrain.md) | Sistema de Terreno Procedural | ✅ Aceptada | 2025-11-29 |
| [ADR-004](ADR-004-string-categories-logger.md) | Categorías como Strings en Logger | ✅ Aceptada | 2025-11-29 |

### ADRs Propuestas (Pendientes de Documentar)

| # | Título | Estado |
|---|--------|--------|
| ADR-005 | Autenticación con Google Sign-In | 🟡 Propuesta |
| ADR-006 | PostgreSQL + Redis para Persistencia | 🟡 Propuesta |
| ADR-007 | Modelo de Monetización (Paid + Store) | 🟡 Propuesta |

---

## 🎯 ¿Qué es un ADR?

Un **Architecture Decision Record (ADR)** es un documento que captura una decisión arquitectónica importante junto con su contexto y consecuencias.

### Cuándo Crear un ADR

Crear un ADR cuando:
- Se elige una tecnología, librería o framework
- Se define un patrón arquitectónico
- Se toma una decisión que será difícil de revertir
- Se hace un tradeoff significativo
- Se cambia una decisión arquitectónica previa

### Template

```markdown
# ADR-XXX: [Título]

## Estado
[Propuesta | Aceptada | Deprecada | Reemplazada por ADR-XXX]

## Fecha
YYYY-MM-DD

## Contexto
¿Cuál es el problema? ¿Qué nos llevó a tomar esta decisión?

## Decisión
¿Qué decidimos hacer?

## Consecuencias

### Positivas
- ...

### Negativas
- ...

### Riesgos
- ...

## Alternativas Consideradas

### Alternativa 1: [Nombre]
- Descripción
- Por qué no se eligió

### Alternativa 2: [Nombre]
- Descripción
- Por qué no se eligió

## Referencias
- Links a documentación relevante
- Issues o PRs relacionados
```

---

## 📊 Estados de ADR

| Estado | Descripción |
|--------|-------------|
| 🟡 **Propuesta** | En discusión, aún no implementada |
| ✅ **Aceptada** | Decisión tomada e implementada |
| ⚠️ **Deprecada** | Ya no es la práctica recomendada |
| 🔄 **Reemplazada** | Sustituida por otra ADR |

---

*Para crear una nueva ADR, copiar el template y crear un archivo `ADR-XXX-nombre-descriptivo.md`*
