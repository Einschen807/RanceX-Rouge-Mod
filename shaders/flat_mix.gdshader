shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform vec3 multiply_color = vec3(1.0);
uniform vec3 add_color = vec3(0.0);
uniform float layer_alpha = 1.0;
varying vec4 inherited_color;
void vertex() { inherited_color = COLOR; }
void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    COLOR = vec4(clamp((pixel.rgb + add_color) * multiply_color, vec3(0.0), vec3(1.0)), pixel.a * layer_alpha) * inherited_color;
}
