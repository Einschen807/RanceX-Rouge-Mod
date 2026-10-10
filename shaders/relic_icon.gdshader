shader_type canvas_item;
uniform bool highlighted = false;
uniform float white_amount : hint_range(0.0, 1.0) = 0.0;
uniform float outline_width = 2.0;
varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	vec4 item = texture(TEXTURE, UV);
	// Fade the original art over a white silhouette, keeping its details visible.
	float art_opacity = 1.0 - 0.6 * white_amount;
	vec3 color = mix(vec3(1.0), item.rgb, art_opacity);
	float edge = 0.0;
	if (highlighted) {
		vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_width;
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				edge = max(edge, texture(TEXTURE, UV + vec2(float(x), float(y)) * step_uv).a);
			}
		}
		edge = smoothstep(0.15, 0.65, edge) * (1.0 - item.a);
	}
	float alpha = item.a + edge;
	vec3 outlined = (color * item.a + vec3(1.0) * edge) / max(alpha, 0.0001);
	COLOR = vec4(outlined, alpha) * item_tint;
}
