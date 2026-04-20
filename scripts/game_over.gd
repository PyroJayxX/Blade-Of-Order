extends CanvasLayer

@export var retry_scene_path: String = "res://scenes/Game/game.tscn"

@onready var _time_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/TimeLabel
@onready var _score_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/ScoreLabel

func show_results(time_taken: float, mistakes_made: int = 0) -> void:
	var total_seconds: int = maxi(int(round(time_taken)), 0)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	_time_label.text = "[center] Time: %02d:%02d [/center]" % [minutes, seconds]
	_score_label.text = "[center] Mistakes: %d [/center]" % max(mistakes_made, 0)

func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu/main_menu.tscn")

func _on_try_again_button_pressed() -> void:
	if retry_scene_path.is_empty():
		get_tree().reload_current_scene()
		return
	get_tree().change_scene_to_file(retry_scene_path)
