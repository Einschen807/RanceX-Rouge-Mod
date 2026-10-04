extends CanvasLayer
## Both title Settings and battle MENU open this same panel and audio buses.
var panel: Control
var config := ConfigFile.new()

func battle_speed() -> int:
	return clampi(int(config.get_value("battle", "speed", 3)), 1, 3)

func set_battle_speed(value: int) -> void:
	config.set_value("battle", "speed", clampi(value, 1, 3))
	config.save("user://settings.cfg")

func _ready() -> void:
	layer = 100
	config.load("user://settings.cfg")
	for bus: String in ["Music", "SFX"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(0.0001, float(config.get_value("audio", bus, 1.0)))))
	if config.get_value("display", "fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func open() -> void:
	if is_instance_valid(panel):
		return
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.add_to_group("modal_overlay")
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := Panel.new()
	frame.position = Vector2(560, 280)
	frame.size = Vector2(800, 520)
	frame.add_theme_stylebox_override("panel", BattleArt.panel_style())
	panel.add_child(frame)
	BattleArt.label(frame, "设置", Vector2(35, 20), Vector2(730, 60), 36, FormationArt.GOLD)
	for i: int in range(2):
		var bus: String = ["Music", "SFX"][i]
		BattleArt.label(frame, ["音乐音量", "音效音量"][i], Vector2(45, 115 + i * 90), Vector2(220, 45), 27)
		var slider := HSlider.new()
		slider.position = Vector2(280, 105 + i * 90)
		slider.size = Vector2(390, 62)
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)))
		var meter := StyleBoxTexture.new()
		meter.texture = load("res://assets/battle/native/settings_meter_ground/lib_0.png")
		meter.texture_margin_left = 8
		meter.texture_margin_right = 8
		meter.texture_margin_top = 31
		meter.texture_margin_bottom = 31
		slider.add_theme_stylebox_override("slider", meter)
		slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
		slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
		slider.add_theme_icon_override("grabber", load("res://assets/battle/native/settings_meter_normal/atlas_0_1.png"))
		slider.add_theme_icon_override("grabber_highlight", load("res://assets/battle/native/settings_meter_hover/atlas_0_1.png"))
		slider.add_theme_icon_override("grabber_disabled", load("res://assets/battle/native/settings_meter_normal/atlas_0_1.png"))
		var value_label := BattleArt.label(frame, "%d%%" % roundi(slider.value * 100), Vector2(690, 115 + i * 90), Vector2(80, 45), 24)
		slider.value_changed.connect(func(value: float) -> void:
			value_label.text = "%d%%" % roundi(value * 100)
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(0.0001, value)))
			config.set_value("audio", bus, value)
			config.save("user://settings.cfg"))
		frame.add_child(slider)
	var fullscreen := BattleArt.button(frame, "settings_check", Vector2(45, 300), Vector2(60, 60), func() -> void: pass)
	fullscreen.toggle_mode = true
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.selected = fullscreen.button_pressed
	BattleArt.label(frame, "全屏显示", Vector2(120, 310), Vector2(400, 45), 27)
	fullscreen.toggled.connect(func(value: bool) -> void:
		fullscreen.selected = value
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		config.set_value("display", "fullscreen", value)
		config.save("user://settings.cfg"))
	BattleArt.text_button(frame, "返回", Vector2(580, 420), Vector2(170, 60), close)

func close() -> void:
	if is_instance_valid(panel):
		panel.remove_from_group("modal_overlay")
		panel.queue_free()
		panel = null
		get_node("/root/UIAudio").play("cancel")

func _input(event: InputEvent) -> void:
	if is_instance_valid(panel) and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
