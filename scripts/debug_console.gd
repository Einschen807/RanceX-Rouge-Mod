extends CanvasLayer
var panel: Control
var entry: LineEdit
var output: RichTextLabel
var history: Array[String] = []
var history_index := 0

func _ready() -> void:
	layer = 110
	panel = Control.new()
	panel.size = Vector2(1920, 330)
	add_child(panel)
	var frame := Panel.new()
	frame.size = panel.size
	frame.add_theme_stylebox_override("panel", BattleArt.panel_style())
	panel.add_child(frame)
	BattleArt.label(frame, "控制台  ·  battle 怪物识别名", Vector2(24, 10), Vector2(1850, 40), 25, FormationArt.GOLD)
	output = RichTextLabel.new()
	output.position = Vector2(24, 58)
	output.size = Vector2(1872, 190)
	output.add_theme_font_override("normal_font", CardWidget.CARD_TEXT_FONT)
	output.add_theme_font_size_override("normal_font_size", 22)
	output.scroll_following = true
	frame.add_child(output)
	entry = LineEdit.new()
	entry.position = Vector2(24, 262)
	entry.size = Vector2(1872, 48)
	entry.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
	entry.add_theme_font_size_override("font_size", 25)
	entry.text_submitted.connect(execute)
	frame.add_child(entry)
	panel.hide()

func toggle() -> void:
	if panel.visible:
		close()
	else:
		panel.show()
		panel.add_to_group("modal_overlay")
		entry.grab_focus()

func close() -> void:
	panel.hide()
	panel.remove_from_group("modal_overlay")
	entry.release_focus()

func execute(command: String) -> void:
	command = command.strip_edges()
	if command.is_empty():
		return
	history.append(command)
	history_index = history.size()
	output.append_text("> " + command + "\n")
	entry.clear()
	var split := command.split(" ", false, 1)
	if split.size() == 2 and split[0].to_lower() == "battle":
		var message: String = get_node("/root/BattleManager").launch(split[1].strip_edges())
		output.append_text(message + "\n")
		if message.begins_with("进入战斗"):
			close()
	else:
		output.append_text("未知指令。用法：battle 怪物识别名\n")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_QUOTELEFT, KEY_ASCIITILDE] or event.physical_keycode == KEY_QUOTELEFT):
		get_viewport().set_input_as_handled()
		toggle()
	elif panel.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			close()
		elif event is InputEventKey and event.pressed and event.keycode in [KEY_UP, KEY_DOWN]:
			get_viewport().set_input_as_handled()
			history_index = clampi(history_index + (-1 if event.keycode == KEY_UP else 1), 0, history.size())
			entry.text = history[history_index] if history_index < history.size() else ""
			entry.caret_column = entry.text.length()
