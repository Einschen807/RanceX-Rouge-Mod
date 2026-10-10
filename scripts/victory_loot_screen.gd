extends Control
class_name VictoryLootScreen
signal completed
var troop: TroopState
var rng: RandomNumberGenerator
var pool_id := 1
var victory := true
var chest: TreasureChest
var reward: TreasureRewardScreen
var pools := TreasurePoolCatalog.new()
var _body: Control
var _row: OriginalUiButton
var _gold_row: OriginalUiButton
var _empty: Label
var _row_motion: Tween
var _leaders: Control
var gold_reward := 0
var gold_claimed := false
const GOLD_RANGES := {1: Vector2i(5, 10), 2: Vector2i(15, 25), 3: Vector2i(50, 60)}
var _finished := false

func _ready() -> void:
	name = "VictoryLoot"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("modal_overlay")
	TreasureArt.backdrop(self)
	if victory: TreasureArt.flat(self, "win")
	else: BattleArt.label(self, "发现宝箱", Vector2(600, 70), Vector2(720, 90), 52, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	if victory:
		_build_leaders()
		troop.changed.connect(_build_leaders)
	_body = Control.new()
	_body.name = "LootInterface"
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	TreasureArt.picture(_body, "loot_panel", Vector2(654, 250), Vector2(612, 472))
	BattleArt.label(_body, "搜刮", Vector2(700, 270), Vector2(520, 70), 38, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_row = OriginalUiButton.make(_body, "formation", Vector2(695, 366), Vector2(530, 92), _open_chest, "click", "res://assets/map/native")
	_row.name = "CardChest"
	_row.art.scale = Vector2(530.0 / 194.0, 1.0)
	TreasureArt.picture(_row.content, "native/gold_closed/atlas_0_1" if pool_id == 3 else "native/chest_closed/atlas_0_1", Vector2(25, 10), Vector2(80, 72))
	BattleArt.label(_row.content, "Boss卡牌宝箱" if pool_id == 3 else ("精英卡牌宝箱" if pool_id == 2 else "卡牌宝箱"), Vector2(124, 10), Vector2(380, 72), 28, Color.WHITE)
	if victory:
		var limits: Vector2i = GOLD_RANGES[pool_id]
		gold_reward = rng.randi_range(limits.x, limits.y)
		_gold_row = OriginalUiButton.make(_body, "formation", Vector2(695, 366), Vector2(530, 92), _claim_gold, "click", "res://assets/map/native")
		_gold_row.name = "ShellReward"
		_gold_row.art.scale = Vector2(530.0 / 194.0, 1.0)
		ShopArt.shell(_gold_row.content, Vector2(39, 14), Vector2(58, 64))
		BattleArt.label(_gold_row.content, "%d 贝壳" % gold_reward, Vector2(124, 10), Vector2(380, 72), 28, Color.WHITE)
	_empty = BattleArt.label(_body, "搜刮完成", Vector2(700, 390), Vector2(520, 100), 30, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_empty.name = "LootComplete"
	_layout_rows(false)
	TreasureArt.button(_body, "继续", Vector2(863, 617), _finish).name = "Continue"
	if not pools.load_catalog(troop.catalog):
		_row.disabled = true
		BattleArt.label(_body, "卡池数据加载失败", Vector2(700, 610), Vector2(520, 70), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		push_error("\n".join(pools.errors))

func _build_leaders() -> void:
	if not is_instance_valid(_leaders):
		_leaders = Control.new()
		_leaders.name = "VictoryLeaders"
		_leaders.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_leaders)
	else: BattleArt.clear(_leaders)
	for index: int in range(troop.leaders.size()):
		var at := Vector2(200 + 218 * index, 730)
		var card_name: String = troop.leaders[index]
		if card_name.is_empty():
			if troop.is_slot_unlocked(index): BattleArt.picture(_leaders, "card_frame", at - Vector2(2, 2))
			else: FormationArt.picture(_leaders, "locked", at, Vector2(208, 312))
			continue
		var card := CardWidget.new()
		card.name = "Leader%d" % index
		card.setup(troop.catalog.find_name(card_name), troop, false, 0)
		card.disabled = true
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = at
		card.set_meta("omit_unavailable", true)
		_leaders.add_child(card)
		for decoration: String in ["LeaderBadge", "LeaderGlow"]:
			if card.visual.has_node(decoration): card.visual.get_node(decoration).hide()

func _layout_rows(animated := true) -> void:
	if is_instance_valid(_row_motion): _row_motion.kill()
	if animated: _row_motion = create_tween().set_parallel(true)
	var remaining: Array[OriginalUiButton] = []
	if is_instance_valid(_gold_row):
		_gold_row.visible = not gold_claimed
		if _gold_row.visible: remaining.append(_gold_row)
	_row.visible = chest == null or not chest.claimed
	if _row.visible: remaining.append(_row)
	for index: int in range(remaining.size()):
		var target := Vector2(695, 366 + 112 * index)
		if animated:
			_row_motion.tween_property(remaining[index], "position", target, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else: remaining[index].position = target
	if animated and remaining.is_empty(): _row_motion.kill()
	_empty.visible = remaining.is_empty()

func _claim_gold() -> void:
	if gold_claimed or _finished or is_instance_valid(reward): return
	gold_claimed = true
	_layout_rows()
	troop.add_gold(gold_reward)

func _open_chest() -> void:
	if is_instance_valid(reward) or _finished: return
	if chest == null: chest = TreasureChest.open(pool_id, troop, rng, pools)
	if chest == null or chest.claimed: return
	_body.hide()
	reward = TreasureRewardScreen.new()
	reward.exit_blackout = true
	reward.troop = troop
	reward.chest = chest
	reward.back_requested.connect(func() -> void:
		reward = null
		_body.show()
		_layout_rows())
	reward.completed.connect(func() -> void:
		reward = null
		_body.show()
		_layout_rows())
	add_child(reward)

func _finish() -> void:
	if _finished or is_instance_valid(reward): return
	_finished = true
	_row.disabled = true
	var transition := get_node("/root/ScreenTransition")
	while transition.busy: await get_tree().process_frame
	transition.play(_complete_finish)

func _complete_finish() -> void:
	remove_from_group("modal_overlay")
	completed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or is_instance_valid(reward): return
	if get_node("/root/DebugConsole").panel.visible or is_instance_valid(get_node("/root/Settings").panel): return
	get_viewport().set_input_as_handled()
	_finish()
