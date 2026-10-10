extends Node
## A single active run, saved only at root-node entry. No manual-save UI or slots.
signal entry_loaded(entry: Dictionary)
signal save_failed(message: String)
signal checkpoint_changed
const VERSION := 1
const SAVE_PATH := "user://run_checkpoint.json"
const BACKUP_PATH := SAVE_PATH + ".bak"
const TEMP_PATH := SAVE_PATH + ".tmp"
var run_id := ""
var rng := RandomNumberGenerator.new()
var last_error := ""
var _entry: Dictionary = {}
var _node_active := false
var _subscenes: Array[Dictionary] = []

func begin_run(id: String, seed_value: int) -> void:
	# This alone does not create a save. The first root node commits the new run.
	run_id = id
	rng.seed = seed_value
	_entry.clear()
	_subscenes.clear()
	_node_active = false
	last_error = ""

func enter_node(id: String, kind: String, initial_node: Dictionary, progress: Dictionary, troop: TroopState) -> Error:
	# Event choices, child battles and other in-node screens cannot advance the save.
	if _node_active or not _subscenes.is_empty(): return _fail("当前节点尚未结束，不能覆盖入口存档", ERR_ALREADY_IN_USE)
	if run_id.is_empty() or id.is_empty() or kind.is_empty() or troop == null: return _fail("节点入口缺少周目或节点信息", ERR_INVALID_PARAMETER)
	var entry := {"version": VERSION, "run_id": run_id, "rng_seed": str(rng.seed), "rng_state": str(rng.state), "node": {"id": id, "kind": kind, "initial": initial_node.duplicate(true)}, "progress": progress.duplicate(true), "troop": TroopCheckpoint.capture(troop)}
	if not _valid(entry, troop.catalog): return _fail("节点入口数据不是完整的可序列化快照", ERR_INVALID_DATA)
	var error := _commit(entry, troop.catalog)
	if error != OK: return error
	_entry = entry
	_node_active = true
	checkpoint_changed.emit()
	return OK

func enter_subscene(kind: String, context: Dictionary = {}) -> bool:
	if not _node_active or kind.is_empty(): return false
	_subscenes.append({"kind": kind, "context": context.duplicate(true)})
	return true

func leave_subscene() -> void:
	if not _subscenes.is_empty(): _subscenes.pop_back()

func finish_node() -> bool:
	if not _node_active or not _subscenes.is_empty(): return false
	# Retain the entry file until the next node successfully commits its checkpoint.
	_node_active = false
	return true

func resume(troop: TroopState) -> Dictionary:
	if troop == null or troop.catalog == null:
		_fail("读档需要已加载的卡牌数据库", ERR_INVALID_PARAMETER)
		return {}
	last_error = ""
	var entry := _read(SAVE_PATH, troop.catalog)
	if entry.is_empty():
		# Refuse a newer schema rather than rolling a newer run back to an old backup.
		if last_error == "存档版本高于当前游戏版本": return {}
		entry = _read(BACKUP_PATH, troop.catalog)
	if entry.is_empty(): return {}
	if not TroopCheckpoint.restore(troop, entry.troop):
		_fail("存档编制数据无法恢复", ERR_INVALID_DATA)
		return {}
	run_id = entry.run_id
	rng.seed = int(entry.rng_seed)
	rng.state = int(entry.rng_state)
	_entry = entry.duplicate(true)
	_node_active = true
	_subscenes.clear()
	last_error = ""
	troop.changed.emit()
	# The future node router reconstructs this entrance, never a child/mid-action view.
	entry_loaded.emit(entry.duplicate(true))
	return entry.duplicate(true)

func entry_snapshot() -> Dictionary:
	return _entry.duplicate(true)

func peek_entry(catalog: CardCatalog) -> Dictionary:
	var previous_error := last_error
	var entry := _read(SAVE_PATH, catalog)
	if entry.is_empty() and last_error != "存档版本高于当前游戏版本":
		entry = _read(BACKUP_PATH, catalog)
	last_error = previous_error
	return entry

func discard_run() -> Error:
	# Remove the recovery copy as well, so an abandoned run cannot return via fallback.
	for path: String in [TEMP_PATH, BACKUP_PATH, SAVE_PATH]:
		if not FileAccess.file_exists(path): continue
		var error := DirAccess.remove_absolute(path)
		if error != OK: return _fail("无法清除本局存档。", error)
	run_id = ""
	_entry.clear()
	_subscenes.clear()
	_node_active = false
	last_error = ""
	checkpoint_changed.emit()
	return OK

func _commit(entry: Dictionary, catalog: CardCatalog) -> Error:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null: return _fail("自动存档临时文件无法写入", FileAccess.get_open_error())
	file.store_string(JSON.stringify(entry, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return _fail("自动存档写入失败", error)
	# On Windows, retain the old complete file across the replacement window.
	if FileAccess.file_exists(SAVE_PATH):
		if not _read(SAVE_PATH, catalog).is_empty():
			if FileAccess.file_exists(BACKUP_PATH):
				error = DirAccess.remove_absolute(BACKUP_PATH)
				if error != OK: return _fail("自动存档备份无法更新", error)
			error = DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH)
			if error != OK: return _fail("自动存档旧文件无法保留", error)
		else:
			# A damaged primary must not replace the last valid recovery copy.
			error = DirAccess.remove_absolute(SAVE_PATH)
			if error != OK: return _fail("损坏的自动存档无法替换", error)
	error = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if error != OK:
		if FileAccess.file_exists(BACKUP_PATH): DirAccess.rename_absolute(BACKUP_PATH, SAVE_PATH)
		return _fail("自动存档无法提交", error)
	last_error = ""
	return OK

func _read(path: String, catalog: CardCatalog) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "未找到可读取的节点存档"
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		last_error = "节点存档内容损坏"
		return {}
	var data: Dictionary = parser.data
	if TroopCheckpoint._number(data.get("version")) and float(data.version) > VERSION:
		last_error = "存档版本高于当前游戏版本"
		return {}
	if not _valid(data, catalog):
		last_error = "节点存档版本或内容不受支持"
		return {}
	return data

func _valid(data: Dictionary, catalog: CardCatalog) -> bool:
	if data.get("version", 0) != VERSION or not data.get("run_id", null) is String or data.run_id.is_empty(): return false
	for key: String in ["rng_seed", "rng_state"]:
		if not data.get(key, null) is String or not data[key].is_valid_int(): return false
	if not data.get("node", null) is Dictionary or not data.get("progress", null) is Dictionary: return false
	for key: String in ["id", "kind"]:
		if not data.node.get(key, null) is String or data.node[key].is_empty(): return false
	if not data.node.get("initial", null) is Dictionary or not data.get("troop", null) is Dictionary: return false
	return TroopCheckpoint.valid(data.troop, catalog) and _plain(data)

func _plain(value: Variant, depth := 0) -> bool:
	if depth > 64: return false
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _plain(value[key], depth+1): return false
		return true
	if value is Array:
		for item: Variant in value:
			if not _plain(item, depth+1): return false
		return true
	return value == null or value is String or value is bool or TroopCheckpoint._number(value)

func _fail(message: String, error: Error) -> Error:
	last_error = message
	save_failed.emit(message)
	return error
