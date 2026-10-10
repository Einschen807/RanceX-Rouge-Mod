extends Node
## One run's graph, inventory and persistent damage; node checkpoints own random state.
signal changed
signal troop_leveled_up(count: int)
signal title_requested
var catalog: CardCatalog
var monsters: MonsterCatalog
var pools: RunPoolCatalog
var troop: TroopState
var maps: Array = []
var act := 0
var seed_value := 0
var current := ""
var last_room_type := ""
var visited: Array = [[], [], []]
var normal_battles: Array = [0, 0, 0]
var beaten: Dictionary = {}
var seen_events: Dictionary = {}
var missing_hp := 0.0
var unknown_odds := {"monster": 0.10, "chest": 0.02, "shop": 0.03}
var pending: Dictionary = {}
var ended := false
var active := false
var error := ""

func _load_catalogs() -> bool:
	error = ""
	catalog = CardCatalog.new()
	if not catalog.load_catalog():
		error = "\n".join(catalog.errors)
		return false
	monsters = MonsterCatalog.new()
	if not monsters.load_catalog(catalog.skills):
		error = "\n".join(monsters.errors)
		return false
	pools = RunPoolCatalog.new()
	if not pools.load_catalog(catalog, monsters):
		error = "\n".join(pools.errors)
		return false
	return true

func _load_data() -> bool:
	if not _load_catalogs(): return false
	troop = TroopState.new()
	troop.configure(catalog, false, pools.initial_cards)
	troop.changed.connect(_troop_changed)
	troop.troop_leveled_up.connect(troop_leveled_up.emit)
	return true

func can_resume() -> bool:
	if catalog == null and not _load_catalogs(): return false
	var entry: Dictionary = get_node("/root/RunAutosave").peek_entry(catalog)
	return not entry.is_empty() and _valid_progress(entry.progress) and not entry.progress.ended and _valid_saved_pending(entry.node.initial, entry.progress)

func suspend() -> void:
	active = false
	get_node("/root/ShopManager").clear()
	get_node("/root/BattleManager").clear_run()
	get_node("/root/RelicHUD").bind_troop(null)

func return_to_title() -> void:
	if get_node("/root/ScreenTransition").busy: return
	title_requested.emit()

func abandon() -> bool:
	if get_node("/root/ScreenTransition").busy: return false
	if get_node("/root/RunAutosave").discard_run() != OK:
		error = get_node("/root/RunAutosave").last_error
		return false
	suspend()
	troop = null
	maps.clear()
	pending.clear()
	ended = false
	title_requested.emit()
	return true

func begin(seed_override := -1) -> bool:
	if not _load_data(): return false
	seed_value = seed_override if seed_override >= 0 else int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	maps.clear()
	for layer: int in range(3):
		var map := ActMapGenerator.generate(seed_value, layer)
		var invalid := ActMapGenerator.validate(map)
		if not invalid.is_empty():
			error = invalid
			return false
		maps.append(map)
	act = 0
	current = ""
	last_room_type = ""
	visited = [[], [], []]
	normal_battles = [0, 0, 0]
	beaten.clear()
	seen_events.clear()
	missing_hp = 0.0
	unknown_odds = {"monster": 0.10, "chest": 0.02, "shop": 0.03}
	pending.clear()
	ended = false
	active = true
	for name: String in pools.initial_cards: troop.deploy(name)
	get_node("/root/RunAutosave").begin_run("run_%d_%d" % [seed_value, Time.get_ticks_msec()], seed_value)
	get_node("/root/BattleManager").register_run(troop)
	return enter("start")

func resume() -> bool:
	if not _load_data(): return false
	var autosave := get_node("/root/RunAutosave")
	var entry: Dictionary = autosave.resume(troop)
	if entry.is_empty():
		error = autosave.last_error
		return false
	var progress: Dictionary = entry.progress
	if not _valid_progress(progress):
		error = "存档没有可恢复的三层地图，或地图数据已损坏。"
		autosave.finish_node()
		return false
	maps = progress.maps.duplicate(true)
	act = int(progress.act)
	seed_value = int(progress.seed)
	current = progress.current
	last_room_type = progress.get("last_room_type", "")
	visited = progress.visited.duplicate(true)
	normal_battles = progress.normal_battles.duplicate()
	beaten = progress.beaten.duplicate()
	seen_events = progress.seen_events.duplicate()
	missing_hp = float(progress.missing_hp)
	unknown_odds = progress.unknown_odds.duplicate()
	ended = progress.ended
	pending = entry.node.initial.duplicate(true)
	if pending.get("type") == "shop" and not pending.has("inventory"):
		pending["inventory"] = ShopInventory.generate(troop, autosave.rng)
	elif pending.get("type") == "shop" and pending.inventory is Dictionary:
		pending["inventory"] = ShopInventory.from_saved(pending.inventory)
	if not _valid_pending(pending):
		error = "入口节点引用的怪物、事件或地图节点已不存在。"
		autosave.finish_node()
		return false
	active = true
	get_node("/root/BattleManager").register_run(troop)
	changed.emit()
	return true

func _valid_progress(data: Dictionary) -> bool:
	if data.get("map_version", 0) != 1 or not data.get("maps") is Array or data.maps.size() != 3 or not RecordTable.integer(data.get("act")) or data.act < 0 or data.act > 2: return false
	if not data.get("seed") is String or not data.seed.is_valid_int() or not data.get("ended") is bool: return false
	if not data.get("current") is String or not data.get("visited") is Array or data.visited.size() != 3 or not data.get("normal_battles") is Array or data.normal_battles.size() != 3: return false
	if not data.get("beaten") is Dictionary or not data.get("seen_events") is Dictionary or not TroopCheckpoint._number(data.get("missing_hp")) or data.missing_hp < 0 or not data.get("unknown_odds") is Dictionary: return false
	for i: int in range(3):
		if not data.maps[i] is Dictionary or not ActMapGenerator.validate(data.maps[i]).is_empty() or not data.visited[i] is Array or not RecordTable.integer(data.normal_battles[i]) or data.normal_battles[i] < 0: return false
		for id: Variant in data.visited[i]:
			if not id is String or not data.maps[i].nodes.has(id): return false
	if not data.current.is_empty() and not data.maps[int(data.act)].nodes.has(data.current): return false
	for kind: String in ["monster", "chest", "shop"]:
		if not TroopCheckpoint._number(data.unknown_odds.get(kind)) or data.unknown_odds[kind] < 0: return false
	return true

func _valid_pending(data: Dictionary) -> bool:
	return _valid_saved_pending(data, snapshot())

func _valid_saved_pending(data: Dictionary, progress: Dictionary) -> bool:
	if progress.ended: return data.get("type") == "finished"
	if not data.get("id") is String or not progress.maps[int(progress.act)].nodes.has(data.id) or data.get("type") not in ActMapGenerator.TYPES: return false
	if data.type in ["monster", "elite", "boss"]: return monsters.monsters.has(data.get("monster", ""))
	if data.type == "unknown": return pools.event_data.has(data.get("event", ""))
	if data.type == "shop" and data.has("inventory"):
		return data.inventory is Dictionary and ShopInventory.valid(data.inventory, catalog)
	return true

func graph() -> Dictionary:
	return maps[act]

func hp() -> float:
	return maxf(0.0, troop.total("hp") - missing_hp)

func available_nodes() -> Array:
	if ended or not pending.is_empty(): return []
	return ["start"] if current.is_empty() else graph().nodes[current].children.duplicate()

func snapshot() -> Dictionary:
	return {"map_version": 1, "maps": maps.duplicate(true), "act": act, "seed": str(seed_value), "current": current, "last_room_type": last_room_type, "visited": visited.duplicate(true), "normal_battles": normal_battles.duplicate(), "beaten": beaten.duplicate(), "seen_events": seen_events.duplicate(), "missing_hp": missing_hp, "unknown_odds": unknown_odds.duplicate(), "ended": ended}

func enter(id: String) -> bool:
	if id not in available_nodes(): return false
	if troop.leaders.all(func(name: String) -> bool: return name.is_empty()):
		error = "请先在部队编制中安排至少一位领队。"
		return false
	if hp() <= 0.0:
		error = "部队当前没有可用HP，请调整编制或重新开始。"
		return false
	var autosave := get_node("/root/RunAutosave")
	var previous_rng_state: int = autosave.rng.state
	var previous_odds := unknown_odds.duplicate()
	var type: String = graph().nodes[id].type
	var original_type := type
	if type == "unknown": type = _roll_unknown(id)
	pending = {"id": id, "type": type, "original_type": original_type}
	var layer: String = RunPoolCatalog.LAYERS[act]
	if type in ["monster", "elite", "boss"]:
		var pool_kind := "BOSS池" if type == "boss" else ("精英池" if type == "elite" else ("弱怪池" if normal_battles[act] < 5 else "强怪池"))
		pending["pool"] = layer + pool_kind
		pending["monster"] = RunPoolCatalog.choose(pools.monsters[pending.pool], beaten, autosave.rng)
	elif type == "unknown":
		pending["event"] = RunPoolCatalog.choose(pools.events[layer + "事件池"], seen_events, autosave.rng)
	elif type == "chest":
		pending["medals"] = 2
	elif type == "shop":
		pending["inventory"] = ShopInventory.generate(troop, autosave.rng)
		if not ShopInventory.valid(pending.inventory, catalog):
			pending.clear()
			unknown_odds = previous_odds
			autosave.rng.state = previous_rng_state
			error = "商店商品生成失败。"
			return false
	var result: Error = autosave.enter_node("%d:%s" % [act + 1, id], original_type, pending, snapshot(), troop)
	if result != OK:
		pending.clear()
		unknown_odds = previous_odds
		autosave.rng.state = previous_rng_state
		error = autosave.last_error
		return false
	error = ""
	changed.emit()
	return true

func _roll_unknown(id: String) -> String:
	var blocked_shop := last_room_type == "shop"
	var children: Array = graph().nodes[id].children
	blocked_shop = blocked_shop or (not children.is_empty() and children.all(func(child: String) -> bool: return graph().nodes[child].type == "shop"))
	var roll: float = get_node("/root/RunAutosave").rng.randf()
	var accumulated := 0.0
	var chosen := "unknown"
	for type: String in ["monster", "chest", "shop"]:
		if type == "shop" and blocked_shop: continue
		accumulated += float(unknown_odds[type])
		if roll < accumulated:
			chosen = type
			break
	for type: String in ["monster", "chest", "shop"]:
		if type == "shop" and blocked_shop: continue
		var base: float = {"monster": 0.10, "chest": 0.02, "shop": 0.03}[type]
		unknown_odds[type] = base if chosen == type else float(unknown_odds[type]) + base
	return chosen

func complete_node() -> void:
	if pending.is_empty(): return
	current = pending.id
	last_room_type = pending.type
	if current not in visited[act]: visited[act].append(current)
	var is_boss: bool = pending.type == "boss"
	pending.clear()
	get_node("/root/RunAutosave").finish_node()
	if is_boss:
		if act == 2:
			ended = true
			pending = {"type": "finished"}
			get_node("/root/RunAutosave").enter_node("run:finished", "finished", pending, snapshot(), troop)
		else:
			act += 1
			current = ""
			unknown_odds = {"monster": 0.10, "chest": 0.02, "shop": 0.03}
			# Commit the next act entrance immediately, so Continue won't replay the old boss.
			enter("start")
	changed.emit()

func battle_won(player_hp: float, max_hp: float) -> void:
	if pending.get("battle_rewarded", false): return
	pending["battle_rewarded"] = true
	missing_hp = maxf(0.0, max_hp - player_hp)
	beaten[pending.monster] = true
	if pending.type == "monster": normal_battles[act] += 1
	troop.add_medals(3 if pending.type == "boss" else (2 if pending.type == "elite" else 1))
	changed.emit()

func heal(percent: int) -> void:
	missing_hp = maxf(0.0, missing_hp - troop.total("hp") * float(percent) / 100.0)
	changed.emit()

func train(name: String, stars := 1) -> void:
	troop.set_level(name, troop.level(name) + stars)

func grant_card(name: String) -> void:
	if not troop.has_card(name) and not catalog.find_name(name).is_empty():
		troop.available.append(catalog.find_name(name))
		troop.changed.emit()

func _troop_changed() -> void:
	changed.emit()
