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

static func pool_names(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"names": [], "error": "池文件不存在：" + path}
	var source := ""
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"): source += line + "\n"
	source = source.replace("；", ";").strip_edges()
	if not source.ends_with(";"): return {"names": [], "error": "池记录缺少分号"}
	var names: Array[String] = []
	for raw: String in source.split(";", false):
		var record := raw.strip_edges()
		if record.is_empty(): continue
		if not record.begins_with("{") or not record.ends_with("}"): return {"names": [], "error": "池名称须使用{名称};"}
		var name := record.substr(1, record.length() - 2).strip_edges()
		if name.begins_with('"'):
			var quoted: Variant = JSON.parse_string(name)
			if not quoted is String: return {"names": [], "error": "池记录只能填写名称"}
			name = quoted
		if name.is_empty() or name.contains(",") or name.contains("{") or name.contains("}") or name in names: return {"names": [], "error": "池名称为空、重复或包含成员"}
		names.append(name)
	return {"names": names, "error": ""}

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floor(float(value))
