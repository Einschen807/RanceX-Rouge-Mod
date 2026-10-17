extends Control
class_name CardUpgradeScreen
## Shared selection flow. Rest upgrades commit together or roll back together.
signal completed
signal cancelled
var troop: TroopState
var remaining := 1
var rest_mode := false
var _used := 0
var _entry: Dictionary
var _formation: TroopFormation
var _remaining_label: Label
var _overlay: Control
var _selected := ""
var _exit_prompt := false
var _finished := false
var _previous_focus: WeakRef

func _ready() -> void:
	name = "CardUpgradeScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("modal_overlay")
	add_to_group("card_upgrade_screen")
	_previous_focus = weakref(get_viewport().gui_get_focus_owner())
	_entry = TroopCheckpoint.capture(troop)
	_formation = (load("res://scenes/troop_formation.tscn") as PackedScene).instantiate() as TroopFormation
	_formation.configure(troop)
	_formation.upgrade_selection = true
	_formation.upgrade_selected.connect(select_card)
	_formation.close_requested.connect(request_back)
	add_child(_formation)
	_remaining_label = BattleArt.label(_formation, "", Vector2(1555, 660), Vector2(350, 105), 25, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_remaining_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_remaining()

func _refresh_remaining() -> void:
	_remaining_label.text = "强化卡牌\n剩余 %d 次" % remaining

func _make_overlay() -> Control:
	_formation.process_mode = Node.PROCESS_MODE_DISABLED
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.02, 0.015, 0.94)
	_overlay.add_child(shade)
	return _overlay

func select_card(display_name: String) -> void:
	if _finished or is_instance_valid(_overlay) or not troop.has_card(display_name): return
	_selected = display_name
	_exit_prompt = false
	_make_overlay()
	var preview := TroopState.new()
	preview.configure(troop.catalog, false)
	TroopCheckpoint.restore(preview, TroopCheckpoint.capture(troop))
	preview.upgrade_card(display_name)
	var before := troop.catalog.find_name(display_name)
	var after := troop.catalog.upgrade_preview(before)
	BattleArt.label(_overlay, "确认强化", Vector2(460, 90), Vector2(1000, 70), 42, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_comparison_card(troop, before, Vector2(410, 260), "当前卡牌")
	_comparison_card(preview, after, Vector2(1140, 260), "强化后")
	BattleArt.label(_overlay, "→", Vector2(850, 430), Vector2(220, 110), 86, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var text := "强化版本替代原卡，保留等级和技能使用状态。" if before.name != after.name else "卡牌等级提升 5 级，保留技能使用状态。"
	BattleArt.label(_overlay, text, Vector2(360, 865), Vector2(1200, 60), 27, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	BattleArt.text_button(_overlay, "返回", Vector2(38, 975), Vector2(180, 72), _close_overlay)
	var confirm := BattleArt.text_button(_overlay, "确认", Vector2(1685, 975), Vector2(195, 72), confirm_upgrade)
	confirm.name = "ConfirmUpgrade"
	confirm.grab_focus()

func _comparison_card(state: TroopState, record: Dictionary, at: Vector2, caption: String) -> void:
	var widget := CardWidget.new()
	widget.name = "BeforeCard" if state == troop else "AfterCard"
	widget.setup(record, state, false, 2)
	widget.set_meta("upgrade_selection", true)
	widget.set_meta("omit_down", true)
	for slot: int in range(2):
		var skill: Dictionary = state.catalog.skills.get(record["skill%d" % (slot + 1)], {})
		if not skill.is_empty():
			widget.skill_costs[slot] = "×" if state.skill_runtime.is_spent(record.name, skill, slot) else state.skill_runtime.ap_cost(record.name, skill, slot)
	widget.position = at
	widget.scale = Vector2.ONE * 1.8
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(widget)
	BattleArt.label(_overlay, caption + "  ★%d" % state.level(record.name), at - Vector2(50, 68), Vector2(475, 54), 30, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	BattleArt.label(_overlay, record.name, at + Vector2(-100, 575), Vector2(575, 50), 27, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

func confirm_upgrade() -> void:
	if _finished or _exit_prompt or _selected.is_empty() or remaining <= 0: return
	if not troop.upgrade_card(_selected): return
	remaining -= 1
	_used += 1
	_close_overlay()
	_refresh_remaining()
	if remaining == 0: _finish(true)

func request_back() -> void:
	if _finished: return
	if is_instance_valid(_overlay):
		_close_overlay()
		return
	if rest_mode and _used == 0:
		_finish(false)
		return
	_exit_prompt = true
	_make_overlay()
	(_overlay.get_child(0) as ColorRect).color = Color(0, 0, 0, 0.65)
	var panel := Panel.new()
	panel.position = Vector2(460, 330)
	panel.size = Vector2(1000, 400)
	panel.add_theme_stylebox_override("panel", BattleArt.panel_style())
	_overlay.add_child(panel)
	BattleArt.label(_overlay, "退出强化", Vector2(535, 343), Vector2(850, 40), 30, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var text := "你还剩%d次强化卡牌没有选择，确认要退出吗？" % remaining
	if rest_mode:
		text = "你还剩%d次强化没有使用，\n退出后将返还本次所有的强化选择，是否要退出？" % remaining
	var body := BattleArt.label(_overlay, text, Vector2(535, 432), Vector2(850, 150), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BattleArt.text_button(_overlay, "确认", Vector2(660, 625), Vector2(220, 76), _confirm_exit)
	var back := BattleArt.text_button(_overlay, "返回" if rest_mode else "取消", Vector2(1040, 625), Vector2(220, 76), _close_overlay)
	back.name = "CancelExit"
	back.grab_focus()

func _confirm_exit() -> void:
	if rest_mode: TroopCheckpoint.restore(troop, _entry); troop.changed.emit()
	_finish(false)

func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		remove_child(_overlay)
		_overlay.queue_free()
	_overlay = null
	_selected = ""
	_exit_prompt = false
	_formation.process_mode = Node.PROCESS_MODE_INHERIT
	_formation._tabs[_formation.selected_faction - 1].grab_focus()

func _finish(success: bool) -> void:
	if _finished: return
	_finished = true
	remove_from_group("modal_overlay")
	remove_from_group("card_upgrade_screen")
	if success: completed.emit()
	else: cancelled.emit()
	var focus: Control = _previous_focus.get_ref() if _previous_focus != null else null
	if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree(): focus.grab_focus()
	queue_free()

func _input(event: InputEvent) -> void:
	var console := get_node("/root/DebugConsole")
	if console.panel.visible or get_node("/root/ScreenTransition").busy: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		request_back()
