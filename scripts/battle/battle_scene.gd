extends Control
class_name BattleScene
const INTENT_STEP := 68.0
const INTENT_ROW_HEIGHT := 89.0
const INTENT_BASELINE := 524.0
const INTENT_LEFT := 491.0
const INTENT_RIGHT := 836.0
const HP_TRAIL_HOLD := 0.40
const HP_TRAIL_CATCH_UP := 0.18
signal close_requested
var battle: BattleState
var speed := 3
var operation_mode := 0
var selected_card := ""
var lifted_actor := ""
var _hovered_card := ""
var _browse_cards := false
var input_locked := false
var formation: TroopFormation
var popup: Control
var analysis_panel: Control
var _analysis_button: OriginalUiButton
var _previous_leaders: Array[String] = []
var _cards: Control
var _leader_power_layer: BattleLeaderPowerLayer
var _ap: BattleApBar
var _ap_override := -1
var _ap_hover_key := ""
var _intents: Control
var _intent_buttons: Array[Button] = []
var _playing_enemy_intents := false
var _combo: Control
var _combo_shown := 0
var _prep: Control
var _swap: OriginalUiButton
var _swap_count: Control
var _swap_number: OriginalBitmapNumber
var _end: OriginalUiButton
var _start: OriginalUiButton
var _formation_button: OriginalUiButton
var _speed_button: OriginalUiButton
var _mode_button: OriginalUiButton
var _restart_button: OriginalUiButton
var _enemy_fill: TextureRect
var _player_fill: TextureRect
var _enemy_hp_trail: TextureRect
var _player_hp_trail: TextureRect
var _enemy_hp_damage: BattleHpDamageEffect
var _player_hp_damage: BattleHpDamageEffect
var _enemy_shield: BattleShieldBar
var _player_shield: BattleShieldBar
var _enemy_number: BattleHpReadout
var _player_number: BattleHpReadout
var _round: OriginalBitmapNumber
var _log: Label
var _result: Control
var reward_pool := 1
var _breath: Tween
var _effect_clock := 0.0
var _presentation: BattlePresentation
var _enemy_damage_preview: TextureRect
var _damage_preview_clock := 0.0
var _pending_damage_preview: Dictionary = {}
var _pointer_position := Vector2.ZERO
var _pointer_known := false
var _status_bars: Array[BattleStatusBar] = []
var _support_bars: Array[BattleSupportBar] = []
var _hidden_hp_labels: Dictionary = {}

func _process(delta: float) -> void:
	_restore_skill_hover()
	if not is_instance_valid(_enemy_damage_preview): return
	if input_locked or battle.phase != "player" or is_instance_valid(popup) or is_instance_valid(formation) or get_tree().get_first_node_in_group("modal_overlay") != null or get_node("/root/ScreenTransition").busy:
		if not _ap_hover_key.is_empty() or not _pending_damage_preview.is_empty() or _enemy_damage_preview.visible:
			_clear_skill_preview()
		return
	if not _pending_damage_preview.is_empty() and not _enemy_hp_trail_animating() and not _enemy_shield.is_animating():
		var request := _pending_damage_preview
		_pending_damage_preview = {}
		if battle.can_use(request.actor, request.id, request.slot):
			_show_damage_preview(request.actor, request.id, request.slot)
		else:
			_clear_skill_preview()
	if not _enemy_damage_preview.visible and not _enemy_shield.preview: return
	_damage_preview_clock += delta
	var alpha := 0.24 + 0.76 * (sin(_damage_preview_clock * TAU * 1.8) + 1.0) * 0.5
	_enemy_damage_preview.modulate = Color(0.0, 0.0, 0.0, alpha)
	_enemy_number.preview_alpha = alpha
	if _enemy_shield.preview: _enemy_shield.set_preview(true, false, alpha)

func _restore_skill_hover() -> void:
	if not _pointer_known or not is_instance_valid(_cards) or input_locked or battle.phase != "player" or is_instance_valid(popup) or is_instance_valid(formation) or get_tree().get_first_node_in_group("modal_overlay") != null or get_node("/root/ScreenTransition").busy: return
	if operation_mode == 1: _hover_card(_pointer_position)
	var hovered: OriginalUiButton
	var actor := ""
	var slot := -1
	var global_pointer := get_global_transform() * _pointer_position
	for card: Node in _cards.get_children():
		if not card is BattleCard: continue
		if not card.visible: continue
		for button: Button in card.skill_buttons:
			if button.get_global_rect().has_point(global_pointer):
				hovered = button as OriginalUiButton
				actor = card.card.name
				slot = int(button.name.trim_prefix("Skill")) - 1
	for card: Node in _cards.get_children():
		if card is BattleCard:
			for button: OriginalUiButton in card.skill_buttons:
				button.sync_hover(button == hovered)
	if hovered == null or hovered.disabled:
		if not _ap_hover_key.is_empty(): _clear_skill_preview()
		return
	var id: int = battle.troop.catalog.find_name(actor)["skill%d" % (slot + 1)]
	if _ap_hover_key != "%s:%d:%d" % [actor, id, slot]:
		_preview_skill_ap(actor, id, slot, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(_enemy_damage_preview):
		_pointer_known = false
		_clear_skill_preview()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	speed = get_node("/root/Settings").battle_speed()
	get_node("/root/Settings").opened.connect(_clear_skill_preview)
	_build_view()

func _build_view() -> void:
	battle.animate_automatic_skills = true
	_build()
	_presentation = BattlePresentation.new()
	_presentation.view = self
	_presentation.layer = _group("BattleEffects")
	_presentation.layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_presentation)
	_status_bars.clear()
	_support_bars.clear()
	_hidden_hp_labels.clear()
	for side: String in ["enemy", "player"]:
		var support_bar := BattleSupportBar.new()
		support_bar.name = "EnemySupportBar" if side == "enemy" else "PlayerSupportBar"
		support_bar.view = self
		support_bar.side = side
		add_child(support_bar)
		_support_bars.append(support_bar)
		battle.support_event.connect(support_bar.on_support_event)
		support_bar.detail_requested.connect(_show_support_detail)
		var bar := BattleStatusBar.new()
		bar.name = "EnemyStatusBar" if side == "enemy" else "PlayerStatusBar"
		bar.view = self
		bar.side = side
		add_child(bar)
		_status_bars.append(bar)
		battle.status_event.connect(bar.on_status_event)
		bar.detail_requested.connect(_show_status_detail)
		var label := BattleArt.label(self, "???", Vector2(30, 550) if side == "enemy" else Vector2(1150, 550), Vector2(740, 44), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT if side == "enemy" else HORIZONTAL_ALIGNMENT_RIGHT)
		label.name = "HiddenHP" + side
		label.hide()
		_hidden_hp_labels[side] = label
	battle.changed.connect(_refresh)
	battle.log_added.connect(_on_log_added)
	_refresh()

func _on_log_added(message: String) -> void:
	_log.text = message

func _restart_battle() -> void:
	if input_locked or is_instance_valid(formation): return
	var keep_analysis := is_instance_valid(analysis_panel)
	_close_popup()
	battle.changed.disconnect(_refresh)
	battle.log_added.disconnect(_on_log_added)
	var restarted := BattleCheckpoint.restore(battle, battle.preparation_checkpoint)
	if restarted == null:
		battle.changed.connect(_refresh)
		battle.log_added.connect(_on_log_added)
		battle.log_message("战前快照无法恢复，重开未执行")
		return
	battle = restarted
	if _breath != null: _breath.kill()
	_breath = null
	BattleArt.clear(self)
	analysis_panel = null
	_result = null
	_combo_shown = 0
	_playing_enemy_intents = false
	_ap_override = -1
	_ap_hover_key = ""
	selected_card = ""
	_hovered_card = ""
	_browse_cards = false
	lifted_actor = ""
	_build_view()
	if keep_analysis: _show_analysis()

func _build() -> void:
	var background := TextureRect.new()
	background.texture = load("res://assets/battle/backgrounds/%s.png" % battle.monster.background)
	background.size = Vector2(1920, 1080)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var stage := Control.new()
	stage.size = Vector2(1920, 690)
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	if battle.monster.portrait == "宝箱团子":
		var native := OriginalFlatPlayer.new()
		native.hidden_libraries = ["Ｃ／背景", "样本背景.png", "Ｇ／色彩渐变.png"]
		native.animation_path = "res://assets/battle/native/monster_treasure/animation.json"
		stage.add_child(native)
	else:
		var portrait := TextureRect.new()
		portrait.texture = load("res://assets/monsters/%s.png" % battle.monster.portrait)
		portrait.size = Vector2(1920, 1080)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.pivot_offset = Vector2(960, 630)
		stage.add_child(portrait)
		_breath = create_tween().set_loops()
		_breath.tween_property(portrait, "scale", Vector2(1.006, 1.015), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_breath.tween_property(portrait, "scale", Vector2.ONE, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	BattleArt.picture(self, "enemy_shadow", Vector2(0, 405))
	BattleArt.picture(self, "player_shadow", Vector2(1520, 405))
	# The HP frame's bend starts at 16 + 475. Align the original long band
	# with that bend, keeping its slanted red end beside the Round ornament.
	var intent_ground := BattleArt.picture(self, "intent_ground", Vector2(INTENT_LEFT, 445))
	intent_ground.name = "EnemyIntentBand"
	var intent_region := AtlasTexture.new()
	intent_region.atlas = intent_ground.texture
	# The native lower band contains weakness UI; only retain the intent band.
	intent_region.region = Rect2(0, 0, 450, 85)
	intent_ground.texture = intent_region
	intent_ground.size = Vector2(450, 85)
	BattleArt.picture(self, "lower_frame", Vector2(0, 568))
	BattleArt.picture(self, "enemy_hp_base", Vector2(16, 588))
	BattleArt.picture(self, "player_hp_base", Vector2(1037, 588))
	_enemy_hp_trail = _hp_trail("enemy_hp_bar", Vector2(29, 597), false)
	_player_hp_trail = _hp_trail("player_hp_bar", Vector2(1050, 597), true)
	_enemy_fill = _hp_fill("enemy_hp_bar", Vector2(29, 597), false)
	_player_fill = _hp_fill("player_hp_bar", Vector2(1050, 597), true)
	_enemy_damage_preview = BattleArt.picture(self, "enemy_hp_bar", Vector2(29, 597))
	_enemy_damage_preview.name = "EnemyDamagePreview"
	var preview_texture := AtlasTexture.new()
	preview_texture.atlas = _enemy_damage_preview.texture
	_enemy_damage_preview.texture = preview_texture
	_enemy_damage_preview.hide()
	_enemy_hp_damage = BattleHpDamageEffect.new()
	_enemy_hp_damage.name = "EnemyHpDamage"
	add_child(_enemy_hp_damage)
	_player_hp_damage = BattleHpDamageEffect.new()
	_player_hp_damage.name = "PlayerHpDamage"
	add_child(_player_hp_damage)
	_enemy_shield = _shield_bar("EnemyShield", Vector2(29, 597), false)
	_player_shield = _shield_bar("PlayerShield", Vector2(1050, 597), true)
	var round_ground := OriginalFlatPlayer.new()
	round_ground.hidden_libraries = ["ＡＰ下地.png"]
	round_ground.animation_path = "res://assets/battle/native/ap_ground/animation.json"
	add_child(round_ground)
	_enemy_number = BattleHpReadout.make_readout(self, Vector2(30, 550), Vector2(740, 44), HORIZONTAL_ALIGNMENT_LEFT)
	_player_number = BattleHpReadout.make_readout(self, Vector2(1150, 550), Vector2(740, 44), HORIZONTAL_ALIGNMENT_RIGHT)
	_player_number.ratio_first = true
	var enemy_name := BattleArt.label(self, battle.monster.name, Vector2(20, 507), Vector2(500, 26), 22)
	enemy_name.name = "EnemyName"
	enemy_name.add_theme_constant_override("outline_size", 3)
	BattleArt.picture(self, "hp_caption", Vector2(20, 532))
	var player_name := BattleArt.label(self, "联合部队", Vector2(1490, 507), Vector2(410, 26), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	player_name.name = "PlayerName"
	player_name.add_theme_constant_override("outline_size", 3)
	BattleArt.picture(self, "hp_caption", Vector2(1867, 532))
	# Native yellow-gradient digits match the original Round / VS ornament.
	_round = BattleArt.number(self, "round_gold", Vector2(905, 553), Vector2(110, 43), HORIZONTAL_ALIGNMENT_CENTER)
	_round.name = "CurrentRound"
	_round.kerning = -4
	_ap = BattleApBar.new()
	_ap.name = "AP"
	add_child(_ap)
	_intents = _group("Intents")
	_combo = _group("Combo")
	_cards = _group("Leaders")
	_leader_power_layer = BattleLeaderPowerLayer.new()
	_leader_power_layer.name = "LeaderPowers"
	add_child(_leader_power_layer)
	_swap = BattleArt.button(self, "swap", Vector2(20, 752), Vector2(160, 105), _open_formation)
	_swap_count = Control.new()
	_swap_count.name = "SwapCooldown"
	_swap_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swap.content.add_child(_swap_count)
	_swap_number = BattleArt.number(_swap_count, "swap_digits", Vector2(34, 62), Vector2(30, 30))
	_speed_button = OriginalUiButton.make(self, "square", Vector2(20, 884), Vector2(80, 80), _cycle_speed)
	_mode_button = OriginalUiButton.make(self, "square", Vector2(103, 884), Vector2(80, 80), _cycle_mode)
	_speed_button.art.scale = Vector2.ONE * (80.0 / 86.0)
	_mode_button.art.scale = Vector2.ONE * (80.0 / 86.0)
	_end = BattleArt.button(self, "end_turn", Vector2(1744, 990), Vector2(158, 78), _end_turn)
	BattleArt.label(_end.content, "结束该轮", Vector2(7, 12), Vector2(144, 48), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	BattleArt.picture(self, "log_background", Vector2(287, 1046))
	_log = BattleArt.label(self, "", Vector2(324, 1048), Vector2(1140, 30), 21)
	BattleArt.button(self, "log_closed", Vector2(1481, 1049), Vector2(150, 31), _show_logs)
	var analysis := OriginalUiButton.make(self, "square", Vector2(1708, 18), Vector2(92, 92), _show_analysis)
	_analysis_button = analysis
	analysis.art.scale = Vector2.ONE * (92.0 / 86.0)
	_option_icon(analysis, "help_icon", "解析")
	_restart_button = OriginalUiButton.make(self, "square", Vector2(1812, 18), Vector2(92, 92), _restart_battle)
	_restart_button.art.scale = analysis.art.scale
	_option_icon(_restart_button, "restart_icon", "重开")
	_build_preparation()
	# MENU stays above the preparation shade and warning artwork in every phase.
	var menu := OriginalUiButton.make(self, "square", Vector2(20, 990), Vector2(160, 80), func() -> void: get_node("/root/Settings").open())
	menu.name = "Menu"
	menu.art.scale = Vector2(160.0 / 86.0, 1.0)
	BattleArt.label(menu.content, "ＭＥＮＵ", Vector2(5, 15), Vector2(150, 50), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

func _group(title: String) -> Control:
	var node := Control.new()
	node.name = title
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func _hp_fill(asset: String, at: Vector2, reverse: bool) -> TextureRect:
	var fill := BattleArt.picture(self, asset, at)
	fill.flip_h = reverse
	fill.set_meta("reverse", reverse)
	fill.set_meta("origin", at)
	return fill

func _shield_bar(node_name: String, at: Vector2, reverse: bool) -> BattleShieldBar:
	var bar := BattleShieldBar.new()
	bar.name = node_name
	bar.position = at
	bar.reverse = reverse
	bar.view = self
	add_child(bar)
	battle.shield_event.connect(bar.on_shield_event)
	return bar

func _hp_trail(asset: String, at: Vector2, reverse: bool) -> TextureRect:
	var trail := _hp_fill(asset, at, reverse)
	trail.name = "PlayerHpTrail" if reverse else "EnemyHpTrail"
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/hp_trail.gdshader")
	if not reverse:
		material.set_shader_parameter("dark_color", Vector3(0.14, 0.08, 0.09))
		material.set_shader_parameter("light_color", Vector3(0.39, 0.27, 0.28))
	trail.material = material
	return trail

func _set_hp_with_trail(fill: TextureRect, trail: TextureRect, current: float, maximum: float) -> void:
	_set_hp(fill, current, maximum)
	var ratio := clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	var previous: float = trail.get_meta("hp_target", -1.0)
	if is_equal_approx(previous, ratio): return
	var tween: Tween = trail.get_meta("hp_tween") if trail.has_meta("hp_tween") else null
	if tween != null and tween.is_valid(): tween.kill()
	trail.set_meta("hp_target", ratio)
	# Initialization and healing snap both layers; damage leaves a dark trailing strip.
	if previous < 0.0 or ratio >= previous or battle.phase == "preparation":
		var damage := _player_hp_damage if fill == _player_fill else _enemy_hp_damage
		damage.stop()
		_set_hp_trail_ratio(ratio, trail)
		return
	var displayed: float = trail.get_meta("hp_ratio", previous)
	var damage := _player_hp_damage if fill == _player_fill else _enemy_hp_damage
	damage.play(fill, previous, ratio)
	# A new hit continues from the visible strip instead of jumping back to full HP.
	tween = trail.create_tween()
	trail.set_meta("hp_tween", tween)
	tween.tween_interval(HP_TRAIL_HOLD)
	tween.tween_method(_set_hp_trail_ratio.bind(trail), displayed, ratio, HP_TRAIL_CATCH_UP).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_hp_trail_ratio(ratio: float, trail: TextureRect) -> void:
	trail.set_meta("hp_ratio", ratio)
	_set_hp(trail, ratio, 1.0)
	if battle.information_hidden("enemy" if trail == _enemy_hp_trail else "player"): trail.hide()

func _set_hp(fill: TextureRect, current: float, maximum: float) -> void:
	var texture := fill.texture as AtlasTexture
	if texture == null:
		texture = AtlasTexture.new()
		texture.atlas = fill.texture
		fill.texture = texture
	var ratio := clampf(current / maxf(maximum, 1.0), 0, 1)
	var full := texture.atlas.get_size()
	texture.region = Rect2(0, 0, full.x * maxf(0.00001, ratio), full.y)
	fill.size = texture.region.size
	fill.visible = ratio > 0
	# Keep the native slope/orientation; crop from the side nearest the center.
	fill.flip_h = false
	if fill.get_meta("reverse"):
		texture.region.position.x = full.x * (1.0 - ratio)
		fill.position.x = Vector2(fill.get_meta("origin")).x + full.x * (1.0 - ratio)

func _build_preparation() -> void:
	_prep = _group("Preparation")
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.25)
	shade.size = Vector2(1920, 1080)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prep.add_child(shade)
	var stripes := OriginalFlatPlayer.new()
	# The native placeholder is replaced by the live stage, dimmed above.
	stripes.hidden_libraries = ["Ｇ／画面模糊化.png"]
	stripes.animation_path = "res://assets/battle/native/preparation_warning/animation.json"
	_prep.add_child(stripes)
	for i: int in stripes._root.nodes:
		if stripes._root.tracks[i].library == "Ｃ／部队名":
			var name_label := BattleArt.label(stripes._root.nodes[i], battle.monster.name, Vector2(-280, -38), Vector2(560, 76), 52, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)
			name_label.name = "PreparationMonsterName"
			name_label.add_theme_font_override("font", load("res://assets/fonts/card_text.ttf"))
			name_label.add_theme_constant_override("outline_size", 1)
	_start = BattleArt.button(_prep, "start", Vector2(823, 413), Vector2(274, 274), _start_battle)
	BattleArt.label(_start.content, "战斗开始", Vector2(36, 102), Vector2(202, 64), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_formation_button = OriginalUiButton.make(_prep, "square", Vector2(1744, 990), Vector2(158, 80), _open_formation)
	_formation_button.art.scale = Vector2(158.0 / 86.0, 1)
	BattleArt.label(_formation_button.content, "部队编制", Vector2(5, 12), Vector2(148, 50), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	BattleArt.label(_prep, "战斗结果", Vector2(1390, 330), Vector2(470, 50), 30, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	BattleArt.label(_prep, "胜利          前进\n败北          GAMEOVER\n超过时间（99 Round） GAMEOVER", Vector2(1370, 390), Vector2(500, 150), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)

func _refresh() -> void:
	_enemy_number.text = str(int(ceil(battle.enemy_hp)))
	_player_number.text = str(int(ceil(battle.player_hp)))
	_enemy_number.ratio_text = "(%d%%)" % roundi(battle.enemy_hp / maxf(1, battle.enemy_max_hp) * 100)
	_player_number.ratio_text = "(%d%%)" % roundi(battle.player_hp / maxf(1, battle.player_max_hp) * 100)
	_set_hp_with_trail(_enemy_fill, _enemy_hp_trail, battle.enemy_hp, battle.enemy_max_hp)
	_set_hp_with_trail(_player_fill, _player_hp_trail, battle.player_hp, battle.player_max_hp)
	_enemy_shield.sync(BattleShields.percent(battle, "enemy"))
	_player_shield.sync(BattleShields.percent(battle, "player"))
	for bar: BattleStatusBar in _status_bars: bar.sync()
	for bar: BattleSupportBar in _support_bars: bar.sync()
	_refresh_hp_visibility()
	_round.text = str(battle.round)
	_swap.disabled = input_locked or not battle.can_swap()
	_swap_count.visible = not battle.can_swap() and battle.phase != "preparation"
	_swap_number.text = str(battle.swap_remaining())
	_swap.refresh_art()
	_end.disabled = input_locked or battle.phase != "player"
	_end.refresh_art()
	_prep.visible = battle.phase == "preparation"
	_start.disabled = battle.player_max_hp <= 0
	_start.refresh_art()
	_restart_button.disabled = input_locked
	_restart_button.refresh_art()
	_refresh_cards()
	_refresh_ap()
	if not _playing_enemy_intents:
		_refresh_intents()
	if battle.combo != _combo_shown:
		_combo_shown = battle.combo
		BattleArt.clear(_combo)
		if battle.combo > 0:
			BattleArt.flat(_combo, "combo_%d" % battle.combo, Vector2(1132, 510))
			_sparkle()
	_refresh_options()
	_apply_speed(self)
	_refresh_analysis_forecast()
	if battle.phase == "result" and not input_locked and not is_instance_valid(_result):
		if battle.outcome == "胜利":
			_show_combat_end()
		else:
			_result = _popup_frame(Vector2(655, 300), Vector2(610, 340))
			BattleArt.label(_result, battle.outcome, Vector2(30, 30), Vector2(550, 100), 56, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
			BattleArt.text_button(_result, "返回", Vector2(205, 235), Vector2(200, 65), func() -> void: close_requested.emit())

func _show_combat_end() -> void:
	input_locked = true
	_close_popup()
	_clear_skill_preview()
	_result = Control.new()
	_result.name = "CombatEnd"
	_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result.add_to_group("modal_overlay")
	add_child(_result)
	var end := TreasureArt.flat(_result, "combat_end")
	end.playback_speed = 3.0
	# Original WinLoseView finishes this native animation before leaving combat.
	while not end.is_root_finished():
		await get_tree().process_frame
	# Shared transition changes the page only after a completely black frame.
	var transition := get_node("/root/ScreenTransition")
	while transition.busy: await get_tree().process_frame
	await transition.play(_mount_victory_loot)
	input_locked = false

func _mount_victory_loot() -> void:
	_result.remove_from_group("modal_overlay")
	_result.hide()
	_result.queue_free()
	var loot := VictoryLootScreen.new()
	loot.troop = battle.troop
	loot.pool_id = reward_pool
	loot.rng = get_node("/root/RunAutosave").rng
	loot.completed.connect(func() -> void: close_requested.emit())
	_result = loot
	add_child(loot)

func _refresh_intents() -> void:
	BattleArt.clear(_intents)
	_intent_buttons.clear()
	if battle.phase == "result": return
	var ids: Array = battle.intent.get("skills", [])
	var scroll := ScrollContainer.new()
	var content_width := maxf(0, ids.size() * INTENT_STEP + 2)
	var row_width := minf(INTENT_RIGHT - INTENT_LEFT, content_width)
	scroll.position = Vector2(INTENT_RIGHT - row_width, INTENT_BASELINE - INTENT_ROW_HEIGHT)
	scroll.size = Vector2(row_width, INTENT_ROW_HEIGHT)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_intents.add_child(scroll)
	# Explicit positions allow the pending icons to glide without container relayout.
	var row := Control.new()
	row.custom_minimum_size = Vector2(content_width, INTENT_ROW_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(row)
	for index: int in range(ids.size()):
		var id: int = ids[index]
		var skill: Dictionary = battle.troop.catalog.skills[id]
		var ultimate := int(skill.get("ultimate", 0)) == 1
		var icon_height := 73.0 if ultimate else 56.0
		var button := Button.new()
		button.position = Vector2((ids.size() - 1 - index) * INTENT_STEP, INTENT_ROW_HEIGHT - icon_height)
		button.size = Vector2(62, icon_height)
		button.set_meta("skill_id", id)
		button.set_meta("ultimate", ultimate)
		for button_state: String in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(button_state, StyleBoxEmpty.new())
		button.pressed.connect(_show_intent.bind(id))
		row.add_child(button)
		_intent_buttons.append(button)
		get_node("/root/UIAudio").bind_button(button)
		var icon := BattleArt.picture(button, ("intent_ultimate_%d" if ultimate else "intent_%d") % skill.type, Vector2.ZERO)
		icon.name = "SkillTypeIcon"
		if ultimate:
			var marker := BattleArt.flat(icon, "intent_ultimate")
			marker.name = "UltimateWarning"
		if index == battle.blocked_enemy_action:
			var blocked := BattleArt.picture(button, "status/blocked_small", Vector2(0, icon_height - 56))
			blocked.name = "BlockedAction"
		button.mouse_entered.connect(func() -> void: icon.self_modulate = Color(1.45, 1.45, 1.25))
		button.mouse_exited.connect(func() -> void: icon.self_modulate = Color.WHITE)
	# The first action is at the right edge, including queues wider than the band.
	scroll.set_deferred("scroll_horizontal", maxi(0, int(content_width - row_width)))

func _refresh_cards() -> void:
	_clear_skill_preview()
	BattleArt.clear(_cards)
	for i: int in range(battle.troop.leaders.size()):
		var name: String = battle.troop.leaders[i]
		# Keep the old DOWN view through the round title, until its entrance starts.
		for replacement: Dictionary in battle.pending_down_replacements:
			if int(replacement.slot) == i: name = replacement.previous
		if name.is_empty():
			if not battle.troop.is_slot_unlocked(i):
				FormationArt.picture(_cards, "locked", Vector2(200 + 218 * i, 730), Vector2(208, 312))
			else:
				BattleArt.picture(_cards, "card_frame", Vector2(198 + 218 * i, 728))
			continue
		var card := BattleCard.new()
		card.configure(battle, name, operation_mode, selected_card == name, input_locked)
		card.position = Vector2(200 + 218 * i, 730)
		card.skill_requested.connect(_use_skill)
		card.card_selected.connect(_select_card)
		card.skill_hovered.connect(_preview_skill_ap)
		_cards.add_child(card)
		card.set_hovered(name == _hovered_card)
		card.visible = name != lifted_actor
	if not lifted_actor.is_empty():
		var slot := battle.troop.leaders.find(lifted_actor)
		if slot >= 0:
			BattleArt.picture(_cards, "card_frame", Vector2(198 + 218 * slot, 728))
	_leader_power_layer.lifted = lifted_actor
	_leader_power_layer.sync(battle, operation_mode, selected_card, animation_speed())

func set_lifted_actor(actor: String) -> void:
	lifted_actor = actor
	_refresh_cards()

func _refresh_ap() -> void:
	_ap.set_state(battle.ap_max(), battle.ap if _ap_override < 0 else _ap_override, animation_speed())

func _preview_skill_ap(actor: String, id: int, slot: int, entered: bool) -> void:
	var key := "%s:%d:%d" % [actor, id, slot]
	if not entered:
		if _ap_hover_key == key:
			_clear_skill_preview()
		return
	_clear_skill_preview()
	if input_locked or is_instance_valid(popup) or is_instance_valid(formation) or get_tree().get_first_node_in_group("modal_overlay") != null or get_node("/root/ScreenTransition").busy or not battle.can_use(actor, id, slot): return
	_ap_hover_key = key
	_ap.set_preview(battle.runtime.ap_cost(actor, battle.troop.catalog.skills[id], slot))
	if _enemy_hp_trail_animating() or _enemy_shield.is_animating():
		_pending_damage_preview = {"actor": actor, "id": id, "slot": slot}
		return
	_show_damage_preview(actor, id, slot)

func _enemy_hp_trail_animating() -> bool:
	var tween: Tween = _enemy_hp_trail.get_meta("hp_tween") if _enemy_hp_trail.has_meta("hp_tween") else null
	return tween != null and tween.is_valid() and tween.is_running()

func _show_damage_preview(actor: String, id: int, slot: int) -> void:
	if battle.information_hidden("enemy"): return
	# Calculate from live HP only after the delayed gauge has completely settled.
	var forecast := BattleForecast.action(battle, actor, id, false, slot)
	if not forecast.ok: return
	_damage_preview_clock = 0.0
	if forecast.shield_loss > 0.0:
		if forecast.remaining_shield > 0.0:
			_enemy_shield.set_preview(true)
			return
		_enemy_shield.set_preview(false, true)
	if forecast.hp_loss <= 0.0: return
	var maximum := maxf(1.0, battle.enemy_max_hp)
	var after := clampf(float(forecast.remaining_hp) / maximum, 0.0, 1.0)
	_enemy_damage_preview.set_meta("remaining_ratio", after)
	_enemy_damage_preview.modulate = Color(0.0, 0.0, 0.0, 0.62)
	_enemy_damage_preview.show()
	_update_damage_preview_region()
	_damage_preview_clock = 0.0
	_enemy_number.preview_ratio = "(%d%%)" % roundi(after * 100.0)
	_enemy_number.preview_alpha = 1.0

func _update_damage_preview_region() -> void:
	var texture := _enemy_damage_preview.texture as AtlasTexture
	var full := texture.atlas.get_size()
	var after: float = _enemy_damage_preview.get_meta("remaining_ratio")
	var current := clampf(battle.enemy_hp / maxf(1.0, battle.enemy_max_hp), 0.0, 1.0)
	texture.region = Rect2(full.x * after, 0, full.x * maxf(0.00001, current - after), full.y)
	_enemy_damage_preview.position = Vector2(29 + full.x * after, 597)
	_enemy_damage_preview.size = texture.region.size

func _clear_skill_preview() -> void:
	_ap_hover_key = ""
	_pending_damage_preview = {}
	if is_instance_valid(_ap): _ap.set_preview(0)
	if is_instance_valid(_enemy_damage_preview): _enemy_damage_preview.hide()
	if is_instance_valid(_enemy_shield):
		_enemy_shield.set_preview(false)
		_enemy_shield.set_information_hidden(battle.information_hidden("enemy"))
	if is_instance_valid(_enemy_number):
		_enemy_number.preview_ratio = ""
		_enemy_number.preview_alpha = 1.0

func show_ap_payment(actor: String, skill: Dictionary, slot: int) -> void:
	_ap_override = maxi(0, battle.ap - battle.runtime.ap_cost(actor, skill, slot))
	_refresh_ap()

func finish_ap_payment() -> void:
	_ap_override = -1
	_refresh_ap()

func _hover_card(at: Vector2) -> void:
	var hovered := ""
	for i: int in range(battle.troop.leaders.size()):
		# Adjacent cards share the small gutter so crossing it stays continuous.
		if Rect2(195 + 218 * i, 730, 218, 312).has_point(at):
			hovered = battle.troop.leaders[i]
			break
	_hovered_card = hovered
	if _browse_cards and selected_card != hovered:
		selected_card = hovered
		if hovered.is_empty(): _browse_cards = false
		_refresh_cards()
	for child: Node in _cards.get_children():
		if child is BattleCard: child.set_hovered(child.card.name == hovered)

func _refresh_options() -> void:
	_option_icon(_speed_button, "speed%d" % speed, "速度·%d倍" % speed)
	_option_icon(_mode_button, "mode%d" % (operation_mode + 1), "操作模式")

func _option_icon(button: OriginalUiButton, asset: String, caption: String) -> void:
	BattleArt.clear(button.content)
	# Retain the original icon, replacing only its baked Japanese caption.
	var icon := BattleArt.picture(button.content, asset, Vector2((button.size.x - 64) / 2, 9))
	var region := AtlasTexture.new()
	region.atlas = icon.texture
	region.region = Rect2(0, 0, 64, 45)
	icon.texture = region
	icon.size = region.region.size
	var label := BattleArt.label(button.content, caption, Vector2(4, button.size.y - 29), Vector2(button.size.x - 8, 22), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_constant_override("outline_size", 2)

func animation_speed() -> float:
	return float(speed) * (4.0 / 3.0)

func ap_position(index: int) -> Vector2:
	var texture := load("res://assets/battle/ap%d.png" % battle.ap_max()) as Texture2D
	return Vector2((1920.0 - texture.get_width()) / 2.0 + 74 + index * 53, 658)

func _apply_speed(node: Node) -> void:
	if node == _result or node is VictoryLootScreen: return
	if node is BattleApBar:
		node.playback_speed = animation_speed()
	if node is OriginalFlatPlayer:
		node.playback_speed = animation_speed() * float(node.get_meta("animation_rate", 1.0))
	if node is CPUParticles2D:
		node.speed_scale = animation_speed()
	for child: Node in node.get_children():
		_apply_speed(child)
	if _breath != null:
		_breath.set_speed_scale(animation_speed())

func _cycle_speed() -> void:
	speed = speed % 3 + 1
	get_node("/root/Settings").set_battle_speed(speed)
	_refresh_options()
	_apply_speed(self)

func _cycle_mode() -> void:
	if input_locked: return
	operation_mode = 1 - operation_mode
	selected_card = ""
	_browse_cards = false
	_hovered_card = ""
	_refresh()

func _select_card(name: String) -> void:
	if not input_locked and operation_mode == 1:
		selected_card = "" if selected_card == name else name
		_browse_cards = not selected_card.is_empty()
		_hovered_card = name
		_refresh_cards()

func _start_battle() -> void:
	if input_locked or get_node("/root/ScreenTransition").busy: return
	input_locked = true
	if battle.start():
		await _presentation.round_start(false)
		await _presentation.automatic_actions()
	input_locked = false
	_refresh()

func _use_skill(name: String, id: int, slot: int = -1) -> void:
	if input_locked or is_instance_valid(popup) or not battle.can_use(name, id, slot):
		return
	input_locked = true
	_browse_cards = false
	selected_card = ""
	_close_popup()
	_refresh()
	await _presentation.action(name, id, false, slot)
	await _presentation.status_feedback()
	if not is_inside_tree(): return
	input_locked = false
	_refresh()

func _wait_animation(seconds: float) -> void:
	var elapsed := 0.0
	# Exact frame multiples must not acquire an extra frame from float rounding.
	while elapsed + 0.00001 < seconds and is_inside_tree():
		await get_tree().process_frame
		elapsed += get_process_delta_time() * animation_speed()

func _end_turn() -> void:
	if input_locked or battle.phase != "player":
		return
	input_locked = true
	battle.begin_enemy_turn()
	await _presentation.status_feedback()
	selected_card = ""
	_browse_cards = false
	_close_popup()
	_refresh()
	_playing_enemy_intents = true
	_presentation.native("enemy_turn", Vector2.ZERO, BattlePresentation.ENEMY_TEMPO)
	await _wait_animation(0.8 / BattlePresentation.ENEMY_TEMPO)
	await _presentation.support_actions("enemy")
	var ids: Array = battle.intent.get("skills", []).duplicate()
	for id: int in ids:
		if battle.phase != "enemy": break
		await _presentation.consume_enemy_intent()
		await _presentation.action(battle.monster.identity, id, true)
		await _presentation.status_feedback()
		if not is_inside_tree(): return
	_playing_enemy_intents = false
	battle.finish_enemy_turn()
	await _presentation.status_feedback()
	if battle.phase == "player":
		await _presentation.round_start(true)
		await _presentation.automatic_actions()
	input_locked = false
	_refresh()

func _open_formation() -> void:
	if input_locked or not battle.can_swap() or is_instance_valid(formation) or get_node("/root/ScreenTransition").busy:
		return
	_close_popup()
	_clear_skill_preview()
	await get_node("/root/ScreenTransition").play(_mount_formation)

func _mount_formation() -> void:
	_previous_leaders = battle.troop.leaders.duplicate()
	battle.troop.begin_battle_formation_edit()
	formation = (load("res://scenes/troop_formation.tscn") as PackedScene).instantiate() as TroopFormation
	formation.configure(battle.troop)
	formation.close_requested.connect(_close_formation)
	add_child(formation)

func _close_formation() -> void:
	if not is_instance_valid(formation) or get_node("/root/ScreenTransition").busy: return
	await get_node("/root/ScreenTransition").play(_return_from_formation)

func _return_from_formation() -> void:
	battle.troop.finish_battle_formation_edit()
	remove_child(formation)
	formation.queue_free()
	formation = null
	battle.sync_formation(_previous_leaders)
	if battle.phase != "preparation":
		battle._check_result()
		_refresh()

func _popup_frame(at: Vector2, dimensions: Vector2) -> Control:
	_clear_skill_preview()
	_close_popup()
	popup = Panel.new()
	popup.position = at
	popup.size = dimensions
	(popup as Panel).add_theme_stylebox_override("panel", BattleArt.panel_style())
	add_child(popup)
	return popup

func _close_popup() -> void:
	if is_instance_valid(popup):
		popup.hide()
		popup.queue_free()
	popup = null

func _show_intent(id: int) -> void:
	if input_locked or is_instance_valid(formation): return
	var skill: Dictionary = battle.troop.catalog.skills[id]
	_show_description("IntentDescription", skill.name, skill.description, Vector2(600, 320))

func _show_description(title: String, heading: String, description: String, at: Vector2) -> void:
	_clear_skill_preview()
	_close_popup()
	popup = Control.new()
	popup.name = title
	popup.size = Vector2(1920, 1080)
	popup.set_meta("dismiss_on_click", true)
	add_child(popup)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0, 0, 0, 0.48)
	shade.size = popup.size
	popup.add_child(shade)
	var frame := BattleArt.picture(popup, "intent_description", at, Vector2(400, 160))
	frame.name = "DescriptionFrame"
	var header := BattleArt.label(frame, heading, Vector2(32, 18), Vector2(336, 38), 23, FormationArt.GOLD)
	header.name = "Heading"
	var text := BattleArt.label(frame, description, Vector2(32, 61), Vector2(336, 80), 19)
	text.name = "Description"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _show_analysis() -> void:
	if is_instance_valid(formation): return
	if is_instance_valid(analysis_panel):
		analysis_panel.hide()
		analysis_panel.queue_free()
		analysis_panel = null
		_analysis_button.selected = false
		return
	var frame := BattleArt.picture(self, "monster_description", Vector2(1110, 120))
	frame.size.y = maxf(frame.size.y, 420.0)
	frame.name = "AnalysisPanel"
	analysis_panel = frame
	_analysis_button.selected = true
	var background := ShaderMaterial.new()
	background.shader = preload("res://shaders/analysis_panel.gdshader")
	frame.material = background
	var monster: Dictionary = battle.monster
	_analysis_text(frame, "MonsterName", monster.name, Vector2(26, 20), Vector2(340, 34), 25, Color("fff479"), 4)
	_analysis_text(frame, "MonsterKind", ["普通怪", "精英怪", "BOSS"][monster.kind - 1], Vector2(26, 62), Vector2(340, 32), 23, Color("fff479"), 4)
	_analysis_text(frame, "Stats", "基础 AT\n物理抗性\n魔法抗性", Vector2(26, 116), Vector2(140, 96), 21)
	_analysis_text(frame, "Values", "%d\n%d%%\n%d%%" % [monster.base_at, monster.physical_resist, monster.magic_resist], Vector2(170, 116), Vector2(194, 96), 21)
	var description := _analysis_text(frame, "Description", monster.analysis, Vector2(26, 246), Vector2(340, 114), 19)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_analysis_text(frame, "RoundDamageForecast", "", Vector2(26, 366), Vector2(340, 34), 19)
	_refresh_analysis_forecast()

func _refresh_analysis_forecast() -> void:
	if not is_instance_valid(analysis_panel): return
	var label := analysis_panel.get_node_or_null("RoundDamageForecast") as Label
	if label != null:
		var forecast := BattleForecast.enemy_round(battle)
		label.text = "本轮预计伤害：???" if battle.information_hidden("player") else "本轮预计伤害：%.1f%%" % float(forecast.percent)

func _refresh_hp_visibility() -> void:
	for side: String in ["enemy", "player"]:
		var hidden := battle.information_hidden(side)
		var number := _enemy_number if side == "enemy" else _player_number
		var fill := _enemy_fill if side == "enemy" else _player_fill
		var trail := _enemy_hp_trail if side == "enemy" else _player_hp_trail
		var effect := _enemy_hp_damage if side == "enemy" else _player_hp_damage
		number.visible = not hidden
		fill.visible = not hidden and (battle.enemy_hp if side == "enemy" else battle.player_hp) > 0.0
		trail.visible = not hidden and float(trail.get_meta("hp_ratio", 0.0)) > 0.0
		if hidden: effect.hide()
		var shield := _enemy_shield if side == "enemy" else _player_shield
		shield.set_information_hidden(hidden)
		_hidden_hp_labels[side].visible = hidden

func _show_status_detail(side: String, id: int) -> void:
	if input_locked or is_instance_valid(formation) or battle.phase == "result" or not battle.has_status(side, id): return
	var bar: BattleStatusBar = _status_bars[0 if side == "enemy" else 1]
	var icon: Control = bar.entries[id]
	# Anchor the original compact description just above the selected status icon.
	var at := Vector2(clampf(icon.position.x - 120, 12, 1508), icon.position.y - 174)
	_show_description("StatusDescription", BattleStatusEffects.effect_name(id), BattleStatusEffects.description(id), at)

func _show_support_detail(side: String, uid: int) -> void:
	if battle.information_hidden(side) or is_instance_valid(formation): return
	for i: int in range(BattleSupports.group(battle, side).size()):
		var entry: Dictionary = BattleSupports.group(battle, side)[i]
		if int(entry.uid) != uid: continue
		var support := BattleSupports.definition(battle, entry)
		var text: String = support.description
		if text.is_empty(): text = troop_skill_description(support.skill)
		var bar := _support_bars[1 if side == "player" else 0]
		var y := clampf(bar.support_position(i).y, 15, 860)
		_show_description("SupportDescription", support.name, text, Vector2(1275 if side == "player" else 235, y))
		return

func troop_skill_description(id: int) -> String:
	return String(battle.troop.catalog.skills.get(id, {}).get("description", ""))

func _analysis_text(parent: Control, title: String, text: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color = Color.WHITE, outline: int = 1) -> Label:
	var label := BattleArt.label(parent, text, at, dimensions, font_size, color)
	label.name = title
	label.add_theme_font_override("font", load("res://assets/fonts/card_text.ttf"))
	label.add_theme_constant_override("outline_size", outline)
	return label

func _show_logs() -> void:
	if input_locked or is_instance_valid(formation): return
	_clear_skill_preview()
	_close_popup()
	var panel := BattleLogPanel.new()
	panel.messages = battle.logs.duplicate()
	panel.close_requested.connect(_close_popup)
	popup = panel
	add_child(panel)

func _sparkle() -> void:
	var particles := CPUParticles2D.new()
	particles.position = Vector2(1190, 570)
	particles.amount = 20
	particles.one_shot = true
	particles.lifetime = 0.55
	particles.explosiveness = 1.0
	particles.spread = 180
	particles.initial_velocity_min = 40
	particles.initial_velocity_max = 150
	particles.gravity = Vector2.ZERO
	particles.color = Color(1, 0.85, 0.3)
	var native: OriginalFlatPlayer = _combo.get_child(0)
	var sparkle_texture: String = native._data.textures.get("Ｇ／光.png", "")
	if not sparkle_texture.is_empty():
		particles.texture = load(sparkle_texture)
		var blend := CanvasItemMaterial.new()
		blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		particles.material = blend
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.22
	particles.finished.connect(particles.queue_free)
	_combo.add_child(particles)
	particles.emitting = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_pointer_position = get_global_transform().affine_inverse() * event.position
		_pointer_known = true
	if get_tree().get_first_node_in_group("modal_overlay") != null or is_instance_valid(formation):
		return
	if event is InputEventMouseMotion and operation_mode == 1 and not input_locked and not is_instance_valid(popup) and battle.phase == "player":
		_hover_card(get_global_transform().affine_inverse() * event.position)
	if is_instance_valid(popup) and popup.get_meta("dismiss_on_click", false):
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			get_viewport().set_input_as_handled()
			_close_popup()
			return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(popup) and popup != _result:
			_close_popup()
		elif _browse_cards:
			_browse_cards = false
			selected_card = ""
			_refresh_cards()
