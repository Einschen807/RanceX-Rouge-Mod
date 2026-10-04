shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform vec3 multiply_color = vec3(1.0);
uniform vec3 add_color = vec3(0.0);
uniform float layer_alpha = 1.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
varying vec4 inherited_color;
void vertex() { inherited_color = COLOR; }
void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    vec3 tint = clamp((pixel.rgb + add_color) * multiply_color, vec3(0.0), vec3(1.0)) * inherited_color.rgb;
    float alpha = pixel.a * layer_alpha * inherited_color.a;
    vec3 backdrop = texture(screen_texture, SCREEN_UV).rgb;
    COLOR = vec4((vec3(1.0) - (vec3(1.0) - tint) * (vec3(1.0) - backdrop)) * alpha, alpha);
}
