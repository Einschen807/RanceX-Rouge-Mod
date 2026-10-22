extends Control
class_name RunTroopHUD
## Shared original-art footer for map and mandatory event choices.
signal formation_requested
var session: Node
var formation_enabled := false
var _hp: OriginalBitmapNumber
var _hp_fill: TextureRect
var _hp_mask: Control
var _medal_icons: Array[TextureRect] = []
var _gold: Label
var _leaders: HBoxContainer

func _ready() -> void:
	name = "RunHUD"
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -206
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right := Control.new()
	right.name = "TroopHUD"
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-900, 0)
	right.size = Vector2(900, 206)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	# Original Pact: HP bottom-right anchor (1909,981), mini cards (-413,-93).
	_picture(right, "hp_ground", Vector2(27, 30), Vector2(862, 77))
	_hp_mask = Control.new()
	_hp_mask.position = Vector2(33, 36)
	_hp_mask.size = Vector2(850, 65)
	_hp_mask.clip_contents = true
	_hp_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_hp_mask)
	_hp_fill = _picture(_hp_mask, "hp_fill", Vector2.ZERO, Vector2(850, 65))
	_hp = OriginalBitmapNumber.new()
	_hp.atlas = load("res://assets/map/hp_map_digits.png")
	_hp.position = Vector2(39, 60)
	_hp.size = Vector2(330, 49)
	_hp.name = "HP"
	_hp.kerning = -3
	_hp.abbreviate = false
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_hp)
	_leaders = HBoxContainer.new()
	_leaders.name = "Leaders"
	_leaders.position = Vector2(476, 14)
	_leaders.size = Vector2(382, 78)
	_leaders.add_theme_constant_override("separation", 3)
	right.add_child(_leaders)
	# Crop only the original medal strip; battle-spoils and meal-ticket regions are omitted.
	_picture(right, "medal_strip", Vector2(0, 119), Vector2(264, 64))
	for i: int in range(3):
		_medal_icons.append(_picture(right, "medal", Vector2(62 + i * 64, 115), Vector2(64, 64)))
	_gold = ShopArt.money(right, Vector2(294, 114))
	_gold.name = "Gold"
	if formation_enabled:
		var formation := OriginalUiButton.make(right, "formation", Vector2(701, 108), Vector2(194, 92), _request_formation, "click", "res://assets/map/native")
		formation.name = "FormationButton"
		var caption := FormationArt.label(formation.content, "部队编制", Vector2(13, 16), Vector2(170, 52), 23, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		caption.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
		caption.add_theme_constant_override("outline_size", 1)
		caption.add_theme_color_override("font_outline_color", Color.BLACK)
		formation.focus_neighbor_top = get_node("/root/ScreenSettings").gear.get_path()

	refresh()
	session.changed.connect(refresh)

func _picture(parent: Node, name: String, at: Vector2, dimensions: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture = load("res://assets/map/%s.png" % name)
	rect.position = at
	rect.size = dimensions
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func refresh() -> void:
	if not is_instance_valid(_hp): return
	_hp.text = str(ceili(session.hp()))
	var hp_ratio := clampf(session.hp() / maxf(1.0, session.troop.total("hp")), 0, 1)
	# Original gauge drains from the left while retaining its right-hand cyan tip.
	_hp_mask.position.x = 33 + 850 * (1.0 - hp_ratio)
	_hp_mask.size.x = 850 * hp_ratio
	_hp_fill.position.x = -850 * (1.0 - hp_ratio)
	for i: int in range(_medal_icons.size()): _medal_icons[i].visible = i < session.troop.medal_progress
	_gold.text = str(session.troop.gold)
	for child: Node in _leaders.get_children():
		_leaders.remove_child(child)
		child.queue_free()
	for index: int in range(session.troop.leaders.size()):
		var name: String = session.troop.leaders[index]
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(52, 78)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_leaders.add_child(slot)
		_picture(slot, "mini_ground", Vector2.ZERO, Vector2(52, 78))
		if session.troop.is_slot_unlocked(index) and not name.is_empty():
			var record: Dictionary = session.catalog.find_name(name)
			_picture(slot, "mini_back_%d" % record.faction, Vector2.ZERO, Vector2(52, 78))
			var portrait := TextureRect.new()
			portrait.texture = load(CardCatalog.portrait_path(record))
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.size = Vector2(52, 78)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(portrait)
			_picture(slot, "mini_frame_%d" % record.faction, Vector2.ZERO, Vector2(52, 78))

func _request_formation() -> void:
	formation_requested.emit()
