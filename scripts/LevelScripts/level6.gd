extends Node2D

@onready var _radix_sort: CanvasLayer = $RadixSort
@onready var _radix_boss: Node = $RadixBoss
@onready var _player: Node2D = $Player
@onready var _hud: CanvasLayer = $HUD
@onready var _level_cleared: CanvasLayer = $LevelCleared
@onready var _game_over: CanvasLayer = $GameOver

var _last_elapsed_seconds: float = 0.0
var _last_mistakes_made: int = 0
var _last_result: String = "running"

func _ready() -> void:
	_radix_sort.visible = false

	# Connect boss defeat signal
	if _radix_boss.has_signal("boss_defeated") and not _radix_boss.boss_defeated.is_connected(_on_boss_defeated):
		_radix_boss.boss_defeated.connect(_on_boss_defeated)

	# Connect player death
	if _player != null and _player.has_signal("player_died") and not _player.player_died.is_connected(_on_player_died):
		_player.player_died.connect(_on_player_died)

	# Connect puzzle signals
	if _radix_sort.has_signal("puzzle_completed") and not _radix_sort.puzzle_completed.is_connected(_on_puzzle_completed):
		_radix_sort.puzzle_completed.connect(_on_puzzle_completed)

	if _radix_sort.has_signal("puzzle_failed") and not _radix_sort.puzzle_failed.is_connected(_on_puzzle_failed):
		_radix_sort.puzzle_failed.connect(_on_puzzle_failed)


func _on_boss_defeated() -> void:
	print("Boss defeated! Opening puzzle...")
	_radix_sort.visible = true
	if _radix_boss.has_method("on_stun_started_mock"):
		_radix_boss.call("on_stun_started_mock")


func _on_puzzle_completed() -> void:
	print("Puzzle completed!")
	# TODO: trigger level complete UI
	_capture_result_snapshot("success")
	if _level_cleared != null and _level_cleared.has_method("show_results"):
		_level_cleared.call("show_results", _last_elapsed_seconds, _last_mistakes_made)
	_level_cleared.visible = true
	# disable player controls
	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)


func _on_puzzle_failed() -> void:
	print("Puzzle failed!")
	# TODO: trigger retry logic
	_capture_result_snapshot("failed")
	if _game_over != null and _game_over.has_method("show_results"):
		_game_over.call("show_results", _last_elapsed_seconds, _last_mistakes_made)
	_game_over.visible = true
	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)


func _on_player_died() -> void:
	print("Player died — showing Game Over")
	_capture_result_snapshot("failed")
	if _game_over != null and _game_over.has_method("show_results"):
		_game_over.call("show_results", _last_elapsed_seconds, _last_mistakes_made)
	_game_over.visible = true
	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)


func _set_boss_combat_enabled(enabled: bool) -> void:
	if _radix_boss != null and _radix_boss.has_method("set_combat_enabled"):
		_radix_boss.call("set_combat_enabled", enabled)


func _set_player_controls_enabled(enabled: bool) -> void:
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", enabled)


func _capture_result_snapshot(result: String) -> void:
	_last_result = result
	if _hud != null and _hud.has_method("stop_timer"):
		_hud.call("stop_timer")
	if _hud != null and _hud.has_method("get_elapsed_seconds"):
		_last_elapsed_seconds = float(_hud.call("get_elapsed_seconds"))
	if _radix_sort != null and _radix_sort.has_method("get_mistake_count"):
		_last_mistakes_made = int(_radix_sort.call("get_mistake_count"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		_radix_sort.visible = not _radix_sort.visible
		get_viewport().set_input_as_handled()
