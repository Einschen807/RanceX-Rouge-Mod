extends Control
class_name RelicEncyclopedia
signal close_requested
var database := RelicCatalog.new()
var tip: RelicTooltip

func _ready() -> void:
	name = "RelicEncyclopedia"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("modal_overlay")
	var shade := ColorRect.new()
	shade.color = Color("11151b")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	BattleArt.label(self, "遗物图鉴", Vector2(340, 45), Vector2(1100, 65), 42, FormationArt.GOLD)
	if not database.load_catalog():
		BattleArt.label(self, "\n".join(database.errors), Vector2(360, 180), Vector2(1100, 300), 24)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(340, 145)
	scroll.size = Vector2(1300, 800)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 1230
	content.add_theme_constant_override("separation", 22)
	scroll.add_child(content)
	for rarity: int in [1, 2, 3, 4]:
		var heading := Label.new()
		heading.text = RelicCatalog.RARITIES[rarity - 1]
		heading.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
		heading.add_theme_font_size_override("font_size", 32)
		heading.add_theme_color_override("font_color", FormationArt.GOLD)
		content.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 10
		grid.custom_minimum_size.y = 105
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 20)
		content.add_child(grid)
		for record: Dictionary in database.entries:
			if record.rarity != rarity: continue
			var icon := RelicIcon.new()
			icon.record = record
			icon.custom_minimum_size = Vector2(100, 100)
			grid.add_child(icon)
			icon.mouse_entered.connect(func() -> void: tip.show_record(record, icon.global_position + Vector2(30, 105)))
			icon.mouse_exited.connect(func() -> void: tip.hide())
			icon.focus_entered.connect(func() -> void: tip.show_record(record, icon.global_position + Vector2(30, 105)))
			icon.focus_exited.connect(func() -> void: tip.hide())
	TreasureArt.button(self, "返回", Vector2(65, 920), func() -> void: close_requested.emit())
	tip = RelicTooltip.new()
	add_child(tip)
	tip.hide()

func _input(event: InputEvent) -> void:
	if get_node("/root/ScreenTransition").busy: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
