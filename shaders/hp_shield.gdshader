shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float shield_ratio = 0.0;
uniform bool reverse = false;
uniform float preview_alpha = 1.0;
uniform sampler2D shield_surface : filter_nearest, repeat_disable;
void fragment() {
    float x = reverse ? 1.0 - UV.x : UV.x;
    float mask = step(x, shield_ratio);
    vec4 native_pixel = texture(TEXTURE, UV);
    // Both sides use the player's surface detail, mirrored for the enemy.
    // Their red/blue HP textures only supply the silhouette, never the shade.
    vec2 surface_uv = vec2(reverse ? UV.x : 1.0 - UV.x, UV.y);
    vec3 surface = texture(shield_surface, surface_uv).rgb;
    float detail = dot(surface, vec3(0.2126, 0.7152, 0.0722));
    float light = clamp(detail * 0.65 + (1.0 - UV.y) * 0.35, 0.0, 1.0);
    vec3 silver = mix(vec3(0.48, 0.50, 0.48), vec3(0.82, 0.81, 0.75), light);
    // Hover pulses brightness; the shield stays opaque over the underlying HP.
    COLOR = vec4(silver * preview_alpha, native_pixel.a * mask);
}
