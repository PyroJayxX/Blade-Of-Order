extends CanvasLayer

signal intro_finished

@export var boss_name: String = "BUBBLE SORT BOSS"
@export var boss_texture: Texture2D
@export var hold_duration: float = 1.5
@export var next_scene_path: String = ""

const SIDE_OFFSCREEN_X: float = 800.0
const SIDE_CENTER_X: float = 0.0
const SLIDE_DURATION: float = 0.25
const FLASH_FADE_DURATION: float = 0.2
const VS_PUNCH_DURATION: float = 0.2
const TITLE_FADE_DURATION: float = 0.1
const EXIT_FADE_DURATION: float = 0.4

@onready var _root: Control = $Root
@onready var _bg_rect: TextureRect = $Root/BGRect
@onready var _right_side: Control = $Root/RightSide
@onready var _boss_art: TextureRect = $Root/RightSide/BossArt
@onready var _boss_name_label: Label = $Root/RightSide/BossNameLabel
@onready var _vs_label: Label = $Root/VSLabel
@onready var _flash_rect: ColorRect = $Root/FlashRect
@onready var _level_title_label: Label = $Root/LevelTitleLabel

var _intro_tween: Tween

func _ready() -> void:
	intro_finished.connect(_on_intro_finished)
	_apply_config()
	play_intro()

func _apply_config() -> void:
	_boss_name_label.text = boss_name.strip_edges().to_upper()
	_level_title_label.text = boss_name.strip_edges().to_upper()

	if boss_texture != null:
		_boss_art.texture = boss_texture

	_boss_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func play_intro() -> void:
	if _intro_tween != null:
		_intro_tween.kill()

	_root.modulate = Color(1, 1, 1, 1)
	_bg_rect.visible = true
	_bg_rect.modulate = Color(1, 1, 1, 1)
	_right_side.position = Vector2(SIDE_OFFSCREEN_X, _right_side.position.y)
	_vs_label.scale = Vector2.ZERO
	_vs_label.modulate.a = 0.0
	_flash_rect.modulate.a = 0.0
	_level_title_label.modulate.a = 0.0

	_intro_tween = create_tween()
	_intro_tween.parallel().tween_property(_right_side, "position", Vector2(SIDE_CENTER_X, _right_side.position.y), SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_callback(func () -> void:
		_flash_rect.modulate.a = 1.0
	)
	_intro_tween.parallel().tween_property(_flash_rect, "modulate:a", 0.0, FLASH_FADE_DURATION)
	_intro_tween.parallel().tween_property(_vs_label, "scale", Vector2(1.3, 1.3), VS_PUNCH_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.parallel().tween_property(_vs_label, "modulate:a", 1.0, VS_PUNCH_DURATION)
	_intro_tween.tween_property(_vs_label, "scale", Vector2.ONE, TITLE_FADE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.parallel().tween_property(_level_title_label, "modulate:a", 1.0, TITLE_FADE_DURATION)
	_intro_tween.tween_interval(hold_duration)
	_intro_tween.tween_property(_root, "modulate:a", 0.0, EXIT_FADE_DURATION)
	_intro_tween.finished.connect(_on_intro_tween_finished)

func _on_intro_tween_finished() -> void:
	intro_finished.emit()
	queue_free()

func _on_intro_finished() -> void:
	if next_scene_path.is_empty():
		return

	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		if flow.has_method("load_level"):
			flow.call("load_level", next_scene_path)
			return
		if flow.has_method("load_scene"):
			flow.call("load_scene", next_scene_path)
			return

	get_tree().change_scene_to_file(next_scene_path)
