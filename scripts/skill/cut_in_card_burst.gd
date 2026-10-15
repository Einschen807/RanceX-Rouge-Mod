extends Control
class_name CutInCardBurst
## Card-origin cinematic. The cut_in animation owns every phase; combat owns impact.
@export var portrait: Texture2D
@export var voice: AudioStream
@export var accent := Color("66b8ff")
@export var actor_name := ""
@export var preview_card_face: Texture2D
@export_range(1, 10) var preview_card_faction := 1
@export var portrait_black_matte := false
@export var portrait_position := Vector2(267, 7)
@export var portrait_width := 1270.0
@export_range(0.0, 1.0) var portrait_focus_x := 0.46
@export var phase_time := 0.0
var clock := 0.0
var source_center := Vector2(960, 760)
var source_scale := 1.15
var _source: CardWidget
var _voice_started := false
var _split_started := false
var _voice_hold := false
var _snapshot: SubViewport
var _halves: Array[TextureRect] = []
var _portrait: TextureRect
var _echoes: Array[TextureRect] = []
var _foreground: Control
var _card_center := Vector2.ZERO
var _card_size := Vector2.ZERO
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var voice_player: AudioStreamPlayer = $Voice
@onready var split_player: AudioStreamPlayer = $SplitSFX
const CARD_SHADER := preload("res://shaders/cut_in_card_split.gdshader")
const PORTRAIT_SHADER := preload("res://shaders/cut_in_burst_portrait.gdshader")

func _ink(reference: Color) -> Color:
	# Hue changes retain the approved blue preset's brightness and contrast.
	var shift := accent.h - Color("66b8ff").h
	if is_zero_approx(shift): return reference
	return Color.from_hsv(fposmod(reference.h + shift, 1.0), reference.s, reference.v, reference.a)

func configure_source(card: CardWidget) -> void:
	_source = card
	if is_instance_valid(card):
		source_center = card.get_global_transform() * Vector2(104, 156)
		source_scale = card.scale.x

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	voice_player.stream = voice
	voice_player.bus = &"Voice"
	voice_player.volume_db = -1.0
	voice_player.finished.connect(_resume_exit)
	split_player.bus = &"SFX"
	_build_card()
	for i: int in range(2):
		var echo := _make_portrait(true)
		_echoes.append(echo)
	_portrait = _make_portrait(false)
	_foreground = Control.new()
	_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_foreground)
	_foreground.draw.connect(_draw_foreground)
	if is_instance_valid(_source): _source.hide()
	_sync_visuals()

func _build_card() -> void:
	_snapshot = SubViewport.new()
	_snapshot.size = Vector2i(416, 624)
	_snapshot.transparent_bg = true
	_snapshot.gui_disable_input = true
	_snapshot.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_snapshot)
	var card: CardWidget
	if is_instance_valid(_source):
		card = CardWidget.new()
		card.setup(_source.card, _source.troop, false, _source.detail_mode, _source.preview_upgrades)
		card.portrait_only = _source.portrait_only
		card.skill_costs = _source.skill_costs.duplicate()
	else:
		# Standalone preview / support and enemy use also have a complete card face.
		var catalog := CardCatalog.new()
		catalog.load_catalog()
		var troop := TroopState.new()
		troop.configure(catalog, true)
		var record := catalog.find_name(actor_name)
		if not record.is_empty():
			card = CardWidget.new()
			card.setup(record, troop, false, 0)
		else:
			# Removed playable cards can still have independent cinematic art previews.
			var preview := Control.new()
			preview.scale = Vector2.ONE * 2.0
			_snapshot.add_child(preview)
			FormationArt.picture(preview, "back_%d" % preview_card_faction, Vector2.ZERO, Vector2(208, 312))
			var face := TextureRect.new()
			face.texture = preview_card_face if preview_card_face != null else portrait
			face.size = Vector2(208, 312)
			face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			preview.add_child(face)
			FormationArt.picture(preview, "frame_%d" % preview_card_faction, Vector2.ZERO, Vector2(208, 312))
	if card != null:
		card.scale = Vector2.ONE * 2.0
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE
		_snapshot.add_child(card)
		for decoration: String in ["LeaderBadge", "LeaderGlow"]:
			if card.visual.has_node(decoration): card.visual.get_node(decoration).hide()
	for side: float in [-1.0, 1.0]:
		var half := TextureRect.new()
		half.texture = _snapshot.get_texture()
		half.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = CARD_SHADER
		mat.set_shader_parameter("side", side)
		mat.set_shader_parameter("light_color", _ink(Color(0.55, 0.86, 1.0)))
		mat.set_shader_parameter("core_color", _ink(Color(0.98, 1.0, 1.0)))
		half.material = mat
		add_child(half)
		_halves.append(half)

func _make_portrait(silhouette: bool) -> TextureRect:
	var art := TextureRect.new()
	art.texture = portrait
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PORTRAIT_SHADER
	mat.set_shader_parameter("silhouette", silhouette)
	mat.set_shader_parameter("accent", accent)
	mat.set_shader_parameter("black_matte", portrait_black_matte)
	mat.set_shader_parameter("focus_x", portrait_focus_x)
	mat.set_shader_parameter("flash_color", _ink(Color(0.89, 0.97, 1.0)))
	art.material = mat
	add_child(art)
	return art

func _process(delta: float) -> void:
	clock += delta
	if _voice_hold and voice_player.playing:
		var remaining := voice.get_length() - voice_player.get_playback_position()
		if remaining <= animation.current_animation_length - animation.current_animation_position:
			_resume_exit()
	_sync_visuals()

static func _progress(t: float, begin: float, end: float) -> float:
	return clampf((t - begin) / (end - begin), 0.0, 1.0)

static func _out(p: float) -> float:
	return 1.0 - pow(1.0 - p, 3.0)

func _sync_visuals() -> void:
	if _portrait == null: return
	var t := phase_time
	var rise := _out(_progress(t, 0.0, 0.32))
	var charge := _progress(t, 0.30, 0.55)
	var split := _out(_progress(t, 0.54, 0.87))
	var exit := _progress(t, 1.49, 1.95)
	_card_center = source_center.lerp(Vector2(690, 505), rise)
	var growth := lerpf(source_scale, 1.90, rise)
	# A fast edge-on flip during ascent, followed by a readable charged card face.
	var flip := 1.0 - 0.94 * sin(PI * _progress(t, 0.025, 0.255))
	_card_size = Vector2(208 * growth * flip, 312 * growth)
	for i: int in range(2):
		var half := _halves[i]
		var side := -1.0 if i == 0 else 1.0
		half.size = _card_size
		half.pivot_offset = _card_size * 0.5
		half.position = _card_center - _card_size * 0.5 + Vector2(side * split * 390, -split * 65)
		half.rotation = lerpf(-0.16, 0.0, rise) + side * split * 0.32
		var mat := half.material as ShaderMaterial
		mat.set_shader_parameter("charge", charge)
		mat.set_shader_parameter("split", split)
		mat.set_shader_parameter("opacity", 1.0 - _progress(t, 0.72, 1.04))
		half.visible = t < 1.04
	var erupt := _out(_progress(t, 0.58, 0.92))
	var settle := _progress(t, 0.92, 1.10)
	var width := lerpf(420.0, portrait_width + 80.0, erupt) - 80.0 * _out(settle)
	var art_size := Vector2(width, width * float(portrait.get_height()) / portrait.get_width())
	var art_position := Vector2(470, 345).lerp(portrait_position - Vector2(22, 12), erupt) + Vector2(22, 12) * _out(settle)
	art_position += Vector2(exit * exit * 450, -exit * 28)
	var burst_flash := (1.0 - _progress(t, 0.62, 0.77)) * _progress(t, 0.58, 0.62)
	_portrait.size = art_size
	_portrait.position = art_position
	var mat := _portrait.material as ShaderMaterial
	mat.set_shader_parameter("reveal", lerpf(0.0, 0.65, erupt))
	mat.set_shader_parameter("wipe", exit)
	mat.set_shader_parameter("flash", burst_flash * 0.38)
	_portrait.visible = t >= 0.58 and t < 1.95
	for i: int in range(_echoes.size()):
		var echo := _echoes[i]
		echo.size = art_size * (1.025 + i * 0.025)
		echo.position = art_position - Vector2(26 + i * 23, 8 + i * 4)
		echo.modulate.a = (0.30 - i * 0.08) * (1.0 - _progress(t, 0.88, 1.15))
		var echo_mat := echo.material as ShaderMaterial
		echo_mat.set_shader_parameter("reveal", lerpf(0.0, 0.65, erupt))
		echo_mat.set_shader_parameter("wipe", exit)
		echo.visible = t >= 0.58 and t < 1.15
	queue_redraw()
	_foreground.queue_redraw()

func _draw() -> void:
	var t := phase_time
	if t <= 0.0 or t >= 1.95: return
	var rise := _out(_progress(t, 0.0, 0.32))
	var charge := _progress(t, 0.30, 0.55)
	var exit := _progress(t, 1.49, 1.95)
	var panel := _out(_progress(t, 0.58, 0.91)) * (1.0 - _out(exit))
	# A local pool of light locates the card before the cinematic opens.
	for i: int in range(18, 0, -1):
		draw_circle(_card_center, 75 + i * 17, _ink(Color(0.12, 0.34, 0.65, rise * (1.0 - panel) * 0.009)))
	if t < 0.80:
		var radius := 240.0 + charge * 72.0
		for i: int in range(3):
			draw_arc(_card_center, radius + i * 12, clock * 0.8 + i * 2.1, clock * 0.8 + i * 2.1 + 1.8, 48, _ink(Color(0.53, 0.79, 1.0, charge * (1.0 - _progress(t, 0.55, 0.80)) * (0.55 - i * 0.12))), 2.0, true)
	if panel > 0.0:
		var top := lerpf(410, 70, panel)
		var bottom := lerpf(530, 910, panel)
		# Preserve the approved upper-band brightness and translucent lower gradient.
		var bar_top := _ink(Color(0.28 * 0.23, 0.60 * 0.23, 0.94 * 0.23, panel * 0.94))
		var bar_bottom := _ink(Color(0.018 + 0.28 * 0.055, 0.027 + 0.60 * 0.055, 0.036 + 0.94 * 0.055, panel * 0.67))
		draw_polygon(PackedVector2Array([Vector2(0, top + 45), Vector2(1920, top - 45), Vector2(1920, bottom - 110), Vector2(0, bottom)]), PackedColorArray([bar_top, bar_top, bar_bottom, bar_bottom]))
		for i: int in range(22):
			var y := top + i * (bottom - top) / 22.0
			draw_line(Vector2(0, y + 40), Vector2(1920, y - 55), _ink(Color(0.09, 0.24, 0.42, panel * (0.08 + sin(i * 0.2) * 0.025))), 22)
		for i: int in range(48):
			var seed := fmod(float(i) * 0.618034, 1.0)
			var y := lerpf(top + 65, bottom - 120, seed)
			var x := fposmod(i * 233.0 + clock * (520 + seed * 1400), 2440.0) - 260
			var start := Vector2(x, y)
			var end := Vector2(x + 90 + seed * 230, y - 14)
			if i % 8 == 0:
				draw_line(start, end, _ink(Color(0.62, 0.85, 0.97, panel * 0.10)), 8.0, true)
				draw_line(start, end, _ink(Color(0.73, 0.90, 0.98, panel * 0.92)), 2.0 + seed, true)
			elif i % 3 == 0:
				draw_line(start, end, _ink(Color(0.28, 0.60, 0.94, panel * 0.62)), 1.0 + seed, true)
			else:
				draw_line(start, end, _ink(Color(0.32, 0.64, 0.96, panel * (0.18 + seed * 0.26))), 1.0 + seed, true)
		for edge: float in [0.0, 1.0]:
			var a := Vector2(0, top + 45 if edge == 0.0 else bottom)
			var b := Vector2(1920, top - 45 if edge == 0.0 else bottom - 110)
			draw_line(a, b, _ink(Color(0.32, 0.65, 0.98, panel * 0.24)), 10, true)
			draw_line(a, b, _ink(Color(0.70, 0.89, 1.0, panel * 0.85)), 2, true)
			draw_line(a + Vector2(0, 7 if edge == 0.0 else -7), b + Vector2(0, 7 if edge == 0.0 else -7), _ink(Color(0.42, 0.63, 0.78, panel * 0.40)), 1, true)
	# Angular light fragments travel out from the same split, never random per frame.
	var debris := _progress(t, 0.54, 1.15)
	if debris > 0.0 and debris < 1.0:
		for i: int in range(34):
			var angle := i * 2.399963
			var direction := Vector2(cos(angle), sin(angle) * 0.72)
			var distance := 50 + _out(debris) * (260 + fmod(i * 79.0, 340.0))
			var p := Vector2(690, 505) + direction * distance
			var length := 7 + fmod(i * 13.0, 28.0)
			draw_line(p, p + direction * length, _ink(Color(0.74, 0.91, 1.0, (1.0 - debris) * 0.8)), 2 if i % 3 else 4, true)

func _draw_foreground() -> void:
	var t := phase_time
	if t >= 0.36 and t < 0.70:
		var strength := _progress(t, 0.36, 0.54) * (1.0 - _progress(t, 0.58, 0.70))
		var points := PackedVector2Array()
		for i: int in range(25):
			var y := float(i) / 24.0
			var x := 0.50 + 0.075 * sin(y * 17) + 0.025 * sin(y * 43)
			points.append(_card_center + Vector2((x - 0.5) * _card_size.x, (y - 0.5) * _card_size.y))
		_foreground.draw_polyline(points, _ink(Color(0.23, 0.57, 1.0, strength * 0.18)), 22, true)
		_foreground.draw_polyline(points, _ink(Color(0.65, 0.88, 1.0, strength * 0.60)), 8, true)
		_foreground.draw_polyline(points, _ink(Color(0.97, 1.0, 1.0, strength)), 2.6, true)
	var flash := _progress(t, 0.56, 0.59) * (1.0 - _progress(t, 0.59, 0.68))
	if flash > 0.0: _foreground.draw_rect(Rect2(0, 0, 1920, 1080), _ink(Color(0.80, 0.93, 1.0, flash * 0.18)))
	# The exit becomes a blade sweeping toward the enemy's upper battlefield.
	var slash := _progress(t, 1.54, 1.95)
	if slash > 0.0 and slash < 1.0:
		var head := Vector2(lerpf(-300, 2360, _out(slash)), lerpf(650, 270, _out(slash)))
		var tail := head - Vector2(1050, -150)
		var strength := sin(PI * slash)
		_foreground.draw_line(tail, head, _ink(Color(0.27, 0.64, 1.0, strength * 0.12)), 52, true)
		_foreground.draw_line(tail, head, _ink(Color(0.42, 0.77, 1.0, strength * 0.35)), 16, true)
		_foreground.draw_colored_polygon(PackedVector2Array([tail + Vector2(0, 5), head, tail - Vector2(0, 5)]), _ink(Color(0.94, 0.99, 1.0, strength)))

func start_voice() -> void:
	if voice == null or _voice_started: return
	_voice_started = true
	voice_player.play()

func start_split() -> void:
	if _split_started: return
	_split_started = true
	split_player.play()

func hold_for_voice() -> void:
	if voice_player.playing:
		_voice_hold = true
		animation.pause()

func _resume_exit() -> void:
	if _voice_hold:
		_voice_hold = false
		animation.play()
