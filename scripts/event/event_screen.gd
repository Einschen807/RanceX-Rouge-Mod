extends Control
class_name EventScreen
signal completed
var session: Node
var record: Dictionary = {}
var options: Array[EventOptionButton] = []
var _status: Label
var _return: Button
var _busy := false

func _ready() -> void:
	name = "EventScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Transparent event illustrations must not reveal the map's interactive footer.
	var backdrop := ColorRect.new()
	backdrop.color = Color("172029")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var background := TextureRect.new()
	background.name = "EventImage"
	background.texture = load(record.get("image", "")) if not record.get("image", "").is_empty() else load("res://assets/battle/backgrounds/云间天光.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.045, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var text_shade := ColorRect.new()
	text_shade.color = Color(0.015, 0.025, 0.035, 0.72)
	text_shade.position = Vector2(885, 135)
	text_shade.size = Vector2(920, 660)
	text_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text_shade)
	var scroll := ScrollContainer.new()
	scroll.name = "EventScroll"
	scroll.position = Vector2(925, 155)
	scroll.size = Vector2(840, 620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	scroll.add_child(content)
	var title := _label(record.get("title", "旅途片刻"), 40, Color("ebcf73"))
	title.name = "EventTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var body := _label(record.get("text", "这里没有符合当前条件的事件，部队继续前进。"), 28, Color("f2ecda"))
	body.name = "EventBody"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(body)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	content.add_child(spacer)
	for index: int in range(record.get("options", []).size()):
		var button := EventOptionButton.new()
		button.name = "Option%d" % (index + 1)
		button.description = record.options[index].text
		button.disabled = not record.options[index].get("unavailable", "").is_empty()
		button.pressed.connect(_choose.bind(index))
		content.add_child(button)
		get_node("/root/UIAudio").bind_button(button)
		options.append(button)
	_status = _label("", 24, Color("d4e4d8"))
	content.add_child(_status)
	_return = FormationArt.button(self, "继续行军", Vector2(1420, 805), Vector2(340, 62), back)
	_return.name = "EventReturn"
	_return.visible = record.is_empty() or session.pending.get("event_resolved", false)
	get_node("/root/UIAudio").bind_button(_return)
	var hud := RunTroopHUD.new()
	hud.session = session
	add_child(hud)
	if session.pending.get("event_resolved", false):
		show_result(session.pending.get("event_result", ""))
	var available: Array = options.filter(func(button: EventOptionButton) -> bool: return not button.disabled)
	if not available.is_empty() and not session.pending.get("event_resolved", false): _focus.call_deferred(available[0])
	elif _return.visible: _focus.call_deferred(_return)

func _focus(control: Control) -> void:
	if is_inside_tree() and is_instance_valid(control) and control.is_inside_tree(): control.grab_focus()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	return label

func _choose(index: int) -> void:
	if _busy or _blocked() or session.pending.get("event_resolved", false): return
	_busy = true
	var result: Dictionary = await session.choose_event_option(index)
	if not is_inside_tree(): return
	_busy = false
	if result.ok or session.pending.get("event_resolved", false): show_result(result.message)
	else: _status.text = result.message

func show_result(message: String) -> void:
	for button: EventOptionButton in options: button.disabled = true
	_status.text = message
	_return.text = "继续行军"
	_return.show()
	(get_node("EventScroll") as ScrollContainer).ensure_control_visible.call_deferred(_status)
	_focus.call_deferred(_return)

func _blocked() -> bool:
	var battle := get_node("/root/BattleManager")
	var overlay := get_tree().get_nodes_in_group("modal_overlay").any(func(node: Node) -> bool: return node != self)
	return get_node("/root/ScreenTransition").busy or is_instance_valid(battle.active) or is_instance_valid(battle._treasure) or is_instance_valid(battle._relic_chest) or is_instance_valid(get_node("/root/ShopManager").active) or overlay

func back() -> void:
	if _busy or _blocked() or session.pending.get("event_executing", false): return
	if record.is_empty() or session.pending.get("event_resolved", false): completed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _blocked():
		get_viewport().set_input_as_handled()
