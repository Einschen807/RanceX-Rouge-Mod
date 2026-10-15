extends RefCounted
class_name SkillEffectCatalog
## The fifth skill field selects an effect by filename, including its own sound.
const ROOT := "res://assets/effects/"
const MAGIC := ["炎", "冰", "雷", "光", "暗"]
const DEFAULTS := {1: "突袭攻击", 2: "远程攻击", 4: "附加效果", 5: "附加效果", 6: "附加效果"}
static var _catalog: Dictionary = {}
static var _warned: Dictionary = {}

static func entries() -> Dictionary:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "catalog.json"))
		if parsed is Dictionary: _catalog = parsed
	return _catalog

static func normalize_name(value: String) -> String:
	var name := value.strip_edges().replace("\\", "/")
	name = name.trim_prefix("特效/").trim_prefix("特效／")
	name = name.trim_suffix("/animation.json").trim_suffix(".flat").trim_suffix(".json")
	# Native full-width slash is part of a filename; accept a normal slash too.
	return name.replace("/", "／")

static func resolve(skill: Dictionary, element: int = 0) -> Dictionary:
	var specified := normalize_name(str(skill.get("effect_asset", "")))
	if not specified.is_empty():
		if entries().has(specified): return _descriptor(specified, false)
		# A designer can add a new self-contained effect directory without editing code.
		var path := ROOT + specified + "/animation.json"
		if FileAccess.file_exists(path):
			return {"name": specified, "path": path, "sound_path": ROOT + specified + "/audio.ogg", "default": false}
		if not _warned.has(specified):
			_warned[specified] = true
			push_warning("技能特效不存在，使用类型默认特效：" + specified)
	var kind := int(skill.get("type", 1))
	var name: String = DEFAULTS.get(kind, "附加效果")
	if kind in [4, 6]:
		for slot: int in range(1, 4):
			var status: int = skill.get("effect%d" % slot, 0)
			if BattleStatusEffects.valid(status) and status != BattleStatusEffects.PURITY and int(skill.get("value%d" % slot, 0)) in range(1, 10):
				name = "负面效果"
				break
	if kind == 3:
		var index := element - 1 if element in [1, 2, 3, 4, 5] else randi_range(0, 4)
		name = "魔法／%s魔法攻击" % MAGIC[index]
	if int(skill.get("ultimate", 0)) == 1: name += "（大）"
	return _descriptor(name, true)

static func _descriptor(name: String, fallback: bool) -> Dictionary:
	var result: Dictionary = entries().get(name, {}).duplicate()
	result["name"] = name
	result["default"] = fallback
	return result
