extends RefCounted
class_name RelicEffects
## Execution follows inventory order, also the left-to-right HUD order.
const PERIODS := {"加奈美忍法帖": 6, "3段喷射发动机": 3}

static func shop_discount(troop: TroopState) -> float:
	return 0.5 if "邦奥佩塔之证Ａ" in troop.relics else 1.0

static func turn_start(state: BattleState) -> void:
	for name: String in state.troop.relics:
		if state.phase != "player": break
		var triggered := false
		if PERIODS.has(name):
			var period: int = PERIODS[name]
			state.troop.relic_counters[name] = (int(state.troop.relic_counters.get(name, 0)) + 1) % period
			if state.troop.relic_counters[name] == 0:
				if name == "加奈美忍法帖": triggered = BattleSupports.add(state, "player", 60, name)
				else:
					state.ap = mini(state.ap_max(), state.ap + 1)
					triggered = true
		elif name == "妖怪宝具":
			triggered = BattleSupports.add(state, "player", 10, name)
		elif name == "郁金香2号" and state.round == 1:
			var before := state.enemy_hp
			state._apply("player", {"type": 2}, [{"kind": "damage", "amount": state.troop.total("at") * 5.0, "element": 0, "actor": name, "relic_source": true}])
			state.pending_relic_feedback.append({"name": name, "damage": before - state.enemy_hp})
			state._check_result()
			triggered = true
		if triggered:
			state.log_message("遗物发动：" + name)
			state.relic_triggered.emit(name)
