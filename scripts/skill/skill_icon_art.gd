extends RefCounted
class_name SkillIconArt
## Shared type icon and top-left ultimate border, independent of cut-ins or buffs.

static func player(parent: Node, skill: Dictionary, at: Vector2, dimensions := Vector2(34, 34), enabled := true) -> TextureRect:
	var kind: int = int(skill.type) if int(skill.action) == 1 else (8 if int(skill.action) == 3 else 7)
	var icon := FormationArt.picture(parent, "skill_%d" % kind, at, dimensions)
	icon.name = "SkillTypeIcon"
	icon.set_meta("ultimate", int(skill.get("ultimate", 0)) == 1)
	if int(skill.get("ultimate", 0)) == 1:
		var marker := Node2D.new()
		marker.name = "UltimateMarker"
		marker.position = Vector2(1, 1) * dimensions / 34.0
		marker.scale = dimensions / 34.0
		marker.modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5)
		icon.add_child(marker)
		var border := Line2D.new()
		border.name = "RedCornerBorder"
		border.points = PackedVector2Array([Vector2(0, 12), Vector2.ZERO, Vector2(12, 0)])
		border.width = 2.0
		border.default_color = Color(0.70, 0.21, 0.13)
		border.joint_mode = Line2D.LINE_JOINT_ROUND
		marker.add_child(border)
	return icon
