extends Area2D

# --- EXPORT VARIABLES ---
# These appear in the Inspector so you can easily build new puzzles
@export var piece_id: String = ""
@export var piece_texture: Texture2D

# --- STATE VARIABLES ---
var is_dragging := false
var is_locked := false
var original_position := Vector2.ZERO

# --- CUSTOM SIGNALS ---
signal piece_snapped_correctly
signal piece_unsnapped

func _ready() -> void:
	# Save the starting location so we can bounce back if we make a mistake
	original_position = global_position
	
	# Automatically apply whatever picture you assigned in the Inspector
	if piece_texture:
		$Sprite2D.texture = piece_texture

func _process(delta: float) -> void:
	# Make the piece follow the mouse while we are holding it
	if is_dragging:
		global_position = get_global_mouse_position()

func _check_drop_location() -> void:
	# Get an array of all other Area2Ds this piece is currently touching
	var overlapping_areas = get_overlapping_areas()
	var dropped_correctly = false
	
	for area in overlapping_areas:
		# 1. Is the area a drop zone?
		# 2. Does the drop zone's ID perfectly match this piece's ID?
		if area.is_in_group("drop_zone") and area.zone_id == piece_id:
			dropped_correctly = true
			_snap_to_zone(area)
			break
			
	# The Error Check: If it wasn't dropped on the correct zone, send it back!
	if not dropped_correctly:
		_return_to_start()

func _snap_to_zone(zone: Area2D) -> void:
	# Snap perfectly to the center of the drop zone
	global_position = zone.global_position
	is_locked = true 
	piece_snapped_correctly.emit() # Tell the puzzle manager we got a point

func _return_to_start() -> void:
	# Create a smooth animation that slides the piece back to its original spot
	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position", original_position, 0.2).set_trans(Tween.TRANS_SINE)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# Works for both mouse clicks (testing on PC) and screen taps (Mobile)
	if (event is InputEventMouseButton or event is InputEventScreenTouch):
		if event.pressed:
			is_dragging = true
			z_index = 10

			if is_locked:
				is_locked = false
				piece_unsnapped.emit()
			# --- THE MAGIC LINE FOR MOBILE ---
			# This tells Godot: "I got this input! Don't pass it to the background swipe script!"
			get_viewport().set_input_as_handled()    
		else:
			is_dragging = false
			z_index = 0
			_check_drop_location()
