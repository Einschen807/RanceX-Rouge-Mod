extends Panel
class_name RelicTooltip

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(440, 180)
	add_theme_stylebox_override("panel", BattleArt.panel_style())

## Below the anchor when the box fits, otherwise flipped above it.
func show_beside(record: Dictionary, anchor: Rect2, gap := 10.0) -> void:
	var below := anchor.end.y + gap
	var y := below if below + size.y <= 1080.0 - 8.0 else anchor.position.y - gap - size.y
	show_record(record, Vector2(anchor.position.x + 20, y))

func show_record(record: Dictionary, at: Vector2) -> void:
	BattleArt.clear(self)
	var backing := ColorRect.new()
	backing.color = Color("0b0b0d")
	backing.position = Vector2(4, 4)
	backing.size = size - Vector2(8, 8)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.show_behind_parent = true
	add_child(backing)
	position = Vector2(clampf(at.x, 8, 1472), clampf(at.y, 8, 885))
	var heading := BattleArt.label(self, record.name, Vector2(25, 16), Vector2(390, 36), 26, FormationArt.GOLD)
	heading.add_theme_constant_override("outline_size", 2)
	var description := BattleArt.label(self, record.description, Vector2(25, 62), Vector2(390, 96), 23)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description.add_theme_constant_override("outline_size", 2)
	show()
