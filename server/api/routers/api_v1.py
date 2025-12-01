"""
Steel Titans API - Version 1 Router
====================================
Aggregates all v1 endpoints under /api/v1 prefix.
"""

from fastapi import APIRouter

from .auth_router import router as auth_router
from .users_router import router as users_router
from .mechs_router import router as mechs_router
from .pilots_router import router as pilots_router
from .bans_router import router as bans_router
from .audit_router import router as audit_router
from .stats_router import router as stats_router
from .matchmaking_router import router as matchmaking_router
from .elo_router import router as elo_router

# Create v1 API router
api_v1_router = APIRouter(prefix="/api/v1")

# Include all v1 routers
api_v1_router.include_router(auth_router)
api_v1_router.include_router(users_router)
api_v1_router.include_router(mechs_router)
api_v1_router.include_router(pilots_router)
api_v1_router.include_router(bans_router)
api_v1_router.include_router(audit_router)
api_v1_router.include_router(stats_router)
api_v1_router.include_router(matchmaking_router)
api_v1_router.include_router(elo_router)
