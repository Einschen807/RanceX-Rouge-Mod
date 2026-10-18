extends RefCounted
class_name DesignedSkillEffects
## Stable skill IDs for both card-design batches. Never parse display descriptions.
const ASSAULT := [20029, 20031]
const QUEEN := [20045, 20047]
const COUNTER := [20061, 20063]
const SUPPORT_SHIELD := [20073, 20075]
const ECHO := [20076, 20078]
const LAST_LEADER := [20156, 20158]
const MIMIC := [20332, 20334]
const CENTER_BOOST := [20313, 20315]

static func can_use(id: int, context: Dictionary) -> bool:
	if id in LAST_LEADER: return int(context.get("other_actionable_leaders", 0)) == 0
	return true

static func attack_bonus(id: int, context: Dictionary) -> float:
	match id:
		20300, 20302: return floor((float(context.get("shield_percent", 0.0)) + 0.000001) / 5.0) * (0.7 if id == 20302 else 0.5)
		20033: return float(context.get("combo", 0)) * 0.5
		20035: return float(context.get("combo", 0)) * 0.7
		20084: return floor(float(context.get("gold", 0)) / 50.0)
		20086: return floor(float(context.get("gold", 0)) / 40.0)
	return 0.0

static func resolve(id: int, context: Dictionary) -> Array[Dictionary]:
	if id in ASSAULT: return [{"kind": "battle_ability", "rule": "assault", "amount": 0.5}]
	if id in QUEEN: return [{"kind": "battle_ability", "rule": "queen", "amount": 1}]
	if id in COUNTER: return [{"kind": "battle_ability", "rule": "counter", "amount": 1.0 if id == 20061 else 1.5}]
	if id in SUPPORT_SHIELD: return [{"kind": "battle_ability", "rule": "support_shield", "amount": 3 if id == 20073 else 4}]
	if id in ECHO: return [{"kind": "next_skill_echo", "count": 1 if id == 20076 else 2}]
	match id:
		20320, 20322: return [{"kind": "restore_ap", "amount": 1}]
		20301, 20303: return [{"kind": "retain_shield"}]
		20313, 20315: return [{"kind": "center_boost_ability"}]
		20309, 20311:
			var stacks := 1 if id == 20309 else 2
			return [{"kind": "status", "status": 10, "rounds": stacks, "target": "opponent"}, {"kind": "status", "status": 19, "rounds": stacks, "target": "opponent"}, {"kind": "status", "status": 20, "rounds": stacks, "target": "opponent"}]
		20316, 20318: return [{"kind": "down", "selector": int(context.get("actor_slot", -1)) + 11, "target": "self"}]
		20317, 20319: return [{"kind": "delayed_recovery", "ap": 1, "shield": 5 if id == 20319 else 0}]
		20329, 20331:
			var multiplier: float = (3.0 if id == 20331 else 2.0) + context.get("player_supports", []).size() * (0.7 if id == 20331 else 0.5)
			return [{"kind": "clear_all_supports"}, {"kind": "damage", "amount": float(context.get("deployed_at", 0.0)) * multiplier, "multiplier": multiplier, "element": int(context.get("element", 0)), "hit": 1}]
		20332, 20334:
			var previous: Dictionary = context.get("last_friendly_skill", {})
			if previous.is_empty() or int(previous.id) in MIMIC: return [{"kind": "no_op", "effective_skill_id": 0}]
			var copied := SkillRuntime.resolve_commands(previous, context)
			if copied.is_empty(): copied.append({"kind": "no_op"})
			for command: Dictionary in copied: command.effective_skill_id = int(previous.id)
			return copied
		20143, 20151:
			# Resolve from the pre-cast context, before the first configuration runs.
			var supports: Array = context.get("player_supports", [])
			if not supports.any(func(support: Dictionary) -> bool: return support.get("identity", "") == "魔法阵"):
				return [{"kind": "support_add", "support": 30, "target": "self"}]
		20152, 20154:
			var statuses: Array = context.get("enemy_statuses", [])
			if statuses.is_empty(): return [{"kind": "status", "status": BattleStatusEffects.WEAK, "rounds": 1 if id == 20152 else 2, "target": "opponent"}]
		20161, 20163:
			return [{"kind": "devour", "percent": 8 if id == 20161 else 10, "levels": 1, "target": "opponent"}]
		20008: return [{"kind": "support_add", "support": 10, "target": "self"}]
		20010: return [{"kind": "support_add", "support": 10, "target": "self"}, {"kind": "support_add", "support": 10, "target": "self"}]
		20021, 20023, 20025, 20027: return [{"kind": "down", "selector": int(context.get("actor_slot", -1)) + 11, "target": "self"}]
		20041, 20043: return [{"kind": "block_enemy_action", "index": 0}]
		20072, 20074:
			var commands: Array[Dictionary] = []
			for i: int in range(2 if id == 20072 else 3): commands.append({"kind": "support_add", "support": 80, "target": "self"})
			return commands
		20084, 20086: return [{"kind": "spend_shells", "amount": 20 if id == 20084 else 15}]
		20085, 20087: return [{"kind": "kill_bonus", "amount": 20 if id == 20085 else 25}]
		20092, 20096: return [{"kind": "restore_ap", "amount": 3}]
		20094, 20098, 20116: return [{"kind": "restore_ap", "amount": 4}]
		20118: return [{"kind": "restore_ap", "amount": 6}]
	return []
