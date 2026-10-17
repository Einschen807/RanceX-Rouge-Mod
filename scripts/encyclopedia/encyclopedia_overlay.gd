extends Control
class_name EncyclopediaOverlay

signal close_requested
signal entry_selected(entry_id: StringName)

@onready var foreground: Control = $Foreground
@onready var entries: HBoxContainer = $Foreground/Entries
@onready var back: TitleButton = $Foreground/Back
@onready var horizontal: ShaderMaterial = $Horizontal.material as ShaderMaterial
@onready var vertical: ShaderMaterial = $Vertical.material as ShaderMaterial

var active: bool = false
var transition: Tween

func _ready() -> void:
	hide()
	back.pressed.connect(func() -> void: close_requested.emit())
	for entry: EncyclopediaEntry in entries.get_children():
		entry.pressed.connect(func() -> void: entry_selected.emit(entry.entry_id))

func open() -> void:
	if active:
		return
	active = true
	if transition != null and transition.is_running():
		transition.kill()
	show()
	_set_interactive(true)
	foreground.modulate.a = 0.0
	_set_blur(0.0)
	transition = create_tween().set_parallel(true)
	transition.tween_method(_set_blur, 0.0, 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	transition.tween_property(foreground, "modulate:a", 1.0, 0.24).set_delay(0.06)
	(entries.get_child(0) as Button).grab_focus()

func close() -> void:
	if not active:
		return
	active = false
	_set_interactive(false)
	if transition != null and transition.is_running():
		transition.kill()
	transition = create_tween().set_parallel(true)
	transition.tween_method(_set_blur, 1.0, 0.0, 0.20)
	transition.tween_property(foreground, "modulate:a", 0.0, 0.14)
	await transition.finished
	if not active:
		hide()

func _set_blur(amount: float) -> void:
	# Screen texture pixels scale with the actual render target/window.
	var screen_scale: float = float(get_viewport().get_texture().get_width()) / 1920.0
	horizontal.set_shader_parameter("blur_pixels", 20.0 * screen_scale * amount)
	vertical.set_shader_parameter("blur_pixels", 20.0 * screen_scale * amount)
	vertical.set_shader_parameter("darkness", 0.57 * amount)

func _set_interactive(enabled: bool) -> void:
	for entry: EncyclopediaEntry in entries.get_children():
		entry.disabled = not enabled
		entry.sync_feedback()
	back.disabled = not enabled

func _input(event: InputEvent) -> void:
	if get_tree().get_first_node_in_group("modal_overlay") != null or is_instance_valid(get_node("/root/BattleManager").active):
		return
	if active and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_node("/root/UIAudio").play("cancel")
		close_requested.emit()
