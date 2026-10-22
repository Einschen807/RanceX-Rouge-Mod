extends RefCounted
class_name BattleDoushinTargets
## Private rules for Doushin's skill IDs; targeting is independent of leader powers.
const BODY := 70
const AIM := 71
const LOCK := 72

static func has(state: BattleState, side: String, id: int) -> bool:
	for entry: Dictionary in BattleSupports.group(state, side):
		if int(entry.id) == id: return true
	return false

static func active(state: BattleState) -> bool:
	return has(state, "player", AIM) or has(state, "enemy", LOCK)

static func candidates(state: BattleState) -> Array[String]:
	var result: Array[String] = []
	for actor: String in state.troop.leaders:
		if not actor.is_empty() and not state.troop.is_unavailable(actor): result.append(actor)
	return result

static func roll(state: BattleState) -> void:
	state.locked_targets.clear()
	if not active(state):
		return
	_fill(state)
	if not state.locked_targets.is_empty(): state.log_message("瞄准目标：" + "、".join(state.locked_targets))

static func _fill(state: BattleState, limit: int = -1) -> void:
	if limit < 0: limit = state.doushin_target_count
	var leaders := candidates(state)
	for actor: String in state.locked_targets: leaders.erase(actor)
	while state.locked_targets.size() < limit and not leaders.is_empty():
		var index := state.runtime.rng.randi_range(0, leaders.size() - 1)
		state.locked_targets.append(leaders[index])
		leaders.remove_at(index)

static func sync(state: BattleState) -> void:
	if not active(state): state.locked_targets.clear()
	# The support's automatic action selects the initial target. Synchronization
	# only replaces an existing target that has left the eligible formation.
	elif not state.locked_targets.is_empty():
		var count := state.locked_targets.size()
		var leaders := candidates(state)
		for actor: String in state.locked_targets.duplicate():
			if actor not in leaders: state.locked_targets.erase(actor)
		_fill(state, count)

static func unacted_count(state: BattleState) -> int:
	var count := 0
	for actor: String in state.locked_targets:
		if actor in candidates(state) and not state.runtime.acted.get(actor, false): count += 1
	return count

static func strengthen(state: BattleState) -> void:
	state.doushin_target_count = mini(7, state.doushin_target_count + 1)
	# Next turn's automatic aim draws the larger set exactly once.
	state.log_message("瞄准目标强化：锁定人数%d" % state.doushin_target_count)

static func added(state: BattleState, side: String, id: int) -> void:
	# Add the replacement first so removing its counterpart keeps the target alive.
	if side == "player" and id == AIM: _remove(state, "enemy", LOCK)
	elif side == "enemy" and id == LOCK: _remove(state, "player", AIM)
	if id in [AIM, LOCK]: sync(state)

static func _remove(state: BattleState, side: String, id: int) -> void:
	for entry: Dictionary in BattleSupports.group(state, side).duplicate():
		if int(entry.id) == id: BattleSupports.remove(state, side, int(entry.uid))

static func removed(state: BattleState, side: String, id: int) -> void:
	# Dispelling the temporary attack permission stops this heavy strike, but does
	# not permanently remove the boss's targeting cycle or the on-field marker.
	if side == "enemy" and id == LOCK and not has(state, "player", AIM) and has(state, "enemy", BODY):
		reaim(state)
	else:
		sync(state)

static func enemy_turn_start(state: BattleState) -> void:
	sync(state)
	if BattleSupports.effects(state, "enemy", "doushin_body").is_empty(): return
	if unacted_count(state) == 0:
		if has(state, "enemy", LOCK): reaim(state)
		return
	BattleSupports.add(state, "enemy", LOCK, state.monster.identity)

static func reaim(state: BattleState) -> void:
	# Keep the marker; the support rerolls it at the next player turn's settlement.
	BattleSupports.add(state, "player", AIM, state.monster.identity)
