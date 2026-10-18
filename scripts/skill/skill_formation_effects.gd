extends RefCounted
class_name SkillFormationEffects
## Percentage points in the base troop channel, activated by the starting factions.
const STATS := {51: "hp", 52: "physical", 53: "magic", 54: "physical_resist"}

static func is_formation(skill: Dictionary) -> bool:
	for slot: int in range(1, 4):
		if STATS.has(int(skill.get("effect%d" % slot, 0))): return true
	return false

static func collect(troop: TroopState) -> Dictionary:
	var factions: Dictionary = {}
	var rates: Dictionary = {}
	for actor: String in troop.leaders:
		if not actor.is_empty() and not troop.is_unavailable(actor):
			factions[int(troop.catalog.find_name(actor).faction)] = true
	for card: Dictionary in troop.available:
		if not factions.has(int(card.faction)): continue
		for id: int in [card.skill1, card.skill2]:
			var skill: Dictionary = troop.catalog.skills.get(id, {})
			if int(skill.get("action", 0)) != 3: continue
			for slot: int in range(1, 4):
				var effect := int(skill.get("effect%d" % slot, 0))
				if not STATS.has(effect): continue
				var stat: String = STATS[effect]
				rates[stat] = float(rates.get(stat, 0.0)) + float(skill["value%d" % slot])
	return rates
