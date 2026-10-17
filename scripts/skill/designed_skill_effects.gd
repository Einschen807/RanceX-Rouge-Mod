extends RefCounted
class_name DesignedSkillEffects
## Stable skill IDs for both card-design batches. Never parse display descriptions.
const ASSAULT := [20029, 20031]
const QUEEN := [20045, 20047]
const COUNTER := [20061, 20063]
const SUPPORT_SHIELD := [20073, 20075]
const ECHO := [20076, 20078]
const LAST_LEADER := [20156, 20158]

static func can_use(id: int, context: Dictionary) -> bool:
	if id in LAST_LEADER: return int(context.get("other_actionable_leaders", 0)) == 0
	return true

static func attack_bonus(id: int, context: Dictionary) -> float:
	match id:
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
