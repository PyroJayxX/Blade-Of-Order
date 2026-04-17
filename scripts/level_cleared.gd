extends CanvasLayer

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_next_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect/level_selector.tscn")
