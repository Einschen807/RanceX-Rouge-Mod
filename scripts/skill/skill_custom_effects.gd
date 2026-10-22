extends RefCounted
class_name SkillCustomEffects
## Add custom rules by stable skill ID here, never by display text.
## Return additional commands; base effects still execute, custom effects are added ONCE.
## Example: match skill_id: 9001: return [{"kind": "your_registered_command", "value": 1}]
## Keep actual battle mutation in the battle consumer, not in encyclopedia widgets.
## Type 7 (能力) normally dispatches here with custom=1. Store its temporary party-wide
## rules in BattleState so they expire with this battle, never in persistent TroopState.

static func resolve(skill_id: int, _context: Dictionary) -> Array[Dictionary]:
	if skill_id >= 9971 and skill_id <= 9975:
		return [{"kind": "support_add", "support": 90, "target": "self", "stacks": skill_id - 9970}]
	var commands := DesignedSkillEffects.resolve(skill_id, _context)
	commands.append_array(DoushinSkillEffects.resolve(skill_id, _context))
	return commands

static func can_use(skill_id: int, context: Dictionary) -> bool:
	return DesignedSkillEffects.can_use(skill_id, context)

## Ongoing support rules use the same custom switch, dispatched by skill ID.
## These are private rule names, never numbered effects in skills.txt.
static func passive(skill_id: int) -> Dictionary:
	match skill_id:
		9270: return {"strength": 10}
		9202: return {"barrier": 1}
		9203: return {"explosion": 2}
		9204: return {"attack_seal": 1}
		9210: return {"strategist": 10}
		9211: return {"strategist": 20}
		9212: return {"strategist": 30}
		9213: return {"strategist": 40}
		9214: return {"strategist": 50}
		9215: return {"strategist": 60}
		9260: return {"damage_block": 1}
	return DoushinSkillEffects.passive(skill_id)
