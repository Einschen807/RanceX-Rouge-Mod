extends Button
class_name MapNodeButton
var point: Dictionary
var travelled := false
var current := false
var node_texture: Texture2D
var _hover := false
var circle_progress := 0.0
var _hint_clock := 0.0

func hint_scale() -> float:
	if disabled: return 1.0
	return 1.0 + 0.08 * (1.0 - cos(_hint_clock * TAU / 1.15))

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if disabled:
		if _hint_clock == 0.0: return
		_hint_clock = 0.0
	else:
		_hint_clock = fmod(_hint_clock + delta, 1.15)
	queue_redraw()

func set_circle_progress(value: float) -> void:
	circle_progress = value
	queue_redraw()

func _ready() -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if point.type not in ["ancient", "boss"]:
		node_texture = load("res://assets/map/%s.png" % point.type) as Texture2D
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not disabled else Control.CURSOR_ARROW
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	get_node("/root/UIAudio").bind_button(self)

func _draw() -> void:
	var center := size * 0.5
	var radius := 44.0 if point.type in ["ancient", "boss"] else 34.0
	var available := not disabled
	if current and not available:
		draw_circle(center, radius + 8.0, Color(1.0, 0.84, 0.35, 0.20))
		draw_arc(center, radius + 7.0, 0.0, TAU, 64, Color("a25917"), 2.5, true)
	# Scale the artwork around its center, leaving the hit area and route anchors fixed.
	draw_set_transform(center, 0.0, Vector2.ONE * hint_scale())
	if point.type in ["ancient", "boss"]:
		draw_circle(Vector2.ZERO, radius, Color(0.22, 0.15, 0.09, 0.06))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color("5c4128"), 4.0, true)
	else:
		var tint := Color.WHITE if available or travelled else Color(0.80, 0.76, 0.67, 0.75)
		if available and (_hover or has_focus()): tint = Color(1.12, 1.12, 1.12)
		draw_texture_rect(node_texture, Rect2(Vector2(-43, -43), Vector2(86, 86)), false, tint)
	draw_set_transform(Vector2.ZERO)
	if travelled:
		draw_arc(center, radius + 4.0, -0.35, TAU - 0.60, 48, Color("a52d21"), 3.0, true)
	if circle_progress > 0:
		var stroke := PackedVector2Array()
		var segments := maxi(2, ceili(72 * circle_progress))
		for i: int in range(segments + 1):
			var angle := -0.35 + (TAU + 0.16) * circle_progress * float(i) / segments
			var ring_radius := radius + 12.0 + 1.7 * sin(angle * 3.0 + 0.4)
			stroke.append(center + Vector2(cos(angle), sin(angle)) * ring_radius)
		draw_polyline(stroke, Color("a52d21"), 4.0, true)
