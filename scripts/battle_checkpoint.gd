extends RefCounted
class_name BattleCheckpoint
## Preparation snapshots drive the local Restart button, independently of node saves.
const VERSION := 1
const FIELDS := ["phase", "round", "round_limit", "ap", "combo", "combo_limit", "player_hp", "player_max_hp", "enemy_hp", "enemy_max_hp", "player_at_bonus", "enemy_at_bonus", "next_swap_round", "player_has_acted", "intent", "outcome", "logs", "enemy_actions_done", "player_statuses", "enemy_statuses", "blocked_player_actors", "blocked_enemy_action", "player_damage_total", "enemy_damage_total", "extra_damage_rates", "received_damage_rates", "combat_damage_rates", "extra_resistance_rates", "support_groups", "support_turns", "next_support_uid", "enemy_down"]

static func capture(state: BattleState) -> Dictionary:
	assert(state.phase == "preparation")
	var fields: Dictionary = {}
	for field: String in FIELDS:
		var value: Variant = state.get(field)
		if field in ["player_statuses", "enemy_statuses"]:
			var statuses: Array[Dictionary] = []
			for id: int in value: statuses.append({"id": id, "turns": value[id]})
			fields[field] = statuses
		else: fields[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return {"version": VERSION, "troop": TroopCheckpoint.capture(state.troop), "monster": state.monster.duplicate(true), "enemy_runtime": TroopCheckpoint.capture_runtime(state.enemy_runtime), "fields": fields}

static func restore(source: BattleState, data: Dictionary) -> BattleState:
	if data.get("version", 0) != VERSION or not data.get("fields", null) is Dictionary or data.fields.get("phase", "") != "preparation": return null
	if not data.get("troop", null) is Dictionary or not TroopCheckpoint.valid(data.troop, source.troop.catalog): return null
	if not data.get("monster", null) is Dictionary or not source.database.monsters.has(data.monster.get("identity", "")): return null
	if not data.get("enemy_runtime", null) is Dictionary or not TroopCheckpoint.valid_runtime(data.enemy_runtime): return null
	for field: String in FIELDS:
		if not data.fields.has(field): return null
	for field: String in ["player_statuses", "enemy_statuses"]:
		if not data.fields[field] is Array: return null
		for status: Variant in data.fields[field]:
			if not status is Dictionary or not BattleStatusEffects.valid(int(status.get("id", 0))) or not TroopCheckpoint._integer(status.get("turns"), 1) or int(status.turns) > 9: return null
	if not TroopCheckpoint.restore(source.troop, data.troop): return null
	var result := BattleState.new()
	result.configure(source.troop, source.database, data.monster.identity)
	result.monster = data.monster.duplicate(true)
	# configure resets battle usage; restore the saved runtime after that reset.
	TroopCheckpoint.restore_runtime(result.runtime, data.troop.skill_runtime)
	TroopCheckpoint.restore_runtime(result.enemy_runtime, data.enemy_runtime)
	for field: String in FIELDS:
		var value: Variant = data.fields[field]
		if field in ["player_statuses", "enemy_statuses"]:
			var statuses: Dictionary = {}
			for status: Dictionary in value: statuses[int(status.id)] = int(status.turns)
			result.set(field, statuses)
		elif result.get(field) is Array: result.get(field).assign(value)
		else: result.set(field, value.duplicate(true) if value is Dictionary else value)
	result.preparation_checkpoint = data.duplicate(true)
	result.animate_automatic_skills = source.animate_automatic_skills
	result.troop.changed.emit()
	return result
