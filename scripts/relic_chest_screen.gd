extends Control
class_name RelicChestScreen
signal completed
var troop: TroopState
var record: Dictionary
var _busy := false
var _opened := false
var _closed := false
var _closed_art: TextureRect
var _chest_button: Button
var _reward: RelicIcon
var _tip: RelicTooltip
var _opening: OriginalFlatPlayer
var _animation_layer: CanvasLayer
var _reward_layer: CanvasLayer

func _ready() -> void:
	name = "RelicChest"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("modal_overlay")
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	_closed_art = TextureRect.new()
	_closed_art.texture = load("res://assets/treasure/native/chest_closed/atlas_0_1.png")
	_closed_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_closed_art.position = Vector2(652, 350)
	_closed_art.size = Vector2(616, 558)
	_closed_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_closed_art.self_modulate = Color(1.3, 1.3, 1.3)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/relic_chest_outline.gdshader")
	_closed_art.material = material
	add_child(_closed_art)
	_chest_button = Button.new()
	_chest_button.position = _closed_art.position
	_chest_button.size = _closed_art.size
	for style: String in ["normal", "hover", "pressed", "focus"]: _chest_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_chest_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_chest_button.pressed.connect(_open)
	_chest_button.mouse_entered.connect(func() -> void: material.set_shader_parameter("highlighted", true))
	_chest_button.mouse_exited.connect(func() -> void: material.set_shader_parameter("highlighted", false))
	add_child(_chest_button)
	# Native projected planes are top-level CanvasItems. Separate canvases keep
	# every chest plane below the reward and its description, including the lid.
	_animation_layer = CanvasLayer.new()
	_animation_layer.layer = 71
	add_child(_animation_layer)
	_reward_layer = CanvasLayer.new()
	_reward_layer.layer = 72
	add_child(_reward_layer)
	_tip = RelicTooltip.new()
	_tip.z_index = 20
	_reward_layer.add_child(_tip)
	_tip.hide()

func _open() -> void:
	if _busy or _opened or _closed: return
	_busy = true
	_chest_button.hide()
	_closed_art.hide()
	# The Rance native open animation includes its original lid and light effects.
	_opening = OriginalFlatPlayer.new()
	_opening.animation_path = "res://assets/treasure/native/chest_open/animation.json"
	_opening.project_tilt = true
	_opening.screen_filter_shader = OriginalFlatPlayer.ADD_SHADER
	var animation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_opening.animation_path))
	# The first native timeline is the large TREASURE heading; show only the chest.
	_opening.hidden_libraries.append(String(animation.timelines[0].library))
	_opening.position = Vector2(960, 635) - Vector2(656, 575) * 2.0
	_opening.scale = Vector2.ONE * 2.0
	_animation_layer.add_child(_opening)
	TreasureArt.sound(self, "chest_open")
	await get_tree().create_timer(1.35).timeout
	if _closed: return
	_opened = true
	_reward = RelicIcon.new()
	_reward.record = record
	_reward.position = Vector2(884, 385)
	_reward.size = Vector2(152, 152)
	_reward.z_index = 10
	_reward.modulate.a = 0.0
	_reward.pressed.connect(_take)
	_reward.mouse_entered.connect(func() -> void: _tip.show_record(record, Vector2(1060, 390)))
	_reward.mouse_exited.connect(_tip.hide)
	_reward_layer.add_child(_reward)
	_reward.flash()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_reward, "position:y", 315.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_reward, "modulate:a", 1.0, 0.3)
	await tween.finished
	_busy = false

func _take() -> void:
	if _busy or _closed or not _opened: return
	_busy = true
	_tip.hide()
	var acquired := troop.acquire_relic(record.name, _reward.global_position + _reward.size * 0.5)
	if acquired:
		_reward.hide()
		await get_tree().create_timer(0.52).timeout
	_busy = false
	_close()

func _close() -> void:
	if _busy or _closed: return
	_closed = true
	completed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_busy = false
		_close()
