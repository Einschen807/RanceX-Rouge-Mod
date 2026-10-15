shader_type canvas_item;
render_mode unshaded;

uniform float opening : hint_range(0.0, 1.0) = 0.002;
uniform vec4 edge_ink : source_color = vec4(0.902, 0.8, 0.573, 1.0);
uniform vec4 inner_ink : source_color = vec4(0.725, 0.918, 1.0, 1.0);

void fragment() {
	vec2 pixel = UV * vec2(1920.0, 1080.0);
	float flank = (pixel.x - 960.0) / 960.0;
	float center = 482.5 - (pixel.x - 960.0) * (133.0 / 1968.0);
	// The center retains card clearance; each flank is only 24 pixels taller per edge.
	float half_height = 211.0 + 24.0 * flank * flank;
	float boundary = abs(pixel.y - center) - half_height * opening;
	float coverage = 1.0 - smoothstep(-0.8, 0.8, boundary);
	vec4 art = texture(TEXTURE, UV);
	float rim = 1.0 - smoothstep(0.7, 2.4, abs(boundary));
	float inner = (1.0 - smoothstep(0.4, 1.2, abs(boundary + 6.0))) * opening;
	vec3 color = mix(art.rgb, inner_ink.rgb, inner * 0.48);
	color = mix(color, edge_ink.rgb, rim * 0.95);
	COLOR = vec4(color, art.a * coverage);
}
