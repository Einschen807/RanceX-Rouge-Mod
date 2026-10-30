extends CanvasLayer
var panel: Control
var entry: LineEdit
var output: RichTextLabel
var history: Array[String] = []
var history_index := 0
## Completion list above the input line: ↓↑ select, Tab/click/Enter on a selection completes.
var suggestions := ConsoleSuggestions.new()
var suggestion_box: Panel
var _matches: Array[Dictionary] = []
var _selected := -1
const SUGGESTION_ROWS := 6
const SUGGESTION_HEIGHT := 31.0
const HELP_TEXT := """可用命令：
help — 显示全部命令
travel — 切换自由移动，开启后可进入当前楼层任意节点
shop [商店名] — 打开商店；shop 米莉 打开米莉的小店
gold 数量 — 添加贝壳（正整数）
pay 数量 — 支付贝壳（正整数，不足时失败）
heal 百分比 — 恢复部队最大HP的1～100%
hurt 百分比 — 失去最大HP的1～99%，至少保留1点HP
battle 怪物识别名 — 进入指定战斗
event 事件名 — 强制进入指定事件，无视出现条件与地图层数
treasure 0|1|2|3 — 打开对应类型的卡牌宝箱
relic [遗物池名称] — 打开遗物宝箱，省略池名使用默认遗物池
add relic 遗物名称 — 获得指定遗物
choose relic 名称|名称|… — 从列出的未持有遗物中选择1件
random relic 数量 名称|名称|… — 从列出的未持有遗物中随机获得指定数量
delet relic 遗物名称 — 删除持有遗物（也支持 delete relic）
add card 卡牌名称 — 获得卡牌，首次重复强化，之后每次等级+5
upgrade [数量] — 选择卡牌强化，默认1次
upgrade test — 切换百科卡牌总览的全部卡牌强化，再次输入或退出总览后恢复
upgrade initial — 直接强化持有的全部初始卡组卡牌（需在冒险中）
enchantment 附魔名 — 选择1张卡牌的1个技能附魔（每张卡牌只能附魔一次）
roulette 50|100|all — 赌场轮盘：押注50、100或全部贝壳，再选红／黑／绿
add medal 数量 — 添加勋章（正整数）
add curse 诅咒名称 — 获得 data/curses.txt 中的诅咒卡，已持有时不重复获得
maxhp 百分比 — HP增加率提升1～100%
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
	entry.text_submitted.connect(_submit)
	entry.text_changed.connect(func(_text: String) -> void: _refresh_suggestions())
	frame.add_child(entry)
	suggestion_box = Panel.new()
	suggestion_box.name = "Suggestions"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.04, 0.97)
	style.border_color = Color(FormationArt.GOLD, 0.55)
	style.set_border_width_all(1)
	suggestion_box.add_theme_stylebox_override("panel", style)
	suggestion_box.position = Vector2(24, 256)
	suggestion_box.size = Vector2(1872, 0)
	frame.add_child(suggestion_box)
	suggestion_box.hide()
	suggestions.owned_relics = func() -> Array:
		var source: TroopState = get_node("/root/BattleManager").current_troop(false)
		return source.relics if source != null else []
	panel.hide()

func toggle() -> void:
	if panel.visible:
		close()
	else:
		panel.show()
		panel.add_to_group("modal_overlay")
		entry.grab_focus()

func _submit(command: String) -> void:
	# Enter on a highlighted suggestion completes it; the next Enter runs the line.
	if suggestion_box.visible and _selected >= 0:
		_complete(_selected)
		return
	execute(command)

func _refresh_suggestions() -> void:
	_matches = suggestions.suggest(entry.text)
	# Nothing left to complete when the line already equals the only candidate.
	if _matches.size() == 1 and String(_matches[0].text).strip_edges() == entry.text.strip_edges(): _matches.clear()
	_selected = -1
	_draw_suggestions()

func _draw_suggestions() -> void:
	BattleArt.clear(suggestion_box)
	if _matches.is_empty():
		suggestion_box.hide()
		return
	var shown := mini(SUGGESTION_ROWS, _matches.size())
	# Keep the highlighted row inside the visible window.
	var first := clampi(_selected - shown + 1, 0, _matches.size() - shown) if _selected >= shown else 0
	suggestion_box.size.y = shown * SUGGESTION_HEIGHT + 8.0
	suggestion_box.position.y = 256.0 - suggestion_box.size.y
	for row: int in range(shown):
		var index := first + row
		var match: Dictionary = _matches[index]
		var button := Button.new()
		button.position = Vector2(4, 4 + row * SUGGESTION_HEIGHT)
		button.size = Vector2(suggestion_box.size.x - 8, SUGGESTION_HEIGHT)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var highlight := StyleBoxFlat.new()
		highlight.bg_color = Color(FormationArt.GOLD, 0.22)
		button.add_theme_stylebox_override("normal", highlight if index == _selected else StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", highlight)
		button.add_theme_stylebox_override("pressed", highlight)
		button.pressed.connect(_complete.bind(index))
		suggestion_box.add_child(button)
		var label := BattleArt.label(button, String(match.label), Vector2(10, 0), Vector2(900, SUGGESTION_HEIGHT), 21, FormationArt.GOLD if index == _selected else Color.WHITE)
		label.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hint := BattleArt.label(button, String(match.hint), Vector2(920, 0), Vector2(button.size.x - 930, SUGGESTION_HEIGHT), 18, Color(0.68, 0.66, 0.62))
		hint.add_theme_font_override("font", CardWidget.CARD_TEXT_FONT)
		hint.clip_text = true
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _matches.size() > shown:
		var count := BattleArt.label(suggestion_box, "%d/%d" % [maxi(_selected, 0) + 1, _matches.size()], Vector2(suggestion_box.size.x - 110, 4), Vector2(100, SUGGESTION_HEIGHT), 16, Color(0.68, 0.66, 0.62), HORIZONTAL_ALIGNMENT_RIGHT)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	suggestion_box.show()

func _complete(index: int) -> void:
	if index < 0 or index >= _matches.size(): return
	entry.text = String(_matches[index].text)
	entry.caret_column = entry.text.length()
	entry.grab_focus()
	_refresh_suggestions()

func close() -> void:
	panel.hide()
	_matches.clear()
	suggestion_box.hide()
	panel.remove_from_group("modal_overlay")
	entry.release_focus()

func execute(command: String) -> void:
	command = command.strip_edges()
	if command.is_empty(): return
	history.append(command)
	history_index = history.size()
	output.append_text("> " + command + "\n")
	entry.clear()
	_refresh_suggestions()
	var result := run_command(command)
	output.append_text(result.message + "\n")
	if result.ok and command.to_lower() != "help": close()

## Shared command dispatcher: event options do not manipulate the console UI.
func run_command(command: String, context: Node = null) -> Dictionary:
	command = command.strip_edges()
	if command.is_empty(): return {"ok": true, "message": ""}
	var split := command.split(" ", false, 1)
	var verb := split[0].to_lower()
	var argument := split[1].strip_edges() if split.size() == 2 else ""
	if verb != "help" and get_tree().get_first_node_in_group("card_upgrade_screen") != null:
		return {"ok": false, "message": "请先完成或退出当前卡牌强化／附魔。"}
	var message := ""
	var ok := false
	match verb:
		"help":
			message = HELP_TEXT
			ok = true
		"travel":
			if not argument.is_empty(): message = "用法：travel（再次输入关闭自由移动）"
			else:
				var enabled: bool = get_node("/root/RunSession").toggle_travel()
				message = "自由移动已开启：可进入当前楼层任意节点。" if enabled else "自由移动已关闭：恢复正常路线限制。"
				ok = true
		"shop":
			message = get_node("/root/ShopManager").launch(argument)
			ok = message.begins_with("进入")
		"upgrade":
			if argument.to_lower() == "test":
				message = get_node("/root/BattleManager").upgrade_test_cards()
				ok = message.begins_with("卡牌总览临时强化")
			elif argument.to_lower() == "initial":
				message = _upgrade_initial()
				ok = message.begins_with("初始卡组已强化")
			else:
				var count := 1 if argument.is_empty() else (int(argument) if argument.is_valid_int() else 0)
				message = get_node("/root/BattleManager").launch_upgrade(count, context.troop if context != null else null)
				ok = message.begins_with("进入卡牌强化")
		"enchantment":
			if argument.is_empty(): message = "用法：enchantment 附魔名"
			else:
				message = get_node("/root/BattleManager").launch_enchant(argument, context.troop if context != null else null)
				ok = message.begins_with("进入卡牌附魔")
		"roulette":
			var source: TroopState = context.troop if context != null else get_node("/root/BattleManager").current_troop()
			message = get_node("/root/EventManager").launch_roulette(argument.to_lower(), source)
			ok = message.begins_with("开始轮盘")
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
			else: message = "用法：heal 1～100（恢复最大HP百分比，需在冒险中）"
		"hurt":
			var session: Node = context if context != null else get_node("/root/EventManager").current_session()
			if session.active and argument.is_valid_int() and int(argument) > 0 and int(argument) < 100:
				message = "失去%d点生命。" % session.hurt(int(argument))
				ok = true
			else: message = "用法：hurt 1～99（失去最大HP百分比，需在冒险中；生命归零即失败）"
		"maxhp":
			var source: TroopState = context.troop if context != null else get_node("/root/BattleManager").current_troop()
			if source == null: message = "部队数据加载失败。"
			elif argument.is_valid_int() and int(argument) > 0 and int(argument) <= 100:
				source.add_max_hp_bonus(int(argument))
				message = "HP增加率提升%d%%。" % int(argument)
				ok = true
			else: message = "用法：maxhp 1～100（HP增加率提升百分比）"
		"choose":
			var args := argument.split(" ", false, 1)
			if args.size() == 2 and args[0].to_lower() == "relic":
				message = get_node("/root/BattleManager").launch_relic_choice(EventCommands.relic_list(args[1]), context != null)
				ok = message.begins_with("选择遗物") or message == "没有可获得的遗物。"
			else: message = "用法：choose relic 名称|名称|…"
		"random":
			var args := argument.split(" ", false, 2)
			if args.size() == 3 and args[0].to_lower() == "relic" and args[1].is_valid_int() and int(args[1]) > 0:
				message = get_node("/root/BattleManager").grant_random_relics(int(args[1]), EventCommands.relic_list(args[2]))
				ok = message.begins_with("获得遗物") or message == "没有可获得的遗物。"
			else: message = "用法：random relic 数量 名称|名称|…"
		"pay":
			var source: TroopState = get_node("/root/BattleManager").current_troop()
			var amount := int(argument) if argument.is_valid_int() else 0
			if source == null: message = "数据加载失败。"
			elif amount <= 0: message = "用法：pay 正整数数量"
			elif not source.spend_gold(amount): message = "贝壳不足：需要%d，持有%d。" % [amount, source.gold]
			else:
				message = "支付贝壳：%d" % amount
				ok = true
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
				var name := args[1].strip_edges()
				if source == null: message = "部队数据加载失败。"
				elif not CurseCatalog.shared().by_name.has(name): message = "未找到诅咒：" + name
				else:
					# Already holding it is not a failure: events continue with their other rewards.
					ok = true
					message = ("获得诅咒：" if source.acquire_curse(name) else "已持有诅咒：") + name
			elif args.size() == 2 and args[0].to_lower() in ["relic", "card"]:
				message = get_node("/root/BattleManager").grant(args[0].to_lower(), args[1].strip_edges())
				ok = message.begins_with("获得")
			else: message = "用法：add relic 遗物名称 / add card 卡牌名称 / add medal 正整数数量 / add curse 诅咒名称"
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

## Upgrades every owned card of data/initial_deck.txt that still has a + version.
func _upgrade_initial() -> String:
	var session := get_node("/root/RunSession")
	if not session.active or session.troop == null: return "upgrade initial 需在冒险中使用。"
	var upgraded: PackedStringArray = []
	for name: String in session.pools.initial_cards:
		var owned: String = session.troop.owned_version(name)
		if owned != name or session.troop.catalog.find_name(name + CardCatalog.UPGRADE_SUFFIX).is_empty(): continue
		if session.troop.upgrade_card(owned): upgraded.append(name + CardCatalog.UPGRADE_SUFFIX)
	return "初始卡组已强化：" + "、".join(upgraded) if not upgraded.is_empty() else "初始卡组没有可强化的卡牌。"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_QUOTELEFT, KEY_ASCIITILDE] or event.physical_keycode == KEY_QUOTELEFT):
		get_viewport().set_input_as_handled()
		toggle()
	elif panel.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			# Back closes the completion list first, then the console.
			if suggestion_box.visible:
				_matches.clear()
				suggestion_box.hide()
			else: close()
		elif suggestion_box.visible and event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			_complete(maxi(_selected, 0))
		elif suggestion_box.visible and event is InputEventKey and event.pressed and event.keycode in [KEY_UP, KEY_DOWN]:
			get_viewport().set_input_as_handled()
			# ↓ moves down the list from its best match; ↑ back to the top returns to plain typing.
			_selected = clampi(_selected + (1 if event.keycode == KEY_DOWN else -1), -1, _matches.size() - 1)
			_draw_suggestions()
		elif event is InputEventKey and event.pressed and event.keycode in [KEY_UP, KEY_DOWN]:
			get_viewport().set_input_as_handled()
			history_index = clampi(history_index + (-1 if event.keycode == KEY_UP else 1), 0, history.size())
			entry.text = history[history_index] if history_index < history.size() else ""
			entry.caret_column = entry.text.length()
