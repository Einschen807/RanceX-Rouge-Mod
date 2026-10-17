extends RefCounted
class_name EventCommands
## Preflight inventory operations in order before a destructive exchange starts.
static func validate(commands: PackedStringArray, troop: TroopState, session: Node) -> String:
	var owned := troop.relics.duplicate()
	var curses: Array[String] = []
	for record: Dictionary in troop.curses: curses.append(record.name)
	var gold := troop.gold
	var medals := maxi(troop.medals, troop.medal_progress)
	var relics := RelicCatalog.new()
	if not relics.load_catalog(): return "遗物数据加载失败。"
	for command: String in commands:
		command = command.strip_edges()
		if command.is_empty(): return "斜杠之间的指令不能为空。"
		var parts := command.split(" ", false, 1)
		var verb := parts[0].to_lower()
		var argument := parts[1].strip_edges() if parts.size() == 2 else ""
		match verb:
			"gold":
				if not argument.is_valid_int() or int(argument) <= 0 or int(argument) > 9223372036854775807 - gold: return "用法：gold 正整数数量"
				gold += int(argument)
			"heal":
				if not session.active or not argument.is_valid_int() or int(argument) <= 0 or int(argument) > 100: return "用法：heal 1～100（恢复最大HP百分比，需在行军中）"
			"add", "delet", "delete":
				var args := argument.split(" ", false, 1)
				if args.size() != 2: return "指令参数不完整：" + command
				var kind := args[0].to_lower()
				var name := args[1].strip_edges()
				if verb in ["delet", "delete"]:
					if kind != "relic" or name not in owned: return "未持有要删除的遗物：" + name
					owned.erase(name)
				elif kind == "relic":
					if not relics.by_name.has(name): return "未找到遗物：" + name
					if name in owned: return "已拥有遗物：" + name
					owned.append(name)
				elif kind == "curse":
					var curse := TroopState.parse_curse(name)
					if curse.is_empty(): return "用法：add curse 名称|说明"
					if curse.name in curses: return "已持有诅咒：" + curse.name
					curses.append(curse.name)
				elif kind == "card":
					var card := troop.catalog.find_name(name)
					if card.is_empty() or CardCatalog.is_upgraded(card): return "未找到基础卡牌：" + name
				elif kind == "medal":
					if not name.is_valid_int() or int(name) <= 0 or int(name) > 9223372036854775807 - medals: return "用法：add medal 正整数数量"
					medals += int(name)
				else: return "未知添加类型：" + kind
			"battle":
				if not session.monsters.monsters.has(argument): return "未找到怪物识别名：" + argument
			"event":
				var events := EventCatalog.new()
				if not events.load_catalog(): return "事件数据加载失败。"
				if not events.records.has(argument): return "未找到事件名：" + argument
			"treasure":
				if argument not in ["0", "1", "2", "3"]: return "用法：treasure 0|1|2|3"
			"relic":
				var pool := argument if not argument.is_empty() else "默认遗物池"
				if not relics.pools.has(pool): return "未找到遗物池：" + pool
				if relics.pools[pool].all(func(record: Dictionary) -> bool: return record.name in owned): return "遗物池没有可获得的遗物。"
			"upgrade":
				if not argument.is_empty() and (not argument.is_valid_int() or int(argument) <= 0): return "用法：upgrade [正整数数量]"
			"shop", "help": pass
			_: return "未知命令：" + command
	return ""

static func execute(source: String, session: Node) -> Dictionary:
	if source.strip_edges().is_empty(): return {"ok": true, "message": "你继续踏上了旅途。", "completed": 0}
	var commands := source.split("/", true)
	var error := validate(commands, session.troop, session)
	if not error.is_empty(): return {"ok": false, "message": error, "completed": 0}
	var tree := session.get_tree()
	var battle := session.get_node("/root/BattleManager")
	var shop := session.get_node("/root/ShopManager")
	var transition := session.get_node("/root/ScreenTransition")
	var events := session.get_node("/root/EventManager")
	var pending: Dictionary = session.pending
	var messages := PackedStringArray()
	var completed := 0
	for command: String in commands:
		if not session.active or session.pending != pending: return {"ok": false, "message": "事件已关闭。", "completed": completed}
		var result: Dictionary = session.get_node("/root/DebugConsole").run_command(command.strip_edges(), session)
		if not result.ok:
			messages.append(result.message)
			return {"ok": false, "message": "\n".join(messages), "completed": completed}
		completed += 1
		messages.append(result.message)
		# Commands that open a screen finish that screen before the next command.
		while transition.busy or is_instance_valid(battle.active) or is_instance_valid(battle._upgrade) or is_instance_valid(battle._treasure) or is_instance_valid(battle._relic_chest) or is_instance_valid(shop.active) or (is_instance_valid(events.active) and events.active.session != session):
			await tree.process_frame
			if not session.active or session.pending != pending: return {"ok": false, "message": "事件已关闭。", "completed": completed}
	return {"ok": true, "message": "\n".join(messages), "completed": completed}
