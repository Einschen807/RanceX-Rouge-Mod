extends RefCounted
class_name RelicEffects
## Execution follows inventory order, also the left-to-right HUD order.
const PERIODS := {"加奈美忍法帖": 6, "3段喷射发动机": 3}
const SKILLS := {"加奈美忍法帖": 9800, "妖怪宝具": 9801, "郁金香2号": 9802}

static func shop_discount(troop: TroopState) -> float:
	return 0.5 if "邦奥佩塔之证Ａ" in troop.relics else 1.0

static func turn_start(state: BattleState) -> void:
	var actions: Array[Dictionary] = []
	for name: String in state.troop.relics:
		if state.phase != "player": break
		var triggered := false
		if PERIODS.has(name):
			var period: int = PERIODS[name]
			state.troop.relic_counters[name] = (int(state.troop.relic_counters.get(name, 0)) + 1) % period
			triggered = state.troop.relic_counters[name] == 0
		elif name == "妖怪宝具":
			triggered = true
		elif name == "郁金香2号" and state.round == 1:
			triggered = true
		if triggered:
			var entry := {"name": name, "id": int(SKILLS.get(name, 0))}
			actions.append(entry)
	if state.animate_automatic_skills:
		state.pending_relic_actions.append_array(actions)
	else:
		for entry: Dictionary in actions:
			if state.phase != "player": break
			execute(state, entry)

static func prepare(state: BattleState, entry: Dictionary) -> Dictionary:
	if state.phase != "player" or not state.troop.catalog.skills.has(entry.id): return {"ok": false}
	var skill: Dictionary = state.troop.catalog.skills[entry.id]
	if BattleSupports.attack_blocked(state, "player", skill): return {"ok": false}
	var ctx := state.context("player")
	ctx.actor = entry.name
	ctx.actor_identity = ""
	ctx.actor_slot = -1
	ctx.element = 0
	ctx.ignore_ap = true
	ctx.allow_multiple_actions = true
	ctx.auto_trigger = skill.action
	var result := state.runtime.use_skill("relic:" + String(entry.name), skill, ctx)
	if result.get("ok", false):
		result.relic_action = true
		for command: Dictionary in result.commands: command.relic_source = true
		state._prepare_accuracy("player", result.commands, skill, 0)
	return result

static func notify(state: BattleState, name: String) -> void:
	state.log_message("遗物发动：" + name)
	state.relic_triggered.emit(name)

static func execute(state: BattleState, entry: Dictionary) -> void:
	if state.phase != "player": return
	if entry.id == 0:
		state.ap = mini(state.ap_max(), state.ap + 1)
		notify(state, entry.name)
		state.changed.emit()
		return
	var result := prepare(state, entry)
	if result.get("ok", false):
		notify(state, entry.name)
		state.apply_skill_commands("player", entry.id, result.commands)
