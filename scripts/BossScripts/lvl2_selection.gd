extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# --- Kunai Rain System Properties ---
@export var kunai_scene: PackedScene
@export var player: Node2D

# Drag your ReferenceRect node from the Scene dock into this slot in the Inspector
@export var spawn_zone: ReferenceRect 

@export var min_spawn_time: float = 0.1
@export var max_spawn_time: float = 0.4

# Spawns every 0.5 seconds
@export var spawn_cooldown: float = 0.5 

# If you don't use a ReferenceRect, this is how high above the player's 
# starting ground level the sky spawn point will be (in pixels)
@export var sky_height_fallback: float = -400.0

# The distance separating each of the 5 potential points horizontally
@export var horizontal_spacing: float = 100.0

var rain_timer: Timer

func _ready() -> void:
	print("Boss Initialized")
	setup_rain_timer()

func _physics_process(delta: float) -> void:
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

# Dynamic background timer setup
func setup_rain_timer() -> void:
	rain_timer = Timer.new()
	rain_timer.wait_time = spawn_cooldown
	rain_timer.autostart = true
	
	# Connect the timeout signal to our spawning loop
	rain_timer.timeout.connect(_on_rain_timer_timeout)
	
	add_child(rain_timer)

# Spawns up to 5 equally spaced kunais randomly above the player
func _on_rain_timer_timeout() -> void:
	if kunai_scene and player:
		
		# Determine the vertical (Y) "sky" position
		var sky_y: float = 0.0
		if spawn_zone:
			sky_y = spawn_zone.get_global_rect().position.y
		else:
			sky_y = sky_height_fallback

		# Calculate the 5 equally spaced horizontal positions centered on the player
		# [Far Left, Left, Center, Right, Far Right]
		var positions_x: Array[float] = [
			player.global_position.x - (horizontal_spacing * 2.0),
			player.global_position.x - horizontal_spacing,
			player.global_position.x,
			player.global_position.x + horizontal_spacing,
			player.global_position.x + (horizontal_spacing * 2.0)
		]
		
		# Build the full Vector2 spawn points array
		var possible_spawn_points: Array[Vector2] = []
		for x_pos in positions_x:
			possible_spawn_points.append(Vector2(x_pos, sky_y))
			
		# Shuffle the points array so the position assignment is completely randomized
		possible_spawn_points.shuffle()
		
		# Randomly decide how many kunais will spawn this turn (from 1 to 5)
		var spawn_count: int = randi_range(1, 5)
		
		# Loop through and spawn only the randomly selected count of projectiles
		for i in range(spawn_count):
			var spawn_pos = possible_spawn_points[i]
			var kunai = kunai_scene.instantiate() as Node2D
			
			# 1. Add it to the main root scene so it uses clean global coordinates
			get_tree().current_scene.add_child(kunai)
			
			# 2. Set the global position AFTER adding it to the tree
			kunai.global_position = spawn_pos
