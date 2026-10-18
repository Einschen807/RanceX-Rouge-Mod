extends RefCounted
class_name ShopInventory
## Stock and price rolls are generated once at the shop's node entrance.
const CARD_PRICES := {1: 50, 2: 75, 3: 150}
const RELIC_PRICES := {1: 175, 2: 225, 3: 275, 4: 200}

static func generate(troop: TroopState, rng: RandomNumberGenerator) -> Dictionary:
	var items: Array[Dictionary] = []
	var cards: Array = troop.catalog.cards.filter(func(c: Dictionary) -> bool: return int(c.rarity) > 0 and not CardCatalog.is_upgraded(c))
	for i: int in range(8):
		if cards.is_empty(): break
		var index := rng.randi_range(0, cards.size() - 1)
		var card: Dictionary = cards.pop_at(index)
		items.append(_offer("card", card.name, CARD_PRICES[card.rarity], rng.randf_range(-0.05, 0.05)))
	var relics := RelicCatalog.new()
	if not relics.load_catalog(): return {}
	var excluded: Array[String] = troop.relics.duplicate()
	for i: int in range(3):
		var pool := "商店遗物池" if i == 2 else "默认遗物池"
		var record := relics.draw(pool, excluded, rng)
		if record.is_empty():
			items.append(_offer("relic", "", 0, 0.0, true))
		else:
			excluded.append(record.name)
			items.append(_offer("relic", record.name, RELIC_PRICES[record.rarity], rng.randf_range(-0.15, 0.15)))
	return {"version": 2, "items": items}

static func _offer(kind: String, id: String, base: int, variation: float, unavailable := false) -> Dictionary:
	return {"kind": kind, "id": id, "base": base, "variation": variation, "sold": false, "unavailable": unavailable}

static func price(offer: Dictionary, troop: TroopState) -> int:
	return maxi(1, roundi(float(offer.base) * (1.0 + float(offer.variation)) * RelicEffects.shop_discount(troop)))

static func buy(stock: Dictionary, index: int, troop: TroopState, at: Vector2) -> String:
	if index < 0 or index >= stock.items.size(): return "商品不存在。"
	var offer: Dictionary = stock.items[index]
	if offer.sold or offer.unavailable: return "该商品无法购买。"
	if offer.kind == "relic" and offer.id in troop.relics: return "已拥有该遗物。"
	var cost := price(offer, troop)
	if troop.gold < cost: return "金币不足。"
	# Commit cost and sold state before inventory emits its synchronous UI signals.
	troop.gold -= cost
	offer.sold = true
	if offer.kind == "card":
		troop.acquire_card(offer.id)
	elif not troop.acquire_relic(offer.id, at):
		troop.gold += cost
		offer.sold = false
		return "无法获得该遗物。"
	return ""

static func from_saved(stock: Dictionary) -> Dictionary:
	if stock.get("version") == 2: return stock
	# Version 1 reserved three disabled trailing slots; retain only real merchandise.
	if stock.get("version") != 1 or not stock.get("items") is Array or stock.items.size() != 14: return {}
	for entry: Variant in stock.items.slice(11):
		if not entry is Dictionary or entry.get("unavailable") != true or entry.get("sold") != false or entry.get("base") != 0 or entry.get("variation") != 0: return {}
	return {"version": 2, "items": stock.items.slice(0, 11).duplicate(true)}

static func valid(stock: Dictionary, catalog: CardCatalog) -> bool:
	stock = from_saved(stock)
	if stock.get("version") != 2 or not stock.get("items") is Array or stock.items.size() != 11: return false
	var relics := RelicCatalog.new()
	if not relics.load_catalog(): return false
	var seen: Array[String] = []
	for index: int in range(11):
		var offer: Variant = stock.items[index]
		if not offer is Dictionary or not offer.get("id") is String or not offer.get("sold") is bool or not offer.get("unavailable") is bool or not RecordTable.integer(offer.get("base")) or not TroopCheckpoint._number(offer.get("variation")): return false
		var kind := "card" if index < 8 else "relic"
		if offer.get("kind") != kind: return false
		if kind == "relic" and offer.id.is_empty():
			if not offer.unavailable or offer.base != 0 or offer.variation != 0 or offer.sold: return false
			continue
		if offer.unavailable or offer.id in seen: return false
		seen.append(offer.id)
		if kind == "card":
			var card := catalog.find_name(offer.id)
			if card.is_empty() or int(card.rarity) == 0 or CardCatalog.is_upgraded(card) or offer.base != CARD_PRICES[card.rarity] or absf(offer.variation) > 0.050001: return false
		else:
			var relic: Dictionary = relics.by_name.get(offer.id, {})
			if relic.is_empty() or offer.base != RELIC_PRICES[relic.rarity] or absf(offer.variation) > 0.150001: return false
			if (index == 10) != (relic.rarity == 4): return false
	return true
