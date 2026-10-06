extends RefCounted
class_name BattleForecast
## Run the actual rules on isolated battle/runtime copies, including private RNG state.

static func _runtime(source: SkillRuntime) -> SkillRuntime:
	var copy := SkillRuntime.new()
	copy.turn = source.turn
	for field: String in ["run_uses", "battle_uses", "last_turn", "acted"]:
		copy.set(field, source.get(field).duplicate(true))
	copy.rng.seed = source.rng.seed
	copy.rng.state = source.rng.state
	return copy

static func snapshot(source: BattleState) -> BattleState:
	var copy := BattleState.new()
	# Formation/catalog is read-only during resolution; lifecycle writes are isolated.
	copy.troop = source.troop
	copy.database = source.database
	copy.monster = source.monster.duplicate(true)
	copy.runtime = _runtime(source.runtime)
	copy.enemy_runtime = _runtime(source.enemy_runtime)
	copy.intent = source.intent.duplicate(true)
	copy.pending_enemy_skill = source.pending_enemy_skill
	copy.pending_enemy_commands.assign(source.pending_enemy_commands.duplicate(true))
	copy.player_statuses = source.player_statuses.duplicate(true)
	copy.enemy_statuses = source.enemy_statuses.duplicate(true)
	copy.extra_damage_rates = source.extra_damage_rates.duplicate(true)
	copy.received_damage_rates = source.received_damage_rates.duplicate(true)
	copy.extra_resistance_rates = source.extra_resistance_rates.duplicate(true)
	copy.blocked_player_actors.assign(source.blocked_player_actors)
	copy.animate_automatic_skills = true
	for field: String in ["phase", "round", "round_limit", "ap", "combo", "combo_limit", "player_hp", "player_max_hp", "enemy_hp", "enemy_max_hp", "player_at_bonus", "enemy_at_bonus", "next_swap_round", "player_has_acted", "outcome", "enemy_actions_done", "blocked_enemy_action", "player_damage_total", "enemy_damage_total"]:
		copy.set(field, source.get(field))
	return copy

static func _damage(state: BattleState, side: String, skill: Dictionary, commands: Array) -> float:
	var total := 0.0
	for command: Dictionary in commands:
		if command.kind == "damage" and command.get("target", "opponent") != "self":
			total += state.damage_amount(side, skill, command)
	return total

static func action(state: BattleState, actor: String, id: int, enemy := false, slot := -1, prepared: Dictionary = {}) -> Dictionary:
	var before := state.player_hp if enemy else state.enemy_hp
	var maximum := state.player_max_hp if enemy else state.enemy_max_hp
	var forecast := {"ok": false, "damage": 0.0, "hp_loss": 0.0, "remaining_hp": before, "maximum_hp": maximum, "lethal": false}
	if not state.troop.catalog.skills.has(id): return forecast
	var copy := snapshot(state)
	var result: Dictionary
	if not prepared.is_empty():
		result = copy.apply_automatic_skill(actor, id, prepared.duplicate(true))
	else:
		result = copy.use_enemy_skill(id) if enemy else copy.use_player_skill(actor, id, slot)
	if not result.get("ok", false): return forecast
	forecast.ok = true
	forecast.damage = (copy.player_damage_total - state.player_damage_total) if enemy else (copy.enemy_damage_total - state.enemy_damage_total)
	forecast.remaining_hp = copy.player_hp if enemy else copy.enemy_hp
	forecast.hp_loss = maxf(0.0, before - float(forecast.remaining_hp))
	forecast.lethal = before > 0.0 and forecast.damage > 0.0 and forecast.remaining_hp <= 0.0
	return forecast

static func enemy_round(state: BattleState) -> Dictionary:
	var copy := snapshot(state)
	var forecast := {"damage": 0.0, "percent": 0.0, "remaining_hp": state.player_hp, "lethal": false}
	if copy.phase == "result": return forecast
	var offset := copy.enemy_actions_done if copy.phase == "enemy" else 0
	if copy.phase == "preparation": copy.phase = "player"
	if copy.phase == "player": copy.begin_enemy_turn()
	if not copy.pending_enemy_commands.is_empty():
		var pending: Array[Dictionary] = copy.pending_enemy_commands.duplicate(true)
		copy.apply_skill_commands("enemy", copy.pending_enemy_skill, pending)
	var ids: Array = copy.intent.get("skills", [])
	for index: int in range(offset, ids.size()):
		if copy.phase != "enemy": break
		var id: int = ids[index]
		copy.use_enemy_skill(id)
	if copy.phase == "enemy": copy.finish_enemy_turn()
	forecast.damage = copy.player_damage_total - state.player_damage_total
	forecast.percent = float(forecast.damage) / maxf(1.0, state.player_max_hp) * 100.0
	forecast.remaining_hp = copy.player_hp
	forecast.lethal = state.player_hp > 0.0 and copy.player_hp <= 0.0
	return forecast
