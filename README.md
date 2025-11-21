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
- **Línea de visión** y detección de obstáculos
- **Combate por turnos** con fases:
  - **Iniciativa** - Ambos bandos tiran 2D6, el ganador mueve primero
  - Movimiento
  - Ataque con armas
  - Ataque físico (puñetazos, patadas, empujes, cargas)
  - Disipación de calor
- **Sistema de precisión** con modificadores por rango, calor y habilidad del piloto
- **Tabla de localización de impactos** (2d6)
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
  - turn_manager.gd      # Gestor de turnos y fases
  - battle_scene.gd      # Escena principal de batalla
  - main_menu.gd         # Menú principal

scenes/
  - main_menu.tscn       # Escena del menú
  - battle_scene.tscn    # Escena de batalla
```

## Próximas Características a Añadir

1. **Más tipos de mechs** (Light, Medium, Heavy, Assault)
2. **Más armas** (PPCs, Flamers, Gauss Rifles, SRMs)
3. **Sistema de críticos** detallado
4. **Ataques físicos** (puñetazos, patadas, DFA)
5. **Terreno avanzado** (agua, bosques, edificios, elevación)
6. **Efectos visuales** y animaciones
7. **Sonido y música**
8. **Campaña** con progresión
9. **Customización de mechs** en el Mech Bay
10. **Multiplayer local/online**

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
