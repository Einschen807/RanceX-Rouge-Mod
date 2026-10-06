extends OriginalBitmapNumber
class_name BattleHpReadout
## One native bitmap run keeps the value and parenthesized ratio adjacent.
var ratio_text := "(100%)":
	set(value):
		ratio_text = value
		queue_redraw()
var percent: Texture2D = preload("res://assets/battle/hp_percent.png")
var ratio_first := false
var preview_ratio := "":
	set(value):
		preview_ratio = value
		queue_redraw()
var preview_alpha := 1.0:
	set(value):
		preview_alpha = value
		queue_redraw()

func display_text() -> String:
	var ratio := ratio_text if preview_ratio.is_empty() else preview_ratio
	return ratio + text if ratio_first else text + ratio

func _advance(glyph: String) -> float:
	if glyph in ["(", ")"]: return 13.0
	if glyph == ".": return 9.0
	if glyph == "%": return 27.0
	return 24.0

func _draw() -> void:
	if atlas == null: return
	var shown := display_text()
	var length := 0.0
	for glyph: String in shown: length += _advance(glyph)
	var fit := minf(1.0, size.x / maxf(1, length))
	var x := size.x - length * fit if alignment == HORIZONTAL_ALIGNMENT_RIGHT else 0.0
	var height := 36.0 * fit
	var y := (size.y - height) / 2.0
	var index := 0
	var ratio_length := (ratio_text if preview_ratio.is_empty() else preview_ratio).length()
	for glyph: String in shown:
		var in_ratio := index < ratio_length if ratio_first else index >= text.length()
		var tint := Color(1, 1, 1, preview_alpha if in_ratio and not preview_ratio.is_empty() else 1.0)
		var advance := _advance(glyph)
		if glyph.is_valid_int():
			draw_texture_rect_region(atlas, Rect2(x, y, 26 * fit, height), Rect2(int(glyph) * 26, 0, 26, 36), tint)
		elif glyph == "%":
			draw_texture_rect_region(percent, Rect2(x, y + 5 * fit, 26 * fit, 27 * fit), Rect2(4, 20, 26, 26), tint)
		elif glyph in ["(", ")"]:
			# Half of the native zero supplies matching curved strokes and gradient.
			var left := 0 if glyph == "(" else 13
			draw_texture_rect_region(atlas, Rect2(x, y, 13 * fit, height), Rect2(left, 0, 13, 36), tint)
		elif glyph == ".":
			draw_circle(Vector2(x + 4 * fit, y + 29 * fit), 3 * fit, Color.BLACK)
			draw_circle(Vector2(x + 4 * fit, y + 28 * fit), 1.7 * fit, Color(0.95, 0.92, 0.76))
		x += advance * fit
		index += 1

static func make_readout(parent: Node, at: Vector2, dimensions: Vector2, align: HorizontalAlignment) -> BattleHpReadout:
	var node := BattleHpReadout.new()
	node.atlas = preload("res://assets/battle/hp_digits.png")
	node.abbreviate = false
	node.alignment = align
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = at
	node.size = dimensions
	return node
