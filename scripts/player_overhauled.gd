extends CharacterBody2D

const SPEED := 750.0
const JUMP_HEIGHT := 240.0
const AIR_TIME := 0.5
const JUMP_VELOCITY := -(4.0 * JUMP_HEIGHT / AIR_TIME)
const JUMP_GRAVITY := 5.0 * JUMP_HEIGHT / (AIR_TIME * AIR_TIME)
const ACTION_JUMP: StringName = &"Jump"
const ACTION_SLASH: StringName = &"Slash"

const ANIM_IDLE: StringName = &"Idle"
const ANIM_RUNNING: StringName = &"Running"
const ANIM_JUMP: StringName = &"Jump"
const ANIM_SLASH: StringName = &"Slash_1"
const ANIM_RESET: StringName = &"RESET"

@onready var body_root: Node2D = $CharacterContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var facing_right := true
var is_attacking := false
var _active_animation: StringName = &""
var _attack_timer := 0.0

func _ready() -> void:
	_apply_facing(facing_right)
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	_play_animation_with_reset(ANIM_IDLE)

func _physics_process(delta: float) -> void:
	if is_attacking:
		_attack_timer = maxf(_attack_timer - delta, 0.0)
		# Fallback release in case slash animation is configured to loop.
		if _attack_timer == 0.0:
			is_attacking = false
			_active_animation = &""

	if not is_on_floor():
		velocity.y += JUMP_GRAVITY * delta

	if _just_pressed(ACTION_JUMP, &"ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if _just_pressed(ACTION_SLASH, &"slash") and not is_attacking:
		is_attacking = true
		_attack_timer = _get_animation_length(ANIM_SLASH)
		_play_animation_with_reset(ANIM_SLASH)

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		velocity.x = direction * SPEED
		var wants_right := direction > 0.0
		if wants_right != facing_right:
			_apply_facing(wants_right)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()
	_update_animation(direction)

func _update_animation(direction: float) -> void:
	if is_attacking:
		return

	if not is_on_floor():
		_play_animation_with_reset(ANIM_JUMP)
		return

	if absf(direction) > 0.01:
		_play_animation_with_reset(ANIM_RUNNING, 2.0)
	else:
		_play_animation_with_reset(ANIM_IDLE)

func _play_animation_with_reset(animation_name: StringName, speed_scale: float = 1.0) -> void:
	if _active_animation == animation_name:
		return

	_active_animation = animation_name
	animation_player.play(ANIM_RESET)
	animation_player.advance(0.0)
	animation_player.play(animation_name, -1, speed_scale)

func _just_pressed(action_primary: StringName, action_fallback: StringName = &"") -> bool:
	if InputMap.has_action(action_primary) and Input.is_action_just_pressed(action_primary):
		return true
	if action_fallback != &"" and InputMap.has_action(action_fallback) and Input.is_action_just_pressed(action_fallback):
		return true
	return false

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == ANIM_SLASH:
		is_attacking = false
		_attack_timer = 0.0
		_active_animation = &""

func _get_animation_length(animation_name: StringName) -> float:
	var animation_resource: Animation = animation_player.get_animation(animation_name)
	if animation_resource == null:
		return 0.25
	return maxf(animation_resource.length, 0.01)

func _apply_facing(face_right: bool) -> void:
	facing_right = face_right
	body_root.scale.x = 1.0 if facing_right else -1.0
