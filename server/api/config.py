"""
Steel Titans API - Configuration
================================
Configuración centralizada usando pydantic-settings.
"""

from functools import lru_cache
from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    """Configuración de la aplicación."""
    
    # Database
    database_url: str = "postgresql+asyncpg://steeltitans_api:password@localhost:5432/steeltitans"
    
    # Redis
    redis_url: str = "redis://localhost:6379/0"
    redis_session_ttl: int = 86400  # 24 horas en segundos
    redis_cache_ttl: int = 300  # 5 minutos en segundos
    redis_matchmaking_ttl: int = 180  # 3 minutos en segundos
    
    # JWT
    jwt_secret_key: str = "change_me_in_production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 30
    
    # API
    api_host: str = "0.0.0.0"
    api_port: int = 8080
    debug: bool = False
    allowed_origins: str = "*"
    
    # Rate limiting
    rate_limit_per_minute: int = 60
    
    # Game settings
    starting_c_bills: int = 10000
    starting_elo: int = 1000
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
    
    @property
    def cors_origins(self) -> List[str]:
        """Parse CORS origins."""
        if self.allowed_origins == "*":
            return ["*"]
        return [origin.strip() for origin in self.allowed_origins.split(",")]


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
