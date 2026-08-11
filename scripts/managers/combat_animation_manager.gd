## CombatAnimationManager - Manages visual effects for weapon attacks
## Handles projectile animations, hit/miss effects, and muzzle flashes
class_name CombatAnimationManager
extends RefCounted

# Signals
signal animation_started(attacker: Node2D, target: Node2D, weapon_type: String)
signal animation_completed(hit: bool)

# Projectile textures by weapon category
var _projectile_textures: Dictionary = {}
var _impact_textures: Dictionary = {}
var _muzzle_flash_texture: Texture2D = null

# Animation settings
const PROJECTILE_SPEED: float = 800.0  # pixels per second
const MISSILE_SPEED: float = 400.0  # slower for missiles
const GAUSS_SPEED: float = 1200.0  # very fast
const LASER_DURATION: float = 0.3  # lasers are instant beams
const IMPACT_DURATION: float = 0.5
const MUZZLE_FLASH_DURATION: float = 0.15

# Reference to the scene for creating nodes
var _scene_tree: SceneTree = null
var _parent_node: Node2D = null

# Weapon type to projectile mapping
enum ProjectileType {
	LASER,
	PPC,
	BALLISTIC,
	MISSILE,
	GAUSS
}


func _init() -> void:
	_load_textures()


func set_scene_tree(tree: SceneTree) -> void:
	_scene_tree = tree
	Log.info("CombatAnimation", "Scene tree set: %s" % (tree != null))


func set_parent_node(parent: Node2D) -> void:
	_parent_node = parent
	Log.info("CombatAnimation", "Parent node set: %s" % (str(parent.name) if parent else "null"))


func _load_textures() -> void:
	"""Load all projectile and impact textures"""
	# Projectiles
	var laser_path = "res://assets/sprites/effects/projectile_laser.svg"
	if ResourceLoader.exists(laser_path):
		_projectile_textures[ProjectileType.LASER] = load(laser_path)
		Log.debug("CombatAnimation", "Loaded LASER texture: %s" % _projectile_textures[ProjectileType.LASER])
	else:
		Log.error("CombatAnimation", "LASER texture not found: %s" % laser_path)
	
	if ResourceLoader.exists("res://assets/sprites/effects/projectile_ppc.svg"):
		_projectile_textures[ProjectileType.PPC] = load("res://assets/sprites/effects/projectile_ppc.svg")
	if ResourceLoader.exists("res://assets/sprites/effects/projectile_ballistic.svg"):
		_projectile_textures[ProjectileType.BALLISTIC] = load("res://assets/sprites/effects/projectile_ballistic.svg")
	if ResourceLoader.exists("res://assets/sprites/effects/projectile_missile.svg"):
		_projectile_textures[ProjectileType.MISSILE] = load("res://assets/sprites/effects/projectile_missile.svg")
	if ResourceLoader.exists("res://assets/sprites/effects/projectile_gauss.svg"):
		_projectile_textures[ProjectileType.GAUSS] = load("res://assets/sprites/effects/projectile_gauss.svg")
	
	# Impacts
	var hit_path = "res://assets/sprites/effects/impact_hit.svg"
	if ResourceLoader.exists(hit_path):
		_impact_textures["hit"] = load(hit_path)
		Log.debug("CombatAnimation", "Loaded HIT impact texture: %s" % _impact_textures["hit"])
	else:
		Log.error("CombatAnimation", "HIT impact not found: %s" % hit_path)
	
	if ResourceLoader.exists("res://assets/sprites/effects/impact_miss.svg"):
		_impact_textures["miss"] = load("res://assets/sprites/effects/impact_miss.svg")
	if ResourceLoader.exists("res://assets/sprites/effects/impact_critical.svg"):
		_impact_textures["critical"] = load("res://assets/sprites/effects/impact_critical.svg")
	
	# Muzzle flash
	if ResourceLoader.exists("res://assets/sprites/effects/muzzle_flash.svg"):
		_muzzle_flash_texture = load("res://assets/sprites/effects/muzzle_flash.svg")
		Log.debug("CombatAnimation", "Loaded muzzle flash texture: %s" % _muzzle_flash_texture)
	
	Log.info("CombatAnimation", "Loaded %d projectile types, %d impact types, muzzle=%s" % [_projectile_textures.size(), _impact_textures.size(), _muzzle_flash_texture != null])


func get_projectile_type_for_weapon(weapon: Dictionary) -> ProjectileType:
	"""Determine projectile type based on weapon properties"""
	var weapon_name: String = weapon.get("name", "").to_lower()
	var weapon_type: String = weapon.get("type", "").to_lower()
	
	# Check for specific weapon types
	if "laser" in weapon_name or "laser" in weapon_type:
		return ProjectileType.LASER
	elif "ppc" in weapon_name or "particle" in weapon_name:
		return ProjectileType.PPC
	elif "gauss" in weapon_name:
		return ProjectileType.GAUSS
	elif "lrm" in weapon_name or "srm" in weapon_name or "missile" in weapon_name or "mml" in weapon_name:
		return ProjectileType.MISSILE
	elif "ac" in weapon_name or "autocannon" in weapon_name or "machine gun" in weapon_name or "mg" in weapon_name or "ultra" in weapon_name or "lb " in weapon_name:
		return ProjectileType.BALLISTIC
	else:
		# Default to ballistic for unknown weapons
		return ProjectileType.BALLISTIC


func play_attack_animation(attacker: Node2D, target: Node2D, weapon: Dictionary, hit: bool, is_critical: bool = false) -> void:
	"""Play the complete attack animation sequence"""
	Log.info("CombatAnimation", "play_attack_animation called: parent=%s, tree=%s" % [_parent_node != null, _scene_tree != null])
	
	if not _parent_node or not _scene_tree:
		Log.warning("CombatAnimation", "Cannot play animation - no parent node or scene tree")
		animation_completed.emit(hit)
		return
	
	var start_pos: Vector2 = attacker.global_position
	var end_pos: Vector2 = target.global_position
	var projectile_type = get_projectile_type_for_weapon(weapon)
	
	Log.info("CombatAnimation", "Animating %s from %s to %s (type=%d)" % [weapon.get("name", "Unknown"), start_pos, end_pos, projectile_type])
	
	animation_started.emit(attacker, target, weapon.get("name", "Unknown"))
	
	# Play muzzle flash
	_play_muzzle_flash(start_pos, end_pos)
	
	# Play projectile animation based on type
	match projectile_type:
		ProjectileType.LASER, ProjectileType.PPC:
			await _play_beam_animation(start_pos, end_pos, projectile_type)
		ProjectileType.MISSILE:
			await _play_projectile_animation(start_pos, end_pos, projectile_type, MISSILE_SPEED)
		ProjectileType.GAUSS:
			await _play_projectile_animation(start_pos, end_pos, projectile_type, GAUSS_SPEED)
		_:
			await _play_projectile_animation(start_pos, end_pos, projectile_type, PROJECTILE_SPEED)
	
	# Play impact effect
	if hit:
		if is_critical:
			_play_impact_effect(end_pos, "critical")
		else:
			_play_impact_effect(end_pos, "hit")
	else:
		# Miss effect - slightly offset from target
		var miss_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		_play_impact_effect(end_pos + miss_offset, "miss")
	
	# Wait for impact effect to finish
	if _scene_tree:
		await _scene_tree.create_timer(IMPACT_DURATION).timeout
	
	animation_completed.emit(hit)


func _play_muzzle_flash(start_pos: Vector2, end_pos: Vector2) -> void:
	"""Show muzzle flash at attacker position"""
	if not _muzzle_flash_texture or not _parent_node:
		Log.warning("CombatAnimation", "Cannot play muzzle flash - texture=%s, parent=%s" % [_muzzle_flash_texture != null, _parent_node != null])
		return
	
	var flash = Sprite2D.new()
	flash.texture = _muzzle_flash_texture
	flash.z_index = 1000  # Very high to ensure visibility
	flash.scale = Vector2(3.0, 3.0)  # Start bigger for visibility
	flash.modulate = Color(1, 1, 1, 1)  # Fully visible
	
	# Rotate to face target
	var direction = (end_pos - start_pos).normalized()
	flash.rotation = direction.angle()
	
	# Add to scene FIRST, then set global position
	_parent_node.add_child(flash)
	flash.global_position = start_pos
	
	Log.info("CombatAnimation", "MUZZLE FLASH: pos=%s, z=%d, in_tree=%s" % [start_pos, flash.z_index, flash.is_inside_tree()])
	
	# Animate flash
	var tween = flash.create_tween()
	tween.tween_property(flash, "scale", Vector2(4.0, 4.0), MUZZLE_FLASH_DURATION * 0.3)
	tween.tween_property(flash, "modulate:a", 0.0, MUZZLE_FLASH_DURATION * 0.7)
	tween.tween_callback(flash.queue_free)


func _play_beam_animation(start_pos: Vector2, end_pos: Vector2, projectile_type: ProjectileType) -> void:
	"""Play laser/PPC beam animation (instant beam that fades)"""
	if not _projectile_textures.has(projectile_type) or not _parent_node:
		Log.warning("CombatAnimation", "Cannot play beam - texture=%s, parent=%s" % [_projectile_textures.has(projectile_type), _parent_node != null])
		if _scene_tree:
			await _scene_tree.create_timer(0.1).timeout
		return
	
	var beam = Sprite2D.new()
	beam.texture = _projectile_textures[projectile_type]
	beam.z_index = 1000  # VERY high z-index to be above everything
	
	# Calculate beam properties
	var direction = (end_pos - start_pos).normalized()
	var distance = start_pos.distance_to(end_pos)
	var mid_point = (start_pos + end_pos) / 2
	
	beam.rotation = direction.angle()
	
	# Scale beam to cover distance
	var texture_width = beam.texture.get_width()
	beam.scale.x = distance / texture_width
	beam.scale.y = 4.0  # Make beam MORE visible (was 3.0)
	
	# Start FULLY VISIBLE (not invisible)
	beam.modulate = Color(1, 1, 1, 1)
	
	# Add to scene FIRST, then set global position
	_parent_node.add_child(beam)
	beam.global_position = mid_point
	
	Log.info("CombatAnimation", "BEAM CREATED: pos=%s, scale=%s, z=%d, visible=%s, in_tree=%s" % [beam.global_position, beam.scale, beam.z_index, beam.visible, beam.is_inside_tree()])
	
	# Animate beam: stay visible, then fade out
	var tween = beam.create_tween()
	tween.tween_interval(LASER_DURATION * 0.6)  # Stay visible
	tween.tween_property(beam, "modulate:a", 0.0, LASER_DURATION * 0.4)  # Fade out
	tween.tween_callback(beam.queue_free)
	
	if _scene_tree:
		await _scene_tree.create_timer(LASER_DURATION).timeout


func _play_projectile_animation(start_pos: Vector2, end_pos: Vector2, projectile_type: ProjectileType, speed: float) -> void:
	"""Play projectile traveling animation"""
	if not _projectile_textures.has(projectile_type) or not _parent_node:
		Log.warning("CombatAnimation", "Cannot play projectile - texture=%s, parent=%s" % [_projectile_textures.has(projectile_type), _parent_node != null])
		if _scene_tree:
			await _scene_tree.create_timer(0.1).timeout
		return
	
	var projectile = Sprite2D.new()
	projectile.texture = _projectile_textures[projectile_type]
	projectile.z_index = 1000  # Very high z-index
	projectile.scale = Vector2(3.0, 3.0)  # Bigger for visibility
	projectile.modulate = Color(1, 1, 1, 1)  # Fully visible
	
	# Rotate to face direction
	var direction = (end_pos - start_pos).normalized()
	projectile.rotation = direction.angle()
	
	# Add to scene FIRST, then set position
	_parent_node.add_child(projectile)
	projectile.global_position = start_pos
	
	# Calculate travel time
	var distance = start_pos.distance_to(end_pos)
	var travel_time = distance / speed
	
	Log.info("CombatAnimation", "PROJECTILE: pos=%s->%s, z=%d, in_tree=%s, time=%.2fs" % [start_pos, end_pos, projectile.z_index, projectile.is_inside_tree(), travel_time])
	
	# For missiles, add slight arc
	if projectile_type == ProjectileType.MISSILE:
		var mid_point = (start_pos + end_pos) / 2
		var perpendicular = Vector2(-direction.y, direction.x) * (distance * 0.15)
		mid_point += perpendicular
		
		# Two-step tween for arc
		var tween = projectile.create_tween()
		tween.tween_property(projectile, "global_position", mid_point, travel_time * 0.5)\
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(projectile, "global_position", end_pos, travel_time * 0.5)\
			.set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(projectile, "rotation", direction.angle(), travel_time)
		tween.tween_callback(projectile.queue_free)
	else:
		# Straight line for other projectiles
		var tween = projectile.create_tween()
		tween.tween_property(projectile, "global_position", end_pos, travel_time)\
			.set_ease(Tween.EASE_IN)
		tween.tween_callback(projectile.queue_free)
	
	if _scene_tree:
		await _scene_tree.create_timer(travel_time).timeout


func _play_impact_effect(pos: Vector2, impact_type: String) -> void:
	"""Play impact effect at position"""
	if not _impact_textures.has(impact_type) or not _parent_node:
		Log.warning("CombatAnimation", "Cannot play impact - texture=%s, parent=%s" % [_impact_textures.has(impact_type), _parent_node != null])
		return
	
	var impact = Sprite2D.new()
	impact.texture = _impact_textures[impact_type]
	
	# MUST add to scene tree BEFORE setting global_position
	_parent_node.add_child(impact)
	
	impact.global_position = pos
	impact.z_index = 1000  # Very high to be visible
	impact.scale = Vector2(1.5, 1.5)  # Start bigger for visibility (was 0.3)
	impact.modulate = Color(1, 1, 1, 1)  # Start FULLY VISIBLE (was 0)
	
	Log.info("CombatAnimation", "IMPACT CREATED: type=%s, pos=%s, z=%d, visible=%s, in_tree=%s" % [impact_type, pos, impact.z_index, impact.visible, impact.is_inside_tree()])
	
	# Different animations for hit vs miss
	var tween = impact.create_tween()
	
	if impact_type == "miss":
		# Miss: stay visible, grow slightly, then fade
		tween.tween_property(impact, "scale", Vector2(2.0, 2.0), 0.2)
		tween.tween_interval(0.1)
		tween.tween_property(impact, "modulate:a", 0.0, 0.3)
		tween.tween_callback(impact.queue_free)
	elif impact_type == "critical":
		# Critical: big dramatic explosion
		tween.tween_property(impact, "scale", Vector2(3.0, 3.0), 0.15)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_interval(0.3)
		tween.tween_property(impact, "modulate:a", 0.0, 0.4)
		tween.parallel().tween_property(impact, "scale", Vector2(4.0, 4.0), 0.4)
		tween.tween_callback(impact.queue_free)
	else:
		# Normal hit: medium impact
		tween.tween_property(impact, "scale", Vector2(2.5, 2.5), 0.15)\
			.set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.15)
		tween.tween_property(impact, "modulate:a", 0.0, 0.3)
		tween.parallel().tween_property(impact, "scale", Vector2(3.0, 3.0), 0.3)
		tween.tween_callback(impact.queue_free)


func play_multi_missile_animation(attacker: Node2D, target: Node2D, missile_count: int, hits: int) -> void:
	"""Play animation for LRM/SRM salvos with multiple missiles"""
	if not _parent_node or not _scene_tree:
		animation_completed.emit(hits > 0)
		return
	
	var start_pos: Vector2 = attacker.global_position
	var end_pos: Vector2 = target.global_position
	
	animation_started.emit(attacker, target, "Missile Salvo")
	_play_muzzle_flash(start_pos, end_pos)
	
	# Launch missiles in waves
	var missiles_per_wave = mini(4, missile_count)
	var waves = ceili(float(missile_count) / missiles_per_wave)
	var hits_remaining = hits
	
	for wave in range(waves):
		var missiles_this_wave = mini(missiles_per_wave, missile_count - wave * missiles_per_wave)
		
		for i in range(missiles_this_wave):
			# Stagger missile launches
			var delay = randf_range(0.0, 0.1)
			if _scene_tree:
				await _scene_tree.create_timer(delay).timeout
			
			# Random offset for each missile
			var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
			var missile_target = end_pos + offset
			
			# Determine if this missile hits
			var this_hits = hits_remaining > 0
			if this_hits:
				hits_remaining -= 1
			
			# Fire missile (don't await each one - let them fly in parallel)
			_fire_single_missile(start_pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 
								  missile_target, this_hits)
		
		# Small delay between waves
		if wave < waves - 1 and _scene_tree:
			await _scene_tree.create_timer(0.15).timeout
	
	# Wait for all missiles to arrive
	var distance = start_pos.distance_to(end_pos)
	var travel_time = distance / MISSILE_SPEED
	if _scene_tree:
		await _scene_tree.create_timer(travel_time + 0.3).timeout
	
	animation_completed.emit(hits > 0)


func _fire_single_missile(start_pos: Vector2, end_pos: Vector2, hits: bool) -> void:
	"""Fire a single missile without waiting"""
	if not _projectile_textures.has(ProjectileType.MISSILE) or not _parent_node:
		Log.warning("CombatAnimation", "Cannot fire missile - texture=%s, parent=%s" % [_projectile_textures.has(ProjectileType.MISSILE), _parent_node != null])
		return
	
	var missile = Sprite2D.new()
	missile.texture = _projectile_textures[ProjectileType.MISSILE]
	
	# MUST add to scene tree BEFORE setting global_position
	_parent_node.add_child(missile)
	
	missile.global_position = start_pos
	missile.z_index = 1000  # Same as other projectiles
	missile.scale = Vector2(3.0, 3.0)  # Larger for visibility
	missile.modulate = Color(1, 1, 1, 1)  # Fully visible
	
	var direction = (end_pos - start_pos).normalized()
	missile.rotation = direction.angle()
	
	var distance = start_pos.distance_to(end_pos)
	var travel_time = distance / MISSILE_SPEED
	
	Log.info("CombatAnimation", "MISSILE FIRED: from=%s to=%s, z=%d, travel_time=%.2fs" % [start_pos, end_pos, missile.z_index, travel_time])
	
	# Arc trajectory
	var mid_point = (start_pos + end_pos) / 2
	var perpendicular = Vector2(-direction.y, direction.x) * (distance * randf_range(0.1, 0.2))
	mid_point += perpendicular
	
	var tween = missile.create_tween()
	tween.tween_property(missile, "global_position", mid_point, travel_time * 0.5)
	tween.tween_property(missile, "global_position", end_pos, travel_time * 0.5)
	tween.tween_callback(func():
		missile.queue_free()
		if hits:
			_play_impact_effect(end_pos, "hit")
		else:
			_play_impact_effect(end_pos + Vector2(randf_range(-15, 15), randf_range(-15, 15)), "miss")
	)
