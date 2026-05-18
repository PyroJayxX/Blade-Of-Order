extends CharacterBody2D

signal boss_defeated

enum BossState {
	IDLE,
	CHASE,
	HURT,
	STUNNED,
	SHOOTING
}

@export var max_health: int = 100
var _current_health: int = 100
var _state: BossState = BossState.IDLE
var _is_defeated: bool = false

const HUD_PATH: NodePath = ^"HUD"

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hit_flash_player: AnimationPlayer = $HitFlash

# --- AnimatedSprite2D Node Reference ---
@onready var animated_sprite = $AnimatedSprite2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export var kunai_scene: PackedScene
@export var player: Node2D

# Drag your ReferenceRect node from the Scene dock into this slot in the Inspector
@export var spawn_zone: ReferenceRect 

@export var min_spawn_time: float = 0.1
@export var max_spawn_time: float = 0.4

# Spawns every 0.5 seconds
@export var spawn_cooldown: float = 0.5 

# This serves as the dynamic offset gap directly above the player's head (in pixels)
@export var sky_height_fallback: float = -750.0

# The horizontal spread dynamically updates based on your export variable
@export var horizontal_spacing: float = 300.0

# --- NEW: Spawn Weights for Slot Positions ---
# Higher numbers mean that slot has a higher priority chance to spawn a kunai.
@export var outer_slots_weight: int = 1   # Weight for slots 0 and 4 (Far Left / Far Right)
@export var inner_slots_weight: int = 2   # Weight for slots 1 and 3 (Mid Left / Mid Right)
@export var center_slot_weight: int = 5   # Weight for slot 2 (Directly over player)

var rain_timer: Timer

func _ready() -> void:
	print("Boss Initialized")
	_current_health = max_health
	_is_defeated = false
	_set_state(BossState.CHASE)
	_sync_boss_hud_health()
	setup_rain_timer()

func _physics_process(delta: float) -> void:
	if _is_defeated:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	match _state:
		BossState.IDLE, BossState.HURT, BossState.STUNNED:
			velocity = Vector2.ZERO
		BossState.CHASE:
			# Add the gravity.
			if not is_on_floor():
				velocity += get_gravity() * delta

			# Handle jump.
			if Input.is_action_just_pressed("ui_accept") and is_on_floor():
				velocity.y = JUMP_VELOCITY

			# Get the input direction and handle the movement/deceleration.
			var direction := Input.get_axis("ui_left", "ui_right")
			if direction:
				velocity.x = direction * SPEED
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _set_state(new_state: BossState) -> void:
	if _state == new_state:
		return
	_state = new_state
	print("Kunai Boss state -> ", _state_to_text(_state))

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
		BossState.IDLE: return "IDLE"
		BossState.CHASE: return "CHASE"
		BossState.HURT: return "HURT"
		BossState.STUNNED: return "STUNNED"
		BossState.SHOOTING: return "SHOOTING"
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
		if rain_timer:
			rain_timer.stop()
		velocity = Vector2.ZERO
		_set_state(BossState.IDLE)
		boss_defeated.emit()
		return

	if causes_stun:
		_set_state(BossState.STUNNED)
	else:
		_set_state(BossState.HURT)
		if anim_player != null:
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		take_damage(10, false)

func setup_rain_timer() -> void:
	rain_timer = Timer.new()
	rain_timer.wait_time = spawn_cooldown
	rain_timer.autostart = true
	rain_timer.timeout.connect(_on_rain_timer_timeout)
	add_child(rain_timer)

func _on_rain_timer_timeout() -> void:
	if _is_defeated:
		return

	if kunai_scene and player:
		if animated_sprite != null:
			animated_sprite.play("base") 
			animated_sprite.play("kunai_attack") 

		# Dynamic vertical position relative to the player
		var sky_y: float = player.global_position.y + sky_height_fallback

		var positions_x: Array[float] = [
			player.global_position.x - (horizontal_spacing * 2.0), # Index 0
			player.global_position.x - horizontal_spacing,         # Index 1
			player.global_position.x,                             # Index 2 (Center)
			player.global_position.x + horizontal_spacing,         # Index 3
			player.global_position.x + (horizontal_spacing * 2.0)  # Index 4
		]
		
		var available_indices: Array[int] = [0, 1, 2, 3, 4]
		
		# --- Highly Defensive Weighted Random Spawn Pool ---
		var spawn_weight_pool: Array[int] = [
			1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  # 12 entries (~43% chance)
			2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,      # 11 entries (~39% chance)
			3, 3, 3,                             # 3 entries  (~11% chance)
			4,                                   # 1 entry    (~3.5% chance)
			5                                    # 1 entry    (~3.5% chance)
		]
		
		var spawn_count: int = spawn_weight_pool.pick_random()
		
		# Spawning Loop with Neighbor-Elimination and Weighted Center Tracking
		for i in range(spawn_count):
			if available_indices.is_empty():
				break 
				
			# --- CHANGED: Build a temporary weighted pool based on *currently available* indices ---
			var weighted_index_pool: Array[int] = []
			for idx in available_indices:
				var weight: int = outer_slots_weight
				if idx == 2:
					weight = center_slot_weight
				elif idx == 1 or idx == 3:
					weight = inner_slots_weight
					
				# Add the index multiple times to the pool depending on its weight
				for w in range(weight):
					weighted_index_pool.append(idx)
			
			# Fallback guard if somehow empty
			if weighted_index_pool.is_empty():
				break
				
			# Pick from our weighted layout
			var chosen_index: int = weighted_index_pool.pick_random()
			
			var spawn_pos = Vector2(positions_x[chosen_index], sky_y)
			var kunai = kunai_scene.instantiate() as Node2D
			get_tree().current_scene.add_child(kunai)
			kunai.global_position = spawn_pos
			
			var indices_to_remove: Array[int] = [chosen_index, chosen_index - 1, chosen_index + 1]
			
			for index in indices_to_remove:
				if available_indices.has(index):
					available_indices.erase(index)
