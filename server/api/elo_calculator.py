"""
Steel Titans API - ELO Calculator
==================================
Sistema de cálculo de ELO para matchmaking competitivo.
Basado en el sistema Elo estándar con ajustes para juegos por equipos.
"""

from dataclasses import dataclass
from typing import List, Optional, Tuple
from enum import Enum
import math


# Constantes exportables
STARTING_ELO = 1000
MIN_ELO = 100
MAX_ELO = 3000

# Rangos de ELO
RANKS = [
    {"name": "Recruit", "tier": 1, "min_elo": 0, "max_elo": 500},
    {"name": "Cadet", "tier": 2, "min_elo": 500, "max_elo": 800},
    {"name": "MechWarrior", "tier": 3, "min_elo": 800, "max_elo": 1000},
    {"name": "Veteran", "tier": 4, "min_elo": 1000, "max_elo": 1200},
    {"name": "Elite", "tier": 5, "min_elo": 1200, "max_elo": 1400},
    {"name": "Star Captain", "tier": 6, "min_elo": 1400, "max_elo": 1600},
    {"name": "Star Colonel", "tier": 7, "min_elo": 1600, "max_elo": 1800},
    {"name": "Galaxy Commander", "tier": 8, "min_elo": 1800, "max_elo": 2000},
    {"name": "Khan", "tier": 9, "min_elo": 2000, "max_elo": 2200},
    {"name": "ilKhan", "tier": 10, "min_elo": 2200, "max_elo": 2500},
    {"name": "Kerensky", "tier": 11, "min_elo": 2500, "max_elo": 2800},
    {"name": "Kerensky Prime", "tier": 12, "min_elo": 2800, "max_elo": MAX_ELO + 1},
]


class MatchResult(Enum):
    """Resultado posible de una partida."""
    WIN = 1.0
    DRAW = 0.5
    LOSS = 0.0


@dataclass
class PlayerMatchData:
    """Datos de un jugador para cálculo de ELO."""
    user_id: str
    elo_before: int
    team: int
    result: Optional[MatchResult] = None
    kills: int = 0
    deaths: int = 0
    damage_dealt: int = 0
    mechs_destroyed: int = 0


@dataclass
class EloChange:
    """Resultado del cálculo de ELO para un jugador."""
    user_id: str
    elo_before: int
    elo_after: int
    elo_change: int
    performance_bonus: int = 0


class EloCalculator:
    """
    Calculador de ELO para Steel Titans.
    
    Características:
    - K-Factor dinámico basado en número de partidas
    - Bonus/penalización por rendimiento individual
    - Soporte para partidas en equipo
    - Límites de cambio para evitar volatilidad extrema
    """
    
    # Configuración base
    BASE_K_FACTOR = 32          # K-factor estándar
    MIN_K_FACTOR = 16           # K mínimo para veteranos
    MAX_K_FACTOR = 48           # K máximo para nuevos jugadores
    
    # Umbrales de partidas para K-factor
    PROVISIONAL_GAMES = 10      # Partidas hasta ser "provisional"
    ESTABLISHED_GAMES = 30      # Partidas hasta ser "establecido"
    
    # Límites de cambio
    MIN_ELO = 100               # ELO mínimo posible
    MAX_ELO = 3000              # ELO máximo posible
    MAX_CHANGE_PER_GAME = 64    # Cambio máximo por partida
    
    # Bonus por rendimiento
    PERFORMANCE_WEIGHT = 0.2    # Peso del bonus de rendimiento (20%)
    MAX_PERFORMANCE_BONUS = 10  # Bonus máximo por buen rendimiento
    
    # ELO inicial
    STARTING_ELO = 1000
    
    def __init__(
        self,
        base_k: int = BASE_K_FACTOR,
        performance_enabled: bool = True
    ):
        """
        Inicializa el calculador.
        
        Args:
            base_k: K-factor base
            performance_enabled: Si se aplican bonus por rendimiento
        """
        self.base_k = base_k
        self.performance_enabled = performance_enabled
    
    def get_k_factor(self, elo: int, games_played: int) -> float:
        """
        Calcula el K-factor dinámico.
        
        - Nuevos jugadores (< 10 partidas): K alto para ajuste rápido
        - Jugadores establecidos (> 30 partidas): K bajo para estabilidad
        - ELO alto (> 2000): K reducido para más estabilidad
        
        Args:
            elo: ELO actual del jugador
            games_played: Número de partidas jugadas
            
        Returns:
            K-factor a aplicar
        """
        # Base K según experiencia
        if games_played < self.PROVISIONAL_GAMES:
            k = self.MAX_K_FACTOR
        elif games_played < self.ESTABLISHED_GAMES:
            # Transición lineal
            progress = (games_played - self.PROVISIONAL_GAMES) / (self.ESTABLISHED_GAMES - self.PROVISIONAL_GAMES)
            k = self.MAX_K_FACTOR - (self.MAX_K_FACTOR - self.base_k) * progress
        else:
            k = self.base_k
        
        # Reducción adicional para ELO alto
        if elo > 2000:
            k = max(self.MIN_K_FACTOR, k * 0.75)
        elif elo > 2500:
            k = max(self.MIN_K_FACTOR, k * 0.5)
        
        return k
    
    def expected_score(self, player_elo: int, opponent_elo: int) -> float:
        """
        Calcula la probabilidad esperada de victoria.
        
        Usa la fórmula estándar de Elo:
        E = 1 / (1 + 10^((opponent_elo - player_elo) / 400))
        
        Args:
            player_elo: ELO del jugador
            opponent_elo: ELO del oponente
            
        Returns:
            Probabilidad de victoria (0.0 - 1.0)
        """
        exponent = (opponent_elo - player_elo) / 400.0
        return 1.0 / (1.0 + math.pow(10, exponent))
    
    def calculate_performance_bonus(
        self,
        player: PlayerMatchData,
        team_avg_elo: int,
        enemy_avg_elo: int
    ) -> int:
        """
        Calcula bonus/penalización por rendimiento individual.
        
        Factores considerados:
        - K/D ratio
        - Daño dealt vs promedio esperado
        - Mechs destruidos
        
        Args:
            player: Datos del jugador
            team_avg_elo: ELO promedio del equipo
            enemy_avg_elo: ELO promedio enemigo
            
        Returns:
            Bonus de ELO (puede ser negativo)
        """
        if not self.performance_enabled:
            return 0
        
        bonus = 0.0
        
        # K/D ratio bonus (máx +/- 3)
        if player.deaths > 0:
            kd_ratio = player.kills / player.deaths
            if kd_ratio > 2.0:
                bonus += 3
            elif kd_ratio > 1.5:
                bonus += 2
            elif kd_ratio > 1.0:
                bonus += 1
            elif kd_ratio < 0.5:
                bonus -= 2
            elif kd_ratio < 0.75:
                bonus -= 1
        elif player.kills > 0:
            bonus += 3  # Sin muertes y con kills
        
        # Bonus por mechs destruidos (máx +3)
        if player.mechs_destroyed >= 3:
            bonus += 3
        elif player.mechs_destroyed >= 2:
            bonus += 2
        elif player.mechs_destroyed >= 1:
            bonus += 1
        
        # Ajuste por diferencia de ELO (luchar contra mejores = más bonus)
        elo_diff = enemy_avg_elo - team_avg_elo
        if elo_diff > 200:
            bonus += 2
        elif elo_diff > 100:
            bonus += 1
        elif elo_diff < -200:
            bonus -= 1
        
        # Limitar bonus total
        return int(max(-self.MAX_PERFORMANCE_BONUS, min(self.MAX_PERFORMANCE_BONUS, bonus)))
    
    def calculate_1v1(
        self,
        winner: PlayerMatchData,
        loser: PlayerMatchData,
        winner_games: int = 50,
        loser_games: int = 50,
        is_draw: bool = False
    ) -> Tuple[EloChange, EloChange]:
        """
        Calcula cambios de ELO para partida 1v1.
        
        Args:
            winner: Datos del ganador
            loser: Datos del perdedor
            winner_games: Partidas totales del ganador
            loser_games: Partidas totales del perdedor
            is_draw: Si la partida terminó en empate
            
        Returns:
            Tupla (cambio_ganador, cambio_perdedor)
        """
        # Resultado
        if is_draw:
            winner_score = 0.5
            loser_score = 0.5
        else:
            winner_score = 1.0
            loser_score = 0.0
        
        # Expectativas
        winner_expected = self.expected_score(winner.elo_before, loser.elo_before)
        loser_expected = self.expected_score(loser.elo_before, winner.elo_before)
        
        # K-factors
        winner_k = self.get_k_factor(winner.elo_before, winner_games)
        loser_k = self.get_k_factor(loser.elo_before, loser_games)
        
        # Cambios base
        winner_change = int(winner_k * (winner_score - winner_expected))
        loser_change = int(loser_k * (loser_score - loser_expected))
        
        # Performance bonus
        winner_bonus = self.calculate_performance_bonus(
            winner, winner.elo_before, loser.elo_before
        )
        loser_bonus = self.calculate_performance_bonus(
            loser, loser.elo_before, winner.elo_before
        )
        
        # Aplicar límites
        winner_total = self._clamp_change(winner_change + winner_bonus)
        loser_total = self._clamp_change(loser_change + loser_bonus)
        
        # Calcular nuevos ELOs
        winner_new = self._clamp_elo(winner.elo_before + winner_total)
        loser_new = self._clamp_elo(loser.elo_before + loser_total)
        
        return (
            EloChange(
                user_id=winner.user_id,
                elo_before=winner.elo_before,
                elo_after=winner_new,
                elo_change=winner_new - winner.elo_before,
                performance_bonus=winner_bonus
            ),
            EloChange(
                user_id=loser.user_id,
                elo_before=loser.elo_before,
                elo_after=loser_new,
                elo_change=loser_new - loser.elo_before,
                performance_bonus=loser_bonus
            )
        )
    
    def calculate_team_match(
        self,
        players: List[PlayerMatchData],
        winning_team: int,
        games_played: dict = None
    ) -> List[EloChange]:
        """
        Calcula cambios de ELO para partida en equipo (2v2, 4v4).
        
        Usa el ELO promedio del equipo para el cálculo base,
        pero aplica bonus individual por rendimiento.
        
        Args:
            players: Lista de todos los jugadores
            winning_team: Número del equipo ganador (1 o 2), 0 para empate
            games_played: Diccionario {user_id: games_played}
            
        Returns:
            Lista de cambios de ELO para cada jugador
        """
        if games_played is None:
            games_played = {}
        
        # Separar equipos
        team1 = [p for p in players if p.team == 1]
        team2 = [p for p in players if p.team == 2]
        
        if not team1 or not team2:
            return []
        
        # Calcular ELO promedio de cada equipo
        team1_avg = sum(p.elo_before for p in team1) // len(team1)
        team2_avg = sum(p.elo_before for p in team2) // len(team2)
        
        results = []
        
        for player in players:
            # Determinar resultado
            if winning_team == 0:
                score = 0.5  # Empate
            elif player.team == winning_team:
                score = 1.0  # Victoria
            else:
                score = 0.0  # Derrota
            
            # ELO del equipo y enemigo
            if player.team == 1:
                team_avg = team1_avg
                enemy_avg = team2_avg
            else:
                team_avg = team2_avg
                enemy_avg = team1_avg
            
            # Expectativa basada en promedios de equipo
            expected = self.expected_score(team_avg, enemy_avg)
            
            # K-factor individual
            player_games = games_played.get(player.user_id, 50)
            k = self.get_k_factor(player.elo_before, player_games)
            
            # Cambio base
            base_change = int(k * (score - expected))
            
            # Performance bonus individual
            perf_bonus = self.calculate_performance_bonus(player, team_avg, enemy_avg)
            
            # Total con límites
            total_change = self._clamp_change(base_change + perf_bonus)
            new_elo = self._clamp_elo(player.elo_before + total_change)
            
            results.append(EloChange(
                user_id=player.user_id,
                elo_before=player.elo_before,
                elo_after=new_elo,
                elo_change=new_elo - player.elo_before,
                performance_bonus=perf_bonus
            ))
        
        return results
    
    def _clamp_change(self, change: int) -> int:
        """Limita el cambio de ELO por partida."""
        return max(-self.MAX_CHANGE_PER_GAME, min(self.MAX_CHANGE_PER_GAME, change))
    
    def _clamp_elo(self, elo: int) -> int:
        """Limita el ELO a los rangos válidos."""
        return max(self.MIN_ELO, min(self.MAX_ELO, elo))
    
    @staticmethod
    def get_rank_name(elo: int) -> str:
        """
        Obtiene el nombre del rango basado en ELO.
        
        Args:
            elo: Puntuación ELO
            
        Returns:
            Nombre del rango
        """
        if elo < 500:
            return "Recruit"
        elif elo < 800:
            return "Cadet"
        elif elo < 1000:
            return "MechWarrior"
        elif elo < 1200:
            return "Veteran"
        elif elo < 1400:
            return "Elite"
        elif elo < 1600:
            return "Star Captain"
        elif elo < 1800:
            return "Star Colonel"
        elif elo < 2000:
            return "Galaxy Commander"
        elif elo < 2200:
            return "Khan"
        elif elo < 2500:
            return "ilKhan"
        else:
            return "Kerensky"
    
    @staticmethod
    def get_rank_tier(elo: int) -> int:
        """
        Obtiene el tier numérico (1-12) basado en ELO.
        
        Args:
            elo: Puntuación ELO
            
        Returns:
            Tier numérico
        """
        if elo < 500:
            return 1
        elif elo < 800:
            return 2
        elif elo < 1000:
            return 3
        elif elo < 1200:
            return 4
        elif elo < 1400:
            return 5
        elif elo < 1600:
            return 6
        elif elo < 1800:
            return 7
        elif elo < 2000:
            return 8
        elif elo < 2200:
            return 9
        elif elo < 2500:
            return 10
        elif elo < 2800:
            return 11
        else:
            return 12
    
    @staticmethod
    def get_rank_for_elo(elo: int) -> dict:
        """
        Obtiene información completa del rango.
        
        Args:
            elo: Puntuación ELO
            
        Returns:
            Dict con name, tier, min_elo
        """
        for rank in RANKS:
            if elo < rank.get("max_elo", MAX_ELO + 1):
                return {
                    "name": rank["name"],
                    "tier": rank["tier"],
                    "min_elo": rank["min_elo"]
                }
        # Máximo rango
        return {
            "name": RANKS[-1]["name"],
            "tier": RANKS[-1]["tier"],
            "min_elo": RANKS[-1]["min_elo"]
        }
    
    def calculate_match(
        self,
        winner_elo: int,
        loser_elo: int,
        winner_games_played: int = 50,
        loser_games_played: int = 50,
        is_draw: bool = False,
        winner_performance: Optional[dict] = None,
        loser_performance: Optional[dict] = None
    ) -> "MatchEloResult":
        """
        Calcula cambios de ELO para una partida 1v1 (API simplificada).
        
        Args:
            winner_elo: ELO del ganador
            loser_elo: ELO del perdedor
            winner_games_played: Partidas del ganador
            loser_games_played: Partidas del perdedor
            is_draw: Si fue empate
            winner_performance: Stats opcionales del ganador
            loser_performance: Stats opcionales del perdedor
            
        Returns:
            MatchEloResult con los cambios
        """
        # Crear PlayerMatchData
        winner = PlayerMatchData(
            user_id="winner",
            elo_before=winner_elo,
            team=1,
            kills=winner_performance.get("kills", 0) if winner_performance else 0,
            deaths=winner_performance.get("deaths", 0) if winner_performance else 0,
            mechs_destroyed=winner_performance.get("mechs_destroyed", 0) if winner_performance else 0
        )
        loser = PlayerMatchData(
            user_id="loser",
            elo_before=loser_elo,
            team=2,
            kills=loser_performance.get("kills", 0) if loser_performance else 0,
            deaths=loser_performance.get("deaths", 0) if loser_performance else 0,
            mechs_destroyed=loser_performance.get("mechs_destroyed", 0) if loser_performance else 0
        )
        
        winner_change, loser_change = self.calculate_1v1(
            winner, loser, winner_games_played, loser_games_played, is_draw
        )
        
        return MatchEloResult(
            winner_new_elo=winner_change.elo_after,
            winner_elo_change=winner_change.elo_change,
            loser_new_elo=loser_change.elo_after,
            loser_elo_change=loser_change.elo_change
        )


@dataclass
class MatchEloResult:
    """Resultado simplificado de cálculo de ELO para una partida."""
    winner_new_elo: int
    winner_elo_change: int
    loser_new_elo: int
    loser_elo_change: int


# Instancia global
elo_calculator = EloCalculator()
