extends CanvasLayer

@export var pages: Array[String] = []
@export var typewriter_speed: float = 0.03

signal cutscene_finished

var _is_typing: bool = false
var _current_page: int = -1
var _accept_taps: bool = false # Keep taps locked until play() finishes fading in

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var dialogue_text: RichTextLabel = $DialogueBox/MarginContainer/DialogueText
@onready var continue_hint: Label = $DialogueBox/MarginContainer/ContinueHint
@onready var skip_button: Button = $SkipButton
@onready var bg_overlay: ColorRect = $BGOverlay
@onready var dialogue_box: PanelContainer = $DialogueBox

func _ready() -> void:
	# Keep the layout completely hidden on startup until play() runs
	visible = false
	_current_page = -1
	_is_typing = false
	_accept_taps = false

	dialogue_text.clear()
	dialogue_text.visible_ratio = 0.0
	continue_hint.visible = false
	skip_button.pressed.connect(Callable(self, "_on_skip_pressed"))

func play() -> void:
	visible = true
	if pages.is_empty():
		_finish()
		return
		
	visible = true
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(bg_overlay, "color:a", 0.7, 0.2)
	tw.tween_property(dialogue_box, "modulate:a", 1.0, 0.2)
	await tw.finished

	# Autoplay the first page safely
	_show_page(0)
	
	# Only unlock screen taps AFTER page 0 has successfully initialized
	get_tree().create_timer(0.1).timeout.connect(func(): _accept_taps = true)

func _show_page(index: int) -> void:
	if index >= pages.size():
		_finish()
		return

	_current_page = index
	continue_hint.visible = false

	dialogue_text.text = pages[index]
	dialogue_text.visible_ratio = 0.0
	_is_typing = pages[index].length() > 0

	_run_typewriter_animation(pages[index])

func _run_typewriter_animation(text: String) -> void:
	var duration: float = maxf(float(maxi(text.length(), 1)) * typewriter_speed, typewriter_speed)
	anim_player.speed_scale = 1.0 / duration
	
	if anim_player.animation_finished.is_connected(_on_typewriter_finished):
		anim_player.animation_finished.disconnect(_on_typewriter_finished)
	anim_player.animation_finished.connect(_on_typewriter_finished, CONNECT_ONE_SHOT)
	
	anim_player.play("typewriter")

func _on_typewriter_finished(_anim_name: String) -> void:
	_is_typing = false
	dialogue_text.visible_ratio = 1.0
	continue_hint.visible = true

func _input(event: InputEvent) -> void:
	# If taps are locked or layer is hidden, ignore everything
	if not visible or not _accept_taps:
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if not event.pressed:
			return
		
		if skip_button.get_global_rect().has_point(event.position):
			return

		# Clean mobile tap debounce loop
		_accept_taps = false
		get_tree().create_timer(0.15).timeout.connect(func(): _accept_taps = true)

		if _is_typing:
			# Skip typewriter instantly
			anim_player.stop()
			dialogue_text.visible_ratio = 1.0
			_on_typewriter_finished("typewriter")
			return

		_show_page(_current_page + 1)

func _on_skip_pressed() -> void:
	anim_player.stop()
	_is_typing = false
	_finish()

func _finish() -> void:
	_accept_taps = false
	continue_hint.visible = false
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(bg_overlay, "color:a", 0.0, 0.2)
	tw.tween_property(dialogue_box, "modulate:a", 0.0, 0.2)
	await tw.finished
	
	visible = false
	emit_signal("cutscene_finished")
	queue_free()
