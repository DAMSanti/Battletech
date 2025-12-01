# 📚 Steel Titans - Documentation Hub

**Versión:** 1.0  
**Última actualización:** 1 de Diciembre, 2025  
**Proyecto:** Steel Titans: Tactical Warfare

---

## 🗂️ Estructura de Documentación

```
doc/
├── design/              # 🎮 Documentos de Diseño
│   ├── GDD.md           # Game Design Document - Mecánicas, gameplay, visión
│   └── TDD.md           # Technical Design Document - Arquitectura técnica
│
├── architecture/        # 🏗️ Arquitectura del Sistema
│   ├── SAD.md           # Software Architecture Document - Diagramas C4
│   └── DATABASE_SCHEMA.md # Esquema completo de PostgreSQL
│
├── development/         # 💻 Guías de Desarrollo
│   ├── GUIDELINES.md    # Convenciones de código, patrones, mejores prácticas
│   ├── TESTING.md       # Framework GUT, cobertura, ejecución de tests
│   └── LOGGING.md       # Sistema de logging, Sentry, niveles de log
│
├── project/             # 📋 Gestión del Proyecto
│   ├── ROADMAP.md       # Plan de desarrollo, fases, milestones
│   └── CHANGELOG.md     # Historial de versiones y cambios
│
├── todo/                # ✅ Planes Mensuales
│   └── TODO_DECEMBER.md # Sprint Diciembre 2025
│
├── api/                 # 🌐 Documentación de API
│   └── REST_API.md      # Endpoints, autenticación, ejemplos
│
├── adr/                 # 📝 Architecture Decision Records
│   ├── ADR-001-logging-system.md
│   ├── ADR-002-networking-architecture.md
│   ├── ADR-003-procedural-terrain.md
│   └── ADR-004-string-categories-logger.md
│
└── archive/             # 📦 Documentos Obsoletos (Referencia histórica)
```

---

## 🚀 Quick Start - ¿Dónde empezar?

| Si necesitas... | Lee este documento |
|-----------------|-------------------|
| Entender el juego y mecánicas | [design/GDD.md](design/GDD.md) |
| Arquitectura técnica del proyecto | [design/TDD.md](design/TDD.md) |
| Diagramas y estructura de código | [architecture/SAD.md](architecture/SAD.md) |
| Escribir código que siga las convenciones | [development/GUIDELINES.md](development/GUIDELINES.md) |
| Ejecutar o escribir tests | [development/TESTING.md](development/TESTING.md) |
| Ver el plan de desarrollo | [project/ROADMAP.md](project/ROADMAP.md) |
| Ver tareas del mes actual | [todo/TODO_DECEMBER.md](todo/TODO_DECEMBER.md) |
| Integrar con la API REST | [api/REST_API.md](api/REST_API.md) |
| Entender una decisión arquitectónica | [adr/](adr/) |

---

## 📊 Estado del Proyecto

| Métrica | Valor |
|---------|-------|
| **Tests pasando** | 380+/383 |
| **Cobertura core** | ~80% |
| **Fase actual** | Pre-Alpha → Alpha |
| **Sprint actual** | Semana 4 Diciembre |

---

## 🔗 Enlaces Importantes

- **Repositorio:** `DAMSanti/Battletech` (branch: `Development`)
- **Servidor producción:** `steeltitans.damsanti.app`
- **API base URL:** `https://steeltitans.damsanti.app/api/v1`
- **Motor:** Godot 4.5.1
- **Backend:** FastAPI + PostgreSQL + Redis

---

## 📖 Documentos Principales

### 🎮 Design Documents

#### [GDD - Game Design Document](design/GDD.md)
Documento completo de diseño del juego:
- Concepto y visión
- Mecánicas de combate por turnos
- Sistema de movimiento hexagonal
- Progresión del jugador
- Monetización

#### [TDD - Technical Design Document](design/TDD.md)
Especificación técnica detallada:
- Stack tecnológico
- Patrones de arquitectura
- Flujos de datos
- Protocolos de red
- Estructuras de datos

### 🏗️ Architecture

#### [SAD - Software Architecture Document](architecture/SAD.md)
Arquitectura usando modelo C4:
- Vista de contexto
- Vista de contenedores
- Vista de componentes
- Decisiones arquitectónicas
- Atributos de calidad

#### [Database Schema](architecture/DATABASE_SCHEMA.md)
Esquema completo de PostgreSQL:
- Entidades y relaciones
- Índices
- Migraciones
- Queries comunes

### 💻 Development

#### [Development Guidelines](development/GUIDELINES.md)
Estándares de desarrollo:
- Naming conventions
- Formato de código
- Patrones recomendados
- Code review checklist

#### [Testing Guide](development/TESTING.md)
Framework y prácticas de testing:
- GUT v9.3.0
- Estructura de tests
- Cobertura por módulo
- CI/CD

### 📋 Project Management

#### [Roadmap](project/ROADMAP.md)
Plan de desarrollo:
- Fases y timeline
- Milestones
- Estado actual
- Próximos pasos

---

## 🏷️ Versionado de Documentos

Los documentos siguen versionado semántico:
- **Mayor:** Cambios estructurales significativos
- **Menor:** Nuevas secciones o contenido
- **Patch:** Correcciones y actualizaciones menores

---

## 📝 Convenciones

- **Idioma código:** Inglés
- **Idioma documentación:** Español (técnico)
- **Commits:** Conventional Commits en inglés
- **Emojis:** Usados para categorización visual

---

*Última actualización automática: Diciembre 2025*
