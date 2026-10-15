extends RefCounted
class_name FormationArt

const GOLD := Color(0.97, 0.84, 0.46)
static func picture(parent: Node, asset: String, at: Vector2, dimensions: Vector2) -> TextureRect:
	var node := TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture = load("res://assets/formation/%s.png" % asset)
	node.position = at
	node.size = dimensions
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func label(parent: Node, text: String, at: Vector2, dimensions: Vector2, font_size: int = 20, color: Color = Color.WHITE, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.size = dimensions
	node.horizontal_alignment = alignment
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color.BLACK)
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(node)
	return node

static func box(color: Color, border: Color = GOLD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style

static func button(parent: Node, text: String, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = at
	node.size = dimensions
	node.add_theme_font_size_override("font_size", 22)
	node.add_theme_color_override("font_color", GOLD)
	node.add_theme_stylebox_override("normal", box(Color(0.11, 0.10, 0.055, 0.94), Color(0.57, 0.43, 0.19)))
	node.add_theme_stylebox_override("hover", box(Color(0.33, 0.25, 0.08)))
	node.add_theme_stylebox_override("pressed", box(Color(0.45, 0.21, 0.08)))
	node.add_theme_stylebox_override("focus", box(Color(0.25, 0.33, 0.25, 0.35), Color(0.5, 0.9, 0.88)))
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(callback)
	parent.add_child(node)
	return node
