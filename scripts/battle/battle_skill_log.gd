extends RefCounted
class_name BattleSkillLog
## Describe this resolved cast, before its costs or effects change the next cast.
static func number(value: float) -> String:
	var formatted := "%.4f" % value
	while formatted.ends_with("0"): formatted = formatted.trim_suffix("0")
	return formatted.trim_suffix(".")

static func suffix(state: BattleState, commands: Array) -> String:
	var multipliers: Array[float] = []
	var details: Array[String] = []
	var additions := {}
	for command: Dictionary in commands:
		if command.get("kind") == "damage" and command.has("multiplier"):
			multipliers.append(float(command.multiplier))
		elif command.get("kind") == "battle_ability":
			var rule := String(command.rule)
			additions[rule] = float(additions.get(rule, 0.0)) + float(command.amount)
	if not multipliers.is_empty():
		var same := multipliers.all(func(value: float) -> bool: return is_equal_approx(value, multipliers[0]))
		if same:
			details.append(number(multipliers[0]) + "倍" + ("×%d连击" % multipliers.size() if multipliers.size() > 1 else ""))
		else:
			var values: Array[String] = []
			for value: float in multipliers: values.append(number(value) + "倍")
			details.append("、".join(values))
	for rule: String in additions:
		var total := float(state.ability_rules.get(rule, 0.0)) + float(additions[rule])
		match rule:
			"assault": details.append("突击倍率合计+%s" % number(total))
			"queen": details.append("合计额外释放%d次" % int(total))
			"counter": details.append("反击合计%s倍" % number(total))
			"support_shield": details.append("生成支援合计获得%s%%护盾" % number(total))
	return "（%s）" % "，".join(details) if not details.is_empty() else ""

static func skill_name(state: BattleState, skill: Dictionary, commands: Array) -> String:
	return String(skill.name) + suffix(state, commands)
