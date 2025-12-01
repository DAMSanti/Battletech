"""
Steel Titans API - Database Models
==================================
SQLAlchemy models para todas las tablas.
"""

from datetime import datetime
from typing import Optional, Dict, Any, List
from uuid import UUID, uuid4

from sqlalchemy import (
    Column, String, Integer, BigInteger, Boolean, Text, 
    ForeignKey, DateTime, JSON, Index, CheckConstraint, Enum as SQLEnum
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID, INET, JSONB
from sqlalchemy.orm import DeclarativeBase, relationship, Mapped, mapped_column
from sqlalchemy.sql import func
import enum


class Base(DeclarativeBase):
    """Base class for all models."""
    pass


class User(Base):
    """Modelo de usuario."""
    __tablename__ = "users"
    
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    username: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    email: Mapped[Optional[str]] = mapped_column(String(255), unique=True)
    password_hash: Mapped[Optional[str]] = mapped_column(String(255))
    display_name: Mapped[Optional[str]] = mapped_column(String(100))
    auth_provider: Mapped[str] = mapped_column(String(20), default="credentials")
    provider_id: Mapped[Optional[str]] = mapped_column(String(255))
    
    # Progression
    elo_rating: Mapped[int] = mapped_column(Integer, default=1000)
    c_bills: Mapped[int] = mapped_column(BigInteger, default=10000)
    premium_currency: Mapped[int] = mapped_column(Integer, default=0)
    
    # House
    house: Mapped[str] = mapped_column(String(50), default="neutral")
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_login: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_banned: Mapped[bool] = mapped_column(Boolean, default=False)
    ban_reason: Mapped[Optional[str]] = mapped_column(Text)
    ban_until: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    
    # Relationships
    sessions: Mapped[List["Session"]] = relationship("Session", back_populates="user", cascade="all, delete-orphan")
    pilots: Mapped[List["Pilot"]] = relationship("Pilot", back_populates="user", cascade="all, delete-orphan")
    mechs: Mapped[List["Mech"]] = relationship("Mech", back_populates="user", cascade="all, delete-orphan")
    transactions: Mapped[List["Transaction"]] = relationship("Transaction", back_populates="user", cascade="all, delete-orphan")
    bans: Mapped[List["Ban"]] = relationship("Ban", back_populates="user", cascade="all, delete-orphan", foreign_keys="Ban.user_id")
    
    __table_args__ = (
        CheckConstraint("char_length(username) >= 3", name="username_length"),
        CheckConstraint("auth_provider IN ('credentials', 'guest', 'google', 'apple')", name="valid_provider"),
        Index("idx_users_username", "username"),
        Index("idx_users_email", "email"),
        Index("idx_users_elo", elo_rating.desc()),
    )


class Session(Base):
    """Modelo de sesión."""
    __tablename__ = "sessions"
    
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    token: Mapped[str] = mapped_column(String(500), unique=True, nullable=False)
    refresh_token: Mapped[Optional[str]] = mapped_column(String(500), unique=True)
    
    # Device info
    device_type: Mapped[Optional[str]] = mapped_column(String(50))
    device_id: Mapped[Optional[str]] = mapped_column(String(255))
    ip_address: Mapped[Optional[str]] = mapped_column(INET)
    user_agent: Mapped[Optional[str]] = mapped_column(Text)
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_activity: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    
    # Status
    is_valid: Mapped[bool] = mapped_column(Boolean, default=True)
    
    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="sessions")
    
    __table_args__ = (
        Index("idx_sessions_user", "user_id"),
        Index("idx_sessions_token", "token"),
        Index("idx_sessions_expires", "expires_at"),
    )


class Pilot(Base):
    """Modelo de piloto."""
    __tablename__ = "pilots"
    
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Identity
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    callsign: Mapped[Optional[str]] = mapped_column(String(50))
    portrait_id: Mapped[str] = mapped_column(String(50), default="default")
    
    # Progression
    xp: Mapped[int] = mapped_column(Integer, default=0)
    level: Mapped[int] = mapped_column(Integer, default=1)
    
    # Skills (JSONB)
    skills: Mapped[Dict[str, Any]] = mapped_column(JSONB, default={"gunnery": 4, "piloting": 5})
    
    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_injured: Mapped[bool] = mapped_column(Boolean, default=False)
    recovery_until: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="pilots")
    mechs: Mapped[List["Mech"]] = relationship("Mech", back_populates="pilot")
    
    __table_args__ = (
        Index("idx_pilots_user", "user_id"),
    )


class Mech(Base):
    """Modelo de mech."""
    __tablename__ = "mechs"
    
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    pilot_id: Mapped[Optional[UUID]] = mapped_column(PGUUID(as_uuid=True), ForeignKey("pilots.id", ondelete="SET NULL"))
    
    # Identification
    variant_id: Mapped[str] = mapped_column(String(50), nullable=False)
    custom_name: Mapped[Optional[str]] = mapped_column(String(100))
    
    # State (JSONB)
    armor_state: Mapped[Dict[str, Any]] = mapped_column(JSONB, nullable=False)
    structure_state: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSONB)
    critical_damage: Mapped[List[Any]] = mapped_column(JSONB, default=[])
    
    # Loadout
    loadout: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSONB)
    
    # Progression
    kills: Mapped[int] = mapped_column(Integer, default=0)
    battles_fought: Mapped[int] = mapped_column(Integer, default=0)
    
    # Status
    needs_repair: Mapped[bool] = mapped_column(Boolean, default=False)
    repair_cost: Mapped[int] = mapped_column(Integer, default=0)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="mechs")
    pilot: Mapped[Optional["Pilot"]] = relationship("Pilot", back_populates="mechs")
    
    __table_args__ = (
        Index("idx_mechs_user", "user_id"),
        Index("idx_mechs_variant", "variant_id"),
    )


class Match(Base):
    """Modelo de partida."""
    __tablename__ = "matches"
    
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    
    # Configuration
    game_mode: Mapped[str] = mapped_column(String(20), nullable=False, default="1v1")
    map_id: Mapped[Optional[str]] = mapped_column(String(50))
    map_seed: Mapped[Optional[int]] = mapped_column(Integer)
    
    # Status
    status: Mapped[str] = mapped_column(String(20), default="pending")
    winner_team: Mapped[Optional[int]] = mapped_column(Integer)
    
    # Data (JSONB)
    turn_count: Mapped[int] = mapped_column(Integer, default=0)
    final_state: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSONB)
    replay_data: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSONB)
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    started_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    ended_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    
    # Relationships
    players: Mapped[List["MatchPlayer"]] = relationship("MatchPlayer", back_populates="match", cascade="all, delete-orphan")
    
    __table_args__ = (
        CheckConstraint("status IN ('pending', 'in_progress', 'completed', 'cancelled', 'abandoned')", name="valid_status"),
        CheckConstraint("game_mode IN ('1v1', '2v2', '4v4', 'practice')", name="valid_game_mode"),
        Index("idx_matches_status", "status"),
        Index("idx_matches_created", created_at.desc()),
    )


class MatchPlayer(Base):
    """Modelo de jugador en partida."""
    __tablename__ = "match_players"
    
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    match_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey("matches.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Team
    team: Mapped[int] = mapped_column(Integer, nullable=False)
    slot: Mapped[int] = mapped_column(Integer, default=0)
    
    # Result
    result: Mapped[Optional[str]] = mapped_column(String(20))
    elo_before: Mapped[Optional[int]] = mapped_column(Integer)
    elo_after: Mapped[Optional[int]] = mapped_column(Integer)
    elo_change: Mapped[Optional[int]] = mapped_column(Integer)
    
    # Stats (JSONB)
    mechs_used: Mapped[List[Any]] = mapped_column(JSONB, default=[])
    damage_dealt: Mapped[int] = mapped_column(Integer, default=0)
    damage_taken: Mapped[int] = mapped_column(Integer, default=0)
    kills: Mapped[int] = mapped_column(Integer, default=0)
    deaths: Mapped[int] = mapped_column(Integer, default=0)
    
    # Rewards
    xp_earned: Mapped[int] = mapped_column(Integer, default=0)
    c_bills_earned: Mapped[int] = mapped_column(Integer, default=0)
    
    # Relationships
    match: Mapped["Match"] = relationship("Match", back_populates="players")
    
    __table_args__ = (
        Index("idx_match_players_match", "match_id"),
        Index("idx_match_players_user", "user_id"),
    )


class Transaction(Base):
    """Modelo de transacción."""
    __tablename__ = "transactions"
    
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Type
    type: Mapped[str] = mapped_column(String(50), nullable=False)
    
    # Currency
    currency: Mapped[str] = mapped_column(String(20), nullable=False)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    balance_after: Mapped[int] = mapped_column(BigInteger, nullable=False)
    
    # Reference
    reference_type: Mapped[Optional[str]] = mapped_column(String(50))
    reference_id: Mapped[Optional[UUID]] = mapped_column(PGUUID(as_uuid=True))
    
    # Description
    description: Mapped[Optional[str]] = mapped_column(Text)
    extra_data: Mapped[Dict[str, Any]] = mapped_column(JSONB, default={})
    
    # Timestamp
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="transactions")
    
    __table_args__ = (
        CheckConstraint("currency IN ('c_bills', 'premium')", name="valid_currency"),
        CheckConstraint("type IN ('match_reward', 'repair', 'purchase', 'sale', 'admin', 'bonus', 'refund')", name="valid_type"),
        Index("idx_transactions_user", "user_id"),
        Index("idx_transactions_created", created_at.desc()),
        Index("idx_transactions_type", "type"),
    )


class BanType(str, enum.Enum):
    """Tipos de ban."""
    TEMPORARY = "temporary"
    PERMANENT = "permanent"
    SHADOW = "shadow"  # User can play but is invisible to others


class BanReason(str, enum.Enum):
    """Razones de ban predefinidas."""
    CHEATING = "cheating"
    TOXICITY = "toxicity"
    EXPLOITING = "exploiting"
    HARASSMENT = "harassment"
    SPAM = "spam"
    FRAUD = "fraud"
    TOS_VIOLATION = "tos_violation"
    OTHER = "other"


class Ban(Base):
    """Modelo de ban/suspensión."""
    __tablename__ = "bans"
    
    id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Ban details
    ban_type: Mapped[str] = mapped_column(String(20), nullable=False, default="temporary")
    reason: Mapped[str] = mapped_column(String(50), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text)
    
    # Evidence
    evidence: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSONB)
    
    # Duration
    banned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))  # NULL = permanent
    
    # Admin info
    banned_by: Mapped[Optional[UUID]] = mapped_column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"))
    banned_by_system: Mapped[bool] = mapped_column(Boolean, default=False)  # Auto-ban by anti-cheat
    
    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    revoked_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    revoked_by: Mapped[Optional[UUID]] = mapped_column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"))
    revoke_reason: Mapped[Optional[str]] = mapped_column(Text)
    
    # IP/Device tracking
    ip_address: Mapped[Optional[str]] = mapped_column(INET)
    device_id: Mapped[Optional[str]] = mapped_column(String(255))
    
    # Metadata
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="bans", foreign_keys=[user_id])
    admin: Mapped[Optional["User"]] = relationship("User", foreign_keys=[banned_by])
    revoker: Mapped[Optional["User"]] = relationship("User", foreign_keys=[revoked_by])
    
    __table_args__ = (
        CheckConstraint("ban_type IN ('temporary', 'permanent', 'shadow')", name="valid_ban_type"),
        CheckConstraint("reason IN ('cheating', 'toxicity', 'exploiting', 'harassment', 'spam', 'fraud', 'tos_violation', 'other')", name="valid_ban_reason"),
        Index("idx_bans_user", "user_id"),
        Index("idx_bans_active", "is_active"),
        Index("idx_bans_expires", "expires_at"),
        Index("idx_bans_ip", "ip_address"),
        Index("idx_bans_device", "device_id"),
    )
