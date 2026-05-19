extends CharacterBody2D

signal boss_defeated

enum BossState {
	IDLE,
	ATTACKING,   
	VULNERABLE,  
	HURT,
	STUNNED
}

@export var max_health: int = 100
var _current_health: int = 100
var _state: BossState = BossState.IDLE
var _is_defeated: bool = false

const HUD_PATH: NodePath = ^"HUD"

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hit_flash_player: AnimationPlayer = $HitFlash
@onready var animated_sprite = $AnimatedSprite2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export var kunai_scene: PackedScene
@export var player: Node2D

# --- MOVEMENT CONFIGURATION ---
@export var hover_offset: Vector2 = Vector2(1400, -500) 
@export var follow_smoothness: float = 12.0           
@export var attack_duration: float = 8.0              
@export var drop_gravity: float = 980.0               

# --- FIXED: AUTOMATIC DOWN WINDOW ---
# The total duration (in seconds) the boss stays grounded on the floor 
# regardless of whether the player attacks him or not.
@export var hit_vulnerability_window: float = 2.2

# --- SPACING & WEIGHT CONFIGURATION ---
@export var sky_height_fallback: float = -750.0
@export var horizontal_spacing: float = 460.0

@export var outer_slots_weight: int = 1   
@export var inner_slots_weight: int = 2   
@export var center_slot_weight: int = 5   

@export var spawn_cooldown: float = 0.5 

var rain_timer: Timer
var state_timer: Timer 

func _ready() -> void:
	print("Boss Initialized")
	_current_health = max_health
	_is_defeated = false
	
	setup_timers()
	_set_state(BossState.ATTACKING)
	_sync_boss_hud_health()

func _physics_process(delta: float) -> void:
	if _is_defeated:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	match _state:
		BossState.ATTACKING:
			if player != null:
				var target_pos = player.global_position + hover_offset
				global_position = global_position.lerp(target_pos, follow_smoothness * delta)
			velocity = Vector2.ZERO
			
		BossState.VULNERABLE:
			if not is_on_floor():
				velocity.y += drop_gravity * delta
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
			move_and_slide()
			
		BossState.IDLE, BossState.HURT, BossState.STUNNED:
			velocity = Vector2.ZERO
			move_and_slide()

func _set_state(new_state: BossState) -> void:
	if _state == new_state:
		return
	_state = new_state
	print("Kunai Boss state -> ", _state_to_text(_state))

	match _state:
		BossState.ATTACKING:
			if anim_player != null: anim_player.play("chase") 
			if rain_timer: rain_timer.start()
			state_timer.start(attack_duration) 
			
		BossState.VULNERABLE:
			if animated_sprite != null: animated_sprite.play("loading")
			if rain_timer: rain_timer.stop()
			# --- CHANGED: Vulnerability timer starts IMMEDIATELY upon entering state ---
			state_timer.start(hit_vulnerability_window) 
			
		BossState.HURT:
			if anim_player != null: anim_player.play("hurt")
			if rain_timer: rain_timer.stop()
			state_timer.stop()

		BossState.STUNNED:
			if anim_player != null: anim_player.play("stunned")
			if rain_timer: rain_timer.stop()
			state_timer.stop()

func _state_to_text(state: BossState) -> String:
	match state:
		BossState.IDLE: return "IDLE"
		BossState.ATTACKING: return "ATTACKING"
		BossState.VULNERABLE: return "VULNERABLE"
		BossState.HURT: return "HURT"
		BossState.STUNNED: return "STUNNED"
		_: return "UNKNOWN"

func take_damage(amount: int = 1, causes_stun: bool = false) -> void:
	if _is_defeated:
		return

	var safe_amount: int = maxi(amount, 0)
	
	if safe_amount > 0 and hit_flash_player != null:
		hit_flash_player.stop() 
		hit_flash_player.play("hit_animation")
	
	_current_health = clampi(_current_health - safe_amount, 0, max_health)
	_sync_boss_hud_health()
	print("Boss HP -> ", _current_health, "/", max_health)

	if _current_health <= 0:
		AudioController.play_boss_stunned()
		_is_defeated = true
		if rain_timer: rain_timer.stop()
		if state_timer: state_timer.stop()
		velocity = Vector2.ZERO
		_set_state(BossState.IDLE)
		boss_defeated.emit()
		return

	# --- CHANGED: Removed countdown starting mechanism from here ---
	# Player hits no longer alter or trigger the recovery timing sequence.
	if _state == BossState.VULNERABLE:
		if animated_sprite != null and animated_sprite.animation != "loading":
			animated_sprite.play("loading")

func _on_state_timer_timeout() -> void:
	if _is_defeated:
		return

	if _state == BossState.ATTACKING:
		_set_state(BossState.VULNERABLE)
	elif _state == BossState.VULNERABLE:
		_set_state(BossState.ATTACKING)

func setup_timers() -> void:
	rain_timer = Timer.new()
	rain_timer.wait_time = spawn_cooldown
	rain_timer.autostart = false
	rain_timer.timeout.connect(_on_rain_timer_timeout)
	add_child(rain_timer)

	state_timer = Timer.new()
	state_timer.one_shot = true
	state_timer.timeout.connect(_on_state_timer_timeout)
	add_child(state_timer)

func _on_rain_timer_timeout() -> void:
	if _is_defeated or _state != BossState.ATTACKING:
		return

	if kunai_scene and player:
		if animated_sprite != null:
			animated_sprite.play("base") 
			animated_sprite.play("kunai_attack") 

		var sky_y: float = player.global_position.y + sky_height_fallback

		var positions_x: Array[float] = [
			player.global_position.x - (horizontal_spacing * 2.0),
			player.global_position.x - horizontal_spacing,
			player.global_position.x,
			player.global_position.x + horizontal_spacing,
			player.global_position.x + (horizontal_spacing * 2.0)
		]
		
		var available_indices: Array[int] = [0, 1, 2, 3, 4]
		
		var spawn_weight_pool: Array[int] = [
			1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
			2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
			3, 3, 3,
			4,
			5
		]
		
		var spawn_count: int = spawn_weight_pool.pick_random()
		
		for i in range(spawn_count):
			if available_indices.is_empty():
				break 
				
			var weighted_index_pool: Array[int] = []
			for idx in available_indices:
				var weight: int = outer_slots_weight
				if idx == 2:
					weight = center_slot_weight
				elif idx == 1 or idx == 3:
					weight = inner_slots_weight
					
				for w in range(weight):
					weighted_index_pool.append(idx)
			
			if weighted_index_pool.is_empty():
				break
				
			var chosen_index: int = weighted_index_pool.pick_random()
			
			var spawn_pos = Vector2(positions_x[chosen_index], sky_y)
			var kunai = kunai_scene.instantiate() as Node2D
			get_tree().current_scene.add_child(kunai)
			kunai.global_position = spawn_pos
			
			available_indices.erase(chosen_index)

func _sync_boss_hud_health() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var hud: Node = current_scene.find_child("HUD", true, false)
	if hud == null:
		hud = current_scene.get_node_or_null(HUD_PATH)
	if hud != null and hud.has_method("set_boss_health"):
		hud.call("set_boss_health", _current_health, max_health)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		take_damage(10, false)

func set_combat_enabled(enabled: bool) -> void:
	# If combat is disabled, stop active attacks
	if not enabled:
		if rain_timer:
			rain_timer.stop()
		if state_timer:
			state_timer.stop()
		velocity = Vector2.ZERO
	else:
		if _state == BossState.ATTACKING:
			if rain_timer:
				rain_timer.start()
			if state_timer:
				state_timer.start(attack_duration)


func on_stun_started_mock() -> void:
	_set_state(BossState.STUNNED)
	print("Stun puzzle opened.")

func on_stun_modal_closed_mock() -> void:
	if _state == BossState.STUNNED:
		_set_state(BossState.ATTACKING)
