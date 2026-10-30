extends ShopScreen
class_name MilliShopScreen
## 「米莉商店」 event shop: the normal shop rules with Milli (Rance 03's weapon-shop clerk
## 米丽, not the mercenary 美莉) as the keeper, a gothic-lolita display, her theme
## 「美妙的致死量」 and her own voiced greetings and pokes. There is no bargaining button.
## Assets come from the Rance 03 unpack (assets/shop/milli/); voice IDs are Rance03Voice numbers.
const ROOT := "res://assets/shop/milli/"
const BREATH_SHADER: Shader = preload("res://shaders/portrait_breath.gdshader")
const DISPLAY_SHADER: Shader = preload("res://shaders/gothic_display.gdshader")
## Original loop begin of 音乐／ＡＤＶ／米丽 (Rance03 timemap_sound2), 44.1 kHz.
const BGM_LOOP := 134306.0 / 44100.0
const GREETINGS := {18077: "……欢迎光临……", 18098: "……欢迎光临……", 18113: "啊……欢迎光临，兰斯先生。"}
const POKES := {
	18078: "咦？……啊……！？", 18091: "什么……", 18111: "什么？", 18118: "唔…………",
	18119: "是的……怎么了？", 18120: "……我才不会。", 18125: "……？", 18126: "呃，兰斯先生……？怎么了……",
	18127: "啊……！", 18130: "……吓我一跳。", 18132: "……我有种不好的预感。", 18133: "啊！",
	18134: "……唔………", 18140: "……没什么。", 22269: "……噫……啊，不是，我……那个……",
}
const PORTRAIT_HEIGHT := 1000.0
const PORTRAIT_PAD := 0.02
const LILAC := Color("efdcff")
var portrait: ColorRect
var voice: AudioStreamPlayer
var bubble: PanelContainer
var _bubble_text: Label
var _bubble_tween: Tween
var _poke_tween: Tween
var _last_poke := 0
var _previous_music: Dictionary = {}
## Items cost troop rates instead of shells: one random rate each, amount by rarity.
const CARD_RATE_COSTS := {1: [1, 1], 2: [2, 2], 3: [3, 3]}
## Relic rarity 1 普通, 2 罕见, 3 稀有, 4 商店 -> inclusive range.
const RELIC_RATE_COSTS := {1: [4, 6], 2: [8, 10], 3: [10, 12], 4: [8, 10]}
const RATE_ICONS := {"physical_resist": "rate_physical_resist.png", "magic_resist": "rate_magic_resist.png", "hp": "rate_hp.png"}
var _rate_values: Dictionary = {}

func _ready() -> void:
	_assign_rate_prices()
	super._ready()
	name = "MilliShopScreen"
	var caption := BattleArt.label(self, "使用部队加成购买物品", Vector2(840, 985), Vector2(620, 80), 34, LILAC, HORIZONTAL_ALIGNMENT_CENTER)
	caption.name = "RatePaymentCaption"
	caption.add_theme_color_override("font_outline_color", Color("4a0716"))
	caption.add_theme_constant_override("outline_size", 8)
	_start_music()
	_greet.call_deferred()

## Rolled once when the shop opens; the price never changes while it stays open.
func _assign_rate_prices() -> void:
	var rng: RandomNumberGenerator = get_node("/root/RunAutosave").rng
	var relics := RelicCatalog.new()
	relics.load_catalog()
	for offer: Dictionary in stock.items:
		if offer.unavailable: continue
		var span: Array = CARD_RATE_COSTS[int(troop.catalog.find_name(offer.id).rarity)] if offer.kind == "card" else RELIC_RATE_COSTS[int(relics.by_name[offer.id].rarity)]
		offer["rate_kind"] = TroopState.RATE_PAYMENTS[rng.randi_range(0, TroopState.RATE_PAYMENTS.size() - 1)]
		offer["rate_cost"] = rng.randi_range(int(span[0]), int(span[1]))

static func rate_icon(kind: String) -> Texture2D:
	return load(ROOT + RATE_ICONS[kind])

func _icon(parent: Control, kind: String, at: Vector2, side: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = rate_icon(kind)
	# The brown HP emblem disappears on the dark cloth; lift it to match the glossy support icons.
	if kind == "hp": icon.modulate = Color(1.9, 1.6, 1.45)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = at
	icon.size = Vector2(side, side)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

## Replaces the shell balance: the three payable rates with their icons, doubling as the legend.
func _build_wallet() -> Label:
	var legend := PanelContainer.new()
	legend.name = "RateLegend"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.02, 0.06, 0.9)
	style.border_color = Color(LILAC, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	legend.add_theme_stylebox_override("panel", style)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ends left of the map's settings gear (top-right corner).
	legend.position = Vector2(900, 6)
	legend.size = Vector2(880, 52)
	add_child(legend)
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_child(row)
	for index: int in range(TroopState.RATE_PAYMENTS.size()):
		var kind: String = TroopState.RATE_PAYMENTS[index]
		var x := 14.0 + index * 290.0
		_icon(row, kind, Vector2(x, 4), 44).name = "Icon_" + kind
		BattleArt.label(row, String(TroopState.RATE_NAMES[kind]), Vector2(x + 52, 6), Vector2(130, 40), 24, LILAC)
		var value := BattleArt.label(row, "", Vector2(x + 172, 6), Vector2(100, 40), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		value.name = "Value_" + kind
		_rate_values[kind] = value
	# The base class keeps a balance label; this shop has none to show.
	var unused := Label.new()
	unused.hide()
	add_child(unused)
	return unused

func _refresh_wallet() -> void:
	for kind: String in _rate_values:
		var value := roundi(troop.rate(kind))
		var label: Label = _rate_values[kind]
		label.text = "%d%%" % value
		label.add_theme_color_override("font_color", Color("ff6b8a") if value < 0 else Color.WHITE)

func _price_tag(offer: Dictionary, index: int, at: Vector2) -> void:
	_icon(item_layer, String(offer.rate_kind), at + Vector2(22, 4), 38)
	var price := BattleArt.label(item_layer, "-%d%%" % int(offer.rate_cost), at + Vector2(66, 3), Vector2(120, 40), 27, Color("ffb0c8"))
	price.name = "Price%d" % index

## Pays with a troop rate; there is no floor, so every item can always be bought.
## Losing HP增加率 keeps the current HP ratio; with no maximum HP left the run ends.
func _buy(index: int, at: Vector2) -> void:
	if _entering: return
	if get_node("/root/DebugConsole").panel.visible or is_instance_valid(get_node("/root/Settings").panel): return
	var offer: Dictionary = stock.items[index]
	if offer.sold or offer.unavailable: return
	if offer.kind == "relic" and offer.id in troop.relics:
		status.text = "已拥有该遗物。"
		return
	var session: Node = get_node("/root/EventManager").current_session()
	var maximum := troop.total("hp")
	var ratio: float = session.hp() / maximum if session.active and maximum > 0.0 else 1.0
	# Commit the sale before inventory emits its synchronous UI signals.
	offer.sold = true
	if offer.kind == "card": troop.acquire_card(offer.id)
	elif not troop.acquire_relic(offer.id, at):
		offer.sold = false
		status.text = "无法获得该遗物。"
		return
	troop.spend_rate(String(offer.rate_kind), int(offer.rate_cost))
	status.text = ""
	if offer.rate_kind == "hp" and session.active:
		maximum = troop.total("hp")
		session.set_event_damage(maximum * (1.0 - ratio))
		if maximum <= 0.0: session.defeat()

func _build_backdrop() -> void:
	var room := TextureRect.new()
	room.name = "MilliRoom"
	room.texture = load(ROOT + "background.png")
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room.size = Vector2(1920, 1080)
	room.modulate = Color(0.46, 0.36, 0.5)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room)
	var shade := ColorRect.new()
	shade.name = "Vignette"
	shade.size = Vector2(1920, 1080)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type canvas_item;\nvoid fragment(){ vec2 c = UV - 0.5; COLOR = vec4(0.05, 0.0, 0.04, clamp(dot(c, c) * 2.4, 0.0, 0.85)); }"
	shade.material = material
	add_child(shade)
	_add_petals()

## Red spider-lily petals (her hair flower) drifting down through the shop.
func _add_petals() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.25, 0.3, 1.0))
	gradient.set_color(1, Color(0.6, 0.0, 0.08, 0.0))
	var petal := GradientTexture2D.new()
	petal.gradient = gradient
	petal.fill = GradientTexture2D.FILL_RADIAL
	petal.fill_from = Vector2(0.5, 0.5)
	petal.fill_to = Vector2(0.5, 0.0)
	petal.width = 10
	petal.height = 26
	var petals := CPUParticles2D.new()
	petals.name = "Petals"
	petals.texture = petal
	petals.position = Vector2(960, -30)
	petals.amount = 26
	petals.lifetime = 11.0
	petals.preprocess = 11.0
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(980, 10)
	petals.direction = Vector2(0.25, 1.0)
	petals.spread = 18.0
	petals.gravity = Vector2(0, 14)
	petals.initial_velocity_min = 40.0
	petals.initial_velocity_max = 80.0
	petals.angular_velocity_min = -70.0
	petals.angular_velocity_max = 70.0
	petals.angle_min = 0.0
	petals.angle_max = 360.0
	petals.scale_amount_min = 0.6
	petals.scale_amount_max = 1.1
	petals.color = Color(1, 1, 1, 0.75)
	add_child(petals)

func _build_keeper() -> Control:
	var keeper := Control.new()
	keeper.name = "Keeper"
	keeper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(keeper)
	var image: Texture2D = load(ROOT + "portrait.png")
	var width := PORTRAIT_HEIGHT * image.get_width() / image.get_height()
	var height := PORTRAIT_HEIGHT / (1.0 - PORTRAIT_PAD)
	portrait = ColorRect.new()
	portrait.name = "MilliPortrait"
	portrait.size = Vector2(width, height)
	portrait.position = Vector2(118, 1078 - height)
	# Breath and pokes squash from her feet.
	portrait.pivot_offset = Vector2(width * 0.45, height)
	var material := ShaderMaterial.new()
	material.shader = BREATH_SHADER
	material.set_shader_parameter("portrait", image)
	material.set_shader_parameter("pad", PORTRAIT_PAD)
	portrait.material = material
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keeper.add_child(portrait)
	# Clicking anywhere on her (not the transparent margin) plays a random line.
	var poke := Button.new()
	poke.name = "PokeMilli"
	poke.position = portrait.position + Vector2(width * 0.12, height * 0.03)
	poke.size = Vector2(width * 0.7, height * 0.94)
	poke.focus_mode = Control.FOCUS_NONE
	poke.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style: String in ["normal", "hover", "pressed", "disabled", "focus"]: poke.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	poke.pressed.connect(poke_milli)
	keeper.add_child(poke)
	voice = AudioStreamPlayer.new()
	voice.name = "MilliVoice"
	voice.bus = &"SFX"
	keeper.add_child(voice)
	bubble = _make_bubble()
	keeper.add_child(bubble)
	return keeper

func _make_bubble() -> PanelContainer:
	var box := PanelContainer.new()
	box.name = "MilliBubble"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.02, 0.06, 0.93)
	style.border_color = Color(0.93, 0.88, 0.95, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	style.shadow_color = Color(0.55, 0.0, 0.12, 0.55)
	style.shadow_size = 8
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_text = Label.new()
	_bubble_text.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	_bubble_text.add_theme_font_size_override("font_size", 26)
	_bubble_text.add_theme_color_override("font_color", Color("ffd9ea"))
	box.add_child(_bubble_text)
	box.modulate.a = 0.0
	box.hide()
	return box

func _build_display() -> void:
	var cloth := ColorRect.new()
	cloth.name = "GothicCloth"
	cloth.position = Vector2(560, 60)
	cloth.size = Vector2(1320, 880)
	cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = DISPLAY_SHADER
	material.set_shader_parameter("size", cloth.size)
	cloth.material = material
	display.add_child(cloth)

func _greet() -> void:
	await get_tree().create_timer(0.35).timeout
	if is_inside_tree(): _speak(GREETINGS.keys().pick_random(), GREETINGS)

## A random poke line, never the same one twice in a row; she bobs as if startled.
func poke_milli() -> void:
	var choices := POKES.keys().filter(func(id: int) -> bool: return id != _last_poke)
	_last_poke = choices.pick_random()
	_speak(_last_poke, POKES)
	if _poke_tween != null: _poke_tween.kill()
	portrait.scale = Vector2.ONE
	_poke_tween = create_tween()
	_poke_tween.tween_property(portrait, "scale", Vector2(1.025, 0.975), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_poke_tween.tween_property(portrait, "scale", Vector2(0.99, 1.015), 0.1)
	_poke_tween.tween_property(portrait, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _speak(id: int, lines: Dictionary) -> void:
	voice.stream = load(ROOT + "voice/%d.ogg" % id)
	voice.play()
	_bubble_text.text = String(lines[id])
	bubble.reset_size()
	bubble.position = Vector2(clampf(portrait.position.x + portrait.size.x * 0.45 - bubble.size.x * 0.5, 16, 560), 10)
	bubble.show()
	if _bubble_tween != null: _bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(bubble, "modulate:a", 1.0, 0.12)
	_bubble_tween.tween_interval(2.2)
	_bubble_tween.tween_property(bubble, "modulate:a", 0.0, 0.35)
	_bubble_tween.tween_callback(bubble.hide)

## Her theme replaces the current music; leaving restores whatever was playing.
func _start_music() -> void:
	var bgm := get_node("/root/BGM")
	if bgm.player.playing and bgm.player.stream != null:
		_previous_music = {"stream": bgm.player.stream, "track": bgm.current_track, "position": bgm.player.get_playback_position()}
	bgm.play_music(load(ROOT + "bgm.ogg"), &"milli_shop", true, BGM_LOOP)

func _exit_tree() -> void:
	var bgm := get_node_or_null("/root/BGM")
	if bgm == null or bgm.current_track != &"milli_shop": return
	if _previous_music.is_empty():
		bgm.stop_music()
		return
	# The saved stream already carries its loop settings.
	bgm.player.stop()
	bgm.player.stream = _previous_music.stream
	bgm.current_track = _previous_music.track
	bgm.player.play(float(_previous_music.position))
