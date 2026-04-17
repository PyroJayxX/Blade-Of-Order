extends CanvasLayer

const ACTIONS_MOVE_LEFT: Array[StringName] = [&"moveLeft", &"moveleft", &"ui_left"]
const ACTIONS_MOVE_RIGHT: Array[StringName] = [&"moveRight", &"moveright", &"ui_right"]
const ACTIONS_SLASH: Array[StringName] = [&"slash", &"Slash"]
const ACTIONS_DASH: Array[StringName] = [&"dash", &"Dash"]
const ACTIONS_JUMP: Array[StringName] = [&"jump", &"Jump", &"ui_accept"]
const ACTIONS_DODGE: Array[StringName] = [&"Dodge", &"dodge"]

func _ready() -> void:
	_connect_button("Left", ACTIONS_MOVE_LEFT)
	_connect_button("Right", ACTIONS_MOVE_RIGHT)
	_connect_button("Slash", ACTIONS_SLASH)
	_connect_button("Dash", ACTIONS_DASH)
	_connect_button("Jump", ACTIONS_JUMP)
	_connect_button("Dodge", ACTIONS_DODGE)

func _connect_button(node_name: String, actions: Array[StringName]) -> void:
	var button: TouchScreenButton = get_node_or_null(node_name) as TouchScreenButton
	if button == null:
		return
	button.pressed.connect(func() -> void: _press_actions(actions))
	button.released.connect(func() -> void: _release_actions(actions))

func _press_actions(actions: Array[StringName]) -> void:
	for action_name in actions:
		if InputMap.has_action(action_name):
			Input.action_press(action_name)

func _release_actions(actions: Array[StringName]) -> void:
	for action_name in actions:
		if InputMap.has_action(action_name):
			Input.action_release(action_name)
