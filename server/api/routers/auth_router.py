"""
Steel Titans API - Authentication Router
=========================================
Endpoints para registro, login y manejo de sesiones.
"""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from database import get_db
from schemas import (
    UserRegister, UserLogin, GuestLogin, TokenResponse, 
    RefreshTokenRequest, UserResponse, SuccessResponse, ErrorResponse
)
from auth import (
    register_user, authenticate_user, create_guest_user,
    create_session, refresh_session, invalidate_session, validate_session
)

router = APIRouter(prefix="/auth", tags=["Authentication"])
settings = get_settings()


def get_client_ip(request: Request) -> Optional[str]:
    """Get client IP from request."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else None


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    data: UserRegister,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Registrar un nuevo usuario.
    
    - **username**: Nombre de usuario único (3-50 caracteres, alfanumérico)
    - **password**: Contraseña (mínimo 8 caracteres)
    - **email**: Email opcional
    - **display_name**: Nombre para mostrar opcional
    """
    user, error = await register_user(
        db=db,
        username=data.username,
        password=data.password,
        email=data.email,
        display_name=data.display_name,
    )
    
    if error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error,
        )
    
    # Create session
    access_token, refresh_token, _ = await create_session(
        db=db,
        user=user,
        ip_address=get_client_ip(request),
        user_agent=request.headers.get("User-Agent"),
    )
    
    await db.commit()
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_expire_minutes * 60,
        user=UserResponse.model_validate(user),
    )


@router.post("/login", response_model=TokenResponse)
async def login(
    data: UserLogin,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Iniciar sesión con usuario y contraseña.
    
    - **username**: Nombre de usuario
    - **password**: Contraseña
    """
    user, error = await authenticate_user(
        db=db,
        username=data.username,
        password=data.password,
    )
    
    if error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=error,
        )
    
    # Create session
    access_token, refresh_token, _ = await create_session(
        db=db,
        user=user,
        device_type=data.device_type,
        device_id=data.device_id,
        ip_address=get_client_ip(request),
        user_agent=request.headers.get("User-Agent"),
    )
    
    await db.commit()
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_expire_minutes * 60,
        user=UserResponse.model_validate(user),
    )


@router.post("/guest", response_model=TokenResponse)
async def login_as_guest(
    data: GuestLogin,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Iniciar sesión como invitado.
    
    Crea una cuenta temporal sin contraseña.
    Los datos del invitado se perderán si no se convierte en cuenta completa.
    """
    user = await create_guest_user(db=db, device_id=data.device_id)
    
    # Create session
    access_token, refresh_token, _ = await create_session(
        db=db,
        user=user,
        device_type=data.device_type,
        device_id=data.device_id,
        ip_address=get_client_ip(request),
        user_agent=request.headers.get("User-Agent"),
    )
    
    await db.commit()
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_expire_minutes * 60,
        user=UserResponse.model_validate(user),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Refrescar token de acceso usando el refresh token.
    """
    new_access, new_refresh, error = await refresh_session(
        db=db,
        refresh_token=data.refresh_token,
    )
    
    if error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=error,
        )
    
    # Get user for response
    from auth import decode_token
    from sqlalchemy import select
    from models import User
    
    payload = decode_token(new_access)
    result = await db.execute(select(User).where(User.id == payload["sub"]))
    user = result.scalar_one()
    
    await db.commit()
    
    return TokenResponse(
        access_token=new_access,
        refresh_token=new_refresh,
        expires_in=settings.access_token_expire_minutes * 60,
        user=UserResponse.model_validate(user),
    )


@router.post("/logout", response_model=SuccessResponse)
async def logout(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Cerrar sesión actual.
    
    Requiere el token en el header Authorization: Bearer <token>
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authorization header",
        )
    
    token = auth_header.split(" ")[1]
    success = await invalidate_session(db=db, token=token)
    
    await db.commit()
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session not found",
        )
    
    return SuccessResponse(message="Logged out successfully")


@router.get("/me", response_model=UserResponse)
async def get_current_user(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Obtener información del usuario actual.
    
    Requiere token de acceso válido.
    """
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
    
    await db.commit()
    
    return UserResponse.model_validate(user)
