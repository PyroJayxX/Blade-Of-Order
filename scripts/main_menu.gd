extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AudioController.play_main_menu_music()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_play_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect/level_selector.tscn")

func _on_exit_btn_pressed() -> void:
	get_tree().quit()
