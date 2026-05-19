extends Node

const LEVEL_DATA_DIR: String = "res://data/levels"
const PROGRESSION_SAVE_PATH: String = "user://progression.cfg"
const LEVEL_DEFINITIONS: Array[Resource] = [
	preload("res://data/levels/level_01.tres"),
	preload("res://data/levels/level_02.tres"),
	preload("res://data/levels/level_03.tres"),
	preload("res://data/levels/level_04.tres"),
	preload("res://data/levels/level_05.tres"),
	preload("res://data/levels/level_06.tres"),
]

var _level_definitions: Array[Resource] = []
var _highest_unlocked_level: int = 1

func _ready() -> void:
	_load_level_definitions()
	_load_progression()

func get_level_definitions() -> Array[Resource]:
	return _level_definitions.duplicate()

func get_level_definition(level_id: int) -> Resource:
	for definition in _level_definitions:
		if int(definition.get("level_id")) == level_id:
			return definition
	return null

func get_highest_unlocked_level() -> int:
	return _highest_unlocked_level

func is_level_unlocked(level_id: int) -> bool:
	# Development mode: keep every level unlocked so the selector can be tested freely.
	return get_level_definition(level_id) != null

func mark_level_completed(level_id: int) -> void:
	var max_level_id: int = _get_max_level_id()
	if max_level_id <= 0:
		return
	var candidate_unlock: int = mini(level_id + 1, max_level_id)
	if candidate_unlock > _highest_unlocked_level:
		_highest_unlocked_level = candidate_unlock
		_save_progression()

func _load_level_definitions() -> void:
	_level_definitions.clear()
	for resource: Resource in LEVEL_DEFINITIONS:
		if resource != null and resource.get("level_id") != null:
			_level_definitions.append(resource)

	if _level_definitions.is_empty():
		push_warning("No level definitions were loaded from the built-in resource list.")

	_level_definitions.sort_custom(func(a: Resource, b: Resource) -> bool: return int(a.get("level_id")) < int(b.get("level_id")))

func _load_progression() -> void:
	_highest_unlocked_level = 1
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(PROGRESSION_SAVE_PATH)
	if err != OK:
		return
	_highest_unlocked_level = maxi(int(cfg.get_value("progression", "highest_unlocked_level", 1)), 1)

func _save_progression() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("progression", "highest_unlocked_level", _highest_unlocked_level)
	var err: int = cfg.save(PROGRESSION_SAVE_PATH)
	if err != OK:
		push_warning("Failed to save progression to %s" % PROGRESSION_SAVE_PATH)

func _get_max_level_id() -> int:
	if _level_definitions.is_empty():
		return 0
	return int(_level_definitions[_level_definitions.size() - 1].get("level_id"))
