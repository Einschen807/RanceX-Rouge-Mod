extends Control
class_name MapPaper
## Nine independent source regions: ornaments keep their dimensions as the sheet grows.
const PAPER: Texture2D = preload("res://assets/map/parchment.png")
const LEFT := 108.0
const RIGHT := 342.0
const TOP := 118.0
const BOTTOM := 240.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var source_x := [0.0, LEFT, PAPER.get_width() - RIGHT, float(PAPER.get_width())]
	var source_y := [0.0, TOP, PAPER.get_height() - BOTTOM, float(PAPER.get_height())]
	var target_x := [0.0, LEFT, size.x - RIGHT, size.x]
	var target_y := [0.0, TOP, size.y - BOTTOM, size.y]
	for y: int in range(3):
		for x: int in range(3):
			var source := Rect2(source_x[x], source_y[y], source_x[x + 1] - source_x[x], source_y[y + 1] - source_y[y])
			var target := Rect2(target_x[x], target_y[y], target_x[x + 1] - target_x[x], target_y[y + 1] - target_y[y])
			if y != 1:
				draw_texture_rect_region(PAPER, target, source)
				continue
			# Fit an odd number of alternating mirrored sections. Both end seams match
			# the original corners, while grain and side ornaments keep natural scale.
			var tiles := maxi(1, roundi(target.size.y / source.size.y))
			if tiles % 2 == 0: tiles += 1
			var tile_height := target.size.y / float(tiles)
			for tile: int in range(tiles):
				var start_y := target.position.y + tile * tile_height
				if tile % 2 == 0:
					draw_texture_rect_region(PAPER, Rect2(target.position.x, start_y, target.size.x, tile_height), source)
				else:
					draw_set_transform(Vector2(0, start_y + tile_height), 0, Vector2(1, -1))
					draw_texture_rect_region(PAPER, Rect2(target.position.x, 0, target.size.x, tile_height), source)
					draw_set_transform(Vector2.ZERO)
