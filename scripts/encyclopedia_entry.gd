extends Button
class_name EncyclopediaEntry
## An encyclopedia entrance; emits normal Button.pressed for future collection pages.

@export var entry_id: StringName
@export var title_text: String
@export var description_text: String
@export_enum("cards", "relics", "potions") var illustration: String = "cards"

var visual: Control
var caption: Label
var held: bool = false
var pointer_inside: bool = false
var feedback_count: int = 0
var _tween: Tween

func _ready() -> void:
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	visual = Control.new()
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.size = Vector2(420, 570)
	visual.pivot_offset = visual.size * 0.5
	add_child(visual)
	var panel: TextureRect = _picture("res://assets/encyclopedia/panel.png", Vector2(7, 7), Vector2(406, 556))
	var interior: AtlasTexture = AtlasTexture.new()
	interior.atlas = panel.texture
	interior.region = Rect2(32, 70, 570, 935)
	panel.texture = interior
	_frame(Vector2.ZERO, visual.size)
	caption = _label(title_text, Vector2(20, 45), Vector2(380, 55), 34, Color(1.0, 0.86, 0.53))
	var rule: ColorRect = ColorRect.new()
	rule.position = Vector2(54, 120)
	rule.size = Vector2(312, 1)
	rule.color = Color(0.79, 0.63, 0.29, 0.45)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(rule)
	if illustration == "cards":
		# Rear cards sit lower and closer in, partly covered by the central card.
		_card(Vector2(75, 184), -0.23, "card_back_free_cities", "card_shizuka")
		_card(Vector2(213, 184), 0.23, "card_back_other", "card_sill")
		_card(Vector2(144, 159), 0.0, "card_back", "card_rance")
	elif illustration == "relics":
		_picture("res://assets/encyclopedia/chest.png", Vector2(54, 165), Vector2(312, 281))
	else:
		_picture("res://assets/encyclopedia/potion.png", Vector2(64, 168), Vector2(292, 292))
	_label(description_text, Vector2(20, 474), Vector2(380, 54), 28, Color(0.93, 0.90, 0.81))
	mouse_entered.connect(func() -> void: pointer_inside = true; _refresh())
	mouse_exited.connect(func() -> void: pointer_inside = false; _refresh())
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	button_down.connect(func() -> void: held = true; _refresh())
	button_up.connect(func() -> void: held = false; _refresh())
	pressed.connect(func() -> void: feedback_count += 1)

func _picture(path: String, at: Vector2, dimensions: Vector2) -> TextureRect:
	var image: TextureRect = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.texture = load(path) as Texture2D
	image.position = at
	image.size = dimensions
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(image)
	return image

func _frame(at: Vector2, dimensions: Vector2, parent: Control = null) -> NinePatchRect:
	var frame: NinePatchRect = NinePatchRect.new()
	frame.texture = preload("res://assets/title/settings_normal/atlas_0_2.png")
	frame.patch_margin_left = 17
	frame.patch_margin_right = 17
	frame.patch_margin_top = 17
	frame.patch_margin_bottom = 17
	frame.position = at
	frame.size = dimensions
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(visual if parent == null else parent).add_child(frame)
	return frame

func _card(at: Vector2, angle: float, background_asset: String, portrait_asset: String) -> void:
	var card: Control = Control.new()
	card.position = at
	card.size = Vector2(132, 216)
	card.pivot_offset = card.size * 0.5
	card.rotation = angle
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(card)
	var back: TextureRect = _picture("res://assets/encyclopedia/%s.png" % background_asset, Vector2(5, 5), Vector2(122, 206))
	back.reparent(card, false)
	var character: TextureRect = _picture("res://assets/encyclopedia/%s.png" % portrait_asset, Vector2(7, 6), Vector2(118, 202))
	character.reparent(card, false)
	_frame(Vector2.ZERO, card.size, card)

func _label(value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.02, 0.01, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	visual.add_child(label)
	return label

func _refresh() -> void:
	if visual == null:
		return
	if _tween != null and _tween.is_running():
		_tween.kill()
	var active: bool = pointer_inside or has_focus()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(visual, "scale", Vector2.ONE * (0.98 if held else (1.025 if active else 1.0)), 0.12)
	_tween.tween_property(visual, "position:y", 2.0 if held else (-6.0 if active else 0.0), 0.12)
	_tween.tween_property(visual, "modulate", Color(0.82, 0.82, 0.82) if held else (Color(1.16, 1.12, 1.02) if active else Color.WHITE), 0.12)
