extends Node2D
class_name BaseLevelController

func start_level() -> void:
	pass

func pause_level(_is_paused: bool) -> void:
	pass

func restart_level() -> void:
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("restart_active_level")

func get_result_payload() -> Dictionary:
	return {}
