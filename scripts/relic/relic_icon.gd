extends Button
class_name RelicIcon
var record: Dictionary
var counter := -1
var imminent := false
var _clock := 0.0
var _flash := 0.0
var _texture: Texture2D
var _bounds: Rect2
var _visual: TextureRect
var _material: ShaderMaterial
var _hover_scale := 1.0
var _hover_tween: Tween
const HOVER_SCALE := 1.12

func _ready() -> void:
	_texture = load("res://assets/relics/%s.png" % record.icon)
	_bounds = Rect2(Vector2.ZERO, _texture.get_size())
	var source := _texture.get_image()
	if source != null: _bounds = Rect2(source.get_used_rect()).grow(6).intersection(Rect2(Vector2.ZERO, _texture.get_size()))
	var cropped := AtlasTexture.new()
	cropped.atlas = _texture
	cropped.region = _bounds
	_visual = TextureRect.new()
	_visual.name = "ItemArt"
	_visual.texture = cropped
	_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.show_behind_parent = true
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/relic_icon.gdshader")
	_visual.material = _material
	add_child(_visual)
	_layout_visual()
	resized.connect(_layout_visual)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style: String in ["normal", "hover", "pressed", "focus"]: add_theme_stylebox_override(style, StyleBoxEmpty.new())
	mouse_entered.connect(_hover_changed)
	mouse_exited.connect(_hover_changed)
	focus_entered.connect(_hover_changed)
	focus_exited.connect(_hover_changed)

func _hover_changed() -> void:
	var highlighted := is_hovered()
	_material.set_shader_parameter("highlighted", highlighted)
	if _hover_tween != null and _hover_tween.is_running(): _hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_method(_set_hover_scale, _hover_scale, HOVER_SCALE if highlighted else 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_hover_scale(value: float) -> void:
	_hover_scale = value
	_layout_visual()

func _layout_visual() -> void:
	if _visual == null: return
	var available := (size - Vector2(12, 12)).max(Vector2.ONE)
	var ratio := minf(available.x / _bounds.size.x, available.y / _bounds.size.y) * _hover_scale
	_visual.size = _bounds.size * ratio
	_visual.position = (size - _visual.size) * 0.5
	_material.set_shader_parameter("outline_width", 2.0 / ratio)

func _process(delta: float) -> void:
	_clock += delta
	_flash = maxf(0.0, _flash - delta)
	var white := 0.0
	if imminent: white = (sin(_clock * TAU / 0.9 - PI * 0.5) * 0.5 + 0.5)
	elif _flash > 0.0: white = sin(PI * (1.0 - _flash / 0.7))
	if _material != null: _material.set_shader_parameter("white_amount", white)

func flash() -> void:
	_flash = 0.7

func _draw() -> void:
	if counter >= 0:
		var at := Vector2(size.x - 22, size.y - 8)
		draw_string_outline(CardWidget.CARD_TEXT_FONT, at, str(counter), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color.BLACK)
		draw_string(CardWidget.CARD_TEXT_FONT, at, str(counter), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
