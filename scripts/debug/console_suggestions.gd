extends RefCounted
class_name ConsoleSuggestions
## Completion candidates for the debug console. Command words match by prefix or substring;
## arguments match any name containing the typed text (case-insensitive), prefix matches first.
## Each suggestion: {"text": full line after completing, "label": shown text, "hint": gray note}.
const LIMIT := 400
## {prefix, argument kind, usage}. Argument kinds are listed in _names(); "" takes no argument,
## "value" takes a typed number without a candidate list.
const COMMANDS := [
	["help", "", "显示全部命令"],
	["travel", "", "切换自由移动"],
	["shop", "shop", "[商店名] — 打开商店"],
	["gold", "value", "数量 — 添加贝壳"],
	["pay", "value", "数量 — 支付贝壳"],
	["heal", "value", "百分比 — 恢复最大HP"],
	["hurt", "value", "百分比 — 失去最大HP"],
	["maxhp", "value", "百分比 — HP增加率提升"],
	["battle", "monster", "怪物识别名 — 进入指定战斗"],
	["event", "event", "事件名 — 强制进入事件"],
	["treasure", "treasure", "0|1|2|3 — 打开卡牌宝箱"],
	["relic", "relic_pool", "[遗物池名称] — 打开遗物宝箱"],
	["add relic", "relic", "遗物名称 — 获得遗物"],
	["add card", "card", "卡牌名称 — 获得卡牌"],
	["add curse", "curse", "诅咒名称 — 获得诅咒"],
	["add medal", "value", "数量 — 添加勋章"],
	["choose relic", "relic_list", "名称|名称|… — 选择1件遗物"],
	["random relic", "count_relic_list", "数量 名称|名称|… — 随机获得遗物"],
	["delet relic", "owned_relic", "遗物名称 — 删除持有遗物"],
	["upgrade", "value", "[数量] — 选择卡牌强化"],
	["upgrade test", "", "切换百科卡牌总览的全部强化"],
	["upgrade initial", "", "直接强化初始卡组（冒险中）"],
	["enchantment", "enchantment", "附魔名 — 选择卡牌技能附魔"],
	["roulette", "roulette", "50|100|all — 赌场轮盘"],
]
## Returns the holder's relic names for 「delet relic」; set by the console.
var owned_relics: Callable
var _cache: Dictionary = {}

func suggest(line: String) -> Array[Dictionary]:
	var text := line.strip_edges(true, false)
	if text.is_empty(): return []
	var lower := text.to_lower()
	# Longest command first, so 「upgrade test」 and 「add card」 win over shorter words.
	var templates := COMMANDS.duplicate()
	templates.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]).length() > String(b[0]).length())
	for template: Array in templates:
		var prefix: String = template[0]
		if not lower.begins_with(prefix + " "): continue
		# Typed values have no list; 「upgrade t」 can still complete to 「upgrade test」.
		if String(template[1]) in ["", "value"]: break
		return _arguments(prefix, String(template[1]), text.substr(prefix.length() + 1))
	return _commands(lower.strip_edges())

func _commands(query: String) -> Array[Dictionary]:
	var first: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for template: Array in COMMANDS:
		var prefix: String = template[0]
		var usage: String = template[2]
		if not (prefix.contains(query) or usage.contains(query)): continue
		var entry := {"text": prefix + ("" if String(template[1]).is_empty() else " "), "label": prefix, "hint": usage}
		(first if prefix.begins_with(query) else rest).append(entry)
	first.append_array(rest)
	return first

func _arguments(prefix: String, kind: String, argument: String) -> Array[Dictionary]:
	var head := prefix + " "
	var query := argument.strip_edges()
	if kind == "count_relic_list":
		# 「random relic 数量 名称|…」: the list starts after the count.
		var parts := argument.strip_edges(true, false).split(" ", false, 1)
		if parts.size() < 2 and not argument.ends_with(" "): return []
		head += parts[0] + " "
		argument = parts[1] if parts.size() == 2 else ""
		kind = "relic_list"
	if kind == "relic_list":
		# Complete only the name being typed after the last 「|」.
		var cut := argument.rfind("|")
		head += argument.substr(0, cut + 1) if cut >= 0 else ""
		query = argument.substr(cut + 1).strip_edges()
		kind = "relic"
	var first: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	var needle := query.to_lower()
	for entry: Array in _names(kind):
		var name: String = entry[0]
		var lowered := name.to_lower()
		if not needle.is_empty() and not lowered.contains(needle): continue
		var suggestion := {"text": head + name, "label": head + name, "hint": entry[1]}
		(first if lowered.begins_with(needle) else rest).append(suggestion)
	first.append_array(rest)
	return first.slice(0, LIMIT)

## [name, hint] pairs for one argument kind; catalogs load once, held relics are read live.
func _names(kind: String) -> Array:
	if kind == "owned_relic":
		var result: Array = []
		for name: Variant in (owned_relics.call() if owned_relics.is_valid() else []):
			result.append([String(name), _hint_for("relic", String(name))])
		return result
	return _cached(kind)

func _hint_for(kind: String, name: String) -> String:
	for entry: Array in _cached(kind):
		if entry[0] == name: return entry[1]
	return ""

func _cached(kind: String) -> Array:
	if _cache.has(kind): return _cache[kind]
	var result: Array = []
	match kind:
		"enchantment":
			for record: Dictionary in CardEnchantments.shared().entries: result.append([record.name, _line(record.description)])
		"card":
			var cards := _card_catalog()
			if cards != null:
				for card: Dictionary in cards.cards:
					if not CardCatalog.is_upgraded(card): result.append([card.name, CardCatalog.FACTIONS[int(card.faction) - 1]])
		"relic", "relic_pool":
			var relics := RelicCatalog.new()
			if relics.load_catalog():
				if kind == "relic":
					for record: Dictionary in relics.entries: result.append([record.name, _line(String(record.get("description", "")))])
				else:
					for pool: String in relics.pools: result.append([pool, "%d件遗物" % (relics.pools[pool] as Array).size()])
		"curse":
			for record: Dictionary in CurseCatalog.shared().entries: result.append([record.name, _line(record.description)])
		"monster":
			var cards := _card_catalog()
			var monsters := MonsterCatalog.new()
			if cards != null and monsters.load_catalog(cards.skills):
				for identity: String in monsters.monsters: result.append([identity, String(monsters.monsters[identity].get("name", ""))])
		"event":
			var events := EventCatalog.new()
			if events.load_catalog():
				for identity: String in events.records: result.append([identity, ""])
		"shop":
			var manager := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("ShopManager")
			if manager != null:
				for variant: String in manager.VARIANTS: result.append([variant, String(manager.VARIANTS[variant])])
		"roulette":
			result = [["50", "押注50贝壳"], ["100", "押注100贝壳"], ["all", "梭哈：押上全部贝壳"]]
		"treasure":
			result = [["0", ""], ["1", ""], ["2", ""], ["3", ""]]
	_cache[kind] = result
	return result

func _card_catalog() -> CardCatalog:
	if _cache.has("_cards"): return _cache["_cards"]
	var cards := CardCatalog.new()
	_cache["_cards"] = cards if cards.load_catalog() else null
	return _cache["_cards"]

## First line of a description, as a one-row hint.
static func _line(description: String) -> String:
	return description.split("\n")[0].strip_edges()
