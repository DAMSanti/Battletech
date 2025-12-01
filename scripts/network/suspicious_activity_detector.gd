# suspicious_activity_detector.gd
# Monitors and flags suspicious player behavior for anti-cheat
# Part of the server-side security system
class_name SuspiciousActivityDetector
extends RefCounted

## SuspiciousActivityDetector - Tracks anomalous behavior patterns
## This runs on the server to detect potential cheating attempts

# ============================================================
# CONSTANTS & THRESHOLDS
# ============================================================

## Thresholds for suspicious behavior
const MAX_ACTIONS_PER_SECOND: float = 5.0  # Normal human limit
const MAX_INVALID_ACTIONS_PER_MINUTE: int = 10  # Too many fails = suspicious
const MAX_IMPOSSIBLE_ACTIONS: int = 3  # Instant ban threshold
const SUSPICION_DECAY_TIME: float = 300.0  # 5 minutes to decay suspicion

## Action categories
enum ActionCategory {
	MOVEMENT,
	ATTACK,
	WEAPON_SELECT,
	TARGET_SELECT,
	PHASE_CHANGE,
	CHAT
}

## Suspicion levels
enum SuspicionLevel {
	NONE = 0,
	LOW = 1,       # Logging only
	MEDIUM = 2,    # Rate limit actions
	HIGH = 3,      # Require verification
	CRITICAL = 4   # Temporary ban
}

# ============================================================
# PLAYER TRACKING DATA
# ============================================================

class PlayerActivityRecord:
	var peer_id: int = 0
	var username: String = ""
	var suspicion_score: float = 0.0
	var last_activity_time: float = 0.0
	var actions_this_second: int = 0
	var invalid_actions_this_minute: int = 0
	var impossible_actions: int = 0
	var action_history: Array[Dictionary] = []  # Last N actions for pattern analysis
	var flagged_reasons: Array[String] = []
	var last_reset_time: float = 0.0
	
	const MAX_HISTORY_SIZE: int = 100
	
	func record_action(action_type: ActionCategory, was_valid: bool, details: Dictionary = {}) -> void:
		var now := Time.get_ticks_msec() / 1000.0
		
		# Reset per-second counter
		if now - last_activity_time >= 1.0:
			actions_this_second = 0
		
		# Reset per-minute counter
		if now - last_reset_time >= 60.0:
			invalid_actions_this_minute = 0
			last_reset_time = now
		
		actions_this_second += 1
		if not was_valid:
			invalid_actions_this_minute += 1
		
		last_activity_time = now
		
		# Add to history
		action_history.append({
			"type": action_type,
			"valid": was_valid,
			"time": now,
			"details": details
		})
		
		# Trim history
		if action_history.size() > MAX_HISTORY_SIZE:
			action_history.pop_front()
	
	func get_actions_per_second() -> float:
		return float(actions_this_second)
	
	func add_flag(reason: String) -> void:
		if reason not in flagged_reasons:
			flagged_reasons.append(reason)
	
	func get_suspicion_level() -> SuspicionLevel:
		if suspicion_score >= 100.0:
			return SuspicionLevel.CRITICAL
		elif suspicion_score >= 70.0:
			return SuspicionLevel.HIGH
		elif suspicion_score >= 40.0:
			return SuspicionLevel.MEDIUM
		elif suspicion_score >= 20.0:
			return SuspicionLevel.LOW
		return SuspicionLevel.NONE


# ============================================================
# STATE
# ============================================================

var _player_records: Dictionary = {}  # peer_id -> PlayerActivityRecord
var _banned_peers: Dictionary = {}  # peer_id -> ban_expiry_time
var _log_callback: Callable  # Optional callback for logging


func _init(log_callback: Callable = Callable()) -> void:
	_log_callback = log_callback


# ============================================================
# PUBLIC API
# ============================================================

## Record an action and check for suspicious behavior
## Returns: Dictionary with "allowed", "suspicion_level", and optional "reason"
func record_action(
	peer_id: int,
	action_type: ActionCategory,
	was_valid: bool,
	details: Dictionary = {}
) -> Dictionary:
	
	# Check if banned
	if is_banned(peer_id):
		return {
			"allowed": false,
			"suspicion_level": SuspicionLevel.CRITICAL,
			"reason": "Player is temporarily banned"
		}
	
	# Get or create record
	var record := _get_or_create_record(peer_id)
	
	# Record the action
	record.record_action(action_type, was_valid, details)
	
	# Run detection checks
	var result := _analyze_behavior(record, action_type, was_valid, details)
	
	# Apply suspicion decay
	_decay_suspicion(record)
	
	# Log if suspicious
	if record.get_suspicion_level() >= SuspicionLevel.MEDIUM:
		_log("Suspicious activity from peer %d: level=%d, score=%.1f, reasons=%s" % [
			peer_id, 
			record.get_suspicion_level(),
			record.suspicion_score,
			record.flagged_reasons
		])
	
	return result


## Check if a player is currently banned
func is_banned(peer_id: int) -> bool:
	if not _banned_peers.has(peer_id):
		return false
	
	var ban_expiry: float = _banned_peers[peer_id]
	var now := Time.get_ticks_msec() / 1000.0
	
	if now >= ban_expiry:
		_banned_peers.erase(peer_id)
		return false
	
	return true


## Get remaining ban time in seconds
func get_ban_remaining(peer_id: int) -> float:
	if not is_banned(peer_id):
		return 0.0
	
	var now := Time.get_ticks_msec() / 1000.0
	return maxf(0.0, _banned_peers[peer_id] - now)


## Get suspicion level for a player
func get_suspicion_level(peer_id: int) -> SuspicionLevel:
	if not _player_records.has(peer_id):
		return SuspicionLevel.NONE
	return _player_records[peer_id].get_suspicion_level()


## Get detailed report for a player
func get_player_report(peer_id: int) -> Dictionary:
	if not _player_records.has(peer_id):
		return {"peer_id": peer_id, "status": "no_data"}
	
	var record: PlayerActivityRecord = _player_records[peer_id]
	return {
		"peer_id": peer_id,
		"suspicion_score": record.suspicion_score,
		"suspicion_level": record.get_suspicion_level(),
		"invalid_actions_this_minute": record.invalid_actions_this_minute,
		"impossible_actions": record.impossible_actions,
		"flagged_reasons": record.flagged_reasons,
		"is_banned": is_banned(peer_id),
		"ban_remaining": get_ban_remaining(peer_id)
	}


## Clear all data (for testing or match end)
func clear_all() -> void:
	_player_records.clear()
	_banned_peers.clear()


## Remove a specific player's record
func clear_player(peer_id: int) -> void:
	_player_records.erase(peer_id)


# ============================================================
# INTERNAL ANALYSIS
# ============================================================

func _get_or_create_record(peer_id: int) -> PlayerActivityRecord:
	if not _player_records.has(peer_id):
		var record := PlayerActivityRecord.new()
		record.peer_id = peer_id
		record.last_reset_time = Time.get_ticks_msec() / 1000.0
		_player_records[peer_id] = record
	return _player_records[peer_id]


func _analyze_behavior(
	record: PlayerActivityRecord,
	_action_type: ActionCategory,
	_was_valid: bool,
	details: Dictionary
) -> Dictionary:
	
	var result := {
		"allowed": true,
		"suspicion_level": SuspicionLevel.NONE,
		"reason": ""
	}
	
	# Check 1: Action rate (bot detection)
	if record.get_actions_per_second() > MAX_ACTIONS_PER_SECOND:
		record.suspicion_score += 5.0
		record.add_flag("excessive_action_rate")
		result["reason"] = "Action rate too high"
	
	# Check 2: Too many invalid actions (probing detection)
	if record.invalid_actions_this_minute > MAX_INVALID_ACTIONS_PER_MINUTE:
		record.suspicion_score += 10.0
		record.add_flag("many_invalid_actions")
		result["reason"] = "Too many invalid actions"
	
	# Check 3: Impossible actions (definite cheat attempt)
	if details.get("impossible", false):
		record.impossible_actions += 1
		record.suspicion_score += 50.0
		record.add_flag("impossible_action")
		result["reason"] = "Impossible action detected"
		
		if record.impossible_actions >= MAX_IMPOSSIBLE_ACTIONS:
			_apply_ban(record.peer_id, 300.0)  # 5 minute ban
	
	# Check 4: Pattern analysis (same action repeated unnaturally)
	if _detect_repetitive_pattern(record):
		record.suspicion_score += 15.0
		record.add_flag("repetitive_pattern")
	
	# Update result based on suspicion level
	result["suspicion_level"] = record.get_suspicion_level()
	
	# If critical, don't allow action
	if result["suspicion_level"] == SuspicionLevel.CRITICAL:
		result["allowed"] = false
		_apply_ban(record.peer_id, 300.0)
	
	return result


func _detect_repetitive_pattern(record: PlayerActivityRecord) -> bool:
	"""Detect unnatural repetitive patterns (bot behavior)."""
	if record.action_history.size() < 10:
		return false
	
	# Check last 10 actions for exact time intervals (bot signature)
	var intervals: Array[float] = []
	for i in range(1, mini(10, record.action_history.size())):
		var delta: float = record.action_history[-i]["time"] - record.action_history[-i-1]["time"]
		intervals.append(delta)
	
	if intervals.is_empty():
		return false
	
	# Calculate variance - very low variance = bot
	var mean: float = 0.0
	for interval in intervals:
		mean += interval
	mean /= intervals.size()
	
	var variance: float = 0.0
	for interval in intervals:
		variance += pow(interval - mean, 2)
	variance /= intervals.size()
	
	# Extremely consistent timing (variance < 0.001) is suspicious
	return variance < 0.001 and mean < 0.5


func _decay_suspicion(record: PlayerActivityRecord) -> void:
	"""Gradually reduce suspicion over time."""
	var now := Time.get_ticks_msec() / 1000.0
	var time_since_activity := now - record.last_activity_time
	
	# Decay 1 point per 30 seconds of inactivity
	var decay := time_since_activity / 30.0
	record.suspicion_score = maxf(0.0, record.suspicion_score - decay)


func _apply_ban(peer_id: int, duration_seconds: float) -> void:
	"""Apply a temporary ban to a player."""
	var now := Time.get_ticks_msec() / 1000.0
	_banned_peers[peer_id] = now + duration_seconds
	_log("BANNED peer %d for %.0f seconds" % [peer_id, duration_seconds])


func _log(message: String) -> void:
	"""Log a message using callback or print."""
	if _log_callback.is_valid():
		_log_callback.call(message)
	else:
		print("[AntiCheat] ", message)
