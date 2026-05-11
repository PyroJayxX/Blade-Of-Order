extends Camera2D
class_name DynamicCamera

# Look-ahead configuration
@export var look_ahead_enabled: bool = true
@export var look_ahead_distance: float = 250.0  # How far ahead to look based on velocity
@export var look_ahead_factor: float = 0.6  # Multiplier for velocity influence (0-1)

# Dynamic zoom configuration
@export var dynamic_zoom_enabled: bool = true
@export var min_zoom: float = 0.35
@export var max_zoom: float = 0.5
@export var zoom_smoothing: float = 3.0  # How fast zoom changes

# Speed-based zoom
@export var base_zoom: float = 0.45  # Zoom when player is stationary
@export var max_player_speed: float = 3000.0  # Speed at which max zoom is reached
@export var zoom_speed_factor: float = 0.5  # How much speed affects zoom (0-1)

# hit effect/animation configs
@export_group("Hit Effects")
@export var default_shake_intensity: float = 4.0 # lower -> slight shake
@export var default_shake_duration: float = 0.2 # shake time
@export var red_flash_opacity: float = 1.0 # opacity, 1.0 since gradient value is handled in the inspector anw
@export var vignette_node: TextureRect

var player: CharacterBody2D = null
var camera_offset: Vector2 = Vector2.ZERO
var target_zoom: Vector2 = Vector2.ONE

# hit effect variables
var _current_shake_time: float = 0.0
var _current_shake_intensity: float = 0.0

func _ready() -> void:
	# Get reference to the player (parent node)
	player = get_parent() as CharacterBody2D
	
	if player == null:
		push_error("DynamicCamera must be a child of a CharacterBody2D (Player)")
		return
	
	# Initialize zoom
	target_zoom = zoom
	if not dynamic_zoom_enabled:
		target_zoom = Vector2(base_zoom, base_zoom)
		
	# vignette starts invisible
	if vignette_node != null:
		vignette_node.modulate.a = 0.0

func _process(delta: float) -> void:
	if player == null:
		return
	
	# Update camera position with look-ahead
	_update_look_ahead()
	
	# Update camera zoom based on player speed
	_update_dynamic_zoom(delta)
	
	# Smooth camera position
	_smooth_camera_movement(delta)
	
	# process camera shake
	_process_shake(delta)

# hit effect functions:

func apply_hit_effect(intensity: float = default_shake_intensity, duration: float = default_shake_duration) -> void:
	""" This function is called from player script when player takes damage"""
	_current_shake_intensity = intensity
	_current_shake_time = duration
	_flash_red()

func _process_shake(delta: float) -> void:
	""" The shake effect that applies slight camera offset. """
	if _current_shake_time > 0:
		_current_shake_time -= delta
		# generate random offset depending on intensity variable
		var random_x = randf_range(-1.0, 1.0) * _current_shake_intensity
		var random_y = randf_range(-1.0, 1.0) * _current_shake_intensity
		
		# apply to the camera's built-in offset property
		offset = Vector2(random_x, random_y)
	else:
		# reset offset when not shaking
		offset = Vector2.ZERO

# this is the funciton that plays the red overlay flashing
func _flash_red() -> void:
	if vignette_node == null:
		push_warning("Vignette node not assigned in DynamicCamera Inspector!")
		return
		
	# Use a Tween to smoothly fade the red color in, then out
	var tween = create_tween()
	
	# fade TO our target opacity quickly (0.05 seconds) using modulate:a
	tween.tween_property(vignette_node, "modulate:a", red_flash_opacity, 0.05).set_trans(Tween.TRANS_SINE)
	
	# Fade back to completely transparent (0.25 seconds)
	tween.tween_property(vignette_node, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_look_ahead() -> void:
	"""Calculate and apply look-ahead offset based on player velocity."""
	if not look_ahead_enabled or player == null:
		camera_offset = Vector2.ZERO
		return
	
	var player_velocity = player.velocity
	var velocity_magnitude = player_velocity.length()
	var normalized_velocity = player_velocity.normalized() if velocity_magnitude > 0 else Vector2.ZERO
	
	camera_offset = normalized_velocity * look_ahead_distance * look_ahead_factor

func _update_dynamic_zoom(delta: float) -> void:
	"""Update zoom based on player speed and screen size."""
	if not dynamic_zoom_enabled or player == null:
		return
	
	var player_velocity = player.velocity
	var velocity_magnitude = player_velocity.length()
	
	var speed_ratio = minf(velocity_magnitude / max_player_speed, 1.0)
	var speed_based_zoom = base_zoom + (max_zoom - base_zoom) * speed_ratio * zoom_speed_factor
	
	speed_based_zoom = clampf(speed_based_zoom, min_zoom, max_zoom)
	target_zoom = Vector2(speed_based_zoom, speed_based_zoom)
	
	zoom = zoom.lerp(target_zoom, zoom_smoothing * delta)

func _smooth_camera_movement(delta: float) -> void:
	"""Smoothly follow player position with look-ahead offset."""
	if player == null:
		return
	
	var target_position = player.global_position + camera_offset
	global_position = global_position.lerp(target_position, position_smoothing_speed * delta)

# Allow external control to toggle features
func set_look_ahead_enabled(enabled: bool) -> void:
	look_ahead_enabled = enabled

func set_dynamic_zoom_enabled(enabled: bool) -> void:
	dynamic_zoom_enabled = enabled

func get_look_ahead_offset() -> Vector2:
	"""Get current look-ahead offset for debugging or external use."""
	return camera_offset
