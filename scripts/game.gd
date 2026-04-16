extends Node2D

@onready var _bubble_sort_puzzle: CanvasLayer = $BubbleSortPuzzle

func _ready() -> void:
	_bubble_sort_puzzle.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		_bubble_sort_puzzle.visible = not _bubble_sort_puzzle.visible
		get_viewport().set_input_as_handled()
