extends Control
class_name RelicChoiceScreen
## Pick one relic from a short list, presented as Rance 10 item cards.
signal completed
var troop: TroopState
var records: Array[Dictionary] = []
## Event choices must end with a relic; console use may back out with ui_cancel.
var mandatory := false
var cards: Array[RelicCard] = []
var _busy := true
var _closed := false

func _ready() -> void:
	name = "RelicChoice"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("modal_overlay")
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var heading := FormationArt.label(self, "选择一件遗物", Vector2(0, 150), Vector2(1920, 64), 46, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_constant_override("outline_size", 3)
	heading.add_theme_color_override("font_outline_color", Color.BLACK)
	var card_scale := 1.5 if records.size() <= 4 else 1.2
	var width := RelicCard.NATIVE.x * card_scale
	var gap := minf(56.0, (1800.0 - width * records.size()) / maxf(1, records.size() - 1))
	var left := 960.0 - (width * records.size() + gap * (records.size() - 1)) * 0.5
	for index: int in range(records.size()):
		var card := RelicCard.new()
		card.name = "Choice%d" % (index + 1)
		card.record = records[index]
		card.card_scale = card_scale
		card.position = Vector2(left + (width + gap) * index, 270)
		card.pressed.connect(_take.bind(index))
		add_child(card)
		get_node("/root/UIAudio").bind_button(card)
		cards.append(card)
	# Shade fades in while the cards rise into place one after another.
	shade.modulate.a = 0.0
	heading.modulate.a = 0.0
	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(shade, "modulate:a", 1.0, 0.15)
	entrance.tween_property(heading, "modulate:a", 1.0, 0.2).set_delay(0.05)
	for index: int in range(cards.size()):
		var card := cards[index]
		var rest := card.position.y
		card.position.y = rest + 140
		card.modulate.a = 0.0
		var delay := 0.08 + index * 0.06
		entrance.tween_property(card, "position:y", rest, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		entrance.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)
	entrance.chain().tween_callback(func() -> void: _busy = false)

func _take(index: int) -> void:
	if _busy or _closed: return
	_busy = true
	var chosen := cards[index]
	var at := chosen.global_position + chosen.size * 0.5
	var outro := create_tween().set_parallel(true)
	for card: RelicCard in cards:
		card.disabled = true
		if card != chosen: outro.tween_property(card, "modulate:a", 0.0, 0.18)
	outro.tween_property(chosen, "scale", Vector2.ONE * 1.12, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await outro.finished
	if troop.acquire_relic(records[index].name, at):
		var vanish := create_tween().set_parallel(true)
		vanish.tween_property(chosen, "modulate:a", 0.0, 0.2)
		vanish.tween_property(chosen, "scale", Vector2.ONE * 0.7, 0.2)
		await get_tree().create_timer(0.52).timeout
	_busy = false
	_close()

func _close() -> void:
	if _busy or _closed: return
	_closed = true
	completed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not mandatory and not _busy: _close()
	elif not cards.is_empty() and get_viewport().gui_get_focus_owner() == null and ["ui_left", "ui_right", "ui_up", "ui_down", "ui_focus_next"].any(func(action: String) -> bool: return event.is_action_pressed(action)):
		get_viewport().set_input_as_handled()
		cards[0].grab_focus()
