extends Node2D

@onready var _bubble_sort_puzzle: CanvasLayer = $BubbleSortPuzzle
@onready var _bubble_boss: Node = $BubbleBoss
@onready var _level_cleared_screen: CanvasLayer = $LevelClearedScreen

func _ready() -> void:
	_bubble_sort_puzzle.visible = false
	_level_cleared_screen.visible = false

	if _bubble_boss.has_signal("boss_defeated") and not _bubble_boss.boss_defeated.is_connected(_on_boss_defeated):
		_bubble_boss.boss_defeated.connect(_on_boss_defeated)

	if _bubble_sort_puzzle.has_signal("puzzle_failed") and not _bubble_sort_puzzle.puzzle_failed.is_connected(_on_puzzle_failed):
		_bubble_sort_puzzle.puzzle_failed.connect(_on_puzzle_failed)

	if _bubble_sort_puzzle.has_signal("puzzle_completed") and not _bubble_sort_puzzle.puzzle_completed.is_connected(_on_puzzle_completed):
		_bubble_sort_puzzle.puzzle_completed.connect(_on_puzzle_completed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		var opening_puzzle: bool = not _bubble_sort_puzzle.visible
		_bubble_sort_puzzle.visible = opening_puzzle
		if opening_puzzle:
			if _bubble_boss.has_method("on_stun_started_mock"):
				_bubble_boss.call("on_stun_started_mock")
		else:
			if _bubble_boss.has_method("on_stun_modal_closed_mock"):
				_bubble_boss.call("on_stun_modal_closed_mock")
		get_viewport().set_input_as_handled()

func _on_puzzle_failed() -> void:
	if _bubble_boss.has_method("on_stun_modal_closed_mock"):
		_bubble_boss.call("on_stun_modal_closed_mock")

func _on_puzzle_completed() -> void:
	_bubble_sort_puzzle.visible = false
	_level_cleared_screen.visible = true
	if _bubble_boss.has_method("on_sealing_success_mock"):
		_bubble_boss.call("on_sealing_success_mock")
		return
	if _bubble_boss.has_method("on_stun_modal_closed_mock"):
		_bubble_boss.call("on_stun_modal_closed_mock")

func _on_boss_defeated() -> void:
	_level_cleared_screen.visible = true
