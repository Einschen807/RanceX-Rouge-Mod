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
var _relic_chest: RelicChestScreen

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
		active.battle.sync_formation()
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
	_relic_chest = RelicChestScreen.new()
	_relic_chest.troop = source
	_relic_chest.record = record
	_relic_chest.completed.connect(_close_relic_chest)
	_treasure_layer.add_child(_relic_chest)
	return "打开遗物宝箱：" + pool

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
	if is_run: run_battle_closed.emit(result, hp, maximum)
