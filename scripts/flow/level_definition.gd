extends Resource
class_name LevelDefinition

@export var level_id: int = 1
@export var display_name: String = "New Level"
@export var preview_image: Texture2D
@export_file("*.tscn") var scene_path: String = ""
@export var unlock_level_required: int = 0
@export var boss_type: String = ""
@export var puzzle_type: String = ""
@export var timer_rules: String = ""
