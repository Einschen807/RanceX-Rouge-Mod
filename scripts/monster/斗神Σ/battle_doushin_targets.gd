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
	if not active(state):
		state.locked_target = ""
		return
	var leaders := candidates(state)
	state.locked_target = "" if leaders.is_empty() else leaders[state.runtime.rng.randi_range(0, leaders.size() - 1)]
	if not state.locked_target.is_empty(): state.log_message("瞄准目标：" + state.locked_target)

static func sync(state: BattleState) -> void:
	if not active(state): state.locked_target = ""
	# The support's automatic action selects the initial target. Synchronization
	# only replaces an existing target that has left the eligible formation.
	elif not state.locked_target.is_empty() and state.locked_target not in candidates(state): roll(state)

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
	if state.locked_target.is_empty() or state.runtime.acted.get(state.locked_target, false): return
	BattleSupports.add(state, "enemy", LOCK, state.monster.identity)

static func reaim(state: BattleState) -> void:
	# Keep the marker; the support rerolls it at the next player turn's settlement.
	BattleSupports.add(state, "player", AIM, state.monster.identity)
