extends RefCounted
class_name SkillCustomEffects
## Add custom rules by stable skill ID here, never by display text.
## Return additional commands; base effects still execute, custom effects are added ONCE.
## Example: match skill_id: 9001: return [{"kind": "your_registered_command", "value": 1}]
## Keep actual battle mutation in the battle consumer, not in encyclopedia widgets.

static func resolve(_skill_id: int, _context: Dictionary) -> Array[Dictionary]:
	return []
