extends Node
signal node_shop_closed
var active: ShopScreen
var layer: CanvasLayer
var node_shop := false

## Themed shops opened by `shop 名称` (events); each keeps the normal shop rules.
const VARIANTS := {"米莉": "米莉的小店"}

func launch(variant := "") -> String:
	if not variant.is_empty() and not VARIANTS.has(variant): return "未找到商店：" + variant
	if not _can_open(): return "当前界面不能进入商店。"
	var session := get_node("/root/RunSession")
	if variant.is_empty() and session.active and session.pending.get("type") == "shop":
		open_node(session.pending.inventory)
	else:
		var troop: TroopState = get_node("/root/BattleManager").current_troop()
		var inventory := ShopInventory.generate(troop, get_node("/root/RunAutosave").rng)
		if not ShopInventory.valid(inventory, troop.catalog): return "商店数据加载失败。"
		_open(troop, inventory, false, variant)
	return "进入商店。" if variant.is_empty() else "进入%s。" % VARIANTS[variant]

func _can_open() -> bool:
	var manager := get_node("/root/BattleManager")
	return not is_instance_valid(active) and not is_instance_valid(manager.active) and not is_instance_valid(manager._relic_chest) and not is_instance_valid(manager._treasure) and not is_instance_valid(get_node("/root/Settings").panel) and not get_node("/root/ScreenTransition").busy

func open_node(inventory: Dictionary) -> void:
	if not _can_open(): return
	_open(get_node("/root/RunSession").troop, ShopInventory.from_saved(inventory), true)

func _open(troop: TroopState, inventory: Dictionary, from_node: bool, variant := "") -> void:
	node_shop = from_node
	layer = CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	active = MilliShopScreen.new() if variant == "米莉" else ShopScreen.new()
	active.troop = troop
	active.stock = inventory
	active.close_requested.connect(close)
	layer.add_child(active)
	get_node("/root/RelicHUD").bind_troop(troop)

func close() -> void:
	var finish_node := node_shop
	clear()
	get_node("/root/UIAudio").play("cancel")
	if finish_node: node_shop_closed.emit()

func clear() -> void:
	if is_instance_valid(active):
		active.remove_from_group("modal_overlay")
		layer.remove_child(active)
		active.queue_free()
	active = null
	if is_instance_valid(layer): layer.queue_free()
	layer = null
	node_shop = false
