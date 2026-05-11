extends CharacterBody2D

signal player_died

# MOVEMENT CONST VARIABLES
const SPEED = 800.0 # how fast the player is
const JUMP_VELOCITY = -1500.0 # lower negative magnitude = higher and faster jump

const FALL_MULTIPLIER = 4 # gravity multiplier when falling
const LOW_JUMP_MULTIPLIER = 2.2 # gravity multiplier when jumping
const MAX_JUMPS = 2

# DASH  CONST VARIABLES
const DASH_SPEED = 2500.0 # higher -> travels faster
const DASH_TIME = 0.4 # higher -> more distance
const DASH_DECEL = 2000.0 # lower -> decelerate more/longer stop
const DASH_COOLDOWN = 0.5
const DASH_POST_INVULN_TIME = 0.12 # dash invincible frames

# COMBO CONST VARIABLES
const MAX_COMBO_STEPS = 3
const COMBO_RESET_TIME = 0.25

# HEALTH VARIABLES
@export var max_health: int = 100
var _current_health: int = 100

# COMBAT VARIABLES
var is_attacking = false

var _slash_has_hit: bool = false
var _combo_step: int = 0
var _queued_next_attack: bool = false
var _combo_timer: float = 0.0

var _slash_bases := {} # slash collision dict per slash

# MOVEMENT
var is_dashing = false

var _jumps_used: int = 0
var _dash_invuln_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0

# COLLISION
var _body_collision_layer: int = 0
var _body_collision_mask: int = 0

# CORE
var _death_emitted: bool = false
var _controls_enabled: bool = true
var _boss_ref: Node2D = null 

@onready var animated_sprite = $AnimatedSprite2D
@onready var slash1_area : Area2D = $SlashCollision1
@onready var slash2_area : Area2D = $SlashCollision2
@onready var slash3_area : Area2D = $SlashCollision3
@onready var dash_particles: GPUParticles2D = $DashParticles
@onready var slash1 : CollisionPolygon2D = $SlashCollision1/CollisionPolygon2D
@onready var slash2 : CollisionPolygon2D = $SlashCollision2/CollisionPolygon2D
@onready var slash3 : CollisionPolygon2D = $SlashCollision3/CollisionPolygon2D

func _ready() -> void:
	_current_health = max_health
	_death_emitted = false
	_controls_enabled = true
	if not is_in_group("player"):
		add_to_group("player")
	_jumps_used = 0
	_dash_invuln_timer = 0.0
	_dash_cooldown_timer = 0.0
	_body_collision_layer = collision_layer
	_body_collision_mask = collision_mask
	_slash_bases = {
		slash1_area: { "pos": slash1_area.position, "scale": slash1_area.scale },
		slash2_area: { "pos": slash2_area.position, "scale": slash2_area.scale },
		slash3_area: { "pos": slash3_area.position, "scale": slash3_area.scale }
	}
	_set_solid_collision_enabled(true)
	_set_slash_collision_enabled(false)
	_update_slash_collision_transform()
	_sync_player_hud_health()

# play animation helper function so there is no animation overlap
func play_anim(name: String, force_restart: bool = false):
	if animated_sprite.animation != name:
		animated_sprite.play(name)
	
	# if force restart (for 2x jump), specify the frame restart to 0
	if force_restart:
		animated_sprite.frame = 0
		animated_sprite.play(name) 

func start_dash(direction):
	is_dashing = true
	_dash_cooldown_timer = DASH_COOLDOWN
	
	# if no input, dash based on facing direction
	if direction == 0:
		direction = -1 if animated_sprite.flip_h else 1
		 
	# get direction player is facing before emitting particles
	dash_particles.scale.x = direction 
	dash_particles.emitting = true
	
	velocity.x = direction * DASH_SPEED
	_dash_invuln_timer = maxf(_dash_invuln_timer, DASH_TIME + DASH_POST_INVULN_TIME)
	
	play_anim("dash")
	AudioController.play_player_dash()
	
	await get_tree().create_timer(DASH_TIME).timeout
	
	is_dashing = false
	dash_particles.emitting = false # turn off particles

func start_attack():
	if is_attacking:
		return
		
	is_attacking = true
	_slash_has_hit = false
	_queued_next_attack = false
	
	var direction := Input.get_axis("moveLeft", "moveRight")
	
	if direction == 0:
		direction = -1 if animated_sprite.flip_h else 1
	
	# apply forward lunge ONLY if pressing forward
	if direction != 0:
		velocity.x = direction * 1200  # tweak this value
	
	if not is_on_floor():
		# while attacking mid air, if velocity.y = 0 = hover, 50 = brakes completely, small number = hover
		velocity.y = 30.0
	
	# advance combo
	_combo_step += 1
	if _combo_step > MAX_COMBO_STEPS:
		_combo_step = 1
	
	# reset timer
	_combo_timer = COMBO_RESET_TIME
	
	# stop movement slightly
	velocity.x *= 0.3
	
	# enable hitboxes for slash
	_set_slash_collision_enabled(true)
	
	AudioController.play_player_slash_1()
	
	# play correct animation
	var anim_name = "slash_" + str(_combo_step)
	play_anim(anim_name)
	
	await animated_sprite.animation_finished
	
	if not is_attacking: # return if no longer attacking (like if jump interrupts)
		return
	
	# disable hitbox for slash
	_set_slash_collision_enabled(false)
	is_attacking = false
	
	if _queued_next_attack:
		_queued_next_attack = false
		start_attack()

func _physics_process(delta: float) -> void:
	if not _controls_enabled:
		velocity = Vector2.ZERO
		is_dashing = false
		is_attacking = false
		_dash_invuln_timer = 0.0
		_set_solid_collision_enabled(true)
		_set_slash_collision_enabled(false)
		move_and_slide()
		return

	if _dash_invuln_timer > 0.0:
		_dash_invuln_timer = maxf(_dash_invuln_timer - delta, 0.0)
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)

	if not is_attacking and _combo_step > 0:
		_combo_timer = maxf(_combo_timer - delta, 0.0)
		if _combo_timer <= 0.0:
			_combo_step = 0
			
	if not is_dashing:
		dash_particles.emitting = false

	# gravity
	if not is_on_floor():
		var current_gravity = get_gravity()
		
		
		if is_attacking: # reduce gravity when attacking mid-air
			velocity += current_gravity * 0.2 * delta 
		elif velocity.y > 0:
			velocity += current_gravity * FALL_MULTIPLIER * delta
		else:
			velocity += current_gravity * LOW_JUMP_MULTIPLIER * delta

	if Input.is_action_just_pressed("jump"):
		if is_on_floor() or _jumps_used < MAX_JUMPS - 1:
			# these lines cancel attacks when clicking jump
			is_attacking = false
			_queued_next_attack = false
			_set_slash_collision_enabled(false) 
			
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
				_jumps_used = 0
			else:
				velocity.y = JUMP_VELOCITY
				_jumps_used += 1
			play_anim("jump", true)

	var direction := Input.get_axis("moveLeft", "moveRight")

	if Input.is_action_just_pressed("dash") and not is_dashing and _dash_cooldown_timer <= 0.0:
		start_dash(direction)
		
	if Input.is_action_just_pressed("slash"):
		if is_attacking and animated_sprite.frame >= 5:
			_queued_next_attack = true
		else:
			start_attack()

	# Movement
	if is_attacking:
		velocity.x = move_toward(velocity.x, 0, DASH_DECEL * delta)
	elif is_dashing:
		velocity.x = move_toward(velocity.x, 0, DASH_DECEL * delta)
	else:
		if direction != 0:
			velocity.x = direction * SPEED
			animated_sprite.flip_h = direction < 0
			
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			
		_update_slash_collision_transform()
			
	# Animation (PRIORITY-BASED)
	if is_attacking:
		play_anim("slash_" + str(_combo_step))
	elif is_dashing:
		play_anim("dash")
	elif not is_on_floor():
			play_anim("jump")
	else:
		if direction != 0:
			play_anim("run")
		else:
			play_anim("idle")

	move_and_slide()
	_process_slash_hits()

func take_damage(amount: int = 1) -> void:
	if _dash_invuln_timer > 0.0:
		return
	var safe_amount: int = maxi(amount, 0)
	_current_health = clampi(_current_health - safe_amount, 0, max_health)
	_sync_player_hud_health()
	print("Player HP -> ", _current_health, "/", max_health)
	if _current_health <= 0 and not _death_emitted:
		_death_emitted = true
		player_died.emit()

func get_current_health() -> int:
	return _current_health

func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not _controls_enabled:
		velocity = Vector2.ZERO
		is_dashing = false
		is_attacking = false
		_dash_invuln_timer = 0.0
		_dash_cooldown_timer = 0.0
		_set_solid_collision_enabled(true)
		_set_slash_collision_enabled(false)

func _set_solid_collision_enabled(enabled: bool) -> void:
	if enabled:
		collision_layer = _body_collision_layer
		collision_mask = _body_collision_mask
	else:
		collision_layer = 0
		collision_mask = 0

func _disable_all_slash_collisions():
	slash1.disabled = true
	slash2.disabled = true
	slash3.disabled = true

func _sync_player_hud_health() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var hud: Node = current_scene.find_child("HUD", true, false)
	if hud != null and hud.has_method("set_player_health"):
		hud.call("set_player_health", _current_health, max_health)

func _set_slash_collision_enabled(enabled: bool) -> void:
	_disable_all_slash_collisions()
	
	if not enabled:
		return

	match _combo_step:
		1:
			slash1.disabled = false
		2:
			slash2.disabled = false
		3:
			slash3.disabled = false

func _update_slash_collision_transform() -> void:
	var facing_sign: float = -1.0 if animated_sprite.flip_h else 1.0
	
	for area in _slash_bases.keys():
		var base = _slash_bases[area]
		
		area.position = Vector2(base["pos"].x * facing_sign, base["pos"].y)
		area.scale = Vector2(base["scale"].x * facing_sign, base["scale"].y)

func _process_slash_hits() -> void:
	if not is_attacking or _slash_has_hit:
		return

	var boss: Node2D = _get_boss_ref()
	if boss == null or not is_instance_valid(boss):
		return
	if not _is_boss_hit_target(boss):
		return

	# Always ask boss to evaluate the slash polygon — boss handles per-node checks
	var poly := _get_slash_world_polygon()
	if poly.size() >= 3:
		if boss.has_method("apply_slash_hits"):
			boss.call("apply_slash_hits", poly)
			_slash_has_hit = true
		else:
			# Fallback for bosses that don't implement apply_slash_hits:
			# only apply fallback damage when the slash actually overlaps the boss
			if _is_boss_overlapping_slash(boss) and boss.has_method("take_damage"):
				boss.call("take_damage", 10)
				_slash_has_hit = true

func _get_boss_ref() -> Node2D:
	if _boss_ref != null and is_instance_valid(_boss_ref):
		return _boss_ref

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null

	var named_boss: Node2D = current_scene.find_child("BubbleBoss", true, false) as Node2D
	if named_boss != null:
		_boss_ref = named_boss
		return _boss_ref

	var fallback: Node = _find_first_descendant_with_boss_defeated(current_scene)
	if fallback is Node2D:
		_boss_ref = fallback as Node2D
		return _boss_ref

	return null

func _find_first_descendant_with_boss_defeated(root: Node) -> Node:
	if root.has_signal("boss_defeated") and root.has_method("take_damage"):
		return root
	for child in root.get_children():
		var found: Node = _find_first_descendant_with_boss_defeated(child)
		if found != null:
			return found
	return null

func _is_boss_hit_target(candidate: Node) -> bool:
	if candidate == null:
		return false
	if candidate == self or is_ancestor_of(candidate):
		return false
	if not candidate.has_method("take_damage"):
		return false
	# Avoid damaging non-combat props that may also expose take_damage.
	if candidate.name == "BubbleBoss":
		return true
	return candidate.has_signal("boss_defeated")

func _is_boss_overlapping_slash(boss: Node2D) -> bool:
	var active = _get_active_slash_collision()
	if active == null:
		return false

	var world_polygon: PackedVector2Array = _get_slash_world_polygon()
	if world_polygon.size() < 3:
		return false

	var boss_center: Vector2 = boss.global_position
	if Geometry2D.is_point_in_polygon(boss_center, world_polygon):
		return true

	var boss_radius: float = _estimate_body_radius(boss)
	if boss_radius <= 0.0:
		boss_radius = 1.0

	for i in range(world_polygon.size()):
		var a: Vector2 = world_polygon[i]
		var b: Vector2 = world_polygon[(i + 1) % world_polygon.size()]
		if _distance_point_to_segment(boss_center, a, b) <= boss_radius:
			return true

	return false

func _get_active_slash_collision() -> CollisionPolygon2D:
	match _combo_step:
		1: return slash1
		2: return slash2
		3: return slash3
	return null

func _get_slash_world_polygon() -> PackedVector2Array:
	var active = _get_active_slash_collision()
	if active == null:
		return PackedVector2Array()

	var local_polygon = active.polygon
	var world_polygon: PackedVector2Array = PackedVector2Array()
	world_polygon.resize(local_polygon.size())
	
	for i in range(local_polygon.size()):
		world_polygon[i] = active.to_global(local_polygon[i])
	
	return world_polygon

func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.000001:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return point.distance_to(closest)

func _estimate_body_radius(target: Node) -> float:
	if target == null:
		return 0.0

	for child in target.get_children():
		var shape_node: CollisionShape2D = child as CollisionShape2D
		if shape_node == null or shape_node.shape == null:
			continue

		var local_scale: Vector2 = shape_node.global_scale
		var scale_factor: float = maxf(absf(local_scale.x), absf(local_scale.y))

		if shape_node.shape is CircleShape2D:
			var circle: CircleShape2D = shape_node.shape as CircleShape2D
			return circle.radius * scale_factor

		if shape_node.shape is CapsuleShape2D:
			var capsule: CapsuleShape2D = shape_node.shape as CapsuleShape2D
			return (capsule.height * 0.5 + capsule.radius) * scale_factor

		if shape_node.shape is RectangleShape2D:
			var rect: RectangleShape2D = shape_node.shape as RectangleShape2D
			return rect.size.length() * 0.5 * scale_factor

	return 0.0

func reset_for_retry(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_current_health = max_health
	_death_emitted = false
	is_dashing = false
	is_attacking = false
	_queued_next_attack = false
	_combo_step = 0
	_combo_timer = 0.0
	_jumps_used = 0
	_dash_invuln_timer = 0.0
	_dash_cooldown_timer = 0.0
	_set_solid_collision_enabled(true)
	_set_slash_collision_enabled(false)
	_sync_player_hud_health()
