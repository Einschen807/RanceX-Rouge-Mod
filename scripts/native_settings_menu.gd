extends Control
class_name NativeSettingsMenu
signal settings_requested
signal title_requested
signal abandon_requested
signal back_requested
const WIDTH := 695.0
var drawer: Control
var shade: ColorRect
var reveal := 0.0
var _slide: Tween
var buttons: Array[Button] = []
var title_button: Button
var abandon_button: Button
var error_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	drawer = Control.new()
	drawer.name = "RightDrawer"
	add_child(drawer)
	drawer.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	drawer.offset_left = 0
	drawer.offset_right = WIDTH
	var background := NativeSettingsArt.picture(drawer, "menu_ground", Vector2.ZERO, Vector2(WIDTH, 1080))
	background.flip_h = true
	abandon_button = _row("放弃本局游戏", "exit_icon", 112, abandon_requested.emit)
	abandon_button.name = "AbandonRun"
	title_button = _row("返回标题界面", "title_icon", 212, title_requested.emit)
	title_button.name = "ReturnToTitle"
	_row("指南", "guide_icon", 712, func() -> void: pass).name = "Guide"
	_row("设置", "settings_icon", 812, settings_requested.emit).name = "Settings"
	var back := OriginalUiButton.make(drawer, "back", Vector2(466, 972), Vector2(196, 92), back_requested.emit, "cancel", NativeSettingsArt.ROOT)
	back.name = "Back"
	BattleArt.label(back.content, "返回", Vector2(12, 8), Vector2(172, 74), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	buttons.append(back)
	error_label = BattleArt.label(drawer, "", Vector2(110, 340), Vector2(480, 140), 23)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slide_in()

func _row(caption: String, icon: String, y: float, callback: Callable) -> OriginalUiButton:
	NativeSettingsArt.picture(drawer, "menu_item", Vector2(36, y), Vector2(580, 92))
	NativeSettingsArt.picture(drawer, icon, Vector2(62, y + 13), Vector2(64, 64))
	var button := NativeSettingsArt.button(drawer, caption, Vector2(144, y), callback)
	buttons.append(button)
	return button

func _set_reveal(value: float) -> void:
	reveal = value
	drawer.offset_left = -WIDTH * value
	drawer.offset_right = WIDTH * (1.0 - value)
	shade.modulate.a = value

func refresh_actions(enabled := true) -> void:
	for button: Button in buttons: button.disabled = not enabled
	var session := get_node("/root/RunSession")
	title_button.disabled = not enabled or not session.active
	abandon_button.disabled = not enabled or not (session.active or session.can_resume())
	for button: OriginalUiButton in buttons: button.refresh_art()

func slide_in() -> void:
	if _slide != null and _slide.is_running(): _slide.kill()
	refresh_actions(false)
	_set_reveal(0.0)
	_slide = create_tween()
	_slide.tween_method(_set_reveal, 0.0, 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _slide.finished
	refresh_actions()

func slide_out() -> void:
	if _slide != null and _slide.is_running(): _slide.kill()
	refresh_actions(false)
	_slide = create_tween()
	_slide.tween_method(_set_reveal, reveal, 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _slide.finished
