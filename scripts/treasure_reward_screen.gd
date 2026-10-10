extends Control
class_name TreasureRewardScreen
signal completed
signal back_requested
var troop: TroopState
var chest: TreasureChest
var standalone := false
var exit_blackout := false
var cards: Array[CardWidget] = []
var slots: Array[Control] = []
var backs: Array[TextureRect] = []
var marks: Array[Control] = []
var faction_info: Array[TreasureFactionInfo] = []
var rarity_frames: Array[OriginalFlatPlayer] = []
var hover_frames: Array[OriginalFlatPlayer] = []
var arrival_effects: Array[OriginalFlatPlayer] = []
var _continue: OriginalUiButton
var _details: OriginalUiButton
var _upgrade_checkbox: OriginalUiButton
var detail_mode := 0
var preview_upgrades := false
var _status: Label
var _busy := true
var _done := false
var _confirming := false
var _serial := 0
var _reveals_left := 0
var _backs_left := 0
var _body: Control
var _entrance: Tween

func _ready() -> void:
	name = "TreasureReward"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("modal_overlay")
	if standalone: TreasureArt.backdrop(self)
	_body = Control.new()
	_body.name = "TreasureInterface"
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	var factor := 0.88 if chest.offers.size() == 5 else 1.0
	var panel_size := Vector2(1962, 572) * factor if chest.offers.size() == 5 else Vector2(1422, 572)
	var panel_at := Vector2((1920 - panel_size.x) * 0.5, 270)
	var art_path := "panel_five_tab" if chest.offers.size() == 5 else "panel_boss_tab"
	_body.pivot_offset = panel_at + (panel_size + Vector2(0, 82 * factor)) * 0.5
	_body.scale = Vector2.ONE * 0.18
	_body.modulate.a = 0.0
	var panel := TreasureArt.picture(_body, art_path, panel_at, panel_size + Vector2(0, 82 * factor))
	panel.name = "TreasurePanel"
	var chest_at := panel_at + Vector2(345, 315) * factor
	var opening := TreasureArt.flat(_body, "gold_open" if chest.pool_id == 3 else "chest_open", chest_at - Vector2(656, 575) * factor)
	opening.playback_speed = 1.40
	opening.scale = Vector2.ONE * factor
	TreasureArt.sound(self, "chest_open")
	for i: int in range(chest.offers.size()):
		var slot := Control.new()
		slot.name = "CardSlot%d" % i
		slot.position = panel_at + Vector2(529 + i * 270, 130) * factor
		slot.size = Vector2(208, 312)
		slot.scale = Vector2.ONE * factor
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(slot)
		slots.append(slot)
		var record: Dictionary = chest.offers[i]
		var card := CardWidget.new()
		card.setup(record, troop, false, 0)
		card.set_meta("omit_unavailable", true)
		card.set_meta("omit_down", true)
		card.pressed.connect(_take.bind(i))
		slot.add_child(card)
		card.hide()
		cards.append(card)
		var info := TreasureFactionInfo.new()
		info.name = "FactionInfo"
		info.record = record
		info.troop = troop
		info.position = Vector2(0, 325)
		slot.add_child(info)
		info.hide()
		faction_info.append(info)
		backs.append(TreasureArt.picture(slot, "back_%d" % record.rarity, Vector2.ZERO, Vector2(208, 312)))
		backs[i].pivot_offset = Vector2(104, 156)
		backs[i].hide()
		# Native entry includes the descent from y=-500 and two side-on turns.
		var arrival := TreasureArt.flat(slot, "common", Vector2(104, 156), false)
		arrival.playback_speed = 1.65
		arrival.z_index = 3
		arrival.hide()
		arrival_effects.append(arrival)
		var frame: OriginalFlatPlayer
		if int(record.rarity) > 1:
			frame = TreasureArt.flat(slot, "uncommon_frame" if int(record.rarity) == 2 else "rare_frame", Vector2(104, 156))
			frame.z_index = 2
			frame.hide()
		rarity_frames.append(frame)
		var mark := Control.new()
		mark.position = Vector2(-18, -30)
		mark.size = Vector2(250, 40)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(mark)
		mark.hide()
		marks.append(mark)
		_refresh_mark(i)
		var hover := TreasureArt.flat(slot, "hover_frame")
		hover.name = "HoverFrame"
		hover.z_index = 4
		hover.hide()
		hover_frames.append(hover)
		if i in chest.selected: slot.hide()
	_status = BattleArt.label(_body, "最多领取 %d 张卡牌" % chest.limit, panel_at + Vector2(25, panel_size.y - 112), Vector2(440 * factor, 30), 23, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_continue = TreasureArt.button(_body, "继续", panel_at + panel_size - Vector2(216, 4) * factor, _finish)
	_continue.scale = Vector2.ONE * factor
	_continue.size.y = 78
	# The button is inset in the extended background itself, with no second frame.
	_continue.art.hide()
	_continue.mouse_entered.connect(func() -> void: _continue.content.modulate = FormationArt.GOLD)
	_continue.mouse_exited.connect(func() -> void: _continue.content.modulate = Color.WHITE)
	_continue.z_index = 4
	_continue.name = "Continue"
	_continue.disabled = true
	_build_view_controls(panel_at + panel_size - Vector2(98, 94))
	TreasureArt.button(_body, "返回", Vector2(863, 905), _back).name = "Back"
	_set_interface_alpha(0.35)
	_play_entrance.call_deferred()
	_reveal.call_deferred()

func _play_entrance() -> void:
	# Present the small frame before starting the tween, including first-time loads.
	if DisplayServer.get_name() == "headless": await get_tree().process_frame
	else: await RenderingServer.frame_post_draw
	if _done: return
	_entrance = create_tween().set_parallel(true)
	_entrance.tween_property(_body, "scale", Vector2.ONE, 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_entrance.tween_method(_set_interface_alpha, 0.35, 1.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _process(_delta: float) -> void:
	var available := not _busy and not _done and _body.visible
	available = available and not get_node("/root/DebugConsole").panel.visible and not is_instance_valid(get_node("/root/Settings").panel)
	for i: int in range(hover_frames.size()):
		hover_frames[i].visible = available and slots[i].visible and cards[i].visible and i not in chest.selected and cards[i].is_hovered()

func _set_interface_alpha(alpha: float) -> void:
	_body.modulate.a = alpha
	# Projected native FLAT nodes inherit transforms, but not their parent's tint.
	# Fade them together with the original panel, without changing animation data.
	var pending: Array[Node] = [_body]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Node2D and node.top_level: node.modulate.a = alpha
		pending.append_array(node.get_children())

func _build_view_controls(at: Vector2) -> void:
	_details = OriginalUiButton.make(_body, "square", at, Vector2(92, 92), _cycle_details)
	_details.name = "Details"
	_details.scale = Vector2.ONE * 0.78
	FormationArt.picture(_details.content, "details_icon", Vector2(11, 11), Vector2(64, 64))
	_upgrade_checkbox = OriginalUiButton.make(_body, "square", at - Vector2(0, 82), Vector2(92, 92), func() -> void: pass)
	_upgrade_checkbox.name = "ViewUpgrades"
	_upgrade_checkbox.scale = Vector2.ONE * 0.78
	_upgrade_checkbox.toggle_mode = true
	var mark := TextureRect.new()
	mark.name = "CheckMark"
	mark.texture = preload("res://assets/formation/upgrade_unchecked.svg")
	mark.position = Vector2(27, 18)
	mark.size = Vector2(32, 32)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_checkbox.content.add_child(mark)
	FormationArt.label(_upgrade_checkbox.content, "查看升级", Vector2(7, 50), Vector2(72, 24), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER).clip_text = true
	_upgrade_checkbox.toggled.connect(_set_upgrade_preview)
	_details.disabled = true
	_upgrade_checkbox.disabled = true

func _refresh_mark(index: int) -> void:
	var mark := marks[index]
	for child: Node in mark.get_children():
		mark.remove_child(child)
		child.queue_free()
	if troop.has_card(chest.offers[index].name):
		TreasureArt.flat(mark, "duplicate")
		var quantity := OriginalBitmapNumber.new()
		quantity.name = "DuplicateCount"
		quantity.atlas = load("res://assets/treasure/duplicate_digits.png")
		# Native Number anchor is bottom-center at (19, 12), inside the blue plate.
		quantity.position = Vector2(10, -12)
		quantity.size = Vector2(18, 24)
		quantity.z_index = 1
		quantity.alignment = HORIZONTAL_ALIGNMENT_CENTER
		quantity.abbreviate = false
		quantity.text = "1"
		quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_child(quantity)
	else: TreasureArt.flat(mark, "new")

func _reveal() -> void:
	var serial := _serial
	_reveals_left = cards.size() - chest.selected.size()
	_backs_left = _reveals_left
	await _present_reveal_frame()
	await get_tree().create_timer(0.55).timeout
	if serial != _serial: return
	for i: int in range(cards.size()):
		if i in chest.selected: continue
		_turn_back(i, serial)
		await get_tree().create_timer(0.07).timeout
		if serial != _serial: return
	while _backs_left > 0:
		await get_tree().process_frame
		if serial != _serial: return
	# Every remaining card back must be drawn at full width before any face reveal.
	await _present_reveal_frame()
	await get_tree().create_timer(0.10).timeout
	if serial != _serial: return
	for rarity: int in [1, 2, 3]:
		var group: Array[int] = []
		for i: int in range(cards.size()):
			if i not in chest.selected and int(chest.offers[i].rarity) == rarity: group.append(i)
		if not group.is_empty(): _show_rarity_group(group, serial)
	while _reveals_left > 0:
		await get_tree().process_frame
		if serial != _serial: return
	# Present the completed flip before accepting selection input.
	await get_tree().process_frame
	_set_busy(false)

func _present_reveal_frame() -> void:
	if DisplayServer.get_name() == "headless": await get_tree().process_frame
	else: await RenderingServer.frame_post_draw

func _turn_back(index: int, serial: int) -> void:
	var arrival := arrival_effects[index]
	TreasureArt.present_flat(arrival, false)
	await _present_reveal_frame()
	if serial != _serial: return
	arrival.autoplay = true
	# The original FadeIn shows the back after the airborne card reaches its slot.
	while arrival.ticks < 12:
		await get_tree().process_frame
		if serial != _serial: return
	backs[index].show()
	# Wait for the white card silhouette to clear, leaving the original tier's back.
	while arrival.ticks < 25:
		await get_tree().process_frame
		if serial != _serial: return
	_backs_left -= 1
	while not arrival.is_finished() and arrival.elapsed < 1.5:
		await get_tree().process_frame
		if serial != _serial: return
	if serial != _serial: return
	arrival.hide()
	arrival.autoplay = false

func _show_rarity_group(indices: Array[int], serial: int) -> void:
	var tween := create_tween().set_parallel(true)
	for index: int in indices:
		tween.tween_property(backs[index], "scale:x", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if serial != _serial: return
	tween = create_tween().set_parallel(true)
	for index: int in indices:
		backs[index].hide()
		cards[index].visual.scale.x = 0.0
		cards[index].show()
		tween.tween_property(cards[index].visual, "scale:x", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if serial != _serial: return
	for index: int in indices:
		marks[index].show()
		faction_info[index].show()
		if is_instance_valid(rarity_frames[index]): rarity_frames[index].show()
	_reveals_left -= indices.size()

func _take(index: int) -> void:
	if _busy or _done or not chest.claim_card(index, troop): return
	get_node("/root/UIAudio").play("click")
	_confirming = true
	_set_busy(true)
	var slot := slots[index]
	faction_info[index].hide()
	marks[index].hide()
	if is_instance_valid(rarity_frames[index]): rarity_frames[index].hide()
	# Receipt begins on click; the inventory grant above is never deferred to Continue.
	slot.reparent(self)
	slot.z_index = 6
	cards[index].visual.modulate = Color.WHITE
	var tween := create_tween().set_parallel(true)
	tween.tween_property(slot, "position", Vector2(960, 540) - slot.size * 0.5, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(slot, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_interface_alpha, 1.0, 0.0, 0.18).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_body.hide()
	# Low-opacity warm edge light replaces the original whole-screen white flash.
	var halo := ColorRect.new()
	halo.name = "ReceiptHalo"
	halo.position = Vector2(-32, -32)
	halo.size = Vector2(272, 376)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.z_index = -1
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/treasure_receipt_glow.gdshader")
	halo.material = material
	halo.modulate.a = 0.0
	slot.add_child(halo)
	TreasureArt.sound(self, "card_get")
	tween = create_tween()
	tween.tween_property(halo, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(halo, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	tween = create_tween()
	tween.tween_property(slot, "modulate:a", 0.0, 0.18)
	await tween.finished
	slot.hide()
	halo.queue_free()
	_body.show()
	tween = create_tween()
	tween.tween_method(_set_interface_alpha, 0.0, 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_confirming = false
	_set_busy(false)
	if chest.selected.size() >= chest.limit:
		_finish()
		return
	_refresh_remaining()

func _set_busy(value: bool) -> void:
	_busy = value
	if value:
		for hover: OriginalFlatPlayer in hover_frames: hover.hide()
	_continue.disabled = value
	_details.disabled = value
	_upgrade_checkbox.disabled = value
	_status.text = "已领取 %d / %d" % [chest.selected.size(), chest.limit]
	for i: int in range(cards.size()):
		cards[i].disabled = value or i in chest.selected

func _refresh_remaining() -> void:
	for i: int in range(cards.size()):
		if i in chest.selected: continue
		cards[i].setup(chest.offers[i], troop, false, detail_mode, preview_upgrades)
		cards[i].redraw()
		faction_info[i].preview_upgrades = preview_upgrades
		faction_info[i].refresh()
		_refresh_mark(i)

func _cycle_details() -> void:
	if _busy or _done: return
	_set_busy(true)
	detail_mode = (detail_mode + 1) % 3
	for i: int in range(cards.size()):
		if i not in chest.selected: cards[i].flip_to(detail_mode)
	await get_tree().create_timer(0.28).timeout
	_set_busy(false)

func _set_upgrade_preview(enabled: bool) -> void:
	if _busy or _done: return
	_set_busy(true)
	preview_upgrades = enabled
	_upgrade_checkbox.selected = enabled
	(_upgrade_checkbox.content.get_node("CheckMark") as TextureRect).texture = preload("res://assets/formation/upgrade_checked.svg") if enabled else preload("res://assets/formation/upgrade_unchecked.svg")
	for i: int in range(cards.size()):
		if i in chest.selected: continue
		cards[i].preview_upgrades = enabled
		cards[i].display_card = troop.catalog.upgrade_preview(chest.offers[i]) if enabled else chest.offers[i]
		cards[i].flip_to(detail_mode)
		faction_info[i].preview_upgrades = enabled
		faction_info[i].refresh()
	await get_tree().create_timer(0.28).timeout
	_set_busy(false)

func _finish() -> void:
	if _busy or _done: return
	chest.finish()
	_done = true
	_set_busy(true)
	_leave(false)

func _back() -> void:
	if _done or _confirming or (_busy and _reveals_left == 0): return
	_done = true
	_serial += 1
	_set_busy(true)
	_leave(true)

func _leave(returning: bool) -> void:
	if is_instance_valid(_entrance): _entrance.kill()
	if exit_blackout:
		var transition := get_node("/root/ScreenTransition")
		while transition.busy: await get_tree().process_frame
		transition.play(_complete_exit.bind(returning))
	else:
		var tween := create_tween()
		tween.tween_method(_set_interface_alpha, _body.modulate.a, 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		_complete_exit(returning)

func _complete_exit(returning: bool) -> void:
	_body.hide()
	remove_from_group("modal_overlay")
	if returning: back_requested.emit()
	else: completed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"): return
	if get_node("/root/DebugConsole").panel.visible or is_instance_valid(get_node("/root/Settings").panel): return
	get_viewport().set_input_as_handled()
	_back()
