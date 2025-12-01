"""
Steel Titans API - Pydantic Schemas
===================================
DTOs para validación de entrada/salida.
"""

from datetime import datetime
from typing import Optional, Dict, Any, List
from uuid import UUID

from pydantic import BaseModel, Field, EmailStr, field_validator


# ═══════════════════════════════════════════════════════════════════════════
# AUTH SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════

class UserRegister(BaseModel):
    """Schema para registro de usuario."""
    username: str = Field(..., min_length=3, max_length=50, pattern=r"^[a-zA-Z0-9_]+$")
    password: str = Field(..., min_length=8, max_length=100)
    email: Optional[EmailStr] = None
    display_name: Optional[str] = Field(None, max_length=100)
    
    @field_validator("username")
    @classmethod
    def username_alphanumeric(cls, v: str) -> str:
        if not v.replace("_", "").isalnum():
            raise ValueError("Username must be alphanumeric (underscores allowed)")
        return v.lower()


class UserLogin(BaseModel):
    """Schema para login."""
    username: str
    password: str
    device_type: Optional[str] = None
    device_id: Optional[str] = None


class GuestLogin(BaseModel):
    """Schema para login como invitado."""
    device_id: Optional[str] = None
    device_type: Optional[str] = None


class TokenResponse(BaseModel):
    """Schema para respuesta de token."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: "UserResponse"


class RefreshTokenRequest(BaseModel):
    """Schema para refresh token."""
    refresh_token: str


# ═══════════════════════════════════════════════════════════════════════════
# USER SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════

class UserResponse(BaseModel):
    """Schema para respuesta de usuario."""
    id: UUID
    username: str
    display_name: Optional[str]
    email: Optional[str]
    auth_provider: str
    elo_rating: int
    c_bills: int
    premium_currency: int
    house: str
    created_at: datetime
    last_login: datetime
    
    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    """Schema para actualizar usuario."""
    display_name: Optional[str] = Field(None, max_length=100)
    house: Optional[str] = Field(None, max_length=50)


class UserStats(BaseModel):
    """Schema para estadísticas de usuario."""
    user_id: UUID
    username: str
    elo_rating: int
    c_bills: int
    total_mechs: int
    total_pilots: int
    total_kills: int
    total_battles: int
    win_rate: float


# ═══════════════════════════════════════════════════════════════════════════
# PILOT SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════

class PilotCreate(BaseModel):
    """Schema para crear piloto."""
    name: str = Field(..., min_length=1, max_length=100)
    callsign: Optional[str] = Field(None, max_length=50)
    portrait_id: str = Field("default", max_length=50)


class PilotResponse(BaseModel):
    """Schema para respuesta de piloto."""
    id: UUID
    user_id: UUID
    name: str
    callsign: Optional[str]
    portrait_id: str
    xp: int
    level: int
    skills: Dict[str, Any]
    is_active: bool
    is_injured: bool
    recovery_until: Optional[datetime]
    created_at: datetime
    
    class Config:
        from_attributes = True


class PilotUpdate(BaseModel):
    """Schema para actualizar piloto."""
    callsign: Optional[str] = Field(None, max_length=50)
    portrait_id: Optional[str] = Field(None, max_length=50)


# ═══════════════════════════════════════════════════════════════════════════
# MECH SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════

class MechCreate(BaseModel):
    """Schema para crear mech."""
    variant_id: str = Field(..., max_length=50)
    custom_name: Optional[str] = Field(None, max_length=100)
    armor_state: Dict[str, Any]
    loadout: Optional[Dict[str, Any]] = None


class MechResponse(BaseModel):
    """Schema para respuesta de mech."""
    id: UUID
    user_id: UUID
    pilot_id: Optional[UUID]
    variant_id: str
    custom_name: Optional[str]
    armor_state: Dict[str, Any]
    structure_state: Optional[Dict[str, Any]]
    critical_damage: List[Any]
    loadout: Optional[Dict[str, Any]]
    kills: int
    battles_fought: int
    needs_repair: bool
    repair_cost: int
    is_available: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class MechUpdate(BaseModel):
    """Schema para actualizar mech."""
    custom_name: Optional[str] = Field(None, max_length=100)
    pilot_id: Optional[UUID] = None
    armor_state: Optional[Dict[str, Any]] = None
    loadout: Optional[Dict[str, Any]] = None


class MechRepair(BaseModel):
    """Schema para reparar mech."""
    mech_id: UUID


# ═══════════════════════════════════════════════════════════════════════════
# MATCH SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════

class MatchCreate(BaseModel):
    """Schema para crear partida."""
    game_mode: str = Field("1v1", pattern=r"^(1v1|2v2|4v4|practice)$")
    map_id: Optional[str] = None
    map_seed: Optional[int] = None


class MatchResponse(BaseModel):
    """Schema para respuesta de partida."""
    id: UUID
    game_mode: str
    map_id: Optional[str]
    map_seed: Optional[int]
    status: str
    winner_team: Optional[int]
    turn_count: int
    created_at: datetime
    started_at: Optional[datetime]
    ended_at: Optional[datetime]
    
    class Config:
        from_attributes = True


class MatchPlayerResponse(BaseModel):
    """Schema para jugador en partida."""
    id: UUID
    match_id: UUID
    user_id: UUID
    team: int
    slot: int
    result: Optional[str]
    elo_before: Optional[int]
    elo_after: Optional[int]
    elo_change: Optional[int]
    mechs_used: List[Any]
    damage_dealt: int
    damage_taken: int
    kills: int
    deaths: int
    xp_earned: int
    c_bills_earned: int
    
    class Config:
        from_attributes = True


class MatchHistory(BaseModel):
    """Schema para historial de partidas."""
    matches: List[MatchResponse]
    total: int
    page: int
    per_page: int


# ═══════════════════════════════════════════════════════════════════════════
# TRANSACTION SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════

class TransactionResponse(BaseModel):
    """Schema para respuesta de transacción."""
    id: UUID
    user_id: UUID
    type: str
    currency: str
    amount: int
    balance_after: int
    reference_type: Optional[str]
    description: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


# ═══════════════════════════════════════════════════════════════════════════
# BAN SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════

class BanCreate(BaseModel):
    """Schema para crear un ban."""
    user_id: UUID
    ban_type: str = Field("temporary", pattern=r"^(temporary|permanent|shadow)$")
    reason: str = Field(..., pattern=r"^(cheating|toxicity|exploiting|harassment|spam|fraud|tos_violation|other)$")
    description: Optional[str] = Field(None, max_length=2000)
    duration_hours: Optional[int] = Field(None, ge=1, le=8760)  # Max 1 year
    evidence: Optional[Dict[str, Any]] = None
    ip_address: Optional[str] = None
    device_id: Optional[str] = None
    
    @field_validator("duration_hours")
    @classmethod
    def validate_duration(cls, v, info):
        ban_type = info.data.get("ban_type")
        if ban_type == "permanent" and v is not None:
            raise ValueError("Permanent bans cannot have a duration")
        if ban_type == "temporary" and v is None:
            raise ValueError("Temporary bans must have a duration")
        return v


class BanResponse(BaseModel):
    """Schema para respuesta de ban."""
    id: UUID
    user_id: UUID
    ban_type: str
    reason: str
    description: Optional[str]
    evidence: Optional[Dict[str, Any]]
    banned_at: datetime
    expires_at: Optional[datetime]
    banned_by: Optional[UUID]
    banned_by_system: bool
    is_active: bool
    revoked_at: Optional[datetime]
    revoked_by: Optional[UUID]
    revoke_reason: Optional[str]
    ip_address: Optional[str]
    device_id: Optional[str]
    
    class Config:
        from_attributes = True


class BanRevoke(BaseModel):
    """Schema para revocar un ban."""
    reason: str = Field(..., min_length=10, max_length=500)


class BanCheck(BaseModel):
    """Schema para verificar estado de ban."""
    is_banned: bool
    ban_type: Optional[str] = None
    reason: Optional[str] = None
    expires_at: Optional[datetime] = None
    description: Optional[str] = None


class BanHistory(BaseModel):
    """Schema para historial de bans."""
    bans: List[BanResponse]
    total: int
    active_bans: int


# ═══════════════════════════════════════════════════════════════════════════
# LEADERBOARD SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════

class LeaderboardEntry(BaseModel):
    """Schema para entrada de leaderboard."""
    rank: int
    user_id: UUID
    username: str
    display_name: Optional[str]
    elo_rating: int
    house: str
    matches_played: int
    wins: int
    win_rate: float


class LeaderboardResponse(BaseModel):
    """Schema para respuesta de leaderboard."""
    entries: List[LeaderboardEntry]
    total: int
    page: int
    per_page: int


# ═══════════════════════════════════════════════════════════════════════════
# GENERIC SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════

class SuccessResponse(BaseModel):
    """Schema para respuesta exitosa."""
    success: bool = True
    message: str


class ErrorResponse(BaseModel):
    """Schema para respuesta de error."""
    success: bool = False
    error: str
    code: str
    details: Optional[Dict[str, Any]] = None


class PaginatedResponse(BaseModel):
    """Schema genérico para respuesta paginada."""
    items: List[Any]
    total: int
    page: int
    per_page: int
    pages: int


# Update forward references
TokenResponse.model_rebuild()
