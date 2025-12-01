"""
Steel Titans API - Audit Router
================================
Endpoints para consultar audit logs (solo admin).
"""

from datetime import datetime, timedelta, timezone
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import select, func, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field

from database import get_db
from auth import require_admin
from models import User
from audit_logger import AuditLog, AuditAction, AuditSeverity

router = APIRouter(prefix="/audit", tags=["Audit"])


# ═══════════════════════════════════════════════════════════════════════════
# SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════

class AuditLogResponse(BaseModel):
    """Response schema for audit log entry."""
    id: UUID
    action: str
    severity: str
    description: Optional[str]
    user_id: Optional[UUID]
    username: Optional[str]
    target_type: Optional[str]
    target_id: Optional[str]
    ip_address: Optional[str]
    endpoint: Optional[str]
    method: Optional[str]
    success: bool
    error_message: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


class AuditLogDetail(AuditLogResponse):
    """Detailed response with all fields."""
    user_agent: Optional[str]
    request_id: Optional[str]
    old_value: Optional[dict]
    new_value: Optional[dict]
    extra_data: Optional[dict]


class AuditStats(BaseModel):
    """Statistics about audit logs."""
    total_entries: int
    entries_today: int
    entries_this_week: int
    failed_actions: int
    by_severity: dict
    by_action_category: dict
    top_users: List[dict]
    top_ips: List[dict]


# ═══════════════════════════════════════════════════════════════════════════
# ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════

@router.get("", response_model=List[AuditLogResponse])
async def list_audit_logs(
    action: Optional[str] = Query(None, description="Filter by action type"),
    severity: Optional[str] = Query(None, pattern=r"^(debug|info|warning|error|critical)$"),
    user_id: Optional[UUID] = Query(None, description="Filter by user who performed action"),
    target_type: Optional[str] = Query(None, description="Filter by target type"),
    target_id: Optional[str] = Query(None, description="Filter by target ID"),
    success: Optional[bool] = Query(None, description="Filter by success status"),
    ip_address: Optional[str] = Query(None, description="Filter by IP address"),
    start_date: Optional[datetime] = Query(None, description="Filter from date"),
    end_date: Optional[datetime] = Query(None, description="Filter to date"),
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    List audit logs with filters.
    Requires admin privileges.
    """
    query = select(AuditLog)
    
    # Apply filters
    conditions = []
    
    if action:
        conditions.append(AuditLog.action == action)
    
    if severity:
        conditions.append(AuditLog.severity == severity)
    
    if user_id:
        conditions.append(AuditLog.user_id == user_id)
    
    if target_type:
        conditions.append(AuditLog.target_type == target_type)
    
    if target_id:
        conditions.append(AuditLog.target_id == target_id)
    
    if success is not None:
        conditions.append(AuditLog.success == success)
    
    if ip_address:
        conditions.append(AuditLog.ip_address == ip_address)
    
    if start_date:
        conditions.append(AuditLog.created_at >= start_date)
    
    if end_date:
        conditions.append(AuditLog.created_at <= end_date)
    
    if conditions:
        query = query.where(and_(*conditions))
    
    query = query.order_by(AuditLog.created_at.desc()).offset(offset).limit(limit)
    
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/actions", response_model=List[str])
async def list_action_types(
    admin: User = Depends(require_admin),
):
    """
    List all available action types.
    Requires admin privileges.
    """
    return [a.value for a in AuditAction]


@router.get("/stats", response_model=AuditStats)
async def get_audit_stats(
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get audit log statistics.
    Requires admin privileges.
    """
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start = today_start - timedelta(days=7)
    
    # Total entries
    total_result = await db.execute(select(func.count(AuditLog.id)))
    total = total_result.scalar() or 0
    
    # Today's entries
    today_result = await db.execute(
        select(func.count(AuditLog.id)).where(AuditLog.created_at >= today_start)
    )
    today = today_result.scalar() or 0
    
    # This week's entries
    week_result = await db.execute(
        select(func.count(AuditLog.id)).where(AuditLog.created_at >= week_start)
    )
    week = week_result.scalar() or 0
    
    # Failed actions
    failed_result = await db.execute(
        select(func.count(AuditLog.id)).where(AuditLog.success == False)
    )
    failed = failed_result.scalar() or 0
    
    # By severity
    severity_result = await db.execute(
        select(AuditLog.severity, func.count(AuditLog.id))
        .group_by(AuditLog.severity)
    )
    by_severity = {row[0]: row[1] for row in severity_result.all()}
    
    # By action category (first part of action)
    action_result = await db.execute(
        select(AuditLog.action, func.count(AuditLog.id))
        .group_by(AuditLog.action)
    )
    action_counts = {}
    for row in action_result.all():
        category = row[0].split(".")[0] if row[0] else "unknown"
        action_counts[category] = action_counts.get(category, 0) + row[1]
    
    # Top 10 users by action count
    users_result = await db.execute(
        select(AuditLog.user_id, AuditLog.username, func.count(AuditLog.id))
        .where(AuditLog.user_id.isnot(None))
        .group_by(AuditLog.user_id, AuditLog.username)
        .order_by(func.count(AuditLog.id).desc())
        .limit(10)
    )
    top_users = [
        {"user_id": str(row[0]), "username": row[1], "count": row[2]}
        for row in users_result.all()
    ]
    
    # Top 10 IPs by action count
    ips_result = await db.execute(
        select(AuditLog.ip_address, func.count(AuditLog.id))
        .where(AuditLog.ip_address.isnot(None))
        .group_by(AuditLog.ip_address)
        .order_by(func.count(AuditLog.id).desc())
        .limit(10)
    )
    top_ips = [
        {"ip_address": str(row[0]), "count": row[1]}
        for row in ips_result.all()
    ]
    
    return AuditStats(
        total_entries=total,
        entries_today=today,
        entries_this_week=week,
        failed_actions=failed,
        by_severity=by_severity,
        by_action_category=action_counts,
        top_users=top_users,
        top_ips=top_ips,
    )


@router.get("/user/{user_id}", response_model=List[AuditLogResponse])
async def get_user_audit_trail(
    user_id: UUID,
    limit: int = Query(100, ge=1, le=500),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get audit trail for a specific user.
    Includes actions performed by the user and actions targeting the user.
    Requires admin privileges.
    """
    result = await db.execute(
        select(AuditLog)
        .where(
            or_(
                AuditLog.user_id == user_id,
                and_(
                    AuditLog.target_type == "user",
                    AuditLog.target_id == str(user_id)
                )
            )
        )
        .order_by(AuditLog.created_at.desc())
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/security", response_model=List[AuditLogResponse])
async def get_security_events(
    hours: int = Query(24, ge=1, le=168, description="Hours to look back"),
    limit: int = Query(100, ge=1, le=500),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get recent security-related events.
    Requires admin privileges.
    """
    since = datetime.now(timezone.utc) - timedelta(hours=hours)
    
    result = await db.execute(
        select(AuditLog)
        .where(
            and_(
                AuditLog.created_at >= since,
                or_(
                    AuditLog.action.like("security.%"),
                    AuditLog.severity.in_(["warning", "error", "critical"]),
                    AuditLog.success == False
                )
            )
        )
        .order_by(AuditLog.created_at.desc())
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/failures", response_model=List[AuditLogResponse])
async def get_failed_actions(
    hours: int = Query(24, ge=1, le=168, description="Hours to look back"),
    limit: int = Query(100, ge=1, le=500),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get recent failed actions.
    Requires admin privileges.
    """
    since = datetime.now(timezone.utc) - timedelta(hours=hours)
    
    result = await db.execute(
        select(AuditLog)
        .where(
            and_(
                AuditLog.created_at >= since,
                AuditLog.success == False
            )
        )
        .order_by(AuditLog.created_at.desc())
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/{log_id}", response_model=AuditLogDetail)
async def get_audit_log_detail(
    log_id: UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get detailed information about a specific audit log entry.
    Requires admin privileges.
    """
    result = await db.execute(select(AuditLog).where(AuditLog.id == log_id))
    log = result.scalar_one_or_none()
    
    if not log:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Audit log entry not found"
        )
    
    return log


@router.post("/cleanup")
async def cleanup_old_logs(
    days_to_keep: int = Query(90, ge=7, le=365, description="Days of logs to keep"),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Cleanup old audit logs.
    Keeps error/critical logs regardless of age.
    Requires admin privileges.
    """
    result = await db.execute(
        select(func.cleanup_old_audit_logs(days_to_keep))
    )
    deleted_count = result.scalar() or 0
    
    return {
        "success": True,
        "message": f"Deleted {deleted_count} old audit log entries",
        "deleted_count": deleted_count,
        "days_kept": days_to_keep
    }
