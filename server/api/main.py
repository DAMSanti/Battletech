"""
Steel Titans API - Main Application
====================================
FastAPI application for Steel Titans game backend.

Run with: uvicorn main:app --reload --host 0.0.0.0 --port 8080
"""

from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

from config import get_settings
from database import init_db, close_db
from redis_manager import redis_manager
from routers import health_router
from routers.api_v1 import api_v1_router
from middleware import RateLimitMiddleware

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator:
    """Application lifespan handler."""
    # Startup
    print("🚀 Starting Steel Titans API...")
    
    # Initialize Redis
    try:
        await redis_manager.connect()
        print("✅ Redis connected!")
    except Exception as e:
        print(f"⚠️ Redis connection failed (optional): {e}")
    
    # Note: init_db creates tables if they don't exist
    # For production, use Alembic migrations instead
    # await init_db()
    print("✅ API ready!")
    
    yield
    
    # Shutdown
    print("🛑 Shutting down Steel Titans API...")
    await redis_manager.disconnect()
    await close_db()
    print("👋 Goodbye!")


# Create FastAPI app
app = FastAPI(
    title="Steel Titans API",
    description="Backend API for Steel Titans: Tactical Warfare",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Rate limiting middleware
app.add_middleware(
    RateLimitMiddleware,
    default_limit=settings.rate_limit_per_minute,
    window_seconds=60,
    exclude_paths=["/health", "/docs", "/redoc", "/openapi.json", "/", "/api/v1"]
)


# Exception handlers
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Handle validation errors."""
    errors = []
    for error in exc.errors():
        errors.append({
            "field": ".".join(str(x) for x in error["loc"]),
            "message": error["msg"],
            "type": error["type"],
        })
    
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "success": False,
            "error": "Validation error",
            "code": "VALIDATION_ERROR",
            "details": {"errors": errors},
        },
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle unexpected errors."""
    # In production, log this error to Sentry
    print(f"❌ Unexpected error: {exc}")
    
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error": "Internal server error",
            "code": "INTERNAL_ERROR",
            "details": {"message": str(exc)} if settings.debug else None,
        },
    )


# Include routers
# Health check at root level (not versioned - for infrastructure monitoring)
app.include_router(health_router)

# API v1 - All versioned endpoints
app.include_router(api_v1_router)


# Root endpoint
@app.get("/", tags=["Root"])
async def root():
    """Root endpoint with API info."""
    return {
        "name": "Steel Titans API",
        "version": "1.0.0",
        "api_versions": {
            "v1": "/api/v1",
            "current": "/api/v1"
        },
        "health": "/health",
        "docs": "/docs" if settings.debug else "Disabled in production",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=settings.debug,
    )
