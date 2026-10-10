shader_type canvas_item;
render_mode unshaded;

uniform float direction = -1.0;
uniform vec2 seam[9];
varying vec2 crest_position;

void vertex() {
	// Bitmap digits are positioned at (-30, -22) relative to the crest center.
	crest_position = VERTEX + vec2(-30.0, -22.0);
}

void fragment() {
	float boundary = 0.0;
	for (int i = 0; i < 8; i++) {
		if (crest_position.y >= seam[i].y && crest_position.y <= seam[i + 1].y) {
			float t = (crest_position.y - seam[i].y) / (seam[i + 1].y - seam[i].y);
			boundary = mix(seam[i].x, seam[i + 1].x, t);
			break;
		}
	}
	float right_half = step(boundary, crest_position.x);
	COLOR.a *= direction < 0.0 ? 1.0 - right_half : right_half;
}
