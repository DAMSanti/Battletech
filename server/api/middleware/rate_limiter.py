"""
Steel Titans API - Rate Limiter
===============================
Rate limiting middleware using slowapi.

Provides protection against:
- Brute force attacks on auth endpoints
- API abuse and DoS attempts
- Resource exhaustion

Usage:
    from middleware import rate_limiter
    
    @app.get("/endpoint")
    @rate_limiter.limit("10/minute")
    async def endpoint(request: Request):
        ...
"""

import time
from collections import defaultdict
from typing import Callable, Optional
from functools import wraps

from fastapi import Request, HTTPException, status
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from config import get_settings

settings = get_settings()


class InMemoryRateLimiter:
    """
    Simple in-memory rate limiter.
    For production with multiple instances, use Redis instead.
    """
    
    def __init__(self):
        # Dictionary: {key: [(timestamp, count), ...]}
        self._requests: dict[str, list[float]] = defaultdict(list)
        self._cleanup_interval = 60  # Clean up old entries every 60 seconds
        self._last_cleanup = time.time()
    
    def _cleanup_old_entries(self, window_seconds: int = 60) -> None:
        """Remove entries older than the window."""
        current_time = time.time()
        
        # Only cleanup periodically
        if current_time - self._last_cleanup < self._cleanup_interval:
            return
        
        self._last_cleanup = current_time
        cutoff = current_time - window_seconds
        
        for key in list(self._requests.keys()):
            self._requests[key] = [
                ts for ts in self._requests[key] if ts > cutoff
            ]
            if not self._requests[key]:
                del self._requests[key]
    
    def is_rate_limited(
        self, 
        key: str, 
        max_requests: int, 
        window_seconds: int = 60
    ) -> tuple[bool, int, int]:
        """
        Check if request is rate limited.
        
        Returns:
            (is_limited, remaining_requests, retry_after_seconds)
        """
        current_time = time.time()
        self._cleanup_old_entries(window_seconds)
        
        # Get requests within window
        cutoff = current_time - window_seconds
        self._requests[key] = [
            ts for ts in self._requests[key] if ts > cutoff
        ]
        
        request_count = len(self._requests[key])
        
        if request_count >= max_requests:
            # Calculate retry after
            oldest = min(self._requests[key]) if self._requests[key] else current_time
            retry_after = int(oldest + window_seconds - current_time) + 1
            return True, 0, max(retry_after, 1)
        
        # Record this request
        self._requests[key].append(current_time)
        remaining = max_requests - request_count - 1
        
        return False, remaining, 0
    
    def get_key(self, request: Request, endpoint: Optional[str] = None) -> str:
        """Generate rate limit key from request."""
        # Get client IP (handle proxied requests)
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            ip = forwarded.split(",")[0].strip()
        else:
            ip = request.client.host if request.client else "unknown"
        
        if endpoint:
            return f"{ip}:{endpoint}"
        return ip


# Global rate limiter instance
_rate_limiter = InMemoryRateLimiter()


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Global rate limiting middleware.
    Applies default rate limit to all endpoints.
    """
    
    # Strict limits for sensitive endpoints
    STRICT_LIMITS = {
        "/auth/login": (5, 60),      # 5 requests per minute
        "/auth/register": (3, 60),   # 3 requests per minute  
        "/auth/guest": (10, 60),     # 10 requests per minute
        "/auth/refresh": (20, 60),   # 20 requests per minute
    }
    
    def __init__(
        self, 
        app, 
        default_limit: int = 60,
        window_seconds: int = 60,
        exclude_paths: list[str] = None
    ):
        super().__init__(app)
        self.default_limit = default_limit
        self.window_seconds = window_seconds
        self.exclude_paths = exclude_paths or ["/health", "/docs", "/redoc", "/openapi.json"]
    
    async def dispatch(self, request: Request, call_next):
        # Skip excluded paths
        if any(request.url.path.startswith(path) for path in self.exclude_paths):
            return await call_next(request)
        
        # Get rate limit for this path
        path = request.url.path.rstrip("/")
        if path in self.STRICT_LIMITS:
            limit, window = self.STRICT_LIMITS[path]
        else:
            limit, window = self.default_limit, self.window_seconds
        
        # Check rate limit with endpoint-specific key for strict endpoints
        if path in self.STRICT_LIMITS:
            key = _rate_limiter.get_key(request, endpoint=path)
        else:
            key = _rate_limiter.get_key(request)
        
        is_limited, remaining, retry_after = _rate_limiter.is_rate_limited(
            key, limit, window
        )
        
        if is_limited:
            return JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                content={
                    "success": False,
                    "error": "Rate limit exceeded",
                    "code": "RATE_LIMIT_EXCEEDED",
                    "details": {
                        "message": f"Too many requests. Please wait {retry_after} seconds.",
                        "retry_after": retry_after
                    }
                },
                headers={
                    "Retry-After": str(retry_after),
                    "X-RateLimit-Limit": str(limit),
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": str(int(time.time()) + retry_after)
                }
            )
        
        # Add rate limit headers to response
        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(limit)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        
        return response


class RateLimiter:
    """
    Decorator-based rate limiter for specific endpoints.
    
    Usage:
        @rate_limiter.limit("5/minute")
        async def login(request: Request):
            ...
    """
    
    def __init__(self):
        self._limiter = _rate_limiter
    
    def limit(self, limit_string: str):
        """
        Decorator to apply rate limit to endpoint.
        
        Args:
            limit_string: Format "N/period" where period is minute, hour, day
                         Examples: "5/minute", "100/hour", "1000/day"
        """
        max_requests, window_seconds = self._parse_limit(limit_string)
        
        def decorator(func: Callable):
            @wraps(func)
            async def wrapper(request: Request, *args, **kwargs):
                # Get endpoint-specific key
                key = self._limiter.get_key(request, endpoint=func.__name__)
                
                is_limited, remaining, retry_after = self._limiter.is_rate_limited(
                    key, max_requests, window_seconds
                )
                
                if is_limited:
                    raise HTTPException(
                        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                        detail={
                            "error": "Rate limit exceeded for this endpoint",
                            "code": "ENDPOINT_RATE_LIMIT",
                            "retry_after": retry_after,
                            "message": f"Too many requests. Try again in {retry_after} seconds."
                        },
                        headers={"Retry-After": str(retry_after)}
                    )
                
                return await func(request, *args, **kwargs)
            
            return wrapper
        return decorator
    
    def _parse_limit(self, limit_string: str) -> tuple[int, int]:
        """Parse limit string into (max_requests, window_seconds)."""
        parts = limit_string.lower().split("/")
        if len(parts) != 2:
            raise ValueError(f"Invalid limit format: {limit_string}")
        
        try:
            max_requests = int(parts[0])
        except ValueError:
            raise ValueError(f"Invalid request count: {parts[0]}")
        
        period = parts[1].strip()
        period_map = {
            "second": 1,
            "minute": 60,
            "hour": 3600,
            "day": 86400,
        }
        
        window_seconds = period_map.get(period)
        if window_seconds is None:
            raise ValueError(f"Invalid period: {period}. Use: second, minute, hour, day")
        
        return max_requests, window_seconds


# Global rate limiter for decorators
rate_limiter = RateLimiter()
