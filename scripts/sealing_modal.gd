extends CanvasLayer
class_name SealingModal

signal sealing_succeeded
signal resonance_surge_triggered
signal modal_closed

const MAX_CONSECUTIVE_ERRORS: int = 3
var _consecutive_errors: int = 0

# --- NEW NODE PATHS ---
# These paths match the SubViewport layout we just built!
@onready var _title_label: Label = $HeaderUI/Title
@onready var _subtitle_label: Label = $HeaderUI/Subtitle
@onready var _error_counter_label: Label = $FooterUI/ErrorCounter
@onready var _validate_button: Button = $FooterUI/Actions/ValidateButton
@onready var _reset_button: Button = $FooterUI/Actions/ResetButton
@onready var _close_button: Button = $FooterUI/Actions/CloseButton

# Grab the TV Screen, and the 2D puzzle minigame that is playing inside of it
@onready var _viewport: SubViewport = $SubViewportContainer/SubViewport

func _ready() -> void:
	visible = false
	layer = 10
	
	# Connect our buttons
	_validate_button.pressed.connect(_on_validate_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_close_button.pressed.connect(hide_modal)
	
	_update_error_counter()

func show_modal() -> void:
	_consecutive_errors = 0
	_update_error_counter()
	_subtitle_label.text = "Reconstruct the Bubble Sort logic to seal the boss."
	visible = true

func hide_modal() -> void:
	if not visible:
		return
	visible = false
	modal_closed.emit()

func _on_validate_pressed() -> void:
	# Get the active 2D puzzle from inside the SubViewport
	var active_puzzle = _viewport.get_child(0)
	
	if not active_puzzle:
		return
		
	# Check if the 2D puzzle manager has all its pieces snapped into place!
	if active_puzzle.solved_pieces == active_puzzle.total_pieces:
		_subtitle_label.text = "Seal locked in. The algorithm is stable."
		sealing_succeeded.emit()
		hide_modal()
		return

	# If they hit execute but the puzzle isn't finished:
	_consecutive_errors += 1
	_update_error_counter()
	
	if _consecutive_errors >= MAX_CONSECUTIVE_ERRORS:
		_subtitle_label.text = "Resonance Surge! Boss regains full power."
		resonance_surge_triggered.emit()
		_on_reset_pressed() # Auto reset the puzzle pieces
		hide_modal()
		return

	_subtitle_label.text = "Logic mismatch. Assembly incomplete."

func _on_reset_pressed() -> void:
	_subtitle_label.text = "Puzzle reset. Try rebuilding the flow from scratch."
	
	# Tell the 2D puzzle to reset its pieces
	var active_puzzle = _viewport.get_child(0)
	if active_puzzle:
		# Loop through the "Pieces" folder inside the 2D minigame
		for piece in active_puzzle.get_node("Pieces").get_children():
			# Force every piece to snap back to its starting coordinate
			piece.is_locked = false
			piece.z_index = 0
			piece._return_to_start()
			
		active_puzzle.solved_pieces = 0

func _update_error_counter() -> void:
	_error_counter_label.text = "System Errors: %d / %d" % [_consecutive_errors, MAX_CONSECUTIVE_ERRORS]
