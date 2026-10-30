extends CanvasLayer
## One global HUD handles acquisition from every source, including console grants.
var troop: TroopState
var database := RelicCatalog.new()
var root: Control
var strip: GridContainer
var tip: RelicTooltip
var icons: Dictionary = {}
var _battle: BattleState
var _flying: Dictionary = {}
## The strip lives in a drawer that folds up behind the top edge, leaving a small tab.
## Map, battle and other screens start it open and pinned; the shop and formation screens
## fold it, opening it while the mouse is over it or after the pushpin is clicked.
## "battle_panel": a battle with its analysis or status window open, which the drawer would cover.
const FOLDED_CONTEXTS := ["shop", "formation", "battle_panel"]
## Compact grid in the top-left corner, sized for a typical run of 20-30 relics: up to 16 per
## row, wrapping into rows of equal length (30 relics: 2 rows of 15). Tooltips carry the detail.
const ICON := 44
const GAP := 4
const PER_ROW := 16
const PAD := 8.0
const PIN_SPACE := 44.0
const TAB_SIZE := Vector2(104, 24)
const CLOSE_DELAY := 0.3
var drawer: Panel
var pin: TextureButton
var pinned := true
var _grid_size := Vector2.ZERO
var _tab: Button
var _tab_label: Label
var _context := ""
var _open := true
var _drawer_tween: Tween
var _leave_time := 0.0
var _peek_until := 0.0

func _ready() -> void:
	layer = 85
	database.load_catalog()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	drawer = Panel.new()
	drawer.name = "RelicDrawer"
	drawer.position = Vector2(16, 0)
	drawer.size = Vector2(PAD * 2 + PIN_SPACE, PAD * 2 + ICON)
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	# Mostly see-through: the icons stay readable without hiding the screen behind.
	style.bg_color = Color(0.05, 0.045, 0.04, 0.3)
	style.border_color = Color(FormationArt.GOLD, 0.85)
	style.border_width_bottom = 1
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 4
	drawer.add_theme_stylebox_override("panel", style)
	root.add_child(drawer)
	strip = GridContainer.new()
	strip.position = Vector2(PAD, PAD)
	strip.add_theme_constant_override("h_separation", GAP)
	strip.add_theme_constant_override("v_separation", GAP)
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	drawer.add_child(strip)
	pin = TextureButton.new()
	pin.name = "RelicPin"
	pin.texture_normal = preload("res://assets/ui/pushpin.svg")
	pin.ignore_texture_size = true
	pin.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	pin.size = Vector2(32, 32)
	pin.pivot_offset = pin.size * 0.5
	pin.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pin.pressed.connect(func() -> void: set_pinned(not pinned))
	drawer.add_child(pin)
	get_node("/root/UIAudio").bind_button(pin)
	# Hangs below the drawer, so it stays visible at the top edge when folded.
	_tab = Button.new()
	_tab.name = "RelicTab"
	_tab.position = Vector2(14, drawer.size.y - 1)
	_tab.size = TAB_SIZE
	_tab.focus_mode = Control.FOCUS_NONE
	_tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var tab_style := style.duplicate() as StyleBoxFlat
	tab_style.bg_color = Color(0.05, 0.045, 0.04, 0.78)
	tab_style.border_width_left = 1
	tab_style.border_width_right = 1
	for state: String in ["normal", "hover", "pressed", "focus"]: _tab.add_theme_stylebox_override(state, tab_style)
	_tab.pressed.connect(func() -> void: set_pinned(not pinned))
	drawer.add_child(_tab)
	_tab_label = BattleArt.label(_tab, "", Vector2.ZERO, TAB_SIZE, 15, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_tab_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip = RelicTooltip.new()
	root.add_child(tip)
	tip.hide()
	_fit_width()
	_show_pin()

## The drawer hugs its relics: one row up to PER_ROW, then rows of equal length.
func _fit_width() -> void:
	var count := maxi(1, icons.size())
	var rows := ceili(float(count) / PER_ROW)
	var columns := ceili(float(count) / rows)
	strip.columns = columns
	_grid_size = Vector2(columns * (ICON + GAP) - GAP, rows * (ICON + GAP) - GAP)
	drawer.size = Vector2(PAD + _grid_size.x + PAD + PIN_SPACE, PAD + _grid_size.y + PAD)
	pin.position = Vector2(drawer.size.x - PIN_SPACE + 4.0, (drawer.size.y - pin.size.y) * 0.5)
	_tab.position.y = drawer.size.y - 1
	# A folded drawer stays fully tucked away when it grows.
	if not _open: drawer.position.y = -drawer.size.y

## Pinned keeps the drawer open until unpinned; screen changes reset it to their default.
func set_pinned(value: bool) -> void:
	pinned = value
	_show_pin()
	if pinned: _set_open(true)

func _show_pin() -> void:
	if pin == null: return
	pin.rotation = 0.0 if pinned else deg_to_rad(38)
	pin.modulate = Color.WHITE if pinned else Color(0.62, 0.62, 0.62, 0.9)
	pin.scale = Vector2.ONE if pinned else Vector2.ONE * 0.9

func _set_open(value: bool) -> void:
	if _open == value: return
	_open = value
	if _drawer_tween != null: _drawer_tween.kill()
	_drawer_tween = drawer.create_tween()
	_drawer_tween.tween_property(drawer, "position:y", 0.0 if value else -drawer.size.y, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not value: tip.hide()

func screen_context() -> String:
	if is_instance_valid(get_node("/root/ShopManager").active): return "shop"
	for node: Node in get_tree().get_nodes_in_group("troop_formations"):
		if node is Control and (node as Control).is_visible_in_tree(): return "formation"
	var battle: BattleScene = get_node("/root/BattleManager").active
	if not is_instance_valid(battle): return "map"
	return "battle_panel" if is_instance_valid(battle.analysis_panel) or is_instance_valid(battle.state_panel) else "battle"

## Folded drawers open while the mouse is over the drawer or its tab, closing shortly after.
func _update_drawer() -> void:
	var context := screen_context()
	if context != _context:
		_context = context
		set_pinned(context not in FOLDED_CONTEXTS)
	_tab_label.text = "遗物 %d %s" % [icons.size(), "▴" if _open else "▾"]
	var now := Time.get_ticks_msec() / 1000.0
	var mouse := root.get_global_mouse_position()
	var area := Rect2(drawer.global_position, drawer.size).merge(_tab.get_global_rect())
	if area.has_point(mouse): _leave_time = now + CLOSE_DELAY
	_set_open(pinned or now < _leave_time or now < _peek_until)

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
		icon.counter = int(troop.relic_counters.get(name, 0)) if troop != null and (RelicEffects.PERIODS.has(name) or name in RelicEffects.STACKING) else -1
		icon.imminent = RelicEffects.PERIODS.has(name) and icon.counter == int(RelicEffects.PERIODS[name]) - 1
		icon.spent = troop != null and RelicEffects.spent(troop, name)
		icon.queue_redraw()
	var modal := get_tree().get_first_node_in_group("modal_overlay")
	root.visible = in_game and not get_tree().get_nodes_in_group("modal_overlay").any(func(node: Node) -> bool: return node is RelicEncyclopedia)
	# Without relics there is nothing to hold: no drawer, no tab.
	drawer.visible = not icons.is_empty() or not _flying.is_empty()
	if root.visible and drawer.visible: _update_drawer()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE if modal != null and not modal is RelicChestScreen else Control.MOUSE_FILTER_PASS
	for icon: RelicIcon in icons.values(): icon.mouse_filter = strip.mouse_filter
	if modal != null and not modal is RelicChestScreen: tip.hide()

func _sync() -> void:
	BattleArt.clear(strip)
	icons.clear()
	tip.hide()
	# After the icons below are rebuilt.
	_fit_width.call_deferred()
	if troop == null: return
	for name: String in troop.relics:
		var record: Dictionary = database.by_name.get(name, {})
		if record.is_empty(): continue
		var icon := RelicIcon.new()
		icon.record = record
		icon.custom_minimum_size = Vector2(ICON, ICON)
		strip.add_child(icon)
		icons[name] = icon
		if _flying.has(name): icon.modulate.a = 0.0
		icon.mouse_entered.connect(func() -> void: tip.show_record(record, Vector2(icon.global_position.x, drawer.global_position.y + drawer.size.y + 8)))
		icon.mouse_exited.connect(tip.hide)
		icon.focus_entered.connect(func() -> void: tip.show_record(record, Vector2(icon.global_position.x, drawer.global_position.y + drawer.size.y + 8)))
		icon.focus_exited.connect(tip.hide)

func _trigger(name: String) -> void:
	if icons.has(name): icons[name].flash()

func _acquired(name: String, at: Vector2) -> void:
	_flying[name] = true
	if icons.has(name): icons[name].modulate.a = 0.0
	# A folded drawer opens long enough for the new relic to land in sight.
	_peek_until = Time.get_ticks_msec() / 1000.0 + 1.6
	drawer.visible = true
	if not _open:
		_set_open(true)
		await get_tree().create_timer(0.23).timeout
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
	tween.tween_property(flying, "size", Vector2(ICON, ICON), 0.45)
	await tween.finished
	flying.queue_free()
	_flying.erase(name)
	if icons.has(name):
		icons[name].modulate.a = 1.0
		icons[name].flash()
