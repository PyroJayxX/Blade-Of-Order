extends CanvasLayer

@export var base_score: int = 150
@export var time_penalty: float = 1.0
@export var mistake_penalty: int = 25
@export var min_score: int = 0
@export var max_displayed_score: int = 100

@onready var _time_label: RichTextLabel = $Container/label_time
@onready var _score_label: RichTextLabel = $Container/label_score

func show_results(time_taken: float, mistakes_made: int) -> void:
	var final_score: int = calculate_final_score(time_taken, mistakes_made)
	var total_seconds: int = maxi(int(round(time_taken)), 0)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	_time_label.text = "[center] Time: %02d:%02d [/center]" % [minutes, seconds]
	_score_label.text = "[center] Score: %d [/center]" % final_score

func calculate_final_score(time_taken: float, mistakes_made: int) -> int:
	# Buffer design: start at 150 but cap display to 100, giving a 50-point cushion
	# so players can spend up to 50 seconds with no mistakes and still show 100.
	var raw_score: float = float(base_score) - (time_taken * time_penalty) - float(mistakes_made * mistake_penalty)
	return int(clamp(raw_score, float(min_score), float(max_displayed_score)))

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_next_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect/level_selector.tscn")
