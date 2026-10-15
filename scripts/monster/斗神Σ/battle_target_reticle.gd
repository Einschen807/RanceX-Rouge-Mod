extends Control
class_name BattleTargetReticle
## A persistent portrait overlay; action use does not hide the target marker.
var clock := 0.0
var playback_speed := 1.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(208, 312)

func _process(delta: float) -> void:
	clock += delta * playback_speed
	queue_redraw()

func _draw() -> void:
	var center := Vector2(104, 156)
	var pulse := (sin(clock * TAU * 1.4) + 1.0) / 2.0
	var color := Color(1.0, 0.035, 0.045, 0.35 + 0.65 * pulse)
	var shadow := Color(0.05, 0.0, 0.0, color.a * 0.85)
	for radius: float in [34.0, 52.0]:
		draw_arc(center, radius, 0.0, TAU, 64, shadow, 7.0, true)
		draw_arc(center, radius, 0.0, TAU, 64, color, 3.5, true)
	for axis: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + axis * 24.0, center + axis * 68.0, shadow, 7.0, true)
		draw_line(center + axis * 24.0, center + axis * 68.0, color, 3.5, true)
	draw_circle(center, 6.0, shadow, true, -1.0, true)
	draw_circle(center, 3.5, color, true, -1.0, true)
