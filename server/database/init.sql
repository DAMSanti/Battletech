-- ═══════════════════════════════════════════════════════════════════════════
-- Steel Titans: Tactical Warfare
-- PostgreSQL Database Initialization Script
-- Version: 1.0.0
-- ═══════════════════════════════════════════════════════════════════════════

-- Crear la base de datos (ejecutar como superuser)
-- CREATE DATABASE steeltitans;

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLA: users
-- Usuarios del sistema
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS users (
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

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_provider ON users(auth_provider, provider_id);
CREATE INDEX IF NOT EXISTS idx_users_elo ON users(elo_rating DESC);

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLA: sessions
-- Sesiones activas de usuarios
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS sessions (
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

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLA: pilots
-- Pilotos de cada usuario
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS pilots (
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

CREATE INDEX IF NOT EXISTS idx_pilots_user ON pilots(user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLA: mechs
-- Mechs en el hangar del usuario
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS mechs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pilot_id        UUID REFERENCES pilots(id) ON DELETE SET NULL,
    
    -- Identificación
    variant_id      VARCHAR(50) NOT NULL,
    custom_name     VARCHAR(100),
    
    -- Estado actual (JSONB para flexibilidad)
    armor_state     JSONB NOT NULL,
    structure_state JSONB,
    critical_damage JSONB DEFAULT '[]',
    
    -- Configuración
    loadout         JSONB,
    
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

CREATE INDEX IF NOT EXISTS idx_mechs_user ON mechs(user_id);
CREATE INDEX IF NOT EXISTS idx_mechs_variant ON mechs(variant_id);
CREATE INDEX IF NOT EXISTS idx_mechs_available ON mechs(user_id, is_available);

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLA: matches
-- Historial de partidas
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS matches (
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

CREATE INDEX IF NOT EXISTS idx_matches_status ON matches(status);
CREATE INDEX IF NOT EXISTS idx_matches_created ON matches(created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLA: match_players
-- Jugadores en cada partida
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS match_players (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id        UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Equipo
    team            INTEGER NOT NULL,
    slot            INTEGER DEFAULT 0,
    
    -- Resultado
    result          VARCHAR(20),
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

CREATE INDEX IF NOT EXISTS idx_match_players_match ON match_players(match_id);
CREATE INDEX IF NOT EXISTS idx_match_players_user ON match_players(user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLA: transactions
-- Historial de transacciones de moneda
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS transactions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Tipo de transacción
    type            VARCHAR(50) NOT NULL,
    
    -- Moneda
    currency        VARCHAR(20) NOT NULL,
    amount          BIGINT NOT NULL,
    balance_after   BIGINT NOT NULL,
    
    -- Referencia
    reference_type  VARCHAR(50),
    reference_id    UUID,
    
    -- Descripción
    description     TEXT,
    metadata        JSONB DEFAULT '{}',
    
    -- Timestamp
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT valid_currency CHECK (currency IN ('c_bills', 'premium')),
    CONSTRAINT valid_type CHECK (type IN ('match_reward', 'repair', 'purchase', 'sale', 'admin', 'bonus', 'refund'))
);

CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);

-- ═══════════════════════════════════════════════════════════════════════════
-- FUNCIONES Y TRIGGERS
-- ═══════════════════════════════════════════════════════════════════════════

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers para updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_pilots_updated_at ON pilots;
CREATE TRIGGER update_pilots_updated_at
    BEFORE UPDATE ON pilots
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_mechs_updated_at ON mechs;
CREATE TRIGGER update_mechs_updated_at
    BEFORE UPDATE ON mechs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Función para calcular cambio de ELO
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
    loser_change := -ROUND(k_factor * expected_loser);
    
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Función para limpiar sesiones expiradas
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM sessions WHERE expires_at < NOW();
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════
-- DATOS INICIALES
-- ═══════════════════════════════════════════════════════════════════════════

-- Usuario de sistema (para transacciones automáticas)
INSERT INTO users (id, username, display_name, auth_provider, elo_rating, c_bills) 
VALUES ('00000000-0000-0000-0000-000000000000', 'system', 'System', 'credentials', 0, 0)
ON CONFLICT (username) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════
-- VISTAS ÚTILES
-- ═══════════════════════════════════════════════════════════════════════════

-- Vista de ranking de jugadores
CREATE OR REPLACE VIEW v_player_rankings AS
SELECT 
    u.id,
    u.username,
    u.display_name,
    u.elo_rating,
    u.house,
    COALESCE(stats.matches_played, 0) as matches_played,
    COALESCE(stats.wins, 0) as wins,
    COALESCE(stats.losses, 0) as losses,
    CASE WHEN COALESCE(stats.matches_played, 0) > 0 
         THEN ROUND(COALESCE(stats.wins, 0)::numeric / stats.matches_played * 100, 1)
         ELSE 0 
    END as win_rate
FROM users u
LEFT JOIN (
    SELECT 
        user_id,
        COUNT(*) as matches_played,
        SUM(CASE WHEN result = 'win' THEN 1 ELSE 0 END) as wins,
        SUM(CASE WHEN result = 'loss' THEN 1 ELSE 0 END) as losses
    FROM match_players
    GROUP BY user_id
) stats ON u.id = stats.user_id
WHERE u.is_active = true AND u.username != 'system'
ORDER BY u.elo_rating DESC;

-- Vista de estadísticas de usuario
CREATE OR REPLACE VIEW v_user_stats AS
SELECT 
    u.id as user_id,
    u.username,
    u.elo_rating,
    u.c_bills,
    COUNT(DISTINCT m.id) as total_mechs,
    COUNT(DISTINCT p.id) as total_pilots,
    COALESCE(SUM(m.kills), 0) as total_kills,
    COALESCE(SUM(m.battles_fought), 0) as total_battles
FROM users u
LEFT JOIN mechs m ON u.id = m.user_id
LEFT JOIN pilots p ON u.id = p.user_id
WHERE u.username != 'system'
GROUP BY u.id, u.username, u.elo_rating, u.c_bills;

-- ═══════════════════════════════════════════════════════════════════════════
-- FIN DEL SCRIPT
-- ═══════════════════════════════════════════════════════════════════════════

-- Verificar que todo se creó correctamente
DO $$
BEGIN
    RAISE NOTICE '✅ Database schema created successfully!';
    RAISE NOTICE 'Tables: users, sessions, pilots, mechs, matches, match_players, transactions';
    RAISE NOTICE 'Views: v_player_rankings, v_user_stats';
    RAISE NOTICE 'Functions: update_updated_at_column, calculate_elo_change, cleanup_expired_sessions';
END $$;
