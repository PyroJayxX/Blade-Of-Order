extends Control

# NOTE: Drag and drop your nodes here like we discussed if the paths are different!
@onready var grid_container = $Overlay/GridContainer
@onready var play_button = $Overlay/PlayButton 
@onready var back_button = $Overlay/BackButton

const LEVEL_TILE_SCENE = preload("res://scenes/LevelSelect/level_tile.tscn")
const LOCK_TEXTURE = preload("res://assets/boss_splash/Locked_Level.png") # Your lock image

var level_data: Array[Resource] = []
var currently_selected_level_id = -1
var currently_selected_tile = null

func _ready():
	AudioController.play_button()
	var config: Node = get_node_or_null("/root/GameConfig")
	if config != null:
		level_data = config.call("get_level_definitions")
	play_button.disabled = true
	play_button.pressed.connect(_on_play_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
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
		var data_image: Texture2D = data.get("preview_image") as Texture2D
		var unlocked: bool = false
		if config != null:
			unlocked = bool(config.call("is_level_unlocked", data_id))
		var is_locked: bool = (not unlocked) or data_scene_path.is_empty()
		
		tile.setup(data_id, data_name, data_image, is_locked, LOCK_TEXTURE)
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
