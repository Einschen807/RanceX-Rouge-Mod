extends Node
## A normal run can register its owned TroopState, even without a formation open.
var run_troop: TroopState
var active: BattleScene
var origin: TroopFormation
var _origin_process_mode := Node.PROCESS_MODE_INHERIT
var _layer: CanvasLayer

func register_run(state: TroopState) -> void:
	run_troop = state

func launch(identity: String) -> String:
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
	if is_instance_valid(active):
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
