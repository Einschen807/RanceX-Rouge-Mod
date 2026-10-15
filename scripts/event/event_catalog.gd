extends RefCounted
class_name EventCatalog
## Events own their map membership; there is no separate event-pool table.
const POOLS := ["一层荒野", "一层遗迹", "二层利萨斯", "二层自由都市", "二层卡拉之森", "三层赫尔曼", "三层JAPAN", "三层赛斯", "四层魔界"]
var records: Dictionary = {}
var errors: PackedStringArray = []

func load_catalog(path := "res://data/events.txt") -> bool:
	if not FileAccess.file_exists(path):
		records.clear()
		errors = PackedStringArray(["事件文件不存在：" + path])
		return false
	return load_text(FileAccess.get_file_as_string(path))

func load_text(source: String) -> bool:
	records.clear()
	errors.clear()
	var parsed := _parse(source)
	if not parsed.error.is_empty():
		errors.append(parsed.error)
		return false
	for row: Array in parsed.rows:
		if row.size() < 8 or (row.size() - 6) % 2 != 0 or not row.all(func(value: Variant) -> bool: return value is String):
			errors.append("事件必须为六个字符串字段，后接成对的选项说明、控制台指令（至少一组）")
			continue
		var id: String = row[0].strip_edges()
		var pool: String = row[4].strip_edges().trim_suffix("事件池")
		if id.is_empty() or records.has(id) or row[1].strip_edges().is_empty():
			errors.append("事件名、标题不能为空，事件名不能重复：" + id)
			continue
		if not pool.is_empty() and pool not in POOLS:
			errors.append("未知事件地图池：" + pool)
			continue
		var condition := parse_condition(row[5])
		if not condition.error.is_empty():
			errors.append(id + "：" + condition.error)
			continue
		var image := image_path(row[3])
		if not image.is_empty() and (not ResourceLoader.exists(image) or not load(image) is Texture2D):
			errors.append(id + "：事件图片不存在或不是纹理：" + image)
			continue
		var options: Array[Dictionary] = []
		for index: int in range(6, row.size(), 2):
			if row[index].strip_edges().is_empty():
				errors.append(id + "：选项说明不能为空")
			else:
				options.append({"text": display_text(row[index]), "command": row[index + 1].strip_edges()})
		records[id] = {"id": id, "title": display_text(row[1]), "text": display_text(row[2]), "image": image, "pool": pool, "conditions": condition.terms, "options": options}
	if records.is_empty(): errors.append("事件文件至少需要一个有效事件")
	return errors.is_empty()

static func display_text(text: String) -> String:
	return text.replace("r", "\n")

static func image_path(value: String) -> String:
	var path := value.strip_edges().replace("\\", "/")
	if path.is_empty() or path.begins_with("res://"): return path
	return "res://" + path if path.begins_with("assets/") else "res://assets/events/" + path

static func parse_condition(source: String) -> Dictionary:
	var terms: Array[Dictionary] = []
	if source.strip_edges().is_empty(): return {"terms": terms, "error": ""}
	var pattern := RegEx.new()
	pattern.compile("^(hp|gold)\\s*([<>])\\s*(\\d+(?:\\.\\d+)?)$")
	for part: String in source.to_lower().split("&&", true):
		var result := pattern.search(part.strip_edges())
		if result == null: return {"terms": [], "error": "出现条件须为 hp>X、hp<X、gold>X、gold<X，可用 && 连接"}
		var value := float(result.get_string(3))
		var stat := result.get_string(1)
		if (stat == "hp" and value > 100) or (stat == "gold" and value != floor(value)):
			return {"terms": [], "error": "HP阈值须在0～100之间，金币阈值须为非负整数"}
		terms.append({"stat": stat, "operator": result.get_string(2), "value": value})
	if terms.is_empty(): return {"terms": [], "error": "出现条件不能为空表达式"}
	return {"terms": terms, "error": ""}

func eligible(pool: String, hp: float, max_hp: float, gold: int) -> Array[String]:
	var result: Array[String] = []
	for id: String in records:
		var event: Dictionary = records[id]
		if not event.pool.is_empty() and event.pool != pool: continue
		var matches := true
		for term: Dictionary in event.conditions:
			var value := hp * 100.0 / max_hp if term.stat == "hp" and max_hp > 0 else float(gold)
			if term.stat == "hp" and max_hp <= 0: value = 0.0
			if not (value > term.value if term.operator == ">" else value < term.value):
				matches = false
				break
		if matches: result.append(id)
	return result

func draw(pool: String, hp: float, max_hp: float, gold: int, seen: Dictionary, rng: RandomNumberGenerator) -> String:
	var candidates := eligible(pool, hp, max_hp, gold)
	if candidates.is_empty(): return ""
	var fresh: Array[String] = []
	for id: String in candidates:
		if not seen.has(id): fresh.append(id)
	if fresh.is_empty():
		# Start a new cycle only for this currently eligible pool.
		for id: String in candidates: seen.erase(id)
		fresh = candidates
	var id := fresh[rng.randi_range(0, fresh.size() - 1)]
	seen[id] = true
	return id

static func _parse(source: String) -> Dictionary:
	var cleaned := ""
	for line: String in source.trim_prefix("\ufeff").split("\n"):
		if not line.strip_edges().begins_with("#"): cleaned += line + "\n"
	var rows: Array = []
	var token := ""
	var quoted := false
	var escaped := false
	var smart_quote := false
	var active := false
	for ch: String in cleaned:
		if not active:
			if ch == "{":
				active = true
				token = ""
			elif ch not in [" ", "\t", "\r", "\n", ";", "；"]:
				return {"rows": [], "error": "事件记录须写在 {...} 内"}
			continue
		if ch == "“" and not quoted:
			smart_quote = true
			ch = '"'
		elif ch == "”" and smart_quote and quoted and not escaped:
			smart_quote = false
			ch = '"'
		if ch == "}" and not quoted:
			var json := JSON.new()
			if json.parse("[" + token + "]") != OK or not json.data is Array:
				return {"rows": [], "error": "事件记录%d格式错误：%s" % [rows.size() + 1, json.get_error_message()]}
			rows.append(json.data)
			active = false
			continue
		if ch == "，" and not quoted: ch = ","
		token += ch
		if escaped: escaped = false
		elif ch == "\\" and quoted: escaped = true
		elif ch == '"': quoted = not quoted
	if active: return {"rows": [], "error": "事件记录括号或引号未闭合"}
	return {"rows": rows, "error": ""}
