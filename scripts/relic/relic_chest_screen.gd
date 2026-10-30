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
var _rays: ColorRect
var _hint: Label
var _glow: Tween
## The native chest art is 308×279; 1.3× keeps it crisp (it used to be doubled and looked blurry).
const CHEST_SCALE := 1.3
## Screen point of the chest's native anchor; the closed art sits CLOSED_OFFSET (native pixels) from it.
const ANCHOR := Vector2(960, 640)
const FLAT_ANCHOR := Vector2(656, 575)
const CLOSED_OFFSET := Vector2(-154, -142.5)
const RAY_IDLE := 0.55
const RAY_HOVER := 0.8
const RAY_OPEN := 1.25

func _ready() -> void:
	name = "RelicChest"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("modal_overlay")
	_build_stage()
	_closed_art = TextureRect.new()
	_closed_art.texture = load("res://assets/treasure/native/chest_closed/atlas_0_1.png")
	_closed_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_closed_art.position = ANCHOR + CLOSED_OFFSET * CHEST_SCALE
	_closed_art.size = _closed_art.texture.get_size() * CHEST_SCALE
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
	_chest_button.mouse_entered.connect(func() -> void:
		material.set_shader_parameter("highlighted", true)
		_glow_to(RAY_HOVER))
	_chest_button.mouse_exited.connect(func() -> void:
		material.set_shader_parameter("highlighted", false)
		_glow_to(RAY_IDLE))
	add_child(_chest_button)
	_hint = _caption("点击打开宝箱", 26, Color("f3e3bd"))
	_hint.position = Vector2(560, ANCHOR.y + 210)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_hint, "modulate:a", 0.45, 1.1).from(1.0).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_hint, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
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

## Dark warm vignette, rotating light rays and rising motes behind the chest, a floor shadow
## under it and the heading on top.
func _build_stage() -> void:
	var back := TextureRect.new()
	var shade := Gradient.new()
	shade.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	shade.colors = PackedColorArray([Color("3a2716"), Color("150f0b"), Color("050404")])
	var radial := GradientTexture2D.new()
	radial.gradient = shade
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.55)
	radial.fill_to = Vector2(1.05, 0.55)
	back.texture = radial
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_rays = ColorRect.new()
	var rays := ShaderMaterial.new()
	rays.shader = preload("res://shaders/relic_chest_rays.gdshader")
	rays.set_shader_parameter("strength", RAY_IDLE)
	_rays.material = rays
	_rays.size = Vector2(1500, 940)
	_rays.position = ANCHOR - Vector2(750, 520)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rays)
	var motes := CPUParticles2D.new()
	motes.amount = 36
	motes.lifetime = 6.0
	motes.preprocess = 6.0
	motes.position = ANCHOR + Vector2(0, 140)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(420, 30)
	motes.direction = Vector2(0, -1)
	motes.spread = 12.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 30.0
	motes.initial_velocity_max = 80.0
	motes.scale_amount_min = 0.2
	motes.scale_amount_max = 0.6
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([Color(1, 0.85, 0.5, 0), Color(1, 0.85, 0.5, 0.8), Color(1, 0.8, 0.45, 0)])
	motes.color_ramp = fade
	var dot := GradientTexture2D.new()
	var soft := Gradient.new()
	soft.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	dot.gradient = soft
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 24
	dot.height = 24
	motes.texture = dot
	add_child(motes)
	var floor_shadow := TextureRect.new()
	var dark := Gradient.new()
	dark.colors = PackedColorArray([Color(0, 0, 0, 0.75), Color(0, 0, 0, 0)])
	var oval := GradientTexture2D.new()
	oval.gradient = dark
	oval.fill = GradientTexture2D.FILL_RADIAL
	oval.fill_from = Vector2(0.5, 0.5)
	oval.fill_to = Vector2(1.0, 0.5)
	floor_shadow.texture = oval
	floor_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor_shadow.size = Vector2(520, 90)
	floor_shadow.position = ANCHOR + Vector2(-260, 95)
	floor_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_shadow)
	var title := _caption("遗物宝箱", 54, FormationArt.GOLD)
	title.position = Vector2(560, 120)
	var rule := TextureRect.new()
	var line := Gradient.new()
	line.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	line.colors = PackedColorArray([Color(1, 0.8, 0.4, 0), Color(1, 0.8, 0.4, 0.8), Color(1, 0.8, 0.4, 0)])
	var bar := GradientTexture2D.new()
	bar.gradient = line
	bar.height = 2
	rule.texture = bar
	rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule.size = Vector2(520, 2)
	rule.position = Vector2(700, 196)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)

func _caption(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.size = Vector2(800, font_size + 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label

func _glow_to(strength: float, duration := 0.25) -> void:
	if _glow != null and _glow.is_running(): _glow.kill()
	_glow = create_tween()
	_glow.tween_property(_rays.material, "shader_parameter/strength", strength, duration)

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
	_opening.position = ANCHOR - FLAT_ANCHOR * CHEST_SCALE
	_opening.scale = Vector2.ONE * CHEST_SCALE
	_hint.text = "点击遗物获得"
	_glow_to(RAY_OPEN, 0.6)
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
