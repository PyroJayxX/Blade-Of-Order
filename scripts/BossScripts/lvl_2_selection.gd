extends CharacterBody2D

signal boss_defeated

enum BossState {
	IDLE,
	CHASE,
	HURT,
	STUNNED
}

@export var target_path: NodePath # path to player node if assigned in scene
@export var player: Node2D # direct player reference used for targeting
@export var chase_speed: float = 800.0 # horizontal movement speed
@export var max_health: int = 100 # total boss hp
@export var right_offset: float = 1200.0 # distance to the right of player
@export var hover_amplitude: float = 30.0 # height of hover bobbing
@export var hover_speed: float = 2.0 # speed of hover animation
@export var vulnerable_delay: float = 20.0 # seconds before boss becomes vulnerable
@export var vulnerable_duration: float = 5.0 # duration of vulnerable state in seconds
@export var lower_speed: float = 100.0 # speed at which boss lowers down
@export var vulnerable_y_offset: float = 150.0 # how far down to lower during vulnerable state

var _state: BossState = BossState.IDLE
var _target: Node2D # resolved player target
var _home_y: float = 0.0 # baseline y position to maintain
var _current_health: int = 100
var _is_defeated: bool = false
var _combat_enabled: bool = true
var _hover_timer: float = 0.0 # timer for hovering animation
var _vulnerable_timer: float = 0.0 # timer until boss becomes vulnerable
var _vulnerable_duration_timer: float = 0.0 # timer tracking how long boss has been vulnerable
var _is_vulnerable: bool = false # whether boss can be hit
var _attack_window_active: bool = false # whether the boss is currently in the attack window
var _kunai_replay_timer: float = 0.0 # timer for replaying kunai animation

@onready var anim_player: AnimationPlayer = $AnimationPlayer # animation player for state visuals
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D # animated sprite for frame animations

func _ready() -> void:
	_current_health = max_health
	_is_defeated = false
	_home_y = global_position.y
	_vulnerable_timer = vulnerable_delay
	_is_vulnerable = false
	_resolve_target()

	# If a Cutscene node exists in the level scene, play it before enabling combat
	var cutscene: Node = null
	# Try direct child first
	if get_tree().current_scene != null:
		cutscene = get_tree().current_scene.get_node_or_null("Cutscene")
	# Fallback: search recursively in case it's nested or named differently
	if cutscene == null and get_tree().current_scene != null:
		cutscene = get_tree().current_scene.find_child("Cutscene", true, false)
	if cutscene != null:
		print("[lvl_2_selection] Found Cutscene node:", cutscene)
		if cutscene.has_method("play"):
			set_combat_enabled(false)
			cutscene.call("play")
			await cutscene.cutscene_finished
			set_combat_enabled(true)
		else:
			print("[lvl_2_selection] Cutscene node found but has no play() method")
	else:
		print("[lvl_2_selection] No Cutscene node found in current_scene")

	_set_state(BossState.CHASE)

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

	# Update vulnerability cycle
	if not _is_vulnerable:
		if _vulnerable_timer > 0.0:
			_vulnerable_timer -= delta
			if _vulnerable_timer <= 0.0:
				_is_vulnerable = true
				_vulnerable_duration_timer = vulnerable_duration
				_attack_window_active = false
				print("Selection Boss is now vulnerable!")
	else:
		if _vulnerable_duration_timer > 0.0:
			_vulnerable_duration_timer -= delta
			if _vulnerable_duration_timer <= 0.0:
				_is_vulnerable = false
				_vulnerable_timer = vulnerable_delay
				_attack_window_active = false
				_kunai_replay_timer = 0.0
				if anim_player != null:
					anim_player.play("chase")
				print("Selection Boss is now invulnerable again!")

	# Play kunai attacks continuously from 5 to 19 seconds in the invulnerable state
	if not _is_vulnerable and _vulnerable_timer > 0.0:
		var time_in_cycle: float = vulnerable_delay - _vulnerable_timer
		var in_attack_window: bool = time_in_cycle >= 5.0 and time_in_cycle <= 19.0
		if in_attack_window:
			if not _attack_window_active:
				_attack_window_active = true
				_kunai_replay_timer = 0.0
		else:
			if _attack_window_active:
				_attack_window_active = false
				if anim_player != null:
					anim_player.play("chase")

	# Handle kunai animation replay while in attack window
	if _attack_window_active and animated_sprite != null:
		if not animated_sprite.is_playing():
			_kunai_replay_timer -= delta
			if _kunai_replay_timer <= 0.0:
				animated_sprite.play("kunai_attack")
				_kunai_replay_timer = 1.0 # one second delay between attacks

	# Update hover timer for animation
	_hover_timer += delta
	
	# Apply hovering effect to all states
	var hover_offset: float = sin(_hover_timer * hover_speed) * hover_amplitude
	var target_pos: Vector2 = _target.global_position if _target != null and is_instance_valid(_target) else Vector2.ZERO

	match _state:
		BossState.IDLE:
			velocity = Vector2.ZERO
			global_position.y = _home_y + hover_offset
		BossState.HURT:
			velocity = Vector2.ZERO
			global_position.y = _home_y + hover_offset
		BossState.STUNNED:
			velocity = Vector2.ZERO
			global_position.y = _home_y + hover_offset
		BossState.CHASE:
			_chase_target(delta, hover_offset, target_pos)

	move_and_slide()

func _chase_target(delta: float, hover_offset: float, target_pos: Vector2) -> void:
	# Position to the right of the player
	var desired_x: float = target_pos.x + right_offset
	var desired_y: float = _home_y
	
	# If vulnerable, lock x position and lower the boss down relative to player
	if _is_vulnerable:
		# Lock x position - don't move horizontally when vulnerable
		# Lower the boss relative to player during vulnerable state
		desired_y = target_pos.y + vulnerable_y_offset + hover_offset
		global_position.y = lerp(global_position.y, desired_y, delta * lower_speed / 100.0)
		# Keep x position unchanged when vulnerable
		velocity = Vector2.ZERO
	else:
		# While invulnerable, hover at original height and follow player
		desired_y += hover_offset
		global_position.y = desired_y
		
		# Smoothly move horizontally toward desired position using lerp
		global_position.x = lerp(global_position.x, desired_x, delta * chase_speed / 100.0)
		velocity = Vector2.ZERO
	
	velocity.y = 0.0

func _resolve_target() -> void:
	if player != null and is_instance_valid(player):
		_target = player
		return

	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node2D
		if _target != null:
			return

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_target = _find_target_in_scene(current_scene)

func _find_target_in_scene(current_scene: Node) -> Node2D:
	var by_group: Node = get_tree().get_first_node_in_group("player")
	if by_group is Node2D and is_instance_valid(by_group):
		return by_group as Node2D

	var modern_player: Node2D = current_scene.find_child("Player_OH", true, false) as Node2D
	if modern_player != null:
		return modern_player

	return current_scene.find_child("Player", true, false) as Node2D

func _set_state(new_state: BossState) -> void:
	if _state == new_state:
		return
	_state = new_state
	print("Selection Boss state -> ", _state_to_text(_state))

	if anim_player != null:
		match _state:
			BossState.IDLE:
				anim_player.play("idle")
			BossState.CHASE:
				anim_player.play("chase")
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
		_:
			return "UNKNOWN"

func take_damage(amount: int = 1, causes_stun: bool = false) -> void:
	if _is_defeated or not _is_vulnerable:
		return

	var safe_amount: int = maxi(amount, 0)
	_current_health = clampi(_current_health - safe_amount, 0, max_health)
	print("Selection Boss HP -> ", _current_health, "/", max_health)

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

func reset_for_retry(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_combat_enabled = true
	_current_health = max_health
	_is_defeated = false
	_home_y = global_position.y
	_vulnerable_timer = vulnerable_delay
	_is_vulnerable = false
	_vulnerable_duration_timer = 0.0
	_hover_timer = 0.0
	_attack_window_active = false
	_kunai_replay_timer = 0.0
	_set_state(BossState.CHASE)

func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled
	if not _combat_enabled:
		velocity = Vector2.ZERO
		_set_state(BossState.IDLE)
		_vulnerable_timer = vulnerable_delay
		_is_vulnerable = false
		_vulnerable_duration_timer = 0.0
	_attack_window_active = false
	_kunai_replay_timer = 0.0
