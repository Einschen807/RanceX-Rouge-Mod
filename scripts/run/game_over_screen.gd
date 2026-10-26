extends CanvasLayer
class_name GameOverScreen
## Rance 10's game-over page: the original diamond backdrop, the ink-splash GAME OVER -RESULT-
## flat, result rows on 数字下地-style bars and the blinking HIT ANY KEY prompt.
## The run save is already deleted; any key or click (right-click included) returns to the title.
signal finished
const ROOT := "res://assets/gameover/"
## The original backdrop is a translucent gradient that fades to black at its right edge.
const BASE := Color.BLACK
const ROW_TOP := 330.0
const ROW_STEP := 112.0
## Rows slide in one by one once the splash settles; the prompt follows and only then accepts input.
const ROWS_AT := 1.6
const ROW_FADE := 0.25
var stats: Array = []
var _rows: Array[Control] = []
var _prompt: OriginalFlatPlayer
var _waiting := false
var _done := false

static func stats_of(session: Node) -> Array:
	var nodes := 0
	for layer: Array in session.visited: nodes += layer.size()
	return [["到达楼层", "第 %d 层" % (session.act + 1)], ["行军节点", "%d" % nodes], ["收集遗物", "%d 件" % session.troop.relics.size()], ["持有卡牌", "%d 张" % session.troop.available.size()]]

func _ready() -> void:
	layer = 900
	var root := Control.new()
	root.name = "GameOver"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_to_group("modal_overlay")
	add_child(root)
	var base := ColorRect.new()
	base.color = BASE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(base)
	_picture(root, "background", Vector2.ZERO, Vector2(1024, 1080))
	var splash := _flat(root, "game_over", Vector2(44, 240))
	splash.name = "GameOverFlat"
	for index: int in range(stats.size()): _rows.append(_row(root, stats[index], ROW_TOP + ROW_STEP * index))
	_prompt = _flat(root, "hit_any_key", Vector2(1460, 850))
	_prompt.name = "HitAnyKey"
	_prompt.modulate.a = 0.0
	var bgm := get_node("/root/BGM")
	bgm.play_music(load(ROOT + "game_over.ogg"), &"game_over", false)
	_reveal()

func _picture(parent: Control, name: String, at: Vector2, dimensions: Vector2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(ROOT + name + ".png")
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = at
	node.size = dimensions
	parent.add_child(node)
	return node

func _flat(parent: Control, name: String, at: Vector2) -> OriginalFlatPlayer:
	var player := OriginalFlatPlayer.new()
	player.animation_path = ROOT + "native/" + name + "/animation.json"
	player.position = at
	parent.add_child(player)
	return player

func _row(parent: Control, stat: Array, top: float) -> Control:
	var row := Control.new()
	row.position = Vector2(1076, top)
	row.size = Vector2(768, 79)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.modulate.a = 0.0
	parent.add_child(row)
	# Like the original 数字下地 bar (drawn for a lighter ground): a band that fades out at both
	# ends, with a thin highlight on top, recoloured to the backdrop's maroon.
	_band(row, Rect2(0, 2, 768, 77), Color(0.36, 0.08, 0.16, 0.6))
	_band(row, Rect2(0, 0, 768, 2), Color(0.95, 0.55, 0.68, 0.8))
	_label(row, stat[0], Vector2(70, 0), 30, Color(0.86, 0.62, 0.68), HORIZONTAL_ALIGNMENT_LEFT)
	_label(row, stat[1], Vector2(318, 0), 40, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	return row

func _band(parent: Control, rect: Rect2, color: Color) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.82, 1.0])
	gradient.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 1
	var band := TextureRect.new()
	band.texture = texture
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.position = rect.position
	band.size = rect.size
	parent.add_child(band)

func _label(parent: Control, text: String, at: Vector2, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(380, 79)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)

func _reveal() -> void:
	var tween := create_tween()
	tween.tween_interval(ROWS_AT)
	for row: Control in _rows:
		tween.tween_property(row, "modulate:a", 1.0, ROW_FADE)
		tween.parallel().tween_property(row, "position:x", row.position.x, ROW_FADE).from(row.position.x + 40.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_prompt, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func() -> void:
		_waiting = true
		# The original prompt blinks while waiting for a key.
		var blink := create_tween().set_loops()
		blink.tween_property(_prompt, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
		blink.tween_property(_prompt, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE))

func _input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if _done or not _waiting or get_node("/root/ScreenTransition").busy: return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]) or (event is InputEventJoypadButton and event.pressed)
	if not pressed: return
	_done = true
	get_node("/root/UIAudio").play("click")
	finished.emit()

func _exit_tree() -> void:
	# Leaving the page means the title is coming back: restore its music.
	var bgm := get_node_or_null("/root/BGM")
	if bgm != null and bgm.current_track == &"game_over": bgm.play_title()
