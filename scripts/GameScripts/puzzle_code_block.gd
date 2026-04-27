extends PanelContainer
class_name PuzzleCodeBlock

signal drag_started(line_id: int)

var line_id: int = -1
var line_text: String = ""

var _label: Label

func setup(new_line_id: int, new_line_text: String) -> void:
	line_id = new_line_id
	line_text = new_line_text
	if is_node_ready():
		_label.text = line_text

func _ready() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(_label)

	custom_minimum_size = Vector2(0, 64)
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	self_modulate = Color(0.93, 0.96, 1.0, 1.0)
	_label.text = line_text

func _get_drag_data(_at_position: Vector2) -> Variant:
	if line_id < 0:
		return null

	var preview: Label = Label.new()
	preview.text = line_text
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.custom_minimum_size = Vector2(320, 48)
	set_drag_preview(preview)
	drag_started.emit(line_id)
	return {
		"line_id": line_id,
		"line_text": line_text,
	}
