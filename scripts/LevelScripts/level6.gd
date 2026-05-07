extends Node2D

const VS_SCREEN: PackedScene = preload("res://scenes/Game/vs_screen.tscn")
const RADIX_BOSS_PORTRAIT: Texture2D = preload("res://assets/boss_splash/BubbleSort_Splash_NOBG.png")

@onready var _radix_sort: CanvasLayer = $RadixSort
@onready var _radix_boss: Node = $RadixBoss
@onready var _player: Node2D = $Player
@onready var _hud: CanvasLayer = $HUD
@onready var _level_cleared: CanvasLayer = $LevelCleared
@onready var _game_over: CanvasLayer = $GameOver

var _initial_player_position: Vector2 = Vector2.ZERO
var _initial_boss_position: Vector2 = Vector2.ZERO
var _last_elapsed_seconds: float = 0.0
var _last_mistakes_made: int = 0
var _last_result: String = "running"


func _ready() -> void:
	AudioController.play_boss_music()
	_radix_sort.visible = false
	_level_cleared.visible = false
	_game_over.visible = false
	_initial_player_position = _player.global_position
	if _radix_boss is Node2D:
		_initial_boss_position = (_radix_boss as Node2D).global_position

	if _radix_boss.has_signal("boss_defeated") and not _radix_boss.boss_defeated.is_connected(_on_boss_defeated):
		_radix_boss.boss_defeated.connect(_on_boss_defeated)

	if _player != null and _player.has_signal("player_died") and not _player.player_died.is_connected(_on_player_died):
		_player.player_died.connect(_on_player_died)

	# Connect puzzle signals. Some puzzles expose signals on the CanvasLayer (like Bubble),
	# others place a `PuzzleManager` child that emits them. Handle both cases.
	if _radix_sort.has_signal("puzzle_failed") and not _radix_sort.puzzle_failed.is_connected(_on_puzzle_failed):
		_radix_sort.puzzle_failed.connect(_on_puzzle_failed)
	else:
		var pm: Node = _radix_sort.get_node_or_null("PuzzleManager")
		if pm != null and pm.has_signal("puzzle_failed") and not pm.puzzle_failed.is_connected(_on_puzzle_failed):
			pm.puzzle_failed.connect(_on_puzzle_failed)

	if _radix_sort.has_signal("puzzle_completed") and not _radix_sort.puzzle_completed.is_connected(_on_puzzle_completed):
		_radix_sort.puzzle_completed.connect(_on_puzzle_completed)
	else:
		var pm2: Node = _radix_sort.get_node_or_null("PuzzleManager")
		if pm2 != null and pm2.has_signal("puzzle_completed") and not pm2.puzzle_completed.is_connected(_on_puzzle_completed):
			pm2.puzzle_completed.connect(_on_puzzle_completed)

	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)
	await _show_vs_intro()
	start_level()


func start_level() -> void:
	_set_player_controls_enabled(true)
	_set_boss_combat_enabled(true)
	if _hud != null and _hud.has_method("start_timer"):
		_hud.call("start_timer")


func _show_vs_intro() -> void:
	var vs: CanvasLayer = VS_SCREEN.instantiate()
	vs.boss_name = "RADIX SORT BOSS"
	vs.boss_texture = RADIX_BOSS_PORTRAIT
	vs.next_scene_path = ""
	add_child(vs)
	await vs.intro_finished


func pause_level(is_paused: bool) -> void:
	get_tree().paused = is_paused


func restart_level() -> void:
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("restart_active_level")


func get_result_payload() -> Dictionary:
	return {
		"result": _last_result,
		"elapsed_seconds": _last_elapsed_seconds,
		"mistakes_made": _last_mistakes_made,
	}


func _on_boss_defeated() -> void:
	_radix_sort.visible = true
	if _radix_boss.has_method("on_stun_started_mock"):
		_radix_boss.call("on_stun_started_mock")


func _on_puzzle_completed() -> void:
	_capture_result_snapshot("cleared")
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("on_level_cleared", {"go_to_level_select": false})

	if _level_cleared != null and _level_cleared.has_method("show_results"):
		_level_cleared.call("show_results", _last_elapsed_seconds, _last_mistakes_made)

	_radix_sort.visible = false
	_game_over.visible = false
	_level_cleared.visible = true
	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)
	if _hud != null and _hud.has_method("stop_timer"):
		_hud.call("stop_timer")


func _on_puzzle_failed() -> void:
	_capture_result_snapshot("failed")
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("on_level_failed", get_result_payload())

	if _game_over != null and _game_over.has_method("show_results"):
		_game_over.call("show_results", _last_elapsed_seconds, _last_mistakes_made)

	_radix_sort.visible = false
	_level_cleared.visible = false
	_game_over.visible = true
	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)


func _on_player_died() -> void:
	_capture_result_snapshot("failed")
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("on_level_failed", get_result_payload())

	if _game_over != null and _game_over.has_method("show_results"):
		_game_over.call("show_results", _last_elapsed_seconds, _last_mistakes_made)

	_radix_sort.visible = false
	_level_cleared.visible = false
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
	# Some puzzles provide a `get_mistake_count()` on the CanvasLayer; others keep it
	# on a `PuzzleManager` child. Try both, otherwise default to 0.
	if _radix_sort != null and _radix_sort.has_method("get_mistake_count"):
		_last_mistakes_made = int(_radix_sort.call("get_mistake_count"))
	else:
		var pm: Node = _radix_sort.get_node_or_null("PuzzleManager")
		if pm != null and pm.has_method("get_mistake_count"):
			_last_mistakes_made = int(pm.call("get_mistake_count"))
		else:
			_last_mistakes_made = 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		var opening_puzzle: bool = not _radix_sort.visible
		_radix_sort.visible = opening_puzzle
		if opening_puzzle:
			if _radix_boss.has_method("on_stun_started_mock"):
				_radix_boss.call("on_stun_started_mock")
		else:
			if _radix_boss.has_method("on_stun_modal_closed_mock"):
				_radix_boss.call("on_stun_modal_closed_mock")
		get_viewport().set_input_as_handled()
