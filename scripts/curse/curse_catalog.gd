extends RefCounted
class_name CurseCatalog
## Run curses are item-style cards of the 主人公 faction with 0 HP/AT. They never deploy and
## never join TroopState.available, so they cannot dilute the troop's average AT.
const FACTION := 1
var entries: Array[Dictionary] = []
var by_name: Dictionary = {}
var errors: PackedStringArray = []

func load_catalog(path := "res://data/curses.txt") -> bool:
	entries.clear()
	by_name.clear()
	errors.clear()
	if not FileAccess.file_exists(path):
		errors.append("诅咒文件不存在：" + path)
		return false
	var parsed := RecordTable.parse(FileAccess.get_file_as_string(path))
	if not parsed.error.is_empty(): errors.append(parsed.error)
	for row: Array in parsed.rows:
		if row.size() != 5 or not row[0] is String or not row[1] is String or not row[2] is String or not RecordTable.integer(row[3]) or not RecordTable.integer(row[4]):
			errors.append("诅咒记录应为名称、卡面、说明、战斗显示、一次性")
			continue
		if row[0].is_empty() or row[0].contains("/") or by_name.has(row[0]) or int(row[3]) not in [0, 1] or int(row[4]) not in [0, 1] or not ResourceLoader.exists(portrait_path(row[1])):
			errors.append("诅咒名称、卡面或开关无效：" + row[0])
			continue
		var record := {"name": row[0], "icon": row[1], "description": String(row[2]).replace("r", "\n"), "battle": int(row[3]) == 1, "one_shot": int(row[4]) == 1, "faction": FACTION, "base_hp": 0, "base_at": 0}
		entries.append(record)
		by_name[record.name] = record
	if not errors.is_empty():
		entries.clear()
		by_name.clear()
	return errors.is_empty()

static func portrait_path(icon: String) -> String:
	return "res://assets/cards/物品／%s.png" % icon

## Shared loaded copy; curses are read on every shop price and battle start.
static func shared() -> CurseCatalog:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.has_meta("curse_catalog"): return tree.get_meta("curse_catalog")
	var catalog := CurseCatalog.new()
	catalog.load_catalog()
	if tree != null: tree.set_meta("curse_catalog", catalog)
	return catalog
