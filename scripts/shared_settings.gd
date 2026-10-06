extends CanvasLayer
signal opened
## Both title Settings and battle MENU open this same panel and audio buses.
var panel: Control
var config := ConfigFile.new()
enum CutInMode { NEVER, ALWAYS, LETHAL }

func cut_in_mode() -> int:
	return clampi(int(config.get_value("presentation", "cut_in_mode", CutInMode.ALWAYS)), CutInMode.NEVER, CutInMode.LETHAL)

func set_cut_in_mode(value: int) -> void:
	config.set_value("presentation", "cut_in_mode", clampi(value, CutInMode.NEVER, CutInMode.LETHAL))
	config.save("user://settings.cfg")

func should_play_cut_in(lethal: bool) -> bool:
	return cut_in_mode() == CutInMode.ALWAYS or (cut_in_mode() == CutInMode.LETHAL and lethal)

func battle_speed() -> int:
	return clampi(int(config.get_value("battle", "speed", 3)), 1, 3)

func set_battle_speed(value: int) -> void:
	config.set_value("battle", "speed", clampi(value, 1, 3))
	config.save("user://settings.cfg")

func _ready() -> void:
	layer = 100
	config.load("user://settings.cfg")
	for bus: String in ["Music", "SFX"]:
		var volume := clampf(float(config.get_value("audio", bus, 1.0)), 0.0, 1.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(0.0001, volume)))
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), volume <= 0.0)
	if config.get_value("display", "fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func open() -> void:
	if is_instance_valid(panel):
		return
	opened.emit()
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.add_to_group("modal_overlay")
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.offset_left = -480
	frame.offset_top = -360
	frame.offset_right = 480
	frame.offset_bottom = 360
	frame.add_theme_stylebox_override("panel", BattleArt.panel_style())
	panel.add_child(frame)
	BattleArt.label(frame, "设置", Vector2(35, 20), Vector2(890, 60), 36, FormationArt.GOLD)
	BattleArt.label(frame, "音量", Vector2(45, 85), Vector2(850, 40), 27, FormationArt.GOLD)
	for i: int in range(2):
		var bus: String = ["Music", "SFX"][i]
		BattleArt.label(frame, ["音乐音量", "音效音量"][i], Vector2(45, 145 + i * 90), Vector2(220, 45), 27)
		var slider := HSlider.new()
		slider.name = bus + "Volume"
		slider.position = Vector2(280, 135 + i * 90)
		slider.size = Vector2(470, 62)
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
		var value_label := BattleArt.label(frame, "%d%%" % roundi(slider.value * 100), Vector2(800, 145 + i * 90), Vector2(100, 45), 24)
		slider.value_changed.connect(func(value: float) -> void:
			value_label.text = "%d%%" % roundi(value * 100)
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(0.0001, value)))
			AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), value <= 0.0)
			config.set_value("audio", bus, value)
			config.save("user://settings.cfg"))
		frame.add_child(slider)
	BattleArt.label(frame, "演出动画", Vector2(45, 390), Vector2(850, 40), 27, FormationArt.GOLD)
	BattleArt.label(frame, "必杀演出", Vector2(45, 440), Vector2(850, 40), 25)
	var switch_group := ButtonGroup.new()
	for index: int in range(3):
		var option := BattleArt.text_button(frame, ["不播放演出", "每次播放演出", "仅致命一击时播放"][index], Vector2(45 + index * 290, 500), Vector2(275, 65), set_cut_in_mode.bind(index))
		option.name = "CutInMode%d" % index
		option.toggle_mode = true
		option.button_group = switch_group
		option.set_pressed_no_signal(cut_in_mode() == index)
		option.selected = option.button_pressed
		option.toggled.connect(func(value: bool) -> void: option.selected = value)
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
	BattleArt.text_button(frame, "返回", Vector2(740, 625), Vector2(170, 60), close)

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
