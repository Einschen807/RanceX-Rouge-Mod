extends Node
## Autoloaded scene: the game's single, persistent BGM player.
## Scene scripts request tracks here; volume and mute affect the Music bus.

const TITLE_STREAM: AudioStreamOggVorbis = preload("res://assets/audio/title_music.ogg")
const TITLE_LOOP_OFFSET: float = 541227.0 / 44100.0

@onready var player: AudioStreamPlayer = $Player
var current_track: StringName = &""
var play_count: int = 0

func play_title() -> bool:
	return play_music(TITLE_STREAM, &"title", true, TITLE_LOOP_OFFSET)

func play_music(stream: AudioStream, track_id: StringName, loop: bool = true, loop_offset: float = 0.0, restart: bool = false) -> bool:
	assert(stream != null, "BGM stream must exist")
	# Requests from another scene for the same track preserve its playback.
	if not restart and current_track == track_id and player.stream != null and (player.playing or player.stream_paused):
		return false
	var owned_stream: AudioStream = stream.duplicate() as AudioStream
	if owned_stream is AudioStreamOggVorbis:
		(owned_stream as AudioStreamOggVorbis).loop = loop
		(owned_stream as AudioStreamOggVorbis).loop_offset = loop_offset
	elif owned_stream is AudioStreamMP3:
		(owned_stream as AudioStreamMP3).loop = loop
		(owned_stream as AudioStreamMP3).loop_offset = loop_offset
	player.stop()
	player.stream_paused = false
	player.stream = owned_stream
	current_track = track_id
	player.play()
	play_count += 1
	return true

func stop_music() -> void:
	player.stop()
	current_track = &""

func pause_music() -> void:
	player.stream_paused = true

func resume_music() -> void:
	player.stream_paused = false

func set_volume(linear_volume: float) -> void:
	var bus: int = AudioServer.get_bus_index("Music")
	assert(bus >= 0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(clampf(linear_volume, 0.0, 1.0), 0.0001)))

func get_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))

func set_muted(muted: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), muted)

func is_muted() -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))

func debug_state() -> Dictionary:
	return {
		"track": current_track,
		"playing": player.playing,
		"position_seconds": player.get_playback_position(),
		"play_count": play_count,
		"player_count": get_child_count(),
		"volume": get_volume(),
		"muted": is_muted(),
	}
