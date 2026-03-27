extends CanvasLayer
class_name SealingModal

signal sealing_succeeded
signal resonance_surge_triggered
signal modal_closed

const MAX_CONSECUTIVE_ERRORS: int = 3
const CODE_LINES: Array[String] = [
	"int n = arr.size();",
	"bool swapped;",
	"for (int i = 0; i < n - 1; i++) {",
	"swapped = false;",
	"for (int j = 0; j < n - i - 1; j++) {",
	"if (arr[j] > arr[j + 1]) {",
	"swap(arr[j], arr[j + 1]);",
	"swapped = true;",
	"}",
	"}",
	"if (!swapped) break;",
	"}",
]

@onready var _code_bank_container: VBoxContainer = $ModalRoot/PuzzlePanel/Content/MainRow/CodeBankPanel/CodeBankBody/CodeBankScroll/CodeBankList
@onready var _slots_container: VBoxContainer = $ModalRoot/PuzzlePanel/Content/MainRow/SlotsPanel/SlotsBody/SlotsScroll/SlotsList
@onready var _status_label: Label = $ModalRoot/PuzzlePanel/Content/FooterRow/StatusLabel
@onready var _error_counter_label: Label = $ModalRoot/PuzzlePanel/Content/FooterRow/ErrorCounter
@onready var _validate_button: Button = $ModalRoot/PuzzlePanel/Content/FooterRow/Actions/ValidateButton
@onready var _reset_button: Button = $ModalRoot/PuzzlePanel/Content/FooterRow/Actions/ResetButton
@onready var _close_button: Button = $ModalRoot/PuzzlePanel/Content/FooterRow/Actions/CloseButton

var _slots: Array[PuzzleDropSlot] = []
var _consecutive_errors: int = 0

func _ready() -> void:
	visible = false
	layer = 10
	_initialize_slots()
	_reset_puzzle_layout()
	_validate_button.pressed.connect(_on_validate_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_close_button.pressed.connect(hide_modal)
	_update_error_counter()

func show_modal() -> void:
	_consecutive_errors = 0
	_reset_puzzle_layout()
	_update_error_counter()
	_status_label.text = "Reconstruct Bubble Sort by dragging each line into the right order."
	visible = true

func hide_modal() -> void:
	if not visible:
		return
	visible = false
	modal_closed.emit()

func _initialize_slots() -> void:
	_slots.clear()
	for child in _slots_container.get_children():
		child.queue_free()

	for i in CODE_LINES.size():
		var slot: PuzzleDropSlot = PuzzleDropSlot.new()
		slot.slot_index = i
		slot.line_assigned.connect(_on_slot_line_assigned)
		_slots_container.add_child(slot)
		_slots.append(slot)

func _reset_puzzle_layout() -> void:
	for slot in _slots:
		slot.clear_assignment()

	for child in _code_bank_container.get_children():
		child.queue_free()

	var line_indices: Array[int] = []
	for i in CODE_LINES.size():
		line_indices.append(i)
	line_indices.shuffle()

	for line_index in line_indices:
		var block: PuzzleCodeBlock = PuzzleCodeBlock.new()
		block.setup(line_index, CODE_LINES[line_index])
		_code_bank_container.add_child(block)

func _on_slot_line_assigned(slot_index: int, line_id: int, _line_text: String) -> void:
	for slot in _slots:
		if slot.slot_index != slot_index and slot.assigned_line_id == line_id:
			slot.clear_assignment()

func _on_validate_pressed() -> void:
	if _is_solution_correct():
		_status_label.text = "Seal locked in. The algorithm is stable."
		sealing_succeeded.emit()
		hide_modal()
		return

	_consecutive_errors += 1
	_update_error_counter()
	if _consecutive_errors >= MAX_CONSECUTIVE_ERRORS:
		_status_label.text = "Resonance Surge! Boss regains full power."
		resonance_surge_triggered.emit()
		_reset_puzzle_layout()
		hide_modal()
		return

	_status_label.text = "Logic mismatch. Check loop bounds and swapped flow."

func _on_reset_pressed() -> void:
	_status_label.text = "Puzzle reset. Try rebuilding the flow from scratch."
	_reset_puzzle_layout()

func _is_solution_correct() -> bool:
	for i in _slots.size():
		if _slots[i].assigned_line_id != i:
			return false
	return true

func _update_error_counter() -> void:
	_error_counter_label.text = "Consecutive errors: %d / %d" % [_consecutive_errors, MAX_CONSECUTIVE_ERRORS]
