extends Node2D

@onready var _radix_sort: CanvasLayer = $RadixSort

func _ready() -> void:
	if _radix_sort != null:
		_radix_sort.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		if _radix_sort != null:
			_radix_sort.visible = not _radix_sort.visible
		get_viewport().set_input_as_handled()
