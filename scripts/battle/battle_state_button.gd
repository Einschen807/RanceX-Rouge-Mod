extends OriginalUiButton
class_name BattleStateButton
## Use the same native square frame, caption and dimensions as Restart.
func _ready() -> void:
	super._ready()
	art.scale = Vector2.ONE * (80.0 / 86.0)
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/formation/skill_ability.png")
	icon.position = Vector2(17.5, 7)
	icon.size = Vector2(45, 45)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var caption := BattleArt.label(content, "状态", Vector2(4, 51), Vector2(72, 22), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	caption.add_theme_constant_override("outline_size", 2)

static func create(parent: Node, callback: Callable) -> BattleStateButton:
	var button := BattleStateButton.new()
	button.name = "StateButton"
	button.kind = "square"
	button.position = Vector2(1835, 856)
	button.size = Vector2(80, 80)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
