extends Node2D

@onready var camera: Camera2D = $Camera2D
var total_pieces := 0
var solved_pieces := 0

signal puzzle_completed

func _ready() -> void:
	total_pieces = $Pieces.get_child_count()
	
	for piece in $Pieces.get_children():
		piece.piece_snapped_correctly.connect(_on_piece_snapped)
		piece.piece_unsnapped.connect(_on_piece_unsnapped) # Connect the new signal!

func _on_piece_snapped() -> void:
	solved_pieces += 1
	
	if solved_pieces == total_pieces:
		print("Puzzle Solved!")
		puzzle_completed.emit()

# NEW: Subtract a point if the player picks the piece back up
func _on_piece_unsnapped() -> void:
	solved_pieces -= 1

# Godot calls this when the screen is touched, BUT ONLY IF a piece didn't already grab the touch
func _unhandled_input(event: InputEvent) -> void:
	# Check if the player is swiping their finger across the screen
	if event is InputEventScreenDrag:
  		# Move the camera in the opposite direction of the swipe (standard mobile scrolling)
		# event.relative is how far the finger moved this exact frame
		camera.position.y -= event.relative.y
		# Clamp the camera so they can't scroll off into space
		camera.position.y = clamp(camera.position.y, camera.limit_top, camera.limit_bottom)
