extends RefCounted
class_name SkillBaseEffects
## Only numbered elementary effects and named conditions belong here.
## Resolution returns commands to a future battle consumer, and never reads description text.

static func has_effect(id: int) -> bool:
	return id in range(0, 10) or id in range(30, 37) or id in range(40, 55) or BattleStatusEffects.valid(id)

static func valid_value(id: int, value: int) -> bool:
	if id in [3, 4]: return true
	if id == 45: return value >= 1
	if id in [46, 47]: return absi(value) < 2000 and absi(value) % 1000 <= 100
	if id == 48: return SkillElements.valid(value)
	if id == 49: return value in [0, 1]
	if id == 50: return value == 1
	if id in range(6, 10): return true
	if id == 5: return value in range(1, 8) or value in range(11, 18) or value in [21, 22]
	if id in BattleLeaderPowers.NAMES: return BattleLeaderPowers.valid_selector(value)
	if id == 33: return value in [1, 2, 3, 4, 5, 9]
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
			var multiplier := value / 100.0
			if String(skill.get("name", "")).contains("突击"): multiplier += float(context.get("assault_bonus", 0.0))
			if int(skill.get("custom", 0)) == 1: multiplier += DesignedSkillEffects.attack_bonus(int(skill.id), context)
			# Combo repeats only attack commands. Other numbered effects execute once.
			for hit: int in range(hits):
				commands.append({"kind": "damage", "amount": float(context.get("deployed_at", 0.0)) * multiplier, "multiplier": multiplier, "hit": hit + 1, "element": int(context.get("element", 0)), "elements": SkillElements.resolve(skill, int(context.get("element", 0)))})
		elif effect in [3, 4]:
			commands.append({"kind": "heal_percent" if effect == 3 else "lose_percent", "percent": absi(value), "target": "self" if value >= 0 else "opponent"})
		elif effect == 5:
			commands.append({"kind": "down", "selector": value, "target": "self"})
		elif effect == 45:
			commands.append({"kind": "cleanse", "count": value, "target": "self"})
		elif effect in [46, 47]:
			commands.append({"kind": "hp_fraction", "basis": "current" if effect == 46 else "missing", "lose": absi(value) >= 1000, "percent": absi(value) % 1000, "target": "self" if value >= 0 else "opponent"})
		elif effect == 50:
			commands.append({"kind": "assassinate", "target": "opponent"})
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
		elif effect in [40, 41]:
			commands.append({"kind": "shield", "percent": value, "side": "player" if effect == 40 else "enemy"})
		elif effect in BattleLeaderPowers.NAMES:
			commands.append({"kind": "leader_power", "power": BattleLeaderPowers.NAMES[effect], "selector": value, "target": "self"})
		elif BattleStatusEffects.valid(effect):
			var command := BattleStatusEffects.command(effect, value)
			if not command.is_empty(): commands.append(command)
	for command: Dictionary in commands:
		command.actor = context.get("actor", "")
		command.actor_identity = context.get("actor_identity", "")
		command.actor_slot = context.get("actor_slot", -1)
		command.support_source = context.get("support_source", false)
	return commands
