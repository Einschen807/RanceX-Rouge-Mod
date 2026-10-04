extends OriginalFlatPlayer
class_name BattleApEffect
## Retain the native flash/ring timeline and supply its unsupported ELK spark emitters.
var gaining := false
var _first_frame := true

func _process(delta: float) -> void:
	# A card rebuild can occupy the frame in which this burst was created.
	# Present its first frame before advancing by that frame's elapsed time.
	if _first_frame:
		_first_frame = false
		return
	super._process(delta)
	queue_redraw()
	if is_root_finished(): queue_free()

func _draw() -> void:
	var t := float(ticks) / fps - (0.23 if gaining else 0.0)
	var phase := clampf(t / 0.43, 0.0, 1.0)
	if t < 0 or phase >= 1: return
	var spark: Texture2D = _textures.get("Ｇ／光.png")
	if spark == null: return
	for i: int in range(12):
		var direction := Vector2.from_angle(i * 2.39996)
		var point := Vector2(21, 21) + direction * (10 + (24 + i % 4 * 7) * phase)
		point.y -= phase * phase * 22
		var width := (8.0 + i % 3 * 3) * (1.0 - phase)
		draw_texture_rect(spark, Rect2(point - Vector2.ONE * width / 2, Vector2.ONE * width), false, Color(1, 0.85, 0.42, 1.0 - phase))
