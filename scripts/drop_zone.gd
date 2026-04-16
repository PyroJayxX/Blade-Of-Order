extends Area2D

# Type the required ID in the Inspector (e.g., "swap_block")
@export var expected_id: String = ""

func _ready() -> void:
	add_to_group("drop_zone")
