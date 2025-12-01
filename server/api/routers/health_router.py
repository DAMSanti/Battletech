"""
Steel Titans API - Health Check Module
======================================
Comprehensive health checks for monitoring.

Provides:
- Basic health endpoint
- Detailed health with DB status
- Readiness probe for k8s
- Liveness probe for k8s
"""

import time
import platform
from typing import Optional
from datetime import datetime

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from database import get_db, engine
from config import get_settings
from redis_manager import redis_manager

router = APIRouter(prefix="/health", tags=["Health"])
settings = get_settings()

# Track startup time
_startup_time = time.time()


def get_uptime() -> int:
    """Get API uptime in seconds."""
    return int(time.time() - _startup_time)


async def check_database_health(db: Optional[AsyncSession] = None) -> dict:
    """
    Check database connection health.
    
    Returns:
        dict with status and details
    """
    try:
        if db is None:
            # Use engine directly for quick check
            async with engine.connect() as conn:
                result = await conn.execute(text("SELECT 1"))
                result.fetchone()
        else:
            await db.execute(text("SELECT 1"))
        
        return {
            "status": "healthy",
            "message": "Database connection successful"
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "message": str(e)
        }


async def check_redis_health() -> dict:
    """
    Check Redis connection health.
    
    Returns:
        dict with status and details
    """
    return await redis_manager.health_check()


@router.get("", response_model=None)
async def health_check():
    """
    Basic health check endpoint.
    
    Use this for load balancer health checks.
    Always returns 200 if the API is running.
    """
    return {
        "status": "healthy",
        "service": "Steel Titans API",
        "version": "1.0.0",
    }


@router.get("/detailed")
async def health_check_detailed(db: AsyncSession = Depends(get_db)):
    """
    Detailed health check with all service statuses.
    
    Includes database connectivity, Redis, uptime, and system info.
    """
    db_health = await check_database_health(db)
    redis_health = await check_redis_health()
    
    overall_healthy = (
        db_health["status"] == "healthy" and 
        redis_health.get("status") in ["healthy", "disconnected"]  # Redis is optional
    )
    
    return {
        "status": "healthy" if overall_healthy else "degraded",
        "service": "Steel Titans API",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "uptime_seconds": get_uptime(),
        "checks": {
            "database": db_health,
            "redis": redis_health,
        },
        "system": {
            "python_version": platform.python_version(),
            "platform": platform.system(),
            "debug_mode": settings.debug,
        }
    }


@router.get("/live")
async def liveness_probe():
    """
    Kubernetes liveness probe.
    
    Returns 200 if the application is alive (not stuck/deadlocked).
    Used by k8s to restart containers that are unresponsive.
    """
    return JSONResponse(
        status_code=status.HTTP_200_OK,
        content={"status": "alive"}
    )


@router.get("/ready")
async def readiness_probe(db: AsyncSession = Depends(get_db)):
    """
    Kubernetes readiness probe.
    
    Returns 200 only if the application is ready to receive traffic.
    Used by k8s to remove pods from load balancers during startup/issues.
    """
    db_health = await check_database_health(db)
    
    if db_health["status"] != "healthy":
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "not ready",
                "reason": "database_unavailable",
                "details": db_health
            }
        )
    
    return JSONResponse(
        status_code=status.HTTP_200_OK,
        content={"status": "ready"}
    )


@router.get("/metrics")
async def metrics():
    """
    Basic metrics endpoint.
    
    For production, integrate with Prometheus using prometheus-fastapi-instrumentator.
    """
    return {
        "uptime_seconds": get_uptime(),
        "requests_total": "N/A (enable Prometheus for real metrics)",
        "timestamp": datetime.utcnow().isoformat() + "Z",
    }
