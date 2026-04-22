extends Area2D

@export var speed: float = 600.0
@export var damage: int = 5
var direction: Vector2 = Vector2.ZERO
var _player_ref: Node2D = null
var _projectile_radius: float = 1.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_projectile_radius = _estimate_projectile_radius()

	await get_tree().create_timer(10.0).timeout
	if is_inside_tree():
		queue_free()

func _physics_process(delta: float) -> void:
	# Move the bubble forward every frame
	position += direction * speed * delta
	_try_pop_from_player_slash()

func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	AudioController.play_boss_hit_bubble()
	queue_free()

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
	queue_free()

func _is_player(body: Node2D) -> bool:
	if body == null:
		return false
	return "Player" in body.name or body.is_in_group("player")

func _get_player_ref() -> Node2D:
	if _player_ref != null and is_instance_valid(_player_ref):
		return _player_ref

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null

	var named_player: Node2D = current_scene.get_node_or_null("Player") as Node2D
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
