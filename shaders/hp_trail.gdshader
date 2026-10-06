shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform vec3 dark_color = vec3(0.08, 0.10, 0.14);
uniform vec3 light_color = vec3(0.29, 0.33, 0.39);
varying vec4 inherited_color;
void vertex() { inherited_color = COLOR; }
void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    float brightness = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 trail_color = mix(dark_color, light_color, brightness);
    COLOR = vec4(trail_color, pixel.a) * inherited_color;
}
