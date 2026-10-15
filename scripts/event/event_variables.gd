extends RefCounted
class_name EventVariables
const TOKENS := ["%友方随机遗物", "%随机遗物", "%普通遗物", "%罕见遗物", "%稀有遗物"]

static func resolve(event: Dictionary, troop: TroopState, rng: RandomNumberGenerator) -> Dictionary:
	var result := event.duplicate(true)
	var relics := RelicCatalog.new()
	var loaded := relics.load_catalog()
	var used: Dictionary = {}
	for option: Dictionary in result.options:
		# One binding table per option, shared by its prose and its commands.
		var bindings := {}
		var error := ""
		for token: String in TOKENS:
			if not option.text.contains(token) and not option.command.contains(token): continue
			var name := ""
			if not loaded:
				error = "遗物数据加载失败。"
			elif token == "%友方随机遗物":
				var owned: Array = troop.relics.filter(func(owned_name: String) -> bool: return relics.by_name.has(owned_name))
				var fresh: Array = owned.filter(func(owned_name: String) -> bool: return owned_name not in used.get(token, []))
				if not fresh.is_empty(): owned = fresh
				else: used[token] = []
				if not owned.is_empty(): name = owned[rng.randi_range(0, owned.size() - 1)]
				else: error = "当前没有持有的遗物。"
			elif token == "%随机遗物":
				var excluded: Array[String] = troop.relics.duplicate()
				for used_name: String in used.get(token, []):
					if used_name not in excluded: excluded.append(used_name)
				var drawn := relics.draw("默认遗物池", excluded, rng)
				if drawn.is_empty() and not used.get(token, []).is_empty():
					used[token] = []
					drawn = relics.draw("默认遗物池", troop.relics, rng)
				if not drawn.is_empty(): name = drawn.name
				else: error = "默认遗物池没有可获得的遗物。"
			else:
				var rarity := TOKENS.find(token) - 1
				var candidates: Array = relics.pools.get("默认遗物池", []).filter(func(record: Dictionary) -> bool: return record.rarity == rarity and record.name not in troop.relics)
				var fresh: Array = candidates.filter(func(record: Dictionary) -> bool: return record.name not in used.get(token, []))
				if not fresh.is_empty(): candidates = fresh
				else: used[token] = []
				if not candidates.is_empty(): name = candidates[rng.randi_range(0, candidates.size() - 1)].name
				else: error = "当前没有可获得的%s遗物。" % RelicCatalog.RARITIES[rarity - 1]
			bindings[token] = name
			if not name.is_empty():
				if not used.has(token): used[token] = []
				used[token].append(name)
			option.text = option.text.replace(token, name if not name.is_empty() else "（无可用遗物）")
			option.command = option.command.replace(token, name)
		option["variables"] = bindings
		option["unavailable"] = error
		if not error.is_empty(): option.text += "\n" + error
	return result
