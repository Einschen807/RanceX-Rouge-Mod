extends CanvasLayer
signal opened
## Title, battle MENU and map gear share a two-level native settings menu.
var panel: Control
var menu: NativeSettingsMenu
var details: NativeSettingsPage
var _closing := false
var config := ConfigFile.new()
enum CutInMode { NEVER, ALWAYS, LETHAL }
const AUDIO_BUSES := ["Music", "SFX", "Voice"]
const VOICE_GAIN_DB := 4.0

func audio_volume(bus: String) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index < 0 or AudioServer.is_bus_mute(index): return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index) - _audio_gain(bus)), 0.0, 1.0)

func _audio_gain(bus: String) -> float:
	return VOICE_GAIN_DB if bus == "Voice" else 0.0

func _apply_audio_volume(bus: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0: return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, volume)) + _audio_gain(bus))
	AudioServer.set_bus_mute(index, volume <= 0.0)

func apply_audio_settings() -> void:
	for bus: String in AUDIO_BUSES:
		_apply_audio_volume(bus, clampf(float(config.get_value("audio", bus, 1.0)), 0.0, 1.0))

func set_audio_volume(bus: String, value: float) -> void:
	if bus not in AUDIO_BUSES: return
	var volume := clampf(value, 0.0, 1.0)
	_apply_audio_volume(bus, volume)
	config.set_value("audio", bus, volume)
	config.save("user://settings.cfg")

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
	apply_audio_settings()
	if config.get_value("display", "fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func open() -> void:
	if is_instance_valid(panel) or get_node("/root/ScreenTransition").busy: return
	opened.emit()
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.add_to_group("modal_overlay")
	menu = NativeSettingsMenu.new()
	menu.settings_requested.connect(_show_settings)
	menu.title_requested.connect(_return_title)
	menu.abandon_requested.connect(_abandon)
	menu.back_requested.connect(close)
	panel.add_child(menu)

func _show_settings() -> void:
	if _closing or is_instance_valid(details): return
	menu.hide()
	details = NativeSettingsPage.new()
	details.back_requested.connect(_back_to_menu)
	details.title_requested.connect(_return_title)
	panel.add_child(details)

func _back_to_menu() -> void:
	if not is_instance_valid(details): return
	panel.remove_child(details)
	details.queue_free()
	details = null
	menu.show()
	menu.refresh_actions()
	get_node("/root/UIAudio").play("cancel")

func _return_title() -> void:
	if get_node("/root/ScreenTransition").busy: return
	_dispose()
	get_node("/root/RunSession").return_to_title()

func _abandon() -> void:
	var session := get_node("/root/RunSession")
	if session.abandon():
		_dispose()
	elif is_instance_valid(menu):
		menu.error_label.text = session.error

func close() -> void:
	if not is_instance_valid(panel) or _closing: return
	_closing = true
	if is_instance_valid(details):
		panel.remove_child(details)
		details.queue_free()
		details = null
		menu.show()
	await menu.slide_out()
	_dispose()
	get_node("/root/UIAudio").play("cancel")

func _dispose() -> void:
	if is_instance_valid(panel):
		panel.remove_from_group("modal_overlay")
		remove_child(panel)
		panel.queue_free()
	panel = null
	menu = null
	details = null
	_closing = false

func _input(event: InputEvent) -> void:
	if is_instance_valid(panel) and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _closing: return
		if is_instance_valid(details): _back_to_menu()
		else: close()
