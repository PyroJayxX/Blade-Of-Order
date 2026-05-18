extends CharacterBody2D

signal boss_defeated

enum BossState {
	IDLE,
	HURT,
	STUNNED,
	ATTACKING,
	RAGE
}

enum AttackType {
	HOMING_LEAF,
	LEAF_VOLLEY,
	RAIN_OF_LEAVES,
	GROUND_SPIKE,
	LEAF_WALL,
	SPORE_BURST
}

# ── Target ──────────────────────────────────────────────────────────────────
@export var target_path: NodePath
@export var player: Node2D

# ── Health ───────────────────────────────────────────────────────────────────
@export var max_health: int = 500

# ── Face textures ─────────────────────────────────────────────────────────────
@export var face_normal: Texture2D = preload("res://assets/bosses/heap_boss/body_no_hands.png")
@export var face_hurt: Texture2D = preload("res://assets/bosses/heap_boss/hurt.png")
@export var face_stunned: Texture2D = preload("res://assets/bosses/heap_boss/stunned.png")

# ── Projectile scenes ────────────────────────────────────────────────────────
@export var homing_leaf_scene: PackedScene
@export var volley_leaf_scene: PackedScene
@export var rain_leaf_scene: PackedScene
@export var ground_spike_scene: PackedScene
@export var leaf_wall_scene: PackedScene
@export var spore_scene: PackedScene
@export var spike_warning_scene: PackedScene

# ── Attack 1 — Homing Leaf ───────────────────────────────────────────────────
@export var homing_cooldown: float = 4.0
@export var homing_count: int = 2
@export var homing_launch_interval: float = 0.3

# ── Attack 2 — Leaf Volley ───────────────────────────────────────────────────
@export var volley_cooldown: float = 3.5
@export var volley_count: int = 7
@export var volley_spread_deg: float = 60.0

# ── Attack 3 — Rain of Leaves ────────────────────────────────────────────────
@export var rain_cooldown: float = 5.0
@export var rain_count: int = 14
@export var rain_interval: float = 0.12
@export var rain_x_variance: float = 500.0

# ── Attack 4 — Ground Spike ──────────────────────────────────────────────────
@export var spike_cooldown: float = 4.5
@export var spike_sweep_count: int = 5
@export var spike_sweep_interval: float = 0.18
@export var spike_sweep_spacing: float = 120.0

# ── Attack 5 — Leaf Wall ─────────────────────────────────────────────────────
@export var wall_cooldown: float = 6.0
@export var wall_leaf_count: int = 10
@export var wall_spacing: float = 80.0
@export var wall_speed: float = 520.0
@export var ground_y: float = 550.0

# ── Attack 6 — Spore Burst (rage) ───────────────────────────────────────────
@export var spore_burst_duration: float = 6.0
@export var spore_shot_interval: float = 0.18
@export var spore_spread_deg: float = 100.0
@export var spore_waves: int = 10

# ── Hand tweening ────────────────────────────────────────────────────────────
@export var hand_tween_duration: float = 0.4

# ── Hurt display ─────────────────────────────────────────────────────────────
@export var hurt_face_duration: float = 0.5  

# ── Misc ─────────────────────────────────────────────────────────────────────
@export var attack_sequence_cooldown: float = 2.2

const HUD_PATH: NodePath = ^"HUD"

# ── Runtime state ─────────────────────────────────────────────────────────────
var _state: BossState = BossState.IDLE
var _target: Node2D
var _current_health: int
var _is_defeated: bool = false
var _combat_enabled: bool = true
var _rage_triggered: bool = false
var _attack_running: bool = false
var _sequence_timer: float = 0.0
var _hurt_timer: float = 0.0      # counts down the hurt face duration
var _is_hurt: bool = false       

var _hand_l_rest: Vector2
var _hand_r_rest: Vector2

var _cooldowns: Dictionary = {}

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hands_root: Node2D = $Hands
@onready var hand_l: Node2D = $Hands/HandL
@onready var hand_r: Node2D = $Hands/HandR
@onready var face_sprite: Sprite2D = $Body
@onready var hit_flash_player: AnimationPlayer = $HitFlash # hit effect animation boss

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_current_health = max_health
	_is_defeated = false
	_hand_l_rest = hand_l.position
	_hand_r_rest = hand_r.position
	_resolve_target()
	_reset_cooldowns()
	_sync_hud_health()
	_set_state(BossState.IDLE)
	anim_player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != "idle" and not _is_defeated:
		anim_player.play("idle")

func _physics_process(delta: float) -> void:
	if not _combat_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _target == null or not is_instance_valid(_target):
		_resolve_target()
		move_and_slide()
		return

	velocity = Vector2.ZERO

	# Tick hurt face timer — revert face once it expires
	if _is_hurt:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0:
			_is_hurt = false
			_update_face()

	_tick_cooldowns(delta)
	if _sequence_timer > 0.0:
		_sequence_timer -= delta

	match _state:
		BossState.IDLE:
			_set_state(BossState.ATTACKING)
		BossState.HURT:
			pass
		BossState.STUNNED:
			pass
		BossState.ATTACKING, BossState.RAGE:
			if not _attack_running and _sequence_timer <= 0.0:
				_pick_and_launch_attack()

	move_and_slide()

# ── State machine ─────────────────────────────────────────────────────────────

func _set_state(new_state: BossState) -> void:
	if _state == new_state:
		return
	_state = new_state
	print("Heap state -> ", _state_name(_state))

	_update_face()

	if anim_player == null:
		return
	match _state:
		BossState.IDLE:
			anim_player.play("idle")
		BossState.ATTACKING:
			anim_player.play("attack")
		BossState.RAGE:
			anim_player.play("rage")
		BossState.HURT:
			anim_player.play("hurt")
		BossState.STUNNED:
			anim_player.play("stunned")

func _update_face() -> void:
	if face_sprite == null:
		return
	if _is_defeated:
		if face_stunned:
			face_sprite.texture = face_stunned
	elif _is_hurt:
		if face_hurt:
			face_sprite.texture = face_hurt
	else:
		if face_normal:
			face_sprite.texture = face_normal

func _state_name(s: BossState) -> String:
	match s:
		BossState.IDLE: return "idle"
		BossState.HURT: return "hurt"
		BossState.STUNNED: return "STUNNED"
		BossState.ATTACKING: return "ATTACKING"
		BossState.RAGE: return "RAGE"
		_: return "UNKNOWN"

# ── Attack selection ──────────────────────────────────────────────────────────

func _pick_and_launch_attack() -> void:
	if _state == BossState.RAGE:
		if _cooldown_ready(AttackType.SPORE_BURST):
			_launch_attack(AttackType.SPORE_BURST)
		return

	var ready: Array = []
	for type in [
		AttackType.HOMING_LEAF,
		AttackType.LEAF_VOLLEY,
		AttackType.RAIN_OF_LEAVES,
		AttackType.GROUND_SPIKE,
		AttackType.LEAF_WALL
	]:
		if _cooldown_ready(type):
			ready.append(type)

	if ready.is_empty():
		return

	var chosen: AttackType = ready[randi() % ready.size()]
	_launch_attack(chosen)

func _launch_attack(type: AttackType) -> void:
	_attack_running = true
	_set_cooldown(type)
	_sequence_timer = attack_sequence_cooldown

	match type:
		AttackType.HOMING_LEAF:
			execute_homing_leaf()
		AttackType.LEAF_VOLLEY:
			execute_leaf_volley()
		AttackType.RAIN_OF_LEAVES:
			execute_rain_of_leaves()
		AttackType.GROUND_SPIKE:
			execute_ground_spike()
		AttackType.LEAF_WALL:
			execute_leaf_wall()
		AttackType.SPORE_BURST:
			execute_spore_burst()

# ── Attack 1 — Homing Leaf ───────────────────────────────────────────────────

func execute_homing_leaf() -> void:
	if _is_defeated:
		_attack_running = false
		return

	anim_player.play("attack_homing")
	await anim_player.animation_finished

	for i in range(maxi(homing_count, 1)):
		if _is_defeated:
			break
		_spawn_projectile(homing_leaf_scene, global_position, Vector2.ZERO, {"homing": true})
		if i < homing_count - 1:
			await get_tree().create_timer(homing_launch_interval).timeout

	_tween_hands_to_rest()
	_attack_running = false

# ── Attack 2 — Leaf Volley ───────────────────────────────────────────────────
func execute_leaf_volley() -> void:
	if _is_defeated:
		_attack_running = false
		return

	var player_is_right: bool = _target.global_position.x > global_position.x
	var active_hand: Node2D = hand_r if player_is_right else hand_l
	var offset: Vector2 = Vector2(40, -50) if player_is_right else Vector2(-40, -50)

	anim_player.play("attack_volley")
	await anim_player.animation_finished

	var base_dir: Vector2 = global_position.direction_to(_target.global_position)
	var base_angle: float = base_dir.angle()
	var half_spread: float = deg_to_rad(volley_spread_deg * 0.5)
	var count: int = maxi(volley_count, 3)
	var waves: int = randi_range(2, 3)

	for w in range(waves):
		if _is_defeated:
			break
		for i in range(count):
			if _is_defeated:
				break
			var t: float = float(i) / float(count - 1) if count > 1 else 0.5
			var angle: float = base_angle - half_spread + half_spread * 2.0 * t
			var dir: Vector2 = Vector2.RIGHT.rotated(angle)
			_spawn_projectile(volley_leaf_scene, global_position, dir, {})
		if w < waves - 1:
			await get_tree().create_timer(0.5).timeout

	_tween_hands_to_rest()
	_attack_running = false

# ── Attack 3 — Rain of Leaves ────────────────────────────────────────────────

func execute_rain_of_leaves() -> void:
	if _is_defeated:
		_attack_running = false
		return

	anim_player.play("attack_rain")
	await anim_player.animation_finished

	var viewport_rect: Rect2 = get_viewport_rect()
	var top_y: float = global_position.y - viewport_rect.size.y * 0.5 - 500.0

	for i in range(maxi(rain_count, 1)):
		if _is_defeated:
			break
		var x_offset: float = randf_range(-rain_x_variance, rain_x_variance)
		var spawn_pos: Vector2 = Vector2(_target.global_position.x + x_offset, top_y)
		_spawn_projectile(rain_leaf_scene, spawn_pos, Vector2.DOWN, {})
		await get_tree().create_timer(rain_interval).timeout

	_tween_hands_to_rest()
	_attack_running = false

# ── Attack 4 — Ground Spike ──────────────────────────────────────────────────

func execute_ground_spike() -> void:
	if _is_defeated:
		_attack_running = false
		return

	anim_player.play("attack_spike")
	await anim_player.animation_finished

	for i in range(maxi(spike_sweep_count, 1)):
		if _is_defeated:
			break

		var spike_x: float = _target.global_position.x + randf_range(-80.0, 80.0)
		var spawn_pos: Vector2 = Vector2(spike_x, 800)

		var warning: Node = null
		if spike_warning_scene != null:
			warning = spike_warning_scene.instantiate()
			warning.global_position = spawn_pos
			_get_level_root().add_child(warning)

		var captured_warning = warning
		var captured_pos = spawn_pos
		get_tree().create_timer(0.8).timeout.connect(func():
			if _is_defeated:
				if is_instance_valid(captured_warning):
					captured_warning.queue_free()
				return
			_spawn_projectile(ground_spike_scene, captured_pos, Vector2.UP, {"lifetime_override": 1.5})
			if is_instance_valid(captured_warning):
				captured_warning.queue_free()
		)

		await get_tree().create_timer(spike_sweep_interval).timeout

	_tween_hands_to_rest()
	_attack_running = false

# ── Attack 5 — Leaf Wall ─────────────────────────────────────────────────────

func execute_leaf_wall() -> void:
	if _is_defeated:
		_attack_running = false
		return

	var player_is_right: bool = _target.global_position.x > global_position.x
	var travel_dir: Vector2 = Vector2.RIGHT if player_is_right else Vector2.LEFT

	anim_player.play("attack_wall")
	await anim_player.animation_finished

	var spawn_pos: Vector2 = Vector2(global_position.x, ground_y)
	_spawn_projectile(leaf_wall_scene, spawn_pos, travel_dir, {"speed_override": wall_speed, "ground_snap_y": 400.0})

	_tween_hands_to_rest()
	_attack_running = false

# ── Attack 6 — Spore Burst (rage) ────────────────────────────────────────────

func execute_spore_burst() -> void:
	if _is_defeated:
		_attack_running = false
		return

	anim_player.play("attack_spore")
	await anim_player.animation_finished

	var elapsed: float = 0.0
	var step: float = maxf(spore_shot_interval, 0.01)

	while elapsed < maxf(spore_burst_duration, 0.1):
		if not is_inside_tree() or _is_defeated:
			break

		var base_dir: Vector2 = global_position.direction_to(_target.global_position)
		var base_angle: float = base_dir.angle()
		var half: float = deg_to_rad(spore_spread_deg * 0.5)
		var waves: int = maxi(spore_waves, 1)

		for w in range(waves):
			var t: float = float(w) / float(waves - 1) if waves > 1 else 0.5
			var angle: float = base_angle - half + half * 2.0 * t
			_spawn_projectile(spore_scene, global_position, Vector2.RIGHT.rotated(angle), {})

		await get_tree().create_timer(step).timeout
		elapsed += step

	_tween_hands_to_rest()
	_attack_running = false

# ── Hand tweening ─────────────────────────────────────────────────────────────

func _tween_hands_to_rest() -> void:
	if not is_instance_valid(hand_l) or not is_instance_valid(hand_r):
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(hand_l, "position", _hand_l_rest, hand_tween_duration)
	tween.tween_property(hand_r, "position", _hand_r_rest, hand_tween_duration)

# ── Projectile spawning ───────────────────────────────────────────────────────

func _spawn_projectile(scene: PackedScene, spawn_pos: Vector2, dir: Vector2, props: Dictionary) -> void:
	if scene == null:
		return
	var level_root: Node = _get_level_root()
	if level_root == null:
		return

	var proj: Node = scene.instantiate()
	if proj == null:
		return

	proj.global_position = spawn_pos

	if dir != Vector2.ZERO and proj.get("direction") != null:
		proj.direction = dir.normalized()

	if props.get("homing", false) and proj.get("target") != null:
		proj.target = _target

	if props.has("speed_override") and proj.get("speed") != null:
		proj.speed = props["speed_override"]
		
	if props.has("ground_snap_y") and proj.get("scale") != null:
		var half_height: float = props["ground_snap_y"]
		proj.global_position.y -= proj.scale.y * half_height

	level_root.add_child(proj)

# ── Damage & defeat ───────────────────────────────────────────────────────────

func take_damage(amount: int = 1, causes_stun: bool = false) -> void:
	if _is_defeated:
		return

	var safe_amount: int = maxi(amount, 0)
	
	if safe_amount > 0:
		hit_flash_player.stop() # forces the animation to restart if hit rapidly
		hit_flash_player.play("hit_animation")

	_current_health = clampi(_current_health - maxi(amount, 0), 0, max_health)
	_sync_hud_health()
	print("Heap HP -> ", _current_health, "/", max_health)

	# Show hurt face for a short duration — does NOT interrupt attack
	_is_hurt = true
	_hurt_timer = hurt_face_duration
	_update_face()

	# Play hurt animation as a one-shot overlay if it exists, then revert
	if anim_player and anim_player.has_animation("hurt"):
		anim_player.play("hurt")

	# Check rage threshold
	if not _rage_triggered and _current_health <= 100:
		_rage_triggered = true
		_trigger_rage()
		return

	if _current_health <= 0:
		_defeat()
		return


func _trigger_rage() -> void:
	print("Heap entered RAGE phase!")
	_attack_running = false
	_set_cooldown(AttackType.SPORE_BURST)
	_set_state(BossState.RAGE)

func _defeat() -> void:
	if _is_defeated:
		return
	AudioController.play_boss_stunned()
	_is_defeated = true
	_attack_running = false
	_is_hurt = false
	velocity = Vector2.ZERO
	_set_state(BossState.IDLE)
	boss_defeated.emit()

# ── Health HUD ────────────────────────────────────────────────────────────────

func _sync_hud_health() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var hud: Node = current_scene.find_child("HUD", true, false)
	if hud == null:
		hud = current_scene.get_node_or_null(HUD_PATH)
	if hud != null and hud.has_method("set_boss_health"):
		hud.call("set_boss_health", _current_health, max_health)

func on_stun_started_mock() -> void:
	_attack_running = false
	_set_state(BossState.STUNNED)
	print("Stun puzzle opened.")

func on_stun_modal_closed_mock() -> void:
	if _state == BossState.STUNNED:
		_set_state(BossState.IDLE)
	print("Stun puzzle closed.")

func on_sealing_success_mock() -> void:
	print("Sealing success.")
	_set_state(BossState.IDLE)

func on_resonance_surge_mock() -> void:
	print("Resonance Surge.")
	_set_state(BossState.ATTACKING)

# ── Cooldown helpers ──────────────────────────────────────────────────────────

func _reset_cooldowns() -> void:
	_cooldowns = {
		AttackType.HOMING_LEAF: 0.0,
		AttackType.LEAF_VOLLEY: 0.0,
		AttackType.RAIN_OF_LEAVES: 0.0,
		AttackType.GROUND_SPIKE: 0.0,
		AttackType.LEAF_WALL: 0.0,
		AttackType.SPORE_BURST: 0.0
	}

func _tick_cooldowns(delta: float) -> void:
	for key in _cooldowns.keys():
		if _cooldowns[key] > 0.0:
			_cooldowns[key] -= delta

func _cooldown_ready(type: AttackType) -> bool:
	return _cooldowns.get(type, 0.0) <= 0.0

func _set_cooldown(type: AttackType) -> void:
	match type:
		AttackType.HOMING_LEAF:    _cooldowns[type] = homing_cooldown
		AttackType.LEAF_VOLLEY:    _cooldowns[type] = volley_cooldown
		AttackType.RAIN_OF_LEAVES: _cooldowns[type] = rain_cooldown
		AttackType.GROUND_SPIKE:   _cooldowns[type] = spike_cooldown
		AttackType.LEAF_WALL:      _cooldowns[type] = wall_cooldown
		AttackType.SPORE_BURST:    _cooldowns[type] = spore_burst_duration + 2.0

# ── Target resolution ─────────────────────────────────────────────────────────

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
		var by_group: Node = get_tree().get_first_node_in_group("player")
		if by_group is Node2D and is_instance_valid(by_group):
			_target = by_group as Node2D
			return
		_target = current_scene.find_child("Player_OH", true, false) as Node2D
		if _target == null:
			_target = current_scene.find_child("Player", true, false) as Node2D

# ── Level root helper ─────────────────────────────────────────────────────────

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

# ── Public API ────────────────────────────────────────────────────────────────

func reset_for_retry(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_combat_enabled = true
	_current_health = max_health
	_is_defeated = false
	_rage_triggered = false
	_attack_running = false
	_is_hurt = false
	_hurt_timer = 0.0
	_sequence_timer = 0.0
	hand_l.position = _hand_l_rest
	hand_r.position = _hand_r_rest
	_reset_cooldowns()
	_sync_hud_health()
	_set_state(BossState.ATTACKING)

func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled
	if not _combat_enabled:
		velocity = Vector2.ZERO
		_attack_running = false
		_sequence_timer = 0.0
		_set_state(BossState.IDLE)

# ── Debug ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		take_damage(10, false)
