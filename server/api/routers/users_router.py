"""
Steel Titans API - Users Router
===============================
Endpoints para gestión de usuarios.
"""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Request, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models import User, MatchPlayer
from schemas import (
    UserResponse, UserUpdate, UserStats,
    LeaderboardEntry, LeaderboardResponse,
    SuccessResponse
)
from auth import validate_session

router = APIRouter(prefix="/users", tags=["Users"])


async def get_current_user(request: Request, db: AsyncSession = Depends(get_db)) -> User:
    """Dependency to get current authenticated user."""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authorization header",
        )
    
    token = auth_header.split(" ")[1]
    user = await validate_session(db=db, token=token)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )
    
    return user


@router.get("/me", response_model=UserResponse)
async def get_me(
    current_user: User = Depends(get_current_user),
):
    """Obtener información del usuario actual."""
    return UserResponse.model_validate(current_user)


@router.patch("/me", response_model=UserResponse)
async def update_me(
    data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Actualizar información del usuario actual."""
    if data.display_name is not None:
        current_user.display_name = data.display_name
    
    if data.house is not None:
        valid_houses = ["neutral", "ferrum", "volant", "ignis", "fortis", "umbra"]
        if data.house.lower() not in valid_houses:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid house. Must be one of: {', '.join(valid_houses)}",
            )
        current_user.house = data.house.lower()
    
    await db.commit()
    await db.refresh(current_user)
    
    return UserResponse.model_validate(current_user)


@router.get("/me/stats", response_model=UserStats)
async def get_my_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtener estadísticas del usuario actual."""
    
    # Count mechs
    from models import Mech, Pilot
    
    mechs_result = await db.execute(
        select(func.count(Mech.id)).where(Mech.user_id == current_user.id)
    )
    total_mechs = mechs_result.scalar() or 0
    
    # Count pilots
    pilots_result = await db.execute(
        select(func.count(Pilot.id)).where(Pilot.user_id == current_user.id)
    )
    total_pilots = pilots_result.scalar() or 0
    
    # Sum kills and battles from mechs
    kills_result = await db.execute(
        select(
            func.coalesce(func.sum(Mech.kills), 0),
            func.coalesce(func.sum(Mech.battles_fought), 0)
        ).where(Mech.user_id == current_user.id)
    )
    kills_row = kills_result.one()
    total_kills = kills_row[0]
    total_battles = kills_row[1]
    
    # Calculate win rate from match history
    matches_result = await db.execute(
        select(
            func.count(MatchPlayer.id),
            func.sum(func.cast(MatchPlayer.result == 'win', type_=int))
        ).where(MatchPlayer.user_id == current_user.id)
    )
    matches_row = matches_result.one()
    matches_played = matches_row[0] or 0
    wins = matches_row[1] or 0
    
    win_rate = (wins / matches_played * 100) if matches_played > 0 else 0.0
    
    return UserStats(
        user_id=current_user.id,
        username=current_user.username,
        elo_rating=current_user.elo_rating,
        c_bills=current_user.c_bills,
        total_mechs=total_mechs,
        total_pilots=total_pilots,
        total_kills=total_kills,
        total_battles=total_battles,
        win_rate=round(win_rate, 1),
    )


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),  # Require auth
):
    """Obtener información de un usuario por ID."""
    result = await db.execute(select(User).where(User.id == user_id, User.is_active == True))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    
    return UserResponse.model_validate(user)


@router.get("/", response_model=LeaderboardResponse)
async def get_leaderboard(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    house: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    """
    Obtener leaderboard de jugadores por ELO.
    
    - **page**: Página actual (default: 1)
    - **per_page**: Resultados por página (default: 20, max: 100)
    - **house**: Filtrar por casa (opcional)
    """
    
    # Base query
    query = select(User).where(
        User.is_active == True,
        User.username != "system",
        User.auth_provider != "guest",  # Exclude guests from leaderboard
    )
    
    if house:
        query = query.where(User.house == house.lower())
    
    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0
    
    # Get page
    offset = (page - 1) * per_page
    query = query.order_by(User.elo_rating.desc()).offset(offset).limit(per_page)
    
    result = await db.execute(query)
    users = result.scalars().all()
    
    # Get match stats for each user
    entries = []
    for rank, user in enumerate(users, start=offset + 1):
        # Get match stats
        stats_result = await db.execute(
            select(
                func.count(MatchPlayer.id),
                func.sum(func.cast(MatchPlayer.result == 'win', type_=int))
            ).where(MatchPlayer.user_id == user.id)
        )
        stats_row = stats_result.one()
        matches_played = stats_row[0] or 0
        wins = stats_row[1] or 0
        win_rate = (wins / matches_played * 100) if matches_played > 0 else 0.0
        
        entries.append(LeaderboardEntry(
            rank=rank,
            user_id=user.id,
            username=user.username,
            display_name=user.display_name,
            elo_rating=user.elo_rating,
            house=user.house,
            matches_played=matches_played,
            wins=wins,
            win_rate=round(win_rate, 1),
        ))
    
    return LeaderboardResponse(
        entries=entries,
        total=total,
        page=page,
        per_page=per_page,
    )
