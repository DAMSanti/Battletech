# 🌐 REST API Documentation
## Steel Titans API v1

**Base URL:** `https://steeltitans.damsanti.app/api/v1`  
**Autenticación:** Bearer Token (JWT)  
**Content-Type:** `application/json`

---

## 📑 Índice

1. [Autenticación](#autenticación)
2. [Usuarios](#usuarios)
3. [Mechs](#mechs)
4. [Pilotos](#pilotos)
5. [Matchmaking](#matchmaking)
6. [ELO y Rankings](#elo-y-rankings)
7. [Estadísticas](#estadísticas)
8. [Bans (Admin)](#bans-admin)
9. [Audit Logs (Admin)](#audit-logs-admin)
10. [Health Checks](#health-checks)
11. [Códigos de Error](#códigos-de-error)

---

## 🔐 Autenticación

### Headers Requeridos

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

### POST /auth/register

Registra un nuevo usuario.

**Request:**
```json
{
  "username": "player1",
  "email": "player1@example.com",
  "password": "securepass123",
  "display_name": "Player One"
}
```

**Response (201):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "expires_in": 900,
  "user": {
    "id": "uuid",
    "username": "player1",
    "display_name": "Player One",
    "elo_rating": 1000,
    "c_bills": 50000
  }
}
```

### POST /auth/login

Inicia sesión con credenciales.

**Request:**
```json
{
  "username": "player1",
  "password": "securepass123",
  "device_type": "android",
  "device_id": "optional-device-uuid"
}
```

**Response (200):** Igual que registro.

### POST /auth/guest

Inicia sesión como invitado.

**Request:**
```json
{
  "device_id": "device-uuid-123"
}
```

**Response (200):**
```json
{
  "access_token": "...",
  "refresh_token": "...",
  "expires_in": 900,
  "user": {
    "id": "uuid",
    "username": "guest_abc123",
    "display_name": "Guest",
    "is_guest": true,
    "elo_rating": 1000
  }
}
```

### POST /auth/refresh

Renueva el access token.

**Request:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

**Response (200):**
```json
{
  "access_token": "new-access-token",
  "refresh_token": "new-refresh-token",
  "expires_in": 900
}
```

### POST /auth/logout

Cierra la sesión actual.

**Headers:** Authorization requerido

**Response (200):**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

## 👤 Usuarios

### GET /users/me

Obtiene datos del usuario autenticado.

**Response (200):**
```json
{
  "id": "uuid",
  "username": "player1",
  "email": "player1@example.com",
  "display_name": "Player One",
  "elo_rating": 1250,
  "c_bills": 75000,
  "premium_currency": 0,
  "created_at": "2025-12-01T10:00:00Z",
  "last_login": "2025-12-01T15:30:00Z",
  "stats": {
    "matches_played": 42,
    "wins": 25,
    "losses": 17,
    "win_rate": 59.5
  }
}
```

### PUT /users/me

Actualiza perfil del usuario.

**Request:**
```json
{
  "display_name": "New Name",
  "avatar_id": 5
}
```

### GET /users/{user_id}

Obtiene perfil público de otro usuario.

---

## 🤖 Mechs

### GET /mechs

Lista mechs del usuario autenticado.

**Response (200):**
```json
{
  "mechs": [
    {
      "id": "uuid",
      "variant_id": "atlas-as7d",
      "custom_name": "My Atlas",
      "tonnage": 100,
      "armor_state": {...},
      "loadout": {...},
      "created_at": "2025-12-01T10:00:00Z"
    }
  ],
  "total": 5
}
```

### POST /mechs

Crea/compra un nuevo mech.

**Request:**
```json
{
  "variant_id": "madcat-prime",
  "custom_name": "Timber Wolf"
}
```

### GET /mechs/{mech_id}

Obtiene detalles de un mech específico.

### PUT /mechs/{mech_id}

Actualiza configuración de un mech.

### DELETE /mechs/{mech_id}

Vende/elimina un mech.

---

## 👨‍✈️ Pilotos

### GET /pilots

Lista pilotos del usuario.

### POST /pilots

Crea un nuevo piloto.

**Request:**
```json
{
  "name": "John Smith",
  "callsign": "Reaper"
}
```

### GET /pilots/{pilot_id}

Detalles de un piloto.

### PUT /pilots/{pilot_id}

Actualiza piloto (skills, etc).

---

## 🎮 Matchmaking

### POST /queue/join

Une al usuario a la cola de matchmaking.

**Request:**
```json
{
  "game_mode": "1v1",
  "lance_ids": ["mech-uuid-1", "mech-uuid-2"]
}
```

**Response (200):**
```json
{
  "success": true,
  "queue_position": 3,
  "estimated_wait_seconds": 30,
  "game_mode": "1v1"
}
```

### POST /queue/leave

Abandona la cola.

**Response (200):**
```json
{
  "success": true,
  "message": "Left queue"
}
```

### GET /queue/status

Estado actual en la cola.

**Response (200):**
```json
{
  "in_queue": true,
  "game_mode": "1v1",
  "queue_position": 2,
  "time_in_queue": 45,
  "estimated_wait": 15
}
```

### GET /queue/check-match

Verifica si se encontró una partida.

**Response (200) - Sin match:**
```json
{
  "match_found": false
}
```

**Response (200) - Match encontrado:**
```json
{
  "match_found": true,
  "match_id": "match-uuid",
  "opponent": {
    "id": "opponent-uuid",
    "username": "opponent1",
    "display_name": "Opponent",
    "elo_rating": 1180
  },
  "server_ip": "159.65.94.179",
  "server_port": 7777,
  "expires_in": 30
}
```

### POST /queue/accept

Acepta la partida encontrada.

**Request:**
```json
{
  "match_id": "match-uuid"
}
```

### POST /queue/decline

Rechaza la partida.

---

## 📊 ELO y Rankings

### GET /elo/rating/{user_id}

Rating de un usuario.

**Response (200):**
```json
{
  "user_id": "uuid",
  "elo_rating": 1250,
  "rank": "Silver",
  "rank_icon": "🥈",
  "percentile": 65.5
}
```

### GET /elo/leaderboard

Top jugadores.

**Query params:**
- `limit` (default: 100)
- `offset` (default: 0)
- `game_mode` (optional)

**Response (200):**
```json
{
  "leaderboard": [
    {
      "rank": 1,
      "user_id": "uuid",
      "username": "topplayer",
      "display_name": "Top Player",
      "elo_rating": 2150,
      "wins": 150,
      "losses": 30
    }
  ],
  "total": 1000
}
```

### POST /elo/report-match

Reporta resultado de partida (solo servidor).

**Request:**
```json
{
  "match_id": "match-uuid",
  "winner_id": "user-uuid",
  "loser_id": "user-uuid",
  "game_mode": "1v1",
  "duration_seconds": 720
}
```

---

## 📈 Estadísticas

### GET /stats/me

Estadísticas del usuario actual.

**Response (200):**
```json
{
  "matches": {
    "total": 100,
    "wins": 60,
    "losses": 40,
    "win_rate": 60.0
  },
  "combat": {
    "total_damage_dealt": 125000,
    "total_damage_taken": 98000,
    "mechs_destroyed": 85,
    "mechs_lost": 42
  },
  "favorite_mech": {
    "variant_id": "madcat-prime",
    "games_played": 45,
    "win_rate": 65.0
  },
  "streaks": {
    "current_win_streak": 3,
    "best_win_streak": 12
  }
}
```

### GET /stats/global

Estadísticas globales del juego.

---

## 🚫 Bans (Admin)

> ⚠️ Todos los endpoints de bans requieren permisos de administrador.

### GET /bans/check

Verifica si el usuario actual está baneado.

**Response (200):**
```json
{
  "is_banned": true,
  "ban_type": "temporary",
  "reason": "Toxic behavior",
  "expires_at": "2025-12-15T00:00:00Z",
  "description": "Insultos repetidos en chat"
}
```

### POST /bans

Crea un nuevo ban (admin).

**Request:**
```json
{
  "user_id": "uuid",
  "ban_type": "temporary",
  "reason": "Cheating",
  "description": "Uso de hacks de velocidad",
  "duration_days": 7
}
```

**Ban Types:**
| Tipo | Descripción |
|------|-------------|
| `temporary` | Ban temporal (requiere duration_days) |
| `permanent` | Ban permanente |
| `chat` | Solo ban de chat |
| `ranked` | Prohibido jugar ranked |

**Response (201):**
```json
{
  "id": "ban-uuid",
  "user_id": "uuid",
  "admin_id": "admin-uuid",
  "ban_type": "temporary",
  "reason": "Cheating",
  "description": "Uso de hacks de velocidad",
  "banned_at": "2025-12-01T16:00:00Z",
  "expires_at": "2025-12-08T16:00:00Z",
  "is_active": true
}
```

### GET /bans/user/{user_id}

Historial de bans de un usuario (admin).

**Response (200):**
```json
{
  "user_id": "uuid",
  "username": "player1",
  "bans": [
    {
      "id": "ban-uuid",
      "ban_type": "temporary",
      "reason": "Cheating",
      "banned_at": "2025-12-01T16:00:00Z",
      "expires_at": "2025-12-08T16:00:00Z",
      "is_active": true,
      "admin_username": "admin1"
    }
  ],
  "total_bans": 1,
  "active_ban": true
}
```

### POST /bans/{ban_id}/revoke

Revoca un ban activo (admin).

**Request:**
```json
{
  "revoke_reason": "Appeal accepted"
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "Ban revoked successfully",
  "ban_id": "ban-uuid"
}
```

### GET /bans/active

Lista todos los bans activos (admin).

**Query params:**
- `ban_type` (optional): Filtrar por tipo
- `limit` (default: 50)
- `offset` (default: 0)

---

## 📜 Audit Logs (Admin)

> ⚠️ Todos los endpoints de audit requieren permisos de administrador.

### GET /audit

Lista logs de auditoría con filtros.

**Query params:**
- `action` - Tipo de acción (ej: "auth.login", "ban.create")
- `severity` - debug, info, warning, error, critical
- `user_id` - UUID del usuario que realizó la acción
- `target_type` - Tipo de objetivo (user, mech, match)
- `target_id` - ID del objetivo
- `success` - true/false
- `ip_address` - Filtrar por IP
- `start_date` - Desde fecha (ISO 8601)
- `end_date` - Hasta fecha (ISO 8601)
- `limit` (default: 50, max: 500)
- `offset` (default: 0)

**Response (200):**
```json
[
  {
    "id": "uuid",
    "action": "auth.login",
    "severity": "info",
    "description": "User logged in successfully",
    "user_id": "uuid",
    "username": "player1",
    "target_type": null,
    "target_id": null,
    "ip_address": "192.168.1.1",
    "endpoint": "/api/v1/auth/login",
    "method": "POST",
    "success": true,
    "error_message": null,
    "created_at": "2025-12-01T16:00:00Z"
  }
]
```

### GET /audit/actions

Lista todos los tipos de acciones disponibles.

**Response (200):**
```json
[
  "auth.login",
  "auth.logout",
  "auth.register",
  "auth.refresh",
  "user.update",
  "ban.create",
  "ban.revoke",
  "match.start",
  "match.end",
  "elo.update"
]
```

### GET /audit/stats

Estadísticas de logs de auditoría.

**Response (200):**
```json
{
  "total_entries": 15000,
  "entries_today": 250,
  "entries_this_week": 1500,
  "failed_actions": 45,
  "by_severity": {
    "info": 12000,
    "warning": 2500,
    "error": 450,
    "critical": 50
  },
  "by_action_category": {
    "auth": 5000,
    "user": 3000,
    "match": 4000,
    "ban": 100
  },
  "top_users": [
    {"user_id": "uuid", "username": "active_player", "action_count": 500}
  ],
  "top_ips": [
    {"ip_address": "192.168.1.1", "action_count": 200}
  ]
}
```

### GET /audit/{log_id}

Detalles completos de un log específico.

**Response (200):**
```json
{
  "id": "uuid",
  "action": "ban.create",
  "severity": "warning",
  "description": "Admin created ban for user",
  "user_id": "admin-uuid",
  "username": "admin1",
  "target_type": "user",
  "target_id": "banned-user-uuid",
  "ip_address": "192.168.1.1",
  "endpoint": "/api/v1/bans",
  "method": "POST",
  "success": true,
  "user_agent": "Mozilla/5.0...",
  "request_id": "req-uuid",
  "old_value": null,
  "new_value": {
    "ban_type": "temporary",
    "reason": "Cheating"
  },
  "extra_data": {
    "duration_days": 7
  },
  "created_at": "2025-12-01T16:00:00Z"
}
```

---

## ❤️ Health Checks

### GET /health

Health check básico.

**Response (200):**
```json
{
  "status": "healthy",
  "timestamp": "2025-12-01T16:00:00Z"
}
```

### GET /health/detailed

Health check con detalles.

**Response (200):**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "uptime_seconds": 86400,
  "database": "connected",
  "redis": "connected",
  "active_users": 150,
  "matches_in_progress": 25
}
```

### GET /health/live

Kubernetes liveness probe.

### GET /health/ready

Kubernetes readiness probe.

### GET /health/metrics

Métricas en formato Prometheus.

---

## ❌ Códigos de Error

### Estructura de Error

```json
{
  "success": false,
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": {}
}
```

### Códigos HTTP

| Código | Significado |
|--------|-------------|
| 200 | OK |
| 201 | Created |
| 400 | Bad Request - Datos inválidos |
| 401 | Unauthorized - Token inválido/expirado |
| 403 | Forbidden - Sin permisos |
| 404 | Not Found - Recurso no existe |
| 409 | Conflict - Usuario ya existe, etc |
| 422 | Validation Error |
| 429 | Too Many Requests - Rate limited |
| 500 | Internal Server Error |

### Códigos de Error Internos

| Código | Descripción |
|--------|-------------|
| `AUTH_REQUIRED` | Se requiere autenticación |
| `INVALID_CREDENTIALS` | Usuario/contraseña incorrectos |
| `USER_NOT_FOUND` | Usuario no existe |
| `USER_ALREADY_EXISTS` | Username/email ya registrado |
| `TOKEN_EXPIRED` | Token JWT expirado |
| `RATE_LIMITED` | Demasiadas solicitudes |
| `VALIDATION_ERROR` | Datos de entrada inválidos |
| `NOT_IN_QUEUE` | Usuario no está en cola |
| `MATCH_NOT_FOUND` | Partida no encontrada |
| `MATCH_EXPIRED` | Match expiró sin aceptar |

---

## 🔧 Rate Limits

| Endpoint | Límite |
|----------|--------|
| `/auth/login` | 5/minuto |
| `/auth/register` | 3/minuto |
| `/auth/guest` | 10/minuto |
| `/queue/*` | 10/minuto |
| Default | 100/minuto |

---

## 📝 Ejemplos cURL

### Login
```bash
curl -X POST https://steeltitans.damsanti.app/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "player1", "password": "pass123"}'
```

### Obtener perfil
```bash
curl https://steeltitans.damsanti.app/api/v1/users/me \
  -H "Authorization: Bearer eyJhbG..."
```

### Unirse a cola
```bash
curl -X POST https://steeltitans.damsanti.app/api/v1/queue/join \
  -H "Authorization: Bearer eyJhbG..." \
  -H "Content-Type: application/json" \
  -d '{"game_mode": "1v1"}'
```

---

## 📄 OpenAPI / Swagger

La documentación interactiva de la API está disponible en:

- **Swagger UI:** `https://steeltitans.damsanti.app/docs`
- **ReDoc:** `https://steeltitans.damsanti.app/redoc`
- **OpenAPI JSON:** `https://steeltitans.damsanti.app/openapi.json`

---

## 🔌 WebSocket Events

Para notificaciones en tiempo real del matchmaking:

**Endpoint:** `wss://steeltitans.damsanti.app/ws/matchmaking`

### Autenticación WebSocket
```json
{
  "type": "auth",
  "token": "Bearer eyJhbG..."
}
```

### Eventos del Servidor

| Evento | Descripción |
|--------|-------------|
| `queue_joined` | Confirmación de unión a cola |
| `queue_position` | Actualización de posición |
| `match_found` | Se encontró una partida |
| `match_cancelled` | Partida cancelada (oponente declinó) |

**Ejemplo match_found:**
```json
{
  "type": "match_found",
  "match_id": "match-uuid",
  "opponent": {
    "username": "opponent1",
    "elo_rating": 1200
  },
  "server": {
    "ip": "159.65.94.179",
    "port": 7777
  },
  "accept_deadline": 30
}
```

---

*Documentación actualizada: Diciembre 2025*
