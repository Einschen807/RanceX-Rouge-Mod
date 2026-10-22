extends RefCounted
class_name RelicEffects
## Execution follows inventory order, also the left-to-right HUD order.
## Persistent counters shown on the HUD. Most advance per player turn; AP_SPENT ones advance per AP paid.
const PERIODS := {"加奈美忍法帖": 6, "3段喷射发动机": 3, "飞马": 10, "瓦古奖章": 10}
const AP_SPENT := ["飞马"]
## Skill 0 means the native AP+1 recovery handled in execute().
const SKILLS := {"加奈美忍法帖": 9800, "妖怪宝具": 9801, "郁金香2号": 9802, "郁金香兵": 9803, "郁金香3号": 9804, "平实柠檬": 9805, "赫尔曼石墙": 9806, "守护神": 9807, "塔罗柯发动机": 0, "利萨斯的旗帜": 9808, "赫尔曼的旗帜": 9809, "男人的友情": 9810, "医学全集": 9811, "雷伊奖章": 9812, "希尔琪奖章": 9813, "瓦古奖章": 9814}
## Fired once at the start of round 1.
const BATTLE_START := ["郁金香2号", "平实柠檬", "赫尔曼石墙", "塔罗柯发动机", "守护神", "医学全集"]
## Fired when the player ends the given round, before the enemy turn begins.
const TURN_END_ROUNDS := {"郁金香3号": 7}
## 希尔琪奖章: fired at every player turn end while the shield reaches this percent of max HP.
const HILCHI_SHIELD := 10.0
## 侍从铠甲: extra shield percent on every player skill shield grant (not relics or supports).
const SQUIRE_SHIELD := 1.0
const MALE := 1

static func shop_discount(troop: TroopState) -> float:
	return 0.5 if "邦奥佩塔之证Ａ" in troop.relics else 1.0

static func turn_start(state: BattleState) -> void:
	var actions: Array[Dictionary] = []
	for name: String in state.troop.relics:
		if state.phase != "player": break
		var triggered := false
		if name in AP_SPENT:
			continue
		elif PERIODS.has(name):
			var period: int = PERIODS[name]
			state.troop.relic_counters[name] = (int(state.troop.relic_counters.get(name, 0)) + 1) % period
			triggered = state.troop.relic_counters[name] == 0
		elif name in ["妖怪宝具", "郁金香兵", "利萨斯的旗帜", "赫尔曼的旗帜"]:
			triggered = true
		elif name == "男人的友情":
			triggered = all_male(state.troop)
		elif name in BATTLE_START and state.round == 1:
			triggered = true
		if triggered:
			var entry := {"name": name, "id": int(SKILLS.get(name, 0))}
			actions.append(entry)
	_dispatch(state, actions)

## 冰箱: expiring player shield may carry over, up to this percent of max HP.
const FRIDGE_PERCENT := 10.0
## 自由的旗帜: flat bonus on every troop rate, including critical/combo chances.
const FREEDOM_RATE := 3.0
const FREEDOM_KINDS := ["hp", "physical", "magic", "physical_resist", "magic_resist", "critical", "combo"]

static func troop_rate_bonus(troop: TroopState, kind: String) -> float:
	return FREEDOM_RATE if kind in FREEDOM_KINDS and "自由的旗帜" in troop.relics else 0.0

static func fridge_carry(state: BattleState, side: String) -> float:
	return BattleShields.maximum(state, side) * FRIDGE_PERCENT / 100.0 if side == "player" and "冰箱" in state.troop.relics else 0.0

## 兰斯/健太郎 always break barriers; 圣刀日光 lets every player character do it.
## Support and relic attacks never borrow a character's identity.
static func can_break_barrier(state: BattleState, attacker_side: String, command: Dictionary) -> bool:
	if command.get("support_source", false) or command.get("relic_source", false): return false
	var identity := String(command.get("actor_identity", ""))
	if identity in ["兰斯", "健太郎"]: return true
	return attacker_side == "player" and not identity.is_empty() and "圣刀日光" in state.troop.relics

## 魔剑卡奥斯: breaking the enemy barrier inflicts 1 round of 致命伤.
static func barrier_broken(state: BattleState, owner_side: String) -> void:
	if owner_side != "enemy" or "魔剑卡奥斯" not in state.troop.relics: return
	if state.apply_status("player", "enemy", BattleStatusEffects.LETHAL_WOUND, 1): notify(state, "魔剑卡奥斯")

## 赛斯的旗帜: the player's first successful status application each battle lasts 1 round longer.
static func status_bonus(state: BattleState, source_side: String) -> int:
	return 1 if source_side == "player" and not state.seth_flag_used and "赛斯的旗帜" in state.troop.relics else 0

## Special eggs hatch at a rest site into the small saint card.
const EGGS := {"生命之蛋": "圣女 温丽娜小", "时间之蛋": "圣女 塞菈库勒斯小", "大地之蛋": "圣女 胡瑟苏娜小", "力量之蛋": "圣女 贝泽爱小"}
const SMALL_SAINTS := ["圣女 温丽娜小", "圣女 塞菈库勒斯小", "圣女 胡瑟苏娜小", "圣女 贝泽爱小"]

static func held_eggs(troop: TroopState) -> Array[String]:
	var result: Array[String] = []
	for name: String in troop.relics: if EGGS.has(name): result.append(name)
	return result

## Owned small saints (base or +) and the adult record each grows into.
static func growable_saints(troop: TroopState) -> Dictionary:
	var result := {}
	for small: String in SMALL_SAINTS:
		var owned := troop.owned_version(small)
		if owned.is_empty(): continue
		var adult := small.trim_suffix("小")
		if owned.ends_with(CardCatalog.UPGRADE_SUFFIX) and not troop.catalog.find_name(adult + CardCatalog.UPGRADE_SUFFIX).is_empty():
			adult += CardCatalog.UPGRADE_SUFFIX
		result[owned] = adult
	return result

## 岩石花 removes one of the player's status-bar slots.
static func status_capacity(state: BattleState, side: String) -> int:
	return BattleStatusEffects.MAX_TYPES - (1 if side == "player" and "岩石花" in state.troop.relics else 0)

## 飞马: every 10 AP paid for player skills recovers 1 AP; the remainder carries over.
static func ap_spent(state: BattleState, amount: int) -> void:
	if amount <= 0 or "飞马" not in state.troop.relics: return
	var total := int(state.troop.relic_counters.get("飞马", 0)) + amount
	var gains := total / int(PERIODS["飞马"])
	state.troop.relic_counters["飞马"] = total % int(PERIODS["飞马"])
	if gains <= 0: return
	state.ap = mini(state.ap_max(), state.ap + gains)
	notify(state, "飞马")

## One-off effects on acquisition. HP is restored by the run and any active battle.
static func acquired(troop: TroopState, name: String) -> void:
	if name == "中元茶泡饭": troop.reset_card_states()

static func turn_end(state: BattleState) -> void:
	var actions: Array[Dictionary] = []
	for name: String in state.troop.relics:
		var triggered: bool = TURN_END_ROUNDS.get(name, -1) == state.round
		if name == "希尔琪奖章": triggered = BattleShields.percent(state, "player") + 0.000001 >= HILCHI_SHIELD
		if triggered: actions.append({"name": name, "id": int(SKILLS.get(name, 0))})
	_dispatch(state, actions)

## 男人的友情: every deployed leader, DOWN ones included, must be male.
static func all_male(troop: TroopState) -> bool:
	var found := false
	for name: String in troop.leaders:
		if name.is_empty(): continue
		if int(troop.catalog.find_name(name).get("gender", 0)) != MALE: return false
		found = true
	return found

## 侍从铠甲: skill shields only; relic and support shields get no bonus.
static func shield_bonus(state: BattleState, command: Dictionary) -> float:
	if String(command.get("side", "")) != "player" or float(command.get("percent", 0.0)) <= 0.0: return 0.0
	if command.get("relic_source", false) or command.get("support_source", false) or "侍从铠甲" not in state.troop.relics: return 0.0
	notify(state, "侍从铠甲")
	return SQUIRE_SHIELD

## 雷伊奖章: each enemy hit that gets past the shield answers at once with a melee attack,
## also during the enemy turn; feedback shares the 招架反击 queue.
static func player_damaged(state: BattleState) -> void:
	if "雷伊奖章" not in state.troop.relics or state.player_hp <= 0.0 or state.enemy_hp <= 0.0: return
	var skill: Dictionary = state.troop.catalog.skills[SKILLS["雷伊奖章"]]
	var commands := SkillRuntime.resolve_commands(skill, _context(state, "雷伊奖章", skill))
	if commands.is_empty(): return
	for command: Dictionary in commands: command.relic_source = true
	state._prepare_accuracy("player", commands, skill, 0)
	var before := state.enemy_hp
	notify(state, "雷伊奖章")
	state._apply("player", skill, commands)
	state.pending_counter_feedback.append({"damage": maxf(0.0, before - state.enemy_hp), "skill": int(skill.id)})
	BattleSupports.after_action(state, "player")
	state._check_result()

static func _dispatch(state: BattleState, actions: Array[Dictionary]) -> void:
	if state.animate_automatic_skills:
		state.pending_relic_actions.append_array(actions)
	else:
		for entry: Dictionary in actions:
			if state.phase != "player": break
			execute(state, entry)

static func prepare(state: BattleState, entry: Dictionary) -> Dictionary:
	if state.phase != "player" or not state.troop.catalog.skills.has(entry.id): return {"ok": false}
	var skill: Dictionary = state.troop.catalog.skills[entry.id]
	if BattleSupports.attack_blocked(state, "player", skill): return {"ok": false}
	var result := state.runtime.use_skill("relic:" + String(entry.name), skill, _context(state, entry.name, skill))
	if result.get("ok", false):
		result.relic_action = true
		for command: Dictionary in result.commands: command.relic_source = true
		state._prepare_accuracy("player", result.commands, skill, 0)
	return result

static func _context(state: BattleState, name: String, skill: Dictionary) -> Dictionary:
	var ctx := state.context("player")
	ctx.actor = name
	ctx.actor_identity = ""
	ctx.actor_slot = -1
	ctx.element = 0
	ctx.ignore_ap = true
	ctx.allow_multiple_actions = true
	ctx.auto_trigger = skill.action
	return ctx

static func notify(state: BattleState, name: String) -> void:
	state.log_message("遗物发动：" + name)
	state.relic_triggered.emit(name)

static func execute(state: BattleState, entry: Dictionary) -> void:
	if state.phase != "player": return
	if entry.id == 0:
		state.ap = mini(state.ap_max(), state.ap + 1)
		notify(state, entry.name)
		state.changed.emit()
		return
	var result := prepare(state, entry)
	if result.get("ok", false):
		notify(state, entry.name)
		state.apply_skill_commands("player", entry.id, result.commands)
