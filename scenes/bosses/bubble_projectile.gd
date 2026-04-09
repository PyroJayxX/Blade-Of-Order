extends Area2D

@export var speed: float = 400.0
var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Automatically detect when it hits something
	body_entered.connect(_on_body_entered)
	
	# Destroy the bubble after 5 seconds so they don't fly forever
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	# Move the bubble forward every frame
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Check if the thing we hit is the player (matching the names your boss uses)
	if "Player" in body.name or body.is_in_group("player"):
		print("Player got hit by a bubble!")
		# We will call body.take_damage() here later!
		
		# Pop the bubble on impact
		queue_free()
