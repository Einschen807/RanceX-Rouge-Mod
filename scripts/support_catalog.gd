extends RefCounted
class_name SupportCatalog
## Definitions are immutable; remaining rounds and casters belong to BattleState.
const FIELDS := ["id", "name", "identity", "icon", "category", "erasable", "rounds", "skill", "repeat", "next", "description"]
const MAX_COUNT := 7
var entries: Dictionary = {}
var errors: PackedStringArray = []

func load_catalog(skills: Dictionary, path := "res://data/supports.txt") -> bool:
	entries.clear()
	errors.clear()
	if not FileAccess.file_exists(path):
		errors.append("支援数据不存在：" + path)
		return false
	var parsed := RecordTable.parse(FileAccess.get_file_as_string(path))
	if not parsed.error.is_empty(): errors.append(parsed.error)
	for row: Array in parsed.rows:
		if row.size() != FIELDS.size():
			errors.append("支援记录必须有11个字段")
			continue
		var valid := true
		for i: int in range(row.size()):
			valid = valid and (row[i] is String if i in [1, 2, 3, 10] else RecordTable.integer(row[i]))
		if not valid:
			errors.append("支援字段类型无效")
			continue
		var entry := {}
		for i: int in range(FIELDS.size()): entry[FIELDS[i]] = row[i] if row[i] is String else int(row[i])
		if entry.id <= 0 or entries.has(entry.id) or entry.name.is_empty() or entry.identity.is_empty() or entry.category not in [1, 2, 3, 4, 5, 9] or entry.erasable not in [0, 1] or entry.rounds < 0 or entry.repeat not in [1, 2, 3, 4] or entry.next < 0:
			errors.append("支援ID重复或字段无效：%s" % entry.id)
			continue
		if not ResourceLoader.exists("res://assets/battle/support/%s.png" % entry.icon): errors.append("支援图标不存在：" + entry.icon)
		if not skills.has(entry.skill) or not (int(skills[entry.skill].action) in [2, 3] or int(skills[entry.skill].action) in range(2000, 3000)):
			errors.append("支援必须引用存在的自动或被动技能：%s" % entry.id)
		entry.description = entry.description.replace("r", "\n")
		entries[entry.id] = entry
	for entry: Dictionary in entries.values():
		if entry.next != 0 and (not entries.has(entry.next) or entries[entry.next].identity != entry.identity): errors.append("支援升级必须引用同识别名的支援：%s" % entry.id)
		var visited: Array[int] = [entry.id]
		var following: int = entry.next
		while entries.has(following):
			if following in visited:
				errors.append("支援升级链不能循环：%s" % entry.id)
				break
			visited.append(following)
			following = int(entries[following].next)
	for skill: Dictionary in skills.values():
		for n: int in range(1, 4):
			if int(skill["effect%d" % n]) in [30, 31, 34] and not entries.has(int(skill["value%d" % n])): errors.append("技能引用不存在的支援：%s" % skill.id)
	if not errors.is_empty(): entries.clear()
	return errors.is_empty()
