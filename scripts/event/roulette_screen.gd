extends Control
class_name RouletteScreen
## 「赌场」 event roulette (`roulette 50|100|all`): the event page picks the stake, this screen
## picks red / black / green, spins a single-zero wheel and settles the bet. The dealer 葉月
## (Rance 01 portraits, Rance 03 voice) grins and mocks the player on a loss.
signal finished(message: String)
const ROOT := "res://assets/events/casino/"
## European single-zero order, clockwise from 0.
const ORDER := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const REDS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
## Total returned for a winning bet, stake included.
const PAYOUT := {"red": 2, "black": 2, "green": 20}
const COLOR_NAMES := {"red": "红", "black": "黑", "green": "绿"}
const SPIN_TIME := 6.4
const AREA := Rect2(1300, 120, 580, 760)
# Rance03Voice numbers of 叶月 with their exact lines.
const GREET := {15508: "您好，欢迎光临～"}
const SPIN_LINES := {15577: "嘿嘿。", 15549: "这样啊这样啊，呵呵呵……"}
const LOSE_LINES := {15566: "好嘞，多谢惠顾～", 15597: "好嘞，多谢惠顾！", 15588: "噗哈！"}
const WIN_LINES := {15627: "……………………啧。", 15525: "呜……可、可恶……混蛋兰斯……", 15520: "唔……", 15614: "…………呃？"}
const JACKPOT_LINES := {15639: "呀啊啊啊啊啊！？", 15509: "………………啊？"}
const TAUNTS := [
	"「噗噗～输光光啦♪r 这些贝壳，就由我收下了哦～」",
	"「哎呀哎呀，运气真差呢～r 要不要再来一局？嘻嘻嘻……」",
	"「就这点本事还想赢我？r 太天真啦～」",
	"「谢谢惠顾～r 〖庄家〗永远是赢家哦！」",
	"「呀哈哈，脸色好难看哦？r 输钱的表情，最下饭了呢～」",
]
const WIN_TEXT := "「啧……r 算、算你运气好啦。」"
const JACKPOT_TEXT := "「骗、骗人的吧！？r 居然押中了〈绿色〉……！」"
var troop: TroopState
var mode := "50"
var stake := 0
var wheel: RouletteWheel
var portrait: TextureRect
var voice: AudioStreamPlayer
var result_message := ""
var lost := false
var _body: RichTextLabel
var _options: Array[EventOptionButton] = []
var _continue: EventOptionButton
var _money: Label
var _bubble: PanelContainer
var _bubble_text: Label
var _bubble_tween: Tween
var _spinning := false
var _done := false

func _ready() -> void:
	name = "RouletteScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("modal_overlay")
	stake = troop.gold if mode == "all" else int(mode)
	var room := TextureRect.new()
	room.name = "Casino"
	room.texture = load(ROOT + "background.png")
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room.size = Vector2(1920, 1080)
	room.modulate = Color(0.5, 0.45, 0.42)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room)
	var column := ColorRect.new()
	column.name = "ColumnShade"
	column.position = Vector2(1260, 0)
	column.size = Vector2(660, 1080)
	column.color = Color(0.03, 0.04, 0.06, 0.78)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	portrait = TextureRect.new()
	portrait.name = "Hazuki"
	portrait.texture = load(ROOT + "hazuki.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size = Vector2(421, 1120) * 0.9
	portrait.position = Vector2(30, 1080 - portrait.size.y + 10)
	portrait.pivot_offset = Vector2(portrait.size.x * 0.5, portrait.size.y)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	wheel = RouletteWheel.new()
	wheel.name = "Wheel"
	wheel.position = Vector2(470, 160)
	wheel.size = Vector2(760, 760)
	add_child(wheel)
	var title := _label("轮盘赌", 44, FormationArt.GOLD)
	title.name = "RouletteTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = AREA.position
	title.size = Vector2(AREA.size.x, 60)
	add_child(title)
	_body = RichTextLabel.new()
	_body.name = "RouletteBody"
	_body.fit_content = true
	_body.scroll_active = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_font_override("normal_font", CardWidget.CARD_TEXT_FONT)
	_body.add_theme_font_size_override("normal_font_size", 26)
	_body.add_theme_color_override("default_color", EventScreen.BODY_COLOR)
	_body.add_theme_constant_override("line_separation", 7)
	EventOptionButton.add_shadow(_body)
	_body.position = AREA.position + Vector2(0, 84)
	_body.size = Vector2(AREA.size.x, 0)
	add_child(_body)
	_set_body("押注〈%d〉贝壳。rr「嘿嘿，押哪个颜色呢？r 红和黑翻〈2〉倍，r 绿色的话……可是〈20〉倍哦～」" % stake)
	var y := AREA.position.y + 400.0
	for color: String in ["red", "black", "green"]:
		var button := EventOptionButton.new()
		button.name = "Bet" + color.capitalize()
		var count := 18 if color != "green" else 1
		button.description = "押%s\n%d个格子，押中获得〈%d〉贝壳。" % [COLOR_NAMES[color], count, stake * PAYOUT[color]]
		button.position = Vector2(AREA.position.x, y)
		button.size = Vector2(AREA.size.x, 92)
		button.pressed.connect(bet.bind(color))
		add_child(button)
		get_node("/root/UIAudio").bind_button(button)
		_options.append(button)
		y += 108.0
	_continue = EventOptionButton.new()
	_continue.name = "RouletteContinue"
	_continue.description = "继续"
	_continue.position = Vector2(AREA.position.x, AREA.position.y + 600)
	_continue.size = Vector2(AREA.size.x, 78)
	_continue.pressed.connect(_finish)
	_continue.hide()
	add_child(_continue)
	get_node("/root/UIAudio").bind_button(_continue)
	_money = ShopArt.money(self, Vector2(1590, 18))
	_money.name = "Gold"
	_refresh_money()
	voice = AudioStreamPlayer.new()
	voice.bus = &"SFX"
	add_child(voice)
	_bubble = _make_bubble()
	add_child(_bubble)
	_speak.call_deferred(GREET)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	EventOptionButton.add_shadow(label)
	return label

func _set_body(text: String) -> void:
	_body.clear()
	_body.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	EventOptionButton.append_marked(_body, EventCatalog.display_text(text))
	_body.pop()

func _refresh_money() -> void:
	_money.text = str(troop.gold)

## Pays the stake and spins; the pocket is drawn first, the animation only shows it.
func bet(color: String) -> void:
	if _spinning or _done or troop.gold < stake or stake <= 0: return
	_spinning = true
	for button: EventOptionButton in _options: button.disabled = true
	troop.spend_gold(stake)
	_refresh_money()
	var pocket: int = get_node("/root/RunAutosave").rng.randi_range(0, ORDER.size() - 1)
	_set_body("押注〈%d〉贝壳在%s。rr「转起来喽～」" % [stake, COLOR_NAMES[color]])
	_speak(SPIN_LINES)
	wheel.spin(pocket, SPIN_TIME)
	await wheel.settled
	if not is_inside_tree(): return
	_settle(color, int(ORDER[pocket]))

func _settle(color: String, number: int) -> void:
	var landed := pocket_color(number)
	var won := landed == color
	var label := "%d号%s" % [number, COLOR_NAMES[landed]]
	if won:
		var payout: int = stake * PAYOUT[color]
		# Winnings are the table's money, not a reward: relic gold bonuses do not apply.
		troop.gold += payout
		troop.changed.emit()
		_play_sound("res://assets/audio/rest_obtain.ogg")
		_speak(JACKPOT_LINES if color == "green" else WIN_LINES)
		_set_body("开出〈%s〉！r获得〈%d〉贝壳。rr%s" % [label, payout, JACKPOT_TEXT if color == "green" else WIN_TEXT])
		result_message = "押%s%d贝壳，开出%s，获得%d贝壳。" % [COLOR_NAMES[color], stake, label, payout]
	else:
		_play_sound("res://assets/audio/ui_cancel.ogg")
		_laugh()
		_speak(LOSE_LINES)
		var taunt: String = TAUNTS.pick_random()
		_set_body("开出〈%s〉……r输掉了〔%d〕贝壳。rr%s" % [label, stake, taunt])
		lost = true
		# The event result is plain text: same taunt, marks removed.
		result_message = "押%s%d贝壳，开出%s，输掉了%d贝壳。\n\n叶月咧嘴大笑：\n%s" % [COLOR_NAMES[color], stake, label, stake, EventOptionButton.strip_marks(EventCatalog.display_text(taunt))]
	_refresh_money()
	for button: EventOptionButton in _options: button.hide()
	_continue.show()
	_spinning = false
	_done = true

static func pocket_color(number: int) -> String:
	if number == 0: return "green"
	return "red" if number in REDS else "black"

## The laughing portrait (shark grin) with a little hop.
func _laugh() -> void:
	portrait.texture = load(ROOT + "hazuki_laugh.png")
	var hop := create_tween()
	hop.tween_property(portrait, "scale", Vector2(1.03, 0.97), 0.08)
	hop.tween_property(portrait, "scale", Vector2(0.98, 1.03), 0.1)
	hop.tween_property(portrait, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _make_bubble() -> PanelContainer:
	var box := PanelContainer.new()
	box.name = "HazukiBubble"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.03, 0.08, 0.92)
	style.border_color = Color("ff86c8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_text = Label.new()
	_bubble_text.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	_bubble_text.add_theme_font_size_override("font_size", 26)
	_bubble_text.add_theme_color_override("font_color", Color("ffe0f0"))
	box.add_child(_bubble_text)
	box.modulate.a = 0.0
	box.hide()
	return box

func _speak(lines: Dictionary) -> void:
	var id: int = lines.keys().pick_random()
	voice.stream = load(ROOT + "voice/%d.ogg" % id)
	voice.play()
	_bubble_text.text = String(lines[id])
	_bubble.reset_size()
	_bubble.position = Vector2(clampf(portrait.position.x + portrait.size.x * 0.5 - _bubble.size.x * 0.5, 16, 900), 12)
	_bubble.show()
	if _bubble_tween != null: _bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, "modulate:a", 1.0, 0.12)
	_bubble_tween.tween_interval(2.4)
	_bubble_tween.tween_property(_bubble, "modulate:a", 0.0, 0.35)
	_bubble_tween.tween_callback(_bubble.hide)

func _play_sound(path: String) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _finish() -> void:
	if not _done: return
	remove_from_group("modal_overlay")
	finished.emit(result_message)

## The bet cannot be abandoned once the screen is open, like any event choice.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): get_viewport().set_input_as_handled()


## Single-zero wheel drawn in code. The ball orbits against the wheel, slows, drops
## inward with a few bounces and comes to rest in the pocket chosen before the spin.
class RouletteWheel extends Control:
	signal settled
	const POCKETS := 37
	const RED := Color("b5161f")
	const BLACK := Color("161414")
	const GREEN := Color("0f7d3c")
	const GOLD := Color("e7c25a")
	var angle := 0.0
	var ball_angle := -PI * 0.5
	var ball_radius := 0.0
	var ball_visible := false
	var winner := -1
	var _time := 0.0
	var _duration := 0.0
	var _pocket := 0
	var _wheel_start := 0.0
	var _wheel_turn := 0.0
	var _relative_start := 0.0
	var _relative_travel := 0.0
	var _land := 0.0
	var _last_tick := -1
	var _glow := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func radius() -> float:
		return minf(size.x, size.y) * 0.5 - 6.0

	func pocket_angle(index: int) -> float:
		return TAU * index / POCKETS

	func spin(pocket: int, duration: float) -> void:
		winner = -1
		_pocket = pocket
		_duration = duration
		_time = 0.0
		_land = duration * 0.78
		_wheel_start = angle
		_wheel_turn = TAU * 2.4
		# Ball angle is tracked relative to the wheel: it starts on the far side spinning
		# the other way and must end exactly over its pocket after many laps.
		_relative_start = (ball_angle - angle) if ball_visible else PI * 1.3
		var target := pocket_angle(pocket)
		var travel := wrapf(target - _relative_start, -TAU, 0.0) - TAU * 8.0
		_relative_travel = travel
		ball_visible = true
		_last_tick = -1

	func _process(delta: float) -> void:
		if _duration > 0.0:
			_time = minf(_time + delta, _duration)
			var t := _time / _duration
			angle = _wheel_start + _wheel_turn * (1.0 - pow(1.0 - t, 3.0))
			var lt := minf(_time / _land, 1.0)
			var relative := _relative_start + _relative_travel * (1.0 - pow(1.0 - lt, 2.6))
			ball_angle = angle + relative
			var r := radius()
			var track := r * 0.86
			var pocket_r := r * 0.6
			# Orbit on the outer track, then fall inward bouncing over the pocket frets.
			var fall := clampf((lt - 0.62) / 0.38, 0.0, 1.0)
			var bounce := absf(sin(fall * PI * 3.0)) * (1.0 - fall) * r * 0.07
			ball_radius = lerpf(track, pocket_r, smoothstep(0.0, 1.0, fall)) + bounce
			# Ticks as the falling ball crosses frets.
			if fall > 0.0 and lt < 1.0:
				var fret := int(floor(wrapf(relative, 0.0, TAU) / (TAU / POCKETS)))
				if fret != _last_tick:
					_last_tick = fret
					get_node("/root/UIAudio").play("cursor")
			if _time >= _duration:
				_duration = 0.0
				winner = _pocket
				settled.emit()
		if winner >= 0:
			_glow += delta
			ball_angle = angle + pocket_angle(winner)
		queue_redraw()

	func _point(a: float, r: float) -> Vector2:
		return size * 0.5 + Vector2(sin(a), -cos(a)) * r

	func _draw() -> void:
		var c := size * 0.5
		var r := radius()
		draw_circle(c + Vector2(8, 12), r + 4, Color(0, 0, 0, 0.45))
		draw_circle(c, r, Color("4a2814"))
		draw_arc(c, r - 3, 0, TAU, 96, GOLD, 5.0, true)
		draw_circle(c, r * 0.92, Color("2a160b"))
		draw_arc(c, r * 0.8, 0, TAU, 96, Color("5c3a1c"), 3.0, true)
		var outer := r * 0.78
		var inner := r * 0.66
		var pocket_in := r * 0.52
		var step := TAU / POCKETS
		for i: int in range(POCKETS):
			var number: int = RouletteScreen.ORDER[i]
			var fill: Color = GREEN if number == 0 else (RED if number in RouletteScreen.REDS else BLACK)
			var a0 := angle + step * (i - 0.5)
			var a1 := angle + step * (i + 0.5)
			var points := PackedVector2Array()
			for k: int in range(5): points.append(_point(lerpf(a0, a1, k / 4.0), outer))
			for k: int in range(5): points.append(_point(lerpf(a1, a0, k / 4.0), inner))
			draw_colored_polygon(points, fill)
			var cup := PackedVector2Array()
			for k: int in range(5): cup.append(_point(lerpf(a0, a1, k / 4.0), inner))
			for k: int in range(5): cup.append(_point(lerpf(a1, a0, k / 4.0), pocket_in))
			draw_colored_polygon(cup, fill.darkened(0.45))
			if i == winner:
				var pulse := 0.55 + 0.45 * sin(_glow * 6.0)
				draw_colored_polygon(points, Color(1.0, 0.92, 0.5, 0.35 * pulse))
				draw_polyline(points + PackedVector2Array([points[0]]), Color(1.0, 0.95, 0.6, pulse), 3.0, true)
			draw_line(_point(a0, outer), _point(a0, pocket_in), GOLD.darkened(0.2), 2.0, true)
			# Numbers stand upright toward the rim.
			var mid := angle + step * i
			var at := _point(mid, (outer + inner) * 0.5)
			draw_set_transform(at, mid, Vector2.ONE)
			var text := str(number)
			var font: Font = CardWidget.CARD_TEXT_FONT
			var font_size := int(r * 0.07)
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, Vector2(-width * 0.5, font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(c, outer, 0, TAU, 96, GOLD, 2.5, true)
		draw_arc(c, inner, 0, TAU, 96, GOLD.darkened(0.2), 1.5, true)
		# Cone and turret.
		for k: int in range(8):
			var f := k / 7.0
			draw_circle(c, lerpf(pocket_in, r * 0.12, f), Color("6b4223").lerp(Color("c99a4b"), f))
		for k: int in range(4):
			var spoke := angle * 1.0 + PI * 0.5 * k
			var tip := c + Vector2(sin(spoke), -cos(spoke)) * r * 0.34
			draw_line(c, tip, GOLD, 7.0, true)
			draw_circle(tip, r * 0.035, GOLD.lightened(0.2))
		draw_circle(c, r * 0.1, GOLD)
		draw_circle(c, r * 0.05, GOLD.lightened(0.35))
		if ball_visible:
			var ball := _point(ball_angle, ball_radius)
			draw_circle(ball + Vector2(3, 4), r * 0.028, Color(0, 0, 0, 0.5))
			draw_circle(ball, r * 0.028, Color("f5f5f2"))
			draw_circle(ball - Vector2(r * 0.009, r * 0.009), r * 0.01, Color.WHITE)
