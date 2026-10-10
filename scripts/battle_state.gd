extends RefCounted
class_name BattleState
## Combat is independent of its view: preview widgets never become battle records.
signal changed
signal log_added(message: String)
signal status_event(side: String, id: int, event: String)
signal support_event(side: String, uid: int, event: String)
signal shield_event(side: String, event: String)
signal relic_triggered(display_name: String)
var pending_relic_feedback: Array[Dictionary] = []
var support_groups := {"player": [], "enemy": []}
var support_turns := {"player": 0, "enemy": 0}
var shields := {"player": [], "enemy": []}
var shield_policy := {"player": {"duration_turns": 1, "decay_percent": -1.0, "prevent_decay": false}, "enemy": {"duration_turns": 1, "decay_percent": -1.0, "prevent_decay": false}}
var next_support_uid := 1
var pending_support_skills: Array[Dictionary] = []
var pending_support_feedback: Array[Dictionary] = []
var enemy_down := false
var preparation_checkpoint: Dictionary = {}
var pending_down_replacements: Array[Dictionary] = []
var troop: TroopState
var database: MonsterCatalog
var monster: Dictionary
var runtime: SkillRuntime
var enemy_runtime := SkillRuntime.new()
var phase := "preparation"
var round := 1
var round_limit := 99
var ap := 0
var combo := 0
var combo_limit := 13
var player_hp := 0.0
var player_max_hp := 0.0
## Negative preserves encyclopedia/debug full-HP preparation; runs carry persistent damage.
var entry_missing_hp := -1.0
var enemy_hp := 0.0
var enemy_max_hp := 0.0
var player_at_bonus := 0.0
var enemy_at_bonus := 0.0
var next_swap_round := 6
var player_has_acted := false
var intent: Dictionary = {}
var outcome := ""
var logs: Array[String] = []
var animate_automatic_skills := false
var pending_automatic_skills: Array[Dictionary] = []
var enemy_actions_done := 0
var pending_enemy_skill := 0
var pending_enemy_commands: Array[Dictionary] = []
var player_statuses: Dictionary = {}
var enemy_statuses: Dictionary = {}
var blocked_player_actors: Array[String] = []
var blocked_enemy_action := -1
var pending_status_feedback: Array[Dictionary] = []
var player_damage_total := 0.0
var enemy_damage_total := 0.0
## Percent values, summed within each channel; reserved for support/leader skills.
var extra_damage_rates := {"player": 0.0, "enemy": 0.0}
var received_damage_rates := {"player": 0.0, "enemy": 0.0}
var combat_damage_rates := {"player": {"physical": 0.0, "magic": 0.0}, "enemy": {"physical": 0.0, "magic": 0.0}}
var extra_resistance_rates := {"player": {"physical": 0.0, "magic": 0.0}, "enemy": {"physical": 0.0, "magic": 0.0}}

func configure(state: TroopState, monsters: MonsterCatalog, identity: String) -> void:
	troop = state
	database = monsters
	monster = monsters.monsters[identity]
	runtime = troop.skill_runtime
	runtime.begin_battle()
	enemy_runtime.begin_battle()
	support_groups = {"player": [], "enemy": []}
	support_turns = {"player": 0, "enemy": 0}
	shields = {"player": [], "enemy": []}
	shield_policy = {"player": {"duration_turns": 1, "decay_percent": -1.0, "prevent_decay": false}, "enemy": {"duration_turns": 1, "decay_percent": -1.0, "prevent_decay": false}}
	next_support_uid = 1
	pending_support_skills.clear()
	pending_support_feedback.clear()
	pending_relic_feedback.clear()
	pending_down_replacements.clear()
	troop.down_cards.clear()
	troop.retired_characters.clear()
	troop.battle_active = false
	troop.bonus_edit_locked = false
	enemy_down = false
	player_statuses.clear()
	enemy_statuses.clear()
	blocked_player_actors.clear()
	blocked_enemy_action = -1
	pending_status_feedback.clear()
	player_damage_total = 0.0
	enemy_damage_total = 0.0
	extra_damage_rates = {"player": 0.0, "enemy": 0.0}
	received_damage_rates = {"player": 0.0, "enemy": 0.0}
	combat_damage_rates = {"player": {"physical": 0.0, "magic": 0.0}, "enemy": {"physical": 0.0, "magic": 0.0}}
	extra_resistance_rates = {"player": {"physical": 0.0, "magic": 0.0}, "enemy": {"physical": 0.0, "magic": 0.0}}
	enemy_max_hp = float(monster.base_hp)
	enemy_hp = enemy_max_hp
	sync_formation()
	_choose_intent()
	preparation_checkpoint = BattleCheckpoint.capture(self)

func ap_max() -> int:
	return 10 if troop.bonuses.get(3, false) else 6

func swap_interval() -> int:
	return 1 if troop.bonuses.get(5, false) else 5

func swap_remaining() -> int:
	return maxi(0, next_swap_round - round)

func can_swap() -> bool:
	return phase == "preparation" or (phase == "player" and round > 1 and not player_has_acted and round >= next_swap_round)

func sync_formation(previous_leaders: Array[String] = []) -> void:
	player_max_hp = troop.total("hp")
	BattleShields.clamp_capacity(self, "player")
	player_hp = (maxf(0.0, player_max_hp - entry_missing_hp) if entry_missing_hp >= 0.0 else player_max_hp) if phase == "preparation" else minf(player_hp, player_max_hp)
	ap = mini(ap, ap_max())
	if phase != "preparation":
		for name: String in troop.leaders:
			if not name.is_empty() and name not in previous_leaders:
				runtime.acted[name] = true
	changed.emit()

func start() -> bool:
	if phase != "preparation" or player_max_hp <= 0:
		return false
	# Include the final preparation choices, before round 1 changes any battle data.
	preparation_checkpoint = BattleCheckpoint.capture(self)
	phase = "player"
	troop.battle_active = true
	troop.bonus_edit_locked = true
	ap = mini(3, ap_max())
	next_swap_round = 1 + swap_interval()
	log_message("战斗开始：" + monster.name)
	_turn_start()
	return true

func context(side: String, card: Dictionary = {}) -> Dictionary:
	var at := float(monster.base_at)
	if side == "player":
		at = troop.total("at") if card.is_empty() else troop.deployed(card, "at")
	return {"ap": ap, "combo": combo, "round": round, "hp": player_hp if side == "player" else enemy_hp, "hp_max": player_max_hp if side == "player" else enemy_max_hp, "player_hp": player_hp, "player_hp_max": player_max_hp, "deployed_at": at, "element": card.get("element", 0) if side == "player" else monster.get("element", 0), "actor": card.get("name", "") if side == "player" else monster.identity, "actor_identity": card.get("identity", "") if side == "player" else monster.identity, "actor_slot": troop.leaders.find(card.get("name", "")) if side == "player" and not card.is_empty() else (0 if side == "enemy" else -1), "auto_trigger": 2}

func skill_slot(name: String, id: int) -> int:
	var card := troop.catalog.find_name(name)
	return [card.get("skill1", 0), card.get("skill2", 0)].find(id)

func can_use(name: String, id: int, slot: int = -1) -> bool:
	if phase != "player" or name not in troop.leaders or not troop.catalog.skills.has(id):
		return false
	if has_status("player", BattleStatusEffects.SLEEP) or name in blocked_player_actors or troop.is_unavailable(name): return false
	if BattleSupports.attack_blocked(self, "player", troop.catalog.skills[id]): return false
	var card := troop.catalog.find_name(name)
	if slot < 0: slot = skill_slot(name, id)
	return slot in [0, 1] and card["skill%d" % (slot + 1)] == id and troop.catalog.skills[id].action == 1 and runtime.can_use(name, troop.catalog.skills[id], context("player", card), slot)

func use_player_skill(name: String, id: int, slot: int = -1) -> Dictionary:
	var result := prepare_player_skill(name, id, slot)
	if result.ok: apply_skill_commands("player", id, result.commands)
	return result

func prepare_player_skill(name: String, id: int, slot: int = -1) -> Dictionary:
	if slot < 0: slot = skill_slot(name, id)
	if not can_use(name, id, slot):
		return {"ok": false, "commands": []}
	var swap_was_available := can_swap()
	var skill: Dictionary = troop.catalog.skills[id]
	var result := runtime.use_skill(name, skill, context("player", troop.catalog.find_name(name)), slot)
	if not result.ok:
		return result
	ap -= result.ap_spent
	player_has_acted = true
	if swap_was_available:
		next_swap_round = round + swap_interval()
	log_message("%s 使用 %s" % [name, skill.name])
	_prepare_accuracy("player", result.commands, skill, int(card_element(name)))
	return result

func begin_enemy_turn() -> bool:
	if phase != "player":
		return false
	_decay_statuses("player")
	_check_result()
	if phase == "result":
		changed.emit()
		return false
	phase = "enemy"
	combo = 0
	enemy_actions_done = 0
	pending_enemy_skill = 0
	pending_enemy_commands.clear()
	BattleShields.begin_turn(self, "enemy")
	_start_status_turn("enemy")
	if phase != "result": BattleSupports.begin_turn(self, "enemy")
	changed.emit()
	return true

func _enemy_skill_context(skill: Dictionary) -> Dictionary:
	var ctx := context("enemy")
	ctx.ignore_ap = true
	ctx.allow_multiple_actions = true
	ctx.auto_trigger = skill.action
	return ctx

func can_use_enemy_skill(id: int) -> bool:
	if phase != "enemy" or not troop.catalog.skills.has(id): return false
	if enemy_down or has_status("enemy", BattleStatusEffects.SLEEP) or enemy_actions_done == blocked_enemy_action: return false
	var skill: Dictionary = troop.catalog.skills[id]
	if BattleSupports.attack_blocked(self, "enemy", skill): return false
	return enemy_runtime.can_use(monster.identity, skill, _enemy_skill_context(skill))

func use_enemy_skill(id: int) -> Dictionary:
	if phase != "enemy" or not troop.catalog.skills.has(id):
		return {"ok": false, "commands": []}
	var result := prepare_enemy_skill(id)
	if result.ok:
		apply_skill_commands("enemy", id, result.commands)
	else:
		_check_result()
		changed.emit()
	return result

func prepare_enemy_skill(id: int) -> Dictionary:
	if phase != "enemy" or not troop.catalog.skills.has(id):
		return {"ok": false, "commands": []}
	var skill: Dictionary = troop.catalog.skills[id]
	if enemy_down or BattleSupports.attack_blocked(self, "enemy", skill):
		enemy_actions_done += 1
		log_message("%s因%s无法使用%s" % [monster.name, "DOWN" if enemy_down else "攻击封锁", skill.name])
		return {"ok": false, "commands": [], "ap_spent": 0}
	if has_status("enemy", BattleStatusEffects.SLEEP) or enemy_actions_done == blocked_enemy_action:
		enemy_actions_done += 1
		var reason := BattleStatusEffects.SLEEP if has_status("enemy", BattleStatusEffects.SLEEP) else (BattleStatusEffects.CONFUSION if has_status("enemy", BattleStatusEffects.CONFUSION) else BattleStatusEffects.FEAR)
		_status_feedback("enemy", reason, "blocked")
		log_message("%s因%s无法行动" % [monster.name, BattleStatusEffects.effect_name(reason)])
		return {"ok": false, "commands": [], "ap_spent": 0}
	var result := enemy_runtime.use_skill(monster.identity, skill, _enemy_skill_context(skill))
	enemy_actions_done += 1
	if result.ok:
		_prepare_accuracy("enemy", result.commands, skill, int(monster.get("element", 0)))
		log_message("%s 使用 %s" % [monster.name, skill.name])
		pending_enemy_skill = id
		pending_enemy_commands.assign(result.commands)
	else:
		log_message("%s 的 %s 未满足释放条件，跳过" % [monster.name, skill.name])
	return result

func finish_enemy_turn() -> void:
	if phase != "enemy":
		return
	_decay_statuses("enemy")
	_check_result()
	if phase == "result":
		changed.emit()
		return
	if round >= round_limit:
		outcome = "时间结束"
		phase = "result"
		changed.emit()
		return
	round += 1
	runtime.next_turn()
	enemy_runtime.next_turn()
	phase = "player"
	player_has_acted = false
	var recovery := 2 + (1 if troop.bonuses.get(4, false) and round % 2 == 0 else 0)
	if has_status("player", BattleStatusEffects.FEAR):
		recovery -= 1
		_status_feedback("player", BattleStatusEffects.FEAR, "trigger")
	ap = mini(ap_max(), ap + recovery)
	_turn_start()

func _turn_start() -> void:
	enemy_actions_done = 0
	pending_automatic_skills.clear()
	log_message("Round %d" % round)
	_replace_down_leaders()
	BattleShields.begin_turn(self, "player")
	_choose_intent()
	_start_status_turn("player")
	if phase != "result": BattleSupports.begin_turn(self, "player")
	if phase == "player": RelicEffects.turn_start(self)
	for name: String in troop.leaders:
		if name.is_empty() or phase != "player":
			continue
		var card := troop.catalog.find_name(name)
		for slot: int in range(2):
			var id: int = card["skill%d" % (slot + 1)]
			if id == 0 or troop.catalog.skills[id].action != 2:
				continue
			var skill: Dictionary = troop.catalog.skills[id]
			if animate_automatic_skills:
				pending_automatic_skills.append({"actor": name, "id": id, "slot": slot})
			else:
				apply_automatic_skill(name, id, prepare_automatic_skill(name, id, slot))
	changed.emit()

func prepare_automatic_skill(actor: String, id: int, slot: int) -> Dictionary:
	if phase != "player" or actor not in troop.leaders: return {"ok": false}
	if has_status("player", BattleStatusEffects.SLEEP) or actor in blocked_player_actors or troop.is_unavailable(actor): return {"ok": false}
	var card := troop.catalog.find_name(actor)
	var skill: Dictionary = troop.catalog.skills[id]
	if skill.action != 2: return {"ok": false}
	if BattleSupports.attack_blocked(self, "player", skill): return {"ok": false}
	# Roll once before animation; apply the resulting commands at its impact frame.
	var result := runtime.use_skill(actor, skill, context("player", card), slot)
	if result.get("ok", false): _prepare_accuracy("player", result.commands, skill, int(card.element))
	return result

func apply_automatic_skill(actor: String, id: int, result: Dictionary) -> Dictionary:
	if result.get("ok", false):
		log_message("%s 自动发动 %s" % [actor, troop.catalog.skills[id].name])
		apply_skill_commands("player", id, result.commands)
	return result

func apply_skill_commands(side: String, id: int, commands: Array, finished := true) -> void:
	_apply(side, troop.catalog.skills[id], commands)
	if side == "enemy" and pending_enemy_skill == id:
		for command: Dictionary in commands:
			if not pending_enemy_commands.is_empty(): pending_enemy_commands.pop_front()
		if finished:
			pending_enemy_commands.clear()
			pending_enemy_skill = 0
	if finished:
		BattleSupports.after_action(self, side)
		_check_result()
	changed.emit()

func _choose_intent() -> void:
	intent = database.choose(monster.behavior, context("enemy"))

func damage_amount(side: String, skill: Dictionary, command: Dictionary) -> float:
	if command.get("miss", false): return 0.0
	return float(damage_breakdown(side, skill, command).damage)

func damage_breakdown(side: String, skill: Dictionary, command: Dictionary) -> Dictionary:
	var self_target: bool = command.get("target", "opponent") == "self"
	var player_target := (side == "player") == self_target
	var kind := "magic" if skill.type == 3 else "physical"
	var target_side := "player" if player_target else "enemy"
	var base_damage := float(command.amount) * (1.0 + troop.rate(kind) / 100.0 if side == "player" else 1.0)
	var base_resistance := troop.rate(kind + "_resist") if player_target else float(monster.get(kind + "_resist", 0.0))
	var additional_resistance := float(extra_resistance_rates[target_side][kind]) + BattleSupports.rate(self, target_side, 7 if kind == "magic" else 6)
	var additional_damage := float(extra_damage_rates[side]) / 100.0 + (player_at_bonus if side == "player" else enemy_at_bonus) / 100.0
	additional_damage += float(received_damage_rates[target_side]) / 100.0
	additional_damage += float(combat_damage_rates[side][kind]) / 100.0
	additional_damage += BattleSupports.rate(self, side, 9 if kind == "magic" else 8) / 100.0
	additional_damage += (BattleSupports.strategist(self, side) - BattleSupports.strategist(self, "enemy" if side == "player" else "player")) / 100.0
	additional_damage += BattleStatusEffects.outgoing_ratio(statuses(side)) - 1.0
	additional_damage += BattleStatusEffects.incoming_ratio(statuses(target_side), int(command.get("element", 0))) - 1.0
	var damage := maxf(0.0, base_damage) * maxf(0.0, 1.0 + additional_damage) * maxf(0.0, 1.0 - base_resistance / 100.0) * maxf(0.0, 1.0 - additional_resistance / 100.0)
	var breaker: bool = String(command.get("actor_identity", "")) in ["兰斯", "健太郎"] and not command.get("support_source", false)
	return {"base_damage": base_damage, "extra_damage_rate": additional_damage * 100.0, "base_resistance": base_resistance, "extra_resistance": additional_resistance, "unblocked_damage": damage, "damage": 0.0 if not breaker and not BattleSupports.effects(self, target_side, BattleSupports.BARRIER).is_empty() else damage}

func _apply(side: String, skill: Dictionary, commands: Array) -> void:
	for command: Dictionary in commands:
		var self_target: bool = command.get("target", "self" if command.kind in ["heal", "buff"] else "opponent") == "self"
		var player_target := (side == "player") == self_target
		var target_side := "player" if player_target else "enemy"
		match String(command.kind):
			"damage":
				if not command.has("miss"):
					command.miss = _attack_misses(side, target_side, skill)
				if command.get("miss", false):
					log_message("%s的攻击未命中" % ("联合部队" if side == "player" else monster.name))
					continue
				var amount := float(damage_breakdown(side, skill, command).unblocked_damage)
				if BattleSupports.absorb(self, target_side, command, amount): continue
				amount = BattleShields.absorb(self, target_side, amount)
				if player_target:
					player_hp = maxf(0.0, player_hp - amount)
				else:
					enemy_hp = maxf(0.0, enemy_hp - amount)
				if side == "player": combo = mini(combo_limit, combo + 1)
				if player_target: player_damage_total += amount
				else: enemy_damage_total += amount
				_log_damage(target_side, amount)
				if amount > 0.0: remove_status(target_side, BattleStatusEffects.SLEEP)
			"heal":
				if has_status(target_side, BattleStatusEffects.ANTI_REGEN):
					_status_feedback(target_side, BattleStatusEffects.ANTI_REGEN, "trigger")
					log_message("%s因反再生无法恢复HP" % ("联合部队" if player_target else monster.name))
					continue
				if player_target:
					player_hp = minf(player_max_hp, player_hp + float(command.amount))
				else:
					enemy_hp = minf(enemy_max_hp, enemy_hp + float(command.amount))
			"heal_percent":
				if has_status(target_side, BattleStatusEffects.ANTI_REGEN):
					_status_feedback(target_side, BattleStatusEffects.ANTI_REGEN, "trigger")
					continue
				var amount := (player_max_hp if player_target else enemy_max_hp) * float(command.percent) / 100.0
				if player_target: player_hp = minf(player_max_hp, player_hp + amount)
				else: enemy_hp = minf(enemy_max_hp, enemy_hp + amount)
			"lose_percent":
				lose_hp(target_side, float(command.percent), command)
			"down":
				down_leaders(side, int(command.selector), int(command.get("actor_slot", -1)))
			"support_add":
				BattleSupports.add(self, target_side, int(command.support), String(command.get("actor", "")))
			"support_remove":
				BattleSupports.dispel(self, target_side, command)
			"shield":
				BattleShields.add(self, String(command.side), float(command.percent), command.get("options", {}))
			"buff":
				if command.get("stat", "at") == "at":
					if player_target:
						player_at_bonus += float(command.amount)
					else:
						enemy_at_bonus += float(command.amount)
				elif command.stat in ["physical_resist", "magic_resist"]:
					extra_resistance_rates[target_side]["magic" if command.stat == "magic_resist" else "physical"] += float(command.amount)
				elif command.stat in ["physical", "magic"]:
					# One-shot channel modifiers are kept separate from support definitions.
					combat_damage_rates[target_side][command.stat] += float(command.amount)
			"status":
				add_status(target_side, int(command.status), int(command.rounds))

func lose_hp(side: String, percent: float, command: Dictionary = {}) -> float:
	var hp := player_hp if side == "player" else enemy_hp
	var maximum := player_max_hp if side == "player" else enemy_max_hp
	var amount := minf(hp, maxf(0.0, maximum * percent / 100.0))
	if BattleSupports.absorb(self, side, command, amount): return 0.0
	amount = BattleShields.absorb(self, side, amount)
	if side == "player":
		player_hp -= amount
		player_damage_total += amount
	else:
		enemy_hp -= amount
		enemy_damage_total += amount
	if amount > 0:
		_log_damage(side, amount)
		remove_status(side, BattleStatusEffects.SLEEP)
	return amount

func down_leaders(side: String, selector: int, actor_slot: int) -> void:
	if side == "enemy":
		# A monster has exactly one leader at index zero; no adjacent leaders.
		if selector in range(1, 8) or selector == 11:
			enemy_down = true
			log_message("%s DOWN" % monster.name)
		return
	var slots: Array[int] = []
	if selector in range(1, 8):
		for i: int in range(troop.leaders.size()):
			if not troop.leaders[i].is_empty() and not troop.down_cards.has(troop.leaders[i]): slots.append(i)
		for i: int in range(slots.size() - 1, 0, -1):
			var j := runtime.rng.randi_range(0, i)
			var tmp := slots[i]
			slots[i] = slots[j]
			slots[j] = tmp
		slots.resize(mini(selector, slots.size()))
	elif selector in range(11, 18): slots.append(selector - 11)
	elif selector in [21, 22] and actor_slot >= 0: slots.append(actor_slot + (-1 if selector == 21 else 1))
	for slot: int in slots:
		if slot < 0 or slot >= troop.leaders.size(): continue
		var actor := troop.leaders[slot]
		if actor.is_empty() or troop.down_cards.has(actor): continue
		troop.down_cards[actor] = true
		troop.retired_characters[troop.catalog.find_name(actor).identity] = true
		log_message("%s DOWN" % actor)

func _replace_down_leaders() -> void:
	# HastleProcessor selects the highest-star bench card of the same faction.
	# Retire the character, including alternate cards, for this battle only.
	var replaced := false
	for slot: int in range(troop.leaders.size()):
		var old_name := troop.leaders[slot]
		if old_name.is_empty() or not troop.down_cards.has(old_name): continue
		var old_card := troop.catalog.find_name(old_name)
		troop.retired_characters[old_card.identity] = true
		var replacement := ""
		var highest_star := -1
		for candidate: Dictionary in troop.available:
			if candidate.faction != old_card.faction or candidate.name in troop.leaders: continue
			if troop.down_cards.has(candidate.name) or troop.retired_characters.has(candidate.identity): continue
			var stars := troop.level(candidate.name)
			if stars > highest_star:
				highest_star = stars
				replacement = candidate.name
		# A faction with no eligible reserve keeps its DOWN leader on the field.
		if replacement.is_empty(): continue
		troop.leaders[slot] = replacement
		if animate_automatic_skills and not replacement.is_empty():
			pending_down_replacements.append({"slot": slot, "previous": old_name, "actor": replacement})
		log_message("%s退场，%s自动上场" % [old_name, replacement])
		replaced = true
	if replaced:
		player_max_hp = troop.total("hp")
		player_hp = minf(player_hp, player_max_hp)
		troop.changed.emit()

func card_element(actor: String) -> int:
	return int(troop.catalog.find_name(actor).get("element", 0))

func statuses(side: String) -> Dictionary:
	return player_statuses if side == "player" else enemy_statuses

func has_status(side: String, id: int) -> bool:
	return statuses(side).has(id)

func information_hidden(side: String) -> bool:
	return has_status(side, BattleStatusEffects.INFORMATION_BLOCK)

func add_status(side: String, id: int, rounds: int) -> bool:
	if not BattleStatusEffects.valid(id) or rounds <= 0: return false
	var group := statuses(side)
	if id == BattleStatusEffects.PURITY:
		# Purity can cleanse a full status bar, while its own layers still stack.
		for other: int in group.keys():
			if other != BattleStatusEffects.PURITY: remove_status(side, other)
		if side == "player": blocked_player_actors.clear()
		else: blocked_enemy_action = -1
	elif group.has(BattleStatusEffects.PURITY):
		# Consume one layer per attempted status, not per requested duration.
		# Commands are processed in effect-slot order, including within one skill.
		group[BattleStatusEffects.PURITY] -= 1
		status_event.emit(side, BattleStatusEffects.PURITY, "blocked")
		log_message("%s的纯净阻挡%s（剩余%d层）" % ["联合部队" if side == "player" else monster.name, BattleStatusEffects.effect_name(id), group[BattleStatusEffects.PURITY]])
		if group[BattleStatusEffects.PURITY] <= 0: remove_status(side, BattleStatusEffects.PURITY)
		else: status_event.emit(side, BattleStatusEffects.PURITY, "updated")
		return false
	if not group.has(id) and group.size() >= BattleStatusEffects.MAX_TYPES:
		log_message("%s异常栏已满，未附加%s" % ["联合部队" if side == "player" else monster.name, BattleStatusEffects.effect_name(id)])
		return false
	group[id] = mini(BattleStatusEffects.MAX_ROUNDS, int(group.get(id, 0)) + rounds)
	status_event.emit(side, id, "added")
	log_message("%s附加%s（%d%s）" % ["联合部队" if side == "player" else monster.name, BattleStatusEffects.effect_name(id), group[id], "层" if id == BattleStatusEffects.PURITY else "回合"])
	return true

func remove_status(side: String, id: int) -> void:
	if not statuses(side).has(id): return
	statuses(side).erase(id)
	status_event.emit(side, id, "removed")

func _status_feedback(side: String, id: int, event: String, damage := 0.0) -> void:
	pending_status_feedback.append({"side": side, "id": id, "event": event, "damage": damage})
	status_event.emit(side, id, event)

func _decay_statuses(side: String) -> void:
	var group := statuses(side)
	for id: int in group.keys():
		if id == BattleStatusEffects.PURITY: continue
		group[id] -= 1
		if group[id] > 0:
			status_event.emit(side, id, "updated")
			continue
		if id == BattleStatusEffects.CURSE:
			_status_damage(side, id, 0.2)
		elif id == BattleStatusEffects.DEATH_COUNTDOWN:
			var dealt := lose_hp(side, 100.0)
			_status_feedback(side, id, "trigger", dealt)
			log_message("%s的即死预告归零" % ("联合部队" if side == "player" else monster.name))
		remove_status(side, id)

func _status_damage(side: String, id: int, ratio: float) -> void:
	var hp := player_hp if side == "player" else enemy_hp
	var amount := maxf(0.0, floor(minf(hp - 1.0, hp * ratio)))
	if BattleSupports.absorb(self, side, {}, amount): amount = 0.0
	amount = BattleShields.absorb(self, side, amount)
	if amount > 0.0:
		if side == "player":
			player_hp -= amount
			player_damage_total += amount
		else:
			enemy_hp -= amount
			enemy_damage_total += amount
		_log_damage(side, amount)
		remove_status(side, BattleStatusEffects.SLEEP)
	_status_feedback(side, id, "trigger", amount)

func _start_status_turn(side: String) -> void:
	if side == "player": blocked_player_actors.clear()
	else: blocked_enemy_action = -1
	if has_status(side, BattleStatusEffects.POISON): _status_damage(side, BattleStatusEffects.POISON, 0.05)
	if has_status(side, BattleStatusEffects.CONFUSION):
		if side == "player":
			var available: Array[String] = []
			for actor: String in troop.leaders:
				if not actor.is_empty() and not runtime.acted.get(actor, false): available.append(actor)
			if not available.is_empty():
				var actor := available[runtime.rng.randi_range(0, available.size() - 1)]
				blocked_player_actors.append(actor)
				_status_feedback(side, BattleStatusEffects.CONFUSION, "blocked")
				log_message("%s因混乱无法行动" % actor)
	if side == "enemy" and (has_status(side, BattleStatusEffects.CONFUSION) or has_status(side, BattleStatusEffects.FEAR)):
		var ids: Array = intent.get("skills", [])
		if not ids.is_empty(): blocked_enemy_action = enemy_runtime.rng.randi_range(0, ids.size() - 1)
	_check_result()

func _prepare_accuracy(side: String, commands: Array, skill: Dictionary, element: int) -> void:
	# Elements are fixed at preparation; accuracy is resolved at each impact,
	# after earlier commands may have awakened the target or changed dark.
	for command: Dictionary in commands:
		if command.kind != "damage": continue
		command.element = command.get("element", element)

func _attack_misses(side: String, target_side: String, skill: Dictionary) -> bool:
	if not has_status(side, BattleStatusEffects.DARK) or int(skill.type) == 2 or has_status(target_side, BattleStatusEffects.SLEEP): return false
	var source := runtime if side == "player" else enemy_runtime
	return source.rng.randf() < 0.25

func _log_damage(side: String, amount: float) -> void:
	var target := "联合部队" if side == "player" else str(monster.name)
	log_message("%s受到伤害" % target if information_hidden(side) else "%s受到 %d 点伤害" % [target, int(floor(amount))])

func _check_result() -> void:
	if enemy_hp <= 0:
		outcome = "胜利"
	elif player_hp <= 0:
		outcome = "败北"
	if not outcome.is_empty():
		phase = "result"
		troop.bonus_edit_locked = true
		log_message(outcome)

func log_message(message: String) -> void:
	logs.append(message)
	if logs.size() > 300:
		logs.pop_front()
	log_added.emit(message)

func finish() -> void:
	shields = {"player": [], "enemy": []}
	troop.battle_active = false
	troop.bonus_edit_locked = false
	pending_down_replacements.clear()
	troop.down_cards.clear()
	troop.retired_characters.clear()
	runtime.end_battle()
	enemy_runtime.end_battle()
