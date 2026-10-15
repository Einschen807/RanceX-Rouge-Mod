extends CanvasLayer
class_name TroopRankUp
## Original Rance 10 troop rank-up FLAT and matching system sound.
signal completed
const ANIMATION := "res://assets/map/native/troop_rank_up/animation.json"
const SOUND: AudioStream = preload("res://assets/audio/troop_rank_up.ogg")
var player: OriginalFlatPlayer
var _audio: AudioStreamPlayer
var _finished := false

func _ready() -> void:
	layer = 80
	add_to_group("modal_overlay")
	var surface := Control.new()
	surface.name = "RankUpSurface"
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	player = OriginalFlatPlayer.new()
	player.animation_path = ANIMATION
	add_child(player)
	_audio = AudioStreamPlayer.new()
	_audio.stream = SOUND
	_audio.bus = &"SFX"
	add_child(_audio)
	_audio.play()
	_fit()
	get_viewport().size_changed.connect(_fit)

func _fit() -> void:
	var dimensions := get_viewport().get_visible_rect().size
	var factor := minf(dimensions.x / 1920.0, dimensions.y / 1080.0)
	player.scale = Vector2.ONE * factor
	player.position = (dimensions - Vector2(1920, 1080) * factor) * 0.5

func _process(_delta: float) -> void:
	if is_instance_valid(player) and player.is_root_finished(): _finish()

func _input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"): _finish()

func _finish() -> void:
	if _finished: return
	_finished = true
	_audio.stop()
	remove_from_group("modal_overlay")
	hide()
	completed.emit()
	queue_free()
