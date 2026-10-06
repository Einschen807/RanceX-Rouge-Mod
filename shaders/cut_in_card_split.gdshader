shader_type canvas_item;
render_mode unshaded;

uniform float side = -1.0;
uniform float charge = 0.0;
uniform float split = 0.0;
uniform float opacity = 1.0;
uniform vec4 light_color : source_color = vec4(0.55, 0.86, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.98, 1.0, 1.0, 1.0);

float seam(float y) {
	return 0.50 + 0.075 * sin(y * 17.0) + 0.025 * sin(y * 43.0);
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float distance_to_seam = UV.x - seam(UV.y);
	float mask = side < 0.0 ? 1.0 - smoothstep(-0.002, 0.002, distance_to_seam) : smoothstep(-0.002, 0.002, distance_to_seam);
	float crack = exp(-abs(distance_to_seam) / (0.004 + charge * 0.012));
	float halo = exp(-abs(distance_to_seam) / 0.09);
	vec3 light = light_color.rgb;
	art.rgb += charge * (crack * core_color.rgb * 1.9 + halo * light * 0.30);
	art.rgb = mix(art.rgb, light, split * crack * 0.7);
	COLOR = vec4(art.rgb, art.a * mask * opacity);
}
