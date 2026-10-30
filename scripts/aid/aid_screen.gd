extends Control
class_name AidScreen
## Floor-entrance aid (Slay the Spire 2 ancient style): a drifting backdrop, the aid person
## standing on the left with a speech bubble coming from her face, three tiered choices on
## the right, then a 继续 bar.
signal completed
## Horizontal centre of the portrait.
const FIGURE_X := 500.0
## Where the bubble's tail points, as a fraction of the portrait (beside the face).
const MOUTH := Vector2(0.655, 0.27)
## The bubble spans SPEECH_LEFT..COLUMN end; choices use COLUMN, clear of the portrait.
const SPEECH_LEFT := 720.0
const COLUMN := Rect2(1000, 0, 840, 0)
## Speech bubble top; choices follow it down, ending above the troop HUD.
const SPEECH_Y := 220.0
## Space between the bubble and the first choice.
const SPEECH_GAP := 90.0
const SPEECH_MIN_WIDTH := 420.0
const BOTTOM := 872.0
const OPTION_STAGGER := 0.07
const OPTION_SLIDE := 56.0
const SPEECH_COLOR := Color("f4f1e8")
const BUBBLE_FILL := Color(0.06, 0.13, 0.16, 0.93)
const BUBBLE_EDGE := Color("6fa6b3")
## Half the width of the tail where it leaves the bubble.
const TAIL_BASE := 18.0
var session: Node
var person: Dictionary = {}
var options: Array[EventOptionButton] = []
## Backdrop and portrait are Node2D sprites: Controls snap to whole pixels, which makes the slow
## drift and breathing step visibly.
var _backdrop: Sprite2D
var _portrait: Sprite2D
var _chosen: Sprite2D
var _figure: Node2D
## Screen rect of the portrait at rest.
var _figure_rect: Rect2
var _speech: RichTextLabel
var _speech_bar: Control
var _bubble: Panel
var _tail: Polygon2D
var _tail_edge: Polygon2D
var _status: Label
var _return: EventOptionButton
var _preview: EventOptionPreview
var _busy := false
var _typing: Tween

func _ready() -> void:
	name = "AidScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var record: Dictionary = session.pending.aid
	person = AidCatalog.shared().persons.get(record.person, {})
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_build_backdrop()
	_build_figure()
	_build_shades()
	_build_name_plate()
	_build_speech()
	for index: int in range(record.options.size()):
		var option: Dictionary = record.options[index]
		var button := EventOptionButton.new()
		button.name = "Option%d" % (index + 1)
		button.description = option.text
		if not String(option.get("icon", "")).is_empty(): button.icon_texture = load(option.icon)
		button.disabled = not option.get("unavailable", "").is_empty()
		button.pressed.connect(_choose.bind(index))
		add_child(button)
		get_node("/root/UIAudio").bind_button(button)
		options.append(button)
	_status = Label.new()
	_status.name = "AidResult"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	_status.add_theme_font_size_override("font_size", 24)
	_status.add_theme_color_override("font_color", Color("d9e6dc"))
	EventOptionButton.add_shadow(_status)
	add_child(_status)
	_return = EventOptionButton.new()
	_return.name = "AidReturn"
	_return.description = "继续"
	_return.pressed.connect(back)
	add_child(_return)
	get_node("/root/UIAudio").bind_button(_return)
	var hud := RunTroopHUD.new()
	hud.session = session
	add_child(hud)
	_preview = EventOptionPreview.new()
	add_child(_preview)
	for index: int in range(options.size()):
		var button := options[index]
		var command := String(record.options[index].get("command", ""))
		for sig: Signal in [button.mouse_entered, button.focus_entered]: sig.connect(_preview.show_for.bind(button, command))
		for sig: Signal in [button.mouse_exited, button.focus_exited]: sig.connect(_preview.hide_for.bind(button))
	var resolved: bool = session.pending.get("aid_resolved", false)
	_return.visible = resolved
	if resolved:
		for button: EventOptionButton in options: button.hide()
		_status.text = session.pending.get("aid_result", "")
		_swap_portrait(false)
	_layout()
	_say(person.get("farewell", "") if resolved else person.get("line", ""))
	_enter_bars()

## The backdrop fills the screen and drifts slowly; warm dust motes float up in front of it.
func _build_backdrop() -> void:
	_backdrop = Sprite2D.new()
	_backdrop.name = "AidBackdrop"
	_backdrop.texture = load(person.get("background", ""))
	_backdrop.modulate = Color(0.72, 0.72, 0.76)
	add_child(_backdrop)
	var cover := maxf(1920.0 / _backdrop.texture.get_width(), 1080.0 / _backdrop.texture.get_height())
	var drift := create_tween().set_loops()
	drift.tween_property(_backdrop, "scale", Vector2.ONE * cover * 1.08, 14.0).from(Vector2.ONE * cover * 1.02).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.parallel().tween_property(_backdrop, "position", Vector2(934, 530), 14.0).from(Vector2(978, 546)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(_backdrop, "scale", Vector2.ONE * cover * 1.02, 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.parallel().tween_property(_backdrop, "position", Vector2(978, 546), 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var motes := CPUParticles2D.new()
	motes.name = "Motes"
	motes.amount = 46
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.position = Vector2(960, 1100)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(1000, 40)
	motes.direction = Vector2(0, -1)
	motes.spread = 18.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 40.0
	motes.initial_velocity_max = 95.0
	motes.scale_amount_min = 0.25
	motes.scale_amount_max = 0.8
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(1, 0.92, 0.7, 0), Color(1, 0.92, 0.7, 0.75), Color(1, 0.86, 0.6, 0.55), Color(1, 0.86, 0.6, 0)])
	motes.color_ramp = fade
	motes.texture = _soft_dot()
	add_child(motes)

func _soft_dot() -> Texture2D:
	var glow := Gradient.new()
	glow.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	glow.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var dot := GradientTexture2D.new()
	dot.gradient = glow
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 24
	dot.height = 24
	return dot

## The portrait stands at the bottom left and breathes; the chosen expression cross-fades in.
func _build_figure() -> void:
	_figure = Node2D.new()
	_figure.name = "AidFigure"
	add_child(_figure)
	var texture: Texture2D = load(person.get("portrait", ""))
	var dimensions := texture.get_size() * (1020.0 / texture.get_size().y)
	# The node sits at the feet so breathing scales from there.
	_figure.position = Vector2(FIGURE_X, 1080 + 40)
	_figure_rect = Rect2(_figure.position - Vector2(dimensions.x * 0.5, dimensions.y), dimensions)
	_portrait = _portrait_layer(texture, "Portrait")
	_chosen = _portrait_layer(load(person.get("chosen_portrait", "")), "ChosenPortrait")
	_chosen.modulate.a = 0.0
	var breath := create_tween().set_loops()
	breath.tween_property(_figure, "scale", Vector2(1.0, 1.012), 2.1).from(Vector2.ONE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(_figure, "scale", Vector2.ONE, 2.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _portrait_layer(texture: Texture2D, layer_name: String) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.name = layer_name
	layer.texture = texture
	layer.centered = false
	layer.scale = Vector2.ONE * (1020.0 / texture.get_height())
	layer.position = Vector2(-texture.get_width() * layer.scale.x * 0.5, -1020.0)
	_figure.add_child(layer)
	return layer

func _swap_portrait(animated := true) -> void:
	if not animated:
		_chosen.modulate.a = 1.0
		_portrait.modulate.a = 0.0
		return
	var swap := create_tween().set_parallel(true)
	swap.tween_property(_chosen, "modulate:a", 1.0, 0.35)
	swap.tween_property(_portrait, "modulate:a", 0.0, 0.35)

## Vignette, a dark lower band and a darker right side behind the speech and choices.
func _build_shades() -> void:
	var band := TextureRect.new()
	var fill := Gradient.new()
	fill.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	fill.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.04, 0.06, 0.55), Color(0.02, 0.04, 0.06, 0.88)])
	var gradient := GradientTexture2D.new()
	gradient.gradient = fill
	gradient.fill_from = Vector2(0, 0)
	gradient.fill_to = Vector2(0, 1)
	band.texture = gradient
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.position = Vector2(0, 640)
	band.size = Vector2(1920, 440)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var side := TextureRect.new()
	var across := Gradient.new()
	across.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	across.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.04, 0.06, 0.45), Color(0.02, 0.04, 0.06, 0.7)])
	var horizontal := GradientTexture2D.new()
	horizontal.gradient = across
	horizontal.fill_from = Vector2(0, 0)
	horizontal.fill_to = Vector2(1, 0)
	side.texture = horizontal
	side.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	side.position = Vector2(620, 0)
	side.size = Vector2(1300, 1080)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side)
	var vignette := TextureRect.new()
	var edge := Gradient.new()
	edge.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	edge.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.08), Color(0, 0, 0, 0.7)])
	var radial := GradientTexture2D.new()
	radial.gradient = edge
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.45)
	radial.fill_to = Vector2(1.08, 0.45)
	vignette.texture = radial
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

## Large faded name with the title below, bottom left as on the original ancient screen.
func _build_name_plate() -> void:
	var plate := Label.new()
	plate.name = "AidName"
	plate.text = person.get("name", "")
	plate.position = Vector2(110, 900)
	plate.size = Vector2(380, 80)
	plate.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	plate.add_theme_font_size_override("font_size", 62)
	plate.add_theme_color_override("font_color", Color(1, 1, 1, 0.62))
	EventOptionButton.add_shadow(plate)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	var title := Label.new()
	title.name = "AidTitle"
	title.text = person.get("title", "")
	title.position = Vector2(112, 978)
	title.size = Vector2(380, 34)
	title.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	EventOptionButton.add_shadow(title)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

## Speech bubble with a tail reaching back to the portrait's face.
func _build_speech() -> void:
	_speech_bar = Control.new()
	_speech_bar.name = "AidSpeech"
	_speech_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_speech_bar)
	# The tail outline sits behind the bubble; its fill on top covers the bubble border where they join.
	_tail_edge = Polygon2D.new()
	_tail_edge.color = BUBBLE_EDGE
	_speech_bar.add_child(_tail_edge)
	_bubble = Panel.new()
	_bubble.name = "Bubble"
	var style := StyleBoxFlat.new()
	style.bg_color = BUBBLE_FILL
	style.border_color = BUBBLE_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(24)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_bar.add_child(_bubble)
	_tail = Polygon2D.new()
	_tail.color = BUBBLE_FILL
	_speech_bar.add_child(_tail)
	_speech = RichTextLabel.new()
	_speech.name = "AidLine"
	_speech.fit_content = true
	_speech.scroll_active = false
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech.add_theme_font_override("normal_font", CardWidget.CARD_TEXT_FONT)
	_speech.add_theme_font_size_override("normal_font_size", 25)
	_speech.add_theme_color_override("default_color", SPEECH_COLOR)
	_speech.add_theme_constant_override("line_separation", 4)
	EventOptionButton.add_shadow(_speech)
	_bubble.add_child(_speech)

func _say(text: String) -> void:
	_speech.clear()
	EventOptionButton.append_marked(_speech, text)
	_layout()
	if _typing != null and _typing.is_running(): _typing.kill()
	var total := _speech.get_total_character_count()
	_speech.visible_characters = 0
	_typing = create_tween()
	_typing.tween_property(_speech, "visible_characters", total, clampf(total * 0.028, 0.2, 1.4))
	_typing.tween_callback(func() -> void: _speech.visible_characters = -1)

func _finish_typing() -> bool:
	if _typing == null or not _typing.is_running(): return false
	_typing.kill()
	_speech.visible_characters = -1
	return true

## Speech bubble, result and visible bars stack downwards from SPEECH_Y; the stack shifts up if needed.
func _layout() -> void:
	var width := COLUMN.size.x
	# The bubble hugs its longest line instead of always running to the column end.
	var longest := 0.0
	for line: String in _speech.get_parsed_text().split("\n"):
		longest = maxf(longest, CardWidget.CARD_TEXT_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x)
	var speech_width := clampf(longest + 64.0, SPEECH_MIN_WIDTH, COLUMN.end.x - SPEECH_LEFT)
	_speech.position = Vector2(28, 22)
	_speech.size = Vector2(speech_width - 56, 0)
	var speech_height := maxf(92.0, _speech.get_content_height() + 44.0)
	_bubble.size = Vector2(speech_width, speech_height)
	var items: Array = [[_speech_bar, speech_height, SPEECH_GAP]]
	if not _status.text.is_empty():
		_status.size = Vector2(width, 0)
		items.append([_status, CardWidget.CARD_TEXT_FONT.get_multiline_string_size(_status.text, HORIZONTAL_ALIGNMENT_CENTER, width, 24).y + 6, 12.0])
	for button: EventOptionButton in options + [_return]:
		if button.visible: items.append([button, button.fit_height(width, 24, 76), 10.0])
	var used := 0.0
	for item: Array in items: used += item[1] + item[2]
	used -= items[-1][2]
	var y := minf(SPEECH_Y, BOTTOM - used)
	for item: Array in items:
		var control: Control = item[0]
		var left := SPEECH_LEFT if control == _speech_bar else COLUMN.position.x
		control.position = Vector2(left, y)
		control.size = Vector2(speech_width if control == _speech_bar else COLUMN.end.x - left, item[1])
		y += item[1] + item[2]
	# The tail leaves the bubble's left edge level with the face (as far as the bubble allows).
	var tip := _figure_rect.position + _figure_rect.size * MOUTH - _speech_bar.position
	var base_y := clampf(tip.y, TAIL_BASE + 14.0, speech_height - TAIL_BASE - 14.0)
	_tail.polygon = PackedVector2Array([Vector2(3, base_y - TAIL_BASE), tip, Vector2(3, base_y + TAIL_BASE)])
	var out := (tip - Vector2(0, base_y)).normalized() * 3.5
	_tail_edge.polygon = PackedVector2Array([Vector2(0, base_y - TAIL_BASE - 2.5), tip + out, Vector2(0, base_y + TAIL_BASE + 2.5)])

func _enter_bars() -> void:
	var entering: Array[Control] = [_speech_bar]
	if not _status.text.is_empty(): entering.append(_status)
	for button: EventOptionButton in options + [_return]:
		if button.visible: entering.append(button)
	var entrance := create_tween().set_parallel(true)
	for index: int in range(entering.size()):
		var control := entering[index]
		var delay := 0.15 + index * OPTION_STAGGER
		control.modulate.a = 0.0
		entrance.tween_property(control, "modulate:a", 1.0, 0.2).set_delay(delay)
		if control is EventOptionButton:
			(control as EventOptionButton).shift = -OPTION_SLIDE
			entrance.tween_property(control, "shift", 0.0, 0.24).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _choose(index: int) -> void:
	if _busy or _blocked() or session.pending.get("aid_resolved", false): return
	_busy = true
	_preview.hide_all()
	var result: Dictionary = await session.choose_aid_option(index)
	if not is_inside_tree() or session.defeated: return
	_busy = false
	if result.ok or session.pending.get("aid_resolved", false): _show_result(result.message)
	else:
		_status.text = result.message
		_layout()

func _show_result(message: String) -> void:
	for button: EventOptionButton in options:
		button.disabled = true
		button.hide()
	_status.text = message
	_return.show()
	_swap_portrait()
	_say(person.get("farewell", ""))
	_enter_bars()

func _blocked() -> bool:
	var battle := get_node("/root/BattleManager")
	var overlay := get_tree().get_nodes_in_group("modal_overlay").any(func(node: Node) -> bool: return node != self)
	return get_node("/root/ScreenTransition").busy or is_instance_valid(battle.active) or is_instance_valid(battle._treasure) or is_instance_valid(battle._relic_chest) or is_instance_valid(get_node("/root/ShopManager").active) or overlay

func back() -> void:
	if _busy or _blocked() or session.pending.get("aid_executing", false): return
	if session.pending.get("aid_resolved", false): completed.emit()

func _focus_first() -> bool:
	if get_viewport().gui_get_focus_owner() != null: return false
	for button: EventOptionButton in options + [_return]:
		if button.visible and not button.disabled:
			button.grab_focus()
			return true
	return false

## Aid choices cannot be skipped: Back is swallowed, a click only completes the typing.
func _input(event: InputEvent) -> void:
	if _blocked(): return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
	elif ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"].any(func(action: String) -> bool: return event.is_action_pressed(action)) and _focus_first():
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _speech_bar.get_global_rect().has_point(event.position) and _finish_typing():
		get_viewport().set_input_as_handled()
