extends RefCounted
class_name SkillBaseEffects
## Only numbered elementary effects and named conditions belong here.
## Resolution returns commands to a future battle consumer, and never reads description text.

static func has_effect(id: int) -> bool:
	return id in range(0, 10) or id in range(30, 37) or id in range(40, 45) or BattleStatusEffects.valid(id)

static func valid_value(id: int, value: int) -> bool:
	if id in [3, 4]: return true
	if id in range(6, 10): return true
	if id == 5: return value in range(1, 8) or value in range(11, 18) or value in [21, 22]
	if id == 33: return value in [1, 2, 3, 4, 5, 9]
	if id in [41, 43, 44]: return value == 1
	if BattleStatusEffects.valid(id): return BattleStatusEffects.valid_value(value)
	return value >= 0

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
				commands.append({"kind": "damage", "amount": float(context.get("deployed_at", 0.0)) * value / 100.0, "multiplier": value / 100.0, "hit": hit + 1, "element": int(context.get("element", 0))})
		elif effect in [3, 4]:
			commands.append({"kind": "heal_percent" if effect == 3 else "lose_percent", "percent": absi(value), "target": "self" if value >= 0 else "opponent"})
		elif effect == 5:
			commands.append({"kind": "down", "selector": value, "target": "self"})
		elif effect in range(6, 10):
			commands.append({"kind": "buff", "stat": {6: "physical_resist", 7: "magic_resist", 8: "physical", 9: "magic"}[effect], "amount": value, "target": "self"})
		elif effect in [30, 31]:
			commands.append({"kind": "support_add", "support": value, "target": "self" if effect == 30 else "opponent"})
		elif effect == 32:
			commands.append({"kind": "support_remove", "count": value, "target": "opponent"})
		elif effect == 33:
			commands.append({"kind": "support_remove", "category": value, "count": 1, "target": "opponent"})
		elif effect == 34:
			commands.append({"kind": "support_remove", "support": value, "count": 1, "target": "opponent"})
		elif effect == 36:
			commands.append({"kind": "heal", "amount": float(context.get("deployed_at", 0.0)) * value / 100.0})
		elif effect == 35:
			commands.append({"kind": "buff", "stat": "at", "amount": value})
		elif BattleStatusEffects.valid(effect):
			var command := BattleStatusEffects.command(effect, value)
			if not command.is_empty(): commands.append(command)
	for command: Dictionary in commands:
		command.actor = context.get("actor", "")
		command.actor_identity = context.get("actor_identity", "")
		command.actor_slot = context.get("actor_slot", -1)
		command.support_source = context.get("support_source", false)
	return commands
