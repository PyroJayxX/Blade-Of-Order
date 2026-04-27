extends Area2D

# Type the required ID in the Inspector (e.g., "swap_block")
@export var expected_id: String = ""
var _occupied: bool = false

func _ready() -> void:
	add_to_group("drop_zone")

func is_occupied() -> bool:
	return _occupied

func set_occupied(value: bool) -> void:
	_occupied = value
