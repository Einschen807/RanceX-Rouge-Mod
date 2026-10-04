extends CanvasLayer
## Swap screens only after presenting a completely black frame.
var busy := false
var shade: ColorRect

func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	shade = ColorRect.new()
	shade.name = "ScreenBlackout"
	shade.color = Color.BLACK
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.hide()

func play(change_screen: Callable) -> void:
	if busy: return
	busy = true
	shade.add_to_group("modal_overlay")
	shade.modulate.a = 0.0
	shade.show()
	await _fade(1.0, 0.16)
	await _draw_frame()
	if change_screen.is_valid(): change_screen.call()
	await _draw_frame()
	await get_tree().create_timer(0.04).timeout
	await _fade(0.0, 0.20)
	shade.hide()
	shade.remove_from_group("modal_overlay")
	busy = false

func _fade(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(shade, "modulate:a", alpha, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _draw_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw

func _input(_event: InputEvent) -> void:
	if busy: get_viewport().set_input_as_handled()
