shader_type canvas_item;
render_mode unshaded;

// A bounded, translucent halo around the card; its face and screen stay unchanged.
void fragment() {
	vec2 p = abs((UV - vec2(0.5)) * vec2(272.0, 376.0));
	vec2 edge = p - vec2(103.0, 155.0);
	float distance_to_card = length(max(edge, vec2(0.0))) + min(max(edge.x, edge.y), 0.0);
	float halo = exp(-abs(distance_to_card) / 11.0) * 0.24;
	float rim = exp(-abs(distance_to_card) / 2.2) * 0.17;
	float boundary = 1.0 - smoothstep(22.0, 31.0, distance_to_card);
	COLOR = vec4(vec3(0.91, 0.76, 0.40), (halo + rim) * boundary) * COLOR;
}
