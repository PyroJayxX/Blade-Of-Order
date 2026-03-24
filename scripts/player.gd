extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -800.0
const DASH_SPEED = 800.0
const DASH_DURATION = 0.12
const ATTACK_DURATION = 0.16

@export var wrap_enabled: bool = true
@export var wrap_left_x: float = 750.0
@export var wrap_right_x: float = 5540.0	
@export var max_air_jumps: int = 1
@export var gravity_scale: float = 2.2
@export var fall_gravity_multiplier: float = 1.2
@export var max_fall_speed: float = 1600.0

const MOVE_LEFT_ACTIONS: Array[StringName] = [&"moveleft", &"moveLeft", &"ui_left"]
const MOVE_RIGHT_ACTIONS: Array[StringName] = [&"moveright", &"moveRight", &"ui_right"]
const JUMP_ACTIONS: Array[StringName] = [&"jump", &"Jump", &"ui_accept"]
const SLASH_ACTIONS: Array[StringName] = [&"slash", &"Slash"]
const DASH_ACTIONS: Array[StringName] = [&"dash", &"Dash"]
const DODGE_ACTIONS: Array[StringName] = [&"dodge", &"Dodge"]

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float
var is_attacking: bool = false
var is_dashing: bool = false
var _attack_timer: float = 0.0
var _dash_timer: float = 0.0
var _facing: float = 1.0
var _air_jumps_used: int = 0
@onready var _visual_root: Node2D = $CharacterContainer

func _ready() -> void:
	_update_visual_facing()

func _physics_process(delta: float) -> void:
	_update_action_timers(delta)

	if not is_on_floor() and not is_dashing:
		var applied_gravity: float = gravity * gravity_scale
		if velocity.y > 0.0:
			applied_gravity *= fall_gravity_multiplier
		velocity.y = minf(velocity.y + applied_gravity * delta, max_fall_speed)
	else:
		_air_jumps_used = 0

	if _just_pressed(JUMP_ACTIONS):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif _air_jumps_used < max_air_jumps:
			_air_jumps_used += 1
			velocity.y = JUMP_VELOCITY

	if _just_pressed(SLASH_ACTIONS) and not is_attacking and not is_dashing:
		perform_slash()

	if _just_pressed(DASH_ACTIONS) and not is_dashing and not is_attacking:
		perform_dash()

	if _just_pressed(DODGE_ACTIONS):
		perform_dodge()

	var direction: float = _get_move_axis()
	if absf(direction) > 0.01:
		_facing = signf(direction)
		_update_visual_facing()

	if is_dashing:
		velocity.x = DASH_SPEED * _facing
	elif absf(direction) > 0.01 and not is_attacking:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_apply_horizontal_wrap()

func perform_slash() -> void:
	is_attacking = true
	_attack_timer = ATTACK_DURATION
	print("Playing Slash Animation")

func perform_dash() -> void:
	is_dashing = true
	_dash_timer = DASH_DURATION * 3.0
	velocity.x = DASH_SPEED * _facing
	print("Dash Initiated")

func perform_dodge() -> void:
	print("Dodge Initiated - Granting i-frames")

func _update_action_timers(delta: float) -> void:
	if is_attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			is_attacking = false

	if is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			is_dashing = false

func _get_move_axis() -> float:
	var left_pressed: bool = _pressed(MOVE_LEFT_ACTIONS)
	var right_pressed: bool = _pressed(MOVE_RIGHT_ACTIONS)
	return float(right_pressed) - float(left_pressed)

func _pressed(actions: Array[StringName]) -> bool:
	for action_name in actions:
		if InputMap.has_action(action_name) and Input.is_action_pressed(action_name):
			return true
	return false

func _just_pressed(actions: Array[StringName]) -> bool:
	for action_name in actions:
		if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
			return true
	return false

func _update_visual_facing() -> void:
	var current_scale: Vector2 = _visual_root.scale
	current_scale.x = absf(current_scale.x) * _facing
	_visual_root.scale = current_scale

func _apply_horizontal_wrap() -> void:
	if not wrap_enabled:
		return

	var span: float = wrap_right_x - wrap_left_x
	if span <= 0.0:
		return

	if global_position.x < wrap_left_x or global_position.x > wrap_right_x:
		var wrapped_x: float = wrap_left_x + fposmod(global_position.x - wrap_left_x, span)
		global_position.x = wrapped_x
