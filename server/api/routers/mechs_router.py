"""
Steel Titans API - Mechs Router
===============================
Endpoints para gestión de mechs.
"""

from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Request, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models import User, Mech, Pilot, Transaction
from schemas import (
    MechCreate, MechResponse, MechUpdate, MechRepair,
    SuccessResponse
)
from auth import validate_session

router = APIRouter(prefix="/mechs", tags=["Mechs"])


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


@router.get("/", response_model=List[MechResponse])
async def get_my_mechs(
    available_only: bool = Query(False),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtener todos los mechs del usuario actual."""
    query = select(Mech).where(Mech.user_id == current_user.id)
    
    if available_only:
        query = query.where(Mech.is_available == True)
    
    result = await db.execute(query.order_by(Mech.created_at.desc()))
    mechs = result.scalars().all()
    
    return [MechResponse.model_validate(m) for m in mechs]


@router.post("/", response_model=MechResponse, status_code=status.HTTP_201_CREATED)
async def create_mech(
    data: MechCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Añadir un mech al hangar del usuario.
    
    Nota: En producción esto requeriría verificar compra/desbloqueo.
    """
    mech = Mech(
        user_id=current_user.id,
        variant_id=data.variant_id,
        custom_name=data.custom_name,
        armor_state=data.armor_state,
        loadout=data.loadout,
    )
    
    db.add(mech)
    await db.flush()
    await db.refresh(mech)
    await db.commit()
    
    return MechResponse.model_validate(mech)


@router.get("/{mech_id}", response_model=MechResponse)
async def get_mech(
    mech_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Obtener un mech específico."""
    result = await db.execute(
        select(Mech).where(Mech.id == mech_id, Mech.user_id == current_user.id)
    )
    mech = result.scalar_one_or_none()
    
    if not mech:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Mech not found",
        )
    
    return MechResponse.model_validate(mech)


@router.patch("/{mech_id}", response_model=MechResponse)
async def update_mech(
    mech_id: UUID,
    data: MechUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Actualizar un mech."""
    result = await db.execute(
        select(Mech).where(Mech.id == mech_id, Mech.user_id == current_user.id)
    )
    mech = result.scalar_one_or_none()
    
    if not mech:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Mech not found",
        )
    
    if data.custom_name is not None:
        mech.custom_name = data.custom_name
    
    if data.pilot_id is not None:
        # Verify pilot belongs to user
        pilot_result = await db.execute(
            select(Pilot).where(Pilot.id == data.pilot_id, Pilot.user_id == current_user.id)
        )
        pilot = pilot_result.scalar_one_or_none()
        if not pilot:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Pilot not found",
            )
        mech.pilot_id = data.pilot_id
    
    if data.armor_state is not None:
        mech.armor_state = data.armor_state
    
    if data.loadout is not None:
        mech.loadout = data.loadout
    
    await db.commit()
    await db.refresh(mech)
    
    return MechResponse.model_validate(mech)


@router.delete("/{mech_id}", response_model=SuccessResponse)
async def delete_mech(
    mech_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Eliminar un mech del hangar."""
    result = await db.execute(
        select(Mech).where(Mech.id == mech_id, Mech.user_id == current_user.id)
    )
    mech = result.scalar_one_or_none()
    
    if not mech:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Mech not found",
        )
    
    await db.delete(mech)
    await db.commit()
    
    return SuccessResponse(message="Mech deleted successfully")


@router.post("/{mech_id}/repair", response_model=MechResponse)
async def repair_mech(
    mech_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Reparar un mech dañado.
    
    Cuesta C-Bills según el daño sufrido.
    """
    result = await db.execute(
        select(Mech).where(Mech.id == mech_id, Mech.user_id == current_user.id)
    )
    mech = result.scalar_one_or_none()
    
    if not mech:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Mech not found",
        )
    
    if not mech.needs_repair:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mech doesn't need repair",
        )
    
    if current_user.c_bills < mech.repair_cost:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough C-Bills. Need {mech.repair_cost}, have {current_user.c_bills}",
        )
    
    # Deduct cost
    current_user.c_bills -= mech.repair_cost
    
    # Create transaction
    transaction = Transaction(
        user_id=current_user.id,
        type="repair",
        currency="c_bills",
        amount=-mech.repair_cost,
        balance_after=current_user.c_bills,
        reference_type="mech",
        reference_id=mech.id,
        description=f"Repair {mech.variant_id}",
    )
    db.add(transaction)
    
    # Reset mech state
    # Note: In production, armor_state would need to be reset to max values
    mech.needs_repair = False
    mech.repair_cost = 0
    mech.is_available = True
    mech.critical_damage = []
    
    await db.commit()
    await db.refresh(mech)
    
    return MechResponse.model_validate(mech)


@router.post("/{mech_id}/assign-pilot", response_model=MechResponse)
async def assign_pilot(
    mech_id: UUID,
    pilot_id: Optional[UUID] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Asignar o desasignar un piloto a un mech.
    
    - **pilot_id**: ID del piloto a asignar, o null para desasignar
    """
    result = await db.execute(
        select(Mech).where(Mech.id == mech_id, Mech.user_id == current_user.id)
    )
    mech = result.scalar_one_or_none()
    
    if not mech:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Mech not found",
        )
    
    if pilot_id:
        # Verify pilot belongs to user and is available
        pilot_result = await db.execute(
            select(Pilot).where(
                Pilot.id == pilot_id,
                Pilot.user_id == current_user.id,
                Pilot.is_active == True,
                Pilot.is_injured == False,
            )
        )
        pilot = pilot_result.scalar_one_or_none()
        
        if not pilot:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Pilot not found or unavailable",
            )
        
        # Check if pilot is already assigned to another mech
        existing_result = await db.execute(
            select(Mech).where(Mech.pilot_id == pilot_id, Mech.id != mech_id)
        )
        if existing_result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Pilot is already assigned to another mech",
            )
        
        mech.pilot_id = pilot_id
    else:
        mech.pilot_id = None
    
    await db.commit()
    await db.refresh(mech)
    
    return MechResponse.model_validate(mech)
