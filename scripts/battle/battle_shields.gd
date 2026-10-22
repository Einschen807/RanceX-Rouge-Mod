extends RefCounted
class_name BattleShields
## Absolute temporary HP, with independent expiration for each stacked grant.
const MAX_PERCENT := 999.0

static func maximum(state: BattleState, side: String) -> float:
	return state.player_max_hp if side == "player" else state.enemy_max_hp

static func amount(state: BattleState, side: String) -> float:
	var total := 0.0
	for layer: Dictionary in state.shields[side]: total += float(layer.amount)
	return total

static func percent(state: BattleState, side: String) -> float:
	return amount(state, side) / maxf(1.0, maximum(state, side)) * 100.0

## duration_turns=0: permanent. decay_percent=-1: remove all when due.
## Other decay values remove that many percentage points of max HP each period.
## Per-side shield_policy may override defaults or suspend the expiration clock.
## prevent_decay belongs to the side policy, not an individual grant's options.
static func add(state: BattleState, side: String, value: float, options: Dictionary = {}) -> float:
	var policy: Dictionary = state.shield_policy[side].duplicate(true)
	policy.merge(options, true)
	var hp_max := maximum(state, side)
	var added := minf(maxf(0.0, value) * hp_max / 100.0, maxf(0.0, hp_max * MAX_PERCENT / 100.0 - amount(state, side)))
	if added <= 0.0: return 0.0
	var duration := maxi(0, int(policy.get("duration_turns", 1)))
	state.shields[side].append({"amount": added, "remaining_turns": duration, "duration_turns": duration, "decay_percent": float(policy.get("decay_percent", -1.0))})
	state.shield_event.emit(side, "gain")
	return added

static func begin_turn(state: BattleState, side: String) -> void:
	if state.shield_policy[side].get("prevent_decay", false): return
	var before := amount(state, side)
	var expired := 0.0
	for layer: Dictionary in state.shields[side].duplicate():
		if int(layer.duration_turns) == 0: continue
		layer.remaining_turns -= 1
		if int(layer.remaining_turns) > 0: continue
		if float(layer.decay_percent) < 0.0:
			expired += float(layer.amount)
			layer.amount = 0.0
		else: layer.amount = maxf(0.0, float(layer.amount) - maximum(state, side) * float(layer.decay_percent) / 100.0)
		layer.remaining_turns = layer.duration_turns
		if float(layer.amount) <= 0.0: state.shields[side].erase(layer)
	# 冰箱 carries part of the expiring shield into the new turn as a one-turn layer.
	var kept := minf(expired, RelicEffects.fridge_carry(state, side))
	if kept > 0.0: state.shields[side].append({"amount": kept, "remaining_turns": 1, "duration_turns": 1, "decay_percent": -1.0})
	if amount(state, side) < before: state.shield_event.emit(side, "decay")

## Spend the earliest expiration first; return the damage that reaches real HP.
static func absorb(state: BattleState, side: String, damage: float) -> float:
	var remaining := maxf(0.0, damage)
	var before := amount(state, side)
	var layers: Array = state.shields[side]
	layers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_turns := int(a.remaining_turns) if int(a.duration_turns) > 0 else 2147483647
		var b_turns := int(b.remaining_turns) if int(b.duration_turns) > 0 else 2147483647
		return a_turns < b_turns)
	for layer: Dictionary in layers.duplicate():
		var used := minf(remaining, float(layer.amount))
		layer.amount -= used
		remaining -= used
		if float(layer.amount) <= 0.0: layers.erase(layer)
		if remaining <= 0.0: break
	if amount(state, side) < before: state.shield_event.emit(side, "damage")
	return remaining

static func clamp_capacity(state: BattleState, side: String) -> void:
	var excess := amount(state, side) - maximum(state, side) * MAX_PERCENT / 100.0
	if excess > 0.0: absorb(state, side, excess)
