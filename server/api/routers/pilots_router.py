"""
Steel Titans API - Pilots Router
================================
Endpoints para gestión de pilotos.
"""

from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Request, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models import User, Pilot
from schemas import (
    PilotCreate, PilotResponse, PilotUpdate,
    SuccessResponse
)
from auth import validate_session

router = APIRouter(prefix="/pilots", tags=["Pilots"])


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


@router.get("/", response_model=List[PilotResponse])
async def get_my_pilots(
    active_only: bool = Query(False),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtener todos los pilotos del usuario actual."""
    query = select(Pilot).where(Pilot.user_id == current_user.id)
    
    if active_only:
        query = query.where(Pilot.is_active == True, Pilot.is_injured == False)
    
    result = await db.execute(query.order_by(Pilot.level.desc(), Pilot.xp.desc()))
    pilots = result.scalars().all()
    
    return [PilotResponse.model_validate(p) for p in pilots]


@router.post("/", response_model=PilotResponse, status_code=status.HTTP_201_CREATED)
async def create_pilot(
    data: PilotCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Crear un nuevo piloto.
    
    - **name**: Nombre del piloto (único por usuario)
    - **callsign**: Apodo/indicativo opcional
    - **portrait_id**: ID del retrato a usar
    """
    # Check if pilot name already exists for this user
    result = await db.execute(
        select(Pilot).where(
            Pilot.user_id == current_user.id,
            Pilot.name == data.name
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A pilot with this name already exists",
        )
    
    pilot = Pilot(
        user_id=current_user.id,
        name=data.name,
        callsign=data.callsign,
        portrait_id=data.portrait_id,
        skills={"gunnery": 4, "piloting": 5},  # Default skills
    )
    
    db.add(pilot)
    await db.flush()
    await db.refresh(pilot)
    await db.commit()
    
    return PilotResponse.model_validate(pilot)


@router.get("/{pilot_id}", response_model=PilotResponse)
async def get_pilot(
    pilot_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtener un piloto específico."""
    result = await db.execute(
        select(Pilot).where(Pilot.id == pilot_id, Pilot.user_id == current_user.id)
    )
    pilot = result.scalar_one_or_none()
    
    if not pilot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pilot not found",
        )
    
    return PilotResponse.model_validate(pilot)


@router.patch("/{pilot_id}", response_model=PilotResponse)
async def update_pilot(
    pilot_id: UUID,
    data: PilotUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Actualizar información de un piloto."""
    result = await db.execute(
        select(Pilot).where(Pilot.id == pilot_id, Pilot.user_id == current_user.id)
    )
    pilot = result.scalar_one_or_none()
    
    if not pilot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pilot not found",
        )
    
    if data.callsign is not None:
        pilot.callsign = data.callsign
    
    if data.portrait_id is not None:
        pilot.portrait_id = data.portrait_id
    
    await db.commit()
    await db.refresh(pilot)
    
    return PilotResponse.model_validate(pilot)


@router.delete("/{pilot_id}", response_model=SuccessResponse)
async def delete_pilot(
    pilot_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Eliminar un piloto.
    
    Nota: Los mechs asignados a este piloto quedarán sin piloto.
    """
    result = await db.execute(
        select(Pilot).where(Pilot.id == pilot_id, Pilot.user_id == current_user.id)
    )
    pilot = result.scalar_one_or_none()
    
    if not pilot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pilot not found",
        )
    
    await db.delete(pilot)
    await db.commit()
    
    return SuccessResponse(message="Pilot deleted successfully")


@router.post("/{pilot_id}/retire", response_model=SuccessResponse)
async def retire_pilot(
    pilot_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Retirar un piloto (desactivarlo sin eliminarlo).
    
    Un piloto retirado no puede ser asignado a mechs pero se conserva su historial.
    """
    result = await db.execute(
        select(Pilot).where(Pilot.id == pilot_id, Pilot.user_id == current_user.id)
    )
    pilot = result.scalar_one_or_none()
    
    if not pilot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pilot not found",
        )
    
    pilot.is_active = False
    await db.commit()
    
    return SuccessResponse(message=f"Pilot {pilot.name} has been retired")


@router.post("/{pilot_id}/reinstate", response_model=PilotResponse)
async def reinstate_pilot(
    pilot_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Reinstalar un piloto retirado."""
    result = await db.execute(
        select(Pilot).where(Pilot.id == pilot_id, Pilot.user_id == current_user.id)
    )
    pilot = result.scalar_one_or_none()
    
    if not pilot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pilot not found",
        )
    
    if pilot.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Pilot is already active",
        )
    
    pilot.is_active = True
    await db.commit()
    await db.refresh(pilot)
    
    return PilotResponse.model_validate(pilot)
