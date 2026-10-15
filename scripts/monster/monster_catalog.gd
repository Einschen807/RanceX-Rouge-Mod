extends RefCounted
class_name MonsterCatalog

const FIELDS := ["name", "identity", "portrait", "background", "base_hp", "base_at", "physical_resist", "magic_resist", "kind", "behavior", "analysis"]
var monsters: Dictionary = {}
var behaviors: Dictionary = {}
var opening_skills: Dictionary = {}
var errors: PackedStringArray = []

func load_catalog(skills: Dictionary, monster_path: String = "res://data/monsters.txt", behavior_path: String = "res://data/monster_behaviors.txt") -> bool:
	monsters.clear()
	behaviors.clear()
	opening_skills.clear()
	errors.clear()
	for row: Array in _read(behavior_path):
		if row.size() < 5 or not RecordTable.integer(row[0]) or int(row[0]) <= 0 or behaviors.has(int(row[0])):
			errors.append("行为ID无效、重复或没有行为记录")
			continue
		if not row[1] is String or not row[1].begins_with("开局追加="):
			errors.append("行为ID后必须填写字符串：开局追加=技能编号1，技能编号2")
			continue
		var opening: Array[int] = []
		var raw: String = row[1].trim_prefix("开局追加=").strip_edges()
		if not raw.is_empty():
			for token: String in raw.replace("，", ",").split(",", true):
				var number := token.strip_edges()
				if not number.is_valid_int() or int(number) <= 0 or not skills.has(int(number)):
					errors.append("开局追加引用无效或不存在的技能：" + number)
				else:
					opening.append(int(number))
		opening_skills[int(row[0])] = opening
		var actions: Array[Dictionary] = []
		var index := 2
		while index < row.size():
			if not row[index] is String:
				errors.append("行为名称必须是字符串")
				break
			var action_name: String = row[index]
			index += 1
			var ids: Array[int] = []
			while index < row.size() and not row[index] is String:
				if not RecordTable.integer(row[index]) or int(row[index]) < 0:
					errors.append("行为技能ID必须是非负整数")
					break
				var id := int(row[index])
				if id != 0:
					if not skills.has(id):
						errors.append("行为引用不存在的技能：%d" % id)
					ids.append(id)
				index += 1
			if index >= row.size() or not row[index] is String or not BattleConditions.valid(row[index]):
				errors.append("行为缺少有效的行动条件")
				break
			actions.append({"name": action_name, "skills": ids, "condition": row[index]})
			index += 1
		behaviors[int(row[0])] = actions
	for row: Array in _read(monster_path):
		if row.size() != FIELDS.size():
			errors.append("怪物记录必须有11个字段")
			continue
		var valid_types := true
		for i: int in range(row.size()):
			valid_types = valid_types and (row[i] is String if i in [0, 1, 2, 3, 10] else RecordTable.integer(row[i]))
		if not valid_types:
			errors.append("怪物字段类型不正确")
			continue
		var monster := {}
		for i: int in range(FIELDS.size()):
			monster[FIELDS[i]] = row[i] if row[i] is String else int(row[i])
		if monster.identity.is_empty() or monsters.has(monster.identity) or monster.name.is_empty() or monster.base_hp <= 0 or monster.base_at < 0 or monster.physical_resist < 0 or monster.physical_resist > 100 or monster.magic_resist < 0 or monster.magic_resist > 100 or monster.kind not in [1, 2, 3] or not behaviors.has(monster.behavior):
			errors.append("怪物识别名重复或字段无效：" + monster.identity)
			continue
		if not ResourceLoader.exists("res://assets/monsters/%s.png" % monster.portrait) or not ResourceLoader.exists("res://assets/battle/backgrounds/%s.png" % monster.background):
			errors.append("怪物立绘或战斗背景不存在：" + monster.identity)
		monsters[monster.identity] = monster
	if not errors.is_empty():
		monsters.clear()
		behaviors.clear()
		opening_skills.clear()
	return errors.is_empty()

func choose(behavior_id: int, context: Dictionary) -> Dictionary:
	for action: Dictionary in behaviors.get(behavior_id, []):
		if BattleConditions.met(action.condition, context):
			return action
	return {"name": "待机", "skills": [], "condition": ""}

func _read(path: String) -> Array:
	if not FileAccess.file_exists(path):
		errors.append("数据文件不存在：" + path)
		return []
	var parsed := RecordTable.parse(FileAccess.get_file_as_string(path))
	if not parsed.error.is_empty():
		errors.append(path + "：" + parsed.error)
	return parsed.rows
