extends CanvasLayer
class_name BubbleSortPuzzleController

signal puzzle_completed
signal puzzle_failed

@export var max_mistakes: int = 4

var total_pieces: int = 0
var solved_pieces: int = 0
var mistake_count: int = 0

@onready var _pieces_root: Node2D = $FlyingPieces
@onready var _skull_1: Node2D = $Overlay/Skull_1
@onready var _skull_2: Node2D = $Overlay/Skull_2
@onready var _skull_3: Node2D = $Overlay/Skull_3

func _ready() -> void:
	_reset_attempt_state()
	_wire_piece_signals()
	total_pieces = _pieces_root.get_child_count()
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)

func _on_piece_placed_correctly() -> void:
	solved_pieces = mini(solved_pieces + 1, total_pieces)
	if solved_pieces >= total_pieces:
		puzzle_completed.emit()

func _on_piece_placed_wrong() -> void:
	mistake_count += 1
	_update_skulls()

	if mistake_count >= max_mistakes:
		puzzle_failed.emit()
		visible = false

func _wire_piece_signals() -> void:
	for piece: Node in _pieces_root.get_children():
		if piece.has_signal("placed_correctly") and not piece.placed_correctly.is_connected(_on_piece_placed_correctly):
			piece.placed_correctly.connect(_on_piece_placed_correctly)
		if piece.has_signal("placed_wrong") and not piece.placed_wrong.is_connected(_on_piece_placed_wrong):
			piece.placed_wrong.connect(_on_piece_placed_wrong)

func _update_skulls() -> void:
	_skull_1.visible = mistake_count >= 1
	_skull_2.visible = mistake_count >= 2
	_skull_3.visible = mistake_count >= 3

func _reset_attempt_state() -> void:
	solved_pieces = 0
	mistake_count = 0
	_update_skulls()

func _on_visibility_changed() -> void:
	if visible:
		_reset_attempt_state()

func get_mistake_count() -> int:
	return mistake_count
