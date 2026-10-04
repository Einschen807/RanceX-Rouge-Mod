extends RefCounted
class_name CardCatalog
## One file for every card and one for every skill; never instantiate one scene per character.

const CARD_FIELDS := ["name", "identity", "portrait", "faction", "element", "gender", "skill1", "skill2", "base_hp", "base_at", "rarity"]
const SKILL_FIELDS := ["id", "name", "action", "type", "effect_asset", "ap", "effect1", "value1", "effect2", "value2", "effect3", "value3", "custom", "condition", "ultimate", "ap_type", "description"]
const FACTIONS := ["主人公", "利萨斯", "赫尔曼", "赛斯", "自由都市", "JAPAN", "其他", "亚人", "怪物", "神魔"]
const ELEMENTS := ["无", "炎", "冰", "雷", "光", "暗"]
const UPGRADE_SUFFIX := "+"
var cards: Array[Dictionary] = []
var by_name: Dictionary = {}
var by_identity: Dictionary = {}
var skills: Dictionary = {}
var errors: PackedStringArray = []

func load_catalog(card_path: String = "res://data/cards.txt", skill_path: String = "res://data/skills.txt") -> bool:
	cards.clear()
	by_name.clear()
	by_identity.clear()
	skills.clear()
	errors.clear()
	var skill_rows := _read(skill_path)
	for row: Array in skill_rows:
		if not _schema(row, SKILL_FIELDS.size(), [1, 4, 13, 16]):
			continue
		var s := _dictionary(SKILL_FIELDS, row)
		var action: int = s.action
		if s.id <= 0 or skills.has(s.id) or not (action in [1, 2, 3] or (action >= 2000 and action <= 2999)) or s.type < 1 or s.type > 6 or s.ap < 0 or s.ap_type < 1 or s.ap_type > 5 or not s.custom in [0, 1] or not s.ultimate in [0, 1]:
			errors.append("技能ID %s 重复或枚举/数值无效" % s.id)
			continue
		if (action == 2 or action >= 2000) and s.ap > 100:
			errors.append("自动技能概率必须为0～100：%s" % s.name)
		for n: int in range(1, 4):
			if not SkillBaseEffects.has_effect(s["effect%d" % n]):
				errors.append("技能 %s 引用了未注册的基础效果" % s.name)
			if s["value%d" % n] < 0:
				errors.append("技能 %s 的效果数值不能为负" % s.name)
		if not SkillBaseEffects.has_condition(s.condition):
			errors.append("技能 %s 引用了未注册的条件" % s.name)
		s.description = s.description.replace("r", "\n")
		skills[s.id] = s
	for row: Array in _read(card_path):
		if not _schema(row, CARD_FIELDS.size(), [0, 1, 2]):
			continue
		var c := _dictionary(CARD_FIELDS, row)
		if c.name.is_empty() or c.identity.is_empty() or by_name.has(c.name) or c.faction < 1 or c.faction > 10 or c.element < 0 or c.element > 5 or c.gender < 1 or c.gender > 3 or c.rarity < 1 or c.rarity > 3 or c.base_hp < 0 or c.base_at < 0:
			errors.append("卡牌 %s 显示名重复或字段无效" % c.name)
			continue
		for id: int in [c.skill1, c.skill2]:
			if id != 0 and not skills.has(id):
				errors.append("卡牌 %s 引用了不存在的技能 %d" % [c.name, id])
		var path := "res://assets/cards/%s.png" % c.portrait
		if not ResourceLoader.exists(path):
			errors.append("卡面不存在：%s" % path)
		else:
			var texture := load(path) as Texture2D
			if texture == null or texture.get_size() != Vector2(208, 312):
				errors.append("卡面必须为208×312：%s" % path)
		cards.append(c)
		by_name[c.name] = c
		if not by_identity.has(c.identity):
			by_identity[c.identity] = []
		by_identity[c.identity].append(c)
	if not errors.is_empty():
		# Failed loads are atomic: no partially valid catalog reaches gameplay.
		cards.clear()
		by_name.clear()
		by_identity.clear()
		skills.clear()
	return errors.is_empty()

func find_name(display_name: String) -> Dictionary:
	return by_name.get(display_name, {})

func find_identity(identity: String) -> Array:
	return by_identity.get(identity, [])

static func is_upgraded(card: Dictionary) -> bool:
	return String(card.name).ends_with(UPGRADE_SUFFIX)

func upgrade_preview(card: Dictionary) -> Dictionary:
	if is_upgraded(card):
		return card
	return by_name.get(String(card.name) + UPGRADE_SUFFIX, card)

func _read(path: String) -> Array:
	if not FileAccess.file_exists(path):
		errors.append("数据文件不存在：" + path)
		return []
	var result := RecordTable.parse(FileAccess.get_file_as_string(path))
	if not result.error.is_empty():
		errors.append(path + "：" + result.error)
	return result.rows

func _schema(row: Array, count: int, strings: Array) -> bool:
	if row.size() != count:
		errors.append("记录字段数必须为%d，实际为%d" % [count, row.size()])
		return false
	for i: int in range(count):
		if (i in strings and not row[i] is String) or (not i in strings and not RecordTable.integer(row[i])):
			errors.append("字段%d的类型不正确" % (i + 1))
			return false
	return true

func _dictionary(fields: Array, row: Array) -> Dictionary:
	var result := {}
	for i: int in range(fields.size()):
		result[fields[i]] = row[i] if row[i] is String else int(row[i])
	return result
