# ADR-004: Categorías como Strings en Logger

## Estado
✅ Aceptada

## Fecha
2025-11-29

## Contexto

La implementación inicial del sistema de logging (v1.0.0 y v1.1.0) usaba un **enum** para las categorías:

```gdscript
# Logger v1.1.0 - Implementación con enum
class_name Logger

enum Category {
    SYSTEM, COMBAT, NETWORK, UI, HEAT, 
    MOVEMENT, SAVE, AUDIO, AI, MATCH, 
    MECH, INPUT, TEST
}

static func info(category: Category, message: String) -> void:
    # ...
```

El uso esperado era:
```gdscript
Logger.info(Logger.Category.COMBAT, "Damage applied")
```

### El Problema

Al intentar usar el logger desde otros scripts, Godot 4 lanzaba errores:

```
Cannot find member 'Category' in base 'Logger'
```

**Causa raíz**: En Godot 4, cuando un script se registra como **autoload**, el acceso a sus enums internos mediante `Autoload.EnumName.VALUE` no funciona correctamente. Esto es una limitación/comportamiento de GDScript con autoloads.

Adicionalmente, descubrimos que el nombre `Logger` conflictuaba con `GDScriptNativeClass` interno de Godot:

```
Static function 'info()' not found in base 'GDScriptNativeClass'
```

## Decisión

Refactorizar el sistema de logging para:

1. **Usar strings para categorías** en lugar de enum
2. **Renombrar el autoload** de `Logger` a `Log`

### Nueva API (v1.2.0)

```gdscript
# Antes (no funcionaba)
Logger.info(Logger.Category.COMBAT, "message")

# Después (funciona)
Log.info("Combat", "message")
```

### Implementación

```gdscript
# scripts/core/logger.gd
extends Node

# Categorías válidas como strings
const VALID_CATEGORIES: Array[String] = [
    "System", "Combat", "Network", "UI", "Heat",
    "Movement", "Save", "Audio", "AI", "Match",
    "Mech", "Input", "Test"
]

func info(category: String, message: String, context: Dictionary = {}) -> void:
    if category not in VALID_CATEGORIES:
        push_warning("Invalid log category: %s" % category)
    _log(Level.INFO, category, message, context)
```

### Cambio en project.godot

```ini
# Antes
[autoload]
Logger="*res://scripts/core/logger.gd"

# Después  
[autoload]
Log="*res://scripts/core/logger.gd"
```

## Consecuencias

### Positivas
- ✅ **Funciona correctamente** - No más errores de enum
- ✅ **API más simple** - `Log.info("Combat", msg)` es más corto
- ✅ **Extensible** - Fácil agregar categorías sin cambiar enum
- ✅ **Sin conflictos de nombre** - `Log` no colisiona con nada interno

### Negativas
- ⚠️ **Sin autocompletado de categorías** - El IDE no sugiere categorías
- ⚠️ **Typos posibles** - `"Comba"` compila pero no es válido
- ⚠️ **Migración requerida** - 141 archivos necesitaron actualización

### Mitigaciones
- Validación en runtime advierte de categorías inválidas
- Documentación clara de categorías disponibles
- Tests verifican uso correcto de categorías

## Migración Realizada

Se actualizaron 141 archivos del proyecto:

```powershell
# Script de migración ejecutado
Get-ChildItem -Path "scripts","scenes","tests" -Recurse -Filter "*.gd" |
ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    
    # Reemplazar Logger.Category.X por "X"
    $content = $content -replace 'Logger\.Category\.SYSTEM', '"System"'
    $content = $content -replace 'Logger\.Category\.COMBAT', '"Combat"'
    # ... etc para todas las categorías
    
    # Reemplazar Logger por Log
    $content = $content -replace '\bLogger\.', 'Log.'
    
    Set-Content -Path $_.FullName -Value $content
}
```

## Alternativas Consideradas

### Alternativa 1: Enum en archivo separado
- Mover `Category` a un script global sin autoload
- **Rechazada**: Añade complejidad, requiere importar dos cosas

### Alternativa 2: Constantes globales para categorías
```gdscript
const LOG_COMBAT = "Combat"
const LOG_NETWORK = "Network"
Log.info(LOG_COMBAT, "message")
```
- **Rechazada**: Verboso, no mejora mucho sobre strings directos

### Alternativa 3: Métodos específicos por categoría
```gdscript
Log.combat_info("message")
Log.network_error("message")
```
- **Rechazada**: Explosión combinatoria (5 niveles × 13 categorías = 65 métodos)

## Lecciones Aprendidas

1. **Limitaciones de Godot 4 autoloads**: Los enums en autoloads no son accesibles como `Autoload.Enum.VALUE`
2. **Nombres de autoload**: Evitar nombres que puedan colisionar con clases internas de Godot
3. **API simple > API type-safe**: En GDScript, la simplicidad de strings supera la seguridad de tipos del enum

## Referencias

- [Logger v1.2.0](../../scripts/core/logger.gd)
- [Documentación del Sistema](../LOGGING_SYSTEM.md)
- [ADR-001: Sistema de Logging](ADR-001-logging-system.md)
