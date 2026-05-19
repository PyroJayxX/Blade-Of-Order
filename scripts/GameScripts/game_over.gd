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
		push_warning("game_over: menu pressed -> calling SceneFlow.goto_main_menu (flow found)")
		flow.call("goto_main_menu")
		return
	var menu_path := "res://scenes/App/main_menu.tscn"
	push_warning("game_over: menu pressed -> SceneFlow not found, falling back to direct scene change to %s" % menu_path)
	if ResourceLoader.exists(menu_path):
		get_tree().change_scene_to_file(menu_path)
	else:
		push_warning("SceneFlow not found and main menu scene missing; cannot navigate to menu.")

func _on_try_again_button_pressed() -> void:
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow == null:
		var current: Node = get_tree().current_scene
		if current != null and not current.scene_file_path.is_empty():
			get_tree().change_scene_to_file(current.scene_file_path)
			return
		if retry_scene_path != "" and ResourceLoader.exists(retry_scene_path):
			get_tree().change_scene_to_file(retry_scene_path)
			return
		push_warning("game_over: SceneFlow not found and no fallback scene available.")
		return

	var active_id: int = -1
	if flow.has_method("get_active_level_id"):
		active_id = int(flow.call("get_active_level_id"))

	push_warning("game_over: try again pressed -> active_id=%d" % active_id)

	if active_id > 0 and flow.has_method("play_level"):
		push_warning("game_over: calling SceneFlow.play_level(%d)" % active_id)
		flow.call("play_level", active_id)
		return

	push_warning("game_over: calling SceneFlow.restart_active_level")
	flow.call("restart_active_level")
