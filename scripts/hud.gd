extends CanvasLayer
class_name HudHealthBars

@export var default_player_max_health: int = 100
@export var default_boss_max_health: int = 100

const PLAYER_BAR_PATH: NodePath = ^"Root/TopRow/PlayerPanel/PlayerBar"
const PLAYER_VALUE_PATH: NodePath = ^"Root/TopRow/PlayerPanel/PlayerValue"
const BOSS_BAR_PATH: NodePath = ^"Root/TopRow/BossPanel/BossBar"
const BOSS_VALUE_PATH: NodePath = ^"Root/TopRow/BossPanel/BossValue"
const TIMER_LABEL_PATH: NodePath = ^"Root/TopRow/Spacer/TimerLabel"

var _player_bar: ProgressBar
var _player_value_label: Label
var _boss_bar: ProgressBar
var _boss_value_label: Label
var _timer_label: Label
var _elapsed_seconds: int = 0
var _timer_accumulator: float = 0.0

func _ready() -> void:
	layer = 5
	_resolve_ui_nodes()
	_elapsed_seconds = 0
	_timer_accumulator = 0.0
	_update_timer_text()
	set_player_health(default_player_max_health, default_player_max_health)
	set_boss_health(default_boss_max_health, default_boss_max_health)

func _process(delta: float) -> void:
	_timer_accumulator += delta
	while _timer_accumulator >= 1.0:
		_timer_accumulator -= 1.0
		_elapsed_seconds += 1
		_update_timer_text()

func set_player_health(current: int, max_value: int) -> void:
	_resolve_ui_nodes()
	_apply_health(_player_bar, _player_value_label, current, max_value, "Player HP")

func set_boss_health(current: int, max_value: int) -> void:
	_resolve_ui_nodes()
	_apply_health(_boss_bar, _boss_value_label, current, max_value, "Boss HP")

func _resolve_ui_nodes() -> void:
	if _player_bar == null:
		_player_bar = get_node_or_null(PLAYER_BAR_PATH) as ProgressBar
	if _player_value_label == null:
		_player_value_label = get_node_or_null(PLAYER_VALUE_PATH) as Label
	if _boss_bar == null:
		_boss_bar = get_node_or_null(BOSS_BAR_PATH) as ProgressBar
	if _boss_value_label == null:
		_boss_value_label = get_node_or_null(BOSS_VALUE_PATH) as Label
	if _timer_label == null:
		_timer_label = get_node_or_null(TIMER_LABEL_PATH) as Label

func _apply_health(bar: ProgressBar, value_label: Label, current: int, max_value: int, label_prefix: String) -> void:
	if bar == null or value_label == null:
		return
	var safe_max: int = maxi(max_value, 1)
	var safe_current: int = clampi(current, 0, safe_max)
	bar.max_value = float(safe_max)
	bar.value = float(safe_current)
	value_label.text = "%s: %d/%d" % [label_prefix, safe_current, safe_max]

func _update_timer_text() -> void:
	if _timer_label == null:
		return
	var minutes: int = _elapsed_seconds / 60
	var seconds: int = _elapsed_seconds % 60
	_timer_label.text = "Time: %02d:%02d" % [minutes, seconds]
