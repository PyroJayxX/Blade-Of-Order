extends CanvasLayer

@onready var _resume_button: BaseButton = $Buttons/Resume
@onready var _menu_button: BaseButton = $Buttons/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if _resume_button != null and not _resume_button.pressed.is_connected(_on_resume_pressed):
		_resume_button.pressed.connect(_on_resume_pressed)
	if _menu_button != null and not _menu_button.pressed.is_connected(_on_menu_pressed):
		_menu_button.pressed.connect(_on_menu_pressed)


func _on_resume_pressed() -> void:
	visible = false
	var level_root: Node = get_parent()
	if level_root != null and level_root.has_method("pause_level"):
		level_root.call("pause_level", false)
	else:
		get_tree().paused = false


func _on_menu_pressed() -> void:
	visible = false
	var tree: SceneTree = get_tree()
	tree.paused = false
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null and flow.has_method("goto_main_menu"):
		flow.call("goto_main_menu")
		return
	var menu_path: String = "res://scenes/App/main_menu.tscn"
	if ResourceLoader.exists(menu_path):
		tree.change_scene_to_file(menu_path)
	else:
		push_warning("SceneFlow not found and main menu scene missing; cannot navigate to menu.")
