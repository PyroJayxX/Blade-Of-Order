extends Node

const SAVE_PATH: String = "user://player_data.json"

var player_name: String = ""
var personal_best: int = 0
var boss_personal_bests: Dictionary = {}
var pending_submission_score: int = 0
var pending_submission_level_id: int = 0

func _ready() -> void:
	_load()

func save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open %s for writing." % SAVE_PATH)
		return

	var data: Dictionary = {
		"player_name": player_name,
		"personal_best": personal_best,
		"boss_personal_bests": boss_personal_bests,
		"pending_submission_score": pending_submission_score,
		"pending_submission_level_id": pending_submission_level_id,
	}
	file.store_string(JSON.stringify(data))

func set_player_name(name: String) -> void:
	player_name = name.strip_edges()
	personal_best = 0
	boss_personal_bests.clear()
	pending_submission_score = 0
	pending_submission_level_id = 0
	save()

func set_pending_submission(score: int, level_id: int) -> void:
	pending_submission_score = maxi(score, 0)
	pending_submission_level_id = maxi(level_id, 0)
	save()

func consume_pending_submission() -> Dictionary:
	if pending_submission_score <= 0 and pending_submission_level_id <= 0:
		return {}
	var payload: Dictionary = {
		"score": pending_submission_score,
		"level_id": pending_submission_level_id,
	}
	pending_submission_score = 0
	pending_submission_level_id = 0
	save()
	return payload

func try_submit_score(score: int) -> bool:
	return try_submit_score_for_boss("global", score)

func get_personal_best_for_boss(boss_key: String) -> int:
	var safe_boss_key: String = _normalize_boss_key(boss_key)
	return maxi(int(boss_personal_bests.get(safe_boss_key, 0)), 0)

func try_submit_score_for_boss(boss_key: String, score: int) -> bool:
	if score <= 0:
		return false
	var safe_boss_key: String = _normalize_boss_key(boss_key)
	var previous_best: int = get_personal_best_for_boss(safe_boss_key)
	if score <= previous_best:
		return false
	boss_personal_bests[safe_boss_key] = score
	personal_best = maxi(personal_best, score)
	save()
	return true

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		player_name = ""
		personal_best = 0
		save()
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Failed to open %s for reading." % SAVE_PATH)
		return

	var raw_text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		var data: Dictionary = parsed
		player_name = String(data.get("player_name", "")).strip_edges()
		personal_best = maxi(int(data.get("personal_best", 0)), 0)
		pending_submission_score = maxi(int(data.get("pending_submission_score", 0)), 0)
		pending_submission_level_id = maxi(int(data.get("pending_submission_level_id", 0)), 0)
		boss_personal_bests.clear()
		var parsed_bests: Variant = data.get("boss_personal_bests", {})
		if parsed_bests is Dictionary:
			for key in parsed_bests.keys():
				var safe_key: String = _normalize_boss_key(String(key))
				boss_personal_bests[safe_key] = maxi(int((parsed_bests as Dictionary).get(key, 0)), 0)
		if boss_personal_bests.is_empty() and personal_best > 0:
			boss_personal_bests["global"] = personal_best
	else:
		player_name = ""
		personal_best = 0
		pending_submission_score = 0
		pending_submission_level_id = 0
		boss_personal_bests.clear()
		save()

func _normalize_boss_key(boss_key: String) -> String:
	var safe_key: String = boss_key.strip_edges().to_lower()
	if safe_key.is_empty():
		return "global"
	return safe_key
