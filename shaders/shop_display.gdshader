shader_type canvas_item;
// Shop goods display: stylized teal felt under a soft spotlight, a faint diamond lattice,
// a gold double frame with corner brackets and thin gold shelves under each row of goods.
uniform vec2 size = vec2(1350.0, 836.0);
uniform vec4 felt_top : source_color = vec4(0.11, 0.27, 0.27, 0.97);
uniform vec4 felt_bottom : source_color = vec4(0.05, 0.13, 0.14, 0.97);
uniform vec4 gold : source_color = vec4(0.91, 0.76, 0.42, 1.0);
uniform vec4 gold_dark : source_color = vec4(0.55, 0.40, 0.18, 1.0);
// Shelf heights in pixels from the top of the panel.
uniform vec2 shelves = vec2(404.0, 773.0);
uniform float frame = 18.0;

float line(float d, float width) {
	return smoothstep(width, width - 1.2, abs(d));
}

void fragment() {
	vec2 p = UV * size;
	vec4 color = mix(felt_top, felt_bottom, UV.y);
	// Spotlight from above the goods.
	vec2 c = (p - vec2(size.x * 0.5, -size.y * 0.15)) / size;
	color.rgb += vec3(0.09, 0.11, 0.08) * exp(-dot(c, c) * 3.2);
	// Faint diamond lattice.
	vec2 q = p / 46.0;
	vec2 f = abs(fract(vec2(q.x + q.y, q.x - q.y)) - 0.5);
	color.rgb += 0.035 * smoothstep(0.04, 0.0, abs(f.x + f.y - 0.5)) * vec3(0.7, 0.9, 0.8);
	// Shelves: a gold rail with a soft shadow falling onto the felt below it.
	for (int i = 0; i < 2; i++) {
		float y = shelves[i];
		float dy = p.y - y;
		float inside = step(frame + 10.0, p.x) * step(p.x, size.x - frame - 10.0);
		color.rgb *= 1.0 - inside * 0.35 * smoothstep(26.0, 0.0, dy) * step(0.0, dy);
		color.rgb = mix(color.rgb, gold_dark.rgb, inside * line(dy + 3.0, 3.0));
		color.rgb = mix(color.rgb, gold.rgb, inside * line(dy, 1.6));
	}
	// Edge vignette.
	vec2 e = min(p, size - p) / 140.0;
	color.rgb *= mix(0.72, 1.0, clamp(min(e.x, e.y), 0.0, 1.0));
	// Gold double frame.
	float edge = min(min(p.x, size.x - p.x), min(p.y, size.y - p.y));
	color.rgb = mix(color.rgb, gold_dark.rgb, step(edge, frame) * 0.92);
	color.rgb = mix(color.rgb, gold.rgb, line(edge - 4.0, 2.0) + line(edge - frame + 2.0, 1.6));
	color.rgb = mix(color.rgb, gold.rgb * 0.85, line(edge - frame - 8.0, 1.0) * 0.8);
	// Corner brackets just inside the frame.
	vec2 corner = min(p, size - p);
	float bracket = (line(corner.x - frame - 16.0, 1.6) * step(corner.y, frame + 70.0) + line(corner.y - frame - 16.0, 1.6) * step(corner.x, frame + 70.0)) * step(frame + 14.0, min(corner.x, corner.y));
	float jewel = smoothstep(9.0, 7.5, length(corner - vec2(frame + 16.0)));
	color.rgb = mix(color.rgb, gold.rgb, clamp(bracket + jewel, 0.0, 1.0));
	// Rounded outer corners.
	vec2 r = max(vec2(10.0) - corner, 0.0);
	color.a *= smoothstep(10.5, 9.5, length(r));
	COLOR = color;
}
