extends Node2D

@onready var _sealing_modal: SealingModal = $SealingModal
@onready var _boss: Node = $BubbleBoss

func _ready() -> void:
	_sealing_modal.sealing_succeeded.connect(_on_sealing_succeeded)
	_sealing_modal.resonance_surge_triggered.connect(_on_resonance_surge_triggered)
	_sealing_modal.modal_closed.connect(_on_modal_closed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		if _sealing_modal.visible:
			_sealing_modal.hide_modal()
		else:
			_open_stun_modal()
		get_viewport().set_input_as_handled()

func _open_stun_modal() -> void:
	if _boss != null and _boss.has_method("on_stun_started_mock"):
		_boss.call("on_stun_started_mock")
	_sealing_modal.show_modal()

func _on_sealing_succeeded() -> void:
	if _boss != null and _boss.has_method("on_sealing_success_mock"):
		_boss.call("on_sealing_success_mock")

func _on_resonance_surge_triggered() -> void:
	if _boss != null and _boss.has_method("on_resonance_surge_mock"):
		_boss.call("on_resonance_surge_mock")

func _on_modal_closed() -> void:
	if _boss != null and _boss.has_method("on_stun_modal_closed_mock"):
		_boss.call("on_stun_modal_closed_mock")
