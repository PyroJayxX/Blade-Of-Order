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
		return
	# Fallback: change to main menu scene directly
	var menu_path := "res://scenes/MainMenu/main_menu.tscn"
	if ResourceLoader.exists(menu_path):
		get_tree().change_scene_to_file(menu_path)
	else:
		push_warning("SceneFlow not found and main menu scene missing; cannot navigate to menu.")

func _on_try_again_button_pressed() -> void:
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		var active_id: int = -1
		var cur_path: String = ""
		if flow.has_method("get_active_level_id"):
			active_id = int(flow.call("get_active_level_id"))
		if flow.has_method("get_current_scene_path"):
			cur_path = String(flow.call("get_current_scene_path"))
		push_warning("game_over: calling SceneFlow.restart_active_level (active_id=%d, current_path=%s)" % [active_id, cur_path])
		flow.call("restart_active_level")
		# Wait one frame for SceneFlow to process the restart; if SceneFlow doesn't change
		# the top-level scene file (common when content is instanced), force a direct reload
		# using the scene path reported by SceneFlow or GameConfig.
		await get_tree().process_frame
		var new_path: String = ""
		if flow.has_method("get_current_scene_path"):
			new_path = String(flow.call("get_current_scene_path"))
		if new_path.is_empty() and active_id > 0:
			var cfg: Node = get_node_or_null("/root/GameConfig")
			if cfg != null and cfg.has_method("get_level_definition"):
				var def: Resource = cfg.call("get_level_definition", active_id)
				if def != null:
					new_path = String(def.get("scene_path"))
		if not new_path.is_empty() and ResourceLoader.exists(new_path):
			push_warning("game_over: forcing reload to %s" % new_path)
			get_tree().change_scene_to_file(new_path)
			return
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		var scene_path: String = String(current_scene.scene_file_path)
		if not scene_path.is_empty():
			get_tree().change_scene_to_file(scene_path)
			return

	# Last-resort fallback if the active scene has no file path.
	if retry_scene_path != "" and ResourceLoader.exists(retry_scene_path):
		get_tree().change_scene_to_file(retry_scene_path)
		return
	push_warning("Could not reload the current scene.")
