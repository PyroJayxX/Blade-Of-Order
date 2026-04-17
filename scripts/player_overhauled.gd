extends CharacterBody2D

const SPEED := 1000.0
const JUMP_HEIGHT := 240.0
const AIR_TIME := 0.5
const JUMP_VELOCITY := -(4.0 * JUMP_HEIGHT / AIR_TIME)
const JUMP_GRAVITY := 5.0 * JUMP_HEIGHT / (AIR_TIME * AIR_TIME)
const ACTION_JUMP: StringName = &"Jump"
const ACTION_SLASH: StringName = &"Slash"
const ACTION_MOVE_LEFT: StringName = &"moveLeft"
const ACTION_MOVE_RIGHT: StringName = &"moveRight"

const ANIM_IDLE: StringName = &"Idle"
const ANIM_RUNNING: StringName = &"Running"
const ANIM_JUMP: StringName = &"Jump"
const ANIM_SLASH: StringName = &"Slash_1"
const ANIM_RESET: StringName = &"RESET"
const SWORD_HITBOX_PATH: NodePath = ^"CharacterContainer/Bones/Skeleton2D/Torso/ShoulderFront/BicepFront/SwordHeld/Area2D"
const HUD_PATH: NodePath = ^"HUD"

@onready var body_root: Node2D = $CharacterContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sword_hitbox: Area2D = get_node_or_null(SWORD_HITBOX_PATH) as Area2D

var facing_right := true
var is_attacking := false
var _active_animation: StringName = &""
var _attack_timer := 0.0
@export var max_health: int = 100
@export var wrap_enabled: bool = true
@export var wrap_left_x: float = 750.0
@export var wrap_right_x: float = 5540.0
var _current_health: int = 100

func _ready() -> void:
	_current_health = max_health
	_apply_facing(facing_right)
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	if sword_hitbox != null:
		if not sword_hitbox.body_entered.is_connected(_on_sword_hitbox_body_entered):
			sword_hitbox.body_entered.connect(_on_sword_hitbox_body_entered)
		if not sword_hitbox.area_entered.is_connected(_on_sword_hitbox_area_entered):
			sword_hitbox.area_entered.connect(_on_sword_hitbox_area_entered)
	else:
		push_warning("Sword hitbox Area2D not found at expected path.")
	_sync_player_hud_health()
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

	var direction := _get_move_axis()
	if direction != 0.0:
		velocity.x = direction * SPEED
		var wants_right := direction > 0.0
		if wants_right != facing_right:
			_apply_facing(wants_right)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()
	_apply_horizontal_wrap()
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

func _get_move_axis() -> float:
	var left_pressed := _pressed(ACTION_MOVE_LEFT, &"ui_left")
	var right_pressed := _pressed(ACTION_MOVE_RIGHT, &"ui_right")
	return float(right_pressed) - float(left_pressed)

func _pressed(action_primary: StringName, action_fallback: StringName = &"") -> bool:
	if InputMap.has_action(action_primary) and Input.is_action_pressed(action_primary):
		return true
	if action_fallback != &"" and InputMap.has_action(action_fallback) and Input.is_action_pressed(action_fallback):
		return true
	return false

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == ANIM_SLASH:
		is_attacking = false
		_attack_timer = 0.0
		_active_animation = &""

func _on_sword_hitbox_body_entered(body: Node2D) -> void:
	if _is_boss_hit_target(body):
		print("Boss got hit by player!")
		body.call("take_damage", 1)

func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	if _is_boss_hit_target(area):
		print("Boss got hit by player!")
		area.call("take_damage", 1)
		return

	var parent_node: Node = area.get_parent()
	if _is_boss_hit_target(parent_node):
		print("Boss got hit by player!")
		parent_node.call("take_damage", 1)

func _is_boss_hit_target(candidate: Node) -> bool:
	if candidate == null or not candidate.has_method("take_damage"):
		return false
	if candidate == self or self.is_ancestor_of(candidate):
		return false
	return true

func take_damage(amount: int = 1) -> void:
	var safe_amount: int = maxi(amount, 0)
	_current_health = clampi(_current_health - safe_amount, 0, max_health)
	_sync_player_hud_health()
	print("Player HP -> ", _current_health, "/", max_health)

func _sync_player_hud_health() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var hud: Node = current_scene.get_node_or_null(HUD_PATH)
	if hud != null and hud.has_method("set_player_health"):
		hud.call("set_player_health", _current_health, max_health)

func _get_animation_length(animation_name: StringName) -> float:
	var animation_resource: Animation = animation_player.get_animation(animation_name)
	if animation_resource == null:
		return 0.25
	return maxf(animation_resource.length, 0.01)

func _apply_facing(face_right: bool) -> void:
	facing_right = face_right
	body_root.scale.x = 1.0 if facing_right else -1.0

func _apply_horizontal_wrap() -> void:
	if not wrap_enabled:
		return

	var span: float = wrap_right_x - wrap_left_x
	if span <= 0.0:
		return

	if global_position.x < wrap_left_x or global_position.x > wrap_right_x:
		var wrapped_x: float = wrap_left_x + fposmod(global_position.x - wrap_left_x, span)
		global_position.x = wrapped_x
