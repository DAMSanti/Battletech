"""
Steel Titans API - Routers Package
"""

from .auth_router import router as auth_router
from .users_router import router as users_router
from .mechs_router import router as mechs_router
from .pilots_router import router as pilots_router
from .health_router import router as health_router
from .bans_router import router as bans_router
from .audit_router import router as audit_router
from .stats_router import router as stats_router
from .matchmaking_router import router as matchmaking_router
from .elo_router import router as elo_router

__all__ = [
    "auth_router", 
    "users_router", 
    "mechs_router", 
    "pilots_router", 
    "health_router", 
    "bans_router", 
    "audit_router", 
    "stats_router",
    "matchmaking_router",
    "elo_router"
]
