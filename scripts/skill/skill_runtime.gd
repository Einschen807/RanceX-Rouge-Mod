extends RefCounted
class_name SkillRuntime
## Pure skill lifecycle, independent of UI and future combat scene.
var turn := 1
var run_uses: Dictionary = {}
var battle_uses: Dictionary = {}
var last_turn: Dictionary = {}
var acted: Dictionary = {}
## Exhaustion inherited when an upgrade changes a once-only skill's AP type.
var inherited_limits: Dictionary = {}
## (actor, slot) -> enchantment name; set by the owning TroopState. Monsters have none.
var enchantment_lookup: Callable
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func _key(actor: String, skill: Dictionary, slot: int = 0) -> String:
	return actor + ":" + str(skill.id) + ":slot" + str(slot)

func replace_card(before: Dictionary, after: Dictionary, catalog: CardCatalog) -> void:
	if acted.has(before.name):
		acted[after.name] = acted[before.name]
		acted.erase(before.name)
	# Upgrade skill IDs differ; transfer all counters by corresponding skill slot.
	for slot: int in range(2):
		var old_skill: Dictionary = catalog.skills.get(before["skill%d" % (slot + 1)], {})
		var new_skill: Dictionary = catalog.skills.get(after["skill%d" % (slot + 1)], {})
		if old_skill.is_empty() or new_skill.is_empty(): continue
		var old_key := _key(before.name, old_skill, slot)
		var new_key := _key(after.name, new_skill, slot)
		var limit := int(inherited_limits.get(old_key, 0))
		# Card settings move before the runtime, so the enchantment is already under the new name.
		if CardEnchantments.ap_type_override(enchantment(after.name, slot)) > 0: pass
		elif old_skill.ap_type == 4 and int(run_uses.get(old_key, 0)) > 0: limit = 4
		elif old_skill.ap_type == 5 and int(battle_uses.get(old_key, 0)) > 0 and limit != 4: limit = 5
		if limit != 0: inherited_limits[new_key] = limit
		inherited_limits.erase(old_key)
		for counters: Dictionary in [run_uses, battle_uses, last_turn]:
			if counters.has(old_key):
				counters[new_key] = counters[old_key]
				counters.erase(old_key)

## "Reset card states" for one card: uses, once-only limits and AP accumulation of both
## skill slots return to their initial state. This turn's action flag is kept.
func reset_card(actor: String) -> void:
	var prefix := actor + ":"
	for counters: Dictionary in [run_uses, battle_uses, last_turn, inherited_limits]:
		for key: String in counters.keys():
			if key.begins_with(prefix): counters.erase(key)

func begin_battle() -> void:
	turn = 1
	battle_uses.clear()
	last_turn.clear()
	acted.clear()
	for key: String in inherited_limits.keys():
		if int(inherited_limits[key]) == 5: inherited_limits.erase(key)

func end_battle() -> void:
	begin_battle()

func next_turn() -> void:
	turn += 1
	acted.clear()

func reset_floor() -> void:
	run_uses.clear()
	inherited_limits.clear()
	begin_battle()

func enchantment(actor: String, slot: int) -> String:
	return String(enchantment_lookup.call(actor, slot)) if enchantment_lookup.is_valid() else ""

## Base AP after enchantments; accumulation and penalties still add on top of it.
func base_ap(actor: String, skill: Dictionary, slot: int = 0) -> int:
	return maxi(0, int(skill.ap) - CardEnchantments.ap_reduction(enchantment(actor, slot)))

## Extra releases owed by the use just recorded (回响: the first use this battle).
func enchantment_repeats(actor: String, skill: Dictionary, slot: int = 0) -> int:
	if int(battle_uses.get(_key(actor, skill, slot), 0)) != 1: return 0
	return CardEnchantments.first_use_repeats(enchantment(actor, slot))

## AP type after enchantments (an enchantment may turn any skill into AP累计).
func ap_type(actor: String, skill: Dictionary, slot: int = 0) -> int:
	var override := CardEnchantments.ap_type_override(enchantment(actor, slot))
	return override if override > 0 else int(skill.ap_type)

func ap_cost(actor: String, skill: Dictionary, slot: int = 0) -> int:
	return _cost_for_key(_key(actor, skill, slot), skill, actor, slot)

func _cost_for_key(key: String, skill: Dictionary, actor: String, slot: int) -> int:
	if skill.action != 1:
		return 0
	var base := base_ap(actor, skill, slot)
	match ap_type(actor, skill, slot):
		1:
			var streak: bool = last_turn.get(key, -1) in [turn, turn - 1] and CardEnchantments.streak_penalty(enchantment(actor, slot))
			return base + (1 if streak else 0)
		2: return base + int(run_uses.get(key, 0))
		3: return base + int(battle_uses.get(key, 0))
	return base

## All card views read the same live state. Upgrade previews retain the source
## counters by slot without mutating inventory or transferring runtime records.
func display_state(actor: String, skill: Dictionary, slot: int = 0, source_skill: Dictionary = {}) -> Dictionary:
	var source := skill if source_skill.is_empty() else source_skill
	var key := _key(actor, source, slot)
	var base := base_ap(actor, skill, slot)
	var amount := _cost_for_key(key, skill, actor, slot)
	var type := ap_type(actor, skill, slot)
	var spent: bool = is_spent(actor, source, slot) or (type == 4 and run_uses.get(key, 0) > 0) or (type == 5 and battle_uses.get(key, 0) > 0)
	var palette := "white"
	if amount > base:
		if type in [2, 3]: palette = "purple"
		elif type == 1: palette = "orange"
	return {"amount": amount, "spent": spent, "palette": palette, "text": str(amount) if skill.action == 1 else "—"}

func is_spent(actor: String, skill: Dictionary, slot: int = 0) -> bool:
	var key := _key(actor, skill, slot)
	if turn > 1 and CardEnchantments.first_turn_only(enchantment(actor, slot)): return true
	var type := ap_type(actor, skill, slot)
	return inherited_limits.has(key) or (type == 4 and run_uses.get(key, 0) > 0) or (type == 5 and battle_uses.get(key, 0) > 0)

func can_use(actor: String, skill: Dictionary, context: Dictionary, slot: int = 0) -> bool:
	if skill.action == 3 or not SkillBaseEffects.condition_met(skill.condition, context):
		return false
	if int(skill.get("custom", 0)) == 1 and not SkillCustomEffects.can_use(int(skill.id), context): return false
	if is_spent(actor, skill, slot):
		return false
	if skill.action == 1:
		return (not acted.get(actor, false) or context.get("allow_multiple_actions", false)) and (context.get("ignore_ap", false) or int(context.get("ap", 0)) >= ap_cost(actor, skill, slot))
	# 2 = standard turn-start trigger. 2xxx IDs are explicit extension event keys.
	return int(context.get("auto_trigger", 2)) == int(skill.action)

func use_skill(actor: String, skill: Dictionary, context: Dictionary, slot: int = 0) -> Dictionary:
	var opening: bool = context.get("battle_opening", false)
	if not opening and not can_use(actor, skill, context, slot):
		return {"ok": false, "commands": [], "ap_spent": 0}
	if not opening and skill.action != 1 and rng.randf() * 100.0 >= float(skill.ap):
		return {"ok": false, "commands": [], "ap_spent": 0}
	var spent := 0 if opening or context.get("ignore_ap", false) else ap_cost(actor, skill, slot)
	var key := _key(actor, skill, slot)
	if not opening and skill.action == 1 and not context.get("allow_multiple_actions", false):
		acted[actor] = true
	last_turn[key] = turn
	run_uses[key] = int(run_uses.get(key, 0)) + 1
	battle_uses[key] = int(battle_uses.get(key, 0)) + 1
	var commands := resolve_commands(skill, context)
	for command: Dictionary in CardEnchantments.release_commands(enchantment(actor, slot)):
		command.merge({"actor": context.get("actor", ""), "actor_identity": context.get("actor_identity", ""), "actor_slot": context.get("actor_slot", -1), "support_source": false})
		commands.append(command)
	return {"ok": true, "commands": commands, "ap_spent": spent, "effect_asset": skill.effect_asset, "cut_in": skill.get("cut_in", "")}

static func resolve_commands(skill: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var commands := SkillBaseEffects.resolve(skill, context)
	if skill.custom == 1:
		commands.append_array(SkillCustomEffects.resolve(skill.id, context))
	for command: Dictionary in commands:
		command.actor = command.get("actor", context.get("actor", ""))
		command.actor_identity = command.get("actor_identity", context.get("actor_identity", ""))
		command.actor_slot = command.get("actor_slot", context.get("actor_slot", -1))
		command.support_source = command.get("support_source", context.get("support_source", false))
	return commands
