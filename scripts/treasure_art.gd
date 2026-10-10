extends RefCounted
class_name TreasureArt
const ROOT := "res://assets/treasure/"

static func picture(parent: Node, name: String, at: Vector2, dimensions: Vector2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(ROOT + name + ".png")
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = at
	node.size = dimensions
	parent.add_child(node)
	return node

static func flat(parent: Node, name: String, at := Vector2.ZERO, autoplay := true) -> OriginalFlatPlayer:
	var player := OriginalFlatPlayer.new()
	player.autoplay = autoplay
	player.project_tilt = true
	# The underlying battle already uses screen-reading materials. Keep treasure
	# glow self-contained so rotating sprite quads cannot expose that cached scene.
	player.screen_filter_shader = OriginalFlatPlayer.ADD_SHADER
	player.animation_path = ROOT + "native/" + name + "/animation.json"
	player.position = at
	parent.add_child(player)
	return player

static func present_flat(player: OriginalFlatPlayer, autoplay := true) -> void:
	# Paused projected planes still hold the transform from the small entry panel.
	# Reproject their first frame at the current panel size before making it visible.
	player._render_layer(player._root, 1.0, Vector3.ONE, player.tint_add, 0)
	player.show()
	player.autoplay = autoplay

static func backdrop(parent: Node) -> void:
	picture(parent, "background", Vector2.ZERO, Vector2(1920, 1080))
	flat(parent, "result_frame")

static func button(parent: Node, text: String, at: Vector2, callback: Callable) -> OriginalUiButton:
	var button := OriginalUiButton.make(parent, "formation", at, Vector2(194, 92), callback, "click", "res://assets/map/native")
	BattleArt.label(button.content, text, Vector2(8, 9), Vector2(178, 67), 27, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	return button

static func sound(parent: Node, cue: String) -> void:
	var audio := AudioStreamPlayer.new()
	audio.stream = load(ROOT + cue + ".ogg")
	audio.bus = &"SFX"
	audio.finished.connect(audio.queue_free)
	parent.add_child(audio)
	audio.play()
