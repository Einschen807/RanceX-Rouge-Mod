extends RefCounted
class_name ActMapGenerator
## Layered graph first; rendering never decides connectivity or room contents.
const WIDTH := 7
## Intermediate rows only: start + 22 rooms + boss = 24 steps in every act.
const LENGTHS := [22, 22, 22, 22]
const LEGACY_LENGTHS := [30, 28, 26, 26]
const TYPES := ["monster", "elite", "chest", "unknown", "shop", "rest", "ancient", "boss"]

static func generate(run_seed: int, act: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + (act + 1) * 104729
	var length: int = LENGTHS[act]
	var scale := float(length) / float(LEGACY_LENGTHS[act])
	var rest_count := 2 * (_gaussian_int(rng, 7 if act == 0 else 6, 6, 7) if act < 2 else rng.randi_range(5, 6))
	var counts := {"rest": rest_count, "shop": 6, "elite": 10, "unknown": 2 * (_gaussian_int(rng, 12, 10, 14) - (1 if act > 0 else 0))}
	for kind: String in counts: counts[kind] = roundi(float(counts[kind]) * scale)
	var treasure_row: int = LEGACY_LENGTHS[act] - 12
	var treasure_rows: Array = [roundi(float(treasure_row / 2) * scale), roundi(float(treasure_row) * scale)]
	if roundi(2.0 * scale) == 1:
		# Two original treasure rows merge to their scaled midpoint when rounding to one.
		treasure_rows = [roundi(float(treasure_row / 2 + treasure_row) * 0.5 * scale)]
	var graph := {"length": length, "width": WIDTH, "nodes": {}, "targets": counts, "treasure_rows": treasure_rows, "elite_rest_min_row": roundi(12.0 * scale), "random_rest_stop_row": length - roundi(5.0 * scale)}
	_add(graph, "start", 3, 0, "ancient", false)
	_add(graph, "boss", 3, length + 1, "boss", false)
	var first_col := -1
	for pass_index: int in range(7):
		var col := rng.randi_range(0, WIDTH - 1)
		if pass_index == 1:
			col = (first_col + rng.randi_range(1, WIDTH - 1)) % WIDTH
		if pass_index == 0: first_col = col
		var current := _point(graph, col, 1)
		_link(graph, "start", current)
		for row: int in range(2, length + 1):
			var directions: Array = [-1, 0, 1]
			_shuffle(directions, rng)
			for direction: int in directions:
				var next_col := clampi(col + direction, 0, WIDTH - 1)
				if _crosses(graph, col, row - 1, next_col): continue
				var next := _point(graph, next_col, row)
				_link(graph, current, next)
				current = next
				col = next_col
				break
		_link(graph, current, "boss")
	for node: Dictionary in graph.nodes.values():
		if node.row == 1: _fixed(node, "monster")
		elif node.row == length: _fixed(node, "rest")
		elif node.row in graph.treasure_rows: _fixed(node, "chest")
	var queue: Array = []
	for kind: String in ["rest", "shop", "elite", "unknown"]:
		for unused: int in range(int(counts[kind])): queue.append(kind)
	for attempt: int in range(3):
		var candidates: Array = _nodes_of_type(graph, "")
		_shuffle(candidates, rng)
		for id: String in candidates:
			for unused: int in range(queue.size()):
				var kind: String = queue.pop_front()
				if valid_type(graph, id, kind):
					graph.nodes[id].type = kind
					break
				queue.append(kind)
	for node: Dictionary in graph.nodes.values():
		if node.type == "": node.type = "monster"
	for attempt: int in range(3):
		_prune(graph, rng)
		var repaired := false
		for kind: String in ["shop", "elite", "rest", "unknown"]:
			var missing: int = int(counts[kind]) - _nodes_of_type(graph, kind).size()
			var candidates := _nodes_of_type(graph, "monster")
			_shuffle(candidates, rng)
			for id: String in candidates:
				if missing <= 0: break
				if graph.nodes[id].mutable and valid_type(graph, id, kind):
					graph.nodes[id].type = kind
					missing -= 1
					repaired = true
		if not repaired: break
	_center(graph)
	return graph

static func _gaussian_int(rng: RandomNumberGenerator, mean: int, low: int, high: int) -> int:
	for attempt: int in range(32):
		var value := roundi(rng.randfn(mean, 1.0))
		if value >= low and value <= high: return value
	return clampi(mean, low, high)

static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var previous: Variant = values[i]
		values[i] = values[j]
		values[j] = previous

static func _add(graph: Dictionary, id: String, col: int, row: int, kind: String, mutable: bool) -> void:
	graph.nodes[id] = {"id": id, "col": col, "row": row, "type": kind, "mutable": mutable, "children": [], "parents": []}

static func _point(graph: Dictionary, col: int, row: int) -> String:
	var id := "r%d_c%d" % [row, col]
	if not graph.nodes.has(id): _add(graph, id, col, row, "", true)
	return id

static func _link(graph: Dictionary, parent: String, child: String) -> void:
	if child not in graph.nodes[parent].children: graph.nodes[parent].children.append(child)
	if parent not in graph.nodes[child].parents: graph.nodes[child].parents.append(parent)

static func _crosses(graph: Dictionary, col: int, row: int, next_col: int) -> bool:
	if col == next_col: return false
	var neighbor := "r%d_c%d" % [row, next_col]
	if not graph.nodes.has(neighbor): return false
	for child: String in graph.nodes[neighbor].children:
		if graph.nodes[child].col == col: return true
	return false

static func _fixed(node: Dictionary, kind: String) -> void:
	node.type = kind
	node.mutable = false

static func _nodes_of_type(graph: Dictionary, kind: String) -> Array:
	var result: Array = []
	for id: String in graph.nodes:
		if graph.nodes[id].type == kind: result.append(id)
	result.sort()
	return result

static func valid_type(graph: Dictionary, id: String, kind: String) -> bool:
	var node: Dictionary = graph.nodes[id]
	if node.row < int(graph.get("elite_rest_min_row", 12)) and kind in ["rest", "elite"]: return false
	if node.row >= int(graph.get("random_rest_stop_row", int(graph.length) - 5)) and kind == "rest": return false
	if kind in ["rest", "elite", "chest", "shop"]:
		for other: String in node.parents + node.children:
			if graph.nodes[other].type == kind: return false
	if kind in ["rest", "monster", "unknown", "elite", "shop"]:
		for parent: String in node.parents:
			for sibling: String in graph.nodes[parent].children:
				if sibling != id and graph.nodes[sibling].type == kind: return false
	return true

static func _prune(graph: Dictionary, rng: RandomNumberGenerator) -> void:
	# Compare simple branch-to-merge corridors, avoiding exponential full-path enumeration
	# on the doubled maps. Interior nodes must have exactly one parent and child.
	for attempt: int in range(50):
		var removed := false
		var ids: Array = graph.nodes.keys()
		ids.sort()
		for start: String in ids:
			if graph.nodes[start].children.size() < 2: continue
			var groups := {}
			for child: String in graph.nodes[start].children:
				var path: Array = [child]
				var cursor := child
				while graph.nodes[cursor].parents.size() == 1 and graph.nodes[cursor].children.size() == 1:
					cursor = graph.nodes[cursor].children[0]
					path.append(cursor)
				if path.size() < 2 or graph.nodes[cursor].parents.size() < 2: continue
				var signature := cursor
				for step: String in path: signature += ":" + str(graph.nodes[step].type)
				if not groups.has(signature): groups[signature] = []
				groups[signature].append(path)
			for paths: Array in groups.values():
				if paths.size() < 2: continue
				_shuffle(paths, rng)
				for index: int in range(paths.size() - 1):
					var path: Array = paths[index]
					graph.nodes[start].children.erase(path[0])
					graph.nodes[path[-1]].parents.erase(path[-2])
					for step: String in path.slice(0, path.size() - 1): graph.nodes.erase(step)
				removed = true
				break
			if removed: break
		if not removed: break

static func _center(graph: Dictionary) -> void:
	var low := 6
	var high := 0
	for node: Dictionary in graph.nodes.values():
		if node.id in ["start", "boss"]: continue
		low = mini(low, int(node.col))
		high = maxi(high, int(node.col))
	var shift := roundi(float(6 - low - high) * 0.5)
	for node: Dictionary in graph.nodes.values():
		if node.id not in ["start", "boss"]: node.col += shift

static func validate(graph: Dictionary) -> String:
	# Existing checkpoints retain their complete graph and route progress.
	if not graph.get("nodes") is Dictionary or not RecordTable.integer(graph.get("length")) or (int(graph.length) not in LENGTHS and int(graph.length) not in LEGACY_LENGTHS): return "地图结构或长度无效"
	var nodes: Dictionary = graph.nodes
	if not nodes.has("start") or not nodes.has("boss"): return "地图缺少起点或BOSS"
	var coordinates := {}
	for id: String in nodes:
		var n: Variant = nodes[id]
		if not n is Dictionary or n.get("id") != id or not n.get("children") is Array or not n.get("parents") is Array or n.get("type") not in TYPES: return "地图节点字段无效"
		if not RecordTable.integer(n.get("row")) or not RecordTable.integer(n.get("col")) or n.col < 0 or n.col >= WIDTH or n.row < 0 or n.row > graph.length + 1: return "地图节点坐标无效"
		var coord := "%d:%d" % [n.row, n.col]
		if coordinates.has(coord): return "地图节点坐标重复"
		coordinates[coord] = true
		for child: Variant in n.children:
			if not child is String or not nodes.has(child): return "地图连线目标无效"
			if nodes[child].row != n.row + 1 or id not in nodes[child].parents: return "地图连线层级无效"
			if id != "start" and child != "boss" and absi(int(n.col) - int(nodes[child].col)) > 1: return "地图连线跨度无效"
		for parent: Variant in n.parents:
			if not parent is String or not nodes.has(parent) or id not in nodes[parent].children: return "地图父子连接不一致"
	var reachable := _reachable(nodes, "start", "children")
	var returnable := _reachable(nodes, "boss", "parents")
	if reachable.size() != nodes.size() or returnable.size() != nodes.size(): return "地图包含断路或不可达节点"
	return ""

static func _reachable(nodes: Dictionary, start: String, field: String) -> Dictionary:
	var visited := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var id: String = queue.pop_front()
		for other: String in nodes[id][field]:
			if not visited.has(other):
				visited[other] = true
				queue.append(other)
	return visited
