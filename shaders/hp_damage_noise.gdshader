shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D stripe_texture;
uniform float span_left = 0.0;
uniform float span_width = 0.0;
uniform float noise_offset = 0.0;
uniform float layer_alpha = 0.0;
varying vec4 inherited_color;
void vertex() { inherited_color = COLOR; }
void fragment() {
    vec2 at = UV * vec2(1920.0, 1080.0);
    float inside = step(span_left, at.x) * (1.0 - step(span_left + span_width, at.x));
    float stripe = texture(stripe_texture, vec2((at.x - span_left + noise_offset) / 1024.0, clamp((at.y + 327.0) / 1024.0, 0.0, 1.0))).a;
    float mask = texture(TEXTURE, UV).a;
    COLOR = vec4(1.0, 1.0, 1.0, mask * stripe * inside * layer_alpha * 0.3) * inherited_color;
}
