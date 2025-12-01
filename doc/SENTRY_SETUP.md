# 🔔 Configuración de Sentry para Steel Titans

## Descripción

Sentry es un servicio de monitoreo de errores que captura automáticamente crashes y errores en producción. Está integrado con nuestro sistema de Logger.

## Configuración

### 1. Crear cuenta en Sentry

1. Ir a [sentry.io](https://sentry.io/) y crear una cuenta
2. Crear un nuevo proyecto de tipo "Godot Engine"
3. Copiar el **DSN** (Data Source Name)

### 2. Configurar DSN en Godot

1. Abrir el proyecto en Godot
2. Ir a `Project` → `Project Settings`
3. Buscar la sección `Sentry`
4. En `DSN`, pegar tu DSN de Sentry

Ejemplo de DSN:
```
https://abc123@o123456.ingest.sentry.io/1234567
```

### 3. Opciones de Configuración

En `Project Settings → Sentry → Options`:

| Opción | Descripción | Recomendado |
|--------|-------------|-------------|
| `enabled` | Habilitar/deshabilitar Sentry | ✅ En producción |
| `dsn` | Tu DSN de Sentry | Requerido |
| `environment` | Nombre del ambiente | `production`, `staging`, `development` |
| `release` | Versión del juego | `steel-titans@0.1.0` |
| `sample_rate` | % de errores a capturar | `1.0` (100%) |
| `attach_log` | Adjuntar archivo de log | ✅ Recomendado |
| `logger_enabled` | Capturar errores de Logger | ✅ |

## Integración con Logger

El Logger envía automáticamente a Sentry:

- **Todos los errores** (`Logger.error()`)
- **Todos los críticos** (`Logger.critical()`)
- **Breadcrumbs** para contexto de navegación

### Ejemplo de uso

```gdscript
# Esto se envía a Sentry automáticamente
Logger.error("Network", "Conexión perdida con servidor")

# Esto también
Logger.critical("Combat", "Estado de combate corrupto", {
    "mech_id": 123,
    "position": str(mech.position)
})

# Capturar excepción manualmente
Logger.capture_exception("Error inesperado en cálculo de daño")

# Añadir breadcrumb manual
Logger.add_breadcrumb("Usuario entró a batalla", "navigation")
```

## Control de Sentry en código

```gdscript
# Verificar si Sentry está disponible
if Logger.is_sentry_available():
    print("Sentry activo")

# Deshabilitar temporalmente
Logger.set_sentry_enabled(false)

# Re-habilitar
Logger.set_sentry_enabled(true)
```

## Dashboard de Sentry

En el dashboard de Sentry podrás ver:

- **Issues**: Errores agrupados por tipo
- **Releases**: Errores por versión del juego
- **Tags**: Filtrar por `session_id`, `mode`, `build`, `os`
- **Breadcrumbs**: Secuencia de eventos antes del error
- **Context**: Información del dispositivo y juego

## Ambientes

Configura diferentes DSN para diferentes ambientes:

```gdscript
# En un autoload de configuración
func _ready():
    if OS.is_debug_build():
        # DSN de desarrollo/staging
        pass
    else:
        # DSN de producción
        pass
```

## Buenas Prácticas

1. **NO enviar datos sensibles**: No incluir contraseñas, tokens, etc.
2. **Usar tags**: Facilita filtrar errores en el dashboard
3. **Añadir contexto**: Incluir información relevante en errores
4. **Revisar sample_rate**: En producción con muchos usuarios, considera reducir a 0.5
5. **Configurar alertas**: En Sentry, configura alertas por Slack/Email

## Troubleshooting

### Sentry no envía eventos

1. Verificar que el DSN esté correcto
2. Verificar conexión a internet
3. Revisar `Logger.is_sentry_available()`
4. En debug, verificar consola de Godot

### Muchos eventos duplicados

1. Revisar `sample_rate`
2. Agrupar errores similares con fingerprinting
3. Usar throttling en opciones de Sentry

## Costo

- **Plan gratuito**: 5,000 errores/mes
- **Plan Team**: $26/mes, 50,000 errores/mes
- **Plan Business**: $80/mes, errores ilimitados

Para indie/desarrollo, el plan gratuito es suficiente.

---

*Documentación actualizada: 29 de Noviembre, 2025*
