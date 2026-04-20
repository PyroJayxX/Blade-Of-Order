extends PanelContainer
class_name PuzzleDropSlot

signal line_assigned(slot_index: int, line_id: int, line_text: String)

@export var slot_index: int = -1

var assigned_line_id: int = -1
var assigned_line_text: String = ""

var _label: Label

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

	custom_minimum_size = Vector2(0, 70)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	self_modulate = Color(0.18, 0.2, 0.26, 0.95)
	_update_display()

func clear_assignment() -> void:
	assigned_line_id = -1
	assigned_line_text = ""
	_update_display()

func assign_line(line_id: int, line_text: String) -> void:
	assigned_line_id = line_id
	assigned_line_text = line_text
	_update_display()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("line_id") and data.has("line_text")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	assign_line(int(data["line_id"]), String(data["line_text"]))
	line_assigned.emit(slot_index, assigned_line_id, assigned_line_text)

func _update_display() -> void:
	if assigned_line_id >= 0:
		_label.text = "%d) %s" % [slot_index + 1, assigned_line_text]
	else:
		_label.text = "%d) Drop code line here" % [slot_index + 1]
