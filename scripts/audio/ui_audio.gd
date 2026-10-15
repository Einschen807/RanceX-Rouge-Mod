extends Node
## Original system sounds persist across menus, without interrupting BGM.
const STREAMS := {
	"cursor": preload("res://assets/audio/ui_cursor.ogg"),
	"click": preload("res://assets/audio/ui_click.ogg"),
	"cancel": preload("res://assets/audio/ui_cancel.ogg"),
	"map_circle": preload("res://assets/audio/map_circle.wav"),
}
var play_counts := {"cursor": 0, "click": 0, "cancel": 0, "map_circle": 0}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0

func _ready() -> void:
	for i: int in range(4):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_voices.append(player)

func play(cue: String = "click") -> void:
	if not STREAMS.has(cue):
		return
	var voice := _voices[_next_voice]
	for candidate: AudioStreamPlayer in _voices:
		if not candidate.playing:
			voice = candidate
			break
	_next_voice = (_voices.find(voice) + 1) % _voices.size()
	voice.stream = STREAMS[cue]
	voice.play()
	play_counts[cue] += 1

func _exit_tree() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
	_voices.clear()

func bind_button(button: BaseButton, cue: String = "click") -> void:
	if button.has_meta("ui_audio_bound"):
		return
	button.set_meta("ui_audio_bound", true)
	button.pressed.connect(play.bind(cue))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			play("cursor"))
	button.focus_entered.connect(func() -> void:
		if not button.disabled and not button.is_hovered():
			play("cursor"))
