"""
Steel Titans API - Audit Log System
====================================
Sistema de registro de auditoría para acciones importantes.
"""

from datetime import datetime, timezone
from typing import Optional, Dict, Any
from uuid import UUID, uuid4
from enum import Enum

from sqlalchemy import select, func, Index
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import UUID as PGUUID, INET, JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Text, DateTime, Boolean

from models import Base
from redis_manager import redis_manager


class AuditAction(str, Enum):
    """Tipos de acciones auditables."""
    # Auth
    LOGIN = "auth.login"
    LOGIN_FAILED = "auth.login_failed"
    LOGOUT = "auth.logout"
    REGISTER = "auth.register"
    PASSWORD_CHANGE = "auth.password_change"
    TOKEN_REFRESH = "auth.token_refresh"
    
    # User
    USER_UPDATE = "user.update"
    USER_DELETE = "user.delete"
    
    # Ban
    BAN_CREATE = "ban.create"
    BAN_REVOKE = "ban.revoke"
    
    # Admin
    ADMIN_ACTION = "admin.action"
    ADMIN_USER_MODIFY = "admin.user_modify"
    ADMIN_CONFIG_CHANGE = "admin.config_change"
    
    # Match
    MATCH_CREATE = "match.create"
    MATCH_CREATED = "match.created"
    MATCH_JOIN = "match.join"
    MATCH_LEAVE = "match.leave"
    MATCH_END = "match.end"
    
    # ELO
    ELO_UPDATE = "elo.update"
    ELO_RESET = "elo.reset"
    ELO_ADJUST = "elo.adjust"
    
    # Matchmaking
    USER_QUEUE_JOIN = "matchmaking.queue_join"
    USER_QUEUE_LEAVE = "matchmaking.queue_leave"
    MATCH_FOUND = "matchmaking.match_found"
    
    # Economy
    TRANSACTION_PURCHASE = "economy.purchase"
    TRANSACTION_REWARD = "economy.reward"
    TRANSACTION_ADMIN = "economy.admin"
    
    # Security
    SUSPICIOUS_ACTIVITY = "security.suspicious"
    RATE_LIMIT_EXCEEDED = "security.rate_limit"
    INVALID_TOKEN = "security.invalid_token"
    
    # System
    SYSTEM_ERROR = "system.error"
    SYSTEM_STARTUP = "system.startup"
    SYSTEM_SHUTDOWN = "system.shutdown"


class AuditSeverity(str, Enum):
    """Niveles de severidad para audit logs."""
    DEBUG = "debug"
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"


class AuditLog(Base):
    """Modelo de audit log."""
    __tablename__ = "audit_logs"
    
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    
    # Action info
    action: Mapped[str] = mapped_column(String(100), nullable=False)
    severity: Mapped[str] = mapped_column(String(20), default="info")
    description: Mapped[Optional[str]] = mapped_column(Text)
    
    # Actor (who performed the action)
    user_id: Mapped[Optional[UUID]] = mapped_column(PGUUID(as_uuid=True))
    username: Mapped[Optional[str]] = mapped_column(String(50))
    
    # Target (what was affected)
    target_type: Mapped[Optional[str]] = mapped_column(String(50))  # user, mech, match, etc.
    target_id: Mapped[Optional[str]] = mapped_column(String(100))
    
    # Request context
    ip_address: Mapped[Optional[str]] = mapped_column(INET)
    user_agent: Mapped[Optional[str]] = mapped_column(Text)
    request_id: Mapped[Optional[str]] = mapped_column(String(100))
    endpoint: Mapped[Optional[str]] = mapped_column(String(200))
    method: Mapped[Optional[str]] = mapped_column(String(10))
    
    # Additional data
    old_value: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSONB)
    new_value: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSONB)
    extra_data: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSONB)
    
    # Result
    success: Mapped[bool] = mapped_column(Boolean, default=True)
    error_message: Mapped[Optional[str]] = mapped_column(Text)
    
    # Timestamp
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        server_default=func.now(),
        index=True
    )
    
    __table_args__ = (
        Index("idx_audit_action", "action"),
        Index("idx_audit_user", "user_id"),
        Index("idx_audit_target", "target_type", "target_id"),
        Index("idx_audit_severity", "severity"),
        Index("idx_audit_created", created_at.desc()),
        Index("idx_audit_ip", "ip_address"),
    )


class AuditLogger:
    """
    Singleton para logging de auditoría.
    Escribe a PostgreSQL y opcionalmente a Redis para alertas en tiempo real.
    """
    
    _instance: Optional["AuditLogger"] = None
    
    def __new__(cls) -> "AuditLogger":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    async def log(
        self,
        db: AsyncSession,
        action: AuditAction,
        *,
        severity: AuditSeverity = AuditSeverity.INFO,
        description: Optional[str] = None,
        user_id: Optional[UUID] = None,
        username: Optional[str] = None,
        target_type: Optional[str] = None,
        target_id: Optional[str] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        request_id: Optional[str] = None,
        endpoint: Optional[str] = None,
        method: Optional[str] = None,
        old_value: Optional[Dict[str, Any]] = None,
        new_value: Optional[Dict[str, Any]] = None,
        extra_data: Optional[Dict[str, Any]] = None,
        success: bool = True,
        error_message: Optional[str] = None,
    ) -> AuditLog:
        """
        Log an audit event.
        
        Args:
            db: Database session
            action: Type of action being logged
            severity: Severity level
            description: Human-readable description
            user_id: ID of user performing action
            username: Username (for display without lookup)
            target_type: Type of object being affected
            target_id: ID of object being affected
            ip_address: Client IP address
            user_agent: Client user agent
            request_id: Unique request identifier
            endpoint: API endpoint called
            method: HTTP method
            old_value: Previous value (for changes)
            new_value: New value (for changes)
            extra_data: Additional context
            success: Whether action succeeded
            error_message: Error details if failed
            
        Returns:
            Created AuditLog entry
        """
        audit_entry = AuditLog(
            action=action.value,
            severity=severity.value,
            description=description,
            user_id=user_id,
            username=username,
            target_type=target_type,
            target_id=str(target_id) if target_id else None,
            ip_address=ip_address,
            user_agent=user_agent,
            request_id=request_id,
            endpoint=endpoint,
            method=method,
            old_value=old_value,
            new_value=new_value,
            extra_data=extra_data,
            success=success,
            error_message=error_message,
        )
        
        db.add(audit_entry)
        await db.flush()
        
        # For critical/error events, also push to Redis for real-time alerts
        if severity in (AuditSeverity.ERROR, AuditSeverity.CRITICAL):
            await self._push_alert(audit_entry)
        
        return audit_entry
    
    async def _push_alert(self, entry: AuditLog) -> None:
        """Push critical events to Redis for real-time monitoring."""
        if not redis_manager._redis:
            return
        
        try:
            alert_data = {
                "id": str(entry.id),
                "action": entry.action,
                "severity": entry.severity,
                "description": entry.description,
                "user_id": str(entry.user_id) if entry.user_id else None,
                "username": entry.username,
                "ip_address": entry.ip_address,
                "created_at": entry.created_at.isoformat() if entry.created_at else None,
                "error_message": entry.error_message,
            }
            
            # Store in a Redis list for recent alerts
            await redis_manager._redis.lpush("audit:alerts", str(alert_data))
            await redis_manager._redis.ltrim("audit:alerts", 0, 99)  # Keep last 100
            
            # Publish for real-time subscribers
            await redis_manager._redis.publish("audit:alerts:channel", str(alert_data))
        except Exception:
            pass  # Don't fail the main operation if Redis alert fails
    
    # Convenience methods for common actions
    
    async def log_login(
        self,
        db: AsyncSession,
        user_id: UUID,
        username: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        success: bool = True,
        error_message: Optional[str] = None,
    ) -> AuditLog:
        """Log a login attempt."""
        return await self.log(
            db,
            AuditAction.LOGIN if success else AuditAction.LOGIN_FAILED,
            severity=AuditSeverity.INFO if success else AuditSeverity.WARNING,
            description=f"User {'logged in' if success else 'failed to login'}",
            user_id=user_id,
            username=username,
            ip_address=ip_address,
            user_agent=user_agent,
            success=success,
            error_message=error_message,
        )
    
    async def log_logout(
        self,
        db: AsyncSession,
        user_id: UUID,
        username: str,
        ip_address: Optional[str] = None,
    ) -> AuditLog:
        """Log a logout."""
        return await self.log(
            db,
            AuditAction.LOGOUT,
            description="User logged out",
            user_id=user_id,
            username=username,
            ip_address=ip_address,
        )
    
    async def log_register(
        self,
        db: AsyncSession,
        user_id: UUID,
        username: str,
        ip_address: Optional[str] = None,
    ) -> AuditLog:
        """Log a new user registration."""
        return await self.log(
            db,
            AuditAction.REGISTER,
            description=f"New user registered: {username}",
            user_id=user_id,
            username=username,
            ip_address=ip_address,
            target_type="user",
            target_id=str(user_id),
        )
    
    async def log_ban(
        self,
        db: AsyncSession,
        admin_id: UUID,
        admin_username: str,
        target_user_id: UUID,
        ban_type: str,
        reason: str,
        ip_address: Optional[str] = None,
    ) -> AuditLog:
        """Log a ban action."""
        return await self.log(
            db,
            AuditAction.BAN_CREATE,
            severity=AuditSeverity.WARNING,
            description=f"User banned ({ban_type}): {reason}",
            user_id=admin_id,
            username=admin_username,
            target_type="user",
            target_id=str(target_user_id),
            ip_address=ip_address,
            extra_data={"ban_type": ban_type, "reason": reason},
        )
    
    async def log_ban_revoke(
        self,
        db: AsyncSession,
        admin_id: UUID,
        admin_username: str,
        target_user_id: UUID,
        revoke_reason: str,
        ip_address: Optional[str] = None,
    ) -> AuditLog:
        """Log a ban revocation."""
        return await self.log(
            db,
            AuditAction.BAN_REVOKE,
            description=f"Ban revoked: {revoke_reason}",
            user_id=admin_id,
            username=admin_username,
            target_type="user",
            target_id=str(target_user_id),
            ip_address=ip_address,
            extra_data={"revoke_reason": revoke_reason},
        )
    
    async def log_transaction(
        self,
        db: AsyncSession,
        user_id: UUID,
        username: str,
        transaction_type: str,
        currency: str,
        amount: int,
        balance_after: int,
        description: Optional[str] = None,
    ) -> AuditLog:
        """Log an economy transaction."""
        action = AuditAction.TRANSACTION_PURCHASE
        if transaction_type == "reward":
            action = AuditAction.TRANSACTION_REWARD
        elif transaction_type == "admin":
            action = AuditAction.TRANSACTION_ADMIN
        
        return await self.log(
            db,
            action,
            description=description or f"{transaction_type}: {amount} {currency}",
            user_id=user_id,
            username=username,
            target_type="transaction",
            extra_data={
                "type": transaction_type,
                "currency": currency,
                "amount": amount,
                "balance_after": balance_after,
            },
        )
    
    async def log_suspicious_activity(
        self,
        db: AsyncSession,
        user_id: Optional[UUID],
        username: Optional[str],
        activity_type: str,
        details: Dict[str, Any],
        ip_address: Optional[str] = None,
    ) -> AuditLog:
        """Log suspicious activity detected by anti-cheat or security systems."""
        return await self.log(
            db,
            AuditAction.SUSPICIOUS_ACTIVITY,
            severity=AuditSeverity.WARNING,
            description=f"Suspicious activity detected: {activity_type}",
            user_id=user_id,
            username=username,
            ip_address=ip_address,
            extra_data={"activity_type": activity_type, **details},
        )
    
    async def log_admin_action(
        self,
        db: AsyncSession,
        admin_id: UUID,
        admin_username: str,
        action_type: str,
        target_type: Optional[str] = None,
        target_id: Optional[str] = None,
        old_value: Optional[Dict[str, Any]] = None,
        new_value: Optional[Dict[str, Any]] = None,
        ip_address: Optional[str] = None,
    ) -> AuditLog:
        """Log an administrative action."""
        return await self.log(
            db,
            AuditAction.ADMIN_ACTION,
            severity=AuditSeverity.INFO,
            description=f"Admin action: {action_type}",
            user_id=admin_id,
            username=admin_username,
            target_type=target_type,
            target_id=target_id,
            old_value=old_value,
            new_value=new_value,
            ip_address=ip_address,
            extra_data={"action_type": action_type},
        )


# Global instance
audit_logger = AuditLogger()
