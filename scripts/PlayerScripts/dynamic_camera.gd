extends Camera2D
class_name DynamicCamera

# Look-ahead configuration
@export var look_ahead_enabled: bool = true
@export var look_ahead_distance: float = 250.0  # How far ahead to look based on velocity
@export var look_ahead_factor: float = 0.6  # Multiplier for velocity influence (0-1)

# Dynamic zoom configuration
@export var dynamic_zoom_enabled: bool = true
@export var min_zoom: float = 0.35
@export var max_zoom: float = 0.80
@export var zoom_smoothing: float = 4.0  # How fast zoom changes

# Speed-based zoom
@export var base_zoom: float = 0.45  # Zoom when player is stationary
@export var max_player_speed: float = 3000.0  # Speed at which max zoom is reached
@export var zoom_speed_factor: float = 0.5  # How much speed affects zoom (0-1)

var player: CharacterBody2D = null
var camera_offset: Vector2 = Vector2.ZERO
var target_zoom: Vector2 = Vector2.ONE

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

func _process(delta: float) -> void:
	if player == null:
		return
	
	# Update camera position with look-ahead
	_update_look_ahead()
	
	# Update camera zoom based on player speed
	_update_dynamic_zoom(delta)
	
	# Smooth camera position
	_smooth_camera_movement(delta)

func _update_look_ahead() -> void:
	"""Calculate and apply look-ahead offset based on player velocity."""
	if not look_ahead_enabled or player == null:
		camera_offset = Vector2.ZERO
		return
	
	# Get player velocity
	var player_velocity = player.velocity
	
	# Calculate look-ahead offset based on velocity direction
	# Normalize to avoid excessive look-ahead at extreme speeds
	var velocity_magnitude = player_velocity.length()
	var normalized_velocity = player_velocity.normalized() if velocity_magnitude > 0 else Vector2.ZERO
	
	# Apply look-ahead with smooth scaling
	camera_offset = normalized_velocity * look_ahead_distance * look_ahead_factor

func _update_dynamic_zoom(delta: float) -> void:
	"""Update zoom based on player speed and screen size."""
	if not dynamic_zoom_enabled or player == null:
		return
	
	var player_velocity = player.velocity
	var velocity_magnitude = player_velocity.length()
	
	# Calculate target zoom based on speed
	# Faster movement = slight zoom out to see more, slower = zoom in for detail
	var speed_ratio = minf(velocity_magnitude / max_player_speed, 1.0)
	var speed_based_zoom = base_zoom + (max_zoom - base_zoom) * speed_ratio * zoom_speed_factor
	
	# Clamp zoom to valid range
	speed_based_zoom = clampf(speed_based_zoom, min_zoom, max_zoom)
	target_zoom = Vector2(speed_based_zoom, speed_based_zoom)
	
	# Smoothly interpolate to target zoom
	zoom = zoom.lerp(target_zoom, zoom_smoothing * delta)

func _smooth_camera_movement(delta: float) -> void:
	"""Smoothly follow player position with look-ahead offset."""
	if player == null:
		return
	
	# Calculate target position: player position + look-ahead offset
	var target_position = player.global_position + camera_offset
	
	# Smooth transition to target position
	global_position = global_position.lerp(target_position, position_smoothing_speed * delta)

# Allow external control to toggle features
func set_look_ahead_enabled(enabled: bool) -> void:
	look_ahead_enabled = enabled

func set_dynamic_zoom_enabled(enabled: bool) -> void:
	dynamic_zoom_enabled = enabled

func get_look_ahead_offset() -> Vector2:
	"""Get current look-ahead offset for debugging or external use."""
	return camera_offset
