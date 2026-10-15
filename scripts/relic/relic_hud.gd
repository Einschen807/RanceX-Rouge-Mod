extends CanvasLayer
## One global HUD handles acquisition from every source, including console grants.
var troop: TroopState
var database := RelicCatalog.new()
var root: Control
var strip: HBoxContainer
var tip: RelicTooltip
var icons: Dictionary = {}
var _battle: BattleState
var _flying: Dictionary = {}

func _ready() -> void:
	layer = 85
	database.load_catalog()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(32, 20)
	scroll.size = Vector2(1640, 80)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(scroll)
	strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 7)
	scroll.add_child(strip)
	tip = RelicTooltip.new()
	root.add_child(tip)
	tip.hide()

func bind_troop(source: TroopState) -> void:
	if troop == source: return
	if troop != null:
		if troop.changed.is_connected(_sync): troop.changed.disconnect(_sync)
		if troop.relic_acquired.is_connected(_acquired): troop.relic_acquired.disconnect(_acquired)
	troop = source
	if troop != null:
		troop.changed.connect(_sync)
		troop.relic_acquired.connect(_acquired)
	_sync()

func _process(_delta: float) -> void:
	var manager := get_node("/root/BattleManager")
	var in_game: bool = get_node("/root/RunSession").active or is_instance_valid(manager.active) or is_instance_valid(manager._relic_chest) or is_instance_valid(manager._treasure) or is_instance_valid(get_node("/root/ShopManager").active)
	var source: TroopState = manager.current_troop(false) if in_game else null
	if source != troop: bind_troop(source)
	var battle: BattleState = manager.active.battle if is_instance_valid(manager.active) else null
	if battle != _battle:
		if _battle != null and _battle.relic_triggered.is_connected(_trigger): _battle.relic_triggered.disconnect(_trigger)
		_battle = battle
		if _battle != null: _battle.relic_triggered.connect(_trigger)
	for name: String in icons:
		var icon: RelicIcon = icons[name]
		icon.counter = int(troop.relic_counters.get(name, 0)) if troop != null and RelicEffects.PERIODS.has(name) else -1
		icon.imminent = RelicEffects.PERIODS.has(name) and icon.counter == int(RelicEffects.PERIODS[name]) - 1
		icon.queue_redraw()
	var modal := get_tree().get_first_node_in_group("modal_overlay")
	root.visible = in_game and not get_tree().get_nodes_in_group("modal_overlay").any(func(node: Node) -> bool: return node is RelicEncyclopedia)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE if modal != null and not modal is RelicChestScreen else Control.MOUSE_FILTER_PASS
	for icon: RelicIcon in icons.values(): icon.mouse_filter = strip.mouse_filter
	if modal != null and not modal is RelicChestScreen: tip.hide()

func _sync() -> void:
	BattleArt.clear(strip)
	icons.clear()
	tip.hide()
	if troop == null: return
	for name: String in troop.relics:
		var record: Dictionary = database.by_name.get(name, {})
		if record.is_empty(): continue
		var icon := RelicIcon.new()
		icon.record = record
		icon.custom_minimum_size = Vector2(70, 70)
		strip.add_child(icon)
		icons[name] = icon
		if _flying.has(name): icon.modulate.a = 0.0
		icon.mouse_entered.connect(func() -> void: tip.show_record(record, icon.global_position + Vector2(0, 80)))
		icon.mouse_exited.connect(tip.hide)
		icon.focus_entered.connect(func() -> void: tip.show_record(record, icon.global_position + Vector2(0, 80)))
		icon.focus_exited.connect(tip.hide)

func _trigger(name: String) -> void:
	if icons.has(name): icons[name].flash()

func _acquired(name: String, at: Vector2) -> void:
	_flying[name] = true
	if icons.has(name): icons[name].modulate.a = 0.0
	var flying := RelicIcon.new()
	flying.record = database.by_name[name]
	flying.position = at - Vector2(52, 52)
	flying.size = Vector2(104, 104)
	flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flying)
	await get_tree().process_frame
	if not icons.has(name):
		flying.queue_free()
		_flying.erase(name)
		return
	var target: Vector2 = icons[name].global_position
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flying, "position", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flying, "size", Vector2(70, 70), 0.45)
	await tween.finished
	flying.queue_free()
	_flying.erase(name)
	if icons.has(name):
		icons[name].modulate.a = 1.0
		icons[name].flash()
