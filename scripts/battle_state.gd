extends RefCounted
class_name BattleState
## Combat is independent of its view: preview widgets never become battle records.
signal changed
signal log_added(message: String)
var troop: TroopState
var database: MonsterCatalog
var monster: Dictionary
var runtime: SkillRuntime
var enemy_runtime := SkillRuntime.new()
var phase := "preparation"
var round := 1
var round_limit := 99
var ap := 0
var combo := 0
var combo_limit := 13
var player_hp := 0.0
var player_max_hp := 0.0
var enemy_hp := 0.0
var enemy_max_hp := 0.0
var player_at_bonus := 0.0
var enemy_at_bonus := 0.0
var next_swap_round := 6
var player_has_acted := false
var intent: Dictionary = {}
var outcome := ""
var logs: Array[String] = []

func configure(state: TroopState, monsters: MonsterCatalog, identity: String) -> void:
	troop = state
	database = monsters
	monster = monsters.monsters[identity]
	runtime = troop.skill_runtime
	runtime.begin_battle()
	enemy_runtime.begin_battle()
	enemy_max_hp = float(monster.base_hp)
	enemy_hp = enemy_max_hp
	sync_formation()
	_choose_intent()

func ap_max() -> int:
	return 10 if troop.bonuses.get(3, false) else 6

func swap_interval() -> int:
	return 1 if troop.bonuses.get(5, false) else 5

func swap_remaining() -> int:
	return maxi(0, next_swap_round - round)

func can_swap() -> bool:
	return phase == "preparation" or (phase == "player" and round > 1 and not player_has_acted and round >= next_swap_round)

func sync_formation(previous_leaders: Array[String] = []) -> void:
	player_max_hp = troop.total("hp")
	player_hp = player_max_hp if phase == "preparation" else minf(player_hp, player_max_hp)
	ap = mini(ap, ap_max())
	if phase != "preparation":
		for name: String in troop.leaders:
			if not name.is_empty() and name not in previous_leaders:
				runtime.acted[name] = true
	changed.emit()

func start() -> bool:
	if phase != "preparation" or player_max_hp <= 0:
		return false
	phase = "player"
	ap = mini(3, ap_max())
	next_swap_round = 1 + swap_interval()
	log_message("战斗开始：" + monster.name)
	_turn_start()
	return true

func context(side: String, card: Dictionary = {}) -> Dictionary:
	var at := float(monster.base_at) * (1.0 + enemy_at_bonus / 100.0)
	if side == "player":
		at = troop.deployed(card, "at") * (1.0 + player_at_bonus / 100.0)
	return {"ap": ap, "combo": combo, "round": round, "hp": player_hp if side == "player" else enemy_hp, "hp_max": player_max_hp if side == "player" else enemy_max_hp, "player_hp": player_hp, "player_hp_max": player_max_hp, "deployed_at": at, "auto_trigger": 2}

func skill_slot(name: String, id: int) -> int:
	var card := troop.catalog.find_name(name)
	return [card.get("skill1", 0), card.get("skill2", 0)].find(id)

func can_use(name: String, id: int, slot: int = -1) -> bool:
	if phase != "player" or name not in troop.leaders or not troop.catalog.skills.has(id):
		return false
	var card := troop.catalog.find_name(name)
	if slot < 0: slot = skill_slot(name, id)
	return slot in [0, 1] and card["skill%d" % (slot + 1)] == id and troop.catalog.skills[id].action == 1 and runtime.can_use(name, troop.catalog.skills[id], context("player", card), slot)

func use_player_skill(name: String, id: int, slot: int = -1) -> Dictionary:
	if slot < 0: slot = skill_slot(name, id)
	if not can_use(name, id, slot):
		return {"ok": false, "commands": []}
	var swap_was_available := can_swap()
	var skill: Dictionary = troop.catalog.skills[id]
	var result := runtime.use_skill(name, skill, context("player", troop.catalog.find_name(name)), slot)
	if not result.ok:
		return result
	ap -= result.ap_spent
	player_has_acted = true
	if swap_was_available:
		next_swap_round = round + swap_interval()
	log_message("%s 使用 %s" % [name, skill.name])
	_apply("player", skill, result.commands)
	_check_result()
	changed.emit()
	return result

func begin_enemy_turn() -> bool:
	if phase != "player":
		return false
	phase = "enemy"
	combo = 0
	changed.emit()
	return true

func _enemy_skill_context(skill: Dictionary) -> Dictionary:
	var ctx := context("enemy")
	ctx.ignore_ap = true
	ctx.allow_multiple_actions = true
	ctx.auto_trigger = skill.action
	return ctx

func can_use_enemy_skill(id: int) -> bool:
	if phase != "enemy" or not troop.catalog.skills.has(id): return false
	var skill: Dictionary = troop.catalog.skills[id]
	return enemy_runtime.can_use(monster.identity, skill, _enemy_skill_context(skill))

func use_enemy_skill(id: int) -> Dictionary:
	if phase != "enemy" or not troop.catalog.skills.has(id):
		return {"ok": false, "commands": []}
	var skill: Dictionary = troop.catalog.skills[id]
	var result := enemy_runtime.use_skill(monster.identity, skill, _enemy_skill_context(skill))
	if result.ok:
		log_message("%s 使用 %s" % [monster.name, skill.name])
		_apply("enemy", skill, result.commands)
	else:
		log_message("%s 的 %s 未满足释放条件，跳过" % [monster.name, skill.name])
	_check_result()
	changed.emit()
	return result

func finish_enemy_turn() -> void:
	if phase != "enemy":
		return
	if round >= round_limit:
		outcome = "时间结束"
		phase = "result"
		changed.emit()
		return
	round += 1
	runtime.next_turn()
	enemy_runtime.next_turn()
	phase = "player"
	player_has_acted = false
	ap = mini(ap_max(), ap + 3 + (1 if troop.bonuses.get(4, false) and round % 2 == 0 else 0))
	_turn_start()

func _turn_start() -> void:
	log_message("Round %d" % round)
	_choose_intent()
	for name: String in troop.leaders:
		if name.is_empty() or phase != "player":
			continue
		var card := troop.catalog.find_name(name)
		for slot: int in range(2):
			var id: int = card["skill%d" % (slot + 1)]
			if id == 0 or troop.catalog.skills[id].action != 2:
				continue
			var skill: Dictionary = troop.catalog.skills[id]
			var result := runtime.use_skill(name, skill, context("player", card), slot)
			if result.ok:
				_apply("player", skill, result.commands)
				log_message("%s 自动发动 %s" % [name, skill.name])
				_check_result()
	changed.emit()

func _choose_intent() -> void:
	intent = database.choose(monster.behavior, context("enemy"))

func _apply(side: String, skill: Dictionary, commands: Array) -> void:
	var attacked := false
	for command: Dictionary in commands:
		var self_target: bool = command.get("target", "self" if command.kind in ["heal", "buff"] else "opponent") == "self"
		var player_target := (side == "player") == self_target
		match String(command.kind):
			"damage":
				var resistance := 0.0 if player_target else float(monster.magic_resist if skill.type == 3 else monster.physical_resist)
				var bonus := troop.rate("magic" if skill.type == 3 else "physical") if side == "player" else 0.0
				var amount := maxf(0.0, float(command.amount) * (1.0 - resistance / 100.0) * (1.0 + bonus / 100.0))
				if player_target:
					player_hp = maxf(0.0, player_hp - amount)
				else:
					enemy_hp = maxf(0.0, enemy_hp - amount)
				attacked = true
				log_message("%s受到 %s 点伤害" % ["联合部队" if player_target else monster.name, str(int(floor(amount)))])
			"heal":
				if player_target:
					player_hp = minf(player_max_hp, player_hp + float(command.amount))
				else:
					enemy_hp = minf(enemy_max_hp, enemy_hp + float(command.amount))
			"buff":
				if command.get("stat", "at") == "at":
					if player_target:
						player_at_bonus += float(command.amount)
					else:
						enemy_at_bonus += float(command.amount)
	if attacked and side == "player":
		combo = mini(combo_limit, combo + 1)

func _check_result() -> void:
	if enemy_hp <= 0:
		outcome = "胜利"
	elif player_hp <= 0:
		outcome = "败北"
	if not outcome.is_empty():
		phase = "result"
		log_message(outcome)

func log_message(message: String) -> void:
	logs.append(message)
	if logs.size() > 300:
		logs.pop_front()
	log_added.emit(message)

func finish() -> void:
	runtime.end_battle()
	enemy_runtime.end_battle()
