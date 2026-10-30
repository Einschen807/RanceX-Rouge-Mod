extends CanvasLayer
## The map's settings entry stays at the screen edge without a header bar.
var gear: TextureButton
var _gear_tween: Tween
var _gear_angle := 0.0

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
	# Hovering grows the gear a little and turns it by one tooth (45°), so it rests seamlessly.
	gear.mouse_entered.connect(func() -> void:
		_gear_angle += PI * 0.25
		_turn_gear(1.14))
	gear.mouse_exited.connect(_turn_gear.bind(1.0))
	gear.pressed.connect(func() -> void: get_node("/root/Settings").open())
	get_node("/root/UIAudio").bind_button(gear)
	gear.hide()

func _turn_gear(grow: float) -> void:
	if _gear_tween != null: _gear_tween.kill()
	# Anchored layout sizes the button after _ready; spin around its live center.
	gear.pivot_offset = gear.size * 0.5
	_gear_tween = gear.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gear_tween.tween_property(gear, "scale", Vector2.ONE * grow, 0.22)
	# Leaving mid-turn still finishes the turn, keeping the teeth aligned.
	_gear_tween.tween_property(gear, "rotation", _gear_angle, 0.45)

func _process(_delta: float) -> void:
	var map := get_tree().get_first_node_in_group("run_map_screen")
	var manager := get_node("/root/BattleManager")
	gear.visible = map != null and get_node("/root/RunSession").active and not is_instance_valid(manager.active) and not is_instance_valid(map._formation)
	gear.disabled = get_node("/root/ScreenTransition").busy or get_tree().get_first_node_in_group("modal_overlay") != null or (map != null and (map._traveling or map._launching))
