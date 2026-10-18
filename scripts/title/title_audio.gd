extends Node
class_name TitleAudio
## Native SceneTitle schedules both assets 1000 ms after the title starts.
## The logo OGG already contains the complete sequence of entrance effects.

const CUE_FRAME: int = 30
const LOGO_STREAM: AudioStreamOggVorbis = preload("res://assets/audio/title_logo.ogg")

var logo_sfx: AudioStreamPlayer
var cue_started: bool = false
var intro_active: bool = false
var logo_play_count: int = 0
var cue_tick: int = -1
var _timeline: OriginalFlatPlayer

func _ready() -> void:
	logo_sfx = AudioStreamPlayer.new()
	logo_sfx.name = "LogoSfx"
	logo_sfx.bus = "SFX"
	logo_sfx.stream = LOGO_STREAM.duplicate() as AudioStreamOggVorbis
	(logo_sfx.stream as AudioStreamOggVorbis).loop = false
	add_child(logo_sfx)

func begin_intro(timeline: OriginalFlatPlayer) -> void:
	_timeline = timeline
	# Keep the original sound's pitch and duration while the visual intro runs faster.
	logo_sfx.pitch_scale = 1.0
	intro_active = true
	_timeline.frame_advanced.connect(_on_title_frame)

func _on_title_frame(tick: int) -> void:
	if not intro_active or cue_started or tick < CUE_FRAME:
		return
	cue_started = true
	cue_tick = tick
	_start_music()
	logo_sfx.play()
	logo_play_count += 1

func finish_intro(skipped: bool) -> void:
	intro_active = false
	if is_instance_valid(_timeline) and _timeline.frame_advanced.is_connected(_on_title_frame):
		_timeline.frame_advanced.disconnect(_on_title_frame)
	if skipped:
		# No delayed entrance SFX after the user has already reached the menu.
		logo_sfx.stop()
	_start_music()

func _start_music() -> void:
	BGM.play_title()

func debug_state() -> Dictionary:
	return {
		"cue_frame": cue_tick,
		"logo_play_count": logo_play_count,
		"music_play_count": BGM.play_count,
		"logo_playing": logo_sfx.playing,
		"music_playing": BGM.player.playing,
		"music_loop_offset_seconds": (BGM.player.stream as AudioStreamOggVorbis).loop_offset,
		"music_position_seconds": BGM.player.get_playback_position(),
		"intro_active": intro_active,
	}
