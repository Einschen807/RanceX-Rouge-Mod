extends RefCounted
class_name CardEnchantments
## Card enchantments (data/enchantments.txt). One enchantment per card instance, bound to one
## skill slot and stored in TroopState.card_settings, so upgrades and checkpoints carry it.
## Effects dispatch by enchantment name here; they never use numbered skill effects.
const BLUE := Color("6cb6ff")
const SETTING := "enchantment"
const PREEMPT := "先机"
const ECHO := "回响"
const NIMBLE := "轻灵"
const CLEVER := "伶俐"
const ACCUMULATE := "无尽"
var entries: Array[Dictionary] = []
var by_name: Dictionary = {}
var errors: PackedStringArray = []

func load_catalog(path := "res://data/enchantments.txt") -> bool:
	entries.clear()
	by_name.clear()
	errors.clear()
	if not FileAccess.file_exists(path):
		errors.append("附魔文件不存在：" + path)
		return false
	var parsed := RecordTable.parse(FileAccess.get_file_as_string(path))
	if not parsed.error.is_empty(): errors.append(parsed.error)
	for row: Array in parsed.rows:
		if row.size() != 2 or not row[0] is String or not row[1] is String or row[0].strip_edges().is_empty() or by_name.has(row[0]):
			errors.append("附魔记录应为不重复的名称、说明")
			continue
		var record := {"name": row[0], "description": String(row[1]).replace("r", "\n")}
		entries.append(record)
		by_name[record.name] = record
	if not errors.is_empty():
		entries.clear()
		by_name.clear()
	return errors.is_empty()

static func shared() -> CardEnchantments:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.has_meta("card_enchantments"): return tree.get_meta("card_enchantments")
	var catalog := CardEnchantments.new()
	catalog.load_catalog()
	if tree != null: tree.set_meta("card_enchantments", catalog)
	return catalog

## {"name", "slot"} of the card's enchantment, or {} when it has none.
static func of_card(settings: Dictionary, display_name: String) -> Dictionary:
	var entry: Variant = settings.get(display_name, {}).get(SETTING, {}) if settings.get(display_name) is Dictionary else {}
	if not entry is Dictionary or not entry.get("name") is String: return {}
	# JSON checkpoints turn the slot into a float.
	return {"name": entry.name, "slot": int(entry.get("slot", -1))}

static func of_skill(settings: Dictionary, display_name: String, slot: int) -> String:
	var entry := of_card(settings, display_name)
	return String(entry.name) if not entry.is_empty() and int(entry.slot) == slot else ""

## Text appended to an enchanted skill's description; the caller colors it BLUE.
static func suffix(enchantment: String) -> String:
	return "" if enchantment.is_empty() else "\n  " + enchantment

## Extension point for conditional enchanting (future events, e.g. "an AP 0 skill"):
## every key present must match. Supported keys:
##   "ap": exact base AP of an active skill (action 1).
##   "action": skill action type (1 active, 2 automatic, ...).
## An empty requirement accepts every skill.
static func requirement_met(skill: Dictionary, requirement: Dictionary) -> bool:
	if skill.is_empty(): return false
	if requirement.has("action") and int(skill.action) != int(requirement.action): return false
	if requirement.has("ap") and (int(skill.action) != 1 or int(skill.ap) != int(requirement.ap)): return false
	return true

## Slots of the card that may receive an enchantment; empty once the card is enchanted.
static func eligible_slots(troop: TroopState, display_name: String, requirement: Dictionary = {}) -> Array[int]:
	var result: Array[int] = []
	var card := troop.catalog.find_name(display_name)
	if card.is_empty() or not of_card(troop.card_settings, display_name).is_empty(): return result
	for slot: int in range(2):
		var skill: Dictionary = troop.catalog.skills.get(int(card.get("skill%d" % (slot + 1), 0)), {})
		if requirement_met(skill, requirement): result.append(slot)
	return result

# Effect dispatch by name.

static func ap_reduction(enchantment: String) -> int:
	return 1 if enchantment == PREEMPT else 0

## Skill may only be used on the battle's first turn.
static func first_turn_only(enchantment: String) -> bool:
	return enchantment == PREEMPT

## Extra releases granted on the skill's first use this battle.
static func first_use_repeats(enchantment: String) -> int:
	return 1 if enchantment == ECHO else 0

## Normal AP skills (type 1) lose the consecutive-use +1; accumulation is untouched.
static func streak_penalty(enchantment: String) -> bool:
	return enchantment != NIMBLE

## AP type the skill uses instead of its own (-1 keeps it). 2 = AP累计, kept across battles.
static func ap_type_override(enchantment: String) -> int:
	return 2 if enchantment == ACCUMULATE else -1

## Commands added to every real release (not extra releases), after the skill's own effects.
static func release_commands(enchantment: String) -> Array[Dictionary]:
	if enchantment == CLEVER: return [{"kind": "shield", "percent": 3.0, "side": "player"}]
	return []
