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
	_keyword_boxes(String(record.description))
	show()

## Every enchantment named in the description gets its own box under the tooltip explaining
## what it does; the whole stack moves up when it would run off the bottom of the screen.
func _keyword_boxes(text: String) -> void:
	var enchantments := CardEnchantments.shared().by_name
	var y := 0.0
	for name: String in enchantments:
		if not text.contains(name): continue
		var effect := String(enchantments[name].description)
		var box := Panel.new()
		box.name = "Keyword_" + name
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_stylebox_override("panel", BattleArt.panel_style())
		box.size = Vector2(size.x, 112 + effect.count("\n") * 28)
		box.position = Vector2(0, size.y + 6 + y)
		var backing := ColorRect.new()
		backing.color = Color("0b0b0d")
		backing.position = Vector2(4, 4)
		backing.size = box.size - Vector2(8, 8)
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backing.show_behind_parent = true
		box.add_child(backing)
		var heading := BattleArt.label(box, name, Vector2(22, 14), Vector2(size.x - 44, 32), 22, CardEnchantments.BLUE)
		heading.add_theme_constant_override("outline_size", 2)
		var body := BattleArt.label(box, effect, Vector2(22, 60), Vector2(size.x - 44, box.size.y - 68), 20)
		body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		body.add_theme_constant_override("outline_size", 2)
		add_child(box)
		y += box.size.y + 6
	var overflow := position.y + size.y + y - 1072.0
	if y > 0.0 and overflow > 0.0: position.y = maxf(8.0, position.y - overflow)
