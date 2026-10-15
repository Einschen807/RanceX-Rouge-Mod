extends Control
class_name BattleShieldBar
## Combat values update immediately; only the displayed cover and crest animate.
const ENTRY_TIME := 0.28
const BAR_TIME := 0.30
const BREAK_TIME := 0.42
# Both fragments use the same seam, so the face joins exactly before separating.
const BREAK_SEAM := [Vector2(0, -52), Vector2(0, -43), Vector2(-6, -30), Vector2(5, -17), Vector2(-5, -4), Vector2(6, 11), Vector2(-4, 26), Vector2(0, 43), Vector2(0, 52)]
var view: BattleScene
var reverse := false
var percent := 0.0
var preview := false
var preview_hidden := false
var preview_alpha := 1.0
var _information_hidden := false
var _overlay: TextureRect
var _material: ShaderMaterial
var _badge: Control
var _number: OriginalBitmapNumber
var _pieces: Array[Control] = []
var _bar_tween: Tween
var _badge_tween: Tween
var _break_tween: Tween
var _display_ratio := 0.0:
	set(value):
		_display_ratio = value
		if _material != null: _material.set_shader_parameter("shield_ratio", value)
		_update_visibility()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(841, 82)
	_overlay = BattleArt.picture(self, "player_hp_bar" if reverse else "enemy_hp_bar", Vector2.ZERO)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/hp_shield.gdshader")
	_material.set_shader_parameter("reverse", reverse)
	_material.set_shader_parameter("shield_surface", preload("res://assets/battle/player_hp_bar.png"))
	_overlay.material = _material
	# The crest and its digits share a transform, above the opaque shield cover.
	_badge = _make_badge(self, _badge_center())
	_badge.name = "ShieldBadge"
	_number = _make_number(_badge, "0")
	_badge.hide()
	_update_preview()

func _process(_delta: float) -> void:
	# Running tweens also respond to a speed change halfway through the animation.
	for tween: Tween in [_bar_tween, _badge_tween, _break_tween]:
		if tween != null and tween.is_valid(): tween.set_speed_scale(_speed())

func on_shield_event(side: String, event: String) -> void:
	if side != ("player" if reverse else "enemy"): return
	set_preview(false)
	set_information_hidden(view.battle.information_hidden(side))
	sync(BattleShields.percent(view.battle, side), event)

func sync(value: float, event := "change") -> void:
	value = clampf(value, 0.0, BattleShields.MAX_PERCENT)
	# Even a tiny positive remainder must transition to zero and retire its crest.
	if value == percent: return
	var was_present := percent > 0.0
	percent = value
	_kill(_bar_tween)
	if percent > 0.0:
		_kill(_break_tween)
		_clear_pieces()
		# Round upward so a small remaining shield is never displayed as zero.
		_number.text = str(ceili(percent))
		if not was_present: _enter_badge()
	elif was_present:
		# Natural expiration keeps the crest intact until the cover has retracted.
		if event != "decay": _fracture()
	_bar_tween = create_tween().set_speed_scale(_speed())
	_bar_tween.tween_property(self, "_display_ratio", minf(1.0, percent / 100.0), BAR_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if percent <= 0.0 and event == "decay": _bar_tween.tween_callback(_fracture)
	_update_preview()

func is_animating() -> bool:
	for tween: Tween in [_bar_tween, _badge_tween, _break_tween]:
		if tween != null and tween.is_valid() and tween.is_running(): return true
	return false

func set_information_hidden(hidden: bool) -> void:
	_information_hidden = hidden
	_update_visibility()

func set_preview(blink: bool, hide_shield := false, alpha := 1.0) -> void:
	preview = blink
	preview_hidden = hide_shield
	preview_alpha = alpha
	_update_preview()

func _update_preview() -> void:
	_update_visibility()
	if _material != null: _material.set_shader_parameter("preview_alpha", preview_alpha if preview else 1.0)
	if _number != null: _number.modulate.a = preview_alpha if preview else 1.0
	if _badge != null: _badge.queue_redraw()

func _update_visibility() -> void:
	if _overlay == null or _badge == null: return
	_overlay.visible = _display_ratio > 0.0
	visible = not _information_hidden and not preview_hidden and (_overlay.visible or _badge.visible or not _pieces.is_empty())

func _enter_badge() -> void:
	_kill(_badge_tween)
	_badge.show()
	_badge.position = _badge_center() - Vector2(0, 32)
	_badge.modulate.a = 0.0
	_badge_tween = create_tween().set_parallel(true).set_speed_scale(_speed())
	_badge_tween.tween_property(_badge, "position", _badge_center(), ENTRY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_badge_tween.tween_property(_badge, "modulate:a", 1.0, ENTRY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _fracture() -> void:
	_kill(_badge_tween)
	_kill(_break_tween)
	_clear_pieces()
	# A shared jagged mask tears the original metal face, rim, and bitmap digits.
	var origin := _badge.position
	var alpha := _badge.modulate.a
	_badge.hide()
	_break_tween = create_tween().set_parallel(true).set_speed_scale(_speed())
	for direction: int in [-1, 1]:
		var piece := Control.new()
		piece.name = "ShieldLeftHalf" if direction < 0 else "ShieldRightHalf"
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.position = origin
		piece.modulate.a = alpha
		add_child(piece)
		_pieces.append(piece)
		var face := _make_badge(piece, Vector2.ZERO, false, direction)
		face.name = "ShieldFragmentFace"
		_make_number(face, _number.text, direction)
		_break_tween.tween_property(piece, "position", piece.position + Vector2(direction * 16, 28), BREAK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_break_tween.tween_property(piece, "rotation", direction * 0.14, BREAK_TIME)
		_break_tween.tween_property(piece, "modulate:a", 0.0, BREAK_TIME * 0.75).set_delay(BREAK_TIME * 0.25)
	_break_tween.chain().tween_callback(_finish_fracture)
	_update_visibility()

func _finish_fracture() -> void:
	_clear_pieces()
	_update_visibility()

func _clear_pieces() -> void:
	for piece: Control in _pieces:
		remove_child(piece)
		piece.queue_free()
	_pieces.clear()

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid(): tween.kill()

func _speed() -> float:
	return view.animation_speed() if is_instance_valid(view) else 1.0

func _fragment_polygon(direction: int) -> PackedVector2Array:
	var polygon := PackedVector2Array(BREAK_SEAM)
	polygon.append(Vector2(direction * 46, 52))
	polygon.append(Vector2(direction * 46, -52))
	return polygon

func _make_badge(parent: Node, at: Vector2, flashing := true, direction := 0) -> Control:
	var canvas := Control.new()
	canvas.position = at
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_badge.bind(canvas, flashing, direction))
	parent.add_child(canvas)
	return canvas

func _make_number(parent: Control, text: String, direction := 0) -> OriginalBitmapNumber:
	var number := BattleArt.number(parent, "hp_digits", Vector2(-30, -22), Vector2(60, 40), HORIZONTAL_ALIGNMENT_CENTER)
	number.name = "ShieldPercent"
	number.text = text
	if direction != 0:
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/shield_fragment.gdshader")
		material.set_shader_parameter("direction", float(direction))
		material.set_shader_parameter("seam", PackedVector2Array(BREAK_SEAM))
		number.material = material
	return number

func _draw_badge(canvas: Control, flashing: bool, direction: int) -> void:
	var light := preview_alpha if preview and flashing else 1.0
	var badge := PackedVector2Array([Vector2(0, -45), Vector2(17, -37), Vector2(36, -29), Vector2(33, 2), Vector2(23, 23), Vector2(0, 45), Vector2(-23, 23), Vector2(-33, 2), Vector2(-36, -29), Vector2(-17, -37)])
	for polygon: PackedVector2Array in _face_parts(badge, direction):
		var metal_colors := PackedColorArray()
		for point: Vector2 in polygon:
			var tint := Color(0.80, 0.79, 0.73).lerp(Color(0.42, 0.44, 0.42), clampf((point.y + 45.0) / 90.0, 0.0, 1.0))
			metal_colors.append(Color(tint.r * light, tint.g * light, tint.b * light, 1.0))
		canvas.draw_polygon(polygon, metal_colors)
	var facet := PackedVector2Array([Vector2(0, -40), Vector2(-31, -26), Vector2(-28, 0), Vector2(-19, 20), Vector2(0, 39)])
	for polygon: PackedVector2Array in _face_parts(facet, direction):
		canvas.draw_colored_polygon(polygon, Color(0.70 * light, 0.71 * light, 0.65 * light, 1.0))
	if direction != 0:
		for edge: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array(BREAK_SEAM), badge):
			canvas.draw_polyline(edge, Color(0.22, 0.23, 0.20), 1.5, true)
	badge.append(badge[0])
	var outlines: Array = [badge] if direction == 0 else Geometry2D.intersect_polyline_with_polygon(badge, _fragment_polygon(direction))
	for edge: PackedVector2Array in outlines:
		canvas.draw_polyline(edge, Color(0.17, 0.15, 0.11), 5.5, true)
		canvas.draw_polyline(edge, Color(0.66, 0.61, 0.46), 2.5, true)

func _face_parts(polygon: PackedVector2Array, direction: int) -> Array[PackedVector2Array]:
	if direction == 0: return [polygon]
	return Geometry2D.intersect_polygons(polygon, _fragment_polygon(direction))

func _badge_center() -> Vector2:
	# Badges overlap the shield-bearing outer end: enemy left, player right.
	return Vector2(830 if reverse else 11, 70)
