extends RefCounted
class_name SkillBaseEffects
## Only numbered elementary effects and named conditions belong here.
## Resolution returns commands to a future battle consumer, and never reads description text.

static func has_effect(id: int) -> bool:
	return id in [0, 1, 2, 3, 4]

static func has_condition(condition: String) -> bool:
	return BattleConditions.valid(condition)

static func condition_met(condition: String, context: Dictionary) -> bool:
	return BattleConditions.met(condition, context)

static func resolve(skill: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var hits := 1
	for n: int in range(1, 4):
		if skill.get("effect%d" % n, 0) == 2:
			hits = maxi(1, skill.get("value%d" % n, 1))
	var commands: Array[Dictionary] = []
	for n: int in range(1, 4):
		var effect: int = skill.get("effect%d" % n, 0)
		var value: int = skill.get("value%d" % n, 0)
		if effect == 1:
			# Combo repeats only attack commands. Other numbered effects execute once.
			for hit: int in range(hits):
				commands.append({"kind": "damage", "amount": float(context.get("deployed_at", 0.0)) * value / 100.0, "multiplier": value / 100.0, "hit": hit + 1})
		elif effect == 3:
			commands.append({"kind": "heal", "amount": float(context.get("deployed_at", 0.0)) * value / 100.0})
		elif effect == 4:
			commands.append({"kind": "buff", "stat": "at", "amount": value})
	return commands
