extends Node

@onready var _content_root: Node = $ContentRoot
@onready var _transition_layer: CanvasLayer = $TransitionLayer

func _ready() -> void:
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow == null:
		push_warning("SceneFlow autoload not found at /root/SceneFlow")
		return
	flow.call("register_root", self, _content_root, _transition_layer)
	flow.call("goto_main_menu")
