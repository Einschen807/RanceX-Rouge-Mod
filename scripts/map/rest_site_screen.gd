extends Control
class_name RestSiteScreen
## Campfire rest site: the native framed night-camp scene over its own blurred backdrop,
## a gently flickering fire and lantern, and one card per available rest action.
## The map screen applies the chosen action.
signal action_selected(id: String)
signal continue_requested
const BACKDROP := preload("res://assets/map/rest_backdrop.png")
const CAMP := preload("res://assets/map/rest_camp.png")
const SCENE_SCALE := 0.92
const SCENE_AT := Vector2((1920.0 - 1798.0 * SCENE_SCALE) / 2.0, 146)
## Light sources in rest_camp.png pixels: the cooking fire and the hanging lantern.
const FIRE_PIXEL := Vector2(655, 492)
const LANTERN_PIXEL := Vector2(246, 222)
const OPTION_SIZE := Vector2(300, 240)
## Completion captions rise over the open sky of the camp scene, clear of its frame.
const CAPTION_AT := Vector2(960, 300)
const SOUNDS := {
	"heal": preload("res://assets/audio/rest_heal.ogg"), "warm": preload("res://assets/audio/rest_warm.ogg"),
	"gear": preload("res://assets/audio/rest_gear.ogg"), "shuffle": preload("res://assets/audio/rest_shuffle.ogg"),
	"crack": preload("res://assets/audio/rest_crack.ogg"), "obtain": preload("res://assets/audio/rest_obtain.ogg"),
	"grow": preload("res://assets/audio/rest_grow.ogg"),
}
var session: Node
var upgrade_count := 1
var finished := false
var _options: Array[Control] = []
var _lights: Array[Sprite2D] = []
var _clock := 0.0
## Extra brightness on the fire/lantern light while the 休息 effect plays.
var _light_boost := 1.0
var _completion: Tween
var _continued := false

func _ready() -> void:
	name = "RestSiteScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := TextureRect.new()
	backdrop.texture = BACKDROP
	backdrop.size = Vector2(1920, 1080)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var camp := TextureRect.new()
	camp.name = "Camp"
	camp.texture = CAMP
	# Expand mode first: otherwise the texture's own size is the minimum and the scale is lost.
	camp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camp.position = SCENE_AT
	camp.size = CAMP.get_size() * SCENE_SCALE
	camp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(camp)
	_build_lights()
	_build_header()
	_build_options()
	_play_intro()

func _scene_point(pixel: Vector2) -> Vector2:
	return SCENE_AT + pixel * SCENE_SCALE

func _soft_dot(size: int) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = size
	texture.height = size
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	texture.gradient = gradient
	return texture

func _additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material

func _light(at: Vector2, scale: Vector2, color: Color) -> Sprite2D:
	var light := Sprite2D.new()
	light.texture = _soft_dot(256)
	light.position = at
	light.scale = scale
	light.modulate = color
	light.material = _additive()
	light.set_meta("base_scale", scale)
	light.set_meta("base_alpha", color.a)
	add_child(light)
	_lights.append(light)
	return light

func _build_lights() -> void:
	# The painted fire stays the subject; additive light only breathes over it.
	var fire := _scene_point(FIRE_PIXEL)
	_light(fire + Vector2(0, -20), Vector2(1.9, 1.3), Color(1.0, 0.55, 0.2, 0.32))
	_light(fire + Vector2(0, -10), Vector2(0.55, 0.5), Color(1.0, 0.75, 0.35, 0.28))
	_light(_scene_point(LANTERN_PIXEL), Vector2(0.75, 0.75), Color(1.0, 0.7, 0.35, 0.22))
	var sparks := CPUParticles2D.new()
	sparks.name = "Sparks"
	sparks.position = fire + Vector2(0, -30)
	sparks.texture = _soft_dot(16)
	sparks.material = _additive()
	sparks.amount = 14
	sparks.lifetime = 2.2
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(26, 6)
	sparks.direction = Vector2.UP
	sparks.spread = 22.0
	sparks.gravity = Vector2(0, -24)
	sparks.initial_velocity_min = 30.0
	sparks.initial_velocity_max = 70.0
	sparks.scale_amount_min = 0.35
	sparks.scale_amount_max = 0.75
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.85, 0.45, 0.9))
	fade.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
	sparks.color_ramp = fade
	add_child(sparks)

func _build_header() -> void:
	var banner := NativeSettingsArt.picture(self, "section_decor", Vector2(560, 6), Vector2(800, 136))
	banner.modulate.a = 0.9
	var title := BattleArt.label(self, "篝火休整", Vector2(560, 26), Vector2(800, 62), 44, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Title"
	var hp := RichTextLabel.new()
	hp.name = "HpLine"
	hp.bbcode_enabled = true
	hp.scroll_active = false
	hp.position = Vector2(560, 88)
	hp.size = Vector2(800, 40)
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.add_theme_font_override("normal_font", CardWidget.CARD_TEXT_FONT)
	hp.add_theme_font_size_override("normal_font_size", 25)
	hp.add_theme_color_override("default_color", Color("f3e3c2"))
	hp.add_theme_color_override("font_outline_color", Color.BLACK)
	hp.add_theme_constant_override("outline_size", 6)
	add_child(hp)
	_refresh_hp()

## Current/maximum HP plus the ratio, coloured so a low troop reads at a glance.
func _refresh_hp() -> void:
	var maximum: float = session.troop.total("hp")
	var current := minf(float(session.hp()), maximum)
	var ratio := current / maxf(1.0, maximum) * 100.0
	var color := "8fd47a" if ratio >= 60.0 else ("f2c75c" if ratio >= 30.0 else "ff6556")
	(get_node("HpLine") as RichTextLabel).text = "[center]部队生命  %d / %d　[color=#%s]%d%%[/color][/center]" % [ceili(current), ceili(maximum), color, roundi(ratio)]

func _option_specs() -> Array[Dictionary]:
	var maximum: float = session.troop.total("hp")
	var heal_amount := minf(maximum * 0.3, maximum - float(session.hp()))
	var specs: Array[Dictionary] = [
		{"id": "heal", "title": "休息", "icon": "res://assets/formation/bonus_symbol_8.png", "text": "恢复最大生命值的30%%\n（+%d）" % floori(heal_amount)},
		{"id": "upgrade", "title": "锻炼", "icon": "res://assets/formation/bonus_symbol_12.png", "text": "强化%d张卡牌" % upgrade_count},
		{"id": "reset", "title": "整备", "icon": "res://assets/formation/bonus_symbol_5.png", "text": "重置所有卡牌状态\n使用次数与AP累计复原"},
	]
	var eggs: Array[String] = RelicEffects.held_eggs(session.troop)
	if not eggs.is_empty():
		specs.append({"id": "hatch", "title": "孵化", "icon": "res://assets/relics/%s.png" % eggs[0], "text": "孵化持有的%d个蛋\n获得圣女" % eggs.size()})
	var saints: Dictionary = RelicEffects.growable_saints(session.troop)
	if not saints.is_empty():
		specs.append({"id": "train", "title": "培养", "icon": "res://assets/formation/bonus_symbol_3.png", "text": "%d名圣女成长为\n大版本" % saints.size()})
	return specs

func _build_options() -> void:
	var specs := _option_specs()
	var gap := 34.0
	var width := specs.size() * OPTION_SIZE.x + (specs.size() - 1) * gap
	var left := (1920.0 - width) / 2.0
	for i: int in range(specs.size()):
		var option := _option(specs[i], Vector2(left + i * (OPTION_SIZE.x + gap), 790))
		_options.append(option)
	var hint := BattleArt.label(self, "所有选项都会结束本次休整　·　右键返回地图", Vector2(460, 1040), Vector2(1000, 34), 20, Color(0.85, 0.8, 0.7, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	hint.name = "Hint"

func _option(spec: Dictionary, at: Vector2) -> Button:
	var button := Button.new()
	button.name = "Option_" + String(spec.id)
	button.position = at
	button.size = OPTION_SIZE
	button.pivot_offset = OPTION_SIZE / 2.0
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	add_child(button)
	get_node("/root/UIAudio").bind_button(button)
	var panel := Panel.new()
	panel.size = OPTION_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", BattleArt.panel_style())
	button.add_child(panel)
	var backing := ColorRect.new()
	backing.color = Color(0.03, 0.02, 0.02, 0.82)
	backing.position = Vector2(5, 5)
	backing.size = OPTION_SIZE - Vector2(10, 10)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.show_behind_parent = true
	panel.add_child(backing)
	var icon := TextureRect.new()
	icon.name = "Icon"
	var texture: Texture2D = load(String(spec.icon))
	var image := texture.get_image()
	if image != null and String(spec.icon).begins_with("res://assets/relics/"):
		# Relic art sits in a padded canvas; crop to the visible item like RelicIcon.
		var cropped := AtlasTexture.new()
		cropped.atlas = texture
		cropped.region = Rect2(image.get_used_rect())
		texture = cropped
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(OPTION_SIZE.x / 2.0 - 36, 68)
	icon.size = Vector2(72, 72)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	# The native frame has a header band above its rule line: the title sits there.
	BattleArt.label(button, spec.title, Vector2(10, 8), Vector2(OPTION_SIZE.x - 20, 48), 32, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var text := BattleArt.label(button, spec.text, Vector2(18, 150), Vector2(OPTION_SIZE.x - 36, 76), 21, Color("eee2ca"), HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text.clip_text = false
	button.mouse_entered.connect(_hover.bind(button, true))
	button.mouse_exited.connect(_hover.bind(button, false))
	button.focus_entered.connect(_hover.bind(button, true))
	button.focus_exited.connect(_hover.bind(button, false))
	button.pressed.connect(_choose.bind(String(spec.id), button))
	return button

func _hover(button: Button, active: bool) -> void:
	if finished: return
	var tween := button.create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2.ONE * (1.06 if active else 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", Color(1.12, 1.05, 0.92) if active else Color.WHITE, 0.12)

func _play_intro() -> void:
	for node: Node in get_children():
		if node is CanvasItem: (node as CanvasItem).modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	for node: Node in get_children():
		if not node is CanvasItem: continue
		var item := node as CanvasItem
		var delay := 0.0
		if item in _options:
			delay = 0.25 + 0.07 * _options.find(item)
			var target := (item as Control).position.y
			(item as Control).position.y += 40
			tween.tween_property(item, "position:y", target, 0.32).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		elif item is Sprite2D:
			continue # Lights fade in through _process.
		tween.tween_property(item, "modulate:a", 1.0, 0.35).set_delay(delay)
	if not _options.is_empty(): _options[0].grab_focus.call_deferred()

func _choose(id: String, button: Button) -> void:
	if finished: return
	if id != "upgrade":
		finished = true
		for option: Control in _options:
			(option as Button).disabled = true
			if option != button: option.create_tween().tween_property(option, "modulate:a", 0.25, 0.2)
		var pulse := button.create_tween()
		pulse.tween_property(button, "scale", Vector2.ONE * 1.12, 0.12)
		pulse.tween_property(button, "scale", Vector2.ONE * 1.04, 0.18)
	action_selected.emit(id)

## Plays the chosen action's completion (no dialog), then asks the map to continue.
## info: heal {before, after}; hatch/train {names}.
func play_completion(id: String, info: Dictionary) -> void:
	finished = true
	var option := get_node_or_null("Option_" + id) as Button
	var center := option.position + OPTION_SIZE / 2.0 if option != null else Vector2(960, 900)
	_completion = create_tween().set_parallel(true)
	match id:
		"heal":
			# The fire flares, warm light washes the camp and the HP line counts up.
			_sound("heal")
			_completion.tween_callback(_sound.bind("warm")).set_delay(0.3)
			_completion.tween_method(func(v: float) -> void: _light_boost = v, 1.0, 2.6, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_completion.tween_method(func(v: float) -> void: _light_boost = v, 2.6, 1.3, 0.8).set_delay(0.35)
			var wash := _wash(Color(1.0, 0.55, 0.2))
			_completion.tween_property(wash, "modulate:a", 0.22, 0.35)
			_completion.tween_property(wash, "modulate:a", 0.0, 0.8).set_delay(0.45)
			var before := float(info.get("before", 0.0))
			var after := float(info.get("after", before))
			_completion.tween_method(func(v: float) -> void: _set_hp_text(v), before, after, 0.9).set_delay(0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_caption("+%d" % floori(after - before), Vector2(1240, 108), Color("8fd47a"), 0.15, 28)
			_caption("部队恢复了体力", CAPTION_AT, Color("f3e3c2"), 0.1)
		"reset":
			# Gear rattles, the card deck shuffles: the icon turns and a gold ring sweeps out.
			_sound("gear")
			_completion.tween_callback(_sound.bind("shuffle")).set_delay(0.28)
			if option != null:
				var icon := option.get_node("Icon") as Control
				icon.pivot_offset = icon.size / 2.0
				_completion.tween_property(icon, "rotation", TAU, 0.7).set_delay(0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			_ring(center + Vector2(0, -20), 0.25)
			_ring(center + Vector2(0, -20), 0.5)
			_caption("所有卡牌状态已重置", CAPTION_AT, FormationArt.GOLD, 0.35)
		"hatch":
			# The egg wobbles and cracks, a white burst, then the new saint is named.
			_sound("crack")
			if option != null:
				var egg := option.get_node("Icon") as Control
				egg.pivot_offset = egg.size / 2.0
				for n: int in range(4):
					_completion.tween_property(egg, "rotation", 0.22 * (1 if n % 2 == 0 else -1), 0.1).set_delay(0.1 * n)
				_completion.tween_property(egg, "rotation", 0.0, 0.08).set_delay(0.4)
				_completion.tween_property(egg, "scale", Vector2.ONE * 1.5, 0.18).set_delay(0.5)
				_completion.tween_property(egg, "modulate", Color(3, 3, 3, 0), 0.25).set_delay(0.55)
			_completion.tween_callback(_sound.bind("obtain")).set_delay(0.55)
			_completion.tween_callback(_burst.bind(center + Vector2(0, -20), Color(1, 1, 1))).set_delay(0.55)
			var names: Array = info.get("names", [])
			for n: int in range(names.size()):
				_caption("获得「%s」" % names[n], CAPTION_AT + Vector2(0, n * 48), FormationArt.GOLD, 0.65 + n * 0.12)
		"train":
			# Growth chime with a rising gold burst for every saint that grew.
			_sound("grow")
			if option != null:
				var plus := option.get_node("Icon") as Control
				plus.pivot_offset = plus.size / 2.0
				_completion.tween_property(plus, "scale", Vector2.ONE * 1.35, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_completion.tween_property(plus, "scale", Vector2.ONE, 0.3).set_delay(0.3)
			_completion.tween_callback(_burst.bind(center + Vector2(0, -20), FormationArt.GOLD)).set_delay(0.15)
			var grown: Array = info.get("names", [])
			for n: int in range(grown.size()):
				_caption("成长为「%s」" % grown[n], CAPTION_AT + Vector2(0, n * 48), FormationArt.GOLD, 0.3 + n * 0.12)
	_completion.chain().tween_interval(0.55)
	_completion.chain().tween_callback(_continue)

## Back during the completion skips straight to the map.
func skip_completion() -> void:
	if _completion != null and _completion.is_valid(): _completion.kill()
	_continue()

func _continue() -> void:
	if _continued: return
	_continued = true
	continue_requested.emit()

func _sound(key: String) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = SOUNDS[key]
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _set_hp_text(current: float) -> void:
	var maximum: float = session.troop.total("hp")
	var ratio := minf(current, maximum) / maxf(1.0, maximum) * 100.0
	var color := "8fd47a" if ratio >= 60.0 else ("f2c75c" if ratio >= 30.0 else "ff6556")
	(get_node("HpLine") as RichTextLabel).text = "[center]部队生命  %d / %d　[color=#%s]%d%%[/color][/center]" % [ceili(minf(current, maximum)), ceili(maximum), color, roundi(ratio)]

func _wash(color: Color) -> ColorRect:
	var wash := ColorRect.new()
	wash.color = color
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.material = _additive()
	wash.modulate.a = 0.0
	add_child(wash)
	return wash

func _ring(at: Vector2, delay: float) -> void:
	var ring := Line2D.new()
	ring.width = 5.0
	ring.default_color = Color(FormationArt.GOLD, 0.0)
	ring.material = _additive()
	for n: int in range(49):
		var a := TAU * n / 48.0
		ring.add_point(Vector2(cos(a), sin(a)) * 40.0)
	ring.position = at
	add_child(ring)
	_completion.tween_property(ring, "default_color:a", 0.9, 0.05).set_delay(delay)
	_completion.tween_property(ring, "scale", Vector2.ONE * 3.2, 0.6).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_completion.tween_property(ring, "default_color:a", 0.0, 0.5).set_delay(delay + 0.1)

func _burst(at: Vector2, color: Color) -> void:
	var glow := Sprite2D.new()
	glow.texture = _soft_dot(256)
	glow.material = _additive()
	glow.position = at
	glow.modulate = Color(color, 0.9)
	glow.scale = Vector2.ONE * 0.2
	add_child(glow)
	var tween := glow.create_tween().set_parallel(true)
	tween.tween_property(glow, "scale", Vector2.ONE * 1.6, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "modulate:a", 0.0, 0.45)
	var sparks := CPUParticles2D.new()
	sparks.position = at
	sparks.texture = _soft_dot(16)
	sparks.material = _additive()
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.amount = 26
	sparks.lifetime = 0.8
	sparks.spread = 180.0
	sparks.gravity = Vector2(0, 160)
	sparks.initial_velocity_min = 120.0
	sparks.initial_velocity_max = 280.0
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 1.0))
	fade.set_color(1, Color(color, 0.0))
	sparks.color_ramp = fade
	add_child(sparks)
	sparks.emitting = true

func _caption(text: String, at: Vector2, color: Color, delay: float, font_size := 40) -> void:
	var label := BattleArt.label(self, text, at - Vector2(400, 28), Vector2(800, 56), font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_constant_override("outline_size", 10)
	label.clip_text = false
	label.modulate.a = 0.0
	_completion.tween_property(label, "modulate:a", 1.0, 0.2).set_delay(delay)
	_completion.tween_property(label, "position:y", label.position.y - 36, 1.0).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_completion.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(delay + 0.8)

func _process(delta: float) -> void:
	_clock += delta
	var rise := clampf(_clock / 0.6, 0.0, 1.0)
	for n: int in range(_lights.size()):
		var light := _lights[n]
		var phase := float(n) * 1.7
		var flicker := 1.0 + 0.12 * sin(_clock * 11.0 + phase) + 0.07 * sin(_clock * 6.3 + phase * 2.0) + 0.05 * sin(_clock * 21.0 + phase)
		light.modulate.a = float(light.get_meta("base_alpha")) * flicker * rise * _light_boost
		light.scale = (light.get_meta("base_scale") as Vector2) * (1.0 + 0.025 * sin(_clock * 8.0 + phase))
