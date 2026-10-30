extends RefCounted
class_name AidCatalog
## Aid characters (data/aids.txt). When a floor listing them is first entered, one of them
## offers three choices: one random option from each tier (1 small, 2 medium, 3 high risk).
const TIERS := 3
const FLOORS := 4
var persons: Dictionary = {}
## Person names in file order, for stable encyclopedia sections.
var order: Array[String] = []
var errors: PackedStringArray = []

func load_catalog(path := "res://data/aids.txt") -> bool:
	persons.clear()
	order.clear()
	errors.clear()
	if not FileAccess.file_exists(path):
		errors.append("援助文件不存在：" + path)
		return false
	var parsed := RecordTable.parse(FileAccess.get_file_as_string(path))
	if not parsed.error.is_empty(): errors.append(parsed.error)
	var options: Array = []
	for row: Array in parsed.rows:
		var kind: Variant = row[0] if not row.is_empty() else null
		if kind == "人物": _add_person(row)
		elif kind == "选项": options.append(row)
		else: errors.append("援助记录须以\"人物\"或\"选项\"开头")
	for row: Array in options: _add_option(row)
	for name: String in order:
		for tier: int in range(1, TIERS + 1):
			if persons[name].tiers[tier - 1].is_empty(): errors.append("%s：第%d档没有选项" % [name, tier])
	if not errors.is_empty():
		persons.clear()
		order.clear()
	return errors.is_empty()

func _add_person(row: Array) -> void:
	if row.size() != 10 or row.slice(1).any(func(field: Variant) -> bool: return not field is String):
		errors.append("援助人物应为人物名、称号、背景图、立绘、选择后立绘、开场对话、告别对话、专属遗物、出现层数")
		return
	var name: String = row[1].strip_edges()
	if name.is_empty() or persons.has(name):
		errors.append("援助人物名不能为空或重复：" + name)
		return
	var record := {"name": name, "title": row[2], "background": image_path(row[3]), "portrait": image_path(row[4]), "chosen_portrait": image_path(row[5]),
		"line": EventCatalog.display_text(row[6]), "farewell": EventCatalog.display_text(row[7]), "relics": EventCommands.relic_list(row[8]), "floors": [], "tiers": [[], [], []]}
	for path: String in [record.background, record.portrait, record.chosen_portrait]:
		if not ResourceLoader.exists(path): errors.append("%s：图片不存在：%s" % [name, path])
	for floor: String in String(row[9]).split("|", false):
		if not floor.strip_edges().is_valid_int() or int(floor) < 1 or int(floor) > FLOORS: errors.append("%s：出现层数应为1～%d" % [name, FLOORS])
		else: record.floors.append(int(floor))
	persons[name] = record
	order.append(name)

func _add_option(row: Array) -> void:
	if row.size() != 7 or not row[1] is String or not RecordTable.integer(row[2]) or row.slice(3).any(func(field: Variant) -> bool: return not field is String):
		errors.append("援助选项应为人物名、档位、选项名、图标、说明、指令")
		return
	if not persons.has(row[1]):
		errors.append("援助选项的人物不存在：" + String(row[1]))
		return
	var tier := int(row[2])
	if tier < 1 or tier > TIERS or String(row[3]).strip_edges().is_empty():
		errors.append("%s：选项档位应为1～%d，选项名不能为空" % [row[1], TIERS])
		return
	var icon := icon_path(row[4])
	if not icon.is_empty() and not ResourceLoader.exists(icon): errors.append("%s：选项图标不存在：%s" % [row[1], icon])
	persons[row[1]].tiers[tier - 1].append({"tier": tier, "text": String(row[3]).strip_edges() + "\n" + EventCatalog.display_text(row[5]), "icon": icon, "command": String(row[6]).strip_edges()})

## Backdrops and portraits default to assets/aid/.
static func image_path(value: String) -> String:
	var path := value.strip_edges().replace("\\", "/")
	if path.is_empty() or path.begins_with("res://"): return path
	return "res://" + path if path.begins_with("assets/") else "res://assets/aid/" + path

## A bare name is an item picture; a path is relative to assets/.
static func icon_path(value: String) -> String:
	var path := value.strip_edges().replace("\\", "/")
	if path.is_empty() or path.begins_with("res://"): return path
	return "res://assets/" + path if path.contains("/") else "res://assets/cards/物品／%s.png" % path

## Random person helping on this floor (1-4), or "" when none is listed.
func person_for_floor(floor: int, rng: RandomNumberGenerator) -> String:
	var candidates := order.filter(func(name: String) -> bool: return floor in persons[name].floors)
	return "" if candidates.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]

## The saved entrance record: one option per tier, with event variables bound.
func draw(name: String, troop: TroopState, rng: RandomNumberGenerator) -> Dictionary:
	var person: Dictionary = persons[name]
	var record := {"person": name, "options": []}
	for tier: Array in person.tiers:
		record.options.append(tier[rng.randi_range(0, tier.size() - 1)].duplicate())
	return EventVariables.resolve(record, troop, rng)

## The aid person a relic belongs to, or "".
func owner_of(relic: String) -> String:
	for name: String in order:
		if relic in persons[name].relics: return name
	return ""

static func shared() -> AidCatalog:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.has_meta("aid_catalog"): return tree.get_meta("aid_catalog")
	var catalog := AidCatalog.new()
	catalog.load_catalog()
	if tree != null: tree.set_meta("aid_catalog", catalog)
	return catalog
