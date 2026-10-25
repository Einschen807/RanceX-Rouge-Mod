extends Control
class_name EventOptionPreview
## Hovering an event choice shows what it names: relic description boxes and curse cards,
## laid out beside the choice column (over the illustration) so nothing overlaps.
const GAP := 16.0
const STACK_GAP := 8.0
const MARGIN := 16.0
const CURSE_SCALE := 1.2
const RELIC_SIZE := Vector2(440, 180)
var _owner: Control
var _relics := RelicCatalog.new()
var _fade: Tween

func _ready() -> void:
	name = "EventOptionPreview"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relics.load_catalog()

## Relic and curse names mentioned by a resolved command string, in order, without repeats.
static func mentions(command: String) -> Dictionary:
	var relics: Array[String] = []
	var curses: Array[String] = []
	for part: String in command.split("/", false):
		var words := part.strip_edges().split(" ", false, 1)
		if words.size() < 2: continue
		var verb := words[0].to_lower()
		var args := words[1].split(" ", false, 1)
		if args.size() < 2: continue
		var kind := args[0].to_lower()
		var rest := args[1].strip_edges()
		var names: PackedStringArray = []
		if kind == "relic" and verb in ["add", "delet", "delete"]: names.append(rest)
		elif kind == "relic" and verb == "choose": names = EventCommands.relic_list(rest)
		elif kind == "relic" and verb == "random": names = EventCommands.relic_list(rest.split(" ", false, 1)[-1])
		elif kind == "curse" and verb == "add": names.append(rest)
		var target := curses if kind == "curse" else relics
		for name: String in names:
			if name not in target: target.append(name)
	return {"relics": relics, "curses": curses}

func show_for(button: Control, command: String) -> void:
	_clear()
	_owner = button
	var found := mentions(command)
	var relics: Array[Dictionary] = []
	for name: String in found.relics:
		if _relics.by_name.has(name): relics.append(_relics.by_name[name])
	var curses: Array[String] = []
	for name: String in found.curses:
		if CurseCatalog.shared().by_name.has(name): curses.append(name)
	if relics.is_empty() and curses.is_empty(): return
	var anchor := button.get_global_rect()
	var right := anchor.position.x - GAP
	var centre := anchor.get_center().y
	var x := right
	var relic_height := relics.size() * RELIC_SIZE.y + maxf(0.0, relics.size() - 1) * STACK_GAP
	var relic_top := _fit_top(centre - relic_height * 0.5, relic_height)
	if not relics.is_empty():
		x -= RELIC_SIZE.x
		for index: int in range(relics.size()):
			var box := RelicTooltip.new()
			box.name = "RelicPreview"
			add_child(box)
			box.show_record(relics[index], Vector2(x, relic_top + index * (RELIC_SIZE.y + STACK_GAP)))
		x -= GAP
	if not curses.is_empty():
		var card_size := RelicCard.NATIVE * CURSE_SCALE
		var row_width := curses.size() * card_size.x + (curses.size() - 1) * GAP
		var row := Vector2(x - row_width, _fit_top(centre - card_size.y * 0.5, card_size.y))
		# Not enough room beside the relic column: stack the cards below it, or above.
		if row.x < MARGIN:
			row.x = right - row_width
			row.y = relic_top + relic_height + GAP
			if row.y + card_size.y > size.y - MARGIN: row.y = relic_top - GAP - card_size.y
		for index: int in range(curses.size()):
			var card := CurseCard.make({"name": curses[index]}, CURSE_SCALE)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.focus_mode = Control.FOCUS_NONE
			add_child(card)
			card.position = row + Vector2(index * (card_size.x + GAP), 0)
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.1)

func hide_for(button: Control) -> void:
	if button == _owner: _clear()

func hide_all() -> void:
	_clear()

func _clear() -> void:
	if _fade != null and _fade.is_running(): _fade.kill()
	_owner = null
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

func _fit_top(top: float, height: float) -> float:
	return clampf(top, MARGIN, maxf(MARGIN, size.y - MARGIN - height))
