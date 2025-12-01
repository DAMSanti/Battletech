-- Migration: Create audit_logs table
-- Date: 2025-12-01
-- Description: Add audit_logs table for tracking important actions

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Action info
    action VARCHAR(100) NOT NULL,
    severity VARCHAR(20) DEFAULT 'info',
    description TEXT,
    
    -- Actor (who performed the action)
    user_id UUID,
    username VARCHAR(50),
    
    -- Target (what was affected)
    target_type VARCHAR(50),
    target_id VARCHAR(100),
    
    -- Request context
    ip_address INET,
    user_agent TEXT,
    request_id VARCHAR(100),
    endpoint VARCHAR(200),
    method VARCHAR(10),
    
    -- Additional data
    old_value JSONB,
    new_value JSONB,
    extra_data JSONB,
    
    -- Result
    success BOOLEAN DEFAULT TRUE,
    error_message TEXT,
    
    -- Timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_target ON audit_logs(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_audit_severity ON audit_logs(severity);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_ip ON audit_logs(ip_address);
CREATE INDEX IF NOT EXISTS idx_audit_success ON audit_logs(success);

-- Partial index for failed actions (commonly queried)
CREATE INDEX IF NOT EXISTS idx_audit_failures ON audit_logs(created_at DESC) 
    WHERE success = FALSE;

-- Partial index for security events
CREATE INDEX IF NOT EXISTS idx_audit_security ON audit_logs(created_at DESC)
    WHERE action LIKE 'security.%';

-- Comments
COMMENT ON TABLE audit_logs IS 'Audit trail for important system actions';
COMMENT ON COLUMN audit_logs.action IS 'Action type (e.g., auth.login, ban.create)';
COMMENT ON COLUMN audit_logs.severity IS 'Severity level: debug, info, warning, error, critical';
COMMENT ON COLUMN audit_logs.target_type IS 'Type of affected resource: user, mech, match, etc.';

-- Function to auto-cleanup old audit logs (keep 90 days by default)
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM audit_logs 
    WHERE created_at < NOW() - (days_to_keep || ' days')::INTERVAL
    AND severity NOT IN ('error', 'critical');  -- Keep errors longer
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_audit_logs IS 'Remove audit logs older than specified days (default 90), keeps errors';
