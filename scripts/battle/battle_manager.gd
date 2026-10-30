extends Node
signal run_battle_closed(outcome: String, player_hp: float, max_hp: float)
## A normal run can register its owned TroopState, even without a formation open.
var run_troop: TroopState
var active: BattleScene
var origin: TroopFormation
var _origin_process_mode := Node.PROCESS_MODE_INHERIT
var _layer: CanvasLayer
var _run_node_battle := false
var _treasure_layer: CanvasLayer
var _treasure: TreasureRewardScreen
var _debug_troop: TroopState
## Relic chest or relic choice screen; both emit completed when closed.
var _relic_chest: Control
## Outcome of the most recently closed battle (胜利/败北), read by event sequences.
var last_outcome := ""
var _upgrade: CardUpgradeScreen
var _upgrade_layer: CanvasLayer
var _upgrade_battle_mode := Node.PROCESS_MODE_INHERIT
## Queued type that opens a default-pool relic chest instead of a card chest.
const RELIC_CHEST := -1
## Chests granted by relics (求人票, 压箱底的宝物); each opens once no other screen blocks it.
var _queued_treasures: Array[int] = []

func queue_treasures(type: int, count: int) -> void:
	for i: int in range(count): _queued_treasures.append(type)
	# Open the first right away when possible, so event commands wait for it.
	_process(0.0)

func _process(_delta: float) -> void:
	if _queued_treasures.is_empty(): return
	if is_instance_valid(get_node("/root/ShopManager").active) or is_instance_valid(_relic_chest) or is_instance_valid(_treasure) or is_instance_valid(_upgrade) or is_instance_valid(active) or get_node("/root/ScreenTransition").busy: return
	var type: int = _queued_treasures.pop_front()
	if type == RELIC_CHEST: launch_relic()
	else: launch_treasure(type)

func upgrade_test_cards() -> String:
	if is_instance_valid(active) or is_instance_valid(_upgrade) or is_instance_valid(_treasure) or is_instance_valid(_relic_chest) or is_instance_valid(get_node("/root/ShopManager").active):
		return "upgrade test 只能在百科大全的卡牌总览部队编制界面使用。"
	if get_node("/root/ScreenTransition").busy: return "界面切换中，请稍后再输入 upgrade test。"
	for modal: Node in get_tree().get_nodes_in_group("modal_overlay"):
		if modal != get_node("/root/DebugConsole").panel: return "请先关闭当前弹窗。"
	for node: Node in get_tree().get_nodes_in_group("encyclopedia_card_overviews"):
		if not node is TroopFormation or not node.is_visible_in_tree() or not node.can_process() or not node.troop.encyclopedia_mode or node.upgrade_selection: continue
		if node._transitioning or node._flip_locked or is_instance_valid(node._drag_art): return "请等待当前卡牌操作结束后再输入 upgrade test。"
		var count := 0
		# This inventory belongs to this overview instance; battle uses the same state.
		var upgraded: bool = not node.test_upgrades
		for card: Dictionary in node.troop.available.duplicate():
			if node.troop.set_card_upgraded(card.name, upgraded): count += 1
		node.test_upgrades = upgraded
		return "卡牌总览临时强化%s：%d张，%s。" % ["已开启" if upgraded else "已关闭", count, "可使用 battle 测试，再次输入或退出卡牌总览后恢复" if upgraded else "已恢复普通版本"]
	return "upgrade test 只能在百科大全的卡牌总览部队编制界面使用。"

func launch_upgrade(count := 1, source: TroopState = null) -> String:
	if count <= 0: return "用法：upgrade [正整数数量]"
	var refusal := _card_screen_refusal("强化")
	if not refusal.is_empty(): return refusal
	if source == null: source = current_troop()
	if source == null or source.available.is_empty(): return "当前没有可强化的卡牌。"
	var screen := CardUpgradeScreen.new()
	screen.remaining = count
	_open_card_screen(screen, source)
	return "进入卡牌强化：%d次。" % count

## requirement: event extension limiting which skills qualify (CardEnchantments.requirement_met).
func launch_enchant(enchantment: String, source: TroopState = null, requirement: Dictionary = {}) -> String:
	if not CardEnchantments.shared().by_name.has(enchantment): return "未找到附魔：" + enchantment
	var refusal := _card_screen_refusal("附魔")
	if not refusal.is_empty(): return refusal
	if source == null: source = current_troop()
	if source == null or source.available.is_empty(): return "当前没有可附魔的卡牌。"
	if not source.available.any(func(card: Dictionary) -> bool: return not CardEnchantments.eligible_slots(source, card.name, requirement).is_empty()):
		return "没有可附魔「%s」的卡牌。" % enchantment
	var screen := CardEnchantScreen.new()
	screen.enchantment = enchantment
	screen.requirement = requirement
	_open_card_screen(screen, source)
	return "进入卡牌附魔：" + enchantment

func _card_screen_refusal(action: String) -> String:
	if is_instance_valid(_upgrade) or is_instance_valid(_treasure) or is_instance_valid(_relic_chest) or get_node("/root/ScreenTransition").busy: return "当前界面不能%s卡牌。" % action
	if get_tree().get_first_node_in_group("modal_overlay") != null and not get_node("/root/DebugConsole").panel.visible: return "请先关闭当前弹窗。"
	if is_instance_valid(active) and (active.input_locked or is_instance_valid(active.formation) or active.battle.phase == "result"): return "请等待当前战斗操作结束。"
	return ""

func _open_card_screen(screen: CardUpgradeScreen, source: TroopState) -> void:
	if is_instance_valid(active):
		_upgrade_battle_mode = active.process_mode
		active.process_mode = Node.PROCESS_MODE_DISABLED
	_upgrade_layer = CanvasLayer.new()
	_upgrade_layer.layer = 95
	add_child(_upgrade_layer)
	_upgrade = screen
	_upgrade.troop = source
	_upgrade.completed.connect(_close_upgrade)
	_upgrade.cancelled.connect(_close_upgrade)
	_upgrade_layer.add_child(_upgrade)

func _close_upgrade() -> void:
	_upgrade = null
	if is_instance_valid(_upgrade_layer): _upgrade_layer.queue_free()
	if is_instance_valid(active):
		active.process_mode = _upgrade_battle_mode
		active.battle.sync_formation(active.battle.troop.leaders.duplicate())
		active._refresh()

func launch_run_encounter(identity: String, missing_hp: float) -> String:
	if is_instance_valid(get_node("/root/ShopManager").active): return "请先离开商店。"
	if is_instance_valid(active) or is_instance_valid(_relic_chest) or is_instance_valid(_treasure) or get_node("/root/ScreenTransition").busy: return "当前不能进入新的战斗。"
	if run_troop == null: return "没有正在进行的部队。"
	var monsters := MonsterCatalog.new()
	if not monsters.load_catalog(run_troop.catalog.skills) or not monsters.monsters.has(identity): return "节点怪物数据无效：" + identity
	_run_node_battle = true
	get_node("/root/ScreenTransition").play(_enter_run_battle.bind(monsters, identity, missing_hp))
	return ""

func _enter_run_battle(monsters: MonsterCatalog, identity: String, missing_hp: float) -> void:
	_enter_battle(run_troop, monsters, identity, null)
	var room: String = get_node("/root/RunSession").pending.get("type", "monster")
	active.reward_pool = 3 if room == "boss" else (2 if room == "elite" else 1)
	active.battle.entry_missing_hp = missing_hp
	active.battle.sync_formation()
	active.battle.preparation_checkpoint = BattleCheckpoint.capture(active.battle)

func register_run(state: TroopState) -> void:
	run_troop = state

func clear_run() -> void:
	# Closing a suspended battle must not advance its map node or award a reward.
	_run_node_battle = false
	_queued_treasures.clear()
	if is_instance_valid(_upgrade): _close_upgrade()
	close()
	if is_instance_valid(_relic_chest): _close_relic_chest()
	if is_instance_valid(_treasure): _close_treasure()
	run_troop = null
	_debug_troop = null

func current_troop(create_debug := true) -> TroopState:
	if is_instance_valid(active): return active.battle.troop
	for node: Node in get_tree().get_nodes_in_group("troop_formations"):
		if node is TroopFormation and node.is_visible_in_tree() and not node.troop.encyclopedia_mode: return node.troop
	if run_troop != null: return run_troop
	if _debug_troop == null and create_debug:
		var catalog := CardCatalog.new()
		if not catalog.load_catalog(): return null
		_debug_troop = TroopState.new()
		_debug_troop.configure(catalog, false, ["Lv42 兰斯"])
	return _debug_troop

func grant(kind: String, display_name: String) -> String:
	var source := current_troop()
	if source == null: return "数据加载失败。"
	get_node("/root/RelicHUD").bind_troop(source)
	if kind == "relic":
		var relics := RelicCatalog.new()
		if not relics.load_catalog(): return "遗物数据加载失败：" + "\n".join(relics.errors)
		if not relics.by_name.has(display_name): return "未找到遗物：" + display_name
		if not source.acquire_relic(display_name): return "已拥有遗物：" + display_name
		return "获得遗物：" + display_name
	var card := source.catalog.find_name(display_name)
	if card.is_empty() or CardCatalog.is_upgraded(card): return "未找到基础卡牌：" + display_name
	source.acquire_card(display_name)
	if is_instance_valid(active):
		active.battle.sync_formation(source.leaders.duplicate())
		active._refresh()
	return "获得卡牌：" + display_name

func launch_relic(pool := "默认遗物池") -> String:
	if is_instance_valid(get_node("/root/ShopManager").active): return "请先离开商店。"
	if is_instance_valid(_relic_chest) or is_instance_valid(_treasure) or get_node("/root/ScreenTransition").busy or is_instance_valid(active): return "当前界面不能打开新的宝箱。"
	var source := current_troop()
	if source == null: return "数据加载失败。"
	var relics := RelicCatalog.new()
	if not relics.load_catalog(): return "遗物数据加载失败：" + "\n".join(relics.errors)
	if not relics.pools.has(pool): return "未找到遗物池：" + pool
	var record := relics.draw(pool, source.relics, get_node("/root/RunAutosave").rng)
	if record.is_empty(): return "遗物池中没有尚未获得的遗物。"
	get_node("/root/RelicHUD").bind_troop(source)
	_treasure_layer = CanvasLayer.new()
	_treasure_layer.layer = 70
	add_child(_treasure_layer)
	var chest := RelicChestScreen.new()
	chest.troop = source
	chest.record = record
	chest.completed.connect(_close_relic_chest)
	_relic_chest = chest
	_treasure_layer.add_child(chest)
	return "打开遗物宝箱：" + pool

## Event and console choice of one relic from a list; owned names are skipped.
func launch_relic_choice(names: PackedStringArray, mandatory := false) -> String:
	if is_instance_valid(get_node("/root/ShopManager").active): return "请先离开商店。"
	if is_instance_valid(_relic_chest) or is_instance_valid(_treasure) or get_node("/root/ScreenTransition").busy or is_instance_valid(active): return "当前界面不能打开遗物选择。"
	var source := current_troop()
	if source == null: return "数据加载失败。"
	var relics := RelicCatalog.new()
	if not relics.load_catalog(): return "遗物数据加载失败：" + "
".join(relics.errors)
	var records: Array[Dictionary] = []
	for name: String in names:
		if not relics.by_name.has(name): return "未找到遗物：" + name
		if name not in source.relics: records.append(relics.by_name[name])
	if records.is_empty(): return "没有可获得的遗物。"
	get_node("/root/RelicHUD").bind_troop(source)
	_treasure_layer = CanvasLayer.new()
	_treasure_layer.layer = 70
	add_child(_treasure_layer)
	var screen := RelicChoiceScreen.new()
	screen.troop = source
	screen.records = records
	screen.mandatory = mandatory
	screen.completed.connect(_close_relic_chest)
	_relic_chest = screen
	_treasure_layer.add_child(screen)
	return "选择遗物：" + "、".join(records.map(func(record: Dictionary) -> String: return record.name))

## Grants up to count random unowned relics from the list.
func grant_random_relics(count: int, names: PackedStringArray) -> String:
	var source := current_troop()
	if source == null: return "数据加载失败。"
	var relics := RelicCatalog.new()
	if not relics.load_catalog(): return "遗物数据加载失败：" + "
".join(relics.errors)
	var candidates: Array[String] = []
	for name: String in names:
		if not relics.by_name.has(name): return "未找到遗物：" + name
		if name not in source.relics and name not in candidates: candidates.append(name)
	if candidates.is_empty(): return "没有可获得的遗物。"
	get_node("/root/RelicHUD").bind_troop(source)
	var rng: RandomNumberGenerator = get_node("/root/RunAutosave").rng
	var gained: Array[String] = []
	while gained.size() < count and not candidates.is_empty():
		var name: String = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		if source.acquire_relic(name, Vector2(960 + (gained.size() - 1.5) * 120, 540)): gained.append(name)
	return "获得遗物：" + "、".join(gained)

func _close_relic_chest() -> void:
	_relic_chest = null
	if is_instance_valid(_treasure_layer): _treasure_layer.queue_free()

func launch_treasure(type: int) -> String:
	if is_instance_valid(get_node("/root/ShopManager").active): return "请先离开商店。"
	if type not in [0, 1, 2, 3]: return "用法：treasure 0|1|2|3"
	if is_instance_valid(_relic_chest) or is_instance_valid(_treasure) or get_node("/root/ScreenTransition").busy or is_instance_valid(active): return "当前界面不能打开新的宝箱。"
	var source := run_troop
	for node: Node in get_tree().get_nodes_in_group("troop_formations"):
		if node is TroopFormation and node.is_visible_in_tree():
			source = node.troop
			break
	if source == null:
		if _debug_troop == null:
			var catalog := CardCatalog.new()
			if not catalog.load_catalog(): return "卡牌数据加载失败。"
			_debug_troop = TroopState.new()
			_debug_troop.configure(catalog, false, ["Lv42 兰斯"])
		source = _debug_troop
	var pools := TreasurePoolCatalog.new()
	if not pools.load_catalog(source.catalog): return "卡池数据加载失败：\n" + "\n".join(pools.errors)
	var chest := TreasureChest.open(type, source, get_node("/root/RunAutosave").rng, pools)
	if chest == null: return "宝箱卡池无法生成卡牌。"
	_treasure_layer = CanvasLayer.new()
	_treasure_layer.layer = 70
	add_child(_treasure_layer)
	_treasure = TreasureRewardScreen.new()
	_treasure.chest = chest
	_treasure.troop = source
	_treasure.standalone = true
	_treasure.completed.connect(_close_treasure)
	_treasure.back_requested.connect(_close_treasure)
	_treasure_layer.add_child(_treasure)
	return "打开宝箱：" + TreasurePoolCatalog.POOL_NAMES[chest.pool_id - 1]

func _close_treasure() -> void:
	_treasure = null
	if is_instance_valid(_treasure_layer): _treasure_layer.queue_free()

func launch(identity: String) -> String:
	if is_instance_valid(_upgrade): return "请先结束卡牌强化。"
	if is_instance_valid(get_node("/root/ShopManager").active): return "请先离开商店。"
	if is_instance_valid(_treasure) or is_instance_valid(_relic_chest): return "请先结束当前宝箱界面。"
	if get_node("/root/ScreenTransition").busy: return "界面切换中，请稍后再进入战斗。"
	var source: TroopState = active.battle.troop if is_instance_valid(active) else run_troop
	var formation: TroopFormation
	if not is_instance_valid(active):
		for node: Node in get_tree().get_nodes_in_group("troop_formations"):
			if node is TroopFormation and node.is_visible_in_tree():
				formation = node
				source = formation.troop
				break
	if source == null or source.available.is_empty():
		return "当前没有可用卡组，battle 指令未执行。"
	var monsters := MonsterCatalog.new()
	if not monsters.load_catalog(source.catalog.skills):
		return "怪物数据加载失败：\n" + "\n".join(monsters.errors)
	if not monsters.monsters.has(identity):
		return "未找到怪物识别名：" + identity
	get_node("/root/ScreenTransition").play(_enter_battle.bind(source, monsters, identity, formation))
	return "进入战斗：" + str(monsters.monsters[identity].name)

func _enter_battle(source: TroopState, monsters: MonsterCatalog, identity: String, formation: TroopFormation) -> void:
	last_outcome = ""
	if is_instance_valid(active):
		active.battle.finish()
		active.queue_free()
	else:
		origin = formation
		if is_instance_valid(origin):
			_origin_process_mode = origin.process_mode
			origin.process_mode = Node.PROCESS_MODE_DISABLED
			origin.hide()
		_layer = CanvasLayer.new()
		_layer.layer = 20
		add_child(_layer)
	var state := BattleState.new()
	state.configure(source, monsters, identity)
	var session: Node = get_node("/root/EventManager").current_session()
	if session.active and session.pending.get("event_executing", false):
		state.entry_missing_hp = session.missing_hp
		state.sync_formation()
	active = BattleScene.new()
	active.battle = state
	active.close_requested.connect(close)
	_layer.add_child(active)

func close() -> void:
	var result := ""
	var hp := 0.0
	var maximum := 0.0
	var is_run := _run_node_battle
	_run_node_battle = false
	if is_instance_valid(active):
		result = active.battle.outcome
		last_outcome = result
		hp = active.battle.player_hp
		maximum = active.battle.player_max_hp
		active.battle.finish()
		active.queue_free()
	active = null
	if is_instance_valid(_layer):
		_layer.queue_free()
	if is_instance_valid(origin):
		origin.process_mode = _origin_process_mode
		origin.show()
		origin._refresh()
	origin = null
	var session: Node = get_node("/root/EventManager").current_session()
	if not is_run and session.active and session.pending.get("event_executing", false) and maximum > 0:
		session.set_event_damage(maxf(0, maximum - hp))
	if is_run: run_battle_closed.emit(result, hp, maximum)
