extends Control

@onready var background: OriginalFlatPlayer = $Background
@onready var logo: OriginalFlatPlayer = $Logo
@onready var actions: HBoxContainer = $Actions
@onready var settings: TitleButton = $Settings
@onready var title_audio: TitleAudio = $TitleAudio
@onready var encyclopedia: EncyclopediaOverlay = $EncyclopediaOverlay

var intro_finished: bool = false
var _intro_seconds: float = 0.0
var card_overview: TroopFormation
var _entry_transitioning := false

func _ready() -> void:
	actions.modulate.a = 0.0
	settings.modulate.a = 0.0
	_set_buttons_enabled(false)
	title_audio.begin_intro(logo)
	($Actions/Encyclopedia as Button).pressed.connect(_open_encyclopedia)
	settings.pressed.connect(func() -> void: get_node("/root/Settings").open())
	encyclopedia.close_requested.connect(_close_encyclopedia)
	encyclopedia.entry_selected.connect(_on_encyclopedia_entry)
	if "--skip-intro" in OS.get_cmdline_user_args():
		_finish_intro(true)

func _process(delta: float) -> void:
	if not intro_finished:
		_intro_seconds += delta
		if logo.is_root_finished():
			_finish_intro()

func _input(event: InputEvent) -> void:
	if get_tree().get_first_node_in_group("modal_overlay") != null or is_instance_valid(get_node("/root/BattleManager").active):
		return
	if _entry_transitioning:
		get_viewport().set_input_as_handled()
		return
	# Root menu has no parent to return to. Reserve cancel even during the intro.
	if event.is_action_pressed("ui_cancel") and not is_instance_valid(card_overview) and not encyclopedia.active:
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().get_first_node_in_group("modal_overlay") != null or is_instance_valid(get_node("/root/BattleManager").active):
		return
	if is_instance_valid(card_overview):
		return
	if encyclopedia.visible:
		return
	if not intro_finished and (event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)):
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
	if _entry_transitioning or get_node("/root/ScreenTransition").busy:
		return
	if is_instance_valid(card_overview):
		return
	if not encyclopedia.active:
		return
	await encyclopedia.close()
	actions.show()
	settings.show()
	_set_buttons_enabled(true)
	($Actions/Encyclopedia as Button).grab_focus()

func _on_encyclopedia_entry(entry_id: StringName) -> void:
	if entry_id != &"cards" or is_instance_valid(card_overview) or _entry_transitioning or get_node("/root/ScreenTransition").busy:
		return
	_entry_transitioning = true
	encyclopedia._set_interactive(false)
	await get_node("/root/ScreenTransition").play(_mount_cards)
	_entry_transitioning = false
	if is_instance_valid(card_overview): card_overview.set_process_input(true)

func _mount_cards() -> void:
	encyclopedia.foreground.hide()
	card_overview = (load("res://scenes/troop_formation.tscn") as PackedScene).instantiate() as TroopFormation
	card_overview.close_requested.connect(_close_cards)
	add_child(card_overview)
	card_overview.set_process_input(false)

func _close_cards() -> void:
	if _entry_transitioning or get_node("/root/ScreenTransition").busy or not is_instance_valid(card_overview): return
	_entry_transitioning = true
	await get_node("/root/ScreenTransition").play(_return_to_encyclopedia)
	_entry_transitioning = false
	encyclopedia._set_interactive(true)
	(encyclopedia.entries.get_child(0) as Button).grab_focus()

func _return_to_encyclopedia() -> void:
	remove_child(card_overview)
	card_overview.queue_free()
	card_overview = null
	encyclopedia.foreground.show()

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
