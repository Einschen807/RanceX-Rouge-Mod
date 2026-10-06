shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float span_left = 0.0;
uniform float span_width = 0.0;
uniform float flash_white = 0.0;
uniform float layer_alpha = 0.0;
varying vec4 inherited_color;
void vertex() { inherited_color = COLOR; }
void fragment() {
    float x = UV.x * 1920.0;
    float inside = step(span_left, x) * (1.0 - step(span_left + span_width, x));
    float mask = texture(TEXTURE, UV).a;
    COLOR = vec4(1.0, flash_white, flash_white, mask * inside * layer_alpha * 0.7) * inherited_color;
}
