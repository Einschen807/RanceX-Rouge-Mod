extends RefCounted
class_name BattleLeaderPassives
## Read deployed, available leaders each time, so swapping or DOWN takes effect immediately.
static func value(state: BattleState, actor: String, effect: int) -> float:
	if actor.is_empty() or state.troop.is_unavailable(actor): return 0.0
	var card := state.troop.catalog.find_name(actor)
	var total := 0.0
	for id: int in [card.get("skill1", 0), card.get("skill2", 0)]:
		var skill: Dictionary = state.troop.catalog.skills.get(id, {})
		if int(skill.get("action", 0)) != 3: continue
		if not BattleConditions.met(skill.condition, state.context("player", card)): continue
		for slot: int in range(1, 4):
			if int(skill["effect%d" % slot]) == effect: total += float(skill["value%d" % slot])
	return total

static func total(state: BattleState, side: String, effect: int) -> float:
	if side != "player": return 0.0
	var result := 0.0
	for actor: String in state.troop.leaders: result += value(state, actor, effect)
	return result
