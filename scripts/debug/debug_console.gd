extends CanvasLayer
var panel: Control
var entry: LineEdit
var output: RichTextLabel
var history: Array[String] = []
var history_index := 0
const HELP_TEXT := """可用命令：
help — 显示全部命令
travel — 切换自由行军，开启后可进入当前楼层任意节点
shop — 打开商店
gold 数量 — 添加贝壳（正整数）
heal 百分比 — 恢复部队最大HP的1～100%
battle 怪物识别名 — 进入指定战斗
event 事件名 — 强制进入指定事件，无视出现条件与地图层数
treasure 0|1|2|3 — 打开对应类型的卡牌宝箱
relic [遗物池名称] — 打开遗物宝箱，省略池名使用默认遗物池
add relic 遗物名称 — 获得指定遗物
delet relic 遗物名称 — 删除持有遗物（也支持 delete relic）
add card 卡牌名称 — 获得卡牌，首次重复强化，之后每次等级+5
upgrade [数量] — 选择卡牌强化，默认1次
upgrade test — 切换百科卡牌总览的全部卡牌强化，再次输入或退出总览后恢复
add medal 数量 — 添加勋章（正整数）
add curse 名称|说明 — 获得持续存在的周目诅咒，说明可省略
"""

func _ready() -> void:
	layer = 110
	panel = Control.new()
	panel.size = Vector2(1920, 330)
	add_child(panel)
	var frame := Panel.new()
	frame.size = panel.size
	frame.add_theme_stylebox_override("panel", BattleArt.panel_style())
	panel.add_child(frame)
	BattleArt.label(frame, "控制台", Vector2(24, 10), Vector2(1850, 40), 25, FormationArt.GOLD)
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
	if command.is_empty(): return
	history.append(command)
	history_index = history.size()
	output.append_text("> " + command + "\n")
	entry.clear()
	var result := run_command(command)
	output.append_text(result.message + "\n")
	if result.ok and command.to_lower() != "help": close()

## Shared command dispatcher: event options do not manipulate the console UI.
func run_command(command: String, context: Node = null) -> Dictionary:
	command = command.strip_edges()
	if command.is_empty(): return {"ok": true, "message": "你继续踏上了旅途。"}
	var split := command.split(" ", false, 1)
	var verb := split[0].to_lower()
	var argument := split[1].strip_edges() if split.size() == 2 else ""
	if verb != "help" and get_tree().get_first_node_in_group("card_upgrade_screen") != null:
		return {"ok": false, "message": "请先完成或退出当前卡牌强化。"}
	var message := ""
	var ok := false
	match verb:
		"help":
			message = HELP_TEXT
			ok = true
		"travel":
			if not argument.is_empty(): message = "用法：travel（再次输入关闭自由行军）"
			else:
				var enabled: bool = get_node("/root/RunSession").toggle_travel()
				message = "自由行军已开启：可进入当前楼层任意节点。" if enabled else "自由行军已关闭：恢复正常路线限制。"
				ok = true
		"shop":
			message = get_node("/root/ShopManager").launch()
			ok = message.begins_with("进入商店")
		"upgrade":
			if argument.to_lower() == "test":
				message = get_node("/root/BattleManager").upgrade_test_cards()
				ok = message.begins_with("卡牌总览临时强化")
			else:
				var count := 1 if argument.is_empty() else (int(argument) if argument.is_valid_int() else 0)
				message = get_node("/root/BattleManager").launch_upgrade(count, context.troop if context != null else null)
				ok = message.begins_with("进入卡牌强化")
		"battle":
			message = get_node("/root/BattleManager").launch(argument)
			ok = message.begins_with("进入战斗")
		"event":
			message = get_node("/root/EventManager").launch(argument)
			ok = message.begins_with("进入事件")
		"treasure":
			message = get_node("/root/BattleManager").launch_treasure(int(argument)) if argument in ["0", "1", "2", "3"] else "用法：treasure 0|1|2|3"
			ok = message.begins_with("打开宝箱")
		"relic":
			message = get_node("/root/BattleManager").launch_relic(argument if not argument.is_empty() else "默认遗物池")
			ok = message.begins_with("打开遗物宝箱")
		"heal":
			var session: Node = context if context != null else get_node("/root/EventManager").current_session()
			if session.active and argument.is_valid_int() and int(argument) > 0 and int(argument) <= 100:
				session.heal(int(argument))
				message = "恢复%d%%最大生命。" % int(argument)
				ok = true
			else: message = "用法：heal 1～100（恢复最大HP百分比，需在行军中）"
		"gold":
			var source: TroopState = get_node("/root/BattleManager").current_troop()
			var amount := int(argument) if argument.is_valid_int() else 0
			if source == null: message = "数据加载失败。"
			elif amount <= 0 or amount > 9223372036854775807 - source.gold: message = "用法：gold 正整数数量"
			else:
				source.add_gold(amount)
				message = "获得贝壳：%d" % amount
				ok = true
		"add":
			var args := argument.split(" ", false, 1)
			if args.size() == 2 and args[0].to_lower() == "medal":
				var amount := int(args[1]) if args[1].is_valid_int() else 0
				var source: TroopState = get_node("/root/BattleManager").current_troop()
				if source == null: message = "数据加载失败。"
				elif amount <= 0 or amount > 9223372036854775807 - maxi(source.medals, source.medal_progress): message = "用法：add medal 正整数数量"
				else:
					source.add_medals(amount)
					message = "获得勋章：%d" % amount
					ok = true
			elif args.size() == 2 and args[0].to_lower() == "curse":
				var source: TroopState = context.troop if context != null else get_node("/root/BattleManager").current_troop()
				var curse := TroopState.parse_curse(args[1])
				if source == null: message = "部队数据加载失败。"
				elif curse.is_empty(): message = "用法：add curse 名称|说明"
				else:
					ok = source.acquire_curse(curse.name, curse.description)
					message = ("获得诅咒：" if ok else "已持有诅咒：") + curse.name
			elif args.size() == 2 and args[0].to_lower() in ["relic", "card"]:
				message = get_node("/root/BattleManager").grant(args[0].to_lower(), args[1].strip_edges())
				ok = message.begins_with("获得")
			else: message = "用法：add relic 遗物名称 / add card 卡牌名称 / add medal 正整数数量 / add curse 名称|说明"
		"delet", "delete":
			var args := argument.split(" ", false, 1)
			var source: TroopState = get_node("/root/BattleManager").current_troop()
			if source != null and args.size() == 2 and args[0].to_lower() == "relic":
				ok = source.remove_relic(args[1].strip_edges())
				message = ("删除遗物：" if ok else "未持有遗物：") + args[1].strip_edges()
			else: message = "用法：delet relic 遗物名称"
		_:
			message = "未知命令或参数不完整，输入 help 查看全部命令。"
	return {"ok": ok, "message": message}

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
