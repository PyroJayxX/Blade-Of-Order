extends CanvasLayer

const ACTION_MOVE_LEFT: StringName = &"moveLeft"
const ACTION_MOVE_RIGHT: StringName = &"moveRight"
const ACTION_SLASH: StringName = &"Slash"
const ACTION_DASH: StringName = &"Dash"
const ACTION_JUMP: StringName = &"Jump"
const ACTION_DODGE: StringName = &"Dodge"

func _ready() -> void:
	$Left.pressed.connect(func() -> void: _press(ACTION_MOVE_LEFT))
	$Left.released.connect(func() -> void: _release(ACTION_MOVE_LEFT))
	$Right.pressed.connect(func() -> void: _press(ACTION_MOVE_RIGHT))
	$Right.released.connect(func() -> void: _release(ACTION_MOVE_RIGHT))
	$Slash.pressed.connect(func() -> void: _press(ACTION_SLASH))
	$Slash.released.connect(func() -> void: _release(ACTION_SLASH))
	$Dash.pressed.connect(func() -> void: _press(ACTION_DASH))
	$Dash.released.connect(func() -> void: _release(ACTION_DASH))
	$Jump.pressed.connect(func() -> void: _press(ACTION_JUMP))
	$Jump.released.connect(func() -> void: _release(ACTION_JUMP))
	$Dodge.pressed.connect(func() -> void: _press(ACTION_DODGE))
	$Dodge.released.connect(func() -> void: _release(ACTION_DODGE))

func _press(action_name: StringName) -> void:
	if InputMap.has_action(action_name):
		Input.action_press(action_name)

func _release(action_name: StringName) -> void:
	if InputMap.has_action(action_name):
		Input.action_release(action_name)
