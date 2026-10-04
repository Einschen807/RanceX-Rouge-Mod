extends RefCounted
class_name BattleConditions
## Small declarative grammar; data files cannot execute expressions or scripts.

static func valid(condition: String) -> bool:
	if condition.strip_edges() in ["", "ALWAYS", "COMBO0"]:
		return true
	var pattern := RegEx.new()
	pattern.compile("^(ROUND|HP|PLAYER_HP|COMBO)(?:%([1-9][0-9]*))?(<=|>=|==|!=|<|>)([0-9]+(?:\\.[0-9]+)?)(%)?$")
	for alternative: String in condition.split("|"):
		for part: String in alternative.split("&"):
			var match_result := pattern.search(part.strip_edges().replace(" ", ""))
			if match_result == null:
				return false
			if match_result.get_string(5) == "%" and match_result.get_string(1) not in ["HP", "PLAYER_HP"]:
				return false
	return true

static func met(condition: String, context: Dictionary) -> bool:
	condition = condition.strip_edges()
	if condition.strip_edges() in ["", "ALWAYS"]:
		return true
	if condition == "COMBO0":
		return int(context.get("combo", 0)) == 0
	if not valid(condition):
		return false
	var pattern := RegEx.new()
	pattern.compile("^(ROUND|HP|PLAYER_HP|COMBO)(?:%([1-9][0-9]*))?(<=|>=|==|!=|<|>)([0-9]+(?:\\.[0-9]+)?)(%)?$")
	for alternative: String in condition.split("|"):
		var matches := true
		for part: String in alternative.split("&"):
			var parsed := pattern.search(part.strip_edges().replace(" ", ""))
			var key := parsed.get_string(1).to_lower()
			var value := float(context.get(key, 0.0))
			if parsed.get_string(5) == "%":
				value = value / maxf(1.0, float(context.get(key + "_max", 1.0))) * 100.0
			if not parsed.get_string(2).is_empty():
				value = fmod(value, float(parsed.get_string(2)))
			var target := float(parsed.get_string(4))
			match parsed.get_string(3):
				"<=": matches = matches and value <= target
				">=": matches = matches and value >= target
				"<": matches = matches and value < target
				">": matches = matches and value > target
				"==": matches = matches and absf(value - target) <= 0.000001
				"!=": matches = matches and absf(value - target) > 0.000001
		if matches:
			return true
	return false
