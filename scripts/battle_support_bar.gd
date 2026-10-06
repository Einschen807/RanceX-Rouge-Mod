extends Control
class_name BattleSupportBar
signal detail_requested(side: String, uid: int)
var view: BattleScene
var side := "enemy"
var entries: Dictionary = {}
const DISPLAY_SCALE := 0.8

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sync()

func support_position(index: int) -> Vector2:
	return Vector2(1693 if side == "player" else 27, 436 - index * 53)

func sync() -> void:
	var group := BattleSupports.group(view.battle, side)
	var alive: Array[int] = []
	for entry: Dictionary in group: alive.append(entry.uid)
	for uid: int in entries.keys():
		if uid not in alive:
			var node: Control = entries[uid]
			entries.erase(uid)
			node.get_node("ClickArea").hide()
			view._presentation.native("support_%s_remove" % side, node.position).scale = Vector2.ONE * DISPLAY_SCALE
			var tween := view._presentation._tween()
			tween.tween_property(node, "modulate:a", 0.0, 0.2)
			tween.tween_callback(node.queue_free)
	for i: int in range(group.size()):
		var entry: Dictionary = group[i]
		var support := BattleSupports.definition(view.battle, entry)
		var old: Control = entries.get(entry.uid)
		if old != null and int(old.get_meta("definition", -1)) != int(entry.id):
			entries.erase(entry.uid)
			old.hide()
			old.queue_free()
		if not entries.has(entry.uid): _create(entry, support, support_position(i))
		var node: Control = entries[entry.uid]
		node.position = support_position(i) - node.pivot_offset * (1.0 - DISPLAY_SCALE)
		node.get_node("Round").text = str(entry.remaining)
		node.visible = not view.battle.information_hidden(side)

func _create(entry: Dictionary, support: Dictionary, at: Vector2) -> void:
	var node := Control.new()
	node.name = "Support%d" % entry.uid
	node.position = at
	node.size = Vector2(250, 66)
	node.pivot_offset = Vector2(250 if side == "player" else 0, 33)
	node.position -= node.pivot_offset * (1.0 - DISPLAY_SCALE)
	node.scale = Vector2.ONE * DISPLAY_SCALE
	node.set_meta("definition", entry.id)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	entries[entry.uid] = node
	var frame := BattleArt.flat(node, "support_%s_%s" % [side, "fixed" if support.erasable == 0 else "base"])
	frame.name = "Frame"
	var icon_at := Vector2(191, 0) if side == "player" else Vector2.ZERO
	BattleArt.picture(node, "support/" + support.icon, icon_at).name = "Icon"
	var title := BattleArt.label(node, support.name, Vector2(5 if side == "player" else 66, 16), Vector2(177, 32), 19, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT if side == "player" else HORIZONTAL_ALIGNMENT_LEFT)
	# Original Desc: regular face, size 19, white, 1px black outline, no bold.
	title.add_theme_font_override("font", preload("res://assets/fonts/card_text.ttf"))
	title.add_theme_constant_override("outline_size", 2)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.name = "Title"
	var round_at := Vector2(232 if side == "player" else 41, 40)
	var badge := BattleArt.picture(node, "support/round_base", round_at)
	badge.visible = support.rounds > 0
	var number := BattleArt.number(node, "status/round_digits", round_at + Vector2(6, 4), Vector2(20, 22))
	number.name = "Round"
	number.visible = support.rounds > 0
	var button := Button.new()
	button.name = "ClickArea"
	button.size = node.size
	button.focus_mode = Control.FOCUS_NONE
	for style: String in ["normal", "hover", "pressed", "focus"]: button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	button.pressed.connect(func() -> void: detail_requested.emit(side, entry.uid))
	button.mouse_entered.connect(_set_highlight.bind(node, true))
	button.mouse_exited.connect(_set_highlight.bind(node, false))
	node.add_child(button)
	get_node("/root/UIAudio").bind_button(button)

func _set_highlight(node: Control, highlighted: bool) -> void:
	var tint := Vector3.ONE * (64.0 / 255.0) if highlighted else Vector3.ZERO
	(node.get_node("Frame") as OriginalFlatPlayer).tint_add = tint
	# Apply the same original additive tint to the icon and round badge.
	for child: Node in node.get_children():
		if not child is TextureRect: continue
		if child.material == null:
			var material := ShaderMaterial.new()
			material.shader = OriginalFlatPlayer.MIX_SHADER
			child.material = material
		(child.material as ShaderMaterial).set_shader_parameter("add_color", tint)
	node.set_meta("highlighted", highlighted)

func activate(uid: int) -> void:
	if not entries.has(uid): return
	var node: Control = entries[uid]
	# Keep the outside edge fixed and raise the whole native row above its neighbours.
	node.z_index = 40
	var tween := view._presentation._tween()
	tween.tween_property(node, "scale", Vector2.ONE * DISPLAY_SCALE * 2.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.8)
	tween.tween_property(node, "scale", Vector2.ONE * DISPLAY_SCALE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(node): node.z_index = 0)

func on_support_event(event_side: String, uid: int, event: String) -> void:
	if event_side != side: return
	sync()
	if event == "added" and entries.has(uid):
		view._presentation.native("support_%s_add" % side, entries[uid].position).scale = Vector2.ONE * DISPLAY_SCALE
		view._presentation._sound("res://assets/audio/support_add.ogg")
	elif event == "removed": view._presentation._sound("res://assets/audio/support_remove.ogg")
