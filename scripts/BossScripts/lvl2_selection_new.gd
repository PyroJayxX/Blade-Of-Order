extends Node2D

@export var kunai_scene: PackedScene
@export var player: Node2D

# Drag your ReferenceRect node from the Scene dock into this slot in the Inspector
@export var spawn_zone: ReferenceRect 

@export var min_spawn_time: float = 0.1
@export var max_spawn_time: float = 0.4

# Spawns every 2 seconds
@export var spawn_cooldown: float = 2.0 

# If you don't use a ReferenceRect, this is how high above the player's 
# starting ground level the sky spawn point will be (in pixels)
@export var sky_height_fallback: float = -400.0

var rain_timer: Timer

func _ready() -> void:
	print("Start")
	setup_rain_timer()
	
func _physics_process(delta: float) -> void:
	if player:
		print(player.global_position)

func setup_rain_timer() -> void:
	rain_timer = Timer.new()
	rain_timer.wait_time = spawn_cooldown
	rain_timer.autostart = true
	
	# Connect the timeout signal to our spawn function
	rain_timer.timeout.connect(_on_rain_timer_timeout)
	
	add_child(rain_timer)

func _on_rain_timer_timeout() -> void:
	# Double check that both the scene and player exist before spawning
	if kunai_scene and player:
		var kunai = kunai_scene.instantiate() as Node2D
		
		# Determine the vertical (Y) "sky" position
		var sky_y: float = 0.0
		
		if spawn_zone:
			# If a ReferenceRect is assigned, use its top edge global Y coordinate
			sky_y = spawn_zone.get_global_rect().position.y
		else:
			# Fallback: Spawn at a fixed coordinate high above the player's baseline
			# (Adjust sky_height_fallback in the inspector if it needs to be higher)
			sky_y = sky_height_fallback
		
		# Position it at the player's horizontal position (X), but up in the sky (Y)
		var spawn_pos = Vector2(
			player.global_position.x,
			sky_y
		)
		
		# 1. Add it to the main root scene so it uses clean global coordinates
		get_tree().current_scene.add_child(kunai)
		
		# 2. Set the global position AFTER adding it to the tree
		kunai.global_position = spawn_pos
		
