extends "res://scripts/run/run_session.gd"
class_name ForcedEventSession
## A console event shares inventory, while owning its own choices and completion.
var host: Node

func configure(source: TroopState, events: EventCatalog, identity: String) -> bool:
	host = get_node("/root/RunSession")
	troop = source
	catalog = source.catalog
	monsters = MonsterCatalog.new()
	if not monsters.load_catalog(catalog.skills): return false
	pools = RunPoolCatalog.new()
	pools.event_catalog = events
	pools.event_data = events.records
	active = true
	if _shares_run(): missing_hp = host.missing_hp
	pending = {"type": "unknown", "event": identity}
	current_event()
	troop.changed.connect(_troop_changed)
	host.changed.connect(_host_changed)
	return true

func _shares_run() -> bool:
	return host != null and host.active and host.troop == troop

func event_pool() -> String:
	return host.event_pool() if _shares_run() else "事件"

func hp() -> float:
	return host.hp() if _shares_run() else super.hp()

func heal(percent: int) -> void:
	if _shares_run(): host.heal(percent)
	else: super.heal(percent)

func set_event_damage(value: float) -> void:
	if _shares_run(): host.set_event_damage(value)
	else: super.set_event_damage(value)

func _host_changed() -> void:
	if _shares_run(): missing_hp = host.missing_hp
	changed.emit()
