extends Button
class_name RelicCard
## A relic shown as an original Rance 10 item card: round portrait, parchment text, name strip.
const NATIVE := Vector2(208, 312)
## Dark rim around the white description text, as on original item cards.
const INK := Color("2e1a08")
## The glow hugs the rectangular body below the round portrait's transparent corners.
const GLOW_TOP := 40.0
var record: Dictionary
var card_scale := 1.5
## Item-card ground; curse cards swap in the 主人公 faction ground.
var back_path := "res://assets/relics/item_card/back.png"
var _visual: Control
var _glow: Panel
var _hover := 0.0
var _labels: Array[Label] = []

func _ready() -> void:
	size = NATIVE * card_scale
	custom_minimum_size = size
	pivot_offset = size * 0.5
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style: String in ["normal", "hover", "pressed", "disabled", "focus"]: add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_glow = Panel.new()
	var light := StyleBoxFlat.new()
	light.bg_color = Color(0, 0, 0, 0)
	light.shadow_color = Color(FormationArt.GOLD, 0.5)
	light.shadow_size = 22
	light.set_corner_radius_all(10)
	_glow.add_theme_stylebox_override("panel", light)
	_glow.position = Vector2(4, GLOW_TOP) * card_scale
	_glow.size = (NATIVE - Vector2(8, GLOW_TOP + 4)) * card_scale
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.modulate.a = 0.0
	add_child(_glow)
	_visual = Control.new()
	_visual.size = NATIVE
	_visual.scale = Vector2.ONE * card_scale
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)
	_picture(back_path, Vector2.ZERO, NATIVE)
	var portrait := "res://assets/cards/物品／%s.png" % record.icon
	if ResourceLoader.exists(portrait): _picture(portrait, Vector2.ZERO, NATIVE)
	else: _picture("res://assets/relics/%s.png" % record.icon, Vector2(24, 20), Vector2(160, 180))
	_picture("res://assets/relics/item_card/frame.png", Vector2.ZERO, NATIVE)
	# Text sits outside the scaled art so it renders crisply at the final size.
	var title := _text(record.name, Rect2(14, 272, 180, 28), 19, FormationArt.GOLD)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 3)
	var lines := PackedStringArray()
	for line: String in String(record.description).split("\n"): lines.append(line.strip_edges())
	# Original item cards: left-aligned white text with a dark rim on the parchment.
	var text := _text("\n".join(lines), Rect2(18, 204, 174, 64), 15.5, Color.WHITE)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_theme_color_override("font_outline_color", INK)
	text.add_theme_constant_override("outline_size", roundi(3.5 * card_scale))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Long saint names shrink rather than spill an extra wrapped line.
	var font_size := text.get_theme_font_size("font_size")
	var widest := func(at_size: int) -> float:
		var result := 0.0
		for line: String in lines: result = maxf(result, CardWidget.CARD_TEXT_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, at_size).x)
		return result
	while widest.call(font_size) > text.size.x - 4 and font_size > 14:
		font_size -= 1
		text.add_theme_font_size_override("font_size", font_size)
	# The mouse carries focus, so only the card under it lights up; keyboard focus still works.
	mouse_entered.connect(func() -> void:
		if not disabled: grab_focus())
	mouse_exited.connect(func() -> void:
		if has_focus(): release_focus())
	for sig: Signal in [focus_entered, focus_exited]: sig.connect(_hover_changed)

func _text(value: String, area: Rect2, font_size: float, colour: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = area.position * card_scale
	label.size = area.size * card_scale
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	label.add_theme_font_size_override("font_size", roundi(font_size * card_scale))
	label.add_theme_color_override("font_color", colour)
	label.add_theme_constant_override("line_spacing", 0)
	_visual.add_sibling(label)
	label.set_meta("rest_y", label.position.y)
	_labels.append(label)
	return label

func _picture(path: String, at: Vector2, dimensions: Vector2) -> void:
	var rect := TextureRect.new()
	rect.texture = load(path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.position = at
	rect.size = dimensions
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(rect)

## Hovered or focused cards lift slightly, grow and gain a gold rim light.
func _hover_changed() -> void:
	var lit := has_focus() and not disabled
	create_tween().tween_method(_set_hover, _hover, 1.0 if lit else 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_hover(value: float) -> void:
	_hover = value
	_visual.position.y = -14.0 * value
	for label: Label in _labels: label.position.y = label.get_meta("rest_y", label.position.y) - 14.0 * value
	_glow.position.y = GLOW_TOP * card_scale - 14.0 * value
	_glow.modulate.a = value
	scale = Vector2.ONE * (1.0 + 0.06 * value)
