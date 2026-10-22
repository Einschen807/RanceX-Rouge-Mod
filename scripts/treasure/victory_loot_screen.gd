extends Control
class_name VictoryLootScreen
## WIN loot: a tall native loot panel (shells and the card chest) with the current
## leaders along the bottom. Map chests show the same panel without leaders.
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
var bonus_gold := 0
var gold_claimed := false
const GOLD_RANGES := {1: Vector2i(5, 10), 2: Vector2i(15, 25), 3: Vector2i(50, 60)}
## Native loot panel art is 612x572. Its middle is cut out (keeping the side
## borders and the centred emblem undistorted) for a taller, narrower panel.
const ART := preload("res://assets/treasure/loot_panel.png")
const ART_SIZE := Vector2(612, 572)
const EDGE := 14.0
const CENTRE_WIDTH := 460.0
const PANEL_SCALE := 0.9
const PANEL_SIZE := Vector2(EDGE * 2.0 + CENTRE_WIDTH, 572) * PANEL_SCALE
const ROW_SIZE := Vector2(362, 92)
const ROW_TOP := 112.0
const LEADER_SCALE := 0.84
var _finished := false
var _panel_at := Vector2((1920.0 - PANEL_SIZE.x) / 2.0, 238)

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
	_build_panel()
	BattleArt.label(_body, "搜刮", _panel_at + Vector2(0, 22), Vector2(PANEL_SIZE.x, 64), 38, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_row = _loot_row("CardChest", "Boss卡牌宝箱" if pool_id == 3 else ("精英卡牌宝箱" if pool_id == 2 else "卡牌宝箱"), "三选一" if pool_id == 3 else "五选二", _open_chest)
	TreasureArt.picture(_row.content, "native/gold_closed/atlas_0_1" if pool_id == 3 else "native/chest_closed/atlas_0_1", Vector2(18, 10), Vector2(80, 72))
	if victory:
		var limits: Vector2i = GOLD_RANGES[pool_id]
		gold_reward = rng.randi_range(limits.x, limits.y) + maxi(0, bonus_gold)
		_gold_row = _loot_row("ShellReward", "%d 贝壳" % gold_reward, "点击领取", _claim_gold)
		ShopArt.shell(_gold_row.content, Vector2(30, 14), Vector2(58, 64))
	_empty = BattleArt.label(_body, "搜刮完成", _panel_at + Vector2(0, 150), Vector2(PANEL_SIZE.x, 100), 30, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_empty.name = "LootComplete"
	_layout_rows(false)
	TreasureArt.button(_body, "继续", _panel_at + Vector2((PANEL_SIZE.x - 194.0) / 2.0, PANEL_SIZE.y - 116), _finish).name = "Continue"
	if not pools.load_catalog(troop.catalog):
		_row.disabled = true
		BattleArt.label(_body, "卡池数据加载失败", _panel_at + Vector2(0, 340), Vector2(PANEL_SIZE.x, 60), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		push_error("\n".join(pools.errors))
	_play_entrance()

## Left border + centre slice + right border of the native panel, scaled together.
func _build_panel() -> void:
	var panel := Control.new()
	panel.name = "LootPanel"
	panel.position = _panel_at
	panel.scale = Vector2.ONE * PANEL_SCALE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(panel)
	var centre_x := (ART_SIZE.x - CENTRE_WIDTH) / 2.0
	var pieces := [
		[Rect2(0, 0, EDGE, ART_SIZE.y), 0.0],
		[Rect2(centre_x, 0, CENTRE_WIDTH, ART_SIZE.y), EDGE],
		[Rect2(ART_SIZE.x - EDGE, 0, EDGE, ART_SIZE.y), EDGE + CENTRE_WIDTH],
	]
	for piece: Array in pieces:
		var region: Rect2 = piece[0]
		var atlas := AtlasTexture.new()
		atlas.atlas = ART
		atlas.region = region
		var slice := TextureRect.new()
		slice.texture = atlas
		slice.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slice.position = Vector2(float(piece[1]), 0)
		slice.size = region.size
		slice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(slice)

func _row_target(index: int) -> Vector2:
	return _panel_at + Vector2((PANEL_SIZE.x - ROW_SIZE.x) / 2.0, ROW_TOP + 108 * index)

func _loot_row(node_name: String, title: String, hint: String, callback: Callable) -> OriginalUiButton:
	var row := OriginalUiButton.make(_body, "formation", _row_target(0), ROW_SIZE, callback, "click", "res://assets/map/native")
	row.name = node_name
	row.art.scale = Vector2(ROW_SIZE.x / 194.0, 1.0)
	BattleArt.label(row.content, title, Vector2(108, 8), Vector2(ROW_SIZE.x - 124, 44), 26, Color.WHITE)
	var sub := BattleArt.label(row.content, hint, Vector2(110, 46), Vector2(ROW_SIZE.x - 124, 30), 19, Color("e8d9b5"))
	sub.name = "Hint"
	return row

func _play_entrance() -> void:
	# The panel fades in, rows slide in one after another, leaders rise from the bottom.
	var tween := create_tween().set_parallel(true)
	for item: CanvasItem in _body.get_children():
		if item == _row or item == _gold_row: continue
		item.modulate.a = 0.0
		tween.tween_property(item, "modulate:a", 1.0, 0.3).set_delay(0.08)
	var order := 0
	for row: OriginalUiButton in [_gold_row, _row]:
		if not is_instance_valid(row) or not row.visible: continue
		var x := row.position.x
		row.modulate.a = 0.0
		row.position.x += 40
		tween.tween_property(row, "modulate:a", 1.0, 0.25).set_delay(0.22 + order * 0.1)
		tween.tween_property(row, "position:x", x, 0.3).set_delay(0.22 + order * 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		order += 1
	if is_instance_valid(_leaders):
		var n := 0
		for card: Node in _leaders.get_children():
			var item := card as Control
			if item == null: continue
			var y := item.position.y
			item.position.y += 80
			item.modulate.a = 0.0
			tween.tween_property(item, "position:y", y, 0.35).set_delay(0.2 + n * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(item, "modulate:a", 1.0, 0.3).set_delay(0.2 + n * 0.05)
			n += 1

func _build_leaders() -> void:
	if not is_instance_valid(_leaders):
		_leaders = Control.new()
		_leaders.name = "VictoryLeaders"
		_leaders.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_leaders)
	else: BattleArt.clear(_leaders)
	# Slightly smaller leaders leave room for the taller loot panel above them.
	var step := 218.0 * LEADER_SCALE
	var left := (1920.0 - (troop.leaders.size() - 1) * step - 208.0 * LEADER_SCALE) / 2.0
	for index: int in range(troop.leaders.size()):
		var at := Vector2(left + step * index, 790)
		var card_name: String = troop.leaders[index]
		var slot: Control
		if card_name.is_empty():
			if troop.is_slot_unlocked(index): slot = BattleArt.picture(_leaders, "card_frame", at - Vector2(2, 2) * LEADER_SCALE)
			else: slot = FormationArt.picture(_leaders, "locked", at, Vector2(208, 312))
			slot.scale = Vector2.ONE * LEADER_SCALE
			continue
		var card := CardWidget.new()
		card.name = "Leader%d" % index
		card.setup(troop.catalog.find_name(card_name), troop, false, 0)
		card.disabled = true
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = at
		card.scale = Vector2.ONE * LEADER_SCALE
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
		var target := _row_target(index)
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
