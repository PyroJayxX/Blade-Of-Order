extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DASH_SPEED = 800.0
const DASH_DURATION = 0.12
const ATTACK_DURATION = 0.16

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

func _physics_process(delta: float) -> void:
	_update_action_timers(delta)

	if not is_on_floor() and not is_dashing:
		velocity.y += gravity * delta

	if _just_pressed(JUMP_ACTIONS) and is_on_floor():
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

	if is_dashing:
		velocity.x = DASH_SPEED * _facing
	elif absf(direction) > 0.01 and not is_attacking:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

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
