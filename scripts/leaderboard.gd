extends CanvasLayer

const TABLE_NAME: String = "leaderboard"
const ROW_SCENE: PackedScene = preload("res://scenes/Game/leaderboard_row.tscn")

const GOLD_RANK_COLOR: Color = Color(1.0, 0.84, 0.0, 1.0)
const SILVER_RANK_COLOR: Color = Color(0.75, 0.75, 0.75, 1.0)
const BRONZE_RANK_COLOR: Color = Color(0.8, 0.5, 0.2, 1.0)
const DEFAULT_RANK_COLOR: Color = Color(0.95, 0.98, 1.0, 1.0)

@onready var _entry_list: VBoxContainer = $Panel/ScrollContainer/VBoxContainer/EntryList
@onready var _name_state_label: Label = $Panel/ScrollContainer/VBoxContainer/NameRow/NameStateLabel
@onready var _name_action_button: Button = $Panel/ScrollContainer/VBoxContainer/NameRow/NameActionButton
@onready var _name_dialog: PanelContainer = $Panel/NameDialog
@onready var _name_line_edit: LineEdit = $Panel/NameDialog/VBox/NameLineEdit
@onready var _name_status_label: Label = $Panel/NameDialog/VBox/NameStatusLabel
@onready var _confirm_name_button: Button = $Panel/NameDialog/VBox/Buttons/ConfirmNameButton
@onready var _cancel_name_button: Button = $Panel/NameDialog/VBox/Buttons/CancelNameButton
@onready var _loading_label: Label = $Panel/ScrollContainer/VBoxContainer/LoadingLabel
@onready var _best_notification_label: Label = $Panel/ScrollContainer/VBoxContainer/BestNotificationLabel
@onready var _notification_timer: Timer = $NotificationTimer
@onready var _boss_filter_option: OptionButton = $Panel/ScrollContainer/VBoxContainer/BossFilterRow/BossFilterOption
@onready var _close_button: Button = $Panel/ScrollContainer/VBoxContainer/Buttons/CloseButton

var _current_score: int = 0
var _pending_auto_submit_score: int = -1
var _submit_after_name_confirm: bool = false
var _notification_tween: Tween = null
var _selected_level_id: int = 0 # 0 means global/no filter

func _ready() -> void:
	_name_action_button.pressed.connect(_on_name_action_button_pressed)
	_confirm_name_button.pressed.connect(_on_confirm_name_button_pressed)
	_cancel_name_button.pressed.connect(_on_cancel_name_button_pressed)
	_notification_timer.timeout.connect(_on_notification_timer_timeout)
	_boss_filter_option.item_selected.connect(_on_boss_filter_selected)
	_close_button.pressed.connect(_on_close_button_pressed)
	_name_dialog.visible = false
	_best_notification_label.visible = false
	_best_notification_label.modulate.a = 0.0
	_loading_label.text = ""
	_populate_boss_filter()
	_apply_scene_flow_context()
	_update_name_ui()
	await _handle_entry_submission()
	fetch_scores()

func open(score: int) -> void:
	_current_score = score
	visible = true
	_name_dialog.visible = false
	_name_line_edit.text = ""
	_name_status_label.text = ""
	_pending_auto_submit_score = -1
	_submit_after_name_confirm = false
	_update_name_ui()
	await _handle_entry_submission()
	fetch_scores()

func fetch_scores() -> void:
	_loading_label.visible = true
	_loading_label.text = "Loading..."
	var db: SupabaseDatabase = _get_database()
	if db == null:
		_loading_label.text = "Failed to load leaderboard: Supabase autoload is missing."
		return

	var query: SupabaseQuery = SupabaseQuery.new().from(TABLE_NAME).select().order("score", SupabaseQuery.Directions.Descending).range(0, 9)
	
	# Apply integer level filter if a specific level is selected
	if _selected_level_id > 0:
		query.eq("level", String.num_int64(_selected_level_id))
		
	var result: Dictionary = await _run_database_query(db, query, &"selected")
	
	if not bool(result.get("success", false)):
		var error_message: String = _extract_error_from_payload(result.get("payload"))
		_loading_label.text = "Failed to load leaderboard: %s" % error_message
		return

	var rows: Array = _normalize_rows(result.get("payload"))
	_loading_label.visible = false
	if rows.is_empty():
		_loading_label.visible = true
		_loading_label.text = "No scores yet."
	_populate_leaderboard(rows)

func submit_score(player_name: String, score: int, refresh_on_success: bool = true) -> bool:
	var safe_name: String = player_name.strip_edges()
	if safe_name.is_empty():
		_name_status_label.text = "Name is required."
		return false
	if score <= 0:
		_name_status_label.text = "Score must be greater than 0."
		return false
	var player_data: Node = _get_player_data()
	if player_data != null:
		var boss_key: String = _get_active_boss_key_for_personal_score()
		var local_best: int = int(player_data.call("get_personal_best_for_boss", boss_key))
		if score < local_best:
			_name_status_label.text = "Score is below your personal best for this boss."
			return false

	_name_status_label.text = "Submitting..."
	var db: SupabaseDatabase = _get_database()
	if db == null:
		_name_status_label.text = "Supabase autoload is missing."
		return false

	# Single-row-per-username sync: update if row exists and score is better, else insert.
	var has_level_filter: bool = _selected_level_id > 0
	var lookup_query: SupabaseQuery = SupabaseQuery.new().from(TABLE_NAME).select().eq("player_name", safe_name).range(0, 0)
	var lookup_result: Dictionary = await _run_database_query(db, lookup_query, &"selected")

	if not bool(lookup_result.get("success", false)):
		_name_status_label.text = "Submit failed: %s" % _extract_error_from_payload(lookup_result.get("payload"))
		return false

	var existing_rows: Array = _normalize_rows(lookup_result.get("payload"))
	if not existing_rows.is_empty():
		var existing_score: int = int((existing_rows[0] as Dictionary).get("score", 0))
		if score <= existing_score:
			_name_status_label.text = ""
			if refresh_on_success:
				fetch_scores()
			return true

		var update_fields: Dictionary = {"score": score}
		if has_level_filter:
			update_fields["level"] = _selected_level_id
		var update_query: SupabaseQuery = SupabaseQuery.new().from(TABLE_NAME).update(update_fields).eq("player_name", safe_name)
		var update_result: Dictionary = await _run_database_query(db, update_query, &"updated")
		if not bool(update_result.get("success", false)):
			_name_status_label.text = "Submit failed: %s" % _extract_error_from_payload(update_result.get("payload"))
			return false
		_name_status_label.text = ""
		if refresh_on_success:
			fetch_scores()
		return true

	var insert_row: Dictionary = {"player_name": safe_name, "score": score}
	if has_level_filter:
		insert_row["level"] = _selected_level_id
	var insert_query: SupabaseQuery = SupabaseQuery.new().from(TABLE_NAME).insert([insert_row])
	var insert_result: Dictionary = await _run_database_query(db, insert_query, &"inserted")
	if bool(insert_result.get("success", false)):
		_name_status_label.text = ""
		if refresh_on_success:
			fetch_scores()
		return true

	_name_status_label.text = "Submit failed: %s" % _extract_error_from_payload(insert_result.get("payload"))
	return false

func _populate_leaderboard(rows: Array) -> void:
	for child in _entry_list.get_children():
		child.queue_free()

	for i in range(rows.size()):
		var row_instance: Node = ROW_SCENE.instantiate()
		_entry_list.add_child(row_instance)

		var row_data: Dictionary = rows[i] if rows[i] is Dictionary else {}
		var rank_label: Label = row_instance.get_node_or_null("RankLabel") as Label
		var name_label: Label = row_instance.get_node_or_null("NameLabel") as Label
		var score_label: Label = row_instance.get_node_or_null("ScoreLabel") as Label

		if rank_label != null:
			rank_label.text = "#%d" % [i + 1]
			rank_label.modulate = _rank_color(i)
		if name_label != null:
			name_label.text = String(row_data.get("player_name", "---"))
		if score_label != null:
			score_label.text = String.num_int64(int(row_data.get("score", 0)))

func _on_submit_button_pressed() -> void:
	var player_name: String = ""
	var player_data: Node = _get_player_data()
	if player_data != null:
		player_name = String(player_data.get("player_name")).strip_edges()
	if player_name.is_empty():
		_submit_after_name_confirm = true
		_show_name_dialog("Enter a display name before submitting.")
		return
	if _current_score <= 0:
		_name_status_label.text = "No run score available. Finish a level to submit a score."
		return
	await submit_score(player_name, _current_score, true)

func _on_close_button_pressed() -> void:
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("goto_main_menu")
	else:
		queue_free()

func _on_boss_filter_selected(index: int) -> void:
	_selected_level_id = int(_boss_filter_option.get_item_metadata(index))
	_update_name_ui()
	fetch_scores()

func _on_name_action_button_pressed() -> void:
	_submit_after_name_confirm = false
	_pending_auto_submit_score = -1
	_show_name_dialog("")

func _on_confirm_name_button_pressed() -> void:
	var safe_name: String = _name_line_edit.text.strip_edges()
	if safe_name.is_empty():
		_name_status_label.text = "Name cannot be empty."
		return

	var player_data: Node = _get_player_data()
	if player_data == null:
		_name_status_label.text = "PlayerData autoload is missing."
		return

	player_data.call("set_player_name", safe_name)
	_update_name_ui()
	_name_status_label.text = ""
	_name_dialog.visible = false

	if _pending_auto_submit_score > 0:
		var pending_score: int = _pending_auto_submit_score
		_pending_auto_submit_score = -1
		var auto_success: bool = await submit_score(String(player_data.get("player_name")), pending_score, false)
		if auto_success:
			fetch_scores()
		return

	if _submit_after_name_confirm:
		_submit_after_name_confirm = false
		await submit_score(String(player_data.get("player_name")), _current_score, true)

func _on_cancel_name_button_pressed() -> void:
	_name_dialog.visible = false
	_name_status_label.text = ""
	_submit_after_name_confirm = false
	_pending_auto_submit_score = -1

func _show_name_dialog(message: String) -> void:
	_name_dialog.visible = true
	var player_data: Node = _get_player_data()
	if player_data != null:
		_name_line_edit.text = String(player_data.get("player_name"))
	else:
		_name_line_edit.text = ""
	_name_status_label.text = message
	_name_line_edit.grab_focus()

func _update_name_ui() -> void:
	var player_data: Node = _get_player_data()
	var safe_name: String = ""
	var personal_score: int = 0
	if player_data != null:
		safe_name = String(player_data.get("player_name")).strip_edges()
		personal_score = int(player_data.call("get_personal_best_for_boss", _get_active_boss_key_for_personal_score()))
	if safe_name.is_empty():
		_name_state_label.text = "You have no name set."
		_name_state_label.modulate = Color(0.95, 0.98, 1.0, 1.0)
		_name_action_button.text = "Enter Name"
	else:
		_name_state_label.text = "Welcome, %s. Personal Best: %d" % [safe_name, personal_score]
		_name_state_label.modulate = Color(0.41960785, 0.9529412, 1.0, 1.0)
		_name_action_button.text = "Edit Name"

func _get_player_data() -> Node:
	if has_node("/root/PlayerData"):
		return get_node("/root/PlayerData")
	return null

func _populate_boss_filter() -> void:
	_boss_filter_option.clear()

	var config: Node = get_node_or_null("/root/GameConfig")
	if config == null:
		return
	var definitions: Array = config.call("get_level_definitions")
	for definition in definitions:
		if not (definition is Resource):
			continue
		var level_id: int = int((definition as Resource).get("level_id"))
		var display_name: String = String((definition as Resource).get("display_name")).strip_edges()
		if display_name.is_empty() or display_name == "???":
			display_name = "Level %d" % level_id
		
		_boss_filter_option.add_item(display_name)
		var item_index: int = _boss_filter_option.get_item_count() - 1
		_boss_filter_option.set_item_metadata(item_index, level_id) # Store the integer level_id
	
	if _boss_filter_option.get_item_count() > 0:
		_boss_filter_option.select(0)
		_selected_level_id = int(_boss_filter_option.get_item_metadata(0))

func _apply_scene_flow_context() -> void:
	var flow: Node = get_node_or_null("/root/SceneFlow")
	var context: Dictionary = {}
	if flow != null and flow.has_method("consume_leaderboard_context"):
		context = flow.call("consume_leaderboard_context")

	if context.is_empty():
		var player_data: Node = _get_player_data()
		if player_data != null and player_data.has_method("consume_pending_submission"):
			context = player_data.call("consume_pending_submission")

	if context.has("score"):
		_current_score = int(context.get("score", _current_score))
	if context.has("level_id"):
		_selected_level_id = int(context.get("level_id", _selected_level_id))

	# Update the dropdown visual selection
	for i in range(_boss_filter_option.get_item_count()):
		if int(_boss_filter_option.get_item_metadata(i)) == _selected_level_id:
			_boss_filter_option.select(i)
			break

func _handle_entry_submission() -> void:
	var player_data: Node = _get_player_data()
	if player_data == null:
		return

	var boss_key: String = _get_active_boss_key_for_personal_score()
	if _current_score > 0:
		player_data.call("try_submit_score_for_boss", boss_key, _current_score)
	var local_best: int = int(player_data.call("get_personal_best_for_boss", boss_key))
	if local_best <= 0:
		return

	var player_name: String = String(player_data.get("player_name")).strip_edges()
	if player_name.is_empty():
		_pending_auto_submit_score = local_best
		_show_name_dialog("Enter a display name to submit your score.")
		return

	var auto_submitted: bool = await submit_score(player_name, local_best, false)
	if auto_submitted and _current_score > 0 and _current_score >= local_best:
		_show_new_best_notification()

func _get_active_boss_key_for_personal_score() -> String:
	# Format the int back into a string so your local PlayerData save file doesn't break
	if _selected_level_id > 0:
		return "level_%d" % _selected_level_id
	return "global"

func _show_new_best_notification() -> void:
	if _notification_tween != null:
		_notification_tween.kill()
	_best_notification_label.visible = true
	_best_notification_label.modulate.a = 0.0
	_notification_tween = create_tween()
	_notification_tween.tween_property(_best_notification_label, "modulate:a", 1.0, 0.2)
	_notification_timer.start(2.5)

func _on_notification_timer_timeout() -> void:
	if _notification_tween != null:
		_notification_tween.kill()
	_notification_tween = create_tween()
	_notification_tween.tween_property(_best_notification_label, "modulate:a", 0.0, 0.3)
	await _notification_tween.finished
	_best_notification_label.visible = false

func _rank_color(index: int) -> Color:
	match index:
		0:
			return GOLD_RANK_COLOR
		1:
			return SILVER_RANK_COLOR
		2:
			return BRONZE_RANK_COLOR
		_:
			return DEFAULT_RANK_COLOR

func _get_database() -> SupabaseDatabase:
	if not has_node("/root/Supabase"):
		return null
	var supabase: Node = get_node("/root/Supabase")
	if not ("database" in supabase):
		return null
	return supabase.database as SupabaseDatabase

func _run_database_query(db: SupabaseDatabase, query: SupabaseQuery, _success_signal_name: StringName) -> Dictionary:
	var task: DatabaseTask = db.query(query)
	await task.completed

	if task.error != null:
		return {
			"success": false,
			"payload": task.error,
		}

	return {
		"success": true,
		"payload": task.data,
	}

func _normalize_rows(payload: Variant) -> Array:
	if payload == null:
		return []
	if payload is Array:
		return payload
	if payload is Dictionary:
		var maybe_data: Variant = (payload as Dictionary).get("data", null)
		if maybe_data is Array:
			return maybe_data
	return []

func _extract_error_from_payload(payload: Variant) -> String:
	if payload == null:
		return "Unknown error"
	if payload is Object and payload.has_method("to_string"):
		return String(payload)
	if payload is Dictionary:
		var payload_dict: Dictionary = payload
		if payload_dict.has("message"):
			return String(payload_dict.get("message"))
		if payload_dict.has("error"):
			return String(payload_dict.get("error"))
	return String(payload)
