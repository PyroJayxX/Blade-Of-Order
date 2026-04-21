extends CharacterBody2D

signal player_died

const SPEED = 800.0 # how fast the player is
const JUMP_VELOCITY = -1200.0 # higher magnitude = higher and faster jump

const FALL_MULTIPLIER = 4 # gravity multiplier when falling
const LOW_JUMP_MULTIPLIER = 2.2 # gravity multiplier when jumping
const MAX_JUMPS = 2

const DASH_SPEED = 2500.0 # higher -> travels faster
const DASH_TIME = 0.4 # higher -> more distance
const DASH_COOLDOWN = 0.5
const DASH_DECEL = 2000.0 # lower -> decelerate more/longer stop
const DASH_POST_INVULN_TIME = 0.12
const MAX_COMBO_STEPS = 3
const COMBO_RESET_TIME = 0.45

var is_dashing = false
var is_attacking = false
@export var max_health: int = 100
var _current_health: int = 100
var _slash_has_hit: bool = false
var _combo_step: int = 0
var _queued_next_attack: bool = false
var _combo_timer: float = 0.0
var _death_emitted: bool = false
var _controls_enabled: bool = true
var _jumps_used: int = 0
var _dash_invuln_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _body_collision_layer: int = 0
var _body_collision_mask: int = 0
 
@onready var animated_sprite = $AnimatedSprite2D
@onready var slash_collision: CollisionPolygon2D = $SlashCollision

func _ready() -> void:
	_current_health = max_health
	_death_emitted = false
	_controls_enabled = true
	_jumps_used = 0
	_dash_invuln_timer = 0.0
	_dash_cooldown_timer = 0.0
	_body_collision_layer = collision_layer
	_body_collision_mask = collision_mask
	_set_solid_collision_enabled(true)
	_set_slash_collision_enabled(false)
	_sync_player_hud_health()

func start_dash(direction):
	is_dashing = true
	_dash_cooldown_timer = DASH_COOLDOWN
	
	# if no input, dash based on facing direction
	if direction == 0:
		direction = -1 if animated_sprite.flip_h else 1
	
	velocity.x = direction * DASH_SPEED
	_dash_invuln_timer = maxf(_dash_invuln_timer, DASH_TIME + DASH_POST_INVULN_TIME)
	
	animated_sprite.play("dash")
	AudioController.play_player_dash()
	
	await get_tree().create_timer(DASH_TIME).timeout
	
	is_dashing = false

func start_attack():
	if is_attacking:
		return
	
	is_attacking = true
	_slash_has_hit = false
	
	# stop movement slightly
	velocity.x *= 0.3
	
	AudioController.play_player_slash_1()
	
	animated_sprite.play("slash_1")
	
	await animated_sprite.animation_finished
	
	_set_slash_collision_enabled(false)
	is_attacking = false

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

	# gravity
	if not is_on_floor():
		if velocity.y > 0:
			velocity += get_gravity() * FALL_MULTIPLIER * delta
		else:
			velocity += get_gravity() * LOW_JUMP_MULTIPLIER * delta
	else:
		_jumps_used = 0
	
	if Input.is_action_just_pressed("jump") and _jumps_used < MAX_JUMPS:
		velocity.y = JUMP_VELOCITY 
		_jumps_used += 1

	var direction := Input.get_axis("moveLeft", "moveRight")

	if Input.is_action_just_pressed("dash") and not is_dashing and _dash_cooldown_timer <= 0.0:
		start_dash(direction)
		
	if Input.is_action_just_pressed("slash"):
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
			
	# Animation (PRIORITY-BASED)
	if is_attacking:
		animated_sprite.play("slash_1")
	elif is_dashing:
		animated_sprite.play("dash")
	elif not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("jump")
	else:
		if direction != 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")

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

func _sync_player_hud_health() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var hud: Node = current_scene.get_node_or_null("HUD")
	if hud != null and hud.has_method("set_player_health"):
		hud.call("set_player_health", _current_health, max_health)

func _set_slash_collision_enabled(enabled: bool) -> void:
	if slash_collision == null:
		return
	slash_collision.disabled = not enabled

func _process_slash_hits() -> void:
	if not is_attacking or _slash_has_hit:
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var boss: Node2D = current_scene.get_node_or_null("BubbleBoss") as Node2D
	if boss == null or not is_instance_valid(boss):
		return
	if not _is_boss_hit_target(boss):
		return

	if _is_boss_overlapping_slash(boss):
		boss.call("take_damage", 10, false)
		_slash_has_hit = true

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
	if slash_collision == null:
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

func _get_slash_world_polygon() -> PackedVector2Array:
	var local_polygon: PackedVector2Array = slash_collision.polygon
	var world_polygon: PackedVector2Array = PackedVector2Array()
	world_polygon.resize(local_polygon.size())
	for i in range(local_polygon.size()):
		world_polygon[i] = slash_collision.to_global(local_polygon[i])
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
