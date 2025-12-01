# 📋 Sistema de Logging Profesional

## Descripción

Steel Titans utiliza un sistema de logging centralizado ubicado en `scripts/core/logger.gd`. Este Logger es un **autoload** (singleton) disponible globalmente en todo el proyecto.

## Estado de Migración (Nov 2025)

### ✅ Archivos Migrados Completamente (100%)

Todos los archivos de producción han sido migrados al sistema Logger:

**Core:**
- `scripts/core/logger.gd` (implementación)
- `scripts/core/battle/battle_scene_adapter.gd`
- `scripts/core/terrain/terrain_decoration.gd`

**Network:**
- `scripts/network/server_main.gd`
- `scripts/network/network_manager.gd`
- `scripts/network/server_battle_manager.gd`
- `scripts/network/network_battle_client.gd`

**Managers:**
- `scripts/managers/audio_manager.gd`
- `scripts/managers/mech_bay_manager.gd`
- `scripts/managers/battle_ai.gd`
- `scripts/managers/battle_state_manager.gd`
- `scripts/managers/selected_loadout_manager.gd`

**UI:**
- `scripts/ui/battle_ui.gd`
- `scripts/ui/facing_selector.gd`
- `scripts/ui/mech_bay_ui.gd`
- `scripts/ui/multiplayer_lobby_ui.gd`
- `scripts/ui/screens/main_menu.gd`
- `scripts/ui/screens/initiative_screen.gd`
- `scripts/ui/screens/team_setup.gd`
- `scripts/ui/screens/mech_bay_screen.gd`

**Entities:**
- `scripts/mech.gd`

**Grid:**
- `scripts/hex_grid.gd`
- `scripts/hex_surface_renderer.gd`

**Battle:**
- `scripts/battle_scene.gd` (4692 líneas - migrado completamente)

### 📝 Archivos Excluidos (intencionalmente)
- Archivos de test (`test_*.gd`) - mantienen prints para output de tests
- Archivos `.backup` y temporales

## Características

- ✅ **5 Niveles de severidad**: DEBUG, INFO, WARNING, ERROR, CRITICAL
- ✅ **13 Categorías** para filtrado fácil
- ✅ **Archivos de log** rotados automáticamente en `user://logs/`
- ✅ **Helpers específicos** para combat, network, movement, heat, etc.
- ✅ **Sistema de timers** para medir rendimiento
- ✅ **Limpieza automática** de logs antiguos
- ✅ **Exportación** de logs para bug reports
- ✅ **Integración con Sentry** para monitoreo remoto de errores

---

## Uso Básico

```gdscript
# Niveles básicos con categorías como strings
Logger.debug("Combat", "Calculando daño...")
Logger.info("Network", "Jugador conectado")
Logger.warning("Heat", "Mech cerca de sobrecalentamiento")
Logger.error("Save", "No se pudo guardar la partida")
Logger.critical("Network", "Conexión perdida con el servidor")

# Con contexto adicional (Dictionary)
Logger.info("Match", "Partida iniciada", {
    "match_id": 123,
    "player1": "Santi",
    "player2": "Bot"
})
```

---

## Niveles de Log

| Nivel | Uso | Ejemplo |
|-------|-----|---------|
| `DEBUG` | Desarrollo, muy detallado | Valores de variables, flujo interno |
| `INFO` | Eventos normales importantes | Conexiones, cambios de fase |
| `WARNING` | Situaciones anómalas pero manejables | Reconexión, recursos faltantes |
| `ERROR` | Errores que afectan funcionalidad | Fallo al guardar, acción rechazada |
| `CRITICAL` | Errores graves, posibles crashes | Desconexión de servidor, corrupción de datos |

---

## Categorías Disponibles

Las categorías se pasan como strings para facilitar su uso desde cualquier script:

```gdscript
"System"    # Inicialización, configuración general
"Combat"    # Sistema de combate, daño, ataques
"Network"   # Conexiones, sincronización, RPCs
"UI"        # Interfaz de usuario
"Heat"      # Sistema de calor
"Movement"  # Movimiento de mechs
"Save"      # Guardado/carga de datos
"Audio"     # Sistema de audio
"AI"        # Inteligencia artificial
"Match"     # Gestión de partidas
"Mech"      # Estado de mechs
"Input"     # Input del jugador
"Test"      # Tests y debugging
```

---

## Helpers Específicos

### Network
```gdscript
# Log de red con peer_id automático
Logger.network("Jugador conectado: Santi", peer_id)
Logger.network("Error de conexión", peer_id, true)  # is_error=true
```

### Combat
```gdscript
# Log de combate con atacante/defensor/daño
Logger.combat("Ataque con AC/20", "Warden", "Crusader", 20)
```

### Movement
```gdscript
# Log de movimiento con coordenadas
Logger.movement("Mech movido", "Warden", Vector2i(5, 5), Vector2i(7, 6))
```

### Heat
```gdscript
# Log de calor (nivel auto-ajustado según severidad)
Logger.heat("Heat status", "Warden", 25, 30)  # 25/30 = WARNING automático
```

### Match
```gdscript
# Log de eventos de partida
Logger.match_event("Partida iniciada", "MATCH001", "Player1", "Player2")
```

### UI
```gdscript
# Log de UI
Logger.ui("Botón presionado", "attack_button")
```

---

## Medición de Tiempos

```gdscript
# Iniciar timer
Logger.start_timer("pathfinding")

# ... código a medir ...

# Terminar y loggear automáticamente el tiempo
var elapsed = Logger.end_timer("pathfinding")
# Output: [DEBUG] Timer 'pathfinding' completado | elapsed_sec=0.045
```

---

## Configuración

### Cambiar Nivel Mínimo
```gdscript
# Solo mostrar WARNING y superiores
Logger.set_min_level(Logger.Level.WARNING)
```

### Filtrar Categorías
```gdscript
# Solo mostrar COMBAT y NETWORK
Logger.enable_only_categories([Logger.Category.COMBAT, Logger.Category.NETWORK])

# Deshabilitar categorías específicas
Logger.disable_categories([Logger.Category.UI, Logger.Category.AUDIO])

# Resetear a todas las categorías
Logger.enable_all_categories()
```

---

## Archivos de Log

### Ubicación
- **Windows**: `%APPDATA%\Godot\app_userdata\Steel Titans\logs\`
- **Linux**: `~/.local/share/godot/app_userdata/Steel Titans/logs/`
- **macOS**: `~/Library/Application Support/Godot/app_userdata/Steel Titans/logs/`

### Nombre de Archivo
```
steel_titans_YYYYMMDD_HHMMSS.log
```

### Formato del Archivo
```
# Steel Titans Log File
# Session: ABC12345
# Started: 2025-11-29 15:30:00
# Format: timestamp|session|level|category|message|context
#
2025-11-29 15:30:01|ABC12345|INFO|SYSTEM|Logger inicializado|
2025-11-29 15:30:02|ABC12345|INFO|NETWORK|Connecting to server|{"address":"159.65.94.179","port":7777}
```

### Limpieza Automática
```gdscript
# Eliminar logs mayores a 7 días
var deleted = Logger.cleanup_old_logs(7)
```

### Exportar para Bug Report
```gdscript
# Exportar log actual a ubicación específica
Logger.export_logs("user://bug_report_2025_11_29.log")
```

---

## Utilidades

### Obtener Información de Sesión
```gdscript
var session_id = Logger.get_session_id()  # "ABC12345"
var log_path = Logger.get_log_path()       # "user://logs/steel_titans_..."
```

---

## Ejemplos de Output

### Consola (Debug Build)
```
[0.001] ℹ️ INFO  [SYSTEM] Logger inicializado - Steel Titans v0.1.0-alpha
[0.001] ℹ️ INFO  [SYSTEM] Session ID: YXP1XER2
[0.002] ℹ️ INFO  [NETWORK] Connecting to server | address=159.65.94.179, port=7777
[0.523] 🔍 DEBUG [COMBAT] Calculating damage | attacker=Warden, weapon=AC/20
[1.234] ⚠️ WARN  [HEAT] Mech overheating! | mech=Crusader, heat=28, max=30
[2.567] ❌ ERROR [SAVE] Failed to save game | error=permission_denied
```

### Archivo de Log
```
2025-11-29 15:30:01|YXP1XER2|INFO|SYSTEM|Logger inicializado - Steel Titans v0.1.0-alpha|
2025-11-29 15:30:02|YXP1XER2|INFO|NETWORK|Connecting to server|{"address":"159.65.94.179","port":7777}
2025-11-29 15:30:02|YXP1XER2|DEBUG|COMBAT|Calculating damage|{"attacker":"Warden","weapon":"AC/20"}
2025-11-29 15:30:03|YXP1XER2|WARNING|HEAT|Mech overheating!|{"mech":"Crusader","heat":28,"max":30}
2025-11-29 15:30:04|YXP1XER2|ERROR|SAVE|Failed to save game|{"error":"permission_denied"}
```

---

## Migración desde print()

### Antes
```gdscript
print("[SERVER] Player connected: %d" % peer_id)
push_warning("Connection failed")
push_error("Critical error!")
```

### Después
```gdscript
Logger.network("Player connected", peer_id)
Logger.warning(Logger.Category.NETWORK, "Connection failed")
Logger.critical(Logger.Category.NETWORK, "Critical error!")
```

---

## Tests

El Logger tiene 28 tests unitarios en `tests/unit/test_logger.gd`:
- Tests de niveles
- Tests de categorías
- Tests de configuración
- Tests de timers
- Tests de formato

Ejecutar tests:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_logger.gd -gexit
```

---

## Roadmap Futuro

- [x] ~~Integración con Sentry para logs remotos~~ ✅ Completado
- [ ] Dashboard web de logs
- [ ] Alertas automáticas en errores críticos (vía Sentry)
- [ ] Compresión de logs antiguos

---

## Integración con Sentry

Ver documentación completa en [SENTRY_SETUP.md](./SENTRY_SETUP.md).

### Resumen Rápido

1. Instalar addon Sentry en `addons/sentry/`
2. Configurar DSN en `Project Settings → Sentry → Options`
3. Los errores y críticos se envían automáticamente a Sentry

```gdscript
# Estos se envían a Sentry automáticamente
Logger.error(Logger.Category.NETWORK, "Connection lost")
Logger.critical(Logger.Category.COMBAT, "Invalid state")

# Control manual
Logger.set_sentry_enabled(false)  # Deshabilitar
Logger.is_sentry_available()      # Verificar estado
```

---

*Última actualización: 29 de Noviembre, 2025*
