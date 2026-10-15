extends Node
## Console events never replace or finish the run's original pending node.
var active: EventScreen
var context: ForcedEventSession
var _layer: CanvasLayer
var _previous_run_troop: TroopState

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
	active = EventScreen.new()
	active.session = context
	active.record = context.current_event()
	active.add_to_group("modal_overlay")
	active.completed.connect(clear)
	_layer.add_child(active)
	return "进入事件：" + identity

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
