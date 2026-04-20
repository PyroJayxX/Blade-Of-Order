extends Button

# Signal to tell the main selector which level was clicked
signal tile_selected(level_id, tile_node)

@onready var boss_image = $BossImage
@onready var boss_name_label = $BossNameLabel
@onready var blur_overlay = $BlurOverlay

var level_id: int
var is_locked: bool = true
var boss_name: String

func setup(id: int, b_name: String, img: Texture2D, locked: bool, lock_img: Texture2D):
	level_id = id
	boss_name = b_name
	is_locked = locked
	
	if is_locked:
		boss_image.texture = lock_img
		boss_name_label.text = "???"
		disabled = true # Prevent clicking on locked levels
	else:
		boss_image.texture = img
		boss_name_label.text = boss_name
		disabled = false

# Connect the Button's built-in "pressed" signal to this function
func _on_pressed():
	if not is_locked:
		emit_signal("tile_selected", level_id, self)

# Called by the main manager to show/hide the hover text
func set_active_selection(is_selected: bool):
	if is_selected:
		boss_name_label.show()
		blur_overlay.show() # <--- Turn on the blur!
	else:
		boss_name_label.hide()
		blur_overlay.hide() # <--- Turn off the blur!
