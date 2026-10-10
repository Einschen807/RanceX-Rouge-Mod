shader_type canvas_item;
uniform bool highlighted = false;
varying vec4 item_tint;
void vertex() {
	item_tint = COLOR;
}
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (highlighted) {
		vec2 step_uv = TEXTURE_PIXEL_SIZE * 2.0;
		float a = 0.0;
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				a = max(a, texture(TEXTURE, UV + vec2(float(x), float(y)) * step_uv).a);
			}
		}
		color = mix(vec4(1.0, 1.0, 1.0, a), color, color.a);
	}
	COLOR = color * item_tint;
}
