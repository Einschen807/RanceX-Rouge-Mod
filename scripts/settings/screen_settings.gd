extends CanvasLayer
## The map's settings entry stays at the screen edge without a header bar.
var gear: TextureButton

func _ready() -> void:
	layer = 86
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	gear = TextureButton.new()
	gear.name = "SettingsGear"
	gear.texture_normal = preload("res://assets/ui/gear.svg")
	gear.ignore_texture_size = true
	gear.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(gear)
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -66
	gear.offset_right = -14
	gear.offset_top = 14
	gear.offset_bottom = 66
	gear.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gear.pressed.connect(func() -> void: get_node("/root/Settings").open())
	get_node("/root/UIAudio").bind_button(gear)
	gear.hide()

func _process(_delta: float) -> void:
	var map := get_tree().get_first_node_in_group("run_map_screen")
	var manager := get_node("/root/BattleManager")
	gear.visible = map != null and get_node("/root/RunSession").active and not is_instance_valid(manager.active) and not is_instance_valid(map._formation)
	gear.disabled = get_node("/root/ScreenTransition").busy or get_tree().get_first_node_in_group("modal_overlay") != null or (map != null and (map._traveling or map._launching))
