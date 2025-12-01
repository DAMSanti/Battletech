"""
Router de estadísticas de usuario.
Endpoints para consultar estadísticas, historial y rankings.
"""
from datetime import datetime, timedelta
from typing import Optional, List
from uuid import UUID
import json

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, desc, and_, case, text
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field

from database import get_db
from models import User, Match, MatchPlayer
from auth import get_current_user, get_optional_user
from redis_manager import redis_manager


router = APIRouter(prefix="/stats", tags=["Statistics"])


# =============================================================================
# Schemas
# =============================================================================

class UserStats(BaseModel):
    """Estadísticas generales del usuario."""
    user_id: UUID
    username: str
    house: Optional[str]
    elo_rating: int
    
    # Match stats
    total_matches: int = 0
    wins: int = 0
    losses: int = 0
    draws: int = 0
    win_rate: float = 0.0
    
    # Combat stats
    total_kills: int = 0
    total_deaths: int = 0
    total_damage_dealt: int = 0
    total_damage_taken: int = 0
    kd_ratio: float = 0.0
    avg_damage_per_match: float = 0.0
    
    # Progression
    total_xp_earned: int = 0
    total_c_bills_earned: int = 0
    
    # Activity
    member_since: datetime
    last_match: Optional[datetime] = None


class MatchHistoryEntry(BaseModel):
    """Entrada del historial de partidas."""
    match_id: UUID
    game_mode: str
    result: Optional[str]
    team: int
    elo_change: Optional[int]
    kills: int
    deaths: int
    damage_dealt: int
    damage_taken: int
    xp_earned: int
    c_bills_earned: int
    played_at: datetime
    duration_minutes: Optional[int] = None


class MatchHistoryResponse(BaseModel):
    """Respuesta del historial de partidas."""
    matches: List[MatchHistoryEntry]
    total: int
    page: int
    page_size: int
    total_pages: int


class LeaderboardEntry(BaseModel):
    """Entrada del leaderboard."""
    rank: int
    user_id: UUID
    username: str
    house: Optional[str]
    elo_rating: int
    total_matches: int
    win_rate: float
    kd_ratio: float


class LeaderboardResponse(BaseModel):
    """Respuesta del leaderboard."""
    entries: List[LeaderboardEntry]
    total_players: int
    page: int
    page_size: int
    your_rank: Optional[int] = None


class EloHistoryEntry(BaseModel):
    """Entrada del historial de ELO."""
    match_id: UUID
    elo_before: int
    elo_after: int
    elo_change: int
    result: Optional[str]
    played_at: datetime


class EloProgressionResponse(BaseModel):
    """Respuesta de progresión de ELO."""
    current_elo: int
    highest_elo: int
    lowest_elo: int
    elo_change_last_30_days: int
    history: List[EloHistoryEntry]


class MechUsageEntry(BaseModel):
    """Entrada de uso de mechs."""
    mech_variant: str
    games_played: int
    wins: int
    losses: int
    win_rate: float
    avg_damage: float
    avg_kills: float


class MechUsageResponse(BaseModel):
    """Respuesta de uso de mechs."""
    mechs: List[MechUsageEntry]
    total_unique_mechs: int


class GlobalStats(BaseModel):
    """Estadísticas globales del juego."""
    total_players: int
    total_matches: int
    matches_today: int
    matches_this_week: int
    active_players_today: int
    active_players_this_week: int
    avg_match_duration_minutes: Optional[float] = None
    most_popular_game_mode: Optional[str] = None


# =============================================================================
# Cache helpers
# =============================================================================

CACHE_TTL_SHORT = 60  # 1 minute
CACHE_TTL_MEDIUM = 300  # 5 minutes
CACHE_TTL_LONG = 3600  # 1 hour


async def get_cached(key: str):
    """Get value from Redis cache."""
    try:
        return await redis_manager.cache_get(f"stats:{key}")
    except Exception:
        return None


async def set_cached(key: str, value: dict, ttl: int = CACHE_TTL_MEDIUM):
    """Set value in Redis cache."""
    try:
        await redis_manager.cache_set(f"stats:{key}", value, ttl=ttl)
    except Exception:
        pass


# =============================================================================
# Endpoints
# =============================================================================

@router.get("/me", response_model=UserStats)
async def get_my_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Obtener mis estadísticas.
    """
    return await _get_user_stats(current_user.id, db)


@router.get("/user/{user_id}", response_model=UserStats)
async def get_user_stats(
    user_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    """
    Obtener estadísticas públicas de un usuario.
    """
    # Check if user exists
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return await _get_user_stats(user_id, db)


async def _get_user_stats(user_id: UUID, db: AsyncSession) -> UserStats:
    """Helper para obtener estadísticas de un usuario."""
    # Try cache first
    cache_key = f"stats:user:{user_id}"
    cached = await get_cached(cache_key)
    if cached:
        return UserStats(**cached)
    
    # Get user
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get match stats
    stats_query = select(
        func.count(MatchPlayer.id).label("total_matches"),
        func.sum(case((MatchPlayer.result == "win", 1), else_=0)).label("wins"),
        func.sum(case((MatchPlayer.result == "loss", 1), else_=0)).label("losses"),
        func.sum(case((MatchPlayer.result == "draw", 1), else_=0)).label("draws"),
        func.sum(MatchPlayer.kills).label("total_kills"),
        func.sum(MatchPlayer.deaths).label("total_deaths"),
        func.sum(MatchPlayer.damage_dealt).label("total_damage_dealt"),
        func.sum(MatchPlayer.damage_taken).label("total_damage_taken"),
        func.sum(MatchPlayer.xp_earned).label("total_xp_earned"),
        func.sum(MatchPlayer.c_bills_earned).label("total_c_bills_earned"),
        func.max(Match.ended_at).label("last_match")
    ).select_from(MatchPlayer).join(
        Match, MatchPlayer.match_id == Match.id
    ).where(
        and_(
            MatchPlayer.user_id == user_id,
            Match.status == "completed"
        )
    )
    
    result = await db.execute(stats_query)
    stats = result.first()
    
    total_matches = stats.total_matches or 0
    wins = stats.wins or 0
    losses = stats.losses or 0
    draws = stats.draws or 0
    total_kills = stats.total_kills or 0
    total_deaths = stats.total_deaths or 0
    total_damage_dealt = stats.total_damage_dealt or 0
    total_damage_taken = stats.total_damage_taken or 0
    
    # Calculate derived stats
    win_rate = (wins / total_matches * 100) if total_matches > 0 else 0.0
    kd_ratio = (total_kills / total_deaths) if total_deaths > 0 else float(total_kills)
    avg_damage = (total_damage_dealt / total_matches) if total_matches > 0 else 0.0
    
    user_stats = UserStats(
        user_id=user.id,
        username=user.username,
        house=user.house,
        elo_rating=user.elo_rating,
        total_matches=total_matches,
        wins=wins,
        losses=losses,
        draws=draws,
        win_rate=round(win_rate, 2),
        total_kills=total_kills,
        total_deaths=total_deaths,
        total_damage_dealt=total_damage_dealt,
        total_damage_taken=total_damage_taken,
        kd_ratio=round(kd_ratio, 2),
        avg_damage_per_match=round(avg_damage, 2),
        total_xp_earned=stats.total_xp_earned or 0,
        total_c_bills_earned=stats.total_c_bills_earned or 0,
        member_since=user.created_at,
        last_match=stats.last_match
    )
    
    # Cache result
    await set_cached(cache_key, user_stats.model_dump(), CACHE_TTL_SHORT)
    
    return user_stats


@router.get("/user/{user_id}/history", response_model=MatchHistoryResponse)
async def get_match_history(
    user_id: UUID,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    game_mode: Optional[str] = Query(None, description="Filter by game mode"),
    result: Optional[str] = Query(None, description="Filter by result (win/loss/draw)"),
    db: AsyncSession = Depends(get_db)
):
    """
    Obtener historial de partidas de un usuario.
    """
    # Check if user exists
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Build query
    base_query = select(
        MatchPlayer, Match
    ).join(
        Match, MatchPlayer.match_id == Match.id
    ).where(
        and_(
            MatchPlayer.user_id == user_id,
            Match.status == "completed"
        )
    )
    
    # Apply filters
    if game_mode:
        base_query = base_query.where(Match.game_mode == game_mode)
    if result:
        base_query = base_query.where(MatchPlayer.result == result)
    
    # Get total count
    count_query = select(func.count()).select_from(base_query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    # Get paginated results
    offset = (page - 1) * page_size
    query = base_query.order_by(desc(Match.ended_at)).offset(offset).limit(page_size)
    result = await db.execute(query)
    rows = result.all()
    
    matches = []
    for mp, match in rows:
        duration = None
        if match.started_at and match.ended_at:
            duration = int((match.ended_at - match.started_at).total_seconds() / 60)
        
        matches.append(MatchHistoryEntry(
            match_id=match.id,
            game_mode=match.game_mode,
            result=mp.result,
            team=mp.team,
            elo_change=mp.elo_change,
            kills=mp.kills,
            deaths=mp.deaths,
            damage_dealt=mp.damage_dealt,
            damage_taken=mp.damage_taken,
            xp_earned=mp.xp_earned,
            c_bills_earned=mp.c_bills_earned,
            played_at=match.ended_at or match.created_at,
            duration_minutes=duration
        ))
    
    total_pages = (total + page_size - 1) // page_size if total > 0 else 1
    
    return MatchHistoryResponse(
        matches=matches,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages
    )


@router.get("/leaderboard", response_model=LeaderboardResponse)
async def get_leaderboard(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    house: Optional[str] = Query(None, description="Filter by house"),
    min_matches: int = Query(10, ge=0, description="Minimum matches played"),
    current_user: Optional[User] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Obtener el leaderboard de jugadores.
    """
    # Try cache for general leaderboard
    cache_key = f"stats:leaderboard:{page}:{page_size}:{house}:{min_matches}"
    cached = await get_cached(cache_key)
    if cached and not current_user:
        return LeaderboardResponse(**cached)
    
    # Subquery to get match stats per user
    match_stats = select(
        MatchPlayer.user_id,
        func.count(MatchPlayer.id).label("total_matches"),
        func.sum(case((MatchPlayer.result == "win", 1), else_=0)).label("wins"),
        func.sum(MatchPlayer.kills).label("total_kills"),
        func.sum(MatchPlayer.deaths).label("total_deaths")
    ).select_from(MatchPlayer).join(
        Match, MatchPlayer.match_id == Match.id
    ).where(
        Match.status == "completed"
    ).group_by(MatchPlayer.user_id).subquery()
    
    # Main query
    query = select(
        User.id,
        User.username,
        User.house,
        User.elo_rating,
        func.coalesce(match_stats.c.total_matches, 0).label("total_matches"),
        func.coalesce(match_stats.c.wins, 0).label("wins"),
        func.coalesce(match_stats.c.total_kills, 0).label("total_kills"),
        func.coalesce(match_stats.c.total_deaths, 0).label("total_deaths")
    ).outerjoin(
        match_stats, User.id == match_stats.c.user_id
    ).where(
        and_(
            User.is_active == True,
            User.is_banned == False,
            func.coalesce(match_stats.c.total_matches, 0) >= min_matches
        )
    )
    
    if house:
        query = query.where(User.house == house)
    
    # Get total count
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total_players = total_result.scalar()
    
    # Get paginated results ordered by ELO
    offset = (page - 1) * page_size
    query = query.order_by(desc(User.elo_rating)).offset(offset).limit(page_size)
    result = await db.execute(query)
    rows = result.all()
    
    entries = []
    for i, row in enumerate(rows):
        rank = offset + i + 1
        total_matches = row.total_matches
        wins = row.wins
        total_kills = row.total_kills
        total_deaths = row.total_deaths
        
        win_rate = (wins / total_matches * 100) if total_matches > 0 else 0.0
        kd_ratio = (total_kills / total_deaths) if total_deaths > 0 else float(total_kills)
        
        entries.append(LeaderboardEntry(
            rank=rank,
            user_id=row.id,
            username=row.username,
            house=row.house,
            elo_rating=row.elo_rating,
            total_matches=total_matches,
            win_rate=round(win_rate, 2),
            kd_ratio=round(kd_ratio, 2)
        ))
    
    # Get current user's rank if authenticated
    your_rank = None
    if current_user:
        rank_query = select(func.count()).select_from(User).outerjoin(
            match_stats, User.id == match_stats.c.user_id
        ).where(
            and_(
                User.is_active == True,
                User.is_banned == False,
                func.coalesce(match_stats.c.total_matches, 0) >= min_matches,
                User.elo_rating > current_user.elo_rating
            )
        )
        if house:
            rank_query = rank_query.where(User.house == house)
        
        rank_result = await db.execute(rank_query)
        your_rank = rank_result.scalar() + 1
    
    response = LeaderboardResponse(
        entries=entries,
        total_players=total_players,
        page=page,
        page_size=page_size,
        your_rank=your_rank
    )
    
    # Cache if no user-specific data
    if not current_user:
        await set_cached(cache_key, response.model_dump(), CACHE_TTL_MEDIUM)
    
    return response


@router.get("/user/{user_id}/elo-progression", response_model=EloProgressionResponse)
async def get_elo_progression(
    user_id: UUID,
    days: int = Query(30, ge=7, le=365, description="Number of days to look back"),
    db: AsyncSession = Depends(get_db)
):
    """
    Obtener progresión de ELO de un usuario.
    """
    # Check if user exists
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get ELO history
    since = datetime.utcnow() - timedelta(days=days)
    
    query = select(
        MatchPlayer.match_id,
        MatchPlayer.elo_before,
        MatchPlayer.elo_after,
        MatchPlayer.elo_change,
        MatchPlayer.result,
        Match.ended_at
    ).join(
        Match, MatchPlayer.match_id == Match.id
    ).where(
        and_(
            MatchPlayer.user_id == user_id,
            Match.status == "completed",
            Match.ended_at >= since,
            MatchPlayer.elo_before.isnot(None),
            MatchPlayer.elo_after.isnot(None)
        )
    ).order_by(Match.ended_at)
    
    result = await db.execute(query)
    rows = result.all()
    
    history = []
    highest_elo = user.elo_rating
    lowest_elo = user.elo_rating
    elo_change_30_days = 0
    
    for row in rows:
        if row.elo_before:
            highest_elo = max(highest_elo, row.elo_before, row.elo_after or row.elo_before)
            lowest_elo = min(lowest_elo, row.elo_before, row.elo_after or row.elo_before)
        
        if row.elo_change:
            elo_change_30_days += row.elo_change
        
        history.append(EloHistoryEntry(
            match_id=row.match_id,
            elo_before=row.elo_before,
            elo_after=row.elo_after,
            elo_change=row.elo_change or 0,
            result=row.result,
            played_at=row.ended_at
        ))
    
    return EloProgressionResponse(
        current_elo=user.elo_rating,
        highest_elo=highest_elo,
        lowest_elo=lowest_elo,
        elo_change_last_30_days=elo_change_30_days,
        history=history
    )


@router.get("/user/{user_id}/mechs", response_model=MechUsageResponse)
async def get_mech_usage(
    user_id: UUID,
    limit: int = Query(10, ge=1, le=50),
    db: AsyncSession = Depends(get_db)
):
    """
    Obtener estadísticas de uso de mechs de un usuario.
    
    Nota: Los mechs se almacenan como JSONB en mechs_used.
    Este endpoint analiza el historial de partidas.
    """
    # Check if user exists
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get all match data for user
    query = select(
        MatchPlayer.mechs_used,
        MatchPlayer.result,
        MatchPlayer.damage_dealt,
        MatchPlayer.kills
    ).join(
        Match, MatchPlayer.match_id == Match.id
    ).where(
        and_(
            MatchPlayer.user_id == user_id,
            Match.status == "completed"
        )
    )
    
    result = await db.execute(query)
    rows = result.all()
    
    # Aggregate mech usage
    mech_stats = {}
    
    for row in rows:
        mechs_used = row.mechs_used or []
        if not mechs_used:
            continue
            
        # Each mech gets credit for the match stats
        num_mechs = len(mechs_used)
        damage_share = row.damage_dealt / num_mechs if num_mechs > 0 else 0
        kills_share = row.kills / num_mechs if num_mechs > 0 else 0
        
        for mech in mechs_used:
            mech_name = mech if isinstance(mech, str) else mech.get("variant", str(mech))
            
            if mech_name not in mech_stats:
                mech_stats[mech_name] = {
                    "games_played": 0,
                    "wins": 0,
                    "losses": 0,
                    "total_damage": 0,
                    "total_kills": 0
                }
            
            mech_stats[mech_name]["games_played"] += 1
            mech_stats[mech_name]["total_damage"] += damage_share
            mech_stats[mech_name]["total_kills"] += kills_share
            
            if row.result == "win":
                mech_stats[mech_name]["wins"] += 1
            elif row.result == "loss":
                mech_stats[mech_name]["losses"] += 1
    
    # Convert to response format
    mechs = []
    for variant, stats in mech_stats.items():
        games = stats["games_played"]
        wins = stats["wins"]
        losses = stats["losses"]
        
        mechs.append(MechUsageEntry(
            mech_variant=variant,
            games_played=games,
            wins=wins,
            losses=losses,
            win_rate=round((wins / games * 100) if games > 0 else 0, 2),
            avg_damage=round(stats["total_damage"] / games if games > 0 else 0, 2),
            avg_kills=round(stats["total_kills"] / games if games > 0 else 0, 2)
        ))
    
    # Sort by games played and limit
    mechs.sort(key=lambda x: x.games_played, reverse=True)
    mechs = mechs[:limit]
    
    return MechUsageResponse(
        mechs=mechs,
        total_unique_mechs=len(mech_stats)
    )


@router.get("/global", response_model=GlobalStats)
async def get_global_stats(
    db: AsyncSession = Depends(get_db)
):
    """
    Obtener estadísticas globales del juego.
    """
    # Try cache first
    cache_key = "stats:global"
    cached = await get_cached(cache_key)
    if cached:
        return GlobalStats(**cached)
    
    now = datetime.utcnow()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start = today_start - timedelta(days=7)
    
    # Get player counts
    total_players_result = await db.execute(
        select(func.count(User.id)).where(User.is_active == True)
    )
    total_players = total_players_result.scalar()
    
    # Get match counts
    total_matches_result = await db.execute(
        select(func.count(Match.id)).where(Match.status == "completed")
    )
    total_matches = total_matches_result.scalar()
    
    # Matches today
    matches_today_result = await db.execute(
        select(func.count(Match.id)).where(
            and_(
                Match.status == "completed",
                Match.ended_at >= today_start
            )
        )
    )
    matches_today = matches_today_result.scalar()
    
    # Matches this week
    matches_week_result = await db.execute(
        select(func.count(Match.id)).where(
            and_(
                Match.status == "completed",
                Match.ended_at >= week_start
            )
        )
    )
    matches_this_week = matches_week_result.scalar()
    
    # Active players today (distinct users with matches)
    active_today_result = await db.execute(
        select(func.count(func.distinct(MatchPlayer.user_id))).select_from(
            MatchPlayer
        ).join(
            Match, MatchPlayer.match_id == Match.id
        ).where(
            and_(
                Match.status == "completed",
                Match.ended_at >= today_start
            )
        )
    )
    active_today = active_today_result.scalar()
    
    # Active players this week
    active_week_result = await db.execute(
        select(func.count(func.distinct(MatchPlayer.user_id))).select_from(
            MatchPlayer
        ).join(
            Match, MatchPlayer.match_id == Match.id
        ).where(
            and_(
                Match.status == "completed",
                Match.ended_at >= week_start
            )
        )
    )
    active_week = active_week_result.scalar()
    
    # Average match duration (for completed matches with both timestamps)
    avg_duration_result = await db.execute(
        select(
            func.avg(
                func.extract('epoch', Match.ended_at) - 
                func.extract('epoch', Match.started_at)
            ) / 60
        ).where(
            and_(
                Match.status == "completed",
                Match.started_at.isnot(None),
                Match.ended_at.isnot(None)
            )
        )
    )
    avg_duration = avg_duration_result.scalar()
    
    # Most popular game mode
    popular_mode_result = await db.execute(
        select(
            Match.game_mode,
            func.count(Match.id).label("count")
        ).where(
            Match.status == "completed"
        ).group_by(
            Match.game_mode
        ).order_by(
            desc("count")
        ).limit(1)
    )
    popular_mode_row = popular_mode_result.first()
    popular_mode = popular_mode_row.game_mode if popular_mode_row else None
    
    response = GlobalStats(
        total_players=total_players or 0,
        total_matches=total_matches or 0,
        matches_today=matches_today or 0,
        matches_this_week=matches_this_week or 0,
        active_players_today=active_today or 0,
        active_players_this_week=active_week or 0,
        avg_match_duration_minutes=round(avg_duration, 1) if avg_duration else None,
        most_popular_game_mode=popular_mode
    )
    
    # Cache for a longer time
    await set_cached(cache_key, response.model_dump(), CACHE_TTL_LONG)
    
    return response


@router.get("/houses", response_model=dict)
async def get_house_stats(
    db: AsyncSession = Depends(get_db)
):
    """
    Obtener estadísticas por casa.
    """
    # Try cache first
    cache_key = "stats:houses"
    cached = await get_cached(cache_key)
    if cached:
        return cached
    
    # Get stats per house
    query = select(
        User.house,
        func.count(User.id).label("player_count"),
        func.avg(User.elo_rating).label("avg_elo")
    ).where(
        and_(
            User.is_active == True,
            User.house.isnot(None)
        )
    ).group_by(User.house)
    
    result = await db.execute(query)
    rows = result.all()
    
    houses = {}
    for row in rows:
        houses[row.house] = {
            "player_count": row.player_count,
            "avg_elo": round(row.avg_elo, 0) if row.avg_elo else 1000
        }
    
    response = {
        "houses": houses,
        "total_houses": len(houses)
    }
    
    await set_cached(cache_key, response, CACHE_TTL_LONG)
    
    return response
