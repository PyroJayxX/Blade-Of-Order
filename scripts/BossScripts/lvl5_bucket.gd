extends CharacterBody2D

signal boss_defeated

enum BossState {
	IDLE,
	CHASE,
	DROP,    
	ATTACK1, # The Smash
	ATTACK2, # Kept in enum for reference, but runs async now
	RETURN,  
	HURT,
	STUNNED
}

# --- EXPORT VARIABLES ---
@export var target_path: NodePath
@export var player: Node2D
@export var attack_range: float = 900.0    
@export var personal_space: float = 850.0  
@export var attack_cooldown: float = 2.0 
@export var chase_speed: float = 200.0 
@export var drop_speed: float = 1500.0     
@export var return_speed: float = 200.0    
@export var keep_y_position: bool = true   
@export var max_health: int = 150 
@export var attack_damage: int = 10 

# PROJECTILE VARIABLES (Orbital Strike)
@export var projectile_scene: PackedScene 
@export var attack2_cooldown: float = 5.0
@export var attack2_trigger_dist: float = 600.0 
@export var projectile_arc_radius: float = 800.0  
@export var projectile_spread_angle: float = 100.0 
@export var projectile_hover_time: float = 1.0    
@export var projectile_fire_delay: float = 0.1
@export var horizontal_stretch: float = 1.7

# LASER WAVE VARIABLES (Wave Attack)
@export var wave_projectile_scene: PackedScene 
@export var laser_cooldown: float = 6.0   
@export var laser_duration: float = 3.0   
@export var laser_fire_rate: float = 0.07 

const HUD_PATH: NodePath = ^"HUD"

# --- INTERNAL VARIABLES ---
var _state: BossState = BossState.IDLE
var _target: Node2D
var _home_y: float = 0.0
var _current_health: int = 100
var _is_defeated: bool = false
var _combat_enabled: bool = true
var _attack1_timer: float = 0.0
var _attack2_timer: float = 4.0
var _laser_timer: float = 6.0 # Starts a bit higher so it doesn't fire at the exact same time as Attack 2
var _floor_y_level: float = 0.0 

# --- NODE REFERENCES ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var smash_sprite: Sprite2D = $SmashAttack 

func _ready() -> void:
	_current_health = max_health
	_is_defeated = false
	_home_y = global_position.y 
	_resolve_target()
	
	if not anim_player.animation_finished.is_connected(_on_animation_finished):
		anim_player.animation_finished.connect(_on_animation_finished)
	
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

	# Decrement all timers
	if _attack1_timer > 0.0: _attack1_timer -= delta
	if _attack2_timer > 0.0: _attack2_timer -= delta
	if _laser_timer > 0.0: _laser_timer -= delta

	var dist_x = abs(global_position.x - _target.global_position.x)

	match _state:
		BossState.IDLE:
			velocity = Vector2.ZERO
			_set_state(BossState.CHASE) 
			
		BossState.CHASE:
			_maintain_horizontal_spacing(dist_x)
			velocity.y = (_home_y - global_position.y) * 10
			
			# 1. Trigger Smash Attack
			if dist_x <= attack_range and _attack1_timer <= 0.0:
				_floor_y_level = _target.global_position.y
				_set_state(BossState.DROP)
			
			# 2. Trigger Projectile Attack (Async)
			elif dist_x > attack2_trigger_dist and _attack2_timer <= 0.0:
				_run_attack2_sequence()
				
			# 3. Trigger Laser Attack (Async)
			elif _laser_timer <= 0.0:
				_fire_wave_laser()
				
		BossState.DROP:
			velocity.x = 0
			velocity.y = drop_speed
			
			if is_on_floor() or global_position.y >= (_floor_y_level - 10):
				velocity.y = 0
				_set_state(BossState.ATTACK1)

		BossState.ATTACK1:
			velocity = Vector2.ZERO 
			
		BossState.RETURN:
			_maintain_horizontal_spacing(dist_x)
			
			if global_position.y > (_home_y + 10):
				velocity.y = -return_speed
			else:
				velocity.y = 0
				global_position.y = _home_y
				_set_state(BossState.CHASE)

		BossState.HURT:
			var dir_away = sign(global_position.x - _target.global_position.x)
			velocity.x = dir_away * 50 
			velocity.y = 0

	move_and_slide()

# --- MOVEMENT LOGIC ---
func _maintain_horizontal_spacing(distance_x: float) -> void:
	var direction_to_player = sign(_target.global_position.x - global_position.x)
	var buffer = 50.0

	if distance_x < (personal_space - buffer):
		# Player is TOO CLOSE. Move AWAY.
		velocity.x = -direction_to_player * 1000.0
	elif distance_x > (personal_space + buffer):
		# Player is TOO FAR. Move CLOSER.
		velocity.x = direction_to_player * chase_speed
	else:
		velocity.x = 0

# --- ATTACK 2 SEQUENCE (Orbital Strike on Player) ---
func _run_attack2_sequence() -> void:
	if projectile_scene == null: 
		print("ERROR: Projectile Scene is missing in the Inspector!")
		return
	
	_attack2_timer = attack2_cooldown
	var spawned_projectiles: Array[Node2D] = []
	var num_shots = 8
	
	# PHASE 1: SUMMON ABOVE THE PLAYER
	var spread_angle = deg_to_rad(projectile_spread_angle) 
	var start_angle = -spread_angle / 2.0
	var angle_step = spread_angle / float(num_shots - 1)
	
	for i in range(num_shots):
		var p = projectile_scene.instantiate()
		get_tree().current_scene.add_child(p)
		
		var current_angle = start_angle + (i * angle_step)
		var offset = Vector2.UP.rotated(current_angle) * projectile_arc_radius 
		
		offset.x *= horizontal_stretch
		
		# Spawn relative to the PLAYER'S position
		p.global_position = _target.global_position + offset
		spawned_projectiles.append(p)
	
	# Wait for the projectiles to hang in the air
	await get_tree().create_timer(projectile_hover_time).timeout
	
	# PHASE 2: FIRE THEM ONE BY ONE
	for i in range(spawned_projectiles.size()):
		if _is_defeated or _state == BossState.STUNNED:
			for unlaunched_p in spawned_projectiles:
				if is_instance_valid(unlaunched_p) and not unlaunched_p._is_launched:
					unlaunched_p.queue_free()
			return
			
		var p = spawned_projectiles[i]
		if is_instance_valid(p):
			p.launch(_target.global_position)
			
		await get_tree().create_timer(projectile_fire_delay).timeout

# --- ATTACK 3: RAPID-FIRE WAVE LASER ---
func _fire_wave_laser() -> void:
	if wave_projectile_scene == null:
		print("ERROR: Wave Projectile Scene missing in Inspector!")
		_laser_timer = laser_cooldown # Reset so it doesn't spam errors
		return
		
	# Immediately reset the cooldown timer
	_laser_timer = laser_cooldown
	var time_passed: float = 0.0
	
	# Keep firing until the duration runs out
	while time_passed < laser_duration:
		# Stop firing if the boss dies or gets stunned!
		if _is_defeated or _state == BossState.STUNNED:
			break 
			
		var wave = wave_projectile_scene.instantiate()
		get_tree().current_scene.add_child(wave)
		
		# Spawn the wave right at the boss's center
		wave.global_position = global_position
		
		# Calculate the exact angle to the player's current position
		if _target and is_instance_valid(_target):
			var dir_to_player = (_target.global_position - global_position).normalized()
			
			if wave.has_method("launch"):
				wave.launch(dir_to_player)
			
		# Wait a tiny fraction of a second, then fire the next one
		await get_tree().create_timer(laser_fire_rate).timeout
		time_passed += laser_fire_rate

# --- STATE MACHINE EXECUTION ---
func _set_state(new_state: BossState) -> void:
	if _state == new_state: return
	_state = new_state
	print("BUCKET LOG: Entering State -> ", _state_to_text(_state))

	if anim_player != null:
		match _state:
			BossState.IDLE:
				anim_player.play("idle")
			BossState.CHASE:
				anim_player.play("chase")
			BossState.DROP:
				_face_player_for_attack()
			BossState.ATTACK1:
				anim_player.play("attack")
				_attack1_timer = attack_cooldown
			BossState.RETURN:
				anim_player.play("idle")
			BossState.HURT:
				anim_player.play("hurt")
			BossState.STUNNED:
				anim_player.play("stunned")

func _face_player_for_attack() -> void:
	if _target == null: return
	smash_sprite.scale.x = 1 if _target.global_position.x < global_position.x else -1

func _on_animation_finished(anim_name: String) -> void:
	if _is_defeated: return
	
	if anim_name == "attack":
		_set_state(BossState.RETURN)
	elif anim_name == "hurt":
		if global_position.y > (_home_y + 100):
			_set_state(BossState.RETURN)
		else:
			_set_state(BossState.CHASE)

# --- COMBAT & HEALTH LOGIC ---
func take_damage(amount: int = 1, causes_stun: bool = false) -> void:
	if _is_defeated: return
	var safe_amount: int = maxi(amount, 0)
	_current_health = clampi(_current_health - safe_amount, 0, max_health)
	_sync_boss_hud_health()
	print("Boss HP -> ", _current_health, "/", max_health)

	if _current_health <= 0:
		if AudioController and AudioController.has_method("play_boss_stunned"):
			AudioController.play_boss_stunned()
		_is_defeated = true
		_set_state(BossState.STUNNED)
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
	if current_scene == null: return
	var hud: Node = current_scene.find_child("HUD", true, false)
	if hud == null: hud = current_scene.get_node_or_null(HUD_PATH)
	if hud != null and hud.has_method("set_boss_health"):
		hud.call("set_boss_health", _current_health, max_health)

func _resolve_target() -> void:
	if player != null and is_instance_valid(player):
		_target = player
		return
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node2D
		if _target != null: return
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_target = _find_target_in_scene(current_scene)

func _find_target_in_scene(current_scene: Node) -> Node2D:
	var by_group: Node = get_tree().get_first_node_in_group("player")
	if by_group is Node2D and is_instance_valid(by_group):
		return by_group as Node2D
	var modern_player: Node2D = current_scene.find_child("Player_OH", true, false) as Node2D
	if modern_player != null: return modern_player
	return current_scene.find_child("Player", true, false) as Node2D

func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled
	if not _combat_enabled:
		velocity = Vector2.ZERO
		_set_state(BossState.IDLE)

func _state_to_text(state: BossState) -> String:
	match state:
		BossState.IDLE: return "IDLE"
		BossState.CHASE: return "CHASE"
		BossState.DROP: return "DROP"
		BossState.RETURN: return "RETURN"
		BossState.HURT: return "HURT"
		BossState.STUNNED: return "STUNNED"
		BossState.ATTACK1: return "ATTACK1"
		BossState.ATTACK2: return "ATTACK2"
		_: return "UNKNOWN"

func _on_smash_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and _state == BossState.ATTACK1:
		if body.has_method("take_damage"):
			body.take_damage(attack_damage) 
			print("Boss dealt ", attack_damage, " damage to the player!")

func _on_boss_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_weapon"):
		take_damage(10)
