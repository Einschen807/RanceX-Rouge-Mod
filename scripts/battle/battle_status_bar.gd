extends Control
class_name BattleStatusBar
## Original 55x68 icons, 66px spacing, round badge, and icon-replacement FLAT.
signal detail_requested(side: String, id: int)
var view: BattleScene
var side := "enemy"
var entries: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sync()

func _process(_delta: float) -> void:
	for id: int in entries:
		var node: Control = entries[id]
		var effect := node.get_node_or_null("Application") as OriginalFlatPlayer
		if effect != null:
			effect.playback_speed = view.animation_speed()
			if effect.elapsed >= 31.0 / 30.0:
				effect.hide()
				effect.queue_free()
				node.get_node("Icon").show()

func icon_position(index: int) -> Vector2:
	return Vector2(1336 + index * 66 if side == "player" else 528 - index * 66, 564)

func sync() -> void:
	var group := view.battle.statuses(side)
	for id: int in entries.keys():
		if not group.has(id): _remove(id)
	var index := 0
	for id: int in group:
		if not entries.has(id): _create(id, icon_position(index))
		var node: Control = entries[id]
		var at := icon_position(index)
		if node.get_meta("move_target", node.position) != at:
			var previous: Tween = node.get_meta("move_tween") if node.has_meta("move_tween") else null
			if previous != null and previous.is_valid(): previous.kill()
			var tween := view._presentation._tween()
			tween.tween_property(node, "position", at, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			node.set_meta("move_tween", tween)
			node.set_meta("move_target", at)
		node.get_node("Round").text = str(group[id])
		index += 1

func _create(id: int, at: Vector2) -> void:
	var node := Control.new()
	node.name = "Status%d" % id
	node.position = at
	node.size = Vector2(55, 68)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	entries[id] = node
	var icon := BattleArt.picture(node, "status/" + BattleStatusEffects.effect_name(id), Vector2.ZERO)
	icon.name = "Icon"
	BattleArt.picture(node, "status/round_base", Vector2(42, 42)).z_index = 2
	var number := BattleArt.number(node, "status/round_digits", Vector2(47, 46), Vector2(15, 20), HORIZONTAL_ALIGNMENT_LEFT)
	number.name = "Round"
	number.kerning = 0
	number.z_index = 3
	var button := Button.new()
	button.name = "ClickArea"
	button.size = node.size
	button.focus_mode = Control.FOCUS_NONE
	for style: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	button.pressed.connect(func() -> void: detail_requested.emit(side, id))
	button.mouse_entered.connect(func() -> void: icon.self_modulate = Color(1.25, 1.25, 1.25))
	button.mouse_exited.connect(func() -> void: icon.self_modulate = Color.WHITE)
	node.add_child(button)

func on_status_event(event_side: String, id: int, event: String) -> void:
	if event_side != side: return
	sync()
	if event == "added" and entries.has(id):
		var node: Control = entries[id]
		var old := node.get_node_or_null("Application")
		if old != null:
			node.remove_child(old)
			old.queue_free()
		var effect := OriginalFlatPlayer.new()
		effect.name = "Application"
		effect.animation_path = "res://assets/battle/native/status_add/animation.json"
		effect.texture_overrides = {"シス／战斗／状态异常／黑暗.png": load("res://assets/battle/status/%s.png" % BattleStatusEffects.effect_name(id))}
		effect.playback_speed = view.animation_speed()
		node.get_node("Icon").hide()
		node.add_child(effect)
		view._presentation._sound("res://assets/audio/status_add.ogg")
	elif event in ["trigger", "blocked"]:
		focus(id)

func _remove(id: int) -> void:
	var node: Control = entries[id]
	entries.erase(id)
	node.name = "RemovedStatus%d" % id
	node.get_node("ClickArea").hide()
	if view._presentation == null:
		node.queue_free()
		return
	view._presentation.native("status_remove", node.position)
	var tween := view._presentation._tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.2)
	tween.tween_callback(node.queue_free)

func focus(id: int) -> void:
	if not entries.has(id): return
	var node: Control = entries[id]
	var picture := BattleArt.picture(self, "status/%s_focus" % BattleStatusEffects.effect_name(id), Vector2.ZERO)
	picture.name = "StatusFocus%d" % id
	picture.position = node.position + node.size / 2.0 - picture.size / 2.0
	picture.pivot_offset = picture.size / 2.0
	picture.scale = Vector2.ZERO
	picture.modulate.a = 0.0
	picture.z_index = 10
	var tween := view._presentation._tween().set_parallel(true)
	tween.tween_property(picture, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(picture, "modulate:a", 1.0, 0.2)
	tween.chain().tween_interval(0.4)
	tween.chain().tween_property(picture, "scale", Vector2.ZERO, 0.2)
	tween.parallel().tween_property(picture, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(picture.queue_free)
