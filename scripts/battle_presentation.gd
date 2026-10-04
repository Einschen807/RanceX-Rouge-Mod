extends Node
class_name BattlePresentation
const CARD_MOVE_TIME := 0.16
const ENEMY_TEMPO := 1.15
## Action presentation owns timing; BattleState still owns all combat arithmetic.
const DEFAULT_EFFECTS := {
	1: {"animation": "effect_melee", "sound": "attack_melee"},
	2: {"animation": "effect_ranged", "sound": "attack_ranged"},
}
var view: BattleScene
var layer: Control
var _transients: Array[OriginalFlatPlayer] = []
var _tweens: Array[Tween] = []
var _voices: Array[AudioStreamPlayer] = []

func _process(_delta: float) -> void:
	for effect: OriginalFlatPlayer in _transients.duplicate():
		if not is_instance_valid(effect):
			_transients.erase(effect)
		elif effect.is_root_finished():
			_transients.erase(effect)
			effect.queue_free()
	for tween: Tween in _tweens.duplicate():
		if not tween.is_valid():
			_tweens.erase(tween)
		else:
			tween.set_speed_scale(view.animation_speed() * float(tween.get_meta("animation_rate", 1.0)))

func native(asset: String, at: Vector2 = Vector2.ZERO, rate: float = 1.0) -> OriginalFlatPlayer:
	return _native_path("res://assets/battle/native/%s/animation.json" % asset, at, rate)

func _native_path(path: String, at: Vector2, rate: float = 1.0) -> OriginalFlatPlayer:
	var effect: OriginalFlatPlayer
	if path.contains("/effect_melee/") or path.contains("/effect_ranged/"):
		var attack := BattleAttackEffect.new()
		attack.ranged = path.contains("/effect_ranged/")
		effect = attack
	else:
		effect = OriginalFlatPlayer.new()
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

static func effect_for(skill: Dictionary) -> Dictionary:
	var specified: String = skill.get("effect_asset", "")
	if not specified.is_empty():
		var path := "res://assets/effects/%s/animation.json" % specified
		# An explicit asset owns its sound and must not also play a default.
		if FileAccess.file_exists(path):
			return {"path": path, "sound_path": "res://assets/effects/%s/audio.ogg" % specified}
		return {}
	return DEFAULT_EFFECTS.get(int(skill.type), {}).duplicate()

func _sound(path: String) -> void:
	if not ResourceLoader.exists(path): return
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

func _banner(actor: String, skill: Dictionary, enemy: bool) -> Control:
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
	text.add_text(view.battle.monster.name if enemy else str(view.battle.troop.catalog.find_name(actor).identity))
	text.pop()
	text.add_text("使用")
	text.push_color(Color("ffe345"))
	text.add_text(skill.name)
	text.pop()
	text.add_text("！")
	text.pop()
	return banner

func action(actor: String, id: int, enemy := false, slot: int = -1) -> void:
	# The queue animation has already played. A blocked action only records its skip.
	if enemy and not view.battle.can_use_enemy_skill(id):
		view.battle.use_enemy_skill(id)
		return
	var skill: Dictionary = view.battle.troop.catalog.skills[id]
	var rate := ENEMY_TEMPO if enemy else 1.0
	var card: CardWidget
	if not enemy:
		view.show_ap_payment(actor, skill, slot if slot >= 0 else view.battle.skill_slot(actor, id))
		card = _card_lift(actor)
	var banner := _banner(actor, skill, enemy)
	await view._wait_animation((0.14 if enemy else CARD_MOVE_TIME) / rate)
	var at := Vector2(960, 860 if enemy else 350)
	var descriptor := effect_for(skill)
	var impact := 0.25
	if not descriptor.is_empty():
		var effect: OriginalFlatPlayer
		if descriptor.has("path"):
			effect = _native_path(descriptor.path, at, rate)
			_sound(descriptor.sound_path)
		else:
			effect = native(descriptor.animation, at, rate)
			_sound("res://assets/audio/%s.ogg" % descriptor.sound)
		impact = _impact_time(effect)
	await view._wait_animation(impact / rate)
	var before_enemy := view.battle.enemy_hp
	var before_player := view.battle.player_hp
	var result := view.battle.use_enemy_skill(id) if enemy else view.battle.use_player_skill(actor, id, slot)
	if result.ok:
		var dealt := (before_player - view.battle.player_hp) if enemy else (before_enemy - view.battle.enemy_hp)
		if dealt > 0:
			_damage(dealt, at, rate)
			if not descriptor.is_empty() and descriptor.has("animation"):
				_sound("res://assets/audio/attack_damage.ogg")
		elif view.battle.player_hp > before_player:
			_heal(view.battle.player_hp - before_player)
	if not enemy: view.finish_ap_payment()
	if is_instance_valid(card):
		var down := _tween().set_parallel(true)
		down.tween_property(card, "position:y", 730.0, CARD_MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		down.tween_property(card, "scale", Vector2.ONE, CARD_MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		down.chain().tween_callback(_finish_card_lift.bind(card))
	await view._wait_animation(0.12 / rate)
	banner.queue_free()
	await view._wait_animation(0.55 / rate)

func _damage(amount: float, at: Vector2, rate: float = 1.0) -> void:
	native("damage_flash", at, rate)
	var number_at := at - Vector2(0, 60) if at.y < 600 else at
	var number := BattleArt.number(layer, "damage_value", number_at - Vector2(330, 53), Vector2(660, 106), HORIZONTAL_ALIGNMENT_CENTER)
	number.kerning = -8
	number.name = "ActionDamage"
	number.text = str(int(floor(amount)))
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.pivot_offset = number.size / 2
	number.scale = Vector2(1.35, 1.35)
	var tween := _tween(rate)
	tween.tween_property(number, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.36)
	tween.tween_property(number, "modulate:a", 0.0, 0.18)
	tween.tween_callback(number.queue_free)

func _heal(amount: float) -> void:
	var number := BattleArt.label(layer, "+%d" % int(amount), Vector2(1250, 495), Vector2(450, 70), 48, Color(0.6, 1, 0.62), HORIZONTAL_ALIGNMENT_CENTER)
	var tween := _tween()
	tween.tween_property(number, "position:y", 465.0, 0.55)
	tween.tween_callback(number.queue_free)

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
	if show_player_turn:
		native("player_turn")
		await view._wait_animation(0.8)

func _exit_tree() -> void:
	for voice: AudioStreamPlayer in _voices:
		if is_instance_valid(voice): voice.stop()
