extends CharacterBody2D

signal boss_defeated

enum BossState {
	IDLE,
	CHASE,
	DROP,    
	ATTACK,
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
@export var return_speed: float = 500.0    
@export var keep_y_position: bool = true   
@export var max_health: int = 150 

const HUD_PATH: NodePath = ^"HUD"

# --- INTERNAL VARIABLES ---
var _state: BossState = BossState.IDLE
var _target: Node2D
var _home_y: float = 0.0
var _current_health: int = 100
var _is_defeated: bool = false
var _combat_enabled: bool = true
var _attack_timer: float = 0.0
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

	if _attack_timer > 0.0:
		_attack_timer -= delta

	var dist_x = abs(global_position.x - _target.global_position.x)

	match _state:
		BossState.IDLE:
			velocity = Vector2.ZERO
			_set_state(BossState.CHASE) 
			
		BossState.CHASE:
			# ACTIVELY MAINTAIN GAP (Follow or Retreat)
			_maintain_horizontal_spacing(dist_x)
			# Stay at hover height
			velocity.y = (_home_y - global_position.y) * 10
			
			if dist_x <= attack_range and _attack_timer <= 0.0:
				_floor_y_level = _target.global_position.y
				_set_state(BossState.DROP)
				
		BossState.DROP:
			velocity.x = 0
			velocity.y = drop_speed
			
			if is_on_floor() or global_position.y >= (_floor_y_level - 10):
				velocity.y = 0
				_set_state(BossState.ATTACK)

		BossState.ATTACK:
			velocity = Vector2.ZERO 
			
		BossState.RETURN:
			# Back up while returning if the player is chasing us!
			_maintain_horizontal_spacing(dist_x)
			
			if global_position.y > (_home_y + 10):
				velocity.y = -return_speed
			else:
				velocity.y = 0
				global_position.y = _home_y
				_set_state(BossState.CHASE)

		BossState.HURT, BossState.STUNNED:
			# Optional: Slight pushback when hurt to prevent spam
			var dir_away = sign(global_position.x - _target.global_position.x)
			velocity.x = dir_away * 50 
			velocity.y = 0

	move_and_slide()

# --- REVISED MOVEMENT LOGIC ---
func _maintain_horizontal_spacing(distance_x: float) -> void:
	var direction_to_player = sign(_target.global_position.x - global_position.x)
	
	# BUFFER: We use a small range (50px) to prevent the boss from jittering back and forth
	var buffer = 50.0

	if distance_x < (personal_space - buffer):
		# Player is TOO CLOSE. Move AWAY from player.
		velocity.x = -direction_to_player * 1000.0
	elif distance_x > (personal_space + buffer):
		# Player is TOO FAR. Move TOWARD player.
		velocity.x = direction_to_player * chase_speed
	else:
		# Player is in the "Sweet Spot". Stay still.
		velocity.x = 0

# --- STATE MACHINE EXECUTION ---
func _set_state(new_state: BossState) -> void:
	if _state == new_state:
		return
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
			BossState.ATTACK:
				anim_player.play("attack")
				_attack_timer = attack_cooldown
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
	
	if _current_health <= 0:
		if AudioController and AudioController.has_method("play_boss_stunned"):
			AudioController.play_boss_stunned()
		_is_defeated = true
		velocity = Vector2.ZERO
		_set_state(BossState.IDLE)
		boss_defeated.emit()
		return

	if causes_stun:
		_set_state(BossState.STUNNED)
	else:
		_set_state(BossState.HURT)

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
		BossState.ATTACK: return "ATTACK"
		_: return "UNKNOWN"

func _on_smash_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and _state == BossState.ATTACK:
		if body.has_method("take_damage"):
			body.take_damage(1)

func _on_boss_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_weapon"):
		take_damage(10)
