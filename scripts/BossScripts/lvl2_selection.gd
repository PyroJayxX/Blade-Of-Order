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
@export var hit_vulnerability_window: float = 4


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
			if is_instance_valid(player):
				# this will make it so boss nvr cross the player
				var is_boss_left = global_position.x < player.global_position.x
				var side_dir = -1 if is_boss_left else 1
				
				if animated_sprite != null:
					animated_sprite.flip_h = is_boss_left
				
				# calculate safe distance from player and height
				var safe_distance = 750.0
				var safe_height = -600.0 
				
				# add a sway wobble
				var time = Time.get_ticks_msec() / 1000.0
				var sway_x = sin(time * 2.0) * 50.0
				var sway_y = cos(time * 3.0) * 30.0
				
				# boss  is player X +/- 450px,, magbackup boss if player is approaching
				var target_x = player.global_position.x + (side_dir * safe_distance) + sway_x
				var target_y = player.global_position.y + safe_height + sway_y
				
				var target_pos = Vector2(target_x, target_y)
				var distance = global_position.distance_to(target_pos)
				
				if distance > 10.0:
					var direction = global_position.direction_to(target_pos)
					velocity = direction * min(distance * follow_smoothness, 1000.0)
				else:
					velocity = Vector2.ZERO
			else:
				velocity = Vector2.ZERO
				
			move_and_slide()
			
		BossState.VULNERABLE:
			if not is_on_floor():
				velocity.y += drop_gravity * delta
				# low air friction so the kick-away maintains momentum
				velocity.x = move_toward(velocity.x, 0, 300.0 * delta) 
				
				# bounce off if collided with wall
				if is_on_wall():
					var wall_normal = get_wall_normal()
					velocity.x = wall_normal.x * 800.0
			else:
				# fast skid once it hits the floor
				velocity.x = move_toward(velocity.x, 0, SPEED * 6.0 * delta)
			move_and_slide()
			
		BossState.IDLE, BossState.HURT, BossState.STUNNED:
			velocity = Vector2.ZERO
			move_and_slide()

func _set_state(new_state: BossState) -> void:
	if _state == new_state:
		return
		
	var previous_state = _state # save previous state
	
	_state = new_state
	print("Kunai Boss state -> ", _state_to_text(_state))

	match _state:
		BossState.ATTACKING:
			if rain_timer: rain_timer.start()
			state_timer.start(attack_duration) 
			
			if anim_player != null:
				if previous_state == BossState.VULNERABLE:
					# if vulnerable last state, play trans back
					anim_player.play("transition_back")
					anim_player.queue("base") # queue the normal base animation after trans back
				else:
					# if starting the round, just play the base immediately
					anim_player.play("base")
			
		BossState.VULNERABLE:
			if anim_player != null: anim_player.play("transition") # play transition before going vulnerable state
			if rain_timer: rain_timer.stop()
			state_timer.start(hit_vulnerability_window) 
			
			# kick away when going to vulnerable state
			if is_instance_valid(player):
				var is_boss_left = global_position.x < player.global_position.x
				var escape_dir = -1 if is_boss_left else 1
				
				# massive velocity burst
				velocity.x = escape_dir * 1500.0 
				velocity.y = -500.0 
				
				# instantly warp 20px up and away so wall/ceiling colliders dont cancel the jump
				global_position.x += escape_dir * 20.0
				global_position.y -= 20.0
			
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
	if _is_defeated or _state != BossState.VULNERABLE:
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

	if kunai_scene and is_instance_valid(player):
		if animated_sprite != null:
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
		
		var roll = randf()
		var spawn_count: int = 1
		if roll > 0.95: spawn_count = 5     # 5% chance
		elif roll > 0.85: spawn_count = 4   # 10% chance
		elif roll > 0.65: spawn_count = 3   # 20% chance
		elif roll > 0.40: spawn_count = 2   # 25% chance
		# otherwise it remains 1            # 40% chance
		
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
	if OS.is_debug_build():
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
