extends Node
class_name BattlePresentation
const CARD_MOVE_TIME := 0.16
const ENEMY_TEMPO := 1.15
## All multi-hit actions share the reference cadence: 0.30s at speed 3,
## 0.45s at speed 2 and 0.90s at speed 1 (battle clock runs at speed * 4/3).
const MULTI_HIT_INTERVAL := 1.2
const MULTI_HIT_RECOVERY := 0.15
const MULTI_HIT_NUMBER_TIME := 0.8
## Action presentation owns timing; BattleState still owns all combat arithmetic.
var view: BattleScene
var layer: Control
var _transients: Array[OriginalFlatPlayer] = []
var _tweens: Array[Tween] = []
var _voices: Array[AudioStreamPlayer] = []
var _cut_in_players: Array[AnimationPlayer] = []

func _process(_delta: float) -> void:
	for effect: OriginalFlatPlayer in _transients.duplicate():
		if not is_instance_valid(effect):
			_transients.erase(effect)
		elif effect.is_root_finished() or effect.elapsed >= float(effect.get_meta("lifetime", INF)):
			_transients.erase(effect)
			effect.queue_free()
	for tween: Tween in _tweens.duplicate():
		if not tween.is_valid():
			_tweens.erase(tween)
		else:
			tween.set_speed_scale(view.animation_speed() * float(tween.get_meta("animation_rate", 1.0)))
	for player: AnimationPlayer in _cut_in_players.duplicate():
		if not is_instance_valid(player):
			_cut_in_players.erase(player)
		else:
			player.speed_scale = 1.0

func native(asset: String, at: Vector2 = Vector2.ZERO, rate: float = 1.0) -> OriginalFlatPlayer:
	return _native_path("res://assets/battle/native/%s/animation.json" % asset, at, rate)

func _native_path(path: String, at: Vector2, rate: float = 1.0) -> OriginalFlatPlayer:
	var effect := OriginalFlatPlayer.new()
	effect.project_tilt = true
	effect.animation_path = path
	effect.position = at
	effect.set_meta("animation_rate", rate)
	effect.playback_speed = view.animation_speed() * rate
	layer.add_child(effect)
	_transients.append(effect)
	return effect

func _tween(rate: float = 1.0) -> Tween:
	var tween := create_tween().set_speed_scale(view.animation_speed() * rate)
	tween.set_meta("animation_rate", rate)
	_tweens.append(tween)
	return tween

static func effect_for(skill: Dictionary, element: int = 0) -> Dictionary:
	return SkillEffectCatalog.resolve(skill, element)

func _play_cut_in(skill: Dictionary, acting_card: CardWidget = null) -> void:
	var cut_in := SkillCutInCatalog.instantiate(str(skill.get("cut_in", "")))
	if cut_in == null: return
	if cut_in is CutInCardBurst:
		cut_in.configure_source(acting_card)
	var player := cut_in.get_node("AnimationPlayer") as AnimationPlayer
	# Cut-ins have a fixed presentation tempo, independent of all combat speed rates.
	player.speed_scale = 1.0
	cut_in.z_index = 100
	layer.add_child(cut_in)
	cut_in.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cut_in_players.append(player)
	player.play(SkillCutInCatalog.ANIMATION)
	await player.animation_finished
	_cut_in_players.erase(player)
	if is_instance_valid(cut_in):
		cut_in.hide()
		# Kenshin's short background can hand off an independently owned voice tail.
		# Other cut-ins retain their existing wait for the complete voice.
		if cut_in.has_method("release_voice_tail"):
			cut_in.call("release_voice_tail")
		# Preserve a short audio tail if the visual wipe finishes between mix frames.
		elif cut_in is CutInCardBurst and cut_in.voice_player.playing:
			await cut_in.voice_player.finished
		cut_in.queue_free()

func _sound(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path): return
	var voice := AudioStreamPlayer.new()
	voice.stream = load(path)
	voice.bus = &"SFX"
	add_child(voice)
	_voices.append(voice)
	voice.finished.connect(func() -> void:
		_voices.erase(voice)
		voice.queue_free())
	voice.play()

func _impact_time(effect: OriginalFlatPlayer) -> float:
	if effect._data.has("impact_time"): return float(effect._data.impact_time)
	for track: Dictionary in effect._data.timelines:
		for event: Dictionary in track.get("script", []):
			for op: Array in event.ops:
				if op.size() > 1 and op[0] == "text" and op[1] == "伤害":
					return float(event.frame) / effect.fps
	return float(effect._root.end_frame) / effect.fps * 0.8

func _card_lift(actor: String) -> CardWidget:
	view.set_lifted_actor(actor)
	var card := CardWidget.new()
	card.name = "ActingCard"
	card.setup(view.battle.troop.catalog.find_name(actor), view.battle.troop, false, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(200 + view.battle.troop.leaders.find(actor) * 218, 730)
	card.pivot_offset = Vector2(104, 312)
	layer.add_child(card)
	for decoration: String in ["LeaderBadge", "LeaderGlow"]:
		if card.visual.has_node(decoration): card.visual.get_node(decoration).hide()
	var lift := _tween().set_parallel(true)
	lift.tween_property(card, "position:y", 580.0, CARD_MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lift.tween_property(card, "scale", Vector2.ONE * 1.15, CARD_MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return card

func _finish_card_lift(card: CardWidget) -> void:
	# Hide before freeing: the restored slot and the animation must never share a frame.
	if is_instance_valid(card):
		card.hide()
		card.queue_free()
	view.set_lifted_actor("")

func _banner(actor: String, skill: Dictionary, enemy: bool, support := false) -> Control:
	var banner := Control.new()
	banner.name = "ActionBanner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(banner)
	BattleArt.picture(banner, "battle_description", Vector2(285, 463))
	var text := RichTextLabel.new()
	text.name = "Message"
	text.position = Vector2(305, 471)
	text.size = Vector2(1310, 40)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.scroll_active = false
	text.add_theme_font_override("normal_font", load("res://assets/fonts/card_text.ttf"))
	text.add_theme_font_size_override("normal_font_size", 21)
	text.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
	text.add_theme_color_override("font_outline_color", Color.BLACK)
	text.add_theme_constant_override("outline_size", 2)
	banner.add_child(text)
	text.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	text.push_color(Color("ee9292") if enemy else Color("86cce6"))
	text.add_text(view.battle.monster.name if enemy else ("联合部队" if support else str(view.battle.troop.catalog.find_name(actor).get("identity", actor))))
	text.pop()
	text.add_text("发动" if support else "使用")
	text.push_color(Color("ffe345"))
	text.add_text(skill.name)
	text.pop()
	text.add_text("！")
	text.pop()
	return banner

func automatic_actions() -> void:
	while not view.battle.pending_relic_feedback.is_empty():
		var feedback: Dictionary = view.battle.pending_relic_feedback.pop_front()
		native("damage_flash", Vector2(960, 350))
		if float(feedback.damage) > 0.0: _damage(float(feedback.damage), Vector2(960, 350))
		await view._wait_animation(0.45 / view.animation_speed())
	await support_actions("player")
	while not view.battle.pending_automatic_skills.is_empty() and view.battle.phase == "player":
		var entry: Dictionary = view.battle.pending_automatic_skills.pop_front()
		var prepared := view.battle.prepare_automatic_skill(entry.actor, entry.id, entry.slot)
		if prepared.get("ok", false): await action(entry.actor, entry.id, false, entry.slot, prepared)
	view.battle.pending_automatic_skills.clear()

func support_actions(side: String) -> void:
	while not view.battle.pending_support_skills.is_empty() and view.battle.phase == side:
		var entry: Dictionary = view.battle.pending_support_skills.pop_front()
		if entry.side != side: continue
		var prepared := BattleSupports.prepare(view.battle, side, entry.uid)
		if not prepared.get("ok", false): continue
		prepared.support_action = true
		prepared.support_uid = entry.uid
		var name := "支援"
		for support: Dictionary in BattleSupports.group(view.battle, side):
			if support.uid == entry.uid: name = BattleSupports.definition(view.battle, support).name
		await action(name, entry.id, side == "enemy", -1, prepared)
		await support_feedback()

func support_feedback() -> void:
	while not view.battle.pending_support_feedback.is_empty():
		var entry: Dictionary = view.battle.pending_support_feedback.pop_front()
		var at := Vector2(960, 860 if entry.side == "player" else 350)
		var event: String = entry.event
		var asset := "support_explode" if event == "explode" else event
		var effect := native(asset, at)
		if event == "barrier_block":
			# The native barrier root stops on frame 4; its owner retires it.
			effect.set_meta("lifetime", 0.6)
			var fade := _tween()
			fade.tween_interval(0.4)
			fade.tween_property(effect, "modulate:a", 0.0, 0.2)
		_sound("res://assets/audio/%s.ogg" % asset)
		if event == "explode" and float(entry.damage) > 0.0:
			_damage(float(entry.damage), at)
			await view._wait_animation(0.2)

static func command_steps(commands: Array) -> Array[Array]:
	# One attack per step. Other commands keep their original order and run once.
	var steps: Array[Array] = []
	var step: Array[Dictionary] = []
	var has_attack := false
	for command: Dictionary in commands:
		if command.kind == "damage" and has_attack:
			steps.append(step)
			step = []
			has_attack = false
		step.append(command)
		if command.kind == "damage": has_attack = true
	steps.append(step)
	return steps

func _skill_effect(descriptor: Dictionary, at: Vector2, rate: float) -> Dictionary:
	var timing := {"impact": 0.25, "duration": 0.0}
	if not descriptor.is_empty():
		var effect := _native_path(descriptor.path, at, rate)
		_sound(descriptor.get("sound_path", ""))
		timing.impact = _impact_time(effect)
		timing.duration = float(effect._data.get("play_duration", float(effect._root.end_frame + 1) / effect.fps))
	return timing

func action(actor: String, id: int, enemy := false, slot: int = -1, automatic: Dictionary = {}) -> void:
	var support_action: bool = automatic.get("support_action", false)
	# The queue animation has already played. A blocked action only records its skip.
	if enemy and not support_action and not view.battle.can_use_enemy_skill(id):
		view.battle.use_enemy_skill(id)
		return
	var skill: Dictionary = view.battle.troop.catalog.skills[id]
	var rate := ENEMY_TEMPO if enemy else 1.0
	if support_action:
		for bar: BattleSupportBar in view._support_bars:
			if bar.side == ("enemy" if enemy else "player"): bar.activate(int(automatic.support_uid))
	var card: CardWidget
	if not enemy and not support_action:
		if automatic.is_empty(): view.show_ap_payment(actor, skill, slot if slot >= 0 else view.battle.skill_slot(actor, id))
		card = _card_lift(actor)
	var banner := _banner(actor, skill, enemy, support_action)
	await view._wait_animation(0.2 if support_action else (0.14 if enemy else CARD_MOVE_TIME) / rate)
	var forecast := BattleForecast.action(view.battle, actor, id, enemy, slot, automatic)
	if get_node("/root/Settings").should_play_cut_in(not enemy and forecast.lethal):
		await _play_cut_in(skill, card)
	var attack := int(skill.type) in [1, 2, 3]
	for n: int in range(1, 4):
		if BattleStatusEffects.valid(int(skill.get("effect%d" % n, 0))) and int(skill.get("value%d" % n, 0)) in range(1, 10): attack = true
	# Support effects belong to the acting side; offensive effects to its opponent.
	var at := Vector2(960, 860 if enemy == attack else 350)
	var element := 0 if enemy else int(view.battle.troop.catalog.find_name(actor).get("element", 0))
	var descriptor := effect_for(skill, element)
	var effect_rate := rate
	var timing := _skill_effect(descriptor, at, effect_rate)
	await view._wait_animation(float(timing.impact) / effect_rate)
	var result: Dictionary
	if not automatic.is_empty():
		result = automatic
		if result.get("ok", false): view.battle.log_message("%s 自动发动 %s" % [actor, skill.name])
	else:
		result = view.battle.prepare_enemy_skill(id) if enemy else view.battle.prepare_player_skill(actor, id, slot)
	var multi_hit := false
	if result.ok:
		var steps := command_steps(result.commands)
		multi_hit = steps.size() > 1
		for index: int in range(steps.size()):
			if index > 0:
				# Schedule impact-to-impact, regardless of attack type or hit count.
				# Long repeat wind-ups must fit while keeping a short recovery window.
				effect_rate = maxf(rate, float(timing.impact) / (MULTI_HIT_INTERVAL - MULTI_HIT_RECOVERY))
				var wind_up := float(timing.impact) / effect_rate
				await view._wait_animation(MULTI_HIT_INTERVAL - wind_up)
				timing = _skill_effect(descriptor, at, effect_rate)
				await view._wait_animation(float(timing.impact) / effect_rate)
			var before_enemy := view.battle.enemy_hp
			var before_player := view.battle.player_hp
			var feedback_before := view.battle.pending_support_feedback.size()
			view.battle.apply_skill_commands("enemy" if enemy else "player", id, steps[index], index == steps.size() - 1)
			for target_side: String in ["enemy", "player"]:
				var dealt := (before_player - view.battle.player_hp) if target_side == "player" else (before_enemy - view.battle.enemy_hp)
				for feedback_index: int in range(feedback_before, view.battle.pending_support_feedback.size()):
					var feedback: Dictionary = view.battle.pending_support_feedback[feedback_index]
					if feedback.event == "explode" and feedback.side == target_side: dealt -= float(feedback.damage)
				if dealt > 0:
					_damage(dealt, Vector2(960, 860 if target_side == "player" else 350), rate, multi_hit)
					_sound("res://assets/audio/attack_damage.ogg")
				elif dealt < 0.0 and not view.battle.information_hidden(target_side):
					_heal(-dealt, target_side == "enemy")
			for command: Dictionary in steps[index]:
				if command.get("miss", false):
					_miss(Vector2(960, 860 if enemy else 350), rate)
			await support_feedback()
			if index == 0:
				# The actor returns after the first impact; remaining strikes are one action.
				_return_card(card)
				card = null
				banner.hide()
				banner.queue_free()
	else:
		view.battle.changed.emit()
	if not enemy and automatic.is_empty(): view.finish_ap_payment()
	_return_card(card)
	await view._wait_animation(0.12 / rate)
	if is_instance_valid(banner): banner.queue_free()
	# Let long effects finish before the next actor starts, preserving their native tail.
	var effect_tail := (float(timing.duration) - float(timing.impact)) / effect_rate - 0.12 / rate
	var damage_tail := ((MULTI_HIT_NUMBER_TIME if multi_hit else 0.66) - 0.12) / rate
	await view._wait_animation(maxf(0.55 / rate, maxf(effect_tail, damage_tail)))
	# Give native/tween processing the final frame before the next action starts.
	if multi_hit: await get_tree().process_frame

func _return_card(card: CardWidget) -> void:
	if not is_instance_valid(card): return
	var down := _tween().set_parallel(true)
	down.tween_property(card, "position:y", 730.0, CARD_MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	down.tween_property(card, "scale", Vector2.ONE, CARD_MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	down.chain().tween_callback(_finish_card_lift.bind(card))

func _damage(amount: float, at: Vector2, rate: float = 1.0, combo := false) -> void:
	if view.battle.information_hidden("player" if at.y > 600 else "enemy"): return
	var number_time := MULTI_HIT_NUMBER_TIME if combo else 0.66
	var flash_time := MULTI_HIT_NUMBER_TIME if combo else 0.4
	var number_at := at - Vector2(0, 60) if at.y < 600 else at
	var flash := native("damage_flash", number_at, rate)
	flash.set_meta("lifetime", flash_time)
	# This stopped native root contains the red/gold flare behind the damage value.
	# Its nested timeline is held by the original engine, so bound its display explicitly.
	var ground := native("damage_ground", number_at, rate)
	ground.set_meta("lifetime", flash_time)
	var number := BattleArt.number(layer, "damage_value", number_at - Vector2(330, 53), Vector2(660, 106), HORIZONTAL_ALIGNMENT_CENTER)
	number.kerning = -8
	number.name = "ActionDamage"
	# Projected native layers draw as top-level CanvasItems; keep values above their glow.
	number.z_index = 10
	number.text = str(int(floor(amount)))
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.pivot_offset = number.size / 2
	number.scale = Vector2(1.35, 1.35)
	var tween := _tween(rate)
	tween.tween_property(number, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fade_time := 0.08 if number_time < 0.66 else 0.18
	tween.tween_interval(maxf(0.0, number_time - 0.12 - fade_time))
	tween.tween_property(number, "modulate:a", 0.0, fade_time)
	tween.tween_callback(number.queue_free)

func _heal(amount: float, enemy := false) -> void:
	var at := Vector2(300, 495) if enemy else Vector2(1250, 495)
	var number := BattleArt.label(layer, "+%d" % int(amount), at, Vector2(450, 70), 48, Color(0.6, 1, 0.62), HORIZONTAL_ALIGNMENT_CENTER)
	var tween := _tween()
	tween.tween_property(number, "position:y", 465.0, 0.55)
	tween.tween_callback(number.queue_free)

func _miss(at: Vector2, rate: float) -> void:
	# The original MISS timeline stops on its visible frame before its end.
	# Its owner must fade and retire it, even when the native root never finishes.
	var effect := native("status_miss", at, rate)
	effect.set_meta("lifetime", 1.1)
	var tween := _tween(rate)
	tween.tween_interval(0.85)
	tween.tween_property(effect, "modulate:a", 0.0, 0.25)

func status_feedback() -> void:
	await support_feedback()
	while not view.battle.pending_status_feedback.is_empty():
		var event: Dictionary = view.battle.pending_status_feedback.pop_front()
		if float(event.damage) > 0.0:
			_damage(event.damage, Vector2(960, 860 if event.side == "player" else 350))
			_sound("res://assets/audio/attack_damage.ogg")
		await view._wait_animation(0.8)

func consume_enemy_intent() -> void:
	if view._intent_buttons.is_empty(): return
	var current: Button = view._intent_buttons.pop_front()
	var source: TextureRect = current.get_child(0)
	var icon := TextureRect.new()
	icon.name = "ActingEnemyIntent"
	icon.texture = source.texture
	icon.size = source.size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.pivot_offset = Vector2(icon.size.x / 2.0, icon.size.y)
	icon.position = layer.get_global_transform().affine_inverse() * source.global_position
	icon.set_meta("skill_id", current.get_meta("skill_id"))
	layer.add_child(icon)
	if current.has_node("BlockedAction"):
		var blocked := BattleArt.picture(icon, "status/blocked_small", Vector2.ZERO)
		blocked.name = "BlockedAction"
	# Lift out of the clipped queue before scaling, leaving no duplicate behind.
	current.hide()
	var pop := _tween(ENEMY_TEMPO)
	pop.tween_property(icon, "scale", Vector2.ONE * 2.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_interval(0.07)
	await pop.finished
	var depart := _tween(ENEMY_TEMPO).set_parallel(true)
	depart.tween_property(icon, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	depart.tween_property(icon, "scale", Vector2.ONE * 2.25, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for pending: Button in view._intent_buttons:
		depart.tween_property(pending, "position:x", pending.position.x + 60.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await depart.finished
	layer.remove_child(icon)
	icon.queue_free()
	current.queue_free()

func round_start(show_player_turn: bool) -> void:
	native("round_ground")
	var title := BattleArt.number(layer, "round_transition_digits", Vector2(780, 464), Vector2(360, 152), HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "RoundTransitionNumber"
	title.kerning = 0
	title.text = str(view.battle.round)
	var fade := _tween()
	fade.tween_interval(1.3)
	fade.tween_property(title, "modulate:a", 0.0, 0.5)
	await view._wait_animation(1.8)
	title.queue_free()
	await down_replacements()
	if show_player_turn:
		native("player_turn")
		await view._wait_animation(0.8)

func down_replacements() -> void:
	while not view.battle.pending_down_replacements.is_empty():
		var entry: Dictionary = view.battle.pending_down_replacements.pop_front()
		if view.battle.troop.leaders[int(entry.slot)] != entry.actor: continue
		view.set_lifted_actor(entry.actor)
		var card := CardWidget.new()
		card.name = "EnteringLeader"
		card.setup(view.battle.troop.catalog.find_name(entry.actor), view.battle.troop, false, 0)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.pivot_offset = Vector2(104,156)
		card.scale = Vector2.ONE * 1.2
		card.position = Vector2(200 + int(entry.slot)*218,930)
		layer.add_child(card)
		for decoration: String in ["LeaderBadge", "LeaderGlow"]:
			if card.visual.has_node(decoration): card.visual.get_node(decoration).hide()
		# Original HastleMotion: rise 200px/150ms, hold 500ms, then
		# fade and shrink 1.2 -> 1.0 over 150ms; reveal the slot at 650ms.
		var entrance := _tween()
		entrance.tween_property(card,"position:y",730.0,0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		entrance.tween_interval(0.5)
		entrance.tween_callback(view.set_lifted_actor.bind(""))
		entrance.tween_property(card,"modulate:a",0.0,0.15)
		entrance.parallel().tween_property(card,"scale",Vector2.ONE,0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await entrance.finished
		card.hide()
		layer.remove_child(card)
		card.queue_free()

func _exit_tree() -> void:
	for voice: AudioStreamPlayer in _voices:
		if is_instance_valid(voice): voice.stop()
