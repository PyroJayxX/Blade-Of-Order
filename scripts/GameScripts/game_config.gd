extends Node

const LEVEL_DATA_DIR: String = "res://data/levels"
const PROGRESSION_SAVE_PATH: String = "user://progression.cfg"

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
	var definition: Resource = get_level_definition(level_id)
	if definition == null:
		return false
	if int(definition.get("unlock_level_required")) <= 0:
		return true
	return _highest_unlocked_level >= int(definition.get("unlock_level_required"))

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
	if not DirAccess.dir_exists_absolute(LEVEL_DATA_DIR):
		push_warning("Level data directory missing: %s" % LEVEL_DATA_DIR)
		return

	var files: PackedStringArray = DirAccess.get_files_at(LEVEL_DATA_DIR)
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var path: String = "%s/%s" % [LEVEL_DATA_DIR, file_name]
		var resource: Resource = load(path)
		if resource != null and resource.get("level_id") != null:
			_level_definitions.append(resource)

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