extends Control

@onready var background: OriginalFlatPlayer = $Background
@onready var logo: OriginalFlatPlayer = $Logo
@onready var actions: HBoxContainer = $Actions
@onready var settings: TitleButton = $Settings
@onready var title_audio: TitleAudio = $TitleAudio
@onready var encyclopedia: EncyclopediaOverlay = $EncyclopediaOverlay

var intro_finished: bool = false
var _intro_seconds: float = 0.0

func _ready() -> void:
	actions.modulate.a = 0.0
	settings.modulate.a = 0.0
	_set_buttons_enabled(false)
	title_audio.begin_intro(logo)
	($Actions/Encyclopedia as Button).pressed.connect(_open_encyclopedia)
	encyclopedia.close_requested.connect(_close_encyclopedia)
	if "--skip-intro" in OS.get_cmdline_user_args():
		_finish_intro(true)
	if "--verify-title-audio-skip" in OS.get_cmdline_user_args():
		_run_skip_verification.call_deferred()
	if "--verify-title" in OS.get_cmdline_user_args():
		_run_verification.call_deferred()
	if "--verify-encyclopedia" in OS.get_cmdline_user_args():
		_run_encyclopedia_verification.call_deferred()

func _process(delta: float) -> void:
	if not intro_finished:
		_intro_seconds += delta
		if logo.is_root_finished():
			_finish_intro()

func _unhandled_input(event: InputEvent) -> void:
	if encyclopedia.visible:
		return
	if not intro_finished and (event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed)):
		_finish_intro(true)
		get_viewport().set_input_as_handled()
	elif intro_finished and event is InputEventKey and event.pressed and not event.echo:
		if get_viewport().gui_get_focus_owner() == null and (event.keycode == KEY_TAB or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left")):
			($Actions/NewGame as TitleButton).grab_focus()
			get_viewport().set_input_as_handled()

func _set_buttons_enabled(enabled: bool) -> void:
	for button: Node in actions.get_children():
		(button as Button).disabled = not enabled
	settings.disabled = not enabled

func _open_encyclopedia() -> void:
	if not intro_finished or encyclopedia.visible:
		return
	_set_buttons_enabled(false)
	actions.hide()
	settings.hide()
	encyclopedia.open()

func _close_encyclopedia() -> void:
	if not encyclopedia.active:
		return
	await encyclopedia.close()
	actions.show()
	settings.show()
	_set_buttons_enabled(true)
	($Actions/Encyclopedia as Button).grab_focus()

func _finish_intro(skipped: bool = false) -> void:
	if intro_finished:
		return
	intro_finished = true
	title_audio.finish_intro(skipped)
	logo.load_animation("res://assets/title/idle/animation.json")
	_set_buttons_enabled(true)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(actions, "modulate:a", 1.0, 0.20)
	tween.tween_property(settings, "modulate:a", 1.0, 0.20)

func _run_verification() -> void:
	# Runs the real scene/rendering and injects viewport pointer events.
	var report: Dictionary = {"engine": Engine.get_version_info()["string"], "checks": []}
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	_capture("intro.png")
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	_capture("intro_reveal.png")
	await get_tree().create_timer(0.75).timeout
	await RenderingServer.frame_post_draw
	_capture("intro_fire.png")
	assert((logo.debug_state()["missing_textures"] as Array).is_empty())
	report["checks"].append("Native logo entrance and 14-frame flame sequence render without missing textures")
	await get_tree().create_timer(1.55).timeout
	assert(intro_finished)
	assert(_intro_seconds >= 2.5 and _intro_seconds < 2.7)
	report["intro_end_seconds"] = _intro_seconds
	assert(actions.get_child_count() == 3)
	assert(not settings.disabled)
	assert(($Actions/NewGame as TitleButton).label_text == "从头开始")
	assert(($Actions/Continue as TitleButton).label_text == "继续游戏")
	assert(($Actions/Encyclopedia as TitleButton).label_text == "百科大全")
	assert(settings.label_text == "设置")
	report["checks"].append("Only three centered action buttons and one settings button")
	await RenderingServer.frame_post_draw
	_capture("title.png")
	var button: TitleButton = $Actions/NewGame
	assert(button._has_point(button.size * 0.5))
	assert(not button._has_point(Vector2(1, 1)))
	var center: Vector2 = button.global_position + button.size * 0.5
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = center
	get_viewport().push_input(motion, true)
	await get_tree().create_timer(0.25).timeout
	assert(button.pointer_inside)
	assert(button.artwork.animation_path.contains("round_hover"))
	await RenderingServer.frame_post_draw
	_capture("hover.png")
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = center
	down.pressed = true
	get_viewport().push_input(down, true)
	await get_tree().create_timer(0.13).timeout
	await RenderingServer.frame_post_draw
	assert(button.held and button.is_pressed())
	assert(button.visual.scale.x < 1.0)
	await RenderingServer.frame_post_draw
	_capture("pressed.png")
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = center
	up.pressed = false
	get_viewport().push_input(up, true)
	await get_tree().create_timer(0.3).timeout
	assert(not button.held)
	assert(button.feedback_count == 1)
	assert(get_tree().current_scene == self)
	report["checks"].append("Circular hit area, hover, held compression and release feedback; no scene change")
	for other: TitleButton in [$Actions/Continue, $Actions/Encyclopedia, settings]:
		var other_center: Vector2 = other.global_position + other.size * 0.5
		motion.position = other_center
		get_viewport().push_input(motion, true)
		await get_tree().create_timer(0.2).timeout
		down.position = other_center
		get_viewport().push_input(down, true)
		await get_tree().create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		assert(other.held and other.visual.scale.x < 1.0)
		assert(other.artwork.animation_path.contains("_down"))
		up.position = other_center
		get_viewport().push_input(up, true)
		await get_tree().create_timer(0.2).timeout
		assert(other.feedback_count == 1 and not other.held)
		if other == $Actions/Encyclopedia:
			assert(encyclopedia.active)
			await _close_encyclopedia()
	report["checks"].append("All four buttons provide press/release feedback")
	var before: Dictionary = background.debug_state()
	await get_tree().create_timer(0.45).timeout
	var after: Dictionary = background.debug_state()
	assert(int(after["ticks"]) > int(before["ticks"]))
	assert((after["missing_textures"] as Array).is_empty())
	assert((logo.debug_state()["missing_textures"] as Array).is_empty())
	report["checks"].append("Native title/background timelines advance without missing textures")
	report["background"] = after
	report["logo"] = logo.debug_state()
	var audio_state: Dictionary = title_audio.debug_state()
	assert(int(audio_state["cue_frame"]) == 30)
	assert(int(audio_state["logo_play_count"]) == 1)
	assert(int(audio_state["music_play_count"]) == 1)
	assert(bool(audio_state["music_playing"]))
	assert(not bool(audio_state["logo_playing"]))
	assert(is_equal_approx(float(audio_state["music_loop_offset_seconds"]), 541227.0 / 44100.0))
	report["audio"] = audio_state
	report["checks"].append("Native logo SFX and music start exactly once at frame 30; music continues with original loop offset")
	assert(BGM.get_parent() == get_tree().root)
	assert(BGM.get_child_count() == 1)
	assert(not BGM.play_title())
	assert(BGM.play_count == 1)
	var saved_volume: float = BGM.get_volume()
	BGM.set_volume(0.25)
	assert(is_equal_approx(BGM.get_volume(), 0.25))
	BGM.set_muted(true)
	assert(BGM.is_muted())
	BGM.set_muted(false)
	BGM.set_volume(saved_volume)
	report["bgm_manager"] = BGM.debug_state()
	report["checks"].append("Persistent BGM scene has one player; repeated requests preserve playback; centralized volume/mute work")
	var testdir: String = ProjectSettings.globalize_path("res://verification")
	DirAccess.make_dir_recursive_absolute(testdir)
	var file: FileAccess = FileAccess.open(testdir.path_join("runtime_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("TITLE_VERIFICATION_PASSED")
	get_tree().quit()

func _run_skip_verification() -> void:
	var early: bool = "--skip-early" in OS.get_cmdline_user_args()
	await get_tree().create_timer(0.3 if early else 1.3).timeout
	var skip_event: InputEventKey = InputEventKey.new()
	skip_event.keycode = KEY_ENTER
	skip_event.pressed = true
	_unhandled_input(skip_event)
	assert(intro_finished)
	assert(not title_audio.logo_sfx.playing)
	assert(BGM.player.playing)
	await get_tree().create_timer(1.3).timeout
	assert(title_audio.logo_play_count == (0 if early else 1))
	assert(BGM.play_count == 1)
	assert(not title_audio.logo_sfx.playing)
	assert(BGM.player.playing)
	var report: Dictionary = title_audio.debug_state()
	report["skip_before_cue"] = early
	var testdir: String = ProjectSettings.globalize_path("res://verification")
	DirAccess.make_dir_recursive_absolute(testdir)
	var file: FileAccess = FileAccess.open(testdir.path_join("audio_skip_early.json" if early else "audio_skip_late.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("TITLE_AUDIO_SKIP_PASSED early=", early)
	get_tree().quit()

func _run_encyclopedia_verification() -> void:
	await get_tree().create_timer(3.5).timeout
	assert(intro_finished)
	var music_stream: AudioStream = BGM.player.stream
	var music_position: float = BGM.player.get_playback_position()
	var background_ticks: int = int(background.debug_state()["ticks"])
	var trigger: TitleButton = $Actions/Encyclopedia
	await _test_click(trigger)
	_open_encyclopedia() # Repeated calls cannot create or stack overlays.
	await get_tree().create_timer(0.4).timeout
	assert(encyclopedia.active and encyclopedia.visible)
	assert(not actions.visible and not settings.visible)
	assert(trigger.disabled)
	assert(get_tree().current_scene == self)
	assert(encyclopedia.entries.get_child_count() == 3)
	assert((encyclopedia.entries.get_child(0) as EncyclopediaEntry).title_text == "卡牌总览")
	assert((encyclopedia.entries.get_child(1) as EncyclopediaEntry).description_text == "检阅所有的遗物")
	assert((encyclopedia.entries.get_child(2) as EncyclopediaEntry).description_text == "查看所有药水")
	assert(float(encyclopedia.horizontal.get_shader_parameter("blur_pixels")) > 0.0)
	await RenderingServer.frame_post_draw
	_capture("encyclopedia.png")
	var selected: Array[StringName] = []
	encyclopedia.entry_selected.connect(func(id: StringName) -> void: selected.append(id))
	for entry: EncyclopediaEntry in encyclopedia.entries.get_children():
		await _test_click(entry)
		assert(entry.feedback_count == 1)
	assert(selected == [&"cards", &"relics", &"potions"])
	# A click on the old menu's position cannot leak through the modal layer.
	var new_game: TitleButton = $Actions/NewGame
	var new_game_count: int = new_game.feedback_count
	await _test_click(new_game, Vector2(-15, 0))
	assert(new_game.feedback_count == new_game_count)
	await _test_click(encyclopedia.back)
	await get_tree().create_timer(0.3).timeout
	assert(not encyclopedia.visible and actions.visible and settings.visible)
	assert(not trigger.disabled and trigger.has_focus())
	await RenderingServer.frame_post_draw
	_capture("encyclopedia_return.png")
	await _test_click(trigger)
	await get_tree().create_timer(0.35).timeout
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape, true)
	await get_tree().create_timer(0.3).timeout
	assert(not encyclopedia.visible and actions.visible)
	assert(BGM.player.stream == music_stream and BGM.player.playing and BGM.play_count == 1)
	assert(BGM.player.get_playback_position() > music_position)
	assert(int(background.debug_state()["ticks"]) > background_ticks)
	# Open once more at the smallest supported window size to check layout bounds.
	get_window().size = Vector2i(960, 540)
	await get_tree().create_timer(0.25).timeout
	await _test_click(trigger)
	await get_tree().create_timer(0.4).timeout
	for entry: Button in encyclopedia.entries.get_children():
		assert(Rect2(Vector2.ZERO, size).encloses(entry.get_global_rect()))
	await RenderingServer.frame_post_draw
	_capture("encyclopedia_960.png")
	var report: Dictionary = {
		"checks": ["Same title scene; live two-pass Gaussian blur", "Three native-art entries with exact descriptions", "Original buttons hidden and input blocked", "All entries emit IDs with press feedback", "Back and Escape restore title and focus", "Repeated open does not stack", "BGM stream and playback continue without restart", "Background animation continues", "960x540 layout stays inside viewport"],
		"selected_ids": selected,
		"music_play_count": BGM.play_count,
		"assets": "All encyclopedia illustrations and frame/panel textures are extracted original Rance10 art"
	}
	var file: FileAccess = FileAccess.open(ProjectSettings.globalize_path("res://verification/encyclopedia_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("ENCYCLOPEDIA_VERIFICATION_PASSED")
	get_tree().quit()

func _test_click(button: Button, offset: Vector2 = Vector2.ZERO) -> void:
	var center: Vector2 = button.global_position + button.size * 0.5 + offset
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = center
	get_viewport().push_input(motion, true)
	await get_tree().create_timer(0.15).timeout
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = center
	click.pressed = true
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(click, true)
	await get_tree().create_timer(0.13).timeout
	if button is EncyclopediaEntry:
		assert((button as EncyclopediaEntry).held)
		assert((button as EncyclopediaEntry).visual.scale.x < 1.0)
		await RenderingServer.frame_post_draw
		_capture("encyclopedia_pressed.png")
	click.pressed = false
	click.button_mask = 0
	get_viewport().push_input(click, true)
	await get_tree().create_timer(0.18).timeout

func _capture(filename: String) -> void:
	var testdir: String = ProjectSettings.globalize_path("res://verification")
	DirAccess.make_dir_recursive_absolute(testdir)
	var image: Image = get_viewport().get_texture().get_image()
	assert(image != null and not image.is_empty())
	assert(image.save_png(testdir.path_join(filename)) == OK)
