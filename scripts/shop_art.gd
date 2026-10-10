extends RefCounted
class_name ShopArt

static func picture(parent: Node, asset: String, at: Vector2, dimensions: Vector2) -> TextureRect:
	var texture := TextureRect.new()
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.texture = load("res://assets/shop/%s.png" % asset)
	texture.position = at
	texture.size = dimensions
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(texture)
	return texture

static func shell(parent: Node, at: Vector2, dimensions: Vector2) -> TextureRect:
	var texture := picture(parent, "shell", at, dimensions)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture.texture
	atlas.region = texture.texture.get_image().get_used_rect()
	texture.texture = atlas
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return texture

static func money(parent: Node, at: Vector2) -> Label:
	var frame := TextureRect.new()
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.texture = preload("res://assets/settings/item_decor.png")
	frame.position = at
	frame.size = Vector2(280, 76)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	shell(parent, at + Vector2(52, 18), Vector2(36, 40))
	return BattleArt.label(parent, "", at + Vector2(100, 10), Vector2(126, 56), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
