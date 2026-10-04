extends RefCounted
class_name SkillRuntime
## Pure skill lifecycle, independent of UI and future combat scene.
var turn := 1
var run_uses: Dictionary = {}
var battle_uses: Dictionary = {}
var last_turn: Dictionary = {}
var acted: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func _key(actor: String, skill: Dictionary, slot: int = 0) -> String:
	return actor + ":" + str(skill.id) + ":slot" + str(slot)

func begin_battle() -> void:
	turn = 1
	battle_uses.clear()
	last_turn.clear()
	acted.clear()

func end_battle() -> void:
	begin_battle()

func next_turn() -> void:
	turn += 1
	acted.clear()

func reset_floor() -> void:
	run_uses.clear()
	begin_battle()

func ap_cost(actor: String, skill: Dictionary, slot: int = 0) -> int:
	if skill.action != 1:
		return 0
	var key := _key(actor, skill, slot)
	match int(skill.ap_type):
		1: return int(skill.ap) + (1 if last_turn.get(key, -1) in [turn, turn - 1] else 0)
		2: return int(skill.ap) + int(run_uses.get(key, 0))
		3: return int(skill.ap) + int(battle_uses.get(key, 0))
	return int(skill.ap)

func is_spent(actor: String, skill: Dictionary, slot: int = 0) -> bool:
	var key := _key(actor, skill, slot)
	return (skill.ap_type == 4 and run_uses.get(key, 0) > 0) or (skill.ap_type == 5 and battle_uses.get(key, 0) > 0)

func can_use(actor: String, skill: Dictionary, context: Dictionary, slot: int = 0) -> bool:
	if skill.action == 3 or not SkillBaseEffects.condition_met(skill.condition, context):
		return false
	if is_spent(actor, skill, slot):
		return false
	if skill.action == 1:
		return (not acted.get(actor, false) or context.get("allow_multiple_actions", false)) and (context.get("ignore_ap", false) or int(context.get("ap", 0)) >= ap_cost(actor, skill, slot))
	# 2 = standard turn-start trigger. 2xxx IDs are explicit extension event keys.
	return int(context.get("auto_trigger", 2)) == int(skill.action)

func use_skill(actor: String, skill: Dictionary, context: Dictionary, slot: int = 0) -> Dictionary:
	if not can_use(actor, skill, context, slot):
		return {"ok": false, "commands": [], "ap_spent": 0}
	if skill.action != 1 and rng.randf() * 100.0 >= float(skill.ap):
		return {"ok": false, "commands": [], "ap_spent": 0}
	var spent := 0 if context.get("ignore_ap", false) else ap_cost(actor, skill, slot)
	var key := _key(actor, skill, slot)
	if skill.action == 1 and not context.get("allow_multiple_actions", false):
		acted[actor] = true
	last_turn[key] = turn
	run_uses[key] = int(run_uses.get(key, 0)) + 1
	battle_uses[key] = int(battle_uses.get(key, 0)) + 1
	var commands := SkillBaseEffects.resolve(skill, context)
	if skill.custom == 1:
		commands.append_array(SkillCustomEffects.resolve(skill.id, context))
	return {"ok": true, "commands": commands, "ap_spent": spent, "effect_asset": skill.effect_asset}
