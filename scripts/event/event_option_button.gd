extends Button
class_name EventOptionButton
var description := ""
var _label: RichTextLabel

func _ready() -> void:
	custom_minimum_size = Vector2(0, 96)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_label = RichTextLabel.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 32
	_label.offset_right = -32
	_label.offset_top = 12
	_label.offset_bottom = -12
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("normal_font", CardWidget.CARD_TEXT_FONT)
	_label.add_theme_font_size_override("normal_font_size", 26)
	_label.add_theme_color_override("default_color", Color("f2ecda"))
	add_child(_label)
	var lines := description.split("\n", true, 1)
	_label.push_color(Color("ebcf73"))
	_label.add_text(lines[0])
	_label.pop()
	if lines.size() > 1: _label.add_text("\n" + lines[1])
	resized.connect(_measure.call_deferred)
	for sig: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited, button_down, button_up]: sig.connect(queue_redraw)
	_measure.call_deferred()

func _measure() -> void:
	if not is_instance_valid(_label): return
	custom_minimum_size.y = maxf(96, _label.get_content_height() + 28)
	queue_redraw()

func _draw() -> void:
	var highlighted := (is_hovered() or has_focus()) and not disabled
	var inset := 22.0
	var points := PackedVector2Array([Vector2(inset, 0), Vector2(size.x - inset, 0), Vector2(size.x, size.y * 0.32), Vector2(size.x, size.y * 0.68), Vector2(size.x - inset, size.y), Vector2(inset, size.y), Vector2(0, size.y * 0.68), Vector2(0, size.y * 0.32)])
	draw_colored_polygon(points, Color("35565e") if highlighted else Color("203c45"))
	points.append(points[0])
	draw_polyline(points, Color("b2c9b6") if highlighted else Color("527d88"), 2.0, true)
	if disabled: draw_colored_polygon(points, Color(0, 0, 0, 0.24))
