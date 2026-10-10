extends RefCounted
class_name TroopCheckpoint
## Plain run/formation data. Catalog resources and battle-only DOWN are not saved.
static func capture(troop: TroopState) -> Dictionary:
	var cards: Array[String] = []
	for card: Dictionary in troop.available: cards.append(card.name)
	var bonuses: Array[Dictionary] = []
	for id: int in troop.bonuses: bonuses.append({"id": id, "enabled": bool(troop.bonuses[id])})
	# Currency is independent of medals and their troop-level progress.
	return {"gold": troop.gold, "relic_counters": troop.relic_counters.duplicate(true), "relics": troop.relics.duplicate(), "cards": cards, "leaders": troop.leaders.duplicate(), "levels": troop.levels.duplicate(true), "ox_coefficient": troop.ox_coefficient, "bonuses": bonuses, "bonus_points": troop.bonus_points, "medals": troop.medals, "medal_progress": troop.medal_progress, "troop_level": troop.troop_level, "rare_card_bias": troop.rare_card_bias, "encyclopedia_mode": troop.encyclopedia_mode, "damage_rates": troop.damage_rates.duplicate(true), "resistance_rates": troop.resistance_rates.duplicate(true), "skill_runtime": capture_runtime(troop.skill_runtime)}

static func capture_runtime(runtime: SkillRuntime) -> Dictionary:
	var result := {"turn": runtime.turn, "rng_seed": str(runtime.rng.seed), "rng_state": str(runtime.rng.state)}
	for key: String in ["run_uses", "battle_uses", "last_turn", "acted"]: result[key] = runtime.get(key).duplicate(true)
	return result

static func restore_runtime(runtime: SkillRuntime, data: Dictionary) -> void:
	runtime.turn = int(data.turn)
	for key: String in ["run_uses", "battle_uses", "last_turn", "acted"]: runtime.set(key, data[key].duplicate(true))
	# JSON numbers cannot preserve every 64-bit RNG state; store these as strings.
	runtime.rng.seed = int(data.rng_seed)
	runtime.rng.state = int(data.rng_state)

static func valid_runtime(data: Dictionary) -> bool:
	if not data.get("rng_seed", null) is String or not data.get("rng_state", null) is String: return false
	if not data.rng_seed.is_valid_int() or not data.rng_state.is_valid_int() or not _integer(data.get("turn"), 1): return false
	for key: String in ["run_uses", "battle_uses", "last_turn", "acted"]:
		if not data.get(key, null) is Dictionary: return false
		for actor: Variant in data[key]:
			if not actor is String: return false
			if key == "acted":
				if not data[key][actor] is bool: return false
			elif not _integer(data[key][actor], -1 if key == "last_turn" else 0): return false
	return true

static func valid(data: Dictionary, catalog: CardCatalog) -> bool:
	if data.has("gold") and not _integer(data.gold, 0): return false
	if catalog == null or not data.get("cards", null) is Array or not data.get("leaders", null) is Array: return false
	if data.leaders.size() != 7 or not data.get("levels", null) is Dictionary or not data.get("bonuses", null) is Array: return false
	if not data.get("encyclopedia_mode", null) is bool or not _integer(data.get("bonus_points"), 0): return false
	var has_progress := data.has("medals") or data.has("medal_progress") or data.has("troop_level")
	for field: String in ["medals", "medal_progress", "troop_level"]:
		if has_progress and not _integer(data.get(field), 0): return false
	if data.get("medal_progress", 0) > 2: return false
	if not _number(data.get("ox_coefficient")) or float(data.ox_coefficient) <= 0.0: return false
	if data.has("relics"):
		if not data.relics is Array: return false
		var relic_database := RelicCatalog.new()
		if not relic_database.load_catalog(): return false
		var seen: Array[String] = []
		for name: Variant in data.relics:
			if not name is String or name in seen or not relic_database.by_name.has(name): return false
			seen.append(name)
	if data.has("relic_counters"):
		if not data.relic_counters is Dictionary: return false
		for name: Variant in data.relic_counters:
			if not name is String or name not in data.get("relics", []) or not RelicEffects.PERIODS.has(name): return false
			if not _integer(data.relic_counters[name], 0) or data.relic_counters[name] >= int(RelicEffects.PERIODS[name]): return false
	var owned: Dictionary = {}
	for name: Variant in data.cards:
		if not name is String or catalog.find_name(name).is_empty() or owned.has(name): return false
		owned[name] = true
	var factions: Dictionary = {}
	for name: Variant in data.leaders:
		if not name is String: return false
		if name.is_empty(): continue
		if not owned.has(name): return false
		var faction: int = catalog.find_name(name).faction
		if factions.has(faction): return false
		factions[faction] = true
	for name: Variant in data.levels:
		if not name is String or catalog.find_name(name).is_empty() or not _integer(data.levels[name], 0): return false
	var bonus_ids: Dictionary = {}
	if data.has("rare_card_bias") and (not _integer(data.rare_card_bias, 0) or float(data.rare_card_bias) > 100): return false
	for bonus: Variant in data.bonuses:
		if not bonus is Dictionary or not _integer(bonus.get("id"), 0) or int(bonus.id) >= TroopState.BONUS_NAMES.size() or not bonus.get("enabled", null) is bool: return false
		if bonus_ids.has(int(bonus.id)): return false
		bonus_ids[int(bonus.id)] = true
	for field: String in ["damage_rates", "resistance_rates"]:
		if not data.get(field, null) is Dictionary: return false
		for channel: String in ["physical", "magic"]:
			if not _number(data[field].get(channel)): return false
	return data.get("skill_runtime", null) is Dictionary and valid_runtime(data.skill_runtime)

static func restore(troop: TroopState, data: Dictionary) -> bool:
	if not valid(data, troop.catalog): return false
	# Validate the complete snapshot before touching the shared formation object.
	troop.relics.assign(data.get("relics", []))
	troop.relic_counters.clear()
	for name: String in troop.relics:
		if RelicEffects.PERIODS.has(name): troop.relic_counters[name] = int(data.get("relic_counters", {}).get(name, 0))
	troop.available.clear()
	for name: String in data.cards: troop.available.append(troop.catalog.find_name(name))
	troop.leaders.assign(data.leaders)
	troop.levels.clear()
	for name: String in data.levels: troop.levels[name] = int(data.levels[name])
	troop.bonuses.clear()
	for bonus: Dictionary in data.bonuses: troop.bonuses[int(bonus.id)] = bonus.enabled
	troop.ox_coefficient = float(data.ox_coefficient)
	troop.gold = int(data.get("gold", 99))
	troop.bonus_points = int(data.bonus_points)
	# Older map saves used bonus_points as the raw medal counter.
	if data.has("troop_level"):
		troop.medals = int(data.medals)
		troop.medal_progress = int(data.medal_progress)
		troop.troop_level = int(data.troop_level)
	else:
		troop.medals = int(data.bonus_points)
		troop.medal_progress = troop.medals % 3
		troop.troop_level = int(troop.medals / 3)
		if not data.encyclopedia_mode: troop.bonus_points = troop.troop_level
	troop.encyclopedia_mode = data.encyclopedia_mode
	troop.rare_card_bias = int(data.get("rare_card_bias", 0))
	troop.damage_rates = data.damage_rates.duplicate(true)
	troop.resistance_rates = data.resistance_rates.duplicate(true)
	troop.down_cards.clear()
	troop.retired_characters.clear()
	troop.battle_active = false
	troop.bonus_edit_locked = false
	restore_runtime(troop.skill_runtime, data.skill_runtime)
	return true

static func _integer(value: Variant, minimum: int) -> bool:
	return _number(value) and float(value) == floor(float(value)) and float(value) >= minimum

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
