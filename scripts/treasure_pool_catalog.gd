extends RefCounted
class_name TreasurePoolCatalog
## TXT registers pool names. Membership follows cards.txt rarity automatically.
const POOL_NAMES := ["普通卡池", "精英卡池", "BOSS卡池"]
var pools: Dictionary = {}
var errors: PackedStringArray = []

func load_catalog(catalog: CardCatalog, path := "res://data/card_pools.txt") -> bool:
	pools.clear()
	errors.clear()
	var parsed := RecordTable.pool_names(path)
	if not parsed.error.is_empty(): errors.append(parsed.error)
	for name: String in parsed.names:
		var members: Array[Dictionary] = []
		for card: Dictionary in catalog.cards:
			if CardCatalog.is_upgraded(card): continue
			if name == "BOSS卡池" and int(card.rarity) != 3: continue
			members.append(card)
		pools[name] = members
	for name: String in POOL_NAMES:
		if not pools.has(name): errors.append("缺少卡池：" + name)
	if not errors.is_empty(): pools.clear()
	return errors.is_empty()
