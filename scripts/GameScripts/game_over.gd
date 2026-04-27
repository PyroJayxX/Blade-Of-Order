extends CanvasLayer

@export var retry_scene_path: String = "res://scenes/Bosses/Level1/level_01_bubble_sort.tscn"

@onready var _time_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/TimeLabel

func show_results(time_taken: float, _mistakes_made: int = 0) -> void:
	var total_seconds: int = maxi(int(round(time_taken)), 0)
	var minutes: int = int(floor(float(total_seconds) / 60.0))
	var seconds: int = total_seconds % 60

	_time_label.text = "[center] Time: %02d:%02d [/center]" % [minutes, seconds]

func _on_menu_button_pressed() -> void:
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("goto_main_menu")

func _on_try_again_button_pressed() -> void:
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("restart_active_level")
