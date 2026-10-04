extends RefCounted
class_name TroopState
## Shared formation model. Encyclopedia creates its own state, never granting run inventory.
signal changed
var catalog: CardCatalog
var available: Array[Dictionary] = []
var leaders: Array[String] = ["", "", "", "", "", "", ""]
var levels: Dictionary = {}
var ox_coefficient := 5.0
var bonuses: Dictionary = {}
var bonus_points := 0
var encyclopedia_mode := false
var skill_runtime := SkillRuntime.new()
const DEPLOYMENT_ORDER := [3, 2, 4, 1, 5, 0, 6]
const BONUS_NAMES := ["增加领队格子 +1", "增加领队格子 +1", "增加领队格子 +1", "AP最大值强化 6→10", "AP恢复强化 偶数回合+1", "更换领队", "神魔阵营解禁", "强化出现概率 +100%", "HP增加 +30%", "物理伤害增加 +30%", "魔法伤害增加 +30%", "哈尼打火机", "全面强化 +3%", "全面强化 +3%", "上限解除 +25%", "上限解除 +25%"]

func configure(database: CardCatalog, encyclopedia: bool, owned_names: Array[String] = []) -> void:
	catalog = database
	encyclopedia_mode = encyclopedia
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

func deploy(display_name: String) -> bool:
	if display_name in leaders:
		return false
	var slot := deployment_slot(display_name)
	if slot < 0:
		return false
	leaders[slot] = display_name
	changed.emit()
	return true

func deployment_slot(display_name: String) -> int:
	if not has_card(display_name):
		return -1
	var faction: int = catalog.find_name(display_name).faction
	var previous := leader_for_faction(faction)
	if not previous.is_empty():
		return leaders.find(previous)
	for slot: int in DEPLOYMENT_ORDER:
		if leaders[slot].is_empty():
			return slot
	return -1

func move_leader(display_name: String, target: int) -> bool:
	var source := leaders.find(display_name)
	if source < 0 or target < 0 or target >= leaders.size() or source == target:
		return false
	var displaced := leaders[target]
	leaders[target] = display_name
	leaders[source] = displaced
	changed.emit()
	return true

func remove(display_name: String) -> void:
	var slot := leaders.find(display_name)
	if slot >= 0:
		leaders[slot] = ""
		changed.emit()

func rate(kind: String) -> float:
	var all := 3.0 * (int(bonuses.get(12, false)) + int(bonuses.get(13, false)))
	match kind:
		"hp": return all + (30.0 if bonuses.get(8, false) else 0.0)
		"physical": return all + (30.0 if bonuses.get(9, false) else 0.0)
		"magic": return all + (30.0 if bonuses.get(10, false) else 0.0)
	return 0.0

func toggle_bonus(index: int) -> bool:
	if index < 0 or index >= BONUS_NAMES.size():
		return false
	if not encyclopedia_mode:
		return false # Real acquisition is provided by the future run reward flow.
	bonuses[index] = not bonuses.get(index, false)
	changed.emit()
	return true
