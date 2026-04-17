extends Node2D

@export var mute: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if not mute:
		play_main_menu_music()

func play_main_menu_music():
	if not mute:
		$main_menu_music.play()

func play_button():
	if not mute:
		$main_menu_button_press.play()

func play_boss_music():
	if not mute:
		$main_menu_music.stop()
		$boss_music.play()

func play_boss_stunned():
	$boss_stunned.play()
	if not mute:
		$boss_music.stop()

func play_boss_hit_bubble():
	$boss_hit_bubble.play()

func play_player_slash_1():
	$player_slash_1.play()

func play_player_dash():
	$player_dash.play()

func play_player_run():
	$player_run.play()
