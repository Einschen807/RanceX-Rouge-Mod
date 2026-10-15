extends Control
class_name TreasureFactionInfo
## Native GetCardAlterValueView layout, with inventory totals and acquisition deltas.
var record: Dictionary
var troop: TroopState
var preview_upgrades := false

func _ready() -> void:
	size = Vector2(208, 85)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh()

func refresh() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	TreasureArt.picture(self, "faction_plate", Vector2.ZERO, Vector2(208, 25))
	TreasureArt.picture(self, "faction_%d" % int(record.faction), Vector2(47, 2), Vector2(118, 21))
	TreasureArt.picture(self, "faction_stats", Vector2(0, 34), Vector2(208, 51))
	for stat: String in ["hp", "at"]:
		var y := 39.0 if stat == "hp" else 65.0
		var current := troop.faction_stat(int(record.faction), stat, preview_upgrades)
		# Floor the resulting faction total, so displayed current + gain agrees with it.
		var gain := floori(current + troop.acquisition_gain(record, stat, preview_upgrades)) - floori(current)
		_number(stat, "Current", Vector2(30, y), Vector2(99, 15), floori(current))
		TreasureArt.picture(self, stat + "_plus", Vector2(129, y), Vector2(12, 15))
		_number(stat, "Gain", Vector2(141, y), Vector2(45, 15), gain)

func _number(stat: String, label: String, at: Vector2, dimensions: Vector2, value: int) -> void:
	var number := OriginalBitmapNumber.new()
	number.name = stat.to_upper() + label
	number.atlas = load("res://assets/treasure/%s_digits.png" % stat)
	number.kerning = 0
	number.position = at
	number.size = dimensions
	number.text = str(value)
	number.abbreviate = false
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(number)
