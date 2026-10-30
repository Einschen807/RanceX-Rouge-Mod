extends Node
## Console events never replace or finish the run's original pending node.
var active: EventScreen
var context: ForcedEventSession
var _layer: CanvasLayer
var _previous_run_troop: TroopState
## 「赌场」 roulette table opened by `roulette 50|100|all`; the event waits until it closes
## and then shows last_roulette_message as the result.
var roulette: RouletteScreen
var last_roulette_message := ""
var _roulette_layer: CanvasLayer

func launch_roulette(mode: String, troop: TroopState) -> String:
	if mode not in ["50", "100", "all"]: return "用法：roulette 50|100|all"
	if is_instance_valid(roulette) or get_node("/root/ScreenTransition").busy: return "当前不能开始轮盘。"
	if troop == null: return "部队数据加载失败。"
	var stake := troop.gold if mode == "all" else int(mode)
	if stake <= 0 or troop.gold < stake: return "贝壳不足：需要%d，持有%d。" % [maxi(stake, 1), troop.gold]
	last_roulette_message = ""
	_roulette_layer = CanvasLayer.new()
	_roulette_layer.layer = 60
	add_child(_roulette_layer)
	roulette = RouletteScreen.new()
	roulette.troop = troop
	roulette.mode = mode
	roulette.finished.connect(_close_roulette)
	_roulette_layer.add_child(roulette)
	return "开始轮盘：押注%d贝壳。" % stake

func _close_roulette(message: String) -> void:
	last_roulette_message = message
	# A lost bet leaves 叶月 grinning on the event page behind the table, too.
	if roulette.lost:
		for node: Node in get_tree().get_nodes_in_group("modal_overlay"):
			var art := node.get_node_or_null("EventImage") as TextureRect if node is EventScreen else null
			if art != null and art.texture != null and art.texture.resource_path.ends_with("/赌场.png"): art.texture = load("res://assets/events/赌场_笑.png")
	roulette = null
	if is_instance_valid(_roulette_layer): _roulette_layer.queue_free()
	_roulette_layer = null

func launch(identity: String, definition_path := "res://data/events.txt") -> String:
	if identity.is_empty(): return "用法：event 事件名"
	var events := EventCatalog.new()
	if not events.load_catalog(definition_path): return "事件数据加载失败：\n" + "\n".join(events.errors)
	if not events.records.has(identity): return "未找到事件名：" + identity
	var battle := get_node("/root/BattleManager")
	if get_node("/root/ScreenTransition").busy or is_instance_valid(battle.active) or is_instance_valid(battle._treasure) or is_instance_valid(battle._relic_chest) or is_instance_valid(get_node("/root/ShopManager").active):
		return "请先结束当前战斗、商店或宝箱界面。"
	for overlay: Node in get_tree().get_nodes_in_group("modal_overlay"):
		if overlay != active and overlay != get_node("/root/DebugConsole").panel: return "请先关闭当前叠加界面。"
	var source: TroopState = battle.current_troop()
	if source == null: return "部队数据加载失败。"
	var next := ForcedEventSession.new()
	add_child(next)
	if not next.configure(source, events, identity):
		next.queue_free()
		return "怪物数据加载失败。"
	clear()
	context = next
	_previous_run_troop = battle.run_troop
	battle.register_run(source)
	_layer = CanvasLayer.new()
	_layer.layer = 15
	add_child(_layer)
	# The page opens, and later closes, under a black fade like a map event.
	var transition := get_node("/root/ScreenTransition")
	transition.play(_mount.bind(next))
	return "进入事件：" + identity

func _mount(session: ForcedEventSession) -> void:
	if session != context or not is_instance_valid(_layer): return
	active = EventScreen.new()
	active.session = context
	active.record = context.current_event()
	active.add_to_group("modal_overlay")
	active.completed.connect(func() -> void: get_node("/root/ScreenTransition").play(clear))
	_layer.add_child(active)

func current_session() -> Node:
	return context if is_instance_valid(context) and context.active else get_node("/root/RunSession")

func clear() -> void:
	var was_open := is_instance_valid(active)
	if is_instance_valid(context):
		context.active = false
		get_node("/root/BattleManager").register_run(_previous_run_troop)
		remove_child(context)
		context.queue_free()
	context = null
	if is_instance_valid(active): active.remove_from_group("modal_overlay")
	active = null
	if is_instance_valid(_layer):
		remove_child(_layer)
		_layer.queue_free()
	_layer = null
	_previous_run_troop = null
	if was_open:
		var map := get_tree().get_first_node_in_group("run_map_screen")
		if map != null and map.session.active and not is_instance_valid(map._modal): map._show_pending.call_deferred()
