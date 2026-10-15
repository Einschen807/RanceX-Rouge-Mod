extends RefCounted
class_name DoushinSkillEffects
## Doushin-specific skill IDs stay with the monster's targeting rules and visuals.

static func resolve(skill_id: int, _context: Dictionary) -> Array[Dictionary]:
	match skill_id:
		9904: return [{"kind": "doushin_target"}]
		9906: return [{"kind": "doushin_reaim"}]
	return []

static func passive(skill_id: int) -> Dictionary:
	return {"doushin_body": 1} if skill_id == 9902 else {}
