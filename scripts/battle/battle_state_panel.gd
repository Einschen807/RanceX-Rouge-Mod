extends TextureRect
class_name BattleStatePanel
var battle: BattleState
var current_page := "ability"
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _ability_tab: OriginalUiButton
var _curse_tab: OriginalUiButton

func _ready() -> void:
	name = "BattleStatePanel"
	position = Vector2(1150, 16)
	scale = BattleArt.INFORMATION_PANEL_SCALE
	size = Vector2(392, 420)
	texture = preload("res://assets/battle/monster_description.png")
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ShaderMaterial.new()
	background.shader = preload("res://shaders/analysis_panel.gdshader")
	material = background
	var title := _text(self, "状态", Vector2(26, 20), Vector2(340, 34), 25, Color("fff479"))
	title.add_theme_constant_override("outline_size", 4)
	_ability_tab = BattleArt.text_button(self, "能力", Vector2(26, 62), Vector2(162, 56), func() -> void: select_page("ability"))
	_ability_tab.name = "AbilityTab"
	_curse_tab = BattleArt.text_button(self, "诅咒", Vector2(204, 62), Vector2(162, 56), func() -> void: select_page("curse"))
	_curse_tab.name = "CurseTab"
	for tab: OriginalUiButton in [_ability_tab, _curse_tab]:
		tab.content.get_child(0).add_theme_font_size_override("font_size", 21)
	_scroll = ScrollContainer.new()
	_scroll.name = "Entries"
	_scroll.position = Vector2(26, 122)
	_scroll.size = Vector2(340, 272)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 12)
	_scroll.add_child(_rows)
	_ability_tab.focus_neighbor_right = _curse_tab.get_path()
	_curse_tab.focus_neighbor_left = _ability_tab.get_path()
	battle.changed.connect(refresh_entries)
	battle.troop.changed.connect(refresh_entries)
	select_page(current_page)

func _text(parent: Node, text: String, at: Vector2, dimensions: Vector2, font_size: int, color := Color.WHITE) -> Label:
	var label := BattleArt.label(parent, text, at, dimensions, font_size, color)
	label.add_theme_font_override("font", preload("res://assets/fonts/card_text.ttf"))
	label.clip_text = false
	label.add_theme_constant_override("outline_size", 1)
	return label

func select_page(page: String) -> void:
	if page not in ["ability", "curse"]: return
	current_page = page
	_ability_tab.selected = page == "ability"
	_curse_tab.selected = page == "curse"
	_scroll.scroll_vertical = 0
	refresh_entries()

func refresh_entries() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var records: Array = battle.abilities if current_page == "ability" else battle.troop.curses
	if records.is_empty():
		var empty := _text(_rows, "本场战斗尚未发动能力。" if current_page == "ability" else "当前未持有诅咒。", Vector2.ZERO, Vector2(320, 120), 19, Color("c9bda2"))
		empty.name = "EmptyState"
		empty.custom_minimum_size = Vector2(0, 120)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return
	for record: Dictionary in records:
		var row := VBoxContainer.new()
		row.name = "Entry"
		row.add_theme_constant_override("separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows.add_child(row)
		var heading := HBoxContainer.new()
		heading.name = "Heading"
		heading.add_theme_constant_override("separation", 10)
		row.add_child(heading)
		var title := _text(heading, record.name, Vector2.ZERO, Vector2.ZERO, 21, Color("fff479"))
		title.name = "Title"
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if current_page == "ability":
			var count := _text(heading, "发动次数：%d" % int(record.count), Vector2.ZERO, Vector2.ZERO, 17, Color("c9bda2"))
			count.name = "ActivationCount"
		var description := _text(row, String(record.get("description", "")), Vector2.ZERO, Vector2.ZERO, 19)
		description.name = "Description"
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.visible = not description.text.is_empty()
		var separator := HSeparator.new()
		separator.modulate = Color(0.65, 0.48, 0.23, 0.5)
		row.add_child(separator)

