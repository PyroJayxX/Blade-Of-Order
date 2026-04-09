extends CharacterBody2D

const SPEED := 500.0
const JUMP_VELOCITY := -800.0

@onready var body_root: Node2D = $CharacterContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var facing_right := true

func _ready() -> void:
	_apply_facing(facing_right)
	animation_player.play("RESET")
	await get_tree().process_frame
	await get_tree().process_frame
	animation_player.play("Idle")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		velocity.x = direction * SPEED
		var wants_right := direction > 0.0
		if wants_right != facing_right:
			_apply_facing(wants_right)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()
	_update_animation(direction)

func _update_animation(direction: float) -> void:
	if absf(direction) > 0.01:
		if animation_player.current_animation != "Running":
			animation_player.play("Running", -1, 2.0)
	else:
		if animation_player.current_animation != "Idle":
			animation_player.play("Idle")

func _apply_facing(face_right: bool) -> void:
	facing_right = face_right
	body_root.scale.x = 1.0 if facing_right else -1.0
