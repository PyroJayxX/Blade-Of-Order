extends Node2D

@onready var hit_anim: AnimationPlayer = $HitFlash 

func play_hit_flash() -> void:
	if hit_anim != null and hit_anim.has_animation("hit_animation_head"):
		hit_anim.stop()
		hit_anim.play("hit_animation_head")
