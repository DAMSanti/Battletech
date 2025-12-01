# 🗄️ Database Schema - Steel Titans
## PostgreSQL Schema Design

**Versión:** 1.0  
**Fecha:** 1 de Diciembre, 2025  
**Estado:** En desarrollo

---

## 📊 Diagrama de Entidades

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         STEEL TITANS DATABASE                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐         ┌──────────────┐         ┌──────────────┐    │
│  │    users     │         │    mechs     │         │   matches    │    │
│  ├──────────────┤         ├──────────────┤         ├──────────────┤    │
│  │ id (PK)      │◄──┐     │ id (PK)      │         │ id (PK)      │    │
│  │ username     │   │     │ user_id (FK) │────┐    │ status       │    │
│  │ email        │   └─────┤ variant_id   │    │    │ created_at   │    │
│  │ password_hash│         │ custom_name  │    │    │ ended_at     │    │
│  │ display_name │         │ armor_state  │    │    │ winner_id    │    │
│  │ auth_provider│         │ damage_log   │    │    │ game_mode    │    │
│  │ elo_rating   │         │ created_at   │    │    │ map_seed     │    │
│  │ c_bills      │         └──────────────┘    │    └──────┬───────┘    │
│  │ created_at   │                             │           │            │
│  │ last_login   │                             │           │            │
│  └──────────────┘                             │           │            │
│         │                                     │           │            │
│         │         ┌──────────────┐            │    ┌──────▼───────┐    │
│         │         │   pilots     │            │    │match_players │    │
│         │         ├──────────────┤            │    ├──────────────┤    │
│         │         │ id (PK)      │            │    │ match_id(FK) │    │
│         └────────►│ user_id (FK) │            │    │ user_id (FK) │    │
│                   │ name         │            │    │ team         │    │
│                   │ callsign     │            │    │ result       │    │
│                   │ xp           │            └───►│ mechs_used   │    │
│                   │ level        │                 │ damage_dealt │    │
│                   │ skills       │                 │ elo_change   │    │
│                   │ created_at   │                 └──────────────┘    │
│                   └──────────────┘                                     │
│                                                                        │
│  ┌──────────────┐         ┌──────────────┐                            │
│  │  sessions    │         │ transactions │                            │
│  ├──────────────┤         ├──────────────┤                            │
│  │ id (PK)      │         │ id (PK)      │                            │
│  │ user_id (FK) │         │ user_id (FK) │                            │
│  │ token        │         │ type         │                            │
│  │ expires_at   │         │ amount       │                            │
│  │ device_info  │         │ item_id      │                            │
│  │ created_at   │         │ created_at   │                            │
│  └──────────────┘         └──────────────┘                            │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📝 Tablas Detalladas

### 1. users - Usuarios del sistema

```sql
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username        VARCHAR(50) UNIQUE NOT NULL,
    email           VARCHAR(255) UNIQUE,
    password_hash   VARCHAR(255),
    display_name    VARCHAR(100),
    auth_provider   VARCHAR(20) DEFAULT 'credentials',
    provider_id     VARCHAR(255),
    
    -- Progresión
    elo_rating      INTEGER DEFAULT 1000,
    c_bills         BIGINT DEFAULT 10000,
    premium_currency INTEGER DEFAULT 0,
    
    -- Casa/Facción
    house           VARCHAR(50) DEFAULT 'neutral',
    
    -- Timestamps
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Estado
    is_active       BOOLEAN DEFAULT true,
    is_banned       BOOLEAN DEFAULT false,
    ban_reason      TEXT,
    ban_until       TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT username_length CHECK (char_length(username) >= 3),
    CONSTRAINT valid_provider CHECK (auth_provider IN ('credentials', 'guest', 'google', 'apple'))
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_provider ON users(auth_provider, provider_id);
CREATE INDEX idx_users_elo ON users(elo_rating DESC);
```

### 2. sessions - Sesiones activas

```sql
CREATE TABLE sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token           VARCHAR(500) UNIQUE NOT NULL,
    refresh_token   VARCHAR(500) UNIQUE,
    
    -- Información del dispositivo
    device_type     VARCHAR(50),
    device_id       VARCHAR(255),
    ip_address      INET,
    user_agent      TEXT,
    
    -- Timestamps
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    last_activity   TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Estado
    is_valid        BOOLEAN DEFAULT true
);

CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_sessions_token ON sessions(token);
CREATE INDEX idx_sessions_expires ON sessions(expires_at);
```

### 3. pilots - Pilotos de cada usuario

```sql
CREATE TABLE pilots (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Identidad
    name            VARCHAR(100) NOT NULL,
    callsign        VARCHAR(50),
    portrait_id     VARCHAR(50) DEFAULT 'default',
    
    -- Progresión
    xp              INTEGER DEFAULT 0,
    level           INTEGER DEFAULT 1,
    
    -- Habilidades (almacenadas como JSONB)
    skills          JSONB DEFAULT '{"gunnery": 4, "piloting": 5}',
    
    -- Estado
    is_active       BOOLEAN DEFAULT true,
    is_injured      BOOLEAN DEFAULT false,
    recovery_until  TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_pilot_per_user UNIQUE (user_id, name)
);

CREATE INDEX idx_pilots_user ON pilots(user_id);
```

### 4. mechs - Mechs en el hangar del usuario

```sql
CREATE TABLE mechs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pilot_id        UUID REFERENCES pilots(id) ON DELETE SET NULL,
    
    -- Identificación
    variant_id      VARCHAR(50) NOT NULL,  -- ej: "AS7-D", "Timber Wolf Prime"
    custom_name     VARCHAR(100),
    
    -- Estado actual (JSONB para flexibilidad)
    armor_state     JSONB NOT NULL,        -- Estado del blindaje
    structure_state JSONB,                 -- Estado de estructura interna
    critical_damage JSONB DEFAULT '[]',    -- Componentes dañados
    
    -- Configuración
    loadout         JSONB,                 -- Armas y equipo personalizados
    
    -- Progresión
    kills           INTEGER DEFAULT 0,
    battles_fought  INTEGER DEFAULT 0,
    
    -- Estado
    needs_repair    BOOLEAN DEFAULT false,
    repair_cost     INTEGER DEFAULT 0,
    is_available    BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_mechs_user ON mechs(user_id);
CREATE INDEX idx_mechs_variant ON mechs(variant_id);
CREATE INDEX idx_mechs_available ON mechs(user_id, is_available);
```

### 5. matches - Historial de partidas

```sql
CREATE TABLE matches (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Configuración
    game_mode       VARCHAR(20) NOT NULL DEFAULT '1v1',
    map_id          VARCHAR(50),
    map_seed        INTEGER,
    
    -- Estado
    status          VARCHAR(20) DEFAULT 'pending',
    winner_team     INTEGER,
    
    -- Datos de la partida (JSONB para replay)
    turn_count      INTEGER DEFAULT 0,
    final_state     JSONB,
    replay_data     JSONB,
    
    -- Timestamps
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    started_at      TIMESTAMP WITH TIME ZONE,
    ended_at        TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT valid_status CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled', 'abandoned')),
    CONSTRAINT valid_game_mode CHECK (game_mode IN ('1v1', '2v2', '4v4', 'practice'))
);

CREATE INDEX idx_matches_status ON matches(status);
CREATE INDEX idx_matches_created ON matches(created_at DESC);
```

### 6. match_players - Jugadores en cada partida

```sql
CREATE TABLE match_players (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id        UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Equipo
    team            INTEGER NOT NULL,
    slot            INTEGER DEFAULT 0,
    
    -- Resultado
    result          VARCHAR(20),  -- 'win', 'loss', 'draw', 'disconnect'
    elo_before      INTEGER,
    elo_after       INTEGER,
    elo_change      INTEGER,
    
    -- Estadísticas
    mechs_used      JSONB DEFAULT '[]',
    damage_dealt    INTEGER DEFAULT 0,
    damage_taken    INTEGER DEFAULT 0,
    kills           INTEGER DEFAULT 0,
    deaths          INTEGER DEFAULT 0,
    
    -- Recompensas
    xp_earned       INTEGER DEFAULT 0,
    c_bills_earned  INTEGER DEFAULT 0,
    
    CONSTRAINT unique_player_in_match UNIQUE (match_id, user_id),
    CONSTRAINT valid_result CHECK (result IN ('win', 'loss', 'draw', 'disconnect', NULL))
);

CREATE INDEX idx_match_players_match ON match_players(match_id);
CREATE INDEX idx_match_players_user ON match_players(user_id);
```

### 7. transactions - Historial de transacciones

```sql
CREATE TABLE transactions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Tipo de transacción
    type            VARCHAR(50) NOT NULL,
    
    -- Moneda
    currency        VARCHAR(20) NOT NULL,  -- 'c_bills', 'premium'
    amount          BIGINT NOT NULL,       -- Positivo = ganancia, Negativo = gasto
    balance_after   BIGINT NOT NULL,
    
    -- Referencia
    reference_type  VARCHAR(50),           -- 'match', 'purchase', 'repair', 'reward'
    reference_id    UUID,
    
    -- Descripción
    description     TEXT,
    metadata        JSONB DEFAULT '{}',
    
    -- Timestamp
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT valid_currency CHECK (currency IN ('c_bills', 'premium')),
    CONSTRAINT valid_type CHECK (type IN ('match_reward', 'repair', 'purchase', 'sale', 'admin', 'bonus', 'refund'))
);

CREATE INDEX idx_transactions_user ON transactions(user_id);
CREATE INDEX idx_transactions_created ON transactions(created_at DESC);
CREATE INDEX idx_transactions_type ON transactions(type);
```

---

## 🔧 Funciones y Triggers

### Auto-actualización de updated_at

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pilots_updated_at
    BEFORE UPDATE ON pilots
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_mechs_updated_at
    BEFORE UPDATE ON mechs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### Función para calcular ELO

```sql
CREATE OR REPLACE FUNCTION calculate_elo_change(
    winner_elo INTEGER,
    loser_elo INTEGER,
    k_factor INTEGER DEFAULT 32
)
RETURNS TABLE(winner_change INTEGER, loser_change INTEGER) AS $$
DECLARE
    expected_winner FLOAT;
    expected_loser FLOAT;
BEGIN
    expected_winner := 1.0 / (1.0 + POWER(10, (loser_elo - winner_elo) / 400.0));
    expected_loser := 1.0 - expected_winner;
    
    winner_change := ROUND(k_factor * (1 - expected_winner));
    loser_change := -ROUND(k_factor * (0 - expected_loser));
    
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;
```

---

## 📈 Índices de Rendimiento

```sql
-- Índices para búsquedas frecuentes
CREATE INDEX idx_users_elo_ranking ON users(elo_rating DESC, username);
CREATE INDEX idx_mechs_user_available ON mechs(user_id) WHERE is_available = true;
CREATE INDEX idx_sessions_valid_user ON sessions(user_id) WHERE is_valid = true;
CREATE INDEX idx_matches_recent ON matches(created_at DESC) WHERE status = 'completed';

-- Índices parciales para limpieza
CREATE INDEX idx_sessions_expired ON sessions(expires_at) WHERE is_valid = true;
```

---

## 🔒 Permisos y Roles

```sql
-- Rol para la API
CREATE ROLE steeltitans_api WITH LOGIN PASSWORD 'CHANGE_ME_IN_PRODUCTION';

GRANT CONNECT ON DATABASE steeltitans TO steeltitans_api;
GRANT USAGE ON SCHEMA public TO steeltitans_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO steeltitans_api;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO steeltitans_api;

-- Rol de solo lectura para analytics
CREATE ROLE steeltitans_readonly WITH LOGIN PASSWORD 'CHANGE_ME_IN_PRODUCTION';
GRANT CONNECT ON DATABASE steeltitans TO steeltitans_readonly;
GRANT USAGE ON SCHEMA public TO steeltitans_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO steeltitans_readonly;
```

---

## 🎯 Datos Iniciales

```sql
-- Crear usuario de sistema (para transacciones automáticas)
INSERT INTO users (id, username, display_name, auth_provider, elo_rating) 
VALUES ('00000000-0000-0000-0000-000000000000', 'system', 'System', 'credentials', 0);
```

---

## 📋 Notas de Migración

### v1.0.0 → v1.1.0 (Futuro)
- Añadir tabla `clans` para sistema de clanes
- Añadir tabla `inventory` para items coleccionables
- Añadir columna `premium_expires_at` a users

---

*Última actualización: 1 de Diciembre, 2025*
