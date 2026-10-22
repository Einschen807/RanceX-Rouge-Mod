extends Control
class_name RelicEncyclopedia
## Native system-page layout: brown settings background, rarity tabs in the right column,
## a dense scrolling grid of named relic tiles grouped by rarity. Hover keeps the gold tooltip.
signal close_requested
const COLUMNS := 10
const TILE := Vector2(104, 126)
const GAP := Vector2(14, 12)
const GRID_WIDTH := COLUMNS * 104.0 + (COLUMNS - 1) * 14.0
const HEADER := 44.0
## Keeps first-column names inside the scroll clip.
const INSET := 10.0
const RARITY_COLORS := [Color("b9b4a6"), Color("6fb2e6"), Color("f2c75c"), Color("8fd47a"), Color("d38ff0")]
var database := RelicCatalog.new()
var tip: RelicTooltip
var filter := 0
var tabs: Array[OriginalUiButton] = []
var _scroll: ScrollContainer
var _content: Control
var _scrollbar: OriginalFormationScrollbar

func _ready() -> void:
	name = "RelicEncyclopedia"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("modal_overlay")
	var shade := ColorRect.new()
	shade.color = Color.BLACK
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	NativeSettingsArt.flat(self, "settings_background", Vector2.ZERO)
	var loaded := database.load_catalog()
	_scroll = ScrollContainer.new()
	_scroll.name = "RelicScroll"
	_scroll.position = Vector2(170, 56)
	_scroll.size = Vector2(GRID_WIDTH + INSET * 2.0, 972)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_content)
	_scrollbar = OriginalFormationScrollbar.new()
	_scrollbar.scroll = _scroll
	_scrollbar.total_height = 940.0
	_scrollbar.position = Vector2(1400, 70)
	add_child(_scrollbar)
	if not loaded:
		BattleArt.label(self, "\n".join(database.errors), Vector2(260, 180), Vector2(1000, 300), 24)
	var captions := ["全部"] + RelicCatalog.RARITIES
	for i: int in range(captions.size()):
		var count := database.entries.size() if i == 0 else database.entries.filter(func(record: Dictionary) -> bool: return record.rarity == i).size()
		var tab := OriginalUiButton.make(self, "tab", Vector2(1608, 140 + i * 100), Vector2(300, 92), show_filter.bind(i), "click", NativeSettingsArt.ROOT)
		tab.name = "Tab_%d" % i
		tab.selected_offset = Vector2.ZERO
		BattleArt.label(tab.content, captions[i], Vector2(28, 8), Vector2(170, 74), 27, Color.WHITE if i == 0 else RARITY_COLORS[i - 1], HORIZONTAL_ALIGNMENT_LEFT)
		BattleArt.label(tab.content, str(count), Vector2(190, 8), Vector2(84, 74), 27, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		tabs.append(tab)
	var back := OriginalUiButton.make(self, "back", Vector2(1712, 972), Vector2(196, 92), func() -> void: close_requested.emit(), "cancel", NativeSettingsArt.ROOT)
	back.name = "Back"
	BattleArt.label(back.content, "返回", Vector2(12, 8), Vector2(172, 74), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	BattleArt.label(self, "遗物收集", Vector2(1608, 30), Vector2(300, 80), 38, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	tip = RelicTooltip.new()
	add_child(tip)
	tip.hide()
	show_filter(0, false)
	tabs[0].grab_focus()

func show_filter(index: int, animated := true) -> void:
	filter = index
	for i: int in range(tabs.size()): tabs[i].selected = i == index
	tip.hide()
	BattleArt.clear(_content)
	_scroll.scroll_vertical = 0
	# Dense left-aligned grid: about 65 relics per screen, scrolling for the rest.
	var y := 0.0
	var order := 0
	for rarity: int in range(1, RelicCatalog.RARITIES.size() + 1):
		if index != 0 and rarity != index: continue
		var records := database.entries.filter(func(record: Dictionary) -> bool: return record.rarity == rarity)
		if records.is_empty(): continue
		var caption := BattleArt.label(_content, "%s  %d" % [RelicCatalog.RARITIES[rarity - 1], records.size()], Vector2(INSET, y), Vector2(220, HEADER), 26, RARITY_COLORS[rarity - 1])
		caption.name = "Section_%d" % rarity
		var rule := TextureRect.new()
		rule.texture = preload("res://assets/settings/native/settings_background/lib_2.png")
		rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rule.stretch_mode = TextureRect.STRETCH_TILE
		var caption_width := caption.get_theme_font("font").get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		rule.position = Vector2(INSET + caption_width + 18, y + HEADER / 2.0)
		rule.size = Vector2(INSET + GRID_WIDTH - rule.position.x, 2)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(rule)
		y += HEADER + 6
		for i: int in range(records.size()):
			var at := Vector2(INSET + (i % COLUMNS) * (TILE.x + GAP.x), y + (i / COLUMNS) * (TILE.y + GAP.y))
			var tile := _tile(records[i], at)
			if animated:
				tile.modulate.a = 0.0
				# Cap the stagger so a hundred relics still settle quickly.
				tile.create_tween().tween_property(tile, "modulate:a", 1.0, 0.16).set_delay(minf(0.012 * order, 0.4))
			order += 1
		var rows := ceili(records.size() / float(COLUMNS))
		y += rows * TILE.y + (rows - 1) * GAP.y + 30
	_content.custom_minimum_size = Vector2(_scroll.size.x, y)
	_scrollbar.visible = _content.custom_minimum_size.y > _scroll.size.y

func _tile(record: Dictionary, at: Vector2) -> Control:
	var tile := Control.new()
	tile.name = "Relic_" + String(record.name)
	tile.position = at
	tile.size = TILE
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(tile)
	var plate := Panel.new()
	plate.position = Vector2(8, 0)
	plate.size = Vector2(TILE.x - 16, TILE.x - 16)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.42)
	style.border_color = RARITY_COLORS[int(record.rarity) - 1] * Color(1, 1, 1, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	plate.add_theme_stylebox_override("panel", style)
	tile.add_child(plate)
	var icon := RelicIcon.new()
	icon.record = record
	icon.position = plate.position
	icon.size = plate.size
	tile.add_child(icon)
	icon.mouse_entered.connect(func() -> void: tip.show_beside(record, Rect2(icon.global_position, icon.size + Vector2(0, 30))))
	icon.mouse_exited.connect(func() -> void: tip.hide())
	icon.focus_entered.connect(func() -> void: tip.show_beside(record, Rect2(icon.global_position, icon.size + Vector2(0, 30))))
	icon.focus_exited.connect(func() -> void: tip.hide())
	var label := BattleArt.label(tile, record.name, Vector2(-6, TILE.x - 14), Vector2(TILE.x + GAP.x - 2, 30), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	label.name = "Name"
	label.add_theme_constant_override("outline_size", 4)
	# Long names shrink to fit the tile instead of being clipped.
	var font := label.get_theme_font("font")
	for font_size: int in range(18, 12, -1):
		label.add_theme_font_size_override("font_size", font_size)
		if font.get_string_size(record.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x: break
	return tile

func _input(event: InputEvent) -> void:
	if get_node("/root/ScreenTransition").busy: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
