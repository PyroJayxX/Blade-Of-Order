extends Area2D

@export var speed: float = 900.0
@export var damage: int = 10
@export var lifetime: float = 4.0 

var _direction: Vector2 = Vector2.RIGHT
var _is_destroyed: bool = false 

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# 1. Connect Body signal (For hitting the Player)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	# 2. NEW: Connect Area signal (For getting hit BY the Sword)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	
	if sprite != null:
		sprite.play("default") 

func launch(dir: Vector2) -> void:
	_direction = dir.normalized()
	rotation = _direction.angle() + PI
		
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree() and not _is_destroyed:
		queue_free()

func _physics_process(delta: float) -> void:
	if _is_destroyed: return
	global_position += _direction * speed * delta

# --- NEW: SWORD HIT SIGNAL ---
func _on_area_entered(area: Area2D) -> void:
	# DEBUG: Tell us exactly what Area touched the wave!
	print("WAVE TOUCHED AREA: ", area.name, " | Groups: ", area.get_groups())
	
	if area.is_in_group("player_weapon"):
		print("SUCCESS! Player weapon detected!")
		_pop()
		
func _pop() -> void:
	_is_destroyed = true
	
	if sprite != null:
		sprite.play("pop") 
		
	await sprite.animation_finished
	if is_inside_tree():
		queue_free()

# --- PLAYER HIT SIGNAL ---
func _on_body_entered(body: Node2D) -> void:
	if _is_destroyed: return
	
	if "Player" in body.name or body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.call("take_damage", damage)
			
		queue_free()
