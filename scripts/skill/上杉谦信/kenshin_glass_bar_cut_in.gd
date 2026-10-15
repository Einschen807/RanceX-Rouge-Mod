extends Control
## Independent face-strip cut-in. The battle hands off to attack_effect_started()
## when the first native attack is created; damage remains on the native hit frame.
const PORTRAIT_MATERIAL := preload("res://shaders/cut_in_burst_portrait.gdshader")
const PANEL_MATERIAL := preload("res://shaders/kenshin_glass_panel.gdshader")
const GOLD := Color("e6cc92")
const ICE := Color("b9eaff")
const HIT := Vector2(960, 350)
const CENTER := Vector2(960, 482.5)
const CARD_SIZE := Vector2(240, 360)
const CREST_CENTER := Vector2(1630, 426)
const CREST_RADIUS := 158.0
var _panel := PackedVector2Array()
@export var portrait: Texture2D
@export var voice: AudioStream
@export var phase_time := 0.0
var _source: CardWidget
var _surface: SubViewport
var _glass_surface: SubViewport
var _panel_material: ShaderMaterial
var _art: Control
var _face: Polygon2D
var _strip: TextureRect
var _card_snapshot: SubViewport
var _moving_card: TextureRect
var _source_center := Vector2(960, 760)
var _source_scale := 1.15
var _fragments: Array[Dictionary] = []
var _fracture := -1.0
var _voice_started := false
var _rng := RandomNumberGenerator.new()
@onready var voice_player: AudioStreamPlayer = $Voice
@onready var glass_player: AudioStreamPlayer = $GlassSFX

func configure_source(card: CardWidget) -> void:
	_source = card
	if is_instance_valid(card):
		_source_center = card.get_global_transform() * Vector2(104, 156)
		_source_scale = card.scale.x

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 5102
	# This outline also clips the glass cells, so shattered edges match the intact bar.
	for i: int in range(49):
		var x := lerpf(-24.0, 1944.0, i / 48.0)
		_panel.append(Vector2(x, _panel_edge_y(x, false)))
	for i: int in range(48, -1, -1):
		var x := lerpf(-24.0, 1944.0, i / 48.0)
		_panel.append(Vector2(x, _panel_edge_y(x, true)))
	voice_player.stream = voice
	voice_player.bus = &"Voice"
	glass_player.bus = &"SFX"
	_surface = SubViewport.new()
	_surface.name = "GlassSurface"
	_surface.size = Vector2i(1920, 1080)
	_surface.transparent_bg = true
	_surface.gui_disable_input = true
	_surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_surface)
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(_art)
	_art.draw.connect(_draw_panel)
	# Clip the actual face artwork to the same slanted glass boundary.
	_face = Polygon2D.new()
	_face.polygon = _panel
	_face.texture = portrait
	var ink := ShaderMaterial.new()
	ink.shader = PORTRAIT_MATERIAL
	ink.set_shader_parameter("reveal", 1.0)
	ink.set_shader_parameter("black_matte", true)
	_face.material = ink
	_art.add_child(_face)
	var glaze := Control.new()
	glaze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(glaze)
	glaze.draw.connect(_draw_glaze.bind(glaze))
	# Bake the curved reveal into its own texture; the strip and every shard share it.
	_glass_surface = SubViewport.new()
	_glass_surface.name = "CurvedGlassSurface"
	_glass_surface.size = Vector2i(1920, 1080)
	_glass_surface.transparent_bg = true
	_glass_surface.gui_disable_input = true
	_glass_surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_glass_surface)
	var masked_image := TextureRect.new()
	masked_image.size = Vector2(1920, 1080)
	masked_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	masked_image.texture = _surface.get_texture()
	_panel_material = ShaderMaterial.new()
	_panel_material.shader = PANEL_MATERIAL
	masked_image.material = _panel_material
	_glass_surface.add_child(masked_image)
	_strip = TextureRect.new()
	_strip.name = "FaceStrip"
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.texture = _glass_surface.get_texture()
	_strip.size = Vector2(1920, 1080)
	_strip.pivot_offset = CENTER
	add_child(_strip)
	_build_card()
	_build_fragments()
	if is_instance_valid(_source): _source.hide()
	_sync_strip()

func _process(delta: float) -> void:
	if _fracture >= 0.0:
		_fracture += delta
		_sync_fragments()
		if _fracture > 0.82 and not voice_player.playing:
			queue_free()
	else:
		_sync_strip()
		_art.queue_redraw()
		_art.get_child(1).queue_redraw()
	queue_redraw()

func start_voice() -> void:
	if _voice_started or voice == null: return
	_voice_started = true
	voice_player.play()

func attack_effect_started(_at: Vector2) -> void:
	if _fracture >= 0.0: return
	# Freeze the exact face strip so every shard carries its own matching pixels.
	_surface.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_glass_surface.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_fracture = 0.0
	# The newly created native attack now draws over the glass, selling the cut.
	z_index = 0
	_strip.hide()
	glass_player.play()
	_sync_fragments()

func _sync_strip() -> void:
	# Hold a readable hairline, then open smoothly without stretch or rebound.
	var opening := lerpf(0.002, 1.0, smoothstep(0.06, 0.50, phase_time))
	_panel_material.set_shader_parameter("opening", opening)
	# Each column opens around its own slanted centerline, keeping the curved silhouette.
	_strip.scale = Vector2.ONE
	_strip.position = Vector2.ZERO
	_strip.modulate.a = 1.0
	_sync_portrait()
	_sync_card()

func _sync_portrait() -> void:
	# Move the artwork inside a fixed glass boundary, keeping its edges clipped.
	var travel := 1.0 - pow(1.0 - clampf((phase_time - 0.10) / 0.40, 0.0, 1.0), 3.0)
	var origin_x := lerpf(1000.0, -570.0, travel) - maxf(0.0, phase_time - 0.50) * 70.0
	var uv := PackedVector2Array()
	for point: Vector2 in _panel:
		uv.append((point - Vector2(origin_x, -105)) / 2.2)
	_face.uv = uv

func _build_card() -> void:
	# Snapshot the complete acting card, preserving its actual upgrades and costs.
	_card_snapshot = SubViewport.new()
	_card_snapshot.name = "ActingCardSnapshot"
	_card_snapshot.size = Vector2i(416, 624)
	_card_snapshot.transparent_bg = true
	_card_snapshot.gui_disable_input = true
	_card_snapshot.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_card_snapshot)
	var card := CardWidget.new()
	if is_instance_valid(_source):
		card.setup(_source.card, _source.troop, false, _source.detail_mode, _source.preview_upgrades)
		card.portrait_only = _source.portrait_only
		card.skill_costs = _source.skill_costs.duplicate()
	else:
		var catalog := CardCatalog.new()
		catalog.load_catalog()
		var troop := TroopState.new()
		troop.configure(catalog, true)
		card.setup(catalog.find_name("Lv43 上杉谦信"), troop, false, 0)
	card.scale = Vector2.ONE * 2.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_snapshot.add_child(card)
	for decoration: String in ["LeaderBadge", "LeaderGlow"]:
		if card.visual.has_node(decoration): card.visual.get_node(decoration).hide()
	_moving_card = TextureRect.new()
	_moving_card.name = "CardIntoGlass"
	_moving_card.texture = _card_snapshot.get_texture()
	_moving_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_moving_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_moving_card)

func _sync_card() -> void:
	if _moving_card == null: return
	var progress := clampf((phase_time - 0.04) / 0.24, 0.0, 1.0)
	var travel := 1.0 - pow(1.0 - progress, 3.0)
	_moving_card.size = (Vector2(208, 312) * _source_scale).lerp(CARD_SIZE, travel)
	_moving_card.pivot_offset = _moving_card.size * 0.5
	_moving_card.position = _source_center.lerp(CENTER, travel) - _moving_card.size * 0.5
	_moving_card.rotation = 0.0
	if phase_time >= 0.50 and _moving_card.get_parent() != _art:
		# Once settled, card and bar become one surface and share the same fractures.
		_moving_card.reparent(_art, false)
		_moving_card.position = CENTER - CARD_SIZE * 0.5

func _draw() -> void:
	var dim := clampf(phase_time / 0.20, 0.0, 1.0) * 0.42
	if _fracture >= 0.0: dim *= 1.0 - clampf(_fracture / 0.28, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.005, 0.009, 0.025, dim))
	if _fracture < 0.0: return
	var flash := 1.0 - clampf(_fracture / 0.095, 0.0, 1.0)
	# A local slash and a short core flash, leaving the battle readable.
	if flash > 0.0:
		draw_line(Vector2(505, 790), Vector2(1420, 75), Color(0.42, 0.77, 1.0, flash * 0.32), 25, true)
		draw_line(Vector2(505, 790), Vector2(1420, 75), Color(0.94, 0.99, 1.0, flash), 4, true)
		draw_circle(HIT, 120.0 * (1.0 - flash) + 12.0, Color(0.8, 0.94, 1.0, flash * 0.38))
	var dust := clampf(_fracture / 0.12, 0.0, 1.0) * (1.0 - clampf((_fracture - 0.18) / 0.44, 0.0, 1.0))
	for i: int in range(26):
		var angle := i * 2.39996
		var direction := Vector2.from_angle(angle)
		var point := HIT + direction * (80.0 + _fracture * (350.0 + i * 19.0))
		draw_line(point, point - direction * (8.0 + i % 5 * 6.0), Color(ICE if i % 4 else GOLD, dust * 0.8), 1.6, true)

func _draw_panel() -> void:
	# Decorations are masked together after compositing, avoiding stray lines outside the bar.
	_art.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(1920, 0), Vector2(1920, 1080), Vector2(0, 1080)]), PackedColorArray([
		Color("060f34"), Color("162e67"), Color("08172e"), Color("18254d")]))
	# Long indigo facets, with a quiet gold military motif at the right flank.
	for i: int in range(9):
		var x := -230.0 + i * 285.0
		_art.draw_colored_polygon(PackedVector2Array([Vector2(x, 345 - x * 0.067),
			Vector2(x + 170, 333 - x * 0.067), Vector2(x + 690, 712 - x * 0.067),
			Vector2(x + 510, 724 - x * 0.067)]), Color(0.23, 0.39, 0.66, 0.16))
	for i: int in range(48):
		var x := fposmod(i * 173.0 - phase_time * (1500.0 + i % 3 * 650), 2300.0) - 200
		var y := 355.0 + fposmod(i * 59.0, 375.0) - x * 0.067
		_art.draw_line(Vector2(x, y), Vector2(x + 90 + i % 6 * 37, y - 10),
			Color(ICE if i % 6 else GOLD, 0.10 if i % 3 else 0.30), 1.2 if i % 4 else 2.8, true)
	# Curved rising streams add a second motion direction behind the hero and card.
	for i: int in range(24):
		var x := 25.0 + i * 83.0
		var head_y := 760.0 - fposmod(i * 117.0 + phase_time * (660.0 + i % 4 * 170), 600.0)
		var length := 66.0 + i % 5 * 23.0
		var path := PackedVector2Array()
		for step: int in range(8):
			var along := step / 7.0
			var y := head_y + length * (1.0 - along)
			var point := Vector2(x + sin(along * PI) * (12.0 + i % 3 * 6.0), y)
			if Geometry2D.is_point_in_polygon(point, _panel):
				path.append(point)
		if path.size() > 1:
			_art.draw_polyline(path, Color(ICE if i % 5 else GOLD, 0.17 if i % 3 else 0.29), 1.1 if i % 4 else 2.0, true)
	_draw_crest()

func _crest_opacity() -> float:
	# Finish the fade exactly when both panel edges have opened past the whole crest.
	var opening := float(_panel_material.get_shader_parameter("opening"))
	var clearance := minf(CREST_CENTER.y - _panel_edge_y(CREST_CENTER.x, false, opening),
		_panel_edge_y(CREST_CENTER.x, true, opening) - CREST_CENTER.y)
	return smoothstep(0.04, 1.0, clearance / CREST_RADIUS)

func _draw_crest() -> void:
	var opacity := _crest_opacity()
	if opacity <= 0.001: return
	# Positive rotation is clockwise on the canvas. The glyph itself stays upright.
	_art.draw_set_transform(CREST_CENTER, phase_time * 0.16)
	for radius: float in [152.0, CREST_RADIUS]:
		_art.draw_arc(Vector2.ZERO, radius, 0, TAU, 144, Color(GOLD, opacity * 0.46), 1.0, true)
	for i: int in range(72):
		var direction := Vector2.from_angle(i * TAU / 72.0)
		var major := i % 6 == 0
		_art.draw_line(direction * (139.0 if major else 146.0), direction * 151.0,
			Color(GOLD, opacity * (0.64 if major else 0.36)), 1.25 if major else 0.8, true)
	# Fine angular meanders echo traditional key-pattern ornament rather than fake lettering.
	for i: int in range(12):
		var radial := Vector2.from_angle(i * TAU / 12.0)
		var tangent := radial.orthogonal()
		var meander := PackedVector2Array()
		for offset: Vector2 in [Vector2(-8, -5), Vector2(8, -5), Vector2(8, 5),
				Vector2(-3, 5), Vector2(-3, 0), Vector2(2, 0)]:
			meander.append(radial * (131.0 + offset.y) + tangent * offset.x)
		_art.draw_polyline(meander, Color(GOLD, opacity * 0.48), 1.0, true)
	_art.draw_set_transform(CREST_CENTER, -phase_time * 0.22)
	for radius: float in [110.0, 116.0]:
		_art.draw_arc(Vector2.ZERO, radius, 0, TAU, 112, Color(GOLD, opacity * 0.46), 0.9, true)
	for i: int in range(48):
		var radial := Vector2.from_angle(i * TAU / 48.0)
		_art.draw_line(radial * (99.0 if i % 6 == 0 else 105.0), radial * 109.0,
			Color(GOLD, opacity * 0.38), 0.9, true)
	for i: int in range(8):
		var radial := Vector2.from_angle(i * TAU / 8.0)
		var tangent := radial.orthogonal()
		# Small diamonds separate the rings; quiet lotus petals sit behind the character.
		_art.draw_polyline(PackedVector2Array([radial * 111, radial * 116 + tangent * 4,
			radial * 121, radial * 116 - tangent * 4, radial * 111]), Color(GOLD, opacity * 0.60), 1, true)
		_art.draw_polyline(PackedVector2Array([radial * 82 - tangent * 7, radial * 95 - tangent * 12,
			radial * 104, radial * 95 + tangent * 12, radial * 82 + tangent * 7]), Color(GOLD, opacity * 0.22), 0.9, true)
	_art.draw_set_transform(Vector2.ZERO)
	_art.draw_string(preload("res://assets/fonts/card_text.tres"), Vector2(1559, 477), "毘",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 140, Color(GOLD, opacity * 0.46))

func _draw_glaze(glaze: Control) -> void:
	# Moving glass reflection stays narrow and never washes out the whole portrait.
	var sweep := lerpf(-600, 2500, clampf((phase_time - 0.12) / 0.78, 0.0, 1.0))
	var shine := PackedVector2Array([Vector2(sweep, 0), Vector2(sweep + 85, 0), Vector2(sweep - 500, 1080), Vector2(sweep - 585, 1080)])
	for clipped: PackedVector2Array in Geometry2D.intersect_polygons(shine, _panel):
		glaze.draw_colored_polygon(clipped, Color(0.7, 0.86, 1.0, 0.16))

func _panel_edge_y(x: float, lower: bool, opening: float = 1.0) -> float:
	var center_y := CENTER.y - (x - CENTER.x) * (133.0 / 1968.0)
	var half_height := 211.0 + 24.0 * pow((x - CENTER.x) / 960.0, 2.0)
	return center_y + half_height * opening * (1.0 if lower else -1.0)

func _clip_half_plane(poly: PackedVector2Array, midpoint: Vector2, normal: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i: int in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var da := (a - midpoint).dot(normal)
		var db := (b - midpoint).dot(normal)
		if da <= 0.0: result.append(a)
		if (da <= 0.0) != (db <= 0.0): result.append(a.lerp(b, da / (da - db)))
	return result

func _build_fragments() -> void:
	# Seeded Voronoi cells share exact edges, without a rectangular tile pattern.
	var seeds := PackedVector2Array()
	for row: int in range(4):
		for col: int in range(14):
			var x := col * 150.0 + _rng.randf_range(-45, 45)
			seeds.append(Vector2(x, 340.0 + row * 130.0 - x * 0.067 + _rng.randf_range(-48, 48)))
	for i: int in range(17):
		seeds.append(HIT + Vector2.from_angle(i * 2.39996) * _rng.randf_range(20, 195))
	for seed_point: Vector2 in seeds:
		var polygon := _panel.duplicate()
		for other: Vector2 in seeds:
			if seed_point == other: continue
			polygon = _clip_half_plane(polygon, (seed_point + other) * 0.5, other - seed_point)
			if polygon.size() < 3: break
		if polygon.size() < 3: continue
		var center := Vector2.ZERO
		for point: Vector2 in polygon: center += point
		center /= polygon.size()
		var local := PackedVector2Array()
		for point: Vector2 in polygon: local.append(point - center)
		var pivot := Node2D.new()
		pivot.position = center
		pivot.visible = false
		add_child(pivot)
		var piece := Polygon2D.new()
		piece.polygon = local
		piece.texture = _glass_surface.get_texture()
		piece.uv = polygon
		pivot.add_child(piece)
		var edge := Line2D.new()
		var outline := local.duplicate()
		outline.append(local[0])
		edge.points = outline
		edge.width = 1.3
		edge.default_color = Color(ICE, 0.85)
		edge.antialiased = true
		pivot.add_child(edge)
		var direction := (center - HIT).normalized()
		_fragments.append({"node": pivot, "center": center,
			"velocity": direction * _rng.randf_range(230, 620) + Vector2(_rng.randf_range(-75, 75), -100),
			"spin": _rng.randf_range(-2.8, 2.8), "tumble": _rng.randf_range(2, 6),
			"edge": edge, "piece": piece})

func _sync_fragments() -> void:
	var fly := maxf(0.0, _fracture - 0.035)
	for shard: Dictionary in _fragments:
		var pivot: Node2D = shard.node
		pivot.visible = _fracture < 0.78
		pivot.position = shard.center + shard.velocity * fly + Vector2(0, 380 * fly * fly)
		pivot.rotation = shard.spin * fly
		pivot.scale = Vector2(maxf(0.12, absf(cos(fly * shard.tumble))), 1.0 - fly * 0.12)
		pivot.modulate.a = 1.0 - smoothstep(0.22, 0.75, _fracture)
		var glint := pow(maxf(0.0, cos(fly * shard.tumble * 2.0)), 10.0)
		shard.piece.modulate = Color(1.0 + glint * 0.6, 1.0 + glint * 0.7, 1.0 + glint * 0.8)
		shard.edge.modulate.a = 0.3 + glint * 0.7
		shard.edge.width = lerpf(2.8, 1.3, clampf(_fracture / 0.12, 0.0, 1.0))
