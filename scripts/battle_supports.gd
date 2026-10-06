extends RefCounted
class_name BattleSupports
## Data-driven support instances. No changes to formation base stats.
const STRATEGIST := 40
const BARRIER := 41
const EXPLOSION := 42
const ATTACK_SEAL := 43

static func group(state: BattleState, side: String) -> Array:
	return state.support_groups[side]

static func definition(state: BattleState, entry: Dictionary) -> Dictionary:
	return state.troop.catalog.supports.get(entry.id, {})

static func effects(state: BattleState, side: String, effect: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in group(state, side):
		var support := definition(state, entry)
		var skill: Dictionary = state.troop.catalog.skills.get(support.get("skill", 0), {})
		if int(skill.get("action", 0)) != 3: continue
		for n: int in range(1, 4):
			if int(skill.get("effect%d" % n, 0)) == effect:
				result.append({"entry": entry, "value": int(skill["value%d" % n])})
	return result

static func rate(state: BattleState, side: String, effect: int) -> float:
	var result := 0.0
	for item: Dictionary in effects(state, side, effect): result += float(item.value)
	return result

static func strategist(state: BattleState, side: String) -> float:
	var result := 0.0
	for item: Dictionary in effects(state, side, STRATEGIST): result = maxf(result, float(item.value))
	return result

static func attack_blocked(state: BattleState, side: String, skill: Dictionary) -> bool:
	return int(skill.type) in [1, 2, 3] and not effects(state, "enemy" if side == "player" else "player", ATTACK_SEAL).is_empty()

static func add(state: BattleState, side: String, id: int, actor := "") -> bool:
	if not state.troop.catalog.supports.has(id): return false
	var support: Dictionary = state.troop.catalog.supports[id]
	var list := group(state, side)
	var found := -1
	for i: int in range(list.size()):
		if definition(state, list[i]).identity == support.identity:
			found = i
			break
	if found >= 0 and int(support.repeat) == 2: return false
	if found >= 0 and int(support.repeat) == 4:
		var old := definition(state, list[found])
		support = state.troop.catalog.supports[old.next] if old.next != 0 else old
	if (found < 0 or int(support.repeat) == 3) and list.size() >= SupportCatalog.MAX_COUNT:
		state.log_message("支援栏已满，未配置%s" % support.name)
		return false
	var entry := {"uid": state.next_support_uid, "id": int(support.id), "remaining": int(support.rounds), "born_turn": int(state.support_turns[side]), "actor": actor}
	state.next_support_uid += 1
	if found >= 0 and int(support.repeat) != 3:
		entry.uid = list[found].uid
		list[found] = entry
	else:
		list.append(entry)
	state.support_event.emit(side, entry.uid, "added")
	state.log_message("%s配置%s" % ["联合部队" if side == "player" else state.monster.name, support.name])
	return true

static func remove(state: BattleState, side: String, uid: int, event := "removed") -> void:
	var list := group(state, side)
	for i: int in range(list.size()):
		if int(list[i].uid) != uid: continue
		var name: String = definition(state, list[i]).name
		list.remove_at(i)
		state.support_event.emit(side, uid, event)
		state.log_message("%s解除" % name)
		return

static func dispel(state: BattleState, side: String, command: Dictionary) -> void:
	var targets: Array[int] = []
	for entry: Dictionary in group(state, side):
		var support := definition(state, entry)
		if support.erasable != 1: continue
		if command.has("category") and support.category != command.category: continue
		if command.has("support") and support.id != command.support: continue
		targets.append(entry.uid)
	var rng := state.runtime.rng
	for i: int in range(targets.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := targets[i]
		targets[i] = targets[j]
		targets[j] = tmp
	for i: int in range(mini(int(command.get("count", 1)), targets.size())): remove(state, side, targets[i])

static func begin_turn(state: BattleState, side: String) -> void:
	state.support_turns[side] += 1
	# The configuration phase counts. Expire before selecting automatic actions.
	for entry: Dictionary in group(state, side).duplicate():
		if int(definition(state, entry).rounds) == 0: continue
		entry.remaining -= 1
		if int(entry.remaining) <= 0: remove(state, side, entry.uid)
		else: state.support_event.emit(side, entry.uid, "updated")
	for entry: Dictionary in group(state, side).duplicate():
		var support := definition(state, entry)
		var skill: Dictionary = state.troop.catalog.skills[support.skill]
		if int(skill.action) != 2: continue
		if state.animate_automatic_skills:
			state.pending_support_skills.append({"side": side, "uid": entry.uid, "id": skill.id})
		else:
			var result := prepare(state, side, entry.uid)
			if result.get("ok", false): state.apply_skill_commands(side, skill.id, result.commands)
		if state.phase == "result": break

static func prepare(state: BattleState, side: String, uid: int) -> Dictionary:
	if state.phase != side: return {"ok": false}
	for entry: Dictionary in group(state, side):
		if int(entry.uid) != uid: continue
		var support := definition(state, entry)
		var skill: Dictionary = state.troop.catalog.skills[support.skill]
		if attack_blocked(state, side, skill): return {"ok": false}
		var ctx := state.context(side)
		ctx.deployed_at = state.troop.total("at") if side == "player" else float(state.monster.base_at)
		ctx.actor = support.name
		ctx.actor_identity = ""
		ctx.actor_slot = -1
		ctx.support_source = true
		ctx.ignore_ap = true
		ctx.allow_multiple_actions = true
		ctx.auto_trigger = skill.action
		var source := state.runtime if side == "player" else state.enemy_runtime
		return source.use_skill("support:%s:%d" % [side, uid], skill, ctx)
	return {"ok": false}

static func after_action(state: BattleState, side: String) -> void:
	var target := "enemy" if side == "player" else "player"
	for item: Dictionary in effects(state, side, EXPLOSION).duplicate():
		if state.phase == "result": break
		var amount := state.lose_hp(target, float(item.value))
		state.pending_support_feedback.append({"side": target, "event": "explode", "damage": amount})
		state._check_result()

static func absorb(state: BattleState, side: String, command: Dictionary, potential: float) -> bool:
	var barriers := effects(state, side, BARRIER)
	if barriers.is_empty() or potential <= 0.0: return false
	var breaker: bool = String(command.get("actor_identity", "")) in ["兰斯", "健太郎"] and not command.get("support_source", false) and command.get("kind", "") == "damage"
	if breaker:
		for item: Dictionary in barriers: remove(state, side, item.entry.uid, "broken")
		state.pending_support_feedback.append({"side": side, "event": "barrier_break", "damage": 0.0})
		return false
	state.pending_support_feedback.append({"side": side, "event": "barrier_block", "damage": 0.0})
	return true
