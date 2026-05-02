extends Node2D

@onready var _bucket_sort: CanvasLayer = $BucketSort

func _ready() -> void:
	if _bucket_sort != null:
		_bucket_sort.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		if _bucket_sort != null:
			_bucket_sort.visible = not _bucket_sort.visible
		get_viewport().set_input_as_handled()
