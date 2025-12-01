"""
Steel Titans API - Bans Router
==============================
Endpoints para gestión de bans y suspensiones.
Solo accesible por administradores.
"""

from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from sqlalchemy import select, func, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from auth import get_current_user, require_admin
from models import User, Ban
from schemas import (
    BanCreate, BanResponse, BanRevoke, BanCheck, BanHistory,
    SuccessResponse, ErrorResponse
)
from redis_manager import redis_manager

router = APIRouter(prefix="/bans", tags=["Bans"])


# ═══════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

async def get_active_ban(db: AsyncSession, user_id: UUID) -> Optional[Ban]:
    """Get the current active ban for a user."""
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(Ban).where(
            and_(
                Ban.user_id == user_id,
                Ban.is_active == True,
                or_(
                    Ban.expires_at.is_(None),  # Permanent
                    Ban.expires_at > now       # Not expired
                )
            )
        ).order_by(Ban.banned_at.desc()).limit(1)
    )
    return result.scalar_one_or_none()


async def update_user_ban_status(db: AsyncSession, user_id: UUID, is_banned: bool, 
                                  reason: Optional[str] = None, 
                                  until: Optional[datetime] = None) -> None:
    """Update the ban status in the User model."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user:
        user.is_banned = is_banned
        user.ban_reason = reason
        user.ban_until = until
        await db.commit()


async def cache_ban_status(user_id: UUID, ban: Optional[Ban]) -> None:
    """Cache ban status in Redis for quick lookups."""
    if not redis_manager._redis:
        return
    
    cache_key = f"ban:{user_id}"
    if ban and ban.is_active:
        ban_data = {
            "is_banned": True,
            "ban_type": ban.ban_type,
            "reason": ban.reason,
            "expires_at": ban.expires_at.isoformat() if ban.expires_at else None
        }
        await redis_manager.set_cache(cache_key, ban_data, ttl=300)  # 5 min cache
    else:
        await redis_manager.set_cache(cache_key, {"is_banned": False}, ttl=300)


async def get_cached_ban_status(user_id: UUID) -> Optional[dict]:
    """Get cached ban status from Redis."""
    if not redis_manager._redis:
        return None
    return await redis_manager.get_cache(f"ban:{user_id}")


# ═══════════════════════════════════════════════════════════════════════════
# PUBLIC ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════

@router.get("/check", response_model=BanCheck)
async def check_ban_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Check if the current user is banned.
    Returns ban details if banned.
    """
    # Try cache first
    cached = await get_cached_ban_status(current_user.id)
    if cached is not None:
        if not cached.get("is_banned"):
            return BanCheck(is_banned=False)
        return BanCheck(
            is_banned=True,
            ban_type=cached.get("ban_type"),
            reason=cached.get("reason"),
            expires_at=datetime.fromisoformat(cached["expires_at"]) if cached.get("expires_at") else None
        )
    
    # Check database
    ban = await get_active_ban(db, current_user.id)
    
    # Update cache
    await cache_ban_status(current_user.id, ban)
    
    if not ban:
        return BanCheck(is_banned=False)
    
    return BanCheck(
        is_banned=True,
        ban_type=ban.ban_type,
        reason=ban.reason,
        expires_at=ban.expires_at,
        description=ban.description
    )


# ═══════════════════════════════════════════════════════════════════════════
# ADMIN ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════

@router.post("", response_model=BanResponse, status_code=status.HTTP_201_CREATED)
async def create_ban(
    ban_data: BanCreate,
    request: Request,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new ban for a user.
    Requires admin privileges.
    """
    # Verify target user exists
    result = await db.execute(select(User).where(User.id == ban_data.user_id))
    target_user = result.scalar_one_or_none()
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Can't ban yourself
    if target_user.id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot ban yourself"
        )
    
    # Check for existing active ban
    existing_ban = await get_active_ban(db, ban_data.user_id)
    if existing_ban:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User already has an active ban"
        )
    
    # Calculate expiration
    expires_at = None
    if ban_data.ban_type == "temporary" and ban_data.duration_hours:
        expires_at = datetime.now(timezone.utc) + timedelta(hours=ban_data.duration_hours)
    
    # Create ban
    ban = Ban(
        user_id=ban_data.user_id,
        ban_type=ban_data.ban_type,
        reason=ban_data.reason,
        description=ban_data.description,
        evidence=ban_data.evidence,
        expires_at=expires_at,
        banned_by=admin.id,
        ip_address=ban_data.ip_address or request.client.host if request.client else None,
        device_id=ban_data.device_id
    )
    
    db.add(ban)
    await db.commit()
    await db.refresh(ban)
    
    # Update user's ban status
    await update_user_ban_status(
        db, ban_data.user_id, True, 
        f"{ban_data.reason}: {ban_data.description or 'No details'}", 
        expires_at
    )
    
    # Invalidate cache
    await cache_ban_status(ban_data.user_id, ban)
    
    # Invalidate user sessions in Redis
    await redis_manager.delete_session(f"user:{ban_data.user_id}:*")
    
    return ban


@router.get("/{ban_id}", response_model=BanResponse)
async def get_ban(
    ban_id: UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get details of a specific ban.
    Requires admin privileges.
    """
    result = await db.execute(select(Ban).where(Ban.id == ban_id))
    ban = result.scalar_one_or_none()
    
    if not ban:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ban not found"
        )
    
    return ban


@router.post("/{ban_id}/revoke", response_model=BanResponse)
async def revoke_ban(
    ban_id: UUID,
    revoke_data: BanRevoke,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Revoke an active ban.
    Requires admin privileges.
    """
    result = await db.execute(select(Ban).where(Ban.id == ban_id))
    ban = result.scalar_one_or_none()
    
    if not ban:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ban not found"
        )
    
    if not ban.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ban is already revoked or expired"
        )
    
    # Revoke the ban
    ban.is_active = False
    ban.revoked_at = datetime.now(timezone.utc)
    ban.revoked_by = admin.id
    ban.revoke_reason = revoke_data.reason
    
    await db.commit()
    await db.refresh(ban)
    
    # Update user's ban status
    await update_user_ban_status(db, ban.user_id, False)
    
    # Update cache
    await cache_ban_status(ban.user_id, None)
    
    return ban


@router.get("/user/{user_id}", response_model=BanHistory)
async def get_user_ban_history(
    user_id: UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get ban history for a specific user.
    Requires admin privileges.
    """
    # Verify user exists
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Get all bans
    result = await db.execute(
        select(Ban).where(Ban.user_id == user_id).order_by(Ban.banned_at.desc())
    )
    bans = result.scalars().all()
    
    # Count active bans
    now = datetime.now(timezone.utc)
    active_count = sum(
        1 for b in bans 
        if b.is_active and (b.expires_at is None or b.expires_at > now)
    )
    
    return BanHistory(
        bans=bans,
        total=len(bans),
        active_bans=active_count
    )


@router.get("", response_model=list[BanResponse])
async def list_bans(
    active_only: bool = Query(True, description="Show only active bans"),
    ban_type: Optional[str] = Query(None, pattern=r"^(temporary|permanent|shadow)$"),
    reason: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    List all bans with filters.
    Requires admin privileges.
    """
    query = select(Ban)
    
    if active_only:
        now = datetime.now(timezone.utc)
        query = query.where(
            and_(
                Ban.is_active == True,
                or_(
                    Ban.expires_at.is_(None),
                    Ban.expires_at > now
                )
            )
        )
    
    if ban_type:
        query = query.where(Ban.ban_type == ban_type)
    
    if reason:
        query = query.where(Ban.reason == reason)
    
    query = query.order_by(Ban.banned_at.desc()).offset(offset).limit(limit)
    
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/stats/summary")
async def get_ban_stats(
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get ban statistics summary.
    Requires admin privileges.
    """
    now = datetime.now(timezone.utc)
    
    # Total bans
    total_result = await db.execute(select(func.count(Ban.id)))
    total = total_result.scalar() or 0
    
    # Active bans
    active_result = await db.execute(
        select(func.count(Ban.id)).where(
            and_(
                Ban.is_active == True,
                or_(Ban.expires_at.is_(None), Ban.expires_at > now)
            )
        )
    )
    active = active_result.scalar() or 0
    
    # By type
    type_result = await db.execute(
        select(Ban.ban_type, func.count(Ban.id))
        .where(Ban.is_active == True)
        .group_by(Ban.ban_type)
    )
    by_type = {row[0]: row[1] for row in type_result.all()}
    
    # By reason
    reason_result = await db.execute(
        select(Ban.reason, func.count(Ban.id))
        .where(Ban.is_active == True)
        .group_by(Ban.reason)
    )
    by_reason = {row[0]: row[1] for row in reason_result.all()}
    
    # Last 24h bans
    yesterday = now - timedelta(days=1)
    recent_result = await db.execute(
        select(func.count(Ban.id)).where(Ban.banned_at >= yesterday)
    )
    recent = recent_result.scalar() or 0
    
    return {
        "total_bans": total,
        "active_bans": active,
        "bans_last_24h": recent,
        "by_type": by_type,
        "by_reason": by_reason
    }


# ═══════════════════════════════════════════════════════════════════════════
# BAN CHECK MIDDLEWARE HELPER
# ═══════════════════════════════════════════════════════════════════════════

async def check_user_banned(user_id: UUID, db: AsyncSession) -> Optional[BanCheck]:
    """
    Helper function to check if a user is banned.
    Used by middleware and other modules.
    Returns BanCheck if banned, None otherwise.
    """
    # Try cache first
    cached = await get_cached_ban_status(user_id)
    if cached is not None:
        if not cached.get("is_banned"):
            return None
        return BanCheck(
            is_banned=True,
            ban_type=cached.get("ban_type"),
            reason=cached.get("reason"),
            expires_at=datetime.fromisoformat(cached["expires_at"]) if cached.get("expires_at") else None
        )
    
    # Check database
    ban = await get_active_ban(db, user_id)
    
    # Update cache
    await cache_ban_status(user_id, ban)
    
    if not ban:
        return None
    
    return BanCheck(
        is_banned=True,
        ban_type=ban.ban_type,
        reason=ban.reason,
        expires_at=ban.expires_at,
        description=ban.description
    )
