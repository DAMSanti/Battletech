"""
ELO Router - Steel Titans API
Endpoints para gestión y consulta del sistema de ELO
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, update, and_, desc, func
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, timezone
from decimal import Decimal

from database import get_db
from models import User
from auth import get_current_user, require_admin
from redis_manager import redis_manager
from elo_calculator import (
    EloCalculator, 
    EloChange,
    MatchEloResult,
    STARTING_ELO,
    MIN_ELO,
    MAX_ELO,
    RANKS
)
# Note: Audit logging disabled for now - using simpler approach

router = APIRouter(prefix="/elo", tags=["elo"])


# =============================================================================
# SCHEMAS
# =============================================================================

class EloInfo(BaseModel):
    """Información de ELO de un usuario"""
    user_id: str
    username: str
    elo: int
    rank_name: str
    rank_tier: int
    points_to_next_rank: int
    progress_to_next: float


class EloSimulationRequest(BaseModel):
    """Request para simular cambio de ELO"""
    player_elo: int = Field(..., ge=MIN_ELO, le=MAX_ELO)
    opponent_elo: int = Field(..., ge=MIN_ELO, le=MAX_ELO)
    player_wins: bool = True
    player_games: int = Field(50, ge=0)
    opponent_games: int = Field(50, ge=0)


class EloSimulationResponse(BaseModel):
    """Response de simulación de ELO"""
    player_expected: float
    player_change: int
    player_new_elo: int
    opponent_expected: float
    opponent_change: int
    opponent_new_elo: int
    k_factor_player: float
    k_factor_opponent: float


class MatchResultRequest(BaseModel):
    """Request para registrar resultado de partida"""
    winner_id: str
    loser_id: str
    is_draw: bool = False
    winner_stats: Optional[dict] = None
    loser_stats: Optional[dict] = None


class MatchResultResponse(BaseModel):
    """Response de resultado de partida"""
    winner_elo_change: int
    winner_new_elo: int
    loser_elo_change: int
    loser_new_elo: int
    winner_rank_up: bool
    loser_rank_down: bool
    winner_new_rank: Optional[str]
    loser_new_rank: Optional[str]


class RankInfo(BaseModel):
    """Información de un rango"""
    name: str
    tier: int
    min_elo: int
    max_elo: Optional[int]


class LeaderboardEntry(BaseModel):
    """Entrada del leaderboard"""
    position: int
    user_id: str
    username: str
    elo: int
    rank_name: str


# =============================================================================
# ENDPOINTS
# =============================================================================

@router.get("/me", response_model=EloInfo)
async def get_my_elo(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Obtiene información de ELO del usuario actual"""
    return _build_elo_info(current_user)


@router.get("/user/{user_id}", response_model=EloInfo)
async def get_user_elo(
    user_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Obtiene información de ELO de un usuario específico"""
    result = await db.execute(
        select(User).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return _build_elo_info(user)


@router.get("/ranks", response_model=List[RankInfo])
async def get_ranks():
    """Obtiene información de todos los rangos"""
    ranks_info = []
    for i, rank in enumerate(RANKS):
        max_elo = RANKS[i + 1]["min_elo"] - 1 if i < len(RANKS) - 1 else None
        ranks_info.append(RankInfo(
            name=rank["name"],
            tier=rank["tier"],
            min_elo=rank["min_elo"],
            max_elo=max_elo
        ))
    return ranks_info


@router.post("/simulate", response_model=EloSimulationResponse)
async def simulate_elo_change(
    request: EloSimulationRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Simula un cambio de ELO sin afectar la base de datos.
    Útil para mostrar potenciales ganancias/pérdidas antes de una partida.
    """
    calc = EloCalculator()
    
    player_k = calc.get_k_factor(request.player_elo, request.player_games)
    opponent_k = calc.get_k_factor(request.opponent_elo, request.opponent_games)
    
    player_expected = calc.expected_score(request.player_elo, request.opponent_elo)
    opponent_expected = calc.expected_score(request.opponent_elo, request.player_elo)
    
    if request.player_wins:
        result = calc.calculate_match(
            winner_elo=request.player_elo,
            loser_elo=request.opponent_elo,
            winner_games_played=request.player_games,
            loser_games_played=request.opponent_games
        )
        return EloSimulationResponse(
            player_expected=round(player_expected, 4),
            player_change=result.winner_elo_change,
            player_new_elo=result.winner_new_elo,
            opponent_expected=round(opponent_expected, 4),
            opponent_change=result.loser_elo_change,
            opponent_new_elo=result.loser_new_elo,
            k_factor_player=round(player_k, 2),
            k_factor_opponent=round(opponent_k, 2)
        )
    else:
        result = calc.calculate_match(
            winner_elo=request.opponent_elo,
            loser_elo=request.player_elo,
            winner_games_played=request.opponent_games,
            loser_games_played=request.player_games
        )
        return EloSimulationResponse(
            player_expected=round(player_expected, 4),
            player_change=result.loser_elo_change,
            player_new_elo=result.loser_new_elo,
            opponent_expected=round(opponent_expected, 4),
            opponent_change=result.winner_elo_change,
            opponent_new_elo=result.winner_new_elo,
            k_factor_player=round(player_k, 2),
            k_factor_opponent=round(opponent_k, 2)
        )


@router.post("/match-result", response_model=MatchResultResponse)
async def record_match_result(
    request: MatchResultRequest,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Registra el resultado de una partida y actualiza ELOs.
    Solo admin pueden usar este endpoint directamente.
    Normalmente el servidor de juego usa esto internamente.
    """
    # Obtener usuarios
    result = await db.execute(
        select(User).where(User.id.in_([request.winner_id, request.loser_id]))
    )
    users = {u.id: u for u in result.scalars().all()}
    
    if request.winner_id not in users or request.loser_id not in users:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="One or both users not found"
        )
    
    winner = users[request.winner_id]
    loser = users[request.loser_id]
    
    # Calcular cambios
    calc = EloCalculator()
    elo_result = calc.calculate_match(
        winner_elo=winner.elo_rating,
        loser_elo=loser.elo_rating,
        winner_games_played=50,  # Default value since model doesn't track this
        loser_games_played=50,   # Default value since model doesn't track this
        is_draw=request.is_draw,
        winner_performance=request.winner_stats,
        loser_performance=request.loser_stats
    )
    
    # Verificar cambios de rango
    winner_old_rank = calc.get_rank_for_elo(winner.elo_rating)
    winner_new_rank = calc.get_rank_for_elo(elo_result.winner_new_elo)
    loser_old_rank = calc.get_rank_for_elo(loser.elo_rating)
    loser_new_rank = calc.get_rank_for_elo(elo_result.loser_new_elo)
    
    # Actualizar ELO de usuarios
    winner.elo_rating = elo_result.winner_new_elo
    loser.elo_rating = elo_result.loser_new_elo
    
    await db.commit()
    
    # TODO: Add audit logging later
    # Audit logging temporarily disabled
    
    # Invalidar caché
    await redis_manager.cache_delete(f"user:{request.winner_id}")
    await redis_manager.cache_delete(f"user:{request.loser_id}")
    await redis_manager.cache_delete("stats:leaderboard")
    
    return MatchResultResponse(
        winner_elo_change=elo_result.winner_elo_change,
        winner_new_elo=elo_result.winner_new_elo,
        loser_elo_change=elo_result.loser_elo_change,
        loser_new_elo=elo_result.loser_new_elo,
        winner_rank_up=winner_new_rank["tier"] > winner_old_rank["tier"],
        loser_rank_down=loser_new_rank["tier"] < loser_old_rank["tier"],
        winner_new_rank=winner_new_rank["name"] if winner_new_rank["tier"] > winner_old_rank["tier"] else None,
        loser_new_rank=loser_new_rank["name"] if loser_new_rank["tier"] < loser_old_rank["tier"] else None
    )


@router.get("/leaderboard", response_model=List[LeaderboardEntry])
async def get_elo_leaderboard(
    limit: int = 100,
    offset: int = 0,
    db: AsyncSession = Depends(get_db)
):
    """Obtiene el leaderboard por ELO"""
    cache_key = f"elo:leaderboard:{limit}:{offset}"
    
    cached = await redis_manager.cache_get(cache_key)
    if cached:
        return cached
    
    calc = EloCalculator()
    
    result = await db.execute(
        select(User)
        .where(User.is_active == True)
        .order_by(desc(User.elo_rating))
        .offset(offset)
        .limit(limit)
    )
    users = result.scalars().all()
    
    leaderboard = []
    for i, user in enumerate(users):
        rank_info = calc.get_rank_for_elo(user.elo_rating)
        
        leaderboard.append(LeaderboardEntry(
            position=offset + i + 1,
            user_id=str(user.id),
            username=user.username,
            elo=user.elo_rating,
            rank_name=rank_info["name"]
        ))
    
    await redis_manager.cache_set(cache_key, [e.model_dump() for e in leaderboard], ttl=300)
    
    return leaderboard


@router.get("/distribution")
async def get_elo_distribution(
    db: AsyncSession = Depends(get_db)
):
    """Obtiene la distribución de ELO por rangos"""
    cache_key = "elo:distribution"
    
    cached = await redis_manager.cache_get(cache_key)
    if cached:
        return cached
    
    distribution = {}
    
    for i, rank in enumerate(RANKS):
        min_elo = rank["min_elo"]
        max_elo = RANKS[i + 1]["min_elo"] if i < len(RANKS) - 1 else MAX_ELO + 1
        
        result = await db.execute(
            select(func.count(User.id))
            .where(
                and_(
                    User.is_active == True,
                    User.elo_rating >= min_elo,
                    User.elo_rating < max_elo
                )
            )
        )
        count = result.scalar()
        
        distribution[rank["name"]] = {
            "tier": rank["tier"],
            "min_elo": min_elo,
            "max_elo": max_elo - 1 if max_elo <= MAX_ELO else None,
            "player_count": count
        }
    
    # Totales
    total_result = await db.execute(
        select(func.count(User.id)).where(User.is_active == True)
    )
    total_players = total_result.scalar()
    
    # Estadísticas globales
    avg_result = await db.execute(
        select(func.avg(User.elo_rating)).where(User.is_active == True)
    )
    avg_elo = avg_result.scalar() or 0
    
    response = {
        "distribution": distribution,
        "total_players": total_players,
        "average_elo": round(float(avg_elo), 0)
    }
    
    await redis_manager.cache_set(cache_key, response, ttl=600)
    
    return response


@router.post("/admin/reset/{user_id}")
async def admin_reset_elo(
    user_id: str,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Reset de ELO de un usuario (solo admin)"""
    result = await db.execute(
        select(User).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    old_elo = user.elo_rating
    user.elo_rating = STARTING_ELO
    
    await db.commit()
    
    # TODO: Add audit logging later
    
    await redis_manager.cache_delete(f"user:{user_id}")
    await redis_manager.cache_delete("elo:distribution")
    
    return {
        "success": True,
        "message": f"ELO reset for user {user.username}",
        "old_elo": old_elo,
        "new_elo": STARTING_ELO
    }


@router.post("/admin/adjust/{user_id}")
async def admin_adjust_elo(
    user_id: str,
    adjustment: int = 0,
    reason: str = "Admin adjustment",
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Ajuste manual de ELO (solo admin)"""
    if adjustment == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Adjustment cannot be zero"
        )
    
    result = await db.execute(
        select(User).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    old_elo = user.elo_rating
    new_elo = max(MIN_ELO, min(MAX_ELO, user.elo_rating + adjustment))
    user.elo_rating = new_elo
    
    await db.commit()
    
    # TODO: Add audit logging later
    
    await redis_manager.cache_delete(f"user:{user_id}")
    
    return {
        "success": True,
        "message": f"ELO adjusted for user {user.username}",
        "old_elo": old_elo,
        "new_elo": new_elo,
        "actual_change": new_elo - old_elo
    }


# =============================================================================
# HELPERS
# =============================================================================

def _build_elo_info(user: User) -> EloInfo:
    """Construye EloInfo desde un User"""
    calc = EloCalculator()
    elo = user.elo_rating
    rank_info = calc.get_rank_for_elo(elo)
    
    # Calcular puntos al siguiente rango
    next_rank_elo = None
    for i, rank in enumerate(RANKS):
        if elo >= rank["min_elo"]:
            if i < len(RANKS) - 1:
                next_rank_elo = RANKS[i + 1]["min_elo"]
    
    points_to_next = next_rank_elo - elo if next_rank_elo else 0
    
    # Progress
    current_rank_min = rank_info["min_elo"]
    if next_rank_elo:
        range_size = next_rank_elo - current_rank_min
        progress = (elo - current_rank_min) / range_size if range_size > 0 else 1.0
    else:
        progress = 1.0
    
    return EloInfo(
        user_id=str(user.id),
        username=user.username,
        elo=elo,
        rank_name=rank_info["name"],
        rank_tier=rank_info["tier"],
        points_to_next_rank=max(0, points_to_next),
        progress_to_next=round(progress, 4)
    )
