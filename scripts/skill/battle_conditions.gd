extends RefCounted
class_name BattleConditions
## Shared declarative conditions: parse data, never execute expressions or scripts.
static var _cache: Dictionary = {}

static func valid(condition: String) -> bool:
	return bool(_compiled(condition).ok)

static func met(condition: String, context: Dictionary) -> bool:
	var compiled := _compiled(condition)
	if not compiled.ok: return false
	var values: Array[bool] = []
	for term: Dictionary in compiled.terms:
		if term.kind in ["&", "|"]:
			var right: bool = values.pop_back()
			var left: bool = values.pop_back()
			values.append(left and right if term.kind == "&" else left or right)
		else:
			values.append(_matches(term, context))
	return values[0]

static func _compact(text: String) -> String:
	return text.replace(" ", "").replace("\t", "").replace("\r", "").replace("\n", "").replace("　", "")

static func _match(pattern: String, text: String) -> RegExMatch:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.search(text)

static func _side(prefix: String) -> String:
	return "player" if prefix == "友方" else "enemy"

static func _comparison(suffix: String) -> String:
	return ">=" if suffix == "以上" else ("<=" if suffix == "以下" else "==")

static func _atom(text: String) -> Dictionary:
	var clean := _compact(text)
	if clean == "ALWAYS": return {"kind": "always"}
	# Keep names intact, including spaces, parentheses and operator characters.
	var found := _match("^(友方|敌方)\\s*支援\\s*存在\\s*\\[([^\\[\\]]+)\\]$", text.strip_edges())
	if found != null:
		var name := found.get_string(2).strip_edges()
		return {} if name.is_empty() else {"kind": "support", "key": _side(found.get_string(1)) + "_supports", "name": name}
	found = _match("^存在支援\\[([^\\[\\]]+)\\]$", text.strip_edges())
	if found != null:
		var name := found.get_string(1).strip_edges()
		return {} if name.is_empty() else {"kind": "support", "key": "supports", "name": name}
	found = _match("^(友方|敌方)\\s*异常\\s*存在\\s*<([^<>]+)>$", text.strip_edges())
	if found != null:
		var name := found.get_string(2).strip_edges()
		return {} if name not in BattleStatusEffects.NAMES else {"kind": "status", "key": _side(found.get_string(1)) + "_statuses", "name": name}
	found = _match("^(COMBO|AP)([0-9]+)(以上|以下)?$", clean)
	if found != null:
		return {"kind": "number", "key": found.get_string(1).to_lower(), "operator": _comparison(found.get_string(3)), "target": float(found.get_string(2))}
	found = _match("^(友方|敌方)(支援|异常)([0-9]+)(以上|以下)?$", clean)
	if found != null:
		var key := _side(found.get_string(1)) + ("_supports" if found.get_string(2) == "支援" else "_statuses")
		return {"kind": "count", "key": key, "operator": _comparison(found.get_string(4)), "target": float(found.get_string(3))}
	found = _match("^(友方|敌方)HP([0-9]+(?:\\.[0-9]+)?)(?:%)?(以上|以下)$", clean)
	if found != null:
		var target := float(found.get_string(2))
		if target > 100.0: return {}
		return {"kind": "number", "key": _side(found.get_string(1)) + "_hp", "operator": _comparison(found.get_string(3)), "target": target, "percent": true}
	found = _match("^回合数([0-9]+)(以上|以下|倍数)?$", clean)
	if found != null:
		var target := float(found.get_string(1))
		if found.get_string(2) == "倍数":
			return {} if target <= 0.0 else {"kind": "number", "key": "round", "operator": "==", "target": 0.0, "modulus": target}
		return {"kind": "number", "key": "round", "operator": _comparison(found.get_string(2)), "target": target}
	# Existing data keeps its original self-relative HP/support semantics.
	found = _match("^(ROUND|HP|PLAYER_HP|COMBO|AP)(?:%([1-9][0-9]*))?(<=|>=|==|!=|<|>)([0-9]+(?:\\.[0-9]+)?)(%)?$", clean)
	if found == null: return {}
	if found.get_string(5) == "%" and found.get_string(1) not in ["HP", "PLAYER_HP"]: return {}
	var term := {"kind": "number", "key": found.get_string(1).to_lower(), "operator": found.get_string(3), "target": float(found.get_string(4)), "legacy": true}
	if not found.get_string(2).is_empty(): term.modulus = float(found.get_string(2))
	if found.get_string(5) == "%": term.percent = true
	return term

static func _tokens(condition: String) -> PackedStringArray:
	var result := PackedStringArray()
	var cursor := 0
	while cursor < condition.length():
		var character := condition[cursor]
		if _compact(character).is_empty():
			cursor += 1
			continue
		if character in ["(", ")", "&", "|"]:
			result.append(character)
			cursor += 2 if character == "&" and condition.substr(cursor, 2) == "&&" else 1
			continue
		var start := cursor
		while cursor < condition.length():
			character = condition[cursor]
			if character in ["(", ")", "&", "|"]: break
			var status_name := character == "<" and _compact(condition.substr(start, cursor - start)) in ["友方异常存在", "敌方异常存在"]
			if character == "[" or status_name:
				var end := condition.find("]" if character == "[" else ">", cursor + 1)
				if end < 0: return PackedStringArray()
				cursor = end + 1
			else:
				cursor += 1
		result.append(condition.substr(start, cursor - start).strip_edges())
	return result

static func _priority(operator: String) -> int:
	return 2 if operator == "&" else 1

static func _compiled(condition: String) -> Dictionary:
	condition = condition.strip_edges()
	if not _cache.has(condition):
		_cache[condition] = _compile(condition)
	return _cache[condition]

static func _compile(condition: String) -> Dictionary:
	var invalid := {"ok": false, "terms": []}
	if condition.is_empty(): return {"ok": true, "terms": [{"kind": "always"}]}
	var tokens := _tokens(condition)
	if tokens.is_empty(): return invalid
	var terms: Array[Dictionary] = []
	var operators: Array[String] = []
	var expect_atom := true
	for token: String in tokens:
		if token == "(":
			if not expect_atom: return invalid
			operators.append(token)
		elif token == ")":
			if expect_atom: return invalid
			while not operators.is_empty() and operators[-1] != "(": terms.append({"kind": operators.pop_back()})
			if operators.is_empty(): return invalid
			operators.pop_back()
		elif token in ["&", "|"]:
			if expect_atom: return invalid
			while not operators.is_empty() and operators[-1] != "(" and _priority(operators[-1]) >= _priority(token):
				terms.append({"kind": operators.pop_back()})
			operators.append(token)
			expect_atom = true
		else:
			if not expect_atom: return invalid
			var term := _atom(token)
			if term.is_empty(): return invalid
			terms.append(term)
			expect_atom = false
	if expect_atom: return invalid
	while not operators.is_empty():
		var operator: String = operators.pop_back()
		if operator == "(": return invalid
		terms.append({"kind": operator})
	return {"ok": true, "terms": terms}

static func _compare(value: float, operator: String, target: float) -> bool:
	match operator:
		"<=": return value <= target
		">=": return value >= target
		"<": return value < target
		">": return value > target
		"==": return absf(value - target) <= 0.000001
		"!=": return absf(value - target) > 0.000001
	return false

static func _matches(term: Dictionary, context: Dictionary) -> bool:
	if term.kind == "always": return true
	if not context.has(term.key) and not term.get("legacy", false): return false
	if term.kind in ["support", "status", "count"]:
		var list: Array = context.get(term.key, [])
		if term.kind == "count": return _compare(float(list.size()), term.operator, term.target)
		for item: Variant in list:
			if item is Dictionary:
				if term.name == item.get("name", "") or term.name == item.get("identity", ""): return true
			elif term.name == str(item): return true
		return false
	var value := float(context.get(term.key, 0.0))
	if term.get("percent", false):
		var maximum := float(context.get(term.key + "_max", 0.0))
		if not term.get("legacy", false) and maximum <= 0.0: return false
		value = value / (maxf(1.0, maximum) if term.get("legacy", false) else maximum) * 100.0
	if term.has("modulus"): value = fmod(value, float(term.modulus))
	return _compare(value, term.operator, term.target)
