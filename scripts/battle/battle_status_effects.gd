extends RefCounted
class_name BattleStatusEffects
## Public skill IDs, independent of the original engine's private enum.
const MAX_ROUNDS := 9
const MAX_TYPES := 3
const BURN := 10
const CONFUSION := 11
const WEAK := 12
const POISON := 13
const CURSE := 14
const DARK := 15
const ANTI_REGEN := 16
const FEAR := 17
const SLEEP := 18
const FREEZE := 19
const SHOCK := 20
const INFORMATION_BLOCK := 21
const DEATH_COUNTDOWN := 22
const LETHAL_WOUND := 23
const PURITY := 24
const NAMES := ["燃烧", "混乱", "虚弱", "毒", "诅咒", "黑暗", "反再生", "恐怖", "沉睡", "冰冻", "触电", "信息阻断", "即死预告", "致命伤", "纯净"]
const DESCRIPTIONS := [
	"受到炎属性攻击时，伤害增加50%。",
	"每次己方回合开始时，随机封锁一个可用行动。",
	"攻击力降低20%，受到攻击时伤害增加20%。",
	"每次己方回合开始时，受到当前HP的5%伤害，至少保留1 HP。",
	"剩余回合归零时，受到当前HP的20%伤害，至少保留1 HP。",
	"攻击的命中率降低25个百分点；远程攻击抵消这项惩罚。",
	"无法恢复HP。",
	"联合部队恢复AP减少1；敌方每回合随机封锁一个行动。",
	"无法行动，受击必中且伤害增加100%；受到伤害后解除。",
	"受到冰属性攻击时，伤害增加50%。",
	"受到雷属性攻击时，伤害增加50%。",
	"HP、伤害数值与伤害预测无法显示。",
	"剩余回合归零时，HP变为0。",
	"攻击力降低50%。",
	"附加时清除其他异常。不会自然减少；每阻挡一次其他异常附加消耗1层。重复附加叠加，上限9层。",
]

static func valid(id: int) -> bool:
	return id >= BURN and id <= PURITY

static func valid_value(value: int) -> bool:
	return value in range(1, 10) or value in range(11, 20)

static func effect_name(id: int) -> String:
	return NAMES[id - BURN] if valid(id) else ""

static func description(id: int) -> String:
	return DESCRIPTIONS[id - BURN] if valid(id) else ""

static func command(id: int, value: int) -> Dictionary:
	if not valid(id) or not valid_value(value): return {}
	return {"kind": "status", "status": id, "rounds": value % 10, "target": "self" if value >= 11 else "opponent"}

static func outgoing_ratio(statuses: Dictionary) -> float:
	return maxf(0.0, 1.0 - (0.2 if statuses.has(WEAK) else 0.0) - (0.5 if statuses.has(LETHAL_WOUND) else 0.0))

static func incoming_ratio(statuses: Dictionary, element: Variant) -> float:
	var extra := (0.2 if statuses.has(WEAK) else 0.0) + (1.0 if statuses.has(SLEEP) else 0.0)
	var elements: Array = element if element is Array else [int(element)]
	for pair: Array in [[1, BURN], [2, FREEZE], [3, SHOCK]]:
		if pair[0] in elements and statuses.has(pair[1]): extra += 0.5
	return 1.0 + extra
