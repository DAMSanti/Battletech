"""
Steel Titans API - Authentication Service
==========================================
Manejo de autenticación, tokens JWT y sesiones.
"""

from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple
from uuid import UUID, uuid4

import bcrypt
from jose import JWTError, jwt
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from models import User, Session

settings = get_settings()


def hash_password(password: str) -> str:
    """Hash a password using bcrypt."""
    password_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    try:
        password_bytes = plain_password.encode('utf-8')
        hashed_bytes = hashed_password.encode('utf-8')
        return bcrypt.checkpw(password_bytes, hashed_bytes)
    except Exception:
        return False


def create_access_token(user_id: str, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT access token."""
    if expires_delta is None:
        expires_delta = timedelta(minutes=settings.access_token_expire_minutes)
    
    expire = datetime.now(timezone.utc) + expires_delta
    to_encode = {
        "sub": user_id,
        "exp": expire,
        "type": "access",
        "jti": str(uuid4()),  # Token ID for revocation
    }
    return jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def create_refresh_token(user_id: str, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT refresh token."""
    if expires_delta is None:
        expires_delta = timedelta(days=settings.refresh_token_expire_days)
    
    expire = datetime.now(timezone.utc) + expires_delta
    to_encode = {
        "sub": user_id,
        "exp": expire,
        "type": "refresh",
        "jti": str(uuid4()),
    }
    return jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> Optional[dict]:
    """Decode and validate a JWT token."""
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
        return payload
    except JWTError:
        return None


async def register_user(
    db: AsyncSession,
    username: str,
    password: str,
    email: Optional[str] = None,
    display_name: Optional[str] = None,
) -> Tuple[Optional[User], Optional[str]]:
    """Register a new user. Returns (user, error_message)."""
    
    # Check if username exists
    result = await db.execute(select(User).where(User.username == username.lower()))
    if result.scalar_one_or_none():
        return None, "Username already exists"
    
    # Check if email exists (if provided)
    if email:
        result = await db.execute(select(User).where(User.email == email.lower()))
        if result.scalar_one_or_none():
            return None, "Email already exists"
    
    # Create user
    user = User(
        username=username.lower(),
        password_hash=hash_password(password),
        email=email.lower() if email else None,
        display_name=display_name or username,
        auth_provider="credentials",
        c_bills=settings.starting_c_bills,
        elo_rating=settings.starting_elo,
    )
    
    db.add(user)
    await db.flush()
    await db.refresh(user)
    
    return user, None


async def authenticate_user(
    db: AsyncSession,
    username: str,
    password: str,
) -> Tuple[Optional[User], Optional[str]]:
    """Authenticate a user. Returns (user, error_message)."""
    
    # Find user by username
    result = await db.execute(select(User).where(User.username == username.lower()))
    user = result.scalar_one_or_none()
    
    if not user:
        return None, "Invalid username or password"
    
    if not user.password_hash:
        return None, "This account uses a different login method"
    
    if not verify_password(password, user.password_hash):
        return None, "Invalid username or password"
    
    if not user.is_active:
        return None, "Account is deactivated"
    
    if user.is_banned:
        if user.ban_until and user.ban_until > datetime.now(timezone.utc):
            return None, f"Account is banned until {user.ban_until}"
        return None, "Account is permanently banned"
    
    # Update last login
    user.last_login = datetime.now(timezone.utc)
    
    return user, None


async def create_guest_user(db: AsyncSession, device_id: Optional[str] = None) -> User:
    """Create a guest user."""
    
    guest_id = str(uuid4())[:8]
    username = f"guest_{guest_id}"
    
    user = User(
        username=username,
        display_name="Guest",
        auth_provider="guest",
        c_bills=settings.starting_c_bills,
        elo_rating=settings.starting_elo,
    )
    
    db.add(user)
    await db.flush()
    await db.refresh(user)
    
    return user


async def create_session(
    db: AsyncSession,
    user: User,
    device_type: Optional[str] = None,
    device_id: Optional[str] = None,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> Tuple[str, str, Session]:
    """Create a new session for a user. Returns (access_token, refresh_token, session)."""
    
    access_token = create_access_token(str(user.id))
    refresh_token = create_refresh_token(str(user.id))
    
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    
    session = Session(
        user_id=user.id,
        token=access_token,
        refresh_token=refresh_token,
        device_type=device_type,
        device_id=device_id,
        ip_address=ip_address,
        user_agent=user_agent,
        expires_at=expires_at,
    )
    
    db.add(session)
    await db.flush()
    
    return access_token, refresh_token, session


async def validate_session(
    db: AsyncSession,
    token: str,
) -> Optional[User]:
    """Validate a session token and return the user."""
    
    # Decode token
    payload = decode_token(token)
    if not payload:
        return None
    
    if payload.get("type") != "access":
        return None
    
    user_id = payload.get("sub")
    if not user_id:
        return None
    
    # Find session
    result = await db.execute(
        select(Session).where(
            Session.token == token,
            Session.is_valid == True,
            Session.expires_at > datetime.now(timezone.utc),
        )
    )
    session = result.scalar_one_or_none()
    
    if not session:
        return None
    
    # Update last activity
    session.last_activity = datetime.now(timezone.utc)
    
    # Get user
    result = await db.execute(select(User).where(User.id == session.user_id))
    user = result.scalar_one_or_none()
    
    if not user or not user.is_active or user.is_banned:
        return None
    
    return user


async def refresh_session(
    db: AsyncSession,
    refresh_token: str,
) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """Refresh a session. Returns (new_access_token, new_refresh_token, error)."""
    
    # Decode refresh token
    payload = decode_token(refresh_token)
    if not payload:
        return None, None, "Invalid refresh token"
    
    if payload.get("type") != "refresh":
        return None, None, "Invalid token type"
    
    user_id = payload.get("sub")
    if not user_id:
        return None, None, "Invalid token payload"
    
    # Find session
    result = await db.execute(
        select(Session).where(
            Session.refresh_token == refresh_token,
            Session.is_valid == True,
        )
    )
    session = result.scalar_one_or_none()
    
    if not session:
        return None, None, "Session not found"
    
    # Get user
    result = await db.execute(select(User).where(User.id == session.user_id))
    user = result.scalar_one_or_none()
    
    if not user or not user.is_active or user.is_banned:
        return None, None, "User not found or inactive"
    
    # Create new tokens
    new_access_token = create_access_token(str(user.id))
    new_refresh_token = create_refresh_token(str(user.id))
    
    # Update session
    session.token = new_access_token
    session.refresh_token = new_refresh_token
    session.expires_at = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    session.last_activity = datetime.now(timezone.utc)
    
    return new_access_token, new_refresh_token, None


async def invalidate_session(db: AsyncSession, token: str) -> bool:
    """Invalidate a session (logout)."""
    
    result = await db.execute(
        select(Session).where(Session.token == token)
    )
    session = result.scalar_one_or_none()
    
    if session:
        session.is_valid = False
        return True
    
    return False


async def invalidate_all_sessions(db: AsyncSession, user_id: UUID) -> int:
    """Invalidate all sessions for a user. Returns count of invalidated sessions."""
    
    result = await db.execute(
        select(Session).where(Session.user_id == user_id, Session.is_valid == True)
    )
    sessions = result.scalars().all()
    
    for session in sessions:
        session.is_valid = False
    
    return len(sessions)


async def cleanup_expired_sessions(db: AsyncSession) -> int:
    """Delete expired sessions. Returns count of deleted sessions."""
    
    result = await db.execute(
        delete(Session).where(Session.expires_at < datetime.now(timezone.utc))
    )
    return result.rowcount


# ═══════════════════════════════════════════════════════════════════════════
# FASTAPI DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════

from fastapi import Depends, HTTPException, status, Request
from database import get_db


async def get_current_user(request: Request, db: AsyncSession = Depends(get_db)) -> User:
    """FastAPI dependency to get current authenticated user."""
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


async def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """FastAPI dependency to require admin privileges."""
    # For now, check a list of admin usernames
    # TODO: Add is_admin field to User model or use roles table
    ADMIN_USERNAMES = ["admin", "damsanti", "steeltitans_admin"]
    
    if current_user.username.lower() not in ADMIN_USERNAMES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required",
        )
    
    return current_user


async def get_optional_user(request: Request, db: AsyncSession = Depends(get_db)) -> Optional[User]:
    """FastAPI dependency to optionally get current user (no auth required)."""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return None
    
    token = auth_header.split(" ")[1]
    return await validate_session(db=db, token=token)
