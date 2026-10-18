extends Control
class_name BattleCard
signal skill_requested(name: String, id: int, slot: int)
signal card_selected(name: String)
signal skill_hovered(name: String, id: int, slot: int, entered: bool)
var battle: BattleState
var card: Dictionary
var mode := 0
var selected := false
var input_locked := false
var skill_buttons: Array[Button] = []
var _hover_border: OriginalFlatPlayer

func set_hovered(value: bool) -> void:
	if is_instance_valid(_hover_border): _hover_border.visible = value and not selected

func configure(state: BattleState, name: String, operation_mode: int, is_selected: bool, locked: bool) -> void:
	battle = state
	card = battle.troop.catalog.find_name(name)
	mode = operation_mode
	selected = is_selected
	input_locked = locked
	size = Vector2(208, 312)

func _ready() -> void:
	# Reuse the formation card at its native aspect ratio; battle skill panels
	# remain outside the scaled portrait component.
	if mode == 1:
		_portrait(Vector2.ZERO, size)
	var click_area := Button.new()
	click_area.size = size
	for style: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		click_area.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	click_area.pressed.connect(func() -> void: card_selected.emit(card.name))
	click_area.disabled = input_locked or battle.phase != "player"
	add_child(click_area)
	if mode == 0:
		BattleArt.picture(self, "card_frame", Vector2(-2, -2))
		for index: int in range(2):
			_skill(index, false)
		_portrait(Vector2(52, 79), Vector2(104, 156))
		var at_background := ColorRect.new()
		at_background.name = "ATBackground"
		at_background.position = Vector2(52, 205)
		at_background.size = Vector2(104, 30)
		at_background.color = Color(0, 0, 0, 0.62)
		at_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(at_background)
	# Deployment AT is a formation value. Combat modifiers only affect damage.
	if mode == 1:
		var plate := FormationArt.picture(self, "leader_at", Vector2(0, 276), Vector2(208, 33))
		plate.name = "ATPlate"
	var at := BattleArt.number(self, "hp_digits", Vector2(52, 205) if mode == 0 else Vector2(36, 277), Vector2(104, 30) if mode == 0 else Vector2(164, 28))
	at.text = str(int(floor(battle.troop.deployed(card, "at"))))
	at.alignment = HORIZONTAL_ALIGNMENT_CENTER if mode == 0 else HORIZONTAL_ALIGNMENT_RIGHT
	at.abbreviate = false
	at.fit_height = true
	at.name = "BattleAT"
	var acted: bool = battle.runtime.acted.get(card.name, false)
	if acted and not battle.troop.down_cards.has(card.name):
		var shade := ColorRect.new()
		shade.size = size
		shade.color = Color(0, 0, 0, 0.68)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		BattleArt.picture(self, "acted", Vector2.ZERO, size)
	if mode == 1 and selected:
		var mask := ColorRect.new()
		mask.name = "DescriptionMask"
		mask.size = size
		mask.color = Color(0, 0, 0, 0.25)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mask)
		for index: int in range(2):
			_skill(index, true)
	if mode == 1 and not selected:
		_hover_border = BattleArt.flat(self, "card_hover")
		_hover_border.name = "HoverBorder"
		_hover_border.hide()
	if card.name in battle.blocked_player_actors:
		var blocked := BattleArt.picture(self, "status/blocked_large", Vector2(76, 100) if mode == 0 else Vector2(48, 128), Vector2(56, 56) if mode == 0 else Vector2(112, 112))
		blocked.name = "BlockedAction"
		blocked.z_index = 20
		var stun := BattleArt.flat(self, "status_blocked_card")
		stun.name = "ConfusionStun"
		stun.z_index = 21
	if battle.troop.down_cards.has(card.name):
		var down := BattleArt.flat(self, "down_overlay")
		down.name = "DownState"
		# Keep DOWN in this card's draw order; battle effects render after the card group.
		down.z_index = 0

func _portrait(at: Vector2, dimensions: Vector2) -> void:
	var layer := Control.new()
	layer.name = "Portrait"
	layer.position = at
	layer.size = dimensions
	layer.clip_contents = true
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	var face := CardWidget.new()
	face.setup(card, battle.troop, false, 0)
	face.portrait_only = mode == 0 or selected
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_meta("omit_down", true)
	face.set_meta("omit_unavailable", true)
	layer.add_child(face)
	face.scale = Vector2.ONE * (dimensions.x / 208.0)
	if face.visual.has_node("CardName"): face.visual.get_node("CardName").hide()
	for decoration: String in ["LeaderBadge", "LeaderGlow"]:
		if face.visual.has_node(decoration): face.visual.get_node(decoration).hide()

func _skill(index: int, descriptions: bool) -> void:
	var id: int = card["skill%d" % (index + 1)]
	if id == 0:
		return
	var skill: Dictionary = battle.troop.catalog.skills[id]
	var kind := "skill" if descriptions else ("skill_top" if index == 0 else "skill_bottom")
	var at := Vector2(1, 7 if index == 0 else 164) if descriptions else Vector2(1, 0 if index == 0 else 164)
	var button := BattleArt.button(self, kind, at, Vector2(228, 162) if descriptions else Vector2(206, 147), func() -> void:
		if not input_locked: skill_requested.emit(card.name, id, index))
	button.name = "Skill%d" % (index + 1)
	button.mouse_entered.connect(func() -> void: skill_hovered.emit(card.name, id, index, true))
	button.mouse_exited.connect(func() -> void: skill_hovered.emit(card.name, id, index, false))
	button.disabled = battle.phase != "player" or not battle.can_use(card.name, id, index)
	button.refresh_art()
	var header_y := 72 if not descriptions and index == 1 else 0
	if descriptions:
		button.scale = Vector2.ONE * 0.9
		_detail_frame(button)
		_native_panel(button.content, "APFrame", Rect2(73, 53, 82, 38), Vector2(73, 19), Vector2(82, 36))
		_native_panel(button.content, "DescriptionFrame", Rect2(13, 90, 202, 62), Vector2(13, 68), Vector2(202, 83))
	var inset := 12 if descriptions else 3
	SkillIconArt.player(button.content, skill, Vector2(16 if descriptions else inset + 1, (16 if descriptions else 6) + header_y), Vector2(34, 34), not button.disabled)
	if not descriptions:
		BattleArt.label(button.content, skill.name, Vector2(inset + 37, 4 + header_y), Vector2(160, 36), 21, FormationArt.GOLD)
	_cost(button.content, skill, Vector2(73 if descriptions else 63, (21 if descriptions else 43) + header_y), index)
	if descriptions:
		var text := BattleArt.label(button.content, skill.description, Vector2(18, 71), Vector2(192, 77), 15)
		text.name = "SkillDescription"
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		text.add_theme_constant_override("line_spacing", 0)
		text.size = Vector2(192, 77)
		for font_size: int in range(15, 11, -1):
			text.add_theme_font_size_override("font_size", font_size)
			if text.get_line_count() <= 4 and text.get_visible_line_count() >= text.get_line_count(): break
	skill_buttons.append(button)

func _detail_frame(button: OriginalUiButton) -> void:
	# Keep the native normal/hover/pressed timelines, including the cyan hover pulse.
	# Only hide its old combined frame; its AP and description pieces move below.
	button.art.hidden_libraries = PackedStringArray(["Ｇ／枠.png"])
	button.art.set_meta("fixed_ui_speed", true)
	# The original disabled state bakes all three old boxes into one image.
	# Replace that image with the same native background, preserving its padding.
	var disabled_background := AtlasTexture.new()
	disabled_background.atlas = load("res://assets/battle/native/skill_normal/atlas_0_0.png")
	disabled_background.region = Rect2(0, 0, 220, 154)
	disabled_background.margin = Rect2(4, 3, 8, 8)
	button.art.texture_overrides["Ｇ／无效.png"] = disabled_background
	button.art.load_animation(button.art.animation_path)
	var frame := NinePatchRect.new()
	frame.name = "DetailFrame"
	frame.texture = load("res://assets/battle/native/skill_normal/atlas_0_1.png")
	frame.size = Vector2(228, 162)
	frame.patch_margin_left = 12
	frame.patch_margin_right = 12
	frame.patch_margin_top = 12
	frame.patch_margin_bottom = 12
	frame.draw_center = false
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.content.add_child(frame)

func _cost(parent: Control, skill: Dictionary, at: Vector2, slot: int) -> void:
	var cost := Control.new()
	cost.name = "APCost"
	cost.position = at
	cost.size = Vector2(82, 30)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cost)
	var status := battle.runtime.display_state(card.name, skill, slot)
	if skill.action != 1:
		BattleArt.label(cost, status.text, Vector2.ZERO, cost.size, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	if status.spent:
		cost.set_meta("palette", "black")
		FormationArt.picture(cost, "ap_spent", Vector2(31, 5), Vector2(19, 19)).name = "SpentAPBadge"
		var digits := OriginalBitmapNumber.make(cost, "digits_ap_spent", Vector2(31, 5), Vector2(19, 19), "", 0)
		digits.name = "SpentAPNumber"
		digits.text = str(status.amount)
		digits.fit_height = true
		digits.abbreviate = false
		digits.alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	var amount: int = status.amount
	var palette: String = status.palette
	cost.set_meta("palette", palette)
	var number := BattleArt.number(cost, "cost_" + palette, Vector2(8, 1), Vector2(42, 26))
	number.text = str(amount)
	BattleArt.picture(cost, "cost_caption_" + palette, Vector2(50, 7))
	if palette != "white":
		BattleArt.picture(cost, "cost_arrow_" + palette, Vector2(2, 1))

func _native_panel(parent: Node, title: String, region: Rect2, at: Vector2, dimensions: Vector2) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/battle/native/skill_normal/atlas_0_1.png")
	texture.region = region
	var panel := NinePatchRect.new()
	panel.name = title
	panel.texture = texture
	panel.position = at
	panel.size = dimensions
	panel.patch_margin_left = 4
	panel.patch_margin_right = 4
	panel.patch_margin_top = 4
	panel.patch_margin_bottom = 4
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
