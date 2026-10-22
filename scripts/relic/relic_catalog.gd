extends RefCounted
class_name RelicCatalog
## 5 特殊: obtained only through dedicated commands or events, never drawn from a pool.
const RARITIES := ["普通", "罕见", "稀有", "商店", "特殊"]
var entries: Array[Dictionary] = []
var by_name: Dictionary = {}
var pools: Dictionary = {}
var errors: PackedStringArray = []

func load_catalog(path := "res://data/relics.txt", pool_path := "res://data/relic_pools.txt") -> bool:
	entries.clear()
	by_name.clear()
	pools.clear()
	errors.clear()
	if not FileAccess.file_exists(path):
		errors.append("遗物文件不存在：" + path)
		return false
	var parsed := RecordTable.parse(FileAccess.get_file_as_string(path))
	if not parsed.error.is_empty(): errors.append(parsed.error)
	for row: Array in parsed.rows:
		if row.size() != 4 or not row[0] is String or not row[1] is String or not RecordTable.integer(row[2]) or not row[3] is String:
			errors.append("遗物记录应为名称、图标、稀有度、描述")
			continue
		if row[0].is_empty() or by_name.has(row[0]) or int(row[2]) not in [1, 2, 3, 4, 5] or not ResourceLoader.exists("res://assets/relics/%s.png" % row[1]):
			errors.append("遗物名称、稀有度或图标无效：" + row[0])
			continue
		# Same convention as skill descriptions: a lowercase r is a line break.
		var record := {"name": row[0], "icon": row[1], "rarity": int(row[2]), "description": String(row[3]).replace("r", "\n")}
		entries.append(record)
		by_name[record.name] = record
	var names := RecordTable.pool_names(pool_path)
	if not names.error.is_empty(): errors.append(names.error)
	for pool: String in names.names:
		pools[pool] = entries.filter(func(r: Dictionary) -> bool: return r.rarity == 4 if pool == "商店遗物池" else r.rarity in [1, 2, 3])
	if not pools.has("默认遗物池"): errors.append("缺少默认遗物池")
	if not errors.is_empty():
		entries.clear()
		by_name.clear()
		pools.clear()
	return errors.is_empty()

func draw(pool: String, owned: Array[String], rng: RandomNumberGenerator) -> Dictionary:
	var candidates: Array = pools.get(pool, []).filter(func(r: Dictionary) -> bool: return r.name not in owned)
	if candidates.is_empty(): return {}
	if pool == "商店遗物池": return candidates[rng.randi_range(0, candidates.size() - 1)]
	# Empty rarity tiers reroll; weighting available tiers is equivalent and bounded.
	var weighted: Array[Dictionary] = []
	var total := 0
	for rarity: int in [1, 2, 3]:
		var tier: Array = candidates.filter(func(r: Dictionary) -> bool: return r.rarity == rarity)
		if tier.is_empty(): continue
		total += int([50, 33, 17][rarity - 1])
		weighted.append({"end": total, "entries": tier})
	var roll := rng.randi_range(1, total)
	for tier: Dictionary in weighted:
		if roll <= tier.end: return tier.entries[rng.randi_range(0, tier.entries.size() - 1)]
	return {}
