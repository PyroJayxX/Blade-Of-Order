extends Control

# NOTE: Drag and drop your nodes here like we discussed if the paths are different!
@onready var grid_container = $Overlay/GridContainer
@onready var play_button = $Overlay/PlayButton 
@onready var back_button = $Overlay/BackButton

const LEVEL_TILE_SCENE = preload("res://scenes/LevelSelect/level_tile.tscn")
const LOCK_TEXTURE = preload("res://assets/boss_splash/Locked_Level.png") # Your lock image

# Load your cool new bubble boss splash art here!
const BOSS_1_IMAGE = preload("res://assets/boss_splash/BubbleSort_Splash.png")

var level_data = [
	{"id": 1, "name": "Bubble Sort", "image": BOSS_1_IMAGE},
	{"id": 2, "name": "???", "image": null},
	{"id": 3, "name": "???", "image": null},
	{"id": 4, "name": "???", "image": null},
	{"id": 5, "name": "???", "image": null},
	{"id": 6, "name": "???", "image": null}
]
# Set to 1 so ONLY the first boss is unlocked
var highest_unlocked_level = 1 
var currently_selected_level_id = -1
var currently_selected_tile = null

func _ready():
	AudioController.play_button()
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
		var data = level_data[i]
		var tile = LEVEL_TILE_SCENE.instantiate()
		grid_container.add_child(tile)
		
		# If the ID is greater than 1, it gets locked
		var is_locked = data.id > highest_unlocked_level
		
		tile.setup(data.id, data.name, data.image, is_locked, LOCK_TEXTURE)
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
		print("Starting level: ", currently_selected_level_id)
		
		# Check which level is selected and load the correct scene
		match currently_selected_level_id:
			1:
				AudioController.play_boss_music()
				get_tree().change_scene_to_file("res://scenes/Game/game.tscn")
			_:
				print("Level not built yet!")

func _on_back_button_pressed() -> void:
	AudioController.play_button()
	get_tree().change_scene_to_file("res://scenes/MainMenu/main_menu.tscn")
