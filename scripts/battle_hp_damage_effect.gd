extends Control
class_name BattleHpDamageEffect

# Port of BarEffect: 600 ms additive white flash, then 300 ms fade/collapse.
# Its native screen mask follows both sloping HP bars; stripes retain pixel scale.
const HOLD := 0.6
const COLLAPSE := 0.3
var active := false
var elapsed := 0.0
var span_left := 0.0
var span_width := 0.0
var reverse := false
var _red: ShaderMaterial
var _stripes: ShaderMaterial
var _noise_rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1920, 1080)
	_red = _layer(preload("res://shaders/hp_damage.gdshader"))
	_stripes = _layer(preload("res://shaders/hp_damage_noise.gdshader"))
	_stripes.set_shader_parameter("stripe_texture", preload("res://assets/battle/hp_damage_noise.png"))
	_noise_rng.randomize()
	hide()

func _layer(shader: Shader) -> ShaderMaterial:
	var picture := BattleArt.picture(self, "hp_damage_mask", Vector2.ZERO)
	var material := ShaderMaterial.new()
	material.shader = shader
	picture.material = material
	return material

func play(fill: TextureRect, before: float, after: float) -> void:
	var atlas := fill.texture as AtlasTexture
	var width := atlas.atlas.get_width()
	var origin: Vector2 = fill.get_meta("origin")
	reverse = bool(fill.get_meta("reverse"))
	span_left = origin.x + width * ((1.0 - before) if reverse else after)
	span_width = width * (before - after)
	elapsed = 0.0
	active = span_width > 0.0
	visible = active
	_update_effect()

func stop() -> void:
	active = false
	hide()

func _process(delta: float) -> void:
	if not active: return
	elapsed += delta * (get_parent() as BattleScene).animation_speed()
	if elapsed >= HOLD + COLLAPSE:
		active = false
		hide()
		return
	_update_effect()

func _update_effect() -> void:
	var collapse := clampf((elapsed - HOLD) / COLLAPSE, 0.0, 1.0)
	var width := lerpf(span_width, minf(1.0, span_width), collapse)
	var left := span_left + (span_width - width if reverse else 0.0)
	for material: ShaderMaterial in [_red, _stripes]:
		material.set_shader_parameter("span_left", left)
		material.set_shader_parameter("span_width", width)
	_red.set_shader_parameter("flash_white", 1.0 - clampf(elapsed / HOLD, 0.0, 1.0))
	_red.set_shader_parameter("layer_alpha", 1.0 - collapse)
	_stripes.set_shader_parameter("layer_alpha", 1.0 - collapse)
	_stripes.set_shader_parameter("noise_offset", _noise_rng.randf_range(0.0, maxf(0.0, 1024.0 - span_width)))
