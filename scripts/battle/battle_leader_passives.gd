extends RefCounted
class_name BattleLeaderPassives
## Read deployed, available leaders each time, so swapping or DOWN takes effect immediately.
static func value(state: BattleState, actor: String, effect: int) -> float:
	var total := 0.0
	for amount: float in values(state, actor, effect): total += amount
	return total

static func values(state: BattleState, actor: String, effect: int) -> Array[float]:
	var result: Array[float] = []
	if actor.is_empty() or state.troop.is_unavailable(actor): return result
	var card := state.troop.catalog.find_name(actor)
	for id: int in [card.get("skill1", 0), card.get("skill2", 0)]:
		var skill: Dictionary = state.troop.catalog.skills.get(id, {})
		if int(skill.get("action", 0)) != 3: continue
		if not BattleConditions.met(skill.condition, state.context("player", card)): continue
		for slot: int in range(1, 4):
			if int(skill["effect%d" % slot]) == effect: result.append(float(skill["value%d" % slot]))
	return result

static func total(state: BattleState, side: String, effect: int) -> float:
	if side != "player": return 0.0
	var result := 0.0
	for actor: String in state.troop.leaders: result += value(state, actor, effect)
	return result
