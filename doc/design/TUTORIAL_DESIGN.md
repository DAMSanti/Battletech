# 📚 TUTORIAL DESIGN DOCUMENT
## Steel Titans: Tactical Warfare

**Versión:** 1.0  
**Fecha:** 1 de Diciembre, 2025  
**Estado:** Diseño Aprobado

---

## 🎯 OBJETIVO DEL TUTORIAL

> **"Enseñar al jugador los conceptos básicos del juego de manera natural y progresiva durante su primera partida"**

### Principios de Diseño
1. **Learn by Doing** - El jugador aprende jugando, no leyendo
2. **Contextual** - Los hints aparecen cuando son relevantes
3. **No intrusivo** - El jugador puede ignorar si ya sabe
4. **Completo** - Cubre todos los conceptos básicos en una partida

---

## 🎮 ESTRUCTURA DEL TUTORIAL

### Condición de Activación
- **Primera partida de una cuenta nueva**
- Variable persistente: `user://tutorial_completed.save`
- Si el archivo no existe o `tutorial_completed = false`, activar tutorial

### Formato de Batalla Tutorial
| Aspecto | Valor |
|---------|-------|
| Formato | 1v1 (un mech vs un mech) |
| Mech Jugador | Atlas AS7-D (pesado, resistente) |
| Mech IA | Hunchback HBK-4G (medio, fácil de destruir) |
| Dificultad IA | EASY (forzado, no seleccionable) |
| Mapa | Pequeño, plano, pocos obstáculos |
| Objetivo | Destruir al enemigo |

### Por qué estos mechs
- **Atlas**: Tanque, perdona errores, muchas armas variadas
- **Hunchback**: Un arma principal (AC/20), fácil de entender, destruible en 2-3 turnos

---

## 📖 SECUENCIA DE TUTORIAL

### Fase 0: Bienvenida (Pre-batalla)
```
┌─────────────────────────────────────────────────────────┐
│  🎮 WELCOME TO STEEL TITANS!                            │
│                                                         │
│  This is your first battle. Don't worry, we'll guide   │
│  you through the basics step by step.                  │
│                                                         │
│  You command a mighty ATLAS assault mech.              │
│  Your mission: Destroy the enemy Hunchback.            │
│                                                         │
│                    [ BEGIN TUTORIAL ]                   │
└─────────────────────────────────────────────────────────┘
```

---

### Fase 1: INICIATIVA
**Trigger:** Al mostrar la pantalla de iniciativa

```
┌─────────────────────────────────────────────────────────┐
│  📊 INITIATIVE PHASE                                    │
│                                                         │
│  Each turn, both sides roll for initiative.            │
│  The LOSER moves first, the WINNER moves last.         │
│                                                         │
│  Moving LAST is usually better - you can react to      │
│  what your enemy does!                                 │
│                                                         │
│  💡 Lighter mechs get bonuses to initiative rolls.     │
│                                                         │
│                         [ GOT IT ]                      │
└─────────────────────────────────────────────────────────┘
```

---

### Fase 2: MOVIMIENTO
**Trigger:** Cuando es el turno del jugador en fase de movimiento

#### 2.1 - Selección de Tipo de Movimiento
```
┌─────────────────────────────────────────────────────────┐
│  🦿 MOVEMENT PHASE                                      │
│                                                         │
│  First, choose HOW to move:                            │
│                                                         │
│  🚶 WALK  - Normal speed, +1 defense                   │
│  🏃 RUN   - Double speed, +2 defense, can't fire       │
│  🚀 JUMP  - Fly over obstacles, +3 defense, uses heat  │
│                                                         │
│  💡 Running is great for closing distance, but you     │
│     won't be able to shoot this turn!                  │
│                                                         │
│  Select a movement type from the buttons below.        │
└─────────────────────────────────────────────────────────┘
```

#### 2.2 - Selección de Destino
**Trigger:** Después de elegir tipo de movimiento
```
┌─────────────────────────────────────────────────────────┐
│  📍 SELECTING DESTINATION                               │
│                                                         │
│  The BLUE hexes show where you can move.               │
│  Tap any blue hex to move there.                       │
│                                                         │
│  💡 Try to get closer to the enemy while staying       │
│     at your weapons' optimal range (4-6 hexes).        │
│                                                         │
│  ⚠️ Moving through WATER or UP hills costs extra.     │
└─────────────────────────────────────────────────────────┘
```

#### 2.3 - Selección de Facing
**Trigger:** Después de moverse, al elegir dirección
```
┌─────────────────────────────────────────────────────────┐
│  🧭 CHOOSE YOUR FACING                                  │
│                                                         │
│  Your mech's facing matters!                           │
│                                                         │
│  • Front armor is STRONGEST                            │
│  • Side armor is WEAKER                                │
│  • Rear armor is WEAKEST (avoid showing your back!)    │
│                                                         │
│  💡 Face your enemy to protect yourself and use       │
│     arm-mounted weapons effectively.                   │
│                                                         │
│  Tap an arrow to choose your facing direction.         │
└─────────────────────────────────────────────────────────┘
```

---

### Fase 3: ATAQUE CON ARMAS
**Trigger:** Cuando es el turno del jugador en fase de ataque

#### 3.1 - Selección de Objetivo
```
┌─────────────────────────────────────────────────────────┐
│  🎯 WEAPON ATTACK PHASE                                 │
│                                                         │
│  Time to attack! First, select a target.               │
│  Tap on an enemy mech to target it.                    │
│                                                         │
│  💡 The targeting panel shows hit chance and damage.   │
│     Red enemies = in range, Gray = out of range.       │
└─────────────────────────────────────────────────────────┘
```

#### 3.2 - Selección de Armas
**Trigger:** Después de seleccionar objetivo
```
┌─────────────────────────────────────────────────────────┐
│  🔫 SELECTING WEAPONS                                   │
│                                                         │
│  Choose which weapons to fire:                         │
│                                                         │
│  Each weapon shows:                                     │
│  • Damage it deals                                     │
│  • Heat it generates                                   │
│  • Hit chance at current range                         │
│                                                         │
│  ⚠️ HEAT WARNING: Firing too many weapons causes       │
│     overheating! Watch your heat bar.                  │
│                                                         │
│  💡 At close range, use ALL your weapons!              │
│     At long range, save low-accuracy weapons.          │
│                                                         │
│  Tap weapons to toggle them, then press FIRE.          │
└─────────────────────────────────────────────────────────┘
```

#### 3.3 - Explicación de Calor (Primera vez que sube mucho)
**Trigger:** Si el calor supera 15 después de disparar
```
┌─────────────────────────────────────────────────────────┐
│  🌡️ HEAT MANAGEMENT                                    │
│                                                         │
│  Your mech is heating up!                              │
│                                                         │
│  Heat comes from:                                       │
│  • Firing energy weapons (lasers, PPCs)                │
│  • Jumping with jump jets                              │
│                                                         │
│  Heat goes down each turn (heat sinks).                │
│                                                         │
│  ⚠️ If heat reaches 30, your mech SHUTS DOWN!         │
│     A shutdown mech can't move or attack!              │
│                                                         │
│  💡 Balance damage output with heat management.        │
└─────────────────────────────────────────────────────────┘
```

---

### Fase 4: ATAQUE FÍSICO (Opcional)
**Trigger:** Si el jugador está adyacente al enemigo

```
┌─────────────────────────────────────────────────────────┐
│  👊 PHYSICAL ATTACK PHASE                               │
│                                                         │
│  You're adjacent to an enemy!                          │
│  You can make a PHYSICAL ATTACK:                       │
│                                                         │
│  🤜 PUNCH - Use your arms, chance to hit head          │
│  🦵 KICK  - Use your legs, can knock down enemy        │
│                                                         │
│  💡 Physical attacks generate NO HEAT!                 │
│     Great for finishing off damaged enemies.           │
│                                                         │
│  Select an attack or SKIP to end your turn.            │
└─────────────────────────────────────────────────────────┘
```

---

### Fase 5: DAÑO Y ARMADURA
**Trigger:** Primera vez que el jugador recibe daño significativo

```
┌─────────────────────────────────────────────────────────┐
│  🛡️ DAMAGE & ARMOR                                     │
│                                                         │
│  Your mech took damage! Here's how it works:           │
│                                                         │
│  ARMOR (outer layer) - Absorbs damage first            │
│  STRUCTURE (inner) - If armor gone, hits structure     │
│  CRITICAL HITS - Can destroy weapons & systems         │
│                                                         │
│  💡 Long-press on your mech to see the damage          │
│     display (Paper Doll) with all armor values.        │
│                                                         │
│  Protect damaged locations by turning away!            │
└─────────────────────────────────────────────────────────┘
```

---

### Fase 6: VICTORIA
**Trigger:** Al destruir al enemigo

```
┌─────────────────────────────────────────────────────────┐
│  🏆 VICTORY! TUTORIAL COMPLETE!                         │
│                                                         │
│  Congratulations, MechWarrior!                         │
│                                                         │
│  You've learned the basics:                            │
│  ✅ Initiative determines turn order                   │
│  ✅ Movement types affect defense & options            │
│  ✅ Facing matters for armor                           │
│  ✅ Weapons generate heat                              │
│  ✅ Physical attacks are heat-free                     │
│  ✅ Armor protects structure                           │
│                                                         │
│  You're ready for real battles!                        │
│                                                         │
│  💡 TIP: Try the Mech Bay to customize your mechs.     │
│                                                         │
│             [ CONTINUE TO MAIN MENU ]                   │
└─────────────────────────────────────────────────────────┘
```

---

## 🔧 IMPLEMENTACIÓN TÉCNICA

### Archivo de Estado del Tutorial
```gdscript
# tutorial_manager.gd

const TUTORIAL_SAVE_PATH = "user://tutorial_state.save"

enum TutorialStep {
    NOT_STARTED,
    WELCOME_SHOWN,
    INITIATIVE_EXPLAINED,
    MOVEMENT_TYPE_EXPLAINED,
    MOVEMENT_DESTINATION_EXPLAINED,
    FACING_EXPLAINED,
    TARGET_SELECTION_EXPLAINED,
    WEAPON_SELECTION_EXPLAINED,
    HEAT_EXPLAINED,
    PHYSICAL_ATTACK_EXPLAINED,
    DAMAGE_EXPLAINED,
    COMPLETED
}

var current_step: TutorialStep = TutorialStep.NOT_STARTED
var is_tutorial_active: bool = false

func should_start_tutorial() -> bool:
    # Verificar si es primera partida
    if not FileAccess.file_exists(TUTORIAL_SAVE_PATH):
        return true
    
    var file = FileAccess.open(TUTORIAL_SAVE_PATH, FileAccess.READ)
    var data = file.get_var()
    file.close()
    
    return not data.get("completed", false)

func mark_completed():
    var file = FileAccess.open(TUTORIAL_SAVE_PATH, FileAccess.WRITE)
    file.store_var({"completed": true, "timestamp": Time.get_unix_time_from_system()})
    file.close()
```

### Sistema de Hints
```gdscript
# tutorial_hint_popup.gd

class_name TutorialHintPopup
extends Control

signal hint_acknowledged

@onready var title_label: Label = $Panel/VBox/Title
@onready var content_label: RichTextLabel = $Panel/VBox/Content
@onready var tip_label: Label = $Panel/VBox/Tip
@onready var ok_button: Button = $Panel/VBox/OKButton

func show_hint(title: String, content: String, tip: String = ""):
    title_label.text = title
    content_label.text = content
    tip_label.text = tip if tip else ""
    tip_label.visible = tip != ""
    
    visible = true
    # Pausar el juego mientras se muestra el hint
    get_tree().paused = true

func _on_ok_pressed():
    visible = false
    get_tree().paused = false
    hint_acknowledged.emit()
```

### Integración con Battle Scene
```gdscript
# En battle_scene.gd

var tutorial_manager: TutorialManager = null
var is_tutorial_battle: bool = false

func _ready():
    # ... código existente ...
    
    # Verificar si es tutorial
    if TutorialManager.should_start_tutorial():
        is_tutorial_battle = true
        tutorial_manager = TutorialManager.new()
        add_child(tutorial_manager)
        tutorial_manager.start_tutorial()

# Hooks para el tutorial
func _on_phase_changed(new_phase: int):
    # ... código existente ...
    
    if is_tutorial_battle and tutorial_manager:
        tutorial_manager.on_phase_changed(new_phase)

func _on_unit_activated(unit):
    # ... código existente ...
    
    if is_tutorial_battle and tutorial_manager:
        tutorial_manager.on_unit_activated(unit)
```

---

## 📱 DISEÑO UI DE HINTS

### Estilo Visual
```
┌────────────────────────────────────────┐
│ ┌────────────────────────────────────┐ │
│ │  🎯 TÍTULO DEL HINT                │ │  <- Header con icono
│ ├────────────────────────────────────┤ │
│ │                                    │ │
│ │  Contenido explicativo del hint.   │ │  <- Cuerpo principal
│ │  Puede ser multilinea y usar       │ │
│ │  formato BBCode para énfasis.      │ │
│ │                                    │ │
│ ├────────────────────────────────────┤ │
│ │  💡 Tip adicional opcional         │ │  <- Tip destacado
│ ├────────────────────────────────────┤ │
│ │         [ ENTENDIDO ]              │ │  <- Botón de acción
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘

Colores:
- Fondo panel: rgba(20, 30, 40, 0.95)
- Borde: Azul militar #4A90D9
- Título: Blanco #FFFFFF
- Contenido: Gris claro #CCCCCC
- Tips: Amarillo #FFD700
- Botón: Azul #4A90D9 con hover más claro
```

### Posicionamiento
- **Centro de pantalla** para hints importantes (bloquean el juego)
- **Esquina inferior** para tips contextuales (no bloquean)
- **Junto al elemento relevante** cuando sea posible (con flecha)

---

## 🔄 FLUJO COMPLETO

```
┌─────────────┐
│ NEW ACCOUNT │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ Check tutorial_state │
│ File exists?        │
└──────┬──────────────┘
       │ NO
       ▼
┌─────────────────────┐
│ TUTORIAL MODE       │
│ - Force 1v1         │
│ - Force EASY AI     │
│ - Load tutorial map │
│ - Atlas vs Hunchback│
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ WELCOME POPUP       │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ BATTLE LOOP         │◄────────────┐
│ (with hints)        │             │
└──────┬──────────────┘             │
       │                            │
       ▼                            │
   ┌───────┐                        │
   │ Phase │───► Show relevant hint │
   │ Change│                        │
   └───┬───┘                        │
       │                            │
       ▼                            │
   ┌───────────┐    NO              │
   │ Enemy     │────────────────────┘
   │ Destroyed?│
   └───┬───────┘
       │ YES
       ▼
┌─────────────────────┐
│ VICTORY + SUMMARY   │
│ Save tutorial_done  │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ MAIN MENU           │
│ (Normal game flow)  │
└─────────────────────┘
```

---

## 📋 CHECKLIST DE IMPLEMENTACIÓN

### Fase 1: Infraestructura (2h)
- [ ] Crear `TutorialManager` singleton
- [ ] Crear `TutorialHintPopup` scene
- [ ] Sistema de guardado de progreso tutorial
- [ ] Detección de cuenta nueva

### Fase 2: Contenido (2h)
- [ ] Escribir todos los textos de hints
- [ ] Crear iconos para cada tipo de hint
- [ ] Diseñar mapa tutorial simplificado
- [ ] Configurar mechs tutorial (Atlas vs Hunchback)

### Fase 3: Integración (3h)
- [ ] Hooks en battle_scene.gd
- [ ] Triggers para cada fase
- [ ] Lógica de progresión de tutorial
- [ ] Pantalla de victoria especial

### Fase 4: Pulido (1h)
- [ ] Animaciones de entrada/salida
- [ ] Sonidos para hints
- [ ] Testing completo
- [ ] Opción para repetir tutorial

---

## 🌍 LOCALIZACIÓN

Todos los textos del tutorial deben estar en el sistema de traducción:

```
TUTORIAL_WELCOME_TITLE = "WELCOME TO STEEL TITANS!"
TUTORIAL_WELCOME_BODY = "This is your first battle..."
TUTORIAL_INITIATIVE_TITLE = "INITIATIVE PHASE"
TUTORIAL_INITIATIVE_BODY = "Each turn, both sides roll..."
# etc.
```

---

## 🔮 FUTURAS MEJORAS (Post-Launch)

1. **Tutorial Avanzado** - Mecánicas complejas (torso twist, aimed shots)
2. **Tutorial de Mech Bay** - Personalización de mechs
3. **Tutorial Multijugador** - Etiqueta y mecánicas online
4. **Misiones Tutorial** - Serie de misiones con dificultad progresiva
5. **Videos Integrados** - Clips cortos mostrando mecánicas

---

*Documento creado: 1 de Diciembre, 2025*  
*Última actualización: 1 de Diciembre, 2025*
