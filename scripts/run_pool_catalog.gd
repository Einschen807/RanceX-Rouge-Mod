extends RefCounted
class_name RunPoolCatalog
const LAYERS := ["一层", "二层", "三层"]
const MONSTER_KINDS := ["弱怪池", "强怪池", "精英池", "BOSS池"]
var monsters: Dictionary = {}
var events: Dictionary = {}
var event_data: Dictionary = {}
var initial_cards: Array[String] = []
var errors: PackedStringArray = []

func load_catalog(cards: CardCatalog, database: MonsterCatalog, monster_path := "res://data/monster_pools.txt", event_path := "res://data/event_pools.txt", definition_path := "res://data/events.txt", initial_path := "res://data/initial_deck.txt") -> bool:
	monsters.clear()
	events.clear()
	event_data.clear()
	initial_cards.clear()
	errors.clear()
	for row: Array in _read(definition_path):
		if row.size() != 5 or not row[0] is String or row[0].is_empty() or event_data.has(row[0]) or not row[1] is String or not row[2] is String or row[3] not in ["heal", "medal", "train"] or not RecordTable.integer(row[4]) or row[4] <= 0:
			errors.append("事件记录必须为识别名、标题、正文、效果、正整数参数")
			continue
		event_data[row[0]] = {"id": row[0], "title": row[1], "text": row[2], "effect": row[3], "value": int(row[4])}
	_load_pools(monster_path, monsters, database.monsters)
	_load_pools(event_path, events, event_data)
	for layer: String in LAYERS:
		for kind: String in MONSTER_KINDS:
			if not monsters.has(layer + kind): errors.append("缺少怪物池：" + layer + kind)
		if not events.has(layer + "事件池"): errors.append("缺少事件池：" + layer + "事件池")
	for row: Array in _read(initial_path):
		if row.size() < 2 or row[0] != "初始卡组":
			errors.append("初始卡组记录必须以\"初始卡组\"开头")
			continue
		for name: Variant in row.slice(1):
			if not name is String:
				errors.append("初始卡牌必须为字符串")
			elif not name.is_empty():
				if cards.find_name(name).is_empty(): errors.append("初始卡牌不存在：" + name)
				elif name not in initial_cards: initial_cards.append(name)
	if initial_cards.is_empty(): errors.append("初始卡组不能为空")
	return errors.is_empty()

func _load_pools(path: String, target: Dictionary, definitions: Dictionary) -> void:
	for row: Array in _read(path):
		if row.size() < 2 or not row[0] is String or row[0].is_empty() or target.has(row[0]):
			errors.append(path + "：池名无效或重复")
			continue
		var entries: Array[String] = []
		for id: Variant in row.slice(1):
			if not id is String:
				errors.append("池成员必须为识别名字符串")
				continue
			if id.is_empty(): continue
			if not definitions.has(id): errors.append("池引用不存在的识别名：" + id)
			elif id not in entries: entries.append(id)
		if entries.is_empty(): errors.append("池不能为空：" + str(row[0]))
		target[row[0]] = entries

static func choose(entries: Array, seen: Dictionary, rng: RandomNumberGenerator) -> String:
	var fresh: Array = entries.filter(func(id: String) -> bool: return not seen.has(id))
	var candidates: Array = fresh if not fresh.is_empty() else entries
	return str(candidates[rng.randi_range(0, candidates.size() - 1)]) if not candidates.is_empty() else ""

func _read(path: String) -> Array:
	if not FileAccess.file_exists(path):
		errors.append("数据文件不存在：" + path)
		return []
	var parsed := RecordTable.parse(FileAccess.get_file_as_string(path))
	if not parsed.error.is_empty(): errors.append(path + "：" + parsed.error)
	return parsed.rows
