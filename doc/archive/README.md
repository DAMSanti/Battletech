# 📦 Archive - Documentación Histórica

Esta carpeta contenía documentación obsoleta que fue eliminada el **1 de Diciembre, 2025** durante la reorganización de documentación.

## 📋 Documentos Eliminados

Los siguientes documentos fueron eliminados por estar obsoletos o redundantes:

### TODOs Antiguos
- `TODO.md`, `TODO_PRODUCTION.md` → Reemplazados por [ROADMAP.md](../project/ROADMAP.md) y [todo/](../todo/)

### Migraciones Completadas
- `MIGRATION_GUIDE.md`, `MIGRATION_CHANGES.md`, `MIGRATION_TO_PROCEDURAL_ONLY.md`
- `REFACTORING.md`, `REFACTORING_PLAN.md`, `INTEGRACION_COMPLETADA.md`

### Arquitectura Antigua
- `ARCHITECTURE.md` → Reemplazado por [SAD.md](../architecture/SAD.md)

### Sistemas de Juego
- `COMBAT_QUICK_REFERENCE.md`, `MOVEMENT_SYSTEM.md`, `physical_attacks.md`
- `dice_system.md`, `LINE_OF_SIGHT_SYSTEM.md`, `WEAPON_ATTACK_*.md`
- → Integrados en [GDD.md](../design/GDD.md) y [TDD.md](../design/TDD.md)

### Generación Procedural
- `PROCEDURAL_*.md`, `TERRAIN_*.md`, `GENERATOR_COMPARISON.md`
- → Integrados en [TDD.md](../design/TDD.md)

### Guías de Configuración
- `MULTIPLAYER_SETUP.md`, `SENTRY_SETUP.md`, `MOBILE_EXPORT.md`
- → Integrados en [GUIDELINES.md](../development/GUIDELINES.md)

### Otros
- `MECH_BAY_SYSTEM.md`, `MECH_PAPER_DOLL_SYSTEM.md`, `TEAM_SETUP_SYSTEM.md`
- `initiative_screen.md`, `UNIFIED_BATTLE_SYSTEM.md`, `QUICK_START_MOVEMENT.md`
- `LOADOUT_BATTLE_INTEGRATION.md`, `COMPONENTS_DATABASE_SUMMARY.md`
- Ejemplos `.gd.txt` de código

## ℹ️ Información

Si necesitas referencia histórica de algún documento eliminado, consulta el historial de Git:

```bash
git log --all --full-history -- "doc/archive/<archivo>.md"
git show <commit>:doc/archive/<archivo>.md
```

---

*Actualizado: 1 de Diciembre, 2025*
- `LINE_OF_SIGHT_SYSTEM.md` - Sistema de línea de visión
- `WEAPON_ATTACK_*.md` - Sistemas de ataque
- `dice_system.md` - Sistema de dados
- `physical_attacks.md` - Ataques físicos
- `UNIFIED_BATTLE_SYSTEM.md` - Sistema de batalla

### UI/Componentes (Documentación técnica inline)
- `MECH_BAY_SYSTEM.md` - Sistema de hangar
- `MECH_PAPER_DOLL_SYSTEM.md` - Paper doll
- `TEAM_SETUP_SYSTEM.md` - Setup de equipo
- `initiative_screen.md` - Pantalla de iniciativa
- `LOADOUT_BATTLE_INTEGRATION.md` - Integración loadout

### Mapas/Terreno (Integrado en TDD.md)
- `TERRAIN_GENERATION.md` - Generación de terreno
- `TERRAIN_DECORATIONS_GUIDE.md` - Decoraciones
- `PROCEDURAL_*.md` - Generación procedural
- `GENERATOR_COMPARISON.md` - Comparación de generadores

### Ejemplos de Código
- `COMBAT_INTEGRATION_EXAMPLE.gd.txt`
- `movement_integration_example.gd.txt`

### Setup/Deploy (Información en README principal)
- `MULTIPLAYER_SETUP.md` - Setup multijugador
- `MOBILE_EXPORT.md` - Exportación móvil
- `SENTRY_SETUP.md` - Configuración Sentry

### Otros
- `COMPONENTS_DATABASE_SUMMARY.md` - Resumen de componentes
- `QUICK_START_MOVEMENT.md` - Guía rápida

---

## 📅 Fecha de Archivo

Diciembre 2025 - Reorganización de documentación

## 📖 Documentación Actual

Ver [../README.md](../README.md) para la estructura actual de documentación.
