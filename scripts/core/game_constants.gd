extends RefCounted
class_name GameConstants

## Constantes del juego Battletech
## Este archivo contiene valores constantes compartidos
## IMPORTANTE: Esta clase solo contiene constantes

## Constantes de combate
const BASE_TARGET_NUMBER: int = 8  # Número objetivo base para to-hit

## Constantes de calor
const DEFAULT_HEAT_CAPACITY: int = 30
const DEFAULT_HEAT_DISSIPATION: int = 10
const SHUTDOWN_THRESHOLD: int = 30
const AMMO_EXPLOSION_START: int = 19

## Constantes de movimiento
const MIN_MOVEMENT_POINTS: int = 1  # MP mínimo que siempre tiene un mech

## Constantes de daño físico
const PUNCH_DAMAGE_DIVISOR: float = 10.0  # Tonelaje / 10
const KICK_DAMAGE_DIVISOR: float = 5.0    # Tonelaje / 5
const CHARGE_DAMAGE_MULTIPLIER: float = 1.0  # (Tonelaje / 10) * hexes
const CHARGE_SELF_DAMAGE_DIVISOR: int = 10   # Daño de carga / 10

## Modificadores de ataque
const KICK_TO_HIT_MODIFIER: int = 2  # +2 más difícil que puñetazo
const CHARGE_TO_HIT_MODIFIER: int = 1  # +1 más difícil

## Modificadores de movimiento al disparar
const WALK_ATTACK_MODIFIER: int = 0   # Sin penalización
const RUN_ATTACK_MODIFIER: int = 2    # +2 al disparar
const JUMP_ATTACK_MODIFIER: int = 3   # +3 al disparar

## Modificadores de defensa por movimiento
const RUN_DEFENSE_BONUS: int = 1   # +1 TMM al correr
const JUMP_DEFENSE_BONUS: int = 2  # +2 TMM al saltar

## Modificadores de rango
const SHORT_RANGE_MODIFIER: int = 0
const MEDIUM_RANGE_MODIFIER: int = 2
const LONG_RANGE_MODIFIER: int = 4

## Colores para UI
const COLOR_PLAYER: Color = Color.GREEN
const COLOR_ENEMY: Color = Color.RED
const COLOR_NEUTRAL: Color = Color.GRAY
const COLOR_DESTROYED: Color = Color.DARK_GRAY

const COLOR_HEAT_LOW: Color = Color.CYAN
const COLOR_HEAT_MEDIUM: Color = Color.YELLOW
const COLOR_HEAT_HIGH: Color = Color.ORANGE
const COLOR_HEAT_CRITICAL: Color = Color.RED

## Configuración de hex grid
const DEFAULT_HEX_SIZE: float = 64.0
const DEFAULT_GRID_WIDTH: int = 12
const DEFAULT_GRID_HEIGHT: int = 16

## Timing para animaciones y IA
const AI_THINK_DELAY: float = 0.5
const PHASE_TRANSITION_DELAY: float = 0.2
const HEAT_DISPLAY_DELAY: float = 2.0

## Debug settings
const ENABLE_DEBUG_LOGS: bool = true
const ENABLE_PHASE_LOGS: bool = true
const ENABLE_ACTIVATION_LOGS: bool = true
