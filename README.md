# Steel Titans: Tactical Warfare

Un juego táctico competitivo de combate de mechs (Steel Titans) para móvil.

> **Nota de desarrollo:** Este proyecto fue originalmente prototipado como "Battletech Mobile" y está siendo migrado a una IP original para cumplir con requisitos legales de publicación comercial.

## 🎮 Sobre el Juego

**Steel Titans** es un juego de combate táctico por turnos con mechs gigantes para dispositivos móviles. Ofrece:

- **Combate PvP competitivo** (1v1, 2v2, 4v4)
- **Partidas rápidas** de 10-15 minutos
- **Personalización profunda** de mechs
- **Sistema de ranking** con ELO y temporadas
- **Modelo justo**: Compra única, sin pay-to-win

## 📊 Estado del Proyecto

**Fase:** Pre-Alpha  
**Versión:** 0.1.0  

### Características Implementadas ✅

- [x] Sistema de combate por turnos (fiel a reglas clásicas)
- [x] Grid hexagonal con pathfinding
- [x] Sistema de Line of Sight (LoS) y cobertura
- [x] Sistema de calor y disipación
- [x] Daño por localizaciones (cabeza, torsos, brazos, piernas)
- [x] Sistema de críticos y destrucción de componentes
- [x] Multijugador básico (servidor dedicado)
- [x] Editor de loadout
- [x] Generación procedural de mapas
- [x] UI táctil para móvil

### En Desarrollo 🔄

- [ ] Sistema de niveles y progresión
- [ ] Sistema de cuentas y autenticación
- [ ] Matchmaking con ELO
- [ ] Tutorial interactivo
- [ ] Arte y audio profesional

## 📁 Estructura del Proyecto

```
scripts/
├── core/                    # Sistemas centrales
│   ├── combat/             # Resolución de combate
│   ├── movement/           # Sistema de movimiento
│   └── terrain/            # Tipos de terreno
├── entities/               # Mechs y unidades
├── managers/               # Gestores globales
├── network/                # Networking y multijugador
├── ui/                     # Interfaz de usuario
└── utils/                  # Utilidades

scenes/                     # Escenas de Godot
assets/                     # Recursos (sprites, audio, etc.)
doc/                        # Documentación
tests/                      # Tests unitarios
server/                     # Configuración del servidor
```

## 📚 Documentación

- [GDD (Game Design Document)](doc/GDD.md) - Diseño completo del juego
- [ROADMAP](doc/ROADMAP.md) - Plan de desarrollo
- [TODO Producción](doc/TODO_PRODUCTION.md) - Tareas pendientes
- [Arquitectura](doc/ARCHITECTURE.md) - Arquitectura técnica

## 🚀 Cómo Ejecutar

### Requisitos
- Godot 4.5.1 o superior
- (Opcional) Android SDK para builds móviles

### Desarrollo Local
```bash
# Clonar repositorio
git clone https://github.com/DAMSanti/Battletech.git
cd Battletech

# Abrir en Godot
# File -> Open Project -> Seleccionar carpeta
```

### Servidor Dedicado
```bash
# Exportar pack del servidor
godot --headless --export-pack "Linux Server" exports/steeltitans.pck

# Ejecutar en servidor
./Godot_v4.5.1-stable_linux.x86_64 --main-pack steeltitans.pck --headless
```

## 🎯 Controles

| Acción | Control |
|--------|---------|
| Mover cámara | Arrastrar |
| Zoom | Pinch / Scroll |
| Seleccionar | Tap / Click |
| Info detallada | Tap largo |

## 🛠️ Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| Motor | Godot 4.5.1 |
| Lenguaje | GDScript |
| Networking | ENet (UDP) |
| Servidor | Linux (DigitalOcean) |
| CI/CD | GitHub Actions (próximamente) |

## 📄 Licencia

Este proyecto está en desarrollo privado. Todos los derechos reservados.

**Steel Titans** es una IP original. Cualquier similitud con otras propiedades intelectuales es coincidencia o inspiración del género.

---

*Desarrollado por DAMSanti - 2025*
