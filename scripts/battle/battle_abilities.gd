extends RefCounted
class_name BattleAbilities
const COUNTER_SKILL := 20210

static func fresh_rules() -> Dictionary:
	return {"assault": 0.0, "queen": 0, "counter": 0.0, "support_shield": 0.0, "echoes": []}

static func prepare(state: BattleState, actor: String, skill: Dictionary) -> void:
	var card := state.troop.catalog.find_name(actor)
	var copies := int(state.ability_rules.queen) if int(card.get("faction", 0)) == 2 else 0
	if int(skill.action) == 1 and int(skill.id) not in DesignedSkillEffects.ECHO:
		for charge: Dictionary in state.ability_rules.echoes.duplicate():
			copies += 1
			charge.remaining -= 1
			if int(charge.remaining) <= 0: state.ability_rules.echoes.erase(charge)
	if copies > 0: state.prepared_repeats.append({"id": int(skill.id), "actor": actor, "copies": copies})

static func finish_action(state: BattleState, id: int, commands: Array) -> void:
	if commands.any(func(command: Dictionary) -> bool: return command.get("echo", false)): return
	for prepared: Dictionary in state.prepared_repeats:
		if int(prepared.id) != id: continue
		state.prepared_repeats.erase(prepared)
		for i: int in range(int(prepared.copies)):
			state.pending_skill_repeats.append({"id": id, "actor": prepared.actor})
		break

static func next_repeat(state: BattleState) -> Dictionary:
	if state.pending_skill_repeats.is_empty() or state.enemy_hp <= 0.0 or state.player_hp <= 0.0: return {}
	var entry: Dictionary = state.pending_skill_repeats.pop_front()
	var skill: Dictionary = state.troop.catalog.skills[entry.id]
	var ctx := state.context("player", state.troop.catalog.find_name(entry.actor))
	var commands := SkillRuntime.resolve_commands(skill, ctx)
	if commands.is_empty(): commands.append({"kind": "no_op"})
	for command: Dictionary in commands: command.echo = true
	BattleLeaderPowers.prepare(state, "player", state.effective_skill(skill, commands), commands)
	state._prepare_accuracy("player", commands, skill, int(ctx.element))
	return {"ok": true, "actor": entry.actor, "id": entry.id, "commands": commands, "ap_spent": 0, "followup_action": true}

static func resolve_pending(state: BattleState) -> void:
	if state.defer_skill_repeats or state.resolving_skill_repeats: return
	state.resolving_skill_repeats = true
	while not state.pending_skill_repeats.is_empty():
		var action := next_repeat(state)
		if action.is_empty():
			state.pending_skill_repeats.clear()
			break
		state.log_message("%s 额外释放 %s" % [action.actor, BattleSkillLog.skill_name(state, state.troop.catalog.skills[action.id], action.commands)])
		state.apply_skill_commands("player", action.id, action.commands)
	state.resolving_skill_repeats = false

static func counter(state: BattleState) -> void:
	var multiplier := float(state.ability_rules.counter)
	if multiplier <= 0.0 or state.player_hp <= 0.0 or state.enemy_hp <= 0.0: return
	var before := state.enemy_hp
	var skill: Dictionary = state.troop.catalog.skills[COUNTER_SKILL]
	var command := {"kind": "damage", "amount": state.troop.total("at") * multiplier, "multiplier": multiplier, "actor": "招架反击", "actor_identity": "", "actor_slot": -1, "elements": [0], "element": 0}
	state.log_message("能力发动：招架反击" + BattleSkillLog.suffix(state, [command]))
	state._apply("player", skill, [command])
	state.pending_counter_feedback.append({"damage": maxf(0.0, before - state.enemy_hp)})
	BattleSupports.after_action(state, "player")
	state._check_result()

static func description(state: BattleState, skill: Dictionary) -> String:
	var id := int(skill.id)
	if id in DesignedSkillEffects.ASSAULT:
		return "技能名称中带“突击”的技能\n基础倍率合计+%s" % str(float(state.ability_rules.assault))
	if id in DesignedSkillEffects.QUEEN:
		return "利萨斯阵营所属领队释放技能时\n合计额外释放%d次" % int(state.ability_rules.queen)
	if id in DesignedSkillEffects.COUNTER:
		return "受到未被格挡的攻击伤害时\n发动攻击(%s倍)" % str(float(state.ability_rules.counter))
	if id in DesignedSkillEffects.SUPPORT_SHIELD:
		return "友方每生成1个支援\n合计获得%s%%护盾" % str(float(state.ability_rules.support_shield))
	return String(skill.get("description", ""))

static func valid_rules(data: Variant) -> bool:
	if not data is Dictionary: return false
	for key: String in ["assault", "queen", "counter", "support_shield"]:
		if not TroopCheckpoint._number(data.get(key)) or not is_finite(float(data[key])) or float(data[key]) < 0.0: return false
	if not TroopCheckpoint._integer(data.queen, 0) or not data.get("echoes") is Array: return false
	for charge: Variant in data.echoes:
		if not charge is Dictionary or not TroopCheckpoint._integer(charge.get("remaining"), 1): return false
	return true
