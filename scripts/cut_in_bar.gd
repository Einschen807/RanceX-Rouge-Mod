extends Control
class_name CutInBar
## Shared upper-left cut-in. Character scenes only supply portrait, voice and palette.
@export var portrait: Texture2D
@export var portrait_black_matte := false
@export var voice: AudioStream
@export var accent := Color("40c99c")
@export var frame_extent := Vector2(1180, 378)
@export var portrait_position := Vector2(-425, -100)
@export_range(200.0, 2600.0, 1.0) var portrait_width := 1470.0
@export_range(-24.0, 6.0) var voice_volume_db := -1.0
@export var reveal := 0.0
@export var travel := -1.0
@export var portrait_push := 0.0
@export var flash := 0.0
@export var wipe := 0.0
@export var slash_progress := 0.0
@export var slash_strength := 0.0
var clock := 0.0
var _voice_started := false
var _voice_hold := false
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var voice_player: AudioStreamPlayer = $Voice
@onready var drawer: ColorRect = $Drawer
var _material: ShaderMaterial

func _ready() -> void:
	_material = drawer.material.duplicate() as ShaderMaterial
	drawer.material = _material
	_material.set_shader_parameter("portrait_texture", portrait)
	_material.set_shader_parameter("portrait_enabled", portrait != null)
	_material.set_shader_parameter("portrait_black_matte", portrait_black_matte)
	voice_player.stream = voice
	voice_player.bus = &"Voice"
	voice_player.volume_db = voice_volume_db
	voice_player.finished.connect(_voice_finished)
	_sync_material()

func _process(delta: float) -> void:
	clock += delta * animation.speed_scale
	if _voice_hold and voice_player.playing:
		var voice_remaining := maxf(0.0, voice.get_length() - voice_player.get_playback_position())
		var exit_remaining := (animation.current_animation_length - animation.current_animation_position) / maxf(0.001, animation.speed_scale)
		if voice_remaining <= exit_remaining:
			_resume_exit()
	_sync_material()

func _sync_material() -> void:
	if _material == null: return
	_material.set_shader_parameter("accent", accent)
	var extent := Vector2(maxf(1.0, frame_extent.x), maxf(1.0, frame_extent.y))
	drawer.size = extent + Vector2(12, 12)
	_material.set_shader_parameter("frame_extent", extent)
	_material.set_shader_parameter("drawer_extent", drawer.size)
	var height := portrait_width * 0.56
	if portrait != null:
		height = portrait_width * float(portrait.get_height()) / float(portrait.get_width())
	_material.set_shader_parameter("portrait_rect", Vector4(portrait_position.x, portrait_position.y, portrait_width, height))
	_material.set_shader_parameter("reveal", reveal)
	_material.set_shader_parameter("travel", travel)
	_material.set_shader_parameter("portrait_push", portrait_push)
	_material.set_shader_parameter("flash", flash)
	_material.set_shader_parameter("wipe", wipe)
	_material.set_shader_parameter("slash_progress", slash_progress)
	_material.set_shader_parameter("slash_strength", slash_strength)
	_material.set_shader_parameter("clock", clock)

func start_voice() -> void:
	if voice == null or _voice_started: return
	_voice_started = true
	voice_player.play()

func hold_for_voice() -> void:
	# Resume in time for the exit wipe to overlap the end of the unpitched phrase.
	if voice_player.playing:
		_voice_hold = true
		animation.pause()

func _voice_finished() -> void:
	_resume_exit()

func _resume_exit() -> void:
	if _voice_hold:
		_voice_hold = false
		animation.play()
