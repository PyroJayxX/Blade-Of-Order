extends Node

const MAIN_MENU_SCENE: String = "res://scenes/MainMenu/main_menu.tscn"
const LEVEL_SELECT_SCENE: String = "res://scenes/LevelSelect/level_selector.tscn"
const LEADERBOARD_SCENE: String = "res://scenes/Game/leaderboard.tscn"

var _root_flow: Node
var _content_root: Node
var _transition_layer: CanvasLayer
var _current_scene: Node
var _current_scene_path: String = ""
var _active_level_id: int = -1
var _is_loading_scene: bool = false
var _leaderboard_context: Dictionary = {}

func register_root(root_flow: Node, content_root: Node, transition_layer: CanvasLayer = null) -> void:
	_root_flow = root_flow
	_content_root = content_root
	_transition_layer = transition_layer

func goto_main_menu() -> void:
	_active_level_id = -1
	load_scene(MAIN_MENU_SCENE)

func goto_level_select() -> void:
	_active_level_id = -1
	load_scene(LEVEL_SELECT_SCENE)

func goto_leaderboard(context: Dictionary = {}) -> void:
	_leaderboard_context = context.duplicate(true)
	load_scene(LEADERBOARD_SCENE)

func consume_leaderboard_context() -> Dictionary:
	var payload: Dictionary = _leaderboard_context.duplicate(true)
	_leaderboard_context.clear()
	return payload

func play_level(level_id: int) -> bool:
	var config: Node = get_node_or_null("/root/GameConfig")
	if config == null:
		push_warning("GameConfig autoload is missing.")
		return false
	var definition: Resource = config.call("get_level_definition", level_id)
	var scene_path_value: String = ""
	if definition != null:
		scene_path_value = String(definition.get("scene_path"))
	if definition == null or scene_path_value.is_empty():
		push_warning("Cannot play level %d: missing level definition or scene path." % level_id)
		return false
	_active_level_id = level_id
	load_scene(scene_path_value)
	return true

func restart_active_level() -> void:
	if _active_level_id > 0:
		if play_level(_active_level_id):
			return
	if not _current_scene_path.is_empty():
		load_scene(_current_scene_path)

func on_level_cleared(payload: Dictionary = {}) -> void:
	if _active_level_id > 0:
		var config: Node = get_node_or_null("/root/GameConfig")
		if config != null:
			config.call("mark_level_completed", _active_level_id)
	if payload.get("go_to_level_select", true):
		goto_level_select()

func on_level_failed(_payload: Dictionary = {}) -> void:
	pass

func load_scene(scene_path: String) -> void:
	if _is_loading_scene:
		return
	if _content_root == null:
		push_warning("SceneFlow root is not registered before loading '%s'." % scene_path)
		return
	if scene_path.is_empty():
		push_warning("SceneFlow received an empty scene path.")
		return
	# Ignore duplicate requests for the scene already mounted in the content root.
	if scene_path == _current_scene_path and _current_scene != null and is_instance_valid(_current_scene):
		return

	_is_loading_scene = true

	if _transition_layer != null and _transition_layer.has_method("fade_out"):
		await _transition_layer.fade_out()

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_warning("Failed to load scene at path '%s'." % scene_path)
		if _transition_layer != null and _transition_layer.has_method("fade_in"):
			await _transition_layer.fade_in()
		_is_loading_scene = false
		return

	if _current_scene != null and is_instance_valid(_current_scene):
		_current_scene.queue_free()
		_current_scene = null

	for child in _content_root.get_children():
		child.queue_free()

	_current_scene = packed.instantiate()
	_content_root.add_child(_current_scene)
	_current_scene_path = scene_path

	if _transition_layer != null and _transition_layer.has_method("fade_in"):
		await _transition_layer.fade_in()

	_is_loading_scene = false

func get_active_level_id() -> int:
	return _active_level_id

func get_current_scene_path() -> String:
	return _current_scene_path
