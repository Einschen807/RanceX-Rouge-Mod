extends Control
class_name RunMapScreen
signal close_requested
const INK := Color("523921")
const GOLD := Color("e8cb84")
var session: Node
var scroll: ScrollContainer
var sheet: Control
var positions: Dictionary = {}
var node_buttons: Dictionary = {}
var _hp: OriginalBitmapNumber
var _hp_fill: TextureRect
var _hp_mask: Control
var _medal_icons: Array[TextureRect] = []
var _gold: Label
var _leaders: HBoxContainer
var _modal: Control
var _modal_body: Control
var _formation: TroopFormation
var _card_choices: Array = []
var _modal_kind := ""
var _launching := false
var _pan_armed := false
var _panning := false
var _pan_origin := Vector2.ZERO
var _pan_scroll := 0
var _pressed_node := ""
var _rank_up_queue := 0
var _rank_up: TroopRankUp
var _routes: MapRoutes
var _traveling := false
var _travel_serial := 0
var _travel_target := ""
var _travel_tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("run_map_screen")
	session = get_node("/root/RunSession")
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SimSun", "宋体"])
	add_theme_font_override("font", font)
	_build()
	session.changed.connect(_refresh_hud)
	session.troop_leveled_up.connect(_queue_rank_up)
	get_node("/root/BattleManager").run_battle_closed.connect(_battle_closed)
	get_node("/root/ShopManager").node_shop_closed.connect(_finish_node)
	_rebuild_map()
	_show_pending.call_deferred()

func _build() -> void:
	var background := FormationArt.picture(self, "background", Vector2.ZERO, Vector2(1920, 1080))
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.03, 0.025, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	scroll = ScrollContainer.new()
	scroll.name = "MapScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 100
	scroll.offset_right = -100
	scroll.offset_top = 20
	scroll.offset_bottom = 0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	add_child(scroll)
	var footer := Control.new()
	footer.name = "RunHUD"
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -206
	footer.offset_bottom = 0
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	var right := Control.new()
	right.name = "TroopHUD"
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-900, 0)
	right.size = Vector2(900, 206)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(right)
	# Original Pact: HP bottom-right anchor (1909,981), mini cards (-413,-93).
	_picture(right, "hp_ground", Vector2(27, 30), Vector2(862, 77))
	_hp_mask = Control.new()
	_hp_mask.position = Vector2(33, 36)
	_hp_mask.size = Vector2(850, 65)
	_hp_mask.clip_contents = true
	_hp_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_hp_mask)
	_hp_fill = _picture(_hp_mask, "hp_fill", Vector2.ZERO, Vector2(850, 65))
	_hp = OriginalBitmapNumber.new()
	_hp.atlas = load("res://assets/map/hp_map_digits.png")
	_hp.position = Vector2(39, 60)
	_hp.size = Vector2(330, 49)
	_hp.kerning = -3
	_hp.abbreviate = false
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_hp)
	_leaders = HBoxContainer.new()
	_leaders.name = "Leaders"
	_leaders.position = Vector2(476, 14)
	_leaders.size = Vector2(382, 78)
	_leaders.add_theme_constant_override("separation", 3)
	right.add_child(_leaders)
	# Crop only the original medal strip; battle-spoils and meal-ticket regions are omitted.
	_picture(right, "medal_strip", Vector2(0, 119), Vector2(264, 64))
	for i: int in range(3):
		_medal_icons.append(_picture(right, "medal", Vector2(62 + i * 64, 115), Vector2(64, 64)))
	_gold = ShopArt.money(right, Vector2(294, 114))
	_gold.name = "Gold"
	var formation := OriginalUiButton.make(right, "formation", Vector2(701, 108), Vector2(194, 92), _open_formation, "click", "res://assets/map/native")
	formation.name = "FormationButton"
	var caption := FormationArt.label(formation.content, "部队编制", Vector2(13, 16), Vector2(170, 52), 23, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	caption.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	caption.add_theme_constant_override("outline_size", 1)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	formation.focus_neighbor_top = get_node("/root/ScreenSettings").gear.get_path()
	_refresh_hud()

func _picture(parent: Node, name: String, at: Vector2, dimensions: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture = load("res://assets/map/%s.png" % name)
	rect.position = at
	rect.size = dimensions
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func _rebuild_map() -> void:
	if is_instance_valid(sheet):
		scroll.remove_child(sheet)
		sheet.queue_free()
	var graph: Dictionary = session.graph()
	var height := float(graph.length + 1) * 164.0 + 440.0
	sheet = Control.new()
	sheet.name = "MapSheet"
	sheet.custom_minimum_size = Vector2(1680, height)
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sheet)
	var paper := MapPaper.new()
	paper.name = "Parchment"
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.add_child(paper)
	positions.clear()
	node_buttons.clear()
	var jitter := RandomNumberGenerator.new()
	jitter.seed = int(session.seed_value) + int(session.act) * 4099
	var ids: Array = graph.nodes.keys()
	ids.sort()
	for id: String in ids:
		var node: Dictionary = graph.nodes[id]
		var at := Vector2(265.0 + float(node.col) * 190.0, height - 190.0 - float(node.row) * 164.0)
		if id not in ["start", "boss"]: at += Vector2(jitter.randf_range(-18, 18), jitter.randf_range(-15, 15))
		positions[id] = at
	var routes := MapRoutes.new()
	_routes = routes
	routes.name = "Routes"
	routes.graph = graph
	routes.positions = positions.duplicate()
	routes.travelled = session.visited[session.act]
	routes.current = session.current
	sheet.add_child(routes)
	routes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var available: Array = session.available_nodes()
	if not session.pending.is_empty() and session.pending.has("id"): available = [session.pending.id]
	for id: String in ids:
		var button := MapNodeButton.new()
		button.name = id
		button.point = graph.nodes[id]
		button.size = Vector2(118, 118) if id in ["start", "boss"] else Vector2(100, 100)
		button.position = positions[id] - button.size * 0.5
		button.travelled = id in session.visited[session.act]
		button.current = id == session.current or id == session.pending.get("id", "")
		button.disabled = id not in available
		button.pressed.connect(_enter.bind(id))
		sheet.add_child(button)
		node_buttons[id] = button
	_refresh_hud()
	_center_current.call_deferred()

func _center_current() -> void:
	await get_tree().process_frame
	if not is_instance_valid(sheet): return
	var id: String = session.pending.get("id", session.current if not session.current.is_empty() else "start")
	var at: Vector2 = positions.get(id, positions.start)
	scroll.scroll_vertical = int(at.y - scroll.size.y * 0.72)
	var available: Array = session.available_nodes()
	if not available.is_empty() and not is_instance_valid(_modal): (node_buttons[available[0]] as Button).grab_focus()

func _refresh_hud() -> void:
	if not is_instance_valid(_hp): return
	_hp.text = str(ceili(session.hp()))
	var hp_ratio := clampf(session.hp() / maxf(1.0, session.troop.total("hp")), 0, 1)
	# Original gauge drains from the left while retaining its right-hand cyan tip.
	_hp_mask.position.x = 33 + 850 * (1.0 - hp_ratio)
	_hp_mask.size.x = 850 * hp_ratio
	_hp_fill.position.x = -850 * (1.0 - hp_ratio)
	for i: int in range(_medal_icons.size()): _medal_icons[i].visible = i < session.troop.medal_progress
	_gold.text = str(session.troop.gold)
	for child: Node in _leaders.get_children():
		_leaders.remove_child(child)
		child.queue_free()
	for index: int in range(session.troop.leaders.size()):
		var name: String = session.troop.leaders[index]
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(52, 78)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_leaders.add_child(slot)
		_picture(slot, "mini_ground", Vector2.ZERO, Vector2(52, 78))
		if session.troop.is_slot_unlocked(index) and not name.is_empty():
			var record: Dictionary = session.catalog.find_name(name)
			_picture(slot, "mini_back_%d" % record.faction, Vector2.ZERO, Vector2(52, 78))
			var portrait := TextureRect.new()
			portrait.texture = load("res://assets/cards/%s.png" % record.portrait)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.size = Vector2(52, 78)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(portrait)
			_picture(slot, "mini_frame_%d" % record.faction, Vector2.ZERO, Vector2(52, 78))

func _enter(id: String) -> void:
	if _blocked(): return
	if session.pending.get("id", "") == id:
		_show_pending()
		return
	if id not in session.available_nodes(): return
	if session.troop.leaders.all(func(name: String) -> bool: return name.is_empty()) or session.hp() <= 0:
		_message("无法进入", "请先在部队编制中安排有可用HP的领队。")
		return
	_traveling = true
	_travel_serial += 1
	var serial := _travel_serial
	_travel_target = id
	_routes.travel_source = session.current if not session.current.is_empty() else "start"
	_routes.travel_target = id
	_routes.set_travel_progress(0.0)
	# Keep the destination above the overlaid HUD while tracing its route.
	var at: Vector2 = positions[id]
	var lower := float(scroll.scroll_vertical) + scroll.size.y - 250.0
	var upper := float(scroll.scroll_vertical) + 95.0
	if at.y < upper or at.y > lower:
		scroll.scroll_vertical = maxi(0, int(at.y - scroll.size.y * 0.58))
	_travel_tween = create_tween()
	_travel_tween.tween_method(_routes.set_travel_progress, 0.0, 1.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.20).timeout
	if serial != _travel_serial: return
	_routes.set_travel_progress(1.0)
	get_node("/root/UIAudio").play("map_circle")
	_travel_tween = create_tween()
	_travel_tween.tween_method((node_buttons[id] as MapNodeButton).set_circle_progress, 0.0, 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.27).timeout
	if serial != _travel_serial: return
	_traveling = false
	if not session.enter(id):
		_cancel_travel()
		_message("无法进入", session.error)
		return
	_rebuild_map()
	_show_pending()

func _cancel_travel() -> void:
	_travel_serial += 1
	_traveling = false
	if is_instance_valid(_travel_tween): _travel_tween.kill()
	_routes.travel_source = ""
	_routes.travel_target = ""
	_routes.set_travel_progress(0.0)
	if node_buttons.has(_travel_target): (node_buttons[_travel_target] as MapNodeButton).set_circle_progress(0.0)
	_travel_target = ""

func _show_pending() -> void:
	if session.pending.is_empty(): return
	if session.ended:
		_end_screen(true)
		return
	match session.pending.type:
		"monster", "elite", "boss":
			if session.pending.get("cleared", false):
				if session.pending.type == "boss": _boss_reward()
				else: _reward_screen()
			else: _launch_battle.call_deferred()
		"ancient":
			_dialog("出征", "第%s层\n选择路线，向本层首领进军。" % ["一", "二", "三"][session.act], "node")
			_action("开始行军", Vector2(240, 265), _finish_node)
		"chest":
			_show_loot(1, false)
		"rest": _rest_screen()
		"shop": _shop_screen()
		"unknown": _event_screen()

func _launch_battle() -> void:
	if _launching: return
	_launching = true
	while get_node("/root/ScreenTransition").busy: await get_tree().process_frame
	if not is_inside_tree(): return
	var error: String = get_node("/root/BattleManager").launch_run_encounter(session.pending.monster, session.missing_hp)
	_launching = false
	if not error.is_empty(): _message("无法进入战斗", error)

func _battle_closed(outcome: String, hp: float, maximum: float) -> void:
	if not is_inside_tree() or session.pending.is_empty(): return
	if outcome != "胜利":
		_end_screen(false)
		return
	session.battle_won(hp, maximum)
	session.pending["cleared"] = true
	_rebuild_map()
	# Battle's WIN loot page has already handled its guaranteed card chest.
	_finish_node()

func _boss_reward() -> void:
	_show_loot(3)

func _reward_screen() -> void:
	_show_loot(2 if session.pending.type == "elite" else 1)

func _show_loot(type: int, won := true) -> void:
	_clear_modal()
	var loot := VictoryLootScreen.new()
	loot.troop = session.troop
	loot.rng = get_node("/root/RunAutosave").rng
	loot.pool_id = type
	loot.victory = won
	loot.completed.connect(func() -> void:
		if not won: session.troop.add_medals(2)
		_finish_node())
	_modal = loot
	_modal_kind = "reward"
	add_child(loot)

func _rest_screen() -> void:
	_dialog("休整部队", "在此恢复 30% 最大HP，或选择一张卡牌进行训练。", "node")
	_action("休息", Vector2(125, 265), func() -> void: session.heal(30); _finish_node())
	_action("训练", Vector2(365, 265), func() -> void: _training_screen(1))

func _training_screen(stars: int) -> void:
	_dialog("整备训练", "选择一张卡牌进行强化。", "training", Vector2(760, 590))
	var scroller := ScrollContainer.new()
	scroller.position = Vector2(65, 150)
	scroller.size = Vector2(630, 305)
	_modal_body.add_child(scroller)
	var choices := VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 12)
	scroller.add_child(choices)
	for card: Dictionary in session.troop.available:
		var button := Button.new()
		button.text = "%s    ★%d → ★%d" % [card.name, session.troop.level(card.name), session.troop.level(card.name) + stars]
		button.custom_minimum_size = Vector2(590, 56)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(func() -> void:
			session.train(card.name, stars)
			if session.pending.has("event"): session.seen_events[session.pending.event] = true
			_finish_node())
		choices.add_child(button)
	_action("返回", Vector2(280, 495), _show_pending)

func _event_screen() -> void:
	var event: Dictionary = session.pools.event_data[session.pending.event]
	_dialog(event.title, event.text, "node")
	_action("继续", Vector2(240, 265), func() -> void:
		if event.effect == "train":
			_training_screen(event.value)
			return
		if event.effect == "heal": session.heal(event.value)
		if event.effect == "medal": session.troop.add_medals(int(event.value))
		session.seen_events[event.id] = true
		_finish_node())

func _shop_screen() -> void:
	_clear_modal()
	while get_node("/root/ScreenTransition").busy:
		await get_tree().process_frame
		if not is_inside_tree(): return
	if session.pending.get("type") != "shop": return
	get_node("/root/ShopManager").open_node(session.pending.inventory)

func _finish_node() -> void:
	_clear_modal()
	session.complete_node()
	_rebuild_map()
	_show_pending.call_deferred()

func _dialog(title: String, text: String, kind: String, dimensions := Vector2(680, 380)) -> void:
	_clear_modal()
	_modal_kind = kind
	_modal = Control.new()
	_modal.name = "RunDialog"
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.65)
	_modal.add_child(shade)
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = -dimensions * 0.5
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", FormationArt.box(Color("30291c"), Color("b69450")))
	_modal.add_child(panel)
	_modal_body = panel
	var heading := FormationArt.label(panel, title, Vector2(35, 24), Vector2(dimensions.x - 70, 65), 35, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	heading.name = "Heading"
	var body := FormationArt.label(panel, text, Vector2(50, 110), Vector2(dimensions.x - 100, 90), 24, Color("eee2ca"), HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _action(text: String, at: Vector2, callback: Callable, dimensions := Vector2(200, 62)) -> Button:
	var button := FormationArt.button(_modal_body, text, at, dimensions, callback)
	get_node("/root/UIAudio").bind_button(button)
	button.grab_focus.call_deferred()
	return button

func _clear_modal() -> void:
	if is_instance_valid(_modal):
		remove_child(_modal)
		_modal.queue_free()
	_modal = null
	_modal_body = null
	_modal_kind = ""

func _message(title: String, text: String) -> void:
	_dialog(title, text, "message")
	_action("返回", Vector2(240, 265), _clear_modal)

func _open_menu() -> void:
	if _blocked(): return
	get_node("/root/Settings").open()

func _open_formation() -> void:
	if _blocked(): return
	await get_node("/root/ScreenTransition").play(_mount_formation)

func _queue_rank_up(count: int) -> void:
	_rank_up_queue += count
	_play_rank_ups.call_deferred()

func _play_rank_ups() -> void:
	if is_instance_valid(_rank_up) or _rank_up_queue <= 0: return
	# Delay until the map has returned from battle/blackout.
	if get_node("/root/ScreenTransition").busy or is_instance_valid(get_node("/root/BattleManager").active):
		await get_tree().process_frame
		_play_rank_ups.call_deferred()
		return
	_rank_up_queue -= 1
	_rank_up = TroopRankUp.new()
	_rank_up.completed.connect(func() -> void:
		_rank_up = null
		_play_rank_ups.call_deferred())
	add_child(_rank_up)

func _mount_formation() -> void:
	_formation = (load("res://scenes/troop_formation.tscn") as PackedScene).instantiate() as TroopFormation
	_formation.configure(session.troop)
	_formation.close_requested.connect(_close_formation)
	add_child(_formation)

func _close_formation() -> void:
	if get_node("/root/ScreenTransition").busy: return
	await get_node("/root/ScreenTransition").play(func() -> void:
		remove_child(_formation)
		_formation.queue_free()
		_formation = null
		_refresh_hud())

func _end_screen(won: bool) -> void:
	_dialog("行军完成" if won else "部队败北", "三层首领均已击破。" if won else "可以从当前节点入口重新出发。", "end", Vector2(680, 460))
	if not won:
		_action("重试本节点", Vector2(240, 220), func() -> void:
			if not session.resume():
				_message("无法继续", session.error)
				return
			_clear_modal()
			_rebuild_map()
			_show_pending())
	_action("返回标题", Vector2(240, 325), func() -> void: close_requested.emit())

func _blocked() -> bool:
	return _traveling or is_instance_valid(_modal) or is_instance_valid(_formation) or _launching or get_node("/root/ScreenTransition").busy or is_instance_valid(get_node("/root/BattleManager").active) or get_tree().get_first_node_in_group("modal_overlay") != null

func _input(event: InputEvent) -> void:
	if _traveling:
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel"): _cancel_travel()
		return
	if _map_pointer_input(event): return
	if not event.is_action_pressed("ui_cancel") or is_instance_valid(_formation) or is_instance_valid(get_node("/root/BattleManager").active) or get_tree().get_first_node_in_group("modal_overlay") != null: return
	get_viewport().set_input_as_handled()
	if get_node("/root/ScreenTransition").busy or _launching: return
	if _modal_kind in ["menu", "message"]:
		_clear_modal()
	elif _modal_kind == "reward":
		_clear_modal()
	elif _modal_kind == "training":
		_show_pending()
	elif _modal_kind == "node":
		_clear_modal()
	elif _modal_kind == "end":
		close_requested.emit()
	else:
		_open_menu()

func _map_pointer_input(event: InputEvent) -> bool:
	if _blocked():
		_pan_armed = false
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not scroll.get_global_rect().has_point(event.position): return false
			for path: String in ["RunHUD/TroopHUD/FormationButton"]:
				if (get_node(path) as Control).get_global_rect().has_point(event.position): return false
			if scroll.get_v_scroll_bar().get_global_rect().has_point(event.position): return false
			_pan_armed = true
			_panning = false
			_pan_origin = event.position
			_pan_scroll = scroll.scroll_vertical
			_pressed_node = ""
			for id: String in node_buttons:
				var button: Button = node_buttons[id]
				if not button.disabled and button.get_global_rect().has_point(event.position):
					_pressed_node = id
					break
		elif _pan_armed:
			_pan_armed = false
			if not _panning and not _pressed_node.is_empty():
				var button: Button = node_buttons[_pressed_node]
				if button.get_global_rect().has_point(event.position): button.pressed.emit()
		else: return false
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventMouseMotion and _pan_armed:
		if event.position.distance_to(_pan_origin) >= 8: _panning = true
		if _panning:
			var bar := scroll.get_v_scroll_bar()
			scroll.scroll_vertical = clampi(_pan_scroll - roundi(event.position.y - _pan_origin.y), 0, maxi(0, int(bar.max_value - bar.page)))
		get_viewport().set_input_as_handled()
		return true
	return false
