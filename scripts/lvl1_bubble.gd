extends CharacterBody2D

enum BossState {
	IDLE,
	CHASE,
	HURT,
	STUNNED,
	ATTACK
}

@export var target_path: NodePath
@export var detection_range: float = 2200.0
@export var disengage_range: float = 2800.0
@export var stop_chase_distance: float = 900.0
@export var chase_speed: float = 250.0
@export var keep_y_position: bool = true
@export var contact_buffer: float = 80.0
@export var retreat_speed_multiplier: float = 0.6
@export var max_eye_distance: float = 20.0 #

var _state: BossState = BossState.IDLE
var _target: Node2D
var _home_y: float = 0.0
var _desired_personal_space: float = 0.0
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var eyes_pivot: Node2D = $EyesPivot

func _process(_delta: float) -> void:
	if _target != null and is_instance_valid(_target):
		if _state == BossState.CHASE or _state == BossState.ATTACK:
			var target_vector = _target.global_position - global_position
			eyes_pivot.position = target_vector.limit_length(max_eye_distance)
			eyes_pivot.global_rotation = 0
		elif _state == BossState.IDLE:
			eyes_pivot.position = Vector2.ZERO
			eyes_pivot.global_rotation = 0

func _ready() -> void:
	_home_y = global_position.y
	_resolve_target()
	_refresh_personal_space()
	_set_state(BossState.IDLE)

func _physics_process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_resolve_target()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var distance_to_target: float = global_position.distance_to(_target.global_position)
	var attack_distance: float = maxf(stop_chase_distance, _desired_personal_space)
	match _state:
		BossState.IDLE:
			velocity = Vector2.ZERO
			if distance_to_target <= detection_range:
				_set_state(BossState.CHASE)
		BossState.CHASE:
			if distance_to_target > disengage_range:
				_set_state(BossState.IDLE)
				velocity = Vector2.ZERO
			elif distance_to_target <= attack_distance:
				_set_state(BossState.ATTACK)
				# Ranged boss behavior: hold distance instead of touching player.
				velocity = Vector2.ZERO
			else:
				_chase_target()
		BossState.ATTACK:
			if distance_to_target < attack_distance * 0.9:
				_retreat_from_target()
			else:
				velocity = Vector2.ZERO
			if distance_to_target > disengage_range:
				_set_state(BossState.IDLE)
			elif distance_to_target > attack_distance + 100.0:
				_set_state(BossState.CHASE)

	move_and_slide()

func _chase_target() -> void:
	var desired_target_pos: Vector2 = _target.global_position
	if keep_y_position:
		desired_target_pos.y = _home_y

	var delta: Vector2 = desired_target_pos - global_position
	if delta.length_squared() <= 0.0001:
		velocity = Vector2.ZERO
		return

	velocity = delta.normalized() * chase_speed

func _retreat_from_target() -> void:
	var delta: Vector2 = global_position - _target.global_position
	if keep_y_position:
		delta.y = 0.0

	if delta.length_squared() <= 0.0001:
		velocity = Vector2.ZERO
		return

	velocity = delta.normalized() * chase_speed * retreat_speed_multiplier

func _resolve_target() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node2D
		if _target != null:
			_refresh_personal_space()
			return

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_target = current_scene.get_node_or_null("Player") as Node2D
		_refresh_personal_space()

func _refresh_personal_space() -> void:
	var self_radius: float = _estimate_body_radius(self)
	var target_radius: float = _estimate_body_radius(_target)
	_desired_personal_space = self_radius + target_radius + contact_buffer

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

	# Fallback if no recognized collision shape exists.
	return 64.0

func _set_state(new_state: BossState) -> void:
	if _state == new_state:
		return
	_state = new_state
	print("Bubble Boss state -> ", _state_to_text(_state))

	if anim_player != null:
		match _state:
			BossState.IDLE:
				anim_player.play("idle")
			BossState.CHASE:
				anim_player.play("chase")
			BossState.ATTACK:
				anim_player.play("attack")
			BossState.HURT:
				anim_player.play("hurt")
			BossState.STUNNED:
				anim_player.play("stunned")

func _state_to_text(state: BossState) -> String:
	match state:
		BossState.IDLE:
			return "IDLE"
		BossState.CHASE:
			return "CHASE"
		BossState.HURT:
			return "HURT"
		BossState.STUNNED:
			return "STUNNED"
		BossState.ATTACK:
			return "ATTACK"
		_:
			return "UNKNOWN"
			
func take_damage(amount: int, causes_stun: bool = false) -> void:
	if causes_stun:
		_set_state(BossState.STUNNED)
	else:
		_set_state(BossState.HURT)
		await anim_player.animation_finished
		_set_state(BossState.CHASE)
		
func _unhandled_input(event: InputEvent) -> void:
	# Press 'H' on your keyboard to instantly hurt the boss
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		take_damage(10, false)
		
	# Press 'K' on your keyboard to test the Stunned animation!
	if event is InputEventKey and event.pressed and event.keycode == KEY_K:
		take_damage(10, true)
