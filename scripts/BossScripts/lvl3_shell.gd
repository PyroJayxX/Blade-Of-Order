extends CharacterBody2D

signal boss_defeated

enum BossState {
	IDLE,
	CHASE,
	HURT,
	STUNNED
}

@export var target_path: NodePath
@export var player: Node2D
@export var chase_speed: float = 800.0
@export var max_health: int = 100
@export var right_offset: float = 1200.0
@export var hover_amplitude: float = 30.0
@export var hover_speed: float = 2.0
@export var vulnerable_delay: float = 20.0
@export var vulnerable_duration: float = 5.0
@export var lower_speed: float = 100.0
@export var vulnerable_y_offset: float = 150.0
@export var shell_projectile_scene: PackedScene = preload("res://scenes/Bosses/Level3/Shell/ShellProjectile.tscn")
@export var shell_attack_interval: float = 0.45
@export var world_min_x: float = -1000.0
@export var world_max_x: float = 2000.0

const HUD_PATH: NodePath = ^"HUD"

var _state: BossState = BossState.IDLE
var _target: Node2D
var _home_y: float = 0.0
var _current_health: int = 100
var _is_defeated: bool = false
var _combat_enabled: bool = true
var _hover_timer: float = 0.0
var _vulnerable_timer: float = 0.0
var _vulnerable_duration_timer: float = 0.0
var _is_vulnerable: bool = false
var _shell_replay_timer: float = 0.0
var _direction: int = 1

# Phase Control Variables
var _phase_2_triggered: bool = false # 50% HP
var _phase_3_triggered: bool = false # 20% HP
var _is_aoe_active: bool = false
var _aoe_timer: float = 0.0

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hit_flash_player: AnimationPlayer = $HitFlash # hit effect animation boss
@onready var _shell_sort_puzzle: CanvasLayer = $ShellSort



func _ready() -> void:
	_current_health = max_health
	_is_defeated = false
	_home_y = global_position.y
	_vulnerable_timer = vulnerable_delay
	_vulnerable_duration_timer = 0.0
	_is_vulnerable = false
	_hover_timer = 0.0
	_shell_replay_timer = 0.0
	_direction = 1
	_resolve_target()
	_sync_boss_hud_health()
	
	# Give the Cutscene instance one frame to finish its own _ready() setup.
	await get_tree().process_frame

	# If a Cutscene node exists in the level scene, play it before enabling combat
	var cutscene: Node = null
	if get_tree().current_scene != null:
		cutscene = get_tree().current_scene.get_node_or_null("Cutscene")
	if cutscene == null and get_tree().current_scene != null:
		cutscene = get_tree().current_scene.find_child("Cutscene", true, false)
	if cutscene != null:
		print("[lvl3_shell] Found Cutscene node:", cutscene)
		print("[lvl3_shell] script:", cutscene.get_script())
		print("[lvl3_shell] has play():", cutscene.has_method("play"))
		print("[lvl3_shell] has signal cutscene_finished:", cutscene.has_signal("cutscene_finished"))
		if cutscene.has_method("play"):
			_combat_enabled = false
			print("[lvl3_shell] calling play() on Cutscene")
			cutscene.call("play")
			print("[lvl3_shell] play() called — awaiting finish signal")
			await cutscene.cutscene_finished
			print("[lvl3_shell] cutscene_finished signal received")
			_combat_enabled = true
		else:
			print("[lvl3_shell] Cutscene node found but has no play() method")
	else:
		print("[lvl3_shell] No Cutscene node found in current_scene")

	_set_state(BossState.CHASE)
	
	
	if _shell_sort_puzzle != null:
		_shell_sort_puzzle.visible = false
	if _shell_sort_puzzle != null:
		if _shell_sort_puzzle.has_signal("puzzle_completed"):
			_shell_sort_puzzle.puzzle_completed.connect(_on_puzzle_completed)

		if _shell_sort_puzzle.has_signal("puzzle_failed"):
			_shell_sort_puzzle.puzzle_failed.connect(_on_puzzle_failed)


func _physics_process(delta: float) -> void:
	if _is_defeated or not _combat_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _target == null or not is_instance_valid(_target):
		_resolve_target()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Handle the 3-second AOE timer logic
	if _is_aoe_active:
		_aoe_timer -= delta
		if _aoe_timer <= 0:
			_is_aoe_active = false

	# INVULNERABLE PHASE ATTACK LOGIC
	if not _is_vulnerable:
		_shell_replay_timer -= delta
		if _shell_replay_timer <= 0.0:
			# DECIDE ATTACK TYPE
			if _is_aoe_active:
				_spawn_aoe_attack()
				_shell_replay_timer = 0.6 # AOE timing
			elif _phase_2_triggered:
				_spawn_triple_shell()
				_shell_replay_timer = shell_attack_interval
			else:
				_spawn_shell_projectile()
				_shell_replay_timer = shell_attack_interval

		# Countdown to vulnerable state
		_vulnerable_timer -= delta
		if _vulnerable_timer <= 0.0:
			_is_vulnerable = true
			_vulnerable_duration_timer = vulnerable_duration
			_shell_replay_timer = 0.0
			print("Shell Boss is now vulnerable!")
	else:
		# Vulnerable phase behavior
		_vulnerable_duration_timer -= delta
		if _vulnerable_duration_timer <= 0.0:
			_is_vulnerable = false
			_vulnerable_timer = vulnerable_delay
			_shell_replay_timer = 0.0
			if anim_player != null:
				anim_player.play("idle")
			print("Shell Boss is now invulnerable again!")

	_hover_timer += delta
	var hover_offset: float = sin(_hover_timer * hover_speed) * hover_amplitude
	var target_pos: Vector2 = _target.global_position

	match _state:
		BossState.CHASE:
			_chase_target(delta, hover_offset, target_pos)
		_:
			velocity = Vector2.ZERO
			global_position.y = _home_y + hover_offset

	move_and_slide()

# --- HEALTH AND PHASES ---

func take_damage(amount: int = 10, causes_stun: bool = false) -> void:
	if _is_defeated: return

	var safe_amount: int = maxi(amount, 0)
	
	if safe_amount > 0:
		hit_flash_player.stop() # forces the animation to restart if hit rapidly
		hit_flash_player.play("hit_animation")
	
	_current_health = clampi(_current_health - safe_amount, 0, max_health)
	_sync_boss_hud_health()
	
	# Correct Percentage Calculation
	var health_percent: float = (float(_current_health) / float(max_health)) * 100.0

	if health_percent <= 50.0 and not _phase_2_triggered:
		_phase_2_triggered = true
		print("Phase 2: Triple Shot Active!")

	if health_percent <= 20.0 and not _phase_3_triggered:
		_phase_3_triggered = true
		_is_aoe_active = true
		_aoe_timer = 3.0 
		print("Phase 3: AOE Burst Initiated!")

	if _current_health <= 0:
		_die()
		return

	if causes_stun:
		_set_state(BossState.STUNNED)
	else:
		_set_state(BossState.HURT)
		if anim_player != null:
			await anim_player.animation_finished
		if not _is_defeated:
			_set_state(BossState.CHASE)

func _die() -> void:
	_is_defeated = true
	velocity = Vector2.ZERO
	_set_state(BossState.STUNNED)

	if has_node("ShellBossFront"):
		$ShellBossFront.visible = false

	if has_node("ShellBossStunned"):
		$ShellBossStunned.visible = true

	boss_defeated.emit()

	# SHOW PUZZLE HERE
	if _shell_sort_puzzle != null:
		_shell_sort_puzzle.visible = true

# --- SPAWNING LOGIC ---

func _spawn_shell_projectile() -> void:
	var dir = global_position.direction_to(_target.global_position).normalized()
	_internal_spawn_projectile(dir)

func _spawn_triple_shell() -> void:
	var spread_angle: float = 25.0
	var base_dir: Vector2 = global_position.direction_to(_target.global_position)
	for i in range(-1, 2):
		var angle: float = deg_to_rad(i * spread_angle)
		_internal_spawn_projectile(base_dir.rotated(angle))

func _spawn_aoe_attack() -> void:
	var pearls_count: int = 8
	for i in range(pearls_count):
		var angle: float = (PI * 2 / pearls_count) * i
		_internal_spawn_projectile(Vector2.RIGHT.rotated(angle))

func _internal_spawn_projectile(dir: Vector2) -> void:
	if shell_projectile_scene == null or _target == null: return
	var level_root = _get_level_root()
	var projectile = shell_projectile_scene.instantiate() as Node2D
	projectile.global_position = global_position
	if "direction" in projectile:
		projectile.direction = dir
	level_root.add_child(projectile)

# --- UTILITY ---

func _get_level_root() -> Node:
	var node: Node = self
	while node != null:
		var parent: Node = node.get_parent()
		if parent == null: break
		if parent.name == "ContentRoot": return node
		node = parent
	return get_tree().current_scene

func _chase_target(_delta: float, hover_offset: float, target_pos: Vector2) -> void:
	var to_player: Vector2 = target_pos - global_position
	var distance: float = to_player.length()

	if not _is_vulnerable:
		# Keep vertical hover height
		global_position.y = _home_y + hover_offset

		# Determine where the player is looking to stay behind them
		var player_facing: int = 1
		if _target.has_method("get_facing_dir"):
			player_facing = _target.get_facing_dir()
		elif "facing_dir" in _target:
			player_facing = _target.facing_dir
		else:
			player_facing = sign(to_player.x)

		var preferred_side: int = -player_facing
		var boss_side: int = sign(global_position.x - target_pos.x)

		# Distance logic
		var too_close: float = 350.0
		var ideal_distance: float = 650.0
		var move_dir: int = 0

		# PRIORITY 1: ESCAPE IF TOO CLOSE
		if distance < too_close:
			move_dir = sign(global_position.x - target_pos.x)

		# PRIORITY 2: POSITION AWAY FROM PLAYER FACING
		elif boss_side == player_facing:
			move_dir = preferred_side

		# PRIORITY 3: NORMAL CHASE WITH BIAS
		else:
			if distance > ideal_distance:
				move_dir = sign(to_player.x)
			else:
				move_dir = preferred_side

		velocity.x = move_dir * chase_speed
		velocity.y = 0.0

		# Boundary safety: Clamp X position
	if global_position.x <= world_min_x and velocity.x < 0:
		velocity.x = 0

	if global_position.x >= world_max_x and velocity.x > 0:
		velocity.x = 0

	else:
		# Vulnerable phase: Move directly toward the player slowly
		var move_dir: Vector2 = to_player.normalized()
		velocity = move_dir * lower_speed
		global_position.y = _home_y + hover_offset

func _resolve_target() -> void:
	if player != null and is_instance_valid(player):
		_target = player
		return
	_target = get_tree().get_first_node_in_group("player")

func _set_state(new_state: BossState) -> void:
	if _state == new_state: return
	_state = new_state
	if anim_player != null:
		anim_player.play(_state_to_text(_state).to_lower())

func _state_to_text(state: BossState) -> String:
	return BossState.keys()[state]

func _sync_boss_hud_health() -> void:
	var hud = get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("set_boss_health"):
		hud.set_boss_health(_current_health, max_health)

func reset_for_retry(spawn_position: Vector2) -> void:
	global_position = spawn_position
	_current_health = max_health
	_is_defeated = false
	_phase_2_triggered = false
	_phase_3_triggered = false
	_is_aoe_active = false
	_set_state(BossState.CHASE)
	_sync_boss_hud_health()

func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled
	if not _combat_enabled: _set_state(BossState.IDLE)


func _on_puzzle_completed() -> void:
	print("Puzzle Completed")
	$LevelCleared.visible = true

	if _shell_sort_puzzle != null:
		_shell_sort_puzzle.visible = false


func _on_puzzle_failed() -> void:
	print("Puzzle Failed")
	$GameOver.visible = true

	if _shell_sort_puzzle != null:
		_shell_sort_puzzle.visible = false
