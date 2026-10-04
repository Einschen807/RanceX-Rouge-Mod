extends OriginalFlatPlayer
class_name BattleAttackEffect
## The native sprite tracks are retained; these particles replace ELK emitters
## that the FLAT sprite player does not implement, using the original textures.
var ranged := false

func _ready() -> void:
	project_tilt = true
	super._ready()
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend

func _process(delta: float) -> void:
	super._process(delta)
	queue_redraw()

func _draw() -> void:
	if _root == null: return
	var t := float(ticks) / fps
	if ranged:
		var arrow: Texture2D = _textures.get("箭矢Ｃ.png")
		if arrow == null: return
		for i: int in range(9):
			var phase := (t - float(i % 3) * 0.045) / 0.31
			if phase < 0 or phase > 1: continue
			var angle := -2.9 + i * 2.39996
			var direction := Vector2.from_angle(angle)
			var head := direction * lerpf(610, 0, phase)
			var tail := head + direction * 240
			var tint := Color(1, 0.65, 0.83, sin(phase * PI)) if i % 2 == 0 else Color(1, 0.85, 0.34, sin(phase * PI))
			draw_line(tail, head, tint, 4, true)
			draw_set_transform(head, angle + PI / 2.0, Vector2(0.75, 1.4))
			draw_texture_rect(arrow, Rect2(-16, -128, 32, 128), false, tint)
			draw_set_transform(Vector2.ZERO)
	var start := 0.4 if ranged else 0.53
	var p := (t - start) / 0.4
	if p < 0 or p > 1: return
	var spark: Texture2D = _textures.get("子弹B.png")
	if spark == null: return
	for i: int in range(18):
		var angle := float(i) * 2.39996
		var radius := (90.0 + float(i % 5) * 37.0) * p
		var point := Vector2.from_angle(angle) * radius
		draw_set_transform(point, angle - PI / 2, Vector2.ONE)
		draw_texture_rect(spark, Rect2(-3, -25, 6, 50), false, Color(1, 0.66, 0.77, 1.0 - p))
	draw_set_transform(Vector2.ZERO)
