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
@export var stop_chase_distance: float = 1250.0
@export var chase_speed: float = 250.0
@export var keep_y_position: bool = true
@export var contact_buffer: float = 80.0
@export var retreat_speed_multiplier: float = 0.6
@export var max_eye_distance: float = 20.0 

# --- NEW: Shooting Variables ---
@export var bubble_scene: PackedScene
@export var shoot_interval: float = 0.6 
var _shoot_timer: float = 0.0
var _attack_anim_timer: float = 0.0 # Re-added so your ATTACK animation doesn't glitch

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
			
func take_damage(_amount: int, causes_stun: bool = false) -> void:
	if causes_stun:
		_set_state(BossState.STUNNED)
	else:
		_set_state(BossState.HURT)
		await anim_player.animation_finished
		_set_state(BossState.CHASE)

func on_stun_started_mock() -> void:
	_set_state(BossState.STUNNED)
	print("Stun puzzle opened (mock hook).")

func on_stun_modal_closed_mock() -> void:
	if _state == BossState.STUNNED:
		_set_state(BossState.CHASE)
	print("Stun puzzle closed (mock hook).")

func on_sealing_success_mock() -> void:
	print("Sealing success (mock hook). TODO: apply real sealing outcome.")
	_set_state(BossState.IDLE)

func on_resonance_surge_mock() -> void:
	print("Resonance Surge (mock hook). TODO: restore boss HP to full.")
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
	bubble.direction = global_position.direction_to(_get_predicted_target_position(bubble.speed))
	
	# Add the bullet to the main level, not the boss
	get_tree().current_scene.add_child(bubble)

func _get_predicted_target_position(projectile_speed: float) -> Vector2:
	var target_position: Vector2 = _target.global_position
	var target_velocity: Vector2 = _get_target_velocity()
	var to_target: Vector2 = target_position - global_position
	var distance_squared: float = to_target.length_squared()

	if distance_squared <= 0.0001 or projectile_speed <= 0.0001:
		return target_position

	var a: float = target_velocity.length_squared() - projectile_speed * projectile_speed
	var b: float = 2.0 * to_target.dot(target_velocity)
	var c: float = distance_squared
	var time_to_hit: float = 0.0

	if absf(a) < 0.0001:
		if absf(b) > 0.0001:
			time_to_hit = -c / b
	else:
		var discriminant: float = b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var sqrt_discriminant: float = sqrt(discriminant)
			var time_one: float = (-b - sqrt_discriminant) / (2.0 * a)
			var time_two: float = (-b + sqrt_discriminant) / (2.0 * a)
			time_to_hit = minf(time_one if time_one > 0.0 else INF, time_two if time_two > 0.0 else INF)

	if time_to_hit <= 0.0 or is_inf(time_to_hit):
		time_to_hit = to_target.length() / projectile_speed

	return target_position + target_velocity * time_to_hit

func _get_target_velocity() -> Vector2:
	if _target is CharacterBody2D:
		return (_target as CharacterBody2D).velocity
	return Vector2.ZERO
