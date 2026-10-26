extends Control
class_name EventScreen
## Slay the Spire 2 style event page: faded illustration on the left, story and choices on the right.
signal completed
const BODY_COLOR := Color("f4f1e8")
## Share of the story shown at once; the rest is typed out quickly.
const INSTANT_RATIO := 0.8
const OPTION_STAGGER := 0.055
const OPTION_SLIDE := 56.0
## Right-hand column; it ends above the troop HUD, so nothing ever needs scrolling.
const AREA := Rect2(900, 34, 780, 838)
## [title, story, choice font, choice min height, gap], largest first.
const TIERS := [[44, 27, 25, 78, 10], [40, 25, 23, 70, 8], [36, 23, 21, 62, 6], [32, 21, 19, 54, 4], [30, 19, 17, 46, 3], [28, 17, 15, 40, 2]]
var session: Node
var record: Dictionary = {}
var options: Array[EventOptionButton] = []
var _status: Label
var _return: EventOptionButton
var _title: Label
var _body: RichTextLabel
var _busy := false
var _reveal: Tween
var _entrance: Tween
var _preview: EventOptionPreview

func _ready() -> void:
	name = "EventScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Opaque backdrop: transparent illustrations must not reveal the map's interactive footer.
	var backdrop := TextureRect.new()
	var fill := Gradient.new()
	fill.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
	fill.colors = PackedColorArray([Color("0b1118"), Color("0d141c"), Color("1b2631")])
	var gradient := GradientTexture2D.new()
	gradient.gradient = fill
	gradient.fill_from = Vector2(0, 0)
	gradient.fill_to = Vector2(0, 1)
	backdrop.texture = gradient
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
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
	var fade := ShaderMaterial.new()
	fade.shader = preload("res://shaders/event_art_fade.gdshader")
	background.material = fade
	add_child(background)
	_title = _label(record.get("title", "旅途片刻"), 44, FormationArt.GOLD)
	_title.name = "EventTitle"
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_body = RichTextLabel.new()
	_body.name = "EventBody"
	_body.fit_content = true
	_body.scroll_active = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_font_override("normal_font", CardWidget.CARD_TEXT_FONT)
	_body.add_theme_color_override("default_color", BODY_COLOR)
	EventOptionButton.add_shadow(_body)
	_body.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	EventOptionButton.append_marked(_body, record.get("text", "这里没有符合当前条件的事件。"))
	_body.pop()
	add_child(_body)
	for index: int in range(record.get("options", []).size()):
		var button := EventOptionButton.new()
		button.name = "Option%d" % (index + 1)
		button.description = record.options[index].text
		button.disabled = not record.options[index].get("unavailable", "").is_empty()
		button.pressed.connect(_choose.bind(index))
		add_child(button)
		get_node("/root/UIAudio").bind_button(button)
		options.append(button)
	_status = _label("", 26, Color("d9e6dc"))
	_status.name = "EventStatus"
	# A wrapped label measured at zero width would claim one character per line.
	_status.size.x = AREA.size.x
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)
	_return = EventOptionButton.new()
	_return.name = "EventReturn"
	_return.description = "继续"
	_return.pressed.connect(back)
	add_child(_return)
	_return.visible = record.is_empty() or session.pending.get("event_resolved", false)
	get_node("/root/UIAudio").bind_button(_return)
	var hud := RunTroopHUD.new()
	hud.session = session
	add_child(hud)
	# Relics and curses named by a choice appear beside it on hover (disabled choices too).
	_preview = EventOptionPreview.new()
	add_child(_preview)
	for index: int in range(options.size()):
		var button := options[index]
		var command := String(record.options[index].get("command", ""))
		for sig: Signal in [button.mouse_entered, button.focus_entered]: sig.connect(_preview.show_for.bind(button, command))
		for sig: Signal in [button.mouse_exited, button.focus_exited]: sig.connect(_preview.hide_for.bind(button))
	if session.pending.get("event_resolved", false):
		for button: EventOptionButton in options:
			button.disabled = true
			button.hide()
		_status.text = session.pending.get("event_result", "")
	_layout()
	_play_reveal()

## Shrinks text in steps until title, story and every choice fit the column at once.
func _layout() -> void:
	var font: Font = CardWidget.CARD_TEXT_FONT
	var width := AREA.size.x
	var items: Array = []
	var gap := 0.0
	for tier: Array in TIERS:
		items.clear()
		gap = tier[4]
		_title.add_theme_font_size_override("font_size", tier[0])
		_body.add_theme_font_size_override("normal_font_size", tier[1])
		_body.add_theme_constant_override("line_separation", roundi(tier[1] * 0.28))
		_body.size = Vector2(width, 0)
		_status.add_theme_font_size_override("font_size", tier[1] - 1)
		items.append([_title, font.get_multiline_string_size(_title.text, HORIZONTAL_ALIGNMENT_CENTER, -1, tier[0]).y + 4, gap * 1.2])
		items.append([_body, _body.get_content_height(), gap * 2.4])
		for button: EventOptionButton in options + [_return]:
			if button.visible: items.append([button, button.fit_height(width, tier[2], tier[3]), gap])
		if not _status.text.is_empty():
			items.insert(2, [_status, font.get_multiline_string_size(_status.text, HORIZONTAL_ALIGNMENT_CENTER, width, tier[1] - 1).y + 4, gap * 1.6])
		var total := 0.0
		for item: Array in items: total += item[1] + item[2]
		total -= items[-1][2]
		if total <= AREA.size.y: break
	var used := 0.0
	for item: Array in items: used += item[1] + item[2]
	used -= items[-1][2]
	var y := AREA.position.y + maxf(0.0, (AREA.size.y - used) * 0.5)
	for item: Array in items:
		var control: Control = item[0]
		control.position = Vector2(AREA.position.x, y)
		# Width first: wrapped labels derive their minimum height from it.
		control.size.x = width
		control.size = Vector2(width, item[1])
		y += item[1] + item[2]

## Title fades in, about 80% of the story appears at once and the rest is typed.
func _play_reveal() -> void:
	_title.modulate.a = 0.0
	var total := _body.get_total_character_count()
	var typed := total - int(total * INSTANT_RATIO)
	_body.visible_characters = total - typed
	for button: EventOptionButton in _entering(): button.modulate.a = 0.0
	_reveal = create_tween()
	_reveal.tween_property(_title, "modulate:a", 1.0, 0.12)
	_reveal.parallel().tween_property(_body, "visible_characters", total, clampf(typed * 0.011, 0.08, 0.32))
	_reveal.tween_callback(_finish_reveal)

func _finish_reveal() -> void:
	if _reveal != null and _reveal.is_running(): _reveal.kill()
	_reveal = null
	_title.modulate.a = 1.0
	_body.visible_characters = -1
	_enter_options()

func _entering() -> Array[EventOptionButton]:
	var result: Array[EventOptionButton] = []
	for button: EventOptionButton in options + [_return]:
		if button.visible: result.append(button)
	return result

## Visible choices slide in from the left and fade in one after another.
func _enter_options() -> void:
	if _entrance != null and _entrance.is_running(): _entrance.kill()
	var entering := _entering()
	if is_instance_valid(_status) and not _status.text.is_empty():
		_status.modulate.a = 0.0
		entering.push_front(null)
	_entrance = create_tween().set_parallel(true)
	for index: int in range(entering.size()):
		var delay := index * OPTION_STAGGER
		if entering[index] == null:
			_entrance.tween_property(_status, "modulate:a", 1.0, 0.16).set_delay(delay)
			continue
		var button := entering[index]
		button.modulate.a = 0.0
		button.shift = -OPTION_SLIDE
		_entrance.tween_property(button, "modulate:a", 1.0, 0.18).set_delay(delay)
		_entrance.tween_property(button, "shift", 0.0, 0.22).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Nothing is focused on open, so no bar looks hovered; the first navigation key picks one.
func _focus_first() -> bool:
	if get_viewport().gui_get_focus_owner() != null: return false
	for button: EventOptionButton in options + [_return]:
		if button.visible and not button.disabled:
			button.grab_focus()
			return true
	return false

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	EventOptionButton.add_shadow(label)
	return label

func _choose(index: int) -> void:
	if _busy or _blocked() or session.pending.get("event_resolved", false): return
	_busy = true
	_preview.hide_all()
	var result: Dictionary = await session.choose_event_option(index)
	if not is_inside_tree() or session.defeated: return
	_busy = false
	if result.ok or session.pending.get("event_resolved", false): show_result(result.message)
	else:
		_status.text = result.message
		_layout()

func show_result(message: String) -> void:
	_preview.hide_all()
	for button: EventOptionButton in options:
		button.disabled = true
		button.hide()
	_status.text = message
	_return.show()
	_layout()
	if _reveal != null: _finish_reveal()
	else: _enter_options()

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
	elif not _blocked() and ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"].any(func(action: String) -> bool: return event.is_action_pressed(action)) and _focus_first():
		get_viewport().set_input_as_handled()
	# A click while the story is still typing completes it immediately.
	elif _reveal != null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _blocked():
		get_viewport().set_input_as_handled()
		_finish_reveal()
