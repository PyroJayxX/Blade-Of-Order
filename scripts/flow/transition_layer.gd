extends CanvasLayer

@export var default_duration: float = 0.2

@onready var _fade_rect: ColorRect = $FadeRect

func _ready() -> void:
	_fade_rect.color = Color(0, 0, 0, 0)
	visible = false

func fade_out(duration: float = -1.0) -> void:
	var tween_duration: float = default_duration if duration < 0.0 else duration
	visible = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, tween_duration)
	await tween.finished

func fade_in(duration: float = -1.0) -> void:
	var tween_duration: float = default_duration if duration < 0.0 else duration
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, tween_duration)
	await tween.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
