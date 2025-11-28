# 📋 TODO - BATTLETECH MOBILE

## Estado del Proyecto
- **Versión actual**: Alpha
- **Última actualización**: 28/11/2025
- **Branch**: multiplayer

---

## 🎯 FASE 1 - PULIDO VISUAL (Prioridad Alta)

### 🎓 Tutorial Interactivo
- [ ] Diseñar flujo del tutorial (5-7 pasos básicos)
- [ ] Crear escena `tutorial_scene.tscn`
- [ ] Paso 1: Explicar controles de cámara (pan/zoom)
- [ ] Paso 2: Selección de mech y movimiento
- [ ] Paso 3: Tipos de movimiento (Walk/Run/Jump)
- [ ] Paso 4: Selección de objetivo y ataque con armas
- [ ] Paso 5: Sistema de calor
- [ ] Paso 6: Ataques físicos
- [ ] Paso 7: Condiciones de victoria
- [ ] Sistema de highlight para elementos UI durante tutorial
- [ ] Opción de saltar tutorial
- [ ] Flag en user://settings para no mostrar de nuevo

### 💥 Animaciones de Impacto
- [ ] Crear partículas para impacto balístico (chispas metálicas)
- [ ] Crear partículas para impacto láser (destello energético)
- [ ] Crear partículas para impacto misil (explosión pequeña)
- [ ] Partículas de armadura saltando al recibir daño
- [ ] Efecto de sacudida de cámara (screen shake) en impactos críticos
- [ ] Pool de partículas reutilizables
- [ ] Integrar con `weapon_attack_system.gd`

### 🔫 Animación de Disparo
- [ ] Crear shader/efecto de línea para proyectiles balísticos
- [ ] Crear shader de rayo para láseres (Line2D con glow)
- [ ] Crear efecto de estela para misiles (curva parabólica)
- [ ] Sistema de timing: disparo → viaje → impacto
- [ ] Múltiples disparos simultáneos para armas automáticas
- [ ] Sonido sincronizado con animación
- [ ] Integrar en flujo de combate (no bloquear UI)

### 🌫️ Mech Humeando
- [ ] Crear GPUParticles2D para humo ligero (daño medio)
- [ ] Crear GPUParticles2D para humo denso (daño crítico)
- [ ] Crear GPUParticles2D para fuego (estructura expuesta)
- [ ] Crear efecto de vapor para calor alto (>20)
- [ ] Lógica en `mech.gd` para activar efectos según estado
- [ ] Optimizar: desactivar partículas fuera de pantalla

### 🎯 Indicador de Turno Activo
- [ ] Crear indicador circular animado bajo mech activo
- [ ] Pulso de color según equipo (azul jugador, rojo enemigo)
- [ ] Flecha/banner flotante sobre mech activo
- [ ] Mini-retrato del mech activo en esquina de pantalla
- [ ] Animación de transición entre mechs
- [ ] Sonido de "tu turno" cuando toca mech del jugador

---

## 🎮 FASE 2 - CONTENIDO (Prioridad Media-Alta)

### 🏁 Modos de Juego
- [ ] **Deathmatch**: Eliminar todos los mechs enemigos (actual)
- [ ] **King of the Hill**: Controlar zona central X turnos
- [ ] **Capture the Flag**: Llevar objeto a zona propia
- [ ] **Escort**: Proteger VIP mientras avanza al objetivo
- [ ] **Survival**: Oleadas de enemigos crecientes
- [ ] Selector de modo en lobby/menú
- [ ] Condiciones de victoria por modo
- [ ] UI específica por modo (contador de zona, marcador de flag, etc.)

### 📖 Campañas
- [ ] Diseñar estructura de campaña (5-10 misiones)
- [ ] Sistema de progresión entre misiones
- [ ] Persistencia de daño entre misiones (reparaciones)
- [ ] Narrativa básica (briefings pre/post misión)
- [ ] Recompensas por completar misiones (C-Bills, nuevos mechs)
- [ ] Dificultad escalable
- [ ] Guardar/cargar progreso de campaña
- [ ] Escena `campaign_menu.tscn`

### 👨‍✈️ Sistema de Pilotos
- [ ] Crear clase `Pilot` con atributos:
  - [ ] Gunnery (precisión de disparo)
  - [ ] Piloting (control, resistencia a caídas)
  - [ ] Tactics (iniciativa bonus)
  - [ ] Experience points
- [ ] Sistema de niveles (1-10)
- [ ] Rasgos especiales (ej: "Sniper" +1 largo alcance)
- [ ] Heridas de piloto que afectan rendimiento
- [ ] UI de asignación piloto-mech
- [ ] Pilotos pueden morir (permadeath opcional)
- [ ] Base de datos de pilotos predefinidos

### 🤖 Más Mechs
- [ ] Añadir mechs ligeros: Locust, Commando, Spider, Firestarter
- [ ] Añadir mechs medios: Wolverine, Shadow Hawk, Griffin, Centurion
- [ ] Añadir mechs pesados: Warhammer, Marauder, Crusader, Orion
- [ ] Añadir mechs de asalto: King Crab, Stalker, Awesome, Banshee
- [ ] Variantes para cada mech (mínimo 2-3)
- [ ] Sprites únicos por chasis (o al menos por clase de peso)
- [ ] Balancear stats según TRO oficial
- [ ] Actualizar `mech_bay_manager.gd`

### 🔧 Editor de Mechs
- [ ] Escena `mech_editor.tscn`
- [ ] Selección de chasis base
- [ ] Sistema de slots por localización
- [ ] Catálogo de armas/equipamiento
- [ ] Validación de reglas de construcción:
  - [ ] Límite de tonelaje
  - [ ] Slots críticos por localización
  - [ ] Engine rating mínimo
  - [ ] Heat sinks requeridos
- [ ] Cálculo automático de BV (Battle Value)
- [ ] Guardar/cargar configuraciones custom
- [ ] Compartir builds (código/hash)

---

## 🔊 FASE 3 - AUDIO (Prioridad Media)

### 🎵 Música por Fase
- [ ] Track para menú principal (épico, orquestal)
- [ ] Track para mech bay (industrial, tranquilo)
- [ ] Track para fase de despliegue (tensión creciente)
- [ ] Track para fase de movimiento (estratégico)
- [ ] Track para fase de combate (intenso, percusión)
- [ ] Track para victoria (triunfante)
- [ ] Track para derrota (sombrío)
- [ ] Transiciones suaves entre tracks
- [ ] Actualizar `audio_manager.gd` con nuevos tracks

### 🔉 Efectos de Sonido
- [ ] **Armas**:
  - [ ] Láser (zap energético)
  - [ ] PPC (carga + descarga)
  - [ ] Autocannon (ráfaga metálica)
  - [ ] LRM/SRM (silbido + explosiones)
  - [ ] Machine Gun (rat-tat-tat)
  - [ ] Flamer (rugido de fuego)
- [ ] **Mech**:
  - [ ] Pasos pesados (según tonelaje)
  - [ ] Servos al girar
  - [ ] Reactor al arrancar
  - [ ] Jump jets (propulsión)
- [ ] **Ambiente**:
  - [ ] Impacto en terreno (tierra, agua, metal)
  - [ ] Explosión de mech destruido
  - [ ] Alarma de calor crítico
- [ ] **UI**:
  - [ ] Hover sobre botones
  - [ ] Confirmación de acción
  - [ ] Error/acción inválida
  - [ ] Notificación de turno

---

## 🌐 FASE 4 - MULTIJUGADOR AVANZADO (Prioridad Media)

### 🎯 Matchmaking
- [ ] Cola de búsqueda de partida
- [ ] Emparejamiento por BV total del lance
- [ ] Emparejamiento por ELO (si existe ranking)
- [ ] Tiempo máximo de espera → bots
- [ ] Preferencias de mapa/modo
- [ ] UI de búsqueda con animación
- [ ] Cancelar búsqueda

### 🏆 Ranking / ELO
- [ ] Implementar sistema ELO básico
- [ ] Rating inicial: 1000
- [ ] Ganancia/pérdida basada en diferencia de rating
- [ ] Tabla de clasificación global
- [ ] Divisiones/ligas (Bronce, Plata, Oro, etc.)
- [ ] Temporadas con reset parcial
- [ ] Recompensas por liga al final de temporada
- [ ] Persistencia en servidor

### 🏅 Torneos
- [ ] Sistema de inscripción a torneos
- [ ] Brackets eliminatorios (8, 16, 32 jugadores)
- [ ] Horarios programados
- [ ] Lobby de torneo con estado de bracket
- [ ] Premios/recompensas por posición
- [ ] Historial de torneos

### 💬 Emotes / Quick Chat
- [ ] Rueda de emotes (8 opciones)
- [ ] Mensajes predefinidos:
  - [ ] "GG" / "Bien jugado"
  - [ ] "Buena suerte"
  - [ ] "Un momento"
  - [ ] "Listo"
  - [ ] "¡Buen disparo!"
  - [ ] "Oops"
- [ ] Cooldown anti-spam (5 segundos)
- [ ] Opción de silenciar oponente
- [ ] Animación/sonido al recibir emote

---

## ⚙️ FASE 5 - CALIDAD DE VIDA (Prioridad Media-Baja)

### ⏭️ Auto-Skip
- [ ] Detectar mechs sin acciones válidas en fase actual
- [ ] Movimiento: 0 MP o completamente rodeado
- [ ] Ataque: Sin enemigos en rango o sin armas funcionales
- [ ] Físico: Sin enemigos adyacentes
- [ ] Mostrar notificación breve "X skipped - no actions"
- [ ] Opción en settings para activar/desactivar
- [ ] No aplicar a mechs del jugador sin confirmación

### 📊 Estadísticas
- [ ] Crear `stats_manager.gd` (autoload)
- [ ] Trackear por jugador:
  - [ ] Partidas jugadas/ganadas/perdidas
  - [ ] Daño total causado/recibido
  - [ ] Mechs destruidos
  - [ ] Mech más usado
  - [ ] Arma con más kills
  - [ ] Mejor racha de victorias
- [ ] Persistir en user://stats.json
- [ ] UI de estadísticas en menú principal
- [ ] Logros/achievements basados en stats

---

## 🔧 FASE 6 - OPTIMIZACIÓN (Prioridad Baja)

### 💾 Caché de Cálculos
- [ ] Cachear paths de movimiento por mech
- [ ] Invalidar caché solo cuando cambia estado relevante
- [ ] Cachear cálculos de LOS entre pares de hexes
- [ ] Cachear modificadores de terreno
- [ ] Implementar dirty flags para regenerar caché
- [ ] Medir impacto en FPS/tiempo de respuesta

### 🖼️ LOD para Sprites
- [ ] Crear sprites de baja resolución (32x32)
- [ ] Crear sprites de media resolución (64x64)
- [ ] Mantener alta resolución actual (128x128+)
- [ ] Cambiar según nivel de zoom de cámara
- [ ] Transición suave entre LODs
- [ ] Ocultar detalles UI a zoom muy alejado

### ♻️ Pool de Objetos
- [ ] Crear `object_pool.gd` genérico
- [ ] Pool para partículas de impacto
- [ ] Pool para proyectiles/efectos de disparo
- [ ] Pool para indicadores de daño flotante
- [ ] Pool para marcadores de hex overlay
- [ ] Pre-instanciar en _ready(), reutilizar en runtime
- [ ] Métricas de uso de pool (debug)

---

## 📝 NOTAS

### Dependencias entre tareas
- **Animaciones de disparo** requiere → Pool de objetos (para rendimiento)
- **Modos de juego** requiere → Campañas (comparten sistema de objetivos)
- **Ranking/ELO** requiere → Matchmaking (para partidas rankeadas)
- **Editor de mechs** requiere → Más mechs (para tener contenido que editar)

### Recursos externos necesarios
- Assets de audio (música y SFX) - Buscar en OpenGameArt, Freesound
- Sprites adicionales de mechs - Crear o encargar
- Iconos de UI para emotes - Diseñar

### Testing requerido
- [ ] Tutorial: Probar con usuario nuevo
- [ ] Multijugador: Test de carga con múltiples conexiones
- [ ] Optimización: Profiling en dispositivos móviles reales

---

## ✅ COMPLETADO

### Noviembre 2025
- [x] Sistema de audio base (AudioManager)
- [x] Música en menús y batalla
- [x] Click sounds en botones
- [x] Panel de opciones con volumen
- [x] Tinte de color por equipo (azul/rojo)
- [x] Mechs destruidos tachados en iniciativa
- [x] Overlay de LOS
- [x] Corrección pinch zoom
- [x] Overlays desactivados por defecto

---

*Última revisión: 28/11/2025*
