extends Button
class_name TitleButton
## Reusable original title button artwork and press feedback.

@export var label_text: String = "从头开始"
@export var rectangular: bool = false

var visual: Control
var artwork: OriginalFlatPlayer
var caption: Label
var pointer_inside: bool = false
var held: bool = false
var feedback_count: int = 0
var _tween: Tween
var _kind: String = "round"

func _ready() -> void:
	text = ""
	_kind = "settings" if rectangular else "round"
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	visual = Control.new()
	visual.name = "Visual"
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.size = custom_minimum_size
	visual.pivot_offset = visual.size * 0.5
	add_child(visual)
	artwork = OriginalFlatPlayer.new()
	artwork.name = "OriginalButtonArt"
	visual.add_child(artwork)
	artwork.load_animation("res://assets/title/%s_normal/animation.json" % _kind)
	caption = Label.new()
	caption.name = "Caption"
	caption.text = label_text
	caption.size = visual.size
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 25 if rectangular else 24)
	caption.add_theme_color_override("font_color", Color(0.94, 0.94, 0.93))
	caption.add_theme_color_override("font_shadow_color", Color(0.04, 0.02, 0.02, 0.95))
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	visual.add_child(caption)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(_on_visual_press)

func _has_point(point: Vector2) -> bool:
	if rectangular:
		return Rect2(Vector2.ZERO, size).has_point(point)
	return point.distance_to(size * 0.5) <= 96.0

func _on_mouse_entered() -> void:
	pointer_inside = true
	_refresh()

func _on_mouse_exited() -> void:
	pointer_inside = false
	_refresh()

func _on_down() -> void:
	held = true
	_refresh()

func _on_up() -> void:
	held = false
	_refresh()

func _refresh() -> void:
	if artwork == null:
		return
	var active: bool = pointer_inside or has_focus()
	var state: String = "down" if held else ("hover" if active else "normal")
	var path: String = "res://assets/title/%s_%s/animation.json" % [_kind, state]
	if artwork.animation_path != path:
		artwork.load_animation(path)
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	var target_scale: float = 0.955 if held else (1.025 if active else 1.0)
	_tween.tween_property(visual, "scale", Vector2.ONE * target_scale, 0.09 if held else 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(caption, "position:y", 2.0 if held else 0.0, 0.09)

func _on_visual_press() -> void:
	feedback_count += 1
	# Visual feedback remains separate from the parent scene's action handlers.
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(visual, "scale", Vector2.ONE * 1.04, 0.075).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(visual, "scale", Vector2.ONE * (1.025 if pointer_inside or has_focus() else 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
