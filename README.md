# Battletech Mobile - Godot Game

Un juego táctico de combate de mechs para móvil basado en Battletech.

## 📊 Project Statistics

**Total Lines of Code**: 3,664
- Production Code: 2,562 lines (70%)
- Test Code: 1,102 lines (30%)
- Test Coverage: **100%** (core systems)

## Características Implementadas

### Sistema de Mechs
- **Sistema completo de armadura y estructura** por localizaciones (cabeza, brazos, piernas, torsos)
- **Sistema de calor** con efectos en rendimiento
- **Múltiples tipos de armas**:
  - Autocannons (AC/20)
  - Misiles (LRM-20)
  - Láseres (Medium Laser)
- **Munición y gestión de recursos**
- **Sistema de daño realista** siguiendo reglas de Battletech

### Sistema de Combate
- **Grid hexagonal** para movimiento táctico
- **Pathfinding** con cálculo de costes de movimiento
- **Sistema completo de Line of Sight (LoS)**:
  - Cálculo de visibilidad con elevación
  - Cobertura por terreno (bosques, edificios)
  - Hull-down mechanics
  - Modificadores de altura
- **Combate por turnos** con fases:
  - **Iniciativa** - Ambos bandos tiran 2D6, el ganador mueve primero
  - Movimiento
  - Ataque con armas
  - Ataque físico (puñetazos, patadas, empujes, cargas)
  - Disipación de calor
- **Sistema de resolución de ataques completo**:
  - Verificación de LoS y rango
  - Cálculo de To-Hit con todos los modificadores (movimiento, calor, rango, terreno)
  - Tirada 2D6 con reglas especiales (2=fallo automático, 12=impacto automático)
  - Tabla de localización de impactos (2D6)
  - Cluster tables para misiles (LRM/SRM)
  - Armor depletion → daño a estructura interna
  - **Sistema de críticos completo**:
    - Tirada por cada punto de daño a estructura
    - Destrucción de componentes (armas, equipamiento)
    - Explosión de munición con/sin CASE
    - Daño al motor, gyro, actuadores
- **Modificadores de equipamiento**:
  - ECM Suite (interferencia con misiles)
  - Beagle Active Probe (mejor targeting)
- **Ataques físicos completos** con mecánicas de derribo

### IA Básica
- Movimiento táctico hacia objetivos
- Selección de blancos y combate automático

### UI Móvil
- Controles táctiles optimizados
- Información de turno y fase
- Stats de unidades en tiempo real
- Botones de acción

## Estructura del Proyecto

```
scripts/
  - mech.gd              # Clase principal del Mech
  - hex_grid.gd          # Sistema de grid hexagonal
  - battle_scene.gd      # Escena principal de batalla
  
  core/
    - game_enums.gd           # Enumeraciones centralizadas
    - game_constants.gd       # Constantes del juego
    - component_database.gd   # Base de datos de armas y equipamiento
    - mech_loadout.gd        # Sistema de configuración de mechs
    
    combat/
      - weapon_attack_system.gd  # Sistema completo de resolución de ataques
      - line_of_sight.gd         # Sistema de LoS y cobertura
      - physical_attack_system.gd # Ataques físicos
      - weapon_system.gd          # Sistema de armas base
      - heat_system.gd            # Gestión de calor
    
    movement/
      - movement_system.gd    # Sistema de movimiento
    
    terrain/
      - terrain_type.gd      # Tipos de terreno
  
  managers/
    - battle_ai.gd           # IA de combate
    - battle_input_handler.gd # Gestión de input

scenes/
  - main_menu.tscn       # Escena del menú
  - battle_scene.tscn    # Escena de batalla
  - mech_bay.tscn        # Hangar de mechs

doc/
  - WEAPON_ATTACK_RESOLUTION.md    # Documentación completa del sistema de combate
  - COMBAT_INTEGRATION_EXAMPLE.gd  # Ejemplos de integración
  - ARCHITECTURE.md                 # Arquitectura del proyecto
  - (y muchos más...)
```

## Próximas Características a Añadir

1. **Más tipos de mechs** (Light, Medium, Heavy, Assault)
2. **Más armas** (PPCs, Flamers, Gauss Rifles, más variantes)
3. **Integración completa del sistema de combate en la UI**
4. **Efectos visuales** de disparos, impactos y explosiones
5. **Terreno avanzado** (agua profunda, edificios destructibles)
6. **Sistema de campaña** con progresión y salvamento
7. **Animaciones** de mechs y armas
8. **Sonido y música**
9. **Customización avanzada** en el Mech Bay
10. **Multiplayer** local/online

## Cómo Ejecutar

1. Abre el proyecto en Godot 4.5+ (recomendado)
2. Ejecuta la escena principal (main_menu.tscn)
3. Click en "New Battle" para empezar

## Controles

- **Touch/Click** en hexágono para mover unidad
- **Touch/Click** en enemigo para atacar
- **Botón "End Activation"** para terminar turno de la unidad actual

## Notas Técnicas

- Optimizado para pantallas móviles (1080x1920)
- Modo de renderizado: Mobile
- Orientación: Vertical
- Emulación táctil activada para pruebas con ratón
