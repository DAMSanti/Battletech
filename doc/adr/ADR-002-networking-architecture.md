# ADR-002: Arquitectura de Red Cliente-Servidor

## Estado
✅ Aceptada

## Fecha
2025-11-29

## Contexto

Steel Titans es un juego de combate táctico por turnos con modos multijugador:
- **PvP 1v1**: Duelos directos
- **PvP 2v2**: Equipos pequeños
- **PvP 4v4**: Batallas grandes

Necesitábamos decidir la arquitectura de red para:
1. Prevenir cheating en partidas competitivas
2. Manejar desconexiones/reconexiones
3. Soportar múltiples partidas simultáneas
4. Escalar con la base de jugadores

## Decisión

Implementar una arquitectura **Cliente-Servidor Autoritativa** usando Godot High-Level Multiplayer con un servidor dedicado.

### Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    SERVIDOR DEDICADO                        │
│                 (DigitalOcean Droplet)                      │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Match 1    │  │  Match 2    │  │  Match N    │         │
│  │  (2 players)│  │  (4 players)│  │  (8 players)│         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              GAME STATE (Authoritative)              │   │
│  │  - Posiciones de mechs                               │   │
│  │  - Estado de combate                                 │   │
│  │  - Validación de acciones                            │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          │
           ┌──────────────┼──────────────┐
           │              │              │
           ▼              ▼              ▼
      ┌─────────┐   ┌─────────┐   ┌─────────┐
      │ Cliente │   │ Cliente │   │ Cliente │
      │ Android │   │ Android │   │ Android │
      │         │   │         │   │         │
      │ - Input │   │ - Input │   │ - Input │
      │ - Render│   │ - Render│   │ - Render│
      │ - Audio │   │ - Audio │   │ - Audio │
      └─────────┘   └─────────┘   └─────────┘
```

### Flujo de Comunicación

```
CLIENTE                           SERVIDOR
   │                                  │
   │  request_move(mech_id, hex)      │
   │ ─────────────────────────────────>│
   │                                  │ Validar:
   │                                  │ - Es turno del jugador?
   │                                  │ - Mech pertenece al jugador?
   │                                  │ - Hex es válido?
   │                                  │ - Tiene MP suficientes?
   │                                  │
   │  broadcast_move(mech_id, hex)    │
   │ <─────────────────────────────────│
   │                                  │
   │  (Actualizar estado local)       │
```

### Validación Server-Side

**TODO** lo que viene del cliente se valida:

```gdscript
# Ejemplo de validación de movimiento
func _validate_move(sender_id: int, mech_id: int, target: Vector2i) -> bool:
    # 1. El mech existe?
    var mech = get_mech_by_id(mech_id)
    if not mech: return false
    
    # 2. El mech pertenece al jugador que envió la request?
    if mech.owner_id != sender_id: return false
    
    # 3. Es el turno de ese jugador?
    if current_turn_player != sender_id: return false
    
    # 4. El hex es alcanzable con los MP disponibles?
    var cost = calculate_path_cost(mech.position, target)
    if cost > mech.movement_points: return false
    
    # 5. El hex no está ocupado?
    if is_hex_occupied(target): return false
    
    return true
```

### Tecnología

- **Godot High-Level Multiplayer API**: ENet bajo el capó
- **WebSocket** para conexión desde navegadores (futuro)
- **Puerto**: 7777 (configurable)
- **Protocolo**: Reliable para acciones, Unreliable para animaciones

## Consecuencias

### Positivas
- ✅ **Anti-cheat inherente**: Clientes no pueden modificar estado del juego
- ✅ **Consistencia**: Todos los clientes ven el mismo estado
- ✅ **Escalabilidad**: Un servidor puede manejar múltiples partidas
- ✅ **Reconexión**: Estado se mantiene en servidor, cliente puede reconectar

### Negativas
- ⚠️ **Latencia**: Toda acción debe ir al servidor y volver
- ⚠️ **Costo**: Requiere servidor dedicado (aunque mínimo para juego por turnos)
- ⚠️ **Single Point of Failure**: Si el servidor cae, todos se desconectan

### Mitigaciones
- Latencia es aceptable en juego por turnos (no es tiempo real)
- Servidor en DigitalOcean es económico (~$6/mes básico)
- Backup y restore automatizado del servidor

## Alternativas Consideradas

### Alternativa 1: Peer-to-Peer (P2P)
- Cada cliente se conecta directamente a los demás
- **Rechazada**: 
  - Vulnerable a cheating (cada cliente tiene el estado completo)
  - Problemas de NAT traversal en móviles
  - Difícil manejar desconexiones

### Alternativa 2: Host Migrating (un cliente es servidor)
- Un jugador actúa como servidor, si se desconecta otro toma el rol
- **Rechazada**:
  - El host tiene ventaja (0 latencia)
  - Complejidad de migración
  - El host puede hacer trampa

### Alternativa 3: Lockstep Determinístico
- Cada cliente ejecuta las mismas acciones, resultado idéntico
- **Rechazada**:
  - Muy complejo de implementar correctamente
  - Cualquier desync arruina la partida
  - No hay forma de reconectar (estado no se guarda)

## Referencias

- [Godot High-Level Multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [Server deployment](../server/Dockerfile)
- [Network Manager](../../scripts/network/network_manager.gd)
