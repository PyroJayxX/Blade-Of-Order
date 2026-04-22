extends CharacterBody2D

signal boss_defeated

enum BossState {
	IDLE,
	CHASE,
	HURT,
	STUNNED,
	SHOOTING
}

@export var target_path: NodePath # path to player node if assigned in scene
@export var player: Node2D # direct player reference used for targeting
@export var stop_chase_distance: float = 1250.0 # preferred distance to keep from player
@export var chase_speed: float = 250.0 # horizontal chase and reposition speed
@export var keep_y_position: bool = true # whether movement should lock to home y
@export var contact_buffer: float = 80.0 # extra spacing added to body radius distance
@export var retreat_speed_multiplier: float = 0.6 # retreat speed as a fraction of chase speed
@export var attack_2_cooldown: float = 7.0 # cooldown between attack_2 uses in seconds
@export var attack_2_waves: int = 4 # number of star-burst waves for attack_2
@export var attack_2_projectiles_per_wave: int = 8 # bullets per attack_2 wave
@export var attack_2_wave_interval: float = 0.22 # delay between attack_2 waves in seconds
@export var attack_3_cooldown: float = 7.0 # cooldown between attack_3 uses in seconds
@export var attack_3_duration: float = 10.0 # total attack_3 stream duration in seconds
@export var attack_3_shot_interval: float = 0.05 # delay between attack_3 shots in seconds
@export var attack_3_start_angle_deg: float = 0.0 # starting angle for attack_3 stream in degrees
@export var attack_3_angle_step_deg: float = 10.0 # angle increment per attack_3 shot in degrees
@export var return_speed: float = 2400.0 # speed used when returning to home y
@export var max_eye_distance: float = 20.0 # max offset for eye tracking movement
@export var max_health: int = 100 # total boss hp

const HUD_PATH: NodePath = ^"HUD" # path to hud node for health updates

@export var bubble_scene: PackedScene # projectile scene used by all attacks
@export var burst_shots: int = 3 # shots fired per normal burst
@export var burst_shot_interval: float = 0.45 # delay between shots inside a burst in seconds
@export var burst_cooldown: float = 2 # delay between normal bursts in seconds
var _shoot_timer: float = 0.0 # timer that gates next normal shot
var _shots_left_in_burst: int = 0 # remaining shots in the current normal burst
var _attack_anim_timer: float = 0.0 # small lock timer before special checks
var _attack_2_running: bool = false # whether attack_2 coroutine is active
var _attack_3_running: bool = false # whether attack_3 coroutine is active
var _next_special_is_attack_2: bool = false # alternation flag for choosing next special

var _state: BossState = BossState.IDLE # current boss state
var _target: Node2D # resolved player target
var _home_y: float = 0.0 # baseline y position the boss returns to
var _desired_personal_space: float = 0.0 # dynamic spacing based on collider radii
var _current_health: int = 100 # runtime hp value
var _is_defeated: bool = false # whether defeat logic has already run
var _combat_enabled: bool = true # global combat gate for pause/cutscene control
var _special_attack_cooldown_timer: float = 0.0 # timer before next special attack
@onready var anim_player: AnimationPlayer = $AnimationPlayer # animation player for state visuals
@onready var eyes_pivot: Node2D = $EyesPivot # node used to move eyes toward target

func _process(_delta: float) -> void:
	if not _combat_enabled:
		eyes_pivot.position = Vector2.ZERO
		eyes_pivot.global_rotation = 0
		return
	if _target != null and is_instance_valid(_target):
		if _state == BossState.CHASE or _state == BossState.SHOOTING:
			var target_vector = _target.global_position - global_position
			eyes_pivot.position = target_vector.limit_length(max_eye_distance)
			eyes_pivot.global_rotation = 0
		elif _state == BossState.IDLE:
			eyes_pivot.position = Vector2.ZERO
			eyes_pivot.global_rotation = 0

func _ready() -> void:
	_current_health = max_health
	_is_defeated = false
	_home_y = global_position.y
	_resolve_target()
	_refresh_personal_space()
	_special_attack_cooldown_timer = attack_2_cooldown
	_set_state(BossState.IDLE)
	_sync_boss_hud_health()

func _physics_process(delta: float) -> void:
	if not _combat_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _target == null or not is_instance_valid(_target):
		_resolve_target()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _is_special_attack_running():
		_maintain_personal_space_during_special()
		move_and_slide()
		return

	if _shoot_timer > 0.0:
		_shoot_timer -= delta
	if _attack_anim_timer > 0.0:
		_attack_anim_timer -= delta
	if _special_attack_cooldown_timer > 0.0:
		_special_attack_cooldown_timer -= delta

	var distance_to_target: float = global_position.distance_to(_target.global_position)
	var attack_distance: float = maxf(stop_chase_distance, _desired_personal_space)
	var shooting_distance: float = attack_distance * 0.8
	match _state:
		BossState.IDLE:
			velocity = Vector2.ZERO
			_return_to_default_y(delta)
			_set_state(BossState.CHASE)
		BossState.HURT:
			velocity = Vector2.ZERO
		BossState.STUNNED:
			velocity = Vector2.ZERO
		BossState.CHASE:
			_return_to_default_y(delta)
			# --- NEW: Shoot while chasing ---
			_process_shooting_burst()
				
			if distance_to_target <= shooting_distance:
				_set_state(BossState.SHOOTING)
				_attack_anim_timer = 0.5 # Lock attack state for animation
				_shots_left_in_burst = 0
				velocity = Vector2.ZERO
			else:
				_chase_target()
		BossState.SHOOTING:
			_process_shooting_burst()

			if distance_to_target > attack_distance + 120.0:
				_set_state(BossState.CHASE)
				_shots_left_in_burst = 0
				return
				
			if distance_to_target < attack_distance * 0.9:
				_retreat_from_target()
			else:
				velocity = Vector2.ZERO
			_return_to_default_y(delta)
				
			if _attack_anim_timer <= 0.0 and _special_attack_cooldown_timer <= 0.0:
				_start_next_special_attack()

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

func _maintain_personal_space_during_special() -> void:
	if _target == null or not is_instance_valid(_target):
		velocity = Vector2.ZERO
		return

	var push_delta: Vector2 = global_position - _target.global_position
	if keep_y_position:
		push_delta.y = 0.0

	var min_distance: float = maxf(_desired_personal_space, stop_chase_distance * 0.7)
	var planar_distance: float = push_delta.length()
	if planar_distance < min_distance:
		if planar_distance <= 0.0001:
			push_delta = Vector2.RIGHT
		velocity = push_delta.normalized() * chase_speed * retreat_speed_multiplier
	else:
		velocity = Vector2.ZERO

	_return_to_default_y(0.0)

func _resolve_target() -> void:
	if player != null and is_instance_valid(player):
		_target = player
		_refresh_personal_space()
		return

	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node2D
		if _target != null:
			_refresh_personal_space()
			return

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_target = _find_target_in_scene(current_scene)
		_refresh_personal_space()

func _find_target_in_scene(current_scene: Node) -> Node2D:
	var by_group: Node = get_tree().get_first_node_in_group("player")
	if by_group is Node2D and is_instance_valid(by_group):
		return by_group as Node2D

	var modern_player: Node2D = current_scene.find_child("Player_OH", true, false) as Node2D
	if modern_player != null:
		return modern_player

	return current_scene.find_child("Player", true, false) as Node2D

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
			BossState.SHOOTING:
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
		BossState.SHOOTING:
			return "SHOOTING"
		_:
			return "UNKNOWN"
			
func take_damage(amount: int = 1, causes_stun: bool = false) -> void:
	if _is_defeated:
		return

	var safe_amount: int = maxi(amount, 0)
	_current_health = clampi(_current_health - safe_amount, 0, max_health)
	_sync_boss_hud_health()
	print("Boss HP -> ", _current_health, "/", max_health)

	if _current_health <= 0:
		AudioController.play_boss_stunned()
		_is_defeated = true
		_attack_2_running = false
		_attack_3_running = false
		velocity = Vector2.ZERO
		_set_state(BossState.IDLE)
		boss_defeated.emit()
		return

	if causes_stun:
		_set_state(BossState.STUNNED)
	else:
		_set_state(BossState.HURT)
		await anim_player.animation_finished
		if not _is_defeated:
			_set_state(BossState.CHASE)

func _sync_boss_hud_health() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var hud: Node = current_scene.find_child("HUD", true, false)
	if hud == null:
		hud = current_scene.get_node_or_null(HUD_PATH)
	if hud != null and hud.has_method("set_boss_health"):
		hud.call("set_boss_health", _current_health, max_health)

func on_stun_started_mock() -> void:
	_set_state(BossState.STUNNED)
	print("Stun puzzle opened.")

func on_stun_modal_closed_mock() -> void:
	if _state == BossState.STUNNED:
		_set_state(BossState.CHASE)
	print("Stun puzzle closed.")

func on_sealing_success_mock() -> void:
	print("Sealing success. TODO: apply real sealing outcome.")
	_set_state(BossState.IDLE)

func on_resonance_surge_mock() -> void:
	print("Resonance Surge. TODO: restore boss HP to full.")
	_set_state(BossState.CHASE)

func reset_for_retry(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_combat_enabled = true
	_current_health = max_health
	_is_defeated = false
	_home_y = global_position.y
	_shoot_timer = 0.0
	_attack_anim_timer = 0.0
	_special_attack_cooldown_timer = attack_2_cooldown
	_shots_left_in_burst = 0
	_attack_2_running = false
	_attack_3_running = false
	_next_special_is_attack_2 = true
	_sync_boss_hud_health()
	_set_state(BossState.CHASE)

func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled
	if not _combat_enabled:
		velocity = Vector2.ZERO
		_shoot_timer = 0.0
		_attack_anim_timer = 0.0
		_special_attack_cooldown_timer = 0.0
		_shots_left_in_burst = 0
		_attack_2_running = false
		_attack_3_running = false
		_set_state(BossState.IDLE)
		
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		take_damage(10, false)

func _start_next_special_attack() -> void:
	if _next_special_is_attack_2:
		execute_attack_2()
	else:
		execute_attack_3()
	_next_special_is_attack_2 = not _next_special_is_attack_2

func execute_attack_2() -> void:
	if _attack_2_running or _attack_3_running or _is_defeated:
		return

	_attack_2_running = true
	_special_attack_cooldown_timer = attack_2_cooldown
	_shots_left_in_burst = 0
	_shoot_timer = 0.0
	velocity = Vector2.ZERO
	_set_state(BossState.SHOOTING)

	for wave in range(maxi(attack_2_waves, 1)):
		if not is_inside_tree() or _is_defeated:
			_attack_2_running = false
			return

		_spawn_attack_2_wave(wave)

		var tree_ref: SceneTree = get_tree()
		if tree_ref == null:
			_attack_2_running = false
			return
		await tree_ref.create_timer(maxf(attack_2_wave_interval, 0.01)).timeout

	_attack_2_running = false
	if _is_defeated:
		return
	_attack_anim_timer = 0.5
	_set_state(BossState.CHASE)

func execute_attack_3() -> void:
	if _attack_3_running or _attack_2_running or _is_defeated:
		return

	_attack_3_running = true
	_special_attack_cooldown_timer = attack_3_cooldown
	_shots_left_in_burst = 0
	_shoot_timer = 0.0
	velocity = Vector2.ZERO
	_set_state(BossState.SHOOTING)

	var elapsed: float = 0.0
	var step: float = maxf(attack_3_shot_interval, 0.01)
	var angle_deg: float = attack_3_start_angle_deg

	while elapsed < maxf(attack_3_duration, 0.1):
		if not is_inside_tree() or _is_defeated:
			_attack_3_running = false
			return

		_spawn_bubble_in_direction(Vector2.RIGHT.rotated(deg_to_rad(angle_deg)))

		var tree_ref: SceneTree = get_tree()
		if tree_ref == null:
			_attack_3_running = false
			return
		await tree_ref.create_timer(step).timeout
		elapsed += step
		angle_deg = wrapf(angle_deg + attack_3_angle_step_deg, 0.0, 360.0)

	_attack_3_running = false
	if _is_defeated:
		return
	_attack_anim_timer = 0.5
	_set_state(BossState.CHASE)

func _spawn_attack_2_wave(wave_index: int) -> void:
	if bubble_scene == null:
		return

	var count: int = maxi(attack_2_projectiles_per_wave, 3)
	var angle_step: float = TAU / float(count)
	var phase: float = 0.0
	if wave_index % 2 == 1:
		phase = angle_step * 0.5

	for i in range(count):
		_spawn_bubble_in_direction(Vector2.RIGHT.rotated(phase + angle_step * float(i)))

func _process_shooting_burst() -> void:
	if _shoot_timer > 0.0:
		return

	if _shots_left_in_burst <= 0:
		_shots_left_in_burst = maxi(burst_shots, 1)

	_shoot_bubble()
	_shots_left_in_burst -= 1

	if _shots_left_in_burst > 0:
		_shoot_timer = burst_shot_interval
	else:
		_shoot_timer = burst_cooldown

func _return_to_default_y(_delta: float) -> void:
	var hover_delta: float = _home_y - global_position.y
	if absf(hover_delta) <= 1.0:
		velocity.y = 0.0
		return

	velocity.y = clampf(hover_delta * 8.0, -return_speed, return_speed)

func _spawn_bubble_in_direction(direction: Vector2) -> void:
	if bubble_scene == null:
		return
	var level_root: Node = _get_level_root()
	if level_root == null:
		return

	var bubble: Node = bubble_scene.instantiate()
	if bubble == null:
		return
	bubble.global_position = global_position
	bubble.direction = direction.normalized()
	level_root.add_child(bubble)

func _is_special_attack_running() -> bool:
	return _attack_2_running or _attack_3_running

func _get_level_root() -> Node:
	var node: Node = self
	while node != null:
		var parent: Node = node.get_parent()
		if parent == null:
			break
		if parent.name == "ContentRoot":
			return node
		node = parent
	return get_tree().current_scene

# --- NEW: Spawning the Bubble ---
func _shoot_bubble() -> void:
	if bubble_scene == null or _target == null:
		return
	_spawn_bubble_in_direction(global_position.direction_to(_target.global_position))
