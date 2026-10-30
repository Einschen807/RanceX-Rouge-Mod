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

## tail_from: text from this index on (a card enchantment) is blue instead of compared.
static func colored_text(before: String, after: String, tail_from := -1) -> String:
	var compared := after if tail_from < 0 else after.substr(0, tail_from)
	var changed := changed_positions(before, compared)
	if tail_from >= 0:
		for index: int in range(tail_from, after.length()): changed[index] = CardEnchantments.BLUE
	var result := ""
	var color: Variant = null
	for index: int in range(after.length()):
		var next_color: Variant = changed.get(index)
		if next_color != color:
			if color != null: result += "[/color]"
			if next_color != null: result += "[color=#%s]" % (next_color as Color).to_html(false)
			color = next_color
		var glyph := after[index]
		result += "[lb]" if glyph == "[" else ("[rb]" if glyph == "]" else glyph)
	if color != null: result += "[/color]"
	return result

static func apply(label: Label, before: String, tail_from := -1) -> void:
	# CardWidget marks an enchanted description; later comparisons keep its blue tail.
	if tail_from < 0: tail_from = int(label.get_meta("enchant_from", -1))
	var existing := label.get_node_or_null("UpgradeDifference") as RichTextLabel
	if existing != null:
		existing.text = colored_text(before, label.text, tail_from)
		return
	if before == label.text and tail_from < 0: return
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
	rich.text = colored_text(before, label.text, tail_from)
	label.add_child(rich)
	for key: String in ["font_color", "font_shadow_color", "font_outline_color"]:
		label.add_theme_color_override(key, Color.TRANSPARENT)
