shader_type canvas_item;
render_mode blend_add;
// Soft rotating light rays with a warm core glow, drawn behind the relic chest.
uniform vec4 ray_color : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform float rays = 14.0;
uniform float speed = 0.05;
uniform float strength : hint_range(0.0, 2.0) = 0.6;
void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= 1.6;
	float r = length(p);
	float angle = atan(p.y, p.x) + TIME * speed;
	float beam = pow(0.5 + 0.5 * cos(angle * rays), 6.0);
	float falloff = smoothstep(0.5, 0.05, r);
	float core = smoothstep(0.22, 0.0, r);
	float a = (beam * 0.55 * falloff + core * 0.6) * strength;
	COLOR = vec4(ray_color.rgb, clamp(a, 0.0, 1.0));
}
