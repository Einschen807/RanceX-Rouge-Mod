extends Control
class_name BattleLeaderPowerLayer
## Separate from rebuilt skill buttons so native loops retain their clocks.
const ORDER := ["critical", "boost", "multi"]
const HEIGHTS := {"critical": 40.0, "boost": 50.0, "multi": 40.0}
const GLOW_RATE := 1.0 / 3.0
var views: Dictionary = {}
var lifted := ""
var target_views: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _native(parent: Node, asset: String, speed: float) -> OriginalFlatPlayer:
	var player := OriginalFlatPlayer.new()
	player.name = asset
	player.animation_path = "res://assets/battle/native/%s/animation.json" % asset
	player.set_meta("animation_rate", GLOW_RATE if asset == "leader_power_glow" else 1.0)
	player.playback_speed = speed * float(player.get_meta("animation_rate"))
	parent.add_child(player)
	return player

func sync(state: BattleState, mode: int, selected: String, speed: float) -> void:
	_sync_target(state, speed)
	var active: Dictionary = state.leader_powers.player
	for actor: String in views.keys():
		if not active.has(actor) or active[actor].is_empty() or actor not in state.troop.leaders:
			views[actor].hide()
			views[actor].queue_free()
			views.erase(actor)
	for actor: String in active:
		if active[actor].is_empty() or actor not in state.troop.leaders: continue
		if not views.has(actor):
			var group := Control.new()
			group.name = "LeaderPower_" + actor
			group.mouse_filter = Control.MOUSE_FILTER_IGNORE
			group.size = Vector2(208, 312)
			add_child(group)
			views[actor] = group
			_native(group, "leader_power_glow", speed)
		var group: Control = views[actor]
		if group.get_parent() == self:
			group.position = Vector2(200 + state.troop.leaders.find(actor) * 218, 730)
			group.visible = actor != lifted and not state.runtime.acted.get(actor, false)
		# Selected portrait mode puts skill descriptions over the portrait.
		var show_labels := group.get_parent() != self or mode == 0 or actor != selected
		var height := 0.0
		for power: String in ORDER:
			if active[actor].get(power, false): height += HEIGHTS[power]
		var y := 156.0 - height / 2.0
		for power: String in ORDER:
			var label: OriginalFlatPlayer = group.get_node_or_null("leader_" + power)
			if active[actor].get(power, false):
				if not is_instance_valid(label): label = _native(group, "leader_" + power, speed)
				label.position = Vector2(104, y + HEIGHTS[power] / 2.0)
				label.visible = show_labels
				y += HEIGHTS[power]
			elif is_instance_valid(label):
				label.hide()
				group.remove_child(label)
				label.queue_free()
		for child: Node in group.get_children():
			if child is OriginalFlatPlayer: child.playback_speed = speed * float(child.get_meta("animation_rate", 1.0))

func lift(actor: String, card: CardWidget) -> void:
	lifted = actor
	if target_views.has(actor):
		var target_view: BattleTargetReticle = target_views[actor]
		target_view.reparent(card, false)
		target_view.position = Vector2.ZERO
		target_view.show()
	if not views.has(actor): return
	var group: Control = views[actor]
	group.reparent(card, false)
	group.position = Vector2.ZERO
	group.show()
	for child: Node in group.get_children(): child.show()

func return_to_slots() -> void:
	if views.has(lifted): views[lifted].reparent(self, false)
	for target_view: BattleTargetReticle in target_views.values():
		if target_view.get_parent() != self: target_view.reparent(self, false)
	lifted = ""

func _sync_target(state: BattleState, speed: float) -> void:
	var actors: Array[String] = []
	if state.phase != "result": actors.assign(state.locked_targets)
	for actor: String in target_views.keys():
		if actor not in actors or actor not in state.troop.leaders:
			target_views[actor].hide()
			target_views[actor].queue_free()
			target_views.erase(actor)
	for actor: String in actors:
		if actor not in state.troop.leaders: continue
		if not target_views.has(actor):
			var marker := BattleTargetReticle.new()
			marker.name = "LockedTarget_" + actor
			marker.z_index = 0
			add_child(marker)
			target_views[actor] = marker
		var target_view: BattleTargetReticle = target_views[actor]
		target_view.playback_speed = speed
		if target_view.get_parent() == self:
			target_view.position = Vector2(200 + state.troop.leaders.find(actor) * 218, 730)
			target_view.visible = actor != lifted
		else:
			target_view.show()
