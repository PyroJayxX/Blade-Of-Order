extends Area2D

enum ProjectileMode {
	STRAIGHT,    # volley leaf, spore — uses direction vector
	FALLING,     # rain leaves — moves straight down
	RISING,      # ground spike — moves straight up, then stops
	HORIZONTAL,  # leaf wall — moves left or right at wall speed
	HOMING       # homing leaf — steers toward player each frame
}

# ── Shared exports ────────────────────────────────────────────────────────────
@export var mode: ProjectileMode = ProjectileMode.STRAIGHT
@export var speed: float = 480.0
@export var damage: int = 8
@export var lifetime: float = 10.0    # auto-destroy after this many seconds

# ── Homing-specific ───────────────────────────────────────────────────────────
@export var homing_turn_speed: float = 2.8  # radians per second turn rate
@export var homing_activation_delay: float = 0.15 # seconds before steering kicks in

# ── Rising-specific (ground spike) ───────────────────────────────────────────
@export var rise_distance: float = 120.0  # how far up the spike travels before stopping

# ── Runtime ───────────────────────────────────────────────────────────────────
var direction: Vector2 = Vector2.DOWN     # used by STRAIGHT, FALLING, RISING, HORIZONTAL
var target: Node2D = null                 # assigned by boss for HOMING mode

var _player_ref: Node2D = null
var _projectile_radius: float = 1.0
var _elapsed: float = 0.0
var _homing_locked_off: bool = false      # permanent one-way latch: true = fly straight forever
var _origin: Vector2 = Vector2.ZERO       # spawn position, used by RISING to cap distance

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_projectile_radius = _estimate_projectile_radius()
	_origin = global_position
	if mode == ProjectileMode.FALLING:
		rotation = randf_range(0.0, TAU)
		var rand_scale: float = randf_range(0.6, 1.2)
		scale = Vector2(rand_scale, rand_scale)
	if mode == ProjectileMode.FALLING or mode == ProjectileMode.HORIZONTAL or mode == ProjectileMode.RISING:
		var rand_scale: float = randf_range(0.3, 1.2)
		scale = Vector2(rand_scale, rand_scale)
	if mode == ProjectileMode.FALLING:
		rotation = randf_range(0.0, TAU)
	# Set initial direction based on mode
	match mode:
		ProjectileMode.FALLING:
			direction = Vector2.DOWN
		ProjectileMode.RISING:
			direction = Vector2.UP
		ProjectileMode.HOMING:
			# Start pointing at player if we have a target, otherwise down
			if target != null and is_instance_valid(target):
				direction = global_position.direction_to(target.global_position)
			elif _get_player_ref() != null:
				direction = global_position.direction_to(_get_player_ref().global_position)
			else:
				direction = Vector2.DOWN

	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta

	match mode:
		ProjectileMode.STRAIGHT:
			_move_straight(delta)
		ProjectileMode.FALLING:
			_move_straight(delta)
		ProjectileMode.RISING:
			_move_rising(delta)
		ProjectileMode.HORIZONTAL:
			_move_straight(delta)
		ProjectileMode.HOMING:
			_move_homing(delta)

	_try_pop_from_player_slash()

# ── Movement modes ────────────────────────────────────────────────────────────

func _move_straight(delta: float) -> void:
	position += direction.normalized() * speed * delta
	if mode == ProjectileMode.FALLING:
		rotation += sin(_elapsed * 3.0) * delta * 2.5
		position.x += sin(_elapsed * 2.0) * 60.0 * delta
	if mode == ProjectileMode.HORIZONTAL:
		rotation += direction.x * speed * delta * 0.01
	if mode == ProjectileMode.STRAIGHT:
		rotation = direction.angle() + PI / 2.0

func _move_rising(delta: float) -> void:
	position += Vector2.UP * speed * delta
	# Stop once the spike has risen its full distance
	if global_position.distance_to(_origin) >= rise_distance:
		set_physics_process(false)

func _move_homing(delta: float) -> void:
	# Brief delay before homing activates — gives player a chance to react
	if _elapsed < homing_activation_delay:
		position += direction.normalized() * speed * delta
		rotation = direction.angle() + PI / 2.0
		return

	var homing_target: Node2D = target if (target != null and is_instance_valid(target)) else _get_player_ref()

	if homing_target == null:
		position += direction.normalized() * speed * delta
		rotation = direction.angle() + PI / 2.0
		return

	var dist: float = global_position.distance_to(homing_target.global_position)

	# One-way latch — once within range, permanently stop homing
	if not _homing_locked_off and dist < 180.0:
		_homing_locked_off = true

	if not _homing_locked_off:
		var desired_dir: Vector2 = global_position.direction_to(homing_target.global_position)
		var current_angle: float = direction.angle()
		var desired_angle: float = desired_dir.angle()
		var new_angle: float = lerp_angle(current_angle, desired_angle, homing_turn_speed * delta)
		direction = Vector2.RIGHT.rotated(new_angle)

	# Rotate sprite tip to point in movement direction
	rotation = direction.angle() + PI / 2.0
	position += direction * speed * delta

# ── Collision ─────────────────────────────────────────────────────────────────
var _hit: bool = false
var _hit_cooldown: float = 0.0
func _on_body_entered(body: Node2D) -> void:
	if _hit_cooldown > 0.0 or not _is_player(body):
		return
	_hit_cooldown = 2.0
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	AudioController.play_boss_hit_bubble()
	if mode == ProjectileMode.HOMING:
		queue_free()

# ── Player slash deflection ───────────────────────────────────────────────────

func _try_pop_from_player_slash() -> void:
	if _hit or not is_inside_tree():
		return
	var player: Node2D = _get_player_ref()
	if player == null:
		return
	if not bool(player.get("is_attacking")):
		return
	if not player.has_method("_get_slash_world_polygon"):
		return
	var slash_polygon: PackedVector2Array = player.call("_get_slash_world_polygon") as PackedVector2Array
	if slash_polygon.size() < 3:
		return
	if not _is_circle_overlapping_polygon(global_position, _projectile_radius, slash_polygon):
		return
	_hit = true
	AudioController.play_boss_hit_bubble()

# ── Player detection ──────────────────────────────────────────────────────────

func _is_player(body: Node2D) -> bool:
	if body == null:
		return false
	return "Player" in body.name or body.is_in_group("player")

func _get_player_ref() -> Node2D:
	if _player_ref != null and is_instance_valid(_player_ref):
		return _player_ref
	var by_group: Node = get_tree().get_first_node_in_group("player")
	if by_group is Node2D and is_instance_valid(by_group):
		_player_ref = by_group as Node2D
		return _player_ref
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null
	var named: Node2D = current_scene.find_child("Player", true, false) as Node2D
	if named != null and _is_player(named):
		_player_ref = named
		return _player_ref
	for child in current_scene.get_children():
		var candidate: Node2D = child as Node2D
		if candidate != null and _is_player(candidate):
			_player_ref = candidate
			return _player_ref
	return null

# ── Geometry helpers ──────────────────────────────────────────────────────────

func _is_circle_overlapping_polygon(center: Vector2, radius: float, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(center, polygon):
		return true
	for i in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		if _distance_point_to_segment(center, a, b) <= radius:
			return true
	return false

func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.000001:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)

func _estimate_projectile_radius() -> float:
	if _collision_shape == null or _collision_shape.shape == null:
		return 1.0
	var local_scale: Vector2 = _collision_shape.global_scale
	var scale_factor: float = maxf(absf(local_scale.x), absf(local_scale.y))
	if _collision_shape.shape is CircleShape2D:
		return maxf((_collision_shape.shape as CircleShape2D).radius * scale_factor, 1.0)
	if _collision_shape.shape is RectangleShape2D:
		return maxf((_collision_shape.shape as RectangleShape2D).size.length() * 0.5 * scale_factor, 1.0)
	if _collision_shape.shape is CapsuleShape2D:
		var c: CapsuleShape2D = _collision_shape.shape as CapsuleShape2D
		return maxf((c.height * 0.5 + c.radius) * scale_factor, 1.0)
	return 1.0
