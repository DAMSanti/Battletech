-- Migration: Create bans table
-- Date: 2025-12-01
-- Description: Add bans table for user suspension management

CREATE TABLE IF NOT EXISTS bans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Ban details
    ban_type VARCHAR(20) NOT NULL DEFAULT 'temporary',
    reason VARCHAR(50) NOT NULL,
    description TEXT,
    
    -- Evidence
    evidence JSONB,
    
    -- Duration
    banned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,  -- NULL = permanent
    
    -- Admin info
    banned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    banned_by_system BOOLEAN DEFAULT FALSE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    revoked_by UUID REFERENCES users(id) ON DELETE SET NULL,
    revoke_reason TEXT,
    
    -- IP/Device tracking
    ip_address INET,
    device_id VARCHAR(255),
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_ban_type CHECK (ban_type IN ('temporary', 'permanent', 'shadow')),
    CONSTRAINT valid_ban_reason CHECK (reason IN ('cheating', 'toxicity', 'exploiting', 'harassment', 'spam', 'fraud', 'tos_violation', 'other'))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_bans_user ON bans(user_id);
CREATE INDEX IF NOT EXISTS idx_bans_active ON bans(is_active);
CREATE INDEX IF NOT EXISTS idx_bans_expires ON bans(expires_at);
CREATE INDEX IF NOT EXISTS idx_bans_ip ON bans(ip_address);
CREATE INDEX IF NOT EXISTS idx_bans_device ON bans(device_id);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_bans_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS bans_updated_at ON bans;
CREATE TRIGGER bans_updated_at
    BEFORE UPDATE ON bans
    FOR EACH ROW
    EXECUTE FUNCTION update_bans_updated_at();

-- Comment
COMMENT ON TABLE bans IS 'User bans and suspensions with full history';
