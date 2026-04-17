extends CharacterBody2D

signal boss_defeated

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
@export var stop_chase_distance: float = 1250.0
@export var chase_speed: float = 250.0
@export var keep_y_position: bool = true
@export var contact_buffer: float = 80.0
@export var retreat_speed_multiplier: float = 0.6
@export var max_eye_distance: float = 20.0 
@export var max_health: int = 100

const HUD_PATH: NodePath = ^"HUD"

# --- NEW: Shooting Variables ---
@export var bubble_scene: PackedScene
@export var shoot_interval: float = 0.6 
var _shoot_timer: float = 0.0
var _attack_anim_timer: float = 0.0 

var _state: BossState = BossState.IDLE
var _target: Node2D
var _home_y: float = 0.0
var _desired_personal_space: float = 0.0
var _current_health: int = 100
var _is_defeated: bool = false
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
	_current_health = max_health
	_is_defeated = false
	_home_y = global_position.y
	_resolve_target()
	_refresh_personal_space()
	_set_state(BossState.IDLE)
	_sync_boss_hud_health()

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_resolve_target()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# --- NEW: Tick down timers ---
	if _shoot_timer > 0.0:
		_shoot_timer -= delta
	if _attack_anim_timer > 0.0:
		_attack_anim_timer -= delta

	var distance_to_target: float = global_position.distance_to(_target.global_position)
	var attack_distance: float = maxf(stop_chase_distance, _desired_personal_space)
	match _state:
		BossState.IDLE:
			velocity = Vector2.ZERO
			if distance_to_target <= detection_range:
				_set_state(BossState.CHASE)
		BossState.HURT:
			velocity = Vector2.ZERO
		BossState.STUNNED:
			velocity = Vector2.ZERO
		BossState.CHASE:
			# --- NEW: Shoot while chasing ---
			if _shoot_timer <= 0.0:
				_shoot_bubble()
				_shoot_timer = shoot_interval
				
			if distance_to_target > disengage_range:
				_set_state(BossState.IDLE)
				velocity = Vector2.ZERO
			elif distance_to_target <= attack_distance:
				_set_state(BossState.ATTACK)
				_attack_anim_timer = 0.5 # Lock attack state for animation
				velocity = Vector2.ZERO
			else:
				_chase_target()
		BossState.ATTACK:
			# --- NEW: Shoot while attacking ---
			if _shoot_timer <= 0.0:
				_shoot_bubble()
				_shoot_timer = shoot_interval
				
			if distance_to_target < attack_distance * 0.9:
				_retreat_from_target()
			else:
				velocity = Vector2.ZERO
				
			if _attack_anim_timer <= 0.0:
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
		_target = _find_target_in_scene(current_scene)
		_refresh_personal_space()

func _find_target_in_scene(current_scene: Node) -> Node2D:
	var by_group: Node = get_tree().get_first_node_in_group("player")
	if by_group is Node2D and is_instance_valid(by_group):
		return by_group as Node2D

	var modern_player: Node2D = current_scene.get_node_or_null("Player_OH") as Node2D
	if modern_player != null:
		return modern_player

	return current_scene.get_node_or_null("Player") as Node2D

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
			
func take_damage(amount: int = 1, causes_stun: bool = false) -> void:
	if _is_defeated:
		return

	var safe_amount: int = maxi(amount, 0)
	_current_health = clampi(_current_health - safe_amount, 0, max_health)
	_sync_boss_hud_health()
	print("Boss HP -> ", _current_health, "/", max_health)

	if _current_health <= 0:
		_is_defeated = true
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
	var hud: Node = current_scene.get_node_or_null(HUD_PATH)
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
		
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		take_damage(10, false)

# --- NEW: Spawning the Bubble ---
func _shoot_bubble() -> void:
	if bubble_scene == null or _target == null:
		return
		
	var bubble = bubble_scene.instantiate()
	bubble.global_position = global_position
	bubble.direction = global_position.direction_to(_target.global_position)
	
	# Add the bullet to the main level, not the boss
	get_tree().current_scene.add_child(bubble)
