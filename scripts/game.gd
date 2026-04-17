extends Node2D

@onready var _bubble_sort_puzzle: CanvasLayer = $BubbleSortPuzzle
@onready var _bubble_boss: Node = $BubbleBoss
@onready var _player: Node2D = $Player
@onready var _hud: CanvasLayer = $HUD
@onready var _level_cleared_screen: CanvasLayer = $LevelClearedScreen

var _initial_player_position: Vector2 = Vector2.ZERO
var _initial_boss_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_bubble_sort_puzzle.visible = false
	_level_cleared_screen.visible = false
	_initial_player_position = _player.global_position
	if _bubble_boss is Node2D:
		_initial_boss_position = (_bubble_boss as Node2D).global_position

	if _bubble_boss.has_signal("boss_defeated") and not _bubble_boss.boss_defeated.is_connected(_on_boss_defeated):
		_bubble_boss.boss_defeated.connect(_on_boss_defeated)

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
	_bubble_sort_puzzle.visible = false

	if _bubble_boss.has_method("reset_for_retry"):
		_bubble_boss.call("reset_for_retry", _initial_boss_position)
	elif _bubble_boss.has_method("on_resonance_surge_mock"):
		_bubble_boss.call("on_resonance_surge_mock")

	if _player != null and _player.has_method("reset_for_retry"):
		_player.call("reset_for_retry", _initial_player_position)
	elif _player != null:
		_player.global_position = _initial_player_position

func _on_puzzle_completed() -> void:
	var elapsed_seconds: float = 0.0
	var mistakes_made: int = 0

	if _hud != null and _hud.has_method("get_elapsed_seconds"):
		elapsed_seconds = float(_hud.call("get_elapsed_seconds"))
	if _bubble_sort_puzzle != null and _bubble_sort_puzzle.has_method("get_mistake_count"):
		mistakes_made = int(_bubble_sort_puzzle.call("get_mistake_count"))

	if _level_cleared_screen != null and _level_cleared_screen.has_method("show_results"):
		_level_cleared_screen.call("show_results", elapsed_seconds, mistakes_made)

	_bubble_sort_puzzle.visible = false
	_level_cleared_screen.visible = true

func _on_boss_defeated() -> void:
	_bubble_sort_puzzle.visible = true
	if _bubble_boss.has_method("on_stun_started_mock"):
		_bubble_boss.call("on_stun_started_mock")
