extends Control
class_name MapThemeBanner
signal finished
var floor_number := 1
var map_theme := ""
var _tween: Tween
var _dismissed := false

func _ready() -> void:
	name = "MapThemeBanner"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	var bar := ColorRect.new()
	bar.name = "Bar"
	bar.color = Color(0.06, 0.045, 0.025, 0.64)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.offset_left = 0.0
	bar.offset_right = 0.0
	bar.offset_top = -110.0
	bar.offset_bottom = 110.0
	var floor_label := _label(bar, "第%d层" % floor_number, 34, Color("a7d3db"), 22.0, 65.0)
	floor_label.name = "Floor"
	var theme_label := _label(bar, map_theme, 84, Color("f0cf6b"), 66.0, 181.0)
	theme_label.name = "Theme"
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(1.65)
	_tween.tween_property(self, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(dismiss)

func _label(parent: Control, text: String, font_size: int, color: Color, top: float, bottom: float) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.anchor_right = 1.0
	label.offset_top = top
	label.offset_bottom = bottom
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	return label

func dismiss() -> void:
	if _dismissed: return
	_dismissed = true
	if is_instance_valid(_tween): _tween.kill()
	finished.emit()
	queue_free()
