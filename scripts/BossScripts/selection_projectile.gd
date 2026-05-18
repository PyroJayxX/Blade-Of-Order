extends Area2D

@export var speed: float = 200.0          # Initial horizontal speed or thrust
@export var max_fall_speed: float = 900.0  # Terminal velocity so it doesn't fall infinitely fast
@export var fall_gravity: float = 980.0    # Renamed to avoid clashing with Area2D.gravity

@export var damage: int = 10
var direction: Vector2 = Vector2.DOWN      # Defaulting direction to straight down
var _player_ref: Node2D = null
var _projectile_radius: float = 1.0

# Tracks current downward velocity accumulation
var _fall_velocity: float = 0.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

var _is_popping: bool = false
@onready var _anim_player: AnimationPlayer = $pop # pop animation
@onready var hit_flash: AnimationPlayer = $HitFlash # hit effect 

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_projectile_radius = _estimate_projectile_radius()

	await get_tree().create_timer(10.0).timeout
	if is_inside_tree() and not _is_popping:
		pop() # pop when it comes out

func _physics_process(delta: float) -> void:
	if _is_popping:
		return
	
	# 1. Accumulate gravity velocity over time using our renamed variable
	_fall_velocity += fall_gravity * delta
	_fall_velocity = minf(_fall_velocity, max_fall_speed)
	
	# 2. Combine horizontal movement with our falling speed
	var movement = Vector2.ZERO
	movement.x = direction.x * speed * delta
	movement.y = _fall_velocity * delta
	
	# 3. Apply the movement vector
	global_position += movement
	
	# Dynamic rotational alignment (points the sprite towards its travel arc)
	if movement.length_squared() > 0.001:
		rotation = movement.angle()
	
	_try_pop_from_player_slash()

func pop() -> void:
	if _is_popping:
		return
	
	_is_popping = true
	_collision_shape.set_deferred("disabled", true)
	AudioController.play_boss_hit_bubble()
	
	# play the hit flash if it exists
	if hit_flash != null and hit_flash.has_animation("hit_animation"):
		hit_flash.play("hit_animation")
	
	# play the pop animation and wait for it to finish
	if _anim_player != null and _anim_player.has_animation("pop"):
		_anim_player.play("pop")
		await _anim_player.animation_finished
	
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	AudioController.play_boss_hit_bubble()
	pop()
	
func _try_pop_from_player_slash() -> void:
	if not is_inside_tree():
		return

	var player: Node2D = _get_player_ref()
	if player == null:
		return
	if not bool(player.get("is_attacking")):
		return
	if not player.has_method("_get_slash_world_polygon"):
		return

	var slash_world_polygon: PackedVector2Array = player.call("_get_slash_world_polygon") as PackedVector2Array
	if slash_world_polygon.size() < 3:
		return
	if not _is_circle_overlapping_polygon(global_position, _projectile_radius, slash_world_polygon):
		return

	AudioController.play_boss_hit_bubble()
	pop()

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

	var named_player: Node2D = current_scene.find_child("Player", true, false) as Node2D
	if named_player != null and _is_player(named_player):
		_player_ref = named_player
		return _player_ref

	for child in current_scene.get_children():
		var candidate: Node2D = child as Node2D
		if candidate != null and _is_player(candidate):
			_player_ref = candidate
			return _player_ref

	return null

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
	var closest: Vector2 = a + ab * t
	return point.distance_to(closest)

func _estimate_projectile_radius() -> float:
	if _collision_shape == null or _collision_shape.shape == null:
		return 1.0

	var local_scale: Vector2 = _collision_shape.global_scale
	var scale_factor: float = maxf(absf(local_scale.x), absf(local_scale.y))

	if _collision_shape.shape is CircleShape2D:
		var circle: CircleShape2D = _collision_shape.shape as CircleShape2D
		return maxf(circle.radius * scale_factor, 1.0)

	if _collision_shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = _collision_shape.shape as RectangleShape2D
		return maxf(rect.size.length() * 0.5 * scale_factor, 1.0)

	if _collision_shape.shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = _collision_shape.shape as CapsuleShape2D
		return maxf((capsule.height * 0.5 + capsule.radius) * scale_factor, 1.0)

	return 1.0
