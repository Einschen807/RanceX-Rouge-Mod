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
	if is_instance_valid(_hover_border): _hover_border.visible = value

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
	var at := BattleArt.label(self, str(int(floor(battle.troop.deployed(card, "at")))), Vector2(3, 206 if mode == 0 else 270), Vector2(202, 34), 28, Color(1, 0.98, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	at.name = "BattleAT"
	var acted: bool = battle.runtime.acted.get(card.name, false)
	if acted:
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
		mask.color = Color(0, 0, 0, 0.88)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mask)
		for index: int in range(2):
			_skill(index, true)
	if mode == 1:
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
	for slot: int in range(2):
		var id: int = card["skill%d" % (slot + 1)]
		if id == 0: continue
		var skill: Dictionary = battle.troop.catalog.skills[id]
		face.skill_costs[slot] = "已" if battle.runtime.is_spent(card.name, skill, slot) else str(battle.runtime.ap_cost(card.name, skill, slot))
	face.portrait_only = mode == 0 or selected
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var at := Vector2(-10, 0 if index == 0 else 150) if descriptions else Vector2(1, 0 if index == 0 else 164)
	var button := BattleArt.button(self, kind, at, Vector2(228, 162) if descriptions else Vector2(206, 147), func() -> void:
		if not input_locked: skill_requested.emit(card.name, id, index))
	button.name = "Skill%d" % (index + 1)
	button.mouse_entered.connect(func() -> void: skill_hovered.emit(card.name, id, index, true))
	button.mouse_exited.connect(func() -> void: skill_hovered.emit(card.name, id, index, false))
	button.disabled = battle.phase != "player" or not battle.can_use(card.name, id, index)
	button.refresh_art()
	var icon: int = skill.type if skill.action == 1 else (8 if skill.action == 3 else 7)
	var header_y := 72 if not descriptions and index == 1 else 0
	if descriptions:
		FormationArt.picture(button.content, "skill_strip", Vector2(12, 8), Vector2(204, 38))
		_panel(button.content, Vector2(73, 49), Vector2(82, 35))
		_panel(button.content, Vector2(12, 86), Vector2(204, 64))
	var inset := 12 if descriptions else 3
	FormationArt.picture(button.content, "skill_%d" % icon, Vector2(inset + 1, 6 + header_y), Vector2(34, 34))
	BattleArt.label(button.content, skill.name, Vector2(inset + 37, 4 + header_y), Vector2(160, 36), 21, FormationArt.GOLD)
	_cost(button.content, skill, Vector2(73 if descriptions else 63, (49 if descriptions else 43) + header_y), index)
	if descriptions:
		var text := BattleArt.label(button.content, skill.description, Vector2(18, 89), Vector2(192, 58), 16)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	skill_buttons.append(button)

func _cost(parent: Control, skill: Dictionary, at: Vector2, slot: int) -> void:
	var cost := Control.new()
	cost.name = "APCost"
	cost.position = at
	cost.size = Vector2(82, 30)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cost)
	if battle.runtime.is_spent(card.name, skill, slot) or skill.action != 1:
		var text := "已" if battle.runtime.is_spent(card.name, skill, slot) else "—"
		BattleArt.label(cost, text, Vector2.ZERO, cost.size, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var amount := battle.runtime.ap_cost(card.name, skill, slot)
	var palette := "white"
	if skill.ap_type in [2, 3] and amount > int(skill.ap):
		palette = "purple"
	elif skill.ap_type == 1 and amount > int(skill.ap):
		palette = "orange"
	cost.set_meta("palette", palette)
	var number := BattleArt.number(cost, "cost_" + palette, Vector2(8, 1), Vector2(42, 26))
	number.text = str(amount)
	BattleArt.picture(cost, "cost_caption_" + palette, Vector2(50, 7))
	if palette != "white":
		BattleArt.picture(cost, "cost_arrow_" + palette, Vector2(2, 1))

func _panel(parent: Node, at: Vector2, dimensions: Vector2) -> void:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0.025, 0.035, 0.83)
	style.border_color = Color(0.5, 0.62, 0.59, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
