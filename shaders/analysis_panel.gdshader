shader_type canvas_item;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 artwork = texture(TEXTURE, UV);
	// Retain the native gold ornament and checker pattern; lighten only the dark fill.
	if (max(max(artwork.r, artwork.g), artwork.b) < 0.12) {
		artwork.a *= 0.62;
	}
	COLOR = tint * artwork;
}
