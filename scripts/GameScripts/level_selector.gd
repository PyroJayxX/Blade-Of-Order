extends Control

@onready var grid_container = $Overlay/GridContainer
@onready var play_button = $Overlay/PlayButton 
@onready var back_button = $Overlay/BackButton

const LEVEL_TILE_SCENE = preload("res://scenes/LevelSelect/level_tile.tscn")
const SPLASH_TEXTURE_BUBBLE = preload("res://assets/boss_splash/BubbleSort_Splash.png")
const SPLASH_TEXTURE_BUCKET = preload("res://assets/boss_splash/BucketSort_Splash.png")
const SPLASH_TEXTURE_HEAP = preload("res://assets/boss_splash/HeapSort_Splash.png")
const SPLASH_TEXTURE_SHELL = preload("res://assets/boss_splash/ShellSort_Splash.png")
const SPLASH_TEXTURE_SELECTION = preload("res://assets/boss_splash/SelectionSort_Splash.png")
const SPLASH_TEXTURE_RADIX = preload("res://assets/boss_splash/RadixSort_Splash.png")
const SPLASH_TEXTURE_LOCKED = preload("res://assets/boss_splash/Locked_Level.png")

var level_data: Array[Resource] = []
var currently_selected_level_id = -1
var currently_selected_tile = null
var _highest_unlocked_level: int = 1

func _ready() -> void:
	AudioController.play_button()
	var config: Node = get_node_or_null("/root/GameConfig")
	if config != null:
		level_data = config.call("get_level_definitions")
	play_button.disabled = true
	play_button.pressed.connect(_on_play_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	await _refresh_unlock_state()
	generate_level_grid()

func generate_level_grid():
	# Clear out any placeholder data in the editor
	for child in grid_container.get_children():
		child.queue_free()
		
	# Spawn exactly 6 tiles
	for i in range(level_data.size()):
		var data: Resource = level_data[i]
		var tile = LEVEL_TILE_SCENE.instantiate()
		grid_container.add_child(tile)
		
		var config: Node = get_node_or_null("/root/GameConfig")
		var data_id: int = int(data.get("level_id"))
		var data_name: String = String(data.get("display_name"))
		var data_scene_path: String = String(data.get("scene_path"))
		var is_locked: bool = (data_id > _highest_unlocked_level) or data_scene_path.is_empty()
		var splash_texture: Texture2D = SPLASH_TEXTURE_BUBBLE
		match data_id:
			1: splash_texture = SPLASH_TEXTURE_BUBBLE
			2: splash_texture = SPLASH_TEXTURE_SELECTION
			3: splash_texture = SPLASH_TEXTURE_SHELL
			4: splash_texture = SPLASH_TEXTURE_HEAP
			5: splash_texture = SPLASH_TEXTURE_BUCKET
			6: splash_texture = SPLASH_TEXTURE_RADIX
		tile.setup(data_id, data_name, splash_texture, is_locked, SPLASH_TEXTURE_LOCKED)
		tile.tile_selected.connect(_on_level_tile_selected)
		
		
func _on_level_tile_selected(level_id, tile_node):
	AudioController.play_button()
	if currently_selected_tile == tile_node:
		currently_selected_tile.set_active_selection(false) # Turn off visuals
		currently_selected_tile = null                      # Clear the selection
		currently_selected_level_id = -1                    # Reset the ID
		play_button.disabled = true                         # Turn off the play button
		return 
		
	if currently_selected_tile != null:
		currently_selected_tile.set_active_selection(false)
		
	currently_selected_tile = tile_node
	currently_selected_tile.set_active_selection(true)
	
	currently_selected_level_id = level_id
	play_button.disabled = false

func _on_play_button_pressed():
	AudioController.play_button()
	if currently_selected_level_id != -1:
		var flow: Node = get_node_or_null("/root/SceneFlow")
		if flow == null or not bool(flow.call("play_level", currently_selected_level_id)):
			print("Level not built yet!")

func _on_back_button_pressed() -> void:
	AudioController.play_button()
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("goto_main_menu")


func _refresh_unlock_state() -> void:
	_highest_unlocked_level = 1
	var player_data: Node = get_node_or_null("/root/PlayerData")
	if player_data == null:
		return

	var player_name: String = String(player_data.get("player_name")).strip_edges()
	if player_name.is_empty():
		return

	var db: SupabaseDatabase = _get_database()
	if db == null:
		return

	var query: SupabaseQuery = SupabaseQuery.new().from("leaderboard").select(PackedStringArray(["level", "score"]))
	query = query.eq("player_name", player_name).order("level", SupabaseQuery.Directions.Ascending).range(0, 99)

	var result: Dictionary = await _run_database_query(db, query)
	if not bool(result.get("success", false)):
		return

	var completed_levels: Dictionary = {}
	for row: Variant in _normalize_rows(result.get("payload")):
		if not (row is Dictionary):
			continue
		var level_id: int = int((row as Dictionary).get("level", 0))
		var score: int = int((row as Dictionary).get("score", 0))
		if level_id > 0 and score > 0:
			completed_levels[level_id] = true

	while completed_levels.has(_highest_unlocked_level):
		_highest_unlocked_level += 1


func _get_database() -> SupabaseDatabase:
	if not has_node("/root/Supabase"):
		return null
	var supabase: Node = get_node_or_null("/root/Supabase")
	if supabase == null or not ("database" in supabase):
		return null
	return supabase.database as SupabaseDatabase


func _run_database_query(db: SupabaseDatabase, query: SupabaseQuery) -> Dictionary:
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
