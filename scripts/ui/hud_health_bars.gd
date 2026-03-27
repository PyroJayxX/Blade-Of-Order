extends CanvasLayer
class_name HudHealthBars

@export var default_player_max_health: int = 100
@export var default_boss_max_health: int = 100

@onready var _player_bar: TextureProgressBar = $Root/SafeMargin/TopRow/PlayerPanel/PlayerBar
@onready var _player_value_label: Label = $Root/SafeMargin/TopRow/PlayerPanel/PlayerValue
@onready var _boss_bar: TextureProgressBar = $Root/SafeMargin/TopRow/BossPanel/BossBar
@onready var _boss_value_label: Label = $Root/SafeMargin/TopRow/BossPanel/BossValue

func _ready() -> void:
	layer = 5
	set_player_health(default_player_max_health, default_player_max_health)
	set_boss_health(default_boss_max_health, default_boss_max_health)

func set_player_health(current: int, max_value: int) -> void:
	_apply_health(_player_bar, _player_value_label, current, max_value, "Player HP")

func set_boss_health(current: int, max_value: int) -> void:
	_apply_health(_boss_bar, _boss_value_label, current, max_value, "Boss HP")

func _apply_health(bar: TextureProgressBar, value_label: Label, current: int, max_value: int, label_prefix: String) -> void:
	var safe_max: int = maxi(max_value, 1)
	var safe_current: int = clampi(current, 0, safe_max)
	bar.max_value = float(safe_max)
	bar.value = float(safe_current)
	value_label.text = "%s: %d/%d" % [label_prefix, safe_current, safe_max]
