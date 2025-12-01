# 📘 GAME DESIGN DOCUMENT (GDD)
## STEEL TITANS: Tactical Warfare

**Versión:** 1.0  
**Fecha:** 29 de Noviembre, 2025  
**Autor:** DAMSanti  
**Estado:** Pre-Producción

---

## 📑 ÍNDICE

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Concepto del Juego](#2-concepto-del-juego)
3. [Universo y Narrativa](#3-universo-y-narrativa)
4. [Mecánicas de Juego](#4-mecánicas-de-juego)
5. [Progresión del Jugador](#5-progresión-del-jugador)
6. [Modos de Juego](#6-modos-de-juego)
7. [Contenido](#7-contenido)
8. [Interfaz de Usuario](#8-interfaz-de-usuario)
9. [Multijugador y Social](#9-multijugador-y-social)
10. [Monetización](#10-monetización)
11. [Audio](#11-audio)
12. [Requisitos Técnicos](#12-requisitos-técnicos)
13. [Roadmap de Desarrollo](#13-roadmap-de-desarrollo)

---

# 1. RESUMEN EJECUTIVO

## 1.1 Elevator Pitch

> **STEEL TITANS** es un juego de combate táctico por turnos con mechs gigantes para dispositivos móviles. Ofrece combate PvP competitivo 1v1, 2v2 y 4v4 con partidas rápidas de 10-15 minutos, personalización profunda de mechs, y un sistema de progresión que recompensa la habilidad sobre el tiempo invertido.

## 1.2 Datos Clave

| Aspecto | Detalle |
|---------|---------|
| **Título** | Steel Titans: Tactical Warfare |
| **Género** | Estrategia táctica por turnos |
| **Plataforma principal** | Android (móvil) |
| **Público objetivo** | Jugadores casuales de móvil + fans de mechs |
| **Duración de sesión** | 10-15 minutos |
| **Modelo de negocio** | Compra única + tienda de cosméticos |
| **Motor** | Godot 4.5 |

## 1.3 Pilares de Diseño

1. **Accesible pero Profundo** - Fácil de aprender, difícil de dominar
2. **Competitivo y Justo** - La habilidad determina la victoria, no el dinero
3. **Sesiones Rápidas** - Perfecto para jugar en cualquier momento
4. **Personalización Significativa** - Tu mech, tu estrategia

## 1.4 Referentes

| Juego | Qué tomamos |
|-------|-------------|
| **XCOM** | Combate táctico por turnos, gestión de riesgo |
| **BattleTech (HBS)** | Sistema de mechs, calor, localizaciones de daño |
| **Clash Royale** | Partidas rápidas, progresión móvil, matchmaking |
| **Into the Breach** | Claridad táctica, información visible |

---

# 2. CONCEPTO DEL JUEGO

## 2.1 Core Loop

```
┌─────────────────────────────────────────────────────────────────┐
│                        CORE GAME LOOP                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│    ┌──────────┐    ┌──────────┐    ┌──────────┐               │
│    │ PREPARAR │───▶│ COMBATIR │───▶│ RECOMPEN │               │
│    │  MECH    │    │          │    │   SAS    │               │
│    └──────────┘    └──────────┘    └────┬─────┘               │
│         ▲                               │                      │
│         │         ┌──────────┐          │                      │
│         └─────────│ MEJORAR  │◀─────────┘                      │
│                   │ PROGRESO │                                 │
│                   └──────────┘                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Flujo de una Sesión

1. **Iniciar sesión** → Ver misiones diarias, recompensas pendientes
2. **Preparar** → Seleccionar/personalizar mech para la partida
3. **Buscar partida** → Matchmaking por ELO
4. **Combatir** → Partida táctica (10-15 min)
5. **Resultados** → XP, monedas, progreso de misiones
6. **Repetir** o **Salir**

## 2.2 Experiencia del Jugador

### Primera Hora (Onboarding)
1. **Tutorial guiado** (5 min) - Movimiento, ataque, conceptos básicos
2. **Primera batalla vs IA** (10 min) - Victoria asegurada para engagement
3. **Desbloqueo de personalización** - Introducción al editor de loadout
4. **Segunda batalla con loadout propio** - Aplicar lo aprendido
5. **Desbloqueo de multijugador** (nivel 3) - Listo para PvP

### Sesión Típica (Jugador Establecido)
- Revisar misiones diarias
- 2-3 partidas ranked
- Ajustar loadout si es necesario
- Revisar progreso/desbloqueos
- Duración total: 30-45 minutos

## 2.3 Fantasía del Jugador

> *"Soy un piloto de élite que controla una máquina de guerra devastadora. Cada decisión táctica que tomo puede cambiar el curso de la batalla. Mi conocimiento del terreno, mi gestión del calor, y mi capacidad para predecir al enemigo son lo que me hace victorioso."*

---

# 3. UNIVERSO Y NARRATIVA

## 3.1 Setting: Los Sectores Fronterizos

> En el año 3147, la humanidad se ha expandido por los Sectores Fronterizos, una región del espacio disputada por las Grandes Casas. Los conflictos se resuelven mediante combates ritualizados entre **Steel Titans** - máquinas de guerra bípedas pilotadas por guerreros de élite llamados **Lancers**.

### Contexto Histórico
- **Era de Expansión** (2800-3000): Colonización de los Sectores Fronterizos
- **Las Guerras de Sucesión** (3000-3100): Conflicto total, tecnología perdida
- **El Pacto de Hierro** (3105): Acuerdo para resolver conflictos mediante duelos de Titans
- **Era Actual** (3147): Combate ritualizado, honor y gloria

### Las Grandes Casas

| Casa | Símbolo | Color | Filosofía | Especialidad |
|------|---------|-------|-----------|--------------|
| **Casa Ferrum** | Yunque | Rojo/Negro | Fuerza bruta | Titans pesados y de asalto |
| **Casa Volant** | Halcón | Azul/Blanco | Velocidad y precisión | Titans ligeros, movilidad |
| **Casa Ignis** | Llama | Naranja/Gris | Potencia de fuego | Armas de energía, calor |
| **Casa Fortis** | Escudo | Verde/Dorado | Defensa y resistencia | Blindaje, supervivencia |
| **Casa Umbra** | Sombra | Púrpura/Negro | Sigilo y engaño | ECM, guerra electrónica |

*Nota: Las casas son principalmente estéticas/narrativas. No afectan gameplay.*

## 3.2 Los Steel Titans

### ¿Qué es un Steel Titan?
Máquinas de combate bípedas de 8-100 toneladas, pilotadas por un único **Lancer**. Equipadas con:
- **Reactor de fusión** - Genera energía y calor
- **Giroscopio** - Mantiene el equilibrio
- **Estructura interna** - Esqueleto del Titan
- **Blindaje** - Protección externa
- **Armamento** - Armas montadas en brazos, torso, cabeza

### Clasificación por Peso

| Clase | Tonelaje | Rol | Características |
|-------|----------|-----|-----------------|
| **Ligero** | 20-35t | Explorador, flanqueador | Rápido, frágil, barato |
| **Medio** | 40-55t | Versátil, soporte | Equilibrado |
| **Pesado** | 60-75t | Línea de batalla | Resistente, buen armamento |
| **Asalto** | 80-100t | Destructor | Lento, devastador, tanque |

## 3.3 Glosario de Términos

| Término Original | Steel Titans | Descripción |
|------------------|--------------|-------------|
| BattleMech | Steel Titan | Máquina de guerra bípeda |
| MechWarrior | Lancer | Piloto de Titan |
| Inner Sphere | Sectores Fronterizos | Región del espacio humano |
| Great Houses | Grandes Casas | Facciones políticas |
| Lance | Escuadrón | Grupo de 2-4 Titans |
| BattleValue (BV) | Combat Rating (CR) | Valor de combate de un Titan |
| C-Bills | Créditos de Titanio (CT) | Moneda del juego |

## 3.4 Tono y Estética

- **Visual**: Militar, industrial, realista dentro de la ciencia ficción
- **Color palette**: Grises, verdes militares, acentos de color por Casa
- **UI**: Limpia, funcional, HUD militar
- **Narrativa**: Seria pero no grimdark, honor entre guerreros
- **Sin**: Gore excesivo, temas políticos modernos, humor fuera de lugar

---

# 4. MECÁNICAS DE JUEGO

## 4.1 Sistema de Combate

### Estructura de Turnos

El combate sigue las fases clásicas adaptadas para móvil:

```
┌─────────────────────────────────────────────────────────────┐
│                    ESTRUCTURA DE TURNO                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. FASE DE INICIATIVA                                      │
│     └─ Se determina orden de activación                     │
│                                                             │
│  2. FASE DE MOVIMIENTO                                      │
│     └─ Todos los Titans se mueven (orden de iniciativa)     │
│                                                             │
│  3. FASE DE COMBATE                                         │
│     └─ Declaración y resolución de ataques                  │
│                                                             │
│  4. FASE DE CALOR                                           │
│     └─ Disipación de calor, chequeos de sobrecalentamiento  │
│                                                             │
│  5. FASE FINAL                                              │
│     └─ Efectos de fin de turno, chequeo de victoria         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Tiempo por Turno
- **Límite**: 60 segundos por jugador por fase
- **Overtime**: Si se agota el tiempo, se ejecuta acción por defecto (no moverse/no atacar)
- **Banco de tiempo**: 30 segundos adicionales por partida para decisiones críticas

### Duración de Partida
- **Objetivo**: 10-15 minutos
- **Turnos estimados**: 8-12 turnos
- **Límite máximo**: 20 turnos (empate si no hay victoria)

## 4.2 Movimiento

### Tipos de Movimiento

| Tipo | Descripción | MP | Modificador Defensa | Calor |
|------|-------------|----|--------------------|-------|
| **Estacionario** | No moverse | 0 | +0 | 0 |
| **Caminar** | Movimiento normal | Base | +1 | 0 |
| **Correr** | Movimiento rápido | Base × 1.5 | +2 | +2 |
| **Saltar** | Con Jump Jets | Variable | +3 | +Jets usados |

### Terreno

| Tipo | Coste MP | Modificador Ataque | Efecto Especial |
|------|----------|-------------------|-----------------|
| **Llano** | 1 | +0 | - |
| **Bosque ligero** | 2 | +1 a defensa | Cobertura parcial |
| **Bosque denso** | 3 | +2 a defensa | Cobertura total |
| **Colina** | +1 por nivel | -1 si elevado | Altura táctica |
| **Agua (poca)** | 2 | +0 | -2 calor/turno |
| **Agua (profunda)** | 4 | +0 | -4 calor/turno, daño a piernas |
| **Edificio** | Variable | +1-3 | Destruible |

### Facing (Orientación)
- Los Titans tienen 6 direcciones de facing (hexagonal)
- **Arcos de ataque**: Frontal, Laterales (izq/der), Trasero
- Cambiar facing cuesta MP
- Ataques por la espalda ignoran parte del blindaje

## 4.3 Combate

### Resolución de Ataques

```
Para Impactar = 2d6 ≥ (4 + Gunnery + Modificadores)

Modificadores:
  + Rango (corto/medio/largo)
  + Movimiento del atacante
  + Movimiento del defensor  
  + Terreno/Cobertura
  + Calor del atacante
  + Daño del atacante (brazos/sensores)
```

### Tabla de Localizaciones (2d6)

| Resultado | Frontal | Lateral | Trasero |
|-----------|---------|---------|---------|
| 2 | Torso Central (Crítico) | Torso Central (Crítico) | Torso Central (Crítico) |
| 3 | Pierna Derecha | Pierna Trasera | Torso Central |
| 4 | Brazo Derecho | Pierna Delantera | Torso Derecho |
| 5 | Brazo Derecho | Torso Frontal | Torso Derecho |
| 6 | Pierna Derecha | Torso | Torso Derecho |
| 7 | Torso Central | Torso Central | Torso Central |
| 8 | Torso Izquierdo | Torso | Torso Izquierdo |
| 9 | Pierna Izquierda | Torso Frontal | Torso Izquierdo |
| 10 | Brazo Izquierdo | Pierna Delantera | Torso Izquierdo |
| 11 | Pierna Izquierda | Pierna Trasera | Torso Central |
| 12 | Cabeza | Cabeza | Cabeza |

### Daño y Destrucción

1. **Daño a Blindaje** → Se resta del blindaje de la localización
2. **Blindaje agotado** → Daño pasa a Estructura Interna
3. **Estructura agotada** → Localización destruida + daño de transferencia
4. **Críticos**: Cuando se daña estructura, tirada de crítico puede destruir componentes

### Condiciones de Victoria

| Condición | Descripción |
|-----------|-------------|
| **Destrucción** | Todos los Titans enemigos destruidos |
| **Descabezamiento** | Destruir la cabeza de un Titan (piloto muerto) |
| **Desconexión** | Destruir el motor (3 críticos en Torso Central) |
| **Rendición** | Jugador se rinde |
| **Tiempo** | Si se acaba el tiempo, gana quien tenga más CR restante |

## 4.4 Sistema de Calor

### Generación de Calor

| Fuente | Calor Generado |
|--------|----------------|
| Armas de energía | Variable (1-12 por arma) |
| Correr | +2 |
| Saltar | +1 por Jump Jet usado |
| Ambiente (opcional) | ±2 según mapa |

### Disipación de Calor

- **Heat Sinks simples**: 1 calor/turno cada uno
- **Heat Sinks dobles**: 2 calor/turno cada uno
- **Base**: 10 Heat Sinks incluidos en motor

### Efectos del Calor

| Nivel de Calor | Efecto |
|----------------|--------|
| 0-4 | Normal |
| 5-8 | +1 a tiradas de ataque |
| 9-12 | +2 a tiradas, -1 MP |
| 13-17 | +3 a tiradas, -2 MP, riesgo de shutdown |
| 18-23 | +4 a tiradas, -3 MP, shutdown probable |
| 24+ | Riesgo de explosión de munición |

### Shutdown
- Titan se apaga temporalmente
- Siguiente turno: tirada para reiniciar
- Durante shutdown: defensa -4, no puede actuar

## 4.5 Sistemas y Equipamiento

### Categorías de Armas

#### Armas de Energía
| Arma | Daño | Calor | Rango C/M/L | Tonelaje | Críticos |
|------|------|-------|-------------|----------|----------|
| Small Laser | 3 | 1 | 1/2/3 | 0.5 | 1 |
| Medium Laser | 5 | 3 | 3/6/9 | 1 | 1 |
| Large Laser | 8 | 8 | 5/10/15 | 5 | 2 |
| PPC | 10 | 10 | 6/12/18 | 7 | 3 |
| ER Large Laser | 8 | 12 | 7/14/19 | 5 | 2 |

#### Armas Balísticas
| Arma | Daño | Calor | Rango C/M/L | Munición | Tonelaje |
|------|------|-------|-------------|----------|----------|
| Machine Gun | 2 | 0 | 1/2/3 | 200 | 0.5 |
| AC/2 | 2 | 1 | 8/16/24 | 45 | 6 |
| AC/5 | 5 | 1 | 6/12/18 | 20 | 8 |
| AC/10 | 10 | 3 | 5/10/15 | 10 | 12 |
| AC/20 | 20 | 7 | 3/6/9 | 5 | 14 |
| Gauss Rifle | 15 | 1 | 7/15/22 | 8 | 15 |

#### Misiles
| Arma | Daño | Calor | Rango C/M/L | Munición | Tonelaje |
|------|------|-------|-------------|----------|----------|
| SRM-2 | 2×2 | 2 | 3/6/9 | 50 | 1 |
| SRM-4 | 4×2 | 3 | 3/6/9 | 25 | 2 |
| SRM-6 | 6×2 | 4 | 3/6/9 | 15 | 3 |
| LRM-5 | 5×1 | 2 | 6/7-12/21 | 24 | 2 |
| LRM-10 | 10×1 | 4 | 6/7-12/21 | 12 | 5 |
| LRM-15 | 15×1 | 5 | 6/7-12/21 | 8 | 7 |
| LRM-20 | 20×1 | 6 | 6/7-12/21 | 6 | 10 |

### Equipamiento Especial

| Equipo | Efecto | Tonelaje | Críticos |
|--------|--------|----------|----------|
| Jump Jets | Permite saltar | 0.5-2 | 1 |
| CASE | Contiene explosiones de munición | 0.5 | 1 |
| Heat Sink | +1 disipación de calor | 1 | 1 |
| Double Heat Sink | +2 disipación de calor | 1 | 3 |
| ECM | Interfiere sensores enemigos | 1.5 | 2 |
| BAP | Mejora detección | 1.5 | 2 |
| AMS | Derriba misiles entrantes | 0.5 | 1 |
| TAG | Mejora precisión de misiles aliados | 1 | 1 |
| Artemis IV | +2 a impacto de misiles | 1 | 1 |

## 4.6 Ataques Físicos

| Ataque | Daño | Requisito | Modificador |
|--------|------|-----------|-------------|
| **Puñetazo** | Peso/10 | Adyacente, brazo funcional | +0 |
| **Patada** | Peso/5 | Adyacente | -2 |
| **Carga** | Peso/10 + hexes movidos | Correr en línea recta | Daño mutuo |
| **DFA (Death from Above)** | Peso/10 × 3 | Saltar sobre enemigo | Riesgo de caída |

---

# 5. PROGRESIÓN DEL JUGADOR

## 5.1 Sistema de Niveles

### Experiencia (XP)

| Acción | XP Ganada |
|--------|-----------|
| Victoria en PvP | 100 XP |
| Derrota en PvP | 40 XP |
| Victoria vs IA | 30 XP |
| Derrota vs IA | 15 XP |
| Completar desafío | 50-200 XP |
| Primera partida del día | +50 XP bonus |

### Tabla de Niveles

| Nivel | XP Total | XP para Siguiente | Desbloqueo |
|-------|----------|-------------------|------------|
| 1 | 0 | 100 | Tutorial, Single Player básico |
| 2 | 100 | 200 | **Editor de Loadout** |
| 3 | 300 | 300 | **Multijugador PvP** |
| 4 | 600 | 400 | Color de Titan #1 |
| 5 | 1,000 | 500 | **Titan Medio #1** |
| 6 | 1,500 | 600 | Emblema #1 |
| 7 | 2,100 | 700 | Color #2 |
| 8 | 2,800 | 800 | Modo 2v2 |
| 9 | 3,600 | 900 | Color #3 |
| 10 | 4,500 | 1,000 | **Titan Pesado #1** |
| 15 | 10,000 | 1,500 | **Titan Asalto #1** |
| 20 | 20,000 | 2,000 | Modo 4v4 |
| 25 | 32,500 | 2,500 | **Titan Legendario #1** |
| ... | ... | ... | Continúa con más cosméticos y Titans |

### Nivel Máximo
- **Soft cap**: Nivel 50 (todos los desbloqueos de gameplay)
- **Prestige**: Después del 50, niveles de prestigio con recompensas cosméticas

## 5.2 Desbloqueos por Categoría

### Titans Desbloqueables

**Inicio (Nivel 1):**
- 2 Titans Ligeros predeterminados

**Por Nivel:**
| Nivel | Desbloqueo |
|-------|------------|
| 5 | Titan Medio #1 |
| 10 | Titan Pesado #1, Titan Ligero #3 |
| 15 | Titan Asalto #1, Titan Medio #2 |
| 20 | Titan Pesado #2 |
| 25 | Titan Asalto #2 |
| 30 | Titan Ligero #4, Titan Medio #3 |
| 35 | Titan Pesado #3 |
| 40 | Titan Asalto #3 |
| 45 | Titan Medio #4 |
| 50 | Titan Legendario |

### Cosméticos (Cada nivel impar)
- Colores de pintura
- Patrones de camuflaje
- Emblemas/insignias
- Efectos de victoria

### Equipamiento
- Todo el equipamiento disponible desde nivel 2
- Balance por Combat Rating, no por bloqueo

## 5.3 Misiones y Objetivos

### Misiones Diarias (3 por día)
| Tipo | Ejemplo | Recompensa |
|------|---------|------------|
| Fácil | "Juega 2 partidas" | 20 CT |
| Media | "Gana 1 partida PvP" | 50 CT |
| Difícil | "Destruye 3 Titans con armas de energía" | 100 CT |

### Misiones Semanales (3 por semana)
| Tipo | Ejemplo | Recompensa |
|------|---------|------------|
| Progreso | "Gana 10 partidas" | 300 CT + Skin |
| Habilidad | "Consigue 5 victorias seguidas" | 500 CT |
| Social | "Juega 5 partidas en equipo" | 200 CT + XP |

### Logros (Una vez)
- "Primera victoria" → 100 CT
- "Primer Titan pesado" → Skin exclusiva
- "100 victorias" → Título especial
- "Alcanza Rango Oro" → Emblema dorado

---

# 6. MODOS DE JUEGO

## 6.1 Single Player

### Tutorial
- **Duración**: 5 minutos
- **Contenido**: Movimiento, ataque, calor, victoria
- **Recompensa**: 100 XP, desbloquea práctica

### Práctica vs IA
- **Configuración libre**: Elige Titan, mapa, dificultad
- **Dificultades**: Fácil, Normal, Difícil, Veterano
- **Uso**: Probar loadouts, aprender mecánicas
- **Recompensas**: XP reducido (30% del PvP)

### Desafíos Tácticos
Escenarios fijos con condiciones especiales:

| Desafío | Descripción | Objetivo |
|---------|-------------|----------|
| "David vs Goliat" | Titan Ligero vs Titan Asalto | Sobrevivir 10 turnos |
| "Sin calor" | Mapa volcánico, +4 calor ambiental | Destruir enemigo |
| "Francotirador" | Solo armas de largo alcance | Eliminar 3 Titans |
| "Última defensa" | 2 Titans vs 4 enemigos | Victoria por puntos |
| "Precisión mortal" | Munición limitada | Ganar sin fallar |

- **Leaderboards**: Tiempo de completado, daño recibido
- **Recompensas**: XP, CT, skins exclusivas por 3 estrellas

## 6.2 Multijugador PvP

### Quick Match (Partida Rápida)
- **Sin ranking**, para práctica y diversión
- **Matchmaking**: Por nivel de cuenta aproximado
- **Recompensas**: XP y CT completos

### Ranked (Competitivo)
- **Sistema ELO** con rangos visibles
- **Temporadas**: 2 meses cada una
- **Recompensas de fin de temporada** según rango máximo alcanzado

### Formatos

| Formato | Jugadores | Titans/Jugador | CR Máximo | Tiempo Est. |
|---------|-----------|----------------|-----------|-------------|
| **Duelo** | 1v1 | 1 | 3,000 | 8-10 min |
| **Escaramuza** | 1v1 | 2 | 5,000 | 12-15 min |
| **Equipo** | 2v2 | 1 | 3,000/jugador | 10-12 min |
| **Gran Batalla** | 4v4 | 1 | 3,000/jugador | 15-20 min |

*Desbloqueo: 2v2 a nivel 8, 4v4 a nivel 20*

### Sistema de Ranking

| Rango | ELO | Icono | Recompensa de Temporada |
|-------|-----|-------|-------------------------|
| Bronce | 0-999 | 🥉 | 100 CT |
| Plata | 1000-1499 | 🥈 | 300 CT + Emblema |
| Oro | 1500-1999 | 🥇 | 500 CT + Skin |
| Platino | 2000-2499 | 💎 | 800 CT + Skin Rara |
| Diamante | 2500-2999 | 💠 | 1200 CT + Skin Épica |
| Leyenda | 3000+ | ⭐ | 2000 CT + Skin Legendaria + Título |

### Matchmaking
- **Búsqueda**: Por ELO similar (±200)
- **Expansión**: Cada 30 segundos amplía rango
- **Máximo espera**: 3 minutos, luego ofrece vs IA

## 6.3 Partidas Privadas

- **Crear sala** con código
- **Configuración personalizada**:
  - Mapa específico o aleatorio
  - Límite de CR
  - Restricciones de equipamiento
  - Número de turnos
- **Sin recompensas de ranking**
- **Para**: Práctica con amigos, torneos comunitarios

---

# 7. CONTENIDO

## 7.1 Steel Titans (Mechs)

### Titans de Lanzamiento (20)

#### Ligeros (5)
| Nombre | Tonelaje | Rol | Firma |
|--------|----------|-----|-------|
| **Specter** | 25t | Explorador | Muy rápido, 6 Jump Jets |
| **Viper** | 30t | Hostigador | Medium Lasers, hit & run |
| **Hornet** | 35t | Misiles ligeros | SRM-4, maniobrable |
| **Jackal** | 35t | Francotirador ligero | ER Large Laser |
| **Fang** | 30t | Cuerpo a cuerpo | Garras, máxima velocidad |

#### Medios (6)
| Nombre | Tonelaje | Rol | Firma |
|--------|----------|-----|-------|
| **Warden** | 45t | Equilibrado | AC/5 + lasers |
| **Phalanx** | 50t | Brawler | Doble AC/10, blindaje frontal |
| **Archer** | 55t | Soporte de misiles | LRM-15 × 2 |
| **Templar** | 50t | Tanque | CASE, mucho blindaje |
| **Stalker** | 55t | Cazador | PPC, Jump Jets |
| **Centurion** | 50t | Versátil | AC/10 + LRM-10 |

#### Pesados (5)
| Nombre | Tonelaje | Rol | Firma |
|--------|----------|-----|-------|
| **Crusader** | 65t | Misiles pesados | LRM-20 × 2, devastador |
| **Warlord** | 70t | Línea de batalla | AC/20 + Medium Lasers |
| **Thunder** | 75t | Artillería | Triple PPC |
| **Bastion** | 70t | Tanque pesado | Máximo blindaje, AMS |
| **Havoc** | 65t | Daño sostenido | Large Lasers + Heat Sinks |

#### Asalto (4)
| Nombre | Tonelaje | Rol | Firma |
|--------|----------|-----|-------|
| **Colossus** | 100t | Fortaleza | Devastador pero lento |
| **Overlord** | 90t | Comando | ECM, armas mixtas |
| **Annihilator** | 100t | Destructor | 4× AC/10 |
| **Titan Prime** | 85t | Equilibrado asalto | Versátil, eficiente en calor |

### Variantes
Cada Titan base tiene 2-3 variantes con loadouts diferentes:
- **Specter SPT-1**: Lasers
- **Specter SPT-2**: SRMs
- **Specter SPT-3**: ECM Support

## 7.2 Mapas

### Generación Procedural

**Parámetros configurables:**
- Tamaño: Pequeño (15×15), Medio (20×20), Grande (25×25)
- Bioma: Bosque, Desierto, Urbano, Tundra, Volcánico, Lunar
- Elevación: Plano, Colinas, Montañoso
- Cobertura: Escasa, Moderada, Densa

**Algoritmo garantiza:**
- Zonas de despliegue equilibradas
- Rutas viables entre bases
- Puntos de interés tácticos
- Sin posiciones "rotas"

### Mapas de Desafío (Fijos)

| Mapa | Bioma | Característica |
|------|-------|----------------|
| "Valle de Hierro" | Industrial | Edificios destruibles |
| "Desierto Rojo" | Desierto | Sin cobertura, calor +2 |
| "Bosque Eterno" | Bosque denso | Mucha cobertura, LOS limitada |
| "Base Lunar" | Lunar | Gravedad baja (Jump +2) |
| "Caldera" | Volcánico | Calor +4, lava dañina |

## 7.3 Arsenal

*Ver sección 4.5 para stats completos*

### Por Categoría
- **Energía**: 8 tipos (Lasers, PPC)
- **Balístico**: 8 tipos (AC, Gauss, MG)
- **Misiles**: 8 tipos (SRM, LRM)
- **Equipamiento**: 12 tipos

---

# 8. INTERFAZ DE USUARIO

## 8.1 Principios de UI Móvil

1. **Touch-first**: Diseñado para dedos, no mouse
2. **Información clara**: Todo visible sin menús ocultos
3. **Confirmación de acciones**: Evitar inputs accidentales
4. **Feedback inmediato**: Cada toque tiene respuesta visual/háptica

## 8.2 Pantallas Principales

### Menú Principal
```
┌─────────────────────────────────────────┐
│  [≡]              STEEL TITANS    [⚙️] │
├─────────────────────────────────────────┤
│                                         │
│         [TITAN ACTUAL: WARDEN]          │
│         ┌─────────────────────┐         │
│         │                     │         │
│         │    [Imagen Titan]   │         │
│         │                     │         │
│         └─────────────────────┘         │
│         CR: 1,245  |  Lv. 15            │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │      🎮 JUGAR RANKED            │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌──────────┐  ┌──────────┐            │
│  │ QUICK    │  │ VS IA    │            │
│  │ MATCH    │  │          │            │
│  └──────────┘  └──────────┘            │
│                                         │
│  ┌──────────┐  ┌──────────┐            │
│  │ HANGAR   │  │ TIENDA   │            │
│  └──────────┘  └──────────┘            │
│                                         │
├─────────────────────────────────────────┤
│  [Misiones: 2/3]      CT: 1,450  💎    │
└─────────────────────────────────────────┘
```

### Pantalla de Batalla
```
┌─────────────────────────────────────────┐
│ [☰] T:8  ⏱️0:45  |  TU: ⚔️  ENE: ❤️❤️   │
├─────────────────────────────────────────┤
│                                         │
│                                         │
│           [MAPA HEXAGONAL]              │
│                                         │
│              🤖←Tu Titan                │
│                                         │
│                    🔴←Enemigo           │
│                                         │
│                                         │
├─────────────────────────────────────────┤
│  WARDEN        ████████░░ HP            │
│  Calor: ███░░░░░░░ 4/30                │
├─────────────────────────────────────────┤
│ [MOVER] [ATACAR] [FÍSICO] [FIN TURNO]  │
└─────────────────────────────────────────┘
```

### Editor de Loadout
```
┌─────────────────────────────────────────┐
│ [←] EDITOR: WARDEN          CR: 1,245  │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐    │
│  │         [PAPER DOLL]            │    │
│  │     ┌───┐                       │    │
│  │     │CAB│ ← Cabeza              │    │
│  │  ┌──┼───┼──┐                    │    │
│  │  │BD│TC │BI│ ← Torsos          │    │
│  │  │  │   │  │                    │    │
│  │  └──┴───┴──┘                    │    │
│  │     │   │                       │    │
│  │    PD   PI ← Piernas            │    │
│  └─────────────────────────────────┘    │
│                                         │
│  TORSO CENTRAL (12 slots):             │
│  [Engine][Engine][Gyro][Gyro]          │
│  [H.Sink][H.Sink][-----][-----]        │
│  [-----][-----][-----][-----]          │
│                                         │
│  Tonelaje: 42/50  |  Blindaje: 120     │
├─────────────────────────────────────────┤
│ [ARMAS] [EQUIPO] [BLINDAJE] [GUARDAR]  │
└─────────────────────────────────────────┘
```

## 8.3 Controles Táctiles

| Gesto | Acción |
|-------|--------|
| **Tap** | Seleccionar hex/unidad |
| **Tap largo** | Información detallada |
| **Arrastrar** | Pan de cámara |
| **Pinch** | Zoom in/out |
| **Doble tap** | Centrar en unidad |
| **Swipe en unidad** | Cambiar facing |

## 8.4 Feedback Visual

- **Hexes alcanzables**: Resaltado azul
- **Enemigos en rango**: Resaltado rojo
- **Cobertura**: Icono de escudo
- **Línea de visión**: Línea punteada al apuntar
- **Probabilidad de impacto**: Porcentaje sobre enemigo
- **Daño estimado**: Rango de daño posible

---

# 9. MULTIJUGADOR Y SOCIAL

## 9.1 Infraestructura

### Servidor Dedicado
- **Autoritativo**: Servidor valida todas las acciones
- **Ubicación**: Inicial en Europa, expandir según demanda
- **Capacidad**: Diseñado para 1000 partidas simultáneas inicialmente

### Reconexión
- **Tiempo límite**: 3 minutos para reconectar
- **Durante desconexión**: IA controla el Titan
- **Penalización por abandono**: -50 ELO, posible ban temporal

## 9.2 Comunicación

### Chat en Partida
- **Mensajes predefinidos** (Quick Chat):
  - "¡Buena suerte!"
  - "Bien jugado"
  - "Un momento"
  - "Gracias"
  - "Lo siento"
  - "GG"
- **Pings en mapa**: Marcar posiciones
- **Con chat de texto libre**

### Sistema de Amigos
- **Lista de amigos**: Añadir por código/nombre
- **Estado**: Online, en partida, offline
- **Invitar a partida**: Quick match o privada
- **Historial**: Ver partidas recientes contra/con amigo

## 9.3 Anti-Toxicidad

- **Sistema de reportes**: AFK, trampa, abuso
- **Penalizaciones**:
  - 1ª ofensa: Advertencia
  - 2ª ofensa: Chat muted 24h
  - 3ª ofensa: Ban temporal (3 días)
  - Reincidencia: Ban permanente

## 9.4 Clanes/Equipos (Post-lanzamiento)

*Funcionalidad planificada para actualizaciones futuras:*
- Crear/unirse a clanes
- Guerras de clanes
- Chat de clan
- Rankings de clan

---

# 10. MONETIZACIÓN

## 10.1 Modelo de Negocio

### Precio Base
| Calidad del Producto | Precio Sugerido |
|---------------------|-----------------|
| MVP básico | €0.99 - €1.99 |
| Pulido, contenido base | €4.99 |
| Completo con arte profesional | €7.99 - €9.99 |

### Filosofía
> **"Compra una vez, juega para siempre"**
> - Todo el contenido de gameplay accesible jugando
> - Cosméticos opcionales no afectan el juego
> - Nunca pay-to-win

## 10.2 Moneda del Juego

### Créditos de Titanio (CT)
- **Obtención gratuita**:
  - Victorias en PvP: 20-50 CT
  - Misiones diarias: 50-200 CT
  - Misiones semanales: 200-500 CT
  - Subir de nivel: 100 CT
  - Logros: Variable

- **Compra con dinero real**:
  | Paquete | CT | Precio | CT/€ |
  |---------|-----|--------|------|
  | Pequeño | 500 | €0.99 | 505 |
  | Medio | 1,200 | €1.99 | 603 |
  | Grande | 3,000 | €4.99 | 601 |
  | Mega | 7,500 | €9.99 | 751 |

## 10.3 Tienda de Cosméticos

### Categorías

| Categoría | Rango de Precio (CT) | Ejemplos |
|-----------|---------------------|----------|
| Colores | 50-150 | Paletas de color |
| Patrones | 200-500 | Camuflajes, rayas, llamas |
| Skins | 500-1,500 | Cambios visuales completos |
| Efectos | 300-800 | Estelas, explosiones especiales |
| Emblemas | 100-300 | Insignias para perfil |
| Títulos | 200-500 | Bajo el nombre de jugador |

### Rotación
- **Tienda diaria**: 4 items, cambian cada 24h
- **Tienda semanal**: 6 items, cambian cada 7 días
- **Tienda permanente**: Items siempre disponibles

## 10.4 Qué NO se Vende

❌ **Nunca venderemos:**
- Titans (se desbloquean jugando)
- Armas o equipamiento
- Boost de stats
- Ventaja en matchmaking
- Skip de tiempo de espera
- Loot boxes / gacha

## 10.5 Pase de Temporada (Opcional - Post-lanzamiento)

*Si el juego tiene éxito:*

| Track | Precio | Contenido |
|-------|--------|-----------|
| **Gratuito** | €0 | 20 niveles, CT y cosméticos básicos |
| **Premium** | €4.99 | 50 niveles, skins exclusivas, más CT |

- Duración: 2 meses (alineado con temporada ranked)
- Se completa jugando normalmente
- Sin FOMO excesivo (misiones recuperables)

---

# 11. AUDIO

## 11.1 Diseño de Audio

### Principios
- **Feedback claro**: Cada acción tiene sonido distintivo
- **Información táctica**: Sonidos indican amenazas
- **Atmósfera militar**: Serio, industrial, épico
- **No intrusivo**: Música de fondo sutil

## 11.2 Música

| Contexto | Estilo | Intensidad |
|----------|--------|------------|
| Menú principal | Orquestal épico | Media |
| Hangar/Editor | Industrial ambient | Baja |
| Lobby/Espera | Tensión creciente | Baja→Media |
| Combate - inicio | Percusión militar | Media |
| Combate - intenso | Orquestal + electrónico | Alta |
| Victoria | Triunfante, bronces | Alta |
| Derrota | Sombrío, cuerdas | Media |

### Especificaciones
- **Tracks necesarios**: 8-10 piezas
- **Duración**: 2-4 minutos loop seamless
- **Formato**: OGG, 128kbps (móvil)

## 11.3 Efectos de Sonido

### Prioritarios
| Categoría | Sonidos | Cantidad |
|-----------|---------|----------|
| Armas - Láser | Disparo, impacto | 4 |
| Armas - Balístico | Disparo, recarga, impacto | 6 |
| Armas - Misiles | Lanzamiento, vuelo, explosión | 6 |
| Movimiento | Pasos (por peso), giro | 8 |
| Daño | Impacto blindaje, estructura, crítico | 6 |
| UI | Botones, confirmación, error, notificación | 8 |
| Ambiente | Por bioma | 5 |

### Especificaciones
- **Formato**: OGG, 96kbps
- **Duración**: 0.5-3 segundos
- **Total estimado**: 50-60 efectos

## 11.4 Recursos de Audio

**Opciones para desarrollo:**
1. **Royalty-free**: Freesound, OpenGameArt
2. **Asset packs**: Unity Asset Store, itch.io (~$20-50)
3. **Compositor freelance**: $200-500 para soundtrack básico

---

# 12. REQUISITOS TÉCNICOS

## 12.1 Plataforma Objetivo

### Android (Principal)
| Aspecto | Mínimo | Recomendado |
|---------|--------|-------------|
| Versión | Android 8.0 | Android 11+ |
| RAM | 2 GB | 4 GB |
| Almacenamiento | 200 MB | 500 MB |
| Pantalla | 720p | 1080p |
| Conexión | 3G estable | 4G/WiFi |

### iOS (Futuro)
| Aspecto | Mínimo | Recomendado |
|---------|--------|-------------|
| Versión | iOS 14 | iOS 16+ |
| Dispositivo | iPhone 8 | iPhone 11+ |
| Almacenamiento | 250 MB | 500 MB |

### PC (Secundario - para testing)
- Windows 10+
- 4 GB RAM
- GPU integrada suficiente

## 12.2 Rendimiento Objetivo

| Métrica | Objetivo |
|---------|----------|
| FPS | 60 estable |
| Tiempo de carga | <5 segundos |
| Uso de batería | <15%/hora |
| Datos móviles | <5 MB/partida |
| Latencia aceptable | <200ms |

## 12.3 Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| Motor | Godot 4.5 |
| Lenguaje | GDScript |
| Networking | ENet (UDP) |
| Servidor | Linux (DigitalOcean) |
| Base de datos | PostgreSQL (futuro) |
| Analytics | Firebase (futuro) |

---

# 13. ROADMAP DE DESARROLLO

## 13.1 Fases

### Fase 1: MVP (Actual → +2 meses)
**Objetivo**: Juego funcional jugable

- [ ] Core loop single player completo
- [ ] 5 Titans jugables
- [ ] Editor de loadout básico
- [ ] Multijugador 1v1 funcional
- [ ] UI placeholder funcional
- [ ] Tutorial básico

### Fase 2: Alpha (+2-4 meses)
**Objetivo**: Testing con usuarios reales

- [ ] 10 Titans
- [ ] Sistema de cuentas básico
- [ ] Ranked con ELO
- [ ] Progresión de niveles
- [ ] Generación procedural de mapas
- [ ] 2v2 funcional

### Fase 3: Beta (+4-6 meses)
**Objetivo**: Contenido completo, pulido

- [ ] 20 Titans
- [ ] Arte mejorado (si hay presupuesto)
- [ ] Audio completo
- [ ] Sistema de misiones
- [ ] Tienda de cosméticos
- [ ] 4v4 funcional
- [ ] Desafíos single player

### Fase 4: Lanzamiento (+6-8 meses)
**Objetivo**: Release en Google Play

- [ ] Pulido final
- [ ] Testing extensivo
- [ ] Localización (ES/EN)
- [ ] Marketing básico
- [ ] Página de tienda optimizada

## 13.2 Post-Lanzamiento

### Mes 1-3: Estabilización
- Hotfixes
- Balance según datos reales
- Eventos de lanzamiento

### Mes 4-6: Contenido
- Nuevos Titans (2-3)
- Nuevos mapas de desafío
- Primera temporada ranked

### Mes 7-12: Expansión
- Pase de batalla (si viable)
- Sistema de clanes
- Torneos in-game
- Puerto a iOS

---

# APÉNDICES

## A. Glosario Completo

| Término | Definición |
|---------|------------|
| **Steel Titan** | Máquina de guerra bípeda pilotada |
| **Lancer** | Piloto de un Steel Titan |
| **CR (Combat Rating)** | Valor de combate de un Titan |
| **CT (Créditos de Titanio)** | Moneda del juego |
| **Loadout** | Configuración de armas y equipos |
| **Paper Doll** | Diagrama visual del Titan |
| **Facing** | Dirección a la que apunta el Titan |
| **LOS (Line of Sight)** | Línea de visión |
| **Heat Sink** | Disipador de calor |
| **CASE** | Sistema de contención de explosiones |

## B. Fórmulas Clave

### Combat Rating (CR)
```
CR = (Daño Potencial × 10) + (Blindaje Total × 2) + (Velocidad × 5) + (Especiales × Variable)
```

### Probabilidad de Impacto
```
Base = 8 (necesitas sacar 8+ en 2d6 para impactar)
Modificado = Base + Gunnery + Movimiento + Rango + Terreno + Calor
Probabilidad = (36 - formas_de_sacar_modificado) / 36
```

### ELO (Simplificado)
```
K = 32 (factor de ajuste)
Expected = 1 / (1 + 10^((ELO_enemigo - ELO_propio) / 400))
Nuevo_ELO = ELO_actual + K × (Resultado - Expected)
Resultado = 1 (victoria), 0 (derrota)
```

## C. Referencias

- BattleTech Manual de Reglas (inspiración mecánica)
- XCOM: Enemy Unknown (referencia de UI táctica)
- Clash Royale (referencia de progresión móvil)
- Into the Breach (referencia de claridad táctica)

---

**FIN DEL DOCUMENTO**

*Última actualización: 29 de Noviembre, 2025*  
*Versión: 1.0*
