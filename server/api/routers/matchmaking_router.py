"""
Steel Titans API - Matchmaking Router
=====================================
Endpoints para el sistema de matchmaking.
"""

from datetime import datetime, timedelta
from typing import Optional, List
from uuid import UUID, uuid4
import asyncio
import logging

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field

from database import get_db
from models import User, Match, MatchPlayer
from auth import get_current_user
from redis_manager import redis_manager
from audit_logger import audit_logger, AuditAction

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/matchmaking", tags=["Matchmaking"])


# =============================================================================
# Schemas
# =============================================================================

class QueueJoinRequest(BaseModel):
    """Request to join matchmaking queue."""
    game_mode: str = Field(default="1v1", pattern="^(1v1|2v2|4v4|practice)$")


class QueueJoinResponse(BaseModel):
    """Response after joining queue."""
    success: bool
    message: str
    position: Optional[int] = None
    estimated_wait_seconds: Optional[int] = None
    queue_size: int = 0


class QueueStatusResponse(BaseModel):
    """Current queue status for user."""
    in_queue: bool
    game_mode: Optional[str] = None
    queued_at: Optional[datetime] = None
    wait_time_seconds: Optional[int] = None
    position: Optional[int] = None
    queue_size: int = 0


class MatchFoundResponse(BaseModel):
    """Response when a match is found."""
    match_found: bool
    match_id: Optional[UUID] = None
    opponent_id: Optional[UUID] = None
    opponent_username: Optional[str] = None
    opponent_elo: Optional[int] = None
    game_mode: Optional[str] = None
    server_ip: Optional[str] = None
    server_port: Optional[int] = None


class QueueStatsResponse(BaseModel):
    """Queue statistics."""
    queues: dict
    total_players_in_queue: int
    average_wait_time_seconds: Optional[int] = None


class CancelQueueResponse(BaseModel):
    """Response after canceling queue."""
    success: bool
    message: str


# =============================================================================
# Constants
# =============================================================================

# ELO range expansion over time (seconds -> range)
ELO_EXPANSION_SCHEDULE = [
    (0, 100),      # First 30s: +/- 100 ELO
    (30, 200),     # 30-60s: +/- 200 ELO
    (60, 300),     # 60-90s: +/- 300 ELO
    (90, 500),     # 90-120s: +/- 500 ELO
    (120, 1000),   # 120s+: +/- 1000 ELO (anyone)
]

GAME_MODE_PLAYERS = {
    "1v1": 2,
    "2v2": 4,
    "4v4": 8,
    "practice": 1
}


# =============================================================================
# Helper Functions
# =============================================================================

def get_elo_range_for_wait_time(wait_seconds: int) -> int:
    """Get ELO range based on how long player has waited."""
    for threshold, elo_range in reversed(ELO_EXPANSION_SCHEDULE):
        if wait_seconds >= threshold:
            return elo_range
    return ELO_EXPANSION_SCHEDULE[0][1]


async def get_user_queue_status(user_id: str) -> Optional[dict]:
    """Get user's current queue status from Redis."""
    player_key = f"mm:player:{user_id}"
    data = await redis_manager.cache_get(player_key.replace("mm:", ""))
    
    # Try direct Redis access for matchmaking keys
    if redis_manager._redis:
        data = await redis_manager._redis.get(player_key)
        if data:
            import json
            return json.loads(data)
    return None


async def create_match_from_players(
    db: AsyncSession,
    player1_id: UUID,
    player2_id: UUID,
    game_mode: str
) -> Match:
    """Create a new match in database."""
    match = Match(
        id=uuid4(),
        game_mode=game_mode,
        status="pending",
        created_at=datetime.utcnow()
    )
    db.add(match)
    
    # Get players' ELO
    p1 = await db.get(User, player1_id)
    p2 = await db.get(User, player2_id)
    
    # Create match players
    mp1 = MatchPlayer(
        id=uuid4(),
        match_id=match.id,
        user_id=player1_id,
        team=1,
        slot=0,
        elo_before=p1.elo_rating if p1 else 1000
    )
    mp2 = MatchPlayer(
        id=uuid4(),
        match_id=match.id,
        user_id=player2_id,
        team=2,
        slot=0,
        elo_before=p2.elo_rating if p2 else 1000
    )
    
    db.add(mp1)
    db.add(mp2)
    await db.flush()
    
    return match


# =============================================================================
# Endpoints
# =============================================================================

@router.post("/queue/join", response_model=QueueJoinResponse)
async def join_queue(
    request: QueueJoinRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Join the matchmaking queue.
    
    - Adds player to Redis sorted set by ELO
    - Triggers background match search
    - Returns queue position and estimated wait
    """
    user_id = str(current_user.id)
    
    # Check if already in queue
    existing = await get_user_queue_status(user_id)
    if existing:
        return QueueJoinResponse(
            success=False,
            message=f"Already in queue for {existing.get('game_mode', 'unknown')}",
            queue_size=await redis_manager.get_queue_size(request.game_mode)
        )
    
    # Check if user is banned
    if current_user.is_banned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Banned users cannot join matchmaking"
        )
    
    # Check if user has active match
    active_match = await db.execute(
        select(MatchPlayer).join(Match).where(
            and_(
                MatchPlayer.user_id == current_user.id,
                Match.status.in_(["pending", "in_progress"])
            )
        )
    )
    if active_match.first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You already have an active match"
        )
    
    # Add to queue
    success = await redis_manager.join_matchmaking(
        user_id=user_id,
        elo=current_user.elo_rating,
        game_mode=request.game_mode
    )
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Matchmaking service temporarily unavailable"
        )
    
    # Get queue info
    queue_size = await redis_manager.get_queue_size(request.game_mode)
    
    # Estimate wait time based on queue size (rough estimate)
    estimated_wait = min(queue_size * 15, 180)  # 15s per player, max 3min
    
    # Log action
    await audit_logger.log(
        db=db,
        action=AuditAction.USER_QUEUE_JOIN,
        user_id=current_user.id,
        target_type="matchmaking",
        extra_data={
            "game_mode": request.game_mode,
            "elo": current_user.elo_rating,
            "queue_size": queue_size
        }
    )
    
    # Trigger background match search
    background_tasks.add_task(
        try_find_match,
        user_id,
        current_user.elo_rating,
        request.game_mode
    )
    
    return QueueJoinResponse(
        success=True,
        message=f"Joined {request.game_mode} queue",
        position=queue_size,
        estimated_wait_seconds=estimated_wait,
        queue_size=queue_size
    )


@router.delete("/queue/leave", response_model=CancelQueueResponse)
async def leave_queue(
    game_mode: str = "1v1",
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Leave the matchmaking queue.
    """
    user_id = str(current_user.id)
    
    # Check if in queue
    existing = await get_user_queue_status(user_id)
    if not existing:
        return CancelQueueResponse(
            success=False,
            message="Not currently in queue"
        )
    
    # Remove from queue
    success = await redis_manager.remove_from_matchmaking(user_id, game_mode)
    
    # Log action
    await audit_logger.log(
        db=db,
        action=AuditAction.USER_QUEUE_LEAVE,
        user_id=current_user.id,
        target_type="matchmaking",
        extra_data={"game_mode": game_mode}
    )
    
    return CancelQueueResponse(
        success=True,
        message="Left matchmaking queue"
    )


@router.get("/queue/status", response_model=QueueStatusResponse)
async def get_queue_status(
    current_user: User = Depends(get_current_user)
):
    """
    Get current queue status for the authenticated user.
    """
    user_id = str(current_user.id)
    
    status_data = await get_user_queue_status(user_id)
    
    if not status_data:
        return QueueStatusResponse(
            in_queue=False,
            queue_size=0
        )
    
    game_mode = status_data.get("game_mode", "1v1")
    queued_at_str = status_data.get("queued_at")
    queued_at = datetime.fromisoformat(queued_at_str) if queued_at_str else None
    
    wait_time = None
    if queued_at:
        wait_time = int((datetime.utcnow() - queued_at).total_seconds())
    
    queue_size = await redis_manager.get_queue_size(game_mode)
    
    # Calculate position (by ELO proximity - simplified)
    position = max(1, queue_size // 2)  # Rough estimate
    
    return QueueStatusResponse(
        in_queue=True,
        game_mode=game_mode,
        queued_at=queued_at,
        wait_time_seconds=wait_time,
        position=position,
        queue_size=queue_size
    )


@router.get("/queue/check-match", response_model=MatchFoundResponse)
async def check_for_match(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Check if a match has been found for the user.
    
    Client should poll this endpoint periodically while in queue.
    """
    user_id = str(current_user.id)
    
    # Check for pending match notification in Redis
    match_key = f"mm:match_found:{user_id}"
    if redis_manager._redis:
        match_data = await redis_manager._redis.get(match_key)
        if match_data:
            import json
            data = json.loads(match_data)
            
            # Clear the notification
            await redis_manager._redis.delete(match_key)
            
            # Get opponent info
            opponent_id = data.get("opponent_id")
            if opponent_id:
                opponent = await db.get(User, UUID(opponent_id))
                
                return MatchFoundResponse(
                    match_found=True,
                    match_id=UUID(data.get("match_id")),
                    opponent_id=UUID(opponent_id),
                    opponent_username=opponent.username if opponent else "Unknown",
                    opponent_elo=opponent.elo_rating if opponent else 1000,
                    game_mode=data.get("game_mode"),
                    server_ip=data.get("server_ip", "159.65.94.179"),
                    server_port=data.get("server_port", 7777)
                )
    
    return MatchFoundResponse(match_found=False)


@router.get("/queue/stats", response_model=QueueStatsResponse)
async def get_queue_stats():
    """
    Get current matchmaking queue statistics.
    
    Public endpoint for displaying queue activity.
    """
    queues = {}
    total = 0
    
    for mode in ["1v1", "2v2", "4v4", "practice"]:
        size = await redis_manager.get_queue_size(mode)
        queues[mode] = {
            "players": size,
            "players_needed": GAME_MODE_PLAYERS.get(mode, 2)
        }
        total += size
    
    return QueueStatsResponse(
        queues=queues,
        total_players_in_queue=total,
        average_wait_time_seconds=30 if total > 0 else None
    )


# =============================================================================
# Background Tasks
# =============================================================================

async def try_find_match(user_id: str, elo: int, game_mode: str):
    """
    Background task to find a match for a player.
    
    Called after player joins queue.
    """
    import json
    
    logging.info(f"try_find_match: Starting search for user {user_id} (ELO: {elo}, mode: {game_mode})")
    
    # Wait a moment for other players to potentially join
    await asyncio.sleep(2)
    
    # Get current queue status
    status = await get_user_queue_status(user_id)
    if not status:
        logging.info(f"try_find_match: User {user_id} left queue or status not found")
        # Even if status not found, still try to find match - player might still be in sorted set
    
    # Calculate ELO range based on wait time
    elo_range = 100  # Start with default
    if status:
        queued_at_str = status.get("queued_at")
        if queued_at_str:
            queued_at = datetime.fromisoformat(queued_at_str)
            wait_seconds = int((datetime.utcnow() - queued_at).total_seconds())
            elo_range = get_elo_range_for_wait_time(wait_seconds)
            logging.info(f"try_find_match: Wait time {wait_seconds}s, using ELO range {elo_range}")
    
    # Try to find a match
    opponent = await redis_manager.find_match(
        user_id=user_id,
        elo=elo,
        game_mode=game_mode,
        elo_range=elo_range
    )
    
    if opponent:
        opponent_id = opponent.get("user_id")
        logging.info(f"try_find_match: Found opponent {opponent_id} for user {user_id}")
        
        # Create match in database (need db session)
        from database import async_session_maker
        async with async_session_maker() as db:
            try:
                match = await create_match_from_players(
                    db,
                    UUID(user_id),
                    UUID(opponent_id),
                    game_mode
                )
                await db.commit()
                logging.info(f"try_find_match: Created match {match.id}")
                
                # Remove both players from queue
                await redis_manager.remove_from_matchmaking(user_id, game_mode)
                await redis_manager.remove_from_matchmaking(opponent_id, game_mode)
                logging.info(f"try_find_match: Removed both players from queue")
                
                # Notify both players via Redis
                match_notification = {
                    "match_id": str(match.id),
                    "game_mode": game_mode,
                    "server_ip": "159.65.94.179",
                    "server_port": 7777
                }
                
                # Notify player 1
                await redis_manager._redis.setex(
                    f"mm:match_found:{user_id}",
                    300,  # 5 min TTL
                    json.dumps({**match_notification, "opponent_id": opponent_id})
                )
                logging.info(f"try_find_match: Notified player 1 ({user_id})")
                
                # Notify player 2
                await redis_manager._redis.setex(
                    f"mm:match_found:{opponent_id}",
                    300,
                    json.dumps({**match_notification, "opponent_id": user_id})
                )
                logging.info(f"try_find_match: Notified player 2 ({opponent_id})")
                
                # Log the match creation
                await audit_logger.log(
                    db=db,
                    action=AuditAction.MATCH_CREATED,
                    user_id=UUID(user_id),
                    target_type="match",
                    target_id=str(match.id),
                    extra_data={
                        "game_mode": game_mode,
                        "player1": user_id,
                        "player2": opponent_id
                    }
                )
                logging.info(f"try_find_match: Match {match.id} fully created and notified")
                
            except Exception as e:
                await db.rollback()
                logging.error(f"try_find_match: Error creating match: {e}", exc_info=True)
    else:
        logging.info(f"try_find_match: No opponent found for user {user_id}")


# =============================================================================
# Admin Endpoints
# =============================================================================

@router.post("/admin/clear-queue/{game_mode}")
async def admin_clear_queue(
    game_mode: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Clear a matchmaking queue (admin only).
    """
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    
    if redis_manager._redis:
        queue_key = f"mm:queue:{game_mode}"
        await redis_manager._redis.delete(queue_key)
    
    await audit_logger.log(
        db=db,
        action=AuditAction.ADMIN_ACTION,
        user_id=current_user.id,
        target_type="matchmaking",
        extra_data={"action": "clear_queue", "game_mode": game_mode}
    )
    
    return {"success": True, "message": f"Queue {game_mode} cleared"}
