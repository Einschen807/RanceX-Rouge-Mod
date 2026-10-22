extends RefCounted
class_name BattleLeaderPowers
## Card-scoped, independent flags. Reapplying a flag refreshes it, never stacks it.
const NAMES := {42: "boost", 43: "critical", 44: "multi"}
const DISPLAY := {"boost": "BOOST", "critical": "必杀", "multi": "连击"}

static func valid_selector(value: int) -> bool:
	return value in range(1, 8) or value in range(11, 18) or value in [21, 22]

static func flags(state: BattleState, side: String, actor: String) -> Dictionary:
	return state.leader_powers[side].get(actor, {})

static func targets(state: BattleState, side: String, selector: int, actor_slot: int) -> Array[String]:
	var result: Array[String] = []
	if side == "enemy":
		if selector in range(1, 8) and state.enemy_runtime.acted.get(state.monster.identity, false): return result
		if not state.enemy_down and (selector in range(1, 8) or selector == 11): result.append(state.monster.identity)
		return result
	var slots: Array[int] = []
	if selector in range(1, 8):
		for i: int in range(state.troop.leaders.size()):
			var actor := state.troop.leaders[i]
			# Filter before drawing so spent leaders never consume a requested target.
			if not actor.is_empty() and not state.troop.is_unavailable(actor) and not state.runtime.acted.get(actor, false): slots.append(i)
		for i: int in range(slots.size() - 1, 0, -1):
			var j := state.runtime.rng.randi_range(0, i)
			var previous := slots[i]
			slots[i] = slots[j]
			slots[j] = previous
		slots.resize(mini(selector, slots.size()))
	elif selector in range(11, 18): slots.append(selector - 11)
	elif selector in [21, 22] and actor_slot >= 0: slots.append(actor_slot + (-1 if selector == 21 else 1))
	for slot: int in slots:
		if slot < 0 or slot >= state.troop.leaders.size(): continue
		var actor := state.troop.leaders[slot]
		if not actor.is_empty() and not state.troop.is_unavailable(actor): result.append(actor)
	return result

static func grant(state: BattleState, side: String, power: String, selector: int, actor_slot: int) -> void:
	if power not in DISPLAY or not valid_selector(selector): return
	for actor: String in targets(state, side, selector, actor_slot):
		if not state.leader_powers[side].has(actor): state.leader_powers[side][actor] = {}
		state.leader_powers[side][actor][power] = true
		state.log_message("%s 获得%s" % [actor, DISPLAY[power]])

## Troop critical/combo occurrence rates: each is rolled independently at player turn start;
## success grants that power to one random available leader.
static func roll_rates(state: BattleState) -> void:
	for pair: Array in [["critical", "critical"], ["multi", "combo"]]:
		var chance := state.troop.rate(pair[1])
		# Skip the draw at 0% so existing seeded battles keep their random sequence.
		if chance <= 0.0: continue
		if state.runtime.rng.randf() * 100.0 < chance: grant(state, "player", pair[0], 1, -1)

static func attack(skill: Dictionary, command: Dictionary) -> bool:
	return int(skill.get("type", 0)) in [1, 2, 3] and command.get("kind", "") == "damage" and not command.get("support_source", false) and command.get("target", "opponent") != "self" and not String(command.get("actor", "")).is_empty()

static func prepare(state: BattleState, side: String, skill: Dictionary, commands: Array) -> void:
	var attacks: Array[int] = []
	for i: int in range(commands.size()):
		if attack(skill, commands[i]): attacks.append(i)
	if attacks.is_empty(): return
	var actor: String = commands[attacks[0]].actor
	var original_hits := 1
	for n: int in range(1, 4):
		if int(skill.get("effect%d" % n, 0)) == 2: original_hits = maxi(original_hits, int(skill.get("value%d" % n, 1)))
	if attacks.size() == 1 and original_hits == 1 and flags(state, side, actor).get("multi", false):
		var extra: Dictionary = commands[attacks[0]].duplicate(true)
		extra.hit = 2
		commands.insert(attacks[0] + 1, extra)
		attacks.append(attacks[0] + 1)
	for n: int in range(attacks.size()): commands[attacks[n]].power_first_hit = n == 0

static func extra_rate(state: BattleState, side: String, skill: Dictionary, command: Dictionary) -> float:
	if not attack(skill, command): return 0.0
	var active := flags(state, side, String(command.actor))
	var rate := 50.0 if active.get("boost", false) else 0.0
	if active.get("critical", false) and command.get("power_first_hit", int(command.get("hit", 1)) == 1): rate += 100.0
	return rate

static func consume(state: BattleState, side: String, skill: Dictionary, command: Dictionary) -> void:
	# First attack segment spends critical even on MISS or an absorbed hit.
	if attack(skill, command) and command.get("power_first_hit", int(command.get("hit", 1)) == 1):
		flags(state, side, String(command.actor)).erase("critical")
		prune(state, side)

static func prune(state: BattleState, side: String) -> void:
	for actor: String in state.leader_powers[side].keys():
		if state.leader_powers[side][actor].is_empty() or (state.enemy_down if side == "enemy" else actor not in state.troop.leaders or state.troop.is_unavailable(actor)):
			state.leader_powers[side].erase(actor)

static func clear(state: BattleState, side: String) -> void:
	state.leader_powers[side].clear()
