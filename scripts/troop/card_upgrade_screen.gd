extends Control
class_name CardUpgradeScreen
## Shared selection flow. Rest upgrades commit together or roll back together.
signal completed
signal cancelled
const BLUR_SHADER: Shader = preload("res://shaders/gaussian_blur.gdshader")
const CARD_SCALE := 1.8
const BEFORE_AT := Vector2(440, 196)
const AFTER_AT := Vector2(1106, 196)
const SPARK := preload("res://assets/formation/forge_spark.png")
const EMBER := preload("res://assets/formation/forge_ember.png")
const STRIKE_SOUND := preload("res://assets/audio/forge_strike.wav")
## Each blow rings at a slightly different pitch, like successive hits on an anvil.
const STRIKE_PITCHES := [1.0, 1.06, 0.95]
const FINISH_SOUND := preload("res://assets/audio/forge_finish.ogg")
## Forge blows land on these fractions of the upgraded card, one after another.
const STRIKES := [Vector2(0.34, 0.3), Vector2(0.68, 0.5), Vector2(0.42, 0.72)]
const STRIKE_GAP := 0.36
var troop: TroopState
var remaining := 1
var rest_mode := false
var _used := 0
var _entry: Dictionary
var _formation: TroopFormation
var _remaining_label: Label
var _overlay: Control
var _notice: Control
## Closing overlays keep animating after _overlay is cleared; any new action settles them first.
var _leaving: Control
var _leaving_tween: Tween
var _intro: Tween
var _arrow_tween: Tween
var _blur: Array[ShaderMaterial] = []
var _pending_finish := false
## Fade to black before reporting completion (rest site), so the next screen appears under it.
var fade_out := false
var _selected := ""
var _exit_prompt := false
var _finished := false
var _previous_focus: WeakRef

func _ready() -> void:
	name = "CardUpgradeScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("modal_overlay")
	add_to_group("card_upgrade_screen")
	_previous_focus = weakref(get_viewport().gui_get_focus_owner())
	_entry = TroopCheckpoint.capture(troop)
	_formation = (load("res://scenes/troop_formation.tscn") as PackedScene).instantiate() as TroopFormation
	_formation.configure(troop)
	_formation.upgrade_selection = true
	_formation.upgrade_selected.connect(select_card)
	_formation.close_requested.connect(request_back)
	add_child(_formation)
	_remaining_label = BattleArt.label(_formation, "", Vector2(1555, 660), Vector2(350, 105), 25, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_remaining_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_remaining()

func _refresh_remaining() -> void:
	_remaining_label.text = "强化卡牌\n剩余 %d 次" % remaining

func _make_overlay(blurred := false) -> Control:
	_settle_leaving()
	_formation.process_mode = Node.PROCESS_MODE_DISABLED
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	if blurred:
		# Same separable blur as the encyclopedia: the formation stays visible but recedes.
		_blur.clear()
		for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
			var copy := BackBufferCopy.new()
			copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
			_overlay.add_child(copy)
			var pass_rect := ColorRect.new()
			pass_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			pass_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var material := ShaderMaterial.new()
			material.shader = BLUR_SHADER
			material.set_shader_parameter("direction", direction)
			pass_rect.material = material
			_overlay.add_child(pass_rect)
			_blur.append(material)
		_set_blur(0.0)
		return _overlay
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.02, 0.015, 0.94)
	_overlay.add_child(shade)
	return _overlay

func _set_blur(amount: float) -> void:
	var screen_scale: float = float(get_viewport().get_texture().get_width()) / 1920.0
	for material: ShaderMaterial in _blur:
		material.set_shader_parameter("blur_pixels", 20.0 * screen_scale * amount)
	if _blur.size() == 2: _blur[1].set_shader_parameter("darkness", 0.62 * amount)

func select_card(display_name: String) -> void:
	_settle_leaving()
	if _finished or is_instance_valid(_overlay) or is_instance_valid(_notice) or not troop.has_card(display_name): return
	var before := troop.catalog.find_name(display_name)
	var after := troop.catalog.upgrade_preview(before)
	if after.name == before.name:
		_show_notice("无法强化", "该卡牌已强化，无法再次强化。" if display_name.ends_with("+") else "该卡牌没有强化版本。")
		return
	var source := _source_rect(display_name)
	_selected = display_name
	_exit_prompt = false
	_make_overlay(true)
	var preview := TroopState.new()
	preview.configure(troop.catalog, false)
	TroopCheckpoint.restore(preview, TroopCheckpoint.capture(troop))
	preview.upgrade_card(display_name)
	var fading: Array[CanvasItem] = []
	var banner := NativeSettingsArt.picture(_overlay, "section_decor", Vector2(612, 18), Vector2(696, 123))
	fading.append(banner)
	fading.append(BattleArt.label(_overlay, "确认强化", Vector2(612, 46), Vector2(696, 66), 42, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var before_view := _comparison_card(troop, before, BEFORE_AT, "当前卡牌", fading)
	var after_view := _comparison_card(preview, after, AFTER_AT, "强化后", fading)
	_highlight_changes(after_view, before)
	var arrow := TextureRect.new()
	arrow.name = "UpgradeArrow"
	arrow.texture = preload("res://assets/ui/upgrade_arrow.png")
	arrow.position = Vector2(917, 420)
	arrow.size = arrow.texture.get_size()
	arrow.modulate = FormationArt.GOLD
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(arrow)
	fading.append(arrow)
	var text := BattleArt.label(_overlay, "强化版本替代原卡，保留等级和技能使用状态。", Vector2(360, 828), Vector2(1200, 50), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	fading.append(text)
	var back := _native_button("返回", Vector2(724, 900), _close_overlay, "cancel")
	back.name = "BackUpgrade"
	var confirm := _native_button("确认强化", Vector2(1000, 900), confirm_upgrade)
	confirm.name = "ConfirmUpgrade"
	fading.append_array([back, confirm])
	confirm.grab_focus()
	_play_intro(source, before_view, after_view, fading, [back, confirm])
	_sway(arrow)

func _comparison_card(state: TroopState, record: Dictionary, at: Vector2, caption: String, fading: Array[CanvasItem]) -> CardWidget:
	var widget := CardWidget.new()
	widget.name = "BeforeCard" if state == troop else "AfterCard"
	widget.setup(record, state, false, 2)
	widget.set_meta("upgrade_selection", true)
	widget.set_meta("omit_down", true)
	widget.set_meta("omit_unavailable", true)
	widget.position = at
	widget.scale = Vector2.ONE * CARD_SCALE
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.focus_mode = Control.FOCUS_NONE
	_overlay.add_child(widget)
	var width := 208.0 * CARD_SCALE
	fading.append(BattleArt.label(_overlay, caption + "  ★%d" % state.level(record.name), Vector2(at.x - 50, at.y - 62), Vector2(width + 100, 54), 30, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var plate := NativeSettingsArt.picture(_overlay, "item_decor", Vector2(at.x + width / 2.0 - 199, at.y + 312.0 * CARD_SCALE + 14), Vector2(398, 42))
	fading.append(plate)
	fading.append(BattleArt.label(_overlay, record.name, plate.position + Vector2(36, 0), Vector2(326, 42), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	return widget

func _highlight_changes(view: CardWidget, original: Dictionary) -> void:
	# The upgraded record is shown directly; mark only its changed description text.
	for index: int in range(2):
		var label := view.visual.get_node_or_null("SkillDescription%d" % (index + 1)) as Label
		var source: Dictionary = troop.catalog.skills.get(int(original["skill%d" % (index + 1)]), {})
		if label != null and not source.is_empty(): UpgradePreviewText.apply(label, String(source.description))

func _native_button(caption: String, at: Vector2, callback: Callable, cue := "click") -> OriginalUiButton:
	var button := OriginalUiButton.make(_overlay, "back", at, Vector2(196, 92), callback, cue, NativeSettingsArt.ROOT)
	BattleArt.label(button.content, caption, Vector2(12, 8), Vector2(172, 74), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	return button

func _source_rect(display_name: String) -> Rect2:
	var fallback := Rect2()
	for node: Node in _formation.find_children("*", "Button", true, false):
		var widget := node as CardWidget
		if widget == null or widget.card.get("name", "") != display_name or not widget.is_visible_in_tree(): continue
		var rect := widget.get_global_rect()
		if rect.has_point(get_global_mouse_position()) or widget.has_focus(): return rect
		if fallback.size == Vector2.ZERO: fallback = rect
	return fallback

func _play_intro(source: Rect2, before_view: CardWidget, after_view: CardWidget, fading: Array[CanvasItem], buttons: Array) -> void:
	for button: OriginalUiButton in buttons: button.disabled = true
	for item: CanvasItem in fading: item.modulate.a = 0.0
	var start_scale := source.size.x / 208.0 if source.size != Vector2.ZERO else CARD_SCALE * 0.82
	var start := source.position if source.size != Vector2.ZERO else BEFORE_AT + Vector2(208, 312) * CARD_SCALE * 0.09
	before_view.position = start
	before_view.scale = Vector2.ONE * start_scale
	after_view.position = BEFORE_AT
	after_view.modulate.a = 0.0
	_intro = create_tween().set_parallel(true)
	_intro.tween_method(_set_blur, 0.0, 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_intro.tween_property(before_view, "position", BEFORE_AT, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro.tween_property(before_view, "scale", Vector2.ONE * CARD_SCALE, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro.tween_property(after_view, "position", AFTER_AT, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.16)
	_intro.tween_property(after_view, "modulate:a", 1.0, 0.24).set_delay(0.16)
	for item: CanvasItem in fading:
		_intro.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(0.3)
	_intro.chain().tween_callback(func() -> void:
		for button: OriginalUiButton in buttons:
			if is_instance_valid(button): button.disabled = false)

func _finish_intro() -> void:
	if _intro != null and _intro.is_valid() and _intro.is_running(): _intro.custom_step(10.0)

func _sway(arrow: Control) -> void:
	if _arrow_tween != null: _arrow_tween.kill()
	_arrow_tween = arrow.create_tween().set_loops()
	_arrow_tween.tween_property(arrow, "position:x", arrow.position.x + 12, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arrow_tween.tween_property(arrow, "position:x", arrow.position.x, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func confirm_upgrade() -> void:
	_finish_intro()
	if _finished or _exit_prompt or _selected.is_empty() or remaining <= 0 or not is_instance_valid(_overlay): return
	if not troop.upgrade_card(_selected): return
	remaining -= 1
	_used += 1
	_refresh_remaining()
	var view := _overlay.get_node_or_null("AfterCard") as CardWidget
	var before_view := _overlay.get_node_or_null("BeforeCard") as CanvasItem
	var node := _detach_overlay()
	_disable_buttons(node)
	_pending_finish = remaining == 0
	_forge(node, view, before_view)

## Blacksmith confirmation without a literal hammer: three blows, each a white spark
## point, a broken fiery ring expanding outward and embers flying off, then a
## finishing chime and gold flash. Right click settles it.
func _forge(node: Control, view: CardWidget, before_view: CanvasItem) -> void:
	_leaving_tween = node.create_tween().set_parallel(true)
	if before_view != null: _leaving_tween.tween_property(before_view, "modulate:a", 0.3, 0.2)
	if view == null:
		_leaving_tween.chain().tween_callback(_settle_leaving)
		return
	var card_size := Vector2(208, 312) * CARD_SCALE
	var marks: Array[Sprite2D] = []
	for n: int in range(STRIKES.size()):
		var point: Vector2 = AFTER_AT + card_size * STRIKES[n]
		_leaving_tween.tween_callback(_strike.bind(node, view, point, marks, float(STRIKE_PITCHES[n]))).set_delay(0.2 + n * STRIKE_GAP)
	var done := 0.12 + STRIKES.size() * STRIKE_GAP
	_leaving_tween.tween_callback(func() -> void:
		_sfx(FINISH_SOUND)
		view.visual.modulate = Color(1.9, 1.65, 1.1)
		pass).set_delay(done)
	_leaving_tween.tween_property(view.visual, "modulate", Color.WHITE, 0.5).set_delay(done + 0.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The last upgrade stays on screen for the black transition; others fade back to selection.
	if not (_pending_finish and fade_out):
		_leaving_tween.tween_property(node, "modulate:a", 0.0, 0.26).set_delay(done + 0.5)
	_leaving_tween.chain().tween_callback(_settle_leaving)

func _strike(node: Control, view: CardWidget, point: Vector2, _marks: Array[Sprite2D], pitch: float) -> void:
	_sfx(STRIKE_SOUND, pitch)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# White spark point at the blow.
	var spark := Sprite2D.new()
	spark.texture = SPARK
	spark.material = additive
	spark.position = point
	spark.rotation = randf() * TAU
	spark.scale = Vector2.ONE * 0.2
	node.add_child(spark)
	var flash := spark.create_tween()
	flash.tween_property(spark, "scale", Vector2.ONE * 0.62, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash.tween_property(spark, "scale", Vector2.ONE * 0.4, 0.18)
	flash.parallel().tween_property(spark, "modulate:a", 0.0, 0.18)
	flash.tween_callback(spark.queue_free)
	# Broken fiery ring: a few arcs with gaps, expanding and thinning out.
	var ring := Node2D.new()
	ring.position = point
	ring.rotation = randf() * TAU
	node.add_child(ring)
	var arcs: Array[Line2D] = []
	for n: int in range(4):
		for core: bool in [false, true]:
			var arc := Line2D.new()
			arc.material = additive
			arc.width = 3.0 if core else 9.0
			arc.default_color = Color(1.0, 0.92, 0.75, 1.0) if core else Color(1.0, 0.36, 0.1, 0.75)
			arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
			arc.end_cap_mode = Line2D.LINE_CAP_ROUND
			arc.set_meta("start", n * TAU / 4.0 + randf_range(0.0, 0.35))
			arc.set_meta("span", randf_range(0.75, 1.1))
			ring.add_child(arc)
			arcs.append(arc)
	var grow := ring.create_tween()
	grow.tween_method(_draw_ring.bind(arcs), 34.0, 150.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grow.parallel().tween_property(ring, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	grow.parallel().tween_property(ring, "rotation", ring.rotation + 0.35, 0.42)
	grow.tween_callback(ring.queue_free)
	# Embers streak outward, aligned with their flight, and fall away.
	var embers := CPUParticles2D.new()
	embers.position = point
	embers.texture = EMBER
	embers.material = additive
	embers.one_shot = true
	embers.explosiveness = 1.0
	embers.amount = 18
	embers.lifetime = 0.6
	embers.particle_flag_align_y = true
	embers.direction = Vector2.UP
	embers.spread = 180.0
	embers.initial_velocity_min = 260.0
	embers.initial_velocity_max = 620.0
	embers.damping_min = 260.0
	embers.damping_max = 420.0
	embers.gravity = Vector2(0, 260)
	embers.scale_amount_min = 0.35
	embers.scale_amount_max = 0.75
	var cool := Gradient.new()
	cool.set_color(0, Color(1, 1, 1, 1))
	cool.set_color(1, Color(1.0, 0.45, 0.2, 0.0))
	embers.color_ramp = cool
	node.add_child(embers)
	embers.emitting = true
	embers.finished.connect(embers.queue_free)
	view.visual.modulate = Color(1.35, 1.28, 1.15)
	var shake := view.create_tween()
	for offset: Vector2 in [Vector2(0, 7), Vector2(0, -3), Vector2(0, 1), Vector2.ZERO]:
		shake.tween_property(view, "position", AFTER_AT + offset, 0.03)
	shake.parallel().tween_property(view.visual, "modulate", Color.WHITE, 0.18)

func _draw_ring(radius: float, arcs: Array[Line2D]) -> void:
	for arc: Line2D in arcs:
		if not is_instance_valid(arc): continue
		var start := float(arc.get_meta("start"))
		var span := float(arc.get_meta("span"))
		var points := PackedVector2Array()
		for k: int in range(13):
			var a := start + span * k / 12.0
			points.append(Vector2(cos(a), sin(a)) * radius)
		arc.points = points

func _sfx(stream: AudioStream, pitch := 1.0) -> void:
	# Owned by the screen (not the overlay) so a skipped animation does not cut the sound.
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func request_back() -> void:
	if _finished: return
	if is_instance_valid(_leaving):
		_settle_leaving()
		return
	if is_instance_valid(_notice):
		_close_notice()
		return
	if is_instance_valid(_overlay):
		_close_overlay()
		return
	if rest_mode and _used == 0:
		_finish(false)
		return
	_exit_prompt = true
	_make_overlay()
	(_overlay.get_child(0) as ColorRect).color = Color(0, 0, 0, 0.65)
	var panel := Panel.new()
	panel.position = Vector2(460, 330)
	panel.size = Vector2(1000, 400)
	panel.add_theme_stylebox_override("panel", BattleArt.panel_style())
	_overlay.add_child(panel)
	BattleArt.label(_overlay, "退出强化", Vector2(535, 343), Vector2(850, 40), 30, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var text := "你还剩%d次强化卡牌没有选择，确认要退出吗？" % remaining
	if rest_mode:
		text = "你还剩%d次强化没有使用，\n退出后将返还本次所有的强化选择，是否要退出？" % remaining
	var body := BattleArt.label(_overlay, text, Vector2(535, 432), Vector2(850, 150), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	BattleArt.text_button(_overlay, "确认", Vector2(660, 625), Vector2(220, 76), _confirm_exit)
	var back := BattleArt.text_button(_overlay, "返回" if rest_mode else "取消", Vector2(1040, 625), Vector2(220, 76), _close_overlay)
	back.name = "CancelExit"
	back.grab_focus()

func _confirm_exit() -> void:
	if rest_mode: TroopCheckpoint.restore(troop, _entry); troop.changed.emit()
	_finish(false)

func _close_overlay() -> void:
	_finish_intro()
	if not is_instance_valid(_overlay): return
	var animated := not _exit_prompt
	var node := _detach_overlay()
	if not animated:
		node.queue_free()
		_restore_selection()
		return
	_disable_buttons(node)
	_leaving_tween = node.create_tween()
	_leaving_tween.tween_property(node, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_leaving_tween.tween_callback(_settle_leaving)

func _disable_buttons(node: Node) -> void:
	for child: Node in node.get_children():
		if child is OriginalUiButton: (child as OriginalUiButton).disabled = true

## Clears the active overlay state now while its node keeps playing the exit animation.
func _detach_overlay() -> Control:
	var node := _overlay
	_overlay = null
	_selected = ""
	_exit_prompt = false
	_leaving = node
	if _arrow_tween != null: _arrow_tween.kill()
	return node

func _settle_leaving() -> void:
	if _leaving_tween != null and _leaving_tween.is_valid(): _leaving_tween.kill()
	_leaving_tween = null
	if is_instance_valid(_leaving) and _pending_finish and fade_out:
		# Keep the forged card visible while the screen fades to black.
		_finish(true)
		return
	if is_instance_valid(_leaving):
		remove_child(_leaving)
		_leaving.queue_free()
		_leaving = null
		if _pending_finish: _finish(true)
		else: _restore_selection()

func _restore_selection() -> void:
	if _finished or is_instance_valid(_overlay) or is_instance_valid(_notice): return
	_formation.process_mode = Node.PROCESS_MODE_INHERIT
	_formation._tabs[_formation.selected_faction - 1].grab_focus()

## Native InformationDialog: 50% shade, シス／对话窗口／下地, caption and text; any click closes it.
func _show_notice(caption: String, message: String) -> void:
	_formation.process_mode = Node.PROCESS_MODE_DISABLED
	_notice = Control.new()
	_notice.name = "UpgradeNotice"
	_notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_notice.mouse_filter = Control.MOUSE_FILTER_STOP
	_notice.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_close_notice())
	add_child(_notice)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_child(shade)
	var dialog := TextureRect.new()
	dialog.name = "Dialog"
	dialog.texture = preload("res://assets/ui/dialog_base.png")
	dialog.size = dialog.texture.get_size()
	dialog.position = Vector2(976, 512) - dialog.size / 2.0
	dialog.pivot_offset = dialog.size / 2.0
	dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_child(dialog)
	var title := BattleArt.label(dialog, caption, Vector2(3, 24), Vector2(862, 44), 26, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Caption"
	var body := BattleArt.label(dialog, message, Vector2(30, 88), Vector2(802, 100), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	body.name = "Text"
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.modulate.a = 0.0
	dialog.scale = Vector2.ONE * 0.92
	var tween := _notice.create_tween().set_parallel(true)
	tween.tween_property(_notice, "modulate:a", 1.0, 0.16)
	tween.tween_property(dialog, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_node("/root/UIAudio").play("cancel")

func _close_notice() -> void:
	if not is_instance_valid(_notice): return
	var node := _notice
	_notice = null
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func() -> void:
		node.queue_free()
		_restore_selection())

func _finish(success: bool) -> void:
	if _finished: return
	_finished = true
	remove_from_group("modal_overlay")
	remove_from_group("card_upgrade_screen")
	if success and fade_out:
		# Report completion under a black frame so the map replaces this screen smoothly.
		get_node("/root/ScreenTransition").play(func() -> void:
			completed.emit()
			queue_free())
		return
	if success: completed.emit()
	else: cancelled.emit()
	var focus: Control = _previous_focus.get_ref() if _previous_focus != null else null
	if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree(): focus.grab_focus()
	queue_free()

func _input(event: InputEvent) -> void:
	var console := get_node("/root/DebugConsole")
	if console.panel.visible or get_node("/root/ScreenTransition").busy: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		request_back()
