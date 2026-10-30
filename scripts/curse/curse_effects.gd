extends RefCounted
class_name CurseEffects
## Rules for held curses, mirroring RelicEffects. Curses execute in acquisition order.
## Fired once when the battle starts (before round 1); skills come from data/skills.txt.
const BATTLE_START := {"撑着了": 9818, "受伤": 9819}
## 利滚利: every shop price is multiplied by this rate (after other discounts).
const PRICE_RATES := {"利滚利": 1.2}

static func held(troop: TroopState, name: String) -> bool:
	return troop.curses.any(func(record: Dictionary) -> bool: return record.name == name)

static func shop_rate(troop: TroopState) -> float:
	var rate := 1.0
	for name: String in PRICE_RATES:
		if held(troop, name): rate *= float(PRICE_RATES[name])
	return rate

## Curses that change combat, shown on the battle state panel.
static func battle_records(troop: TroopState) -> Array[Dictionary]:
	var catalog := CurseCatalog.shared()
	var result: Array[Dictionary] = []
	for record: Dictionary in troop.curses:
		if catalog.by_name.get(record.name, {}).get("battle", false): result.append(record.duplicate())
	return result

## Runs at BattleState.start(). One-shot curses then leave the troop; the preparation
## checkpoint was captured just before, so a battle restart fires them again.
static func battle_start(state: BattleState) -> void:
	var catalog := CurseCatalog.shared()
	var removed := false
	for record: Dictionary in state.troop.curses.duplicate():
		var id := int(BATTLE_START.get(record.name, 0))
		if id != 0 and state.troop.catalog.skills.has(id) and state.phase == "player":
			var skill: Dictionary = state.troop.catalog.skills[id]
			var ctx := state.context("player")
			ctx.actor = record.name
			ctx.actor_identity = ""
			ctx.actor_slot = -1
			var commands := SkillRuntime.resolve_commands(skill, ctx)
			# Curse effects are not attacks: no 侍从铠甲 bonus, no barrier breaking.
			for command: Dictionary in commands: command.relic_source = true
			state._apply("player", skill, commands)
			state.log_message("诅咒发动：" + record.name)
		if catalog.by_name.get(record.name, {}).get("one_shot", false):
			state.troop.curses.erase(record)
			removed = true
	if removed: state.troop.changed.emit()
