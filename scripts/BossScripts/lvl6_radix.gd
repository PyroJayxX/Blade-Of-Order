extends Node2D

signal boss_defeated

const MOVE_SPEED = 1000.0
const CHARGE_SPEED = 2500.0
const SEGMENT_DISTANCE = 200.0
const DASH_MAX_DISTANCE = 3000.0
const MAX_HEALTH = 100
const HEAD_DAMAGE = 5
const SEGMENT_DAMAGE = 2
const PLAYER_SEGMENT_DAMAGE = 2
const PLAYER_DAMAGE_PER_HIT = 5
const DAMAGE_COOLDOWN = 0.5

var segments: Array[Node2D] = []
var parent_node: Node
var velocity: Vector2 = Vector2.ZERO
var player: Node2D = null
var state: String = "attacking"
var turn_speed: float = 4.0
var is_dashing: bool = true
var dash_target_angle: float = 0.0
var dash_start_pos: Vector2 = Vector2.ZERO

var position_history: Array[Vector2] = []
var rotation_history: Array[Vector2] = []
var _last_history_pos: Vector2 = Vector2.ZERO
var _current_health: int = MAX_HEALTH
var _is_defeated: bool = false
var _boss_damaged_player_time: float = 0.0
var _player_damaged_boss_time: float = 0.0
var _nodes_last_overlap: Dictionary = {}
var _prev_dashing: bool = false
var _combat_enabled: bool = true

@onready var head: Node2D = $Head
@onready var segment: Node2D = $Segment


func _ready() -> void:
	parent_node = get_parent()
	if not parent_node:
		push_error("No parent node found!")
		return

	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		player = player_nodes[0] as Node2D
	else:
		push_warning("Player not found in 'player' group!")

	_collect_manual_segments()
	if segments.size() == 0:
		push_warning("No segments found in scene.")

	for c in get_children():
		if c is CharacterBody2D:
			c.collision_layer = 0
			c.collision_mask = 0
			for hc in c.get_children():
				if hc is CollisionShape2D:
					hc.disabled = true
		elif c is CollisionShape2D:
			c.disabled = true

	_prefill_history()

	if player:
		dash_target_angle = (player.global_position - global_position).angle()
		dash_start_pos = global_position
		rotation = dash_target_angle

	_sync_boss_hud_health()

	_nodes_last_overlap.clear()
	_nodes_last_overlap[self] = false
	for s in segments:
		_nodes_last_overlap[s] = false


func _collect_manual_segments() -> void:
	segments.clear()
	for c in get_children():
		if c.name.findn("Segment") >= 0:
			segments.append(c)
	if get_parent():
		for c in get_parent().get_children():
			if c.name.findn("Segment") >= 0 and not segments.has(c):
				segments.append(c)

	if segments.size() > 0:
		var behind_dir = -Vector2.RIGHT.rotated(global_rotation)
		for i in range(segments.size()):
			segments[i].global_position = global_position + behind_dir * SEGMENT_DISTANCE * (i + 1)
			segments[i].z_index = 100 + i
			if segments[i] is CharacterBody2D:
				segments[i].collision_layer = 0
				segments[i].collision_mask = 0
			for child in segments[i].get_children():
				if child is CollisionShape2D:
					child.disabled = true


func _prefill_history() -> void:
	var needed := 2000
	var behind_dir: Vector2 = -Vector2.RIGHT.rotated(global_rotation)
	var forward_dir: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	position_history.clear()
	rotation_history.clear()
	for i in range(needed):
		position_history.append(global_position + behind_dir * float(i))
		rotation_history.append(forward_dir)
	_last_history_pos = global_position


func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return

	# Honor external combat gating (e.g., cutscenes)
	if not _combat_enabled:
		_prev_dashing = is_dashing
		return

	_prev_dashing = is_dashing

	if _is_defeated:
		return

	match state:
		"attacking":
			if not is_dashing:
				var aim: float = (player.global_position - global_position).angle()
				var diff: float = wrapf(aim - rotation, -PI, PI)
				rotation += clamp(diff, -turn_speed * delta, turn_speed * delta)
				rotation = wrapf(rotation, -PI, PI)
				velocity = Vector2.RIGHT.rotated(rotation) * CHARGE_SPEED
				global_position += velocity * delta

				if abs(diff) < 0.1:
					dash_target_angle = rotation
					dash_start_pos = global_position
					is_dashing = true
			else:
				velocity = Vector2.RIGHT.rotated(dash_target_angle) * CHARGE_SPEED
				global_position += velocity * delta
				rotation = wrapf(dash_target_angle, -PI, PI)

				var traveled: float = global_position.distance_to(dash_start_pos)
				if traveled >= DASH_MAX_DISTANCE:
					is_dashing = false

	_record_history()
	_update_segments_from_history()

	_boss_damaged_player_time += delta
	_player_damaged_boss_time += delta

	_check_collisions_with_player()

	if is_dashing and not _prev_dashing:
		_apply_instant_damage_to_player()


func _record_history() -> void:
	position_history.push_front(global_position)
	rotation_history.push_front(Vector2.RIGHT.rotated(rotation))

	var max_entries := 2000
	while position_history.size() > max_entries:
		position_history.pop_back()
	while rotation_history.size() > max_entries:
		rotation_history.pop_back()

	_last_history_pos = global_position


func _update_segments_from_history() -> void:
	for i in range(segments.size()):
		var s: Node2D = segments[i]
		if not is_instance_valid(s):
			continue

		var target_distance: float = float(i + 1) * SEGMENT_DISTANCE
		var accumulated: float = 0.0

		for j in range(1, position_history.size()):
			var step: float = position_history[j - 1].distance_to(position_history[j])
			accumulated += step
			if accumulated >= target_distance:
				s.global_position = position_history[j]
				if j < rotation_history.size():
					s.rotation = rotation_history[j].angle()
				break


func _check_collisions_with_player() -> void:
	if not player or not is_instance_valid(player):
		return

	var total_damage: int = 0
	var head_overlapping: bool = _nodes_overlap(self, player)
	if head_overlapping and not _nodes_last_overlap.get(self, false):
		total_damage += HEAD_DAMAGE
	_nodes_last_overlap[self] = head_overlapping

	for segment in segments:
		if not is_instance_valid(segment):
			continue
		var seg_overlapping: bool = _nodes_overlap(segment, player)
		if seg_overlapping and not _nodes_last_overlap.get(segment, false):
			total_damage += SEGMENT_DAMAGE
		_nodes_last_overlap[segment] = seg_overlapping

	if total_damage > 0 and player.has_method("take_damage"):
		player.take_damage(total_damage)


func _apply_instant_damage_to_player() -> void:
	if not player or not is_instance_valid(player):
		return
	var total_damage: int = 0
	if _nodes_overlap(self, player):
		total_damage += HEAD_DAMAGE
	for segment in segments:
		if not is_instance_valid(segment):
			continue
		if _nodes_overlap(segment, player):
			total_damage += SEGMENT_DAMAGE

	if total_damage > 0 and player.has_method("take_damage"):
		player.take_damage(total_damage)


func take_damage(amount: int = PLAYER_DAMAGE_PER_HIT, causes_stun: bool = false) -> void:
	if _is_defeated:
		return

	var safe_amount: int = maxi(amount, 0)
	
	if safe_amount > 0:
		# 1. Flash the head
		if head.has_method("play_hit_flash"):
			head.play_hit_flash()
		
		# 2. Flash all the segments
		if segment.has_method("play_hit_flash"):
			segment.play_hit_flash()
	
	_current_health = clampi(_current_health - safe_amount, 0, MAX_HEALTH)
	_sync_boss_hud_health()
	print("Boss HP -> ", _current_health, "/", MAX_HEALTH)

	if _current_health <= 0:
		_is_defeated = true
		state = "idle"
		velocity = Vector2.ZERO
		is_dashing = false
		boss_defeated.emit()
		print("Boss defeated!")

	if causes_stun:
		velocity = Vector2.ZERO


func apply_slash_hits(world_polygon: PackedVector2Array) -> void:
	if _is_defeated:
		return

	var damage_accum: int = 0

	var head_center: Vector2 = global_position
	if world_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(head_center, world_polygon):
		damage_accum += HEAD_DAMAGE
	else:
		var head_radius: float = _estimate_body_radius(self)
		for i in range(world_polygon.size()):
			var a: Vector2 = world_polygon[i]
			var b: Vector2 = world_polygon[(i + 1) % world_polygon.size()]
			if _distance_point_to_segment(head_center, a, b) <= head_radius:
				damage_accum += HEAD_DAMAGE
				break

	for s in segments:
		if not is_instance_valid(s):
			continue
		var seg_center: Vector2 = s.global_position
		if world_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(seg_center, world_polygon):
			damage_accum += PLAYER_SEGMENT_DAMAGE
			continue
		var seg_radius: float = _estimate_body_radius(s)
		for i in range(world_polygon.size()):
			var a: Vector2 = world_polygon[i]
			var b: Vector2 = world_polygon[(i + 1) % world_polygon.size()]
			if _distance_point_to_segment(seg_center, a, b) <= seg_radius:
				damage_accum += PLAYER_SEGMENT_DAMAGE
				break

	if damage_accum > 0:
		take_damage(damage_accum, false)


func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.000001:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return point.distance_to(closest)


func _estimate_body_radius(node: Node) -> float:
	if node == null:
		return 0.0
	for child in node.get_children():
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
	return 32.0


func _get_collision_shape_node(node: Node) -> CollisionShape2D:
	if node == null:
		return null
	for child in node.get_children():
		if child is CollisionShape2D:
			return child
	return null


func _nodes_overlap(node_a: Node, node_b: Node) -> bool:
	var shape_a: CollisionShape2D = _get_collision_shape_node(node_a)
	var shape_b: CollisionShape2D = _get_collision_shape_node(node_b)
	if shape_a == null or shape_b == null:
		return node_a.global_position.distance_to(node_b.global_position) <= (_estimate_body_radius(node_a) + _estimate_body_radius(node_b))

	if shape_a.shape is CircleShape2D and shape_b.shape is RectangleShape2D:
		return _circle_rect_overlap(shape_a, shape_b)
	if shape_a.shape is RectangleShape2D and shape_b.shape is CircleShape2D:
		return _circle_rect_overlap(shape_b, shape_a)
	if shape_a.shape is CircleShape2D and shape_b.shape is CircleShape2D:
		var radius_a: float = (shape_a.shape as CircleShape2D).radius * maxf(absf(shape_a.global_scale.x), absf(shape_a.global_scale.y))
		var radius_b: float = (shape_b.shape as CircleShape2D).radius * maxf(absf(shape_b.global_scale.x), absf(shape_b.global_scale.y))
		return shape_a.global_position.distance_to(shape_b.global_position) <= radius_a + radius_b

	return node_a.global_position.distance_to(node_b.global_position) <= (_estimate_body_radius(node_a) + _estimate_body_radius(node_b))


func _circle_rect_overlap(circle_shape: CollisionShape2D, rect_shape: CollisionShape2D) -> bool:
	if circle_shape == null or rect_shape == null:
		return false
	if not (circle_shape.shape is CircleShape2D) or not (rect_shape.shape is RectangleShape2D):
		return false

	var circle: CircleShape2D = circle_shape.shape as CircleShape2D
	var rect: RectangleShape2D = rect_shape.shape as RectangleShape2D

	var circle_scale: float = maxf(absf(circle_shape.global_scale.x), absf(circle_shape.global_scale.y))
	var rect_scale: Vector2 = rect_shape.global_scale

	var circle_center: Vector2 = circle_shape.global_position
	var rect_center: Vector2 = rect_shape.global_position
	var rect_half_size: Vector2 = (rect.size * rect_scale) * 0.5
	var nearest_point: Vector2 = Vector2(
		clampf(circle_center.x, rect_center.x - rect_half_size.x, rect_center.x + rect_half_size.x),
		clampf(circle_center.y, rect_center.y - rect_half_size.y, rect_center.y + rect_half_size.y)
	)

	return circle_center.distance_squared_to(nearest_point) <= pow(circle.radius * circle_scale, 2.0)


func _sync_boss_hud_health() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var hud: Node = current_scene.find_child("HUD", true, false)
	if hud != null and hud.has_method("set_boss_health"):
		hud.call("set_boss_health", _current_health, MAX_HEALTH)


func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled
	if not _combat_enabled:
		velocity = Vector2.ZERO
		is_dashing = false
		state = "idle"
	else:
		state = "attacking"
