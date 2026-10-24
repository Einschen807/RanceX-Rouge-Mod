extends RefCounted
class_name RockGSkillEffects
## Rock G skill IDs: opening hard-shell stacks and the shell's passive rule.
const HARD_SHELL := 83
const HARD_SHELL_STACKS := 10

static func resolve(skill_id: int, _context: Dictionary) -> Array[Dictionary]:
	if skill_id == 9924:
		return [{"kind": "support_add", "support": HARD_SHELL, "target": "self", "stacks": HARD_SHELL_STACKS}]
	return []

static func passive(skill_id: int) -> Dictionary:
	return {"hard_shell": 1} if skill_id == 9922 else {}
