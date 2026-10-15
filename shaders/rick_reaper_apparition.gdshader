shader_type canvas_item;
render_mode unshaded;

uniform float phase_time = 0.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	// Keep the skull stable; only the surrounding hood, torn cloth and smoke ripple.
	float cloth = smoothstep(0.12, 0.34, distance(UV, vec2(0.59, 0.44)));
	vec2 flowing = UV;
	flowing.x += sin(UV.y * 14.0 - phase_time * 5.0) * 0.014 * cloth;
	flowing.y += sin(UV.x * 17.0 + phase_time * 3.7) * 0.009 * cloth;
	vec4 art = texture(TEXTURE, flowing);
	vec2 eye_a = (UV - vec2(0.5986, 0.3579)) / vec2(0.026, 0.032);
	vec2 eye_b = (UV - vec2(0.5559, 0.3968)) / vec2(0.018, 0.022);
	float eyes = exp(-dot(eye_a, eye_a) * 2.0) + exp(-dot(eye_b, eye_b) * 2.0);
	vec3 fire = vec3(1.0, 0.28, 0.035) * eyes * (0.10 + 0.06 * sin(phase_time * 6.0));
	COLOR = vec4(art.rgb + fire, art.a) * vertex_tint;
}
