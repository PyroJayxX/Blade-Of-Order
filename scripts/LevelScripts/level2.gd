extends Node2D

const VS_SCREEN: PackedScene = preload("res://scenes/Game/vs_screen.tscn")
const CUTSCENE_SCREEN: PackedScene = preload("res://scenes/App/cutscene.tscn")
const SELECTION_BOSS_PORTRAIT: Texture2D = preload("res://assets/boss_splash/SelectionSort_Splash_NOBG.png")

@onready var _selection_sort_puzzle: CanvasLayer = $SelectionSort
@onready var _selection_boss: Node = $Lvl2Selection
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
	_selection_sort_puzzle.visible = false
	_level_cleared.visible = false
	_game_over.visible = false
	_initial_player_position = _player.global_position
	if _selection_boss is Node2D:
		_initial_boss_position = (_selection_boss as Node2D).global_position

	if _selection_boss.has_signal("boss_defeated") and not _selection_boss.boss_defeated.is_connected(_on_boss_defeated):
		_selection_boss.boss_defeated.connect(_on_boss_defeated)

	if _player != null and _player.has_signal("player_died") and not _player.player_died.is_connected(_on_player_died):
		_player.player_died.connect(_on_player_died)

	if _selection_sort_puzzle.has_signal("puzzle_failed") and not _selection_sort_puzzle.puzzle_failed.is_connected(_on_puzzle_failed):
		_selection_sort_puzzle.puzzle_failed.connect(_on_puzzle_failed)

	if _selection_sort_puzzle.has_signal("puzzle_completed") and not _selection_sort_puzzle.puzzle_completed.is_connected(_on_puzzle_completed):
		_selection_sort_puzzle.puzzle_completed.connect(_on_puzzle_completed)

	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)
	await _show_vs_intro()
	await _show_level_start_cutscene()
	start_level()


func _show_level_start_cutscene() -> void:
	var cutscene: Node = get_node_or_null("Cutscene")
	var instantiated: bool = false
	if cutscene == null:
		cutscene = CUTSCENE_SCREEN.instantiate()
		add_child(cutscene)
		instantiated = true

	_set_boss_combat_enabled(false)
	cutscene.play()

	await cutscene.cutscene_finished
	_set_boss_combat_enabled(true)

func start_level() -> void:
	_set_player_controls_enabled(true)
	_set_boss_combat_enabled(true)
	if _hud != null and _hud.has_method("start_timer"):
		_hud.call("start_timer")

func _show_vs_intro() -> void:
	var vs: CanvasLayer = VS_SCREEN.instantiate()
	vs.boss_name = "SELECTION SORT BOSS"
	vs.boss_texture = SELECTION_BOSS_PORTRAIT
	vs.next_scene_path = ""
	add_child(vs)
	await vs.intro_finished

func pause_level(is_paused: bool) -> void:
	get_tree().paused = is_paused

func restart_level() -> void:
	_stop_level_music()
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("restart_active_level")

func get_result_payload() -> Dictionary:
	return {
		"result": _last_result,
		"elapsed_seconds": _last_elapsed_seconds,
		"mistakes_made": _last_mistakes_made,
	}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		var opening_puzzle: bool = not _selection_sort_puzzle.visible
		_selection_sort_puzzle.visible = opening_puzzle
		if opening_puzzle:
			if _selection_boss.has_method("on_stun_started_mock"):
				_selection_boss.call("on_stun_started_mock")
		else:
			if _selection_boss.has_method("on_stun_modal_closed_mock"):
				_selection_boss.call("on_stun_modal_closed_mock")
		get_viewport().set_input_as_handled()

func _on_puzzle_failed() -> void:
	_stop_level_music()
	_capture_result_snapshot("failed")
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("on_level_failed", get_result_payload())

	if _game_over != null and _game_over.has_method("show_results"):
		_game_over.call("show_results", _last_elapsed_seconds, _last_mistakes_made)

	_selection_sort_puzzle.visible = false
	_level_cleared.visible = false
	_game_over.visible = true
	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)

func _on_puzzle_completed() -> void:
	_stop_level_music()
	_capture_result_snapshot("cleared")
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("on_level_cleared", {"go_to_level_select": false})

	if _level_cleared != null and _level_cleared.has_method("show_results"):
		_level_cleared.call("show_results", _last_elapsed_seconds, _last_mistakes_made)

	_selection_sort_puzzle.visible = false
	_game_over.visible = false
	_level_cleared.visible = true
	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)
	if _hud != null and _hud.has_method("stop_timer"):
		_hud.call("stop_timer")

func _on_player_died() -> void:
	_stop_level_music()
	_capture_result_snapshot("failed")
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("on_level_failed", get_result_payload())

	if _game_over != null and _game_over.has_method("show_results"):
		_game_over.call("show_results", _last_elapsed_seconds, _last_mistakes_made)

	_selection_sort_puzzle.visible = false
	_level_cleared.visible = false
	_game_over.visible = true
	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)

func _on_boss_defeated() -> void:
	_selection_sort_puzzle.visible = true
	if _selection_boss.has_method("on_stun_started_mock"):
		_selection_boss.call("on_stun_started_mock")

func _set_boss_combat_enabled(enabled: bool) -> void:
	if _selection_boss != null and _selection_boss.has_method("set_combat_enabled"):
		_selection_boss.call("set_combat_enabled", enabled)

func _set_player_controls_enabled(enabled: bool) -> void:
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", enabled)

func _capture_result_snapshot(result: String) -> void:
	_last_result = result
	if _hud != null and _hud.has_method("stop_timer"):
		_hud.call("stop_timer")
	if _hud != null and _hud.has_method("get_elapsed_seconds"):
		_last_elapsed_seconds = float(_hud.call("get_elapsed_seconds"))
	if _selection_sort_puzzle != null and _selection_sort_puzzle.has_method("get_mistake_count"):
		_last_mistakes_made = int(_selection_sort_puzzle.call("get_mistake_count"))
		
func _stop_level_music() -> void:
	if AudioController != null and AudioController.has_method("stop_all_music"):
		AudioController.stop_all_music()
