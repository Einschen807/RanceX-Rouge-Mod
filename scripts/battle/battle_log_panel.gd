extends Control
class_name BattleLogPanel
signal close_requested
var messages: Array[String] = []
var scroll: ScrollContainer

func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Original Game/Battle/LowerLog.pactex coordinates and 31px ruled lines.
	BattleArt.picture(self, "log_background", Vector2(287, 84))
	scroll = ScrollContainer.new()
	scroll.position = Vector2(324, 119)
	scroll.size = Vector2(1165, 930)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 0)
	scroll.add_child(rows)
	for message: String in messages:
		var text := BattleArt.label(rows, message, Vector2.ZERO, Vector2(1165, 31), 21, _color(message))
		text.custom_minimum_size = Vector2(1165, 31)
		text.add_theme_constant_override("outline_size", 0)
	var bar := OriginalFormationScrollbar.new()
	bar.scroll = scroll
	bar.total_height = 948
	bar.scroll_step = 93
	bar.position = Vector2(1538, 96)
	add_child(bar)
	BattleArt.button(self, "log", Vector2(1481, 1049), Vector2(150, 31), func() -> void: close_requested.emit())
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	_scroll_to_latest.call_deferred()

func _scroll_to_latest() -> void:
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func _color(message: String) -> Color:
	if message.begins_with("Round") or message in ["胜利", "败北", "时间结束"]:
		return FormationArt.GOLD
	if message.contains("受到"):
		return Color(1, 0.72, 0.75)
	return Color.WHITE
