extends RefCounted
class_name RunPoolCatalog
const LAYERS := MapThemeCatalog.LAYERS
const MONSTER_LAYERS := MapThemeCatalog.LAYERS
const MAP_THEMES := MapThemeCatalog.THEMES
const MONSTER_KINDS := ["弱怪池", "强怪池", "精英池", "BOSS池"]
var monsters: Dictionary = {}
var event_catalog: EventCatalog
var event_data: Dictionary = {}
var initial_cards: Array[String] = []
var errors: PackedStringArray = []
var themes: MapThemeCatalog

func load_catalog(cards: CardCatalog, database: MonsterCatalog, monster_path := "res://data/monster_pools.txt", definition_path := "res://data/events.txt", initial_path := "res://data/initial_deck.txt") -> bool:
	monsters.clear()
	event_data.clear()
	initial_cards.clear()
	errors.clear()
	themes = MapThemeCatalog.new()
	if not themes.load_catalog(): errors.append_array(themes.errors)
	event_catalog = EventCatalog.new()
	if not event_catalog.load_catalog(definition_path): errors.append_array(event_catalog.errors)
	event_data = event_catalog.records
	_load_pools(monster_path, monsters, database.monsters)
	for layer_index: int in range(MONSTER_LAYERS.size()):
		for theme: String in MAP_THEMES[layer_index]:
			for kind: String in MONSTER_KINDS:
				var pool_name := monster_pool_name(layer_index, kind, theme)
				if not monsters.has(pool_name): errors.append("缺少怪物池：" + pool_name)
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

static func monster_pool_name(layer_index: int, kind: String, theme := "") -> String:
	if layer_index < 0 or layer_index >= MONSTER_LAYERS.size() or kind not in MONSTER_KINDS: return ""
	var themes: Array = MAP_THEMES[layer_index]
	var chosen_theme: String = str(themes[0]) if theme.is_empty() else theme
	if chosen_theme not in themes: return ""
	return MONSTER_LAYERS[layer_index] + chosen_theme + kind

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
