extends Control
class_name TroopFormation
## Encyclopedia and gameplay both instantiate this scene, passing different TroopState inventory.
signal close_requested
var catalog := CardCatalog.new()
var troop := TroopState.new()
var selected_faction := 1
var detail_mode := 0
var sort_mode := 0
var bonuses_visible := false
var preview_upgrades := false
var _flip_locked := false
var _configured := false
var _transitioning := false
var _requested_faction := 1
var _requested_bonus := false
var _requested_upgrades := false
var _flights: Dictionary = {}
var _drag_source: CardWidget
var _drag_art: Control
var _drag_start := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _drag_name := ""
var _leader_area: Control
var _tabs: Array[Button] = []
var _tab_hp: Array[OriginalBitmapNumber] = []
var _tab_at: Array[OriginalBitmapNumber] = []
var _scroll: FormationDropArea
var _grid: GridContainer
var _ground: OriginalFlatPlayer
var _bonus_area: Control
var _summary: Dictionary = {}
var _leader_counts: Control
var _scrollbar: OriginalFormationScrollbar
var _sort_buttons: Array[OriginalUiButton] = []
var _sort_caption: TextureRect
var _formation_button: OriginalUiButton
var _details: OriginalUiButton
var _upgrade_checkbox: OriginalUiButton
var _bonus_button: OriginalUiButton
var _bonus_buttons: Array[Button] = []
var _bonus_rank: OriginalBitmapNumber
var _bonus_points: OriginalBitmapNumber

func configure(state: TroopState) -> void:
	troop = state
	catalog = state.catalog
	_configured = true

func _ready() -> void:
	add_to_group("troop_formations")
	if not _configured:
		if not catalog.load_catalog():
			FormationArt.label(self, "卡牌数据加载失败\n" + "\n".join(catalog.errors), Vector2(40, 40), Vector2(1750, 900), 26)
			FormationArt.button(self, "返回", Vector2(1730, 980), Vector2(140, 65), func() -> void: close_requested.emit())
			return
		troop.configure(catalog, true)
	_build()
	troop.changed.connect(_refresh)
	_refresh()
	_tabs[0].grab_focus()

func _build() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SimSun", "宋体"])
	add_theme_font_override("font", font)
	clip_contents = true
	FormationArt.picture(self, "background", Vector2.ZERO, Vector2(1920, 1080))
	FormationArt.picture(self, "leader_ground", Vector2(0, -18), Vector2(1574, 400))
	_ground = OriginalFlatPlayer.new()
	_ground.position = Vector2(0, 323)
	add_child(_ground)
	_leader_area = Control.new()
	_leader_area.position = Vector2(12, 8)
	_leader_area.size = Vector2(1530, 312)
	add_child(_leader_area)
	_leader_counts = Control.new()
	_leader_counts.position = Vector2(12, 320)
	_leader_counts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_leader_counts)
	for i: int in range(10):
		var button := OriginalUiButton.make(self, "tab", Vector2(30 + i * 150, 339), Vector2(146, 64), _select_faction.bind(i + 1))
		FormationArt.picture(button.content, "flag_%d" % (i + 1), Vector2(14, 6), Vector2(118, 21))
		_tab_hp.append(OriginalBitmapNumber.make(button.content, "digits_hp", Vector2(35, 26), Vector2(97, 15), "", -1))
		_tab_at.append(OriginalBitmapNumber.make(button.content, "digits_at", Vector2(35, 42), Vector2(97, 15), "", -1))
		_tabs.append(button)
	_scroll = FormationDropArea.new()
	_scroll.troop = troop
	_scroll.position = Vector2(36, 422)
	_scroll.size = Vector2(1310, 658)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.leader_removed.connect(troop.remove)
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)
	_scrollbar = OriginalFormationScrollbar.new()
	_scrollbar.scroll = _scroll
	_scrollbar.position = Vector2(1384, 411)
	add_child(_scrollbar)
	_sort_caption = FormationArt.picture(self, "sort_caption", Vector2(1433, 412), Vector2(94, 29))
	for i: int in range(4):
		var button := OriginalUiButton.make(self, "round", Vector2(1442, 444 + i * 106), Vector2(78, 96), _sort.bind(i))
		FormationArt.label(button.content, ["获取顺序", "名称顺序", "AT顺序", "★顺序"][i], Vector2(0, 29), Vector2(78, 38), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_sort_buttons.append(button)
	_build_upgrade_checkbox()
	_details = OriginalUiButton.make(self, "square", Vector2(1435, 979), Vector2(92, 92), _cycle_details)
	FormationArt.picture(_details.content, "details_icon", Vector2(11, 11), Vector2(64, 64))
	_bonus_area = Control.new()
	_bonus_area.position = Vector2(0, 384)
	_bonus_area.size = Vector2(1542, 696)
	add_child(_bonus_area)
	_build_bonuses()
	_bonus_area.hide()
	FormationArt.picture(self, "troop_title", Vector2(1540, 0), Vector2(380, 162))
	_summary.count = OriginalBitmapNumber.make(self, "digits_count", Vector2(1588, 96), Vector2(284, 62), "digits_count_suffix", -3)
	_summary.count.alignment = HORIZONTAL_ALIGNMENT_CENTER
	FormationArt.picture(self, "summary_hp", Vector2(1568, 177), Vector2(340, 198))
	FormationArt.picture(self, "summary_at", Vector2(1568, 400), Vector2(340, 243))
	_summary.hp = _summary_number(177 + 30, false)
	_summary.at = _summary_number(400 + 30, false)
	for i: int in range(3):
		_summary[["physical_resist", "magic_resist", "hp_rate"][i]] = _summary_number(177 + 75 + i * 45, true)
	for i: int in range(4):
		_summary[["physical", "magic", "critical", "combo"][i]] = _summary_number(400 + 75 + i * 45, true)
	FormationArt.picture(self, "mode_frame_compact", Vector2(1542, 777), Vector2(86, 200))
	_bonus_button = OriginalUiButton.make(self, "mode", Vector2(1542, 782), Vector2(82, 96), _show_bonuses.bind(true))
	FormationArt.picture(_bonus_button.content, "bonus_icon", Vector2.ZERO, Vector2(82, 96))
	_formation_button = OriginalUiButton.make(self, "mode", Vector2(1542, 878), Vector2(82, 96), _show_bonuses.bind(false))
	FormationArt.picture(_formation_button.content, "formation_icon", Vector2.ZERO, Vector2(82, 96))
	var close := OriginalUiButton.make(self, "square", Vector2(1825, 982), Vector2(92, 92), func() -> void: close_requested.emit(), "cancel")
	FormationArt.picture(close.content, "close_icon", Vector2(11, 11), Vector2(64, 64))

func _build_upgrade_checkbox() -> void:
	_upgrade_checkbox = OriginalUiButton.make(self, "square", Vector2(1435, 873), Vector2(92, 92), func() -> void: pass)
	_upgrade_checkbox.name = "ViewUpgrades"
	_upgrade_checkbox.toggle_mode = true
	var mark := TextureRect.new()
	mark.texture = preload("res://assets/formation/upgrade_unchecked.svg")
	mark.name = "CheckMark"
	# The native frame is centered at x=43, inside its 92px input area.
	mark.position = Vector2(27, 18)
	mark.size = Vector2(32, 32)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_checkbox.content.add_child(mark)
	var caption := FormationArt.label(_upgrade_checkbox.content, "查看升级", Vector2(7, 50), Vector2(72, 24), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	caption.name = "UpgradeLabel"
	caption.clip_text = true
	_upgrade_checkbox.toggled.connect(_set_upgrade_preview)

func _summary_number(y: int, percent: bool) -> OriginalBitmapNumber:
	return OriginalBitmapNumber.make(self, "digits_summary", Vector2(1703, y), Vector2(200, 28), "digits_percent" if percent else "")

func _build_bonuses() -> void:
	FormationArt.picture(_bonus_area, "bonus_frame", Vector2.ZERO, Vector2(1542, 701))
	_bonus_rank = OriginalBitmapNumber.make(_bonus_area, "digits_rank", Vector2(1228, 36), Vector2(40, 30))
	_bonus_points = OriginalBitmapNumber.make(_bonus_area, "digits_point", Vector2(1383, 5), Vector2(72, 64))
	for display_index: int in range(TroopState.BONUS_IDS.size()):
		var i: int = TroopState.BONUS_IDS[display_index]
		var button := Button.new()
		button.name = "Bonus%d" % i
		button.set_meta("bonus_id", i)
		button.position = Vector2(26 + (display_index % 4) * 375, 83 + (display_index / 4) * 123)
		button.size = Vector2(365, 123)
		for pair: Array in [["normal", "bonus_normal"], ["hover", "bonus_hover"], ["pressed", "bonus_pressed"], ["disabled", "bonus_disabled"]]:
			var style := StyleBoxTexture.new()
			style.texture = load("res://assets/formation/%s.png" % pair[1])
			button.add_theme_stylebox_override(pair[0], style)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.disabled = not troop.can_toggle_bonus(i)
		button.pressed.connect(func() -> void: troop.toggle_bonus(i))
		_bonus_area.add_child(button)
		get_node("/root/UIAudio").bind_button(button)
		FormationArt.picture(button, "bonus_symbol_%d" % i, Vector2(49, 23), Vector2(74, 74))
		var parts: PackedStringArray = String(TroopState.BONUS_NAMES[i]).split(" ", true, 1)
		FormationArt.label(button, parts[0], Vector2(147, 32), Vector2(208, 30), 22, Color(0.43, 0.22, 0.18))
		if parts.size() > 1:
			FormationArt.label(button, parts[1], Vector2(147, 64), Vector2(208, 30), 22, Color(0.43, 0.22, 0.18))
		var chosen := FormationArt.picture(button, "bonus_selected", Vector2.ZERO, Vector2(365, 123))
		chosen.name = "Selected"
		chosen.hide()
		_bonus_buttons.append(button)

func _refresh() -> void:
	if _grid == null:
		return
	for slot: int in _flights.keys():
		if troop.leaders[slot] != _flights[slot].card:
			_cancel_flight(slot)
	_clear(_leader_area)
	for i: int in range(7):
		var at := Vector2(i * 220, 0)
		if not troop.is_slot_unlocked(i) or troop.leaders[i].is_empty():
			FormationArt.picture(_leader_area, "locked" if not troop.is_slot_unlocked(i) else "empty", at, Vector2(208, 312))
		else:
			var widget := _card(catalog.find_name(troop.leaders[i]), true)
			widget.position = at
			_leader_area.add_child(widget)
			widget.visible = not _flights.has(i)
	_refresh_faction_cards()
	for i: int in range(10):
		_tab_hp[i].text = CardWidget._number(troop.faction_stat(i + 1, "hp", preview_upgrades))
		_tab_at[i].text = CardWidget._number(troop.faction_stat(i + 1, "at", preview_upgrades))
		(_tabs[i] as OriginalUiButton).neutral = troop.leader_for_faction(i + 1).is_empty()
		(_tabs[i] as OriginalUiButton).selected = i + 1 == selected_faction
	_summary.count.text = "%d 张" % troop.available.size()
	_summary.hp.text = CardWidget._number(troop.total("hp", preview_upgrades))
	_summary.at.text = CardWidget._number(troop.total("at", preview_upgrades))
	for kind: String in ["physical_resist", "magic_resist", "critical", "combo"]:
		_summary[kind].text = "%d%%" % int(troop.rate(kind))
	_summary.hp_rate.text = "%d%%" % int(troop.rate("hp"))
	_summary.physical.text = "%d%%" % int(troop.rate("physical"))
	_summary.magic.text = "%d%%" % int(troop.rate("magic"))
	_bonus_rank.text = str(troop.troop_level)
	_bonus_points.text = str(troop.bonus_points)
	for button: Button in _bonus_buttons:
		var id: int = button.get_meta("bonus_id")
		button.get_node("Selected").visible = troop.bonuses.get(id, false)
		button.disabled = not troop.can_toggle_bonus(id)
	_clear(_leader_counts)
	for i: int in range(7):
		if troop.leaders[i].is_empty():
			continue
		var faction: int = catalog.find_name(troop.leaders[i]).faction
		FormationArt.picture(_leader_counts, "leader_count_ground", Vector2(i * 220, 0), Vector2(208, 66))
		FormationArt.picture(_leader_counts, "flag_%d" % faction, Vector2(i * 220 + 46, 4.5), Vector2(118, 21))
		var count := troop.available.filter(func(c: Dictionary) -> bool: return c.faction == faction).size()
		var number := OriginalBitmapNumber.make(_leader_counts, "digits_leader_count", Vector2(i * 220, 34), Vector2(208, 28), "digits_leader_suffix")
		number.alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.text = "%d张" % count
	for i: int in range(_sort_buttons.size()):
		_sort_buttons[i].selected = i == sort_mode
	_apply_mode_view(bonuses_visible)

func _refresh_faction_cards() -> void:
	_clear(_grid)
	var cards: Array[Dictionary] = []
	for c: Dictionary in troop.available:
		if c.faction == selected_faction:
			cards.append(c)
	match sort_mode:
		1: cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _display_name(a).naturalnocasecmp_to(_display_name(b)) < 0)
		2: cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return troop.actual(a, "at", preview_upgrades) > troop.actual(b, "at", preview_upgrades))
		3: cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return troop.level(a.name) > troop.level(b.name))
	for card: Dictionary in cards:
		_grid.add_child(_card(card, false))
	if cards.is_empty():
		FormationArt.label(_grid, "此阵营暂无卡牌", Vector2.ZERO, Vector2(650, 100), 28, FormationArt.GOLD)
	var path := "res://assets/formation/native/ground_%d/animation.json" % selected_faction
	if _ground.animation_path != path:
		_ground.load_animation(path)
	for i: int in range(_tabs.size()):
		(_tabs[i] as OriginalUiButton).selected = i + 1 == selected_faction

func _display_name(record: Dictionary) -> String:
	return catalog.upgrade_preview(record).name if preview_upgrades else record.name

func _card(record: Dictionary, is_leader: bool) -> CardWidget:
	var widget := CardWidget.new()
	widget.setup(record, troop, is_leader, detail_mode, preview_upgrades)
	widget.card_clicked.connect(_on_card_clicked)
	widget.leader_removed.connect(troop.remove)
	widget.card_dropped.connect(_deploy)
	return widget

func _on_card_clicked(display_name: String, is_leader: bool) -> void:
	if is_leader:
		get_node("/root/UIAudio").play()
		_select_faction(catalog.find_name(display_name).faction)
	else:
		_deploy(display_name)

func _deploy(display_name: String) -> void:
	if _transitioning or _flip_locked:
		return
	if display_name in troop.leaders:
		return
	var slot := troop.deployment_slot(display_name)
	if slot < 0:
		return
	var source: CardWidget
	for child: Node in _grid.get_children():
		if child is CardWidget and child.card.name == display_name:
			source = child
			break
	_cancel_flight(slot)
	if source == null or not _scroll.visible:
		troop.deploy(display_name)
		return
	# Snapshot the card before the model's changed signal rebuilds the grid.
	var flying := source.visual.duplicate() as Control
	flying.position = source.global_position - global_position
	flying.scale = Vector2.ONE
	flying.modulate = Color.WHITE
	flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flying)
	_flights[slot] = {"node": flying, "card": display_name, "tween": null}
	if not troop.deploy(display_name):
		_cancel_flight(slot)
		return
	get_node("/root/UIAudio").play()
	_animate_flight(slot)

func _animate_flight(slot: int) -> void:
	var flying: Control = _flights[slot].node
	var tween := create_tween()
	_flights[slot].tween = tween
	var destination := _leader_area.position + Vector2(slot * 220, 0)
	tween.tween_property(flying, "position", destination, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_flight.bind(slot, flying))

func _card_at(point: Vector2) -> CardWidget:
	for area: Control in [_leader_area, _grid]:
		if not area.is_visible_in_tree():
			continue
		if area == _grid and not _scroll.get_global_rect().has_point(point):
			continue
		for child: Node in area.get_children():
			if child is CardWidget and child.is_visible_in_tree() and child.get_global_rect().has_point(point):
				return child
	return null

func _start_drag(point: Vector2) -> void:
	if not is_instance_valid(_drag_source) or _drag_source.selection_blocked():
		_drag_source = null
		return
	_drag_source.dragging = true
	_drag_art = _drag_source.visual
	_drag_name = _drag_source.card.name
	_drag_offset = _drag_start - _drag_source.global_position
	# Move the actual visual tree, including running original animations.
	_drag_art.reparent(self, true)
	if _drag_source.leader:
		var placeholder := FormationArt.picture(_drag_source, "empty", Vector2.ZERO, _drag_source.size)
		placeholder.name = "DragSlotPlaceholder"
	_drag_art.scale = Vector2.ONE
	_drag_source.refresh_feedback()
	_drag_art.position = point - global_position - _drag_offset

func _release_drag(point: Vector2) -> void:
	var art := _drag_art
	var display_name := _drag_name
	if is_instance_valid(_drag_source):
		_drag_source.dragging = false
		_drag_source.refresh_feedback()
	art.modulate.a = 1.0
	_drag_art = null
	_drag_source = null
	_drag_name = ""
	var local := point - global_position
	var source_slot := troop.leaders.find(display_name)
	# The full faction area (tabs, cards, and its empty space) unloads leaders.
	if not bonuses_visible and Rect2(0, 339, 1542, 741).has_point(local):
		art.queue_free()
		if source_slot >= 0:
			get_node("/root/UIAudio").play("cancel")
			troop.remove(display_name)
		else:
			_refresh()
		return
	var target := 0
	var nearest := INF
	var dragged_center := art.position + art.size * 0.5
	for slot: int in range(7):
		var center := _leader_area.position + Vector2(slot * 220 + 104, 156)
		var distance := dragged_center.distance_squared_to(center)
		if distance < nearest:
			nearest = distance
			target = slot
	if source_slot < 0:
		target = troop.deployment_slot(display_name, target)
		if target < 0:
			art.queue_free()
			_refresh()
			return
	if not troop.is_slot_unlocked(target):
		art.queue_free()
		_refresh()
		return
	_cancel_flight(target)
	if source_slot >= 0:
		_cancel_flight(source_slot)
		var displaced := troop.leaders[target]
		if target != source_slot and not displaced.is_empty():
			var other := (_leader_area.get_child(target) as CardWidget).visual
			other.reparent(self, true)
			other.modulate = Color.WHITE
			_flights[source_slot] = {"node": other, "card": displaced, "tween": null}
	_flights[target] = {"node": art, "card": display_name, "tween": null}
	get_node("/root/UIAudio").play()
	if source_slot < 0:
		troop.deploy(display_name, target)
	elif source_slot != target:
		troop.move_leader(display_name, target)
	else:
		_refresh()
	_animate_flight(target)
	if source_slot >= 0 and source_slot != target and _flights.has(source_slot):
		_animate_flight(source_slot)

func _finish_flight(slot: int, flying: Control) -> void:
	if not _flights.has(slot) or _flights[slot].node != flying:
		return
	_flights.erase(slot)
	flying.queue_free()
	if slot < _leader_area.get_child_count():
		_leader_area.get_child(slot).show()

func _cancel_flight(slot: int) -> void:
	if not _flights.has(slot):
		return
	var flight: Dictionary = _flights[slot]
	if flight.tween != null:
		flight.tween.kill()
	flight.node.queue_free()
	_flights.erase(slot)

func _select_faction(faction: int) -> void:
	_request_view(faction, _requested_bonus)

func _sort(mode: int) -> void:
	if _transitioning or _drag_art != null or is_instance_valid(_drag_source):
		return
	sort_mode = mode
	_refresh()

func _cycle_details() -> void:
	if _flip_locked or _transitioning or _drag_art != null:
		return
	_flip_locked = true
	detail_mode = (detail_mode + 1) % 3
	for parent: Node in [_leader_area, _grid]:
		for child: Node in parent.get_children():
			if child is CardWidget:
				child.flip_to(detail_mode)
	await get_tree().create_timer(0.28).timeout
	_flip_locked = false

func _toggle_bonuses() -> void:
	_show_bonuses(not _requested_bonus)

func _show_bonuses(show: bool) -> void:
	_request_view(_requested_faction, show)

func _set_upgrade_preview(enabled: bool) -> void:
	if _drag_art != null:
		_upgrade_checkbox.set_pressed_no_signal(_requested_upgrades)
		return
	_upgrade_checkbox.selected = enabled
	(_upgrade_checkbox.content.get_node("CheckMark") as TextureRect).texture = preload("res://assets/formation/upgrade_checked.svg") if enabled else preload("res://assets/formation/upgrade_unchecked.svg")
	_requested_upgrades = enabled
	_request_view(_requested_faction, _requested_bonus)

func _request_view(faction: int, show: bool) -> void:
	if _drag_art != null:
		return
	_requested_faction = faction
	_requested_bonus = show
	if not _transitioning and (selected_faction != faction or bonuses_visible != show or preview_upgrades != _requested_upgrades):
		_transition_view()

func _transition_view() -> void:
	_transitioning = true
	while selected_faction != _requested_faction or bonuses_visible != _requested_bonus or preview_upgrades != _requested_upgrades:
		while _flip_locked:
			await get_tree().create_timer(0.03).timeout
		if bonuses_visible != _requested_bonus:
			await _fade_content(0.0, 0.075)
			var faction_changed := selected_faction != _requested_faction
			selected_faction = _requested_faction
			bonuses_visible = _requested_bonus
			preview_upgrades = _requested_upgrades
			if faction_changed:
				_scroll.scroll_vertical = 0
			_refresh()
			await _fade_content(1.0, 0.10)
		else:
			var upgrades_changed := preview_upgrades != _requested_upgrades
			if not bonuses_visible:
				await _stagger_cards(0.0, upgrades_changed)
			var faction_changed := selected_faction != _requested_faction
			selected_faction = _requested_faction
			upgrades_changed = upgrades_changed or preview_upgrades != _requested_upgrades
			preview_upgrades = _requested_upgrades
			if faction_changed:
				_scroll.scroll_vertical = 0
			if upgrades_changed:
				# Any deployment already in flight settles before the preview redraw.
				for slot: int in _flights.keys():
					_cancel_flight(slot)
				_refresh()
			else:
				_refresh_faction_cards()
			if not bonuses_visible:
				await _stagger_cards(1.0, upgrades_changed)
	_transitioning = false

func _stagger_cards(alpha: float, include_leaders: bool = false) -> void:
	var all_cards: Array[CanvasItem] = []
	for child: CanvasItem in _grid.get_children():
		all_cards.append(child)
	if include_leaders:
		for child: Node in _leader_area.get_children():
			if child is CardWidget:
				all_cards.append(child)
	if alpha > 0:
		for child: CanvasItem in all_cards:
			child.modulate.a = 0.0
	# Let GridContainer place new cards before calculating visible wave ranks.
	await get_tree().process_frame
	var visible_cards: Array[Control] = []
	var ranks: Array[int] = []
	var first_rank := 1000000
	var viewport_rect := _scroll.get_global_rect()
	for i: int in range(_grid.get_child_count()):
		var child := _grid.get_child(i) as Control
		if child is CardWidget and viewport_rect.intersects(child.get_global_rect()):
			var rank: int = i / _grid.columns + i % _grid.columns
			visible_cards.append(child)
			ranks.append(rank)
			first_rank = mini(first_rank, rank)
	if include_leaders:
		for i: int in range(_leader_area.get_child_count()):
			var child := _leader_area.get_child(i) as Control
			if child is CardWidget:
				visible_cards.append(child)
				ranks.append(i)
				first_rank = mini(first_rank, i)
	if not visible_cards.is_empty():
		var tween := create_tween().set_parallel(true)
		for i: int in range(visible_cards.size()):
			tween.tween_property(visible_cards[i], "modulate:a", alpha, 0.085).set_delay((ranks[i] - first_rank) * 0.025).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
	for child: CanvasItem in all_cards:
		child.modulate.a = alpha

func _fade_content(alpha: float, duration: float) -> void:
	var nodes: Array[CanvasItem] = [_ground, _scroll, _scrollbar, _sort_caption, _details, _upgrade_checkbox, _bonus_area, _leader_counts]
	for node: CanvasItem in _tabs + _sort_buttons:
		nodes.append(node)
	var tween := create_tween().set_parallel(true)
	for node: CanvasItem in nodes:
		tween.tween_property(node, "modulate:a", alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _apply_mode_view(show: bool) -> void:
	bonuses_visible = show
	_bonus_area.visible = show
	_leader_counts.visible = show
	_ground.visible = not show
	_scroll.visible = not show
	_scrollbar.visible = not show
	_sort_caption.visible = not show
	_details.visible = not show
	_upgrade_checkbox.visible = not show
	_bonus_button.selected = show
	_formation_button.selected = not show
	for button: Button in _tabs + _sort_buttons:
		button.visible = not show

func _preview_level(value: float) -> void:
	# Batch update to avoid rebuilding all widgets once per record.
	if troop.encyclopedia_mode:
		for card: Dictionary in troop.available:
			if card.faction == selected_faction:
				troop.levels[card.name] = int(value)
		troop.changed.emit()

func _input(event: InputEvent) -> void:
	if get_tree().get_first_node_in_group("modal_overlay") != null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_node("/root/UIAudio").play("cancel")
		close_requested.emit()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _transitioning and not _flip_locked:
				_drag_source = _card_at(event.position)
				if is_instance_valid(_drag_source) and _drag_source.selection_blocked(): _drag_source = null
				_drag_start = event.position
		elif _drag_art != null:
			get_viewport().set_input_as_handled()
			_release_drag(event.position)
		else:
			_drag_source = null
	elif event is InputEventMouseMotion:
		if _drag_art == null and is_instance_valid(_drag_source) and event.position.distance_to(_drag_start) >= 8:
			_start_drag(event.position)
		if _drag_art != null:
			_drag_art.position = event.position - global_position - _drag_offset
			get_viewport().set_input_as_handled()

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
