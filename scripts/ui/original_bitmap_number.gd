extends Control
class_name OriginalBitmapNumber
## Original digit sheets have ten equally sized cells; kerning mirrors Pact layouts.
var text := "0":
	set(value):
		text = value
		queue_redraw()
var atlas: Texture2D
var suffix: Texture2D
var asset := "digits_summary"
var kerning := -2.0
var alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT
var abbreviate := true
var fit_height := false

func _draw() -> void:
	if atlas == null:
		return
	var shown := text.replace(" ", "")
	if abbreviate and shown.is_valid_int() and shown.length() > 8:
		var value := int(shown)
		shown = str(value / 100000000) + "亿" if value >= 100000000 else str(value / 10000) + "万"
	var width := atlas.get_width() / 10.0
	var height := float(atlas.get_height())
	var length := shown.length() * (width + kerning) - kerning
	var fit := minf(1.0, size.x / maxf(1.0, length))
	if fit_height: fit = minf(fit, size.y / maxf(1.0, height))
	var x := (size.x - length * fit) / 2.0 if alignment == HORIZONTAL_ALIGNMENT_CENTER else (size.x - length * fit if alignment == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)
	var y := (size.y - height * fit) / 2.0
	for glyph: String in shown:
		var rectangle := Rect2(Vector2(x, y), Vector2(width, height) * fit)
		if glyph.is_valid_int():
			draw_texture_rect_region(atlas, rectangle, Rect2(int(glyph) * width, 0, width, height))
		elif glyph in ["%", "张"] and suffix != null:
			draw_texture_rect(suffix, rectangle, false)
		elif glyph in ["万", "亿", "兆"]:
			var unit := load("res://assets/formation/%s_%s.png" % [asset, glyph]) as Texture2D
			draw_texture_rect(unit, rectangle, false)
		x += (width + kerning) * fit

static func make(parent: Node, tag: String, at: Vector2, dimensions: Vector2, mark: String = "", spacing: float = -2.0) -> OriginalBitmapNumber:
	var node := OriginalBitmapNumber.new()
	node.asset = tag
	node.atlas = load("res://assets/formation/%s.png" % tag)
	if not mark.is_empty():
		node.suffix = load("res://assets/formation/%s.png" % mark)
	node.position = at
	node.size = dimensions
	node.kerning = spacing
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
