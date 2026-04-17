extends Area2D

@export var piece_id: String = ""
@export var speed: float = 150.0

var velocity: Vector2 = Vector2.ZERO
var is_dragging := false
var is_locked := false

# We send these to the level manager to track health and wins
signal placed_correctly
signal placed_wrong

# This grabs the Hacker Terminal UI box!
@onready var overlay = $"../../Overlay"

func _ready() -> void:
	# Give the piece a random starting direction
	randomize()
	velocity = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * speed

func _process(delta: float) -> void:
	if is_locked: return
	
	if is_dragging:
		# Snap perfectly to the finger/mouse
		global_position = get_global_mouse_position()
	else:
		# 1. Move the piece
		global_position += velocity * delta
		
		# 2. Get the exact physical box of your Hacker Terminal
		var bounds = overlay.get_global_rect()
		var margin = 40 # Adjust this depending on how wide your piece sprite is
		
		# --- LEFT AND RIGHT BOUNCING ---
		if global_position.x < bounds.position.x + margin:
			velocity.x = abs(velocity.x) # Force move right
			global_position.x = bounds.position.x + margin # Prevent edge sticking
			
		elif global_position.x > bounds.end.x - margin:
			velocity.x = -abs(velocity.x) # Force move left
			global_position.x = bounds.end.x - margin
			
		# --- TOP AND BOTTOM BOUNCING ---
		if global_position.y < bounds.position.y + margin:
			velocity.y = abs(velocity.y) # Force move down
			global_position.y = bounds.position.y + margin
			
		elif global_position.y > bounds.end.y - margin:
			velocity.y = -abs(velocity.y) # Force move up
			global_position.y = bounds.end.y - margin

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_locked: return
	
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if is_dragging:
				return
			# CAUGHT IT!
			is_dragging = true
			z_index = 10
			get_viewport().set_input_as_handled()
		else:
			if not is_dragging:
				return
			# RELEASED IT!
			is_dragging = false
			z_index = 0
			_check_drop()

func _check_drop() -> void:
	var overlapping = get_overlapping_areas()
	var hit_zone = false
	var correct_zone = false
	
	for area in overlapping:
		if area.is_in_group("drop_zone"):
			hit_zone = true
			if area.expected_id == piece_id:
				correct_zone = true
				_snap_to_zone(area)
			break
			
	if hit_zone and not correct_zone:
		# WRONG DROP: Nudge it away and lose health!
		placed_wrong.emit()
		_nudge_away()
		
func _snap_to_zone(zone: Area2D) -> void:
	# 1. Lock the piece so it can't be dragged anymore
	is_locked = true
	
	# 2. Safely attach this piece to the DropZone so they scroll together
	call_deferred("reparent", zone)
	
	# 3. Reset its local position so it snaps perfectly to the center of its new parent
	set_deferred("position", Vector2.ZERO)
	
	# 4. Tell the manager it was placed correctly
	placed_correctly.emit()

func _nudge_away() -> void:
	# Create a quick animation throwing it down and away
	var tween = get_tree().create_tween()
	var nudge_target = global_position + Vector2(0, 100) # Push it 100 pixels down
	tween.tween_property(self, "global_position", nudge_target, 0.2).set_trans(Tween.TRANS_BOUNCE)
	
	# Randomize its velocity again so it flies off wildly
	velocity = Vector2(randf_range(-1, 1), randf_range(0.5, 1)).normalized() * (speed * 1.5)
