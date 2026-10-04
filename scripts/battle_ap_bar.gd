extends Control
class_name BattleApBar
var shown := -1
var capacity := 0
var playback_speed := 1.0
var preview_cost := 0
var _orbs: Dictionary = {}
var _preview: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func orb_position(index: int) -> Vector2:
	var ground := load("res://assets/battle/ap%d.png" % capacity) as Texture2D
	return Vector2((1920.0 - ground.get_width()) / 2.0 + 74 + index * 53, 658)

func set_state(maximum: int, value: int, speed: float) -> void:
	playback_speed = speed
	value = clampi(value, 0, maximum)
	var initial := maximum != capacity
	if initial:
		BattleArt.clear(self)
		_orbs.clear()
		capacity = maximum
		shown = 0
		var ground := BattleArt.picture(self, "ap%d" % capacity, Vector2.ZERO)
		ground.position = Vector2((1920.0 - ground.size.x) / 2.0, 649)
		_preview = Control.new()
		_preview.name = "APPreview"
		_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview.z_index = 1
		add_child(_preview)
	if shown == value and not initial: return
	set_preview(0)
	for index: int in range(value, shown):
		var orb: OriginalFlatPlayer = _orbs[index]
		remove_child(orb)
		orb.queue_free()
		_orbs.erase(index)
		_burst(index, false)
	for index: int in range(shown, value):
		var orb := BattleArt.flat(self, "ap_%d" % (index + 1), orb_position(index))
		orb.playback_speed = speed
		_orbs[index] = orb
		if not initial: _burst(index, true)
	shown = value

func set_preview(cost: int) -> void:
	cost = clampi(cost, 0, maxi(0, shown))
	if cost == preview_cost and is_instance_valid(_preview) and _preview.get_child_count() == cost: return
	preview_cost = cost
	if not is_instance_valid(_preview): return
	BattleArt.clear(_preview)
	for index: int in range(shown - cost, shown):
		var highlight := BattleArt.flat(_preview, "ap_preview", orb_position(index))
		highlight.playback_speed = playback_speed

func _burst(index: int, gaining: bool) -> void:
	var effect := BattleApEffect.new()
	effect.name = "APGain" if gaining else "APSpend"
	effect.gaining = gaining
	effect.animation_path = "res://assets/battle/native/%s/animation.json" % ("ap_gain" if gaining else "ap_spend")
	effect.position = orb_position(index)
	effect.playback_speed = playback_speed
	effect.z_index = 2
	add_child(effect)
