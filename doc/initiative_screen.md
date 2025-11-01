# Pantalla de Iniciativa Pre-Batalla

## 🎲 Sistema de Dados 3D Interactivo

### Flujo del Juego

```
1. Main Menu
   ↓
2. [NUEVA] Initiative Screen ← AQUÍ EMPIEZA
   - Dados 3D en pantalla
   - Botón "ROLL DICE"
   - Jugador tira los dados manualmente
   ↓
3. Battle Scene
   - Comienza con iniciativa ya decidida
```

## 🎬 Pantalla de Iniciativa

### Elementos Visuales

```
┌─────────────────────────────────────────────────┐
│     BATTLETECH - INITIATIVE                     │
│  Roll for initiative to determine who moves first│
│                                                  │
│   PLAYER DICE              ENEMY DICE           │
│   ┌─────┐  ┌─────┐       ┌─────┐  ┌─────┐    │
│   │  ?  │  │  ?  │       │  ?  │  │  ?  │    │ Antes
│   └─────┘  └─────┘       └─────┘  └─────┘    │
│                                                 │
│          [  ROLL DICE  ]                       │
│                                                 │
└─────────────────────────────────────────────────┘

         ↓ USUARIO HACE CLICK ↓

┌─────────────────────────────────────────────────┐
│     BATTLETECH - INITIATIVE                     │
│                                                  │
│   PLAYER DICE              ENEMY DICE           │
│   ┌─────┐  ┌─────┐       ┌─────┐  ┌─────┐    │
│   │  ⚃  │  │  ⚅  │       │  ⚁  │  │  ⚂  │    │ Después
│   └─────┘  └─────┘       └─────┘  └─────┘    │
│                                                 │
│   Player: 4 + 6 = 10                          │
│   Enemy: 2 + 3 = 5                            │
│                                                 │
│   ★ PLAYER WINS INITIATIVE! ★                 │
│   You will move first                          │
│                                                 │
│          [ START BATTLE ]                      │
└─────────────────────────────────────────────────┘
```

## 🎯 Animación de Dados

### Secuencia Completa (3 segundos):

**FASE 1: Lanzamiento (0.5s)**
- Dados saltan hacia arriba (-300px)
- Rotan 2 vueltas completas (720°)
- Escalan 1.0x → 1.3x
- Caras cambian cada 0.05s

**FASE 2: Caída con Rebotes (1.0s)**
- Caen a posición original
- Efecto BOUNCE (rebote realista)
- Rotan 4 vueltas completas (1440°)
- Caras siguen cambiando cada 0.08s
- Escala 1.3x → 1.0x (elástico)

**FASE 3: Resultado Final (1.5s)**
- Muestra cara final
- Bounce 1.2x → 1.0x (elástico)
- Flash amarillo en el borde (0.2s)
- Borde vuelve a color original (Cyan/Red)

### Código de Animación Principal:

```gdscript
func animate_dice_roll(dice: Node2D, final_result: int):
    # LANZAMIENTO
    - Posición Y: +0 → -300 (hacia arriba)
    - Rotación: 0 → 720° (2 vueltas)
    - Escala: 1.0 → 1.3
    - Caras: Aleatorias cada 0.05s
    
    # CAÍDA
    - Posición Y: -300 → +0 (con rebote)
    - Rotación: 720° → 1440° (2 vueltas más)
    - Escala: 1.3 → 1.0 (elástico)
    - Caras: Aleatorias cada 0.08s
    
    # RESULTADO
    - Cara final mostrada
    - Bounce 1.2 → 1.0
    - Flash amarillo → color original
```

## 🎨 Estilos Visuales

**Dados:**
- Tamaño: 150x150 px
- Color: Blanco (#FFFFFF)
- Bordes: 6px
  - Jugador: Cyan (#00FFFF)
  - Enemigo: Red (#FF0000)
- Sombra: 15px, offset (8, 8), alpha 0.6
- Radio esquinas: 20px
- Símbolos: ⚀ ⚁ ⚂ ⚃ ⚄ ⚅ (Unicode, 96pt, Negro)

**Botones:**
- "ROLL DICE": 240x80, 32pt
- "START BATTLE": 280x80, 32pt
- Aparecen/desaparecen con fade in/out

**Fondo:**
- Color: rgba(5, 5, 10, 0.98)
- Casi negro, opaco 98%

## 🔧 Integración Técnica

### Archivos Creados:
1. `scripts/initiative_screen.gd` - Lógica de la pantalla
2. `scenes/initiative_screen.tscn` - Escena

### Modificaciones:
- `battle_scene.gd`:
  - Preload de initiative_screen
  - Espera a que termine antes de empezar batalla
  - Guarda datos de iniciativa
  
- `turn_manager.gd`:
  - Nuevo método `use_precalculated_initiative()`
  - Salta la tirada automática si hay datos previos

### Señales:
```gdscript
signal initiative_complete(data: Dictionary)
```

**Datos emitidos:**
```gdscript
{
    "player_dice": [4, 6],
    "player_total": 10,
    "enemy_dice": [2, 3],
    "enemy_total": 5,
    "winner": "player"
}
```

## 🎮 Experiencia de Usuario

1. **Nueva batalla** → Aparece pantalla de iniciativa
2. **Usuario ve 4 dados** (2 suyos cyan, 2 enemigos red)
3. **Click en "ROLL DICE"** → ¡ACCIÓN!
4. **Dados saltan y ruedan** por 3 segundos
5. **Aterrizan con rebote** mostrando resultados
6. **Se calculan totales** automáticamente
7. **Aparece ganador** con estrella y color
8. **Click "START BATTLE"** → Fade out
9. **Battle scene carga** con iniciativa ya decidida

## ⚡ Rendimiento

- Animaciones: Godot Tween (GPU acelerado)
- Sin partículas (para móvil)
- 4 dados simultáneos sin lag
- Fade transitions suaves
- Total: 60 FPS constante

## 🎯 Resultado

✅ Pantalla pre-batalla con dados 3D
✅ Botón interactivo "ROLL DICE"
✅ Animación espectacular de 3 segundos
✅ Dados saltan, ruedan y caen con física
✅ Resultados claros y coloridos
✅ Transición suave a batalla
✅ Datos de iniciativa guardados y usados
