extends CanvasLayer
class_name HudHealthBars

@export var default_player_max_health: int = 100
@export var default_boss_max_health: int = 100

const PLAYER_BAR_PATH: NodePath = ^"Root/SafeMargin/TopRow/PlayerPanel/PlayerBar"
const PLAYER_VALUE_PATH: NodePath = ^"Root/SafeMargin/TopRow/PlayerPanel/PlayerValue"
const BOSS_BAR_PATH: NodePath = ^"Root/SafeMargin/TopRow/BossPanel/BossBar"
const BOSS_VALUE_PATH: NodePath = ^"Root/SafeMargin/TopRow/BossPanel/BossValue"

var _player_bar: TextureProgressBar
var _player_value_label: Label
var _boss_bar: TextureProgressBar
var _boss_value_label: Label

func _ready() -> void:
	layer = 5
	_resolve_ui_nodes()
	set_player_health(default_player_max_health, default_player_max_health)
	set_boss_health(default_boss_max_health, default_boss_max_health)

func set_player_health(current: int, max_value: int) -> void:
	_resolve_ui_nodes()
	_apply_health(_player_bar, _player_value_label, current, max_value, "Player HP")

func set_boss_health(current: int, max_value: int) -> void:
	_resolve_ui_nodes()
	_apply_health(_boss_bar, _boss_value_label, current, max_value, "Boss HP")

func _resolve_ui_nodes() -> void:
	if _player_bar == null:
		_player_bar = get_node_or_null(PLAYER_BAR_PATH) as TextureProgressBar
	if _player_value_label == null:
		_player_value_label = get_node_or_null(PLAYER_VALUE_PATH) as Label
	if _boss_bar == null:
		_boss_bar = get_node_or_null(BOSS_BAR_PATH) as TextureProgressBar
	if _boss_value_label == null:
		_boss_value_label = get_node_or_null(BOSS_VALUE_PATH) as Label

func _apply_health(bar: TextureProgressBar, value_label: Label, current: int, max_value: int, label_prefix: String) -> void:
	if bar == null or value_label == null:
		return
	var safe_max: int = maxi(max_value, 1)
	var safe_current: int = clampi(current, 0, safe_max)
	bar.max_value = float(safe_max)
	bar.value = float(safe_current)
	value_label.text = "%s: %d/%d" % [label_prefix, safe_current, safe_max]
