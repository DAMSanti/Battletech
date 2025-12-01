# ADR-001: Sistema de Logging con Sentry

## Estado
✅ Aceptada

## Fecha
2025-11-29

## Contexto

El proyecto necesitaba un sistema de logging profesional para:

1. **Debugging en desarrollo**: Reemplazar los `print()` dispersos por el código
2. **Monitoreo en producción**: Capturar errores de usuarios reales en Android
3. **Categorización**: Poder filtrar logs por sistema (Combat, Network, UI, etc.)
4. **Niveles de severidad**: Distinguir entre debug info y errores críticos

Teníamos ~150+ llamadas a `print()` sin estructura ni posibilidad de monitoreo remoto.

## Decisión

Implementar un **sistema de logging centralizado** como singleton (`Log`) con integración a **Sentry SDK**.

### Características Implementadas

```gdscript
# 5 niveles de severidad
Log.debug("Category", "message")    # Solo desarrollo
Log.info("Category", "message")     # Eventos normales
Log.warning("Category", "message")  # Situaciones anómalas
Log.error("Category", "message")    # Errores que afectan funcionalidad
Log.critical("Category", "message") # Errores graves

# 13 categorías predefinidas
"System", "Combat", "Network", "UI", "Heat", "Movement", 
"Save", "Audio", "AI", "Match", "Mech", "Input", "Test"

# Contexto adicional
Log.error("Network", "Connection failed", {"ip": ip, "error": code})
```

### Integración con Sentry

- **ERROR** y **CRITICAL** se envían automáticamente a Sentry
- DSN configurado en `project.godot`
- Breadcrumbs para trazabilidad
- Tags de categoría para filtrado en dashboard

### Archivos de Log Local

- Ubicación: `user://logs/game_YYYY-MM-DD.log`
- Rotación automática (máximo 5 archivos)
- Formato: `[TIMESTAMP] [LEVEL] [CATEGORY] Message`

## Consecuencias

### Positivas
- ✅ Monitoreo de errores en producción sin intervención del usuario
- ✅ Logs estructurados y filtrables
- ✅ Consistencia en todo el codebase
- ✅ Fácil debugging con contexto
- ✅ Historial de logs local para debugging offline

### Negativas
- ⚠️ Overhead mínimo en cada llamada de log
- ⚠️ Dependencia de servicio externo (Sentry)
- ⚠️ Requiere conexión a internet para enviar a Sentry

### Riesgos
- 📋 Sentry tiene límites en plan gratuito (5K errores/mes)
- 📋 Si Sentry está caído, los errores no se capturan remotamente

### Mitigaciones
- Los logs locales se guardan independientemente de Sentry
- El sistema funciona sin Sentry (solo logging local)

## Alternativas Consideradas

### Alternativa 1: Solo print() mejorado
- Wrapper simple sobre `print()`
- **Rechazada**: No permite monitoreo remoto ni logging a archivo

### Alternativa 2: Firebase Crashlytics
- SDK de Google para crash reporting
- **Rechazada**: Más complejo de integrar con Godot, menos flexible

### Alternativa 3: Sistema custom sin servicio externo
- Logging solo local con exportación manual
- **Rechazada**: No permite monitoreo proactivo de errores

## Referencias

- [Sentry SDK para Godot](https://github.com/getsentry/sentry-godot)
- [Documentación del sistema](../LOGGING_SYSTEM.md)
- [Setup de Sentry](../SENTRY_SETUP.md)
