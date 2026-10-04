extends RefCounted
class_name RecordTable
## Strict brace/semicolon records. Strings use JSON escaping; # comments occupy whole lines.

static func parse(source: String) -> Dictionary:
	var cleaned := ""
	for line: String in source.split("\n"):
		if not line.strip_edges().begins_with("#"):
			cleaned += line + "\n"
	var rows: Array = []
	var token := ""
	var quoted := false
	var escaped := false
	for ch: String in cleaned:
		if ch == ";" and not quoted:
			var record := token.strip_edges()
			if not record.begins_with("{") or not record.ends_with("}"):
				return {"error": "记录必须使用 { ... };", "rows": []}
			var json := JSON.new()
			if json.parse("[" + record.substr(1, record.length() - 2) + "]") != OK or not json.data is Array:
				return {"error": "记录 %d 格式错误：%s" % [rows.size() + 1, json.get_error_message()], "rows": []}
			rows.append(json.data)
			token = ""
			continue
		token += ch
		if escaped:
			escaped = false
		elif ch == "\\" and quoted:
			escaped = true
		elif ch == '"':
			quoted = not quoted
	if not token.strip_edges().is_empty():
		return {"error": "末尾记录缺少分号或引号未闭合", "rows": []}
	return {"error": "", "rows": rows}

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floor(float(value))
