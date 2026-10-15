extends "res://scripts/skill/上杉谦信/kenshin_glass_bar_cut_in.gd"
## Independent 赤色死神 styling. The inherited glass/card timing remains unchanged.
const SCARLET := Color("d92f3e")
const EMBER := Color("ff8676")
const BONE := Color("e7e1d8")
const RICK_PORTRAIT := preload("res://shaders/rick_glass_portrait.gdshader")
func _ready() -> void:
	super._ready()
	var portrait_ink := ShaderMaterial.new()
	portrait_ink.shader = RICK_PORTRAIT
	_face.material = portrait_ink
	_panel_material.set_shader_parameter("edge_ink", Color("dfaaa1"))
	_panel_material.set_shader_parameter("inner_ink", EMBER)
	for shard: Dictionary in _fragments:
		shard.edge.default_color = Color(EMBER, 0.85)

func _build_card() -> void:
	if is_instance_valid(_source):
		super._build_card()
		return
	# The standalone preview must also use Rick's own complete card.
	var catalog := CardCatalog.new()
	catalog.load_catalog()
	var troop := TroopState.new()
	troop.configure(catalog, true)
	var fallback := CardWidget.new()
	fallback.setup(catalog.find_name("Lv58 里克"), troop, false, 0)
	_source = fallback
	super._build_card()
	_source = null
	fallback.free()

func _sync_portrait() -> void:
	var travel := 1.0 - pow(1.0 - clampf((phase_time - 0.10) / 0.40, 0.0, 1.0), 3.0)
	var origin_x := lerpf(650.0, -1180.0, travel) - maxf(0.0, phase_time - 0.50) * 70.0
	var uv := PackedVector2Array()
	for point: Vector2 in _panel:
		uv.append((point - Vector2(origin_x, -20)) / 2.1)
	_face.uv = uv

func _draw_panel() -> void:
	_art.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(1920, 0), Vector2(1920, 1080), Vector2(0, 1080)]),
		PackedColorArray([Color("17060d"), Color("430c1e"), Color("1c0810"), Color("320c18")]))
	# Deep flowing cloth folds traverse the full strip behind the armor.
	for i: int in range(7):
		var band := PackedVector2Array()
		var center_y := 310.0 + i * 65.0
		for j: int in range(33):
			var x := j * 64.0 - 64.0
			var y := center_y - x * 0.067 + sin(x * 0.005 + phase_time * 4.5 + i * 0.8) * 20.0
			band.append(Vector2(x, y))
		for j: int in range(32, -1, -1):
			var x := j * 64.0 - 64.0
			var y := center_y - x * 0.067 + sin(x * 0.005 + phase_time * 4.5 + i * 0.8) * 20.0
			band.append(Vector2(x, y + 25.0 + i % 3 * 9.0))
		_art.draw_colored_polygon(band, Color(SCARLET, 0.11 if i % 2 else 0.18))
	for i: int in range(48):
		var x := fposmod(i * 173.0 - phase_time * (1650.0 + i % 3 * 650), 2300.0) - 200.0
		var y := 355.0 + fposmod(i * 59.0, 375.0) - x * 0.067
		_art.draw_line(Vector2(x, y), Vector2(x + 110 + i % 6 * 37, y - 10),
			Color(BONE if i % 6 == 0 else EMBER, 0.24 if i % 3 == 0 else 0.11), 2.4 if i % 4 == 0 else 1.1, true)
	for i: int in range(24):
		var x := 20.0 + i * 83.0
		var head_y := 770.0 - fposmod(i * 117.0 + phase_time * (720.0 + i % 4 * 160), 600.0)
		var path := PackedVector2Array()
		for j: int in range(8):
			var along := j / 7.0
			path.append(Vector2(x + sin(along * PI) * 18.0, head_y + (1.0 - along) * (70 + i % 5 * 21)))
		_art.draw_polyline(path, Color(SCARLET if i % 4 else EMBER, 0.18), 1.2, true)
	_draw_crest()

func _draw_crest() -> void:
	var opacity := _crest_opacity()
	if opacity <= 0.001: return
	_art.draw_set_transform(CREST_CENTER)
	_draw_crest_smoke(opacity)
	_draw_reaper_contour(opacity)
	_draw_hidden_eyes(opacity)
	_draw_curse_ring(opacity)
	_art.draw_set_transform(CREST_CENTER + Vector2(0,22),0,Vector2(0.82,0.82))
	_draw_chi_brush(opacity)
	# Cloth is foreground; the face shadow and sockets stay behind the stable glyph.
	_draw_hood_foreground(opacity)
	_art.draw_set_transform(Vector2.ZERO)

func _crest_opacity() -> float:
	# The taller hood finishes fading only once its pointed outer contour fits the bar.
	var opening := float(_panel_material.get_shader_parameter("opening"))
	var clearance := minf(CREST_CENTER.y - _panel_edge_y(CREST_CENTER.x,false,opening),
		_panel_edge_y(CREST_CENTER.x,true,opening) - CREST_CENTER.y)
	return smoothstep(0.04,1.0,clearance / 216.0)

func _draw_chi_brush(opacity: float) -> void:
	# Seven hand-shaped strokes preserve 赤's structure while tapering into blade-like tips.
	var strokes: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-71,-76),Vector2(-44,-65),Vector2(72,-79),Vector2(66,-63),Vector2(53,-55),Vector2(-63,-57)]),
		PackedVector2Array([Vector2(-9,-109),Vector2(17,-96),Vector2(10,-34),Vector2(-5,-23),Vector2(-13,-30)]),
		PackedVector2Array([Vector2(-99,-40),Vector2(-72,-31),Vector2(98,-48),Vector2(88,-31),Vector2(75,-21),Vector2(-90,-17)]),
		PackedVector2Array([Vector2(-20,-25),Vector2(-2,-28),Vector2(-6,14),Vector2(-13,47),Vector2(-34,75),Vector2(-83,105),Vector2(-69,84),Vector2(-47,64),Vector2(-29,33),Vector2(-23,6)]),
		PackedVector2Array([Vector2(25,-28),Vector2(47,-31),Vector2(43,57),Vector2(35,77),Vector2(15,88),Vector2(-8,80),Vector2(-17,67),Vector2(16,72),Vector2(22,62)]),
		PackedVector2Array([Vector2(-64,-7),Vector2(-46,2),Vector2(-61,38),Vector2(-96,59),Vector2(-80,36),Vector2(-72,21)]),
		PackedVector2Array([Vector2(62,-9),Vector2(78,3),Vector2(102,57),Vector2(82,43),Vector2(72,37),Vector2(58,6)])]
	for stroke: PackedVector2Array in strokes:
		var shadow := PackedVector2Array()
		for point: Vector2 in stroke: shadow.append(point + Vector2(3,4))
		_art.draw_colored_polygon(shadow, Color(0.035,0.002,0.009,opacity * 0.85))
		_art.draw_colored_polygon(stroke, Color("ffaaa0") * Color(1,1,1,opacity * 0.88))
		var rim := stroke.duplicate()
		rim.append(stroke[0])
		_art.draw_polyline(rim, Color(EMBER,opacity * 0.66),0.8,true)
	# Sparse dry-brush cuts and bright leading edges keep the strokes from looking typeset.
	_art.draw_line(Vector2(-44,-67),Vector2(55,-71),Color(BONE,opacity * 0.48),1,true)
	_art.draw_line(Vector2(-67,-29),Vector2(70,-37),Color(BONE,opacity * 0.48),1,true)
	_art.draw_line(Vector2(34,-19),Vector2(30,42),Color(BONE,opacity * 0.34),0.8,true)
	_art.draw_colored_polygon(PackedVector2Array([Vector2(-59,-58),Vector2(-38,-64),
		Vector2(-49,-58)]),Color("4c0a18") * Color(1,1,1,opacity * 0.80))
	_art.draw_colored_polygon(PackedVector2Array([Vector2(26,31),Vector2(43,20),
		Vector2(40,26),Vector2(26,34)]),Color("4c0a18") * Color(1,1,1,opacity * 0.80))

func _draw_curse_ring(opacity: float) -> void:
	# Only three quiet broken arcs and six marks; the hood silhouette carries the design.
	_art.draw_set_transform(CREST_CENTER, -phase_time * 0.48)
	for i: int in range(3):
		var angle := i * TAU / 3.0
		_art.draw_arc(Vector2.ZERO,111,angle + 0.20,angle + 1.15,28,
			Color(EMBER,opacity * 0.12),0.7,true)
	for i: int in range(6):
		var radial := Vector2.from_angle(i * TAU / 6.0)
		var tangent := radial.orthogonal()
		_art.draw_polyline(PackedVector2Array([radial * 106 - tangent * 3,
			radial * 100 + tangent * 2,radial * 97 - tangent * 2]),
			Color(EMBER,opacity * 0.17),0.75,true)

func _hood_transform() -> void:
	# Subtle breathing belongs to the cloth; the central lettering remains still.
	var breath := sin(phase_time * 3.2)
	_art.draw_set_transform(CREST_CENTER,0,Vector2(1.0 + breath * 0.007,1.0 + breath * 0.004))

func _draw_reaper_contour(opacity: float) -> void:
	_hood_transform()
	var left_drift := sin(phase_time * 3.1 + 0.3) * 7.0
	var middle_drift := sin(phase_time * 2.7 + 1.4) * 6.0
	var right_drift := sin(phase_time * 3.4 + 2.2) * 9.0
	# Unequal lengths, torn notches and bent tips read as cloth instead of three pendants.
	var left_hem := PackedVector2Array([Vector2(-127,28),Vector2(-75,84),
		Vector2(-88,117),Vector2(-106 + left_drift,145),Vector2(-128 + left_drift,168),
		Vector2(-119 + left_drift,136),Vector2(-139 + left_drift,148),
		Vector2(-125,111),Vector2(-137,79)])
	var middle_hem := PackedVector2Array([Vector2(-57,108),Vector2(42,109),
		Vector2(29,151),Vector2(12 + middle_drift,180),Vector2(21 + middle_drift,194),
		Vector2(-17 + middle_drift,215),Vector2(-6 + middle_drift,184),
		Vector2(-34 + middle_drift,194),Vector2(-24,158),Vector2(-43,145)])
	var right_hem := PackedVector2Array([Vector2(76,65),Vector2(117,41),
		Vector2(128,101),Vector2(110 + right_drift,132),Vector2(124 + right_drift,148),
		Vector2(83 + right_drift,183),Vector2(92 + right_drift,150),
		Vector2(74 + right_drift,158),Vector2(84,120)])
	for hem: PackedVector2Array in [left_hem,middle_hem,right_hem]:
		_art.draw_colored_polygon(hem,Color("641027") * Color(1,1,1,opacity * 0.96))
		_art.draw_polyline(hem,Color(SCARLET,opacity * 0.38),1.0,true)
	# The face is a shaded hollow, separate from the foreground cloth.
	var opening := PackedVector2Array([Vector2(-6,-78),Vector2(39,-106),
		Vector2(73,-83),Vector2(92,-25),Vector2(87,35),Vector2(53,94),
		Vector2(-8,120),Vector2(-62,93),Vector2(-94,31),Vector2(-96,-26),
		Vector2(-76,-75),Vector2(-35,-101)])
	for i: int in range(opening.size()):
		_art.draw_polygon(PackedVector2Array([Vector2(0,14),opening[i],opening[(i + 1) % opening.size()]]),
			PackedColorArray([Color("300919") * Color(1,1,1,opacity * 0.98),
				Color("08040b") * Color(1,1,1,opacity * 0.99),Color("08040b") * Color(1,1,1,opacity * 0.99)]))
	var mist := sin(phase_time * 2.0) * 5.0
	_art.draw_polygon(PackedVector2Array([Vector2(-71,39),Vector2(-23,12 + mist),
		Vector2(56,40),Vector2(64,71),Vector2(-6,95),Vector2(-68,72)]),
		PackedColorArray([Color(SCARLET,0),Color(SCARLET,opacity * 0.06),
			Color(SCARLET,0),Color(SCARLET,0),Color(SCARLET,opacity * 0.025),Color(SCARLET,0)]))

func _draw_hidden_eyes(opacity: float) -> void:
	_hood_transform()
	# A suggestion of a face under the brow; no literal skull or bright cartoon eyes.
	var sockets: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-77,-66),Vector2(-23,-48),Vector2(-34,-22),Vector2(-66,-36)]),
		PackedVector2Array([Vector2(24,-48),Vector2(75,-76),Vector2(62,-32),Vector2(34,-23)])]
	var glimmer := exp(-pow((phase_time - 0.72) / 0.10,2.0))
	for socket: PackedVector2Array in sockets:
		_art.draw_colored_polygon(socket,Color("030207") * Color(1,1,1,opacity * 0.95))
	_art.draw_colored_polygon(PackedVector2Array([Vector2(-71,-60),Vector2(-28,-46),
		Vector2(-38,-32),Vector2(-62,-40)]),Color("9a1731") * Color(1,1,1,opacity * (0.18 + glimmer * 0.24)))
	_art.draw_colored_polygon(PackedVector2Array([Vector2(30,-46),Vector2(68,-67),
		Vector2(58,-37),Vector2(36,-32)]),Color("9a1731") * Color(1,1,1,opacity * (0.18 + glimmer * 0.24)))

func _draw_hood_foreground(opacity: float) -> void:
	_hood_transform()
	# Two cloth panels leave the face hollow open, while covering any glyph overflow.
	var left := PackedVector2Array([Vector2(-18,-184),Vector2(-62,-146),
		Vector2(-103,-102),Vector2(-127,-39),Vector2(-133,40),Vector2(-116,93),
		Vector2(-63,135),Vector2(-8,143),Vector2(-8,120),Vector2(-62,93),
		Vector2(-94,31),Vector2(-96,-26),Vector2(-76,-75),Vector2(-35,-101),Vector2(-6,-78)])
	var right := PackedVector2Array([Vector2(-18,-184),Vector2(28,-166),
		Vector2(84,-120),Vector2(117,-59),Vector2(127,19),Vector2(113,91),
		Vector2(60,130),Vector2(-8,143),Vector2(-8,120),Vector2(53,94),
		Vector2(87,35),Vector2(92,-25),Vector2(73,-83),Vector2(39,-106),Vector2(-6,-78)])
	for cloth: PackedVector2Array in [left,right]:
		_art.draw_colored_polygon(cloth,Color("761329") * Color(1,1,1,opacity * 0.98))
	# Broad cel-shaded folds: dark outside, blood-red inner rim, deep shadow at the opening.
	_art.draw_colored_polygon(PackedVector2Array([Vector2(-18,-184),Vector2(-62,-146),
		Vector2(-103,-102),Vector2(-83,-84),Vector2(-35,-101),Vector2(-6,-78),
		Vector2(39,-106),Vector2(84,-120),Vector2(28,-166),Vector2(0,-137)]),
		Color("86172d") * Color(1,1,1,opacity * 0.95))
	_art.draw_colored_polygon(PackedVector2Array([Vector2(-103,-102),Vector2(-127,-39),
		Vector2(-133,40),Vector2(-116,93),Vector2(-63,135),Vector2(-84,100),
		Vector2(-111,28),Vector2(-110,-32)]),Color("390b1b") * Color(1,1,1,opacity * 0.90))
	_art.draw_colored_polygon(PackedVector2Array([Vector2(84,-120),Vector2(117,-59),
		Vector2(127,19),Vector2(113,91),Vector2(60,130),Vector2(84,87),
		Vector2(107,19),Vector2(101,-51)]),Color("470c20") * Color(1,1,1,opacity * 0.90))
	_art.draw_colored_polygon(PackedVector2Array([Vector2(-35,-101),Vector2(-76,-75),
		Vector2(-96,-26),Vector2(-94,31),Vector2(-62,93),Vector2(-8,120),
		Vector2(-21,131),Vector2(-73,105),Vector2(-107,35),Vector2(-108,-28),
		Vector2(-83,-84),Vector2(-38,-114)]),Color("ca293e") * Color(1,1,1,opacity * 0.90))
	_art.draw_colored_polygon(PackedVector2Array([Vector2(39,-106),Vector2(73,-83),
		Vector2(92,-25),Vector2(87,35),Vector2(53,94),Vector2(-8,120),
		Vector2(5,131),Vector2(65,102),Vector2(99,38),Vector2(105,-28),
		Vector2(82,-91),Vector2(41,-118)]),Color("b5233a") * Color(1,1,1,opacity * 0.88))
	# The low, hooked brow overlaps the top of 赤, joining letter and hood into one mark.
	_art.draw_colored_polygon(PackedVector2Array([Vector2(-83,-84),Vector2(-38,-114),
		Vector2(-6,-91),Vector2(41,-118),Vector2(82,-91),Vector2(39,-106),
		Vector2(-6,-63),Vector2(-35,-101),Vector2(-76,-75)]),
		Color("e43a4a") * Color(1,1,1,opacity * 0.92))
	_art.draw_polyline(PackedVector2Array([Vector2(-76,-75),Vector2(-35,-101),
		Vector2(-6,-63),Vector2(39,-106),Vector2(73,-83)]),Color("200717") * Color(1,1,1,opacity),3.0,true)

func _draw_crest_smoke(opacity: float) -> void:
	# A few broad shadows and red wisps support the silhouette without decorative clutter.
	for i: int in range(4):
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector2(side * (151.0 + i % 2 * 10.0),-20.0 + i * 46.0)
		at += Vector2(sin(phase_time * 2.1 + i) * 7.0,-phase_time * 9.0)
		for ring: int in range(3,0,-1):
			_art.draw_circle(at,14 + ring * 7,Color(Color("060308") if i < 2 else SCARLET,
				opacity * (0.035 if i < 2 else 0.016)))
	for i: int in range(4):
		var at := Vector2(-164.0 + i * 109.0,138.0 - fposmod(i * 57.0 + phase_time * 30.0,240.0))
		_art.draw_line(at,at + Vector2(2,-5),Color(EMBER,opacity * 0.25),1.1,true)

func _draw() -> void:
	var dim := clampf(phase_time / 0.20, 0.0, 1.0) * 0.45
	if _fracture >= 0.0: dim *= 1.0 - clampf(_fracture / 0.28, 0.0, 1.0)
	draw_rect(Rect2(0,0,1920,1080), Color(0.02,0.002,0.007,dim))
	if _fracture < 0.0: return
	var flash := 1.0 - clampf(_fracture / 0.095, 0.0, 1.0)
	if flash > 0.0:
		draw_line(Vector2(505,790),Vector2(1420,75),Color(SCARLET,flash * 0.42),25,true)
		draw_line(Vector2(505,790),Vector2(1420,75),Color(BONE,flash),4,true)
	var dust := clampf(_fracture / 0.12,0,1) * (1.0 - clampf((_fracture - 0.18) / 0.44,0,1))
	for i: int in range(26):
		var direction := Vector2.from_angle(i * 2.39996)
		var point := HIT + direction * (80.0 + _fracture * (350.0 + i * 19.0))
		draw_line(point,point - direction * (8 + i % 5 * 6),Color(BONE if i % 4 == 0 else EMBER,dust * 0.8),1.6,true)
