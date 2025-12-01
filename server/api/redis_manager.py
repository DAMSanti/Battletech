"""
Steel Titans API - Redis Manager
================================
Gestión de Redis para sesiones, cache y matchmaking.
"""

import json
import logging
from typing import Optional, Any, Dict, List
from datetime import datetime
import redis.asyncio as redis
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


class RedisManager:
    """
    Manager para operaciones de Redis.
    Maneja sesiones de usuario, cache y cola de matchmaking.
    """
    
    _instance: Optional['RedisManager'] = None
    _redis: Optional[redis.Redis] = None
    
    # Prefijos de keys para organización
    PREFIX_SESSION = "session:"
    PREFIX_CACHE = "cache:"
    PREFIX_USER = "user:"
    PREFIX_MATCHMAKING = "mm:"
    PREFIX_RATE_LIMIT = "rate:"
    
    def __new__(cls) -> 'RedisManager':
        """Singleton pattern."""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    async def connect(self) -> None:
        """Establece conexión con Redis."""
        if self._redis is None:
            try:
                self._redis = redis.from_url(
                    settings.redis_url,
                    encoding="utf-8",
                    decode_responses=True
                )
                # Test connection
                await self._redis.ping()
                logger.info("Redis connected successfully")
            except Exception as e:
                logger.error(f"Failed to connect to Redis: {e}")
                self._redis = None
                raise
    
    async def disconnect(self) -> None:
        """Cierra la conexión con Redis."""
        if self._redis:
            await self._redis.close()
            self._redis = None
            logger.info("Redis disconnected")
    
    async def is_connected(self) -> bool:
        """Verifica si la conexión está activa."""
        if self._redis is None:
            return False
        try:
            await self._redis.ping()
            return True
        except Exception:
            return False
    
    # ============================================================
    # SESSION MANAGEMENT
    # ============================================================
    
    async def create_session(
        self,
        user_id: str,
        session_data: Dict[str, Any],
        ttl: Optional[int] = None
    ) -> str:
        """
        Crea una nueva sesión para un usuario.
        
        Args:
            user_id: ID del usuario
            session_data: Datos de la sesión (tokens, etc.)
            ttl: Tiempo de vida en segundos (default: config)
            
        Returns:
            Session key
        """
        if not self._redis:
            raise ConnectionError("Redis not connected")
        
        ttl = ttl or settings.redis_session_ttl
        key = f"{self.PREFIX_SESSION}{user_id}"
        
        session_data["created_at"] = datetime.utcnow().isoformat()
        session_data["user_id"] = user_id
        
        await self._redis.setex(
            key,
            ttl,
            json.dumps(session_data)
        )
        
        logger.debug(f"Session created for user {user_id}")
        return key
    
    async def get_session(self, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Obtiene los datos de sesión de un usuario.
        
        Args:
            user_id: ID del usuario
            
        Returns:
            Datos de sesión o None si no existe
        """
        if not self._redis:
            return None
        
        key = f"{self.PREFIX_SESSION}{user_id}"
        data = await self._redis.get(key)
        
        if data:
            return json.loads(data)
        return None
    
    async def refresh_session(self, user_id: str, ttl: Optional[int] = None) -> bool:
        """
        Renueva el TTL de una sesión existente.
        
        Args:
            user_id: ID del usuario
            ttl: Nuevo TTL en segundos
            
        Returns:
            True si se renovó, False si no existía
        """
        if not self._redis:
            return False
        
        ttl = ttl or settings.redis_session_ttl
        key = f"{self.PREFIX_SESSION}{user_id}"
        
        return await self._redis.expire(key, ttl)
    
    async def delete_session(self, user_id: str) -> bool:
        """
        Elimina la sesión de un usuario (logout).
        
        Args:
            user_id: ID del usuario
            
        Returns:
            True si se eliminó, False si no existía
        """
        if not self._redis:
            return False
        
        key = f"{self.PREFIX_SESSION}{user_id}"
        result = await self._redis.delete(key)
        
        if result:
            logger.debug(f"Session deleted for user {user_id}")
        return result > 0
    
    async def is_session_valid(self, user_id: str) -> bool:
        """Verifica si una sesión existe y es válida."""
        if not self._redis:
            return False
        
        key = f"{self.PREFIX_SESSION}{user_id}"
        return await self._redis.exists(key) > 0
    
    # ============================================================
    # CACHE MANAGEMENT
    # ============================================================
    
    async def cache_set(
        self,
        key: str,
        value: Any,
        ttl: Optional[int] = None
    ) -> bool:
        """
        Guarda un valor en cache.
        
        Args:
            key: Clave del cache
            value: Valor a guardar (será serializado a JSON)
            ttl: Tiempo de vida en segundos
            
        Returns:
            True si se guardó correctamente
        """
        if not self._redis:
            return False
        
        ttl = ttl or settings.redis_cache_ttl
        full_key = f"{self.PREFIX_CACHE}{key}"
        
        try:
            await self._redis.setex(
                full_key,
                ttl,
                json.dumps(value)
            )
            return True
        except Exception as e:
            logger.error(f"Cache set error for {key}: {e}")
            return False
    
    async def cache_get(self, key: str) -> Optional[Any]:
        """
        Obtiene un valor del cache.
        
        Args:
            key: Clave del cache
            
        Returns:
            Valor deserializado o None
        """
        if not self._redis:
            return None
        
        full_key = f"{self.PREFIX_CACHE}{key}"
        data = await self._redis.get(full_key)
        
        if data:
            return json.loads(data)
        return None
    
    async def cache_delete(self, key: str) -> bool:
        """Elimina un valor del cache."""
        if not self._redis:
            return False
        
        full_key = f"{self.PREFIX_CACHE}{key}"
        return await self._redis.delete(full_key) > 0
    
    async def cache_get_or_set(
        self,
        key: str,
        factory_func,
        ttl: Optional[int] = None
    ) -> Any:
        """
        Obtiene del cache o ejecuta factory_func y guarda el resultado.
        
        Args:
            key: Clave del cache
            factory_func: Función async que genera el valor si no está en cache
            ttl: Tiempo de vida
            
        Returns:
            Valor del cache o generado
        """
        cached = await self.cache_get(key)
        if cached is not None:
            return cached
        
        value = await factory_func()
        await self.cache_set(key, value, ttl)
        return value
    
    # ============================================================
    # USER DATA CACHE
    # ============================================================
    
    async def cache_user_data(self, user_id: str, data: Dict[str, Any]) -> bool:
        """Cache de datos de usuario (perfil, stats)."""
        key = f"{self.PREFIX_USER}{user_id}"
        return await self.cache_set(key, data)
    
    async def get_cached_user_data(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Obtiene datos de usuario del cache."""
        key = f"{self.PREFIX_USER}{user_id}"
        return await self.cache_get(key)
    
    async def invalidate_user_cache(self, user_id: str) -> bool:
        """Invalida el cache de un usuario."""
        key = f"{self.PREFIX_USER}{user_id}"
        return await self.cache_delete(key)
    
    # ============================================================
    # MATCHMAKING QUEUE
    # ============================================================
    
    async def add_to_matchmaking(
        self,
        user_id: str,
        elo: int,
        game_mode: str = "1v1"
    ) -> bool:
        """
        Añade un jugador a la cola de matchmaking.
        
        Args:
            user_id: ID del usuario
            elo: ELO del jugador
            game_mode: Modo de juego (1v1, 2v2, etc.)
            
        Returns:
            True si se añadió correctamente
        """
        if not self._redis:
            return False
        
        queue_key = f"{self.PREFIX_MATCHMAKING}queue:{game_mode}"
        player_key = f"{self.PREFIX_MATCHMAKING}player:{user_id}"
        
        player_data = {
            "user_id": user_id,
            "elo": elo,
            "game_mode": game_mode,
            "queued_at": datetime.utcnow().isoformat()
        }
        
        pipe = self._redis.pipeline()
        # Añadir al sorted set por ELO
        pipe.zadd(queue_key, {user_id: elo})
        # Guardar datos del jugador
        pipe.setex(player_key, settings.redis_matchmaking_ttl, json.dumps(player_data))
        
        await pipe.execute()
        logger.info(f"User {user_id} added to {game_mode} queue with ELO {elo}")
        return True
    
    async def remove_from_matchmaking(self, user_id: str, game_mode: str = "1v1") -> bool:
        """Elimina un jugador de la cola de matchmaking."""
        if not self._redis:
            return False
        
        queue_key = f"{self.PREFIX_MATCHMAKING}queue:{game_mode}"
        player_key = f"{self.PREFIX_MATCHMAKING}player:{user_id}"
        
        pipe = self._redis.pipeline()
        pipe.zrem(queue_key, user_id)
        pipe.delete(player_key)
        
        results = await pipe.execute()
        return results[0] > 0
    
    async def find_match(
        self,
        user_id: str,
        elo: int,
        game_mode: str = "1v1",
        elo_range: int = 200
    ) -> Optional[Dict[str, Any]]:
        """
        Busca un oponente en el rango de ELO.
        
        Args:
            user_id: ID del usuario buscando match
            elo: ELO del usuario
            game_mode: Modo de juego
            elo_range: Rango de ELO aceptable (+/-)
            
        Returns:
            Datos del oponente encontrado o None
        """
        if not self._redis:
            return None
        
        queue_key = f"{self.PREFIX_MATCHMAKING}queue:{game_mode}"
        
        # Buscar jugadores en el rango de ELO
        min_elo = elo - elo_range
        max_elo = elo + elo_range
        
        candidates = await self._redis.zrangebyscore(
            queue_key,
            min_elo,
            max_elo,
            withscores=True
        )
        
        # Filtrar self y buscar el más cercano en ELO
        best_match = None
        best_diff = float('inf')
        
        for candidate_id, candidate_elo in candidates:
            if candidate_id == user_id:
                continue
            
            diff = abs(candidate_elo - elo)
            if diff < best_diff:
                best_diff = diff
                player_key = f"{self.PREFIX_MATCHMAKING}player:{candidate_id}"
                data = await self._redis.get(player_key)
                if data:
                    best_match = json.loads(data)
        
        return best_match
    
    async def get_queue_size(self, game_mode: str = "1v1") -> int:
        """Obtiene el tamaño de la cola de matchmaking."""
        if not self._redis:
            return 0
        
        queue_key = f"{self.PREFIX_MATCHMAKING}queue:{game_mode}"
        return await self._redis.zcard(queue_key)
    
    # ============================================================
    # RATE LIMITING
    # ============================================================
    
    async def check_rate_limit(
        self,
        identifier: str,
        limit: int,
        window_seconds: int = 60
    ) -> tuple[bool, int]:
        """
        Verifica y actualiza el rate limit.
        
        Args:
            identifier: Identificador (IP, user_id, etc.)
            limit: Número máximo de requests
            window_seconds: Ventana de tiempo
            
        Returns:
            Tuple (allowed: bool, remaining: int)
        """
        if not self._redis:
            return True, limit  # Allow if Redis unavailable
        
        key = f"{self.PREFIX_RATE_LIMIT}{identifier}"
        
        pipe = self._redis.pipeline()
        pipe.incr(key)
        pipe.ttl(key)
        
        results = await pipe.execute()
        count = results[0]
        ttl = results[1]
        
        # Si es el primer request, setear TTL
        if ttl == -1:
            await self._redis.expire(key, window_seconds)
        
        remaining = max(0, limit - count)
        allowed = count <= limit
        
        return allowed, remaining
    
    # ============================================================
    # HEALTH & STATS
    # ============================================================
    
    async def health_check(self) -> Dict[str, Any]:
        """
        Health check de Redis.
        
        Returns:
            Dict con estado de Redis
        """
        if not self._redis:
            return {
                "status": "disconnected",
                "connected": False
            }
        
        try:
            info = await self._redis.info("memory")
            return {
                "status": "healthy",
                "connected": True,
                "memory_used": info.get("used_memory_human", "unknown"),
                "memory_peak": info.get("used_memory_peak_human", "unknown")
            }
        except Exception as e:
            return {
                "status": "error",
                "connected": False,
                "error": str(e)
            }
    
    async def get_stats(self) -> Dict[str, Any]:
        """Obtiene estadísticas de Redis."""
        if not self._redis:
            return {}
        
        try:
            info = await self._redis.info()
            return {
                "connected_clients": info.get("connected_clients", 0),
                "used_memory": info.get("used_memory_human", "unknown"),
                "total_commands": info.get("total_commands_processed", 0),
                "uptime_days": info.get("uptime_in_days", 0)
            }
        except Exception:
            return {}


# Global instance
redis_manager = RedisManager()


async def get_redis() -> RedisManager:
    """Dependency injection para FastAPI."""
    if not await redis_manager.is_connected():
        await redis_manager.connect()
    return redis_manager
