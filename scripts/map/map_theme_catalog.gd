extends RefCounted
class_name MapThemeCatalog
## One weighted theme list per floor. Zero weights disable a theme for new floors.
const LAYERS := ["一层", "二层", "三层", "四层"]
const THEMES := [["荒野", "遗迹"], ["利萨斯", "自由都市", "卡拉之森"], ["赫尔曼", "赛斯", "JAPAN"], ["魔界"]]
var floors: Array[Dictionary] = []
var errors: PackedStringArray = []

func load_catalog(path := "res://data/map.txt") -> bool:
	if not FileAccess.file_exists(path):
		floors.clear()
		errors = PackedStringArray(["地图主题文件不存在：" + path])
		return false
	return load_text(FileAccess.get_file_as_string(path))

func load_text(source: String) -> bool:
	floors.clear()
	errors.clear()
	for line: String in source.trim_prefix("\ufeff").split("\n"):
		var record := line.strip_edges()
		if record.is_empty() or record.begins_with("#"): continue
		var layer := floors.size()
		if layer >= THEMES.size():
			errors.append("地图主题最多配置四层")
			break
		record = record.trim_suffix(";").trim_suffix("；").strip_edges()
		var weights: Dictionary = {}
		floors.append(weights)
		if not record.begins_with("{") or not record.ends_with("}"):
			errors.append(LAYERS[layer] + "地图主题须写成 {主题,权重,...}")
			continue
		var fields := record.substr(1, record.length() - 2).replace("，", ",").split(",", true)
		if fields.size() < 2 or fields.size() % 2 != 0:
			errors.append(LAYERS[layer] + "地图主题和权重必须成对填写")
			continue
		var total := 0.0
		for index: int in range(0, fields.size(), 2):
			var theme := fields[index].strip_edges()
			if theme.begins_with('"') and theme.ends_with('"'): theme = theme.substr(1, theme.length() - 2)
			if theme.to_upper() == "JAPAN": theme = "JAPAN"
			var weight_text := fields[index + 1].strip_edges()
			if theme not in THEMES[layer] or weights.has(theme):
				errors.append(LAYERS[layer] + "主题无效、层数不符或重复：" + theme)
				continue
			if not weight_text.is_valid_float() or not is_finite(float(weight_text)) or float(weight_text) < 0.0:
				errors.append(LAYERS[layer] + theme + "权重须为非负数字")
				continue
			var weight := float(weight_text)
			weights[theme] = weight
			total += weight
		if not is_finite(total) or total <= 0.0: errors.append(LAYERS[layer] + "至少需要一个大于0的主题权重")
	if floors.size() != THEMES.size(): errors.append("map.txt 必须按顺序配置一至四层，共四行主题记录")
	return errors.is_empty()

func choose(layer: int, rng: RandomNumberGenerator) -> String:
	if not errors.is_empty() or layer < 0 or layer >= floors.size(): return ""
	var weights: Dictionary = floors[layer]
	var total := 0.0
	for weight: float in weights.values(): total += weight
	var roll := rng.randf() * total
	var last := ""
	for theme: String in weights:
		var weight: float = weights[theme]
		if weight <= 0.0: continue
		last = theme
		roll -= weight
		if roll < 0.0: return theme
	return last
