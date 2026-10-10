extends RefCounted
class_name TreasureChest
## One opened chest owns its offers and selection. Returning to loot never rerolls it.
var offers: Array[Dictionary] = []
var selected: Array[int] = []
var pool_id := 1
var limit := 2
var claimed := false
var bias_before := 0
var bias_after := 0

static func probabilities(type: int, bias: int) -> Array[int]:
	if type == 3: return [0, 0, 100]
	var rare := mini(100, (10 if type == 2 else 3) + maxi(0, bias))
	var common := maxi(0, (50 if type == 2 else 60) - maxi(0, bias))
	return [common, 100 - common - rare, rare]

static func open(type: int, troop: TroopState, rng: RandomNumberGenerator, pools: TreasurePoolCatalog) -> TreasureChest:
	if type not in [0, 1, 2, 3] or pools.pools.is_empty(): return null
	var chest := TreasureChest.new()
	chest.pool_id = 1 if type == 0 else type
	chest.limit = 1 if type == 3 else 2
	chest.bias_before = troop.rare_card_bias
	var odds := probabilities(type, chest.bias_before)
	var members: Array = pools.pools[TreasurePoolCatalog.POOL_NAMES[chest.pool_id - 1]]
	var used: Array[String] = []
	for slot: int in range(3 if type == 3 else 5):
		var roll := rng.randf() * 100.0
		var rarity := 1 if roll < odds[0] else (2 if roll < odds[0] + odds[1] else 3)
		var tier: Array = members.filter(func(card: Dictionary) -> bool: return int(card.rarity) == rarity)
		# Repeat only when this rarity's configured pool has no unused member.
		var fresh: Array = tier.filter(func(card: Dictionary) -> bool: return card.name not in used)
		var choices: Array = fresh if not fresh.is_empty() else tier
		if choices.is_empty(): return null
		var card: Dictionary = choices[rng.randi_range(0, choices.size() - 1)]
		chest.offers.append(card)
		used.append(card.name)
	var has_rare := chest.offers.any(func(card: Dictionary) -> bool: return int(card.rarity) == 3)
	troop.rare_card_bias = 0 if has_rare else mini(100, troop.rare_card_bias + 1)
	chest.bias_after = troop.rare_card_bias
	troop.changed.emit()
	return chest

func claim_card(index: int, troop: TroopState) -> bool:
	if claimed or index < 0 or index >= offers.size(): return false
	if index in selected: return false
	if selected.size() >= limit: return false
	selected.append(index)
	troop.acquire_card(offers[index].name)
	return true

func finish() -> void:
	claimed = true
