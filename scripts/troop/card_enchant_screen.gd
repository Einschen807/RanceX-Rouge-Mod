extends CardUpgradeScreen
class_name CardEnchantScreen
## Enchanting reuses the upgrade selection list and comparison layout: choose a card, then
## one of its skills on the enlarged card. Each card accepts a single enchantment.
const ENCHANT_SOUND := preload("res://assets/audio/status_add.ogg")
const PANEL_SIZE := Vector2(208, 156)
var enchantment := ""
## Event extension: only skills meeting this requirement may be enchanted
## (see CardEnchantments.requirement_met, e.g. {"ap": 0}). Empty accepts every skill.
var requirement: Dictionary = {}
var _slot := -1
var _preview: TroopState
var _skill_buttons: Array[Button] = []

func _ready() -> void:
	super._ready()
	name = "CardEnchantScreen"

func _configure_formation() -> void:
	_formation.selection_check = func(display_name: String) -> bool: return not CardEnchantments.eligible_slots(troop, display_name, requirement).is_empty()

func _action_name() -> String:
	return "附魔"

func _refresh_remaining() -> void:
	_remaining_label.text = "附魔「%s」\n剩余 %d 次" % [enchantment, remaining]

func select_card(display_name: String) -> void:
	_settle_leaving()
	if _finished or is_instance_valid(_overlay) or is_instance_valid(_notice) or not troop.has_card(display_name): return
	var slots := CardEnchantments.eligible_slots(troop, display_name, requirement)
	if slots.is_empty():
		var enchanted := not CardEnchantments.of_card(troop.card_settings, display_name).is_empty()
		_show_notice("无法附魔", "该卡牌已附魔，每张卡牌只能附魔一次。" if enchanted else "该卡牌没有满足附魔条件的技能。")
		return
	var record := troop.catalog.find_name(display_name)
	var source := _source_rect(display_name)
	_selected = display_name
	_slot = -1
	_exit_prompt = false
	_make_overlay(true)
	_preview = TroopState.new()
	_preview.configure(troop.catalog, false)
	TroopCheckpoint.restore(_preview, TroopCheckpoint.capture(troop))
	var fading: Array[CanvasItem] = []
	fading.append(NativeSettingsArt.picture(_overlay, "section_decor", Vector2(612, 18), Vector2(696, 123)))
	fading.append(BattleArt.label(_overlay, "选择附魔技能", Vector2(612, 46), Vector2(696, 66), 42, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var before_view := _comparison_card(troop, record, BEFORE_AT, "当前卡牌", fading)
	var after_view := _comparison_card(_preview, record, AFTER_AT, "附魔后", fading)
	_add_pending_shade(after_view)
	_add_skill_choices(before_view, record, slots)
	var arrow := TextureRect.new()
	arrow.name = "UpgradeArrow"
	arrow.texture = preload("res://assets/ui/upgrade_arrow.png")
	arrow.position = Vector2(917, 420)
	arrow.size = arrow.texture.get_size()
	arrow.modulate = CardEnchantments.BLUE
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(arrow)
	fading.append(arrow)
	var effect := PackedStringArray()
	for line: String in String(CardEnchantments.shared().by_name.get(enchantment, {}).get("description", "")).split("\n"): effect.append(line.strip_edges())
	var text := BattleArt.label(_overlay, "「%s」%s" % [enchantment, " ".join(effect)], Vector2(260, 828), Vector2(1400, 50), 26, CardEnchantments.BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	fading.append(text)
	var back := _native_button("返回", Vector2(724, 900), _close_overlay, "cancel")
	back.name = "BackUpgrade"
	var confirm := _native_button("确认附魔", Vector2(1000, 900), confirm_upgrade)
	confirm.name = "ConfirmUpgrade"
	fading.append_array([back, confirm])
	fading.append_array(_skill_buttons)
	_play_intro(source, before_view, after_view, fading, [back])
	confirm.disabled = true
	back.grab_focus()
	_sway(arrow)
	# A single eligible skill is chosen for the player; the choice remains visible.
	if slots.size() == 1: _skill_buttons[0].button_pressed = true

## Clickable frames over the enlarged card's two skill panels; refused skills are dimmed.
func _add_skill_choices(view: CardWidget, record: Dictionary, slots: Array[int]) -> void:
	_skill_buttons.clear()
	var group := ButtonGroup.new()
	for slot: int in range(2):
		if int(record.get("skill%d" % (slot + 1), 0)) == 0: continue
		var at := Vector2(0, PANEL_SIZE.y * slot)
		if slot not in slots:
			var shade := ColorRect.new()
			shade.name = "RefusedSkill%d" % (slot + 1)
			shade.position = at
			shade.size = PANEL_SIZE
			shade.color = Color(0, 0, 0, 0.62)
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.add_child(shade)
			continue
		var button := Button.new()
		button.name = "EnchantSkill%d" % (slot + 1)
		button.position = at
		button.size = PANEL_SIZE
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var blue := CardEnchantments.BLUE
		for style: String in ["normal", "focus", "disabled"]: button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", _frame(Color(blue, 0.6), Color(blue, 0.08), 2))
		for style: String in ["pressed", "hover_pressed"]: button.add_theme_stylebox_override(style, _frame(blue, Color(blue, 0.16), 3))
		button.toggled.connect(func(on: bool) -> void:
			if on: _choose_slot(slot))
		view.add_child(button)
		_skill_buttons.append(button)

func _frame(border: Color, fill: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	return style

func _add_pending_shade(view: CardWidget) -> void:
	var shade := ColorRect.new()
	shade.name = "PendingShade"
	shade.size = Vector2(208, 312)
	shade.color = Color(0, 0, 0, 0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(shade)
	var hint := FormationArt.label(shade, "请选择左侧卡牌中\n要附魔的技能", Vector2(0, 126), Vector2(208, 60), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF

func _choose_slot(slot: int) -> void:
	if not is_instance_valid(_overlay) or _selected.is_empty(): return
	get_node("/root/UIAudio").play()
	_slot = slot
	# The preview always starts from the live card settings, so switching skills moves the enchantment.
	_preview.card_settings = troop.card_settings.duplicate(true)
	_preview.enchant_card(_selected, slot, enchantment, requirement)
	var view := _overlay.get_node_or_null("AfterCard") as CardWidget
	if view != null:
		var shade := view.get_node_or_null("PendingShade")
		if shade != null: shade.queue_free()
		view.redraw()
		var label := view.visual.get_node_or_null("SkillDescription%d" % (slot + 1)) as CanvasItem
		if label != null:
			label.modulate = Color(1.6, 1.8, 2.4)
			label.create_tween().tween_property(label, "modulate", Color.WHITE, 0.3)
	var confirm := _overlay.get_node_or_null("ConfirmUpgrade") as OriginalUiButton
	if confirm != null:
		confirm.disabled = false
		confirm.grab_focus()

func confirm_upgrade() -> void:
	_finish_intro()
	if _finished or _exit_prompt or _selected.is_empty() or _slot < 0 or remaining <= 0 or not is_instance_valid(_overlay): return
	if not troop.enchant_card(_selected, _slot, enchantment, requirement): return
	remaining -= 1
	_used += 1
	_refresh_remaining()
	var view := _overlay.get_node_or_null("AfterCard") as CardWidget
	var before_view := _overlay.get_node_or_null("BeforeCard") as CanvasItem
	var slot := _slot
	for button: Button in _skill_buttons: button.disabled = true
	var node := _detach_overlay()
	_disable_buttons(node)
	_pending_finish = remaining == 0
	_enchant_effect(node, view, before_view, slot)

## Blue enchanting light gathers on the chosen skill panel: a bright core, two expanding rings
## and rising motes, then the card flashes blue. Right click settles it like the forge.
func _enchant_effect(node: Control, view: CardWidget, before_view: CanvasItem, slot: int) -> void:
	_leaving_tween = node.create_tween().set_parallel(true)
	if before_view != null: _leaving_tween.tween_property(before_view, "modulate:a", 0.3, 0.2)
	if view == null:
		_leaving_tween.chain().tween_callback(_settle_leaving)
		return
	var center := AFTER_AT + (Vector2(0, PANEL_SIZE.y * slot) + PANEL_SIZE / 2.0) * CARD_SCALE
	_leaving_tween.tween_callback(_burst.bind(node, view, center)).set_delay(0.15)
	_leaving_tween.tween_callback(_burst.bind(node, view, center)).set_delay(0.5)
	var done := 0.9
	_leaving_tween.tween_callback(func() -> void:
		_sfx(FINISH_SOUND)
		view.visual.modulate = Color(1.3, 1.6, 2.3)).set_delay(done)
	_leaving_tween.tween_property(view.visual, "modulate", Color.WHITE, 0.5).set_delay(done + 0.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not (_pending_finish and fade_out):
		_leaving_tween.tween_property(node, "modulate:a", 0.0, 0.26).set_delay(done + 0.5)
	_leaving_tween.chain().tween_callback(_settle_leaving)

func _burst(node: Control, view: CardWidget, point: Vector2) -> void:
	_sfx(ENCHANT_SOUND)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var blue := CardEnchantments.BLUE
	var core := Sprite2D.new()
	core.texture = SPARK
	core.material = additive
	core.modulate = Color(0.75, 0.9, 1.0)
	core.position = point
	core.scale = Vector2.ONE * 0.25
	node.add_child(core)
	var flash := core.create_tween()
	flash.tween_property(core, "scale", Vector2.ONE * 0.8, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash.tween_property(core, "modulate:a", 0.0, 0.3)
	flash.tween_callback(core.queue_free)
	var ring := Node2D.new()
	ring.position = point
	ring.rotation = randf() * TAU
	node.add_child(ring)
	var arcs: Array[Line2D] = []
	for n: int in range(3):
		for inner: bool in [false, true]:
			var arc := Line2D.new()
			arc.material = additive
			arc.width = 3.0 if inner else 10.0
			arc.default_color = Color(0.85, 0.95, 1.0) if inner else Color(blue, 0.7)
			arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
			arc.end_cap_mode = Line2D.LINE_CAP_ROUND
			arc.set_meta("start", n * TAU / 3.0)
			arc.set_meta("span", TAU / 3.0 - 0.3)
			ring.add_child(arc)
			arcs.append(arc)
	var grow := ring.create_tween()
	grow.tween_method(_draw_ring.bind(arcs), 30.0, 210.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grow.parallel().tween_property(ring, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	grow.parallel().tween_property(ring, "rotation", ring.rotation - 0.6, 0.55)
	grow.tween_callback(ring.queue_free)
	var motes := CPUParticles2D.new()
	motes.position = point
	# The white spark tints cleanly; the forge ember sprite is baked orange.
	motes.texture = SPARK
	motes.material = additive
	motes.one_shot = true
	motes.explosiveness = 0.85
	motes.amount = 22
	motes.lifetime = 0.8
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = PANEL_SIZE * CARD_SCALE * 0.42
	motes.direction = Vector2.UP
	motes.spread = 25.0
	motes.initial_velocity_min = 80.0
	motes.initial_velocity_max = 220.0
	motes.gravity = Vector2(0, -120)
	motes.scale_amount_min = 0.05
	motes.scale_amount_max = 0.12
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.95, 1.0, 1.0))
	fade.set_color(1, Color(blue, 0.0))
	motes.color_ramp = fade
	node.add_child(motes)
	motes.emitting = true
	motes.finished.connect(motes.queue_free)
	view.visual.modulate = Color(1.15, 1.3, 1.6)
	view.create_tween().tween_property(view.visual, "modulate", Color.WHITE, 0.25)
