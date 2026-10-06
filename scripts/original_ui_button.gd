extends Button
class_name OriginalUiButton
## Original FLAT timelines provide each native button state without theme panels.
var kind := "square"
var asset_root := "res://assets/formation/native"
var sound_cue := "click"
var neutral := false:
	set(value):
		neutral = value
		refresh_art()
var selected := false:
	set(value):
		selected = value
		refresh_art()
var art: OriginalFlatPlayer
var content: Control
var _hover := false
var _down := false
var _state := ""

func _ready() -> void:
	get_node("/root/UIAudio").bind_button(self, sound_cue)
	for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	art = OriginalFlatPlayer.new()
	add_child(art)
	move_child(art, 0)
	if content == null:
		content = Control.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(content)
	mouse_entered.connect(func() -> void: _hover = true; refresh_art())
	mouse_exited.connect(func() -> void: _hover = false; refresh_art())
	button_down.connect(func() -> void: _down = true; refresh_art())
	button_up.connect(func() -> void: _down = false; refresh_art())
	refresh_art()

func sync_hover(hovered: bool) -> void:
	# Rebuilt buttons can appear under a stationary pointer without an enter signal.
	if hovered != _hover:
		_hover = hovered
		refresh_art()

func refresh_art() -> void:
	if art == null:
		return
	var state := "disabled" if disabled else ("down" if _down else ("selected" if selected else ("hover" if _hover else "normal")))
	if kind == "tab" and neutral and state == "normal":
		state = "disabled"
	if kind in ["mode", "round"] and selected:
		state = "current"
	var path := "%s/%s_%s/animation.json" % [asset_root, kind, state]
	if not FileAccess.file_exists(path):
		state = "normal"
		path = "%s/%s_normal/animation.json" % [asset_root, kind]
	if state != _state:
		_state = state
		art.load_animation(path)
	var offset := Vector2(0, -14) if kind == "tab" and selected else Vector2.ZERO
	art.position = offset
	content.position = offset

static func make(parent: Node, type: String, at: Vector2, dimensions: Vector2, callback: Callable, cue: String = "click", root_path: String = "res://assets/formation/native") -> OriginalUiButton:
	var node := OriginalUiButton.new()
	node.kind = type
	node.asset_root = root_path
	node.sound_cue = cue
	node.position = at
	node.size = dimensions
	node.content = Control.new()
	node.content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(node.content)
	node.pressed.connect(callback)
	parent.add_child(node)
	return node
