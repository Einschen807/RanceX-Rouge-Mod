extends RefCounted
class_name BattleArt
const INFORMATION_PANEL_SCALE := Vector2(0.9, 0.9)

static func picture(parent: Node, asset: String, at: Vector2, dimensions: Vector2 = Vector2.ZERO) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load("res://assets/battle/%s.png" % asset)
	node.position = at
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.size = node.texture.get_size() if dimensions == Vector2.ZERO else dimensions
	return node

static func flat(parent: Node, asset: String, at: Vector2 = Vector2.ZERO) -> OriginalFlatPlayer:
	var node := OriginalFlatPlayer.new()
	node.animation_path = "res://assets/battle/native/%s/animation.json" % asset
	node.position = at
	parent.add_child(node)
	return node

static func button(parent: Node, kind: String, at: Vector2, dimensions: Vector2, callback: Callable) -> OriginalUiButton:
	return OriginalUiButton.make(parent, kind, at, dimensions, callback, "click", "res://assets/battle/native")

static func label(parent: Node, text: String, at: Vector2, dimensions: Vector2, font_size: int = 24, color: Color = Color.WHITE, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := FormationArt.label(parent, text, at, dimensions, font_size, color, alignment)
	node.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	node.add_theme_color_override("font_outline_color", Color.BLACK)
	node.add_theme_constant_override("outline_size", 6)
	node.add_theme_constant_override("shadow_offset_x", 0)
	node.add_theme_constant_override("shadow_offset_y", 0)
	node.clip_text = true
	node.size = dimensions
	return node

static func number(parent: Node, asset: String, at: Vector2, dimensions: Vector2, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT) -> OriginalBitmapNumber:
	var node := OriginalBitmapNumber.new()
	node.atlas = load("res://assets/battle/%s.png" % asset)
	node.position = at
	node.size = dimensions
	node.alignment = alignment
	node.abbreviate = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

static func panel_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/battle/monster_description.png")
	style.texture_margin_left = 22
	style.texture_margin_right = 22
	style.texture_margin_top = 65
	style.texture_margin_bottom = 22
	return style

static func text_button(parent: Node, text: String, at: Vector2, dimensions: Vector2, callback: Callable) -> OriginalUiButton:
	var button := OriginalUiButton.make(parent, "square", at, dimensions, callback)
	button.art.scale = dimensions / Vector2(86, 86)
	label(button.content, text, Vector2(4, 0), dimensions - Vector2(8, 0), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	return button
