extends RefCounted
class_name UpgradePreviewText
## Compare the actual owned card with its preview without modifying either record.
const GREEN := Color("9fe47f")

static func changed_positions(before: String, after: String) -> Dictionary:
	var result := {}
	if before == after: return result
	var rows: Array[PackedInt32Array] = []
	for i: int in range(before.length() + 1):
		var row := PackedInt32Array()
		row.resize(after.length() + 1)
		rows.append(row)
	for i: int in range(before.length() - 1, -1, -1):
		for j: int in range(after.length() - 1, -1, -1):
			rows[i][j] = 1 + rows[i + 1][j + 1] if before[i] == after[j] else maxi(rows[i + 1][j], rows[i][j + 1])
	var i := 0
	var j := 0
	while j < after.length():
		if i < before.length() and before[i] == after[j]:
			i += 1
			j += 1
		elif i < before.length() and rows[i + 1][j] > rows[i][j + 1]:
			i += 1
		else:
			result[j] = GREEN
			j += 1
	# Numbers are semantic units: 2 -> 2.5 and 50 -> 40 highlight the
	# complete new value, including a percentage sign. Other unchanged units
	# such as 贝壳 or 倍 retain their original color.
	var numbers := RegEx.new()
	numbers.compile("[+-]?[0-9]+(?:\\.[0-9]+)?[%％]?")
	for token: RegExMatch in numbers.search_all(after):
		var affected := false
		for index: int in range(token.get_start(), token.get_end()):
			if result.has(index): affected = true; break
		if affected:
			for index: int in range(token.get_start(), token.get_end()): result[index] = GREEN
	return result

static func colored_text(before: String, after: String) -> String:
	var changed := changed_positions(before, after)
	var result := ""
	var green := false
	for index: int in range(after.length()):
		var next_green := changed.has(index)
		if next_green != green:
			result += "[color=#%s]" % GREEN.to_html(false) if next_green else "[/color]"
			green = next_green
		var glyph := after[index]
		result += "[lb]" if glyph == "[" else ("[rb]" if glyph == "]" else glyph)
	if green: result += "[/color]"
	return result

static func apply(label: Label, before: String) -> void:
	if before == label.text: return
	# Keep Label's native measurement and plain text for fitting/accessibility;
	# RichTextLabel supplies only the colored rendering at identical coordinates.
	var rich := RichTextLabel.new()
	rich.name = "UpgradeDifference"
	rich.bbcode_enabled = true
	rich.scroll_active = false
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.size = label.size
	rich.autowrap_mode = label.autowrap_mode
	rich.horizontal_alignment = label.horizontal_alignment
	rich.vertical_alignment = label.vertical_alignment
	rich.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	rich.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	rich.add_theme_font_override("normal_font", label.get_theme_font("font"))
	rich.add_theme_font_size_override("normal_font_size", label.get_theme_font_size("font_size"))
	rich.add_theme_constant_override("line_separation", label.get_theme_constant("line_spacing"))
	for key: String in ["outline_size", "shadow_offset_x", "shadow_offset_y"]:
		rich.add_theme_constant_override(key, label.get_theme_constant(key))
	rich.add_theme_color_override("default_color", label.get_theme_color("font_color"))
	for key: String in ["font_shadow_color", "font_outline_color"]:
		rich.add_theme_color_override(key, label.get_theme_color(key))
	rich.text = colored_text(before, label.text)
	label.add_child(rich)
	for key: String in ["font_color", "font_shadow_color", "font_outline_color"]:
		label.add_theme_color_override(key, Color.TRANSPARENT)
