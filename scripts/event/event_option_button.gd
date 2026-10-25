extends Button
class_name EventOptionButton
## Slay the Spire 2 style choice bar: gold first line, marked-up description below.
const FILL := Color("1f4049")
const FILL_HOVER := Color("2f5d68")
const EDGE := Color("4f8592")
const TEXT := Color("eef2ec")
const RED := Color("ff5a5a")
const BLUE := Color("8fd3ff")
const WAVE := Color("e2b8ff")
const GLOW := Color("6fd6ff")
## Hovered bars grow by this fraction around their centre.
const HOVER_GROW := 0.025
## 【】 gold keyword, 〔〕 red cost, 〈〉 blue number, 〖〗 rippling quote; brackets are not displayed.
const MARKS := {"【": ["】", FormationArt.GOLD], "〔": ["〕", RED], "〈": ["〉", BLUE], "〖": ["〗", WAVE]}
const WAVE_EFFECT := preload("res://scripts/event/event_wave_effect.gd")
var description := ""
## Horizontal draw offset used by the entrance slide; containers keep the real position.
var shift := 0.0:
	set(value):
		shift = value
		if is_instance_valid(_label):
			_label.offset_left = 38 + value
			_label.offset_right = -46 + value
		queue_redraw()
var _label: RichTextLabel
var _hover := 0.0
var _hover_tween: Tween

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_label = RichTextLabel.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_top = 9
	_label.offset_bottom = -9
	_label.fit_content = true
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("normal_font", CardWidget.CARD_TEXT_FONT)
	_label.add_theme_font_size_override("normal_font_size", 25)
	_label.add_theme_color_override("default_color", TEXT)
	_label.add_theme_constant_override("line_separation", 2)
	add_shadow(_label)
	add_child(_label)
	shift = shift
	var lines := description.split("\n", true, 1)
	_label.push_color(FormationArt.GOLD)
	_label.add_text(strip_marks(lines[0]))
	_label.pop()
	if lines.size() > 1:
		_label.add_text("\n")
		append_marked(_label, lines[1])
	resized.connect(func() -> void:
		pivot_offset = size * 0.5
		queue_redraw())
	# The mouse moves focus with it, so only one bar is ever lit; keyboard focus still works.
	mouse_entered.connect(func() -> void:
		if not disabled: grab_focus())
	mouse_exited.connect(func() -> void:
		if has_focus(): release_focus())
	for sig: Signal in [focus_entered, focus_exited, button_down, button_up]: sig.connect(_hover_changed)

## Outline and soft drop shadow shared by every event text (title, story, results, choices).
static func add_shadow(control: Control) -> void:
	control.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	control.add_theme_constant_override("outline_size", 3)
	control.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	control.add_theme_constant_override("shadow_offset_x", 2)
	control.add_theme_constant_override("shadow_offset_y", 2)
	control.add_theme_constant_override("shadow_outline_size", 3)

func _hover_changed() -> void:
	queue_redraw()
	var lit := has_focus() and not disabled
	if _hover_tween != null and _hover_tween.is_running(): _hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_method(_set_hover, _hover, 1.0 if lit else 0.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_hover(value: float) -> void:
	_hover = value
	scale = Vector2.ONE * (1.0 + HOVER_GROW * value)
	queue_redraw()

## Appends text to a RichTextLabel, colouring bracket-marked spans.
static func append_marked(label: RichTextLabel, text: String) -> void:
	var index := 0
	while index < text.length():
		var opener := ""
		var at := text.length()
		for mark: String in MARKS:
			var found := text.find(mark, index)
			if found >= 0 and found < at and text.find(MARKS[mark][0], found + 1) > found:
				at = found
				opener = mark
		label.add_text(text.substr(index, at - index))
		if opener.is_empty(): return
		var close := text.find(MARKS[opener][0], at + 1)
		label.push_color(MARKS[opener][1])
		if opener == "〖": label.push_customfx(WAVE_EFFECT.new(), {})
		label.add_text(text.substr(at + 1, close - at - 1))
		if opener == "〖": label.pop()
		label.pop()
		index = close + 1

static func strip_marks(text: String) -> String:
	for mark: String in MARKS: text = text.replace(mark, "").replace(MARKS[mark][0], "")
	return text

## Applies a text size and returns the bar height needed at this width.
func fit_height(width: float, font_size: int, min_height: float) -> float:
	_label.add_theme_font_size_override("normal_font_size", font_size)
	var pad := clampf(min_height * 0.24, 10, 18)
	_label.offset_top = pad * 0.5
	_label.offset_bottom = -pad * 0.5
	# The anchored label takes its width from the bar.
	size.x = width
	var needed := _label.get_content_height()
	return maxf(min_height, needed + pad)

func _draw() -> void:
	var highlighted := has_focus() and not disabled
	var tip := minf(30.0, size.y * 0.42)
	var cut := 12.0
	var x := shift
	var w := size.x
	# Left side keeps small corner cuts; the right side narrows to a shallow point.
	var points := PackedVector2Array([Vector2(x + cut, 0), Vector2(x + w - tip, 0), Vector2(x + w, size.y * 0.5), Vector2(x + w - tip, size.y), Vector2(x + cut, size.y), Vector2(x, size.y - cut), Vector2(x, cut)])
	draw_colored_polygon(points, FILL_HOVER if highlighted else FILL)
	# Faint inner sheen towards the right, as on the original bars.
	var sheen := PackedVector2Array([Vector2(x + w * 0.55, 0), Vector2(x + w - tip, 0), Vector2(x + w, size.y * 0.5), Vector2(x + w - tip, size.y), Vector2(x + w * 0.62, size.y)])
	draw_colored_polygon(sheen, Color(1, 1, 1, 0.035 if highlighted else 0.02))
	if disabled: draw_colored_polygon(points, Color(0, 0, 0, 0.35))
	points.append(points[0])
	# Blue rim light fades in with the hover scale.
	if _hover > 0.0:
		for ring: Array in [[11.0, 0.10], [7.0, 0.18], [4.0, 0.32]]:
			draw_polyline(points, Color(GLOW, ring[1] * _hover), ring[0], true)
	draw_polyline(points, EDGE.lerp(GLOW, _hover) if not disabled else EDGE, 2.0 + 0.5 * _hover, true)
