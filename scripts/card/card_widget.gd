extends Button
class_name CardWidget
const CARD_TEXT_FONT: Font = preload("res://assets/fonts/card_text.tres")
const DRAGGED_LEADER_ALPHA := 0.55
## A single reusable 208x312 view, populated by catalog records.
signal card_clicked(display_name: String, leader: bool)
signal leader_removed(display_name: String)
signal card_dropped(display_name: String)
var card: Dictionary
var display_card: Dictionary
var preview_upgrades := false
var troop: TroopState
var leader := false
var detail_mode := 0
var portrait_only := false
var skill_costs: Dictionary = {}
var visual: Control
var flipping := false
var dragging := false
var _hovered := false

func setup(record: Dictionary, state: TroopState, is_leader: bool, mode: int, show_upgrades: bool = false) -> void:
	card = record
	troop = state
	preview_upgrades = show_upgrades
	display_card = state.catalog.upgrade_preview(record) if show_upgrades else record
	leader = is_leader
	detail_mode = mode
	custom_minimum_size = Vector2(208, 312)
	size = custom_minimum_size

func _ready() -> void:
	for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	visual = Control.new()
	visual.size = Vector2(208, 312)
	visual.pivot_offset = visual.size / 2.0
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)
	pressed.connect(func() -> void:
		if not selection_blocked(): card_clicked.emit(card.name, leader))
	mouse_entered.connect(func() -> void:
		_hovered = true
		refresh_feedback())
	mouse_exited.connect(func() -> void:
		_hovered = false
		refresh_feedback())
	focus_entered.connect(refresh_feedback)
	focus_exited.connect(refresh_feedback)
	redraw()

func refresh_feedback() -> void:
	if visual == null:
		return
	var tint := Color(1.15, 1.15, 1.10) if _hovered or has_focus() else Color.WHITE
	tint.a = DRAGGED_LEADER_ALPHA if leader and dragging else 1.0
	visual.modulate = tint

func selection_blocked() -> bool:
	return not leader and troop.is_unavailable(card.name)

func redraw() -> void:
	for child: Node in visual.get_children():
		visual.remove_child(child)
		child.queue_free()
	FormationArt.picture(visual, "back_%d" % display_card.faction, Vector2.ZERO, size)
	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/cards/%s.png" % display_card.portrait)
	portrait.size = size
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(portrait)
	if detail_mode != 0:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.68)
		shade.size = size
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.add_child(shade)
	# Ornament surrounds the portrait; every information layer renders above it.
	FormationArt.picture(visual, "frame_%d" % display_card.faction, Vector2.ZERO, size)
	if portrait_only:
		_portrait_emblem()
		_down_art()
		return
	if detail_mode == 2:
		_skill(0, 4, true)
		_skill(1, 158, true)
	else:
		if detail_mode == 1:
			FormationArt.picture(visual, "stats_overlay", Vector2.ZERO, size)
		_portrait_emblem()
		FormationArt.picture(visual, "star", Vector2(5, 56), Vector2(20, 23))
		var stars := FormationArt.label(visual, str(troop.level(card.name)), Vector2(24, 55), Vector2(53, 26), 21, Color.YELLOW)
		stars.add_theme_font_override("font", CARD_TEXT_FONT)
		stars.add_theme_color_override("font_outline_color", Color.BLACK)
		stars.add_theme_constant_override("outline_size", 7)
		if detail_mode == 1:
			FormationArt.label(visual, CardCatalog.ELEMENTS[display_card.element], Vector2(72, 25), Vector2(62, 24), 19, FormationArt.GOLD)
			FormationArt.label(visual, str(troop.level(card.name)), Vector2(111, 59), Vector2(86, 25), 21, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
			FormationArt.label(visual, CardCatalog.FACTIONS[display_card.faction - 1], Vector2(70, 85), Vector2(128, 25), 18, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
			FormationArt.label(visual, _number(troop.actual(card, "hp", preview_upgrades)), Vector2(61, 111), Vector2(136, 26), 24, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
			FormationArt.label(visual, _number(troop.actual(card, "at", preview_upgrades)), Vector2(61, 138), Vector2(136, 26), 24, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		_skill(0, 192, false)
		_skill(1, 230, false)
		if leader and detail_mode == 0:
			FormationArt.picture(visual, "leader_at", Vector2(0, 276), Vector2(208, 33))
			var at_number := FormationArt.label(visual, _number(troop.deployed(card, "at", preview_upgrades)), Vector2(32, 276), Vector2(166, 30), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
			at_number.name = "LeaderAT"
		else:
			FormationArt.picture(visual, "name_%d" % display_card.faction, Vector2(0, 276), Vector2(208, 32))
			var display_name := FormationArt.label(visual, display_card.name, Vector2(6, 277), Vector2(196, 26), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			display_name.name = "CardName"
			display_name.add_theme_color_override("font_outline_color", Color.BLACK)
			display_name.add_theme_constant_override("outline_size", 1)
	if card.name in troop.leaders:
		var glow := OriginalFlatPlayer.new()
		glow.name = "LeaderGlow"
		glow.animation_path = "res://assets/formation/native/card_selected/animation.json"
		visual.add_child(glow)
		if not leader:
			var badge := OriginalFlatPlayer.new()
			badge.name = "LeaderBadge"
			badge.animation_path = "res://assets/formation/native/card_leader/animation.json"
			visual.add_child(badge)
	refresh_feedback()
	_down_art()
	if selection_blocked() and not get_meta("omit_unavailable", false):
		var shade := ColorRect.new()
		shade.name = "UnavailableShade"
		shade.size = size
		shade.color = Color(0, 0, 0, 0.55)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.add_child(shade)
		var unavailable := FormationArt.picture(visual, "unselectable", Vector2.ZERO, size)
		unavailable.name = "UnavailableState"

func _down_art() -> void:
	if not troop.down_cards.has(card.name) or get_meta("omit_down", false): return
	if selection_blocked(): return
	var down := OriginalFlatPlayer.new()
	down.name = "DownState"
	down.animation_path = "res://assets/battle/native/down_overlay/animation.json"
	visual.add_child(down)

func _portrait_emblem() -> void:
	# Ornament bounds differ by faction; their native 40px sockets share the same
	# (9, 9) inset. Stretching every ornament to 60px displaced and distorted it.
	var medallion: Texture2D = load("res://assets/formation/medallion_%d.png" % display_card.faction)
	var frame := FormationArt.picture(visual, "medallion_%d" % display_card.faction, Vector2(3, 1), medallion.get_size())
	frame.name = "ElementFrame"
	var element := FormationArt.picture(visual, "element_%d" % display_card.element, Vector2(12, 10), Vector2(40, 40))
	element.name = "ElementIcon"

func _skill(index: int, y: int, description: bool) -> void:
	var id: int = display_card["skill%d" % (index + 1)]
	if id == 0:
		return
	var s: Dictionary = troop.catalog.skills[id]
	FormationArt.picture(visual, "skill_detail" if description else "skill_strip", Vector2(6, y), Vector2(196, 150 if description else 38))
	var icon := SkillIconArt.player(visual, s, Vector2(9, y + 1))
	icon.name = "SkillTypeIcon%d" % (index + 1)
	if s.action == 1:
		var badge := FormationArt.picture(visual, "ap", Vector2(32, y), Vector2(19, 19))
		badge.name = "SkillCostBadge%d" % (index + 1)
		var shown_cost := str(skill_costs.get(index, s.ap))
		var ap := FormationArt.label(visual, shown_cost, Vector2(32, y), Vector2(19, 19), 13 if shown_cost.length() == 1 else 10, Color(0.08, 0.07, 0.04), HORIZONTAL_ALIGNMENT_CENTER)
		ap.name = "SkillCost%d" % (index + 1)
		ap.add_theme_font_override("font", CARD_TEXT_FONT)
		ap.add_theme_constant_override("outline_size", 0)
		ap.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		ap.add_theme_constant_override("shadow_offset_x", 0)
		ap.add_theme_constant_override("shadow_offset_y", 0)
		ap.size = Vector2(19, 19)
	var skill_name := FormationArt.label(visual, s.name, Vector2(50, y + 2), Vector2(147, 32), 18)
	# Bind the vector face explicitly: the title's SystemFont must not replace it.
	skill_name.add_theme_font_override("font", CARD_TEXT_FONT)
	skill_name.add_theme_color_override("font_color", Color.WHITE)
	skill_name.add_theme_color_override("font_outline_color", Color.BLACK)
	skill_name.add_theme_constant_override("outline_size", 8)
	skill_name.add_theme_constant_override("shadow_offset_x", 0)
	skill_name.add_theme_constant_override("shadow_offset_y", 0)
	if description:
		var text := FormationArt.label(visual, s.description, Vector2(15, y + 43), Vector2(180, 100), 15)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func flip_to(mode: int) -> void:
	if flipping:
		return
	flipping = true
	var tween := create_tween()
	tween.tween_property(visual, "scale:x", 0.015, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		detail_mode = mode
		redraw())
	tween.tween_property(visual, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: flipping = false)

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("troop") == troop and data.has("card") and (not troop.is_unavailable(data.card) or (data.get("from_leader", false) and data.card in troop.leaders)) and (leader or data.get("from_leader", false))

func _drop_data(_at: Vector2, data: Variant) -> void:
	if leader:
		card_dropped.emit(data.card)
	else:
		leader_removed.emit(data.card)

static func _number(value: float) -> String:
	return str(int(floor(value)))
