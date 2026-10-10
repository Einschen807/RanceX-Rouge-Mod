extends "res://scripts/cut_in_card_burst.gd"
## Private background treatment for 谦信必杀1. The shared card/portrait choreography stays intact.
const CREST_FONT := preload("res://assets/fonts/card_text.tres")
const GOLD := Color("e7cc88")
const WHITE := Color("edf5ff")
var _background_layers: Array[Control] = []
var _voice_detached := false
var _voice_tail_released := false

func _ready() -> void:
	# All four background passes sit behind the template's card and untouched portrait.
	for spec: Array in [["BaseLayer", _draw_base], ["PatternLayer", _draw_pattern],
			["AuraLayer", _draw_aura], ["SpeedLineLayer", _draw_speed]]:
		var layer := Control.new()
		layer.name = spec[0]
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		layer.draw.connect(spec[1].bind(layer))
		_background_layers.append(layer)
	super._ready()
	_foreground.name = "FXLayer"

func _sync_visuals() -> void:
	super._sync_visuals()
	for layer: Control in _background_layers:
		layer.queue_redraw()

func hold_for_voice() -> void:
	# Keep the 0.39 s hero hold; the voice tail must not postpone the attack.
	pass

func start_voice() -> void:
	if voice == null or _voice_started: return
	# Move the idle player before playback so scene removal cannot interrupt it.
	# The battle layer owns the complete voice, including its tail over the attack.
	voice_player.reparent(get_parent())
	_voice_detached = true
	super.start_voice()

func release_voice_tail() -> void:
	if not _voice_detached: return
	_voice_tail_released = true
	if voice_player.playing:
		voice_player.finished.connect(voice_player.queue_free, CONNECT_ONE_SHOT)
	else:
		voice_player.queue_free()

func _exit_tree() -> void:
	# An interrupted cinematic has not handed off its voice; clean it up too.
	if _voice_detached and not _voice_tail_released and is_instance_valid(voice_player):
		voice_player.stop()
		voice_player.queue_free()

func _panel_strength() -> float:
	return _out(_progress(phase_time, 0.58, 0.91)) * (1.0 - _out(_progress(phase_time, 1.49, 1.95)))

func _color(ink: Color, opacity: float) -> Color:
	return Color(ink, opacity)

func _begin_panel(layer: Control) -> float:
	var strength := _panel_strength()
	layer.draw_set_transform(Vector2(0, lerpf(470.0, 0.0, strength)), 0, Vector2(1, strength))
	return strength

func _edge_y(x: float, lower: bool) -> float:
	return lerpf(910.0, 800.0, x / 1920.0) if lower else lerpf(115.0, 25.0, x / 1920.0)

func _draw_base(layer: Control) -> void:
	var p := _begin_panel(layer)
	if p <= 0.001: return
	# Four gradient stops, rather than an ice-blue flat wash.
	var stops := [0.0, 0.24, 0.60, 1.0]
	var inks := [Color(0.045, 0.060, 0.18, 0.98), Color(0.075, 0.115, 0.30, 0.96),
		Color(0.040, 0.070, 0.18, 0.91), Color(0.018, 0.029, 0.08, 0.76)]
	for i: int in range(3):
		var a: float = stops[i]
		var b: float = stops[i + 1]
		var ca: Color = inks[i]
		var cb: Color = inks[i + 1]
		ca.a *= p
		cb.a *= p
		layer.draw_polygon(PackedVector2Array([Vector2(0, lerpf(115, 910, a)), Vector2(1920, lerpf(25, 800, a)),
			Vector2(1920, lerpf(25, 800, b)), Vector2(0, lerpf(115, 910, b))]), PackedColorArray([ca, ca, cb, cb]))
	# Broad indigo folds add depth without competing with the armor silhouette.
	for i: int in range(8):
		var y := 165.0 + i * 82.0
		layer.draw_colored_polygon(PackedVector2Array([Vector2(0, y), Vector2(1920, y - 96),
			Vector2(1920, y - 78), Vector2(0, y + 30)]), Color(0.23, 0.29, 0.53, p * 0.045))
	for lower: bool in [false, true]:
		var a := Vector2(0, _edge_y(0, lower))
		var b := Vector2(1920, _edge_y(1920, lower))
		layer.draw_line(a, b, _color(GOLD, p * 0.10), 9, true)
		layer.draw_line(a, b, _color(GOLD, p * 0.68), 1.8, true)
		var offset := Vector2(0, -8 if lower else 8)
		layer.draw_line(a + offset, b + offset, Color(0.64, 0.78, 0.97, p * 0.26), 1, true)

func _draw_pattern(layer: Control) -> void:
	var p := _begin_panel(layer)
	if p <= 0.001: return
	var ink := _color(GOLD, p * 0.16)
	# A single quiet war-banner crest; no title or text overlay.
	layer.draw_line(Vector2(1514, 145), Vector2(1514, 704), ink, 3, true)
	var banner := PackedVector2Array([Vector2(1527, 174), Vector2(1707, 165), Vector2(1707, 534),
		Vector2(1617, 500), Vector2(1527, 549), Vector2(1527, 174)])
	layer.draw_colored_polygon(banner, Color(0.25, 0.32, 0.50, p * 0.085))
	layer.draw_polyline(banner, ink, 2, true)
	layer.draw_string(CREST_FONT, Vector2(1550, 379), "毘", HORIZONTAL_ALIGNMENT_LEFT, -1, 132, _color(GOLD, p * 0.19))
	# Fainter, oversized crest on the opposite flank balances the banner.
	layer.draw_string(CREST_FONT, Vector2(124, 425), "毘", HORIZONTAL_ALIGNMENT_LEFT, -1, 212, _color(GOLD, p * 0.07))
	# Five-tier sacred pagoda in outline, set apart from the hero.
	var center := 1786.0
	layer.draw_line(Vector2(center, 393), Vector2(center, 460), ink, 1.5, true)
	layer.draw_circle(Vector2(center, 414), 4, ink)
	for tier: int in range(5):
		var y := 465.0 + tier * 50.0
		var width := 42.0 + tier * 9.0
		layer.draw_polyline(PackedVector2Array([Vector2(center - width, y + 12), Vector2(center - width * 0.6, y + 2),
			Vector2(center, y - 16), Vector2(center + width * 0.6, y + 2), Vector2(center + width, y + 12)]), ink, 2, true)
		layer.draw_line(Vector2(center - width * 0.62, y + 15), Vector2(center - width * 0.62, y + 38), ink, 1, true)
		layer.draw_line(Vector2(center + width * 0.62, y + 15), Vector2(center + width * 0.62, y + 38), ink, 1, true)
		layer.draw_line(Vector2(center - width * 0.72, y + 39), Vector2(center + width * 0.72, y + 39), ink, 1, true)
	# Restrained sashiko-like diamond rhythm along the upper band.
	for i: int in range(18):
		var x := 30.0 + i * 108.0
		var y := _edge_y(x, false) + 28
		layer.draw_polyline(PackedVector2Array([Vector2(x, y - 8), Vector2(x + 14, y), Vector2(x, y + 8),
			Vector2(x - 14, y), Vector2(x, y - 8)]), _color(GOLD, p * 0.12), 1, true)

func _draw_aura(layer: Control) -> void:
	var p := _begin_panel(layer) * _out(_progress(phase_time, 0.62, 1.02))
	if p <= 0.001: return
	var center := Vector2(820, 357)
	var growth := lerpf(0.86, 1.0, _out(_progress(phase_time, 0.62, 1.08)))
	layer.draw_set_transform(Vector2(0, lerpf(470.0, 0.0, _panel_strength())) + center * Vector2(1, _panel_strength()),
		0, Vector2(growth, growth * _panel_strength()))
	# A warm, soft core and thin ritual rings read as divine protection.
	for i: int in range(14, 0, -1):
		layer.draw_circle(Vector2.ZERO, 100 + i * 10, _color(GOLD, p * 0.008))
	for spec: Vector2 in [Vector2(201, 0.20), Vector2(223, 0.50), Vector2(233, 0.24)]:
		layer.draw_arc(Vector2.ZERO, spec.x, 0, TAU, 128, _color(GOLD, p * spec.y), 1.5, true)
	for i: int in range(48):
		var angle := i * TAU / 48.0 + phase_time * 0.035
		var direction := Vector2.from_angle(angle)
		var tangent := direction.orthogonal()
		var outer := 260.0 if i % 4 == 0 else 245.0
		layer.draw_colored_polygon(PackedVector2Array([direction * 148 - tangent * 2.5,
			direction * outer, direction * 148 + tangent * 2.5]), _color(GOLD, p * (0.22 if i % 4 == 0 else 0.10)))
		layer.draw_line(direction * 210, direction * outer, _color(WHITE if i % 4 == 0 else GOLD, p * 0.38), 1, true)
	for i: int in range(8):
		var direction := Vector2.from_angle(i * TAU / 8.0)
		var tangent := direction.orthogonal()
		var at := direction * 223
		layer.draw_polyline(PackedVector2Array([at - direction * 6, at + tangent * 4, at + direction * 6,
			at - tangent * 4, at - direction * 6]), _color(GOLD, p * 0.65), 1.5, true)

func _draw_speed(layer: Control) -> void:
	var p := _begin_panel(layer)
	if p <= 0.001: return
	var surge := _out(_progress(phase_time, 0.58, 0.95))
	# Slower broad streaks behind faster hairline trails, both behind the portrait.
	for depth: int in range(2):
		for i: int in range(24 if depth == 0 else 32):
			var seed := fmod(float(i) * 0.618034 + depth * 0.27, 1.0)
			var x := fposmod(i * 239.0 + phase_time * (620 + depth * 1280 + seed * 540), 2540.0) - 380
			var y := lerpf(155, 755, seed) - x * 0.047
			var start := Vector2(x, y)
			var end := start + Vector2(140 + seed * (210 + depth * 110), -12 - seed * 10)
			var ink := Color(0.35, 0.56, 0.95) if depth == 0 else WHITE
			if depth == 1 and i % 9 == 0: ink = GOLD
			var alpha := (0.035 + surge * 0.07) if depth == 0 else (0.10 + surge * 0.30)
			layer.draw_line(start, end, _color(ink, p * alpha), 7 if depth == 0 else 1.3, true)

func _draw() -> void:
	# Keep the card's original local charge pool, using indigo rather than frost.
	if phase_time <= 0 or phase_time >= 1.95: return
	var rise := _out(_progress(phase_time, 0, 0.32))
	for i: int in range(18, 0, -1):
		draw_circle(_card_center, 75 + i * 17, Color(0.15, 0.20, 0.51, rise * (1 - _panel_strength()) * 0.009))
	var charge := _progress(phase_time, 0.30, 0.55) * (1 - _progress(phase_time, 0.55, 0.80))
	for i: int in range(3):
		draw_arc(_card_center, 240 + i * 12, clock * 0.8 + i * 2.1, clock * 0.8 + i * 2.1 + 1.8,
			48, _color(GOLD if i == 0 else WHITE, charge * (0.36 - i * 0.09)), 1.5, true)

func _draw_foreground() -> void:
	var t := phase_time
	if t >= 0.36 and t < 0.70:
		var strength := _progress(t, 0.36, 0.54) * (1.0 - _progress(t, 0.58, 0.70))
		var points := PackedVector2Array()
		for i: int in range(25):
			var y := float(i) / 24.0
			var x := 0.50 + 0.075 * sin(y * 17) + 0.025 * sin(y * 43)
			points.append(_card_center + Vector2((x - 0.5) * _card_size.x, (y - 0.5) * _card_size.y))
		_foreground.draw_polyline(points, _color(GOLD, strength * 0.12), 20, true)
		_foreground.draw_polyline(points, _color(GOLD, strength * 0.52), 7, true)
		_foreground.draw_polyline(points, _color(WHITE, strength), 2.6, true)
	# 140 ms gold-white sweep starts on the same 0.54 s fracture cue as SplitSFX.
	var sweep := _progress(t, 0.54, 0.68)
	if sweep > 0 and sweep < 1:
		var head := Vector2(690, lerpf(825, 130, sweep))
		var tail := head + Vector2(-170, 145)
		var strength := sin(PI * sweep)
		_foreground.draw_line(tail, head, _color(GOLD, strength * 0.12), 34, true)
		_foreground.draw_line(tail, head, _color(GOLD, strength * 0.66), 10, true)
		_foreground.draw_line(tail, head, _color(WHITE, strength * 0.95), 2.8, true)
	# Eight card shards and twelve energy motes originate along the tear seam.
	var debris := _progress(t, 0.54, 1.08)
	if debris > 0 and debris < 1:
		for i: int in range(20):
			var side := -1.0 if i % 2 == 0 else 1.0
			var seed := fmod(i * 0.618034, 1.0)
			var origin := Vector2(690, 330 + seed * 340)
			var direction := Vector2(side, (seed - 0.5) * 1.4).normalized()
			var at := origin + direction * _out(debris) * (180 + seed * 300)
			var alpha := pow(1 - debris, 1.5)
			if i < 8:
				var tangent := direction.orthogonal()
				_foreground.draw_colored_polygon(PackedVector2Array([at + direction * 9, at - direction * 7 + tangent * 4,
					at - direction * 4 - tangent * 3]), _color(GOLD if i % 3 == 0 else WHITE, alpha * 0.74))
			else:
				_foreground.draw_line(at - direction * 12, at, _color(GOLD if i % 4 == 0 else WHITE, alpha * 0.65), 1.4, true)
	# Sparse near-plane trails live at the frame's margins, clear of face and armor.
	var panel := _panel_strength()
	if panel > 0:
		for i: int in range(6):
			var x := fposmod(i * 377.0 + t * 2700, 2500.0) - 400
			var y := (173.0 if i % 2 == 0 else 792.0) - x * 0.047
			_foreground.draw_line(Vector2(x, y), Vector2(x + 360, y - 18), _color(GOLD if i == 0 else WHITE, panel * 0.38), 2, true)
	var slash := _progress(t, 1.54, 1.95)
	if slash > 0 and slash < 1:
		var head := Vector2(lerpf(-300, 2360, _out(slash)), lerpf(650, 270, _out(slash)))
		var tail := head - Vector2(1050, -150)
		var strength := sin(PI * slash)
		_foreground.draw_line(tail, head, _color(GOLD, strength * 0.10), 42, true)
		_foreground.draw_line(tail, head, _color(GOLD, strength * 0.32), 12, true)
		_foreground.draw_colored_polygon(PackedVector2Array([tail + Vector2(0, 4), head, tail - Vector2(0, 4)]), _color(WHITE, strength))
