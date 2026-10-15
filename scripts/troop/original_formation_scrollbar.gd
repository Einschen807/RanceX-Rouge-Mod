extends Control
class_name OriginalFormationScrollbar
var scroll: ScrollContainer
var _thumb: OriginalUiButton
var _up: OriginalUiButton
var _down: OriginalUiButton
var _dragging := false
var _offset := 0.0
var total_height := 656.0
var scroll_step := 160
var track_path := "res://assets/formation/native/scroll_track/animation.json"

func _ready() -> void:
	size = Vector2(32, total_height)
	var track := OriginalFlatPlayer.new()
	track.animation_path = track_path
	track.position.y = 54
	track.scale.y = (total_height - 108.0) / 528.0
	add_child(track)
	_up = OriginalUiButton.make(self, "up", Vector2.ZERO, Vector2(32, 54), func() -> void: scroll.scroll_vertical -= scroll_step)
	_down = OriginalUiButton.make(self, "down", Vector2(0, total_height - 54), Vector2(32, 54), func() -> void: scroll.scroll_vertical += scroll_step)
	_thumb = OriginalUiButton.make(self, "thumb", Vector2(0, 54), Vector2(32, 150), func() -> void: pass)
	_thumb.gui_input.connect(_thumb_input)
	gui_input.connect(_track_input)

func _process(_delta: float) -> void:
	var bar := scroll.get_v_scroll_bar()
	var extent := maxf(0.0, bar.max_value - bar.page)
	_thumb.position.y = 54.0 + (bar.value / extent * (total_height - 258.0) if extent > 0.0 else 0.0)
	for button: OriginalUiButton in [_up, _down, _thumb]:
		button.disabled = extent <= 0.0
		button.refresh_art()

func _thumb_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_offset = event.position.y
		_thumb.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var ratio := clampf((_thumb.position.y + event.position.y - _offset - 54.0) / (total_height - 258.0), 0.0, 1.0)
		var bar := scroll.get_v_scroll_bar()
		bar.value = ratio * maxf(0.0, bar.max_value - bar.page)
		_thumb.accept_event()

func _track_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			scroll.scroll_vertical += -scroll_step if event.button_index == MOUSE_BUTTON_WHEEL_UP else scroll_step
		elif event.button_index == MOUSE_BUTTON_LEFT:
			scroll.scroll_vertical += -(total_height - 108) if event.position.y < _thumb.position.y else total_height - 108
		accept_event()
