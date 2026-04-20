extends Node2D

@onready var _bubble_sort_puzzle: CanvasLayer = $BubbleSortPuzzle
@onready var _bubble_boss: Node = $BubbleBoss
@onready var _player: Node2D = $Player
@onready var _hud: CanvasLayer = $HUD
@onready var _level_cleared: CanvasLayer = $LevelCleared
@onready var _game_over: CanvasLayer = $GameOver

var _initial_player_position: Vector2 = Vector2.ZERO
var _initial_boss_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	AudioController.play_boss_music()
	_bubble_sort_puzzle.visible = false
	_level_cleared.visible = false
	_game_over.visible = false
	_set_player_controls_enabled(true)
	_set_boss_combat_enabled(true)
	_initial_player_position = _player.global_position
	if _bubble_boss is Node2D:
		_initial_boss_position = (_bubble_boss as Node2D).global_position

	if _bubble_boss.has_signal("boss_defeated") and not _bubble_boss.boss_defeated.is_connected(_on_boss_defeated):
		_bubble_boss.boss_defeated.connect(_on_boss_defeated)

	if _player != null and _player.has_signal("player_died") and not _player.player_died.is_connected(_on_player_died):
		_player.player_died.connect(_on_player_died)

	if _bubble_sort_puzzle.has_signal("puzzle_failed") and not _bubble_sort_puzzle.puzzle_failed.is_connected(_on_puzzle_failed):
		_bubble_sort_puzzle.puzzle_failed.connect(_on_puzzle_failed)

	if _bubble_sort_puzzle.has_signal("puzzle_completed") and not _bubble_sort_puzzle.puzzle_completed.is_connected(_on_puzzle_completed):
		_bubble_sort_puzzle.puzzle_completed.connect(_on_puzzle_completed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		var opening_puzzle: bool = not _bubble_sort_puzzle.visible
		_bubble_sort_puzzle.visible = opening_puzzle
		if opening_puzzle:
			if _bubble_boss.has_method("on_stun_started_mock"):
				_bubble_boss.call("on_stun_started_mock")
		else:
			if _bubble_boss.has_method("on_stun_modal_closed_mock"):
				_bubble_boss.call("on_stun_modal_closed_mock")
		get_viewport().set_input_as_handled()

func _on_puzzle_failed() -> void:
	if _hud != null and _hud.has_method("stop_timer"):
		_hud.call("stop_timer")

	var elapsed_seconds: float = 0.0
	var mistakes_made: int = 0

	if _hud != null and _hud.has_method("get_elapsed_seconds"):
		elapsed_seconds = float(_hud.call("get_elapsed_seconds"))
	if _bubble_sort_puzzle != null and _bubble_sort_puzzle.has_method("get_mistake_count"):
		mistakes_made = int(_bubble_sort_puzzle.call("get_mistake_count"))

	if _game_over != null and _game_over.has_method("show_results"):
		_game_over.call("show_results", elapsed_seconds, mistakes_made)

	_bubble_sort_puzzle.visible = false
	_level_cleared.visible = false
	_game_over.visible = true
	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)

func _on_puzzle_completed() -> void:
	var elapsed_seconds: float = 0.0
	var mistakes_made: int = 0

	if _hud != null and _hud.has_method("get_elapsed_seconds"):
		elapsed_seconds = float(_hud.call("get_elapsed_seconds"))
	if _bubble_sort_puzzle != null and _bubble_sort_puzzle.has_method("get_mistake_count"):
		mistakes_made = int(_bubble_sort_puzzle.call("get_mistake_count"))

	if _level_cleared != null and _level_cleared.has_method("show_results"):
		_level_cleared.call("show_results", elapsed_seconds, mistakes_made)

	_bubble_sort_puzzle.visible = false
	_game_over.visible = false
	_level_cleared.visible = true
	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)
	if _hud != null and _hud.has_method("stop_timer"):
		_hud.call("stop_timer")

func _on_player_died() -> void:
	if _hud != null and _hud.has_method("stop_timer"):
		_hud.call("stop_timer")

	var elapsed_seconds: float = 0.0
	var mistakes_made: int = 0

	if _hud != null and _hud.has_method("get_elapsed_seconds"):
		elapsed_seconds = float(_hud.call("get_elapsed_seconds"))
	if _bubble_sort_puzzle != null and _bubble_sort_puzzle.has_method("get_mistake_count"):
		mistakes_made = int(_bubble_sort_puzzle.call("get_mistake_count"))

	if _game_over != null and _game_over.has_method("show_results"):
		_game_over.call("show_results", elapsed_seconds, mistakes_made)

	_bubble_sort_puzzle.visible = false
	_level_cleared.visible = false
	_game_over.visible = true
	_set_player_controls_enabled(false)
	_set_boss_combat_enabled(false)

func _on_boss_defeated() -> void:
	_bubble_sort_puzzle.visible = true
	if _bubble_boss.has_method("on_stun_started_mock"):
		_bubble_boss.call("on_stun_started_mock")

func _set_boss_combat_enabled(enabled: bool) -> void:
	if _bubble_boss != null and _bubble_boss.has_method("set_combat_enabled"):
		_bubble_boss.call("set_combat_enabled", enabled)

func _set_player_controls_enabled(enabled: bool) -> void:
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", enabled)
