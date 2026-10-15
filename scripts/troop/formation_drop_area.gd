extends ScrollContainer
class_name FormationDropArea
signal leader_removed(display_name: String)
var troop: TroopState

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("troop") == troop and data.get("from_leader", false)

func _drop_data(_at: Vector2, data: Variant) -> void:
	leader_removed.emit(data.card)
