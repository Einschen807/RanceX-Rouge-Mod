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
