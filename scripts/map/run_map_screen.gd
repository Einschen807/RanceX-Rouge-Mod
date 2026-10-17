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
var _hud: RunTroopHUD
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
var _theme_banner: MapThemeBanner
var _starting_floor := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("run_map_screen")
	session = get_node("/root/RunSession")
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SimSun", "宋体"])
	add_theme_font_override("font", font)
	_build()
	session.troop_leveled_up.connect(_queue_rank_up)
	session.travel_mode_changed.connect(_refresh_node_availability)
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
	_hud = RunTroopHUD.new()
	_hud.session = session
	_hud.formation_enabled = true
	_hud.formation_requested.connect(_open_formation)
	add_child(_hud)

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
	if not available.is_empty() and not is_instance_valid(_modal):
		var focus_id: String = id if id in available else available[0]
		(node_buttons[focus_id] as Button).grab_focus()

func _refresh_hud() -> void:
	if is_instance_valid(_hud): _hud.refresh()

func _refresh_node_availability() -> void:
	# Update existing buttons in place so a console toggle never recenters the map.
	var available: Array = session.available_nodes()
	if not session.pending.is_empty() and session.pending.has("id"): available = [session.pending.id]
	for id: String in node_buttons:
		var button: MapNodeButton = node_buttons[id]
		button.disabled = id not in available
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not button.disabled else Control.CURSOR_ARROW
		button.queue_redraw()

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
	if _starting_floor or is_instance_valid(_theme_banner): return
	if is_instance_valid(get_node("/root/EventManager").active): return
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
			_start_floor()
		"chest":
			_show_loot(1, false)
		"rest": _rest_screen()
		"shop": _shop_screen()
		"unknown": _event_screen()

func _start_floor() -> void:
	_starting_floor = true
	# Begin the introduction after the title/formation blackout has cleared.
	while get_node("/root/ScreenTransition").busy:
		await get_tree().process_frame
		if not is_inside_tree(): return
	var show_intro: bool = not session.graph().get("intro_seen", false)
	if show_intro and session.mark_map_intro_seen() != OK:
		_starting_floor = false
		_message("无法保存地图入口", session.error)
		return
	session.complete_node()
	_rebuild_map()
	_starting_floor = false
	if show_intro:
		_theme_banner = MapThemeBanner.new()
		_theme_banner.floor_number = session.act + 1
		_theme_banner.map_theme = session.map_theme()
		_theme_banner.finished.connect(func() -> void: _theme_banner = null)
		add_child(_theme_banner)

func _launch_battle() -> void:
	if is_instance_valid(get_node("/root/EventManager").active): return
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
	var count: int = maxi(1, int(session.pending.get("upgrade_count", 1)))
	_dialog("休整部队", "恢复最大生命值30%%的血量并重置所有卡牌技能状态，或强化%s卡牌。" % ("一张" if count == 1 else "%d张" % count), "node")
	_action("恢复30%生命", Vector2(95, 265), func() -> void: session.recover_at_rest(); _finish_node(), Vector2(240, 62))
	_action("强化卡牌", Vector2(365, 265), _training_screen.bind(count))

func _training_screen(count: int) -> void:
	_clear_modal()
	var screen := CardUpgradeScreen.new()
	screen.troop = session.troop
	screen.remaining = count
	screen.rest_mode = true
	screen.completed.connect(_finish_node)
	screen.cancelled.connect(func() -> void:
		_clear_modal()
		_rest_screen())
	_modal = screen
	_modal_kind = "training"
	add_child(screen)

func _event_screen() -> void:
	_clear_modal()
	_modal_kind = "event"
	var page := EventScreen.new()
	page.session = session
	page.record = session.current_event()
	page.completed.connect(_finish_node)
	_modal = page
	add_child(page)

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
	panel.add_theme_stylebox_override("panel", BattleArt.panel_style())
	_modal.add_child(panel)
	_modal_body = panel
	var heading := FormationArt.label(panel, title, Vector2(35, 12), Vector2(dimensions.x - 70, 44), 32, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	heading.name = "Heading"
	var body := FormationArt.label(panel, text, Vector2(50, 110), Vector2(dimensions.x - 100, 90), 24, Color("eee2ca"), HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _action(text: String, at: Vector2, callback: Callable, dimensions := Vector2(200, 62)) -> Button:
	var button := BattleArt.text_button(_modal_body, text, at, dimensions, callback)
	button.grab_focus()
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
	_dialog("行军完成" if won else "部队败北", "四层首领均已击破。" if won else "可以从当前节点入口重新出发。", "end", Vector2(680, 460))
	if not won:
		_action("重试本节点", Vector2(240, 220), func() -> void:
			if not session.resume():
				_message("无法继续", session.error)
				return
			_clear_modal()
			_rebuild_map()
			_show_pending())
	_action("返回标题", Vector2(240, 325), func() -> void: close_requested.emit())

func _blocked(allow_banner_pan := false) -> bool:
	return _starting_floor or (is_instance_valid(_theme_banner) and not allow_banner_pan) or _traveling or is_instance_valid(_modal) or is_instance_valid(_formation) or _launching or get_node("/root/ScreenTransition").busy or is_instance_valid(get_node("/root/BattleManager").active) or get_tree().get_first_node_in_group("modal_overlay") != null

func _input(event: InputEvent) -> void:
	if is_instance_valid(_theme_banner):
		if _map_pointer_input(event): return
		# The banner stays fixed while the map can pan or scroll underneath it.
		if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: return
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel"): _theme_banner.dismiss()
		return
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
	elif _modal_kind == "event":
		return # Events advance only through their choice/result buttons.
	elif _modal_kind == "node":
		_clear_modal()
	elif _modal_kind == "end":
		close_requested.emit()
	else:
		_open_menu()

func _map_pointer_input(event: InputEvent) -> bool:
	if _blocked(true):
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
				if not is_instance_valid(_theme_banner) and not button.disabled and button.get_global_rect().has_point(event.position):
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
