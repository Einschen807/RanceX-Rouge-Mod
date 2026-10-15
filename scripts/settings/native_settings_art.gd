extends RefCounted
class_name NativeSettingsArt
const ROOT := "res://assets/settings/native"

static func meter_handle(state: String) -> ImageTexture:
	# Preserve the original FLAT handle's frame and inset fill at their native positions.
	var frame: Texture2D = load(ROOT + "/volume_%s/atlas_0_1.png" % state)
	var fill: Texture2D = load(ROOT + "/volume_%s/atlas_0_0.png" % state)
	var bitmap := frame.get_image()
	bitmap.convert(Image.FORMAT_RGBA8)
	bitmap.blend_rect(fill.get_image(), Rect2i(Vector2i.ZERO, fill.get_size()), Vector2i(3, 3))
	return ImageTexture.create_from_image(bitmap)

static func picture(parent: Node, asset: String, at: Vector2, dimensions := Vector2.ZERO) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load("res://assets/settings/%s.png" % asset)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = at
	node.size = node.texture.get_size() if dimensions == Vector2.ZERO else dimensions
	parent.add_child(node)
	return node

static func flat(parent: Node, asset: String, at: Vector2) -> OriginalFlatPlayer:
	var node := OriginalFlatPlayer.new()
	node.animation_path = ROOT + "/%s/animation.json" % asset
	node.position = at
	parent.add_child(node)
	return node

static func button(parent: Node, caption: String, at: Vector2, callback: Callable) -> OriginalUiButton:
	var node := OriginalUiButton.make(parent, "menu_button", at, Vector2(400, 92), callback, "click", ROOT)
	BattleArt.label(node.content, caption, Vector2(12, 7), Vector2(376, 78), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	return node
