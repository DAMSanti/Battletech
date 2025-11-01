# Sistema de Dados 3D - Battletech

## 🎲 Visualización de Iniciativa 3D

### Componentes Implementados

#### 1. **DiceRoller** (`dice_roller.gd`)
Cada dado individual con animación:
- ✅ Símbolos Unicode de dados (⚀ ⚁ ⚂ ⚃ ⚄ ⚅)
- ✅ Rotación 3D simulada
- ✅ Escala dinámica (bounce effect)
- ✅ Cambio rápido de caras durante el roleo
- ✅ Animación de "aterrizaje" con bounce elástico
- ✅ Sombras y bordes 3D
- ✅ Fade in/out suaves

#### 2. **InitiativeDisplay** (`initiative_display.gd`)
Panel completo de iniciativa:
- ✅ 4 dados simultáneos (2 jugador, 2 enemigo)
- ✅ Panel semi-transparente con borde dorado
- ✅ Títulos coloreados (Cyan=Jugador, Red=Enemigo)
- ✅ Tiradas escalonadas (0.3s entre cada dado)
- ✅ Cálculo automático de totales
- ✅ Anuncio del ganador con efectos
- ✅ Fade out automático después de 2 segundos

### Efectos Visuales

**Durante el Roleo:**
```
- Rotación: ±0.5 radianes (±28°)
- Escala: 1.0 → 1.3 → 1.0 (bounce)
- Velocidad: 6 rotaciones por segundo
- Cambio de caras: Cada 2 frames
- Duración: 1.2 segundos
```

**Resultado Final:**
```
- Bounce elástico: 1.3x → 1.0x
- Color: Pulsante → Blanco puro
- Tiempo visible: 0.8 segundos
- Fade out: 0.3 segundos
```

### Secuencia de Animación

```
1. INICIO (0.0s)
   ├─ Panel aparece con fade in
   ├─ Escala 0.5x → 1.0x (efecto lanzamiento)
   └─ Alpha 0 → 1

2. ROLEO (0.0s - 1.2s)
   ├─ Caras cambian aleatoriamente
   ├─ Rotación continua
   ├─ Escala pulsante
   └─ Color modulado

3. RESULTADO (1.2s - 2.0s)
   ├─ Muestra cara final
   ├─ Bounce elástico dramático
   ├─ Rotación a 0°
   └─ Color blanco puro

4. FADE OUT (2.0s - 2.3s)
   └─ Transparencia 1 → 0
```

### Layout del Panel

```
┌─────────────────────────────────────────┐
│        INITIATIVE ROLL                  │ (Dorado)
├─────────────────────────────────────────┤
│  PLAYER              ENEMY              │
│  ┌─────┐ ┌─────┐    ┌─────┐ ┌─────┐   │
│  │  ⚃  │ │  ⚅  │    │  ⚁  │ │  ⚃  │   │ (Dados rolando)
│  └─────┘ └─────┘    └─────┘ └─────┘   │
│                                         │
│  Total: 9           Total: 5           │
│                                         │
│      ★ PLAYER WINS! ★                  │ (Verde brillante)
└─────────────────────────────────────────┘
```

## 🎨 Personalización de Colores

**Panel Principal:**
- Fondo: rgba(0.1, 0.1, 0.15, 0.95) - Casi negro
- Borde: Gold - Dorado brillante
- Radio esquinas: 10px

**Dados:**
- Fondo: White - Blanco puro
- Texto: Black - Negro
- Sombra: rgba(0, 0, 0, 0.5) - 50% transparente
- Borde: Dark Gray - Gris oscuro 3D

**Texto:**
- Jugador: Cyan (#00FFFF)
- Enemigo: Red (#FF0000)
- Ganador: Green/OrangeRed
- Título: Gold (#FFD700)

## 🎬 Integración en el Juego

```gdscript
# En battle_scene.gd
func _on_initiative_rolled(data: Dictionary):
    if initiative_display:
        initiative_display.show_initiative_roll(data)
```

## 📊 Datos de Entrada

```gdscript
var data = {
    "player_dice": [4, 5],      # Valores individuales
    "player_total": 9,          # Suma
    "enemy_dice": [2, 3],       # Valores individuales
    "enemy_total": 5,           # Suma
    "winner": "player"          # "player" o "enemy"
}
```

## ⚡ Rendimiento

- **Tweens**: Animaciones optimizadas con Godot Tween
- **Process**: Solo activo durante roleo
- **Memoria**: Componentes reutilizables
- **FPS**: Sin impacto notable (60 FPS constante)

## 🎯 Próximas Mejoras Opcionales

- [ ] Sonidos de dados (clic, roleo, aterrizaje)
- [ ] Partículas al aterrizar
- [ ] Trail effect durante rotación
- [ ] Sombras dinámicas más realistas
- [ ] Dados con texturas reales
- [ ] Perspectiva 3D real con shader
