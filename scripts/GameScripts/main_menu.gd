extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AudioController.play_main_menu_music()
	var leaderboard_button: TextureButton = get_node_or_null("MarginContainer/VBoxContainer/leaderboard_btn") as TextureButton
	if leaderboard_button != null and not leaderboard_button.pressed.is_connected(_on_leaderboard_btn_pressed):
		leaderboard_button.pressed.connect(_on_leaderboard_btn_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_play_btn_pressed() -> void:
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("goto_level_select")

func _on_leaderboard_btn_pressed() -> void:
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("goto_leaderboard")

func _on_exit_btn_pressed() -> void:
	get_tree().quit()
