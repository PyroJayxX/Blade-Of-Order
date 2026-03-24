extends CharacterBody2D

enum BossState {
	IDLE,
	CHASE,
	ATTACK
}

@export var target_path: NodePath
@export var detection_range: float = 2200.0
@export var disengage_range: float = 2800.0
@export var stop_chase_distance: float = 900.0
@export var chase_speed: float = 250.0
@export var keep_y_position: bool = true

var _state: BossState = BossState.IDLE
var _target: Node2D
var _home_y: float = 0.0

func _ready() -> void:
	_home_y = global_position.y
	_resolve_target()
	_set_state(BossState.IDLE)

func _physics_process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_resolve_target()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var distance_to_target: float = global_position.distance_to(_target.global_position)
	match _state:
		BossState.IDLE:
			velocity = Vector2.ZERO
			if distance_to_target <= detection_range:
				_set_state(BossState.CHASE)
		BossState.CHASE:
			if distance_to_target > disengage_range:
				_set_state(BossState.IDLE)
				velocity = Vector2.ZERO
			elif distance_to_target <= stop_chase_distance:
				_set_state(BossState.ATTACK)
				# Ranged boss behavior: hold distance instead of touching player.
				velocity = Vector2.ZERO
			else:
				_chase_target()
		BossState.ATTACK:
			velocity = Vector2.ZERO
			if distance_to_target > disengage_range:
				_set_state(BossState.IDLE)
			elif distance_to_target > stop_chase_distance + 100.0:
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

func _resolve_target() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node2D
		if _target != null:
			return

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_target = current_scene.get_node_or_null("Player") as Node2D

func _set_state(new_state: BossState) -> void:
	if _state == new_state:
		return
	_state = new_state
	print("Bubble Boss state -> ", _state_to_text(_state))

func _state_to_text(state: BossState) -> String:
	match state:
		BossState.IDLE:
			return "IDLE"
		BossState.CHASE:
			return "CHASE"
		BossState.ATTACK:
			return "ATTACK"
		_:
			return "UNKNOWN"
