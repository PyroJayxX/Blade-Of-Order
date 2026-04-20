extends Node2D

@export var mute: bool = false

const MAIN_MENU_MUSIC_PATH: String = "res://audio/sfx/main menu music.mp3"
const BOSS_MUSIC_PATH: String = "res://audio/sfx/boss music.mp3"

@onready var _main_menu_music: AudioStreamPlayer = $main_menu_music
@onready var _boss_music: AudioStreamPlayer = $boss_music

# Called when the node enters the scene tree for the first time.
func _ready():
	_main_menu_music.stream = load(MAIN_MENU_MUSIC_PATH)
	_boss_music.stream = load(BOSS_MUSIC_PATH)
	if _main_menu_music.stream is AudioStreamMP3:
		(_main_menu_music.stream as AudioStreamMP3).loop = true
	if _boss_music.stream is AudioStreamMP3:
		(_boss_music.stream as AudioStreamMP3).loop = true
	_main_menu_music.stream_paused = false
	_boss_music.stream_paused = false
	if not mute:
		play_main_menu_music()

func play_main_menu_music():
	if mute:
		return
	if _boss_music.playing:
		_boss_music.stop()
	_boss_music.stream_paused = false
	if _main_menu_music.playing:
		_main_menu_music.stop()
	_main_menu_music.stream_paused = false
	_main_menu_music.volume_db = -12.0
	_main_menu_music.pitch_scale = 1.0
	_main_menu_music.play()

func play_button():
	if not mute:
		$main_menu_button_press.play()

func play_boss_music():
	if mute:
		return
	if _main_menu_music.playing:
		_main_menu_music.stop()
	_main_menu_music.stream_paused = false
	if _boss_music.playing:
		_boss_music.stop()
	_boss_music.stream_paused = false
	_boss_music.volume_db = -6.0
	_boss_music.pitch_scale = 1.0
	_boss_music.seek(0.0)
	_boss_music.play()

func play_boss_stunned():
	$boss_stunned.play()
	if not mute:
		_boss_music.stop()

func play_boss_hit_bubble():
	$boss_hit_bubble.play()

func play_player_slash_1():
	$player_slash_1.play()

func play_player_dash():
	$player_dash.play()

func play_player_run():
	$player_run.play()
