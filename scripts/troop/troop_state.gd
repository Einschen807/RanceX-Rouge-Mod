extends RefCounted
class_name TroopState
## Shared formation model. Encyclopedia creates its own state, never granting run inventory.
signal changed
signal card_replaced(previous: String, replacement: String)
signal troop_leveled_up(count: int)
signal relic_acquired(display_name: String, source_position: Vector2)
var relics: Array[String] = []
## Acquired relic progress belongs to the run, surviving battle boundaries.
var relic_counters: Dictionary = {}
## Run curses persist across battles, separately from combat status ailments.
var curses: Array[Dictionary] = []
var catalog: CardCatalog
var available: Array[Dictionary] = []
var leaders: Array[String] = ["", "", "", "", "", "", ""]
var levels: Dictionary = {}
## Instance settings are independent of the catalog version (future enchantments, etc.).
var card_settings: Dictionary = {}
var ox_coefficient := 5.0
var bonuses: Dictionary = {}
## Persistent formation rates. Combat support/status modifiers belong to BattleState.
var damage_rates := {"physical": 0.0, "magic": 0.0}
var resistance_rates := {"physical": 0.0, "magic": 0.0}
var bonus_points := 0
var medals := 0
var gold := 99
var medal_progress := 0
var troop_level := 0
## Percentage-point bonus shared by all treasure pools, reset on an offered rare.
var rare_card_bias := 0
var encyclopedia_mode := false
## Battle-only DOWN records; do not affect deployment AT or owned faction stats.
var down_cards: Dictionary = {}
## Original battle replacement excludes every card of a retired character.
var retired_characters: Dictionary = {}
## Manual swaps retire identities only when the formation window closes.
var battle_formation_editing := false
var pending_retired_characters: Dictionary = {}
var battle_active := false
## Battle-only starting-lineup snapshot; never serialized into run inventory.
var formation_effect_rates: Dictionary = {}
## Locks after Start through the result page; preparation remains editable.
var bonus_edit_locked := false
var skill_runtime := SkillRuntime.new()
const DEPLOYMENT_ORDER := [3, 2, 4, 1, 5, 0, 6]
const BONUS_NAMES := ["增加领队格子 +1", "增加领队格子 +1", "增加领队格子 +1", "AP最大值强化 6→10", "AP恢复强化 偶数回合+1", "更换领队", "神魔阵营解禁", "强化出现概率 +100%", "HP增加 +30%", "物理伤害增加 +30%", "魔法伤害增加 +30%", "哈尼打火机", "全面强化 +3%", "全面强化 +3%", "上限解除 +25%", "上限解除 +25%"]
## Keep stable saved bonus IDs; retired choices are never displayed or acquired.
const BONUS_IDS := [0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 14, 15]

## "Reset card states" restores skill uses/AP costs, preserving card instance settings.
func reset_card_states() -> void:
	skill_runtime.reset_floor()
	changed.emit()

func add_gold(amount: int) -> void:
	if amount <= 0: return
	gold += amount
	changed.emit()

static func parse_curse(argument: String) -> Dictionary:
	var parts := argument.split("|", true, 1)
	var name := parts[0].strip_edges()
	if name.is_empty(): return {}
	return {"name": name, "description": parts[1].strip_edges().replace("r", "\n") if parts.size() == 2 else ""}

func acquire_curse(display_name: String, description := "") -> bool:
	var name := display_name.strip_edges()
	if name.is_empty() or curses.any(func(record: Dictionary) -> bool: return record.name == name): return false
	curses.append({"name": name, "description": description})
	changed.emit()
	return true

func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount: return false
	gold -= amount
	changed.emit()
	return true

func add_medals(amount: int) -> void:
	if amount <= 0: return
	medals += amount
	var progress := medal_progress + amount
	var gained := int(progress / 3)
	medal_progress = progress % 3
	troop_level += gained
	bonus_points += gained
	changed.emit()
	if gained > 0: troop_leveled_up.emit(gained)

func spend_medals(amount: int) -> bool:
	if amount < 0 or medals < amount: return false
	medals -= amount
	changed.emit()
	return true

func leader_capacity() -> int:
	return 4 + int(bonuses.get(0, false)) + int(bonuses.get(1, false)) + int(bonuses.get(2, false))

func is_slot_unlocked(slot: int) -> bool:
	return slot >= 0 and slot < leaders.size() and slot in DEPLOYMENT_ORDER.slice(0, leader_capacity())

func rate_cap() -> float:
	return 49.0 + 25.0 * (int(bonuses.get(14, false)) + int(bonuses.get(15, false)))

func configure(database: CardCatalog, encyclopedia: bool, owned_names: Array[String] = []) -> void:
	catalog = database
	encyclopedia_mode = encyclopedia
	if encyclopedia_mode:
		for id: int in BONUS_IDS: bonuses[id] = true
	available.clear()
	for card: Dictionary in catalog.cards:
		if (encyclopedia and not CardCatalog.is_upgraded(card)) or (not encyclopedia and card.name in owned_names):
			available.append(card)
	for i: int in range(leaders.size()):
		if not leaders[i].is_empty() and not has_card(leaders[i]):
			leaders[i] = ""
	changed.emit()

func has_card(display_name: String) -> bool:
	return available.any(func(c: Dictionary) -> bool: return c.name == display_name)

func owned_version(display_name: String) -> String:
	var base := display_name.trim_suffix(CardCatalog.UPGRADE_SUFFIX)
	if has_card(base + CardCatalog.UPGRADE_SUFFIX): return base + CardCatalog.UPGRADE_SUFFIX
	return base if has_card(base) else ""

func acquire_card(display_name: String) -> void:
	var card := catalog.find_name(display_name)
	if card.is_empty(): return
	var owned := owned_version(display_name)
	if not owned.is_empty():
		upgrade_card(owned)
		return
	available.append(card)
	# Newly obtained cards remain in inventory, without deploying a leader.
	changed.emit()

func upgrade_card(display_name: String) -> bool:
	if not has_card(display_name): return false
	var before := catalog.find_name(display_name)
	var after := catalog.upgrade_preview(before)
	if after.name == before.name:
		levels[display_name] = level(display_name) + 5
	else:
		return set_card_upgraded(display_name, true)
	changed.emit()
	return true

## Version-only replacement for the encyclopedia toggle; never adds card levels.
func set_card_upgraded(display_name: String, upgraded: bool) -> bool:
	if not has_card(display_name): return false
	var before := catalog.find_name(display_name)
	var base := display_name.trim_suffix(CardCatalog.UPGRADE_SUFFIX)
	return replace_card_version(display_name, base + CardCatalog.UPGRADE_SUFFIX if upgraded else base)

## Swaps one owned card for another record in place (upgrade toggle, saint growth).
func replace_card_version(display_name: String, target_name: String) -> bool:
	if not has_card(display_name): return false
	var before := catalog.find_name(display_name)
	var after := catalog.find_name(target_name)
	if after.is_empty() or after.name == before.name or has_card(after.name): return false
	# Replace in place: acquisition order, deployment and per-instance state survive.
	available[available.find(before)] = after
	levels[after.name] = level(before.name)
	levels.erase(before.name)
	for settings: Dictionary in [card_settings, down_cards]:
		if settings.has(before.name):
			settings[after.name] = settings[before.name]
			settings.erase(before.name)
	for slot: int in range(leaders.size()):
		if leaders[slot] == before.name: leaders[slot] = after.name
	skill_runtime.replace_card(before, after, catalog)
	card_replaced.emit(before.name, after.name)
	changed.emit()
	return true

func remove_relic(display_name: String) -> bool:
	if display_name not in relics: return false
	relics.erase(display_name)
	relic_counters.erase(display_name)
	changed.emit()
	return true

func acquire_relic(display_name: String, source_position := Vector2(960, 540)) -> bool:
	if display_name in relics: return false
	var database := RelicCatalog.new()
	if not database.load_catalog() or not database.by_name.has(display_name): return false
	relics.append(display_name)
	if RelicEffects.PERIODS.has(display_name): relic_counters[display_name] = 0
	RelicEffects.acquired(self, display_name)
	changed.emit()
	relic_acquired.emit(display_name, source_position)
	return true

func level(display_name: String) -> int:
	return int(levels.get(display_name, 0))

func set_level(display_name: String, value: int) -> void:
	if has_card(display_name):
		levels[display_name] = maxi(0, value)
		changed.emit()

func actual(card: Dictionary, stat: String, preview_upgrades: bool = false) -> float:
	# Preview uses upgraded base values with the owned card's stars; it never writes inventory.
	var display_card := catalog.upgrade_preview(card) if preview_upgrades else card
	return float(display_card["base_" + stat]) * pow(1.0 + 0.12 * level(card.name), 2.5)

func acquisition_gain(card: Dictionary, stat: String, preview_upgrades: bool = false) -> float:
	var owned_name := owned_version(card.name)
	var owned := not owned_name.is_empty()
	var next_level := level(owned_name) + (5 if owned and CardCatalog.is_upgraded(catalog.find_name(owned_name)) else 0)
	var display_card := catalog.upgrade_preview(card) if preview_upgrades or owned else card
	var next_value := float(display_card["base_" + stat]) * pow(1.0 + 0.12 * next_level, 2.5)
	return next_value - (actual(catalog.find_name(owned_name), stat, preview_upgrades) if owned else 0.0)

func leader_for_faction(faction: int) -> String:
	for display_name: String in leaders:
		if not display_name.is_empty() and catalog.find_name(display_name).faction == faction:
			return display_name
	return ""

func faction_stat(faction: int, stat: String, preview_upgrades: bool = false) -> float:
	var sum := 0.0
	for card: Dictionary in available:
		if card.faction == faction:
			sum += actual(card, stat, preview_upgrades)
	return sum

func deployed(card: Dictionary, stat: String, preview_upgrades: bool = false) -> float:
	return actual(card, stat, preview_upgrades) * ox_coefficient + faction_stat(card.faction, stat, preview_upgrades) - actual(card, stat, preview_upgrades)

func total(stat: String, preview_upgrades: bool = false) -> float:
	var sum := 0.0
	if stat == "at":
		for card: Dictionary in available:
			sum += actual(card, stat, preview_upgrades)
		return sum / available.size() * ox_coefficient if not available.is_empty() else 0.0
	for display_name: String in leaders:
		if not display_name.is_empty():
			sum += deployed(catalog.find_name(display_name), stat, preview_upgrades)
	return sum * (1.0 + rate("hp") / 100.0) if stat == "hp" else sum

func deploy(display_name: String, target: int = -1) -> bool:
	if display_name in leaders:
		return false
	var slot := deployment_slot(display_name, target)
	if slot < 0:
		return false
	var faction: int = catalog.find_name(display_name).faction
	# Replace the requested slot and unload any other leader of this faction atomically.
	for i: int in range(leaders.size()):
		var previous := leaders[i]
		if previous.is_empty() or (i != slot and catalog.find_name(previous).faction != faction): continue
		if battle_active and catalog.find_name(previous).identity != catalog.find_name(display_name).identity:
			_retire_character(previous)
		leaders[i] = ""
	if battle_active:
		skill_runtime.acted[display_name] = true
	leaders[slot] = display_name
	changed.emit()
	return true

func deployment_slot(display_name: String, target: int = -1) -> int:
	if not has_card(display_name) or is_unavailable(display_name):
		return -1
	var faction: int = catalog.find_name(display_name).faction
	if target != -1: return target if is_slot_unlocked(target) else -1
	var previous := leader_for_faction(faction)
	if not previous.is_empty():
		return leaders.find(previous)
	for slot: int in DEPLOYMENT_ORDER:
		if is_slot_unlocked(slot) and leaders[slot].is_empty():
			return slot
	return -1

func is_unavailable(display_name: String) -> bool:
	return is_faction_locked(display_name) or down_cards.has(display_name) or retired_characters.has(catalog.find_name(display_name).get("identity", ""))

func is_faction_locked(display_name: String) -> bool:
	return catalog.find_name(display_name).get("faction", 0) == 10 and not bonuses.get(6, false)

func move_leader(display_name: String, target: int) -> bool:
	var source := leaders.find(display_name)
	if source < 0 or not is_slot_unlocked(target) or source == target:
		return false
	var displaced := leaders[target]
	leaders[target] = display_name
	leaders[source] = displaced
	changed.emit()
	return true

func remove(display_name: String) -> void:
	var slot := leaders.find(display_name)
	if slot >= 0:
		if battle_active:
			_retire_character(display_name)
		leaders[slot] = ""
		changed.emit()

func begin_battle_formation_edit() -> void:
	if not battle_active or battle_formation_editing: return
	battle_formation_editing = true
	pending_retired_characters.clear()

func finish_battle_formation_edit() -> void:
	if not battle_formation_editing: return
	battle_formation_editing = false
	if battle_active:
		var deployed_identities: Dictionary = {}
		for actor: String in leaders:
			if not actor.is_empty(): deployed_identities[catalog.find_name(actor).identity] = true
		for identity: String in pending_retired_characters:
			if not deployed_identities.has(identity): retired_characters[identity] = true
	pending_retired_characters.clear()
	changed.emit()

func clear_battle_formation_edit() -> void:
	battle_formation_editing = false
	pending_retired_characters.clear()

func _retire_character(display_name: String) -> void:
	var identity: String = catalog.find_name(display_name).identity
	if battle_formation_editing: pending_retired_characters[identity] = true
	else: retired_characters[identity] = true

func rate(kind: String) -> float:
	var all := 3.0 * (int(bonuses.get(12, false)) + int(bonuses.get(13, false)))
	var value := 0.0
	match kind:
		"hp": value = all + (30.0 if bonuses.get(8, false) else 0.0)
		"physical": value = float(damage_rates.physical) + all + (30.0 if bonuses.get(9, false) else 0.0)
		"magic": value = float(damage_rates.magic) + all + (30.0 if bonuses.get(10, false) else 0.0)
		"physical_resist": value = float(resistance_rates.physical)
		"magic_resist": value = float(resistance_rates.magic)
	var formation := formation_effect_rates if battle_active else SkillFormationEffects.collect(self)
	value += float(formation.get(kind, 0.0)) + RelicEffects.troop_rate_bonus(self, kind)
	return minf(value, rate_cap())

func can_toggle_bonus(index: int) -> bool:
	if index not in BONUS_IDS or bonus_edit_locked or battle_active: return false
	if encyclopedia_mode or bonuses.get(index, false): return true
	if bonus_points < 1: return false
	return not (index in [1, 2, 13, 15] and not bonuses.get(index - 1, false))

func toggle_bonus(index: int) -> bool:
	if not can_toggle_bonus(index): return false
	var was_enabled: bool = bonuses.get(index, false)
	if not encyclopedia_mode: bonus_points += 1 if was_enabled else -1
	bonuses[index] = not was_enabled
	if was_enabled and index in [0, 1, 2, 6]: _normalize_leaders()
	changed.emit()
	return true

func _normalize_leaders() -> void:
	# Closing a slot unequips its card, then reuses another open slot if possible.
	# Inventory and card levels are retained when the reduced formation is full.
	var displaced: Array[String] = []
	for slot: int in range(leaders.size()):
		var name := leaders[slot]
		if name.is_empty(): continue
		var god_locked := is_faction_locked(name)
		if not is_slot_unlocked(slot) or god_locked:
			leaders[slot] = ""
			if not god_locked: displaced.append(name)
	for name: String in displaced:
		var slot := deployment_slot(name)
		if slot >= 0: leaders[slot] = name
