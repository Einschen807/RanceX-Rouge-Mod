extends Control
class_name NativeSettingsPage
signal back_requested
signal title_requested
var settings: Node
var body: Control
var category := "window"
var tabs: Dictionary = {}
var title_button: OriginalUiButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings = get_node("/root/Settings")
	NativeSettingsArt.flat(self, "settings_background", Vector2.ZERO)
	# Original page reserves its right column for navigation and the TITLE button.
	title_button = OriginalUiButton.make(self, "square", Vector2(1818, 18), Vector2(86, 86), title_requested.emit)
	title_button.name = "Title"
	NativeSettingsArt.picture(title_button.content, "title_icon", Vector2(11, 11), Vector2(64, 64))
	title_button.disabled = not get_node("/root/RunSession").active
	title_button.refresh_art()
	var categories := ["window", "sound", "animation"]
	for i: int in range(categories.size()):
		var id: String = categories[i]
		var tab := OriginalUiButton.make(self, "tab", Vector2(1608, 140 + i * 100), Vector2(300, 92), show_category.bind(id), "click", NativeSettingsArt.ROOT)
		tab.name = "Tab_" + id
		tab.selected_offset = Vector2.ZERO
		NativeSettingsArt.picture(tab.content, id + "_icon", Vector2(20, 18), Vector2(54, 54))
		BattleArt.label(tab.content, ["窗口", "声音", "动画"][i], Vector2(88, 8), Vector2(192, 74), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		tabs[id] = tab
	var back := OriginalUiButton.make(self, "back", Vector2(1712, 972), Vector2(196, 92), back_requested.emit, "cancel", NativeSettingsArt.ROOT)
	back.name = "Back"
	BattleArt.label(back.content, "返回", Vector2(12, 8), Vector2(172, 74), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	body = Control.new()
	body.name = "CategoryBody"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	show_category("window")

func show_category(id: String) -> void:
	category = id
	BattleArt.clear(body)
	for key: String in tabs: tabs[key].selected = key == id
	match id:
		"window": _window()
		"sound": _sound()
		"animation": _animation()

func _section(caption: String, y: float) -> void:
	NativeSettingsArt.picture(body, "section_decor", Vector2(240, y), Vector2(1028, 216))
	BattleArt.label(body, caption, Vector2(290, y - 30), Vector2(930, 50), 27, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

func _window() -> void:
	_section("窗口显示", 150)
	var fullscreen := BattleArt.button(body, "settings_check", Vector2(380, 260), Vector2(60, 60), func() -> void: pass)
	fullscreen.name = "Fullscreen"
	fullscreen.toggle_mode = true
	fullscreen.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen.selected = fullscreen.button_pressed
	BattleArt.label(body, "全屏显示", Vector2(465, 263), Vector2(530, 52), 27)
	fullscreen.toggled.connect(func(value: bool) -> void:
		fullscreen.selected = value
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		settings.config.set_value("display", "fullscreen", value)
		settings.config.save("user://settings.cfg"))
	_section("内容显示", 450)
	var harmony := BattleArt.button(body, "settings_check", Vector2(380, 560), Vector2(60, 60), func() -> void: pass)
	harmony.name = "HarmonyMode"
	harmony.toggle_mode = true
	harmony.set_pressed_no_signal(settings.harmony_mode())
	harmony.selected = harmony.button_pressed
	BattleArt.label(body, "和谐模式", Vector2(465, 563), Vector2(530, 52), 27)
	harmony.toggled.connect(func(value: bool) -> void:
		harmony.selected = value
		settings.set_harmony_mode(value))

func _sound() -> void:
	for i: int in range(settings.AUDIO_BUSES.size()):
		var bus: String = settings.AUDIO_BUSES[i]
		var y := 105.0 + i * 270.0
		_section(["音乐音量", "音效音量", "语音音量"][i], y)
		NativeSettingsArt.flat(body, "volume_ground", Vector2(410, y + 98))
		var slider := HSlider.new()
		slider.name = bus + "Volume"
		slider.position = Vector2(410, y + 98)
		slider.size = Vector2(512, 62)
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = settings.audio_volume(bus)
		slider.add_theme_stylebox_override("slider", StyleBoxEmpty.new())
		slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
		slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
		slider.add_theme_icon_override("grabber", NativeSettingsArt.meter_handle("normal"))
		slider.add_theme_icon_override("grabber_highlight", NativeSettingsArt.meter_handle("hover"))
		slider.add_theme_icon_override("grabber_disabled", NativeSettingsArt.meter_handle("normal"))
		body.add_child(slider)
		var value_label := BattleArt.label(body, "%d%%" % roundi(slider.value * 100), Vector2(965, y + 102), Vector2(125, 52), 26)
		slider.value_changed.connect(func(value: float) -> void:
			settings.set_audio_volume(bus, value)
			value_label.text = "%d%%" % roundi(value * 100))

func _animation() -> void:
	_section("必杀演出动画", 150)
	var group := ButtonGroup.new()
	for index: int in range(3):
		var option := OriginalUiButton.make(body, "tab", Vector2(295 + index * 310, 260), Vector2(295, 65), settings.set_cut_in_mode.bind(index), "click", NativeSettingsArt.ROOT)
		option.selected_offset = Vector2.ZERO
		option.art.scale = Vector2(295, 65) / Vector2(300, 92)
		BattleArt.label(option.content, ["不播放演出", "每次播放演出", "仅致命一击时播放"][index], Vector2(4, 0), Vector2(287, 65), 23, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		option.name = "CutInMode%d" % index
		option.toggle_mode = true
		option.button_group = group
		option.set_pressed_no_signal(settings.cut_in_mode() == index)
		option.selected = option.button_pressed
		option.toggled.connect(func(value: bool) -> void: option.selected = value)
