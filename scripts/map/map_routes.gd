extends Control
class_name MapRoutes
var graph: Dictionary
var positions: Dictionary
var travelled: Array = []
var current := ""
var travel_source := ""
var travel_target := ""
var travel_progress := 0.0

func set_travel_progress(value: float) -> void:
	travel_progress = value
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	for id: String in graph.nodes:
		for child: String in graph.nodes[id].children:
			var source: Vector2 = positions[id]
			var target: Vector2 = positions[child]
			var vector := target - source
			var offset := 60.0 if id == "start" else 40.0
			var end_offset := 60.0 if child == "boss" else 40.0
			var a := source + vector.normalized() * offset
			var b := target - vector.normalized() * end_offset
			var visited_edge: bool = id in travelled and child in travelled
			var active_edge := id == current
			var color := Color("9b3021") if visited_edge else (Color("9d5f22") if active_edge else Color(0.29, 0.21, 0.13, 0.42))
			var direction := (b - a).normalized()
			var distance := a.distance_to(b)
			var dash := 0.0
			while dash < distance:
				draw_line(a + direction * dash, a + direction * minf(dash + 9.0, distance), color, 3.0 if visited_edge or active_edge else 2.0, true)
				if id == travel_source and child == travel_target and dash < distance * travel_progress:
					var lit_end := minf(dash + 9.0, distance * travel_progress)
					draw_line(a + direction * dash, a + direction * lit_end, Color("f6d080"), 5.0, true)
				dash += 17.0
