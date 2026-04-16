extends CharacterBody2D

const SPEED = 800.0 # how fast the player is
const JUMP_VELOCITY = -1200.0 # higher magnitude = higher and faster jump

const FALL_MULTIPLIER = 4 # gravity multiplier when falling
const LOW_JUMP_MULTIPLIER = 2.2 # gravity multiplier when jumping

const DASH_SPEED = 2500.0 # higher -> travels faster
const DASH_TIME = 0.4 # higher -> more distance
const DASH_DECEL = 2000.0 # lower -> decelerate more/longer stop

var is_dashing = false
 
@onready var animated_sprite = $AnimatedSprite2D

func start_dash(direction):
	is_dashing = true
	
	# if no input, dash based on facing direction
	if direction == 0:
		direction = -1 if animated_sprite.flip_h else 1
	
	velocity.x = direction * DASH_SPEED
	
	animated_sprite.play("dash")
	
	await get_tree().create_timer(DASH_TIME).timeout
	
	is_dashing = false

func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		if velocity.y > 0:
			velocity += get_gravity() * FALL_MULTIPLIER * delta
		else:
			velocity += get_gravity() * LOW_JUMP_MULTIPLIER * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY 

	var direction := Input.get_axis("ui_left", "ui_right")

	if Input.is_action_just_pressed("dash") and not is_dashing:
		start_dash(direction)

	# Movement
	if is_dashing:
		# decelerate instead of sharp stop
		velocity.x = move_toward(velocity.x, 0, DASH_DECEL * delta)
	else:
		if direction != 0:
			velocity.x = direction * SPEED
			animated_sprite.flip_h = direction < 0
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	# Animation (PRIORITY-BASED)
	if is_dashing:
		animated_sprite.play("dash")

	elif not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("fall")
	else:
		if direction != 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")

	move_and_slide()
