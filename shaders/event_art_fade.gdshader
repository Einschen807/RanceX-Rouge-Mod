shader_type canvas_item;
// Event illustration: an oval vignette on the left that dissolves into the dark backdrop.
uniform vec2 center = vec2(0.29, 0.5);
uniform vec2 radius = vec2(0.42, 0.66);
uniform float right_start = 0.40;
uniform float right_end = 0.62;
uniform float brightness = 0.92;

void fragment() {
	float oval = 1.0 - smoothstep(0.5, 1.0, length((SCREEN_UV - center) / radius));
	float right = 1.0 - smoothstep(right_start, right_end, SCREEN_UV.x);
	COLOR.rgb *= brightness;
	COLOR.a *= oval * right;
}
